// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ExecuteParams} from "../../utils/common/Structs.sol";

/**
 * @title ISocketBatcher
 * @notice Interface for a helper contract for socket which batches attest (on sb) and execute calls (on socket).
 */
interface ISocketBatcher {
    /**
     * @notice Attests a payload and executes it
     * @param executeParams_ The execution parameters
     * @param digest_ The digest of the payload
     * @param proof_ The proof of the payload
     * @param transmitterSignature_ The signature of the transmitter
     * @return The return data after execution
     */
    function attestAndExecute(
        ExecuteParams calldata executeParams_,
        address switchboard_,
        bytes32 digest_,
        bytes calldata proof_,
        bytes calldata transmitterSignature_,
        address refundAddress_
    ) external payable returns (bool, bytes memory);
}
