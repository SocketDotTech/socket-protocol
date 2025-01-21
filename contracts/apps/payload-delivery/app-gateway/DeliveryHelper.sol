// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {Ownable} from "../../../utils/Ownable.sol";
import {Bid, PayloadBatch, FeesData, PayloadDetails, FinalizeParams} from "../../../common/Structs.sol";
import {DISTRIBUTE_FEE, DEPLOY} from "../../../common/Constants.sol";
import "./BatchAsync.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract DeliveryHelper is BatchAsync, Ownable, Initializable {
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address resolver contract
    /// @param feesManager_ The fees manager contract
    /// @param owner_ The owner address
    function initialize(
        address addressResolver_,
        address feesManager_,
        address owner_
    ) public initializer {
        _setAddressResolver(addressResolver_);
        feesManager = feesManager_;
        _claimOwner(owner_);
    }

    function startBatchProcessing(
        bytes32 asyncId_,
        Bid memory winningBid_
    ) external onlyAuctionManager(asyncId_) {
        payloadBatches[asyncId_].winningBid = winningBid_;
        _process(asyncId_);
    }

    function callback(bytes memory asyncId_, bytes memory) external override onlyPromises {
        bytes32 asyncId = abi.decode(asyncId_, (bytes32));
        _process(asyncId);
    }

    error PromisesNotResolved();

    function _process(bytes32 asyncId_) internal {
        PayloadBatch storage payloadBatch = payloadBatches[asyncId_];
        if (payloadBatch.isBatchCancelled) return;

        // Check if there are remaining payloads to process
        // Check if there are promises from last batch that need to be resolved
        if (payloadBatch.lastBatchPromises.length > 0) {
            // Check if all promises are resolved
            for (uint256 i = 0; i < payloadBatch.lastBatchPromises.length; i++) {
                if (!IPromise(payloadBatch.lastBatchPromises[i]).resolved()) {
                    revert PromisesNotResolved();
                }
            }
            // Clear promises array after all are resolved
            delete payloadBatch.lastBatchPromises;
        }

        if (payloadBatch.totalPayloadsRemaining > 0) {
            // Proceed with next payload only if all promises are resolved
            _finalizeNextPayload(asyncId_);
        } else {
            _finishBatch(asyncId_, payloadBatch);
        }
    }

    function _finishBatch(bytes32 asyncId_, PayloadBatch storage payloadBatch_) internal {
        (bytes32 payloadId_, bytes32 root_, PayloadDetails memory payloadDetails_) = IFeesManager(
            feesManager
        ).distributeFees(
                payloadBatch_.appGateway,
                payloadBatch_.feesData,
                payloadBatch_.winningBid
            );

        payloadIdToPayloadDetails[payloadId_] = payloadDetails_;
        payloadIdToBatchHash[payloadId_] = asyncId_;
        emit PayloadAsyncRequested(asyncId_, payloadId_, root_, payloadDetails_);

        IAppGateway(payloadBatch_.appGateway).onBatchComplete(asyncId_, payloadBatch_);
    }

    function _finalizeNextPayload(bytes32 asyncId_) internal {
        PayloadBatch storage payloadBatch_ = payloadBatches[asyncId_];
        uint256 currentIndex = payloadBatch_.currentPayloadIndex;
        PayloadDetails[] storage payloads = payloadBatchDetails[asyncId_];

        // Deploy single promise for the next batch of operations
        address batchPromise = IAddressResolver(addressResolver__).deployAsyncPromiseContract(
            address(this)
        );
        isValidPromise[batchPromise] = true;
        IPromise(batchPromise).then(this.callback.selector, abi.encode(asyncId_));

        // Handle batch processing based on type
        if (payloads[currentIndex].callType == CallType.READ) {
            _processBatchedReads(asyncId_, payloadBatch_, payloads, currentIndex, batchPromise);
        } else if (!payloads[currentIndex].isSequential) {
            _processParallelCalls(asyncId_, payloadBatch_, payloads, currentIndex, batchPromise);
        } else {
            _processSequentialCall(asyncId_, payloadBatch_, payloads, currentIndex, batchPromise);
        }
    }

    function _executeWatcherCall(
        bytes32 asyncId_,
        PayloadDetails storage payloadDetails_,
        PayloadBatch storage payloadBatch_,
        address batchPromise_,
        bool isRead_
    ) internal returns (bytes32 payloadId, bytes32 root) {
        payloadDetails_.next[1] = batchPromise_;
        if (isRead_) {
            payloadId = watcherPrecompile__().query(
                payloadDetails_.chainSlug,
                payloadDetails_.target,
                payloadDetails_.appGateway,
                payloadDetails_.next,
                payloadDetails_.payload
            );
            root = bytes32(0);
        } else {
            FinalizeParams memory finalizeParams = FinalizeParams({
                payloadDetails: payloadDetails_,
                transmitter: payloadBatch_.winningBid.transmitter
            });
            (payloadId, root) = watcherPrecompile__().finalize(
                finalizeParams,
                payloadBatch_.appGateway
            );
        }

        payloadIdToBatchHash[payloadId] = asyncId_;
        payloadIdToPayloadDetails[payloadId] = payloadDetails_;

        emit PayloadAsyncRequested(asyncId_, payloadId, root, payloadDetails_);
    }

    function _processBatchedReads(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch_,
        PayloadDetails[] storage payloads_,
        uint256 startIndex_,
        address batchPromise_
    ) internal {
        uint256 endIndex = startIndex_;
        while (
            endIndex + 1 < payloads_.length && payloads_[endIndex + 1].callType == CallType.READ
        ) {
            endIndex++;
        }

        address[] memory promises = new address[](endIndex - startIndex_ + 1);
        for (uint256 i = startIndex_; i <= endIndex; i++) {
            promises[i - startIndex_] = payloads_[i].next[0];
            _executeWatcherCall(asyncId_, payloads_[i], payloadBatch_, batchPromise_, true);
        }

        _updateBatchState(payloadBatch_, promises, endIndex - startIndex_ + 1, endIndex + 1);
    }

    function _processParallelCalls(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch_,
        PayloadDetails[] storage payloads_,
        uint256 startIndex_,
        address batchPromise_
    ) internal {
        uint256 endIndex = startIndex_;
        while (endIndex + 1 < payloads_.length && !payloads_[endIndex + 1].isSequential) {
            endIndex++;
        }

        // Store promises for last batch
        address[] memory promises = new address[](endIndex - startIndex_ + 1);
        for (uint256 i = startIndex_; i <= endIndex; i++) {
            promises[i - startIndex_] = payloads_[i].next[0];

            _executeWatcherCall(asyncId_, payloads_[i], payloadBatch_, batchPromise_, false);
        }

        _updateBatchState(payloadBatch_, promises, endIndex - startIndex_ + 1, endIndex + 1);
    }

    function _processSequentialCall(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch_,
        PayloadDetails[] storage payloads_,
        uint256 currentIndex_,
        address batchPromise_
    ) internal {
        address[] memory promises = new address[](1);
        promises[0] = payloads_[currentIndex_].next[0];

        _executeWatcherCall(
            asyncId_,
            payloads_[currentIndex_],
            payloadBatch_,
            batchPromise_,
            false
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
}
