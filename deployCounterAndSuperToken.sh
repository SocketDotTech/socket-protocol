# counter
source .env && forge script scripts/counter/DeployGateway.s.sol:DeployGateway --rpc-url $OFF_CHAIN_VM_RPC --private-key $PRIVATE_KEY --skip-simulation --broadcast
source .env && forge script scripts/counter/DeployContracts.s.sol:DeployContracts --rpc-url $OFF_CHAIN_VM_RPC --private-key $PRIVATE_KEY --skip-simulation --broadcast
source .env && forge script scripts/counter/Increment.s.sol:Increment --rpc-url $OFF_CHAIN_VM_RPC --private-key $PRIVATE_KEY --skip-simulation --broadcast

# super token
source .env && forge script scripts/super-token/DeployGateway.s.sol:DeployGateway --rpc-url $OFF_CHAIN_VM_RPC --private-key $PRIVATE_KEY --skip-simulation --broadcast
source .env && forge script scripts/super-token/DeployContracts.s.sol:DeployContracts --rpc-url $OFF_CHAIN_VM_RPC --private-key $PRIVATE_KEY --skip-simulation --broadcast
source .env && forge script scripts/super-token/Bridge.s.sol:Bridge --rpc-url $OFF_CHAIN_VM_RPC --private-key $PRIVATE_KEY --skip-simulation --broadcast

# deposit fees
source .env && forge script scripts/depositFees.s.sol:DepositFees --rpc-url $ARBITRUM_SEPOLIA_RPC --private-key $SPONSOR_KEY  --broadcast
