// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

address constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

bytes32 constant FORWARD_CALL = keccak256("FORWARD_CALL");
bytes32 constant DISTRIBUTE_FEE = keccak256("DISTRIBUTE_FEE");
bytes32 constant DEPLOY = keccak256("DEPLOY");
bytes32 constant QUERY = keccak256("QUERY");
bytes32 constant FINALIZE = keccak256("FINALIZE");
bytes32 constant SCHEDULE = keccak256("SCHEDULE");
bytes32 constant FAST = keccak256("FAST");
uint256 constant REQUEST_PAYLOAD_COUNT_LIMIT = 10;
uint256 constant PAYLOAD_SIZE_LIMIT = 24_500;
uint16 constant MAX_COPY_BYTES = 2048; // 2KB
