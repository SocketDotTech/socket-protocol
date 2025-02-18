// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "../interfaces/IAppGateway.sol";
import "../interfaces/IWatcherPrecompile.sol";
import "../interfaces/IPromise.sol";

import {PayloadRootParams, AsyncRequest, FinalizeParams, TimeoutRequest, CallFromInboxParams, PlugConfig, ResolvedPromises, AppGatewayConfig} from "../protocol/utils/common/Structs.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../protocol/utils/common/Constants.sol";
import {TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled} from "../protocol/utils/common/Errors.sol";
import "solady/utils/ERC1967Factory.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract MockWatcherPrecompile {
    uint256 public maxTimeoutDelayInSeconds = 24 * 60 * 60; // 24 hours
    /// @notice Counter for tracking query requests
    uint256 public queryCounter;
    /// @notice Counter for tracking payload execution requests
    uint256 public payloadCounter;
    /// @notice Counter for tracking timeout requests
    uint256 public timeoutCounter;
    /// @notice Mapping to store async requests
    /// @dev payloadId => AsyncRequest struct
    mapping(bytes32 => AsyncRequest) public asyncRequests;
    /// @notice Mapping to store timeout requests
    /// @dev timeoutId => TimeoutRequest struct
    mapping(bytes32 => TimeoutRequest) public timeoutRequests;

    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    /// @notice Maps app gateway to their associated plugs per network
    /// @dev appGateway => chainSlug => plug
    mapping(address => mapping(uint32 => address)) public appGatewayPlugs;
    /// @notice Error thrown when an invalid chain slug is provided
    error InvalidChainSlug();
    error InvalidTransmitter();

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
    /// @param watcherSignature The signature from the watcher
    event Finalized(bytes32 indexed payloadId, AsyncRequest asyncRequest, bytes watcherSignature);

    /// @notice Emitted when a promise is resolved
    /// @param payloadId The unique identifier for the resolved promise
    event PromiseResolved(bytes32 indexed payloadId);

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

    /// @notice Contract constructor
    /// @param _owner Address of the contract owner
    constructor(address _owner, address addressResolver_) {}

    // ================== Timeout functions ==================

    /// @notice Sets a timeout for a payload execution on app gateway
    /// @param payload_ The payload data
    /// @param delayInSeconds_ The delay in seconds
    function setTimeout(bytes calldata payload_, uint256 delayInSeconds_) external {
        uint256 executeAt = block.timestamp + delayInSeconds_;
        bytes32 timeoutId = _encodeTimeoutId(timeoutCounter++);
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
    /// @param timeoutId The unique identifier for the timeout
    /// @dev Only callable by the contract owner
    function resolveTimeout(bytes32 timeoutId) external {
        TimeoutRequest storage timeoutRequest = timeoutRequests[timeoutId];

        (bool success, ) = address(timeoutRequest.target).call(timeoutRequest.payload);
        if (!success) revert CallFailed();
        emit TimeoutResolved(
            timeoutId,
            timeoutRequest.target,
            timeoutRequest.payload,
            block.timestamp
        );
    }

    // ================== Finalize functions ==================

    /// @notice Finalizes a payload request, requests the watcher to release the signatures to execute on chain
    /// @param params_ The finalization parameters
    /// @return payloadId The unique identifier for the finalized request
    /// @return root The merkle root of the payload parameters
    function finalize(
        FinalizeParams memory params_
    ) external returns (bytes32 payloadId, bytes32 root) {
        root = keccak256(abi.encode(block.timestamp));
        // Generate a unique payload ID by combining chain, target, and counter
        payloadId = encodePayloadId(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target,
            payloadCounter++
        );
        address[] memory next = new address[](1);
        emit FinalizeRequested(
            payloadId,
            AsyncRequest(
                address(0),
                address(0),
                params_.payloadDetails.target,
                address(0),
                0,
                params_.asyncId,
                bytes32(0),
                bytes(""),
                next
            )
        );
    }

    // ================== Query functions ==================
    /// @notice Creates a new query request
    /// @param chainSlug The identifier of the destination chain
    /// @param targetAddress The address of the target contract
    /// @param payload The query payload data
    /// @return payloadId The unique identifier for the query
    function query(
        uint32 chainSlug,
        address targetAddress,
        address[] memory,
        bytes memory payload
    ) public returns (bytes32 payloadId) {
        payloadId = bytes32(queryCounter++);
        emit QueryRequested(chainSlug, targetAddress, payloadId, payload);
    }

    /// @notice Marks a request as finalized with a signature
    /// @param payloadId_ The unique identifier of the request
    /// @param signature_ The watcher's signature
    /// @dev Only callable by the contract owner
    function finalized(bytes32 payloadId_, bytes calldata signature_) external {
        emit Finalized(payloadId_, asyncRequests[payloadId_], signature_);
    }

    /// @notice Resolves multiple promises with their return data
    /// @param resolvedPromises_ Array of resolved promises and their return data
    /// @dev Only callable by the contract owner
    function resolvePromises(ResolvedPromises[] calldata resolvedPromises_) external {
        for (uint256 i = 0; i < resolvedPromises_.length; i++) {
            emit PromiseResolved(resolvedPromises_[i].payloadId);
        }
    }

    // ================== On-Chain Inbox ==================

    function callAppGateways(CallFromInboxParams[] calldata params_) external {
        for (uint256 i = 0; i < params_.length; i++) {
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

    /// @notice Encodes a unique payload ID from chain slug, plug address, and counter
    /// @param chainSlug_ The identifier of the chain
    /// @param plug_ The plug address
    /// @param counter_ The current counter value
    /// @return The encoded payload ID as bytes32
    /// @dev Reverts if chainSlug is 0
    function encodePayloadId(
        uint32 chainSlug_,
        address plug_,
        uint256 counter_
    ) internal view returns (bytes32) {
        if (chainSlug_ == 0) revert InvalidChainSlug();
        (, address switchboard) = getPlugConfigs(chainSlug_, plug_);
        // Encode payload ID by bit-shifting and combining:
        // chainSlug (32 bits) | switchboard address (160 bits) | counter (64 bits)

        return
            bytes32(
                (uint256(chainSlug_) << 224) | (uint256(uint160(switchboard)) << 64) | counter_
            );
    }

    function _encodeTimeoutId(uint256 timeoutCounter_) internal view returns (bytes32) {
        // watcher address (160 bits) | counter (64 bits)
        return bytes32((uint256(uint160(address(this))) << 64) | timeoutCounter_);
    }

    function setAppGateways(AppGatewayConfig[] calldata configs) external {
        for (uint256 i = 0; i < configs.length; i++) {
            // Store the plug configuration for this network and plug
            _plugConfigs[configs[i].chainSlug][configs[i].plug] = PlugConfig({
                appGateway: configs[i].appGateway,
                switchboard: configs[i].switchboard
            });

            // Create reverse mapping from app gateway to plug for easy lookup
            appGatewayPlugs[configs[i].appGateway][configs[i].chainSlug] = configs[i].plug;
        }
    }

    /// @notice Retrieves the configuration for a specific plug on a network
    /// @param chainSlug_ The identifier of the network
    /// @param plug_ The address of the plug
    /// @return The app gateway address and switchboard address for the plug
    /// @dev Returns zero addresses if configuration doesn't exist
    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) public view returns (address, address) {
        return (
            _plugConfigs[chainSlug_][plug_].appGateway,
            _plugConfigs[chainSlug_][plug_].switchboard
        );
    }
}
