
# Phase II - integrate Solana next steps after POC

SS - Socket Solana
SE - Socket EVM
TP - Transmitter Processor
SP - Socket Protocol (EVMx)
WP - Watcher Processor
I - Indexer
SI - Solana Indexer

- In Socket at a PlugConfig mapping (same as in EVM) target -> (apiGateway, switchboard) (SS)
  -> remove hardcoded apiGateway address in transmitter (TP)
- In `WatcherPrecompileConfig` -> _createSolanaDigestParams() remove hardcoded Solana Socket address 
  and make `watcherPrecompileConfig__.sockets(params_.payloadHeader.getChainSlug())` work with Solana chainSlugs (SP)
- In deploy/config TS scripts make `Solana chainSlugs` register the contract addresses in the `pocConfig.json`   (SP)
  -> remove special cases for Solana (like for `appConfigs`) in deploy/config TS scripts (if possible )
  -> add logging of the Socket signer balance for Solana (`deploy.TS`)

- change `PlugConnected` event fields (plug, switchboard => bytes32); fix this in watcher service (revert manual bytes32 conversion) and in EVM contract `SocketConfig` (WP + SE)
- search for places where in TS processors we use conversions address <-> bytes32 (all usage of `defaultAbiCoder`) (TP + WP + I + SP)
  make sure they are needed and can not be removed by fixing types on EVMx side

- watcher key used when creating the proof must be passed in queue msg or saved in DB. We must have access to it in Transmitter to pass it to (WP + TP)
  Solana Switchboard to perform proof validation (it needs: msg, signature, pub-key of signer)

- `ExecuteParams` that are now passed to Solana Socket contains unnecessary data like: gasLimit, value, extraData. Make a separate or more generic structure
  that will suit Solana needs. Also rename current ExecuteParams to ExecuteParamsEvm. (TP + SP)
- change the `DigestParams` transmitter field from address -> bytes32 (now it is EVM transmitter key but for Solana key it will be a bytes32) (SP)
  -> update Solana Socket to avoid using transmitterEvm key (SS)
  -> update EVM Socket to use bytes32 for transmitter in digest recreation. (SE)

- solve `Borsh` encoding for function args while creating Solana digest payload (in `_createSolanaDigestParams()`)
- change fixed array [u8; 8] to slice &[u8] for instruction_discriminator argument: recently anchor allows custom size discriminators (SS)

- update ForwarderSolana to accept Switchboard address as in regular Forwarder (`bytes32 switchboard = watcherPrecompileConfig().switchboards(chainSlug, sbType);`)
  This must be fixed in Forwarder as well as deployment scripts (probably : `upgradeManagers.ts`) (SP)
- fix ForwarderSolana issue with `function then(bytes4 selector_, bytes memory data_) external returns (address promise_)`
  which, if uncommented, causes the deployment to silently fail.

- move `toBytes32FormatHexString() / toBytes32Format() / toSolidityFormat()` into socket-commons npm package. Clean redundant declarations in services and deployment scripts (SP + TP + WP + I?)
- move `SolanaEvents` declaration from SI to socket-commons (SI)

- clean up Socket Solana from logs, add omitted validation checks, refactor; Also look at Switchboard for missing prod functionalities.
  and perform a direct call to Switchboard program rather than just checking the PDA existence (to make it more generic) (SS)
- Add SocketFeeManager for Solana  
- Add a transaction failure event for Solana (SS + WP + SI)
- Add support for using `writeFinalityBucket` for Solana confirmation levels (WP + TP + SI)

- Change `appGatewayId`: bytes32 -> address. AppGateway will always be in EVMx and will have 20-byte EVM address (also change name to appGatewayAddress) (SP)


- Minor refactor for finalized event handling for Solana and EVM chainSlugs (TP)
- Minor refactor `processEventSolana and processEventEvm` in index.TS (WP) 

- `checkIfPayloadExecutionIsFinal()` to set `isFinal` flag on finalizeRequest/process.TS (WP)
  Maybe not needed if in all services we operate on one confirmation level (for Solana that should be the case anyway)

- add fee estimation for Solana transaction (TP)

- add forge tests for ForwarderSolana and EvmSolana API gateway ?

- Consider whether we should listen on EVMx events in indexer after they are confirmed (now it seems that we listen for processed events)
  as a result some actions are out of order like The bidding end can happen after Execute event handling.


====

Socket Solana missing validations:
- deadline 
- callType (ask when you can can have READ or WRITE by example )
- PlugConfig mapping and check for appGateway exists and status of Switchboard
  - add mapping for Switchboard status
- check if tx did not cost too much 
   - sort of gasLimit check but for Solana - it must be an estimated(declared) amount in SOL 
     most likely given by transmitter (he is placing a bid). We will check how much SOL was taken from payer account.
- add validation if payload was already executed 
   - add mapping for payload status (why status can be reverted ?  - would it be enough to 
     have verify bool if it was executed ??? - we could just have sort of mapping like payloadIdToDigest to check if it exists)
        - payloadIdToDigest ? vs ? payloadExecuted
- what is `_triggerAppGateway()` and triggerCounter ?
- change just checking if the switchboard attestation PDA exists to call to switchboard to make validation more generic
- add rescueFunds()

Switchboard Solana missing parts:
- emit event after attestation was successful
- add rescueFunds()