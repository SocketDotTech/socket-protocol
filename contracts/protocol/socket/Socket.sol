// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SocketUtils.sol";
import {LibCall} from "solady/utils/LibCall.sol";
import {IPlug} from "../../interfaces/IPlug.sol";
import {PlugDisconnected, InvalidAppGateway} from "../utils/common/Errors.sol";
import {MAX_COPY_BYTES} from "../utils/common/Constants.sol";

/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketUtils and
 * provides functionality for payload execution, verification.
 * It manages the mapping of payload execution status
 * timestamps
 * It also includes functions for payload execution and verification
 */
contract Socket is SocketUtils {
    using LibCall for address;

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
    error InsufficientMsgValue();
    constructor(
        uint32 chainSlug_,
        address owner_,
        string memory version_
    ) SocketUtils(chainSlug_, owner_, version_) {}

    /**
     * @notice Executes a payload that has been delivered by transmitters and authenticated by switchboards
     */
    function execute(
        ExecuteParams memory executeParams_,
        TransmissionParams memory transmissionParams_
    ) external payable returns (bytes memory) {
        if (executeParams_.deadline < block.timestamp) revert DeadlinePassed();
        PlugConfig memory plugConfig = _plugConfigs[executeParams_.target];
        if (plugConfig.appGatewayId == bytes32(0)) revert PlugDisconnected();

        if (msg.value < executeParams_.value + transmissionParams_.socketFees)
            revert InsufficientMsgValue();
        bytes32 payloadId = _createPayloadId(plugConfig.switchboard, executeParams_);
        _validateExecutionStatus(payloadId);

        address transmitter = transmissionParams_.transmitterSignature.length > 0
            ? _recoverSigner(
                keccak256(abi.encode(address(this), payloadId)),
                transmissionParams_.transmitterSignature
            )
            : address(0);

        bytes32 digest = _createDigest(
            transmitter,
            payloadId,
            plugConfig.appGatewayId,
            executeParams_
        );
        _verify(digest, payloadId, plugConfig.switchboard);
        return _execute(payloadId, executeParams_, transmissionParams_);
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////
    function _verify(bytes32 digest_, bytes32 payloadId_, address switchboard_) internal view {
        if (isValidSwitchboard[switchboard_] != SwitchboardStatus.REGISTERED)
            revert InvalidSwitchboard();
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
        ExecuteParams memory executeParams_,
        TransmissionParams memory transmissionParams_
    ) internal returns (bytes memory) {
        if (gasleft() < executeParams_.gasLimit) revert LowGasLimit();

        // NOTE: external un-trusted call
        (bool success, , bytes memory returnData) = executeParams_.target.tryCall(
            executeParams_.value,
            executeParams_.gasLimit,
            maxCopyBytes,
            executeParams_.payload
        );

        if (success) {
            emit ExecutionSuccess(payloadId_, returnData);
            if (address(socketFeeManager) != address(0)) {
                socketFeeManager.payAndCheckFees{value: transmissionParams_.socketFees}(
                    executeParams_,
                    transmissionParams_
                );
            }
        } else {
            payloadExecuted[payloadId_] = ExecutionStatus.Reverted;
            emit ExecutionFailed(payloadId_, returnData);
        }

        return returnData;
    }

    function _validateExecutionStatus(bytes32 payloadId_) internal {
        if (payloadExecuted[payloadId_] == ExecutionStatus.Executed)
            revert PayloadAlreadyExecuted(payloadExecuted[payloadId_]);
        payloadExecuted[payloadId_] = ExecutionStatus.Executed;
    }

    ////////////////////////////////////////////////////////
    ////////////////////// OPERATIONS //////////////////////////
    ////////////////////////////////////////////////////////
    /**
     * @notice To send message to a connected remote chain. Should only be called by a plug.
     * @param payload_ bytes to be delivered on EVMx
     * @param overrides_ a bytes param to add details for execution, for eg: fees to be paid for execution
     */
    function _callAppGateway(
        address plug_,
        bytes memory overrides_,
        bytes memory payload_
    ) internal returns (bytes32 triggerId) {
        PlugConfig memory plugConfig = _plugConfigs[plug_];

        // if no sibling plug is found for the given chain slug, revert
        if (plugConfig.appGatewayId == bytes32(0)) revert PlugDisconnected();

        // creates a unique ID for the message
        triggerId = _encodeTriggerId();
        emit AppGatewayCallRequested(triggerId, chainSlug, plug_, overrides_, payload_);
    }

    /// @notice Fallback function that forwards all calls to Socket's callAppGateway
    /// @dev The calldata is passed as-is to the gateways
    fallback(bytes calldata) external returns (bytes memory) {
        bytes memory overrides = IPlug(msg.sender).overrides();
        return abi.encode(_callAppGateway(msg.sender, overrides, msg.data));
    }
}
