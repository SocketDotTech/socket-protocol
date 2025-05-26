// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./Trigger.sol";

contract Watcher is Trigger {
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    function initialize(
        uint32 evmxSlug_,
        uint256 triggerFees_,
        address owner_,
        address addressResolver_
    ) public reinitializer(1) {
        evmxSlug = evmxSlug_;
        triggerFees = triggerFees_;
        _initializeOwner(owner_);
        _setAddressResolver(addressResolver_);
    }

    function setCoreContracts(
        address requestHandler_,
        address configManager_,
        address promiseResolver_
    ) external onlyOwner {
        requestHandler__ = IRequestHandler(requestHandler_);
        configurations__ = IConfigurations(configManager_);
        promiseResolver__ = IPromiseResolver(promiseResolver_);
    }

    function setTriggerFees(
        uint256 triggerFees_,
        uint256 nonce_,
        bytes memory signature_
    ) external {
        _validateSignature(abi.encode(triggerFees_), nonce_, signature_);
        _setTriggerFees(triggerFees_);
    }

    function isWatcher(address account_) public view override returns (bool) {
        return
            account_ == address(requestHandler__) ||
            account_ == address(configurations__) ||
            account_ == address(promiseResolver__);
    }

    function queueAndSubmit(
        QueueParams memory queue_,
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes memory onCompleteData
    ) external returns (uint40, address[] memory) {
        _queue(queue_, msg.sender);
        return _submitRequest(maxFees, auctionManager, consumeFrom, onCompleteData);
    }

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
        // checks if app gateway passed by forwarder is coming from same core app gateway group
        if (appGatewayTemp != address(0))
            if (appGatewayTemp != appGateway_ || appGateway_ == address(0))
                revert InvalidAppGateway();

        uint40 requestCount = getCurrentRequestCount();
        // Deploy a new async promise contract.
        latestAsyncPromise = asyncDeployer__().deployAsyncPromiseContract(
            appGateway_,
            requestCount
        );
        appGatewayTemp = appGateway_;
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
        bytes memory onCompleteData
    ) external returns (uint40, address[] memory) {
        return _submitRequest(maxFees, auctionManager, consumeFrom, onCompleteData);
    }

    function _submitRequest(
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes memory onCompleteData
    ) internal returns (uint40 requestCount, address[] memory promiseList) {
        // this check is to verify that msg.sender (app gateway base) belongs to correct app gateway
        address appGateway = msg.sender;
        if (appGateway != appGatewayTemp) revert InvalidAppGateway();
        latestAsyncPromise = address(0);

        (requestCount, promiseList) = requestHandler__.submitRequest(
            maxFees,
            auctionManager,
            consumeFrom,
            appGateway,
            payloadQueue,
            onCompleteData
        );
        clearQueue();
    }

    /// @notice Clears the call parameters array
    function clearQueue() public {
        delete payloadQueue;
    }

    function callAppGateways(WatcherMultiCallParams[] memory params_) external {
        for (uint40 i = 0; i < params_.length; i++) {
            _validateSignature(params_[i].data, params_[i].nonce, params_[i].signature);
            TriggerParams memory params = abi.decode(params_[i].data, (TriggerParams));
            _callAppGateways(params);
        }
    }

    function getCurrentRequestCount() public view returns (uint40) {
        return requestHandler__.nextRequestCount();
    }

    function getRequestParams(uint40 requestCount_) external view returns (RequestParams memory) {
        return requestHandler__.requests(requestCount_);
    }

    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return requestHandler__.payloads(payloadId_);
    }

    function getPrecompileFees(
        bytes4 precompile_,
        bytes memory precompileData_
    ) external view returns (uint256) {
        return requestHandler__.getPrecompileFees(precompile_, precompileData_);
    }

    // all function from watcher requiring signature
    // can be also used to do msg.sender check related function in other contracts like withdraw credits from fees manager and set core app-gateways in configurations
    function watcherMultiCall(WatcherMultiCallParams[] memory params_) external payable {
        for (uint40 i = 0; i < params_.length; i++) {
            if (params_[i].contractAddress == address(0)) revert InvalidContract();
            _validateSignature(params_[i].data, params_[i].nonce, params_[i].signature);

            // call the contract
            // trusting watcher to send enough value for all calls
            (bool success, ) = params_[i].contractAddress.call{value: params_[i].value}(
                params_[i].data
            );
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
    ) internal returns (bool) {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(
            abi.encode(address(this), evmxSlug, signatureNonce_, inputData_)
        );
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        return signer == owner();
    }
}
