// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IPrecompile.sol";
import "../../../utils/common/Structs.sol";
import {InvalidScheduleDelay, ResolvingScheduleTooEarly} from "../../../utils/common/Errors.sol";
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
    /// @notice The expiry time for a schedule
    uint256 public expiryTime;

    /// @notice Emitted when the maximum schedule delay in seconds is set
    event MaxScheduleDelayInSecondsSet(uint256 maxScheduleDelayInSeconds_);
    /// @notice Emitted when the fees per second for a schedule is set
    event ScheduleFeesPerSecondSet(uint256 scheduleFeesPerSecond_);
    /// @notice Emitted when the callback fees for a schedule is set
    event ScheduleCallbackFeesSet(uint256 scheduleCallbackFees_);
    /// @notice Emitted when the expiry time for a schedule is set
    event ExpiryTimeSet(uint256 expiryTime_);
    /// @notice Emitted when a schedule is requested
    event ScheduleRequested(bytes32 payloadId, uint256 executeAfter, uint256 deadline);
    /// @notice Emitted when a schedule is resolved
    event ScheduleResolved(bytes32 payloadId);

    constructor(
        address watcher_,
        uint256 maxScheduleDelayInSeconds_,
        uint256 scheduleFeesPerSecond_,
        uint256 scheduleCallbackFees_,
        uint256 expiryTime_
    ) WatcherBase(watcher_) {
        maxScheduleDelayInSeconds = maxScheduleDelayInSeconds_;
        scheduleFeesPerSecond = scheduleFeesPerSecond_;
        scheduleCallbackFees = scheduleCallbackFees_;

        if (maxScheduleDelayInSeconds < expiryTime) revert InvalidScheduleDelay();
        expiryTime = expiryTime_;
    }

    function getPrecompileFees(bytes memory precompileData_) public view returns (uint256) {
        uint256 delayInSeconds = abi.decode(precompileData_, (uint256));
        return scheduleFeesPerSecond * delayInSeconds + scheduleCallbackFees;
    }

    /// @notice Sets the maximum schedule delay in seconds
    /// @param maxScheduleDelayInSeconds_ The maximum schedule delay in seconds
    /// @dev This function sets the maximum schedule delay in seconds
    /// @dev Only callable by the contract owner
    function setMaxScheduleDelayInSeconds(uint256 maxScheduleDelayInSeconds_) external onlyWatcher {
        if (maxScheduleDelayInSeconds < expiryTime) revert InvalidScheduleDelay();
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

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external onlyWatcher {
        if (maxScheduleDelayInSeconds < expiryTime) revert InvalidScheduleDelay();
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    /// @notice Validates schedule parameters and return data with fees
    /// @dev assuming that tx is executed on EVMx chain
    function validateAndGetPrecompileData(
        QueueParams calldata queueParams_,
        address
    ) external view returns (bytes memory precompileData, uint256 estimatedFees) {
        if (queueParams_.overrideParams.delayInSeconds > maxScheduleDelayInSeconds)
            revert InvalidScheduleDelay();

        // For schedule precompile, encode the payload parameters
        precompileData = abi.encode(queueParams_.overrideParams.delayInSeconds, 0);
        estimatedFees = getPrecompileFees(precompileData);
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        address,
        PayloadParams calldata payloadParams
    )
        external
        onlyRequestHandler
        returns (uint256 fees, uint256 deadline, bytes memory precompileData)
    {
        (uint256 delayInSeconds, ) = abi.decode(payloadParams.precompileData, (uint256, uint256));

        // expiryTime is very low, to account for infra delay
        uint256 executeAfter = block.timestamp + delayInSeconds;
        deadline = executeAfter + expiryTime;
        precompileData = abi.encode(delayInSeconds, executeAfter);
        fees = getPrecompileFees(precompileData);

        // emits event for watcher to track schedule and resolve when deadline is reached
        emit ScheduleRequested(payloadParams.payloadId, executeAfter, deadline);
    }

    function resolvePayload(PayloadParams calldata payloadParams_) external onlyRequestHandler {
        (, uint256 executeAfter) = abi.decode(payloadParams_.precompileData, (uint256, uint256));

        if (executeAfter > block.timestamp) revert ResolvingScheduleTooEarly();
        emit ScheduleResolved(payloadParams_.payloadId);
    }
}
