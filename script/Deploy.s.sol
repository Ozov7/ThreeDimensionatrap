// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/traps/MEVSandwichDetector.sol";
import "../src/traps/GovernanceAttackMonitor.sol";
import "../src/traps/OracleManipulationDetector.sol";
import "../src/responders/SecurityResponder.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        SecurityResponder responder = new SecurityResponder();
        console.log("Responder deployed at: %s", address(responder));
        
        MEVSandwichDetector mevTrap = new MEVSandwichDetector();
        console.log("MEV Trap deployed at: %s", address(mevTrap));
        
        GovernanceAttackMonitor govTrap = new GovernanceAttackMonitor();
        console.log("Governance Trap deployed at: %s", address(govTrap));
        
        OracleManipulationDetector oracleTrap = new OracleManipulationDetector();
        console.log("Oracle Trap deployed at: %s", address(oracleTrap));
        
        vm.stopBroadcast();
    }
}
