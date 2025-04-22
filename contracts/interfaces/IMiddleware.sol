// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import {PayloadSubmitParams, QueuePayloadParams, Bid, WriteFinality, BatchParams, CallType, Parallel, IsPlug, RequestMetadata} from "../protocol/utils/common/Structs.sol";

/// @title IMiddleware
/// @notice Interface for the Middleware contract
interface IMiddleware {
    /// @notice Returns the timeout after which a bid expires
    function bidTimeout() external view returns (uint128);

    /// @notice Returns the metadata for a request
    /// @param requestCount_ The request id
    /// @return requestMetadata The metadata for the request
    function getRequestMetadata(
        uint40 requestCount_
    ) external view returns (RequestMetadata memory);

    /// @notice Clears the temporary queue used to store payloads for a request
    function clearQueue() external;

    /// @notice Queues a payload for a request
    /// @param queuePayloadParams_ The parameters for the payload
    function queue(QueuePayloadParams memory queuePayloadParams_) external;

    /// @notice Batches a request
    /// @param fees_ The fees for the request
    /// @param auctionManager_ The address of the auction manager
    /// @param feesApprovalData_ the data to be passed to the fees manager
    /// @param onCompleteData_ The data to be passed to the onComplete callback
    /// @return requestCount The request id
    function batch(
        uint256 fees_,
        address auctionManager_,
        bytes memory feesApprovalData_,
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount);

    /// @notice Withdraws funds to a receiver
    /// @param chainSlug_ The chain slug
    /// @param token_ The token address
    /// @param amount_ The amount to withdraw
    /// @param receiver_ The receiver address
    /// @param auctionManager_ The address of the auction manager
    /// @param fees_ The fees for the request
    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        address auctionManager_,
        uint256 fees_
    ) external returns (uint40);

    /// @notice Cancels a request
    /// @param requestCount_ The request id
    function cancelRequest(uint40 requestCount_) external;

    /// @notice Increases the fees for a request
    /// @param requestCount_ The request id
    /// @param fees_ The new fees
    function increaseFees(uint40 requestCount_, uint256 fees_) external;

    /// @notice Starts the request processing
    /// @param requestCount_ The request id
    /// @param winningBid_ The winning bid
    function startRequestProcessing(uint40 requestCount_, Bid memory winningBid_) external;

    /// @notice Returns the fees for a request
    function getFees(uint40 requestCount_) external view returns (uint256);

    /// @notice Finishes a request by assigning fees and calling the onComplete callback
    /// @param requestCount_ The request id
    function finishRequest(uint40 requestCount_) external;

    /// @notice Handles request reverts by unblocking the fees and calling the onRevert callback
    /// @param requestCount_ The request id
    function handleRequestReverts(uint40 requestCount_) external;
}
