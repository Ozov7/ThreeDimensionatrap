// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/traps/MEVSandwichDetector.sol";
import "../src/traps/GovernanceAttackMonitor.sol";
import "../src/traps/OracleManipulationDetector.sol";
import "../src/responders/SecurityResponder.sol";
import "../src/orchestrator/SecurityOrchestrator.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy responder
        SecurityResponder responder = new SecurityResponder();
        console.log("Responder deployed at:", address(responder));
        
        // Deploy individual traps
        MEVSandwichDetector mevTrap = new MEVSandwichDetector();
        console.log("MEV Trap deployed at:", address(mevTrap));
        
        GovernanceAttackMonitor govTrap = new GovernanceAttackMonitor();
        console.log("Governance Trap deployed at:", address(govTrap));
        
        OracleManipulationDetector oracleTrap = new OracleManipulationDetector();
        console.log("Oracle Trap deployed at:", address(oracleTrap));
        
        // Deploy unified orchestrator
        SecurityOrchestrator orchestrator = new SecurityOrchestrator(
            address(mevTrap),
            address(govTrap),
            address(oracleTrap)
        );
        console.log("Security Orchestrator deployed at:", address(orchestrator));
        
        vm.stopBroadcast();
        
        // Configuration output
        console.log("\nDrosera Configuration:");
        console.log("=======================");
        console.log("\n[trap.security_orchestrator]");
        console.log("address = \"%s\"", address(orchestrator));
        console.log("response_contract = \"%s\"", address(responder));
        console.log("response_function = \"handleCrossVectorAlert\"");
        console.log("block_sample_size = 5");
    }
}
