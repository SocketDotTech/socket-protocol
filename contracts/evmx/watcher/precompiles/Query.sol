// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../libs/PayloadHeaderDecoder.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

/// @title Query
/// @notice Handles query precompile logic
contract Query is IPrecompile {
    using PayloadHeaderDecoder for bytes32;

    /// @notice Emitted when a new query is requested
    event QueryRequested(PayloadParams params);

    /// @notice The watcher precompile fees manager
    IWatcherFeesManager public immutable watcherFeesManager;

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return fees Estimated fees required for processing
    function getPrecompileData(
        QueueParams calldata queuePayloadParams_
    ) external pure returns (bytes memory precompileData, uint256 fees) {
        if (queuePayloadParams_.target != address(0)) revert InvalidTarget();

        // For query precompile, encode the payload parameters
        precompileData = abi.encode(
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams.readAt
        );
        fees = watcherFeesManager.queryFees();
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees) {
        fees = watcherFeesManager.queryFees();
        emit QueryRequested(payloadParams);
    }
}
