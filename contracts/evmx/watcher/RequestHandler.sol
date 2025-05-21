// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./WatcherBase.sol";
import "../../utils/common/Structs.sol";
import "../../utils/common/Errors.sol";
import "../../utils/common/Constants.sol";

import "../interfaces/IPrecompile.sol";

/// @title RequestHandler
/// @notice Contract that handles request processing and management
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
contract RequestHandler is WatcherBase {
    error InvalidPrecompileData();
    error InvalidCallType();

    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;

    /// @notice Counter for tracking request counts
    uint40 public nextRequestCount = 1;

    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    /// @notice Mapping to store the list of payload IDs for each batch
    mapping(uint40 => bytes32[]) public batchPayloadIds;

    /// @notice Mapping to store the batch IDs for each request
    mapping(uint40 => uint40[]) public requestBatchIds;

    /// @notice Mapping to store the precompiles for each call type
    mapping(bytes4 => IPrecompile) public precompiles;

    constructor(address watcherStorage_) WatcherBase(watcherStorage_) {}

    function setPrecompile(bytes4 callType_, IPrecompile precompile_) external onlyWatcherStorage {
        precompiles[callType_] = precompile_;
    }

    function submitRequest(
        uint256 maxFees_,
        address auctionManager_,
        address consumeFrom_,
        address appGateway_,
        QueueParams[] calldata queuePayloadParams_,
        bytes memory onCompleteData_
    ) external onlyWatcherPrecompile returns (uint40 requestCount, address[] memory promiseList) {
        if (queuePayloadParams_.length == 0) return uint40(0);
        if (queuePayloadParams.length > REQUEST_PAYLOAD_COUNT_LIMIT)
            revert RequestPayloadCountLimitExceeded();

        address appGateway = _getCoreAppGateway(appGateway_);
        if (!IFeesManager(feesManager__()).isUserCreditsEnough(consumeFrom_, appGateway, maxFees_))
            revert InsufficientFees();

        requestCount = nextRequestCount++;
        RequestParams memory r = RequestParams({
            requestTrackingParams: RequestTrackingParams({
                currentBatch: nextBatchCount,
                currentBatchPayloadsLeft: 0,
                payloadsRemaining: queuePayloadParams_.length
            }),
            requestFeesDetails: RequestFeesDetails({
                watcherFees: 0,
                consumeFrom: consumeFrom_,
                maxFees: maxFees_
            }),
            writeCount: 0,
            auctionManager: _getAuctionManager(auctionManager_),
            appGateway: appGateway,
            onCompleteData: onCompleteData_
        });

        (r.requestFeesDetails.watcherFees, r.writeCount, promiseList) = _createRequest(
            queuePayloadParams_,
            appGateway,
            requestCount
        );

        if (r.requestFeesDetails.watcherFees > maxFees_) revert InsufficientFees();
        watcherPrecompile__().setRequestParams(requestCount, r);

        if (r.writeCount == 0) startProcessingRequest();
        emit RequestSubmitted();
    }

    function _createRequest(
        QueueParams[] calldata queuePayloadParams_,
        address appGateway_,
        uint40 requestCount_
    )
        internal
        returns (uint256 totalWatcherFees, uint256 writeCount, address[] memory promiseList)
    {
        // push first batch count
        requestBatchIds[requestCount_].push(nextBatchCount);

        for (uint256 i = 0; i < queuePayloadParams.length; i++) {
            QueueParams calldata queuePayloadParam = queuePayloadParams_[i];
            bytes4 callType = queuePayloadParam.overrideParams.callType;

            // checks
            if (getCoreAppGateway(queuePayloadParam.appGateway) != appGateway_)
                revert InvalidAppGateway();

            if (callType == WRITE) writeCount++;

            // decide batch count
            if (i > 0 && queuePayloadParams[i].isParallel != Parallel.ON) {
                nextBatchCount++;
                requestBatchCounts[requestCount_].push(nextBatchCount);
            }

            // get the switchboard address from the watcher precompile config
            address switchboard = watcherPrecompileConfig().switchboards(
                queuePayloadParam.chainSlug,
                queuePayloadParam.switchboardType
            );

            // process payload data and store
            (uint256 fees, bytes memory precompileData) = _validateAndGetPrecompileData(
                queuePayloadParam,
                appGateway_,
                callType
            );
            totalWatcherFees += fees;

            // create payload id
            uint40 payloadCount = payloadCounter++;
            bytes32 payloadId = WatcherIdUtils.createPayloadId(
                requestCount_,
                batchCount,
                payloadCount,
                switchboard,
                queuePayloadParam.chainSlug
            );
            batchPayloadIds[batchCount].push(payloadId);

            // create prev digest hash
            PayloadSubmitParams memory p = PayloadSubmitParams({
                requestCount: requestCount_,
                batchCount: batchCount,
                payloadCount: payloadCount,
                payloadId: payloadId,
                prevDigestsHash: prevDigestsHash,
                precompileData: precompileData,
                asyncPromise: queuePayloadParams_.asyncPromise,
                appGateway: queuePayloadParams_.appGateway
            });
            promiseList.push(queuePayloadParams_.asyncPromise);
            watcherPrecompile__().setPayloadParams(payloadId, p);
        }

        nextBatchCount++;
    }

    function _validateAndGetPrecompileData(
        QueueParams calldata payloadParams_,
        address appGateway_,
        bytes4 callType_
    ) internal returns (uint256, bytes memory) {
        if (address(precompiles[callType_]) == address(0)) revert InvalidCallType();

        return
            IPrecompile(precompiles[callType_]).validateAndGetPrecompileData(
                payloadParams_,
                appGateway_
            );
    }

    function _getAuctionManager(address auctionManager_) internal view returns (address) {
        return
            auctionManager_ == address(0)
                ? addressResolver__().defaultAuctionManager()
                : auctionManager_;
    }

    //todo
    function _getPreviousDigestsHash(uint40 batchCount_) internal view returns (bytes32) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount_];
        bytes32 prevDigestsHash = bytes32(0);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            PayloadParams memory p = payloads[payloadIds[i]];
            DigestParams memory digestParams = DigestParams(
                watcherPrecompileConfig__.sockets(p.payloadHeader.getChainSlug()),
                p.finalizedTransmitter,
                p.payloadId,
                p.deadline,
                p.payloadHeader.getCallType(),
                p.gasLimit,
                p.value,
                p.payload,
                p.target,
                WatcherIdUtils.encodeAppGatewayId(p.appGateway),
                p.prevDigestsHash
            );
            prevDigestsHash = keccak256(abi.encodePacked(prevDigestsHash, getDigest(digestParams)));
        }
        return prevDigestsHash;
    }

    // /// @notice Increases the fees for a request if no bid is placed
    // /// @param requestCount_ The ID of the request
    // /// @param newMaxFees_ The new maximum fees
    // function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external override {
    //     address appGateway = _getCoreAppGateway(msg.sender);
    //     // todo: should we allow core app gateway too?
    //     if (appGateway != requests[requestCount_].appGateway) {
    //         revert OnlyAppGateway();
    //     }
    //     if (requests[requestCount_].winningBid.transmitter != address(0)) revert WinningBidExists();
    //     if (requests[requestCount_].maxFees >= newMaxFees_)
    //         revert NewMaxFeesLowerThanCurrent(requests[requestCount_].maxFees, newMaxFees_);
    //     requests[requestCount_].maxFees = newMaxFees_;
    //     emit FeesIncreased(appGateway, requestCount_, newMaxFees_);
    // }

    // /// @notice Updates the transmitter for a request
    // /// @param requestCount The request count to update
    // /// @param transmitter The new transmitter address
    // /// @dev This function updates the transmitter for a request
    // /// @dev It verifies that the caller is the middleware and that the request hasn't been started yet
    // function updateTransmitter(uint40 requestCount, address transmitter) public {
    //     RequestParams storage r = requestParams[requestCount];
    //     if (r.isRequestCancelled) revert RequestCancelled();
    //     if (r.payloadsRemaining == 0) revert RequestAlreadyExecuted();
    //     if (r.middleware != msg.sender) revert InvalidCaller();
    //     if (r.transmitter != address(0)) revert RequestNotProcessing();
    //     r.transmitter = transmitter;

    //     _processBatch(requestCount, r.currentBatch);
    // }

    // /// @notice Cancels a request
    // /// @param requestCount The request count to cancel
    // /// @dev This function cancels a request
    // /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    // function cancelRequest(uint40 requestCount) external {
    //     RequestParams storage r = requestParams[requestCount];
    //     if (r.isRequestCancelled) revert RequestAlreadyCancelled();
    //     if (r.middleware != msg.sender) revert InvalidCaller();

    //     r.isRequestCancelled = true;
    //     emit RequestCancelledFromGateway(requestCount);
    // }

    // /// @notice Ends the timeouts and calls the target address with the callback payload
    // /// @param timeoutId_ The unique identifier for the timeout
    // /// @param signatureNonce_ The nonce used in the watcher's signature
    // /// @param signature_ The watcher's signature
    // /// @dev It verifies if the signature is valid and the timeout hasn't been resolved yet
    // function resolveTimeout(
    //     bytes32 timeoutId_,
    //     uint256 signatureNonce_,
    //     bytes memory signature_
    // ) external {
    //     _isWatcherSignatureValid(
    //         abi.encode(this.resolveTimeout.selector, timeoutId_),
    //         signatureNonce_,
    //         signature_
    //     );

    //     TimeoutRequest storage timeoutRequest_ = timeoutRequests[timeoutId_];
    //     if (timeoutRequest_.target == address(0)) revert InvalidTimeoutRequest();
    //     if (timeoutRequest_.isResolved) revert TimeoutAlreadyResolved();
    //     if (block.timestamp < timeoutRequest_.executeAt) revert ResolvingTimeoutTooEarly();

    //     (bool success, , bytes memory returnData) = timeoutRequest_.target.tryCall(
    //         0,
    //         gasleft(),
    //         0, // setting max_copy_bytes to 0 as not using returnData right now
    //         timeoutRequest_.payload
    //     );
    //     if (!success) revert CallFailed();

    //     timeoutRequest_.isResolved = true;
    //     timeoutRequest_.executedAt = block.timestamp;

    //     emit TimeoutResolved(
    //         timeoutId_,
    //         timeoutRequest_.target,
    //         timeoutRequest_.payload,
    //         block.timestamp,
    //         returnData
    //     );
    // }
}
