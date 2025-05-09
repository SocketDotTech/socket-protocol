# Custom Error Codes

## base/PlugBase.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `SocketAlreadyInitialized()` | `0xc9500b00` |

## interfaces/IWatcherPrecompile.sol

| Error                                 | Signature    |
| ------------------------------------- | ------------ |
| `InvalidChainSlug()`                  | `0xbff6b106` |
| `InvalidConnection()`                 | `0x63228f29` |
| `InvalidTimeoutRequest()`             | `0x600ca372` |
| `InvalidPayloadId()`                  | `0xfa0b8c86` |
| `InvalidCaller()`                     | `0x48f5c3ed` |
| `InvalidGateway()`                    | `0xfc9dfe85` |
| `InvalidSwitchboard()`                | `0xf63c9e4d` |
| `RequestAlreadyCancelled()`           | `0xc70f47d8` |
| `RequestCancelled()`                  | `0xe3cf2258` |
| `AlreadyStarted()`                    | `0x1fbde445` |
| `RequestNotProcessing()`              | `0x07ba8aaa` |
| `InvalidLevelNumber()`                | `0x5022f14b` |
| `DeadlineNotPassedForOnChainRevert()` | `0x7006aa10` |

## protocol/AddressResolver.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `InvalidAppGateway(address)` | `0x0e66940d` |

## protocol/AsyncPromise.sol

| Error                           | Signature    |
| ------------------------------- | ------------ |
| `PromiseAlreadyResolved()`      | `0x56b63537` |
| `OnlyForwarderOrLocalInvoker()` | `0xa9fb0b28` |
| `PromiseAlreadySetUp()`         | `0x927c53d5` |
| `PromiseRevertFailed()`         | `0x0175b9de` |

## protocol/payload-delivery/AuctionManager.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `InvalidBid()`               | `0xc6388ef7` |
| `MaxReAuctionCountReached()` | `0xf2b4388c` |

## protocol/payload-delivery/ContractFactoryPlug.sol

| Error                      | Signature    |
| -------------------------- | ------------ |
| `DeploymentFailed()`       | `0x30116425` |
| `ExecutionFailed()`        | `0xacfdb444` |
| `information(bool,,bytes)` | `0x3a82a1f3` |

## protocol/payload-delivery/FeesManager.sol

| Error                            | Signature    |
| -------------------------------- | ------------ |
| `InsufficientCreditsAvailable()` | `0xe61dc0aa` |
| `NoFeesForTransmitter()`         | `0x248bac55` |
| `NoCreditsBlocked()`             | `0xada9eb4c` |
| `InvalidCaller()`                | `0x48f5c3ed` |
| `InvalidUserSignature()`         | `0xe3fb657c` |
| `AppGatewayNotWhitelisted()`     | `0x84e5309f` |
| `InvalidAmount()`                | `0x2c5211c6` |
| `InsufficientBalance()`          | `0xf4d678b8` |

## protocol/payload-delivery/FeesPlug.sol

| Error                                               | Signature    |
| --------------------------------------------------- | ------------ |
| `InsufficientTokenBalance(address,uint256,uint256)` | `0xebd6ced9` |
| `InvalidDepositAmount()`                            | `0xfe9ba5cd` |
| `TokenNotWhitelisted(address)`                      | `0xea3bff2e` |

## protocol/payload-delivery/app-gateway/DeliveryUtils.sol

| Error                                | Signature    |
| ------------------------------------ | ------------ |
| `PayloadTooLarge()`                  | `0x492f620d` |
| `OnlyAppGateway()`                   | `0xfec944ea` |
| `WinningBidExists()`                 | `0xe8733654` |
| `InsufficientFees()`                 | `0x8d53e553` |
| `ReadOnlyRequests()`                 | `0x5f16b0e6` |
| `RequestPayloadCountLimitExceeded()` | `0xcbef144b` |
| `MaxMsgValueLimitExceeded()`         | `0x97b4e8ce` |

## protocol/payload-delivery/app-gateway/FeesHelpers.sol

| Error                                         | Signature    |
| --------------------------------------------- | ------------ |
| `NewMaxFeesLowerThanCurrent(uint256,uint256)` | `0x1345dda1` |

## protocol/socket/Socket.sol

| Error                                     | Signature    |
| ----------------------------------------- | ------------ |
| `PayloadAlreadyExecuted(ExecutionStatus)` | `0xf4c54edd` |
| `VerificationFailed()`                    | `0x439cc0cd` |
| `LowGasLimit()`                           | `0xd38edae0` |
| `InvalidSlug()`                           | `0x290a8315` |
| `DeadlinePassed()`                        | `0x70f65caa` |
| `InsufficientMsgValue()`                  | `0x78f38f76` |
| `ReadOnlyCall()`                          | `0xcf8fd6f1` |

## protocol/socket/SocketConfig.sol

| Error                           | Signature    |
| ------------------------------- | ------------ |
| `InvalidConnection()`           | `0x63228f29` |
| `InvalidSwitchboard()`          | `0xf63c9e4d` |
| `SwitchboardExists()`           | `0x2dff8555` |
| `SwitchboardExistsOrDisabled()` | `0x1c7d2487` |

## protocol/socket/SocketFeeManager.sol

| Error                | Signature    |
| -------------------- | ------------ |
| `InsufficientFees()` | `0x8d53e553` |
| `FeeTooLow()`        | `0x732f9413` |

## protocol/socket/switchboard/FastSwitchboard.sol

| Error               | Signature    |
| ------------------- | ------------ |
| `AlreadyAttested()` | `0x35d90805` |
| `WatcherNotFound()` | `0xa278e4ad` |

## protocol/utils/AccessControl.sol

| Error               | Signature    |
| ------------------- | ------------ |
| `NoPermit(bytes32)` | `0x962f6333` |

## protocol/utils/AddressResolverUtil.sol

| Error                                     | Signature    |
| ----------------------------------------- | ------------ |
| `OnlyPayloadDelivery()`                   | `0x7ccc3a43` |
| `OnlyWatcherPrecompile()`                 | `0x663a892a` |
| `OnlyWatcherPrecompileOrDeliveryHelper()` | `0xe93a2814` |

## protocol/utils/common/Errors.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `NotSocket()`                | `0xc59f8f7c` |
| `ZeroAddress()`              | `0xd92e233d` |
| `TimeoutDelayTooLarge()`     | `0xc10bfe64` |
| `TimeoutAlreadyResolved()`   | `0x7dc8be06` |
| `ResolvingTimeoutTooEarly()` | `0x28fd4c50` |
| `LimitReached()`             | `0x3dd19101` |
| `FeesAlreadyPaid()`          | `0xd3b1ad69` |
| `NotAuctionManager()`        | `0x87944c26` |
| `CallFailed()`               | `0x3204506f` |
| `PlugNotFound()`             | `0x5f1ac76a` |
| `InvalidAppGateway()`        | `0x82ded261` |
| `AppGatewayAlreadyCalled()`  | `0xb224683f` |
| `InvalidInboxCaller()`       | `0x4f1aa61e` |
| `InvalidCallerTriggered()`   | `0x3292d247` |
| `PromisesNotResolved()`      | `0xb91dbe7d` |
| `InvalidPromise()`           | `0x45f2d176` |
| `InvalidTransmitter()`       | `0x58a70a0a` |
| `FeesNotSet()`               | `0x2a831034` |
| `InvalidTokenAddress()`      | `0x1eb00b06` |
| `InvalidWatcherSignature()`  | `0x5029f14f` |
| `NonceUsed()`                | `0x1f6d5aef` |
| `AuctionClosed()`            | `0x36b6b46d` |
| `AuctionAlreadyStarted()`    | `0x628e3883` |
| `BidExceedsMaxFees()`        | `0x4c923f3c` |
| `LowerBidAlreadyExists()`    | `0xaaa1f709` |
| `AsyncModifierNotUsed()`     | `0xb9521e1a` |
| `InvalidIndex()`             | `0x63df8171` |
| `RequestAlreadyExecuted()`   | `0xd6f1f946` |
| `NoAsyncPromiseFound()`      | `0xa2928f68` |
| `PromiseCallerMismatch()`    | `0x2b87f115` |
| `RequestCountMismatch()`     | `0x98bbcbff` |
| `DeliveryHelperNotSet()`     | `0x07e6c946` |

## protocol/watcherPrecompile/WatcherPrecompileConfig.sol

| Error                  | Signature    |
| ---------------------- | ------------ |
| `InvalidGateway()`     | `0xfc9dfe85` |
| `InvalidSwitchboard()` | `0xf63c9e4d` |

## protocol/watcherPrecompile/WatcherPrecompileLimits.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `WatcherFeesNotSet(bytes32)` | `0x1ce1de3f` |
