# Event Topics

## base/PlugBase.sol

| Event                       | Topic                                                                |
| --------------------------- | -------------------------------------------------------------------- |
| `ConnectorPlugDisconnected` | `0xc2af098c82dba3c4b00be8bda596d62d13b98a87b42626fefa67e0bb0e198fdd` |

## interfaces/IAddressResolver.sol

| Event                                 | Topic                                                                |
| ------------------------------------- | -------------------------------------------------------------------- |
| `AddressSet(bytes32,address,address)` | `0x9ef0e8c8e52743bb38b83b17d9429141d494b8041ca6d616a6c77cebae9cd8b7` |

## interfaces/IMiddleware.sol

| Event                      | Topic                                                                |
| -------------------------- | -------------------------------------------------------------------- |
| `BidPlaced(uint40,Bid)`    | `0xf3ae5b3ee2e40669d77bd3a4cf2bd6b4e74a8a28d2944a88f46978b2754ca431` |
| `AuctionEnded(uint40,Bid)` | `0xe0653b5457803803208b7fd0e583b7be1d8ec58613838fef4f86341ab2e36a04` |

## interfaces/ISocket.sol

| Event                                                                   | Topic                                                                |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `ExecutionSuccess(bytes32,bytes)`                                       | `0xc54787fbe087097b182e713f16d3443ad2e67cbe6732628451dd3695a11814c2` |
| `ExecutionFailed(bytes32,bytes)`                                        | `0xd255d8a333980d77af4f9179384057def133983cb02db3e1fdb70c4dc14102e8` |
| `PlugConnected(address,address,address)`                                | `0x99c37c6da3bd69c6d59967915f8339f11a0a17fed28c615efb19457fdec0d7db` |
| `AppGatewayCallRequested(bytes32,uint32,address,address,bytes32,bytes)` | `0x392cb36fae7bd0470268c65b15c32a745b37168c4ccd13348c59bd9170f3b3e8` |

## interfaces/IWatcherPrecompile.sol

| Event                                                            | Topic                                                                |
| ---------------------------------------------------------------- | -------------------------------------------------------------------- |
| `CalledAppGateway(bytes32,uint32,address,address,bytes32,bytes)` | `0x255bcf22d238fe60f6611670cd7919d2bc890283be2fdaf6d2ad3411e777e33c` |
| `QueryRequested(PayloadParams)`                                  | `0x7488872f7dfa5365c1eb3ff6e87be6f76e1943fd7a0d49e7680ddffd31033864` |
| `FinalizeRequested(address,bytes32,bytes32,PayloadParams)`       | `0xa598ce01fa40f1a400aefe99a30ccdbb45c65ee903b94d98982d8572156f8a02` |
| `Finalized(bytes32,bytes)`                                       | `0x7e6e3e411317567fb9eabe3eb86768c3e33c46e38a50790726e916939b4918d6` |
| `PromiseResolved(bytes32,bool,address)`                          | `0x3f1120f34271f52a541dfc8a71efbe6123ab80730562e8948fa7275514c41bda` |
| `PromiseNotResolved(bytes32,bool,address)`                       | `0xcf395c2f3b165573b3e8f83c5810f6fb22f1659497882dc2e75f8157d241485e` |
| `TimeoutRequested(bytes32,address,bytes,uint256)`                | `0xdf94fed77e41734b8a17815476bbbf88e2db15d762f42a30ddb9d7870f2fb858` |
| `TimeoutResolved(bytes32,address,bytes,uint256)`                 | `0x221462ec065e22637f794ec3a7edb17b2f04bec88f0546dda308bc37a83801b8` |
| `RequestSubmitted(address,uint40,PayloadParams[])`               | `0x5d58a8d0c1df3c5daf9fbdc1e2fb915882f50f1f49dba0ee2d437a787917a697` |

## interfaces/IWatcherPrecompileLimits.sol

| Event                                          | Topic                                                                |
| ---------------------------------------------- | -------------------------------------------------------------------- |
| `LimitParamsUpdated(UpdateLimitParams[])`      | `0x76b76501b1f65d80b7de6c1a42b2245466c1c80504052e7ad48e86b6038d39a1` |
| `AppGatewayActivated(address,uint256,uint256)` | `0x44628d7d5628b9fbc2c84ea9bf3bd3987fa9cde8d2b28e2d5ceb451f916cb8b9` |

## protocol/AddressResolver.sol

| Event                                   | Topic                                                                |
| --------------------------------------- | -------------------------------------------------------------------- |
| `PlugAdded(address,uint32,address)`     | `0x2cb8d865028f9abf3dc064724043264907615fadc8615a3699a85edb66472273` |
| `ForwarderDeployed(address,bytes32)`    | `0x4dbbecb9cf9c8b93da9743a2b48ea52efe68d69230ab1c1b711891d9d223b29f` |
| `AsyncPromiseDeployed(address,bytes32)` | `0xb6c5491cf83e09749b1a4dd6a9f07b0e925fcb0a915ac8c2b40e8ab28191c270` |
| `ImplementationUpdated(string,address)` | `0xa1e41aa2c2f3f20d9b63ac06b634d2788768d6034f3d9192cdf7d07374bb16f4` |

## protocol/payload-delivery/AuctionManager.sol

| Event                      | Topic                                                                |
| -------------------------- | -------------------------------------------------------------------- |
| `AuctionRestarted(uint40)` | `0x071867b21946ec4655665f0d4515d3757a5a52f144c762ecfdfb11e1da542b82` |
| `AuctionStarted(uint40)`   | `0xcd040613cf8ef0cfcaa3af0d711783e827a275fc647c116b74595bf17cb9364f` |
| `AuctionEnded(uint40,Bid)` | `0xe0653b5457803803208b7fd0e583b7be1d8ec58613838fef4f86341ab2e36a04` |
| `BidPlaced(uint40,Bid)`    | `0xf3ae5b3ee2e40669d77bd3a4cf2bd6b4e74a8a28d2944a88f46978b2754ca431` |

## protocol/payload-delivery/ContractFactoryPlug.sol

| Event                             | Topic                                                                |
| --------------------------------- | -------------------------------------------------------------------- |
| `Deployed(address,bytes32,bytes)` | `0x1246c6f8fd9f4abc542c7c8c8f793cfcde6b67aed1976a38aa134fc24af2dfe3` |

## protocol/payload-delivery/FeesManager.sol

| Event                                                  | Topic                                                                |
| ------------------------------------------------------ | -------------------------------------------------------------------- |
| `FeesBlocked(uint40,uint32,address,uint256)`           | `0xbb23ad39130b455188189b8de52b55fa41a7ea8ee8413dc28ced31e543d0df0c` |
| `TransmitterFeesUpdated(uint40,address,uint256)`       | `0x9839a0f8408a769f0f3bb89025b64a6cff279673c77d2de3ab8d59b1841fcd5f` |
| `FeesDepositedUpdated(uint32,address,address,uint256)` | `0xe82dece33ef85114446a366b7d94538d641968e3ec87bf9f2f5a957ace1086e7` |
| `FeesUnblockedAndAssigned(uint40,address,uint256)`     | `0x04d2986fb321499f6bc8263ff6e65d823570e186dcdc16c04c6b388ccd0f29a8` |
| `FeesUnblocked(uint40,address)`                        | `0xc8b27128d97a92b6664c696ac891afaa87c9fc7d7c7cda17d892237589ebd4fc` |

## protocol/payload-delivery/FeesPlug.sol

| Event                                    | Topic                                                                |
| ---------------------------------------- | -------------------------------------------------------------------- |
| `FeesDeposited(address,address,uint256)` | `0x0fd38537e815732117cfdab41ba9b6d3eb2c5799d44039c100c05fc9c112f235` |
| `FeesWithdrawn(address,uint256,address)` | `0x87044da2612407bc001bb0985725dcc651a0dc71eaabfd1d7e8617ca85a8c19c` |
| `TokenWhitelisted(address)`              | `0x6a65f90b1a644d2faac467a21e07e50e3f8fa5846e26231d30ae79a417d3d262` |
| `TokenRemovedFromWhitelist(address)`     | `0xdd2e6d9f52cbe8f695939d018b7d4a216dc613a669876163ac548b916489d917` |

## protocol/payload-delivery/app-gateway/DeliveryUtils.sol

| Event                                                                 | Topic                                                                |
| --------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `CallBackReverted(uint40,bytes32)`                                    | `0xcecb2641ea89470f68bf9f852d731e123505424e4dcfd770c7ea9e2e25326b1b` |
| `RequestCancelled(uint40)`                                            | `0xff191657769be72fc08def44c645014c60d18cb24b9ca05c9a33406a28253245` |
| `BidTimeoutUpdated(uint256)`                                          | `0xd4552e666d0e4e343fb2b13682972a8f0c7f1a86e252d6433b356f0c0e817c3d` |
| `PayloadSubmitted(uint40,address,PayloadSubmitParams[],Fees,address)` | `0x0d73f57fea2b58d4d2df3d65c988018a30f52ae1537eee65ac24558bdc533c73` |
| `FeesIncreased(address,uint40,uint256)`                               | `0x63ee9e9e84d216b804cb18f51b7f7511254b0c1f11304b7a3aa34d57511aa6dc` |
| `PayloadAsyncRequested(//,//,//,//)`                                  | `0x1c268ecaf7a0d595f8c277430613b278197257c9315654ce1717f7aebdc9674c` |

## protocol/socket/SocketConfig.sol

| Event                          | Topic                                                                |
| ------------------------------ | -------------------------------------------------------------------- |
| `SwitchboardAdded(address)`    | `0x1595852923edfbbf906f09fc8523e4cfb022a194773c4d1509446b614146ee88` |
| `SwitchboardDisabled(address)` | `0x1b4ee41596b4e754e5665f01ed6122b356f7b36ea0a02030804fac7fa0fdddfc` |

## protocol/socket/switchboard/FastSwitchboard.sol

| Event                       | Topic                                                                |
| --------------------------- | -------------------------------------------------------------------- |
| `Attested(bytes32,address)` | `0x3d83c7bc55c269e0bc853ddc0d7b9fca30216ecc43779acb4e36b7e0ad1c71e4` |

## protocol/utils/AccessControl.sol

| Event                          | Topic                                                                |
| ------------------------------ | -------------------------------------------------------------------- |
| `RoleGranted(bytes32,address)` | `0x2ae6a113c0ed5b78a53413ffbb7679881f11145ccfba4fb92e863dfcd5a1d2f3` |
| `RoleRevoked(bytes32,address)` | `0x155aaafb6329a2098580462df33ec4b7441b19729b9601c5fc17ae1cf99a8a52` |

## protocol/watcherPrecompile/WatcherPrecompileConfig.sol

| Event                                                | Topic                                                                |
| ---------------------------------------------------- | -------------------------------------------------------------------- |
| `PlugAdded(address,uint32,address)`                  | `0x2cb8d865028f9abf3dc064724043264907615fadc8615a3699a85edb66472273` |
| `SwitchboardSet(uint32,bytes32,address)`             | `0x6273f161f4a795e66ef3585d9b4442ef3796b32337157fdfb420b5281e4cf2e3` |
| `OnChainContractSet(uint32,address,address,address)` | `0xd24cf816377e3c571e7bc798dd43d3d5fc78c32f7fc94b42898b0d37c5301a4e` |
