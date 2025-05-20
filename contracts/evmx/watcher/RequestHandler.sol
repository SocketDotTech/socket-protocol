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

    /// @notice Mapping to store if a promise is executed for each payload ID
    mapping(bytes32 => bool) public isPromiseExecuted;

    constructor(address watcherStorage_) WatcherBase(watcherStorage_) {}

    modifier isRequestCancelled(uint40 requestCount_) {
        if (requestParams[requestCount_].requestTrackingParams.isRequestCancelled)
            revert RequestCancelled();
        _;
    }

    function setPrecompile(bytes4 callType_, IPrecompile precompile_) external onlyWatcher {
        precompiles[callType_] = precompile_;
    }

    function submitRequest(
        uint256 maxFees_,
        address auctionManager_,
        address consumeFrom_,
        address appGateway_,
        QueueParams[] calldata queuePayloadParams_,
        bytes memory onCompleteData_
    ) external onlyWatcher returns (uint40 requestCount, address[] memory promiseList) {
        if (queuePayloadParams_.length == 0) return uint40(0);
        if (queuePayloadParams.length > REQUEST_PAYLOAD_COUNT_LIMIT)
            revert RequestPayloadCountLimitExceeded();

        address appGateway = _getCoreAppGateway(appGateway_);
        if (!IFeesManager(feesManager__()).isUserCreditsEnough(consumeFrom_, appGateway, maxFees_))
            revert InsufficientFees();

        requestCount = nextRequestCount++;
        RequestParams storage r = requestParams[requestCount];
        r = RequestParams({
            requestTrackingParams: RequestTrackingParams({
                isRequestCancelled: false,
                isRequestExecuted: false,
                currentBatch: nextBatchCount,
                currentBatchPayloadsLeft: 0,
                payloadsRemaining: queuePayloadParams_.length
            }),
            requestFeesDetails: RequestFeesDetails({
                maxFees: maxFees_,
                consumeFrom: consumeFrom_,
                winningBid: Bid({transmitter: address(0), fees: 0})
            }),
            writeCount: 0,
            auctionManager: _getAuctionManager(auctionManager_),
            appGateway: appGateway,
            onCompleteData: onCompleteData_
        });

        PayloadParams[] memory payloadParams;
        uint256 totalEstimatedWatcherFees;
        (totalEstimatedWatcherFees, r.writeCount, promiseList, payloadParams) = _createRequest(
            queuePayloadParams_,
            appGateway,
            requestCount
        );

        if (totalEstimatedWatcherFees > maxFees_) revert InsufficientFees();

        if (r.writeCount == 0) _processBatch(requestCount, r.requestTrackingParams.currentBatch, r);
        emit RequestSubmitted(
            r.writeCount > 0,
            requestCount,
            totalEstimatedWatcherFees,
            r,
            payloadParams
        );
    }

    // called by auction manager when a auction ends or a new transmitter is assigned (bid expiry)
    function assignTransmitter(
        uint40 requestCount_,
        Bid memory bid_
    ) external isRequestCancelled(requestCount_) {
        RequestParams storage r = requestParams[requestCount_];
        if (r.auctionManager != msg.sender) revert InvalidCaller();
        if (r.requestTrackingParams.isRequestExecuted) revert RequestAlreadySettled();

        if (r.writeCount == 0) revert NoWriteRequest();
        if (r.requestFeesDetails.winningBid.transmitter == bid_.transmitter)
            revert AlreadyAssigned();

        if (r.requestFeesDetails.winningBid.transmitter != address(0)) {
            feesManager__().unblockCredits(requestCount_);
        }

        r.requestFeesDetails.winningBid = bid_;
        if (bid_.transmitter == address(0)) return;
        feesManager__().blockCredits(requestCount_, r.requestFeesDetails.consumeFrom, bid_.fees);

        // re-process current batch again or process the batch for the first time
        _processBatch(requestCount_, r.requestTrackingParams.currentBatch, r);
    }

    function _createRequest(
        QueueParams[] calldata queuePayloadParams_,
        address appGateway_,
        uint40 requestCount_
    )
        internal
        returns (
            uint256 totalEstimatedWatcherFees,
            uint256 writeCount,
            address[] memory promiseList,
            PayloadParams[] memory payloadParams
        )
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
            (uint256 estimatedFees, bytes memory precompileData) = _validateAndGetPrecompileData(
                queuePayloadParam,
                appGateway_,
                callType
            );
            totalEstimatedWatcherFees += estimatedFees;

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
            PayloadParams memory p = PayloadParams({
                requestCount: requestCount_,
                batchCount: batchCount,
                payloadCount: payloadCount,
                callType: callType,
                asyncPromise: queuePayloadParams_.asyncPromise,
                appGateway: queuePayloadParams_.appGateway,
                payloadId: payloadId,
                resolvedAt: 0,
                deadline: 0,
                precompileData: precompileData
            });
            promiseList.push(queuePayloadParams_.asyncPromise);
            payloadParams.push(p);
            payloads[payloadId] = p;
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

    function _processBatch(
        uint40 requestCount_,
        uint40 batchCount_,
        RequestParams storage r
    ) internal {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount_];

        uint256 totalFees = 0;
        for (uint40 i = 0; i < payloadIds.length; i++) {
            bytes32 payloadId = payloadIds[i];

            // check needed for re-process, in case a payload is already executed by last transmitter
            if (!isPromiseExecuted[payloadId]) continue;

            PayloadParams storage payloadParams = payloads[payloadId];
            payloadParams.deadline = block.timestamp + expiryTime;

            uint256 fees = IPrecompile(precompiles[payloadParams.callType]).handlePayload(
                r.requestFeesDetails.winningBid.transmitter,
                payloadParams
            );
            totalFees += fees;
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
        RequestParams storage r = requestParams[requestCount_];
        address appGateway = _getCoreAppGateway(msg.sender);

        if (appGateway != r.appGateway) revert OnlyAppGateway();
        if (r.requestFeesDetails.winningBid.transmitter != address(0)) revert WinningBidExists();
        if (r.requestFeesDetails.maxFees >= newMaxFees_)
            revert NewMaxFeesLowerThanCurrent(r.requestFeesDetails.maxFees, newMaxFees_);

        r.requestFeesDetails.maxFees = newMaxFees_;
        emit FeesIncreased(appGateway, requestCount_, newMaxFees_);
    }

    function markPayloadExecutedAndProcessBatch(
        uint40 requestCount_,
        bytes32 payloadId_
    ) external onlyPromiseResolver isRequestCancelled(requestCount_) {
        RequestParams storage r = requestParams[requestCount_];

        isPromiseExecuted[payloadId_] = true;
        r.requestTrackingParams.currentBatchPayloadsLeft--;
        r.requestTrackingParams.payloadsRemaining--;

        if (r.requestTrackingParams.currentBatchPayloadsLeft != 0) return;
        if (r.requestTrackingParams.payloadsRemaining == 0) {
            _settleRequest(requestCount_, r);
            return;
        }

        r.requestTrackingParams.currentBatch++;
        _processBatch(requestCount_, r.requestTrackingParams.currentBatch_, r);
    }

    /// @notice Cancels a request
    /// @param requestCount The request count to cancel
    /// @dev This function cancels a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    function cancelRequest(uint40 requestCount) external {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestAlreadyCancelled();
        if (r.appGateway != getCoreAppGateway(msg.sender)) revert InvalidCaller();

        r.isRequestCancelled = true;

        _settleRequest(requestCount, r);
        emit RequestCancelled(requestCount);
    }

    function _settleRequest(uint40 requestCount_, RequestParams storage r) internal {
        if (r.requestTrackingParams.isRequestExecuted) return;
        r.requestTrackingParams.isRequestExecuted = true;

        feesManager__().unblockAndAssignCredits(
            requestCount_,
            r.requestFeesDetails.winningBid.transmitter
        );

        if (r.appGateway.code.length > 0 && r.onCompleteData.length > 0) {
            try
                IAppGateway(r.appGateway).onRequestComplete(requestCount_, r.onCompleteData)
            {} catch {
                emit RequestCompletedWithErrors(requestCount_);
            }
        }

        emit RequestSettled(requestCount_, r.requestFeesDetails.winningBid.transmitter);
    }
}
