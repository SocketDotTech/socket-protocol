// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./DeliveryUtils.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract RequestQueue is DeliveryUtils {
    // slots [207-257] reserved for gap
    uint256[50] _gap_queue_async;

   
    /// @notice Initiates a batch of payloads
    /// @param maxFees_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return requestCount The ID of the batch
    function batch(
        uint256 maxFees_,
        address auctionManager_,
        address consumeFrom_,
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount) {
        address appGateway = _getCoreAppGateway(msg.sender);
        return _batch(appGateway, auctionManager_, consumeFrom_, maxFees_, onCompleteData_);
    }

    /// @notice Initiates a batch of payloads
    /// @dev it checks fees, payload limits and creates the payload submit params array after assigning proper levels
    /// @dev It also modifies the deploy payloads as needed by contract factory plug
    /// @dev Stores request metadata and submits the request to watcher precompile
    function _batch(
        address appGateway_,
        address auctionManager_,
        address consumeFrom_,
        uint256 maxFees_,
        bytes memory onCompleteData_
    ) internal returns (uint40 requestCount) {
        if (queuePayloadParams.length == 0) return 0;

        BatchParams memory params = BatchParams({
            appGateway: appGateway_,
            auctionManager: _getAuctionManager(auctionManager_),
            maxFees: maxFees_,
            onCompleteData: onCompleteData_,
            onlyReadRequests: false,
            queryCount: 0,
            finalizeCount: 0
        });

        // Split the function into smaller parts
        (
            PayloadSubmitParams[] memory payloadSubmitParamsArray,
            bool onlyReadRequests,
            uint256 queryCount,
            uint256 finalizeCount
        ) = _createPayloadSubmitParamsArray();

        params.onlyReadRequests = onlyReadRequests;
        params.queryCount = queryCount;
        params.finalizeCount = finalizeCount;

        _checkBatch(consumeFrom_, params.appGateway, params.maxFees);
        return _submitBatchRequest(payloadSubmitParamsArray, consumeFrom_, params);
    }

    function _submitBatchRequest(
        PayloadSubmitParams[] memory payloadSubmitParamsArray,
        address consumeFrom_,
        BatchParams memory params
    ) internal returns (uint40 requestCount) {
        RequestMetadata memory requestMetadata = RequestMetadata({
            appGateway: params.appGateway,
            auctionManager: params.auctionManager,
            maxFees: params.maxFees,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            onCompleteData: params.onCompleteData,
            onlyReadRequests: params.onlyReadRequests,
            consumeFrom: consumeFrom_,
            queryCount: params.queryCount,
            finalizeCount: params.finalizeCount
        });

        requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
        requests[requestCount] = requestMetadata;

        if (params.onlyReadRequests) {
            watcherPrecompile__().startProcessingRequest(requestCount, address(0));
        }

        uint256 watcherFees = watcherPrecompileLimits().getTotalFeesRequired(
            params.queryCount,
            params.finalizeCount,
            0,
            0
        );
        if (watcherFees > params.maxFees) revert InsufficientFees();
        uint256 maxTransmitterFees = params.maxFees - watcherFees;

        emit PayloadSubmitted(
            requestCount,
            params.appGateway,
            payloadSubmitParamsArray,
            maxTransmitterFees,
            params.auctionManager,
            params.onlyReadRequests
        );
    }

    function _getAuctionManager(address auctionManager_) internal view returns (address) {
        return
            auctionManager_ == address(0)
                ? IAddressResolver(addressResolver__).defaultAuctionManager()
                : auctionManager_;
    }

    function _checkBatch(
        address consumeFrom_,
        address appGateway_,
        uint256 maxFees_
    ) internal view {
        if (queuePayloadParams.length > REQUEST_PAYLOAD_COUNT_LIMIT)
            revert RequestPayloadCountLimitExceeded();

        if (
            !IFeesManager(addressResolver__.feesManager()).isUserCreditsEnough(
                consumeFrom_,
                appGateway_,
                maxFees_
            )
        ) revert InsufficientFees();
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function _createPayloadSubmitParamsArray()
        internal
        returns (
            PayloadSubmitParams[] memory payloadDetailsArray,
            bool onlyReadRequests,
            uint256 queryCount,
            uint256 finalizeCount
        )
    {
        payloadDetailsArray = new PayloadSubmitParams[](queuePayloadParams.length);
        onlyReadRequests = queuePayloadParams[0].callType == CallType.READ;

        uint256 currentLevel = 0;
        for (uint256 i = 0; i < queuePayloadParams.length; i++) {
            if (queuePayloadParams[i].callType == CallType.READ) {
                queryCount++;
            } else {
                onlyReadRequests = false;
                finalizeCount++;
            }

            // Update level for calls
            if (i > 0 && queuePayloadParams[i].isParallel != Parallel.ON) {
                currentLevel = currentLevel + 1;
            }

            payloadDetailsArray[i] = _createPayloadDetails(currentLevel, queuePayloadParams[i]);
        }

        clearQueue();
    }

    function _createDeployPayloadDetails(
        QueuePayloadParams memory queuePayloadParams_
    ) internal returns (bytes memory payload, address target) {
        bytes32 salt = keccak256(
            abi.encode(queuePayloadParams_.appGateway, queuePayloadParams_.chainSlug, saltCounter++)
        );

        // app gateway is set in the plug deployed on chain
        payload = abi.encodeWithSelector(
            IContractFactoryPlug.deployContract.selector,
            queuePayloadParams_.isPlug,
            salt,
            bytes32(uint256(uint160(queuePayloadParams_.appGateway))),
            queuePayloadParams_.switchboard,
            queuePayloadParams_.payload,
            queuePayloadParams_.initCallData
        );

        // getting app gateway for deployer as the plug is connected to the app gateway
        target = getDeliveryHelperPlugAddress(queuePayloadParams_.chainSlug);
    }

    /// @notice Creates the payload details for a given call parameters
    /// @param queuePayloadParams_ The call parameters
    /// @return payloadDetails The payload details
    function _createPayloadDetails(
        uint256 level_,
        QueuePayloadParams memory queuePayloadParams_
    ) internal returns (PayloadSubmitParams memory) {
        bytes memory payload = queuePayloadParams_.payload;
        address target = queuePayloadParams_.target;
        if (queuePayloadParams_.callType == CallType.DEPLOY) {
            (payload, target) = _createDeployPayloadDetails(queuePayloadParams_);
        }

        if (queuePayloadParams_.value > chainMaxMsgValueLimit[queuePayloadParams_.chainSlug])
            revert MaxMsgValueLimitExceeded();

        return
            PayloadSubmitParams({
                levelNumber: level_,
                chainSlug: queuePayloadParams_.chainSlug,
                callType: queuePayloadParams_.callType,
                isParallel: queuePayloadParams_.isParallel,
                writeFinality: queuePayloadParams_.writeFinality,
                asyncPromise: queuePayloadParams_.asyncPromise,
                switchboard: queuePayloadParams_.switchboard,
                target: target,
                appGateway: queuePayloadParams_.appGateway,
                gasLimit: queuePayloadParams_.gasLimit == 0
                    ? 10_000_000
                    : queuePayloadParams_.gasLimit,
                value: queuePayloadParams_.value,
                readAt: queuePayloadParams_.readAt,
                payload: payload
            });
    }
}
