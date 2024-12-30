// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {CallParams, FeesData, PayloadDetails, CallType, Bid, PayloadBatch} from "../../../common/Structs.sol";
import {NotAuctionManager} from "../../../common/Errors.sol";
import {AsyncPromise} from "../../../AsyncPromise.sol";
import {IPromise} from "../../../interfaces/IPromise.sol";
import {IAppDeployer} from "../../../interfaces/IAppDeployer.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract QueueAsync is AddressResolverUtil {
    uint256 public saltCounter;
    uint256 public asyncCounter;

    address public auctionManager;
    address public feesManager;

    CallParams[] public callParamsArray;
    mapping(address => bool) public isValidPromise;

    // payloadId => asyncId
    mapping(bytes32 => bytes32) public payloadIdToBatchHash;
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

    modifier onlyAuctionManager() {
        if (msg.sender != auctionManager) revert NotAuctionManager();
        _;
    }

    constructor(
        address _addressResolver,
        address _auctionManager,
        address _feesManager
    ) AddressResolverUtil(_addressResolver) {
        auctionManager = _auctionManager;
        feesManager = _feesManager;
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
    function createPayloadDetailsArray()
        internal
        returns (PayloadDetails[] memory payloadDetailsArray)
    {
        payloadDetailsArray = new PayloadDetails[](callParamsArray.length);

        for (uint256 i = 0; i < callParamsArray.length; i++) {
            CallParams memory params = callParamsArray[i];
            PayloadDetails memory payloadDetails = getPayloadDetails(params);
            payloadDetailsArray[i] = payloadDetails;
        }

        clearQueue();
    }

    /// @notice Gets the payload details for a given call parameters
    /// @param params The call parameters
    /// @return payloadDetails The payload details
    function getPayloadDetails(
        CallParams memory params
    ) internal returns (PayloadDetails memory) {
        address[] memory next = new address[](2);
        next[0] = params.asyncPromise;

        bytes memory payload = params.payload;
        if (params.callType == CallType.DEPLOY) {
            bytes32 salt = keccak256(
                abi.encode(msg.sender, params.chainSlug, saltCounter++)
            );

            payload = abi.encodeWithSelector(
                IContractFactoryPlug.deployContract.selector,
                params.payload,
                salt
            );
        }

        return
            PayloadDetails({
                chainSlug: params.chainSlug,
                target: params.target,
                payload: payload,
                callType: params.callType,
                executionGasLimit: params.gasLimit == 0
                    ? 1_000_000
                    : params.gasLimit,
                next: next,
                isSequential: params.isSequential
            });
    }
}
