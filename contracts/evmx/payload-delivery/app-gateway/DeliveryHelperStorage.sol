// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../../interfaces/IMiddleware.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {IContractFactoryPlug} from "../../../interfaces/IContractFactoryPlug.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {IAuctionManager} from "../../../interfaces/IAuctionManager.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";

import {NotAuctionManager, InvalidTransmitter, InvalidIndex} from "../../../utils/common/Errors.sol";
import {DEPLOY, PAYLOAD_SIZE_LIMIT, REQUEST_PAYLOAD_COUNT_LIMIT} from "../../../utils/common/Constants.sol";

/// @title DeliveryHelperStorage
/// @notice Storage contract for DeliveryHelper
abstract contract DeliveryHelperStorage is IMiddleware {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    /// @notice The timeout after which a bid expires
    uint128 public bidTimeout;

    // slot 51
    /// @notice The counter for the salt used to generate/deploy the contract address
    uint256 public saltCounter;

    // slot 52
    /// @notice The parameters array used to store payloads for a request
    QueuePayloadParams[] public queuePayloadParams;

    // slot 53
    /// @notice The metadata for a request
    mapping(uint40 => RequestMetadata) public requests;

    // slot 54
    /// @notice The maximum message value limit for a chain
    mapping(uint32 => uint256) public chainMaxMsgValueLimit;

    // slots [55-104] reserved for gap
    uint256[50] _gap_after;

    // slots 105-155 (51) reserved for addr resolver utils
}
