// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import "solady/auth/Ownable.sol";

import "../../interfaces/IPrecompile.sol";
import {WRITE, PAYLOAD_SIZE_LIMIT} from "../../../utils/common/Constants.sol";
import {InvalidIndex, MaxMsgValueLimitExceeded, InvalidPayloadSize} from "../../../utils/common/Errors.sol";
import "../../../utils/RescueFundsLib.sol";
import "../WatcherBase.sol";
import {toBytes32Format} from "../../../utils/common/Converters.sol";

abstract contract WritePrecompileStorage is IPrecompile {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    /// @notice The fees for a write and includes callback fees
    uint256 public writeFees;

    // slot 51
    uint256 public expiryTime;

    // slot 52
    /// @notice Mapping to store watcher proofs
    /// @dev Maps payload ID to proof bytes
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    // slot 53
    /// @notice The maximum message value limit for a chain
    mapping(uint32 => uint256) public chainMaxMsgValueLimit;

    // slot 54
    /// @notice The digest hash for a payload
    mapping(bytes32 => bytes32) public digestHashes;

    // slot 55
    mapping(uint32 => bytes32) public contractFactoryPlugs;

    // slots [56-105] reserved for gap
    uint256[50] _gap_after;

    // 1 slot reserved for watcher base
}

/// @title WritePrecompile
/// @notice Handles write precompile logic
contract WritePrecompile is WritePrecompileStorage, Initializable, Ownable, WatcherBase {
    /// @notice Emitted when fees are set
    event FeesSet(uint256 writeFees);
    event ChainMaxMsgValueLimitsUpdated(uint32 chainSlug, uint256 maxMsgValueLimit);
    event ContractFactoryPlugSet(uint32 chainSlug, bytes32 contractFactoryPlug);
    /// @notice Emitted when a proof upload request is made
    event WriteProofRequested(
        address transmitter,
        bytes32 digest,
        bytes32 prevBatchDigestHash,
        uint256 deadline,
        PayloadParams payloadParams
    );

    /// @notice Emitted when a proof is uploaded
    /// @param payloadId The unique identifier for the request
    /// @param proof The proof from the watcher
    event WriteProofUploaded(bytes32 indexed payloadId, bytes proof);
    event ExpiryTimeSet(uint256 expiryTime);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    function initialize(
        address owner_,
        address watcher_,
        uint256 writeFees_,
        uint256 expiryTime_
    ) external reinitializer(1) {
        writeFees = writeFees_;
        expiryTime = expiryTime_;
        _initializeOwner(owner_);
        _initializeWatcher(watcher_);
    }

    function getPrecompileFees(bytes memory) public view returns (uint256) {
        return writeFees;
    }

    /// @notice Gets precompile data and fees for queue parameters
    /// @param queueParams_ The queue parameters to process
    /// @return precompileData The encoded precompile data
    /// @return estimatedFees Estimated fees required for processing
    function validateAndGetPrecompileData(
        QueueParams memory queueParams_,
        address appGateway_
    ) external view override returns (bytes memory precompileData, uint256 estimatedFees) {
        if (
            queueParams_.overrideParams.value >
            chainMaxMsgValueLimit[queueParams_.transaction.chainSlug]
        ) revert MaxMsgValueLimitExceeded();

        if (
            queueParams_.transaction.payload.length == 0 ||
            queueParams_.transaction.payload.length > PAYLOAD_SIZE_LIMIT
        ) {
            revert InvalidPayloadSize();
        }

        if (queueParams_.transaction.target == bytes32(0)) {
            queueParams_.transaction.target = contractFactoryPlugs[
                queueParams_.transaction.chainSlug
            ];
            appGateway_ = address(this);
        } else {
            configurations__().verifyConnections(
                queueParams_.transaction.chainSlug,
                queueParams_.transaction.target,
                appGateway_,
                queueParams_.switchboardType
            );
        }

        // todo: can be changed to set the default gas limit for each chain
        if (queueParams_.overrideParams.gasLimit == 0) {
            queueParams_.overrideParams.gasLimit = 10000000;
        }

        // For write precompile, encode the payload parameters
        precompileData = abi.encode(
            appGateway_,
            queueParams_.transaction,
            queueParams_.overrideParams.writeFinality,
            queueParams_.overrideParams.gasLimit,
            queueParams_.overrideParams.value,
            configurations__().switchboards(
                queueParams_.transaction.chainSlug,
                queueParams_.switchboardType
            )
        );

        estimatedFees = getPrecompileFees(precompileData);
    }

    /// @notice Handles payload processing and returns fees
    /// @param payloadParams The payload parameters to handle
    /// @return fees The fees required for processing
    /// @return deadline The deadline for the payload
    function handlePayload(
        address transmitter_,
        PayloadParams memory payloadParams
    )
        external
        onlyRequestHandler
        returns (uint256 fees, uint256 deadline, bytes memory precompileData)
    {
        (
            address appGateway,
            Transaction memory transaction,
            , // _writeFinality
            uint256 gasLimit,
            uint256 value,
            // bytes32 switchboard
        ) = abi.decode(
                payloadParams.precompileData,
                (address, Transaction, WriteFinality, uint256, uint256, bytes32)
            );

        precompileData = payloadParams.precompileData;
        deadline = block.timestamp + expiryTime;
        fees = getPrecompileFees(payloadParams.precompileData);

        bytes32 prevBatchDigestHash = getPrevBatchDigestHash(
            payloadParams.requestCount,
            payloadParams.batchCount
        );

        // create digest
        DigestParams memory digestParams_ = DigestParams(
            configurations__().sockets(transaction.chainSlug),
            transmitter_,
            payloadParams.payloadId,
            deadline,
            payloadParams.callType,
            gasLimit,
            value,
            transaction.payload,
            transaction.target,
            toBytes32Format(appGateway),
            prevBatchDigestHash,
            bytes("")
        );

        // Calculate and store digest from payload parameters
        bytes32 digest = getDigest(digestParams_);
        digestHashes[payloadParams.payloadId] = digest;

        emit WriteProofRequested(
            transmitter_,
            digest,
            prevBatchDigestHash,
            deadline,
            payloadParams
        );
    }

    function getPrevBatchDigestHash(
        uint40 requestCount_,
        uint40 batchCount_
    ) public view returns (bytes32) {
        if (batchCount_ == 0) return bytes32(0);

        // if first batch, return bytes32(0)
        uint40[] memory requestBatchIds = requestHandler__().getRequestBatchIds(requestCount_);
        if (requestBatchIds[0] == batchCount_) return bytes32(0);

        uint40 prevBatchCount = batchCount_ - 1;

        bytes32[] memory payloadIds = requestHandler__().getBatchPayloadIds(prevBatchCount);
        bytes32 prevBatchDigestHash = bytes32(0);
        for (uint40 i = 0; i < payloadIds.length; i++) {
            prevBatchDigestHash = keccak256(
                abi.encodePacked(prevBatchDigestHash, digestHashes[payloadIds[i]])
            );
        }
        return prevBatchDigestHash;
    }

    /// @notice Calculates the digest hash of payload parameters
    /// @dev extraData is empty for now, not needed for this EVMx
    /// @param params_ The payload parameters to calculate the digest for
    /// @return digest The calculated digest hash
    /// @dev This function creates a keccak256 hash of the payload parameters
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encodePacked(
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
                params_.prevBatchDigestHash,
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
    /// @param chainSlug_ The chain identifier
    /// @param maxMsgValueLimit_ The maximum message value limit
    function updateChainMaxMsgValueLimits(
        uint32 chainSlug_,
        uint256 maxMsgValueLimit_
    ) external onlyOwner {
        chainMaxMsgValueLimit[chainSlug_] = maxMsgValueLimit_;
        emit ChainMaxMsgValueLimitsUpdated(chainSlug_, maxMsgValueLimit_);
    }

    function setFees(uint256 writeFees_) external onlyWatcher {
        writeFees = writeFees_;
        emit FeesSet(writeFees_);
    }

    function setContractFactoryPlugs(
        uint32 chainSlug_,
        bytes32 contractFactoryPlug_
    ) external onlyOwner {
        contractFactoryPlugs[chainSlug_] = contractFactoryPlug_;
        emit ContractFactoryPlugSet(chainSlug_, contractFactoryPlug_);
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external onlyWatcher {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    function resolvePayload(
        PayloadParams calldata payloadParams_
    ) external override onlyRequestHandler {}

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
