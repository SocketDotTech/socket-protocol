// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {QueueParams, PayloadParams} from "../../utils/common/Structs.sol";

/// @title IPrecompile
/// @notice Interface for precompile functionality
interface IPrecompile {
    /// @notice Gets precompile fees
    /// @param precompileData_ The precompile data
    /// @return fees The fees required for processing
    function getPrecompileFees(bytes memory precompileData_) external view returns (uint256 fees);

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queueParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return estimatedFees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams calldata queueParams_,
        address appGateway_
    ) external view returns (bytes memory precompileData, uint256 estimatedFees);

    /// @notice Handles payload processing and returns fees
    /// @param transmitter The address of the transmitter
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    /// @return deadline The deadline for processing
    /// @return precompileData The encoded precompile data
    function handlePayload(
        address transmitter,
        PayloadParams calldata payloadParams
    ) external returns (uint256 fees, uint256 deadline, bytes memory precompileData);

    /// @notice Resolves a payload
    /// @param payloadParams The payload parameters to resolve
    function resolvePayload(PayloadParams calldata payloadParams) external;
}
