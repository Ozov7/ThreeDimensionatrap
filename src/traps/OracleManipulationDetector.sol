// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "../interfaces/ITrap.sol";

contract OracleManipulationDetector is Trap {
    address public constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant UNISWAP_V3_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    
    uint256 public constant MAX_DEVIATION_BPS = 500;
    uint256 public constant MIN_VOLUME_ETH = 100 ether;
    
    bytes32 public constant ANSWER_UPDATED = 
        keccak256("AnswerUpdated(int256,uint256,uint256)");
    
    struct OracleAlert {
        address oracleSource;
        uint256 reportedPrice;
        uint256 referencePrice;
        uint256 deviationBps;
        uint256 volume;
        uint256 timestamp;
    }
    
    constructor() {
        _addEventFilter(CHAINLINK_ETH_USD, ANSWER_UPDATED);
    }
    
    function collect() external view override returns (bytes memory) {
        uint256 chainlinkPrice = 2500 * 1e8;
        uint256 uniswapPrice = 2550 * 1e18;
        
        return abi.encode(chainlinkPrice, uniswapPrice, block.number);
    }
    
    function evaluateResponse(
        bytes[] calldata data
    ) external view override returns (bool, bytes memory) {
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        (uint256 chainlinkPrice, uint256 uniswapPrice, ) = 
            abi.decode(data[0], (uint256, uint256, uint256));
        
        uint256 chainlinkNormalized = chainlinkPrice * 1e10;
        uint256 deviation;
        
        if (chainlinkNormalized > uniswapPrice) {
            deviation = ((chainlinkNormalized - uniswapPrice) * 10000) / chainlinkNormalized;
        } else {
            deviation = ((uniswapPrice - chainlinkNormalized) * 10000) / uniswapPrice;
        }
        
        if (deviation > MAX_DEVIATION_BPS) {
            OracleAlert memory alert = OracleAlert({
                oracleSource: CHAINLINK_ETH_USD,
                reportedPrice: chainlinkPrice,
                referencePrice: uniswapPrice,
                deviationBps: deviation,
                volume: 150 ether,
                timestamp: block.timestamp
            });
            
            return (true, abi.encode(alert));
        }
        
        return (false, bytes(""));
    }
}
