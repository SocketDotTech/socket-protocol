// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./RequestHandler.sol";
import "../../interfaces/IMiddleware.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract WatcherPrecompile is RequestHandler {
    error RequestAlreadyCancelled();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initial initialization (version 1)
    function initialize(
        address owner_,
        address addressResolver_,
        uint256 defaultLimit_,
        uint256 expiryTime_,
        uint32 evmxSlug_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
        maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours
        expiryTime = expiryTime_;

        // limit per day
        defaultLimit = defaultLimit_ * 10 ** LIMIT_DECIMALS;
        // limit per second
        defaultRatePerSecond = defaultLimit / (24 * 60 * 60);

        evmxSlug = evmxSlug_;
    }

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @param payload_ The payload data
    /// @param delayInSeconds_ The delay in seconds
    function setTimeout(
        address appGateway_,
        uint256 delayInSeconds_,
        bytes calldata payload_
    ) external {
        _setTimeout(appGateway_, payload_, delayInSeconds_);
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
    ) external returns (bytes32 payloadId, bytes32 digest) {
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
        RequestParams memory r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestCancelled();
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert AlreadyStarted();

        r.transmitter = transmitter;
        /// todo: recheck limits
        _processBatch(requestCount, r.currentBatch);
    }

    function cancelRequest(uint40 requestCount) public {
        RequestParams memory r = requestParams[requestCount];
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
                payloadParams.requestCount,
                resolvedPromises_[i].payloadId,
                resolvedPromises_[i].returnData
            );

            if (!success) {
                emit PromiseNotResolved(resolvedPromises_[i].payloadId, success, asyncPromise);
                continue;
            }

            RequestParams storage requestParams_ = requestParams[payloadParams.requestCount];
            requestParams_.currentBatchPayloadsLeft--;

            if (requestParams_.currentBatchPayloadsLeft == 0) {
                IMiddleware(requestParams_.middleware).finishRequest(payloadParams.requestCount);
            }
            emit PromiseResolved(resolvedPromises_[i].payloadId, success, asyncPromise);
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
        RequestParams storage requestParams = requestParams[payloadParams.requestCount];
        requestParams.isRequestCancelled = true;

        if (isRevertingOnchain_)
            IPromise(payloadParams.asyncPromise).markOnchainRevert(
                payloadParams.requestCount,
                payloadId_
            );

        // assign fees after expiry time
        IFeesManager(payloadParams.appGateway).unblockAndAssignFees(
            payloadParams.requestCount,
            payloadParams.transmitter,
            payloadParams.appGateway
        );
    }

    function setMaxTimeoutDelayInSeconds(uint256 maxTimeoutDelayInSeconds_) external onlyOwner {
        maxTimeoutDelayInSeconds = maxTimeoutDelayInSeconds_;
    }

    // ================== On-Chain Inbox ==================

    function callAppGateways(
        CallFromChainParams[] calldata params_,
        uint256 signatureNonce_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(this.callAppGateways.selector, params_),
            signatureNonce_,
            signature_
        );

        for (uint256 i = 0; i < params_.length; i++) {
            if (appGatewayCalled[params_[i].callId]) revert AppGatewayAlreadyCalled();
            if (!isValidPlug[params_[i].appGateway][params_[i].chainSlug][params_[i].plug])
                revert InvalidInboxCaller();

            appGatewayCalled[params_[i].callId] = true;
            IAppGateway(params_[i].appGateway).callFromChain(
                params_[i].chainSlug,
                params_[i].plug,
                params_[i].payload,
                params_[i].params
            );

            emit CalledAppGateway(
                params_[i].callId,
                params_[i].chainSlug,
                params_[i].plug,
                params_[i].appGateway,
                params_[i].params,
                params_[i].payload
            );
        }
    }

    // ================== Helper functions ==================

    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
    }
}
