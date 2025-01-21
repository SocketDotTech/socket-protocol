// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./interfaces/IAddressResolver.sol";
import {Forwarder} from "./Forwarder.sol";
import {AsyncPromise} from "./AsyncPromise.sol";
import {OwnableTwoStep} from "./utils/OwnableTwoStep.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @title AddressResolver Contract
/// @notice This contract is responsible for fetching latest core addresses and deploying Forwarder and AsyncPromise contracts.
/// @dev Inherits the OwnableTwoStep contract and implements the IAddressResolver interface.
contract AddressResolver is OwnableTwoStep, IAddressResolver, Initializable {
    IWatcherPrecompile public override watcherPrecompile__;
    address public override deliveryHelper;
    address public override feesManager;

    // Beacons for managing upgrades
    UpgradeableBeacon public forwarderBeacon;
    UpgradeableBeacon public asyncPromiseBeacon;

    // Array to store promises
    address[] internal _promises;

    uint256 public asyncPromiseCounter;

    // contracts to gateway map
    mapping(address => address) public override contractsToGateways;
    // gateway to contract map
    mapping(address => address) public override gatewaysToContracts;

    /// @notice Error thrown if AppGateway contract was already set by a different address
    error AppGatewayContractAlreadySetByDifferentSender(address contractAddress_);
    /// @notice Error thrown if it failed to deploy the create2 contract
    error DeploymentFailed();

    event PlugAdded(address appGateway, uint32 chainSlug, address plug);
    event ForwarderDeployed(address newForwarder, bytes32 salt);
    event AsyncPromiseDeployed(address newAsyncPromise, bytes32 salt);
    event ImplementationUpdated(string contractName, address newImplementation);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param owner_ The address of the contract owner
    function initialize(
        address owner_,
        address forwarderImplementation_,
        address asyncPromiseImplementation_
    ) public initializer {
        _claimOwner(owner_);

        // Deploy beacons with initial implementations
        forwarderBeacon = new UpgradeableBeacon(forwarderImplementation_, address(this));
        asyncPromiseBeacon = new UpgradeableBeacon(asyncPromiseImplementation_, address(this));

        emit ImplementationUpdated("Forwarder", forwarderImplementation_);
        emit ImplementationUpdated("AsyncPromise", asyncPromiseImplementation_);
    }

    /// @notice Gets or deploys a Forwarder proxy contract
    /// @param chainContractAddress_ The address of the chain contract
    /// @param chainSlug_ The chain slug
    /// @return The address of the deployed Forwarder proxy contract
    function getOrDeployForwarderContract(
        address appDeployer_,
        address chainContractAddress_,
        uint32 chainSlug_
    ) public returns (address) {
        // predict address
        address forwarderAddress = getForwarderAddress(chainContractAddress_, chainSlug_);
        // check if addr has code, if yes, return
        if (forwarderAddress.code.length > 0) {
            return forwarderAddress;
        }

        bytes memory constructorArgs = abi.encode(chainSlug_, chainContractAddress_, address(this));
        bytes memory initData = abi.encodeWithSelector(
            Forwarder.initialize.selector,
            chainSlug_,
            chainContractAddress_,
            address(this)
        );

        bytes32 salt = keccak256(constructorArgs);

        // Deploy beacon proxy with CREATE2
        BeaconProxy proxy = new BeaconProxy{salt: salt}(address(forwarderBeacon), initData);

        address newForwarder = address(proxy);
        _setConfig(appDeployer_, newForwarder);
        emit ForwarderDeployed(newForwarder, salt);
        return newForwarder;
    }

    /// @notice Deploys an AsyncPromise proxy contract
    /// @param invoker_ The address of the invoker
    /// @return The address of the deployed AsyncPromise proxy contract
    function deployAsyncPromiseContract(address invoker_) external returns (address) {
        bytes memory constructorArgs = abi.encode(invoker_, msg.sender, address(this));
        bytes memory initData = abi.encodeWithSelector(
            AsyncPromise.initialize.selector,
            invoker_,
            msg.sender,
            address(this)
        );

        bytes32 salt = keccak256(abi.encodePacked(constructorArgs, asyncPromiseCounter++));

        // Deploy beacon proxy with CREATE2
        BeaconProxy proxy = new BeaconProxy{salt: salt}(address(asyncPromiseBeacon), initData);

        address newAsyncPromise = address(proxy);
        emit AsyncPromiseDeployed(newAsyncPromise, salt);
        _promises.push(newAsyncPromise);
        return newAsyncPromise;
    }

    /// @notice Clears the list of promises
    /// @dev this function helps in queueing the promises and whitelisting on gateway at the end.
    function clearPromises() external {
        delete _promises;
    }

    /// @notice Gets the list of promises
    /// @return array of promises deployed while queueing async calls
    function getPromises() external view returns (address[] memory) {
        return _promises;
    }

    /// @notice Sets the contract to gateway mapping
    /// @param contractAddress_ The address of the contract
    function setContractsToGateways(address contractAddress_) external {
        if (
            contractsToGateways[contractAddress_] != address(0) &&
            contractsToGateways[contractAddress_] != msg.sender
        ) {
            revert AppGatewayContractAlreadySetByDifferentSender(contractAddress_);
        }
        contractsToGateways[contractAddress_] = msg.sender;
    }

    /// @notice Gets the predicted address of a Forwarder proxy contract
    /// @param chainContractAddress_ The address of the chain contract
    /// @param chainSlug_ The chain slug
    /// @return The predicted address of the Forwarder proxy contract
    function getForwarderAddress(
        address chainContractAddress_,
        uint32 chainSlug_
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encode(chainSlug_, chainContractAddress_, address(this)));
        return _predictProxyAddress(salt);
    }

    /// @notice Gets the predicted address of an AsyncPromise proxy contract
    /// @param invoker_ The address of the invoker
    /// @param forwarder_ The address of the forwarder
    /// @return The predicted address of the AsyncPromise proxy contract
    function getAsyncPromiseAddress(
        address invoker_,
        address forwarder_
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(invoker_, forwarder_, asyncPromiseCounter));
        return _predictProxyAddress(salt);
    }

    /// @notice Predicts the address of a proxy contract
    /// @param salt_ The salt used for address prediction
    /// @return The predicted address of the proxy contract
    function _predictProxyAddress(bytes32 salt_) internal view returns (address) {
        bytes memory proxyBytecode = type(BeaconProxy).creationCode;
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt_, keccak256(proxyBytecode))
        );
        return address(uint160(uint256(hash)));
    }

    function _setConfig(address appDeployer_, address newForwarder_) internal {
        address gateway = contractsToGateways[appDeployer_];
        gatewaysToContracts[gateway] = newForwarder_;
        contractsToGateways[newForwarder_] = gateway;
    }

    /// @notice Updates the implementation contract for Forwarder
    /// @param implementation_ The new implementation address
    function setForwarderImplementation(address implementation_) external onlyOwner {
        forwarderBeacon.upgradeTo(implementation_);
        emit ImplementationUpdated("Forwarder", implementation_);
    }

    /// @notice Updates the implementation contract for AsyncPromise
    /// @param implementation_ The new implementation address
    function setAsyncPromiseImplementation(address implementation_) external onlyOwner {
        asyncPromiseBeacon.upgradeTo(implementation_);
        emit ImplementationUpdated("AsyncPromise", implementation_);
    }

    /// @notice Updates the address of the delivery helper
    /// @param deliveryHelper_ The address of the delivery helper
    function setDeliveryHelper(address deliveryHelper_) external onlyOwner {
        deliveryHelper = deliveryHelper_;
    }

    /// @notice Updates the address of the fees manager
    /// @param feesManager_ The address of the fees manager
    function setFeesManager(address feesManager_) external onlyOwner {
        feesManager = feesManager_;
    }

    /// @notice Updates the address of the watcher precompile contract
    /// @param watcherPrecompile_ The address of the watcher precompile contract
    function setWatcherPrecompile(address watcherPrecompile_) external onlyOwner {
        watcherPrecompile__ = IWatcherPrecompile(watcherPrecompile_);
    }
}
