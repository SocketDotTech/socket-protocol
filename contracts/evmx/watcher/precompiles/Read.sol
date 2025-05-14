// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcher.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";
import "../WatcherBase.sol";

/// @title Read
/// @notice Handles read precompile logic
contract Read is IPrecompile, WatcherBase {
    /// @notice Emitted when a new read is requested
    event ReadRequested(PayloadParams params);

    uint256 public readFees;
    uint256 public callbackFees;

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return fees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams calldata queuePayloadParams_,
        address
    ) external view returns (bytes memory precompileData, uint256 fees) {
        if (queuePayloadParams_.transaction.target != address(0)) revert InvalidTarget();
        if (queuePayloadParams_.transaction.payload.length > 0) revert InvalidPayloadSize();

        // For read precompile, encode the payload parameters
        precompileData = abi.encode(
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams.readAtBlockNumber
        );
        fees = readFees + callbackFees;
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees) {
        fees = readFees + callbackFees;
        emit ReadRequested(payloadParams);
    }

    function setFees(uint256 readFees_, uint256 callbackFees_) external onlyWatcher {
        readFees = readFees_;
        callbackFees = callbackFees_;
        emit FeesSet(readFees_, callbackFees_);
    }
}
