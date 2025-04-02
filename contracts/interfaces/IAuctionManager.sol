// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {Bid, Fees} from "../protocol/utils/common/Structs.sol";

interface IAuctionManager {
    function bid(
        uint40 requestCount_,
        uint256 fee_,
        bytes memory transmitterSignature_,
        bytes memory extraData_
    ) external;

    function endAuction(uint40 requestCount_) external;

    function auctionClosed(uint40 requestCount_) external view returns (bool);

    function auctionStarted(uint40 requestCount_) external view returns (bool);
}
