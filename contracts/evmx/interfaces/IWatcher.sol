// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import {TriggerParams, ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, QueueParams, PayloadParams, RequestParams} from "../../utils/common/Structs.sol";
import {InvalidCallerTriggered, TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed, RequestAlreadyExecuted} from "../../utils/common/Errors.sol";

/// @title IWatcher
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcher {
    /// @notice Emitted when a new call is made to an app gateway
    /// @param triggerId The unique identifier for the trigger
    event CalledAppGateway(bytes32 triggerId);

    /// @notice Emitted when a call to an app gateway fails
    /// @param triggerId The unique identifier for the trigger
    event AppGatewayCallFailed(bytes32 triggerId);

    /// @notice Emitted when a proof upload request is made
    event WriteProofRequested(bytes32 digest, PayloadParams params);

    /// @notice Emitted when a proof is uploaded
    /// @param payloadId The unique identifier for the request
    /// @param proof The proof from the watcher
    event WriteProofUploaded(bytes32 indexed payloadId, bytes proof);

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
        bool hasWrite,
        uint40 requestCount,
        RequestParams requestParams,
        PayloadParams[] payloadParamsArray
    );

    event MaxTimeoutDelayInSecondsSet(uint256 maxTimeoutDelayInSeconds);

    event ExpiryTimeSet(uint256 expiryTime);

    event WatcherPrecompileLimitsSet(address watcherPrecompileLimits);

    event WatcherPrecompileConfigSet(address watcherPrecompileConfig);

    event RequestCancelledFromGateway(uint40 requestCount);

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
    error RequestNotProcessing();
    error InvalidLevelNumber();
    error DeadlineNotPassedForOnChainRevert();

    function queueSubmitStart(QueueParams calldata queuePayloadParams_) external;

    function queue(QueueParams calldata queuePayloadParams_) external;

    /// @notice Clears the temporary queue used to store payloads for a request
    function clearQueue() external;

    function submitRequest(
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes calldata onCompleteData
    ) external returns (uint40 requestCount);

    function assignTransmitter(uint40 requestCount, Bid memory bid_) external;

    // _processBatch();
    // prev digest hash create
    // create digest, deadline

    // handlePayload:
    // emit relevant events

    function _validateProcessBatch() external;

    function _settleRequest(uint40 requestCount) external;

    function markPayloadResolved(uint40 requestCount, RequestParams memory requestParams) external;

    // update RequestTrackingParams
    // if(_validateProcessBatch() == true) processBatch()

    /// @notice Increases the fees for a request
    /// @param requestCount_ The request id
    /// @param fees_ The new fees
    function increaseFees(uint40 requestCount_, uint256 fees_) external;

    function uploadProof(bytes32 payloadId_, bytes calldata proof_) external;

    function cancelRequest(uint40 requestCount) external;

    // settleFees on FM

    function getMaxFees(uint40 requestCount) external view returns (uint256);

    function getCurrentRequestCount() external view returns (uint40);

    function getRequestParams(uint40 requestCount) external view returns (RequestParams memory);
}
