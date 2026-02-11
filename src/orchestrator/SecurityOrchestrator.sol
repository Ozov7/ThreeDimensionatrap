// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "../interfaces/ITrap.sol";
import "../traps/MEVSandwichDetector.sol";
import "../traps/GovernanceAttackMonitor.sol";
import "../traps/OracleManipulationDetector.sol";

/**
 * @title SecurityOrchestrator
 * @notice UNIFIED TRAP that coordinates all 3 security vectors
 * @dev Detects multi-stage attacks that span MEV + Governance + Oracle
 * 
 * THIS MAKES ALL 3 TRAPS WORK TOGETHER AS ONE SYSTEM
 */
contract SecurityOrchestrator is Trap {
    // ========== DEPENDENCIES ==========
    MEVSandwichDetector public mevDetector;
    GovernanceAttackMonitor public govMonitor;
    OracleManipulationDetector public oracleDetector;
    
    // ========== STRUCTS ==========
    struct CrossVectorAlert {
        address primaryTarget;
        string attackType;
        uint256 startBlock;
        uint256 endBlock;
        address[] involvedAddresses;
        uint256 estimatedTotalProfit;
        string[] triggeredTraps; // ["MEV", "GOVERNANCE", "ORACLE"]
    }
    
    // ========== CONSTRUCTOR ==========
    constructor(
        address _mevDetector,
        address _govMonitor,
        address _oracleDetector
    ) {
        mevDetector = MEVSandwichDetector(_mevDetector);
        govMonitor = GovernanceAttackMonitor(_govMonitor);
        oracleDetector = OracleManipulationDetector(_oracleDetector);
    }
    
    // ========== UNIFIED TRAP FUNCTIONS ==========
    function collect() external view override returns (bytes memory) {
        // Collect data from ALL 3 traps
        bytes memory mevData = mevDetector.collect();
        bytes memory govData = govMonitor.collect();
        bytes memory oracleData = oracleDetector.collect();
        
        return abi.encode(mevData, govData, oracleData, block.number);
    }
    
    function evaluateResponse(
        bytes[] calldata data
    ) external view override returns (bool, bytes memory) {
        // Planner safety
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        // Decode combined data from all traps
        (bytes memory mevData, bytes memory govData, bytes memory oracleData, uint256 collectionBlock) = 
            abi.decode(data[0], (bytes, bytes, bytes, uint256));
        
        // Check each trap individually
        bool mevTriggering = false;
        bool govTriggering = false;
        bool oracleTriggering = false;
        bytes memory mevResponse;
        bytes memory govResponse;
        bytes memory oracleResponse;
        
        // Check MEV trap
        bytes[] memory mevInput = new bytes[](1);
        mevInput[0] = mevData;
        (mevTriggering, mevResponse) = mevDetector.evaluateResponse(mevInput);
        
        // Check Governance trap
        bytes[] memory govInput = new bytes[](1);
        govInput[0] = govData;
        (govTriggering, govResponse) = govMonitor.evaluateResponse(govInput);
        
        // Check Oracle trap
        bytes[] memory oracleInput = new bytes[](1);
        oracleInput[0] = oracleData;
        (oracleTriggering, oracleResponse) = oracleDetector.evaluateResponse(oracleInput);
        
        // ===== CROSS-VECTOR DETECTION =====
        // THIS IS THE MAGIC - DETECTING ATTACKS THAT USE MULTIPLE VECTORS
        
        // SCENARIO 1: MEV + Oracle combined attack
        if (mevTriggering && oracleTriggering) {
            CrossVectorAlert memory alert = CrossVectorAlert({
                primaryTarget: extractAttacker(mevResponse),
                attackType: "MEV_WITH_ORACLE_MANIPULATION",
                startBlock: collectionBlock - 10,
                endBlock: collectionBlock,
                involvedAddresses: extractAddresses(mevResponse, oracleResponse),
                estimatedTotalProfit: extractProfit(mevResponse) + 100 ether,
                triggeredTraps: new string[](2)
            });
            alert.triggeredTraps[0] = "MEV";
            alert.triggeredTraps[1] = "ORACLE";
            
            return (true, abi.encode(alert));
        }
        
        // SCENARIO 2: Governance + Oracle combined attack
        if (govTriggering && oracleTriggering) {
            CrossVectorAlert memory alert = CrossVectorAlert({
                primaryTarget: extractSuspiciousAddress(govResponse),
                attackType: "GOVERNANCE_ORACLE_TAKEOVER",
                startBlock: collectionBlock - 100,
                endBlock: collectionBlock,
                involvedAddresses: extractGovernanceAddresses(govResponse),
                estimatedTotalProfit: 0,
                triggeredTraps: new string[](2)
            });
            alert.triggeredTraps[0] = "GOVERNANCE";
            alert.triggeredTraps[1] = "ORACLE";
            
            return (true, abi.encode(alert));
        }
        
        // SCENARIO 3: MEV + Governance combined attack
        if (mevTriggering && govTriggering) {
            CrossVectorAlert memory alert = CrossVectorAlert({
                primaryTarget: extractAttacker(mevResponse),
                attackType: "MEV_GOVERNANCE_COORDINATED",
                startBlock: collectionBlock - 50,
                endBlock: collectionBlock,
                involvedAddresses: new address[](2),
                estimatedTotalProfit: extractProfit(mevResponse),
                triggeredTraps: new string[](2)
            });
            alert.triggeredTraps[0] = "MEV";
            alert.triggeredTraps[1] = "GOVERNANCE";
            alert.involvedAddresses[0] = extractAttacker(mevResponse);
            alert.involvedAddresses[1] = extractSuspiciousAddress(govResponse);
            
            return (true, abi.encode(alert));
        }
        
        // SCENARIO 4: All 3 traps trigger together (sophisticated attack)
        if (mevTriggering && govTriggering && oracleTriggering) {
            CrossVectorAlert memory alert = CrossVectorAlert({
                primaryTarget: extractAttacker(mevResponse),
                attackType: "FULL_SPECTRUM_ATTACK",
                startBlock: collectionBlock - 100,
                endBlock: collectionBlock,
                involvedAddresses: new address[](3),
                estimatedTotalProfit: extractProfit(mevResponse) + 200 ether,
                triggeredTraps: new string[](3)
            });
            alert.triggeredTraps[0] = "MEV";
            alert.triggeredTraps[1] = "GOVERNANCE";
            alert.triggeredTraps[2] = "ORACLE";
            alert.involvedAddresses[0] = extractAttacker(mevResponse);
            alert.involvedAddresses[1] = extractSuspiciousAddress(govResponse);
            alert.involvedAddresses[2] = address(0);
            
            return (true, abi.encode(alert));
        }
        
        // SCENARIO 5: Individual trap triggers (fallback)
        if (mevTriggering) return (true, abi.encode("MEV", mevResponse));
        if (govTriggering) return (true, abi.encode("GOVERNANCE", govResponse));
        if (oracleTriggering) return (true, abi.encode("ORACLE", oracleResponse));
        
        return (false, bytes(""));
    }
    
    // ========== HELPER FUNCTIONS ==========
    function extractAttacker(bytes memory mevResponse) internal pure returns (address) {
        (address victim, address attacker, , , ) = 
            abi.decode(mevResponse, (address, address, uint256, uint256, uint256));
        return attacker;
    }
    
    function extractProfit(bytes memory mevResponse) internal pure returns (uint256) {
        (, , uint256 profit, , ) = abi.decode(mevResponse, (address, address, uint256, uint256, uint256));
        return profit;
    }
    
    function extractAddresses(bytes memory mevResponse, bytes memory) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](2);
        (, address attacker, , , ) = abi.decode(mevResponse, (address, address, uint256, uint256, uint256));
        addresses[0] = attacker;
        addresses[1] = address(0);
        return addresses;
    }
    
    function extractSuspiciousAddress(bytes memory govResponse) internal pure returns (address) {
        (, address suspiciousAddress, , , ) = 
            abi.decode(govResponse, (uint256, address, string, uint256, uint256));
        return suspiciousAddress;
    }
    
    function extractGovernanceAddresses(bytes memory govResponse) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](1);
        (, address suspiciousAddress, , , ) = 
            abi.decode(govResponse, (uint256, address, string, uint256, uint256));
        addresses[0] = suspiciousAddress;
        return addresses;
    }
}
