// SPDX-License-Identifier: MIT
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
error PlugDisconnected();
error InvalidAppGateway();
error AppGatewayAlreadyCalled();
error InvalidInboxCaller();
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
