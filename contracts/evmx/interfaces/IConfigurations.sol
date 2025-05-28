// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {AppGatewayConfig, PlugConfig} from "../../utils/common/Structs.sol";

/// @title IConfigurations
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IConfigurations {
    /// @notice Verifies connections between components
    function verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        bytes32 switchboardType_
    ) external view;

    /// @notice Maps app gateway, chain slug and plug to validity
    function isValidPlug(
        address appGateway,
        uint32 chainSlug,
        address plug
    ) external view returns (bool);

    /// @notice Retrieves the configuration for a specific plug on a network
    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) external view returns (bytes32, address);

    /// @notice Maps chain slug to their associated socket
    /// @param chainSlug_ The chain slug
    /// @return The socket
    function sockets(uint32 chainSlug_) external view returns (address);

    /// @notice Returns the socket for a given chain slug
    /// @param chainSlug_ The chain slug
    /// @return The socket
    function switchboards(uint32 chainSlug_, bytes32 sbType_) external view returns (address);

    /// @notice Sets the switchboard for a network
    function setSwitchboard(uint32 chainSlug_, bytes32 sbType_, address switchboard_) external;

    /// @notice Sets valid plugs for each chain slug
    /// @dev This function is used to verify if a plug deployed on a chain slug is valid connection to the app gateway
    function setIsValidPlug(bool isValid_, uint32 chainSlug_, address plug_) external;

    function setAppGatewayConfigs(AppGatewayConfig[] calldata configs_) external;

    /// @notice Sets the socket for a chain slug
    function setSocket(uint32 chainSlug_, address socket_) external;
}
