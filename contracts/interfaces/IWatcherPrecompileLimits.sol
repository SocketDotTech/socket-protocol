// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {LimitParams, UpdateLimitParams} from "../protocol/utils/common/Structs.sol";

/// @title IWatcherPrecompileLimits
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompileLimits {
    /// @notice Get the current limit for a specific app gateway and limit type
    /// @param limitType_ The type of limit to query
    /// @param appGateway_ The app gateway address
    /// @return The current limit value
    function getCurrentLimit(
        bytes32 limitType_,
        address appGateway_
    ) external view returns (uint256);

    /// @notice Get the limit parameters for a specific app gateway and limit type
    /// @param limitType_ The type of limit to query
    /// @param appGateway_ The app gateway address
    /// @return The limit parameters
    function getLimitParams(
        bytes32 limitType_,
        address appGateway_
    ) external view returns (LimitParams memory);

    /// @notice Update limit parameters for multiple app gateways
    /// @param updates_ Array of limit parameter updates
    function updateLimitParams(UpdateLimitParams[] calldata updates_) external;

    /// @notice Set the default limit value
    /// @param defaultLimit_ The new default limit value
    function setDefaultLimit(uint256 defaultLimit_) external;

    /// @notice Set the rate at which limit replenishes
    /// @param defaultRatePerSecond_ The new rate per second
    function setDefaultRatePerSecond(uint256 defaultRatePerSecond_) external;

    /// @notice Number of decimals used in limit calculations
    function limitDecimals() external view returns (uint256);

    /// @notice Default limit value for any app gateway
    function defaultLimit() external view returns (uint256);

    /// @notice Rate at which limit replenishes per second
    function defaultRatePerSecond() external view returns (uint256);

    function consumeLimit(address appGateway_, bytes32 limitType_, uint256 consumeLimit_) external;

    /// @notice Emitted when limit parameters are updated
    event LimitParamsUpdated(UpdateLimitParams[] updates);

    /// @notice Emitted when an app gateway is activated with default limits
    event AppGatewayActivated(address indexed appGateway, uint256 maxLimit, uint256 ratePerSecond);

    error ActionNotSupported(address appGateway_, bytes32 limitType_);
    error NotDeliveryHelper();
    error LimitExceeded(
        address appGateway,
        bytes32 limitType,
        uint256 requested,
        uint256 available
    );
}
