// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
import {PayloadDetails, CallParams, Bid, Fees, WriteFinality, DeployParams, CallType, PayloadRequest, Parallel, IsPlug} from "../protocol/utils/common/Structs.sol";

interface IDeliveryHelper {
    event BidPlaced(
        bytes32 indexed asyncId,
        Bid bid // Replaced transmitter and bidAmount with Bid struct
    );

    event AuctionEnded(
        bytes32 indexed asyncId,
        Bid winningBid // Replaced winningTransmitter and winningBid with Bid struct
    );

    function bidTimeout() external view returns (uint128);

    function payloadRequestes(bytes32) external view returns (PayloadRequest memory);

    function clearQueue() external;

    function queue(CallParams memory callParams_) external;

    function batch(
        Fees memory fees_,
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
        Fees memory fees_
    ) external;

    function cancelTransaction(bytes32 asyncId_) external;

    function increaseFees(bytes32 asyncId_, uint256 fees_) external;

    function startRequestProcessing(bytes32 asyncId_, Bid memory winningBid_) external;

    function getFees(bytes32 asyncId_) external view returns (Fees memory);

    function getCurrentAsyncId() external view returns (bytes32);

    function getAsyncRequestDetails(bytes32 asyncId_) external view returns (PayloadRequest memory);
}
