// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ExecuteParams} from "../protocol/utils/common/Structs.sol";

interface ISocketBatcher {
        function attestAndExecute(
        ExecuteParams calldata executeParams_,
        bytes32 digest_,
        bytes calldata proof_,
        bytes calldata transmitterSignature_
    ) external payable returns (bytes memory);
}
