// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../../contracts/protocol/interfaces/IMessageTransmitter.sol";
import "../../contracts/protocol/interfaces/IMessageHandler.sol";

contract CCTPMessageTransmitter is IMessageTransmitter {
    uint32 public immutable override localDomain;
    address public immutable override attestationManager;

    // Mapping to store sent messages for verification
    mapping(uint64 => bytes) public sentMessages;
    uint64 public nonce;

    event MessageSent(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes messageBody,
        uint64 nonce,
        bytes message
    );

    event MessageReceived(bytes message, bytes attestation, bool success);

    constructor(uint32 _localDomain, address _attestationManager) {
        localDomain = _localDomain;
        attestationManager = _attestationManager;
    }

    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external override returns (uint64) {
        uint64 currentNonce = nonce++;
        sentMessages[currentNonce] = messageBody;

        bytes memory message = abi.encode(
            localDomain,
            msg.sender,
            destinationDomain,
            recipient,
            messageBody
        );
        emit MessageSent(destinationDomain, recipient, messageBody, currentNonce, message);

        return currentNonce;
    }

    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external override returns (bool) {
        (
            uint32 sourceDomain,
            bytes32 sender, // destinationDomain
            ,
            bytes32 recipient,
            bytes memory messageBody
        ) = abi.decode(message, (uint32, bytes32, uint32, bytes32, bytes));
        IMessageHandler(bytes32ToAddress(recipient)).handleReceiveMessage(
            sourceDomain,
            sender,
            messageBody
        );
        // In mock implementation, we'll always return true
        // In real implementation, this would verify the attestation
        emit MessageReceived(message, attestation, true);
        return true;
    }

    function addressToBytes32(address addr_) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr_)));
    }
    function bytes32ToAddress(bytes32 addrBytes32_) public pure returns (address) {
        return address(uint160(uint256(addrBytes32_)));
    }
}
