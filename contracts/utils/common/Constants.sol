// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

address constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

bytes32 constant FORWARD_CALL = keccak256("FORWARD_CALL");
bytes32 constant DISTRIBUTE_FEE = keccak256("DISTRIBUTE_FEE");
bytes32 constant DEPLOY = keccak256("DEPLOY");

bytes4 constant READ = bytes4(keccak256("READ"));
bytes4 constant WRITE = bytes4(keccak256("WRITE"));
bytes4 constant SCHEDULE = bytes4(keccak256("SCHEDULE"));

bytes32 constant CALLBACK = keccak256("CALLBACK");
bytes32 constant FAST = keccak256("FAST");
bytes32 constant CCTP = keccak256("CCTP");

uint256 constant PAYLOAD_SIZE_LIMIT = 24_500;
uint16 constant MAX_COPY_BYTES = 2048; // 2KB

uint32 constant CHAIN_SLUG_SOLANA_MAINNET = 10000001;
uint32 constant CHAIN_SLUG_SOLANA_DEVNET = 10000002;

// Constant appGatewayId used on all chains
bytes32 constant APP_GATEWAY_ID = 0xdeadbeefcafebabe1234567890abcdef1234567890abcdef1234567890abcdef;
