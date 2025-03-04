// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/**
 * @title ISwitchboard
 * @dev The interface for a switchboard contract that is responsible for verification of packets between
 * different blockchain networks.
 */
interface ISwitchboard {
    struct PayloadParams {
        bytes32 payloadId;
        address appGateway;
        address transmitter;
        address target;
        uint256 value;
        uint256 deadline;
        uint256 executionGasLimit;
        bytes payload;
    }

    /**
     * @notice Checks if a packet can be allowed to go through the switchboard.
     * @param digest_ the packet digest.
     * @param packetId_ The unique identifier for the packet.
     * @return A boolean indicating whether the packet is allowed to go through the switchboard or not.
     */
    function allowPacket(bytes32 digest_, bytes32 packetId_) external view returns (bool);

    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata proof_) external;

    function syncOut(
        bytes32 digest_,
        bytes32 payloadId_,
        PayloadParams calldata payloadParams_
    ) external;
}
