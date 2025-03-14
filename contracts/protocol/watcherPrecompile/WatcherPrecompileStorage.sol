// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IWatcherPrecompile.sol";
import {IAppGateway} from "../../interfaces/IAppGateway.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import {IPromise} from "../../interfaces/IPromise.sol";
import {IMiddleware} from "../../interfaces/IMiddleware.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../utils/common/Constants.sol";
import {TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed} from "../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, TimeoutRequest, CallFromChainParams, QueuePayloadParams, PayloadParams, RequestParams} from "../utils/common/Structs.sol";

abstract contract WatcherPrecompileStorage is IWatcherPrecompile {
    // slot 0-49: gap for future storage variables
    uint256[50] _gap_before;

    // slot 52: evmxSlug
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // slot 60: isNonceUsed
    /// @notice Maps nonce to whether it has been used
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 62: maxTimeoutDelayInSeconds
    uint256 public maxTimeoutDelayInSeconds;
    // slot 63: payloadCounter
    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;

    // slot 64: timeoutCounter
    /// @notice Counter for tracking timeout requests
    uint40 public timeoutCounter;

    // slot 65: expiryTime
    /// @notice The expiry time for the payload
    uint256 public expiryTime;

    // slot 65: asyncRequests
    // slot 66: timeoutRequests
    /// @notice Mapping to store timeout requests
    /// @dev timeoutId => TimeoutRequest struct
    mapping(bytes32 => TimeoutRequest) public timeoutRequests;
    // slot 67: watcherProofs
    /// @notice Mapping to store watcher proofs
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    // slot 68: appGatewayCalled
    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev callId => bool
    mapping(bytes32 => bool) public appGatewayCalled;

    // slot 69: requests

    // slots 71-118: gap for future storage variables
    uint256[48] _gap_after;

    uint40 public nextRequestCount;
    uint40 public nextBatchCount;

    mapping(uint40 => RequestParams) public requestParams;
    mapping(uint40 => bytes32[]) public batchPayloadIds;
    mapping(uint40 => uint40[]) public requestBatchIds;
    mapping(bytes32 => PayloadParams) public payloads;

    IWatcherPrecompileLimits public watcherPrecompileLimits__;
    IWatcherPrecompileConfig public watcherPrecompileConfig__;
}
