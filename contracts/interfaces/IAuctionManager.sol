// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {Bid} from "../common/Structs.sol";

interface IAuctionManager {
    function startAuction(bytes32 asyncId_) external;
    function bid(
        bytes32 asyncId_,
        uint256 fee,
        bytes memory transmitterSignature,
        bytes memory extraData
    ) external;
    function endAuction(bytes32 asyncId_) external;
    function winningBids(bytes32 asyncId_) external view returns (Bid memory);
    function auctionClosed(bytes32 asyncId_) external view returns (bool);
    function auctionStarted(bytes32 asyncId_) external view returns (bool);
}
