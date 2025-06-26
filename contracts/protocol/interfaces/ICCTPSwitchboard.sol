// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./ISwitchboard.sol";
import {ExecuteParams, CCTPExecutionParams, CCTPBatchParams} from "../../utils/common/Structs.sol";

/**
 * @title ISwitchboard
 * @dev The interface for a switchboard contract that is responsible for verification of payloads if the correct
 * digest is executed.
 */
interface ICCTPSwitchboard is ISwitchboard {
    /**
     * @notice Syncs out a payload to the remote chains
     * @param payloadId_ The unique identifier for the payload
     * @param remoteChainSlugs_ The remote chain slugs
     */
    function syncOut(bytes32 payloadId_, uint32[] calldata remoteChainSlugs_) external;

    /**
     * @notice Handles the receive message
     * @param sourceDomain The source domain
     * @param sender The sender
     * @param messageBody The message body
     */
    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool);

    /**
     * @notice Proves the remote executions
     * @param previousPayloadIds_ The previous payload ids
     * @param currentPayloadId_ The current payload id
     * @param transmitterSignature_ The transmitter signature
     * @param executeParams_ The execute parameters
     */
    function proveRemoteExecutions(
        bytes32[] calldata previousPayloadIds_,
        bytes32 currentPayloadId_,
        bytes calldata transmitterSignature_,
        ExecuteParams calldata executeParams_
    ) external;

    /**
     * @notice Verifies the attestations
     * @param messages_ The messages
     * @param attestations_ The attestations
     */
    function verifyAttestations(
        bytes[] calldata messages_,
        bytes[] calldata attestations_
    ) external;

    function attestVerifyAndProveExecutions(
        CCTPExecutionParams calldata execParams_,
        CCTPBatchParams calldata cctpParams_,
        bytes32 payloadId_
    ) external;
}
