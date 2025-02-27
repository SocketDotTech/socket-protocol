

## Parallel Counter 
source .env && forge script script/parallel-counter/deployOnEVMx.s.sol --broadcast --skip-simulation
## set limits for the app gateway using API
source .env && cast send $DEPLOYER "deployMultiChainContracts(uint32[])" '[421614, 11155420]' --private-key $PRIVATE_KEY
source .env && forge script script/parallel-counter/checkCounters.s.sol --broadcast --skip-simulation


## Counter 
source .env && forge script script/counter/deployEVMxCounterApp.s.sol --broadcast --skip-simulation --legacy --gas-price 0
source .env && forge script script/counter/DeployCounterOnchain.s.sol --broadcast --skip-simulation
## set limits for the app gateway using API
source .env && cast send $DEPLOYER "deployContracts(uint32)" 421614 --private-key $PRIVATE_KEY --legacy --gas-price 0
source .env && cast send $APP_GATEWAY "incrementCounters(address[])" '[0x18a93d520879524e0c215b64f05914da5883540f]' --private-key $PRIVATE_KEY --legacy --gas-price 0
source .env && cast send $APP_GATEWAY "readCounters(address[])" '[0x18a93d520879524e0c215b64f05914da5883540f]' --private-key $PRIVATE_KEY --legacy --gas-price 0

forge script script/counter/incrementCounters.s.sol --broadcast --skip-simulation
forge script script/counter/checkCounters.s.sol --broadcast --skip-simulation

## Cron
source .env && forge script script/cron/DeployGateway.s.sol:DeployGateway --broadcast --skip-simulation
source .env && forge script script/cron/SetTimeout.s.sol:SetTimeoutScript --broadcast --skip-simulation
source .env && cast send $APP_GATEWAY "setTimeout(uint256)" 0 --private-key $PRIVATE_KEY

## Super Token Lockable
forge script script/super-token-lockable/DeployGateway.s.sol --broadcast --skip-simulation
source .env && cast send $DEPLOYER "deployContracts(uint32)" 421614 --private-key $PRIVATE_KEY
source .env && cast send $DEPLOYER "deployContracts(uint32)" 11155420 --private-key $PRIVATE_KEY
forge script script/super-token-lockable/Bridge.s.sol --broadcast --skip-simulation
source .env && cast send $APP_GATEWAY  $data --private-key $PRIVATE_KEY


## Counter Inbox
source .env && forge script script/counter-inbox/DeployCounterAndGateway.s.sol --broadcast --skip-simulation
source .env && cast send $COUNTER_INBOX "connectSocket(address,address,address)" $APP_GATEWAY $SOCKET $SWITCHBOARD --rpc-url $ARBITRUM_SEPOLIA_RPC --private-key $SPONSOR_KEY 
source .env && cast send $COUNTER_INBOX "increaseOnGateway(uint256)" 100 --rpc-url $ARBITRUM_SEPOLIA_RPC --private-key $SPONSOR_KEY 
source .env && forge script script/counter-inbox/CheckGatewayCounter.s.sol --broadcast --skip-simulation



## Mock Testing 
source .env && forge script script/mock/DeployEVMx.s.sol --broadcast --skip-simulation 
source .env && forge script script/mock/DeploySocket.s.sol --broadcast --skip-simulation 
source .env && forge script script/mock/Timeout.s.sol --broadcast --skip-simulation 
source .env && forge script script/mock/Query.s.sol --broadcast --skip-simulation 
source .env && forge script script/mock/Inbox.s.sol --broadcast --skip-simulation 
source .env && forge script script/mock/FinalizeAndExecution.s.sol --broadcast --skip-simulation 


## Check Limits
source .env && forge script script/admin/checkLimits.s.sol --broadcast --skip-simulation
source .env && forge script script/admin/UpdateLimits.s.sol --broadcast --skip-simulation


# add fees
source .env && forge script script/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation 
source .env && forge script script/AppGatewayFeeBalance.s.sol 
