// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./WatcherPrecompileCore.sol";

/// @title RequestHandler
/// @notice Contract that handles request submission and processing
/// @dev This contract extends WatcherPrecompileCore to provide request handling functionality
/// @dev It manages the submission of payload requests and their processing
abstract contract RequestHandler is WatcherPrecompileCore {
    using PayloadHeaderDecoder for bytes32;

    // slots [266-315] reserved for gap
    uint256[50] _request_handler_gap;

    /// @notice Submits a batch of payload requests from middleware
    /// @param payloadSubmitParams_ Array of payload submit parameters
    /// @return requestCount The unique identifier for the submitted request
    /// @dev This function processes a batch of payload requests and assigns them to batches
    /// @dev It also consumes limits for the app gateway based on the number of reads and writes
    function submitRequest(
        PayloadSubmitParams[] memory payloadSubmitParams_
    ) public returns (uint40 requestCount) {
        requestCount = nextRequestCount++;
        uint40 batchCount = nextBatchCount;
        uint40 currentBatch = batchCount;

        uint256 readCount;
        uint256 writeCount;
        PayloadSubmitParams memory lastP;

        for (uint256 i = 0; i < payloadSubmitParams_.length; i++) {
            PayloadSubmitParams memory p = payloadSubmitParams_[i];

            // Count reads and writes for checking limits
            if (p.callType == READ) {
                readCount++;
            } else writeCount++;

            // checking level number for batching
            if (i > 0) {
                if (p.levelNumber != lastP.levelNumber && p.levelNumber != lastP.levelNumber + 1)
                    revert InvalidLevelNumber();
                if (p.levelNumber == lastP.levelNumber + 1) {
                    requestBatchIds[requestCount].push(batchCount);
                    batchCount = ++nextBatchCount;
                }
            }

            batchPayloadIds[batchCount].push(payloadId);

            bytes32 payloadHeader = PayloadHeaderDecoder.createPayloadHeader(
                requestCount,
                batchCount,
                localPayloadCount,
                p.chainSlug,
                p.callType,
                p.isParallel,
                p.writeFinality
            );

            payloads[payloadId].payloadHeader = payloadHeader;
            payloads[payloadId].asyncPromise = p.asyncPromise;
            payloads[payloadId].switchboard = p.switchboard;
            payloads[payloadId].target = p.target;
            payloads[payloadId].appGateway = p.appGateway;
            payloads[payloadId].payloadId = payloadId;
            payloads[payloadId].gasLimit = p.gasLimit;
            payloads[payloadId].value = p.value;
            payloads[payloadId].readAtBlockNumber = p.readAtBlockNumber;
            payloads[payloadId].payload = p.payload;

            requestParams[requestCount].payloadParamsArray.push(payloads[payloadId]);
            lastP = p;
        }

        // Push the final batch ID to the request's batch list and increment the counter
        // This is needed because the last batch in the loop above doesn't get added since there's no next level to trigger it
        requestBatchIds[requestCount].push(nextBatchCount++);
        requestParams[requestCount].currentBatch = currentBatch;

        emit RequestSubmitted(
            msg.sender,
            requestCount,
            requestParams[requestCount].payloadParamsArray
        );
    }

    /// @notice Checks if all app gateways in the payload submit parameters are valid and same
    /// @dev It also handles special cases for the delivery helper
    /// @param payloadSubmitParams Array of payload submit parameters
    /// @return appGateway The core app gateway address
    function _checkAppGateways(
        PayloadSubmitParams[] memory payloadSubmitParams
    ) internal view returns (address appGateway) {
        // Get first app gateway and use it as reference
        address coreAppGateway = _getCoreAppGateway(msg.sender);

        // Skip first element since we already checked it
        for (uint256 i = 1; i < payloadSubmitParams.length; i++) {
            appGateway = isDeliveryHelper
                ? _getCoreAppGateway(payloadSubmitParams[i].appGateway)
                : coreAppGateway;

            if (appGateway != coreAppGateway) revert InvalidGateway();
        }
    }

    /// @notice Starts processing a request with a specified transmitter
    /// @param requestCount The request count to start processing
    /// @param transmitter_ The winning bid, contains fees, transmitter and extra data
    /// @dev This function initiates the processing of a request by a transmitter
    /// @dev It verifies that the caller is the middleware and that the request hasn't been started yet
    function startProcessingRequest(uint40 requestCount, address transmitter_) public {
        RequestParams storage r = requestParams[requestCount];
        if (r.transmitter != address(0)) revert AlreadyStarted();
        if (r.currentBatchPayloadsLeft > 0) revert AlreadyStarted();

        uint40 batchCount = r.payloadParamsArray[0].payloadHeader.getBatchCount();
        r.transmitter = transmitter_;
        r.currentBatch = batchCount;

        _processBatch(requestCount, batchCount);
    }

    /// @notice Processes a batch of payloads for a request
    /// @param requestCount_ The request count to process
    /// @param batchCount_ The batch count to process
    /// @dev This function processes all payloads in a batch, either finalizing them or querying them
    /// @dev It skips payloads that have already been executed
    function _processBatch(uint40 requestCount_, uint40 batchCount_) internal {
        RequestParams storage r = requestParams[requestCount_];
        PayloadParams[] memory payloadParamsArray = _getBatch(batchCount_);
        if (r.isRequestCancelled) revert RequestCancelled();

        uint256 totalPayloads = 0;
        for (uint40 i = 0; i < payloadParamsArray.length; i++) {
            if (isPromiseExecuted[payloadParamsArray[i].payloadId]) continue;
            totalPayloads++;

            if (payloadParamsArray[i].payloadHeader.getCallType() != CallType.READ) {
                _finalize(payloadParamsArray[i], r.transmitter);
            } else {
                _query(payloadParamsArray[i]);
            }
        }

        r.currentBatchPayloadsLeft = totalPayloads;
    }
}
