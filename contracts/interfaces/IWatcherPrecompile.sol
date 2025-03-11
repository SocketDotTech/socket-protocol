// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {DigestParams, AppGatewayConfig, ResolvedPromises, PayloadParams} from "../protocol/utils/common/Structs.sol";

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

    /// @notice Sets the switchboard for a network
    /// @param chainSlug_ The identifier of the network
    /// @param switchboard_ The address of the switchboard  
    function setSwitchboard(
        uint32 chainSlug_,
        bytes32 sbType_,
        address switchboard_
    ) external;

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
    /// @param params_ The payload parameters
    /// @param transmitter_ The address of the transmitter
    /// @return payloadId The unique identifier for the finalized request   
    /// @return digest The digest of the payload parameters
    function finalize(
        PayloadParams memory params_,
        address transmitter_
    ) external returns (bytes32 payloadId, bytes32 digest);

    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    function query(
        PayloadParams memory params_
    ) external;

    /// @notice Marks a request as finalized with a proof
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    function finalized(
        bytes32 payloadId_,
        bytes calldata proof_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    function resolvePromises(
        ResolvedPromises[] calldata resolvedPromises_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    /// @notice Sets a timeout for payload execution
    /// @param appGateway_ app gateway address
    /// @param delayInSeconds_ The timeout duration in seconds
    /// @param payload_ The payload data
    function setTimeout(
        address appGateway_,
        uint256 delayInSeconds_,
        bytes calldata payload_
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
    function getDigest(DigestParams memory params_) external pure returns (bytes32 digest);

    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external;

    function switchboards(uint32 chainSlug_, bytes32 sbType_) external view returns (address);

    function sockets(uint32 chainSlug_) external view returns (address);

    function contractFactoryPlug(uint32 chainSlug_) external view returns (address);

    function feesPlug(uint32 chainSlug_) external view returns (address);

    function setIsValidPlug(uint32 chainSlug_, address plug_, bool isValid_) external;
}
