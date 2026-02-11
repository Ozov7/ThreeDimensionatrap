// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/traps/MEVSandwichDetector.sol";

contract MEVSandwichDetectorTest is Test {
    MEVSandwichDetector detector;
    
    function setUp() public {
        detector = new MEVSandwichDetector();
    }
    
    function testConstants() public view {
        assertEq(detector.UNISWAP_POOL(), address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640));
        assertEq(detector.MIN_PRICE_IMPACT_BPS(), 50);
        assertEq(detector.MIN_PROFIT_ETH(), 0.1 ether);
    }
    
    function testPlannerSafety() public view {
        bytes[] memory emptyData = new bytes[](0);
        (bool shouldTrigger, ) = detector.evaluateResponse(emptyData);
        assertFalse(shouldTrigger);
    }
    
    function testConstructor() public view {
        address(detector);
    }
}
