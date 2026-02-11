// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/traps/OracleManipulationDetector.sol";

contract OracleManipulationDetectorTest is Test {
    OracleManipulationDetector detector;
    
    function setUp() public {
        detector = new OracleManipulationDetector();
    }
    
    function testConstants() public view {
        assertEq(detector.CHAINLINK_ETH_USD(), address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));
        assertEq(detector.MAX_DEVIATION_BPS(), 500);
    }
    
    function testPlannerSafety() public view {
        bytes[] memory emptyData = new bytes[](0);
        (bool shouldTrigger, ) = detector.evaluateResponse(emptyData);
        assertFalse(shouldTrigger);
    }
}
