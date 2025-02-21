// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/**
 * @title ISwitchboard
 * @dev The interface for a switchboard contract that is responsible for verification of packets between
 * different blockchain networks.
 */
interface ISwitchboard {
    /**
     * @notice Checks if a packet can be allowed to go through the switchboard.
     * @param digest_ the packet digest.
     * @param packetId_ The unique identifier for the packet.
     * @return A boolean indicating whether the packet is allowed to go through the switchboard or not.
     */
    function allowPacket(bytes32 digest_, bytes32 packetId_) external view returns (bool);

    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata signature_) external;
}
