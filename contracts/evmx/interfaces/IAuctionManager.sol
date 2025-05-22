// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {QueueParams, OverrideParams, Transaction, Bid, RequestParams} from "../../utils/common/Structs.sol";

interface IAuctionManager {
    enum AuctionStatus {
        NOT_STARTED,
        OPEN,
        CLOSED,
        RESTARTED,
        EXPIRED
    }

    /// @notice Bids for an auction
    /// @param requestCount_ The request count
    /// @param bidFees The bid amount
    /// @param transmitterSignature The signature of the transmitter
    /// @param extraData The extra data
    function bid(
        uint40 requestCount_,
        uint256 bidFees,
        bytes memory transmitterSignature,
        bytes memory extraData
    ) external;

    /// @notice Ends an auction
    /// @param requestCount_ The request count
    function endAuction(uint40 requestCount_) external;

    /// @notice Expires a bid and restarts an auction in case a request is not fully executed.
    /// @dev Auction can be restarted only for `maxReAuctionCount` times.
    /// @dev It also unblocks the fees from last transmitter to be assigned to the new winner.
    /// @param requestCount_ The request id
    function expireBid(uint40 requestCount_) external;

    /// @notice Checks if an auction is closed
    /// @param requestCount_ The request count
    /// @return isClosed_ Whether the auction is closed
    function auctionStatus(uint40 requestCount_) external view returns (AuctionStatus);
}
