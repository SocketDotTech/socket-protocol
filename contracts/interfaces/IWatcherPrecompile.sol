// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {PayloadDetails, AsyncRequest, FinalizeParams, PayloadRootParams, AppGatewayConfig, PlugConfig, ResolvedPromises} from "../protocol/utils/common/Structs.sol";

/// @title IWatcherPrecompile
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompile {
    /// @notice Sets up app gateway configurations
    /// @param configs_ Array of app gateway configurations
    /// @dev Only callable by authorized addresses
    function setAppGateways(AppGatewayConfig[] calldata configs_) external;

    /// @notice Retrieves plug configuration for a specific network and plug
    /// @param chainSlug_ The identifier of the network
    /// @param plug_ The address of the plug
    /// @return appGateway The configured app gateway address
    /// @return switchboard The configured switchboard address
    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) external view returns (address appGateway, address switchboard);

    /// @notice Finalizes a payload execution request
    /// @param params_ Parameters needed for finalization
    /// @return payloadId The unique identifier for the request
    /// @return root The merkle root of the payload parameters
    function finalize(
        FinalizeParams memory params_,
        address originAppGateway_
    ) external returns (bytes32 payloadId, bytes32 root);

    /// @notice Creates a new query request
    /// @param chainSlug_ The identifier of the destination network
    /// @param targetAddress_ The address of the target contract
    /// @param asyncPromises_ Array of promise addresses to be resolved
    /// @param payload_ The query payload data
    /// @return payloadId The unique identifier for the query
    function query(
        uint32 chainSlug_,
        address targetAddress_,
        address appGateway_,
        address[] memory asyncPromises_,
        bytes memory payload_
    ) external returns (bytes32 payloadId);

    /// @notice Marks a request as finalized with a signature
    /// @param payloadId_ The unique identifier of the request
    /// @param signature_ The watcher's signature
    function finalized(bytes32 payloadId_, bytes calldata signature_) external;

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    function resolvePromises(ResolvedPromises[] calldata resolvedPromises_) external;

    /// @notice Sets a timeout for payload execution
    /// @param payload_ The payload data
    /// @param delayInSeconds_ The timeout duration in seconds
    function setTimeout(
        address appGateway_,
        bytes calldata payload_,
        uint256 delayInSeconds_
    ) external;

    /// @notice Resolves a timeout by executing the payload
    /// @param timeoutId_ The unique identifier for the timeout
    function resolveTimeout(bytes32 timeoutId_) external;

    /// @notice Calculates the root hash for payload parameters
    /// @param params_ The payload parameters used to calculate the root
    /// @return root The calculated merkle root hash
    function getRoot(PayloadRootParams memory params_) external pure returns (bytes32 root);

    /// @notice Gets the plug address for a given app gateway and chain
    /// @param appGateway_ The address of the app gateway contract
    /// @param chainSlug_ The identifier of the destination chain
    /// @return The plug address for the given app gateway and chain
    function appGatewayPlugs(
        address appGateway_,
        uint32 chainSlug_
    ) external view returns (address);

    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external;

    function switchboards(uint32 chainSlug_, bytes32 sbType_) external view returns (address);

    function setIsValidInboxCaller(uint32 chainSlug_, address plug_, bool isValid_) external;

    function checkAndUpdateLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) external;
}
