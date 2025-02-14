// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../libraries/ECDSA.sol";
import "../../interfaces/ISignatureVerifier.sol";
import "../../libraries/RescueFundsLib.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import "solady/utils/Initializable.sol";

/**
 * @title Signature Verifier
 * @notice Verifies the signatures and returns the address of signer recovered from the input signature or digest.
 * @dev This contract is modular component in socket to support different signing algorithms.
 */
contract SignatureVerifier is ISignatureVerifier, AccessControl, Initializable {
    uint64 public version;

    /*
     * @dev Error thrown when signature length is invalid
     */
    error InvalidSigLength();

    /**
     * @notice initializes and grants RESCUE_ROLE to owner.
     * @param owner_ The address of the owner of the contract.
     */
    function initialize(address owner_, uint64 version_) public reinitializer(version_) {
        version = version_;
        _claimOwner(owner_);
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice returns the address of signer recovered from input signature and digest
     * @param digest_ The payload digest to be signed
     * @param signature_ The signature to be verified
     * @return signer The address of the signer
     */
    function recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) public pure override returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA._recover(digest, signature_);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake.
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
