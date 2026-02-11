// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecurityResponder {
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
        string alertType,
        uint256 votingPowerChange,
        uint256 timestamp
    );
    
    event OracleAlert(
        address indexed oracleSource,
        uint256 reportedPrice,
        uint256 referencePrice,
        uint256 deviationBps,
        uint256 volume,
        uint256 timestamp
    );
    
    function handleMEVAlert(bytes calldata alertData) external {
        (
            address victim,
            address attacker,
            uint256 profitEstimate,
            uint256 priceImpact,
            uint256 blockNumber
        ) = abi.decode(alertData, (address, address, uint256, uint256, uint256));
        
        emit MEVAlert(victim, attacker, profitEstimate, priceImpact, blockNumber);
    }
    
    function handleGovernanceAlert(bytes calldata alertData) external {
        (
            uint256 proposalId,
            address suspiciousAddress,
            string memory alertType,
            uint256 votingPowerChange,
            uint256 timestamp
        ) = abi.decode(alertData, (uint256, address, string, uint256, uint256));
        
        emit GovernanceAlert(proposalId, suspiciousAddress, alertType, votingPowerChange, timestamp);
    }
    
    function handleOracleAlert(bytes calldata alertData) external {
        (
            address oracleSource,
            uint256 reportedPrice,
            uint256 referencePrice,
            uint256 deviationBps,
            uint256 volume,
            uint256 timestamp
        ) = abi.decode(alertData, (address, uint256, uint256, uint256, uint256, uint256));
        
        emit OracleAlert(oracleSource, reportedPrice, referencePrice, deviationBps, volume, timestamp);
    }
}
