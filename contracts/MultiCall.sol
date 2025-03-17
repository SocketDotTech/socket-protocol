pragma solidity ^0.8.0;

contract MultiCall {
    function multiCall(address[] calldata targets, bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call(data[i]);
            if (!success) {
                // Forward the revert data exactly as received
                assembly {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
            results[i] = result;
        }
    }
}