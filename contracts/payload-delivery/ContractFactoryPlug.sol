// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../base/PlugBase.sol";
import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import "../libraries/RescueFundsLib.sol";
import {NotSocket} from "../common/Errors.sol";

/// @title ContractFactory
/// @notice Abstract contract for deploying contracts
contract ContractFactoryPlug is PlugBase, AccessControl {
    event Deployed(address addr, bytes32 salt);

    /// @notice Error thrown if it failed to deploy the create2 contract
    error DeploymentFailed();

    constructor(address socket_, address owner_) PlugBase(socket_) {
        _initializeOwner(owner_);
    }

    function deployContract(
        bytes memory creationCode_,
        bytes32 salt_,
        address appGateway_,
        address switchboard_
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

        IPlug(addr).initSocket(appGateway_, msg.sender, switchboard_);
        emit Deployed(addr, salt_);
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

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, socket_, switchboard_);
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
