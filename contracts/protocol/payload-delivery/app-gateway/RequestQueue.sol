// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../../utils/AddressResolverUtil.sol";
import "./DeliveryHelperStorage.sol";

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
    /// @return requestId The ID of the batch
    function batch(
        Fees memory fees_,
        address auctionManager_,
        bytes memory onCompleteData_
    ) external returns (bytes32) {
        if (queuePayloadParams.length == 0) return bytes32(0);

        address appGateway = _getCoreAppGateway(msg.sender);
        if (!IFeesManager(addressResolver__.feesManager()).isFeesEnough(appGateway, fees_))
            revert InsufficientFees();

        (
            PayloadSubmitParams[] memory payloadSubmitParamsArray,
            bool onlyReadRequests
        ) = _createPayloadSubmitParamsArray();

        if (auctionManager_ == address(0))
            auctionManager_ = IAddressResolver(addressResolver__).defaultAuctionManager();

        RequestMetadata memory requestMetadata = RequestMetadata({
            appGateway: appGateway,
            auctionManager: auctionManager_,
            fees: fees_,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            onCompleteData: onCompleteData_
        });

        bytes32 requestId = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
        requests[requestId] = requestMetadata;

        // send query directly if req contains only reads
        if (onlyReadRequests) watcherPrecompile__().startProcessingRequest(requestId, address(0));

        emit PayloadSubmitted(
            requestId,
            appGateway,
            payloadSubmitParamsArray,
            fees_,
            auctionManager_
        );
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function _createPayloadDetailsArray()
        internal
        returns (PayloadDetails[] memory payloadDetailsArray, uint256 levels, bool onlyReadRequests)
    {
        if (queuePayloadParams.length == 0) return (payloadDetailsArray, onlyReadRequests);
        payloadDetailsArray = new PayloadDetails[](queuePayloadParams.length);

        levels = 0;
        onlyReadRequests = queuePayloadParams[0].callType == CallType.READ;

        for (uint256 i = 0; i < queuePayloadParams.length; i++) {
            // Check if first batch is all reads
            if (
                levels == 0 &&
                queuePayloadParams[i].isParallel == Parallel.ON &&
                queuePayloadParams[i].callType != CallType.READ
            ) {
                onlyReadRequests = false;
            }

            // Update level for sequential calls
            if (i > 0 && queuePayloadParams[i].isParallel != Parallel.ON) {
                levels = levels + 1;
            }

            payloadDetailsArray[i] = _createPayloadDetails(currentLevel, queuePayloadParams[i]);
        }

        if (levels > 1) onlyReadRequests = false;

        clearQueue();
    }

    /// @notice Gets the payload details for a given call parameters
    /// @param params_ The call parameters
    /// @return payloadDetails The payload details
    function _createPayloadDetails(
        uint256 level_,
        QueuePayloadParams memory queuePayloadParams_
    ) internal returns (PayloadDetails memory) {
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
                payload_,
                queuePayloadParams_.initCallData
            );

            if (payload_.length > 24.5 * 1024) revert PayloadTooLarge();
            target = getDeliveryHelperPlugAddress(queuePayloadParams_.chainSlug);
        }

        return
            PayloadDetails({
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
                    ? 1_000_000
                    : queuePayloadParams_.gasLimit,
                value: queuePayloadParams_.value,
                readAt: queuePayloadParams_.readAt,
                payload: payload_
            });
    }
}
