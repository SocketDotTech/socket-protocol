// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {InvalidIndex} from "../../../utils/common/Errors.sol";
import "../../../utils/common/Constants.sol";
import "../../interfaces/IPrecompile.sol";
import {encodeAppGatewayId} from "../../../utils/common/IdUtils.sol";

import "../WatcherBase.sol";

/// @title WritePrecompile
/// @notice Handles write precompile logic
contract WritePrecompile is IPrecompile, WatcherBase {
    /// @notice Mapping to store watcher proofs
    /// @dev Maps payload ID to proof bytes
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    /// @notice The maximum message value limit for a chain
    mapping(uint32 => uint256) public chainMaxMsgValueLimit;

    /// @notice The digest hash for a payload
    mapping(bytes32 => bytes32) public digestHashes;

    mapping(address => bool) public isContractFactoryPlug;

    /// @notice The fees for a write and includes callback fees
    uint256 public writeFees;

    error MaxMsgValueLimitExceeded();

    /// @notice Emitted when fees are set
    event FeesSet(uint256 writeFees, uint256 callbackFees);
    event ChainMaxMsgValueLimitsUpdated(uint32[] chainSlugs, uint256[] maxMsgValueLimits);
    event WriteRequested(bytes32 digest, PayloadParams payloadParams);
    event Finalized(bytes32 payloadId, bytes proof);

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queuePayloadParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return estimatedFees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams calldata queuePayloadParams_,
        address appGateway_
    ) external view returns (bytes memory precompileData, uint256 estimatedFees) {
        if (
            queuePayloadParams_.value >
            chainMaxMsgValueLimit[queuePayloadParams_.transaction.chainSlug]
        ) revert MaxMsgValueLimitExceeded();

        if (
            queuePayloadParams_.transaction.payload.length > 0 &&
            queuePayloadParams_.transaction.payload.length < PAYLOAD_SIZE_LIMIT
        ) {
            revert InvalidPayloadSize();
        }

        if (queuePayloadParams_.transaction.target == address(0)) {
            queuePayloadParams_.transaction.target = contractFactoryPlugs[
                queuePayloadParams_.transaction.chainSlug
            ];
            appGateway_ = address(this);
        } else {
            configurations__().verifyConnections(
                queuePayloadParams_.transaction.chainSlug,
                queuePayloadParams_.transaction.target,
                appGateway_,
                queuePayloadParams_.switchboardType
            );
        }

        // For write precompile, encode the payload parameters
        precompileData = abi.encode(
            appGateway_,
            queuePayloadParams_.transaction,
            queuePayloadParams_.overrideParams.writeFinality,
            queuePayloadParams_.overrideParams.gasLimit,
            queuePayloadParams_.overrideParams.value
        );

        estimatedFees = writeFees;
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    /// @return precompileData The precompile data
    function handlePayload(
        address transmitter_,
        PayloadParams calldata payloadParams
    ) external pure returns (uint256 fees, uint256 deadline) {
        fees = writeFees + callbackFees;
        deadline = block.timestamp + expiryTime;

        (
            address appGateway,
            Transaction transaction,
            WriteFinality writeFinality,
            uint256 gasLimit,
            uint256 value
        ) = abi.decode(
                payloadParams.precompileData,
                (address, Transaction, bool, uint256, uint256)
            );

        bytes32 prevBatchDigestHash = _getPrevBatchDigestHash(payloadParams);

        // create digest
        DigestParams memory digestParams_ = DigestParams(
            configManager__().sockets(transaction.chainSlug),
            transmitter_,
            payloadParams.payloadId,
            payloadParams.deadline,
            payloadParams.callType,
            gasLimit,
            value,
            transaction.payload,
            transaction.target,
            encodeAppGatewayId(appGateway),
            prevBatchDigestHash,
            bytes("")
        );

        // Calculate and store digest from payload parameters
        bytes32 digest = getDigest(digestParams_);
        digestHashes[payloadParams.payloadId] = digest;

        emit WriteProofRequested(digest, transaction, writeFinality, gasLimit, value);
    }

    function _getPrevBatchDigestHash(uint40 batchCount_) internal view returns (bytes32) {
        if (batchCount_ == 0) return bytes32(0);

        // if first batch, return bytes32(0)
        uint40[] memory requestBatchIds = requestHandler__().requestBatchIds(batchCount_);
        if (requestBatchIds[0] == batchCount_) return bytes32(0);

        uint40 prevBatchCount = batchCount_ - 1;

        bytes32[] memory payloadIds = requestHandler__().batchPayloadIds(prevBatchCount);
        bytes32 prevDigestsHash = bytes32(0);
        for (uint40 i = 0; i < payloadIds.length; i++) {
            prevDigestsHash = keccak256(
                abi.encodePacked(prevDigestsHash, digestHashes[payloadIds[i]])
            );
        }
        return prevDigestsHash;
    }

    /// @notice Calculates the digest hash of payload parameters
    /// @dev extraData is empty for now, not needed for this EVMx
    /// @param params_ The payload parameters to calculate the digest for
    /// @return digest The calculated digest hash
    /// @dev This function creates a keccak256 hash of the payload parameters
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                params_.socket,
                params_.transmitter,
                params_.payloadId,
                params_.deadline,
                params_.callType,
                params_.gasLimit,
                params_.value,
                params_.payload,
                params_.target,
                params_.appGatewayId,
                params_.prevDigestsHash,
                params_.extraData
            )
        );
    }

    /// @notice Marks a write request with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    function uploadProof(bytes32 payloadId_, bytes memory proof_) public onlyWatcher {
        watcherProofs[payloadId_] = proof_;
        emit WriteProofUploaded(payloadId_, proof_);
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

    function setFees(uint256 writeFees_) external onlyWatcher {
        writeFees = writeFees_;
        emit FeesSet(writeFees_);
    }

    function resolvePayload(PayloadParams calldata payloadParams_) external {}
}
