// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {QueueParams, OverrideParams, Transaction, Bid, RequestParams} from "../../utils/common/Structs.sol";

interface IAuctionManager {
    /// @notice Bids for an auction
    /// @param requestCount_ The request count
    /// @param fee_ The fee
    /// @param transmitterSignature_ The transmitter signature
    /// @param extraData_ The extra data
    function bid(
        uint40 requestCount_,
        uint256 fee_,
        address scheduleFees_,
        bytes memory transmitterSignature_,
        bytes memory extraData_
    ) external;

    /// @notice Ends an auction
    /// @param requestCount_ The request count
    /// @param scheduleFees_ The schedule fees
    function endAuction(uint40 requestCount_, uint256 scheduleFees_) external;

    /// @notice Checks if an auction is closed
    /// @param requestCount_ The request count
    /// @return isClosed_ Whether the auction is closed
    function auctionClosed(uint40 requestCount_) external view returns (bool);

    /// @notice Checks if an auction is started
    /// @param requestCount_ The request count
    /// @return isStarted_ Whether the auction is started
    function auctionStarted(uint40 requestCount_) external view returns (bool);
}
