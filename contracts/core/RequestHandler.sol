// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./WatcherPrecompileCore.sol";

/// @title RequestHandler
/// @notice Contract that handles request submission and processing
/// @dev This contract extends WatcherPrecompileCore to provide request handling functionality
/// @dev It manages the submission of payload requests and their processing
abstract contract RequestHandler is WatcherPrecompileCore {
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
