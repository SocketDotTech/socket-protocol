// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../base/PlugBase.sol";
import {Ownable} from "../../utils/Ownable.sol";
import {NotSocket} from "../../common/Errors.sol";

/// @title ContractFactory
/// @notice Abstract contract for deploying contracts
contract ContractFactoryPlug is PlugBase, Ownable {
    event Deployed(address addr, bytes32 salt);

    /// @notice Error thrown if it failed to deploy the create2 contract
    error DeploymentFailed();

    constructor(address socket_, address owner_) PlugBase(socket_) {
        _claimOwner(owner_);
    }

    function deployContract(
        bytes memory creationCode,
        bytes32 salt,
        address appGateway_,
        address switchboard_
    ) public returns (address) {
        if (msg.sender != address(socket__)) {
            revert NotSocket();
        }

        address addr;
        assembly {
            addr := create2(callvalue(), add(creationCode, 0x20), mload(creationCode), salt)
            if iszero(addr) {
                mstore(0, 0x30116425) // Error selector for DeploymentFailed
                revert(0x1C, 0x04) // reverting with just 4 bytes
            }
        }

        IPlug(addr).connectSocket(appGateway_, msg.sender, switchboard_);
        emit Deployed(addr, salt);
        return addr;
    }

    /// @notice Gets the address for a deployed contract
    /// @param creationCode The creation code
    /// @param salt The salt
    /// @return address The deployed address
    function getAddress(bytes memory creationCode, uint256 salt) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(creationCode))
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
}
