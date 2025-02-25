// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileConfig.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract WatcherPrecompile is WatcherPrecompileConfig {
    /// @notice Error thrown when an invalid chain slug is provided
    error InvalidChainSlug();
    /// @notice Error thrown when an invalid app gateway reaches a plug
    error InvalidConnection();
    /// @notice Error thrown if winning bid is assigned to an invalid transmitter
    error InvalidTransmitter();
    /// @notice Error thrown when a timeout request is invalid
    error InvalidTimeoutRequest();
    /// @notice Error thrown when a payload id is invalid
    error InvalidPayloadId();
    /// @notice Error thrown when a caller is invalid
    error InvalidCaller();

    event CalledAppGateway(
        bytes32 callId,
        uint32 chainSlug,
        address plug,
        address appGateway,
        bytes32 params,
        bytes payload
    );

    /// @notice Emitted when a new query is requested
    /// @param chainSlug The identifier of the destination chain
    /// @param targetAddress The address of the target contract
    /// @param payloadId The unique identifier for the query
    /// @param payload The query data
    event QueryRequested(uint32 chainSlug, address targetAddress, bytes32 payloadId, bytes payload);

    /// @notice Emitted when a finalize request is made
    /// @param payloadId The unique identifier for the request
    /// @param asyncRequest The async request details
    event FinalizeRequested(bytes32 indexed payloadId, AsyncRequest asyncRequest);

    /// @notice Emitted when a request is finalized
    /// @param payloadId The unique identifier for the request
    /// @param asyncRequest The async request details
    /// @param proof The proof from the watcher
    event Finalized(bytes32 indexed payloadId, AsyncRequest asyncRequest, bytes proof);

    /// @notice Emitted when a promise is resolved
    /// @param payloadId The unique identifier for the resolved promise
    event PromiseResolved(bytes32 indexed payloadId, bool success, address asyncPromise);

    /// @notice Emitted when a promise is not resolved
    /// @param payloadId The unique identifier for the not resolved promise
    event PromiseNotResolved(bytes32 indexed payloadId, bool success, address asyncPromise);

    event TimeoutRequested(
        bytes32 timeoutId,
        address target,
        bytes payload,
        uint256 executeAt // Epoch time when the task should execute
    );

    /// @notice Emitted when a timeout is resolved
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the timeout
    /// @param payload The payload data
    /// @param executedAt The epoch time when the task was executed
    event TimeoutResolved(bytes32 timeoutId, address target, bytes payload, uint256 executedAt);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initial initialization (version 1)
    function initialize(
        address owner_,
        address addressResolver_,
        uint256 defaultLimit_,
        uint256 expiryTime_,
        uint32 evmxChainSlug_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
        maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours
        expiryTime = expiryTime_;

        // limit per day
        defaultLimit = defaultLimit_ * 10 ** LIMIT_DECIMALS;
        // limit per second
        defaultRatePerSecond = defaultLimit / (24 * 60 * 60);

        evmxChainSlug = evmxChainSlug_;
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
        if (delayInSeconds_ > maxTimeoutDelayInSeconds) revert TimeoutDelayTooLarge();

        // from auction manager
        _consumeLimit(appGateway_, SCHEDULE, 1);
        uint256 executeAt = block.timestamp + delayInSeconds_;
        bytes32 timeoutId = _encodeId(evmxChainSlug, address(this));
        timeoutRequests[timeoutId] = TimeoutRequest(
            timeoutId,
            msg.sender,
            delayInSeconds_,
            executeAt,
            0,
            false,
            payload_
        );
        emit TimeoutRequested(timeoutId, msg.sender, payload_, executeAt);
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
            signatureNonce_,
            keccak256(abi.encode(address(this), evmxChainSlug, signatureNonce_, timeoutId_)),
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
        // Generate a unique payload ID by combining chain, target, and counter
        payloadId = _encodeWritePayloadId(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target
        );

        digest = _finalize(payloadId, originAppGateway_, params_);
    }

    function refinalize(bytes32 payloadId_, FinalizeParams memory params_) external {
        if (asyncRequests[payloadId_].appGateway == address(0)) revert InvalidPayloadId();
        if (asyncRequests[payloadId_].finalizedBy != msg.sender) revert InvalidCaller();

        _finalize(payloadId_, asyncRequests[payloadId_].appGateway, params_);
    }

    function _finalize(
        bytes32 payloadId_,
        address originAppGateway_,
        FinalizeParams memory params_
    ) internal returns (bytes32 digest) {
        if (params_.transmitter == address(0)) revert InvalidTransmitter();

        // The app gateway is the caller of this function
        _consumeLimit(originAppGateway_, FINALIZE, 1);

        // Verify that the app gateway is properly configured for this chain and target
        _verifyConnections(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target,
            params_.payloadDetails.appGateway
        );

        // Get the switchboard address from plug configurations
        (, address switchboard) = getPlugConfigs(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target
        );

        // Construct parameters for digest calculation
        PayloadDigestParams memory digestParams_ = PayloadDigestParams(
            params_.payloadDetails.appGateway,
            params_.transmitter,
            params_.payloadDetails.target,
            payloadId_,
            params_.payloadDetails.value,
            params_.payloadDetails.executionGasLimit,
            block.timestamp + expiryTime,
            params_.payloadDetails.payload
        );

        // Calculate digest from payload parameters
        digest = getDigest(digestParams_);

        // Create and store the async request with all necessary details
        AsyncRequest memory asyncRequest = AsyncRequest(
            msg.sender,
            params_.payloadDetails.appGateway,
            params_.transmitter,
            params_.payloadDetails.target,
            switchboard,
            params_.payloadDetails.executionGasLimit,
            block.timestamp + expiryTime,
            params_.asyncId,
            digest,
            params_.payloadDetails.payload,
            params_.payloadDetails.next
        );
        asyncRequests[payloadId_] = asyncRequest;
        emit FinalizeRequested(payloadId_, asyncRequest);
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
        bytes memory payload_
    ) public returns (bytes32 payloadId) {
        // from payload delivery
        _consumeLimit(appGateway_, QUERY, 1);
        // Generate unique payload ID from query counter
        payloadId = _encodeId(evmxChainSlug, address(this));

        // Create async request with minimal information for queries
        // Note: addresses set to 0 as they're not needed for queries
        AsyncRequest memory asyncRequest_ = AsyncRequest(
            msg.sender,
            address(0),
            address(0),
            targetAddress_,
            address(0),
            0,
            block.timestamp + expiryTime,
            bytes32(0),
            bytes32(0),
            payload_,
            asyncPromises_
        );
        asyncRequests[payloadId] = asyncRequest_;
        emit QueryRequested(chainSlug_, targetAddress_, payloadId, payload_);
    }

    /// @notice Marks a request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @dev Only callable by the contract owner
    /// @dev Watcher signs on following digest for validation on switchboard:
    /// @dev keccak256(abi.encode(switchboard, digest))
    function finalized(
        bytes32 payloadId_,
        uint256 signatureNonce_,
        bytes calldata proof_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            signatureNonce_,
            keccak256(
                abi.encode(address(this), evmxChainSlug, signatureNonce_, payloadId_, proof_)
            ),
            signature_
        );

        watcherProofs[payloadId_] = proof_;
        emit Finalized(payloadId_, asyncRequests[payloadId_], proof_);
    }

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @dev Only callable by the contract owner
    function resolvePromises(
        uint256 signatureNonce_,
        ResolvedPromises[] calldata resolvedPromises_,
        bytes calldata signature_
    ) external {
        _isWatcherSignatureValid(
            signatureNonce_,
            keccak256(abi.encode(address(this), evmxChainSlug, signatureNonce_, resolvedPromises_)),
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
            signatureNonce_,
            keccak256(
                abi.encode(
                    address(this),
                    evmxChainSlug,
                    signatureNonce_,
                    payloadId_,
                    isRevertingOnchain_
                )
            ),
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

            // batch.isBatchCancelled
        }
    }

    /// @notice Calculates the digest hash of payload parameters
    /// @param params_ The payload parameters
    /// @return digest The calculated digest
    function getDigest(PayloadDigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                params_.payloadId,
                params_.appGateway,
                params_.transmitter,
                params_.target,
                params_.value,
                params_.deadline,
                params_.executionGasLimit,
                params_.payload
            )
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
            signatureNonce_,
            keccak256(abi.encode(address(this), evmxChainSlug, signatureNonce_, params_)),
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

    /// @notice Verifies the connection between chain slug, target, and app gateway
    /// @param chainSlug_ The identifier of the chain
    /// @param target_ The target address
    /// @param appGateway_ The app gateway address to verify
    /// @dev Internal function to validate connections
    function _verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_
    ) internal view {
        (address appGateway, ) = getPlugConfigs(chainSlug_, target_);
        if (appGateway != appGateway_) revert InvalidConnection();
    }

    /// @notice Encodes a unique payload ID from chain slug, plug address, and counter
    /// @param chainSlug_ The identifier of the chain
    /// @param plug_ The plug address
    /// @return The encoded payload ID as bytes32
    /// @dev Reverts if chainSlug is 0
    function _encodeWritePayloadId(uint32 chainSlug_, address plug_) internal returns (bytes32) {
        if (chainSlug_ == 0) revert InvalidChainSlug();
        (, address switchboard) = getPlugConfigs(chainSlug_, plug_);
        return _encodeId(chainSlug_, switchboard);
    }

    function _encodeId(
        uint32 chainSlug_,
        address switchboardOrWatcher_
    ) internal returns (bytes32) {
        // Encode payload ID by bit-shifting and combining:
        // chainSlug (32 bits) | switchboard or watcher precompile address (160 bits) | counter (64 bits)
        return
            bytes32(
                (uint256(chainSlug_) << 224) |
                    (uint256(uint160(switchboardOrWatcher_)) << 64) |
                    payloadCounter++
            );
    }

    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
    }
}
