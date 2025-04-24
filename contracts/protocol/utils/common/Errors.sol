// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

error NotSocket();
error ZeroAddress();
error TimeoutDelayTooLarge();
error TimeoutAlreadyResolved();
error ResolvingTimeoutTooEarly();
error LimitReached();
error FeesAlreadyPaid();
error NotAuctionManager();
error CallFailed();
error PlugNotFound();
error InvalidAppGateway();
error AppGatewayAlreadyCalled();
error InvalidInboxCaller();
error InvalidCallerTriggered();
error PromisesNotResolved();
error InvalidPromise();
error InvalidTransmitter();
error FeesNotSet();
error InvalidTokenAddress();
error InvalidWatcherSignature();
error NonceUsed();
/// @notice Error thrown when trying to start or bid a closed auction
error AuctionClosed();
/// @notice Error thrown when trying to start an ongoing auction
error AuctionAlreadyStarted();
/// @notice Error thrown if fees exceed the maximum set fees
error BidExceedsMaxFees();
/// @notice Error thrown if a lower bid already exists
error LowerBidAlreadyExists();
error AsyncModifierNotUsed();
error InvalidIndex();
error RequestAlreadyExecuted();
/// @notice Error thrown when no async promise is found
error NoAsyncPromiseFound();
/// @notice Error thrown when promise caller mismatch
error PromiseCallerMismatch();
/// @notice Error thrown when request count mismatch
error RequestCountMismatch();
/// @notice Error thrown when delivery helper is not set
error DeliveryHelperNotSet();
