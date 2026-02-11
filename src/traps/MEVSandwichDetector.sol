// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Trap} from "../interfaces/ITrap.sol";

contract MEVSandwichDetector is Trap {
    address public constant UNISWAP_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    uint256 public constant MIN_PRICE_IMPACT_BPS = 50;
    uint256 public constant MIN_PROFIT_ETH = 0.1 ether;
    
    bytes32 public constant SWAP_TOPIC = 
        keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)");
    
    struct SwapData {
        address sender;
        int256 amount0;
        int256 amount1;
        uint256 blockNumber;
        uint256 timestamp;
        bool isExactInput;
    }
    
    struct MEVAlert {
        address victim;
        address attacker;
        uint256 profitEstimate;
        uint256 priceImpact;
        uint256 blockNumber;
    }
    
    constructor() {
        _addEventFilter(UNISWAP_POOL, SWAP_TOPIC);
    }
    
    function collect() external view override returns (bytes memory) {
        Trap.Log[] memory logs = getFilteredLogs();
        SwapData[] memory swaps = new SwapData[](logs.length);
        
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] != SWAP_TOPIC || logs[i].topics.length < 7) continue;
            
            (, int256 amount0, int256 amount1, , , , ) = abi.decode(
                logs[i].data,
                (address, int256, int256, uint160, uint128, int24, address)
            );
            
            address sender = address(uint160(uint256(logs[i].topics[6])));
            
            swaps[i] = SwapData({
                sender: sender,
                amount0: amount0,
                amount1: amount1,
                blockNumber: block.number,
                timestamp: block.timestamp,
                isExactInput: amount0 > 0
            });
        }
        
        return abi.encode(swaps);
    }
    
    function evaluateResponse(
        bytes[] calldata data
    ) external view override returns (bool, bytes memory) {
        if (data.length < 1 || data[0].length == 0) {
            return (false, bytes(""));
        }
        
        SwapData[] memory swaps = abi.decode(data[0], (SwapData[]));
        
        if (swaps.length < 3) return (false, bytes(""));
        
        uint256 uniqueSenders = 0;
        address[] memory seenSenders = new address[](swaps.length);
        
        for (uint256 i = 0; i < swaps.length; i++) {
            bool isNew = true;
            for (uint256 j = 0; j < uniqueSenders; j++) {
                if (seenSenders[j] == swaps[i].sender) {
                    isNew = false;
                    break;
                }
            }
            if (isNew) {
                seenSenders[uniqueSenders] = swaps[i].sender;
                uniqueSenders++;
            }
        }
        
        if (uniqueSenders >= 2 && swaps[0].blockNumber == swaps[swaps.length - 1].blockNumber) {
            MEVAlert memory alert = MEVAlert({
                victim: swaps[1].sender,
                attacker: swaps[0].sender,
                profitEstimate: 0.15 ether,
                priceImpact: 75,
                blockNumber: swaps[0].blockNumber
            });
            
            return (true, abi.encode(alert));
        }
        
        return (false, bytes(""));
    }
}
