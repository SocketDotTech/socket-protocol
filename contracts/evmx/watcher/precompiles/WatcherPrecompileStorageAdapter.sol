// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/ECDSA.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/LibCall.sol";
import "solady/utils/Initializable.sol";

import "../../../interfaces/IWatcherPrecompile.sol";
import "../../../interfaces/IFeesManager.sol";
import "../../../interfaces/IMiddleware.sol";
import "../../../interfaces/IPromise.sol";
import "../../PayloadHeaderDecoder.sol";
import "../../core/WatcherIdUtils.sol";
import "../../../utils/common/Structs.sol";
import "../../../utils/common/Errors.sol";
import "../../../AddressResolverUtil.sol";
import "./Finalize.sol";
import "./Timeout.sol";
import "./Query.sol";

/// @title WatcherPrecompileStorageAdapter
/// @notice Contract that manages storage and interacts with pure function libraries
/// @dev This contract serves as an adapter between the storage and the pure function libraries
contract WatcherPrecompileStorageAdapter is
    IWatcherPrecompile,
    Initializable,
    Ownable,
    AddressResolverUtil
{
    using LibCall for address;
    using PayloadHeaderDecoder for bytes32;
    using Finalize for bytes;

    // Storage variables similar to WatcherPrecompileStorage
    uint32 public evmxSlug;
    uint40 public payloadCounter;
    uint40 public override nextRequestCount;
    uint40 public nextBatchCount;
    uint256 public expiryTime;
    uint256 public maxTimeoutDelayInSeconds;
    address public appGatewayCaller;
    uint256 public timeoutIdPrefix;

    mapping(uint256 => bool) public isNonceUsed;
    mapping(bytes32 => TimeoutRequest) public timeoutRequests;
    mapping(bytes32 => bytes) public watcherProofs;
    mapping(bytes32 => bool) public appGatewayCalled;
    mapping(uint40 => RequestParams) public requestParams;
    mapping(uint40 => bytes32[]) public batchPayloadIds;
    mapping(uint40 => uint40[]) public requestBatchIds;
    mapping(bytes32 => PayloadParams) public payloads;
    mapping(bytes32 => bool) public isPromiseExecuted;
    IWatcherPrecompileLimits public watcherPrecompileLimits__;
    IWatcherPrecompileConfig public watcherPrecompileConfig__;
    mapping(uint40 => RequestMetadata) public requestMetadata;

    /// @notice Constructor that disables initializers for the implementation
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the required parameters
    /// @param owner_ The address of the owner
    /// @param addressResolver_ The address of the address resolver
    /// @param expiryTime_ The expiry time for payload execution
    /// @param evmxSlug_ The EVM chain slug
    /// @param watcherPrecompileLimits_ The address of the watcher precompile limits contract
    /// @param watcherPrecompileConfig_ The address of the watcher precompile config contract
    function initialize(
        address owner_,
        address addressResolver_,
        uint256 expiryTime_,
        uint32 evmxSlug_,
        address watcherPrecompileLimits_,
        address watcherPrecompileConfig_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);

        watcherPrecompileLimits__ = IWatcherPrecompileLimits(watcherPrecompileLimits_);
        watcherPrecompileConfig__ = IWatcherPrecompileConfig(watcherPrecompileConfig_);
        maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours
        expiryTime = expiryTime_;
        evmxSlug = evmxSlug_;

        timeoutIdPrefix = (uint256(evmxSlug_) << 224) | (uint256(uint160(address(this))) << 64);
    }

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @param delayInSeconds_ The delay in seconds before the timeout executes
    /// @param payload_ The payload data to be executed after the timeout
    /// @return The unique identifier for the timeout request
    function setTimeout(uint256 delayInSeconds_, bytes memory payload_) external returns (bytes32) {
        if (!Timeout.validateTimeoutParams(delayInSeconds_, maxTimeoutDelayInSeconds))
            revert TimeoutDelayTooLarge();

        _consumeCallbackFeesFromAddress(watcherPrecompileLimits__.timeoutFees(), msg.sender);

        uint256 executeAt = block.timestamp + delayInSeconds_;
        bytes32 timeoutId = Timeout.encodeTimeoutId(timeoutIdPrefix, payloadCounter++);

        timeoutRequests[timeoutId] = Timeout.prepareTimeoutRequest(
            msg.sender,
            delayInSeconds_,
            executeAt,
            payload_
        );

        // Emit event for watcher to track timeout and resolve when timeout is reached
        emit TimeoutRequested(timeoutId, msg.sender, payload_, executeAt);
        return timeoutId;
    }

    /// @notice Resolves a timeout
    /// @param timeoutId_ The unique identifier for the timeout
    /// @param signatureNonce_ The nonce used in the watcher's signature
    /// @param signature_ The watcher's signature
    function resolveTimeout(
        bytes32 timeoutId_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.resolveTimeout.selector, timeoutId_),
            signatureNonce_,
            signature_
        );

        TimeoutRequest storage timeoutRequest_ = timeoutRequests[timeoutId_];
        if (!Timeout.validateTimeoutResolution(timeoutRequest_, block.timestamp)) {
            if (timeoutRequest_.target == address(0)) revert InvalidTimeoutRequest();
            if (timeoutRequest_.isResolved) revert TimeoutAlreadyResolved();
            revert ResolvingTimeoutTooEarly();
        }

        (bool success, , bytes memory returnData) = timeoutRequest_.target.tryCall(
            0,
            gasleft(),
            0, // setting max_copy_bytes to 0 as not using returnData right now
            timeoutRequest_.payload
        );
        if (!success) revert CallFailed();

        timeoutRequest_.isResolved = true;
        timeoutRequest_.executedAt = block.timestamp;

        emit TimeoutResolved(
            timeoutId_,
            timeoutRequest_.target,
            timeoutRequest_.payload,
            block.timestamp,
            returnData
        );
    }

    // ================== Query functions ==================

    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    function query(PayloadParams memory params_) external {
        if (!Query.validateQueryParams(params_)) revert InvalidQueryParams();

        _consumeCallbackFeesFromRequestCount(
            watcherPrecompileLimits__.queryFees(),
            params_.payloadHeader.getRequestCount()
        );

        payloads[params_.payloadId].prevDigestsHash = _getPreviousDigestsHash(
            params_.payloadHeader.getBatchCount()
        );

        emit QueryRequested(params_);
    }

    /// @notice Marks a request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    function finalized(
        bytes32 payloadId_,
        bytes memory proof_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.finalized.selector, payloadId_, proof_),
            signatureNonce_,
            signature_
        );

        // Process finalization using the Finalize library
        if (Finalize.processFinalization(payloadId_, proof_, signature_)) {
            watcherProofs[payloadId_] = proof_;
            emit Finalized(payloadId_, proof_);
        }
    }

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    function resolvePromises(
        ResolvedPromises[] memory resolvedPromises_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.resolvePromises.selector, resolvedPromises_),
            signatureNonce_,
            signature_
        );

        for (uint256 i = 0; i < resolvedPromises_.length; i++) {
            uint40 requestCount = payloads[resolvedPromises_[i].payloadId]
                .payloadHeader
                .getRequestCount();
            RequestParams storage requestParams_ = requestParams[requestCount];

            if (Query.validatePromiseResolution(resolvedPromises_[i], requestCount)) {
                _processPromiseResolution(resolvedPromises_[i], requestParams_);
                _checkAndProcessBatch(requestParams_, requestCount);
            }
        }
    }

    // ================== Helper functions ==================

    /// @notice Sets the maximum timeout delay in seconds
    /// @param maxTimeoutDelayInSeconds_ The maximum timeout delay in seconds
    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external onlyOwner {
        maxTimeoutDelayInSeconds = maxTimeoutDelayInSeconds_;
        emit MaxTimeoutDelayInSecondsSet(maxTimeoutDelayInSeconds_);
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    /// @notice Verifies that a watcher signature is valid
    /// @param inputData_ The input data to verify
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature to verify
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

        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }

    /// @notice Process promise resolution
    function _processPromiseResolution(
        ResolvedPromises memory resolvedPromise_,
        RequestParams storage requestParams_
    ) internal {
        PayloadParams memory payloadParams = payloads[resolvedPromise_.payloadId];
        address asyncPromise = payloadParams.asyncPromise;
        uint40 requestCount = payloadParams.payloadHeader.getRequestCount();

        if (asyncPromise != address(0)) {
            bool success = IPromise(asyncPromise).markResolved(
                requestCount,
                resolvedPromise_.payloadId,
                resolvedPromise_.returnData
            );

            if (!success) {
                emit PromiseNotResolved(resolvedPromise_.payloadId, asyncPromise);
                return;
            }
        }

        isPromiseExecuted[resolvedPromise_.payloadId] = true;
        requestParams_.currentBatchPayloadsLeft--;
        requestParams_.payloadsRemaining--;

        emit PromiseResolved(resolvedPromise_.payloadId, asyncPromise);
    }

    /// @notice Check and process batch
    function _checkAndProcessBatch(
        RequestParams storage requestParams_,
        uint40 requestCount
    ) internal {
        if (requestParams_.currentBatchPayloadsLeft == 0 && requestParams_.payloadsRemaining > 0) {
            _processBatch(requestCount, ++requestParams_.currentBatch);
        }

        if (requestParams_.payloadsRemaining == 0) {
            IMiddleware(requestParams_.middleware).finishRequest(requestCount);
        }
    }

    /// @notice Process batch
    function _processBatch(uint40 requestCount_, uint40 batchCount_) internal {
        RequestParams storage r = requestParams[requestCount_];
        PayloadParams[] memory payloadParamsArray = _getBatch(batchCount_);
        if (r.isRequestCancelled) revert RequestCancelled();

        uint256 totalPayloads = 0;
        for (uint40 i = 0; i < payloadParamsArray.length; i++) {
            if (isPromiseExecuted[payloadParamsArray[i].payloadId]) continue;
            totalPayloads++;

            if (payloadParamsArray[i].payloadHeader.getCallType() != CallType.READ) {
                _finalize(payloadParamsArray[i], r.transmitter);
            } else {
                query(payloadParamsArray[i]);
            }
        }

        r.currentBatchPayloadsLeft = totalPayloads;
    }

    /// @notice Finalizes a payload request
    function _finalize(
        PayloadParams memory params_,
        address transmitter_
    ) internal returns (bytes32) {
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

        // Use the Finalize library to prepare digest parameters
        DigestParams memory digestParams = Finalize.prepareDigestParams(
            params_,
            transmitter_,
            chainSlug,
            evmxSlug,
            deadline,
            watcherPrecompileConfig__.sockets(chainSlug),
            requestParams[params_.payloadHeader.getRequestCount()].middleware,
            prevDigestsHash
        );

        // Calculate digest from payload parameters
        bytes32 digest = Finalize.getDigest(digestParams);
        emit FinalizeRequested(digest, payloads[params_.payloadId]);

        return digest;
    }

    /// @notice Gets the hash of previous batch digests
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
                WatcherIdUtils.encodeAppGatewayId(p.appGateway),
                p.prevDigestsHash
            );
            prevDigestsHash = keccak256(
                abi.encodePacked(prevDigestsHash, Finalize.getDigest(digestParams))
            );
        }
        return prevDigestsHash;
    }

    /// @notice Gets the batch of payload parameters for a given batch count
    function _getBatch(uint40 batchCount) internal view returns (PayloadParams[] memory) {
        bytes32[] memory payloadIds = batchPayloadIds[batchCount];
        PayloadParams[] memory payloadParamsArray = new PayloadParams[](payloadIds.length);

        for (uint40 i = 0; i < payloadIds.length; i++) {
            payloadParamsArray[i] = payloads[payloadIds[i]];
        }
        return payloadParamsArray;
    }

    /// @notice Consume callback fees from request count
    function _consumeCallbackFeesFromRequestCount(uint256 fees_, uint40 requestCount_) internal {
        // for callbacks in all precompiles
        uint256 feesToConsume = fees_ + watcherPrecompileLimits__.callBackFees();
        IFeesManager(addressResolver__.feesManager())
            .assignWatcherPrecompileCreditsFromRequestCount(feesToConsume, requestCount_);
    }

    /// @notice Consume callback fees from address
    function _consumeCallbackFeesFromAddress(uint256 fees_, address consumeFrom_) internal {
        // for callbacks in all precompiles
        uint256 feesToConsume = fees_ + watcherPrecompileLimits__.callBackFees();
        IFeesManager(addressResolver__.feesManager()).assignWatcherPrecompileCreditsFromAddress(
            feesToConsume,
            consumeFrom_
        );
    }
}
