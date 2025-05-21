// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../PayloadHeaderDecoder.sol";
import "../../interfaces/IWatcherPrecompile.sol";
import {IAppGateway} from "../../interfaces/IAppGateway.sol";
import {InvalidCallerTriggered, TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed, RequestAlreadyExecuted} from "../../../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, TimeoutRequest, QueuePayloadParams, PayloadParams, RequestParams, RequestMetadata} from "../../../utils/common/Structs.sol";

/// @title WatcherPrecompileStorage
/// @notice Storage contract for the WatcherPrecompile system
/// @dev This contract contains all the storage variables used by the WatcherPrecompile system
/// @dev It is inherited by WatcherPrecompileCore and WatcherPrecompile
abstract contract WatcherPrecompileStorage is IWatcherPrecompile {
    // slots [0-49]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 50
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // IDs
    /// @notice Counter for tracking payload requests
    uint40 public payloadCounter;

    /// @notice Counter for tracking request counts
    uint40 public override nextRequestCount;

    /// @notice Counter for tracking batch counts
    uint40 public nextBatchCount;

    // Payload Params
    /// @notice The time from finalize for the payload to be executed
    /// @dev Expiry time in seconds for payload execution
    uint256 public expiryTime;

    // slot 55
    /// @notice Maps nonce to whether it has been used
    /// @dev Used to prevent replay attacks with signature nonces
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 56
    /// @notice Mapping to store watcher proofs
    /// @dev Maps payload ID to proof bytes
    /// @dev payloadId => proof bytes
    mapping(bytes32 => bytes) public watcherProofs;

    // slot 59
    /// @notice Mapping to store the list of payload IDs for each batch
    mapping(uint40 => bytes32[]) public batchPayloadIds;

    // slot 60
    /// @notice Mapping to store the batch IDs for each request
    mapping(uint40 => uint40[]) public requestBatchIds;

    // slot 61
    // queue => update to payloadParams, assign id, store in payloadParams map
    /// @notice Mapping to store the payload parameters for each payload ID
    mapping(bytes32 => PayloadParams) public payloads;

    // slot 53
    /// @notice The metadata for a request
    mapping(uint40 => RequestParams) public requests;

    // slot 62
    /// @notice The queue of payloads
    QueueParams[] public queue;

    // slots [67-114]: gap for future storage variables
    uint256[48] _gap_after;

    // slots 115-165 (51) reserved for access control
    // slots 166-216 (51) reserved for addr resolver util
}

contract WatcherPrecompileStorageAdapter is WatcherPrecompileStorage {
     /// @notice Clears the call parameters array
    function clearQueue() public {
        delete queuePayloadParams;
    }

    /// @notice Queues a new payload
    /// @param queuePayloadParams_ The call parameters
    function queue(QueuePayloadParams memory queuePayloadParams_) external {
        queuePayloadParams.push(queuePayloadParams_);
    }

    
    /// @notice Marks a request as finalized with a proof on digest
    /// @param payloadId_ The unique identifier of the request
    /// @param proof_ The watcher's proof
    /// @dev This function marks a request as finalized with a proof
    function finalized(bytes32 payloadId_, bytes memory proof_) public onlyOwner {
        watcherProofs[payloadId_] = proof_;
        emit Finalized(payloadId_, proof_);
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }


    /// @notice Gets the current request count
    /// @return The current request count
    /// @dev This function returns the next request count, which is the current request count
    function getCurrentRequestCount() external view returns (uint40) {
        return nextRequestCount;
    }

    /// @notice Gets the request parameters for a request
    /// @param requestCount The request count to get the parameters for
    /// @return The request parameters for the given request count
    function getRequestParams(uint40 requestCount) external view returns (RequestParams memory) {
        return requestParams[requestCount];
    }


    // all function from watcher requiring signature
    function watcherMultiCall(address[] callData contracts, bytes[] callData data_, uint256[] calldata nonces_, bytes[] callData signatures_) {
        for (uint40 i = 0; i < contracts.length; i++) {
            if (contracts[i] == address(0)) revert InvalidContract();
            if (data_[i].length == 0) revert InvalidData();
            if (nonces_[i] == 0) revert InvalidNonce();
            if (signatures_[i].length == 0) revert InvalidSignature();

            // check if signature is valid
            if (!_isWatcherSignatureValid(nonces_[i], data_[i], signatures_[i])) revert InvalidSignature();

            // call the contract
            (bool success, bytes memory result) = contracts[i].call(data_[i]);
            if (!success) revert CallFailed();
        }
    }

     /// @notice Verifies that a watcher signature is valid
    /// @param signatureNonce_ The nonce of the signature
    /// @param inputData_ The input data to verify
    /// @param signature_ The signature to verify
    /// @dev This function verifies that the signature was created by the watcher and that the nonce has not been used before
    function _isWatcherSignatureValid(
        uint256 signatureNonce_,
        bytes memory inputData_,
        bytes memory signature_
    ) internal {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(
            abi.encode(address(this), evmxSlug, signatureNonce_, inputData_)
        );
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }
}
