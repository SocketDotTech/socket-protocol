// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../libraries/RescueFundsLib.sol";
import "./SocketConfig.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

/**
 * @title SocketBase
 * @notice A contract that is responsible for common storage for src and dest contracts, governance
 * setters and inherits SocketConfig
 */
abstract contract SocketBase is SocketConfig {
    // Version string for this socket instance
    bytes32 public immutable version;
    // ChainSlug for this deployed socket instance
    uint32 public immutable chainSlug;

    /*
     * @notice constructor for creating a new Socket contract instance.
     * @param chainSlug_ The unique identifier of the chain this socket is deployed on.
     * @param owner_ The address of the owner who has the initial admin role.
     * @param version_ The version string which is hashed and stored in socket.
     */
    constructor(uint32 chainSlug_, address owner_, string memory version_) {
        chainSlug = chainSlug_;
        version = keccak256(bytes(version_));
        _initializeOwner(owner_);
    }

    ////////////////////////////////////////////////////////
    ////////////////////// ERRORS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @dev Error thrown when non-transmitter tries to execute
     */
    error InvalidTransmitter();

    /**
     * @notice Packs the payload into a bytes32 hash
     * @param payloadId_ The ID of the payload
     * @param appGateway_ The address of the application gateway
     * @param transmitter_ The address of the transmitter
     * @param target_ The address of the target contract
     * @param executionGasLimit_ The gas limit for the execution
     * @param payload_ The payload to be packed
     * @return The packed payload as a bytes32 hash
     */
    function _packPayload(
        bytes32 payloadId_,
        address appGateway_,
        address transmitter_,
        address target_,
        uint256 executionGasLimit_,
        bytes memory payload_
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    payloadId_,
                    appGateway_,
                    transmitter_,
                    target_,
                    executionGasLimit_,
                    payload_
                )
            );
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    //////////////////////////////////////////////
    //////////// Rescue role actions ////////////
    /////////////////////////////////////////////

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
