# Conversion list

## Socket Protocol 

### EVMx
* AppGatewayBase -> `_deploy()` : QueuePayloadParams : target: toBytes32Format(address(0))
* WatcherPrecompileConfig -> `verifyConnections()` : toBytes32Format(appGateway_)
* WatcherPrecompile -> `callAppGateways()` : appGateway = fromBytes32Format(params_[i].appGatewayId);
* WatcherPrecompileCore 
    -> `_getPreviousDigestsHash()` : toBytes32Format(p.appGateway)
    -> `_createEvmDigestParams()` : toBytes32Format(params_.appGateway)
    -> `_createSolanaDigestParams()` : toBytes32Format(params_.appGateway)
    
### EVM

* SocketUtils
    -> `_createDigest()` : toBytes32Format(address(this))
    -> `_createDigest()` : toBytes32Format(executeParams_.target)
* FastSwitchboard -> attest() : (proof verification) `(toBytes32Format(address(this)), chainSlug, digest_)`   

### Socket-protocol scripts:

* 3.upgradeManagers.ts 
    -> `watcherPrecompileConfig.setOnChainContracts()`:
        - toBytes32Format(socketAddress)
        - toBytes32Format(contractFactoryPlugAddress)
        - toBytes32Format(feesPlugAddress)
    -> `watcherPrecompileConfig.setSwitchboard()` : toBytes32Format(sbAddress)

* 4.connects.ts
    -> `watcher.getPlugConfigs` : toBytes32Format(plugHexStringBytes32)
    -> `updateConfigEVMx()` :
        - plugAddressHexStringBytes32 = toBytes32FormatHexString(plugAddress);
        - switchboardHexStringBytes32 = toBytes32FormatHexString(switchboard);


### Watcher-processor

* evm_helpers.ts
    -> `executeEvm()`
        - fromBytes32ToAddress(switchboard);
        - fromBytes32ToAddress(executeParams.target);

### Transmitter-processor

* plugConnected/process.ts
    -> toBytes32FormatHexString(plug)
    -> toBytes32FormatHexString(switchboard)

* finality/resolvePromise.ts
    -> toSolidityFormat(payload.returnData)
    -> toSolidityFormat(payloadId)
