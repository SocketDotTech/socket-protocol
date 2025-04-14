// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../interfaces/IWatcherPrecompile.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";
import {IPromise} from "../../../interfaces/IPromise.sol";
import "../DumpDecoder.sol";

import {IMiddleware} from "../../../interfaces/IMiddleware.sol";
import {QUERY, FINALIZE, SCHEDULE, MAX_COPY_BYTES} from "../../utils/common/Constants.sol";
import {InvalidCallerTriggered, TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed} from "../../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, TimeoutRequest, QueuePayloadParams, PayloadParams, RequestParams} from "../../utils/common/Structs.sol";

abstract contract WatcherPrecompileStorage is IWatcherPrecompile {
    // slots [0-49]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 50
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;
    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;
    /// @notice Counter for tracking timeout requests
    uint40 public timeoutCounter;
    /// @notice Counter for tracking request counts
    uint40 public nextRequestCount;
    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    // slot 51
    /// @notice The time from finalize for the payload to be executed
    uint256 public expiryTime;

    // slot 52
    /// @notice The maximum delay for a timeout
    uint256 public maxTimeoutDelayInSeconds;

    // slot 53
    /// @notice stores temporary address of the app gateway caller from a chain
    address public appGatewayCaller;

    // slot 54
    /// @notice Maps nonce to whether it has been used
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 55
    /// @notice Mapping to store timeout requests
    /// @dev timeoutId => TimeoutRequest struct
    mapping(bytes32 => TimeoutRequest) public timeoutRequests;

    // slot 56
    /// @notice Mapping to store watcher proofs
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    // slot 57
    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev callId => bool
    mapping(bytes32 => bool) public appGatewayCalled;

    // slot 58
    mapping(uint40 => RequestParams) public requestParams;

    // slot 59
    mapping(uint40 => bytes32[]) public batchPayloadIds;

    // slot 60
    mapping(uint40 => uint40[]) public requestBatchIds;

    // slot 61
    mapping(bytes32 => PayloadParams) public payloads;

    // slot 62
    mapping(bytes32 => bool) public isPromiseExecuted;

    // slot 63
    IWatcherPrecompileLimits public watcherPrecompileLimits__;

    // slot 64
    IWatcherPrecompileConfig public watcherPrecompileConfig__;

    // slots [65-114]: gap for future storage variables
    uint256[50] _gap_after;

    // slots 115-165 (51) reserved for access control
    // slots 166-216 (51) reserved for addr resolver util
}
