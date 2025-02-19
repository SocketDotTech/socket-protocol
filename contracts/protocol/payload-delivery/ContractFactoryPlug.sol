// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/common/AccessRoles.sol";
import "../utils/RescueFundsLib.sol";
import {NotSocket} from "../utils/common/Errors.sol";
import "../../base/PlugBase.sol";

/// @title ContractFactory
/// @notice Abstract contract for deploying contracts
contract ContractFactoryPlug is PlugBase, AccessControl {
    event Deployed(address addr, bytes32 salt, bytes returnData);

    /// @notice Error thrown if it failed to deploy the create2 contract
    error DeploymentFailed();
    error ExecutionFailed();

    constructor(address socket_, address owner_) {
        _initializeOwner(owner_);
        _setSocket(socket_);
    }

    function deployContract(
        bool canConnectSocket_,
        bytes32 salt_,
        address appGateway_,
        address switchboard_,
        bytes memory creationCode_,
        bytes memory initCallData_
    ) public returns (address) {
        if (msg.sender != address(socket__)) {
            revert NotSocket();
        }

        address addr;
        assembly {
            addr := create2(callvalue(), add(creationCode_, 0x20), mload(creationCode_), salt_)
            if iszero(addr) {
                mstore(0, 0x30116425) // Error selector for DeploymentFailed
                revert(0x1C, 0x04) // reverting with just 4 bytes
            }
        }

        if (canConnectSocket_) IPlug(addr).initSocket(appGateway_, msg.sender, switchboard_);

        bytes memory returnData;
        if (initCallData_.length > 0) {
            (bool success, bytes memory returnData_) = addr.call(initCallData_);
            if (!success) {
                revert ExecutionFailed();
            }
            returnData = returnData_;
        }

        emit Deployed(addr, salt_, returnData);
        return addr;
    }

    /// @notice Gets the address for a deployed contract
    /// @param creationCode_ The creation code
    /// @param salt_ The salt
    /// @return address The deployed address
    function getAddress(bytes memory creationCode_, uint256 salt_) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt_, keccak256(creationCode_))
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
