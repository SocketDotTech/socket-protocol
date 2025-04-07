// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../utils/RescueFundsLib.sol";
import "./SocketConfig.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

/**
 * @title SocketUtils
 * @notice A contract that is responsible for common storage for src and dest contracts, governance
 * setters and inherits SocketConfig
 */
abstract contract SocketUtils is SocketConfig {
    ////////////////////////////////////////////////////////////
    ////////////////////// State Vars //////////////////////////
    ////////////////////////////////////////////////////////////

    // Version string for this socket instance
    bytes32 public immutable version;
    // ChainSlug for this deployed socket instance
    uint32 public immutable chainSlug;

    uint64 public triggerCounter;

    /**
     * @dev keeps track of whether a payload has been executed or not using payload id
     */
    mapping(bytes32 => ExecutionStatus) public payloadExecuted;

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
     * @notice creates the digest for the payload
     * @param transmitter_ The address of the transmitter
     * @param payloadId_ The ID of the payload
     * @param appGateway_ The address of the app gateway
     * @param executeParams_ The parameters of the payload
     * @return The packed payload as a bytes32 hash
     */
    function _createDigest(
        address transmitter_,
        bytes32 payloadId_,
        address appGateway_,
        ExecuteParams memory executeParams_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    transmitter_,
                    payloadId_,
                    executeParams_.deadline,
                    executeParams_.callType,
                    executeParams_.writeFinality,
                    executeParams_.gasLimit,
                    msg.value,
                    executeParams_.readAt,
                    executeParams_.payload,
                    executeParams_.target,
                    appGateway_,
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
        // todo: match with watcher
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

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
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
