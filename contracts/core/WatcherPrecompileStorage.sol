// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../PayloadHeaderDecoder.sol";
import "../../interfaces/IWatcherPrecompile.sol";
import {IAppGateway} from "../../interfaces/IAppGateway.sol";
import {IPromise} from "../../interfaces/IPromise.sol";
import {IMiddleware} from "../../interfaces/IMiddleware.sol";
import {QUERY, FINALIZE, SCHEDULE, MAX_COPY_BYTES} from "../../../utils/common/Constants.sol";
import {InvalidCallerTriggered, TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed, RequestAlreadyExecuted} from "../../../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, TimeoutRequest, QueuePayloadParams, PayloadParams, RequestParams, RequestMetadata} from "../../../utils/common/Structs.sol";

/// @title WatcherPrecompileStorage
/// @notice Storage contract for the WatcherPrecompile system
/// @dev This contract contains all the storage variables used by the WatcherPrecompile system
/// @dev It is inherited by WatcherPrecompileCore and WatcherPrecompile
abstract contract WatcherPrecompileStorage is IWatcherPrecompile {
    // slots [0-49]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 50
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;

    /// @notice Counter for tracking request counts
    uint40 public override nextRequestCount;

    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    // slot 51
    /// @notice The time from finalize for the payload to be executed
    /// @dev Expiry time in seconds for payload execution
    uint256 public expiryTime;

    // slot 52
    /// @notice The maximum delay for a timeout
    /// @dev Maximum timeout delay in seconds
    uint256 public maxTimeoutDelayInSeconds;

    // slot 53
    /// @notice stores temporary address of the app gateway caller from a chain
    address public appGatewayCaller;


    // slot 52
    /// @notice The parameters array used to store payloads for a request
    QueuePayloadParams[] public queuePayloadParams;

    // slot 53
    /// @notice The metadata for a request
    mapping(uint40 => RequestMetadata) public requests;

    // slot 54
    /// @notice The prefix for timeout IDs
    uint256 public timeoutIdPrefix;

    // slot 54
    /// @notice The maximum message value limit for a chain
    mapping(uint32 => uint256) public chainMaxMsgValueLimit;


    // slot 55
    /// @notice Maps nonce to whether it has been used
    /// @dev Used to prevent replay attacks with signature nonces
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 55
    /// @notice Mapping to store timeout requests
    /// @dev Maps timeout ID to TimeoutRequest struct
    /// @dev timeoutId => TimeoutRequest struct
    mapping(bytes32 => TimeoutRequest) public timeoutRequests;

    // slot 56
    /// @notice Mapping to store watcher proofs
    /// @dev Maps payload ID to proof bytes
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    // slot 57
    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev Maps call ID to boolean indicating if the appGateway has been called
    /// @dev callId => bool
    mapping(bytes32 => bool) public appGatewayCalled;

    // slot 58
    /// @notice Mapping to store the request parameters for each request count
    mapping(uint40 => RequestParams) public requestParams;

    // slot 59
    /// @notice Mapping to store the list of payload IDs for each batch
    mapping(uint40 => bytes32[]) public batchPayloadIds;

    // slot 60
    /// @notice Mapping to store the batch IDs for each request
    mapping(uint40 => uint40[]) public requestBatchIds;

    // slot 61
    /// @notice Mapping to store the payload parameters for each payload ID
    mapping(bytes32 => PayloadParams) public payloads;

    // slot 62
    /// @notice Mapping to store if a promise has been executed
    mapping(bytes32 => bool) public isPromiseExecuted;

    // slot 63
    IWatcherPrecompileLimits public watcherPrecompileLimits__;

    // slot 64
    IWatcherPrecompileConfig public watcherPrecompileConfig__;

    // slot 65
    /// @notice Mapping to store the request metadata for each request count
    mapping(uint40 => RequestMetadata) public requestMetadata;

    // slots [67-114]: gap for future storage variables
    uint256[48] _gap_after;

    // slots 115-165 (51) reserved for access control
    // slots 166-216 (51) reserved for addr resolver util
}
