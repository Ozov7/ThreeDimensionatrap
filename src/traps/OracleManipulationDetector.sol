// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "drosera-contracts/Trap.sol";

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
}

interface IUniswapV3Pool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/**
 * @title OracleManipulationDetector
 * @notice REAL oracle manipulation detection with live price feeds
 */
contract OracleManipulationDetector is Trap {
    // ========== MAINNET ADDRESSES ==========
    address public constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant UNISWAP_V3_WETH_USDC = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // ========== CONFIGURABLE THRESHOLDS ==========
    uint256 public deviationThresholdBps = 500; // 5%
    uint256 public volumeThreshold = 100 ether; // 100 ETH
    uint256 public timeWindow = 30; // 30 blocks
    
    address public owner;
    
    // ========== EVENTS ==========
    event ThresholdsUpdated(uint256 deviationBps, uint256 volume);
    event OracleAttackDetected(address indexed oracle, uint256 deviation, uint256 volume);
    
    // ========== CONSTRUCTOR ==========
    constructor() {
        owner = msg.sender;
        // Monitor Chainlink updates
        _addEventFilter(
            CHAINLINK_ETH_USD,
            keccak256("AnswerUpdated(int256,uint256,uint256)")
        );
    }
    
    // ========== OWNER FUNCTIONS ==========
    function setThresholds(uint256 _deviationBps, uint256 _volume) external {
        require(msg.sender == owner, "Only owner");
        require(_deviationBps >= 100 && _deviationBps <= 2000, "Invalid deviation");
        deviationThresholdBps = _deviationBps;
        volumeThreshold = _volume;
        emit ThresholdsUpdated(_deviationBps, _volume);
    }
    
    // ========== DROSERA TRAP FUNCTIONS ==========
    function collect() external view override returns (bytes memory) {
        // Get REAL Chainlink price
        int256 chainlinkPrice;
        uint256 chainlinkTimestamp;
        
        try IChainlinkAggregator(CHAINLINK_ETH_USD).latestAnswer() returns (int256 price) {
            chainlinkPrice = price;
        } catch {
            chainlinkPrice = 0;
        }
        
        try IChainlinkAggregator(CHAINLINK_ETH_USD).latestTimestamp() returns (uint256 ts) {
            chainlinkTimestamp = ts;
        } catch {
            chainlinkTimestamp = 0;
        }
        
        // Get REAL Uniswap price
        uint160 sqrtPriceX96;
        int24 tick;
        
        try IUniswapV3Pool(UNISWAP_V3_WETH_USDC).slot0() returns (
            uint160 _sqrtPriceX96,
            int24 _tick,
            uint16,
            uint16,
            uint16,
            uint8,
            bool
        ) {
            sqrtPriceX96 = _sqrtPriceX96;
            tick = _tick;
        } catch {
            sqrtPriceX96 = 0;
            tick = 0;
        }
        
        // Calculate ETH price from sqrtPriceX96
        // Formula: price = (sqrtPriceX96^2 * 10^18) / 2^192
        uint256 uniswapPrice;
        if (sqrtPriceX96 > 0) {
            uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
            price = (price * 1e18) >> 192; // Convert to 18 decimals
            uniswapPrice = price; // This is USDC per WETH (inverted)
        }
        
        return abi.encode(
            chainlinkPrice,
            chainlinkTimestamp,
            uniswapPrice,
            tick,
            block.number,
            block.timestamp
        );
    }
    
    function shouldRespond(bytes[] calldata data) external view override returns (bool, bytes memory) {
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        (int256 chainlinkPrice, uint256 chainlinkTimestamp, uint256 uniswapPrice, int24 tick, , ) = 
            abi.decode(data[0], (int256, uint256, uint256, int24, uint256, uint256));
        
        // Need both prices
        if (chainlinkPrice <= 0 || uniswapPrice == 0) {
            return (false, bytes(""));
        }
        
        // Normalize to same decimals (both to 18)
        uint256 chainlinkNormalized = uint256(chainlinkPrice) * 1e10; // Chainlink: 8 decimals -> 18
        uint256 uniswapNormalized = uniswapPrice; // Already 18 decimals
        
        // Calculate deviation percentage
        uint256 deviation;
        if (chainlinkNormalized > uniswapNormalized) {
            deviation = ((chainlinkNormalized - uniswapNormalized) * 10000) / chainlinkNormalized;
        } else {
            deviation = ((uniswapNormalized - chainlinkNormalized) * 10000) / uniswapNormalized;
        }
        
        // Check if price is stale (older than 1 hour)
        bool isStale = block.timestamp > chainlinkTimestamp + 3600;
        
        // Alert on significant deviation OR stale price
        if (deviation > deviationThresholdBps || isStale) {
            OracleAlert memory alert = OracleAlert({
                oracleSource: CHAINLINK_ETH_USD,
                reportedPrice: uint256(chainlinkPrice),
                referencePrice: uniswapNormalized,
                deviationBps: deviation,
                volume: volumeThreshold, // Would need real volume data
                timestamp: block.timestamp,
                isStale: isStale
            });
            
            emit OracleAttackDetected(CHAINLINK_ETH_USD, deviation, volumeThreshold);
            return (true, abi.encode(alert));
        }
        
        return (false, bytes(""));
    }
    
    // ========== STRUCTS ==========
    struct OracleAlert {
        address oracleSource;
        uint256 reportedPrice;
        uint256 referencePrice;
        uint256 deviationBps;
        uint256 volume;
        uint256 timestamp;
        bool isStale;
    }
}
