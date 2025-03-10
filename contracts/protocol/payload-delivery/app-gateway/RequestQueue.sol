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
        delete callParamsArray;
    }

    /// @notice Queues a new payload
    /// @param callParams_ The call parameters
    function queue(CallParams memory callParams_) external {
        callParamsArray.push(callParams_);
    }

    /// @notice Initiates a batch of payloads
    /// @param fees_ The fees data
    /// @param auctionManager_ The auction manager address
    /// @return asyncId The ID of the batch
    function batch(
        Fees memory fees_,
        address auctionManager_,
        bytes memory onCompleteData_
    ) external returns (bytes32) {
        if (callParamsArray.length == 0) return bytes32(0);

        address appGateway = _getCoreAppGateway(msg.sender);
        if (!IFeesManager(addressResolver__.feesManager()).isFeesEnough(appGateway, fees_))
            revert InsufficientFees();

        (
            PayloadDetails[] memory payloadDetailsArray,
            uint256 levels,
            bool isFirstRequestRead
        ) = _createPayloadDetailsArray(appGateway);

        if (auctionManager_ == address(0))
            auctionManager_ = IAddressResolver(addressResolver__).defaultAuctionManager();

        PayloadRequest memory payloadRequest = PayloadRequest({
            appGateway: appGateway,
            fees: fees_,
            auctionManager: auctionManager_,
            winningBid: Bid({fee: 0, transmitter: address(0), extraData: new bytes(0)}),
            // w:
            isRequestCancelled: false,
            lastRequestExecuting: 0,
            onCompleteData: onCompleteData_,
            payloadDetailsArray: payloadDetailsArray
        });

        (bytes32 asyncId, bytes32[] memory payloadIds) = watcherPrecompile__().createRequest(
            payloadDetailsArray
        );

        // send query directly if first batch is all reads
        if (isFirstRequestRead) watcherPrecompile__().execute(asyncId);
        emit PayloadSubmitted(asyncId, appGateway, payloadDetailsArray, fees_, auctionManager_);
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function _createPayloadDetailsArray(
        address appGateway_
    )
        internal
        returns (
            PayloadDetails[] memory payloadDetailsArray,
            uint256 levels,
            bool isFirstRequestRead
        )
    {
        if (callParamsArray.length == 0) return (payloadDetailsArray, isFirstRequestRead);
        payloadDetailsArray = new PayloadDetails[](callParamsArray.length);

        uint256 reads = 0;
        uint256 writes = 0;
        levels = 0;
        isFirstRequestRead = callParamsArray[0].callType == CallType.READ;

        for (uint256 i = 0; i < callParamsArray.length; i++) {
            // Check if first batch is all reads
            if (
                i == 0 &&
                callParamsArray[i].isParallel == Parallel.ON &&
                callParamsArray[i].callType != CallType.READ
            ) {
                isFirstRequestRead = false;
            }

            // Track read/write counts
            if (callParamsArray[i].callType == CallType.READ) reads++;
            else writes++;

            // Update level for sequential calls
            if (i > 0 && callParamsArray[i].isParallel != Parallel.ON) {
                levels = levels + 1;
            }

            payloadDetailsArray[i] = _createPayloadDetails(currentLevel, callParamsArray[i]);

            // verify app gateway
            if (getCoreAppGateway(callParamsArray[i].appGateway) != appGateway_)
                revert("Invalid app gateway");
        }

        // todo: check limits on read and write
        watcherPrecompile__().checkAndConsumeLimit(appGateway_, QUERY, reads);
        watcherPrecompile__().checkAndConsumeLimit(appGateway_, FINALIZE, writes);

        clearQueue();
    }

    /// @notice Gets the payload details for a given call parameters
    /// @param params_ The call parameters
    /// @return payloadDetails The payload details
    function _createPayloadDetails(
        uint256 level_,
        CallParams memory params_
    ) internal returns (PayloadDetails memory) {
        bytes memory payload_ = params_.payload;
        address target = params_.target;
        if (params_.callType == CallType.DEPLOY) {
            // getting app gateway for deployer as the plug is connected to the app gateway
            bytes32 salt_ = keccak256(
                abi.encode(params_.appGateway, params_.chainSlug, saltCounter++)
            );

            // app gateway is set in the plug deployed on chain
            payload_ = abi.encodeWithSelector(
                IContractFactoryPlug.deployContract.selector,
                params_.isPlug,
                salt_,
                params_.appGateway,
                payload_,
                params_.initCallData
            );

            if (payload_.length > 24.5 * 1024) revert PayloadTooLarge();
            target = getDeliveryHelperPlugAddress(params_.chainSlug);
        }

        return
            PayloadDetails({
                levelNumber: level_,
                chainSlug: params_.chainSlug,
                isParallel: params_.isParallel,
                callType: params_.callType,
                writeFinality: params_.writeFinality,
                appGateway: params_.appGateway,
                target: target,
                asyncPromise: params_.asyncPromise,
                switchboard: params_.switchboard,
                value: params_.value,
                executionGasLimit: params_.gasLimit == 0 ? 1_000_000 : params_.gasLimit,
                readAt: params_.readAt,
                payload: payload_
            });
    }
}
