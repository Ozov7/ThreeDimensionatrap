// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    struct Log {
        bytes32[] topics;
        bytes data;
    }
    
    function collect() external view returns (bytes memory);
    function evaluateResponse(bytes[] calldata data) external view returns (bool, bytes memory);
}

abstract contract Trap is ITrap {
    function _addEventFilter(address, bytes32) internal virtual {}
    function getFilteredLogs() internal view virtual returns (Log[] memory) {
        return new Log[](0);
    }
}
