// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

abstract contract WatcherPrecompileUtils {
    function _encodeAppGatewayId(address appGateway_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(appGateway_)));
    }

    function _decodeAppGatewayId(bytes32 appGatewayId_) internal pure returns (address) {
        return address(uint160(uint256(appGatewayId_)));
    }
}
