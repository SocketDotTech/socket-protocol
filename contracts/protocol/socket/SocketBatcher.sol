// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../utils/RescueFundsLib.sol";
import {ExecuteParams} from "../../protocol/utils/common/Structs.sol";
import "../../interfaces/ISocketBatcher.sol";
import {OpInteropSwitchboard} from "./switchboard/OpInteropSwitchboard.sol";

/**
 * @title SocketBatcher
 * @notice The SocketBatcher contract is responsible for batching payloads and transmitting them to the destination chain
 */
contract SocketBatcher is ISocketBatcher, Ownable {
    // socket contract
    ISocket public immutable socket__;

    /**
     * @notice Initializes the TransmitManager contract
     * @param socket_ The address of socket contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     */
    constructor(address owner_, ISocket socket_) {
        socket__ = socket_;
        _initializeOwner(owner_);
    }

    function attestAndExecute(
        ExecuteParams calldata executeParams_,
        bytes32 digest_,
        bytes calldata proof_,
        bytes calldata transmitterSignature_
    ) external payable returns (bytes memory) {
        ISwitchboard(executeParams_.switchboard).attest(digest_, proof_);
        return socket__.execute{value: msg.value}(executeParams_, transmitterSignature_);
    }

    function attestOPProveAndExecute(
        ExecuteParams calldata executeParams_,
        bytes32[] calldata previousPayloadIds_,
        bytes32 digest_,
        bytes calldata proof_,
        bytes calldata transmitterSignature_
    ) external payable returns (bytes memory) {
        OpInteropSwitchboard(executeParams_.switchboard).attest(
            _createPayloadId(executeParams_),
            digest_,
            proof_
        );
        OpInteropSwitchboard(executeParams_.switchboard).proveRemoteExecutions(
            previousPayloadIds_,
            _createPayloadId(executeParams_),
            transmitterSignature_,
            executeParams_
        );
        return socket__.execute{value: msg.value}(executeParams_, transmitterSignature_);
    }

    function _createPayloadId(ExecuteParams memory executeParams_) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    executeParams_.requestCount,
                    executeParams_.batchCount,
                    executeParams_.payloadCount,
                    executeParams_.switchboard,
                    socket__.chainSlug()
                )
            );
    }

    function rescueFunds(address token_, address to_, uint256 amount_) external onlyOwner {
        RescueFundsLib._rescueFunds(token_, to_, amount_);
    }
}
