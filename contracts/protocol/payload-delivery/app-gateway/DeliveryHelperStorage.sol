// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {IPromise} from "../../../interfaces/IPromise.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IContractFactoryPlug} from "../../../interfaces/IContractFactoryPlug.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IAuctionManager} from "../../../interfaces/IAuctionManager.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";

import {CallParams, Fees, PayloadDetails, CallType, Bid, PayloadBatch, Parallel, IsPlug, FinalizeParams} from "../../utils/common/Structs.sol";
import {NotAuctionManager, InvalidPromise, InvalidIndex, PromisesNotResolved, InvalidTransmitter} from "../../utils/common/Errors.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW, QUERY, FINALIZE} from "../../utils/common/Constants.sol";

/// @title DeliveryHelperStorage
/// @notice Storage contract for DeliveryHelper
abstract contract DeliveryHelperStorage is IDeliveryHelper {
    uint256 public saltCounter;
    uint256 public asyncCounter;
    uint256 public bidTimeout;

    /// @notice The call parameters array
    CallParams[] public callParamsArray;

    bytes32[] public tempPayloadIds;

    /// @notice The mapping of valid promises
    mapping(address => bool) public isValidPromise;
    // payloadId => asyncId
    mapping(bytes32 => bytes32) public payloadIdToBatchHash;
    mapping(bytes32 => PayloadDetails) public payloadIdToPayloadDetails;
    // asyncId => PayloadDetails[]
    mapping(bytes32 => PayloadDetails[]) public payloadBatchDetails;
    // asyncId => PayloadBatch
    mapping(bytes32 => PayloadBatch) internal _payloadBatches;
}
