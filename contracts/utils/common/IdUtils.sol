// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

function encodeAppGatewayId(address appGateway_) pure returns (bytes32) {
    return bytes32(uint256(uint160(appGateway_)));
}

function decodeAppGatewayId(bytes32 appGatewayId_) pure returns (address) {
    return address(uint160(uint256(appGatewayId_)));
}

/// @notice Creates a payload ID from the given parameters
/// @param requestCount_ The request count
/// @param batchCount_ The batch count
/// @param payloadCount_ The payload count
/// @param switchboard_ The switchboard address
/// @param chainSlug_ The chain slug
/// @return The created payload ID
function createPayloadId(
    uint40 requestCount_,
    uint40 batchCount_,
    uint40 payloadCount_,
    address switchboard_,
    uint32 chainSlug_
) pure returns (bytes32) {
    return
        keccak256(abi.encode(requestCount_, batchCount_, payloadCount_, chainSlug_, switchboard_));
}
