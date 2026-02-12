// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecurityResponder {
    // ========== STATE ==========
    address public immutable orchestrator;
    address public owner;
    bool public paused;
    
    // ========== EVENTS ==========
    event OrchestratorUpdated(address indexed newOrchestrator);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    
    event MEVAlert(
        address indexed victim,
        address indexed attacker,
        uint256 profitEstimate,
        uint256 priceImpact,
        uint256 blockNumber
    );
    
    event GovernanceAlert(
        uint256 indexed proposalId,
        address indexed suspiciousAddress,
        string attackType,
        uint256 votingPowerChange,
        uint256 timestamp
    );
    
    event OracleAlert(
        address indexed oracleSource,
        uint256 reportedPrice,
        uint256 referencePrice,
        uint256 deviationBps,
        uint256 volume,
        uint256 timestamp,
        bool isStale
    );
    
    event CrossVectorAlert(
        string attackType,
        uint256 blockNumber,
        bytes[] alertData
    );
    
    // ========== MODIFIERS ==========
    modifier onlyOrchestrator() {
        require(msg.sender == orchestrator, "Only orchestrator can call");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Responder paused");
        _;
    }
    
    // ========== CONSTRUCTOR ==========
    constructor(address _orchestrator) {
        require(_orchestrator != address(0), "Invalid orchestrator");
        orchestrator = _orchestrator;
        owner = msg.sender;
    }
    
    // ========== OWNER FUNCTIONS ==========
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
    
    // ========== RESPONSE FUNCTIONS ==========
    function handleMEVAlert(bytes calldata alertData) 
        external 
        onlyOrchestrator 
        whenNotPaused 
    {
        (
            address victim,
            address attacker,
            uint256 profitEstimate,
            uint256 priceImpact,
            uint256 blockNumber
        ) = abi.decode(alertData, (address, address, uint256, uint256, uint256));
        
        emit MEVAlert(victim, attacker, profitEstimate, priceImpact, blockNumber);
    }
    
    function handleGovernanceAlert(bytes calldata alertData) 
        external 
        onlyOrchestrator 
        whenNotPaused 
    {
        (
            uint256 proposalId,
            address suspiciousAddress,
            string memory attackType,
            uint256 votingPowerChange,
            uint256 timestamp
        ) = abi.decode(alertData, (uint256, address, string, uint256, uint256));
        
        emit GovernanceAlert(proposalId, suspiciousAddress, attackType, votingPowerChange, timestamp);
    }
    
    function handleOracleAlert(bytes calldata alertData) 
        external 
        onlyOrchestrator 
        whenNotPaused 
    {
        (
            address oracleSource,
            uint256 reportedPrice,
            uint256 referencePrice,
            uint256 deviationBps,
            uint256 volume,
            uint256 timestamp,
            bool isStale
        ) = abi.decode(alertData, (address, uint256, uint256, uint256, uint256, uint256, bool));
        
        emit OracleAlert(oracleSource, reportedPrice, referencePrice, deviationBps, volume, timestamp, isStale);
    }
    
    function handleCrossVectorAlert(bytes calldata alertData) 
        external 
        onlyOrchestrator 
        whenNotPaused 
    {
        (
            string memory attackType,
            uint256 blockNumber,
            bytes[] memory individualAlerts
        ) = abi.decode(alertData, (string, uint256, bytes[]));
        
        emit CrossVectorAlert(attackType, blockNumber, individualAlerts);
    }
}
