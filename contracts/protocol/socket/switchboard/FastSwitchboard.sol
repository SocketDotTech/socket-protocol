// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SwitchboardBase.sol";

/**
 * @title FastSwitchboard contract
 * @dev This contract implements a fast version of the SwitchboardBase contract
 * that enables packet attestations and watchers registration.
 */
contract FastSwitchboard is SwitchboardBase {
    // used to track which watcher have attested a digest
    // watcher => digest => isAttested
    mapping(bytes32 => bool) public isAttested;

    // Error emitted when a digest is already attested by a specific watcher.
    // This is hit even if they are attesting a new proposalCount with same digest.
    error AlreadyAttested();
    error WatcherNotFound();
    event Attested(bytes32 payloadId, bytes32 digest_, address watcher);

    /**
     * @dev Constructor function for the FastSwitchboard contract
     * @param chainSlug_ Chain slug of the chain where the contract is deployed
     */
    constructor(
        uint32 chainSlug_,
        ISocket socket_,
        address owner_
    ) SwitchboardBase(chainSlug_, socket_, owner_) {}

    /**
     * @dev Function to attest a packet
     * @param payloadId_ Packet ID
     * @param digest_ Digest of the packet
     * @param proof_ Proof of the watcher
     * @notice we are attesting a digest uniquely identified with packetId and proposalCount. However,
     * there can be multiple proposals for same digest. To avoid need to re-attest for different proposals
     *  with same digest, we are storing attestations against digest instead of packetId and proposalCount.
     */
    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata proof_) external virtual {
        address watcher = _recoverSigner(keccak256(abi.encode(address(this), digest_)), proof_);

        if (isAttested[digest_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_] = true;
        emit Attested(payloadId_, digest_, watcher);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPacket(bytes32 digest_, bytes32) external view returns (bool) {
        // digest has enough attestations
        if (isAttested[digest_]) return true;

        // not enough attestations and timeout not hit
        return false;
    }

    /**
     * @notice adds a watcher for `srcChainSlug_` chain
     * @param watcher_ watcher address
     */
    function grantWatcherRole(address watcher_) external onlyOwner {
        _grantRole(WATCHER_ROLE, watcher_);
    }

    /**
     * @notice removes a watcher from `srcChainSlug_` chain list
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(address watcher_) external onlyOwner {
        _revokeRole(WATCHER_ROLE, watcher_);
    }

    function registerSwitchboard() external onlyOwner {
        socket__.registerSwitchboard();
    }
}
