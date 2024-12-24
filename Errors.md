# Custom Error Codes

## AddressResolver.sol

| Error                                                                     | Signature    |
| ------------------------------------------------------------------------- | ------------ |
| `AppGatewayContractAlreadySetByDifferentSender(address contractAddress_)` | `0x4062307a` |

## AsyncPromise.sol

| Error                      | Signature    |
| -------------------------- | ------------ |
| `PromiseAlreadyResolved()` | `0x56b63537` |

## apps/payload-delivery/FeesManager.sol

| Error               | Signature    |
| ------------------- | ------------ |
| `FeesAlreadyPaid()` | `0xd3b1ad69` |

## apps/payload-delivery/app-gateway/BatchAsync.sol

| Error                           | Signature    |
| ------------------------------- | ------------ |
| `AllPayloadsExecuted()`         | `0x6bc43bfe` |
| `NotFromForwarder()`            | `0xe83aa6bd` |
| `CallFailed(bytes32 payloadId)` | `0xe6176664` |
| `DelayLimitReached()`           | `0xaa2ddd8e` |
| `PayloadTooLarge()`             | `0x492f620d` |

## apps/payload-delivery/app-gateway/QueueAsync.sol

| Error              | Signature    |
| ------------------ | ------------ |
| `InvalidPromise()` | `0x45f2d176` |

## apps/super-token/LimitHook.sol

| Error                 | Signature    |
| --------------------- | ------------ |
| `BurnLimitExceeded()` | `0x85e72fd4` |
| `MintLimitExceeded()` | `0xb643bfa6` |

## apps/super-token/SuperToken.sol

| Error                        | Signature    |
| ---------------------------- | ------------ |
| `InsufficientBalance()`      | `0xf4d678b8` |
| `InsufficientLockedTokens()` | `0x4f6d2a3e` |
| `NotController()`            | `0x23019e67` |

## base/AppGatewayBase.sol

| Error              | Signature    |
| ------------------ | ------------ |
| `InvalidPromise()` | `0x45f2d176` |
| `FeesDataNotSet()` | `0x2ec61400` |

## common/Errors.sol

| Error                    | Signature    |
| ------------------------ | ------------ |
| `NotAuthorized()`        | `0xea8e4eb5` |
| `NotBridge()`            | `0x7fea9dc5` |
| `NotSocket()`            | `0xc59f8f7c` |
| `ConnectorUnavailable()` | `0xb1efb84a` |
| `InvalidTokenContract()` | `0x29bdfb34` |
| `ZeroAddressReceiver()`  | `0x96bbcf1e` |
| `ZeroAddress()`          | `0xd92e233d` |
| `ZeroAmount()`           | `0x1f2a2005` |
| `InsufficientFunds()`    | `0x356680b7` |
| `InvalidSigner()`        | `0x815e1d64` |
| `InvalidFunction()`      | `0xdb2079c3` |

## libraries/ECDSA.sol

| Error                                         | Signature    |
| --------------------------------------------- | ------------ |
| `ECDSAInvalidSignature()`                     | `0xf645eedf` |
| `ECDSAInvalidSignatureLength(uint256 length)` | `0x367e2e27` |
| `ECDSAInvalidSignatureS(bytes32 s)`           | `0x5fedc3a1` |

## libraries/RescueFundsLib.sol

| Error                   | Signature    |
| ----------------------- | ------------ |
| `InvalidTokenAddress()` | `0x1eb00b06` |

## socket/Socket.sol

| Error                      | Signature    |
| -------------------------- | ------------ |
| `PayloadAlreadyExecuted()` | `0xe17bd578` |
| `VerificationFailed()`     | `0x439cc0cd` |
| `InvalidAppGateway()`      | `0x82ded261` |
| `LowGasLimit()`            | `0xd38edae0` |
| `InvalidSlug()`            | `0x290a8315` |

## socket/SocketBase.sol

| Error                  | Signature    |
| ---------------------- | ------------ |
| `InvalidTransmitter()` | `0x58a70a0a` |

## socket/SocketConfig.sol

| Error                  | Signature    |
| ---------------------- | ------------ |
| `SwitchboardExists()`  | `0x2dff8555` |
| `InvalidConnection()`  | `0x63228f29` |
| `InvalidSwitchboard()` | `0xf63c9e4d` |

## socket/switchboard/FastSwitchboard.sol

| Error               | Signature    |
| ------------------- | ------------ |
| `AlreadyAttested()` | `0x35d90805` |
| `WatcherNotFound()` | `0xa278e4ad` |

## socket/switchboard/SwitchboardBase.sol

| Error            | Signature    |
| ---------------- | ------------ |
| `InvalidNonce()` | `0x756688fe` |

## socket/utils/AccessControl.sol

| Error                    | Signature    |
| ------------------------ | ------------ |
| `NoPermit(bytes32 role)` | `0x3db46572` |

## socket/utils/SignatureVerifier.sol

| Error                | Signature    |
| -------------------- | ------------ |
| `InvalidSigLength()` | `0xd2453293` |

## utils/Ownable.sol

| Error           | Signature    |
| --------------- | ------------ |
| `OnlyOwner()`   | `0x5fc483c5` |
| `OnlyNominee()` | `0x7c91ccdd` |

## watcherPrecompile/WatcherPrecompile.sol

| Error                | Signature    |
| -------------------- | ------------ |
| `InvalidChainSlug()` | `0xbff6b106` |
