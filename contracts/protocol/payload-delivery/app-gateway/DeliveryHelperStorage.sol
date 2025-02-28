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
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    uint256 public saltCounter;

    // slot 51
    uint128 public asyncCounter;
    uint128 public bidTimeout;

    // slot 52
    bytes32[] public tempPayloadIds;

    // slot 53
    /// @notice The call parameters array
    CallParams[] public callParamsArray;

    // slot 54
    /// @notice The mapping of valid promises
    mapping(address => bool) public isValidPromise;

    // slot 55 - payloadIdToBatchHash
    mapping(bytes32 => bytes32) public payloadIdToBatchHash;
    // slot 56 - payloadIdToPayloadDetails
    mapping(bytes32 => PayloadDetails) public payloadIdToPayloadDetails;

    // slot 57
    // asyncId => PayloadDetails[]
    mapping(bytes32 => PayloadDetails[]) public payloadBatchDetails;

    // slot 58
    // asyncId => PayloadBatch
    mapping(bytes32 => PayloadBatch) internal _payloadBatches;

    // slots [59-108] reserved for gap
    uint256[50] _gap_after;
}
