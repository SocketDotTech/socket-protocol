// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./Trigger.sol";

contract Watcher is Trigger {
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

    function queueAndSubmit(
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

        // checks if app gateway passed by forwarder is coming from same core app gateway group
        if (appGatewayTemp != address(0))
            if (appGatewayTemp != coreAppGateway || coreAppGateway == address(0))
                revert InvalidAppGateway();

        uint40 requestCount = requestHandler__.nextRequestCount();
        // Deploy a new async promise contract.
        latestAsyncPromise = asyncDeployer__().deployAsyncPromiseContract(
            appGateway_,
            requestCount
        );
        appGatewayTemp = coreAppGateway;
        queue_.asyncPromise = latestAsyncPromise;

        // Add the promise to the queue.
        payloadQueue.push(queue_);
        // return the promise and request count
        return (latestAsyncPromise, requestCount);
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
        // this check is to verify that msg.sender (app gateway base) belongs to correct app gateway
        address coreAppGateway = getCoreAppGateway(msg.sender);
        if (coreAppGateway != appGatewayTemp) revert InvalidAppGateways();
        latestAsyncPromise = address(0);

        (requestCount, promiseList) = requestHandler__.submitRequest(
            maxFees,
            auctionManager,
            consumeFrom,
            coreAppGateway,
            payloadQueue,
            onCompleteData
        );
        clearQueue();
    }

    /// @notice Clears the call parameters array
    function clearQueue() public {
        delete queue;
    }

    function callAppGateways(
        TriggerParams[] memory params_,
        uint256 nonce_,
        bytes memory signature_
    ) external {
        _validateSignature(abi.encode(params_), nonce_, signature_);
        for (uint40 i = 0; i < params_.length; i++) {
            _callAppGateways(params_[i]);
        }
    }

    function getRequestParams(uint40 requestCount_) external view returns (RequestParams memory) {
        return requestHandler__().getRequestParams(requestCount_);
    }

    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return requestHandler__().getPayloadParams(payloadId_);
    }

    /// @notice Sets the expiry time for payload execution
    /// @param expiryTime_ The expiry time in seconds
    /// @dev This function sets the expiry time for payload execution
    /// @dev Only callable by the contract owner
    function setExpiryTime(uint256 expiryTime_) external onlyOwner {
        expiryTime = expiryTime_;
        emit ExpiryTimeSet(expiryTime_);
    }

    function setTriggerFees(
        uint256 triggerFees_,
        uint256 nonce_,
        bytes memory signature_
    ) external {
        _validateSignature(abi.encode(triggerFees_), nonce_, signature_);
        _setTriggerFees(triggerFees_);
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
            _validateSignature(data_[i], nonces_[i], signatures_[i]);
            // call the contract
            (bool success, bytes memory result) = contracts[i].call{value: msg.value}(data_[i]);
            if (!success) revert CallFailed();
        }
    }

    function _validateSignature(
        bytes memory data_,
        uint256 nonce_,
        bytes memory signature_
    ) internal {
        if (data_.length == 0) revert InvalidData();
        if (nonce_ == 0) revert InvalidNonce();
        if (signature_.length == 0) revert InvalidSignature();

        // check if signature is valid
        if (!_isWatcherSignatureValid(nonce_, data_, signature_)) revert InvalidSignature();
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
