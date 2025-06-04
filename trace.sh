echo "chainSlug: $1"
echo "txHash: $2"
echo "rpcUrl: $3"
npx ts-node hardhat-scripts/misc-scripts/createLabels.ts $1 
cast run --la $2 --rpc-url $3

# usage :
# yarn trace <chainSlug> <txHash> <rpcUrl>
# Example : 
# yarn trace 10 0x129f0f8dc131d59b88aa05d1bb136665480eb9e98ab11796f1f60fc7d4179b8d $ARBITRUM_RPC