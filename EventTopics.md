# Event Topics

## AuctionManager

| Event                        | Arguments                                   | Topic                                                                |
| ---------------------------- | ------------------------------------------- | -------------------------------------------------------------------- |
| `AuctionEndDelaySecondsSet`  | `(auctionEndDelaySeconds: uint256)`         | `0xf38f0d9dc8459cf5426728c250d115196a4c065ebc1a6c29da24764a8c0da722` |
| `AuctionEnded`               | `(requestCount: uint40, winningBid: tuple)` | `0xede4ec1efc469fac10dcb4930f70be4cd21f3700ed61c91967c19a7cd7c0d86e` |
| `AuctionRestarted`           | `(requestCount: uint40)`                    | `0x071867b21946ec4655665f0d4515d3757a5a52f144c762ecfdfb11e1da542b82` |
| `AuctionStarted`             | `(requestCount: uint40)`                    | `0xcd040613cf8ef0cfcaa3af0d711783e827a275fc647c116b74595bf17cb9364f` |
| `BidPlaced`                  | `(requestCount: uint40, bid: tuple)`        | `0x7f79485e4c9aeea5d4899bc6f7c63b22ac1f4c01d2d28c801e94732fee657b5d` |
| `Initialized`                | `(version: uint64)`                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `MaxReAuctionCountSet`       | `(maxReAuctionCount: uint256)`              | `0x2f6fadde7ab8ab83d21ab10c3bc09dde179f8696d47c4176581facf0c6f96bbf` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`         | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`         | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## Socket

| Event                        | Arguments                                                                                                            | Topic                                                                |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `AppGatewayCallRequested`    | `(triggerId: bytes32, appGatewayId: bytes32, switchboard: bytes32, plug: bytes32, overrides: bytes, payload: bytes)` | `0xf83cee1d13047d8a1785495ac352da7c9ac5725641f76506899def19750c7696` |
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

## FeesManager

| Event                         | Arguments                                                                                               | Topic                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `CreditsBlocked`              | `(requestCount: uint40, consumeFrom: address, amount: uint256)`                                         | `0xf037c15aef41440aa823cf1fdeaea332105d8b23d52557f6670189b5d76f1eed` |
| `CreditsTransferred`          | `(from: address, to: address, amount: uint256)`                                                         | `0xed198cadddd93e734cbf04cb1c3226d9bafaeb504cedbd8ee36b830b0cb9e7a5` |
| `CreditsUnblocked`            | `(requestCount: uint40, consumeFrom: address)`                                                          | `0x45db29ef2701319155cac058aa2f56ce1f73e0e238161d3db9f8c9a47655210d` |
| `CreditsUnblockedAndAssigned` | `(requestCount: uint40, consumeFrom: address, transmitter: address, amount: uint256)`                   | `0x38fd327622576a468e1b2818b00f50c8854703633ef8e583e1f31662888ffac2` |
| `CreditsUnwrapped`            | `(consumeFrom: address, amount: uint256)`                                                               | `0xdcc9473b722b4c953617ab373840b365298a520bc7f20ce94fa7314f4a857774` |
| `CreditsWrapped`              | `(consumeFrom: address, amount: uint256)`                                                               | `0x40246503613721eb4acf4020c6c56b6a16e5d08713316db0bea5210e8819c592` |
| `Deposited`                   | `(chainSlug: uint32, token: address, depositTo: address, creditAmount: uint256, nativeAmount: uint256)` | `0x72aedd284699bbd7a987e6942b824cfd6c627e354cb5a0760ac5768acd473f4a` |
| `FeesPlugSet`                 | `(chainSlug: uint32, feesPlug: bytes32)`                                                                | `0x677a00737c8099aa9e6c554104ca7941deb59125335cfb3d0d9f604f178db59c` |
| `FeesPoolSet`                 | `(feesPool: address)`                                                                                   | `0xd07af3fd70b48ab3c077a8d45c3a288498d905d0e3d1e65bc171f6c2e890d8ef` |
| `Initialized`                 | `(version: uint64)`                                                                                     | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`   | `(pendingOwner: address)`                                                                               | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`  | `(pendingOwner: address)`                                                                               | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`        | `(oldOwner: address, newOwner: address)`                                                                | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `WithdrawFailed`              | `(payloadId: bytes32)`                                                                                  | `0xea147eb2109f71b4bda9e57528ba08b84821087a31cb43a7851dc6ff743d9be7` |

## FeesPool

| Event                        | Arguments                                       | Topic                                                                |
| ---------------------------- | ----------------------------------------------- | -------------------------------------------------------------------- |
| `NativeDeposited`            | `(from: address, amount: uint256)`              | `0xb5d7700fb0cf415158b8db7cc7c39f0eab16a825c92e221404b4c8bb099b4bbb` |
| `NativeWithdrawn`            | `(success: bool, to: address, amount: uint256)` | `0xa81f1c8490022ee829d2e1a231053f5dbecad46caee71f6ea38a9db663a3f12b` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                       | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                       | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`        | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`             | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`             | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## AddressResolver

| Event                          | Arguments                                           | Topic                                                                |
| ------------------------------ | --------------------------------------------------- | -------------------------------------------------------------------- |
| `AsyncDeployerUpdated`         | `(asyncDeployer_: address)`                         | `0x4df9cdd01544e8f6b0326650bc0b55611f47ce5ba2faa522d21fb675e9fc1f73` |
| `ContractAddressUpdated`       | `(contractId_: bytes32, contractAddress_: address)` | `0xdf5ec2c15e11ce657bb21bc09c0b5ba95e315b4dba9934c6e311f47559babf28` |
| `DefaultAuctionManagerUpdated` | `(defaultAuctionManager_: address)`                 | `0x60f296739208a505ead7fb622df0f76b7791b824481b120a2300bdaf85e3e3d6` |
| `DeployForwarderUpdated`       | `(deployForwarder_: address)`                       | `0x237b9bc9fef7508a02ca9ccca81f6965e500064a58024cae1218035da865fd2b` |
| `FeesManagerUpdated`           | `(feesManager_: address)`                           | `0x94e67aa1341a65767dfde81e62fd265bfbade1f5744bfd3cd73f99a6eca0572a` |
| `Initialized`                  | `(version: uint64)`                                 | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`    | `(pendingOwner: address)`                           | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`   | `(pendingOwner: address)`                           | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`         | `(oldOwner: address, newOwner: address)`            | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `WatcherUpdated`               | `(watcher_: address)`                               | `0xc13081d38d92b454cdb6ca20bbc65c12fa43a7a14a1529204ced5b6350052bb0` |

## AsyncDeployer

| Event                        | Arguments                                            | Topic                                                                |
| ---------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------- |
| `AsyncPromiseDeployed`       | `(newAsyncPromise: address, salt: bytes32)`          | `0xb6c5491cf83e09749b1a4dd6a9f07b0e925fcb0a915ac8c2b40e8ab28191c270` |
| `ForwarderDeployed`          | `(newForwarder: address, salt: bytes32)`             | `0x4dbbecb9cf9c8b93da9743a2b48ea52efe68d69230ab1c1b711891d9d223b29f` |
| `ImplementationUpdated`      | `(contractName: string, newImplementation: address)` | `0xa1e41aa2c2f3f20d9b63ac06b634d2788768d6034f3d9192cdf7d07374bb16f4` |
| `Initialized`                | `(version: uint64)`                                  | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                            | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                            | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`             | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |

## AsyncPromise

| Event         | Arguments           | Topic                                                                |
| ------------- | ------------------- | -------------------------------------------------------------------- |
| `Initialized` | `(version: uint64)` | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |

## DeployForwarder

| Event                        | Arguments                                | Topic                                                                |
| ---------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `Initialized`                | `(version: uint64)`                      | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |

## Forwarder

| Event         | Arguments           | Topic                                                                |
| ------------- | ------------------- | -------------------------------------------------------------------- |
| `Initialized` | `(version: uint64)` | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |

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

## Configurations

| Event                        | Arguments                                                                | Topic                                                                |
| ---------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `Initialized`                | `(version: uint64)`                                                      | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `IsValidPlugSet`             | `(appGateway: address, chainSlug: uint32, plug: bytes32, isValid: bool)` | `0xd7a90efd60960a8435ef282822190655f6bd2ffa14bb350dc23d6f6956056d7e` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                 | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugAdded`                  | `(appGatewayId: bytes32, chainSlug: uint32, plug: bytes32)`              | `0x3734a2406c5c2f2556c82a0819c51e42a135dd102465cc9856594481ea2f1637` |
| `SocketSet`                  | `(chainSlug: uint32, socket: bytes32)`                                   | `0x3200bf6ad2ab31b9220ed9d2f83089d7a1332f55aaa3825c57510743a315165b` |
| `SwitchboardSet`             | `(chainSlug: uint32, sbType: bytes32, switchboard: bytes32)`             | `0xcdfbfa261040f4dffb03c7d9493f74b575f2ae533bb43fd7b5d5b24ac9d804f4` |

## PromiseResolver

| Event                | Arguments                                        | Topic                                                                |
| -------------------- | ------------------------------------------------ | -------------------------------------------------------------------- |
| `MarkedRevert`       | `(payloadId: bytes32, isRevertingOnchain: bool)` | `0xcf1fd844cb4d32cbebb5ca6ce4ac834fe98da3ddac44deb77fffd22ad933824c` |
| `PromiseNotResolved` | `(payloadId: bytes32, asyncPromise: address)`    | `0xbcf0d0c678940566e9e64f0c871439395bd5fb5c39bca3547b126fe6ee467937` |
| `PromiseResolved`    | `(payloadId: bytes32, asyncPromise: address)`    | `0x1b1b5810494fb3e17f7c46547e6e67cd6ad3e6001ea6fb7d12ea0241ba13c4ba` |

## RequestHandler

| Event                        | Arguments                                                                                                                       | Topic                                                                |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `FeesIncreased`              | `(requestCount: uint40, newMaxFees: uint256)`                                                                                   | `0xf258fca4e49b803ee2a4c2e33b6fcf18bc3982df21f111c00677025bf1ccbb6a` |
| `Initialized`                | `(version: uint64)`                                                                                                             | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                                                                       | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                                                                       | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                                                        | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RequestCancelled`           | `(requestCount: uint40)`                                                                                                        | `0xff191657769be72fc08def44c645014c60d18cb24b9ca05c9a33406a28253245` |
| `RequestCompletedWithErrors` | `(requestCount: uint40)`                                                                                                        | `0xd8d9915dc14b5a29b66cb263e1ea1e99e60418fc21d97f0fbf09cae1281291e2` |
| `RequestSettled`             | `(requestCount: uint40, winner: address)`                                                                                       | `0x1234f98acbe1548b214f4528461a5377f1e2349569c04caa59325e488e7d2aa4` |
| `RequestSubmitted`           | `(hasWrite: bool, requestCount: uint40, totalEstimatedWatcherFees: uint256, requestParams: tuple, payloadParamsArray: tuple[])` | `0x762bac43d5d7689b8911c5654a9d5550804373cead33bc98282067e6166e518f` |

## Watcher

| Event                        | Arguments                                | Topic                                                                |
| ---------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `AppGatewayCallFailed`       | `(triggerId: bytes32)`                   | `0xcaf8475fdade8465ea31672463949e6cf1797fdcdd11eeddbbaf857e1e5907b7` |
| `CalledAppGateway`           | `(triggerId: bytes32)`                   | `0xf659ffb3875368f54fb4ab8f5412ac4518af79701a48076f7a58d4448e4bdd0b` |
| `Initialized`                | `(version: uint64)`                      | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `TriggerFailed`              | `(triggerId: bytes32)`                   | `0x4386783bb0f7cad4ba12f033dbec03dc3441e7757a122f3097a7a4d945c98040` |
| `TriggerFeesSet`             | `(triggerFees: uint256)`                 | `0x7df3967b7c8727af5ac0ee9825d88aafeb899d769bc428b91f8967fa0b623084` |
| `TriggerSucceeded`           | `(triggerId: bytes32)`                   | `0x92d20fbcbf31370b8218e10ed00c5aad0e689022da30a08905ba5ced053219eb` |

## FastSwitchboard

| Event                        | Arguments                                 | Topic                                                                |
| ---------------------------- | ----------------------------------------- | -------------------------------------------------------------------- |
| `Attested`                   | `(payloadId_: bytes32, watcher: address)` | `0x3d83c7bc55c269e0bc853ddc0d7b9fca30216ecc43779acb4e36b7e0ad1c71e4` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                 | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                 | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`  | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`       | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`       | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## ReadPrecompile

| Event           | Arguments                                                              | Topic                                                                |
| --------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `ExpiryTimeSet` | `(expiryTime: uint256)`                                                | `0x07e837e13ad9a34715a6bd45f49bbf12de19f06df79cb0be12b3a7d7f2397fa9` |
| `ReadFeesSet`   | `(readFees: uint256)`                                                  | `0xc674cb6dde3a59f84dbf226832e606ffc54ac8a169e1568fc834c7813010f926` |
| `ReadRequested` | `(transaction: tuple, readAtBlockNumber: uint256, payloadId: bytes32)` | `0xbcad63ac625c0f3cb23b62b126567728fcf5950ca8e559150e764eced73e794a` |

## SchedulePrecompile

| Event                          | Arguments                                                        | Topic                                                                |
| ------------------------------ | ---------------------------------------------------------------- | -------------------------------------------------------------------- |
| `ExpiryTimeSet`                | `(expiryTime_: uint256)`                                         | `0x07e837e13ad9a34715a6bd45f49bbf12de19f06df79cb0be12b3a7d7f2397fa9` |
| `MaxScheduleDelayInSecondsSet` | `(maxScheduleDelayInSeconds_: uint256)`                          | `0xfd5e4f0e96753ffb08a583390c2f151c51001d8e560625ab93b7fa7b4dac6d75` |
| `ScheduleCallbackFeesSet`      | `(scheduleCallbackFees_: uint256)`                               | `0x82a2f41efc81ce7bfabc0affda7354dae42a3d09bd74a6196e8904b223138a52` |
| `ScheduleFeesPerSecondSet`     | `(scheduleFeesPerSecond_: uint256)`                              | `0x7901a21229f6d2543d8676f53e21214d15f42513e7d46e0dcb510357222bdc7c` |
| `ScheduleRequested`            | `(payloadId: bytes32, executeAfter: uint256, deadline: uint256)` | `0xd099d3e3d0f0e2c9c40e0066affeea125aab71d763b7ab0a279ccec3dff70b64` |
| `ScheduleResolved`             | `(payloadId: bytes32)`                                           | `0x925dc6c3ebffa07cac89d6e9675f1a5d04e045f2ed9a4fa442665935cb73e26b` |

## WritePrecompile

| Event                           | Arguments                                                                                                        | Topic                                                                |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `ChainMaxMsgValueLimitsUpdated` | `(chainSlug: uint32, maxMsgValueLimit: uint256)`                                                                 | `0x439087d094fe7dacbba3f0c67032041952d8bd58a891e15af10ced28fed0eb91` |
| `ContractFactoryPlugSet`        | `(chainSlug: uint32, contractFactoryPlug: bytes32)`                                                              | `0xfad552a6feb82bef23201b8dce04b2460bff41b00f26fef3d791572cfdab49c2` |
| `ExpiryTimeSet`                 | `(expiryTime: uint256)`                                                                                          | `0x07e837e13ad9a34715a6bd45f49bbf12de19f06df79cb0be12b3a7d7f2397fa9` |
| `FeesSet`                       | `(writeFees: uint256)`                                                                                           | `0x3346af6da1932164d501f2ec28f8c5d686db5828a36b77f2da4332d89184fe7b` |
| `Initialized`                   | `(version: uint64)`                                                                                              | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`     | `(pendingOwner: address)`                                                                                        | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested`    | `(pendingOwner: address)`                                                                                        | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`          | `(oldOwner: address, newOwner: address)`                                                                         | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `WriteProofRequested`           | `(transmitter: address, digest: bytes32, prevBatchDigestHash: bytes32, deadline: uint256, payloadParams: tuple)` | `0x3247df5b4e8df4ac60c2c1f803b404ee16bc9d84a6b7649865464a8a397b9acb` |
| `WriteProofUploaded`            | `(payloadId: bytes32, proof: bytes)`                                                                             | `0xd8fe3a99a88c9630360418877afdf14e3e79f0f25fee162aeb230633ea740156` |
