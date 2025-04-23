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

    // @notice mapping of payload id to execution status
    mapping(bytes32 => ExecutionStatus) public payloadExecuted;

    // @notice mapping of payload id to execution status
    mapping(bytes32 => bytes32) public payloadIdToDigest;

    // @notice buffer to account for gas used by current contract execution
    uint256 public constant GAS_LIMIT_BUFFER = 105;

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
    ) external payable returns (bool, bool, bytes memory) {
        // check if the deadline has passed
        if (executeParams_.deadline < block.timestamp) revert DeadlinePassed();

        PlugConfig memory plugConfig = _plugConfigs[executeParams_.target];
        // check if the plug is disconnected
        if (plugConfig.appGatewayId == bytes32(0)) revert PlugNotFound();

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
        payloadIdToDigest[payloadId] = digest;

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
    ) internal returns (bool, bool, bytes memory) {
        // check if the gas limit is sufficient
        // bump by 5% to account for gas used by current contract execution
        if (gasleft() < (executeParams_.gasLimit * GAS_LIMIT_BUFFER) / 100) revert LowGasLimit();

        // NOTE: external un-trusted call
        (bool success, bool exceededMaxCopy, bytes memory returnData) = executeParams_
            .target
            .tryCall(msg.value, executeParams_.gasLimit, maxCopyBytes, executeParams_.payload);

        // if the execution failed, set the execution status to reverted
        if (!success) {
            payloadExecuted[payloadId_] = ExecutionStatus.Reverted;
            emit ExecutionFailed(payloadId_, exceededMaxCopy, returnData);
        } else {
            emit ExecutionSuccess(payloadId_, exceededMaxCopy, returnData);
        }

        return (success, exceededMaxCopy, returnData);
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
     */
    function _triggerAppGateway(address plug_) internal returns (bytes32 triggerId) {
        PlugConfig storage plugConfig = _plugConfigs[plug_];

        // if no sibling plug is found for the given chain slug, revert
        // sends the trigger to connected app gateway
        if (plugConfig.appGatewayId == bytes32(0)) revert PlugNotFound();

        // creates a unique ID for the message
        triggerId = _encodeTriggerId();
        emit AppGatewayCallRequested(
            triggerId,
            plugConfig.switchboard,
            plug_,
            // gets the overrides from the plug
            IPlug(plug_).overrides(),
            msg.data
        );
    }

    /// @notice Fallback function that forwards all calls to Socket's callAppGateway
    /// @dev The calldata is passed as-is to the gateways
    /// @dev if ETH sent with the call, it will revert
    fallback(bytes calldata) external returns (bytes memory) {
        // return the trigger id
        return abi.encode(_triggerAppGateway(msg.sender));
    }
}
