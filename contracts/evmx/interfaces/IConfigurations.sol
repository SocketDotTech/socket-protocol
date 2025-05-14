// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {AppGatewayConfig, PlugConfig} from "../../utils/common/Structs.sol";

/// @title IConfigurations
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IConfigurations {
    struct SocketConfig {
        address socket;
        address contractFactoryPlug;
        address feesPlug;
    }

    /// @notice Verifies connections between components
    function verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address switchboard_
    ) external view;

    /// @notice Maps contract address to their associated app gateway
    function getCoreAppGateway(address contractAddress) external view returns (address);

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
    function socketConfigs(uint32 chainSlug) external view returns (SocketConfig memory);

    /// @notice Sets the switchboard for a network
    function setSwitchboard(uint32 chainSlug_, bytes32 sbType_, address switchboard_) external;

    /// @notice Sets valid plugs for each chain slug
    /// @dev This function is used to verify if a plug deployed on a chain slug is valid connection to the app gateway
    function setIsValidPlug(bool isValid_, uint32 chainSlug_, address plug_) external;

    function setPlugConfigs(AppGatewayConfig[] calldata configs_) external;

    function setOnChainContracts(uint32 chainSlug_, SocketConfig memory socketConfig_) external;

    /// @notice Sets the core app gateway for the watcher precompile
    function setCoreAppGateway(address appGateway_) external;
}
