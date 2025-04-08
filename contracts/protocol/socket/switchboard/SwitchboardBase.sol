// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../../interfaces/ISwitchboard.sol";
import "../../../interfaces/ISocket.sol";
import "../../utils/AccessControl.sol";
import {RESCUE_ROLE, WATCHER_ROLE} from "../../utils/common/AccessRoles.sol";
import "../../utils/RescueFundsLib.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControl {
    ISocket public immutable socket__;

    // chain slug of deployed chain
    uint32 public immutable chainSlug;
    
    /**
     * @dev Constructor of SwitchboardBase
     * @param chainSlug_ Chain slug of deployment chain
     * @param socket_ socket_ contract
     */
    constructor(uint32 chainSlug_, ISocket socket_, address owner_) {
        chainSlug = chainSlug_;
        socket__ = socket_;
        _initializeOwner(owner_);
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    //////////////////////////////////////////////
    //////////// Rescue role actions ////////////
    /////////////////////////////////////////////

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
