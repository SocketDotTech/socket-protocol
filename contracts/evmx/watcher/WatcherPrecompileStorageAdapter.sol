// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../PayloadHeaderDecoder.sol";
import "../../interfaces/IWatcherPrecompile.sol";
import {IAppGateway} from "../../interfaces/IAppGateway.sol";
import {IPromise} from "../../interfaces/IPromise.sol";
import {IMiddleware} from "../../interfaces/IMiddleware.sol";
import {InvalidCallerTriggered, TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed, RequestAlreadyExecuted} from "../../../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, TimeoutRequest, QueuePayloadParams, PayloadParams, RequestParams, RequestMetadata} from "../../../utils/common/Structs.sol";

/// @title WatcherPrecompileStorage
/// @notice Storage contract for the WatcherPrecompile system
/// @dev This contract contains all the storage variables used by the WatcherPrecompile system
/// @dev It is inherited by WatcherPrecompileCore and WatcherPrecompile
abstract contract WatcherPrecompileStorage is IWatcherPrecompile {
    // slot 50
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // IDs
    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;

    /// @notice Counter for tracking request counts
    uint40 public override nextRequestCount;

    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    // Payload Params
    /// @notice The time from finalize for the payload to be executed
    /// @dev Expiry time in seconds for payload execution
    uint256 public expiryTime;

    // slot 52
    /// @notice The maximum delay for a timeout
    /// @dev Maximum timeout delay in seconds
    uint256 public maxTimeoutDelayInSeconds;

    // slot 54
    /// @notice The maximum message value limit for a chain
    mapping(uint32 => uint256) public chainMaxMsgValueLimit;

    // slot 55
    /// @notice Maps nonce to whether it has been used
    /// @dev Used to prevent replay attacks with signature nonces
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 56
    /// @notice Mapping to store watcher proofs
    /// @dev Maps payload ID to proof bytes
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    // slot 59
    /// @notice Mapping to store the list of payload IDs for each batch
    mapping(uint40 => bytes32[]) public batchPayloadIds;

    // slot 60
    /// @notice Mapping to store the batch IDs for each request
    mapping(uint40 => uint40[]) public requestBatchIds;

    // slot 61
    // queue => update to payloadParams, assign id, store in payloadParams map
    /// @notice Mapping to store the payload parameters for each payload ID
    mapping(bytes32 => PayloadParams) public payloads;

    // slot 53
    /// @notice The metadata for a request
    mapping(uint40 => RequestParams) public requests;
}

contract WatcherPrecompileStorageAdapter is WatcherPrecompileStorage {

    // all function from watcher requiring signature
    function watcherUpdater(address[] callData contracts, bytes[] callData data_, uint256[] calldata nonces_, bytes[] callData signatures_) {

    }
}
