// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {Ownable} from "../../../utils/Ownable.sol";
import {Bid, PayloadBatch, FeesData, PayloadDetails, FinalizeParams} from "../../../common/Structs.sol";
import {DISTRIBUTE_FEE, DEPLOY} from "../../../common/Constants.sol";
import "./BatchAsync.sol";

contract DeliveryHelper is BatchAsync, Ownable(msg.sender) {
    constructor(
        address _addressResolver,
        address _feesManager
    ) AddressResolverUtil(_addressResolver) {
        feesManager = _feesManager;
    }

    function startBatchProcessing(
        bytes32 asyncId_
    ) external onlyAuctionManager(asyncId_) {
        _process(asyncId_, "");
    }

    function callback(
        bytes memory asyncId_,
        bytes memory payloadDetails_
    ) external override onlyPromises {
        bytes32 asyncId = abi.decode(asyncId_, (bytes32));

        _process(asyncId, payloadDetails_);
    }

    error PromisesNotResolved();

    function _process(bytes32 asyncId, bytes memory payloadDetails_) internal {
        PayloadBatch storage payloadBatch = payloadBatches[asyncId];
        if (payloadBatch.isBatchCancelled) return;

        // Check if there are remaining payloads to process
        if (payloadBatch.totalPayloadsRemaining > 0) {
            // Check if there are promises from last batch that need to be resolved
            if (payloadBatch.lastBatchPromises.length > 0) {
                // Check if all promises are resolved
                for (
                    uint256 i = 0;
                    i < payloadBatch.lastBatchPromises.length;
                    i++
                ) {
                    if (
                        !IPromise(payloadBatch.lastBatchPromises[i]).resolved()
                    ) {
                        revert PromisesNotResolved();
                    }
                }
                // Clear promises array after all are resolved
                delete payloadBatch.lastBatchPromises;
            }

            // Proceed with next payload only if all promises are resolved
            _finalizeNextPayload(asyncId);
        } else {
            _finishBatch(asyncId, payloadBatch, payloadDetails_);
        }
    }

    function _finishBatch(
        bytes32 asyncId,
        PayloadBatch storage payloadBatch,
        bytes memory payloadDetails_
    ) internal {
        (bytes32 payloadId, bytes32 root) = IFeesManager(feesManager)
            .distributeFees(
                payloadBatch.appGateway,
                payloadBatch.feesData,
                payloadBatch.winningBid
            );

        payloadIdToBatchHash[payloadId] = asyncId;
        emit PayloadAsyncRequested(
            asyncId,
            payloadId,
            root,
            abi.decode(payloadDetails_, (PayloadDetails))
        );

        IAppGateway(payloadBatch.appGateway).onBatchComplete(
            asyncId,
            payloadBatch
        );
    }

    function _finalizeNextPayload(bytes32 asyncId_) internal {
        PayloadBatch storage payloadBatch = payloadBatches[asyncId_];
        uint256 currentIndex = payloadBatch.currentPayloadIndex;
        PayloadDetails[] storage payloads = payloadBatchDetails[asyncId_];

        // Deploy single promise for the next batch of operations
        address batchPromise = IAddressResolver(addressResolver)
            .deployAsyncPromiseContract(address(this));
        isValidPromise[batchPromise] = true;
        IPromise(batchPromise).then(
            this.callback.selector,
            abi.encode(asyncId_)
        );

        // Handle batch processing based on type
        if (payloads[currentIndex].callType == CallType.READ) {
            _processBatchedReads(
                asyncId_,
                payloadBatch,
                payloads,
                currentIndex,
                batchPromise
            );
        } else if (!payloads[currentIndex].isSequential) {
            _processParallelCalls(
                asyncId_,
                payloadBatch,
                payloads,
                currentIndex,
                batchPromise
            );
        } else {
            _processSequentialCall(
                asyncId_,
                payloadBatch,
                payloads,
                currentIndex,
                batchPromise
            );
        }
    }

    function _executeWatcherCall(
        bytes32 asyncId_,
        PayloadDetails storage payload,
        PayloadBatch storage payloadBatch,
        address batchPromise,
        bool isRead
    ) internal returns (bytes32 payloadId, bytes32 root) {
        if (isRead) {
            payload.next[1] = batchPromise;
            payloadId = watcherPrecompile().query(
                payload.chainSlug,
                payload.target,
                payload.next,
                payload.payload
            );
            root = bytes32(0);
        } else {
            FinalizeParams memory finalizeParams = FinalizeParams({
                payloadDetails: payload,
                transmitter: payloadBatch.winningBid.transmitter
            });
            (payloadId, root) = watcherPrecompile().finalize(finalizeParams);
        }

        payload.next[1] = batchPromise;
        payloadIdToBatchHash[payloadId] = asyncId_;
        emit PayloadAsyncRequested(asyncId_, payloadId, root, payload);
    }

    function _processBatchedReads(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch,
        PayloadDetails[] storage payloads,
        uint256 startIndex,
        address batchPromise
    ) internal {
        uint256 endIndex = startIndex;
        while (
            endIndex + 1 < payloads.length &&
            payloads[endIndex + 1].callType == CallType.READ
        ) {
            endIndex++;
        }

        address[] memory promises = new address[](endIndex - startIndex + 1);
        for (uint256 i = startIndex; i <= endIndex; i++) {
            promises[i - startIndex] = payloads[i].next[0];
            _executeWatcherCall(
                asyncId_,
                payloads[i],
                payloadBatch,
                batchPromise,
                true
            );
        }

        _updateBatchState(
            payloadBatch,
            promises,
            endIndex - startIndex + 1,
            endIndex + 1
        );
    }

    function _processParallelCalls(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch,
        PayloadDetails[] storage payloads,
        uint256 startIndex,
        address batchPromise
    ) internal {
        uint256 endIndex = startIndex;
        while (
            endIndex + 1 < payloads.length &&
            !payloads[endIndex + 1].isSequential
        ) {
            endIndex++;
        }

        // Store promises for last batch
        address[] memory promises = new address[](endIndex - startIndex + 1);
        for (uint256 i = startIndex; i <= endIndex; i++) {
            promises[i - startIndex] = payloads[i].next[0];

            _executeWatcherCall(
                asyncId_,
                payloads[i],
                payloadBatch,
                batchPromise,
                false
            );
        }

        _updateBatchState(
            payloadBatch,
            promises,
            endIndex - startIndex + 1,
            endIndex + 1
        );
    }

    function _processSequentialCall(
        bytes32 asyncId_,
        PayloadBatch storage payloadBatch,
        PayloadDetails[] storage payloads,
        uint256 currentIndex,
        address batchPromise
    ) internal {
        address[] memory promises = new address[](1);
        promises[0] = payloads[currentIndex].next[0];

        _executeWatcherCall(
            asyncId_,
            payloads[currentIndex],
            payloadBatch,
            batchPromise,
            false
        );
        _updateBatchState(payloadBatch, promises, 1, currentIndex + 1);
    }

    function _updateBatchState(
        PayloadBatch storage batch,
        address[] memory promises,
        uint256 completedCount,
        uint256 nextIndex
    ) internal {
        batch.totalPayloadsRemaining -= completedCount;
        batch.currentPayloadIndex = nextIndex;
        batch.lastBatchPromises = promises;
    }
}
