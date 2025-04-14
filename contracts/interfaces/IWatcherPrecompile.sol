// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {DigestParams, ResolvedPromises, PayloadParams, TriggerParams, PayloadSubmitParams, RequestParams} from "../protocol/utils/common/Structs.sol";
import {IWatcherPrecompileLimits} from "./IWatcherPrecompileLimits.sol";
import {IWatcherPrecompileConfig} from "./IWatcherPrecompileConfig.sol";

/// @title IWatcherPrecompile
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompile {
    /// @notice Emitted when a new call is made to an app gateway
    /// @param triggerId The unique identifier for the trigger
    event CalledAppGateway(bytes32 triggerId);

    /// @notice Emitted when a call to an app gateway fails
    /// @param triggerId The unique identifier for the trigger
    event AppGatewayCallFailed(bytes32 triggerId);

    /// @notice Emitted when a new query is requested
    event QueryRequested(PayloadParams params);

    /// @notice Emitted when a finalize request is made
    event FinalizeRequested(bytes32 digest, PayloadParams params);

    /// @notice Emitted when a request is finalized
    /// @param payloadId The unique identifier for the request
    /// @param proof The proof from the watcher
    event Finalized(bytes32 indexed payloadId, bytes proof);

    /// @notice Emitted when a promise is resolved
    /// @param payloadId The unique identifier for the resolved promise
    event PromiseResolved(bytes32 indexed payloadId, address asyncPromise);

    /// @notice Emitted when a promise is not resolved
    /// @param payloadId The unique identifier for the not resolved promise
    event PromiseNotResolved(bytes32 indexed payloadId, address asyncPromise);

    /// @notice Emitted when a payload is marked as revert
    /// @param payloadId The unique identifier for the payload
    /// @param isRevertingOnchain Whether the payload is reverting onchain
    event MarkedRevert(bytes32 indexed payloadId, bool isRevertingOnchain);

    /// @notice Emitted when a timeout is requested
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the timeout callback
    /// @param payload The payload data
    /// @param executeAt The epoch time when the task should execute
    event TimeoutRequested(bytes32 timeoutId, address target, bytes payload, uint256 executeAt);

    /// @notice Emitted when a timeout is resolved
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the callback
    /// @param payload The payload data
    /// @param executedAt The epoch time when the task was executed
    /// @param returnData The return data from the callback
    event TimeoutResolved(
        bytes32 timeoutId,
        address target,
        bytes payload,
        uint256 executedAt,
        bytes returnData
    );

    event RequestSubmitted(
        address middleware,
        uint40 requestCount,
        PayloadParams[] payloadParamsArray
    );

    event MaxTimeoutDelayInSecondsSet(uint256 maxTimeoutDelayInSeconds);

    event ExpiryTimeSet(uint256 expiryTime);

    /// @notice Error thrown when an invalid chain slug is provided
    error InvalidChainSlug();
    /// @notice Error thrown when an invalid app gateway reaches a plug
    error InvalidConnection();
    /// @notice Error thrown when a timeout request is invalid
    error InvalidTimeoutRequest();
    /// @notice Error thrown when a payload id is invalid
    error InvalidPayloadId();
    /// @notice Error thrown when a caller is invalid
    error InvalidCaller();
    /// @notice Error thrown when a gateway is invalid
    error InvalidGateway();
    /// @notice Error thrown when a switchboard is invalid
    error InvalidSwitchboard();
    /// @notice Error thrown when a request is already cancelled
    error RequestAlreadyCancelled();

    error RequestCancelled();
    error AlreadyStarted();
    error InvalidLevelNumber();
    error DeadlineNotPassedForOnChainRevert();
    /// @notice Calculates the digest hash of payload parameters
    /// @param params_ The payload parameters
    /// @return digest The calculated digest
    function getDigest(DigestParams memory params_) external pure returns (bytes32 digest);

    /// @notice Gets the batch IDs for a request
    /// @param requestCount_ The request count
    /// @return Array of batch IDs
    function getBatches(uint40 requestCount_) external view returns (uint40[] memory);

    /// @notice Gets the payload IDs for a batch
    /// @param batchCount_ The batch count
    /// @return Array of payload IDs
    function getBatchPayloadIds(uint40 batchCount_) external view returns (bytes32[] memory);

    /// @notice Gets the payload parameters for a payload ID
    /// @param payloadId_ The payload ID
    /// @return The payload parameters
    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory);

    function setTimeout(
        uint256 delayInSeconds_,
        bytes calldata payload_
    ) external returns (bytes32);

    function resolveTimeout(
        bytes32 timeoutId_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function finalize(
        PayloadParams memory params_,
        address transmitter_
    ) external returns (bytes32 digest);

    function query(PayloadParams memory params_) external;

    function finalized(
        bytes32 payloadId_,
        bytes calldata proof_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function updateTransmitter(uint40 requestCount, address transmitter) external;

    function cancelRequest(uint40 requestCount) external;

    function resolvePromises(
        ResolvedPromises[] calldata resolvedPromises_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function markRevert(
        bool isRevertingOnchain_,
        bytes32 payloadId_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external;

    function callAppGateways(
        TriggerParams[] calldata params_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function setExpiryTime(uint256 expiryTime_) external;

    function submitRequest(
        PayloadSubmitParams[] calldata payloadSubmitParams
    ) external returns (uint40 requestCount);

    function startProcessingRequest(uint40 requestCount, address transmitter) external;

    function getCurrentRequestCount() external view returns (uint40);

    function watcherPrecompileConfig__() external view returns (IWatcherPrecompileConfig);

    function watcherPrecompileLimits__() external view returns (IWatcherPrecompileLimits);

    function getRequestParams(uint40 requestCount) external view returns (RequestParams memory);

    function nextRequestCount() external view returns (uint40);
}
