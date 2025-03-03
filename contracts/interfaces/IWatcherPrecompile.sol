// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {PayloadDetails, AsyncRequest, FinalizeParams, PayloadDigestParams, AppGatewayConfig, PlugConfig, ResolvedPromises} from "../protocol/utils/common/Structs.sol";

/// @title IWatcherPrecompile
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompile {
    /// @notice Sets up app gateway configurations
    /// @param configs_ Array of app gateway configurations
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev Only callable by authorized addresses
    function setAppGateways(
        AppGatewayConfig[] calldata configs_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    /// @notice Sets up on-chain contract configurations
    /// @dev Only callable by authorized addresses
    function setOnChainContracts(
        uint32 chainSlug_,
        address socket_,
        address contractFactoryPlug_,
        address feesPlug_
    ) external;

    function setSwitchboard(uint32 chainSlug_, bytes32 sbType_, address switchboard_) external;

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
    /// @return digest The digest of the payload parameters
    function finalize(
        address originAppGateway_,
        FinalizeParams memory params_
    ) external returns (bytes32 payloadId, bytes32 digest);

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

    /// @notice Marks a request as finalized with a proof
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    function finalized(
        bytes32 payloadId_,
        bytes calldata proof_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    /// @notice Finalizes multiple payload execution requests with a new transmitter
    /// @param payloadId_ The unique identifier of the request
    /// @param params_ The parameters for finalization
    function refinalize(bytes32 payloadId_, FinalizeParams memory params_) external;

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    function resolvePromises(
        ResolvedPromises[] calldata resolvedPromises_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

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
    function resolveTimeout(
        bytes32 timeoutId_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    /// @notice Calculates the Digest hash for payload parameters
    /// @param params_ The payload parameters used to calculate the digest
    /// @return digest The calculated digest hash
    function getDigest(PayloadDigestParams memory params_) external pure returns (bytes32 digest);

    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external;

    function switchboards(uint32 chainSlug_, bytes32 sbType_) external view returns (address);

    function sockets(uint32 chainSlug_) external view returns (address);

    function contractFactoryPlug(uint32 chainSlug_) external view returns (address);

    function feesPlug(uint32 chainSlug_) external view returns (address);

    function setIsValidPlug(uint32 chainSlug_, address plug_, bool isValid_) external;

    function checkAndConsumeLimit(
        address appGateway_,
        bytes32 limitType_,
        uint256 consumeLimit_
    ) external;
}
