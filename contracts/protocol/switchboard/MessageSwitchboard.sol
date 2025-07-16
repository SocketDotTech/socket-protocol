// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SwitchboardBase.sol";
import {WATCHER_ROLE} from "../../utils/common/AccessRoles.sol";
import {toBytes32Format} from "../../utils/common/Converters.sol";
import {createPayloadId} from "../../utils/common/IdUtils.sol";
import {DigestParams} from "../../utils/common/Structs.sol";
import {WRITE} from "../../utils/common/Constants.sol";

/**
 * @title MessageSwitchboard contract
 * @dev This contract implements a message switchboard that enables payload attestations from watchers
 */
contract MessageSwitchboard is SwitchboardBase {
    // used to track if watcher have attested a payload
    // payloadId => isAttested
    mapping(bytes32 => bool) public isAttested;

    // sibling mappings for outbound journey
    // chainSlug => siblingSocket
    mapping(uint32 => bytes32) public siblingSockets;
    // chainSlug => siblingSwitchboard
    mapping(uint32 => bytes32) public siblingSwitchboards;
    // chainSlug => address => siblingPlug
    mapping(uint32 => mapping(address => bytes32)) public siblingPlugs;

    // payload counter for generating unique payload IDs
    uint40 public payloadCounter;

    // Constant appGatewayId used on all chains
    bytes32 constant APP_GATEWAY_ID =
        0xdeadbeefcafebabe1234567890abcdef1234567890abcdef1234567890abcdef;

    // Error emitted when a payload is already attested by watcher.
    error AlreadyAttested();
    // Error emitted when watcher is not valid
    error WatcherNotFound();
    // Error emitted when sibling not found
    error SiblingNotFound();
    // Error emitted when invalid target verification
    error InvalidTargetVerification();

    // Event emitted when watcher attests a payload
    event Attested(bytes32 payloadId_, address watcher);
    // Event emitted when trigger is processed
    event TriggerProcessed(
        bytes32 payloadId,
        bytes32 digest,
        bytes32 dstPlug,
        uint32 dstChainSlug,
        bytes payload
    );
    // Event emitted when sibling is registered
    event SiblingRegistered(uint32 chainSlug, address plugAddress, bytes32 siblingPlug);

    // Event emitted when sibling config is set
    event SiblingConfigSet(uint32 chainSlug, bytes32 socket, bytes32 switchboard);

    /**
     * @dev Constructor function for the MessageSwitchboard contract
     * @param chainSlug_ Chain slug of the chain where the contract is deployed
     * @param socket_ Socket contract address
     * @param owner_ Owner of the contract
     */
    constructor(
        uint32 chainSlug_,
        ISocket socket_,
        address owner_
    ) SwitchboardBase(chainSlug_, socket_, owner_) {}

    /**
     * @dev Function to register sibling addresses for a chain (admin only)
     * @param chainSlug_ Chain slug of the sibling chain
     * @param socket_ Sibling socket address
     * @param switchboard_ Sibling switchboard address
     */
    function setSiblingConfig(
        uint32 chainSlug_,
        bytes32 socket_,
        bytes32 switchboard_
    ) external onlyOwner {
        siblingSockets[chainSlug_] = socket_;
        siblingSwitchboards[chainSlug_] = switchboard_;

        emit SiblingConfigSet(chainSlug_, socket_, switchboard_);
    }

    /**
     * @dev Function for plugs to register their own siblings
     * @param chainSlug_ Chain slug of the sibling chain
     * @param siblingPlug_ Sibling plug address
     */
    function registerSibling(uint32 chainSlug_, bytes32 siblingPlug_) external {
        if (
            siblingSockets[chainSlug_] == bytes32(0) ||
            siblingSwitchboards[chainSlug_] == bytes32(0)
        ) {
            revert SiblingNotFound();
        }

        // Register the sibling for the calling plug
        siblingPlugs[chainSlug_][msg.sender] = siblingPlug_;
        emit SiblingRegistered(chainSlug_, msg.sender, siblingPlug_);
    }

    /**
     * @dev Function to process trigger and create payload
     * @param plug_ Source plug address
     * @param triggerId_ Trigger ID from socket
     * @param payload_ Payload data
     * @param overrides_ Override parameters including dstChainSlug and gasLimit
     */
    function processTrigger(
        address plug_,
        bytes32 triggerId_,
        bytes calldata payload_,
        bytes calldata overrides_
    ) external payable override {
        (uint32 dstChainSlug, uint256 gasLimit, uint256 value) = abi.decode(
            overrides_,
            (uint32, uint256, uint256)
        );

        bytes32 dstSocket = siblingSockets[dstChainSlug];
        bytes32 dstSwitchboard = siblingSwitchboards[dstChainSlug];
        bytes32 dstPlug = siblingPlugs[dstChainSlug][plug_];

        if (dstSocket == bytes32(0) || dstSwitchboard == bytes32(0) || dstPlug == bytes32(0)) {
            revert SiblingNotFound();
        }

        uint64 socketCounter = uint64(uint256(triggerId_));
        bytes32 payloadId = createPayloadId(
            0,
            uint40(socketCounter),
            payloadCounter++,
            dstSwitchboard,
            dstChainSlug
        );

        // Create digest with new structure
        bytes memory extraData = abi.encodePacked(chainSlug, toBytes32Format(plug_));
        bytes32 digest = _createDigest(
            dstSocket,
            address(0),
            payloadId,
            block.timestamp + 3600,
            WRITE,
            gasLimit,
            value,
            dstPlug,
            APP_GATEWAY_ID,
            triggerId_,
            payload_,
            extraData
        );

        emit TriggerProcessed(payloadId, digest, dstPlug, dstChainSlug, payload_);
    }

    /**
     * @dev Function to attest a payload with enhanced verification
     * @param digest_ Full unhashed digest parameters
     * @param proof_ proof from watcher
     * @notice Enhanced attestation that verifies target with srcChainSlug and srcPlug
     */
    function attest(DigestParams calldata digest_, bytes calldata proof_) public {
        if (isAttested[digest_.payloadId]) revert AlreadyAttested();
        (uint32 srcChainSlug, bytes32 srcPlug) = abi.decode(digest_.extraData, (uint32, bytes32));

        if (siblingPlugs[srcChainSlug][address(uint160(uint256(srcPlug)))] != digest_.target) {
            revert InvalidTargetVerification();
        }

        address watcher = _recoverSigner(
            keccak256(
                abi.encodePacked(toBytes32Format(address(this)), chainSlug, digest_.payloadId)
            ),
            proof_
        );
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_.payloadId] = true;
        emit Attested(digest_.payloadId, watcher);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPayload(bytes32 digest_, bytes32) external view override returns (bool) {
        // digest has enough attestations
        return isAttested[digest_];
    }

    function registerSwitchboard() external onlyOwner {
        socket__.registerSwitchboard();
    }

    /**
     * @dev Internal function to create digest from parameters
     */
    function _createDigest(
        bytes32 socket_,
        address transmitter_,
        bytes32 payloadId_,
        uint256 deadline_,
        bytes4 callType_,
        uint256 gasLimit_,
        uint256 value_,
        bytes32 target_,
        bytes32 appGatewayId_,
        bytes32 prevDigestHash_,
        bytes calldata payload_,
        bytes memory extraData_
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    socket_,
                    transmitter_,
                    payloadId_,
                    deadline_,
                    callType_,
                    gasLimit_,
                    value_,
                    payload_,
                    target_,
                    appGatewayId_,
                    prevDigestHash_,
                    extraData_
                )
            );
    }
}
