// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/ISocketBatcher.sol";
import "../utils/RescueFundsLib.sol";
import {ExecuteParams} from "../../protocol/utils/common/Structs.sol";

/**
 * @title SocketBatcher
 * @notice The SocketBatcher contract is responsible for batching payloads and transmitting them to the destination chain
 */
contract SocketBatcher is ISocketBatcher, Ownable {
    // socket contract
    ISocket public immutable socket__;

    /**
     * @notice Initializes the SocketBatcher contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     * @param socket_ The address of socket contract
     */
    constructor(address owner_, ISocket socket_) {
        socket__ = socket_;
        _initializeOwner(owner_);
    }

    /**
     * @notice Attests a payload and executes it
     * @param executeParams_ The execution parameters
     * @param digest_ The digest of the payload
     * @param proof_ The proof of the payload
     * @param transmitterSignature_ The signature of the transmitter
     * @return The return data after execution
     */
    function attestAndExecute(
        ExecuteParams calldata executeParams_,
        bytes32 digest_,
        bytes calldata proof_,
        bytes calldata transmitterSignature_
    ) external payable returns (bool, bool, bytes memory) {
        ISwitchboard(executeParams_.switchboard).attest(digest_, proof_);
        return socket__.execute{value: msg.value}(executeParams_, transmitterSignature_);
    }

    /**
     * @notice Rescues funds from the contract
     * @param token_ The address of the token to rescue
     * @param to_ The address to rescue the funds to
     * @param amount_ The amount of funds to rescue
     */
    function rescueFunds(address token_, address to_, uint256 amount_) external onlyOwner {
        RescueFundsLib._rescueFunds(token_, to_, amount_);
    }
}
