// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SocketUtils.sol";
import {PlugDisconnected, InvalidAppGateway} from "../utils/common/Errors.sol";

/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketUtils and
 * provides functionality for payload execution, verification.
 * It manages the mapping of payload execution status
 * timestamps
 * It also includes functions for payload execution and verification
 */
contract Socket is SocketUtils {
    ////////////////////////////////////////////////////////
    ////////////////////// ERRORS //////////////////////////
    ////////////////////////////////////////////////////////
    /**
     * @dev Error emitted when a payload has already been executed
     */
    error PayloadAlreadyExecuted(ExecutionStatus status);
    /**
     * @dev Error emitted when verification fails
     */
    error VerificationFailed();

    /**
     * @dev Error emitted when less gas limit is provided for execution than expected
     */
    error LowGasLimit();
    error InvalidSlug();
    error DeadlinePassed();

    constructor(
        uint32 chainSlug_,
        address owner_,
        string memory version_
    ) SocketUtils(chainSlug_, owner_, version_) {}

    ////////////////////////////////////////////////////////
    ////////////////////// OPERATIONS //////////////////////////
    ////////////////////////////////////////////////////////
    /**
     * @notice To send message to a connected remote chain. Should only be called by a plug.
     * @param payload bytes to be delivered to the Plug on the siblingChainSlug_
     * @param params a 32 bytes param to add details for execution, for eg: fees to be paid for execution
     */
    function callAppGateway(
        bytes calldata payload,
        bytes32 params
    ) external returns (bytes32 callId) {
        PlugConfig memory plugConfig = plugConfigs[msg.sender];

        // if no sibling plug is found for the given chain slug, revert
        if (plugConfig.appGateway == address(0)) revert PlugDisconnected();

        // creates a unique ID for the message
        callId = _encodeCallId(plugConfig.appGateway);
        emit AppGatewayCallRequested(
            callId,
            chainSlug,
            msg.sender,
            plugConfig.appGateway,
            params,
            payload
        );
    }

    /**
     * @notice Executes a payload that has been delivered by transmitters and authenticated by switchboards
     */
    function execute(
        ExecuteParams memory executeParams_,
        bytes memory transmitterSignature_
    ) external payable returns (bytes memory) {
        if (executeParams_.deadline < block.timestamp) revert DeadlinePassed();
        PlugConfig memory plugConfig = plugConfigs[executeParams_.target];
        if (plugConfig.appGateway == address(0)) revert PlugDisconnected();

        bytes32 payloadId = _createPayloadId(plugConfig.switchboard, executeParams_);
        _validateExecutionStatus(payloadId);

        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(this), payloadId)),
            transmitterSignature_
        );

        bytes32 digest = _createDigest(
            transmitter,
            payloadId,
            plugConfig.appGateway,
            executeParams_
        );
        _verify(digest, payloadId, plugConfig.switchboard);
        return _execute(payloadId, executeParams_);
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////
    function _verify(bytes32 digest_, bytes32 payloadId_, address switchboard_) internal view {
        // NOTE: is the the first un-trusted call in the system, another one is Plug.call
        if (!ISwitchboard(switchboard_).allowPacket(digest_, payloadId_))
            revert VerificationFailed();
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the payload
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     */
    function _execute(
        bytes32 payloadId_,
        ExecuteParams memory executeParams_
    ) internal returns (bytes memory) {
        if (gasleft() < executeParams_.gasLimit) revert LowGasLimit();

        // NOTE: external un-trusted call
        (bool success, bytes memory returnData) = executeParams_.target.call{
            gas: executeParams_.gasLimit,
            value: msg.value
        }(executeParams_.payload);

        if (!success) {
            payloadExecuted[payloadId_] = ExecutionStatus.Reverted;
            emit ExecutionFailed(payloadId_, returnData);
        } else {
            emit ExecutionSuccess(payloadId_, returnData);
        }

        return returnData;
    }

    function _validateExecutionStatus(bytes32 payloadId_) internal {
        if (payloadExecuted[payloadId_] != ExecutionStatus.NotExecuted)
            revert PayloadAlreadyExecuted(payloadExecuted[payloadId_]);
        payloadExecuted[payloadId_] = ExecutionStatus.Executed;
    }
}
