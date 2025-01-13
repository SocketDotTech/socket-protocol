// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {CallParams, FeesData, PayloadDetails, CallType, Bid, PayloadBatch} from "../../../common/Structs.sol";
import {NotAuctionManager} from "../../../common/Errors.sol";
import {AsyncPromise} from "../../../AsyncPromise.sol";
import {IPromise} from "../../../interfaces/IPromise.sol";
import {IAppDeployer} from "../../../interfaces/IAppDeployer.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IContractFactoryPlug} from "../../../interfaces/IContractFactoryPlug.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract QueueAsync is AddressResolverUtil, IDeliveryHelper {
    uint256 public saltCounter;
    uint256 public asyncCounter;
    address public feesManager;

    CallParams[] public callParamsArray;
    mapping(address => bool) public isValidPromise;

    // payloadId => asyncId
    mapping(bytes32 => bytes32) public payloadIdToBatchHash;
    mapping(bytes32 => PayloadDetails) public payloadIdToPayloadDetails;

    // asyncId => PayloadBatch
    mapping(bytes32 => PayloadBatch) public payloadBatches;
    // asyncId => PayloadDetails[]
    mapping(bytes32 => PayloadDetails[]) public payloadBatchDetails;
    error InvalidPromise();

    modifier onlyPromises() {
        if (!isValidPromise[msg.sender]) revert InvalidPromise();
        // remove promise once resolved
        isValidPromise[msg.sender] = false;
        _;
    }

    modifier onlyAuctionManager(bytes32 asyncId_) {
        if (msg.sender != payloadBatches[asyncId_].auctionManager) revert NotAuctionManager();
        _;
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
        bool isSequential_,
        uint32 chainSlug_,
        address target_,
        address asyncPromise_,
        CallType callType_,
        bytes memory payload_
    ) external {
        // todo: sb related details
        callParamsArray.push(
            CallParams({
                callType: callType_,
                asyncPromise: asyncPromise_,
                chainSlug: chainSlug_,
                target: target_,
                payload: payload_,
                gasLimit: 10000000,
                isSequential: isSequential_
            })
        );
    }

    /// @notice Creates an array of payload details
    /// @return payloadDetailsArray An array of payload details
    function createPayloadDetailsArray(
        bytes32 sbType_
    ) internal returns (PayloadDetails[] memory payloadDetailsArray) {
        payloadDetailsArray = new PayloadDetails[](callParamsArray.length);
        for (uint256 i = 0; i < callParamsArray.length; i++) {
            CallParams memory params = callParamsArray[i];

            // getting switchboard address for sbType given. It is updated by watcherPrecompile by watcher
            address switchboard = watcherPrecompile().switchboards(params.chainSlug, sbType_);

            PayloadDetails memory payloadDetails = getPayloadDetails(params, switchboard);
            payloadDetailsArray[i] = payloadDetails;
        }

        clearQueue();
    }

    /// @notice Gets the payload details for a given call parameters
    /// @param params The call parameters
    /// @param switchboard_ The switchboard address
    /// @return payloadDetails The payload details
    function getPayloadDetails(
        CallParams memory params,
        address switchboard_
    ) internal returns (PayloadDetails memory) {
        address[] memory next = new address[](2);
        next[0] = params.asyncPromise;

        bytes memory payload = params.payload;
        address appGateway = msg.sender;
        if (params.callType == CallType.DEPLOY) {
            // getting app gateway for deployer as the plug is connected to the app gateway
            address appGatewayForPlug = _getCoreAppGateway(appGateway);
            bytes32 salt = keccak256(abi.encode(appGatewayForPlug, params.chainSlug, saltCounter++));

            // app gateway is set in the plug deployed on chain
            payload = abi.encodeWithSelector(
                IContractFactoryPlug.deployContract.selector,
                payload,
                salt,
                appGatewayForPlug,
                switchboard_
            );

            // for deploy, we set delivery helper as app gateway of contract factory plug
            appGateway = address(this);
        }

        return
            PayloadDetails({
                appGateway: appGateway,
                chainSlug: params.chainSlug,
                target: params.target,
                payload: payload,
                callType: params.callType,
                executionGasLimit: params.gasLimit == 0 ? 1_000_000 : params.gasLimit,
                next: next,
                isSequential: params.isSequential
            });
    }

    function getFeesData(bytes32 asyncId_) external view returns (FeesData memory) {
        return payloadBatches[asyncId_].feesData;
    }

    function getPayloadDetails(bytes32 payloadId_) external view returns (PayloadDetails memory) {
        return payloadIdToPayloadDetails[payloadId_];
    }
}
