// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./WatcherPrecompileConfig.sol";
import {RequestParams, PayloadSubmitParams, PayloadParams, CallType} from "../utils/common/Structs.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
abstract contract WatcherPrecompileCore is WatcherPrecompileConfig {
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
    /// @notice Error thrown when a gateway is invalid
    error InvalidGateway();
    /// @notice Error thrown when a switchboard is invalid
    error InvalidSwitchboard();

    event CalledAppGateway(
        bytes32 callId,
        uint32 chainSlug,
        address plug,
        address appGateway,
        bytes32 params,
        bytes payload
    );

    /// @notice Emitted when a new query is requested
    event QueryRequested(PayloadParams params);

    /// @notice Emitted when a finalize request is made
    event FinalizeRequested(address transmitter, bytes32 digest, PayloadParams params);

    /// @notice Emitted when a request is finalized
    /// @param payloadId The unique identifier for the request
    /// @param proof The proof from the watcher
    event Finalized(bytes32 indexed payloadId, bytes proof);

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

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @param payload_ The payload data
    /// @param delayInSeconds_ The delay in seconds
    function _setTimeout(
        address appGateway_,
        bytes calldata payload_,
        uint256 delayInSeconds_
    ) internal {
        if (delayInSeconds_ > maxTimeoutDelayInSeconds) revert TimeoutDelayTooLarge();

        // from auction manager
        _consumeLimit(appGateway_, SCHEDULE, 1);
        uint256 executeAt = block.timestamp + delayInSeconds_;
        bytes32 timeoutId = _encodeId(evmxSlug, address(this));
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

    function _finalize(
        PayloadParams memory params_,
        address transmitter_
    ) internal returns (bytes32 digest) {
        // Verify that the app gateway is properly configured for this chain and target
        _verifyConnections(
            params_.chainSlug,
            params_.target,
            params_.appGateway,
            params_.switchboard
        );

        // Construct parameters for digest calculation
        DigestParams memory digestParams_ = DigestParams(
            transmitter_,
            params_.payloadId,
            block.timestamp + expiryTime,
            params_.callType,
            params_.writeFinality,
            params_.gasLimit,
            params_.value,
            params_.readAt,
            params_.payload,
            params_.target,
            params_.appGateway
        );

        // Calculate digest from payload parameters
        digest = getDigest(digestParams_);
        emit FinalizeRequested(transmitter_, digest, params_);
    }

    // ================== Query functions ==================
    /// @notice Creates a new query request
    /// @param params_ The payload parameters
    function _query(PayloadParams memory params_) internal {
        emit QueryRequested(params_);
    }

    /// @notice Calculates the digest hash of payload parameters
    /// @param params_ The payload parameters
    /// @return digest The calculated digest
    function getDigest(DigestParams memory params_) public pure returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                params_.transmitter,
                params_.payloadId,
                params_.deadline,
                params_.callType,
                params_.writeFinality,
                params_.gasLimit,
                params_.value,
                params_.readAt,
                params_.payload,
                params_.target,
                params_.appGateway
            )
        );
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
        address appGateway_,
        address switchboard_
    ) internal view {
        (address appGateway, address switchboard) = getPlugConfigs(chainSlug_, target_);
        if (appGateway != appGateway_) revert InvalidGateway();
        if (switchboard != switchboard_) revert InvalidSwitchboard();
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

    function _createPayloadId(
        PayloadSubmitParams memory p_,
        uint40 requestCount_,
        uint40 batchCount_,
        uint40 payloadCount_,
        bytes32 prevDigestsHash_
    ) internal returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    requestCount_,
                    batchCount_,
                    payloadCount_,
                    prevDigestsHash_,
                    p_.switchboard,
                    p_.chainSlug
                )
            );
    }
}
