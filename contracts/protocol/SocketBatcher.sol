// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "./interfaces/ISocket.sol";
import "./interfaces/ISocketBatcher.sol";
import "./interfaces/ISwitchboard.sol";
import "./interfaces/ICCTPSwitchboard.sol";
import "../utils/RescueFundsLib.sol";
import {ExecuteParams, TransmissionParams, CCTPBatchParams, CCTPExecutionParams} from "../utils/common/Structs.sol";
import {createPayloadId} from "../utils/common/IdUtils.sol";

/**
 * @title SocketBatcher
 * @notice The SocketBatcher contract is responsible for batching payloads and transmitting them to the destination chain
 */
contract SocketBatcher is ISocketBatcher, Ownable {
    // socket contract
    ISocket public immutable socket__;

    /**
     * @notice Initializes the SocketBatcher contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     * @param socket_ The address of socket contract
     */
    constructor(address owner_, ISocket socket_) {
        socket__ = socket_;
        _initializeOwner(owner_);
    }

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
    ) external payable returns (bool, bytes memory) {
        ISwitchboard(switchboard_).attest(digest_, proof_);
        return
            socket__.execute{value: msg.value}(
                executeParams_,
                TransmissionParams({
                    transmitterSignature: transmitterSignature_,
                    socketFees: 0,
                    extraData: executeParams_.extraData,
                    refundAddress: refundAddress_
                })
            );
    }

    function attestCCTPAndProveAndExecute(
        CCTPExecutionParams calldata execParams_,
        CCTPBatchParams calldata cctpParams_,
        address switchboard_
    ) external payable returns (bool, bytes memory) {
        bytes32 payloadId = _createPayloadId(execParams_.executeParams, switchboard_);
        ICCTPSwitchboard(switchboard_).attest(payloadId, execParams_.digest, execParams_.proof);

        ICCTPSwitchboard(switchboard_).verifyAttestations(
            cctpParams_.messages,
            cctpParams_.attestations
        );
        ICCTPSwitchboard(switchboard_).proveRemoteExecutions(
            cctpParams_.previousPayloadIds,
            payloadId,
            execParams_.transmitterSignature,
            execParams_.executeParams
        );
        (bool success, bytes memory returnData) = socket__.execute{value: msg.value}(
            execParams_.executeParams,
            TransmissionParams({
                transmitterSignature: execParams_.transmitterSignature,
                socketFees: 0,
                extraData: execParams_.executeParams.extraData,
                refundAddress: execParams_.refundAddress
            })
        );

        ICCTPSwitchboard(switchboard_).syncOut(payloadId, cctpParams_.nextBatchRemoteChainSlugs);
        return (success, returnData);
    }

    function _createPayloadId(
        ExecuteParams memory executeParams_,
        address switchboard_
    ) internal view returns (bytes32) {
        return
            createPayloadId(
                executeParams_.requestCount,
                executeParams_.batchCount,
                executeParams_.payloadCount,
                switchboard_,
                socket__.chainSlug()
            );
    }

    /**
     * @notice Rescues funds from the contract
     * @param token_ The address of the token to rescue
     * @param to_ The address to rescue the funds to
     * @param amount_ The amount of funds to rescue
     */
    function rescueFunds(address token_, address to_, uint256 amount_) external onlyOwner {
        RescueFundsLib._rescueFunds(token_, to_, amount_);
    }
}
