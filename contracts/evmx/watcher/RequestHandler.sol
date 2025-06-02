// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import "solady/auth/Ownable.sol";
import "../helpers/AddressResolverUtil.sol";
import "../../utils/common/Errors.sol";
import "../../utils/common/Constants.sol";
import "../../utils/common/IdUtils.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";
import "../interfaces/IRequestHandler.sol";
import "../../utils/RescueFundsLib.sol";

abstract contract RequestHandlerStorage is IRequestHandler {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50 (40 + 40 + 40)
    /// @notice Counter for tracking request counts
    uint40 public nextRequestCount = 1;

    /// @notice Counter for tracking payload _requests
    uint40 public payloadCounter;

    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    // slot 51
    /// @notice Mapping to store the precompiles for each call type
    mapping(bytes4 => IPrecompile) public precompiles;

    // slot 52
    /// @notice Mapping to store the list of payload IDs for each batch
    mapping(uint40 => bytes32[]) internal _batchPayloadIds;

    // slot 53
    /// @notice Mapping to store the batch IDs for each request
    mapping(uint40 => uint40[]) internal _requestBatchIds;

    // queue => update to payloadParams, assign id, store in payloadParams map
    // slot 54
    /// @notice Mapping to store the payload parameters for each payload ID
    mapping(bytes32 => PayloadParams) internal _payloads;

    // slot 55
    /// @notice The metadata for a request
    mapping(uint40 => RequestParams) internal _requests;

    // slots [56-105] reserved for gap
    uint256[50] _gap_after;

    // slots [106-155] 50 slots reserved for address resolver util
}

/// @title RequestHandler
/// @notice Contract that handles request processing and management, including request submission, batch processing, and request lifecycle management
/// @dev Handles request submission, batch processing, transmitter assignment, request cancellation and settlement
contract RequestHandler is RequestHandlerStorage, Initializable, Ownable, AddressResolverUtil {
    error InsufficientMaxFees();

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
        if (_requests[requestCount_].requestTrackingParams.isRequestCancelled)
            revert RequestAlreadyCancelled();
        _;
    }

    modifier onlyPromiseResolver() {
        if (msg.sender != address(watcher__().promiseResolver__())) revert NotPromiseResolver();
        _;
    }

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    function initialize(address owner_, address addressResolver_) external reinitializer(1) {
        _initializeOwner(owner_);
        _setAddressResolver(addressResolver_);
    }

    function setPrecompile(bytes4 callType_, IPrecompile precompile_) external onlyOwner {
        precompiles[callType_] = precompile_;
    }

    function getPrecompileFees(
        bytes4 callType_,
        bytes memory precompileData_
    ) external view returns (uint256) {
        return precompiles[callType_].getPrecompileFees(precompileData_);
    }

    function getRequestBatchIds(uint40 requestCount_) external view returns (uint40[] memory) {
        return _requestBatchIds[requestCount_];
    }

    function getBatchPayloadIds(uint40 batchCount_) external view returns (bytes32[] memory) {
        return _batchPayloadIds[batchCount_];
    }

    function getRequest(uint40 requestCount_) external view returns (RequestParams memory) {
        return _requests[requestCount_];
    }

    function getPayload(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return _payloads[payloadId_];
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
        uint40 currentBatch = nextBatchCount;

        RequestParams storage r = _requests[requestCount];
        r.requestTrackingParams.payloadsRemaining = queueParams_.length;
        r.requestFeesDetails.maxFees = maxFees_;
        r.requestFeesDetails.consumeFrom = consumeFrom_;
        r.auctionManager = _getAuctionManager(auctionManager_);
        r.appGateway = appGateway_;
        r.onCompleteData = onCompleteData_;

        CreateRequestResult memory result = _createRequest(queueParams_, appGateway_, requestCount);

        // initialize tracking params
        r.requestTrackingParams.currentBatch = currentBatch;
        r.requestTrackingParams.currentBatchPayloadsLeft = _batchPayloadIds[currentBatch].length;

        r.writeCount = result.writeCount;
        promiseList = result.promiseList;

        if (result.totalEstimatedWatcherFees > maxFees_) revert InsufficientMaxFees();
        if (r.writeCount == 0) _processBatch(currentBatch, r);

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
        RequestParams storage r = _requests[requestCount_];
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
        _requestBatchIds[requestCount_].push(nextBatchCount);

        result.promiseList = new address[](queueParams_.length);
        result.payloadParams = new PayloadParams[](queueParams_.length);
        for (uint256 i = 0; i < queueParams_.length; i++) {
            QueueParams calldata queuePayloadParam = queueParams_[i];
            bytes4 callType = queuePayloadParam.overrideParams.callType;
            if (callType == WRITE) result.writeCount++;

            // decide batch count
            if (i > 0 && queueParams_[i].overrideParams.isParallelCall != Parallel.ON) {
                nextBatchCount++;
                _requestBatchIds[requestCount_].push(nextBatchCount);
            }

            // get the switchboard address from the configurations
            // returns address(0) for schedule precompile and reads if sb type not set
            address switchboard = watcher__().configurations__().switchboards(
                queuePayloadParam.transaction.chainSlug,
                queuePayloadParam.switchboardType
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
                // todo: add evmx chain slug if schedule or read?
                queuePayloadParam.transaction.chainSlug
            );
            _batchPayloadIds[nextBatchCount].push(payloadId);

            // create prev digest hash
            PayloadParams memory p;
            p.requestCount = requestCount_;
            p.batchCount = nextBatchCount;
            p.payloadCount = payloadCount;
            p.callType = callType;
            p.asyncPromise = queueParams_[i].asyncPromise;
            p.appGateway = appGateway_;
            p.payloadId = payloadId;
            p.precompileData = precompileData;

            result.promiseList[i] = queueParams_[i].asyncPromise;
            result.payloadParams[i] = p;
            _payloads[payloadId] = p;
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

    // called when processing batch first time or being retried
    function _processBatch(uint40 batchCount_, RequestParams storage r) internal {
        bytes32[] memory payloadIds = _batchPayloadIds[batchCount_];

        uint256 totalFees = 0;
        for (uint40 i = 0; i < payloadIds.length; i++) {
            bytes32 payloadId = payloadIds[i];

            // check needed for re-process, in case a payload is already executed by last transmitter
            if (_isPromiseResolved(_payloads[payloadId].asyncPromise)) continue;
            PayloadParams storage payloadParams = _payloads[payloadId];

            (uint256 fees, uint256 deadline, bytes memory precompileData) = IPrecompile(
                precompiles[payloadParams.callType]
            ).handlePayload(r.requestFeesDetails.winningBid.transmitter, payloadParams);

            totalFees += fees;
            payloadParams.deadline = deadline;
            payloadParams.precompileData = precompileData;
        }

        address watcherFeesPayer = r.requestFeesDetails.winningBid.transmitter == address(0)
            ? r.requestFeesDetails.consumeFrom
            : r.requestFeesDetails.winningBid.transmitter;
        feesManager__().transferCredits(watcherFeesPayer, address(this), totalFees);
    }

    /// @notice Increases the fees for a request if no bid is placed
    /// @param requestCount_ The ID of the request
    /// @param newMaxFees_ The new maximum fees
    function increaseFees(
        uint40 requestCount_,
        uint256 newMaxFees_,
        address appGateway_
    ) external onlyWatcher isRequestCancelled(requestCount_) {
        RequestParams storage r = _requests[requestCount_];
        if (r.requestTrackingParams.isRequestExecuted) revert RequestAlreadySettled();

        if (appGateway_ != r.appGateway) revert OnlyAppGateway();
        if (r.requestFeesDetails.maxFees >= newMaxFees_)
            revert NewMaxFeesLowerThanCurrent(r.requestFeesDetails.maxFees, newMaxFees_);

        if (
            !IFeesManager(feesManager__()).isCreditSpendable(
                r.requestFeesDetails.consumeFrom,
                appGateway_,
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
        RequestParams storage r = _requests[requestCount_];

        PayloadParams storage payloadParams = _payloads[payloadId_];
        payloadParams.resolvedAt = block.timestamp;

        RequestTrackingParams storage trackingParams = r.requestTrackingParams;
        trackingParams.currentBatchPayloadsLeft--;
        trackingParams.payloadsRemaining--;

        IPrecompile(precompiles[payloadParams.callType]).resolvePayload(payloadParams);

        if (trackingParams.currentBatchPayloadsLeft != 0) return;
        if (trackingParams.payloadsRemaining == 0) {
            trackingParams.isRequestExecuted = true;
            _settleRequest(requestCount_, r);
        } else {
            uint40 currentBatch = ++trackingParams.currentBatch;
            trackingParams.currentBatchPayloadsLeft = _batchPayloadIds[currentBatch].length;
            _processBatch(currentBatch, r);
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
        _cancelRequest(requestCount, _requests[requestCount]);
    }

    /// @notice Cancels a request
    /// @param requestCount The request count to cancel
    /// @dev This function cancels a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    function cancelRequest(uint40 requestCount, address appGateway_) external onlyWatcher {
        RequestParams storage r = _requests[requestCount];
        if (appGateway_ != r.appGateway) revert InvalidCaller();
        _cancelRequest(requestCount, r);
    }

    function handleRevert(uint40 requestCount) external onlyPromiseResolver {
        _cancelRequest(requestCount, _requests[requestCount]);
    }

    function _cancelRequest(
        uint40 requestCount_,
        RequestParams storage r
    ) internal isRequestCancelled(requestCount_) {
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

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
