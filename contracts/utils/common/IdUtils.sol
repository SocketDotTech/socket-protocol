// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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
    bytes32 switchboard_,
    uint32 chainSlug_
) pure returns (bytes32) {
    return
        keccak256(
            abi.encodePacked(
                requestCount_,
                batchCount_,
                payloadCount_,
                chainSlug_,
                switchboard_
            )
        );
}
