// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "drosera-contracts/Trap.sol";
import "../traps/MEVSandwichDetector.sol";
import "../traps/GovernanceAttackMonitor.sol";
import "../traps/OracleManipulationDetector.sol";

contract SecurityOrchestrator is Trap {
    // ========== DEPENDENCIES ==========
    MEVSandwichDetector public immutable mevDetector;
    GovernanceAttackMonitor public immutable govMonitor;
    OracleManipulationDetector public immutable oracleDetector;
    
    // ========== OWNERSHIP ==========
    address public owner;
    bool public paused;
    
    // ========== EVENTS ==========
    event OrchestratorPaused(address indexed by);
    event OrchestratorUnpaused(address indexed by);
    event CrossVectorAttackDetected(string attackType, uint256 blockNumber);
    
    // ========== MODIFIERS ==========
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Orchestrator paused");
        _;
    }
    
    // ========== CONSTRUCTOR ==========
    constructor(
        address _mevDetector,
        address _govMonitor,
        address _oracleDetector
    ) {
        require(_mevDetector != address(0), "Invalid MEV detector");
        require(_govMonitor != address(0), "Invalid gov monitor");
        require(_oracleDetector != address(0), "Invalid oracle detector");
        
        mevDetector = MEVSandwichDetector(_mevDetector);
        govMonitor = GovernanceAttackMonitor(_govMonitor);
        oracleDetector = OracleManipulationDetector(_oracleDetector);
        owner = msg.sender;
    }
    
    // ========== OWNER FUNCTIONS ==========
    function pause() external onlyOwner {
        paused = true;
        emit OrchestratorPaused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit OrchestratorUnpaused(msg.sender);
    }
    
    // ========== DROSERA TRAP FUNCTIONS ==========
    function collect() external view override whenNotPaused returns (bytes memory) {
        // Collect data from all traps with try/catch to prevent revert bombing
        bytes memory mevData;
        bytes memory govData;
        bytes memory oracleData;
        
        // Try MEV detector
        (bool mevSuccess, bytes memory mevResult) = address(mevDetector).staticcall(
            abi.encodeWithSelector(mevDetector.collect.selector)
        );
        if (mevSuccess) {
            mevData = abi.decode(mevResult, (bytes));
        } else {
            mevData = abi.encode(new MEVSandwichDetector.SwapInfo[](0), block.number);
        }
        
        // Try Governance monitor
        (bool govSuccess, bytes memory govResult) = address(govMonitor).staticcall(
            abi.encodeWithSelector(govMonitor.collect.selector)
        );
        if (govSuccess) {
            govData = abi.decode(govResult, (bytes));
        } else {
            govData = abi.encode(uint256(0), uint256(0), block.number);
        }
        
        // Try Oracle detector
        (bool oracleSuccess, bytes memory oracleResult) = address(oracleDetector).staticcall(
            abi.encodeWithSelector(oracleDetector.collect.selector)
        );
        if (oracleSuccess) {
            oracleData = abi.decode(oracleResult, (bytes));
        } else {
            oracleData = abi.encode(int256(0), uint256(0), uint256(0), int24(0), block.number, block.timestamp);
        }
        
        return abi.encode(mevData, govData, oracleData, block.number, address(this));
    }
    
    function shouldRespond(bytes[] calldata data) external view override whenNotPaused returns (bool, bytes memory) {
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        (bytes memory mevData, bytes memory govData, bytes memory oracleData, uint256 collectionBlock, address orchestratorAddress) = 
            abi.decode(data[0], (bytes, bytes, bytes, uint256, address));
        
        require(orchestratorAddress == address(this), "Invalid orchestrator");
        
        // Check each trap individually with try/catch
        bool mevTriggered = false;
        bool govTriggered = false;
        bool oracleTriggered = false;
        bytes memory mevResponse;
        bytes memory govResponse;
        bytes memory oracleResponse;
        
        // Check MEV
        bytes[] memory mevInput = new bytes[](1);
        mevInput[0] = mevData;
        (bool mevSuccess, bytes memory mevResult) = address(mevDetector).staticcall(
            abi.encodeWithSelector(mevDetector.shouldRespond.selector, mevInput)
        );
        if (mevSuccess) {
            (mevTriggered, mevResponse) = abi.decode(mevResult, (bool, bytes));
        }
        
        // Check Governance
        bytes[] memory govInput = new bytes[](1);
        govInput[0] = govData;
        (bool govSuccess, bytes memory govResult) = address(govMonitor).staticcall(
            abi.encodeWithSelector(govMonitor.shouldRespond.selector, govInput)
        );
        if (govSuccess) {
            (govTriggered, govResponse) = abi.decode(govResult, (bool, bytes));
        }
        
        // Check Oracle
        bytes[] memory oracleInput = new bytes[](1);
        oracleInput[0] = oracleData;
        (bool oracleSuccess, bytes memory oracleResult) = address(oracleDetector).staticcall(
            abi.encodeWithSelector(oracleDetector.shouldRespond.selector, oracleInput)
        );
        if (oracleSuccess) {
            (oracleTriggered, oracleResponse) = abi.decode(oracleResult, (bool, bytes));
        }
        
        // Detect cross-vector attacks
        if (mevTriggered && oracleTriggered) {
            emit CrossVectorAttackDetected("MEV_WITH_ORACLE_MANIPULATION", collectionBlock);
            return (true, abi.encode("MEV_WITH_ORACLE_MANIPULATION", mevResponse, oracleResponse));
        }
        
        if (govTriggered && oracleTriggered) {
            emit CrossVectorAttackDetected("GOVERNANCE_ORACLE_TAKEOVER", collectionBlock);
            return (true, abi.encode("GOVERNANCE_ORACLE_TAKEOVER", govResponse, oracleResponse));
        }
        
        if (mevTriggered && govTriggered) {
            emit CrossVectorAttackDetected("MEV_GOVERNANCE_COORDINATED", collectionBlock);
            return (true, abi.encode("MEV_GOVERNANCE_COORDINATED", mevResponse, govResponse));
        }
        
        if (mevTriggered || govTriggered || oracleTriggered) {
            if (mevTriggered) return (true, abi.encode("MEV_ONLY", mevResponse));
            if (govTriggered) return (true, abi.encode("GOVERNANCE_ONLY", govResponse));
            if (oracleTriggered) return (true, abi.encode("ORACLE_ONLY", oracleResponse));
        }
        
        return (false, bytes(""));
    }
}
