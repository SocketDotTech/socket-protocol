// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
import {PayloadDetails, Bid, FeesData, DeployParams, CallType} from "../common/Structs.sol";

interface IDeliveryHelper {
    event BidPlaced(
        bytes32 indexed asyncId,
        Bid bid // Replaced transmitter and bidAmount with Bid struct
    );

    event AuctionEnded(
        bytes32 indexed asyncId,
        Bid winningBid // Replaced winningTransmitter and winningBid with Bid struct
    );

    function clearQueue() external;

    function queue(
        bool isSequential_,
        uint32 chainSlug_,
        address target_,
        address asyncPromise_,
        CallType callType_,
        bytes memory payload_
    ) external;

    function batch(
        FeesData memory feesData_,
        address auctionManager_,
        bytes memory onCompleteData_,
        bytes32 sbType_
    ) external returns (bytes32);

    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        address auctionManager_,
        FeesData memory feesData_
    ) external;

    function cancelTransaction(bytes32 asyncId_) external;

    function startBatchProcessing(bytes32 asyncId_, Bid memory winningBid) external;

    function getFeesData(bytes32 asyncId_) external view returns (FeesData memory);

    function getCurrentAsyncId() external view returns (bytes32);
}
