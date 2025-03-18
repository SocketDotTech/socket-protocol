// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./RequestQueue.sol";

/// @title RequestAsync
/// @notice Abstract contract for managing asynchronous payload batches
abstract contract FeesHelpers is RequestQueue {
    // slots [210-259] reserved for gap
    uint256[50] _gap_batch_async;

    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external override {
        address appGateway = _getCoreAppGateway(msg.sender);
        if (appGateway != requests[requestCount_].appGateway) {
            revert OnlyAppGateway();
        }

        if (requests[requestCount_].winningBid.transmitter != address(0)) revert WinningBidExists();
        requests[requestCount_].fees.amount = newMaxFees_;
        emit FeesIncreased(appGateway, requestCount_, newMaxFees_);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    /// @param fees_ The fees data
    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        address auctionManager_,
        Fees memory fees_
    ) external returns (uint40) {
        IFeesManager(addressResolver__.feesManager()).withdrawFees(
            msg.sender,
            chainSlug_,
            token_,
            amount_,
            receiver_,
            auctionManager_,
            fees_
        );

        return _batch(msg.sender, auctionManager_, fees_, bytes(""));
    }

    function getFees(uint40 requestCount_) external view returns (Fees memory) {
        return requests[requestCount_].fees;
    }
}
