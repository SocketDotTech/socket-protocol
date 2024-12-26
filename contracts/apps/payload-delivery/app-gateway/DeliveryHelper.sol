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

            PayloadDetails storage payloadDetails = payloadDetailsArrays[
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
        uint256 currentPayloadIndex = payloadBatch.currentPayloadIndex;
        totalPayloadsRemaining[asyncId_]--;

        PayloadDetails[] storage payloads = payloadDetailsArrays[asyncId_];
        PayloadDetails storage payloadDetails = payloads[currentPayloadIndex];

        bytes32 payloadId;
        bytes32 root;

        if (payloadDetails.callType == CallType.READ) {
            // Find consecutive READ calls
            uint256 readEndIndex = currentPayloadIndex;
            while (readEndIndex + 1 < payloads.length && 
                   payloads[readEndIndex + 1].callType == CallType.READ) {
                readEndIndex++;
            }

            // Create a batched read promise
            address batchPromise = IAddressResolver(addressResolver)
                .deployAsyncPromiseContract(address(this));
            isValidPromise[batchPromise] = true;

            // Process all reads in the batch
            for (uint256 i = currentPayloadIndex; i <= readEndIndex; i++) {
                payloadId = watcherPrecompile().query(
                    payloads[i].chainSlug,
                    payloads[i].target,
                    [batchPromise, address(0)], // Use same promise for all reads in batch
                    payloads[i].payload
                );
                payloadIdToBatchHash[payloadId] = asyncId_;
            }

            // Skip the batched payloads
            payloadBatch.currentPayloadIndex = readEndIndex;
        } else {
            FinalizeParams memory finalizeParams = FinalizeParams({
                payloadDetails: payloadDetails,
                transmitter: IAuctionManager(auctionManager).winningBids(asyncId_).transmitter
            });

            (payloadId, root) = watcherPrecompile().finalize(finalizeParams);
            payloadIdToBatchHash[payloadId] = asyncId_;
            payloadBatch.currentPayloadIndex = currentPayloadIndex;
        }

        emit PayloadAsyncRequested(asyncId_, payloadId, root, payloadDetails);
    }
}
