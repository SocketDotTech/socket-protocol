// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcherPrecompile.sol";
import "../../libs/PayloadHeaderDecoder.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

/// @title Finalize
/// @notice Handles finalization precompile logic
contract Finalize is IPrecompile {
    using PayloadHeaderDecoder for bytes32;

    /// @notice The watcher precompile fees manager
    IWatcherFeesManager public immutable watcherFeesManager;

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return fees Estimated fees required for processing
    function getPrecompileData(
        QueueParams calldata queuePayloadParams_
    ) external pure returns (bytes memory precompileData, uint256 fees) {
        // For finalize precompile, encode the payload parameters
        precompileData = abi.encode(
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams
        );
        fees = watcherFeesManager.finalizeFees();
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees) {
        fees = watcherFeesManager.finalizeFees();
        emit FinalizeRequested(bytes32(0), payloadParams); // digest will be calculated in core
    }

     /// @notice Updates the maximum message value limit for multiple chains
    /// @param chainSlugs_ Array of chain identifiers
    /// @param maxMsgValueLimits_ Array of corresponding maximum message value limits
    function updateChainMaxMsgValueLimits(
        uint32[] calldata chainSlugs_,
        uint256[] calldata maxMsgValueLimits_
    ) external onlyOwner {
        if (chainSlugs_.length != maxMsgValueLimits_.length) revert InvalidIndex();

        for (uint256 i = 0; i < chainSlugs_.length; i++) {
            chainMaxMsgValueLimit[chainSlugs_[i]] = maxMsgValueLimits_[i];
        }

        emit ChainMaxMsgValueLimitsUpdated(chainSlugs_, maxMsgValueLimits_);
    }
}
