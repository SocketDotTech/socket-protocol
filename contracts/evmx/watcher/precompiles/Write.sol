// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../interfaces/IWatcher.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";

import "../WatcherBase.sol";

/// @title Write
/// @notice Handles write precompile logic
contract Write is IPrecompile, WatcherBase {
    /// @notice Mapping to store watcher proofs
    /// @dev Maps payload ID to proof bytes
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    uint256 public writeFees;
    uint256 public callbackFees;

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return fees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams calldata queuePayloadParams_,
        address appGateway_
    ) external view returns (bytes memory precompileData, uint256 fees) {
        if (queuePayloadParams_.value > chainMaxMsgValueLimit[queuePayloadParams_.chainSlug])
            revert MaxMsgValueLimitExceeded();

        if (queuePayloadParams_.transaction.target != address(0)) {
            revert InvalidTarget();
        }

        if (
            queuePayloadParams_.transaction.payload.length > 0 &&
            queuePayloadParams_.transaction.payload.length < PAYLOAD_SIZE_LIMIT
        ) {
            revert InvalidPayloadSize();
        }

        configurations__().verifyConnections(
            queuePayloadParams_.chainSlug,
            queuePayloadParams_.transaction.target,
            appGateway_,
            queuePayloadParams_.switchboardType
        );

        // For write precompile, encode the payload parameters
        precompileData = abi.encode(
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams.writeFinality,
            queuePayloadParams_.overrideParams.gasLimit,
            queuePayloadParams_.overrideParams.value
        );

        fees = writeFees + callbackFees;
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    function handlePayload(
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees) {
        fees = writeFees + callbackFees;
        emit WriteRequested(payloadParams);
    }

    /// @notice Marks a write request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    function finalize(bytes32 payloadId_, bytes memory proof_) public onlyWatcher {
        watcherProofs[payloadId_] = proof_;
        emit Finalized(payloadId_, proof_);
    }

    /// @notice Updates the maximum message value limit for multiple chains
    /// @param chainSlugs_ Array of chain identifiers
    /// @param maxMsgValueLimits_ Array of corresponding maximum message value limits
    function updateChainMaxMsgValueLimits(
        uint32[] calldata chainSlugs_,
        uint256[] calldata maxMsgValueLimits_
    ) external onlyWatcher {
        if (chainSlugs_.length != maxMsgValueLimits_.length) revert InvalidIndex();

        for (uint256 i = 0; i < chainSlugs_.length; i++) {
            chainMaxMsgValueLimit[chainSlugs_[i]] = maxMsgValueLimits_[i];
        }

        emit ChainMaxMsgValueLimitsUpdated(chainSlugs_, maxMsgValueLimits_);
    }

    function setFees(uint256 writeFees_, uint256 callbackFees_) external onlyWatcher {
        writeFees = writeFees_;
        callbackFees = callbackFees_;
        emit FeesSet(writeFees_, callbackFees_);
    }
}
