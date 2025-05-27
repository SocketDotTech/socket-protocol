// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

error ZeroAddress();
error InvalidTransmitter();
error InvalidTokenAddress();
error InvalidSwitchboard();
error SocketAlreadyInitialized();

// Socket
error NotSocket();
error PlugNotFound();

// EVMx
error ResolvingScheduleTooEarly();
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
error InvalidChainSlug();
error InvalidPayloadSize();
error InvalidScheduleDelay();
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
/// @notice Error thrown when a caller is invalid
error InvalidCaller();

/// @notice Error thrown when a gateway is invalid
error InvalidGateway();
/// @notice Error thrown when a request is already cancelled
error RequestAlreadyCancelled();
error DeadlineNotPassedForOnChainRevert();

error InvalidBid();
error MaxReAuctionCountReached();
error MaxMsgValueLimitExceeded();
/// @notice Error thrown when an invalid address attempts to call the Watcher only function
error OnlyWatcherAllowed();
error InvalidPrecompileData();
error InvalidCallType();
error NotRequestHandler();
error NotInvoker();
error NotPromiseResolver();
error RequestPayloadCountLimitExceeded();
error InsufficientFees();
error RequestAlreadySettled();
error NoWriteRequest();
error AlreadyAssigned();

error OnlyAppGateway();
error NewMaxFeesLowerThanCurrent(uint256 currentMaxFees, uint256 newMaxFees);
error InvalidContract();
error InvalidData();
error InvalidNonce();
error InvalidSignature();
