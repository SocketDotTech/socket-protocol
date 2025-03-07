// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./RequestQueue.sol";

/// @title BatchAsync
/// @notice Abstract contract for managing asynchronous payload batches
abstract contract FeesHelpers is RequestQueue {
    // slots [210-259] reserved for gap
    uint256[50] _gap_batch_async;

    /// @notice Cancels a transaction
    /// @param asyncId_ The ID of the batch
    function cancelTransaction(bytes32 asyncId_) external {
        if (msg.sender != _payloadBatches[asyncId_].appGateway) {
            revert OnlyAppGateway();
        }

        _payloadBatches[asyncId_].isBatchCancelled = true;

        if (_payloadBatches[asyncId_].winningBid.transmitter != address(0)) {
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                asyncId_,
                _payloadBatches[asyncId_].winningBid.transmitter,
                _payloadBatches[asyncId_].appGateway
            );
        } else {
            IFeesManager(addressResolver__.feesManager()).unblockFees(
                asyncId_,
                _payloadBatches[asyncId_].appGateway
            );
        }

        emit BatchCancelled(asyncId_);
    }

    function increaseFees(bytes32 asyncId_, uint256 newMaxFees_) external override {
        address appGateway = _getCoreAppGateway(msg.sender);
        if (appGateway != _payloadBatches[asyncId_].appGateway) {
            revert OnlyAppGateway();
        }

        if (_payloadBatches[asyncId_].winningBid.transmitter != address(0))
            revert WinningBidExists();

        _payloadBatches[asyncId_].fees.amount = newMaxFees_;
        emit FeesIncreased(appGateway, asyncId_, newMaxFees_);
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
    ) external {
        PayloadDetails[] memory payloadDetailsArray = new PayloadDetails[](1);
        payloadDetailsArray[0] = IFeesManager(addressResolver__.feesManager()).getWithdrawToPayload(
            msg.sender,
            chainSlug_,
            token_,
            amount_,
            receiver_
        );
        if (auctionManager_ == address(0)) {
            auctionManager_ = IAddressResolver(addressResolver__).defaultAuctionManager();
        }
        _deliverPayload(payloadDetailsArray, fees_, auctionManager_, new bytes(0));
    }
}
