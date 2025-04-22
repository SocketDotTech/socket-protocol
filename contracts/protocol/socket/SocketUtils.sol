// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "../utils/RescueFundsLib.sol";
import "./SocketConfig.sol";

/**
 * @title SocketUtils
 * @notice Utility functions for socket
 */
abstract contract SocketUtils is SocketConfig {
    ////////////////////////////////////////////////////////////
    ////////////////////// State Vars //////////////////////////
    ////////////////////////////////////////////////////////////

    // Version string for this socket instance
    bytes32 public immutable version;
    // ChainSlug for this deployed socket instance
    uint32 public immutable chainSlug;

    // @notice counter for trigger id
    uint64 public triggerCounter;

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

    /**
     * @notice creates the digest for the payload
     * @param transmitter_ The address of the transmitter
     * @param payloadId_ The ID of the payload
     * @param appGatewayId_ The id of the app gateway
     * @param executeParams_ The parameters of the payload
     * @return The packed payload as a bytes32 hash
     */
    function _createDigest(
        address transmitter_,
        bytes32 payloadId_,
        bytes32 appGatewayId_,
        ExecuteParams memory executeParams_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    address(this),
                    transmitter_,
                    payloadId_,
                    executeParams_.deadline,
                    CallType.WRITE,
                    executeParams_.gasLimit,
                    executeParams_.value,
                    executeParams_.payload,
                    executeParams_.target,
                    appGatewayId_,
                    executeParams_.prevDigestsHash
                )
            );
    }

    /**
     * @notice creates the payload ID
     * @param switchboard_ The address of the switchboard
     * @param executeParams_ The parameters of the payload
     */
    function _createPayloadId(
        address switchboard_,
        ExecuteParams memory executeParams_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    executeParams_.requestCount,
                    executeParams_.batchCount,
                    executeParams_.payloadCount,
                    switchboard_,
                    chainSlug
                )
            );
    }

    /**
     * @notice recovers the signer from the signature
     * @param digest_ The digest of the payload
     * @param signature_ The signature of the payload
     * @return signer The address of the signer
     */
    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    /**
     * @notice Encodes the trigger ID with the chain slug, socket address and nonce
     * @return The trigger ID
     */
    function _encodeTriggerId() internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(address(this))) << 64) |
                    triggerCounter++
            );
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
