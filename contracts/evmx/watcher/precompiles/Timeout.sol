// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

/// @title Timeout
/// @notice Library that handles timeout logic for the WatcherPrecompile system
/// @dev This library contains pure functions for timeout operations
library Timeout {
    /// @notice Validates timeout parameters
    /// @param delayInSeconds_ The delay in seconds before the timeout executes
    /// @param maxTimeoutDelayInSeconds The maximum allowed timeout delay
    /// @return isValid Whether the timeout parameters are valid
    function validateTimeoutParams(
        uint256 delayInSeconds_,
        uint256 maxTimeoutDelayInSeconds
    ) public pure returns (bool isValid) {
        return delayInSeconds_ <= maxTimeoutDelayInSeconds;
    }

    /// @notice Encodes a unique timeout ID
    /// @param timeoutIdPrefix The prefix for timeout IDs
    /// @param counter The counter value to include in the ID
    /// @return timeoutId The encoded timeout ID
    function encodeTimeoutId(
        uint256 timeoutIdPrefix,
        uint256 counter
    ) public pure returns (bytes32 timeoutId) {
        // Encode timeout ID by bit-shifting and combining:
        // EVMx chainSlug (32 bits) | watcher precompile address (160 bits) | counter (64 bits)
        return bytes32(timeoutIdPrefix | counter);
    }

    /// @notice Prepares a timeout request
    /// @param target The target address for the timeout callback
    /// @param delayInSeconds_ The delay in seconds before the timeout executes
    /// @param executeAt The timestamp when the timeout should be executed
    /// @param payload_ The payload data to be executed after the timeout
    /// @return request The prepared timeout request
    function prepareTimeoutRequest(
        address target,
        uint256 delayInSeconds_,
        uint256 executeAt,
        bytes memory payload_
    ) public pure returns (TimeoutRequest memory request) {
        request.target = target;
        request.delayInSeconds = delayInSeconds_;
        request.executeAt = executeAt;
        request.payload = payload_;
        request.isResolved = false;
        request.executedAt = 0;
        return request;
    }

    /// @notice Validates timeout resolution conditions
    /// @param request The timeout request to validate
    /// @param currentTimestamp The current block timestamp
    /// @return isValid Whether the timeout can be resolved
    function validateTimeoutResolution(
        TimeoutRequest memory request,
        uint256 currentTimestamp
    ) public pure returns (bool isValid) {
        if (request.target == address(0)) return false;
        if (request.isResolved) return false;
        if (currentTimestamp < request.executeAt) return false;
        return true;
    }

    /// @notice Creates the event data for timeout request
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the timeout callback
    /// @param payload The payload data to be executed
    /// @param executeAt The timestamp when the timeout should be executed
    /// @return The encoded event data for timeout request
    function createTimeoutRequestEventData(
        bytes32 timeoutId,
        address target,
        bytes memory payload,
        uint256 executeAt
    ) public pure returns (bytes memory) {
        return abi.encode(timeoutId, target, payload, executeAt);
    }

    /// @notice Creates the event data for timeout resolution
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the timeout callback
    /// @param payload The payload data that was executed
    /// @param executedAt The timestamp when the timeout was executed
    /// @param returnData The return data from the timeout execution
    /// @return The encoded event data for timeout resolution
    function createTimeoutResolvedEventData(
        bytes32 timeoutId,
        address target,
        bytes memory payload,
        uint256 executedAt,
        bytes memory returnData
    ) public pure returns (bytes memory) {
        return abi.encode(timeoutId, target, payload, executedAt, returnData);
    }
}
