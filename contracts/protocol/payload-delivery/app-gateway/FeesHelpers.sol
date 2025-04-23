// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./RequestQueue.sol";

/// @title RequestAsync
/// @notice Abstract contract for managing asynchronous payload batches
abstract contract FeesHelpers is RequestQueue {
    // slots [258-308] reserved for gap
    uint256[50] _gap_batch_async;

    error NewMaxFeesLowerThanCurrent(uint256 current, uint256 new_);
    /// @notice Increases the fees for a request if no bid is placed
    /// @param requestCount_ The ID of the request
    /// @param newMaxFees_ The new maximum fees
    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external override {
        address appGateway = _getCoreAppGateway(msg.sender);
        // todo: should we allow core app gateway too?
        if (appGateway != requests[requestCount_].appGateway) {
            revert OnlyAppGateway();
        }
        if (requests[requestCount_].winningBid.transmitter != address(0)) revert WinningBidExists();
        if (requests[requestCount_].maxFees >= newMaxFees_) revert NewMaxFeesLowerThanCurrent(requests[requestCount_].maxFees, newMaxFees_);
        requests[requestCount_].maxFees = newMaxFees_;
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
        uint256 fees_
    ) external returns (uint40) {
        IFeesManager(addressResolver__.feesManager()).withdrawFees(
            msg.sender,
            chainSlug_,
            token_,
            amount_,
            receiver_
        );
        bytes memory feesApprovalData = abi.encode(msg.sender, msg.sender, true, bytes(""));
        return _batch(msg.sender, auctionManager_, fees_, feesApprovalData, bytes(""));
    }

    /// @notice Withdraws fees to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The token address
    /// @param receiver_ The address of the receiver
    function withdrawTransmitterFees(
        uint32 chainSlug_,
        address token_,
        address receiver_,
        uint256 amount_
    ) external returns (uint40 requestCount) {
        address transmitter = msg.sender;

        PayloadSubmitParams[] memory payloadSubmitParamsArray = IFeesManager(
            addressResolver__.feesManager()
        ).getWithdrawTransmitterCreditsPayloadParams(
                transmitter,
                chainSlug_,
                token_,
                receiver_,
                amount_
            );

        RequestMetadata memory requestMetadata = RequestMetadata({
            appGateway: addressResolver__.feesManager(),
            auctionManager: address(0),
            maxFees: 0,
            winningBid: Bid({transmitter: transmitter, fee: 0, extraData: new bytes(0)}),
            onCompleteData: bytes(""),
            onlyReadRequests: false,
            consumeFrom: transmitter,
            queryCount: 0,
            finalizeCount: 1
        }); // finalize for plug contract
        requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
        requests[requestCount] = requestMetadata;
        // same transmitter can execute requests without auction
        watcherPrecompile__().startProcessingRequest(requestCount, transmitter);
    }
    /// @notice Returns the fees for a request
    /// @param requestCount_ The ID of the request
    /// @return fees The fees data
    function getFees(uint40 requestCount_) external view returns (uint256) {
        return requests[requestCount_].maxFees;
    }
}
