// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

error ZeroAddress();
error InvalidTransmitter();
error InvalidTokenAddress();

// Socket
error NotSocket();
error PlugNotFound();

// EVMx
error TimeoutAlreadyResolved();
error ResolvingTimeoutTooEarly();
error CallFailed();
error InvalidAppGateway();
error AppGatewayAlreadyCalled();
error InvalidCallerTriggered();
error InvalidPromise();
error InvalidWatcherSignature();
error NonceUsed();
error AsyncModifierNotSet();
error WatcherNotSet();
error InvalidTarget();
error InvalidIndex();
error InvalidPayloadSize();
error InvalidScheduleDelay();
error InvalidTimeoutRequest();
/// @notice Error thrown when trying to start or bid a closed auction
error AuctionClosed();
/// @notice Error thrown when trying to start or bid an auction that is not open
error AuctionNotOpen();
/// @notice Error thrown if fees exceed the maximum set fees
error BidExceedsMaxFees();
/// @notice Error thrown if a lower bid already exists
error LowerBidAlreadyExists();
/// @notice Error thrown when request count mismatch
error RequestCountMismatch();

error InvalidAmount();
error InsufficientCreditsAvailable();
error InsufficientBalance();
