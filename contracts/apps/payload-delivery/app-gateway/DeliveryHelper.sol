// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {Ownable} from "../../../utils/Ownable.sol";
import {Bid, PayloadBatch, FeesData, PayloadDetails, FinalizeParams} from "../../../common/Structs.sol";
import {DISTRIBUTE_FEE, DEPLOY} from "../../../common/Constants.sol";
import "./BatchAsync.sol";

// msg.sender map and call next function flow
contract DeliveryHelper is BatchAsync, Ownable(msg.sender) {
    /// @notice Starts the batch processing
    /// @param asyncId_ The ID of the batch
    function startBatchProcessing(
        bytes32 asyncId_
    ) external onlyAuctionManager {
        PayloadBatch storage payloadBatch = payloadBatches[asyncId_];
        if (payloadBatch.isBatchCancelled) return;

        _finalizeNextPayload(asyncId_);
    }

    /// @notice Callback function for handling promises
    /// @param asyncId_ The ID of the batch
    /// @param payloadDetails_ The payload details
    function callback(
        bytes memory asyncId_,
        bytes memory payloadDetails_
    ) external override onlyPromises {
        bytes32 asyncId = abi.decode(asyncId_, (bytes32));
        PayloadBatch storage payloadBatch = payloadBatches[asyncId];
        if (payloadBatch.isBatchCancelled) return;

        uint256 payloadsRemaining = totalPayloadsRemaining[asyncId];

        if (payloadsRemaining > 0) {
            payloadBatch.currentPayloadIndex++;
            _finalizeNextPayload(asyncId);
        } else {
            // todo: change it to call to fees manager
            (bytes32 payloadId, bytes32 root) = IFeesManager(feesManager)
                .distributeFees(
                    asyncId,
                    payloadBatch.appGateway,
                    payloadBatch.feesData,
                    winningBids[asyncId]
                );
            payloadIdToBatchHash[payloadId] = asyncId;
            emit PayloadAsyncRequested(
                asyncId,
                payloadId,
                root,
                payloadDetails_
            );

            PayloadDetails storage payloadDetails = payloadBatchDetails[
                asyncId
            ][payloadBatch.currentPayloadIndex];

            if (payloadDetails.callType == CallType.DEPLOY) {
                IAppGateway(payloadBatch.appGateway).allContractsDeployed(
                    payloadDetails.chainSlug
                );
            }
        }
    }

    /// @notice Finalizes the next payload in the batch
    /// @param asyncId_ The ID of the batch
    function _finalizeNextPayload(bytes32 asyncId_) internal {
        PayloadBatch storage payloadBatch = payloadBatches[asyncId_];
        uint256 currentIndex = payloadBatch.currentPayloadIndex;
        PayloadDetails[] storage payloads = payloadBatchDetails[asyncId_];

        // Find consecutive reads
        if (payloads[currentIndex].callType == CallType.READ) {
            uint256 readEndIndex = currentIndex;
            while (
                readEndIndex + 1 < payloads.length &&
                payloads[readEndIndex + 1].callType == CallType.READ
            ) {
                readEndIndex++;
            }

            // Process all reads together
            address batchPromise = IAddressResolver(addressResolver)
                .deployAsyncPromiseContract(address(this));
            isValidPromise[batchPromise] = true;

            for (uint256 i = currentIndex; i <= readEndIndex; i++) {
                bytes32 payloadId = watcherPrecompile().query(
                    payloads[i].chainSlug,
                    payloads[i].target,
                    [batchPromise, address(0)],
                    payloads[i].payload
                );
                payloadIdToBatchHash[payloadId] = asyncId_;
                emit PayloadAsyncRequested(
                    asyncId_,
                    payloadId,
                    bytes32(0),
                    payloads[i]
                );
            }

            totalPayloadsRemaining[asyncId_] -= (readEndIndex -
                currentIndex +
                1);
            payloadBatch.currentPayloadIndex = readEndIndex + 1;
            return;
        }

        // Find consecutive parallel non-read calls
        if (!payloads[currentIndex].isSequential) {
            uint256 parallelEndIndex = currentIndex;
            while (
                parallelEndIndex + 1 < payloads.length &&
                !payloads[parallelEndIndex + 1].isSequential
            ) {
                parallelEndIndex++;
            }

            // Process all parallel calls together
            address parallelPromise = IAddressResolver(addressResolver)
                .deployAsyncPromiseContract(address(this));
            isValidPromise[parallelPromise] = true;

            for (uint256 i = currentIndex; i <= parallelEndIndex; i++) {
                FinalizeParams memory finalizeParams = FinalizeParams({
                    payloadDetails: payloads[i],
                    transmitter: winningBids[asyncId_].transmitter
                });

                (bytes32 payloadId, bytes32 root) = watcherPrecompile()
                    .finalize(finalizeParams);
                payloadIdToBatchHash[payloadId] = asyncId_;
                emit PayloadAsyncRequested(
                    asyncId_,
                    payloadId,
                    root,
                    payloads[i]
                );
            }

            totalPayloadsRemaining[asyncId_] -= (parallelEndIndex -
                currentIndex +
                1);
            payloadBatch.currentPayloadIndex = parallelEndIndex + 1;
            return;
        }

        // Process single sequential call
        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloads[currentIndex],
            transmitter: winningBids[asyncId_].transmitter
        });

        (bytes32 payloadId, bytes32 root) = watcherPrecompile().finalize(
            finalizeParams
        );
        payloadIdToBatchHash[payloadId] = asyncId_;
        emit PayloadAsyncRequested(
            asyncId_,
            payloadId,
            root,
            payloads[currentIndex]
        );

        totalPayloadsRemaining[asyncId_]--;
        payloadBatch.currentPayloadIndex++;
    }
}
