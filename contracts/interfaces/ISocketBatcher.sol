// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "../common/Structs.sol";

interface ISocketBatcher {
    function attestAndExecute(
        ExecutePayloadParams calldata params_
    ) external returns (bytes memory);
}
