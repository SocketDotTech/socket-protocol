// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IWatcher.sol";

import {InvalidCallerTriggered, TimeoutDelayTooLarge, TimeoutAlreadyResolved, InvalidInboxCaller, ResolvingTimeoutTooEarly, CallFailed, AppGatewayAlreadyCalled, InvalidWatcherSignature, NonceUsed, RequestAlreadyExecuted} from "../../utils/common/Errors.sol";
import {ResolvedPromises, AppGatewayConfig, LimitParams, WriteFinality, UpdateLimitParams, PlugConfig, DigestParams, TimeoutRequest, QueueParams, PayloadParams, RequestParams} from "../../utils/common/Structs.sol";

/// @title WatcherStorage
/// @notice Storage contract for the WatcherPrecompile system
/// @dev This contract contains all the storage variables used by the WatcherPrecompile system
/// @dev It is inherited by WatcherPrecompileCore and WatcherPrecompile
abstract contract WatcherStorage is IWatcher {
    // todo: can we remove proxies?
    // slots [0-49]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 50
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // Payload Params
    /// @notice The time from queue for the payload to be executed
    /// @dev Expiry time in seconds for payload execution
    uint256 public expiryTime;

    /// @notice Maps nonce to whether it has been used
    /// @dev Used to prevent replay attacks with signature nonces
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // queue => update to payloadParams, assign id, store in payloadParams map
    /// @notice Mapping to store the payload parameters for each payload ID
    mapping(bytes32 => PayloadParams) public payloads;

    /// @notice The metadata for a request
    mapping(uint40 => RequestParams) public requests;

    /// @notice The queue of payloads
    QueueParams[] public payloadQueue;
    address public latestAsyncPromise;
    address public appGatewayTemp;

    // slots [51-100]: gap for future storage variables
    uint256[50] _gap_after;

    // slots 115-165 (51) reserved for access control
    // slots 166-216 (51) reserved for addr resolver util
}

contract Watcher is WatcherStorage {
    IRequestHandler public requestHandler__;
    IConfigManager public configManager__;
    IPromiseResolver public promiseResolver__;
    IAddressResolver public addressResolver__;

    constructor(
        address requestHandler_,
        address configManager_,
        address promiseResolver_,
        address addressResolver_
    ) {
        requestHandler__ = requestHandler_;
        configManager__ = configManager_;
        promiseResolver__ = promiseResolver_;
        addressResolver__ = addressResolver_;
    }

    /// @notice Clears the call parameters array
    function clearQueue() public {
        delete queue;
    }

    function queueAndRequest(
        QueueParams memory queue_,
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes onCompleteData
    ) internal returns (uint40, address[] memory) {
        _queue(queue_, msg.sender);
        return _submitRequest(maxFees, auctionManager, consumeFrom, onCompleteData);
    }

    // todo: delegate call?
    // todo: check app gateway input auth
    /// @notice Queues a new payload
    /// @param queue_ The call parameters
    function queue(
        QueueParams memory queue_,
        address appGateway_
    ) external returns (address, uint40) {
        return _queue(queue_, appGateway_);
    }

    function _queue(
        QueueParams memory queue_,
        address appGateway_
    ) internal returns (address, uint40) {
        address coreAppGateway = getCoreAppGateway(appGateway_);
        // Deploy a new async promise contract.
        if (appGatewayTemp != address(0))
            if (appGatewayTemp != coreAppGateway || coreAppGateway == address(0))
                revert InvalidAppGateway();

        latestAsyncPromise = asyncDeployer__().deployAsyncPromiseContract(coreAppGateway);
        appGatewayTemp = coreAppGateway;
        queue_.asyncPromise = latestAsyncPromise;

        // Add the promise to the queue.
        payloadQueue.push(queue_);
        // return the promise and request count
        return (latestAsyncPromise, requestHandler__.nextRequestCount());
    }

    function then(bytes4 selector_, bytes memory data_) external {
        if (latestAsyncPromise == address(0)) revert NoAsyncPromiseFound();
        if (latestRequestCount != requestHandler__.nextRequestCount())
            revert RequestCountMismatch();

        address latestAsyncPromise_ = latestAsyncPromise;
        latestAsyncPromise = address(0);

        // as same req count is checked, assuming app gateway will be same else it will revert on batch
        promise_ = IPromise(latestAsyncPromise_).then(selector_, data_);
    }

    function submitRequest(
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes onCompleteData
    ) external returns (uint40, address[] memory) {
        return _submitRequest(maxFees, auctionManager, consumeFrom, onCompleteData);
    }

    function _submitRequest(
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes onCompleteData
    ) internal returns (uint40 requestCount, address[] memory promiseList) {
        if (getCoreAppGateway(msg.sender) != appGatewayTemp) revert InvalidAppGateways();

        (requestCount, promiseList) = requestHandler__.submitRequest(
            maxFees,
            auctionManager,
            consumeFrom,
            msg.sender,
            payloadQueue,
            onCompleteData
        );
        clearQueue();
    }

    function setPayloadParams(bytes32 payloadId_, PayloadParams memory payloadParams_) external {
        if (msg.sender != address(requestHandler)) revert InvalidCaller();
        payloads[payloadId_] = payloadParams_;
    }

    function setRequestParams(uint40 requestCount_, RequestParams memory requestParams_) external {
        if (msg.sender != address(requestHandler)) revert InvalidCaller();
        requests[requestCount_] = requestParams_;
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    function getRequestParams(uint40 requestCount_) external view returns (RequestParams memory) {
        return requests[requestCount_];
    }

    // all function from watcher requiring signature
    function watcherMultiCall(
        address[] memory contracts,
        bytes[] memory data_,
        uint256[] memory nonces_,
        bytes[] memory signatures_
    ) external payable {
        for (uint40 i = 0; i < contracts.length; i++) {
            if (contracts[i] == address(0)) revert InvalidContract();
            if (data_[i].length == 0) revert InvalidData();
            if (nonces_[i] == 0) revert InvalidNonce();
            if (signatures_[i].length == 0) revert InvalidSignature();

            // check if signature is valid
            if (!_isWatcherSignatureValid(nonces_[i], data_[i], signatures_[i]))
                revert InvalidSignature();

            // call the contract
            (bool success, bytes memory result) = contracts[i].call{value: msg.value}(data_[i]);
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
