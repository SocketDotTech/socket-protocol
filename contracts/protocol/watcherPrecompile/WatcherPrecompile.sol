// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./RequestHandler.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract WatcherPrecompile is RequestHandler {
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
        bytes calldata payload_,
        uint256 delayInSeconds_
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
    /// @param params_ The finalization parameters
    /// @return payloadId The unique identifier for the finalized request
    /// @return digest The digest of the payload parameters
    function finalize(
        address originAppGateway_,
        FinalizeParams memory params_
    ) external returns (bytes32 payloadId, bytes32 digest) {
        digest = _finalize(payloadId, originAppGateway_, params_);
    }

    // ================== Query functions ==================
    /// @notice Creates a new query request
    /// @param chainSlug_ The identifier of the destination chain
    /// @param targetAddress_ The address of the target contract
    /// @param asyncPromises_ Array of promise addresses to be resolved
    /// @param payload_ The query payload data
    /// @return payloadId The unique identifier for the query
    function query(
        uint32 chainSlug_,
        address targetAddress_,
        address appGateway_,
        address[] memory asyncPromises_,
        bytes memory payload_,
        uint256 readAt_
    ) internal returns (bytes32) {
        return _query(chainSlug_, targetAddress_, appGateway_, asyncPromises_, payload_, readAt_);
    }

    /// @notice Marks a request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
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
        emit Finalized(payloadId_, asyncRequests[payloadId_], proof_);
    }

    function updateTransmitter(uint40 requestCount, address transmitter) public {
        RequestParams r = requestParams[requestCount];
        if (r.isRequestCancelled) revert RequestCancelled();
        if (r.middleware != msg.sender) revert InvalidCaller();
        if (r.transmitter != address(0)) revert AlreadyStarted();

        r.transmitter = transmitter;
        /// todo: recheck limits
        _processBatch(requestCount, r.currentBatchCount);
    }

    function cancelRequest(uint40 requestCount) public {
        RequestParams r = requestParams[requestCount];
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
            AsyncRequest memory asyncRequest_ = asyncRequests[resolvedPromises_[i].payloadId];
            address[] memory next = asyncRequest_.next;

            // Resolve each promise with its corresponding return data
            bool success;
            for (uint256 j = 0; j < next.length; j++) {
                if (next[j] == address(0)) continue;
                success = IPromise(next[j]).markResolved(
                    asyncRequest_.asyncId,
                    resolvedPromises_[i].payloadId,
                    resolvedPromises_[i].returnData[j]
                );

                if (!success) {
                    emit PromiseNotResolved(resolvedPromises_[i].payloadId, success, next[j]);
                    break;
                } else {
                    emit PromiseResolved(resolvedPromises_[i].payloadId, success, next[j]);
                }
            }
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

        AsyncRequest memory asyncRequest_ = asyncRequests[payloadId_];
        address[] memory next = asyncRequest_.next;

        for (uint256 j = 0; j < next.length; j++) {
            if (isRevertingOnchain_)
                IPromise(next[j]).markOnchainRevert(asyncRequest_.asyncId, payloadId_);

            // assign fees after expiry time
            IFeesManager(asyncRequest_.appGateway).unblockAndAssignFees(
                asyncRequest_.asyncId,
                asyncRequest_.transmitter,
                asyncRequest_.appGateway
            );

            // batch.isRequestCancelled
        }
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
