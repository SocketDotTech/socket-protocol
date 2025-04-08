// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./RequestHandler.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract WatcherPrecompile is RequestHandler {
    using DumpDecoder for bytes32;

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initial initialization (version 1)
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
    }

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @param payload_ The payload data
    /// @param delayInSeconds_ The delay in seconds
    function setTimeout(
        uint256 delayInSeconds_,
        bytes calldata payload_
    ) external returns (bytes32) {
        return _setTimeout(payload_, delayInSeconds_);
    }

    /// @notice Ends the timeouts and calls the target address with the callback payload
    /// @param timeoutId_ The unique identifier for the timeout
    /// @dev Only callable by the contract owner
    function resolveTimeout(
        bytes32 timeoutId_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.resolveTimeout.selector, timeoutId_),
            signatureNonce_,
            signature_
        );

        TimeoutRequest storage timeoutRequest_ = timeoutRequests[timeoutId_];
        if (timeoutRequest_.target == address(0)) revert InvalidTimeoutRequest();
        if (timeoutRequest_.isResolved) revert TimeoutAlreadyResolved();
        if (block.timestamp < timeoutRequest_.executeAt) revert ResolvingTimeoutTooEarly();

        (bool success, ) = address(timeoutRequest_.target).call(timeoutRequest_.payload);
        if (!success) revert CallFailed();

        timeoutRequest_.isResolved = true;
        timeoutRequest_.executedAt = block.timestamp;

        emit TimeoutResolved(
            timeoutId_,
            timeoutRequest_.target,
            timeoutRequest_.payload,
            block.timestamp
        );
    }

    // ================== Finalize functions ==================

    /// @notice Finalizes a payload request, requests the watcher to release the proofs to execute on chain
    /// @param params_ The payload parameters
    /// @param transmitter_ The address of the transmitter
    function finalize(
        PayloadParams memory params_,
        address transmitter_
    ) external returns (bytes32 digest) {
        digest = _finalize(params_, transmitter_);
    }

    // ================== Query functions ==================
    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    function query(PayloadParams memory params_) external {
        _query(params_);
    }

    /// @notice Marks a request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev Only callable by the contract owner
    /// @dev Watcher signs on following digest for validation on switchboard:
    /// @dev keccak256(abi.encode(switchboard, digest))
    function finalized(
        bytes32 payloadId_,
        bytes calldata proof_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.finalized.selector, payloadId_, proof_),
            signatureNonce_,
            signature_
        );

        watcherProofs[payloadId_] = proof_;
        emit Finalized(payloadId_, proof_);
    }

    function updateTransmitter(uint40 requestCount, address transmitter) public {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestCancelled();
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert AlreadyStarted();

        r.transmitter = transmitter;
        /// todo: recheck limits
        _processBatch(requestCount, r.currentBatch);
    }

    function cancelRequest(uint40 requestCount) external {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestAlreadyCancelled();
        if (r.middleware != msg.sender) revert InvalidCaller();

        r.isRequestCancelled = true;
    }

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @dev Only callable by the contract owner
    function resolvePromises(
        ResolvedPromises[] calldata resolvedPromises_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.resolvePromises.selector, resolvedPromises_),
            signatureNonce_,
            signature_
        );

        for (uint256 i = 0; i < resolvedPromises_.length; i++) {
            // Get the array of promise addresses for this payload
            PayloadParams memory payloadParams = payloads[resolvedPromises_[i].payloadId];
            address asyncPromise = payloadParams.asyncPromise;
            if (asyncPromise == address(0)) continue;

            // Resolve each promise with its corresponding return data
            bool success = IPromise(asyncPromise).markResolved(
                payloadParams.dump.getRequestCount(),
                resolvedPromises_[i].payloadId,
                resolvedPromises_[i].returnData
            );

            isPromiseExecuted[resolvedPromises_[i].payloadId] = true;
            if (!success) {
                emit PromiseNotResolved(resolvedPromises_[i].payloadId, asyncPromise);
                continue;
            }

            RequestParams storage requestParams_ = requestParams[
                payloadParams.dump.getRequestCount()
            ];

            requestParams_.currentBatchPayloadsLeft--;
            requestParams_.payloadsRemaining--;

            if (
                requestParams_.currentBatchPayloadsLeft == 0 && requestParams_.payloadsRemaining > 0
            ) {
                uint256 totalPayloadsLeft = _processBatch(
                    payloadParams.dump.getRequestCount(),
                    ++requestParams_.currentBatch
                );
                requestParams_.currentBatchPayloadsLeft = totalPayloadsLeft;
            }

            if (requestParams_.payloadsRemaining == 0) {
                IMiddleware(requestParams_.middleware).finishRequest(
                    payloadParams.dump.getRequestCount()
                );
            }
            emit PromiseResolved(resolvedPromises_[i].payloadId, asyncPromise);
        }
    }

    // wait till expiry time to assign fees
    function markRevert(
        bool isRevertingOnchain_,
        bytes32 payloadId_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.markRevert.selector, isRevertingOnchain_, payloadId_),
            signatureNonce_,
            signature_
        );

        PayloadParams storage payloadParams = payloads[payloadId_];
        if (payloadParams.deadline > block.timestamp) revert DeadlineNotPassedForOnChainRevert();

        RequestParams storage currentRequestParams = requestParams[
            payloadParams.dump.getRequestCount()
        ];
        currentRequestParams.isRequestCancelled = true;

        if (isRevertingOnchain_)
            IPromise(payloadParams.asyncPromise).markOnchainRevert(
                payloadParams.dump.getRequestCount(),
                payloadId_
            );

        IMiddleware(currentRequestParams.middleware).handleRequestReverts(
            payloadParams.dump.getRequestCount()
        );

        emit MarkedRevert(payloadId_, isRevertingOnchain_);
    }

    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external onlyOwner {
        maxTimeoutDelayInSeconds = maxTimeoutDelayInSeconds_;
    }

    // ================== On-Chain Trigger ==================

    function callAppGateways(
        TriggerParams[] calldata params_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.callAppGateways.selector, params_),
            signatureNonce_,
            signature_
        );

        for (uint256 i = 0; i < params_.length; i++) {
            if (appGatewayCalled[params_[i].triggerId]) revert AppGatewayAlreadyCalled();

            address appGateway = _decodeAppGateway(params_[i].triggerId);
            if (
                !watcherPrecompileConfig__.isValidPlug(
                    appGateway,
                    params_[i].chainSlug,
                    params_[i].plug
                )
            ) revert InvalidCallerTriggered();

            appGatewayCaller = appGateway;
            appGatewayCalled[params_[i].triggerId] = true;

            (bool success, ) = address(appGateway).call(params_[i].payload);
            if (!success) {
                emit AppGatewayCallFailed(params_[i].triggerId);
            } else {
                emit CalledAppGateway(params_[i].triggerId);
            }
        }

        appGatewayCaller = address(0);
    }

    // ================== Helper functions ==================

    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
    }

    function getRequestParams(uint40 requestCount) external view returns (RequestParams memory) {
        return requestParams[requestCount];
    }

    function _decodeAppGateway(bytes32 triggerId_) internal pure returns (address) {
        return address(uint160(uint256(triggerId_) >> 64));
    }
}
