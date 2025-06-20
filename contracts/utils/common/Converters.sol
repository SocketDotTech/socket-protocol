// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.21;

error NotAnEvmAddress(bytes32 bytes32FormatAddress);

function toBytes32Format(address addr) pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
}

function fromBytes32Format(bytes32 bytes32FormatAddress) pure returns (address) {
    if (uint256(bytes32FormatAddress) >> 160 != 0) {
        revert NotAnEvmAddress(bytes32FormatAddress);
    }
    return address(uint160(uint256(bytes32FormatAddress)));
}
