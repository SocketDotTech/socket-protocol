// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./FeesHelpers.sol";

/// @title DeliveryHelper
/// @notice Contract for managing payload delivery
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
        _initializeOwner(owner_);

        bidTimeout = bidTimeout_;
    }

    /// @notice Calls the watcher precompile to start processing a request
    /// @dev If a transmitter was already assigned, it updates the transmitter in watcher precompile too
    /// @param requestCount_ The ID of the request
    /// @param winningBid_ The winning bid
    function startRequestProcessing(
        uint40 requestCount_,
        Bid memory winningBid_
    ) external onlyAuctionManager(requestCount_) {
        if (requests[requestCount_].onlyReadRequests) revert ReadOnlyRequests();
        if (winningBid_.transmitter == address(0)) revert InvalidTransmitter();

        RequestMetadata storage requestMetadata_ = requests[requestCount_];
        // if a transmitter was already assigned, it means the request was restarted
        bool isRestarted = requestMetadata_.winningBid.transmitter != address(0);
        requestMetadata_.winningBid.transmitter = winningBid_.transmitter;

        if (!isRestarted) {
            watcherPrecompile__().startProcessingRequest(requestCount_, winningBid_.transmitter);
        } else {
            watcherPrecompile__().updateTransmitter(requestCount_, winningBid_.transmitter);
        }
    }

    /// @notice Finishes the request processing by assigning fees and calling the on complete hook on app gateway
    /// @param requestCount_ The ID of the request
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

    /// @notice Cancels a request and settles the fees
    /// @dev if no transmitter was assigned, fees is unblocked to app gateway
    /// @dev Only app gateway can call this function
    /// @param requestCount_ The ID of the request
    function cancelRequest(uint40 requestCount_) external {
        if (msg.sender != requests[requestCount_].appGateway) {
            revert OnlyAppGateway();
        }

        _settleFees(requestCount_);
        watcherPrecompile__().cancelRequest(requestCount_);
        emit RequestCancelled(requestCount_);
    }

    /// @notice For request reverts, settles the fees
    /// @param requestCount_ The ID of the request
    function handleRequestReverts(uint40 requestCount_) external onlyWatcherPrecompile {
        _settleFees(requestCount_);
    }

    /// @notice Settles the fees for a request
    /// @dev If a transmitter was already assigned, it unblocks and assigns fees to the transmitter
    /// @dev If no transmitter was assigned, it unblocks fees to the app gateway
    /// @param requestCount_ The ID of the request
    function _settleFees(uint40 requestCount_) internal {
        // If the request has a winning bid, ie. transmitter already assigned, unblock and assign fees
        if (requests[requestCount_].winningBid.transmitter != address(0)) {
            IFeesManager(addressResolver__.feesManager()).unblockAndAssignFees(
                requestCount_,
                requests[requestCount_].winningBid.transmitter,
                requests[requestCount_].appGateway
            );
        } else {
            // If the request has no winning bid, ie. transmitter not assigned, unblock fees
            IFeesManager(addressResolver__.feesManager()).unblockFees(requestCount_);
        }
    }

    /// @notice Returns the request metadata
    /// @param requestCount_ The ID of the request
    /// @return requestMetadata The request metadata
    function getRequestMetadata(
        uint40 requestCount_
    ) external view returns (RequestMetadata memory) {
        return requests[requestCount_];
    }
}
