// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IPlug.sol";
import "./SocketBase.sol";
import {PlugDisconnected, InvalidAppGateway} from "../common/Errors.sol";
/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketBase and
 * provides functionality for payload execution, verification.
 * It manages the mapping of payload execution status
 * timestamps
 * It also includes functions for payload execution and verification
 */
contract Socket is SocketBase {
    ////////////////////////////////////////////////////////
    ////////////////////// ERRORS //////////////////////////
    ////////////////////////////////////////////////////////
    /**
     * @dev Error emitted when proof is invalid
     */

    /**
     * @dev Error emitted when a payload has already been executed
     */
    error PayloadAlreadyExecuted();
    /**
     * @dev Error emitted when the executor is not valid
     */
    /**
     * @dev Error emitted when verification fails
     */
    error VerificationFailed();
    /**
     * @dev Error emitted when source slugs deduced from packet id and msg id don't match
     */
    /**
     * @dev Error emitted when less gas limit is provided for execution than expected
     */
    error LowGasLimit();
    error InvalidSlug();
    error ExecutionFailed();

    ////////////////////////////////////////////////////////////
    ////////////////////// State Vars //////////////////////////
    ////////////////////////////////////////////////////////////
    uint64 public callCounter;

    /**
     * @dev keeps track of whether a payload has been executed or not using payload id
     */
    mapping(bytes32 => bool) public payloadExecuted;

    constructor(
        uint32 chainSlug_,
        address hasher_,
        address signatureVerifier_,
        address owner_,
        string memory version_
    ) SocketBase(chainSlug_, hasher_, signatureVerifier_, owner_, version_) {}

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
        PlugConfig memory plugConfig = _plugConfigs[msg.sender];

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
        bytes32 payloadId_,
        address appGateway_,
        address target_,
        uint256 executionGasLimit_,
        bytes memory transmitterSignature_,
        bytes memory payload_
    ) external payable returns (bytes memory) {
        // make sure payload is not executed already
        if (payloadExecuted[payloadId_]) revert PayloadAlreadyExecuted();
        // update state to make sure no reentrancy
        payloadExecuted[payloadId_] = true;

        // extract plug address from msgID
        address switchboard = _decodeSwitchboard(payloadId_);
        uint32 localSlug = _decodeChainSlug(payloadId_);

        PlugConfig memory plugConfig = _plugConfigs[target_];

        if (switchboard != address(plugConfig.switchboard__)) revert InvalidSwitchboard();

        if (localSlug != chainSlug) revert InvalidSlug();

        address transmitter = signatureVerifier__.recoverSigner(
            keccak256(abi.encode(address(this), payloadId_)),
            transmitterSignature_
        );

        // create packed payload
        bytes32 root = hasher__.packPayload(
            payloadId_,
            appGateway_,
            transmitter,
            target_,
            executionGasLimit_,
            payload_
        );

        // verify payload was part of the packet and
        // authenticated by respective switchboard
        _verify(root, payloadId_, ISwitchboard(switchboard));

        // execute payload
        return _execute(target_, payloadId_, executionGasLimit_, payload_);
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////

    function _verify(bytes32 root_, bytes32 payloadId_, ISwitchboard switchboard__) internal view {
        // NOTE: is the the first un-trusted call in the system, another one is Plug.call
        if (!switchboard__.allowPacket(root_, payloadId_)) revert VerificationFailed();
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the payload
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     */
    function _execute(
        address localPlug_,
        bytes32 payloadId_,
        uint256 executionGasLimit_,
        bytes memory payload_
    ) internal returns (bytes memory) {
        if (gasleft() < executionGasLimit_) revert LowGasLimit();
        // NOTE: external un-trusted call
        (bool success, bytes memory returnData) = localPlug_.call{
            gas: executionGasLimit_,
            value: msg.value
        }(payload_);

        if (!success) revert ExecutionFailed();
        emit ExecutionSuccess(payloadId_, returnData);
        return returnData;
    }

    /**
     * @dev Decodes the switchboard address from a given payload id.
     * @param id_ The ID of the msg to decode the switchboard from.
     * @return switchboard_ The address of switchboard decoded from the payload ID.
     */
    function _decodeSwitchboard(bytes32 id_) internal pure returns (address switchboard_) {
        switchboard_ = address(uint160(uint256(id_) >> 64));
    }

    /**
     * @dev Decodes the chain ID from a given packet/payload ID.
     * @param id_ The ID of the packet/msg to decode the chain slug from.
     * @return chainSlug_ The chain slug decoded from the packet/payload ID.
     */
    function _decodeChainSlug(bytes32 id_) internal pure returns (uint32 chainSlug_) {
        chainSlug_ = uint32(uint256(id_) >> 224);
    }

    // Packs the local plug, local chain slug, remote chain slug and nonce
    // callCount++ will take care of call id overflow as well
    // callId(256) = localChainSlug(32) | appGateway_(160) | nonce(64)
    function _encodeCallId(address appGateway_) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) | (uint256(uint160(appGateway_)) << 64) | callCounter++
            );
    }
}
