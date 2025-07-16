// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SwitchboardBase.sol";
import {WATCHER_ROLE} from "../../utils/common/AccessRoles.sol";
import {toBytes32Format} from "../../utils/common/Converters.sol";

/**
 * @title FastSwitchboard contract
 * @dev This contract implements a fast version of the SwitchboardBase contract
 * that enables payload attestations from watchers
 */
contract FastSwitchboard is SwitchboardBase {
    // used to track if watcher have attested a payload
    // payloadId => isAttested
    mapping(bytes32 => bool) public isAttested;

    // Error emitted when a payload is already attested by watcher.
    error AlreadyAttested();
    // Error emitted when watcher is not valid
    error WatcherNotFound();
    // Event emitted when watcher attests a payload
    event Attested(bytes32 payloadId_, address watcher);

    /**
     * @dev Constructor function for the FastSwitchboard contract
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
     * @dev Function to attest a payload
     * @param digest_ digest of the payload to be executed
     * @param proof_ proof from watcher
     * @notice we are attesting a payload uniquely identified with digest.
     */
    function attest(bytes32 digest_, bytes calldata proof_) public virtual {
        if (isAttested[digest_]) revert AlreadyAttested();

        address watcher = _recoverSigner(
            keccak256(abi.encodePacked(toBytes32Format(address(this)), chainSlug, digest_)),
            proof_
        );
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_] = true;
        emit Attested(digest_, watcher);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPayload(bytes32 digest_, bytes32) external view returns (bool) {
        // digest has enough attestations
        return isAttested[digest_];
    }

    function registerSwitchboard() external onlyOwner {
        socket__.registerSwitchboard();
    }

    function processTrigger(
        address plug_,
        bytes32 triggerId_,
        bytes calldata payload_,
        bytes calldata overrides_
    ) external payable {
        revert("Not implemented");
    }
}
