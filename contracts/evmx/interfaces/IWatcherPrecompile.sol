// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {DigestParams, ResolvedPromises, PayloadParams, TriggerParams, PayloadSubmitParams, RequestParams} from "../../utils/common/Structs.sol";

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

    QueueParams[] queuePayloadParams;

    function queueSubmitStart(QueueParams calldata queuePayloadParams_) external;

    // queue:
    function queue(QueueParams calldata queuePayloadParams_) external;
    // push in queue

    // validateAndGetPrecompileData:
    // finalize: verifyConnection, max msg gas limit is under limit, 
    // timeout: max delay 
    // query: 
    // return encoded data and fees
    
    /// @notice Clears the temporary queue used to store payloads for a request
    function clearQueueAndPrecompileFees() external;

    function submitRequest(address auctionManager, bytes onCompleteData) external returns (uint40 requestCount);
    // {
    //     (params.precompileData, fees) = IPrecompile.getPrecompileData(queuePayloadParams_);
    // }
    // precompileFees += fees
    // if coreAppGateway is not set, set it else check if it is the same
    // decide level
    // create id and assign counts
    // store payload struct

    // set default AM if addr(0)
    // total fees check from maxFees
    // verify if msg sender have same core app gateway
    // create and store req param
    // if writeCount == 0, startProcessing else wait

    function assignTransmitter(uint40 requestCount, Bid memory bid_) external;
    // validate AM from req param
    // update transmitter
    // assignTransmitter
    // - block for new transmitter
    // refinalize payloads for new transmitter
    // 0 => non zero 
    // non zero => non zero
    // - unblock credits from prev transmitter
    // non zero => 0
    // - just unblock credits and return
    // if(_validateProcessBatch() == true) processBatch()

    // _processBatch();
    // if a batch is already processed or in process, reprocess it for new transmitter
    // deduct fee with precompile call (IPrecompile.handlePayload(payloadParams) returns fees)
    // prev digest hash create

    // handlePayload:
    // create digest, deadline
    // emit relevant events

    function _validateProcessBatch() external;
    // if request is cancelled, return
    // check if all payloads from last batch are executed, else return;
    // check if all payloads are executed, if yes call _settleRequest

    function _settleRequest(uint40 requestCount) external;
    // if yes, call settleFees on FM and call onCompleteData in App gateway, if not success emit DataNotExecuted()

    function markPayloadResolved(uint40 requestCount, RequestParams memory requestParams) external;
    // update RequestTrackingParams
    // if(_validateProcessBatch() == true) processBatch()


    /// @notice Increases the fees for a request
    /// @param requestCount_ The request id
    /// @param fees_ The new fees
    function increaseFees(uint40 requestCount_, uint256 fees_) external;

    function finalized(
        bytes32 payloadId_,
        bytes calldata proof_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external;

    function cancelRequest(uint40 requestCount) external;
    // settleFees on FM

    function getMaxFees(uint40 requestCount) external view returns (uint256);

    function getCurrentRequestCount() external view returns (uint40);

    function nextRequestCount() external view returns (uint40);
}
