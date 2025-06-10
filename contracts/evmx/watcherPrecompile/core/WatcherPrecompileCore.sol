// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../../AddressResolverUtil.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import {toBytes32Format} from "../../../utils/common/Converters.sol";
import "./WatcherPrecompileStorage.sol";
import {SolanaInstruction} from "../../../utils/common/Structs.sol";
import {CHAIN_SLUG_SOLANA_MAINNET, CHAIN_SLUG_SOLANA_DEVNET} from "../../../utils/common/Constants.sol";

/// @title WatcherPrecompileCore
/// @notice Core functionality for the WatcherPrecompile system
/// @dev This contract implements the core functionality for payload verification, execution, and app configurations
/// @dev It is inherited by WatcherPrecompile and provides the base implementation for request handling
abstract contract WatcherPrecompileCore is
    IWatcherPrecompile,
    WatcherPrecompileStorage,
    Initializable,
    Ownable,
    AddressResolverUtil
{
    using PayloadHeaderDecoder for bytes32;

    // slots [216-265] reserved for gap
    uint256[50] _core_gap;

    event DigestWithSourceParams(bytes32 digest, DigestParams digestParams);

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @return timeoutId The unique identifier for the timeout request
    function _setTimeout(
        uint256 delayInSeconds_,
        bytes memory payload_
    ) internal returns (bytes32 timeoutId) {
        if (delayInSeconds_ > maxTimeoutDelayInSeconds) revert TimeoutDelayTooLarge();
        _consumeCallbackFeesFromAddress(watcherPrecompileLimits__.timeoutFees(), msg.sender);

        uint256 executeAt = block.timestamp + delayInSeconds_;
        timeoutId = _encodeTimeoutId();

        timeoutRequests[timeoutId].target = msg.sender;
        timeoutRequests[timeoutId].delayInSeconds = delayInSeconds_;
        timeoutRequests[timeoutId].executeAt = executeAt;
        timeoutRequests[timeoutId].payload = payload_;

        // emits event for watcher to track timeout and resolve when timeout is reached
        emit TimeoutRequested(timeoutId, msg.sender, payload_, executeAt);
    }

    /// @notice Finalizes a payload request and requests the watcher to release the proofs
    /// @param params_ The payload parameters to be finalized
    /// @param transmitter_ The address of the transmitter
    /// @return digest The digest hash of the finalized payload
    /// @dev This function verifies the app gateway configuration and creates a digest for the payload
    function _finalize(
        PayloadParams memory params_,
        address transmitter_  // TODO:GW: ask why transmitter has address if it is an off-chain service ?
    ) internal returns (bytes32 digest) {
        uint32 chainSlug = params_.payloadHeader.getChainSlug();

        // Verify that the app gateway is properly configured for this chain and target
        watcherPrecompileConfig__.verifyConnections(
            chainSlug,
            params_.target,
            params_.appGateway,
            params_.switchboard,
            requestParams[params_.payloadHeader.getRequestCount()].middleware
        );

        _consumeCallbackFeesFromRequestCount(
            watcherPrecompileLimits__.finalizeFees(),
            params_.payloadHeader.getRequestCount()
        );

        uint256 deadline = block.timestamp + expiryTime;
        payloads[params_.payloadId].deadline = deadline;
        payloads[params_.payloadId].finalizedTransmitter = transmitter_;

        bytes32 prevDigestsHash = _getPreviousDigestsHash(params_.payloadHeader.getBatchCount());
        payloads[params_.payloadId].prevDigestsHash = prevDigestsHash;

        // Construct parameters for digest calculation
        DigestParams memory digestParams_;
        if (_isSolanaChainSlug(chainSlug)) {
            digestParams_ = _createSolanaDigestParams(params_, transmitter_, prevDigestsHash, deadline);
        } else {
            digestParams_ = _createEvmDigestParams(params_, transmitter_, prevDigestsHash, deadline);
        }
        
        
        // Calculate digest from payload parameters
        digest = getDigest(digestParams_);

        emit DigestWithSourceParams(digest, digestParams_);

        emit FinalizeRequested(digest, payloads[params_.payloadId]);
    }

    // ================== Query functions ==================

    /// @notice Creates a new query request
    /// @param params_ The payload parameters for the query
    /// @dev This function sets up a query request and emits a QueryRequested event
    function _query(PayloadParams memory params_) internal {
        _consumeCallbackFeesFromRequestCount(
            watcherPrecompileLimits__.queryFees(),
            params_.payloadHeader.getRequestCount()
        );

        payloads[params_.payloadId].prevDigestsHash = _getPreviousDigestsHash(
            params_.payloadHeader.getBatchCount()
        );
        emit QueryRequested(params_);
    }

    // ================== Helper functions ==================

    /// @notice Calculates the digest hash of payload parameters
    /// @dev extraData is empty for now, not needed for this EVMx
    /// @param params_ The payload parameters to calculate the digest for
    /// @return digest The calculated digest hash
    /// @dev This function creates a keccak256 hash of the payload parameters
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            // TODO:GW: change into abi.encodePacked
            abi.encodePacked(
                params_.socket,
                params_.transmitter, // TODO: this later will have to moved to bytes32 format as transmitter on solana side is bytes32 address
                params_.payloadId,
                params_.deadline,
                params_.callType,
                params_.gasLimit,
                params_.value,
                params_.payload,
                params_.target,
                params_.appGatewayId,
                params_.prevDigestsHash,
                bytes("")
            )
        );
    }

    /// @notice Gets the hash of previous batch digests
    /// @param batchCount_ The batch count to get the previous digests hash
    /// @return The hash of all digests in the previous batch
    function _getPreviousDigestsHash(uint40 batchCount_) internal view returns (bytes32) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount_];
        bytes32 prevDigestsHash = bytes32(0);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            PayloadParams memory p = payloads[payloadIds[i]];
            DigestParams memory digestParams = DigestParams(
                watcherPrecompileConfig__.sockets(p.payloadHeader.getChainSlug()),
                p.finalizedTransmitter,
                p.payloadId,
                p.deadline,
                p.payloadHeader.getCallType(),
                p.gasLimit,
                p.value,
                p.payload,
                p.target,
                toBytes32Format(p.appGateway),
                p.prevDigestsHash
            );
            prevDigestsHash = keccak256(abi.encodePacked(prevDigestsHash, getDigest(digestParams)));
        }
        return prevDigestsHash;
    }

    /// @notice Gets the batch of payload parameters for a given batch count
    /// @param batchCount The batch count to get the payload parameters for
    /// @return An array of PayloadParams for the given batch
    /// @dev This function retrieves all payload parameters for a specific batch
    function _getBatch(uint40 batchCount) internal view returns (PayloadParams[] memory) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[](payloadIds.length);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            payloadParamsArray[i] = payloads[payloadIds[i]];
        }
        return payloadParamsArray;
    }

    /// @notice Encodes an ID for a timeout or payload
    /// @return The encoded ID
    /// @dev This function creates a unique ID by combining the chain slug, address, and a counter
    function _encodeTimeoutId() internal returns (bytes32) {
        // Encode timeout ID by bit-shifting and combining:
        // EVMx chainSlug (32 bits) | watcher precompile address (160 bits) | counter (64 bits)
        return bytes32(timeoutIdPrefix | payloadCounter++);
    }

    /// @notice Verifies that a watcher signature is valid
    /// @param inputData_ The input data to verify
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature to verify
    /// @dev This function verifies that the signature was created by the watcher and that the nonce has not been used before
    function _isWatcherSignatureValid(
        bytes memory inputData_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) internal {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(
            abi.encode(address(this), evmxSlug, signatureNonce_, inputData_)
        );
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }

    function _consumeCallbackFeesFromRequestCount(uint256 fees_, uint40 requestCount_) internal {
        // for callbacks in all precompiles
        uint256 feesToConsume = fees_ + watcherPrecompileLimits__.callBackFees();
        IFeesManager(addressResolver__.feesManager())
            .assignWatcherPrecompileCreditsFromRequestCount(feesToConsume, requestCount_);
    }

    function _consumeCallbackFeesFromAddress(uint256 fees_, address consumeFrom_) internal {
        // for callbacks in all precompiles
        uint256 feesToConsume = fees_ + watcherPrecompileLimits__.callBackFees();
        IFeesManager(addressResolver__.feesManager()).assignWatcherPrecompileCreditsFromAddress(
            feesToConsume,
            consumeFrom_
        );
    }

    function _createEvmDigestParams(
        PayloadParams memory params_,
        address transmitter_,
        bytes32 prevDigestsHash_,
        uint256 deadline_
    ) internal view returns (DigestParams memory) {
        return DigestParams(
            watcherPrecompileConfig__.sockets(params_.payloadHeader.getChainSlug()),
            transmitter_,
            params_.payloadId,
            deadline_,
            params_.payloadHeader.getCallType(),
            params_.gasLimit,
            params_.value,
            params_.payload,
            params_.target,
            toBytes32Format(params_.appGateway),
            prevDigestsHash_
        );
    }

    function _createSolanaDigestParams(
        PayloadParams memory params_,
        address transmitter_,
        bytes32 prevDigestsHash_,
        uint256 deadline_
    ) internal view returns (DigestParams memory) {
        SolanaInstruction memory instruction = abi.decode(params_.payload, (SolanaInstruction));
        // TODO: this is a problem, function arguments must be packed in a way that is not later touched and that can be used on Solana side in raw Instruction call
        // like a call data, so it should be Borsh encoded already here
        bytes memory functionArgsPacked;
        for (uint256 i = 0; i < instruction.data.functionArguments.length; i++) {
            uint256 abiDecodedArg = abi.decode(instruction.data.functionArguments[i], (uint256));
            // silent assumption that all arguments are uint64 to simplify the encoding
            uint64 arg = uint64(abiDecodedArg);
            bytes8 borshEncodedArg = encodeU64Borsh(arg);
            functionArgsPacked = abi.encodePacked(functionArgsPacked, borshEncodedArg);
        }
        
        bytes memory payloadPacked = abi.encodePacked(
            instruction.data.programId,
            instruction.data.accounts,
            instruction.data.instructionDiscriminator,
            functionArgsPacked
        );

        // bytes32 of Solana Socket address : 9vFEQ5e3xf4eo17WttfqmXmnqN3gUicrhFGppmmNwyqV
        bytes32 hardcodedSocket = 0x84815e8ca2f6dad7e12902c39a51bc72e13c48139b4fb10025d94e7abea2969c;
        return DigestParams(
            // watcherPrecompileConfig__.sockets(params_.payloadHeader.getChainSlug()), // TODO: this does not work, for some reason it returns 0x000.... address
            hardcodedSocket,
            transmitter_,
            params_.payloadId,
            deadline_,
            params_.payloadHeader.getCallType(),
            params_.gasLimit,
            params_.value,
            payloadPacked,
            params_.target,
            toBytes32Format(params_.appGateway),
            prevDigestsHash_
        );
    }

    function _isSolanaChainSlug(uint32 chainSlug_) internal pure returns (bool) {
        return chainSlug_ == CHAIN_SLUG_SOLANA_MAINNET || chainSlug_ == CHAIN_SLUG_SOLANA_DEVNET;
    }

    /// @notice Gets the batch IDs for a request
    /// @param requestCount_ The request count to get the batch IDs for
    /// @return An array of batch IDs for the given request
    function getBatches(uint40 requestCount_) external view returns (uint40[] memory) {
        return requestBatchIds[requestCount_];
    }

    /// @notice Gets the payload IDs for a batch
    /// @param batchCount_ The batch count to get the payload IDs for
    /// @return An array of payload IDs for the given batch
    function getBatchPayloadIds(uint40 batchCount_) external view returns (bytes32[] memory) {
        return batchPayloadIds[batchCount_];
    }

    /// @notice Gets the payload parameters for a payload ID
    /// @param payloadId_ The payload ID to get the parameters for
    /// @return The payload parameters for the given payload ID
    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return payloads[payloadId_];
    }

    // Borsh helper functions
    function encodeU64Borsh(uint64 v) public pure returns (bytes8) {
        return bytes8(swapBytes8(v));
    }

    function swapBytes8(uint64 v) internal pure returns (uint64) {
        v = ((v & 0x00ff00ff00ff00ff) << 8) | ((v & 0xff00ff00ff00ff00) >> 8);
        v = ((v & 0x0000ffff0000ffff) << 16) | ((v & 0xffff0000ffff0000) >> 16);
        return (v << 32) | (v >> 32);
    }
}
