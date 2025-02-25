// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWatcherPrecompile} from "../../interfaces/IWatcherPrecompile.sol";
import {IAppGateway} from "../../interfaces/IAppGateway.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import {IPromise} from "../../interfaces/IPromise.sol";

import {QUERY, FINALIZE, SCHEDULE} from "../utils/common/Constants.sol";
import {TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed} from "../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, UpdateLimitParams, PlugConfig, PayloadDigestParams, AsyncRequest, FinalizeParams, TimeoutRequest, CallFromChainParams} from "../utils/common/Structs.sol";

abstract contract WatcherPrecompileStorage is IWatcherPrecompile {
    uint256[50] _gap_before;

    /// @notice Number of decimals used in limit calculations
    uint256 public constant LIMIT_DECIMALS = 18;

    /// @notice Default limit value for any app gateway
    uint256 public defaultLimit;
    /// @notice Rate at which limit replenishes per second
    uint256 public defaultRatePerSecond;

    /// @notice The chain slug of the watcher precompile
    uint32 public evmxChainSlug;

    // appGateway => limitType => receivingLimitParams
    mapping(address => mapping(bytes32 => LimitParams)) internal _limitParams;

    // Mapping to track active app gateways
    mapping(address => bool) internal _activeAppGateways;

    /// @notice Maps network and plug to their configuration
    /// @dev chainSlug => plug => PlugConfig
    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    /// @notice Maps chain slug to their associated switchboard
    /// @dev chainSlug => sb type => switchboard address
    mapping(uint32 => mapping(bytes32 => address)) public switchboards;

    /// @notice Maps chain slug to their associated socket
    /// @dev chainSlug => socket address
    mapping(uint32 => address) public sockets;

    /// @notice Maps chain slug to their associated contract factory plug
    /// @dev chainSlug => contract factory plug address
    mapping(uint32 => address) public contractFactoryPlug;

    /// @notice Maps chain slug to their associated fees plug
    /// @dev chainSlug => fees plug address
    mapping(uint32 => address) public feesPlug;

    /// @notice Maps nonce to whether it has been used
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // appGateway => chainSlug => plug => isValid
    mapping(address => mapping(uint32 => mapping(address => bool))) public isValidPlug;

    uint256 public maxTimeoutDelayInSeconds;
    /// @notice Counter for tracking payload requests
    uint256 public payloadCounter;
    /// @notice The expiry time for the payload
    uint256 public expiryTime;

    /// @notice Mapping to store async requests
    /// @dev payloadId => AsyncRequest struct
    mapping(bytes32 => AsyncRequest) public asyncRequests;
    /// @notice Mapping to store timeout requests
    /// @dev timeoutId => TimeoutRequest struct
    mapping(bytes32 => TimeoutRequest) public timeoutRequests;
    /// @notice Mapping to store watcher proofs
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev callId => bool
    mapping(bytes32 => bool) public appGatewayCalled;

    uint256[50] _gap_after;
}
