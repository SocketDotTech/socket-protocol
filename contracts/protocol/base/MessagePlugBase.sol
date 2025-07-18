// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {PlugBase} from "./PlugBase.sol";
import {ISwitchboard} from "../interfaces/ISwitchboard.sol";
import {APP_GATEWAY_ID} from "../../utils/common/Constants.sol";

interface IMessageSwitchboard is ISwitchboard {
    function registerSibling(uint32 chainSlug_, bytes32 siblingPlug_) external;
}

/// @title MessagePlugBase
/// @notice Abstract contract for message plugs in the updated protocol
/// @dev This contract contains helpers for socket connection, disconnection, and overrides
/// Uses constant appGatewayId (0xaaaaa) for all chains
abstract contract MessagePlugBase is PlugBase {
    address public switchboard;
    error NotSupported();

    constructor(address socket_, address switchboard_) {
        _setSocket(socket_);
        switchboard = switchboard_;
        socket__.connect(APP_GATEWAY_ID, switchboard);
    }

    /// @notice Initializes the socket with the new protocol
    function initSocket(bytes32, address, address) external override socketInitializer {
        revert("Not Supported");
    }

    /// @notice Registers a sibling plug for a specific chain
    /// @param chainSlug_ Chain slug of the sibling chain
    /// @param siblingPlug_ Address of the sibling plug on the destination chain
    function registerSibling(uint32 chainSlug_, bytes32 siblingPlug_) public {
        // Call the switchboard to register the sibling
        IMessageSwitchboard(switchboard).registerSibling(chainSlug_, siblingPlug_);
    }
}
