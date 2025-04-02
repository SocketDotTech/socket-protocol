// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {CallType, Parallel, WriteFinality} from "../utils/common/Structs.sol";

library DumpDecoder {
    // Corrected mapping (most significant bits on the left):
    //  [256.....................................................................80][79.............................................0]
    //   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //    requestCount(40) | batchCount(40) | payloadCount(40) | chainSlug(32) | callType(8) | isParallel(8) | writeFinality(8)
    //
    // Bits:
    //   requestCount:  [216..255] (shift >> 216)
    //   batchCount:    [176..215] (shift >> 176, mask 0xFFFFFFFFFF)
    //   payloadCount:  [136..175]
    //   chainSlug:     [104..135]
    //   callType:      [96..103]
    //   isParallel:    [88..95]
    //   writeFinality: [80..87]

    // -------------------------------------------------------------------------
    // GETTERS
    // -------------------------------------------------------------------------
    function getRequestCount(bytes32 dump_) internal pure returns (uint40) {
        // Top 40 bits => shift right by 216
        return uint40(uint256(dump_) >> 216);
    }

    function getBatchCount(bytes32 dump_) internal pure returns (uint40) {
        return uint40((uint256(dump_) >> 176) & 0xFFFFFFFFFF);
    }

    function getPayloadCount(bytes32 dump_) internal pure returns (uint40) {
        return uint40((uint256(dump_) >> 136) & 0xFFFFFFFFFF);
    }

    function getChainSlug(bytes32 dump_) internal pure returns (uint32) {
        return uint32((uint256(dump_) >> 104) & 0xFFFFFFFF);
    }

    function getCallType(bytes32 dump_) internal pure returns (CallType) {
        return CallType(uint8((uint256(dump_) >> 96) & 0xFF));
    }

    function getIsParallel(bytes32 dump_) internal pure returns (Parallel) {
        return Parallel(uint8((uint256(dump_) >> 88) & 0xFF));
    }

    function getWriteFinality(bytes32 dump_) internal pure returns (WriteFinality) {
        return WriteFinality(uint8((uint256(dump_) >> 80) & 0xFF));
    }

    // -------------------------------------------------------------------------
    // SETTERS
    // -------------------------------------------------------------------------

    /// @notice Sets the request count in a dump (top 40 bits)
    function setRequestCount(bytes32 dump_, uint40 requestCount_) internal pure returns (bytes32) {
        // Clear bits [216..255], then OR in the new requestCount << 216
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFFFFFFFFFF)) << 216)) |
                    (uint256(requestCount_) << 216)
            );
    }

    /// @notice Sets the batch count in a dump [176..215]
    function setBatchCount(bytes32 dump_, uint40 batchCount_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFFFFFFFFFF)) << 176)) |
                    ((uint256(batchCount_) & 0xFFFFFFFFFF) << 176)
            );
    }

    /// @notice Sets the payload count [136..175]
    function setPayloadCount(bytes32 dump_, uint40 payloadCount_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFFFFFFFFFF)) << 136)) |
                    ((uint256(payloadCount_) & 0xFFFFFFFFFF) << 136)
            );
    }

    /// @notice Sets the chain slug [104..135]
    function setChainSlug(bytes32 dump_, uint32 chainSlug_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFFFFFFFF)) << 104)) |
                    ((uint256(chainSlug_) & 0xFFFFFFFF) << 104)
            );
    }

    /// @notice Sets the call type [96..103]
    function setCallType(bytes32 dump_, CallType callType_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFF)) << 96)) |
                    ((uint256(uint8(callType_)) & 0xFF) << 96)
            );
    }

    /// @notice Sets the parallel flag [88..95]
    function setIsParallel(bytes32 dump_, Parallel isParallel_) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFF)) << 88)) |
                    ((uint256(uint8(isParallel_)) & 0xFF) << 88)
            );
    }

    /// @notice Sets the write finality [80..87]
    function setWriteFinality(
        bytes32 dump_,
        WriteFinality writeFinality_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(dump_) & ~((uint256(0xFF)) << 80)) |
                    ((uint256(uint8(writeFinality_)) & 0xFF) << 80)
            );
    }

    // -------------------------------------------------------------------------
    // CREATE
    // -------------------------------------------------------------------------
    /// @notice Creates a new dump with all fields set
    function createDump(
        uint40 requestCount_,
        uint40 batchCount_,
        uint40 payloadCount_,
        uint32 chainSlug_,
        CallType callType_,
        Parallel isParallel_,
        WriteFinality writeFinality_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(requestCount_) << 216) |
                    ((uint256(batchCount_) & 0xFFFFFFFFFF) << 176) |
                    ((uint256(payloadCount_) & 0xFFFFFFFFFF) << 136) |
                    ((uint256(chainSlug_) & 0xFFFFFFFF) << 104) |
                    ((uint256(uint8(callType_)) & 0xFF) << 96) |
                    ((uint256(uint8(isParallel_)) & 0xFF) << 88) |
                    ((uint256(uint8(writeFinality_)) & 0xFF) << 80)
            );
    }
}
