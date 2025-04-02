// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ISocket} from "../interfaces/ISocket.sol";
import {IPlug} from "../interfaces/IPlug.sol";
import {NotSocket} from "../protocol/utils/common/Errors.sol";

/// @title PlugBase
/// @notice Abstract contract for plugs
abstract contract PlugBase is IPlug {
    ISocket public socket__;
    address public appGateway;
    uint256 public isSocketInitialized;

    error SocketAlreadyInitialized();
    event ConnectorPlugDisconnected();

    /// @notice Modifier to ensure only the socket can call the function
    /// @dev only the socket can call the function
    modifier onlySocket() {
        if (msg.sender != address(socket__)) revert NotSocket();
        _;
    }

    /// @notice Modifier to ensure the socket is initialized
    modifier socketInitializer() {
        if (isSocketInitialized == 1) revert SocketAlreadyInitialized();
        isSocketInitialized = 1;
        _;
    }

    /// @notice Connects the plug to the app gateway and switchboard
    /// @param appGateway_ The app gateway address
    /// @param switchboard_ The switchboard address
    function _connectSocket(address appGateway_, address socket_, address switchboard_) internal {
        _setSocket(socket_);
        appGateway = appGateway_;

        socket__.connect(appGateway_, switchboard_);
    }

    /// @notice Disconnects the plug from the socket
    function _disconnectSocket() internal {
        (, address switchboard) = socket__.getPlugConfig(address(this));
        socket__.connect(address(0), switchboard);
        emit ConnectorPlugDisconnected();
    }

    /// @notice Sets the socket
    /// @param socket_ The socket address
    function _setSocket(address socket_) internal {
        socket__ = ISocket(socket_);
    }

    function _callAppGateway(bytes memory payload_, bytes32 params_) internal returns (bytes32) {
        return socket__.callAppGateway(payload_, params_);
    }

    function initSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external virtual socketInitializer {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
