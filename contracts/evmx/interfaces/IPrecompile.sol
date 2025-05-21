// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../utils/common/Structs.sol";

/// @title IPrecompile
/// @notice Interface for precompile functionality
interface IPrecompile {
    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return fees Estimated fees required for processing
    function getPrecompileData(
        QueueParams calldata queuePayloadParams_
    ) external returns (bytes memory precompileData, uint256 fees);

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(PayloadParams calldata payloadParams) external returns (uint256 fees);
}
