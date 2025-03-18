// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
import {QueuePayloadParams, Bid, Fees, WriteFinality, CallType, Parallel, IsPlug, RequestMetadata} from "../protocol/utils/common/Structs.sol";

interface IMiddleware {
    event BidPlaced(
        uint40 indexed requestCount,
        Bid bid // Replaced transmitter and bidAmount with Bid struct
    );

    event AuctionEnded(
        uint40 indexed requestCount,
        Bid winningBid // Replaced winningTransmitter and winningBid with Bid struct
    );

    function bidTimeout() external view returns (uint128);

    function getRequestMetadata(
        uint40 requestCount_
    ) external view returns (RequestMetadata memory);

    function clearQueue() external;

    function queue(QueuePayloadParams memory queuePayloadParams_) external;

    function batch(
        Fees memory fees_,
        address auctionManager_,
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount);

    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        address auctionManager_,
        Fees memory fees_
    ) external returns (uint40);

    function cancelRequest(uint40 requestCount_) external;

    function increaseFees(uint40 requestCount_, uint256 fees_) external;

    function startRequestProcessing(uint40 requestCount_, Bid memory winningBid_) external;

    function getFees(uint40 requestCount_) external view returns (Fees memory);

    function finishRequest(uint40 requestCount_) external;
}
