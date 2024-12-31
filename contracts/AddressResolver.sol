// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./interfaces/IAddressResolver.sol";
import {Forwarder} from "./Forwarder.sol";
import {AsyncPromise} from "./AsyncPromise.sol";
import {Ownable} from "./utils/Ownable.sol";

/// @title AddressResolver Contract
/// @notice This contract is responsible for fetching latest core addresses and deploying Forwarder and AsyncPromise contracts.
/// @dev Inherits the Ownable contract and implements the IAddressResolver interface.
contract AddressResolver is Ownable, IAddressResolver {
    IWatcherPrecompile public override watcherPrecompile;
    address public override auctionHouse;
    uint256 public asyncPromiseCounter;

    address[] internal promises;

    bytes public forwarderBytecode = type(Forwarder).creationCode;
    bytes public asyncPromiseBytecode = type(AsyncPromise).creationCode;

    // Contracts to gateway mapping
    mapping(address => address) public override contractsToGateways;
    mapping(address => address) public override gatewaysToContracts;

    event ForwarderDeployed(address newForwarder, bytes32 salt);
    event AsyncPromiseDeployed(address newAsyncPromise, bytes32 salt);
    error AppGatewayContractAlreadySetByDifferentSender(address contractAddress_);

    constructor(address _owner, address _watcherPrecompile) Ownable(_owner) {
        watcherPrecompile = IWatcherPrecompile(_watcherPrecompile);
    }

    /// @notice Gets or deploys a Forwarder contract
    function getOrDeployForwarderContract(address chainContractAddress_, uint32 chainSlug_) public returns (address) {
        bytes memory constructorArgs = abi.encode(chainSlug_, chainContractAddress_, address(this));
        bytes memory combinedBytecode = abi.encodePacked(forwarderBytecode, constructorArgs);
        
        address forwarderAddress = getForwarderAddress(chainContractAddress_, chainSlug_);
        if (forwarderAddress.code.length > 0) {
            return forwarderAddress; // Return existing contract if already deployed
        }

        bytes32 salt = keccak256(abi.encodePacked(constructorArgs, block.timestamp));
        address newForwarder;

        assembly {
            newForwarder := create2(callvalue(), add(combinedBytecode, 0x20), mload(combinedBytecode), salt)
            if iszero(extcodesize(newForwarder)) {
                revert(0, 0) // Revert if contract creation fails
            }
        }
        emit ForwarderDeployed(newForwarder, salt);
        return newForwarder;
    }

    /// @notice Deploys an AsyncPromise contract
    function deployAsyncPromiseContract(address invoker_) external returns (address) {
        bytes memory constructorArgs = abi.encode(invoker_, msg.sender, address(this));
        bytes memory combinedBytecode = abi.encodePacked(asyncPromiseBytecode, constructorArgs);
        
        bytes32 salt = keccak256(abi.encodePacked(constructorArgs, block.timestamp, asyncPromiseCounter++));
        address newAsyncPromise;

        assembly {
            newAsyncPromise := create2(callvalue(), add(combinedBytecode, 0x20), mload(combinedBytecode), salt)
            if iszero(extcodesize(newAsyncPromise)) {
                revert(0, 0) // Revert if contract creation fails
            }
        }

        emit AsyncPromiseDeployed(newAsyncPromise, salt);
        promises.push(newAsyncPromise);
        return newAsyncPromise;
    }

    /// @notice Clears the list of promises
    function clearPromises() external {
        delete promises;
    }

    /// @notice Gets the list of promises
    function getPromises() external view returns (address[] memory) {
        return promises;
    }

    /// @notice Sets the contract to gateway mapping
    function setContractsToGateways(address contractAddress_) external {
        if (contractsToGateways[contractAddress_] != address(0) && contractsToGateways[contractAddress_] != msg.sender) {
            revert AppGatewayContractAlreadySetByDifferentSender(contractAddress_);
        }
        contractsToGateways[contractAddress_] = msg.sender;
    }

    /// @notice Gets the predicted address of a Forwarder contract
    function getForwarderAddress(address chainContractAddress_, uint32 chainSlug_) public view returns (address) {
        bytes memory constructorArgs = abi.encode(chainSlug_, chainContractAddress_, address(this));
        return _predictAddress(forwarderBytecode, constructorArgs, keccak256(constructorArgs));
    }

    /// @notice Gets the predicted address of an AsyncPromise contract
    function getAsyncPromiseAddress(address invoker_, address forwarder_) public view returns (address) {
        bytes memory constructorArgs = abi.encode(invoker_, forwarder_, address(this));
        return _predictAddress(asyncPromiseBytecode, constructorArgs, keccak256(abi.encodePacked(constructorArgs, asyncPromiseCounter)));
    }

    /// @notice Predicts the address of a contract
    function _predictAddress(bytes memory bytecode_, bytes memory constructorArgs_, bytes32 salt_) internal view returns (address) {
        bytes memory combinedBytecode = abi.encodePacked(bytecode_, constructorArgs_);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt_, keccak256(combinedBytecode)));
        return address(uint160(uint256(hash)));
    }
}
