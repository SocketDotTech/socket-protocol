# Function Signatures

## ProxyFactory

| Function | Signature |
| -------- | --------- |
| `adminOf` | `0x2abbef15` |
| `changeAdmin` | `0x1acfd02a` |
| `deploy` | `0x545e7c61` |
| `deployAndCall` | `0x4314f120` |
| `deployDeterministic` | `0x3729f922` |
| `deployDeterministicAndCall` | `0xa97b90d5` |
| `initCodeHash` | `0xdb4c545e` |
| `predictDeterministicAddress` | `0x5414dff0` |
| `upgrade` | `0x99a88ec4` |
| `upgradeAndCall` | `0x9623609d` |

## AddressResolver

| Function | Signature |
| -------- | --------- |
| `asyncPromiseBeacon` | `0xc0fbc0ef` |
| `asyncPromiseCounter` | `0x97cdbf4c` |
| `asyncPromiseImplementation` | `0x59531b8d` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `clearPromises` | `0x96e03234` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `contractsToGateways` | `0x5bc03a67` |
| `defaultAuctionManager` | `0x8f27cdc6` |
| `deliveryHelper` | `0x71eaa36f` |
| `deployAsyncPromiseContract` | `0x00afbf9d` |
| `feesManager` | `0x05a9e073` |
| `forwarderBeacon` | `0x945709ae` |
| `forwarderImplementation` | `0xe38d60a1` |
| `getAsyncPromiseAddress` | `0xb6400df5` |
| `getForwarderAddress` | `0x48c0b3e0` |
| `getOrDeployForwarderContract` | `0xe8d616a8` |
| `getPromises` | `0xa01afb0d` |
| `initialize` | `0xc4d66de8` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `setAsyncPromiseImplementation` | `0xeb506eab` |
| `setContractsToGateways` | `0xb08dd08b` |
| `setDefaultAuctionManager` | `0xede8b4b5` |
| `setDeliveryHelper` | `0x75523822` |
| `setFeesManager` | `0x1c89382a` |
| `setForwarderImplementation` | `0x83b1e974` |
| `setWatcherPrecompile` | `0x5ca44c9b` |
| `transferOwnership` | `0xf2fde38b` |
| `version` | `0x54fd4d50` |
| `watcherPrecompile__` | `0x1de360c3` |

## AsyncPromise

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `callbackData` | `0xef44c272` |
| `callbackSelector` | `0x2764f92f` |
| `deliveryHelper__` | `0xc031dfb4` |
| `forwarder` | `0xf645d4f9` |
| `initialize` | `0xc0c53b8b` |
| `localInvoker` | `0x45eb87f4` |
| `markOnchainRevert` | `0x7734a84e` |
| `markResolved` | `0xdd94d9b2` |
| `resolved` | `0x3f6fa655` |
| `state` | `0xc19d93fb` |
| `then` | `0x0bf2ba15` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |

## Forwarder

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `chainSlug` | `0xb349ba65` |
| `deliveryHelper__` | `0xc031dfb4` |
| `getChainSlug` | `0x0b8c6568` |
| `getOnChainAddress` | `0x9da48789` |
| `initialize` | `0x647c576c` |
| `latestAsyncPromise` | `0xb8a8ba52` |
| `onChainAddress` | `0x8bd0b363` |
| `then` | `0x0bf2ba15` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |

## AuctionManager

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `auctionClosed` | `0x6862ebb0` |
| `auctionEndDelaySeconds` | `0x9087dfdb` |
| `auctionStarted` | `0x7c9c5bb8` |
| `bid` | `0xfcdf49c2` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `deliveryHelper__` | `0xc031dfb4` |
| `endAuction` | `0x1212e653` |
| `evmxSlug` | `0x8bae77c2` |
| `expireBid` | `0x1dd5022c` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initialize` | `0x5f24043b` |
| `maxReAuctionCount` | `0xc367b376` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `reAuctionCount` | `0x9b4b22d3` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `revokeRole` | `0xd547741f` |
| `setAuctionEndDelaySeconds` | `0x88606b1a` |
| `transferOwnership` | `0xf2fde38b` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |
| `whitelistedTransmitters` | `0xc2f1bf5d` |
| `winningBids` | `0x9133f232` |

## ContractFactoryPlug

| Function | Signature |
| -------- | --------- |
| `appGateway` | `0xb82bb881` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `connectSocket` | `0x052615a6` |
| `deployContract` | `0x35041492` |
| `getAddress` | `0x94ca2cb5` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initSocket` | `0x59c92b64` |
| `isSocketInitialized` | `0x9a7d9a9b` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `rescueFunds` | `0x6ccae054` |
| `revokeRole` | `0xd547741f` |
| `socket__` | `0xc6a261d2` |
| `transferOwnership` | `0xf2fde38b` |

## FeesManager

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `appGatewayFeeBalances` | `0x46a312be` |
| `blockFees` | `0x1c0ac675` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `deliveryHelper__` | `0xc031dfb4` |
| `evmxSlug` | `0x8bae77c2` |
| `feesCounter` | `0xb94f4778` |
| `getAvailableFees` | `0xe3d07506` |
| `incrementFeesDeposited` | `0x4f88fe32` |
| `initialize` | `0x6f6186bd` |
| `isFeesEnough` | `0x7d274c6a` |
| `isNonceUsed` | `0x5d00bb12` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `renounceOwnership` | `0x715018a6` |
| `requestCountBlockedFees` | `0xd09604ed` |
| `requestOwnershipHandover` | `0x25692962` |
| `sbType` | `0x745de344` |
| `transferOwnership` | `0xf2fde38b` |
| `transmitterFees` | `0xefb4cdea` |
| `unblockAndAssignFees` | `0x3c5366a2` |
| `unblockFees` | `0xc1867a4b` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |
| `withdrawFees` | `0xe1a69364` |
| `withdrawTransmitterFees` | `0x8c047bbd` |

## FeesPlug

| Function | Signature |
| -------- | --------- |
| `appGateway` | `0xb82bb881` |
| `balanceOf` | `0x70a08231` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `connectSocket` | `0x052615a6` |
| `deposit` | `0x8340f549` |
| `distributeFee` | `0x7aeee972` |
| `feesRedeemed` | `0x58f8782b` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initSocket` | `0x59c92b64` |
| `isSocketInitialized` | `0x9a7d9a9b` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `removeTokenFromWhitelist` | `0x306275be` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `rescueFunds` | `0x6ccae054` |
| `revokeRole` | `0xd547741f` |
| `socket__` | `0xc6a261d2` |
| `transferOwnership` | `0xf2fde38b` |
| `whitelistToken` | `0x6247f6f2` |
| `whitelistedTokens` | `0xdaf9c210` |
| `withdrawFees` | `0x9ba372c2` |

## Socket

| Function | Signature |
| -------- | --------- |
| `callAppGateway` | `0x31ed7099` |
| `callCounter` | `0xc0f9882e` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `chainSlug` | `0xb349ba65` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `connect` | `0x295058ef` |
| `disableSwitchboard` | `0xe545b261` |
| `execute` | `0x2c6571a9` |
| `getPlugConfig` | `0xf9778ee0` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `isValidSwitchboard` | `0xb2d67675` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `payloadExecuted` | `0x3eaeac3d` |
| `registerSwitchboard` | `0x74f5b1fc` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `rescueFunds` | `0x6ccae054` |
| `revokeRole` | `0xd547741f` |
| `transferOwnership` | `0xf2fde38b` |
| `version` | `0x54fd4d50` |

## SocketBatcher

| Function | Signature |
| -------- | --------- |
| `attestAndExecute` | `0x841f0228` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `rescueFunds` | `0x6ccae054` |
| `socket__` | `0xc6a261d2` |
| `transferOwnership` | `0xf2fde38b` |

## WatcherPrecompile

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `appGatewayCalled` | `0xc6767cf1` |
| `batchPayloadIds` | `0x02b74f98` |
| `callAppGateways` | `0xdede3465` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `cancelRequest` | `0x50ad0779` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `deliveryHelper__` | `0xc031dfb4` |
| `evmxSlug` | `0x8bae77c2` |
| `expiryTime` | `0x99bc0aea` |
| `finalize` | `0x7ffecf2e` |
| `finalized` | `0x81c051de` |
| `getBatchPayloadIds` | `0xfd83cd1f` |
| `getBatches` | `0xcb95b7b3` |
| `getCurrentRequestCount` | `0x5715abbb` |
| `getDigest` | `0xeba9500e` |
| `getPayloadParams` | `0xae5eeb77` |
| `getRequestParams` | `0x71263d0d` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initialize` | `0xb7dc6b77` |
| `isNonceUsed` | `0x5d00bb12` |
| `isPromiseExecuted` | `0x17a2cdf0` |
| `markRevert` | `0x1c75dad5` |
| `maxTimeoutDelayInSeconds` | `0x46fbc9d7` |
| `nextBatchCount` | `0x333a3963` |
| `nextRequestCount` | `0xfef72893` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `payloadCounter` | `0x550ce1d5` |
| `payloads` | `0x58722672` |
| `query` | `0x16ad71bc` |
| `renounceOwnership` | `0x715018a6` |
| `requestBatchIds` | `0xf865c4a7` |
| `requestOwnershipHandover` | `0x25692962` |
| `requestParams` | `0x5ce2d853` |
| `resolvePromises` | `0xccb1caff` |
| `resolveTimeout` | `0xa67c0781` |
| `revokeRole` | `0xd547741f` |
| `setExpiryTime` | `0x30fc4cff` |
| `setMaxTimeoutDelayInSeconds` | `0x65d480fc` |
| `setTimeout` | `0x9c29ec74` |
| `startProcessingRequest` | `0x77290f24` |
| `submitRequest` | `0x16b47482` |
| `timeoutCounter` | `0x94f6522e` |
| `timeoutRequests` | `0xcdf85751` |
| `transferOwnership` | `0xf2fde38b` |
| `updateTransmitter` | `0xb228a22c` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileConfig__` | `0xa816cbd9` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompileLimits__` | `0xb2ad6c48` |
| `watcherPrecompile__` | `0x1de360c3` |
| `watcherProofs` | `0x3fa3166b` |

## WatcherPrecompileConfig

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `contractFactoryPlug` | `0xd8427483` |
| `deliveryHelper__` | `0xc031dfb4` |
| `evmxSlug` | `0x8bae77c2` |
| `feesPlug` | `0xd1ba159d` |
| `getPlugConfigs` | `0x8a028c38` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initialize` | `0x6ecf2b22` |
| `isNonceUsed` | `0x5d00bb12` |
| `isValidPlug` | `0xec8aef74` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `revokeRole` | `0xd547741f` |
| `setAppGateways` | `0xbdf0b455` |
| `setIsValidPlug` | `0xb3a6bbcf` |
| `setOnChainContracts` | `0x33fa78c2` |
| `setSwitchboard` | `0x61706f1e` |
| `sockets` | `0xb44a23ab` |
| `switchboards` | `0xaa539546` |
| `transferOwnership` | `0xf2fde38b` |
| `verifyConnections` | `0xe283ce7b` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |

## WatcherPrecompileLimits

| Function | Signature |
| -------- | --------- |
| `LIMIT_DECIMALS` | `0x1e65497d` |
| `addressResolver__` | `0x6a750469` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `consumeLimit` | `0xc22f5a13` |
| `defaultLimit` | `0xe26b013b` |
| `defaultRatePerSecond` | `0x16d7acdf` |
| `deliveryHelper__` | `0xc031dfb4` |
| `getCurrentLimit` | `0x1a065507` |
| `getLimitParams` | `0x2ff81ee0` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initialize` | `0x1794bb3c` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `revokeRole` | `0xd547741f` |
| `setDefaultLimit` | `0x995284b1` |
| `setDefaultRatePerSecond` | `0xa44df657` |
| `transferOwnership` | `0xf2fde38b` |
| `updateLimitParams` | `0x01b2a5a0` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |

## DeliveryHelper

| Function | Signature |
| -------- | --------- |
| `addressResolver__` | `0x6a750469` |
| `batch` | `0x039cc50a` |
| `bidTimeout` | `0x94090d0b` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `cancelRequest` | `0x50ad0779` |
| `clearQueue` | `0xf22cb874` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `deliveryHelper__` | `0xc031dfb4` |
| `endTimeout` | `0x9c3bb867` |
| `finishRequest` | `0xeab148c0` |
| `getDeliveryHelperPlugAddress` | `0xb709bd9f` |
| `getFees` | `0xfbf4ec4b` |
| `getRequestMetadata` | `0x5f1dde51` |
| `handleRequestReverts` | `0x8fe9734f` |
| `increaseFees` | `0xe9b304da` |
| `initialize` | `0x7265580f` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `queue` | `0x1b9396f5` |
| `queuePayloadParams` | `0x3c362159` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `requests` | `0xb71a5e58` |
| `saltCounter` | `0xa04c6809` |
| `startRequestProcessing` | `0xf61474a9` |
| `transferOwnership` | `0xf2fde38b` |
| `updateBidTimeout` | `0xa29f83d1` |
| `watcherPrecompileConfig` | `0x8618a912` |
| `watcherPrecompileLimits` | `0xa71cd97d` |
| `watcherPrecompile__` | `0x1de360c3` |
| `withdrawTo` | `0x74c33667` |

## FastSwitchboard

| Function | Signature |
| -------- | --------- |
| `allowPacket` | `0x21e9ec80` |
| `attest` | `0x63671b60` |
| `cancelOwnershipHandover` | `0x54d1f13d` |
| `chainSlug` | `0xb349ba65` |
| `completeOwnershipHandover` | `0xf04e283e` |
| `grantRole` | `0x2f2ff15d` |
| `hasRole` | `0x91d14854` |
| `initialPacketCount` | `0x7c138814` |
| `isAttested` | `0xc13c2396` |
| `nextNonce` | `0x0cd55abf` |
| `owner` | `0x8da5cb5b` |
| `ownershipHandoverExpiresAt` | `0xfee81cf4` |
| `registerSwitchboard` | `0x74f5b1fc` |
| `renounceOwnership` | `0x715018a6` |
| `requestOwnershipHandover` | `0x25692962` |
| `rescueFunds` | `0x6ccae054` |
| `revokeRole` | `0xd547741f` |
| `socket__` | `0xc6a261d2` |
| `transferOwnership` | `0xf2fde38b` |

