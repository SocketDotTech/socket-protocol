// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ISocket} from "../interfaces/ISocket.sol";
import {IPlug} from "../interfaces/IPlug.sol";
import {NotSocket} from "../../utils/common/Errors.sol";

/// @title PlugBase
/// @notice Abstract contract for plugs
/// @dev This contract contains helpers for socket connection, disconnection, and overrides
abstract contract PlugBase is IPlug {
    ISocket public socket__;
    bytes32 public appGatewayId;
    uint256 public isSocketInitialized;
    bytes public overrides;

    error SocketAlreadyInitialized();
    event ConnectorPlugDisconnected();

    /// @notice Modifier to ensure only the socket can call the function
    /// @dev only the socket can call the function
    modifier onlySocket() {
        if (msg.sender != address(socket__)) revert NotSocket();
        _;
    }

    /// @notice Modifier to ensure the socket is initialized and if not already initialized, it will be initialized
    modifier socketInitializer() {
        if (isSocketInitialized == 1) revert SocketAlreadyInitialized();
        isSocketInitialized = 1;
        _;
    }

    /// @notice Connects the plug to the app gateway and switchboard
    /// @param appGatewayId_ The app gateway id
    /// @param socket_ The socket address
    /// @param switchboard_ The switchboard address
    function _connectSocket(bytes32 appGatewayId_, address socket_, address switchboard_) internal {
        _setSocket(socket_);
        appGatewayId = appGatewayId_;

        socket__.connect(appGatewayId_, switchboard_);
    }

    /// @notice Disconnects the plug from the socket
    function _disconnectSocket() internal {
        (, address switchboard) = socket__.getPlugConfig(address(this));
        socket__.connect(bytes32(0), switchboard);
        emit ConnectorPlugDisconnected();
    }

    /// @notice Sets the socket
    /// @param socket_ The socket address
    function _setSocket(address socket_) internal {
        socket__ = ISocket(socket_);
    }

    /// @notice Sets the overrides needed for the trigger
    /// @param overrides_ The overrides
    function _setOverrides(bytes memory overrides_) internal {
        overrides = overrides_;
    }

    function initSocket(
        bytes32 appGatewayId_,
        address socket_,
        address switchboard_
    ) external virtual socketInitializer {
        _connectSocket(appGatewayId_, socket_, switchboard_);
    }
}
