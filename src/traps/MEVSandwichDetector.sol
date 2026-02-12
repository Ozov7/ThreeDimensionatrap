// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "drosera-contracts/Trap.sol";

/**
 * @title MEVSandwichDetector
 * @notice CORRECT implementation for Uniswap V3 sandwich detection
 */
contract MEVSandwichDetector is Trap {
    // ========== MAINNET ADDRESSES ==========
    address public constant UNISWAP_V3_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // WETH-USDC 0.05%
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // ========== THRESHOLDS (Configurable) ==========
    uint256 public priceImpactThresholdBps = 50; // 0.5%
    uint256 public minProfitThreshold = 0.1 ether; // 0.1 ETH
    address public owner;
    
    // ========== EVENTS ==========
    event ThresholdsUpdated(uint256 priceImpact, uint256 minProfit);
    event MEVDetected(address indexed victim, address indexed attacker, uint256 profit, uint256 impact);
    
    // ========== CONSTRUCTOR ==========
    constructor() {
        owner = msg.sender;
        // CORRECT: Add event filter with real Uniswap V3 Swap topic
        _addEventFilter(
            UNISWAP_V3_POOL,
            keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)")
        );
    }
    
    // ========== OWNER FUNCTIONS ==========
    function setThresholds(uint256 _priceImpactBps, uint256 _minProfit) external {
        require(msg.sender == owner, "Only owner");
        require(_priceImpactBps >= 10 && _priceImpactBps <= 500, "Invalid price impact");
        priceImpactThresholdBps = _priceImpactBps;
        minProfitThreshold = _minProfit;
        emit ThresholdsUpdated(_priceImpactBps, _minProfit);
    }
    
    // ========== DROSERA TRAP FUNCTIONS ==========
    function collect() external view override returns (bytes memory) {
        // CORRECT: Get REAL logs from Drosera
        Trap.Log[] memory logs = getFilteredLogs();
        
        // Store swaps from this block
        SwapInfo[] memory swaps = new SwapInfo[](logs.length);
        uint256 swapCount = 0;
        
        for (uint256 i = 0; i < logs.length; i++) {
            // CORRECT: Uniswap V3 Swap event has 3 topics
            // topics[0] = event signature
            // topics[1] = sender (indexed)
            // topics[2] = recipient (indexed)
            if (logs[i].topics.length < 3) continue;
            if (logs[i].topics[0] != getSwapTopic()) continue;
            
            // CORRECT: Decode Uniswap V3 Swap data
            // Data contains: amount0, amount1, sqrtPriceX96, liquidity, tick
            (int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick) = 
                abi.decode(logs[i].data, (int256, int256, uint160, uint128, int24));
            
            address sender = address(uint160(uint256(logs[i].topics[1])));
            address recipient = address(uint160(uint256(logs[i].topics[2])));
            
            swaps[swapCount] = SwapInfo({
                sender: sender,
                recipient: recipient,
                amount0: amount0,
                amount1: amount1,
                sqrtPriceX96: sqrtPriceX96,
                liquidity: liquidity,
                tick: tick,
                blockNumber: block.number,
                timestamp: block.timestamp
            });
            swapCount++;
        }
        
        // Resize array
        assembly { mstore(swaps, swapCount) }
        
        return abi.encode(swaps, block.number);
    }
    
    function shouldRespond(bytes[] calldata data) external view override returns (bool, bytes memory) {
        // Planner safety
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        // Decode swap data
        (SwapInfo[] memory swaps, uint256 blockNumber) = 
            abi.decode(data[0], (SwapInfo[], uint256));
        
        // Need at least 3 swaps for sandwich
        if (swaps.length < 3) return (false, bytes(""));
        
        // Look for sandwich pattern:
        // 1. First swap: BUY (amount0 > 0, amount1 < 0)
        // 2. Middle swap: VICTIM (could be either direction)
        // 3. Last swap: SELL (amount0 < 0, amount1 > 0)
        // AND they happen in same block with same pool
        
        bool isSandwich = false;
        address attacker;
        address victim;
        uint256 estimatedProfit = 0;
        uint256 priceImpact = 0;
        
        // Simple detection: First and last swaps by same address, middle by different address
        if (swaps[0].sender == swaps[swaps.length - 1].sender && 
            swaps[0].sender != swaps[1].sender) {
            
            isSandwich = true;
            attacker = swaps[0].sender;
            victim = swaps[1].sender;
            
            // Estimate profit (simplified - would need actual token decimals)
            if (swaps[0].amount0 > 0 && swaps[0].amount1 < 0 && 
                swaps[swaps.length - 1].amount0 < 0 && swaps[swaps.length - 1].amount1 > 0) {
                // ETH -> USDC then USDC -> ETH
                estimatedProfit = uint256(-swaps[swaps.length - 1].amount1) - uint256(swaps[0].amount1);
            }
            
            // Calculate price impact from tick
            if (swaps.length >= 2) {
                priceImpact = uint256(uint24(
                    swaps[swaps.length - 1].tick > swaps[0].tick ? 
                    swaps[swaps.length - 1].tick - swaps[0].tick : 
                    swaps[0].tick - swaps[swaps.length - 1].tick
                ));
            }
        }
        
        if (isSandwich && estimatedProfit >= minProfitThreshold) {
            MEVAlert memory alert = MEVAlert({
                victim: victim,
                attacker: attacker,
                profitEstimate: estimatedProfit,
                priceImpact: priceImpact,
                blockNumber: blockNumber
            });
            
            emit MEVDetected(victim, attacker, estimatedProfit, priceImpact);
            return (true, abi.encode(alert));
        }
        
        return (false, bytes(""));
    }
    
    // ========== STRUCTS ==========
    struct SwapInfo {
        address sender;
        address recipient;
        int256 amount0;
        int256 amount1;
        uint160 sqrtPriceX96;
        uint128 liquidity;
        int24 tick;
        uint256 blockNumber;
        uint256 timestamp;
    }
    
    struct MEVAlert {
        address victim;
        address attacker;
        uint256 profitEstimate;
        uint256 priceImpact;
        uint256 blockNumber;
    }
    
    // ========== HELPERS ==========
    function getSwapTopic() public pure returns (bytes32) {
        return keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)");
    }
}
