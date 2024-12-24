// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
import {Bid} from "../common/Structs.sol";

interface IAuctionContract {
    function auctionEndDelaySeconds() external view returns (uint256);
    function isNewBidBetter(
        Bid memory oldWinningBid,
        Bid memory newBid
    ) external view returns (bool);
}
