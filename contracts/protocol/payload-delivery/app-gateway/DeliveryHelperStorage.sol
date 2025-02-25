// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {CallParams, PayloadDetails, PayloadBatch} from "../../../protocol/utils/common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";

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
