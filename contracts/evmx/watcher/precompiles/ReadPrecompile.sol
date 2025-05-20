// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IPrecompile.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";
import "../WatcherBase.sol";

/// @title Read
/// @notice Handles read precompile logic
contract ReadPrecompile is IPrecompile, WatcherBase {
    /// @notice Emitted when a new read is requested
    event ReadRequested(PayloadParams params);

    /// @notice The fees for a read and includes callback fees
    uint256 public readFees;

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return estimatedFees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams calldata queuePayloadParams_,
        address
    ) external view returns (bytes memory precompileData, uint256 estimatedFees) {
        if (queuePayloadParams_.transaction.target != address(0)) revert InvalidTarget();
        if (queuePayloadParams_.transaction.payload.length > 0) revert InvalidPayloadSize();

        // For read precompile, encode the payload parameters
        precompileData = abi.encode(
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams.readAtBlockNumber
        );
        estimatedFees = readFees;
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        address,
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees) {
        fees = readFees;

        (Transaction memory transaction, uint256 readAtBlockNumber) = abi.decode(
            payloadParams.precompileData,
            (Transaction, uint256)
        );
        emit ReadRequested(transaction, readAtBlockNumber, payloadParams.payloadId);
    }

    function setFees(uint256 readFees_) external onlyWatcher {
        readFees = readFees_;
        emit FeesSet(readFees_);
    }
}
