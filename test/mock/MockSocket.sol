// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {PlugDisconnected, InvalidAppGateway} from "../../contracts/protocol/utils/common/Errors.sol";
import "../../contracts/interfaces/ISwitchboard.sol";
import "../../contracts/interfaces/ISocket.sol";

/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketUtils and
 * provides functionality for payload execution, verification.
 * It manages the mapping of payload execution status
 * timestamps
 * It also includes functions for payload execution and verification
 */
contract MockSocket is ISocket {
    struct PlugConfig {
        // address of the sibling plug on the remote chain
        address appGateway;
        // switchboard instance for the plug connection
        ISwitchboard switchboard__;
    }

    // plug => (appGateway, switchboard__)
    mapping(address => PlugConfig) internal _plugConfigs;

    function getPlugConfig(
        address plugAddress_
    ) external view returns (address appGateway, address switchboard__) {
        PlugConfig memory _plugConfig = _plugConfigs[plugAddress_];
        return (_plugConfig.appGateway, address(_plugConfig.switchboard__));
    }

    function connect(address appGateway_, address switchboard_) external override {}

    function registerSwitchboard() external override {}

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

    ////////////////////////////////////////////////////////////
    ////////////////////// State Vars //////////////////////////
    ////////////////////////////////////////////////////////////
    uint64 public triggerCounter;
    uint32 public chainSlug;

    enum ExecutionStatus {
        NotExecuted,
        Executed,
        Reverted
    }

    /**
     * @dev keeps track of whether a payload has been executed or not using payload id
     */
    mapping(bytes32 => ExecutionStatus) public payloadExecuted;

    constructor(uint32 chainSlug_, address, address, address, string memory) {
        chainSlug = chainSlug_;
    }

    ////////////////////////////////////////////////////////
    ////////////////////// OPERATIONS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @notice To send message to a connected remote chain. Should only be called by a plug.
     */
    function callAppGateway(
        bytes calldata payload,
        bytes calldata overrides
    ) external returns (bytes32 triggerId) {
        PlugConfig memory plugConfig = _plugConfigs[msg.sender];
        // creates a unique ID for the message
        triggerId = _encodeTriggerId(plugConfig.appGateway);
        emit AppGatewayCallRequested(triggerId, chainSlug, msg.sender, overrides, payload);
    }

    /**
     * @notice Executes a payload that has been delivered by transmitters and authenticated by switchboards
     */
    function execute(
        ExecuteParams memory executeParams_,
        bytes memory transmitterSignature_
    ) external payable override returns (bytes memory) {
        // execute payload
        // return
        //     _execute(
        //         executeParams_.target,
        //         executeParams_.payloadId,
        //         executeParams_.gasLimit,
        //         executeParams_.payload
        //     );
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////

    function _verify(
        bytes32 digest_,
        bytes32 payloadId_,
        ISwitchboard switchboard__
    ) internal view {
        // NOTE: is the the first un-trusted call in the system, another one is Plug.call
        if (!switchboard__.allowPacket(digest_, payloadId_)) revert VerificationFailed();
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the payload
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     */
    function _execute(
        address,
        bytes32 payloadId_,
        uint256,
        bytes memory
    ) internal returns (bytes memory) {
        bytes memory returnData = hex"00010203";
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
    // triggerCounter++ will take care of call id overflow as well
    // triggerId(256) = localChainSlug(32) | appGateway_(160) | nonce(64)
    function _encodeTriggerId(address appGateway_) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(appGateway_)) << 64) |
                    triggerCounter++
            );
    }
}
