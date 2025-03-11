// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/**
 * @title ISwitchboard
 * @dev The interface for a switchboard contract that is responsible for verification of payloadss between
 * different blockchain networks.
 */
interface ISwitchboard {
    /**
     * @notice Checks if a payloads can be allowed to go through the switchboard.
     * @param digest_ the payloads digest.
     * @param payloadId_ The unique identifier for the payloads.
     * @return A boolean indicating whether the payloads is allowed to go through the switchboard or not.
     */
    function allowPacket(bytes32 digest_, bytes32 payloadId_) external view returns (bool);

    function attest(bytes32 digest_, bytes calldata proof_) external;
}
