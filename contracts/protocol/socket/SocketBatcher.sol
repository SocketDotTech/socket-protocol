// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../utils/RescueFundsLib.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {AttestAndExecutePayloadParams} from "../../protocol/utils/common/Structs.sol";

/**
 * @title SocketBatcher
 * @notice The SocketBatcher contract is responsible for batching payloads and transmitting them to the destination chain
 */
contract SocketBatcher is Ownable {
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
        AttestAndExecutePayloadParams calldata params_
    ) external payable returns (bytes memory returnData) {
        ISwitchboard(params_.switchboard).attest(params_.payloadId, params_.digest, params_.proof);

        ISocket.ExecuteParams memory executeParams = ISocket.ExecuteParams({
            payloadId: params_.payloadId,
            target: params_.target,
            executionGasLimit: params_.executionGasLimit,
            deadline: params_.deadline,
            payload: params_.payload
        });

        returnData = socket__.execute{value: msg.value}(
            params_.appGateway,
            executeParams,
            params_.transmitterSignature
        );

        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(socket__), params_.payloadId)),
            params_.transmitterSignature
        );
        ISwitchboard.PayloadParams memory payloadParams = ISwitchboard.PayloadParams({
            payloadId: params_.payloadId,
            appGateway: params_.appGateway,
            transmitter: transmitter,
            target: params_.target,
            value: 0,
            deadline: params_.deadline,
            executionGasLimit: params_.executionGasLimit,
            payload: params_.payload
        });
        ISwitchboard(params_.switchboard).syncOut(params_.digest, params_.payloadId, payloadParams);
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    function rescueFunds(address token_, address to_, uint256 amount_) external onlyOwner {
        RescueFundsLib._rescueFunds(token_, to_, amount_);
    }
}
