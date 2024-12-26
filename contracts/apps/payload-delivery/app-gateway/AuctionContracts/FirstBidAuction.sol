// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Bid, FeesData} from "../../../../common/Structs.sol";
import {IAuctionContract} from "../../../../interfaces/IAuctionContract.sol";


/// @title AuctionHouse
/// @notice Contract for managing auctions and placing bids
contract FirstBidAuction is IAuctionContract {
    uint256 public constant auctionEndDelaySeconds = 0;

    constructor() {}

    function isNewBidBetter(
        Bid memory oldWinningBid,
        Bid memory newBid
    ) external pure returns (bool) {
        if (oldWinningBid.transmitter == address(0)) return true;
        return newBid.fee < oldWinningBid.fee;
    }
}
