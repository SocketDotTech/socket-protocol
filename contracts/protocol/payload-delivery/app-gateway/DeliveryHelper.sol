// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BatchAsync.sol";

contract DeliveryHelper is BatchAsync {
    event CallBackReverted(bytes32 asyncId_, bytes32 payloadId_);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address resolver contract
    /// @param owner_ The owner address
    function initialize(
        address addressResolver_,
        address owner_,
        uint128 bidTimeout_,
        address defaultAuctionManager_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        bidTimeout = bidTimeout_;
        _initializeOwner(owner_);
        defaultAuctionManager = defaultAuctionManager_;
    }

    function startBatchProcessing(
        bytes32 asyncId_,
        Bid memory winningBid_
    ) external onlyAuctionManager(asyncId_) {
        if (winningBid_.transmitter == address(0)) revert InvalidTransmitter();

        bool isRestarted = _payloadBatches[asyncId_].winningBid.transmitter != address(0);
        _payloadBatches[asyncId_].winningBid = winningBid_;

        if (!isRestarted) return _process(asyncId_, false);

        // Re-finalize all payloads in the batch if a new transmitter is assigned
        bytes32[] memory payloadIds = _payloadBatches[asyncId_].lastBatchOfPayloads;
        for (uint256 i = 0; i < payloadIds.length; i++) {
            watcherPrecompile__().refinalize(
                payloadIds[i],
                FinalizeParams({
                    payloadDetails: payloadIdToPayloadDetails[payloadIds[i]],
                    asyncId: asyncId_,
                    transmitter: winningBid_.transmitter
                })
            );
        }
    }

    function callback(bytes memory asyncId_, bytes memory) external override onlyPromises {
        bytes32 asyncId = abi.decode(asyncId_, (bytes32));
        _process(asyncId, true);
    }

    function _process(bytes32 asyncId_, bool isCallback_) internal {
        PayloadBatch storage payloadBatch = _payloadBatches[asyncId_];
        if (payloadBatch.isBatchCancelled) return;

        // Check if there are remaining payloads to process
        // Check if there are promises from last batch that need to be resolved
        if (payloadBatch.lastBatchPromises.length > 0) {
            // Check if all promises are resolved
            for (uint256 i = 0; i < payloadBatch.lastBatchPromises.length; i++) {
                if (payloadBatch.lastBatchPromises[i] == address(0)) continue;
                if (!IPromise(payloadBatch.lastBatchPromises[i]).resolved()) {
                    if (isCallback_) revert PromisesNotResolved();
                }
            }
            // Clear promises array after all are resolved
            if (isCallback_) {
                delete payloadBatch.lastBatchPromises;
            }
        }

        if (payloadBatch.totalPayloadsRemaining > 0) {
            delete tempPayloadIds;

            // Proceed with next payload only if all promises are resolved
            _finalizeNextPayload(asyncId_);
            payloadBatch.lastBatchOfPayloads = tempPayloadIds;
        } else {
            _finishBatch(asyncId_, payloadBatch);
        }

        isValidPromise[msg.sender] = false;
    }

    function _finishBatch(bytes32 asyncId_, PayloadBatch storage payloadBatch_) internal {
        IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
            asyncId_,
            payloadBatch_.winningBid.transmitter,
            payloadBatch_.appGateway
        );
        IAppGateway(payloadBatch_.appGateway).onBatchComplete(asyncId_, payloadBatch_);
    }

    function _finalizeNextPayload(bytes32 asyncId_) internal {
        PayloadBatch storage payloadBatch_ = _payloadBatches[asyncId_];
        uint256 currentIndex = payloadBatch_.currentPayloadIndex;
        PayloadDetails[] storage payloads = payloadBatchDetails[asyncId_];

        // Check for empty payloads or index out of bounds
        if (payloads.length == 0 || currentIndex >= payloads.length) {
            revert InvalidIndex();
        }

        // Deploy single promise for the next batch of operations
        address batchPromise = IAddressResolver(addressResolver__).deployAsyncPromiseContract(
            address(this)
        );

        isValidPromise[batchPromise] = true;
        IPromise(batchPromise).then(this.callback.selector, abi.encode(asyncId_));

        // Handle batch processing based on type
        if (payloads[currentIndex].isParallel == Parallel.ON) {
            _processParallelCalls(asyncId_, payloadBatch_, payloads, currentIndex, batchPromise);
        } else {
            _processSequentialCall(
                asyncId_,
                payloadBatch_,
                payloads,
                currentIndex,
                batchPromise,
                payloads[currentIndex].callType == CallType.READ
            );
        }
    }

    function _executeWatcherCall(
        bytes32 asyncId_,
        PayloadDetails storage payloadDetails_,
        PayloadBatch storage payloadBatch_,
        address batchPromise_,
        bool isRead_
    ) internal returns (bytes32 payloadId, bytes32 digest) {
        payloadDetails_.next[1] = batchPromise_;
        if (isRead_) {
            payloadId = watcherPrecompile__().query(
                payloadDetails_.chainSlug,
                payloadDetails_.target,
                payloadDetails_.appGateway,
                payloadDetails_.next,
                payloadDetails_.payload
            );
            digest = bytes32(0);
        } else {
            FinalizeParams memory finalizeParams = FinalizeParams({
                payloadDetails: payloadDetails_,
                asyncId: asyncId_,
                transmitter: payloadBatch_.winningBid.transmitter
            });
            (payloadId, digest) = watcherPrecompile__().finalize(
                payloadBatch_.appGateway,
                finalizeParams
            );
        }

        tempPayloadIds.push(payloadId);
        payloadIdToBatchHash[payloadId] = asyncId_;
        payloadIdToPayloadDetails[payloadId] = payloadDetails_;

        emit PayloadAsyncRequested(asyncId_, payloadId, digest, payloadDetails_);
    }

    function _processParallelCalls(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch_,
        PayloadDetails[] storage payloads_,
        uint256 startIndex_,
        address batchPromise_
    ) internal {
        // Validate input parameters
        if (startIndex_ >= payloads_.length) revert InvalidIndex();

        uint256 endIndex = startIndex_;
        while (
            endIndex + 1 < payloads_.length && payloads_[endIndex + 1].isParallel == Parallel.ON
        ) {
            endIndex++;
        }

        address[] memory promises = new address[](endIndex - startIndex_ + 1);
        for (uint256 i = startIndex_; i <= endIndex; i++) {
            promises[i - startIndex_] = payloads_[i].next[0];
            if (payloads_[i].callType == CallType.READ) {
                _executeWatcherCall(asyncId_, payloads_[i], payloadBatch_, batchPromise_, true);
            } else {
                _executeWatcherCall(asyncId_, payloads_[i], payloadBatch_, batchPromise_, false);
            }
        }

        _updateBatchState(payloadBatch_, promises, endIndex - startIndex_ + 1, endIndex + 1);
    }

    function _processSequentialCall(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch_,
        PayloadDetails[] storage payloads_,
        uint256 currentIndex_,
        address batchPromise_,
        bool isRead_
    ) internal {
        // Validate input parameters
        if (currentIndex_ >= payloads_.length) revert InvalidIndex();

        address[] memory promises = new address[](1);
        promises[0] = payloads_[currentIndex_].next[0];

        _executeWatcherCall(
            asyncId_,
            payloads_[currentIndex_],
            payloadBatch_,
            batchPromise_,
            isRead_
        );
        _updateBatchState(payloadBatch_, promises, 1, currentIndex_ + 1);
    }

    function _updateBatchState(
        PayloadBatch storage batch_,
        address[] memory promises_,
        uint256 completedCount_,
        uint256 nextIndex_
    ) internal {
        batch_.totalPayloadsRemaining -= completedCount_;

        batch_.currentPayloadIndex = nextIndex_;
        batch_.lastBatchPromises = promises_;
    }

    function handleRevert(bytes32 asyncId_, bytes32 payloadId_) external onlyPromises {
        emit CallBackReverted(asyncId_, payloadId_);
    }
}
