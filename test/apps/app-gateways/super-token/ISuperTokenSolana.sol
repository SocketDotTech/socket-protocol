// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {SolanaInstruction} from "../../../../contracts/utils/common/Structs.sol";

interface ISuperTokenSolana {
    function callSolana(SolanaInstruction memory instruction) external;
}
