// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

error NotAuthorized();
error NotBridge();
error NotSocket();
error ConnectorUnavailable();
error InvalidTokenContract();
error ZeroAddressReceiver();
error ZeroAddress();
error ZeroAmount();
error InsufficientFunds();
error InvalidSigner();
error InvalidFunction();
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
error PromisesNotResolved();
error InvalidPromise();
error InvalidIndex();
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
