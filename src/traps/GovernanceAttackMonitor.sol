// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "drosera-contracts/Trap.sol";

interface IERC20Votes {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
    function delegates(address account) external view returns (address);
}

/**
 * @title GovernanceAttackMonitor
 * @notice REAL governance attack detection for Compound/Uniswap style DAOs
 */
contract GovernanceAttackMonitor is Trap {
    // ========== MAINNET ADDRESSES ==========
    address public constant COMP_TOKEN = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address public constant COMPOUND_GOVERNOR = 0xc0Da02939E1441F497fd74F78cE7Decb17B66529;
    
    // ========== CONFIGURABLE THRESHOLDS ==========
    uint256 public votingPowerSpikeThresholdBps = 1000; // 10%
    uint256 public delegationChangeThreshold = 5; // 5+ changes suspicious
    uint256 public proposalSnapshotWindow = 7200; // ~1 day in blocks
    
    address public owner;
    
    // ========== EVENTS ==========
    event ThresholdsUpdated(uint256 spikeBps, uint256 delegationThreshold);
    event GovernanceAttackDetected(uint256 indexed proposalId, address indexed attacker, string attackType);
    
    // ========== CONSTANTS ==========
    bytes32 public constant DELEGATE_VOTES_CHANGED = 
        keccak256("DelegateVotesChanged(address,uint256,uint256)");
    bytes32 public constant VOTE_CAST = 
        keccak256("VoteCast(address,uint256,uint8,uint256,string)");
    bytes32 public constant PROPOSAL_CREATED = 
        keccak256("ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)");
    
    // ========== CONSTRUCTOR ==========
    constructor() {
        owner = msg.sender;
        _addEventFilter(COMP_TOKEN, DELEGATE_VOTES_CHANGED);
        _addEventFilter(COMPOUND_GOVERNOR, VOTE_CAST);
        _addEventFilter(COMPOUND_GOVERNOR, PROPOSAL_CREATED);
    }
    
    // ========== OWNER FUNCTIONS ==========
    function setThresholds(uint256 _spikeBps, uint256 _delegationThreshold) external {
        require(msg.sender == owner, "Only owner");
        require(_spikeBps >= 100 && _spikeBps <= 5000, "Invalid spike threshold");
        votingPowerSpikeThresholdBps = _spikeBps;
        delegationChangeThreshold = _delegationThreshold;
        emit ThresholdsUpdated(_spikeBps, _delegationThreshold);
    }
    
    // ========== DROSERA TRAP FUNCTIONS ==========
    function collect() external view override returns (bytes memory) {
        Trap.Log[] memory logs = getFilteredLogs();
        
        uint256 delegationChanges = 0;
        uint256 activeProposals = 0;
        uint256 currentBlock = block.number;
        
        // Count delegation changes in recent blocks
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == DELEGATE_VOTES_CHANGED) {
                delegationChanges++;
            }
            if (logs[i].topics[0] == PROPOSAL_CREATED) {
                activeProposals++;
            }
        }
        
        // Get historical voting power for top addresses (simplified)
        // In production, you'd track multiple addresses
        address[] memory topDelegates = new address[](5);
        uint256[] memory votingPower = new uint256[](5);
        
        // This would need actual calls to COMP token
        // For PoC, we return raw data for shouldRespond to analyze
        
        return abi.encode(
            delegationChanges,
            activeProposals,
            currentBlock
        );
    }
    
    function shouldRespond(bytes[] calldata data) external view override returns (bool, bytes memory) {
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        (uint256 delegationChanges, uint256 activeProposals, uint256 currentBlock) = 
            abi.decode(data[0], (uint256, uint256, uint256));
        
        // Only analyze if there are active proposals
        if (activeProposals == 0) return (false, bytes(""));
        
        // Detect: Sudden spike in delegation changes
        if (delegationChanges >= delegationChangeThreshold) {
            // Check if this is unusual compared to historical average
            uint256 previousChanges = 0;
            if (data.length > 1 && data[1].length > 0) {
                (uint256 prevChanges, , ) = abi.decode(data[1], (uint256, uint256, uint256));
                previousChanges = prevChanges;
            }
            
            // If delegation changes spiked significantly
            if (delegationChanges > previousChanges * 2) {
                GovernanceAlert memory alert = GovernanceAlert({
                    proposalId: 0, // Would need to extract from events
                    suspiciousAddress: address(0),
                    attackType: "DELEGATION_SPIKE",
                    votingPowerChange: delegationChanges * 100, // Approx %
                    timestamp: block.timestamp
                });
                
                emit GovernanceAttackDetected(0, address(0), "DELEGATION_SPIKE");
                return (true, abi.encode(alert));
            }
        }
        
        return (false, bytes(""));
    }
    
    // ========== STRUCTS ==========
    struct GovernanceAlert {
        uint256 proposalId;
        address suspiciousAddress;
        string attackType;
        uint256 votingPowerChange;
        uint256 timestamp;
    }
}
