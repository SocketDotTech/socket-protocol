// SPDX-License-Identifier: GPL-3.0-only
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
    function setDefaultLimitAndRatePerSecond(uint256 defaultLimit_) external;

    /// @notice Number of decimals used in limit calculations
    function limitDecimals() external view returns (uint256);

    /// @notice Default limit value for any app gateway
    function defaultLimit() external view returns (uint256);

    /// @notice Rate at which limit replenishes per second
    function defaultRatePerSecond() external view returns (uint256);

    /// @notice Consumes a limit for an app gateway
    /// @param appGateway_ The app gateway address
    /// @param limitType_ The type of limit to consume
    /// @param consumeLimit_ The amount of limit to consume
    function consumeLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) external;

    function getTotalFeesRequired(uint40 requestCount_) external view returns (uint256);

    function queryFees() external view returns (uint256);
    function finalizeFees() external view returns (uint256);
    function scheduleFees() external view returns (uint256);
    function callBackFees() external view returns (uint256);

    /// @notice Emitted when limit parameters are updated
    event LimitParamsUpdated(UpdateLimitParams[] updates);

    /// @notice Emitted when an app gateway is activated with default limits
    event AppGatewayActivated(address indexed appGateway, uint256 maxLimit, uint256 ratePerSecond);
}
