# Event Topics

## ProxyFactory

| Event          | Arguments                                                   | Topic                                                                |
| -------------- | ----------------------------------------------------------- | -------------------------------------------------------------------- |
| `AdminChanged` | `(proxy: address, admin: address)`                          | `0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f` |
| `Deployed`     | `(proxy: address, implementation: address, admin: address)` | `0xc95935a66d15e0da5e412aca0ad27ae891d20b2fb91cf3994b6a3bf2b8178082` |
| `Upgraded`     | `(proxy: address, implementation: address)`                 | `0x5d611f318680d00598bb735d61bacf0c514c6b50e1e5ad30040a4df2b12791c7` |

## TestUSDC

| Event      | Arguments                                             | Topic                                                                |
| ---------- | ----------------------------------------------------- | -------------------------------------------------------------------- |
| `Approval` | `(owner: address, spender: address, amount: uint256)` | `0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925` |
| `Transfer` | `(from: address, to: address, amount: uint256)`       | `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |

## AddressResolver

| Event                          | Arguments                                                   | Topic                                                                |
| ------------------------------ | ----------------------------------------------------------- | -------------------------------------------------------------------- |
| `AddressSet`                   | `(name: bytes32, oldAddress: address, newAddress: address)` | `0x9ef0e8c8e52743bb38b83b17d9429141d494b8041ca6d616a6c77cebae9cd8b7` |
| `AsyncPromiseDeployed`         | `(newAsyncPromise: address, salt: bytes32)`                 | `0xb6c5491cf83e09749b1a4dd6a9f07b0e925fcb0a915ac8c2b40e8ab28191c270` |
| `ContractsToGatewaysUpdated`   | `(contractAddress_: address, appGateway_: address)`         | `0xb870bb0c6b5ea24214ae6c653af6c2a8b6240d5838f82132703ee5c069b14b4c` |
| `DefaultAuctionManagerUpdated` | `(defaultAuctionManager_: address)`                         | `0x60f296739208a505ead7fb622df0f76b7791b824481b120a2300bdaf85e3e3d6` |
| `DeliveryHelperUpdated`        | `(deliveryHelper_: address)`                                | `0xc792471d30bbabcf9dc9fdba5bfa74f8872ff3c28f6e65e122bdb82a71b83c1c` |
| `FeesManagerUpdated`           | `(feesManager_: address)`                                   | `0x94e67aa1341a65767dfde81e62fd265bfbade1f5744bfd3cd73f99a6eca0572a` |
| `ForwarderDeployed`            | `(newForwarder: address, salt: bytes32)`                    | `0x4dbbecb9cf9c8b93da9743a2b48ea52efe68d69230ab1c1b711891d9d223b29f` |
| `ImplementationUpdated`        | `(contractName: string, newImplementation: address)`        | `0xa1e41aa2c2f3f20d9b63ac06b634d2788768d6034f3d9192cdf7d07374bb16f4` |
| `Initialized`                  | `(version: uint64)`                                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`    | `(pendingOwner: address)`                                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`   | `(pendingOwner: address)`                                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`         | `(oldOwner: address, newOwner: address)`                    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugAdded`                    | `(appGateway: address, chainSlug: uint32, plug: address)`   | `0x2cb8d865028f9abf3dc064724043264907615fadc8615a3699a85edb66472273` |
| `WatcherPrecompileUpdated`     | `(watcherPrecompile_: address)`                             | `0xb00972c0b5c3d3d9ddc6d6a6db612abeb109653a3424d5d972510fa20bff4972` |

## AsyncPromise

| Event         | Arguments           | Topic                                                                |
| ------------- | ------------------- | -------------------------------------------------------------------- |
| `Initialized` | `(version: uint64)` | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |

## Forwarder

| Event         | Arguments           | Topic                                                                |
| ------------- | ------------------- | -------------------------------------------------------------------- |
| `Initialized` | `(version: uint64)` | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |

## AuctionManager

| Event                        | Arguments                                   | Topic                                                                |
| ---------------------------- | ------------------------------------------- | -------------------------------------------------------------------- |
| `AuctionEndDelaySecondsSet`  | `(auctionEndDelaySeconds: uint256)`         | `0xf38f0d9dc8459cf5426728c250d115196a4c065ebc1a6c29da24764a8c0da722` |
| `AuctionEnded`               | `(requestCount: uint40, winningBid: tuple)` | `0xede4ec1efc469fac10dcb4930f70be4cd21f3700ed61c91967c19a7cd7c0d86e` |
| `AuctionRestarted`           | `(requestCount: uint40)`                    | `0x071867b21946ec4655665f0d4515d3757a5a52f144c762ecfdfb11e1da542b82` |
| `AuctionStarted`             | `(requestCount: uint40)`                    | `0xcd040613cf8ef0cfcaa3af0d711783e827a275fc647c116b74595bf17cb9364f` |
| `BidPlaced`                  | `(requestCount: uint40, bid: tuple)`        | `0x7f79485e4c9aeea5d4899bc6f7c63b22ac1f4c01d2d28c801e94732fee657b5d` |
| `Initialized`                | `(version: uint64)`                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`         | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`         | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## ContractFactoryPlug

| Event                        | Arguments                                           | Topic                                                                |
| ---------------------------- | --------------------------------------------------- | -------------------------------------------------------------------- |
| `ConnectorPlugDisconnected`  | `()`                                                | `0xc2af098c82dba3c4b00be8bda596d62d13b98a87b42626fefa67e0bb0e198fdd` |
| `Deployed`                   | `(addr: address, salt: bytes32, returnData: bytes)` | `0x1246c6f8fd9f4abc542c7c8c8f793cfcde6b67aed1976a38aa134fc24af2dfe3` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                           | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                           | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`            | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                 | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                 | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## FeesManager

| Event                                           | Arguments                                                                   | Topic                                                                |
| ----------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `CreditsBlocked`                                | `(requestCount: uint40, consumeFrom: address, amount: uint256)`             | `0xf037c15aef41440aa823cf1fdeaea332105d8b23d52557f6670189b5d76f1eed` |
| `CreditsDeposited`                              | `(chainSlug: uint32, appGateway: address, token: address, amount: uint256)` | `0x7254d040844de2dac4225a23f81bb54acb13d1eadb6e8b369dd251d36a9e8552` |
| `CreditsUnblocked`                              | `(requestCount: uint40, appGateway: address)`                               | `0x45db29ef2701319155cac058aa2f56ce1f73e0e238161d3db9f8c9a47655210d` |
| `CreditsUnblockedAndAssigned`                   | `(requestCount: uint40, transmitter: address, amount: uint256)`             | `0x6f3d11270d1df9aff1aa04d1ea7797a3a572586a31437acc415ac853f625050c` |
| `CreditsUnwrapped`                              | `(consumeFrom: address, amount: uint256)`                                   | `0xdcc9473b722b4c953617ab373840b365298a520bc7f20ce94fa7314f4a857774` |
| `CreditsWrapped`                                | `(consumeFrom: address, amount: uint256)`                                   | `0x40246503613721eb4acf4020c6c56b6a16e5d08713316db0bea5210e8819c592` |
| `Initialized`                                   | `(version: uint64)`                                                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `InsufficientWatcherPrecompileCreditsAvailable` | `(chainSlug: uint32, token: address, consumeFrom: address)`                 | `0xd50bc02f94b9ef4a8aff7438da15a69e443956f56b6aa007cf2c584215e87493` |
| `OwnershipHandoverCanceled`                     | `(pendingOwner: address)`                                                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`                    | `(pendingOwner: address)`                                                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`                          | `(oldOwner: address, newOwner: address)`                                    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `TransmitterCreditsUpdated`                     | `(requestCount: uint40, transmitter: address, amount: uint256)`             | `0x24790626bfbe84d1358ce3e8cb0ff6cfc9eb7ea16e597f43ab607107baf889e3` |
| `WatcherPrecompileCreditsAssigned`              | `(amount: uint256, consumeFrom: address)`                                   | `0x87eddb69736f41b812366535a59efc79b1997f2d237240d7176d210397012e1b` |

## FeesPlug

| Event                        | Arguments                                                                           | Topic                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `ConnectorPlugDisconnected`  | `()`                                                                                | `0xc2af098c82dba3c4b00be8bda596d62d13b98a87b42626fefa67e0bb0e198fdd` |
| `FeesDeposited`              | `(token: address, receiver: address, creditAmount: uint256, nativeAmount: uint256)` | `0xeb4e1b24b7fe377de69f80f7380bda5ba4b43176c6a4d300a3be9009c49f4228` |
| `FeesWithdrawn`              | `(token: address, receiver: address, amount: uint256)`                              | `0x5e110f8bc8a20b65dcc87f224bdf1cc039346e267118bae2739847f07321ffa8` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                           | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                           | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                            | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                                                 | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                                                 | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `TokenRemovedFromWhitelist`  | `(token: address)`                                                                  | `0xdd2e6d9f52cbe8f695939d018b7d4a216dc613a669876163ac548b916489d917` |
| `TokenWhitelisted`           | `(token: address)`                                                                  | `0x6a65f90b1a644d2faac467a21e07e50e3f8fa5846e26231d30ae79a417d3d262` |

## Socket

| Event                        | Arguments                                                                                                            | Topic                                                                |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `AppGatewayCallRequested`    | `(triggerId: bytes32, appGatewayId: bytes32, switchboard: address, plug: address, overrides: bytes, payload: bytes)` | `0x5c88d65ab8ba22a57e582bd8ddfa9801cc0ca6be6cb3182baaedc705a612419e` |
| `ExecutionFailed`            | `(payloadId: bytes32, exceededMaxCopy: bool, returnData: bytes)`                                                     | `0x385334bc68a32c4d164625189adc7633e6074eb1b837fb4d11d768245151e4ce` |
| `ExecutionSuccess`           | `(payloadId: bytes32, exceededMaxCopy: bool, returnData: bytes)`                                                     | `0x324d63a433b21a12b90e79cd2ba736b2a5238be6165e03b750fa4a7d5193d5d9` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                                                            | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                                                            | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                                             | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugConnected`              | `(plug: address, appGatewayId: bytes32, switchboard: address)`                                                       | `0x90c5924e27cfb6e3a688e729083681f30494ae2615ae14aac3bc807a0c436a88` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                                                                                  | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                                                                                  | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `SocketFeeManagerUpdated`    | `(oldSocketFeeManager: address, newSocketFeeManager: address)`                                                       | `0xdcb02e10d5220346a4638aa2826eaab1897306623bc40a427049e4ebd12255b4` |
| `SwitchboardAdded`           | `(switchboard: address)`                                                                                             | `0x1595852923edfbbf906f09fc8523e4cfb022a194773c4d1509446b614146ee88` |
| `SwitchboardDisabled`        | `(switchboard: address)`                                                                                             | `0x1b4ee41596b4e754e5665f01ed6122b356f7b36ea0a02030804fac7fa0fdddfc` |
| `SwitchboardEnabled`         | `(switchboard: address)`                                                                                             | `0x6909a9974e3eec619bc479ba882d30a5ef1219b72ab1ce6a354516e91be317b8` |

## SocketBatcher

| Event                        | Arguments                                | Topic                                                                |
| ---------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |

## SocketFeeManager

| Event                        | Arguments                                | Topic                                                                |
| ---------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`      | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`      | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `SocketFeesUpdated`          | `(oldFees: uint256, newFees: uint256)`   | `0xcbd4d756fb6198bbcc2e4013cce929f504ad46e9d97c543ef9a8dfea3e407053` |

## WatcherPrecompileConfig

| Event                        | Arguments                                                                               | Topic                                                                |
| ---------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `Initialized`                | `(version: uint64)`                                                                     | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `IsValidPlugSet`             | `(appGateway: address, chainSlug: uint32, plug: address, isValid: bool)`                | `0x61cccc7387868fc741379c7acd9dd346e0ca2e5c067dc5b156fbbc55b1c2fcf5` |
| `OnChainContractSet`         | `(chainSlug: uint32, socket: address, contractFactoryPlug: address, feesPlug: address)` | `0xd24cf816377e3c571e7bc798dd43d3d5fc78c32f7fc94b42898b0d37c5301a4e` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                               | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                               | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugAdded`                  | `(appGatewayId: bytes32, chainSlug: uint32, plug: address)`                             | `0x7b3e14230a721c4737d275f9a63b92c44cb657bcfddbe6fe9b4d9cd9bd8d4a95` |
| `SwitchboardSet`             | `(chainSlug: uint32, sbType: bytes32, switchboard: address)`                            | `0x6273f161f4a795e66ef3585d9b4442ef3796b32337157fdfb420b5281e4cf2e3` |

## WatcherPrecompileLimits

| Event                             | Arguments                                                          | Topic                                                                |
| --------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `AppGatewayActivated`             | `(appGateway: address, maxLimit: uint256, ratePerSecond: uint256)` | `0x44628d7d5628b9fbc2c84ea9bf3bd3987fa9cde8d2b28e2d5ceb451f916cb8b9` |
| `CallBackFeesSet`                 | `(callBackFees: uint256)`                                          | `0x667c97afffb32265f3b4e026d31b81dc223275ff8bb9819e67012197f5799faf` |
| `DefaultLimitAndRatePerSecondSet` | `(defaultLimit: uint256, defaultRatePerSecond: uint256)`           | `0x39def16be1ce80876ad0b0936cfdf88b8be7a1790b6c1da16ba8bdee53367e8e` |
| `FinalizeFeesSet`                 | `(finalizeFees: uint256)`                                          | `0x0b710f92aabbdda2e8c347f802353f34ef27845d79db79efb4884e8790a0d5fb` |
| `Initialized`                     | `(version: uint64)`                                                | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `LimitParamsUpdated`              | `(updates: tuple[])`                                               | `0x81576b12f4d507fd0543afd25a86785573a595334c2c7eb8ca8ec1b0a56a55b3` |
| `OwnershipHandoverCanceled`       | `(pendingOwner: address)`                                          | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`      | `(pendingOwner: address)`                                          | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`            | `(oldOwner: address, newOwner: address)`                           | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `QueryFeesSet`                    | `(queryFees: uint256)`                                             | `0x19569faa0df733d4b0806372423e828b05a5257eb7652da812b90f662bed5cfb` |
| `TimeoutFeesSet`                  | `(timeoutFees: uint256)`                                           | `0xe8a5b23529bc11019d6df86a1ee0d043571d464902a3fa98e7e3e67dbd5981ca` |

## DeliveryHelper

| Event                           | Arguments                                                                                                                                   | Topic                                                                |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `BidTimeoutUpdated`             | `(newBidTimeout: uint256)`                                                                                                                  | `0xd4552e666d0e4e343fb2b13682972a8f0c7f1a86e252d6433b356f0c0e817c3d` |
| `ChainMaxMsgValueLimitsUpdated` | `(chainSlugs: uint32[], maxMsgValueLimits: uint256[])`                                                                                      | `0x17e47f6f0fa0e79831bee11b7c29adc45d9a7bd25acd70b91e4b2bad0f544352` |
| `FeesIncreased`                 | `(appGateway: address, requestCount: uint40, newMaxFees: uint256)`                                                                          | `0x63ee9e9e84d216b804cb18f51b7f7511254b0c1f11304b7a3aa34d57511aa6dc` |
| `Initialized`                   | `(version: uint64)`                                                                                                                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`     | `(pendingOwner: address)`                                                                                                                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`    | `(pendingOwner: address)`                                                                                                                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`          | `(oldOwner: address, newOwner: address)`                                                                                                    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PayloadSubmitted`              | `(requestCount: uint40, appGateway: address, payloadSubmitParams: tuple[], fees: uint256, auctionManager: address, onlyReadRequests: bool)` | `0xc6455dba7c07a5e75c7189040ae9e3478162f333a96365b283b434fd0e32c6b3` |
| `RequestCancelled`              | `(requestCount: uint40)`                                                                                                                    | `0xff191657769be72fc08def44c645014c60d18cb24b9ca05c9a33406a28253245` |

## FastSwitchboard

| Event                        | Arguments                                 | Topic                                                                |
| ---------------------------- | ----------------------------------------- | -------------------------------------------------------------------- |
| `Attested`                   | `(payloadId_: bytes32, watcher: address)` | `0x3d83c7bc55c269e0bc853ddc0d7b9fca30216ecc43779acb4e36b7e0ad1c71e4` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                 | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                 | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`  | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`       | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`       | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## WatcherPrecompile

| Event                         | Arguments                                                                                       | Topic                                                                |
| ----------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `AppGatewayCallFailed`        | `(triggerId: bytes32)`                                                                          | `0xcaf8475fdade8465ea31672463949e6cf1797fdcdd11eeddbbaf857e1e5907b7` |
| `CalledAppGateway`            | `(triggerId: bytes32)`                                                                          | `0xf659ffb3875368f54fb4ab8f5412ac4518af79701a48076f7a58d4448e4bdd0b` |
| `ExpiryTimeSet`               | `(expiryTime: uint256)`                                                                         | `0x07e837e13ad9a34715a6bd45f49bbf12de19f06df79cb0be12b3a7d7f2397fa9` |
| `FinalizeRequested`           | `(digest: bytes32, params: tuple)`                                                              | `0x5bc623895e2e50e307b4c3ba21df61ddfe68de0e084bb85eb1d42d4596532589` |
| `Finalized`                   | `(payloadId: bytes32, proof: bytes)`                                                            | `0x7e6e3e411317567fb9eabe3eb86768c3e33c46e38a50790726e916939b4918d6` |
| `Initialized`                 | `(version: uint64)`                                                                             | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `MarkedRevert`                | `(payloadId: bytes32, isRevertingOnchain: bool)`                                                | `0xcf1fd844cb4d32cbebb5ca6ce4ac834fe98da3ddac44deb77fffd22ad933824c` |
| `MaxTimeoutDelayInSecondsSet` | `(maxTimeoutDelayInSeconds: uint256)`                                                           | `0x3564638b089495c19e7359a040be083841e11da34c22a29ea8d602c8a9805fec` |
| `OwnershipHandoverCanceled`   | `(pendingOwner: address)`                                                                       | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`  | `(pendingOwner: address)`                                                                       | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`        | `(oldOwner: address, newOwner: address)`                                                        | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PromiseNotResolved`          | `(payloadId: bytes32, asyncPromise: address)`                                                   | `0xbcf0d0c678940566e9e64f0c871439395bd5fb5c39bca3547b126fe6ee467937` |
| `PromiseResolved`             | `(payloadId: bytes32, asyncPromise: address)`                                                   | `0x1b1b5810494fb3e17f7c46547e6e67cd6ad3e6001ea6fb7d12ea0241ba13c4ba` |
| `QueryRequested`              | `(params: tuple)`                                                                               | `0xca81bf0029a549d7e6e3a9c668a717472f4330a6a5ec4350304a9e79bf437345` |
| `RequestCancelledFromGateway` | `(requestCount: uint40)`                                                                        | `0x333619ca4a2a9c4ee292aafa3c37215d88afe358afee4a575cfed21d743091c6` |
| `RequestSubmitted`            | `(middleware: address, requestCount: uint40, payloadParamsArray: tuple[])`                      | `0xb856562fcff2119ba754f0486f47c06087ebc1842bff464faf1b2a1f8d273b1d` |
| `TimeoutRequested`            | `(timeoutId: bytes32, target: address, payload: bytes, executeAt: uint256)`                     | `0xdf94fed77e41734b8a17815476bbbf88e2db15d762f42a30ddb9d7870f2fb858` |
| `TimeoutResolved`             | `(timeoutId: bytes32, target: address, payload: bytes, executedAt: uint256, returnData: bytes)` | `0x61122416680ac7038ca053afc2c26983f2c524e5003b1f4d9dea095fbc8f6905` |
| `WatcherPrecompileConfigSet`  | `(watcherPrecompileConfig: address)`                                                            | `0xdc19bca647582b3fbf69a6ffacabf56b4f7a4551d2d0944843712f2d0987a8e5` |
| `WatcherPrecompileLimitsSet`  | `(watcherPrecompileLimits: address)`                                                            | `0xcec7ba89301793a37efb418279f17f8dd77e5959e9f3fbcbc54e40615a14bd8e` |
