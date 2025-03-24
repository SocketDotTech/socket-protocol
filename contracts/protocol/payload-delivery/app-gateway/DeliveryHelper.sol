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

    function endTimeout(uint40 requestCount_) external onlyWatcherPrecompile {
        IAuctionManager(requests[requestCount_].auctionManager).endAuction(requestCount_);
    }

    function startRequestProcessing(
        uint40 requestCount_,
        Bid memory winningBid_
    ) external onlyAuctionManager(requestCount_) {
        if (requests[requestCount_].onlyReadRequests) revert ReadOnlyRequests();
        if (winningBid_.transmitter == address(0)) revert InvalidTransmitter();

        RequestMetadata storage requestMetadata_ = requests[requestCount_];
        bool isRestarted = requestMetadata_.winningBid.transmitter != address(0);

        requestMetadata_.winningBid.transmitter = winningBid_.transmitter;

        if (!isRestarted) {
            watcherPrecompile__().startProcessingRequest(requestCount_, winningBid_.transmitter);
        } else {
            watcherPrecompile__().updateTransmitter(requestCount_, winningBid_.transmitter);
        }
    }

    function finishRequest(uint40 requestCount_) external onlyWatcherPrecompile {
        RequestMetadata storage requestMetadata_ = requests[requestCount_];

        if (requestMetadata_.winningBid.transmitter != address(0))
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                requestCount_,
                requestMetadata_.winningBid.transmitter,
                requestMetadata_.appGateway
            );

        IAppGateway(requestMetadata_.appGateway).onRequestComplete(
            requestCount_,
            requestMetadata_.onCompleteData
        );
    }

    /// @notice Cancels a request
    /// @param requestCount_ The ID of the request
    function cancelRequest(uint40 requestCount_) external {
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
            IFeesManager(addressResolver__.feesManager()).unblockFees(requestCount_);
        }

        watcherPrecompile__().cancelRequest(requestCount_);
        emit RequestCancelled(requestCount_);
    }

    /// @notice Handles request reverts
    /// @param requestCount_ The ID of the request
    function handleRequestReverts(uint40 requestCount_) external onlyWatcherPrecompile {
        // assign fees after expiry time
        if (requests[requestCount_].winningBid.transmitter != address(0)) {
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                requestCount_,
                requests[requestCount_].winningBid.transmitter,
                requests[requestCount_].appGateway
            );
        } else {
            IFeesManager(addressResolver__.feesManager()).unblockFees(requestCount_);
        }
    }

    function getRequestMetadata(
        uint40 requestCount_
    ) external view returns (RequestMetadata memory) {
        return requests[requestCount_];
    }
}
