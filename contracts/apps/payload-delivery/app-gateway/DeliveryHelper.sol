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
    function _startBatchProcessing(bytes32 asyncId_) internal {
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
            IFeesManager(feesManager).createFeesSignature(
                asyncId,
                payloadBatch.appGateway,
                payloadBatch.feesData,
                winningBids[asyncId]
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
            payloadId = watcherPrecompile().query(
                payloadDetails.chainSlug,
                payloadDetails.target,
                payloadDetails.next,
                payloadDetails.payload
            );
            payloadIdToBatchHash[payloadId] = asyncId_;
        } else {
            FinalizeParams memory finalizeParams = FinalizeParams({
                payloadDetails: payloadDetails,
                transmitter: winningBids[asyncId_].transmitter
            });

            (payloadId, root) = watcherPrecompile().finalize(finalizeParams);
            payloadIdToBatchHash[payloadId] = asyncId_;
        }

        emit PayloadAsyncRequested(asyncId_, payloadId, root, payloadDetails);
    }

}
