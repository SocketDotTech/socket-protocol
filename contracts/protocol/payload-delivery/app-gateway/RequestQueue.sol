// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./DeliveryUtils.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract RequestQueue is DeliveryUtils {
    // slots [207-257] reserved for gap
    uint256[50] _gap_queue_async;

    /// @notice Clears the call parameters array
    function clearQueue() public {
        delete queuePayloadParams;
    }

    /// @notice Queues a new payload
    /// @param queuePayloadParams_ The call parameters
    function queue(QueuePayloadParams memory queuePayloadParams_) external {
        queuePayloadParams.push(queuePayloadParams_);
    }

    /// @notice Initiates a batch of payloads
    /// @param fees_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return requestCount The ID of the batch
    function batch(
        Fees memory fees_,
        address auctionManager_,
        address consumeFrom_,
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount) {
        address appGateway = _getCoreAppGateway(msg.sender);
        return _batch(appGateway, auctionManager_, consumeFrom_, fees_, onCompleteData_);
    }

    function _checkBatch(
        address appGateway_,
        address consumeFrom_,
        Fees memory fees_,
        uint readCount,
        uint writeCount
    ) internal view {
        if (queuePayloadParams.length > REQUEST_PAYLOAD_COUNT_LIMIT)
            revert RequestPayloadCountLimitExceeded();

        uint256 totalWatcherPrecompileFeesRequired = watcherPrecompileLimits__.getTotalFeesRequired(
            fees_.feePoolToken,
            readCount,
            writeCount,
            0
        );
        fees_.amount += totalWatcherPrecompileFeesRequired;
        if (
            !IFeesManager(addressResolver__.feesManager()).isFeesEnough(
                appGateway_,
                consumeFrom_,
                fees_
            )
        ) revert InsufficientFees();
    }

    function _getAuctionManager(address auctionManager_) internal view returns (address) {
        return
            auctionManager_ == address(0)
                ? IAddressResolver(addressResolver__).defaultAuctionManager()
                : auctionManager_;
    }

    /// @notice Initiates a batch of payloads
    /// @dev it checks fees, payload limits and creates the payload submit params array after assigning proper levels
    /// @dev It also modifies the deploy payloads as needed by contract factory plug
    /// @dev Stores request metadata and submits the request to watcher precompile
    function _batch(
        address appGateway_,
        address auctionManager_,
        address consumeFrom_,
        Fees memory fees_,
        bytes memory onCompleteData_
    ) internal returns (uint40 requestCount) {
        if (queuePayloadParams.length == 0) return 0;
        address auctionManager = _getAuctionManager(auctionManager_);

        // create the payload submit params array in desired format
        (
            PayloadSubmitParams[] memory payloadSubmitParamsArray,
            uint readCount,
            uint writeCount,
            bool onlyReadRequests
        ) = _createPayloadSubmitParamsArray();

        _checkBatch(appGateway_, consumeFrom_, fees_, readCount, writeCount);
        RequestMetadata memory requestMetadata = RequestMetadata({
            appGateway: appGateway_,
            auctionManager: auctionManager,
            consumeFrom: consumeFrom_,
            fees: fees_,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            onCompleteData: onCompleteData_,
            onlyReadRequests: onlyReadRequests
        });

        // process and submit the queue of payloads to watcher precompile
        requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
        requests[requestCount] = requestMetadata;

        // send query directly if request contains only reads
        // transmitter should ignore the batch for auction, the transaction will also revert if someone bids
        if (onlyReadRequests)
            watcherPrecompile__().startProcessingRequest(requestCount, address(0));

        emit PayloadSubmitted(
            requestCount,
            appGateway_,
            payloadSubmitParamsArray,
            fees_,
            auctionManager_,
            consumeFrom_,
            onlyReadRequests
        );
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function _createPayloadSubmitParamsArray()
        internal
        returns (
            PayloadSubmitParams[] memory payloadDetailsArray,
            uint readCount,
            uint writeCount,
            bool onlyReadRequests
        )
    {
        payloadDetailsArray = new PayloadSubmitParams[](queuePayloadParams.length);
        onlyReadRequests = queuePayloadParams[0].callType == CallType.READ;

        uint256 currentLevel = 0;
        for (uint256 i = 0; i < queuePayloadParams.length; i++) {
            if (queuePayloadParams[i].callType != CallType.READ) {
                onlyReadRequests = false;
                writeCount++;
            } else readCount++;

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
            queuePayloadParams_.appGateway,
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

        if (payload.length > PAYLOAD_SIZE_LIMIT) revert PayloadTooLarge();
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
