// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/traps/GovernanceAttackMonitor.sol";

contract GovernanceAttackMonitorTest is Test {
    GovernanceAttackMonitor monitor;
    
    function setUp() public {
        monitor = new GovernanceAttackMonitor();
    }
    
    function testConstants() public view {
        assertEq(monitor.GOVERNANCE_TOKEN(), address(0xc00e94Cb662C3520282E6f5717214004A7f26888));
        assertEq(monitor.GOVERNOR(), address(0xc0Da02939E1441F497fd74F78cE7Decb17B66529));
        assertEq(monitor.VOTING_POWER_SPIKE_BPS(), 1000);
    }
    
    function testPlannerSafety() public view {
        bytes[] memory emptyData = new bytes[](0);
        (bool shouldTrigger, ) = monitor.evaluateResponse(emptyData);
        assertFalse(shouldTrigger);
    }
}
