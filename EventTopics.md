# Event Topics

## ProxyFactory

| Event          | Arguments                                                   | Topic                                                                |
| -------------- | ----------------------------------------------------------- | -------------------------------------------------------------------- |
| `AdminChanged` | `(proxy: address, admin: address)`                          | `0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f` |
| `Deployed`     | `(proxy: address, implementation: address, admin: address)` | `0xc95935a66d15e0da5e412aca0ad27ae891d20b2fb91cf3994b6a3bf2b8178082` |
| `Upgraded`     | `(proxy: address, implementation: address)`                 | `0x5d611f318680d00598bb735d61bacf0c514c6b50e1e5ad30040a4df2b12791c7` |

## AddressResolver

| Event                        | Arguments                                                   | Topic                                                                |
| ---------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------- |
| `AddressSet`                 | `(name: bytes32, oldAddress: address, newAddress: address)` | `0x9ef0e8c8e52743bb38b83b17d9429141d494b8041ca6d616a6c77cebae9cd8b7` |
| `AsyncPromiseDeployed`       | `(newAsyncPromise: address, salt: bytes32)`                 | `0xb6c5491cf83e09749b1a4dd6a9f07b0e925fcb0a915ac8c2b40e8ab28191c270` |
| `ForwarderDeployed`          | `(newForwarder: address, salt: bytes32)`                    | `0x4dbbecb9cf9c8b93da9743a2b48ea52efe68d69230ab1c1b711891d9d223b29f` |
| `ImplementationUpdated`      | `(contractName: string, newImplementation: address)`        | `0xa1e41aa2c2f3f20d9b63ac06b634d2788768d6034f3d9192cdf7d07374bb16f4` |
| `Initialized`                | `(version: uint64)`                                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugAdded`                  | `(appGateway: address, chainSlug: uint32, plug: address)`   | `0x2cb8d865028f9abf3dc064724043264907615fadc8615a3699a85edb66472273` |

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
| `AuctionEnded`               | `(requestCount: uint40, winningBid: tuple)` | `0x9cc96c8b9e588c26f8beae57fe7fbb59113b82865578b54ff3f025317dcd6895` |
| `AuctionRestarted`           | `(requestCount: uint40)`                    | `0x071867b21946ec4655665f0d4515d3757a5a52f144c762ecfdfb11e1da542b82` |
| `AuctionStarted`             | `(requestCount: uint40)`                    | `0xcd040613cf8ef0cfcaa3af0d711783e827a275fc647c116b74595bf17cb9364f` |
| `BidPlaced`                  | `(requestCount: uint40, bid: tuple)`        | `0xd3dc2f289bc8a88faaaf6a3f4f800dd0eac760a653b067ef749771252a1343b3` |
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

| Event                        | Arguments                                                                    | Topic                                                                |
| ---------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `FeesBlocked`                | `(requestCount: uint40, chainSlug: uint32, token: address, amount: uint256)` | `0xbb23ad39130b455188189b8de52b55fa41a7ea8ee8413dc28ced31e543d0df0c` |
| `FeesDepositedUpdated`       | `(chainSlug: uint32, appGateway: address, token: address, amount: uint256)`  | `0xe82dece33ef85114446a366b7d94538d641968e3ec87bf9f2f5a957ace1086e7` |
| `FeesUnblocked`              | `(requestCount: uint40, appGateway: address)`                                | `0xc8b27128d97a92b6664c696ac891afaa87c9fc7d7c7cda17d892237589ebd4fc` |
| `FeesUnblockedAndAssigned`   | `(requestCount: uint40, transmitter: address, amount: uint256)`              | `0x04d2986fb321499f6bc8263ff6e65d823570e186dcdc16c04c6b388ccd0f29a8` |
| `Initialized`                | `(version: uint64)`                                                          | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                    | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                    | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                     | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `TransmitterFeesUpdated`     | `(requestCount: uint40, transmitter: address, amount: uint256)`              | `0x9839a0f8408a769f0f3bb89025b64a6cff279673c77d2de3ab8d59b1841fcd5f` |

## FeesPlug

| Event                        | Arguments                                                | Topic                                                                |
| ---------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------- |
| `ConnectorPlugDisconnected`  | `()`                                                     | `0xc2af098c82dba3c4b00be8bda596d62d13b98a87b42626fefa67e0bb0e198fdd` |
| `FeesDeposited`              | `(appGateway: address, token: address, amount: uint256)` | `0x0fd38537e815732117cfdab41ba9b6d3eb2c5799d44039c100c05fc9c112f235` |
| `FeesWithdrawn`              | `(token: address, amount: uint256, receiver: address)`   | `0x87044da2612407bc001bb0985725dcc651a0dc71eaabfd1d7e8617ca85a8c19c` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                 | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                      | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                      | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `TokenRemovedFromWhitelist`  | `(token: address)`                                       | `0xdd2e6d9f52cbe8f695939d018b7d4a216dc613a669876163ac548b916489d917` |
| `TokenWhitelisted`           | `(token: address)`                                       | `0x6a65f90b1a644d2faac467a21e07e50e3f8fa5846e26231d30ae79a417d3d262` |

## Socket

| Event                        | Arguments                                                                                                   | Topic                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `AppGatewayCallRequested`    | `(callId: bytes32, chainSlug: uint32, plug: address, appGateway: address, params: bytes32, payload: bytes)` | `0x392cb36fae7bd0470268c65b15c32a745b37168c4ccd13348c59bd9170f3b3e8` |
| `ExecutionFailed`            | `(payloadId: bytes32, returnData: bytes)`                                                                   | `0xd255d8a333980d77af4f9179384057def133983cb02db3e1fdb70c4dc14102e8` |
| `ExecutionSuccess`           | `(payloadId: bytes32, returnData: bytes)`                                                                   | `0xc54787fbe087097b182e713f16d3443ad2e67cbe6732628451dd3695a11814c2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                                                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                                                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                                    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugConnected`              | `(plug: address, appGateway: address, switchboard: address)`                                                | `0x99c37c6da3bd69c6d59967915f8339f11a0a17fed28c615efb19457fdec0d7db` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                                                                         | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                                                                         | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `SwitchboardAdded`           | `(switchboard: address)`                                                                                    | `0x1595852923edfbbf906f09fc8523e4cfb022a194773c4d1509446b614146ee88` |
| `SwitchboardDisabled`        | `(switchboard: address)`                                                                                    | `0x1b4ee41596b4e754e5665f01ed6122b356f7b36ea0a02030804fac7fa0fdddfc` |

## SocketBatcher

| Event                        | Arguments                                | Topic                                                                |
| ---------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |

## WatcherPrecompile

| Event                        | Arguments                                                                                                   | Topic                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `CalledAppGateway`           | `(callId: bytes32, chainSlug: uint32, plug: address, appGateway: address, params: bytes32, payload: bytes)` | `0x255bcf22d238fe60f6611670cd7919d2bc890283be2fdaf6d2ad3411e777e33c` |
| `FinalizeRequested`          | `(digest: bytes32, params: tuple)`                                                                          | `0x5bc623895e2e50e307b4c3ba21df61ddfe68de0e084bb85eb1d42d4596532589` |
| `Finalized`                  | `(payloadId: bytes32, proof: bytes)`                                                                        | `0x7e6e3e411317567fb9eabe3eb86768c3e33c46e38a50790726e916939b4918d6` |
| `Initialized`                | `(version: uint64)`                                                                                         | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `MarkedRevert`               | `(payloadId: bytes32, isRevertingOnchain: bool)`                                                            | `0xcf1fd844cb4d32cbebb5ca6ce4ac834fe98da3ddac44deb77fffd22ad933824c` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                                                   | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                                                   | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                                    | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PromiseNotResolved`         | `(payloadId: bytes32, asyncPromise: address)`                                                               | `0xbcf0d0c678940566e9e64f0c871439395bd5fb5c39bca3547b126fe6ee467937` |
| `PromiseResolved`            | `(payloadId: bytes32, asyncPromise: address)`                                                               | `0x1b1b5810494fb3e17f7c46547e6e67cd6ad3e6001ea6fb7d12ea0241ba13c4ba` |
| `QueryRequested`             | `(params: tuple)`                                                                                           | `0xca81bf0029a549d7e6e3a9c668a717472f4330a6a5ec4350304a9e79bf437345` |
| `RequestSubmitted`           | `(middleware: address, requestCount: uint40, payloadParamsArray: tuple[])`                                  | `0xb856562fcff2119ba754f0486f47c06087ebc1842bff464faf1b2a1f8d273b1d` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                                                                         | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                                                                         | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `TimeoutRequested`           | `(timeoutId: bytes32, target: address, payload: bytes, executeAt: uint256)`                                 | `0xdf94fed77e41734b8a17815476bbbf88e2db15d762f42a30ddb9d7870f2fb858` |
| `TimeoutResolved`            | `(timeoutId: bytes32, target: address, payload: bytes, executedAt: uint256)`                                | `0x221462ec065e22637f794ec3a7edb17b2f04bec88f0546dda308bc37a83801b8` |

## WatcherPrecompileConfig

| Event                        | Arguments                                                                               | Topic                                                                |
| ---------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `Initialized`                | `(version: uint64)`                                                                     | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OnChainContractSet`         | `(chainSlug: uint32, socket: address, contractFactoryPlug: address, feesPlug: address)` | `0xd24cf816377e3c571e7bc798dd43d3d5fc78c32f7fc94b42898b0d37c5301a4e` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                               | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                               | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PlugAdded`                  | `(appGateway: address, chainSlug: uint32, plug: address)`                               | `0x2cb8d865028f9abf3dc064724043264907615fadc8615a3699a85edb66472273` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                                                     | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                                                     | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
| `SwitchboardSet`             | `(chainSlug: uint32, sbType: bytes32, switchboard: address)`                            | `0x6273f161f4a795e66ef3585d9b4442ef3796b32337157fdfb420b5281e4cf2e3` |

## WatcherPrecompileLimits

| Event                        | Arguments                                                          | Topic                                                                |
| ---------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `AppGatewayActivated`        | `(appGateway: address, maxLimit: uint256, ratePerSecond: uint256)` | `0x44628d7d5628b9fbc2c84ea9bf3bd3987fa9cde8d2b28e2d5ceb451f916cb8b9` |
| `Initialized`                | `(version: uint64)`                                                | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `LimitParamsUpdated`         | `(updates: tuple[])`                                               | `0x81576b12f4d507fd0543afd25a86785573a595334c2c7eb8ca8ec1b0a56a55b3` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                          | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                          | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                           | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`                                | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`                                | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## DeliveryHelper

| Event                        | Arguments                                                                                                                                 | Topic                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `AuctionEnded`               | `(requestCount: uint40, winningBid: tuple)`                                                                                               | `0x9cc96c8b9e588c26f8beae57fe7fbb59113b82865578b54ff3f025317dcd6895` |
| `BidTimeoutUpdated`          | `(newBidTimeout: uint256)`                                                                                                                | `0xd4552e666d0e4e343fb2b13682972a8f0c7f1a86e252d6433b356f0c0e817c3d` |
| `CallBackReverted`           | `(requestCount_: uint40, payloadId_: bytes32)`                                                                                            | `0xcecb2641ea89470f68bf9f852d731e123505424e4dcfd770c7ea9e2e25326b1b` |
| `FeesIncreased`              | `(appGateway: address, requestCount: uint40, newMaxFees: uint256)`                                                                        | `0x63ee9e9e84d216b804cb18f51b7f7511254b0c1f11304b7a3aa34d57511aa6dc` |
| `Initialized`                | `(version: uint64)`                                                                                                                       | `0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                                                                                                                 | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                                                                                                                 | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)`                                                                                                  | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `PayloadSubmitted`           | `(requestCount: uint40, appGateway: address, payloadSubmitParams: tuple[], fees: tuple, auctionManager: address, onlyReadRequests: bool)` | `0x204c4de167e7a12fc9ad8231fa3d877639ed95a66bd19e1a55d1f68088d4c784` |
| `RequestCancelled`           | `(requestCount: uint40)`                                                                                                                  | `0xff191657769be72fc08def44c645014c60d18cb24b9ca05c9a33406a28253245` |

## FastSwitchboard

| Event                        | Arguments                                | Topic                                                                |
| ---------------------------- | ---------------------------------------- | -------------------------------------------------------------------- |
| `Attested`                   | `(digest_: bytes32, watcher: address)`   | `0x3d83c7bc55c269e0bc853ddc0d7b9fca30216ecc43779acb4e36b7e0ad1c71e4` |
| `OwnershipHandoverCanceled`  | `(pendingOwner: address)`                | `0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92` |
| `OwnershipHandoverRequested` | `(pendingOwner: address)`                | `0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d` |
| `OwnershipTransferred`       | `(oldOwner: address, newOwner: address)` | `0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0` |
| `RoleGranted`                | `(role: bytes32, grantee: address)`      | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked`                | `(role: bytes32, revokee: address)`      | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |
