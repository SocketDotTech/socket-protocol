// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../common/Structs.sol";
import "../common/Errors.sol";

/// @title RequestQueueLib
/// @notice Pure function library for processing and validating payload request batches
/// @dev Extracted from RequestQueue contract, with storage operations removed
library RequestQueueLib {
    /// @notice Validates a batch of payloads
    /// @param payloadCount The number of payloads in the batch
    /// @param maxPayloadCount The maximum number of payloads allowed
    /// @return isValid Whether the batch is valid
    function validateBatch(
        uint256 payloadCount,
        uint256 maxPayloadCount
    ) public pure returns (bool isValid) {
        return payloadCount <= maxPayloadCount;
    }

    /// @notice Analyzes an array of queue payload params and creates payload submit params
    /// @param queuePayloadParams An array of queue payload params
    /// @return payloadSubmitParams The resulting array of payload submit params
    /// @return onlyReadRequests Whether the batch contains only read requests
    /// @return queryCount The number of query (read) operations
    /// @return finalizeCount The number of finalize (write) operations
    function createPayloadSubmitParams(
        QueuePayloadParams[] memory queuePayloadParams
    )
        public
        pure
        returns (
            PayloadSubmitParams[] memory payloadSubmitParams,
            bool onlyReadRequests,
            uint256 queryCount,
            uint256 finalizeCount
        )
    {
        if (queuePayloadParams.length == 0) {
            return (new PayloadSubmitParams[](0), true, 0, 0);
        }

        payloadSubmitParams = new PayloadSubmitParams[](queuePayloadParams.length);
        onlyReadRequests = queuePayloadParams[0].callType == CallType.READ;

        uint256 currentLevel = 0;
        for (uint256 i = 0; i < queuePayloadParams.length; i++) {
            if (queuePayloadParams[i].callType == CallType.READ) {
                queryCount++;
            } else {
                onlyReadRequests = false;
                finalizeCount++;
            }

            // Update level for calls
            if (i > 0 && queuePayloadParams[i].isParallel != Parallel.ON) {
                currentLevel = currentLevel + 1;
            }

            payloadSubmitParams[i] = createPayloadDetails(currentLevel, queuePayloadParams[i]);
        }
    }

    /// @notice Creates the payload details for a given level and queue params
    /// @param level The level number for parallel execution
    /// @param queueParams The queue payload parameters
    /// @return payloadDetails The payload submit parameters
    function createPayloadDetails(
        uint256 level,
        QueuePayloadParams memory queueParams
    ) public pure returns (PayloadSubmitParams memory payloadDetails) {
        // Skip deploy case - we're ignoring deploy-related functions

        return
            PayloadSubmitParams({
                levelNumber: level,
                chainSlug: queueParams.chainSlug,
                callType: queueParams.callType,
                isParallel: queueParams.isParallel,
                writeFinality: queueParams.writeFinality,
                asyncPromise: queueParams.asyncPromise,
                switchboard: queueParams.switchboard,
                target: queueParams.target,
                appGateway: queueParams.appGateway,
                gasLimit: queueParams.gasLimit == 0 ? 10_000_000 : queueParams.gasLimit,
                value: queueParams.value,
                readAt: queueParams.readAt,
                payload: queueParams.payload
            });
    }

    /// @notice Calculates fees needed for a batch
    /// @param queryCount Number of read operations
    /// @param finalizeCount Number of write operations
    /// @param baseQueryFee Base fee for query operations
    /// @param baseFinalizeFee Base fee for finalize operations
    /// @return totalFees The total fees required
    function calculateRequiredFees(
        uint256 queryCount,
        uint256 finalizeCount,
        uint256 baseQueryFee,
        uint256 baseFinalizeFee
    ) public pure returns (uint256 totalFees) {
        return (queryCount * baseQueryFee) + (finalizeCount * baseFinalizeFee);
    }

    /// @notice Determines if the batch should be processed immediately
    /// @param onlyReadRequests Whether the batch contains only read requests
    /// @return shouldProcessImmediately Whether the batch should be processed immediately
    function shouldProcessImmediately(
        bool onlyReadRequests
    ) public pure returns (bool shouldProcessImmediately) {
        return onlyReadRequests;
    }

    /// @notice Validates payload values against chain limits
    /// @param payloadParams Array of payload parameters
    /// @param chainValueLimits Mapping of chain slug to max value limit
    /// @return isValid Whether all values are valid
    function validatePayloadValues(
        PayloadSubmitParams[] memory payloadParams,
        mapping(uint32 => uint256) storage chainValueLimits
    ) public view returns (bool isValid) {
        for (uint256 i = 0; i < payloadParams.length; i++) {
            uint32 chainSlug = payloadParams[i].chainSlug;
            uint256 value = payloadParams[i].value;

            if (value > chainValueLimits[chainSlug]) {
                return false;
            }
        }
        return true;
    }

    /// @notice Creates batch parameters from payload analysis
    /// @param appGateway The application gateway address
    /// @param auctionManager The auction manager address
    /// @param maxFees The maximum fees allowed
    /// @param onCompleteData Data to be used on batch completion
    /// @param queryCount Number of read operations
    /// @param finalizeCount Number of write operations
    /// @param onlyReadRequests Whether the batch contains only read requests
    /// @return batchParams The batch parameters
    function createBatchParams(
        address appGateway,
        address auctionManager,
        uint256 maxFees,
        bytes memory onCompleteData,
        uint256 queryCount,
        uint256 finalizeCount,
        bool onlyReadRequests
    ) public pure returns (BatchParams memory batchParams) {
        return
            BatchParams({
                appGateway: appGateway,
                auctionManager: auctionManager,
                maxFees: maxFees,
                onCompleteData: onCompleteData,
                onlyReadRequests: onlyReadRequests,
                queryCount: queryCount,
                finalizeCount: finalizeCount
            });
    }

    /// @notice Creates request metadata
    /// @param params The batch parameters
    /// @param consumeFrom Address to consume fees from
    /// @return metadata The request metadata
    function createRequestMetadata(
        BatchParams memory params,
        address consumeFrom
    ) public pure returns (RequestMetadata memory metadata) {
        return
            RequestMetadata({
                appGateway: params.appGateway,
                auctionManager: params.auctionManager,
                maxFees: params.maxFees,
                winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
                onCompleteData: params.onCompleteData,
                onlyReadRequests: params.onlyReadRequests,
                consumeFrom: consumeFrom,
                queryCount: params.queryCount,
                finalizeCount: params.finalizeCount
            });
    }
}
