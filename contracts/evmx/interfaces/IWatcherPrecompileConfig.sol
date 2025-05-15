// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {AppGatewayConfig, PlugConfig} from "../../utils/common/Structs.sol";

/// @title IWatcherPrecompileConfig
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompileConfig {
    /// @notice The chain slug of the watcher precompile
    function evmxSlug() external view returns (uint32);

    /// @notice Maps chain slug to their associated switchboard
    function switchboards(uint32 chainSlug, bytes32 sbType) external view returns (bytes32);

    /// @notice Maps chain slug to their associated socket
    function sockets(uint32 chainSlug) external view returns (bytes32);

    /// @notice Maps chain slug to their associated contract factory plug
    function contractFactoryPlug(uint32 chainSlug) external view returns (address);

    /// @notice Maps chain slug to their associated fees plug
    function feesPlug(uint32 chainSlug) external view returns (address);

    /// @notice Maps nonce to whether it has been used
    function isNonceUsed(uint256 nonce) external view returns (bool);

    /// @notice Maps app gateway, chain slug and plug to validity
    function isValidPlug(
        address appGateway,
        uint32 chainSlug,
        bytes32 plug
    ) external view returns (bool);

    /// @notice Sets the switchboard for a network
    function setSwitchboard(uint32 chainSlug_, bytes32 sbType_, bytes32 switchboard_) external;

    /// @notice Sets valid plugs for each chain slug
    /// @dev This function is used to verify if a plug deployed on a chain slug is valid connection to the app gateway
    function setIsValidPlug(uint32 chainSlug_, bytes32 plug_, bool isValid_) external;

    /// @notice Retrieves the configuration for a specific plug on a network
    function getPlugConfigs(
        uint32 chainSlug_,
        bytes32 plug_
    ) external view returns (bytes32, bytes32);

    /// @notice Verifies connections between components
    function verifyConnections(
        uint32 chainSlug_,
        bytes32 target_,
        address appGateway_,
        bytes32 switchboard_,
        address middleware_
    ) external view;

    function setAppGateways(
        AppGatewayConfig[] calldata configs_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;
}
