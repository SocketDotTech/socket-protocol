// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SwitchboardBase.sol";

/**
 * @title FastSwitchboard contract
 * @dev This contract implements a fast version of the SwitchboardBase contract
 * that enables packet attestations
 */
contract FastSwitchboard is SwitchboardBase {
    // used to track if watcher have attested a digest
    // digest => isAttested
    mapping(bytes32 => bool) public isAttested;

    // Error emitted when a digest is already attested by watcher.
    error AlreadyAttested();
    // Error emitted when watcher is not valid
    error WatcherNotFound();

    // Event emitted when watcher attests a digest
    event Attested(bytes32 digest_, address watcher);

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
     * @dev Function to attest a packet
     * @param digest_ digest of the payload to be executed
     * @param proof_ proof from watcher
     * @notice we are attesting a digest uniquely identified with payloadId.
     */
    function attest(bytes32 digest_, bytes calldata proof_) external {
        address watcher = _recoverSigner(keccak256(abi.encode(address(this), digest_)), proof_);

        if (isAttested[digest_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();
        isAttested[digest_] = true;

        emit Attested(digest_, watcher);
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

    function registerSwitchboard() external onlyOwner {
        socket__.registerSwitchboard();
    }
}
