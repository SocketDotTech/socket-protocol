// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FeesHelpers.sol";

contract DeliveryHelper is FeesHelpers {
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

    function endTimeout(bytes32 requestCount_) external onlyWatcherPrecompile {
        IAuctionManager(_payloadRequestes[requestCount_].auctionManager).endAuction(requestCount_);
    }

    function startRequestProcessing(
        bytes32 requestCount_,
        Bid memory winningBid_
    ) external onlyAuctionManager(requestCount_) {
        if (winningBid_.transmitter == address(0)) revert InvalidTransmitter();

        if (!isRestarted) {
            watcherPrecompile__().startProcessingRequest(requestCount_, winningBid_.transmitter);
        } else {
            watcherPrecompile__().updateTransmitter(requestCount_, winningBid_.transmitter);
        }
    }

    function finishRequest(
        bytes32 requestCount_,
        PayloadRequest storage payloadRequest_
    ) external onlyWatcherPrecompile {
        IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
            requestCount_,
            payloadRequest_.winningBid.transmitter,
            payloadRequest_.appGateway
        );
        IAppGateway(payloadRequest_.appGateway).onRequestComplete(requestCount_, payloadRequest_);
    }

    /// @notice Cancels a request
    /// @param requestCount_ The ID of the request
    function cancelRequest(bytes32 requestCount_) external {
        if (msg.sender != requests[requestCount_].appGateway) {
            revert OnlyAppGateway();
        }

        if (requests[requestCount_].winningBid.transmitter != address(0)) {
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                requestCount_,
                requests[requestCount_].winningBid.transmitter,
                requests[requestCount_].appGateway
            );
        } else {
            IFeesManager(addressResolver__.feesManager()).unblockFees(
                requestCount_,
                requests[requestCount_].appGateway
            );
        }

        watcherPrecompile__().cancelRequest(requestCount_);
        emit RequestCancelled(requestCount_);
    }
}
