// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {DigestParams, AppGatewayConfig, ResolvedPromises, PayloadParams, QueuePayloadParams, PayloadSubmitParams} from "../protocol/utils/common/Structs.sol";

/// @title IWatcherPrecompile
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompile {
    event CalledAppGateway(
        bytes32 callId,
        uint32 chainSlug,
        address plug,
        address appGateway,
        bytes32 params,
        bytes payload
    );

    /// @notice Emitted when a new query is requested
    event QueryRequested(PayloadParams params);

    /// @notice Emitted when a finalize request is made
    event FinalizeRequested(address transmitter, bytes32 digest, PayloadParams params);

    /// @notice Emitted when a request is finalized
    /// @param payloadId The unique identifier for the request
    /// @param proof The proof from the watcher
    event Finalized(bytes32 indexed payloadId, bytes proof);

    /// @notice Emitted when a promise is resolved
    /// @param payloadId The unique identifier for the resolved promise
    event PromiseResolved(bytes32 indexed payloadId, bool success, address asyncPromise);

    /// @notice Emitted when a promise is not resolved
    /// @param payloadId The unique identifier for the not resolved promise
    event PromiseNotResolved(bytes32 indexed payloadId, bool success, address asyncPromise);

    event TimeoutRequested(
        bytes32 timeoutId,
        address target,
        bytes payload,
        uint256 executeAt // Epoch time when the task should execute
    );

    /// @notice Emitted when a timeout is resolved
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the timeout
    /// @param payload The payload data
    /// @param executedAt The epoch time when the task was executed
    event TimeoutResolved(bytes32 timeoutId, address target, bytes payload, uint256 executedAt);

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
    /// @param params_ The payload parameters
    /// @param transmitter_ The address of the transmitter
    /// @return digest The digest of the payload parameters
    function finalize(
        PayloadParams memory params_,
        address transmitter_
    ) external returns (bytes32 digest);

    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    function query(PayloadParams memory params_) external;

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
    ) external returns (bytes32 timeoutId);

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

    function getCurrentRequestCount() external view returns (uint40);

    function submitRequest(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) external returns (uint40 requestCount);

    function startProcessingRequest(uint40 requestCount, address transmitter) external;

    function updateTransmitter(uint40 requestCount, address transmitter) external;

    function cancelRequest(uint40 requestCount) external;
}
