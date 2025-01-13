

## Counter 
forge script script/counter/DeployCounterOffchain.s.sol --broadcast --skip-simulation
cast send $COUNTER_DEPLOYER "deployContracts(uint32)" 421614 --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY


## Cron
forge script script/cron/DeployGateway.s.sol:DeployGateway --broadcast --skip-simulation --rpc-url $ETH_RPC_URL
forge script script/cron/SetTimeout.s.sol:SetTimeoutScript --broadcast --skip-simulation --rpc-url $ETH_RPC_URL


forge script script/mock/DeployVM.s.sol --broadcast --skip-simulation 
forge script script/mock/DeploySocket.s.sol --broadcast --skip-simulation 
forge script script/mock/Timeout.s.sol --broadcast --skip-simulation 
forge script script/mock/Query.s.sol --broadcast --skip-simulation 
forge script script/mock/Inbox.s.sol --broadcast --skip-simulation 
forge script script/mock/FinalizeAndExecution.s.sol --broadcast --skip-simulation 
