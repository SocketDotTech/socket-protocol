// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./Trigger.sol";
import "../interfaces/IPromise.sol";

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

    function isWatcher(address account_) public view override returns (bool) {
        return
            account_ == address(requestHandler__) ||
            account_ == address(configurations__) ||
            account_ == address(promiseResolver__);
    }

    // can be called to submit single payload request without any callback
    function queueAndSubmit(
        QueueParams memory queue_,
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes memory onCompleteData
    ) external returns (uint40 requestCount, address[] memory promises) {
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
        if (payloadQueue.length == 0) return (0, new address[](0));
        address appGateway = msg.sender;

        // this check is to verify that msg.sender (app gateway base) belongs to correct app gateway
        if (appGateway != appGatewayTemp) revert InvalidAppGateway();
        latestAsyncPromise = address(0);
        appGatewayTemp = address(0);

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

    function callAppGateways(WatcherMultiCallParams memory params_) external {
        _validateSignature(address(this), params_.data, params_.nonce, params_.signature);
        TriggerParams[] memory params = abi.decode(params_.data, (TriggerParams[]));

        for (uint40 i = 0; i < params.length; i++) {
            _callAppGateways(params[i]);
        }
    }

    function setTriggerFees(
        uint256 triggerFees_,
        uint256 nonce_,
        bytes memory signature_
    ) external {
        _validateSignature(address(this), abi.encode(triggerFees_), nonce_, signature_);
        _setTriggerFees(triggerFees_);
    }

    function getCurrentRequestCount() public view returns (uint40) {
        return requestHandler__.nextRequestCount();
    }

    function getRequestParams(uint40 requestCount_) external view returns (RequestParams memory) {
        return requestHandler__.getRequest(requestCount_);
    }

    function getPayloadParams(bytes32 payloadId_) external view returns (PayloadParams memory) {
        return requestHandler__.getPayload(payloadId_);
    }

    function setIsValidPlug(bool isValid_, uint32 chainSlug_, bytes32 plug_) external override {
        configurations__.setIsValidPlug(isValid_, chainSlug_, plug_, msg.sender);
    }

    function cancelRequest(uint40 requestCount_) external override {
        requestHandler__.cancelRequest(requestCount_, msg.sender);
    }

    function increaseFees(uint40 requestCount_, uint256 newFees_) external override {
        requestHandler__.increaseFees(requestCount_, newFees_, msg.sender);
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
            _validateSignature(
                params_[i].contractAddress,
                params_[i].data,
                params_[i].nonce,
                params_[i].signature
            );

            // call the contract
            (bool success, ) = params_[i].contractAddress.call(params_[i].data);
            if (!success) revert CallFailed();
        }
    }

    /// @notice Verifies that a watcher signature is valid
    /// @param data_ The data to verify
    /// @param nonce_ The nonce of the signature
    /// @param signature_ The signature to verify
    function _validateSignature(
        address contractAddress_,
        bytes memory data_,
        uint256 nonce_,
        bytes memory signature_
    ) internal {
        if (contractAddress_ == address(0)) revert InvalidContract();
        if (data_.length == 0) revert InvalidData();
        if (signature_.length == 0) revert InvalidSignature();
        if (isNonceUsed[nonce_]) revert NonceUsed();
        isNonceUsed[nonce_] = true;

        bytes32 digest = keccak256(
            abi.encode(address(this), evmxSlug, nonce_, contractAddress_, data_)
        );

        // check if signature is valid
        if (_recoverSigner(digest, signature_) != owner()) revert InvalidSignature();
    }

    /// @notice Recovers the signer of a message
    /// @param digest_ The digest of the input data
    /// @param signature_ The signature to verify
    /// @dev This function verifies that the signature was created by the watcher and that the nonce has not been used before
    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));

        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

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
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) external {
        _validateSignature(
            address(this),
            abi.encode(token_, rescueTo_, amount_),
            nonce_,
            signature_
        );
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
