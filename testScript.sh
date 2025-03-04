

## Parallel Counter 
source .env && forge script script/parallel-counter/deployOnEVMx.s.sol --broadcast --skip-simulation
## set limits for the app gateway using API
source .env && cast send $APP_GATEWAY "deployMultiChainContracts(uint32[])" '[421614, 11155420]' --private-key $PRIVATE_KEY
source .env && forge script script/parallel-counter/checkCounters.s.sol --broadcast --skip-simulation


## Counter 
source .env && forge script script/counter/deployEVMxCounterApp.s.sol --broadcast --skip-simulation --legacy --gas-price 0
source .env && forge script script/counter/DeployCounterOnchain.s.sol --broadcast --skip-simulation
## set limits for the app gateway using API
source .env && cast send $APP_GATEWAY "deployContracts(uint32)" 421614 --private-key $PRIVATE_KEY --legacy --gas-price 0
cast call $APP_GATEWAY "getOnChainAddress(bytes32,uint32)(address)" 0x5ab1536adcb0c297300e651c684f844c311727059d17eb2be15c313b5839b9eb 421614
cast call $APP_GATEWAY "forwarderAddresses(bytes32,uint32)(address)" 0x5ab1536adcb0c297300e651c684f844c311727059d17eb2be15c313b5839b9eb 421614
source .env && cast send $APP_GATEWAY "incrementCounters(address[])" '[0xB491b4b9343471d79d33A7c45Dc4d0a7EA818F93]' --private-key $PRIVATE_KEY --legacy --gas-price 0
source .env && cast send $APP_GATEWAY "readCounters(address[])" '[0x18a93d520879524e0c215b64f05914da5883540f]' --private-key $PRIVATE_KEY --legacy --gas-price 0
source .env && cast send $APP_GATEWAY "withdrawFeeTokens(uint32,address,uint256,address)" 421614 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE 987793576908782 0x3339Cf48f1F9cf31b6F8c2664d144c7444eBBB18 --private-key $PRIVATE_KEY --legacy --gas-price 0

forge script script/counter/incrementCounters.s.sol --broadcast --skip-simulation
forge script script/counter/checkCounters.s.sol --broadcast --skip-simulation

## Cron
source .env && forge script script/cron/DeployGateway.s.sol:DeployGateway --broadcast --skip-simulation
source .env && forge script script/cron/SetTimeout.s.sol:SetTimeoutScript --broadcast --skip-simulation
source .env && cast send $APP_GATEWAY "setTimeout(uint256)" 0 --private-key $PRIVATE_KEY

## Super Token Lockable
forge script script/super-token-lockable/DeployGateway.s.sol --broadcast --skip-simulation
source .env && cast send $APP_GATEWAY "deployContracts(uint32)" 421614 --private-key $PRIVATE_KEY
source .env && cast send $APP_GATEWAY "deployContracts(uint32)" 11155420 --private-key $PRIVATE_KEY
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

source .env && forge script script/super-token/Bridge.s.sol --broadcast --skip-simulation --private-key $PRIVATE_KEY --legacy --with-gas-price 0

# add fees
source .env && forge script script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation 
source .env && forge script script/helpers/AppGatewayFeeBalance.s.sol 



source .env && forge script script/super-token/DeployGateway.s.sol --broadcast --skip-simulation --private-key $PRIVATE_KEY --legacy --with-gas-price 0
source .env && forge script script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation --private-key $PRIVATE_KEY

source .env && cast send $APP_GATEWAY "deployContracts(uint32)" 420120000 --private-key $PRIVATE_KEY --legacy --gas-price 0
source .env && cast send $APP_GATEWAY "deployContracts(uint32)" 420120001 --private-key $PRIVATE_KEY --legacy --gas-price 0

source .env && forge script script/super-token/GetToken.s.sol --broadcast --skip-simulation
source .env && forge script script/super-token/SetToken.s.sol --broadcast --skip-simulation --private-key $PRIVATE_KEY




# // commands
source .env && cast call $APP_GATEWAY "status()" --rpc-url $EVMX_RPC | cast to-ascii   

source .env && cast send $APP_GATEWAY "transfer(bytes)" 0x0000000000000000000000009c79440ad7e70b895d88433d7b268ba4482e406f000000000000000000000000d6ce61b9be8c8ad07b043e61079d66fb10f2e405000000000000000000000000b62505feacc486e809392c65614ce4d7b051923b00000000000000000000000000000000000000000000000000000000000186a00000000000000000000000000000000000000000000000000000000067c88d59 --private-key $PRIVATE_KEY --legacy --gas-price 0
