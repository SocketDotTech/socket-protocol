// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./RequestHandler.sol";
import {LibCall} from "solady/utils/LibCall.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles request submission, iteration and execution
/// @dev This contract extends RequestHandler to provide the main functionality for the WatcherPrecompile system
/// @dev It handles timeout requests, finalization, queries, and promise resolution
contract WatcherPrecompile is RequestHandler {
    using PayloadHeaderDecoder for bytes32;
    using LibCall for address;

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
    /// @dev This function initializes the contract with the required parameters and sets up the initial state
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
    /// @dev This function creates a timeout request that will be executed after the specified `delayInSeconds_`
    /// @dev request is executed on msg.sender
    /// @dev msg sender needs SCHEDULE precompile limit
    /// @param delayInSeconds_ The delay in seconds before the timeout executes
    /// @param payload_ The payload data to be executed after the timeout
    /// @return The unique identifier for the timeout request
    function setTimeout(uint256 delayInSeconds_, bytes memory payload_) external returns (bytes32) {
        return _setTimeout(delayInSeconds_, payload_);
    }

    /// @notice Ends the timeouts and calls the target address with the callback payload
    /// @param timeoutId_ The unique identifier for the timeout
    /// @param signatureNonce_ The nonce used in the watcher's signature
    /// @param signature_ The watcher's signature
    /// @dev It verifies if the signature is valid and the timeout hasn't been resolved yet
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
        if (timeoutRequest_.target == address(0)) revert InvalidTimeoutRequest();
        if (timeoutRequest_.isResolved) revert TimeoutAlreadyResolved();
        if (block.timestamp < timeoutRequest_.executeAt) revert ResolvingTimeoutTooEarly();

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

    // ================== Finalize functions ==================

    /// @notice Finalizes a payload request, requests the watcher to release the proofs to execute on chain
    /// @param params_ The payload parameters
    /// @param transmitter_ The address of the transmitter
    /// @return The digest hash of the finalized payload
    /// @dev This function finalizes a payload request and requests the watcher to release the proofs
    function finalize(
        PayloadParams memory params_,
        address transmitter_
    ) external returns (bytes32) {
        return _finalize(params_, transmitter_);
    }

    // ================== Query functions ==================

    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    /// @dev This function creates a new query request
    function query(PayloadParams memory params_) external {
        _query(params_);
    }

    /// @notice Marks a request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev This function marks a request as finalized with a proof
    /// @dev It verifies that the signature is valid
    /// @dev Watcher signs on following digest for validation on switchboard:
    /// @dev keccak256(abi.encode(switchboard, digest))
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

        watcherProofs[payloadId_] = proof_;
        emit Finalized(payloadId_, proof_);
    }

    /// @notice Updates the transmitter for a request
    /// @param requestCount The request count to update
    /// @param transmitter The new transmitter address
    /// @dev This function updates the transmitter for a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been started yet
    function updateTransmitter(uint40 requestCount, address transmitter) public {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestCancelled();
        if (r.payloadsRemaining == 0) revert RequestAlreadyExecuted();
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert RequestNotProcessing();
        r.transmitter = transmitter;

        _processBatch(requestCount, r.currentBatch);
    }

    /// @notice Cancels a request
    /// @param requestCount The request count to cancel
    /// @dev This function cancels a request
    /// @dev It verifies that the caller is the middleware and that the request hasn't been cancelled yet
    function cancelRequest(uint40 requestCount) external {
        RequestParams storage r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestAlreadyCancelled();
        if (r.middleware != msg.sender) revert InvalidCaller();

        r.isRequestCancelled = true;
        emit RequestCancelledFromGateway(requestCount);
    }

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev This function resolves multiple promises with their return data
    /// @dev It verifies that the signature is valid
    /// @dev It also processes the next batch if the current batch is complete
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

            _processPromiseResolution(resolvedPromises_[i], requestParams_);
            _checkAndProcessBatch(requestParams_, requestCount);
        }
    }

    /// @notice Marks a request as reverting
    /// @param isRevertingOnchain_ Whether the request is reverting onchain
    /// @param payloadId_ The unique identifier of the payload
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev Only valid watcher can mark a request as reverting
    /// @dev This function marks a request as reverting if callback or payload is reverting on chain
    /// @dev Request is marked cancelled for both cases.
    function markRevert(
        bool isRevertingOnchain_,
        bytes32 payloadId_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.markRevert.selector, isRevertingOnchain_, payloadId_),
            signatureNonce_,
            signature_
        );

        PayloadParams memory payloadParams = payloads[payloadId_];
        if (payloadParams.deadline > block.timestamp) revert DeadlineNotPassedForOnChainRevert();

        RequestParams storage currentRequestParams = requestParams[
            payloadParams.payloadHeader.getRequestCount()
        ];
        currentRequestParams.isRequestCancelled = true;

        IMiddleware(currentRequestParams.middleware).handleRequestReverts(
            payloadParams.payloadHeader.getRequestCount()
        );

        if (isRevertingOnchain_ && payloadParams.asyncPromise != address(0))
            IPromise(payloadParams.asyncPromise).markOnchainRevert(
                payloadParams.payloadHeader.getRequestCount(),
                payloadId_
            );

        emit MarkedRevert(payloadId_, isRevertingOnchain_);
    }

    // ================== On-Chain Inbox ==================

    /// @notice Calls app gateways with the specified parameters
    /// @param params_ Array of call from chain parameters
    /// @param signatureNonce_ The nonce of the signature
    /// @param signature_ The signature of the watcher
    /// @dev This function calls app gateways with the specified parameters
    /// @dev It verifies that the signature is valid and that the app gateway hasn't been called yet
    function callAppGateways(
        TriggerParams[] memory params_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.callAppGateways.selector, params_),
            signatureNonce_,
            signature_
        );

        for (uint256 i = 0; i < params_.length; i++) {
            if (appGatewayCalled[params_[i].triggerId]) revert AppGatewayAlreadyCalled();

            address appGateway = _decodeAppGatewayId(params_[i].appGatewayId);
            if (
                !watcherPrecompileConfig__.isValidPlug(
                    appGateway,
                    params_[i].chainSlug,
                    params_[i].plug
                )
            ) revert InvalidCallerTriggered();

            IFeesManager(addressResolver__.feesManager()).assignWatcherPrecompileCreditsFromAddress(
                    watcherPrecompileLimits__.callBackFees(),
                    appGateway
                );

            appGatewayCaller = appGateway;
            appGatewayCalled[params_[i].triggerId] = true;

            (bool success, , ) = appGateway.tryCall(
                0,
                gasleft(),
                0, // setting max_copy_bytes to 0 as not using returnData right now
                params_[i].payload
            );
            if (!success) {
                emit AppGatewayCallFailed(params_[i].triggerId);
            } else {
                emit CalledAppGateway(params_[i].triggerId);
            }
        }

        appGatewayCaller = address(0);
    }

    // ================== Helper functions ==================

    /// @notice Sets the maximum timeout delay in seconds
    /// @param maxTimeoutDelayInSeconds_ The maximum timeout delay in seconds
    /// @dev This function sets the maximum timeout delay in seconds
    /// @dev Only callable by the contract owner
    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external onlyOwner {
        maxTimeoutDelayInSeconds = maxTimeoutDelayInSeconds_;
        emit MaxTimeoutDelayInSecondsSet(maxTimeoutDelayInSeconds_);
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    /// @notice Sets the watcher precompile limits contract
    /// @param watcherPrecompileLimits_ The address of the watcher precompile limits contract
    /// @dev This function sets the watcher precompile limits contract
    /// @dev Only callable by the contract owner
    function setWatcherPrecompileLimits(address watcherPrecompileLimits_) external onlyOwner {
        watcherPrecompileLimits__ = IWatcherPrecompileLimits(watcherPrecompileLimits_);
        emit WatcherPrecompileLimitsSet(watcherPrecompileLimits_);
    }

    /// @notice Sets the watcher precompile config contract
    /// @param watcherPrecompileConfig_ The address of the watcher precompile config contract
    /// @dev This function sets the watcher precompile config contract
    /// @dev Only callable by the contract owner
    function setWatcherPrecompileConfig(address watcherPrecompileConfig_) external onlyOwner {
        watcherPrecompileConfig__ = IWatcherPrecompileConfig(watcherPrecompileConfig_);
        emit WatcherPrecompileConfigSet(watcherPrecompileConfig_);
    }

    /// @notice Gets the request parameters for a request
    /// @param requestCount The request count to get the parameters for
    /// @return The request parameters for the given request count
    function getRequestParams(uint40 requestCount) external view returns (RequestParams memory) {
        return requestParams[requestCount];
    }

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
}
