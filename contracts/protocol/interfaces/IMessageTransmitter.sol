// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface IMessageTransmitter {
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external returns (uint64 nonce);

    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool success);

    function localDomain() external view returns (uint32);

    function attestationManager() external view returns (address);
}
