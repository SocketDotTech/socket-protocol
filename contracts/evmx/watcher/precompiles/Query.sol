// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../libs/PayloadHeaderDecoder.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

/// @title Query
/// @notice Library that handles query logic for the WatcherPrecompile system
/// @dev This library contains pure functions for query operations
library Query {
    using PayloadHeaderDecoder for bytes32;

    /// @notice Validates query parameters
    /// @param params_ The payload parameters for the query
    /// @return isValid Whether the query parameters are valid
    function validateQueryParams(PayloadParams memory params_) public pure returns (bool isValid) {
        // Query is valid if it has a valid payload ID and target
        return params_.payloadId != bytes32(0) && params_.target != address(0);
    }

    /// @notice Prepares the batch of payload parameters for a given batch count
    /// @param payloadParams Array of payload parameters to process
    /// @return An array of validated PayloadParams for the batch
    function prepareBatch(
        PayloadParams[] memory payloadParams
    ) public pure returns (PayloadParams[] memory) {
        // Batch logic would normally involve storage interactions
        // This function provides the pure logic for preparation
        return payloadParams;
    }

    /// @notice Creates the event data for a query request
    /// @param params_ The payload parameters for the query
    /// @return The encoded event data for query request
    function createQueryRequestEventData(
        PayloadParams memory params_
    ) public pure returns (bytes memory) {
        return abi.encode(params_);
    }

    /// @notice Validates batch parameters for query processing
    /// @param batchCount The batch count to validate
    /// @param requestCount The request count to validate
    /// @return isValid Whether the batch parameters are valid
    function validateBatchParams(
        uint40 batchCount,
        uint40 requestCount
    ) public pure returns (bool isValid) {
        return batchCount > 0 && requestCount > 0;
    }

    /// @notice Prepares parameters for batch processing
    /// @param payloadParamsArray Array of payload parameters
    /// @param batchSize The size of the batch
    /// @return totalPayloads The number of payloads to process
    function prepareBatchProcessing(
        PayloadParams[] memory payloadParamsArray,
        uint256 batchSize
    ) public pure returns (uint256 totalPayloads) {
        // Validate and count payloads that should be processed
        uint256 total = 0;
        for (uint256 i = 0; i < payloadParamsArray.length && i < batchSize; i++) {
            if (validateQueryParams(payloadParamsArray[i])) {
                total++;
            }
        }
        return total;
    }
}
