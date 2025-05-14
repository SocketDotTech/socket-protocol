// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IPrecompile.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

/// @title Schedule
/// @notice Library that handles schedule logic for the WatcherPrecompile system
/// @dev This library contains pure functions for schedule operations
contract Schedule is IPrecompile {
    // slot 52
    /// @notice The maximum delay for a schedule
    /// @dev Maximum schedule delay in seconds
    uint256 public maxScheduleDelayInSeconds;

    /// @notice The fees per second for a schedule
    uint256 public scheduleFeesPerSecond;
    /// @notice The callback fees for a schedule
    uint256 public scheduleCallbackFees;

    /// @notice Emitted when the maximum schedule delay in seconds is set
    event MaxScheduleDelayInSecondsSet(uint256 maxScheduleDelayInSeconds_);
    /// @notice Emitted when the fees per second for a schedule is set
    event ScheduleFeesPerSecondSet(uint256 scheduleFeesPerSecond_);
    /// @notice Emitted when the callback fees for a schedule is set
    event ScheduleCallbackFeesSet(uint256 scheduleCallbackFees_);

    /// @notice Sets the maximum schedule delay in seconds
    /// @param maxScheduleDelayInSeconds_ The maximum schedule delay in seconds
    /// @dev This function sets the maximum schedule delay in seconds
    /// @dev Only callable by the contract owner
    function setMaxScheduleDelayInSeconds(uint256 maxScheduleDelayInSeconds_) external onlyOwner {
        maxScheduleDelayInSeconds = maxScheduleDelayInSeconds_;
        emit MaxScheduleDelayInSecondsSet(maxScheduleDelayInSeconds_);
    }

    /// @notice Sets the fees per second for a schedule
    /// @param scheduleFeesPerSecond_ The fees per second for a schedule
    /// @dev This function sets the fees per second for a schedule
    /// @dev Only callable by the contract owner
    function setScheduleFeesPerSecond(uint256 scheduleFeesPerSecond_) external onlyOwner {
        scheduleFeesPerSecond = scheduleFeesPerSecond_;
        emit ScheduleFeesPerSecondSet(scheduleFeesPerSecond_);
    }

    /// @notice Sets the callback fees for a schedule
    /// @param scheduleCallbackFees_ The callback fees for a schedule
    /// @dev This function sets the callback fees for a schedule
    /// @dev Only callable by the contract owner
    function setScheduleCallbackFees(uint256 scheduleCallbackFees_) external onlyOwner {
        scheduleCallbackFees = scheduleCallbackFees_;
        emit ScheduleCallbackFeesSet(scheduleCallbackFees_);
    }

    /// @notice Validates schedule parameters and return data with fees
    /// @dev assuming that tx is executed on EVMx chain
    function validateAndGetPrecompileData(
        QueueParams calldata queuePayloadParams_,
        address appGateway_
    ) external view returns (bytes memory precompileData, uint256 fees) {
        if (
            queuePayloadParams_.transaction.target != address(0) &&
            appGateway_ != getCoreAppGateway(queuePayloadParams_.transaction.target)
        ) revert InvalidTarget();

        if (
            queuePayloadParams_.transaction.payload.length > 0 &&
            queuePayloadParams_.transaction.payload.length < PAYLOAD_SIZE_LIMIT
        ) {
            revert InvalidPayloadSize();
        }
        if (queuePayloadParams_.overrideParams.delayInSeconds > maxScheduleDelayInSeconds)
            revert InvalidScheduleDelay();

        // todo: how do we store tx data in promise and execute?

        // For schedule precompile, encode the payload parameters
        precompileData = abi.encode(
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams.delayInSeconds
        );

        fees =
            scheduleFeesPerSecond *
            queuePayloadParams_.overrideParams.delayInSeconds +
            scheduleCallbackFees;
    }

    // /// @notice Encodes a unique schedule ID
    // /// @param scheduleIdPrefix The prefix for schedule IDs
    // /// @param counter The counter value to include in the ID
    // /// @return scheduleId The encoded schedule ID
    // function encodeScheduleId(
    //     uint256 scheduleIdPrefix,
    //     uint256 counter
    // ) public pure returns (bytes32 scheduleId) {
    //     // Encode schedule ID by bit-shifting and combining:
    //     // EVMx chainSlug (32 bits) | watcher precompile address (160 bits) | counter (64 bits)
    //     return bytes32(scheduleIdPrefix | counter);
    // }

    /// @notice Prepares a schedule request
    /// @param target The target address for the schedule callback
    /// @param delayInSeconds_ The delay in seconds before the schedule executes
    /// @param executeAt The timestamp when the schedule should be executed
    /// @param payload_ The payload data to be executed after the schedule
    /// @return request The prepared schedule request
    function prepareScheduleRequest(
        address target,
        uint256 delayInSeconds_,
        uint256 executeAt,
        bytes memory payload_
    ) public pure returns (ScheduleRequest memory request) {
        request.target = target;
        request.delayInSeconds = delayInSeconds_;
        request.executeAt = executeAt;
        request.payload = payload_;
        request.isResolved = false;
        request.executedAt = 0;
        return request;
    }

    /// @notice Validates schedule resolution conditions
    /// @param request The schedule request to validate
    /// @param currentTimestamp The current block timestamp
    /// @return isValid Whether the schedule can be resolved
    function _validateScheduleResolution(
        ScheduleRequest memory request,
        uint256 currentTimestamp
    ) internal pure returns (bool isValid) {
        if (request.target == address(0)) return false;
        if (request.isResolved) return false;
        if (currentTimestamp < request.executeAt) return false;
        return true;
    }

    /// @notice Creates the event data for schedule request
    /// @param scheduleId The unique identifier for the schedule
    /// @param target The target address for the schedule callback
    /// @param payload The payload data to be executed
    /// @param executeAt The timestamp when the schedule should be executed
    /// @return The encoded event data for schedule request
    function createScheduleRequestEventData(
        bytes32 scheduleId,
        address target,
        bytes memory payload,
        uint256 executeAt
    ) public pure returns (bytes memory) {
        return abi.encode(scheduleId, target, payload, executeAt);
    }

    /// @notice Creates the event data for schedule resolution
    /// @param scheduleId The unique identifier for the schedule
    /// @param target The target address for the schedule callback
    /// @param payload The payload data that was executed
    /// @param executedAt The timestamp when the schedule was executed
    /// @param returnData The return data from the schedule execution
    /// @return The encoded event data for schedule resolution
    function createScheduleResolvedEventData(
        bytes32 scheduleId,
        address target,
        bytes memory payload,
        uint256 executedAt,
        bytes memory returnData
    ) public pure returns (bytes memory) {
        return abi.encode(scheduleId, target, payload, executedAt, returnData);
    }
}
