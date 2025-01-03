// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {PlugBase} from "../../base/PlugBase.sol";
import {Ownable} from "../../utils/Ownable.sol";
/// @title ContractFactory
/// @notice Abstract contract for deploying contracts
contract ContractFactoryPlug is PlugBase, Ownable {
    event Deployed(address addr, bytes32 salt);

    constructor(
        address socket_,
        uint32 chainSlug_,
        address owner_
    ) PlugBase(socket_, chainSlug_) Ownable(owner_) {}

    function deployContract(
        bytes memory creationCode,
        bytes32 salt
    ) public returns (address) {
        address addr;
        assembly {
            addr := create2(
                callvalue(),
                add(creationCode, 0x20),
                mload(creationCode),
                salt
            )
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, salt);
        return addr;
    }

    /// @notice Gets the address for a deployed contract
    /// @param creationCode The creation code
    /// @param salt The salt
    /// @return address The deployed address
    function getAddress(
        bytes memory creationCode,
        uint256 salt
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(creationCode)
            )
        );

        return address(uint160(uint256(hash)));
    }

    function connect(
        address appGateway_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, switchboard_);
    }
}
