// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RequestAsync.sol";

contract DeliveryHelper is RequestAsync {
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address resolver contract
    /// @param owner_ The owner address
    function initialize(
        address addressResolver_,
        address owner_,
        uint128 bidTimeout_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        bidTimeout = bidTimeout_;
        _initializeOwner(owner_);
    }

    function endTimeout(bytes32 requestId_) external onlyWatcherPrecompile {
        IAuctionManager(_payloadRequestes[requestId_].auctionManager).endAuction(requestId_);
    }

    function startRequestProcessing(
        bytes32 requestId_,
        Bid memory winningBid_
    ) external onlyAuctionManager(requestId_) {
        if (winningBid_.transmitter == address(0)) revert InvalidTransmitter();

        if (!isRestarted) {
            watcherPrecompile__().executeRequest(requestId_, winningBid_.transmitter);
        } else {
            watcherPrecompile__().updateTransmitter(requestId_, winningBid_.transmitter);
        }
    }

    function finishRequest(
        bytes32 requestId_,
        PayloadRequest storage payloadRequest_
    ) external onlyWatcherPrecompile {
        IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
            requestId_,
            payloadRequest_.winningBid.transmitter,
            payloadRequest_.appGateway
        );
        IAppGateway(payloadRequest_.appGateway).onRequestComplete(requestId_, payloadRequest_);
    }

    /// @notice Cancels a request
    /// @param requestId_ The ID of the request
    function cancelRequest(bytes32 requestId_) external {
        if (msg.sender != requests[requestId_].appGateway) {
            revert OnlyAppGateway();
        }

        if (requests[requestId_].winningBid.transmitter != address(0)) {
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                requestId_,
                requests[requestId_].winningBid.transmitter,
                requests[requestId_].appGateway
            );
        } else {
            IFeesManager(addressResolver__.feesManager()).unblockFees(
                requestId_,
                requests[requestId_].appGateway
            );
        }

        watcherPrecompile__().cancelRequest(requestId_);
        emit RequestCancelled(requestId_);
    }
}
