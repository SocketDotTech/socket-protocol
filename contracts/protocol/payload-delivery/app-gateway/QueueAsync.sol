// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";

import {AddressResolverUtil} from "../../utils/AddressResolverUtil.sol";

import "./DeliveryHelperStorage.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract QueueAsync is DeliveryHelperStorage, Initializable, Ownable, AddressResolverUtil {
    // slots [0-108] reserved for delivery helper storage and [109-159] reserved for addr resolver util
    // slots [160-209] reserved for gap
    uint256[50] _gap_queue_async;

    event PayloadBatchCancelled(bytes32 asyncId);
    event BidTimeoutUpdated(uint256 newBidTimeout);

    modifier onlyPromises() {
        if (!isValidPromise[msg.sender]) revert InvalidPromise();
        _;
    }

    modifier onlyAuctionManager(bytes32 asyncId_) {
        if (msg.sender != _payloadBatches[asyncId_].auctionManager) revert NotAuctionManager();
        _;
    }

    function payloadBatches(bytes32 asyncId_) external view override returns (PayloadBatch memory) {
        return _payloadBatches[asyncId_];
    }

    function getPayloadDetails(bytes32 payloadId_) external view returns (PayloadDetails memory) {
        return payloadIdToPayloadDetails[payloadId_];
    }

    /// @notice Clears the call parameters array
    function clearQueue() public {
        delete callParamsArray;
    }

    /// @notice Queues a new payload
    /// @param chainSlug_ The chain identifier
    /// @param target_ The target address
    /// @param asyncPromise_ The async promise or ID
    /// @param callType_ The call type
    /// @param payload_ The payload
    function queue(
        IsPlug isPlug_,
        Parallel isParallel_,
        uint32 chainSlug_,
        address target_,
        address asyncPromise_,
        uint256 value_,
        CallType callType_,
        bytes memory payload_,
        bytes memory initCallData_
    ) external {
        // todo: sb related details
        callParamsArray.push(
            CallParams({
                isPlug: isPlug_,
                callType: callType_,
                asyncPromise: asyncPromise_,
                chainSlug: chainSlug_,
                target: target_,
                payload: payload_,
                value: value_,
                gasLimit: 10000000,
                isParallel: isParallel_,
                initCallData: initCallData_
            })
        );
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function _createPayloadDetailsArray(
        bytes32 sbType_
    ) internal returns (PayloadDetails[] memory payloadDetailsArray) {
        if (callParamsArray.length == 0) return payloadDetailsArray;

        payloadDetailsArray = new PayloadDetails[](callParamsArray.length);
        for (uint256 i = 0; i < callParamsArray.length; i++) {
            CallParams memory params = callParamsArray[i];

            // getting switchboard address for sbType given. It is updated by watcherPrecompile by watcher
            address switchboard = watcherPrecompile__().switchboards(params.chainSlug, sbType_);

            PayloadDetails memory payloadDetails = _createPayloadDetails(params, switchboard);
            payloadDetailsArray[i] = payloadDetails;
        }

        clearQueue();
    }

    /// @notice Gets the payload details for a given call parameters
    /// @param params_ The call parameters
    /// @param switchboard_ The switchboard address
    /// @return payloadDetails The payload details
    function _createPayloadDetails(
        CallParams memory params_,
        address switchboard_
    ) internal returns (PayloadDetails memory) {
        address[] memory next = new address[](2);
        next[0] = params_.asyncPromise;

        bytes memory payload_ = params_.payload;
        address appGateway_ = msg.sender;
        if (params_.callType == CallType.DEPLOY) {
            // getting app gateway for deployer as the plug is connected to the app gateway
            address appGatewayForPlug_ = _getCoreAppGateway(appGateway_);
            bytes32 salt_ = keccak256(
                abi.encode(appGatewayForPlug_, params_.chainSlug, saltCounter++)
            );

            // app gateway is set in the plug deployed on chain
            payload_ = abi.encodeWithSelector(
                IContractFactoryPlug.deployContract.selector,
                params_.isPlug,
                salt_,
                appGatewayForPlug_,
                switchboard_,
                payload_,
                params_.initCallData
            );

            // for deploy, we set delivery helper as app gateway of contract factory plug
            appGateway_ = address(this);
        }

        return
            PayloadDetails({
                appGateway: appGateway_,
                chainSlug: params_.chainSlug,
                target: params_.target,
                value: params_.value,
                payload: payload_,
                callType: params_.callType,
                executionGasLimit: params_.gasLimit == 0 ? 1_000_000 : params_.gasLimit,
                next: next,
                isParallel: params_.isParallel
            });
    }

    /// @notice Updates the bid timeout
    /// @param newBidTimeout_ The new bid timeout value
    function updateBidTimeout(uint128 newBidTimeout_) external onlyOwner {
        bidTimeout = newBidTimeout_;
        emit BidTimeoutUpdated(newBidTimeout_);
    }

    function getPayloadIndexDetails(
        bytes32 asyncId_,
        uint256 index_
    ) external view returns (PayloadDetails memory) {
        if (index_ >= payloadBatchDetails[asyncId_].length) revert InvalidIndex();
        return payloadBatchDetails[asyncId_][index_];
    }

    function getFees(bytes32 asyncId_) external view returns (Fees memory) {
        return _payloadBatches[asyncId_].fees;
    }

    function getAsyncBatchDetails(bytes32 asyncId_) external view returns (PayloadBatch memory) {
        return _payloadBatches[asyncId_];
    }
}
