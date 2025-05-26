// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../helpers/AddressResolverUtil.sol";
import "../../utils/common/Errors.sol";
import "../../utils/common/Constants.sol";
import "../../utils/common/IdUtils.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";

/// @title RequestHandler
/// @notice Contract that handles request processing and management, including request submission, batch processing, and request lifecycle management
/// @dev Handles request submission, batch processing, transmitter assignment, request cancellation and settlement
/// @dev This contract interacts with the WatcherPrecompileStorage for storage access
contract RequestHandler is AddressResolverUtil {
    /// @notice Counter for tracking request counts
    uint40 public nextRequestCount = 1;

    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;

    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    /// @notice Mapping to store the list of payload IDs for each batch
    mapping(uint40 => bytes32[]) public batchPayloadIds;

    /// @notice Mapping to store the batch IDs for each request
    mapping(uint40 => uint40[]) public requestBatchIds;

    /// @notice Mapping to store the precompiles for each call type
    mapping(bytes4 => IPrecompile) public precompiles;

    // queue => update to payloadParams, assign id, store in payloadParams map
    /// @notice Mapping to store the payload parameters for each payload ID
    mapping(bytes32 => PayloadParams) public payloads;

    /// @notice The metadata for a request
    mapping(uint40 => RequestParams) public requests;
    struct CreateRequestResult {
        uint256 totalEstimatedWatcherFees;
        uint256 writeCount;
        address[] promiseList;
        PayloadParams[] payloadParams;
    }

    event RequestSubmitted(
        bool hasWrite,
        uint40 requestCount,
        uint256 totalEstimatedWatcherFees,
        RequestParams requestParams,
        PayloadParams[] payloadParamsArray
    );

    event FeesIncreased(uint40 requestCount, uint256 newMaxFees);
    event RequestSettled(uint40 requestCount, address winner);
    event RequestCompletedWithErrors(uint40 requestCount);
    event RequestCancelled(uint40 requestCount);

    modifier isRequestCancelled(uint40 requestCount_) {
        if (requests[requestCount_].requestTrackingParams.isRequestCancelled)
            revert RequestAlreadyCancelled();
        _;
    }

    modifier onlyPromiseResolver() {
        if (msg.sender != address(watcher__().promiseResolver__())) revert NotPromiseResolver();
        _;
    }

    // constructor(address watcherStorage_) WatcherBase(watcherStorage_) {}

    function setPrecompile(bytes4 callType_, IPrecompile precompile_) external onlyWatcher {
        precompiles[callType_] = precompile_;
    }

    function submitRequest(
        uint256 maxFees_,
        address auctionManager_,
        address consumeFrom_,
        address appGateway_,
        QueueParams[] calldata queueParams_,
        bytes memory onCompleteData_
    ) external onlyWatcher returns (uint40 requestCount, address[] memory promiseList) {
        if (queueParams_.length == 0) return (0, new address[](0));
        if (queueParams_.length > REQUEST_PAYLOAD_COUNT_LIMIT)
            revert RequestPayloadCountLimitExceeded();

        if (!feesManager__().isCreditSpendable(consumeFrom_, appGateway_, maxFees_))
            revert InsufficientFees();

        requestCount = nextRequestCount++;
        RequestParams storage r = requests[requestCount];
        r.requestTrackingParams.currentBatch = nextBatchCount;
        r.requestTrackingParams.payloadsRemaining = queueParams_.length;
        r.requestFeesDetails.maxFees = maxFees_;
        r.requestFeesDetails.consumeFrom = consumeFrom_;
        r.auctionManager = _getAuctionManager(auctionManager_);
        r.appGateway = appGateway_;
        r.onCompleteData = onCompleteData_;

        CreateRequestResult memory result = _createRequest(queueParams_, appGateway_, requestCount);
        r.writeCount = result.writeCount;
        promiseList = result.promiseList;
        if (result.totalEstimatedWatcherFees > maxFees_) revert InsufficientFees();
        if (r.writeCount == 0) _processBatch(r.requestTrackingParams.currentBatch, r);

        emit RequestSubmitted(
            r.writeCount > 0,
            requestCount,
            result.totalEstimatedWatcherFees,
            r,
            result.payloadParams
        );
    }

    // called by auction manager when a auction ends or a new transmitter is assigned (bid expiry)
    function assignTransmitter(
        uint40 requestCount_,
        Bid memory bid_
    ) external isRequestCancelled(requestCount_) {
        RequestParams storage r = requests[requestCount_];
        if (r.auctionManager != msg.sender) revert InvalidCaller();
        if (r.requestTrackingParams.isRequestExecuted) revert RequestAlreadySettled();

        if (r.writeCount == 0) revert NoWriteRequest();

        // If same transmitter is reassigned, revert
        if (r.requestFeesDetails.winningBid.transmitter == bid_.transmitter)
            revert AlreadyAssigned();

        // If a transmitter was already assigned previously, unblock the credits
        if (r.requestFeesDetails.winningBid.transmitter != address(0)) {
            feesManager__().unblockCredits(requestCount_);
        }

        r.requestFeesDetails.winningBid = bid_;

        // If a transmitter changed to address(0), return after unblocking the credits
        if (bid_.transmitter == address(0)) return;

        // Block the credits for the new transmitter
        feesManager__().blockCredits(requestCount_, r.requestFeesDetails.consumeFrom, bid_.fee);

        // re-process current batch again or process the batch for the first time
        _processBatch(r.requestTrackingParams.currentBatch, r);
    }

    function _createRequest(
        QueueParams[] calldata queueParams_,
        address appGateway_,
        uint40 requestCount_
    ) internal returns (CreateRequestResult memory result) {
        // push first batch count
        requestBatchIds[requestCount_].push(nextBatchCount);

        result.promiseList = new address[](queueParams_.length);
        result.payloadParams = new PayloadParams[](queueParams_.length);
        for (uint256 i = 0; i < queueParams_.length; i++) {
            QueueParams calldata queuePayloadParam = queueParams_[i];
            bytes4 callType = queuePayloadParam.overrideParams.callType;
            if (callType == WRITE) result.writeCount++;

            // decide batch count
            if (i > 0 && queueParams_[i].overrideParams.isParallelCall != Parallel.ON) {
                nextBatchCount++;
                requestBatchIds[requestCount_].push(nextBatchCount);
            }

            // get the switchboard address from the watcher precompile config
            address switchboard = watcher__().configurations__().sockets(
                queuePayloadParam.transaction.chainSlug
            );

            // process payload data and store
            (bytes memory precompileData, uint256 estimatedFees) = _validateAndGetPrecompileData(
                queuePayloadParam,
                appGateway_,
                callType
            );
            result.totalEstimatedWatcherFees += estimatedFees;

            // create payload id
            uint40 payloadCount = payloadCounter++;
            bytes32 payloadId = createPayloadId(
                requestCount_,
                nextBatchCount,
                payloadCount,
                switchboard,
                queuePayloadParam.transaction.chainSlug
            );
            batchPayloadIds[nextBatchCount].push(payloadId);

            // create prev digest hash
            PayloadParams memory p = PayloadParams({
                requestCount: requestCount_,
                batchCount: nextBatchCount,
                payloadCount: payloadCount,
                callType: callType,
                asyncPromise: queueParams_[i].asyncPromise,
                appGateway: appGateway_,
                payloadId: payloadId,
                resolvedAt: 0,
                deadline: 0,
                precompileData: precompileData
            });
            result.promiseList[i] = queueParams_[i].asyncPromise;
            result.payloadParams[i] = p;
            payloads[payloadId] = p;
        }

        nextBatchCount++;
    }

    function _validateAndGetPrecompileData(
        QueueParams calldata payloadParams_,
        address appGateway_,
        bytes4 callType_
    ) internal view returns (bytes memory precompileData, uint256 estimatedFees) {
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
                ? addressResolver__.defaultAuctionManager()
                : auctionManager_;
    }

    function _processBatch(uint40 batchCount_, RequestParams storage r) internal {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount_];

        uint256 totalFees = 0;
        for (uint40 i = 0; i < payloadIds.length; i++) {
            bytes32 payloadId = payloadIds[i];

            // check needed for re-process, in case a payload is already executed by last transmitter
            if (!_isPromiseResolved(payloads[payloadId].asyncPromise)) continue;
            PayloadParams storage payloadParams = payloads[payloadId];

            (uint256 fees, uint256 deadline) = IPrecompile(precompiles[payloadParams.callType])
                .handlePayload(r.requestFeesDetails.winningBid.transmitter, payloadParams);
            totalFees += fees;
            payloadParams.deadline = deadline;
        }

        address watcherFeesPayer = r.requestFeesDetails.winningBid.transmitter == address(0)
            ? r.requestFeesDetails.consumeFrom
            : r.requestFeesDetails.winningBid.transmitter;
        feesManager__().transferCredits(watcherFeesPayer, address(this), totalFees);
    }

    /// @notice Increases the fees for a request if no bid is placed
    /// @param requestCount_ The ID of the request
    /// @param newMaxFees_ The new maximum fees
    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external {
        RequestParams storage r = requests[requestCount_];
        address appGateway = getCoreAppGateway(msg.sender);

        if (r.requestTrackingParams.isRequestCancelled) revert RequestAlreadyCancelled();
        if (r.requestTrackingParams.isRequestExecuted) revert RequestAlreadySettled();

        if (appGateway != r.appGateway) revert OnlyAppGateway();
        if (r.requestFeesDetails.maxFees >= newMaxFees_)
            revert NewMaxFeesLowerThanCurrent(r.requestFeesDetails.maxFees, newMaxFees_);
        if (
            !IFeesManager(feesManager__()).isCreditSpendable(
                r.requestFeesDetails.consumeFrom,
                appGateway,
                newMaxFees_
            )
        ) revert InsufficientFees();

        r.requestFeesDetails.maxFees = newMaxFees_;

        // indexed by transmitter and watcher to start bidding or re-processing the request
        emit FeesIncreased(requestCount_, newMaxFees_);
    }

    function updateRequestAndProcessBatch(
        uint40 requestCount_,
        bytes32 payloadId_
    ) external onlyPromiseResolver isRequestCancelled(requestCount_) {
        RequestParams storage r = requests[requestCount_];

        PayloadParams storage payloadParams = payloads[payloadId_];
        IPrecompile(precompiles[payloadParams.callType]).resolvePayload(payloadParams);

        payloadParams.resolvedAt = block.timestamp;

        if (r.requestTrackingParams.currentBatchPayloadsLeft != 0) return;
        if (r.requestTrackingParams.payloadsRemaining == 0) {
            r.requestTrackingParams.isRequestExecuted = true;
            _settleRequest(requestCount_, r);
        } else {
            r.requestTrackingParams.currentBatch++;
            _processBatch(r.requestTrackingParams.currentBatch, r);
        }
    }

    function _isPromiseResolved(address promise_) internal view returns (bool) {
        return IPromise(promise_).state() == AsyncPromiseState.RESOLVED;
    }

    /// @notice Cancels a request
    /// @param requestCount The request count to cancel
    /// @dev This function cancels a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    function cancelRequestForReverts(uint40 requestCount) external onlyPromiseResolver {
        _cancelRequest(requestCount, requests[requestCount]);
    }

    /// @notice Cancels a request
    /// @param requestCount The request count to cancel
    /// @dev This function cancels a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    function cancelRequest(uint40 requestCount) external {
        RequestParams storage r = requests[requestCount];
        if (r.appGateway != getCoreAppGateway(msg.sender)) revert InvalidCaller();
        _cancelRequest(requestCount, r);
    }

    function handleRevert(uint40 requestCount) external onlyPromiseResolver {
        _cancelRequest(requestCount, requests[requestCount]);
    }

    function _cancelRequest(uint40 requestCount_, RequestParams storage r) internal {
        if (r.requestTrackingParams.isRequestCancelled) revert RequestAlreadyCancelled();
        if (r.requestTrackingParams.isRequestExecuted) revert RequestAlreadySettled();

        r.requestTrackingParams.isRequestCancelled = true;
        _settleRequest(requestCount_, r);
        emit RequestCancelled(requestCount_);
    }

    function _settleRequest(uint40 requestCount_, RequestParams storage r) internal {
        feesManager__().unblockAndAssignCredits(
            requestCount_,
            r.requestFeesDetails.winningBid.transmitter
        );

        if (r.onCompleteData.length > 0) {
            try
                IAppGateway(r.appGateway).onRequestComplete(requestCount_, r.onCompleteData)
            {} catch {
                emit RequestCompletedWithErrors(requestCount_);
            }
        }

        emit RequestSettled(requestCount_, r.requestFeesDetails.winningBid.transmitter);
    }
}
