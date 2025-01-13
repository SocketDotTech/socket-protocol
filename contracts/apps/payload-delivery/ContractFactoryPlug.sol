// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "../../base/PlugBase.sol";
import {Ownable} from "../../utils/Ownable.sol";

/// @title ContractFactory
/// @notice Abstract contract for deploying contracts
contract ContractFactoryPlug is PlugBase, Ownable {
    event Deployed(address addr, bytes32 salt);

    constructor(address socket_, address owner_) Ownable(owner_) PlugBase(socket_) {}

    function deployContract(
        bytes memory creationCode,
        bytes32 salt,
        address appGateway_,
        address switchboard_
    ) public returns (address) {
        if (msg.sender != address(socket__)) {
            revert("Only socket can deploy contracts");
        }

        address addr;
        assembly {
            addr := create2(callvalue(), add(creationCode, 0x20), mload(creationCode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
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
