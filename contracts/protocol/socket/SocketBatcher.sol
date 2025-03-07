// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../interfaces/ISocket.sol";
import "../../interfaces/ISwitchboard.sol";
import "../utils/RescueFundsLib.sol";
import {AttestAndExecutePayloadParams} from "../../protocol/utils/common/Structs.sol";

/**
 * @title SocketRequester
 * @notice The SocketRequester contract is responsible for batching payloads and transmitting them to the destination chain
 */
contract SocketRequester is Ownable {
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
    ) external payable returns (bytes memory) {
        ISwitchboard(params_.switchboard).attest(params_.payloadId, params_.digest, params_.proof);

        ISocket.ExecuteParams memory executeParams = ISocket.ExecuteParams({
            payloadId: params_.payloadId,
            target: params_.target,
            executionGasLimit: params_.executionGasLimit,
            deadline: params_.deadline,
            payload: params_.payload
        });
        return
            socket__.execute{value: msg.value}(
                params_.appGateway,
                executeParams,
                params_.transmitterSignature
            );
    }

    function rescueFunds(address token_, address to_, uint256 amount_) external onlyOwner {
        RescueFundsLib._rescueFunds(token_, to_, amount_);
    }
}
