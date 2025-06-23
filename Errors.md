# Custom Error Codes


## evmx/fees/FeesPool.sol

| Error | Signature |
|-------|-----------|
| `TransferFailed()` | `0x90b8ec18` |

## evmx/helpers/AsyncPromise.sol

| Error | Signature |
|-------|-----------|
| `PromiseAlreadyResolved()` | `0x56b63537` |
| `OnlyInvoker()` | `0x74ed21f5` |
| `PromiseAlreadySetUp()` | `0x927c53d5` |
| `PromiseRevertFailed()` | `0x0175b9de` |
| `NotLatestPromise()` | `0x39ca95d3` |

## evmx/plugs/ContractFactoryPlug.sol

| Error | Signature |
|-------|-----------|
| `DeploymentFailed()` | `0x30116425` |
| `ExecutionFailed(bytes32,bytes)` | `0xd255d8a3` |
| `information(bool,,bytes)` | `0x3a82a1f3` |

## evmx/plugs/FeesPlug.sol

| Error | Signature |
|-------|-----------|
| `InsufficientTokenBalance(address,uint256,uint256)` | `0xebd6ced9` |
| `InvalidDepositAmount()` | `0xfe9ba5cd` |
| `TokenNotWhitelisted(address)` | `0xea3bff2e` |

## evmx/watcher/RequestHandler.sol

| Error | Signature |
|-------|-----------|
| `InsufficientMaxFees()` | `0x0e5bc492` |

## protocol/Socket.sol

| Error | Signature |
|-------|-----------|
| `PayloadAlreadyExecuted(ExecutionStatus)` | `0xf4c54edd` |
| `VerificationFailed()` | `0x439cc0cd` |
| `LowGasLimit()` | `0xd38edae0` |
| `InsufficientMsgValue()` | `0x78f38f76` |

## protocol/SocketConfig.sol

| Error | Signature |
|-------|-----------|
| `SwitchboardExists()` | `0x2dff8555` |
| `SwitchboardExistsOrDisabled()` | `0x1c7d2487` |

## protocol/SocketFeeManager.sol

| Error | Signature |
|-------|-----------|
| `InsufficientFees()` | `0x8d53e553` |
| `FeeTooLow()` | `0x732f9413` |

## protocol/SocketUtils.sol

| Error | Signature |
|-------|-----------|
| `OnlyOffChain()` | `0x9cbfe066` |
| `SimulationFailed()` | `0x2fbab3ac` |

## protocol/switchboard/CCTPSwitchboard.sol

| Error | Signature |
|-------|-----------|
| `RemoteExecutionNotFound()` | `0xbd506972` |
| `DigestMismatch()` | `0x582e0907` |
| `PrevBatchDigestHashMismatch()` | `0xc9864e9d` |
| `NotAttested()` | `0x99efb890` |
| `NotExecuted()` | `0xec84b1da` |
| `InvalidDomain()` | `0xeb127982` |
| `InvalidSender()` | `0xddb5de5e` |
| `OnlyMessageTransmitter()` | `0x935ac89c` |

## protocol/switchboard/FastSwitchboard.sol

| Error | Signature |
|-------|-----------|
| `AlreadyAttested()` | `0x35d90805` |
| `WatcherNotFound()` | `0xa278e4ad` |

## utils/AccessControl.sol

| Error | Signature |
|-------|-----------|
| `NoPermit(bytes32)` | `0x962f6333` |

## utils/common/Errors.sol

| Error | Signature |
|-------|-----------|
| `ZeroAddress()` | `0xd92e233d` |
| `InvalidTransmitter()` | `0x58a70a0a` |
| `InvalidTokenAddress()` | `0x1eb00b06` |
| `InvalidSwitchboard()` | `0xf63c9e4d` |
| `SocketAlreadyInitialized()` | `0xc9500b00` |
| `NotSocket()` | `0xc59f8f7c` |
| `PlugNotFound()` | `0x5f1ac76a` |
| `ResolvingScheduleTooEarly()` | `0x207e8731` |
| `CallFailed()` | `0x3204506f` |
| `InvalidAppGateway()` | `0x82ded261` |
| `AppGatewayAlreadyCalled()` | `0xb224683f` |
| `InvalidCallerTriggered()` | `0x3292d247` |
| `InvalidPromise()` | `0x45f2d176` |
| `InvalidWatcherSignature()` | `0x5029f14f` |
| `NonceUsed()` | `0x1f6d5aef` |
| `AsyncModifierNotSet()` | `0xcae106f9` |
| `WatcherNotSet()` | `0x42d473a7` |
| `InvalidTarget()` | `0x82d5d76a` |
| `InvalidIndex()` | `0x63df8171` |
| `InvalidChainSlug()` | `0xbff6b106` |
| `InvalidPayloadSize()` | `0xfbdf7954` |
| `InvalidOnChainAddress()` | `0xb758c606` |
| `InvalidScheduleDelay()` | `0x9a993219` |
| `AuctionClosed()` | `0x36b6b46d` |
| `AuctionNotOpen()` | `0xf0460077` |
| `BidExceedsMaxFees()` | `0x4c923f3c` |
| `LowerBidAlreadyExists()` | `0xaaa1f709` |
| `RequestCountMismatch()` | `0x98bbcbff` |
| `InvalidAmount()` | `0x2c5211c6` |
| `InsufficientCreditsAvailable()` | `0xe61dc0aa` |
| `InsufficientBalance()` | `0xf4d678b8` |
| `InvalidCaller()` | `0x48f5c3ed` |
| `InvalidGateway()` | `0xfc9dfe85` |
| `RequestAlreadyCancelled()` | `0xc70f47d8` |
| `DeadlineNotPassedForOnChainRevert()` | `0x7006aa10` |
| `InvalidBid()` | `0xc6388ef7` |
| `MaxReAuctionCountReached()` | `0xf2b4388c` |
| `MaxMsgValueLimitExceeded()` | `0x97b4e8ce` |
| `OnlyWatcherAllowed()` | `0xdf7d227c` |
| `InvalidPrecompileData()` | `0x320062c0` |
| `InvalidCallType()` | `0x39d2eb55` |
| `NotRequestHandler()` | `0x8f8cba5b` |
| `NotInvoker()` | `0x8a6353d1` |
| `NotPromiseResolver()` | `0x86d876b2` |
| `RequestPayloadCountLimitExceeded()` | `0xcbef144b` |
| `InsufficientFees()` | `0x8d53e553` |
| `RequestAlreadySettled()` | `0x66fad465` |
| `NoWriteRequest()` | `0x9dcd3065` |
| `AlreadyAssigned()` | `0x9688dc51` |
| `OnlyAppGateway()` | `0xfec944ea` |
| `NewMaxFeesLowerThanCurrent(uint256,uint256)` | `0x1345dda1` |
| `InvalidContract()` | `0x6eefed20` |
| `InvalidData()` | `0x5cb045db` |
| `InvalidSignature()` | `0x8baa579f` |
| `DeadlinePassed()` | `0x70f65caa` |
