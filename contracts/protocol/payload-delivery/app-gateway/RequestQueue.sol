// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../../utils/AddressResolverUtil.sol";
import "./DeliveryUtils.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract RequestQueue is DeliveryUtils {
    // slots [0-108] reserved for delivery helper storage and [109-159] reserved for addr resolver util
    // slots [160-209] reserved for gap
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
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount) {
        if (queuePayloadParams.length == 0) return 0;

        address appGateway = _getCoreAppGateway(msg.sender);
        if (!IFeesManager(addressResolver__.feesManager()).isFeesEnough(appGateway, fees_))
            revert InsufficientFees();

        (
            PayloadSubmitParams[] memory payloadSubmitParamsArray,
            ,
            bool onlyReadRequests
        ) = _createPayloadSubmitParamsArray();

        if (auctionManager_ == address(0))
            auctionManager_ = IAddressResolver(addressResolver__).defaultAuctionManager();

        RequestMetadata memory requestMetadata = RequestMetadata({
            appGateway: appGateway,
            auctionManager: auctionManager_,
            fees: fees_,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            onCompleteData: onCompleteData_,
            onlyReadRequests: onlyReadRequests
        });

        requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
        requests[requestCount] = requestMetadata;

        // send query directly if request contains only reads
        // transmitter should ignore the batch for auction, the transaction will also revert if someone bids
        if (onlyReadRequests)
            watcherPrecompile__().startProcessingRequest(requestCount, address(0));

        emit PayloadSubmitted(
            requestCount,
            appGateway,
            payloadSubmitParamsArray,
            fees_,
            auctionManager_,
            onlyReadRequests
        );
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function _createPayloadSubmitParamsArray()
        internal
        returns (
            PayloadSubmitParams[] memory payloadDetailsArray,
            uint256 totalLevels,
            bool onlyReadRequests
        )
    {
        if (queuePayloadParams.length == 0)
            return (payloadDetailsArray, totalLevels, onlyReadRequests);
        payloadDetailsArray = new PayloadSubmitParams[](queuePayloadParams.length);

        totalLevels = 0;
        onlyReadRequests = queuePayloadParams[0].callType == CallType.READ;
        for (uint256 i = 0; i < queuePayloadParams.length; i++) {
            if (queuePayloadParams[i].callType != CallType.READ) {
                onlyReadRequests = false;
            }

            // Update level for sequential calls
            if (i > 0 && queuePayloadParams[i].isParallel != Parallel.ON) {
                totalLevels = totalLevels + 1;
            }

            payloadDetailsArray[i] = _createPayloadDetails(totalLevels, queuePayloadParams[i]);
        }

        clearQueue();
    }

    /// @notice Creates the payload details for a given call parameters
    /// @param queuePayloadParams_ The call parameters
    /// @return payloadDetails The payload details
    function _createPayloadDetails(
        uint256 level_,
        QueuePayloadParams memory queuePayloadParams_
    ) internal returns (PayloadSubmitParams memory) {
        bytes memory payload_ = queuePayloadParams_.payload;
        address target = queuePayloadParams_.target;
        if (queuePayloadParams_.callType == CallType.DEPLOY) {
            // getting app gateway for deployer as the plug is connected to the app gateway
            bytes32 salt_ = keccak256(
                abi.encode(
                    queuePayloadParams_.appGateway,
                    queuePayloadParams_.chainSlug,
                    saltCounter++
                )
            );

            // app gateway is set in the plug deployed on chain
            payload_ = abi.encodeWithSelector(
                IContractFactoryPlug.deployContract.selector,
                queuePayloadParams_.isPlug,
                salt_,
                queuePayloadParams_.appGateway,
                queuePayloadParams_.switchboard,
                payload_,
                queuePayloadParams_.initCallData
            );

            if (payload_.length > 24.5 * 1024) revert PayloadTooLarge();
            target = getDeliveryHelperPlugAddress(queuePayloadParams_.chainSlug);
        }

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
                payload: payload_
            });
    }
}
