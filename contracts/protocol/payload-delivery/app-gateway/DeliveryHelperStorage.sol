// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {IMiddleware} from "../../../interfaces/IMiddleware.sol";
import {IPromise} from "../../../interfaces/IPromise.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IContractFactoryPlug} from "../../../interfaces/IContractFactoryPlug.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IAuctionManager} from "../../../interfaces/IAuctionManager.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";

import {QueuePayloadParams, Fees, CallType, Bid, Parallel, IsPlug, WriteFinality, RequestMetadata} from "../../utils/common/Structs.sol";
import {NotAuctionManager, InvalidPromise, InvalidIndex, PromisesNotResolved, InvalidTransmitter} from "../../utils/common/Errors.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW, QUERY, FINALIZE} from "../../utils/common/Constants.sol";

/// @title DeliveryHelperStorage
/// @notice Storage contract for DeliveryHelper
abstract contract DeliveryHelperStorage is IMiddleware {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    uint128 public bidTimeout;
    uint256 public saltCounter;

    /// @notice The call parameters array
    QueuePayloadParams[] public queuePayloadParams;

    mapping(uint40 => RequestMetadata) public requests;

    // slots [59-108] reserved for gap
    uint256[50] _gap_after;
}
