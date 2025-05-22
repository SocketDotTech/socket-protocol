// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IPrecompile.sol";
import "../../../utils/common/Structs.sol";
import {InvalidTarget, InvalidPayloadSize, InvalidScheduleDelay, InvalidTimeoutRequest, TimeoutAlreadyResolved, ResolvingTimeoutTooEarly, CallFailed} from "../../../utils/common/Errors.sol";
import "../WatcherBase.sol";

/// @title SchedulePrecompile
/// @notice Library that handles schedule logic for the WatcherPrecompile system
/// @dev This library contains pure functions for schedule operations
contract SchedulePrecompile is IPrecompile, WatcherBase {
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
    function setMaxScheduleDelayInSeconds(uint256 maxScheduleDelayInSeconds_) external onlyWatcher {
        maxScheduleDelayInSeconds = maxScheduleDelayInSeconds_;
        emit MaxScheduleDelayInSecondsSet(maxScheduleDelayInSeconds_);
    }

    /// @notice Sets the fees per second for a schedule
    /// @param scheduleFeesPerSecond_ The fees per second for a schedule
    /// @dev This function sets the fees per second for a schedule
    /// @dev Only callable by the contract owner
    function setScheduleFeesPerSecond(uint256 scheduleFeesPerSecond_) external onlyWatcher {
        scheduleFeesPerSecond = scheduleFeesPerSecond_;
        emit ScheduleFeesPerSecondSet(scheduleFeesPerSecond_);
    }

    /// @notice Sets the callback fees for a schedule
    /// @param scheduleCallbackFees_ The callback fees for a schedule
    /// @dev This function sets the callback fees for a schedule
    /// @dev Only callable by the contract owner
    function setScheduleCallbackFees(uint256 scheduleCallbackFees_) external onlyWatcher {
        scheduleCallbackFees = scheduleCallbackFees_;
        emit ScheduleCallbackFeesSet(scheduleCallbackFees_);
    }

    /// @notice Validates schedule parameters and return data with fees
    /// @dev assuming that tx is executed on EVMx chain
    function validateAndGetPrecompileData(
        QueueParams calldata queuePayloadParams_,
        address appGateway_
    ) external view returns (bytes memory precompileData, uint256 estimatedFees) {
        if (queuePayloadParams_.overrideParams.delayInSeconds > maxScheduleDelayInSeconds)
            revert InvalidScheduleDelay();

        // For schedule precompile, encode the payload parameters
        precompileData = abi.encode(queuePayloadParams_.overrideParams.delayInSeconds);
        estimatedFees =
            scheduleFeesPerSecond *
            queuePayloadParams_.overrideParams.delayInSeconds +
            scheduleCallbackFees;
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        address,
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees, uint256 deadline) {
        uint256 delayInSeconds = abi.decode(payloadParams.precompileData, (uint256));
        // expiryTime is very low, to account for infra delay
        deadline = block.timestamp + delayInSeconds + expiryTime;

        // emits event for watcher to track timeout and resolve when timeout is reached
        emit ScheduleRequested(payloadParams.payloadId, deadline);
    }

    function resolvePayload(PayloadParams calldata payloadParams_) external {
        if (block.timestamp < payloadParams_.deadline) revert ResolvingTimeoutTooEarly();

        emit ScheduleResolved(payloadParams_.payloadId);
    }
}
