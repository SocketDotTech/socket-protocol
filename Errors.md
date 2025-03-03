# Custom Error Codes

## apps/super-token-lockable/LimitHook.sol

| Error                 | Signature    |
| --------------------- | ------------ |
| `BurnLimitExceeded()` | `0x85e72fd4` |
| `MintLimitExceeded()` | `0xb643bfa6` |

## apps/super-token-lockable/SuperTokenLockable.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `InsufficientBalance()`      | `0xf4d678b8` |
| `InsufficientLockedTokens()` | `0x4f6d2a3e` |

## base/PlugBase.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `SocketAlreadyInitialized()` | `0xc9500b00` |

## mock/MockSocket.sol

| Error                      | Signature    |
| -------------------------- | ------------ |
| `PayloadAlreadyExecuted()` | `0xe17bd578` |
| `VerificationFailed()`     | `0x439cc0cd` |
| `LowGasLimit()`            | `0xd38edae0` |
| `InvalidSlug()`            | `0x290a8315` |

## mock/MockWatcherPrecompile.sol

| Error                  | Signature    |
| ---------------------- | ------------ |
| `InvalidChainSlug()`   | `0xbff6b106` |
| `InvalidTransmitter()` | `0x58a70a0a` |

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

## protocol/payload-delivery/ContractFactoryPlug.sol

| Error                     | Signature    |
| ------------------------- | ------------ |
| `DeploymentFailed()`      | `0x30116425` |
| `ExecutionFailed()`       | `0xacfdb444` |
| `information(bool,bytes)` | `0x1a5c6d63` |

## protocol/payload-delivery/FeesPlug.sol

| Error                               | Signature    |
| ----------------------------------- | ------------ |
| `FeesAlreadyPaid()`                 | `0xd3b1ad69` |
| `InsufficientTokenBalance(address)` | `0x642faafa` |
| `InvalidDepositAmount()`            | `0xfe9ba5cd` |
| `TokenNotWhitelisted(address)`      | `0xea3bff2e` |

## protocol/payload-delivery/app-gateway/AuctionManager.sol

| Error                     | Signature    |
| ------------------------- | ------------ |
| `AuctionClosed()`         | `0x36b6b46d` |
| `AuctionAlreadyStarted()` | `0x628e3883` |
| `BidExceedsMaxFees()`     | `0x4c923f3c` |
| `InvalidTransmitter()`    | `0x58a70a0a` |
| `LowerBidAlreadyExists()` | `0xaaa1f709` |

## protocol/payload-delivery/app-gateway/BatchAsync.sol

| Error                   | Signature    |
| ----------------------- | ------------ |
| `AllPayloadsExecuted()` | `0x6bc43bfe` |
| `NotFromForwarder()`    | `0xe83aa6bd` |
| `CallFailed(bytes32)`   | `0xe22e3683` |
| `PayloadTooLarge()`     | `0x492f620d` |
| `OnlyAppGateway()`      | `0xfec944ea` |
| `WinningBidExists()`    | `0xe8733654` |
| `InsufficientFees()`    | `0x8d53e553` |

## protocol/payload-delivery/app-gateway/FeesManager.sol

| Error                         | Signature    |
| ----------------------------- | ------------ |
| `InsufficientFeesAvailable()` | `0x51488f54` |
| `NoFeesForTransmitter()`      | `0x248bac55` |
| `NoFeesBlocked()`             | `0x116d68f9` |
| `InvalidWatcherSignature()`   | `0x5029f14f` |
| `NonceUsed()`                 | `0x1f6d5aef` |

## protocol/socket/Socket.sol

| Error                                     | Signature    |
| ----------------------------------------- | ------------ |
| `PayloadAlreadyExecuted(ExecutionStatus)` | `0xf4c54edd` |
| `VerificationFailed()`                    | `0x439cc0cd` |
| `LowGasLimit()`                           | `0xd38edae0` |
| `InvalidSlug()`                           | `0x290a8315` |
| `DeadlinePassed()`                        | `0x70f65caa` |

## protocol/socket/SocketConfig.sol

| Error                           | Signature    |
| ------------------------------- | ------------ |
| `SwitchboardExists()`           | `0x2dff8555` |
| `InvalidConnection()`           | `0x63228f29` |
| `InvalidSwitchboard()`          | `0xf63c9e4d` |
| `SwitchboardExistsOrDisabled()` | `0x1c7d2487` |

## protocol/socket/SocketUtils.sol

| Error                  | Signature    |
| ---------------------- | ------------ |
| `InvalidTransmitter()` | `0x58a70a0a` |

## protocol/socket/switchboard/FastSwitchboard.sol

| Error               | Signature    |
| ------------------- | ------------ |
| `AlreadyAttested()` | `0x35d90805` |
| `WatcherNotFound()` | `0xa278e4ad` |

## protocol/socket/switchboard/SwitchboardBase.sol

| Error            | Signature    |
| ---------------- | ------------ |
| `InvalidNonce()` | `0x756688fe` |

## protocol/utils/AccessControl.sol

| Error               | Signature    |
| ------------------- | ------------ |
| `NoPermit(bytes32)` | `0x962f6333` |

## protocol/utils/AddressResolverUtil.sol

| Error                     | Signature    |
| ------------------------- | ------------ |
| `OnlyPayloadDelivery()`   | `0x7ccc3a43` |
| `OnlyWatcherPrecompile()` | `0x663a892a` |

## protocol/utils/common/Errors.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `NotAuthorized()`            | `0xea8e4eb5` |
| `NotBridge()`                | `0x7fea9dc5` |
| `NotSocket()`                | `0xc59f8f7c` |
| `ConnectorUnavailable()`     | `0xb1efb84a` |
| `InvalidTokenContract()`     | `0x29bdfb34` |
| `ZeroAddressReceiver()`      | `0x96bbcf1e` |
| `ZeroAddress()`              | `0xd92e233d` |
| `ZeroAmount()`               | `0x1f2a2005` |
| `InsufficientFunds()`        | `0x356680b7` |
| `InvalidSigner()`            | `0x815e1d64` |
| `InvalidFunction()`          | `0xdb2079c3` |
| `TimeoutDelayTooLarge()`     | `0xc10bfe64` |
| `TimeoutAlreadyResolved()`   | `0x7dc8be06` |
| `ResolvingTimeoutTooEarly()` | `0x28fd4c50` |
| `LimitReached()`             | `0x3dd19101` |
| `FeesAlreadyPaid()`          | `0xd3b1ad69` |
| `NotAuctionManager()`        | `0x87944c26` |
| `CallFailed()`               | `0x3204506f` |
| `PlugDisconnected()`         | `0xe741bafb` |
| `InvalidAppGateway()`        | `0x82ded261` |
| `AppGatewayAlreadyCalled()`  | `0xb224683f` |
| `InvalidInboxCaller()`       | `0x4f1aa61e` |
| `PromisesNotResolved()`      | `0xb91dbe7d` |
| `InvalidPromise()`           | `0x45f2d176` |
| `InvalidIndex()`             | `0x63df8171` |
| `InvalidTransmitter()`       | `0x58a70a0a` |
| `FeesNotSet()`               | `0x2a831034` |
| `InvalidTokenAddress()`      | `0x1eb00b06` |
| `InvalidWatcherSignature()`  | `0x5029f14f` |
| `NonceUsed()`                | `0x1f6d5aef` |

## protocol/watcherPrecompile/WatcherPrecompile.sol

| Error                     | Signature    |
| ------------------------- | ------------ |
| `InvalidChainSlug()`      | `0xbff6b106` |
| `InvalidConnection()`     | `0x63228f29` |
| `InvalidTransmitter()`    | `0x58a70a0a` |
| `InvalidTimeoutRequest()` | `0x600ca372` |
| `InvalidPayloadId()`      | `0xfa0b8c86` |
| `InvalidCaller()`         | `0x48f5c3ed` |

## protocol/watcherPrecompile/WatcherPrecompileLimits.sol

| Error                                            | Signature    |
| ------------------------------------------------ | ------------ |
| `ActionNotSupported(address,bytes32)`            | `0xa219158f` |
| `NotDeliveryHelper()`                            | `0x29029c67` |
| `LimitExceeded(address,bytes32,uint256,uint256)` | `0x80bb2621` |
