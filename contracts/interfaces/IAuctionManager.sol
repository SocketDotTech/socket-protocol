// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {Bid, Fees} from "../common/Structs.sol";

interface IAuctionManager {
    function startAuction(bytes32 asyncId_) external returns (uint256);

    function bid(
        bytes32 asyncId_,
        uint256 fee_,
        bytes memory transmitterSignature_,
        bytes memory extraData_
    ) external;

    function endAuction(bytes32 asyncId_) external;

    function auctionClosed(bytes32 asyncId_) external view returns (bool);

    function auctionStarted(bytes32 asyncId_) external view returns (bool);
}
