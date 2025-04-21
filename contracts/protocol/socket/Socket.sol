// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {LibCall} from "solady/utils/LibCall.sol";
import "./SocketUtils.sol";

/**
 * @title Socket
 * @dev Socket is an abstract contract that inherits from SocketUtils and SocketConfig and
 * provides functionality for payload execution, verification, and management of payload execution status
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
    /**
     * @dev Error emitted when the chain slug is invalid
     */
    error InvalidSlug();
    /**
     * @dev Error emitted when the deadline has passed
     */
    error DeadlinePassed();
    /**
     * @dev Error emitted when the message value is insufficient
     */
    error InsufficientMsgValue();

    /**
     * @notice Constructor for the Socket contract
     * @param chainSlug_ The chain slug
     * @param owner_ The owner of the contract
     * @param version_ The version of the contract
     */
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
        bytes memory transmitterSignature_
    ) external payable returns (bytes memory) {
        // check if the deadline has passed
        if (executeParams_.deadline < block.timestamp) revert DeadlinePassed();

        PlugConfig memory plugConfig = _plugConfigs[executeParams_.target];
        // check if the plug is disconnected
        if (plugConfig.appGatewayId == bytes32(0)) revert PlugDisconnected();

        // check if the message value is insufficient
        if (msg.value < executeParams_.value) revert InsufficientMsgValue();

        // create the payload id
        bytes32 payloadId = _createPayloadId(plugConfig.switchboard, executeParams_);

        // validate the execution status
        _validateExecutionStatus(payloadId);

        address transmitter = transmitterSignature_.length > 0
            ? _recoverSigner(keccak256(abi.encode(address(this), payloadId)), transmitterSignature_)
            : address(0);

        // create the digest
        // transmitter, payloadId, appGateway, executeParams_ and there contents are validated using digest verification from switchboard
        bytes32 digest = _createDigest(
            transmitter,
            payloadId,
            plugConfig.appGatewayId,
            executeParams_
        );

        // verify the digest
        _verify(digest, payloadId, plugConfig.switchboard);

        // execute the payload and return the data
        return _execute(payloadId, executeParams_);
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////
    function _verify(bytes32 digest_, bytes32 payloadId_, address switchboard_) internal view {
        if (isValidSwitchboard[switchboard_] != SwitchboardStatus.REGISTERED)
            revert InvalidSwitchboard();

        // NOTE: is the the first un-trusted call in the system, another one is Plug.call
        if (!ISwitchboard(switchboard_).allowPayload(digest_, payloadId_))
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
        // check if the gas limit is sufficient
        if (gasleft() < executeParams_.gasLimit) revert LowGasLimit();

        // NOTE: external un-trusted call
        (bool success, , bytes memory returnData) = executeParams_.target.tryCall(
            msg.value,
            executeParams_.gasLimit,
            maxCopyBytes,
            executeParams_.payload
        );

        // if the execution failed, set the execution status to reverted
        if (!success) {
            payloadExecuted[payloadId_] = ExecutionStatus.Reverted;
            emit ExecutionFailed(payloadId_, returnData);
        } else {
            emit ExecutionSuccess(payloadId_, returnData);
        }

        return returnData;
    }

    function _validateExecutionStatus(bytes32 payloadId_) internal {
        if (payloadExecuted[payloadId_] == ExecutionStatus.Executed)
            revert PayloadAlreadyExecuted(payloadExecuted[payloadId_]);
        payloadExecuted[payloadId_] = ExecutionStatus.Executed;
    }

    ////////////////////////////////////////////////////////
    ////////////////////// Trigger //////////////////////
    ////////////////////////////////////////////////////////
    /**
     * @notice To trigger to a connected remote chain. Should only be called by a plug.
     * @param payload_ bytes to be delivered on EVMx
     * @param overrides_ a bytes param to add details for execution, for eg: fees to be paid for execution
     */
    function _triggerAppGateway(
        address plug_,
        bytes memory overrides_,
        bytes memory payload_
    ) internal returns (bytes32 triggerId) {
        PlugConfig memory plugConfig = _plugConfigs[plug_];

        // if no sibling plug is found for the given chain slug, revert
        // sends the trigger to connected app gateway
        if (plugConfig.appGatewayId == bytes32(0)) revert PlugDisconnected();

        // creates a unique ID for the message
        triggerId = _encodeTriggerId();
        emit AppGatewayCallRequested(triggerId, chainSlug, plug_, overrides_, payload_);
    }

    /// @notice Fallback function that forwards all calls to Socket's callAppGateway
    /// @dev The calldata is passed as-is to the gateways
    /// @dev if ETH sent with the call, it will revert
    fallback(bytes calldata) external returns (bytes memory) {
        // gets the overrides from the plug
        bytes memory overrides = IPlug(msg.sender).overrides();

        // return the trigger id
        return abi.encode(_triggerAppGateway(msg.sender, overrides, msg.data));
    }
}
