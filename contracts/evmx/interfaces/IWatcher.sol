// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import {InvalidCallerTriggered, TimeoutAlreadyResolved, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed} from "../../utils/common/Errors.sol";
import {Bid, ResolvedPromises, AppGatewayConfig, WriteFinality, PlugConfig, DigestParams, QueueParams, PayloadParams, RequestParams, WatcherMultiCallParams} from "../../utils/common/Structs.sol";

import "./IRequestHandler.sol";
import "./IConfigurations.sol";
import "./IPromiseResolver.sol";
import "./IAddressResolver.sol";

/// @title IWatcher
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcher {
    /// @notice Emitted when a new call is made to an app gateway
    /// @param triggerId The unique identifier for the trigger
    event CalledAppGateway(bytes32 triggerId);

    /// @notice Emitted when a call to an app gateway fails
    /// @param triggerId The unique identifier for the trigger
    event AppGatewayCallFailed(bytes32 triggerId);

    function requestHandler__() external view returns (IRequestHandler);

    function configurations__() external view returns (IConfigurations);

    function promiseResolver__() external view returns (IPromiseResolver);

    function addressResolver__() external view returns (IAddressResolver);

    /// @notice Returns the request params for a given request count
    /// @param requestCount_ The request count
    /// @return The request params
    function getRequestParams(uint40 requestCount_) external view returns (RequestParams memory);

    /// @notice Returns the current request count
    /// @return The current request count
    function getCurrentRequestCount() external view returns (uint40);

    /// @notice Returns the latest async promise deployed for a payload queued
    /// @return The latest async promise
    function latestAsyncPromise() external view returns (address);

    /// @notice Queues a payload for execution
    /// @param queuePayloadParams_ The parameters for the payload
    function queue(QueueParams calldata queuePayloadParams_, address appGateway_) external;

    /// @notice Clears the queue of payloads
    function clearQueue() external;

    function submitRequest(
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes calldata onCompleteData
    ) external returns (uint40 requestCount, address[] memory promises);

    function queueAndSubmit(
        QueueParams memory queue_,
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes calldata onCompleteData
    ) external returns (uint40 requestCount, address[] memory promises);

    /// @notice Assigns a transmitter to a request
    /// @param requestCount_ The request count
    /// @param bid_ The bid
    function assignTransmitter(uint40 requestCount_, Bid memory bid_) external;

    /// @notice Returns the precompile fees for a given precompile
    /// @param precompile_ The precompile
    /// @return The precompile fees
    function getPrecompileFees(bytes4 precompile_) external view returns (uint256);
}
