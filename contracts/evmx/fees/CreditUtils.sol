// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./UserUtils.sol";

/// @title FeesManager
/// @notice Contract for managing fees
abstract contract CreditUtils is UserUtils {
    /// @notice Emitted when fees are blocked for a batch
    /// @param requestCount The batch identifier
    /// @param consumeFrom The consume from address
    /// @param amount The blocked amount
    event CreditsBlocked(uint40 indexed requestCount, address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when transmitter fees are updated
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The new amount deposited
    event TransmitterCreditsUpdated(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );
    event WatcherPrecompileCreditsAssigned(uint256 amount, address consumeFrom);

    /// @notice Emitted when fees are unblocked and assigned to a transmitter
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The unblocked amount
    event CreditsUnblockedAndAssigned(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked
    /// @param requestCount The batch identifier
    /// @param appGateway The app gateway address
    event CreditsUnblocked(uint40 indexed requestCount, address indexed appGateway);

    /// @notice Emitted when insufficient watcher precompile fees are available
    event InsufficientWatcherPrecompileCreditsAvailable(
        uint32 chainSlug,
        address token,
        address consumeFrom
    );

    /// @notice Blocks fees for a request count
    /// @param consumeFrom_ The fees payer address
    /// @param transmitterCredits_ The total fees to block
    /// @param requestCount_ The batch identifier
    /// @dev Only callable by delivery helper
    function blockCredits(
        uint40 requestCount_,
        address consumeFrom_,
        uint256 credits_
    ) external onlyWatcher {
        if (getAvailableCredits(consumeFrom_) < credits_) revert InsufficientCreditsAvailable();

        UserCredits storage userCredit = userCredits[consumeFrom_];
        userCredit.blockedCredits += credits_;

        requestCountCredits[requestCount_] = credits_;
        emit CreditsBlocked(requestCount_, consumeFrom_, credits_);
    }

    /// @notice Unblocks fees after successful execution and assigns them to the transmitter
    /// @param requestCount_ The async ID of the executed batch
    /// @param assignTo_ The address of the transmitter
    function unblockAndAssignCredits(
        uint40 requestCount_,
        address assignTo_
    ) external override onlyWatcher {
        uint256 blockedCredits = requestCountCredits[requestCount_];
        if (blockedCredits == 0) return;

        RequestParams memory requestParams = _getRequestParams(requestCount_);
        uint256 fees = requestParams.requestFeesDetails.maxFees;

        // Unblock fees from deposit
        _updateUserCredits(requestParams.consumeFrom, blockedCredits, fees);

        // Assign fees to transmitter
        userCredits[assignTo_].totalCredits += fees;

        // Clean up storage
        delete requestCountCredits[requestCount_];
        emit CreditsUnblockedAndAssigned(requestCount_, assignTo_, fees);
    }

    function _useAvailableUserCredits(address consumeFrom_, uint256 toConsume_) internal {
        UserCredits storage userCredit = userCredits[consumeFrom_];
        if (userCredit.totalCredits < toConsume_) revert InsufficientCreditsAvailable();
        userCredit.totalCredits -= toConsume_;
    }

    function assignWatcherPrecompileCreditsFromAddress(
        uint256 amount_,
        address consumeFrom_
    ) external onlyWatcher {
        // deduct the fees from the user
        _useAvailableUserCredits(consumeFrom_, amount_);
        // add the fees to the watcher precompile
        watcherPrecompileCredits += amount_;
        emit WatcherPrecompileCreditsAssigned(amount_, consumeFrom_);
    }

    function unblockCredits(uint40 requestCount_) external onlyWatcher {
        RequestParams memory r = _getRequestParams(requestCount_);
        uint256 blockedCredits = requestCountCredits[requestCount_];
        if (blockedCredits == 0) return;

        // Unblock fees from deposit
        _updateUserCredits(r.requestFeesDetails.consumeFrom, blockedCredits, 0);
        delete requestCountCredits[requestCount_];
        emit CreditsUnblocked(requestCount_, r.requestFeesDetails.consumeFrom);
    }

    function _getRequestParams(uint40 requestCount_) internal view returns (RequestParams memory) {
        return watcherPrecompile__().getRequestParams(requestCount_);
    }
}

//  /// @notice Withdraws funds to a specified receiver
//     /// @param chainSlug_ The chain identifier
//     /// @param token_ The address of the token
//     /// @param amount_ The amount of tokens to withdraw
//     /// @param receiver_ The address of the receiver
//     /// @param fees_ The fees data
//     function withdrawTo(
//         uint32 chainSlug_,
//         address token_,
//         uint256 amount_,
//         address receiver_,
//         address auctionManager_,
//         uint256 fees_
//     ) external returns (uint40) {
//         feesManager__().withdrawCredits(
//             msg.sender,
//             chainSlug_,
//             token_,
//             amount_,
//             receiver_
//         );
//         return _batch(msg.sender, auctionManager_, msg.sender, fees_, bytes(""));
//     }

//     /// @notice Withdraws fees to a specified receiver
//     /// @param chainSlug_ The chain identifier
//     /// @param token_ The token address
//     /// @param receiver_ The address of the receiver
//     function withdrawTransmitterFees(
//         uint32 chainSlug_,
//         address token_,
//         address receiver_,
//         uint256 amount_
//     ) external returns (uint40 requestCount) {
//         address transmitter = msg.sender;

//         PayloadSubmitParams[] memory payloadSubmitParamsArray = feesManager__()
//         .getWithdrawTransmitterCreditsPayloadParams(
//                 transmitter,
//                 chainSlug_,
//                 token_,
//                 receiver_,
//                 amount_
//             );

//         RequestMetadata memory requestMetadata = RequestMetadata({
//             appGateway: feesManager__(),
//             auctionManager: address(0),
//             maxFees: 0,
//             winningBid: Bid({transmitter: transmitter, fee: 0, extraData: new bytes(0)}),
//             onCompleteData: bytes(""),
//             onlyReadRequests: false,
//             consumeFrom: transmitter,
//             queryCount: 0,
//             finalizeCount: 1
//         }); // finalize for plug contract
//         requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
//         requests[requestCount] = requestMetadata;
//         // same transmitter can execute requests without auction
//         watcherPrecompile__().startProcessingRequest(requestCount, transmitter);
//     }
