// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {CallType, Parallel, WriteFinality} from "../utils/common/Structs.sol";

library DumpDecoder {
    function getRequestCount(bytes32 dump_) internal pure returns (uint40) {
        return uint40(uint256(dump_) >> 224);
    }

    function getBatchCount(bytes32 dump_) internal pure returns (uint40) {
        return uint40((uint256(dump_) >> 184) & 0xFFFF);
    }

    function getPayloadCount(bytes32 dump_) internal pure returns (uint40) {
        return uint40((uint256(dump_) >> 144) & 0xFFFF);
    }

    function getChainSlug(bytes32 dump_) internal pure returns (uint32) {
        return uint32((uint256(dump_) >> 112) & 0xFFFF);
    }

    function getCallType(bytes32 dump_) internal pure returns (CallType) {
        return CallType((uint256(dump_) >> 80) & 0xFFFF);
    }

    function getIsParallel(bytes32 dump_) internal pure returns (Parallel) {
        return Parallel((uint256(dump_) >> 48) & 0xFFFF);
    }

    function getWriteFinality(bytes32 dump_) internal pure returns (WriteFinality) {
        return WriteFinality((uint256(dump_) >> 16) & 0xFFFF);
    }

    function getAsyncPromise(bytes32 dump_) internal pure returns (address) {
        return
            address(
                uint160(
                    uint256(dump_) & uint256(uint160(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF))
                )
            );
    }

    /// @notice Sets the request count in a dump
    /// @param dump_ The original dump value
    /// @param requestCount_ The request count to set
    /// @return bytes32 The updated dump value
    function setRequestCount(bytes32 dump_, uint40 requestCount_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(type(uint40).max) << 224)) |
                    (uint256(requestCount_) << 224)
            );
    }

    /// @notice Sets the batch count in a dump
    /// @param dump_ The original dump value
    /// @param batchCount_ The batch count to set
    /// @return bytes32 The updated dump value
    function setBatchCount(bytes32 dump_, uint40 batchCount_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(0xFFFF) << 184)) |
                    ((uint256(batchCount_) & 0xFFFF) << 184)
            );
    }

    /// @notice Sets the payload count in a dump
    /// @param dump_ The original dump value
    /// @param payloadCount_ The payload count to set
    /// @return bytes32 The updated dump value
    function setPayloadCount(bytes32 dump_, uint40 payloadCount_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(0xFFFF) << 144)) |
                    ((uint256(payloadCount_) & 0xFFFF) << 144)
            );
    }

    /// @notice Sets the chain slug in a dump
    /// @param dump_ The original dump value
    /// @param chainSlug_ The chain slug to set
    /// @return bytes32 The updated dump value
    function setChainSlug(bytes32 dump_, uint32 chainSlug_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(0xFFFF) << 112)) |
                    ((uint256(chainSlug_) & 0xFFFF) << 112)
            );
    }

    /// @notice Sets the call type in a dump
    /// @param dump_ The original dump value
    /// @param callType_ The call type to set
    /// @return bytes32 The updated dump value
    function setCallType(bytes32 dump_, CallType callType_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(0xFFFF) << 80)) |
                    ((uint256(uint8(callType_)) & 0xFFFF) << 80)
            );
    }

    /// @notice Sets the parallel flag in a dump
    /// @param dump_ The original dump value
    /// @param isParallel_ The parallel flag to set
    /// @return bytes32 The updated dump value
    function setIsParallel(bytes32 dump_, Parallel isParallel_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(0xFFFF) << 48)) |
                    ((uint256(uint8(isParallel_)) & 0xFFFF) << 48)
            );
    }

    /// @notice Sets the write finality in a dump
    /// @param dump_ The original dump value
    /// @param writeFinality_ The write finality to set
    /// @return bytes32 The updated dump value
    function setWriteFinality(
        bytes32 dump_,
        WriteFinality writeFinality_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~(uint256(0xFFFF) << 16)) |
                    ((uint256(uint8(writeFinality_)) & 0xFFFF) << 16)
            );
    }

    /// @notice Sets the async promise address in a dump
    /// @param dump_ The original dump value
    /// @param asyncPromise_ The async promise address to set
    /// @return bytes32 The updated dump value
    function setAsyncPromise(bytes32 dump_, address asyncPromise_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~uint256(uint160(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF))) |
                    uint256(uint160(asyncPromise_))
            );
    }

    /// @notice Creates a new dump with all fields set
    /// @param requestCount_ The request count
    /// @param batchCount_ The batch count
    /// @param payloadCount_ The payload count
    /// @param chainSlug_ The chain slug
    /// @param callType_ The call type
    /// @param isParallel_ The parallel flag
    /// @param writeFinality_ The write finality
    /// @param asyncPromise_ The async promise address
    /// @return bytes32 The newly created dump value
    function createDump(
        uint40 requestCount_,
        uint40 batchCount_,
        uint40 payloadCount_,
        uint32 chainSlug_,
        CallType callType_,
        Parallel isParallel_,
        WriteFinality writeFinality_,
        address asyncPromise_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(requestCount_) << 224) |
                    ((uint256(batchCount_) & 0xFFFF) << 184) |
                    ((uint256(payloadCount_) & 0xFFFF) << 144) |
                    ((uint256(chainSlug_) & 0xFFFF) << 112) |
                    ((uint256(uint8(callType_)) & 0xFFFF) << 80) |
                    ((uint256(uint8(isParallel_)) & 0xFFFF) << 48) |
                    ((uint256(uint8(writeFinality_)) & 0xFFFF) << 16) |
                    uint256(uint160(asyncPromise_))
            );
    }
}
