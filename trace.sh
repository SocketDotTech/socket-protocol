#!/bin/bash
source .env

# Usage function
show_usage() {
    echo "Usage: yarn trace <chainSlug> <txHash> <rpcUrl>"
    echo "Example: yarn trace 42161 0x129f0f8dc131d59b88aa05d1bb136665480eb9e98ab11796f1f60fc7d4179b8d \$ARBITRUM_RPC"
}

# Check if we have 3 arguments
if [ "$#" -ne 3 ]; then
    echo "Error: 3 arguments required"
    show_usage
    exit 0
fi

# Validate required arguments
if [ -z "$1" ]; then
    echo "Error: chainSlug argument is required"
    show_usage
    exit 0
fi

if [ -z "$2" ]; then
    echo "Error: txHash argument is required"
    show_usage
    exit 0
fi

# Validate chainSlug is a number
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: chainSlug must be a number"
    show_usage
    exit 0
fi

# Validate txHash format (0x followed by 64 hex chars)
if ! [[ "$2" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
    echo "Error: Invalid transaction hash format"
    show_usage
    exit 0
fi

# Validate RPC URL
RPC_URL=${3:-$ETH_RPC_URL}
if [ -z "$RPC_URL" ]; then
    echo "Error: No RPC URL provided and ETH_RPC_URL not set in .env"
    show_usage
    exit 0
fi

echo "chainSlug: $1"
echo "txHash: $2"
echo "rpcUrl: $RPC_URL"

npx ts-node hardhat-scripts/misc-scripts/createLabels.ts $1
cast run --la $2 --rpc-url $RPC_URL

# usage :
# yarn trace <chainSlug> <txHash> <rpcUrl>
# Example : 
# yarn trace 42161 0x129f0f8dc131d59b88aa05d1bb136665480eb9e98ab11796f1f60fc7d4179b8d $ARBITRUM_RPC