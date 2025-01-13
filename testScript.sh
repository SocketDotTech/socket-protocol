

## Counter 
source .env && forge script script/counter/DeployCounterOffchain.s.sol --broadcast --skip-simulation
## set limits for the app gateway using API
source .env && cast send $COUNTER_DEPLOYER "deployContracts(uint32)" 421614 --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
source .env && cast send $COUNTER_APP_GATEWAY "incrementCounters(address[])" '[0x4507f726d8ca980e3a1800a8d972792d7ff46f65]' --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY
forge script script/counter/incrementCounters.s.sol --broadcast --skip-simulation
forge script script/counter/checkCounters.s.sol --broadcast --skip-simulation


## Cron
forge script script/cron/DeployGateway.s.sol:DeployGateway --broadcast --skip-simulation --rpc-url $ETH_RPC_URL
forge script script/cron/SetTimeout.s.sol:SetTimeoutScript --broadcast --skip-simulation --rpc-url $ETH_RPC_URL


forge script script/mock/DeployVM.s.sol --broadcast --skip-simulation 
forge script script/mock/DeploySocket.s.sol --broadcast --skip-simulation 
forge script script/mock/Timeout.s.sol --broadcast --skip-simulation 
forge script script/mock/Query.s.sol --broadcast --skip-simulation 
forge script script/mock/Inbox.s.sol --broadcast --skip-simulation 
forge script script/mock/FinalizeAndExecution.s.sol --broadcast --skip-simulation 



source .env && cast send $COUNTER_APP_GATEWAY "incrementCounters(address[])" '[0x4507f726d8ca980e3a1800a8d972792d7ff46f65]' --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY