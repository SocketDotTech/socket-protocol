// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "./interfaces/IAddressResolver.sol";
import {Forwarder} from "./Forwarder.sol";
import {AsyncPromise} from "./AsyncPromise.sol";
import {OwnableTwoStep} from "./utils/OwnableTwoStep.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {UpgradeableBeacon} from "solady/utils/UpgradeableBeacon.sol";
import {Initializable} from "solady/utils/Initializable.sol";

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

    address public forwarderImplementation;
    address public asyncPromiseImplementation;

    // Array to store promises
    address[] internal _promises;

    uint256 public asyncPromiseCounter;

    // contracts to gateway map
    mapping(address => address) public override contractsToGateways;
    // gateway to contract map
    mapping(address => address) public override gatewaysToContracts;

    /// @notice Error thrown if AppGateway contract was already set by a different address
    error AppGatewayContractAlreadySetByDifferentSender(address contractAddress_);

    event PlugAdded(address appGateway, uint32 chainSlug, address plug);
    event ForwarderDeployed(address newForwarder, bytes32 salt);
    event AsyncPromiseDeployed(address newAsyncPromise, bytes32 salt);
    event ImplementationUpdated(string contractName, address newImplementation);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param owner_ The address of the contract owner
    function initialize(address owner_) public reinitializer(1) {
        _claimOwner(owner_);

        forwarderImplementation = address(new Forwarder());
        asyncPromiseImplementation = address(new AsyncPromise());

        // Deploy beacons with initial implementations
        forwarderBeacon = _deployBeacon(forwarderImplementation);
        asyncPromiseBeacon = _deployBeacon(asyncPromiseImplementation);
    }

    function _deployBeacon(address implementation_) internal returns (UpgradeableBeacon) {
        return new UpgradeableBeacon(address(this), implementation_);
    }

    /// @notice Gets or deploys a Forwarder proxy contract
    /// @param chainContractAddress_ The address of the chain contract
    /// @param chainSlug_ The chain slug
    /// @return newForwarder The address of the deployed Forwarder proxy contract
    function getOrDeployForwarderContract(
        address appDeployer_,
        address chainContractAddress_,
        uint32 chainSlug_
    ) public returns (address newForwarder) {
        // predict address
        address forwarderAddress = getForwarderAddress(chainContractAddress_, chainSlug_);
        // check if addr has code, if yes, return
        if (forwarderAddress.code.length > 0) {
            return forwarderAddress;
        }

        (bytes32 salt, bytes memory initData) = _createForwarderParams(
            chainContractAddress_,
            chainSlug_
        );

        newForwarder = _deployProxy(salt, address(forwarderBeacon), initData);
        _setConfig(appDeployer_, newForwarder);
        emit ForwarderDeployed(newForwarder, salt);
    }

    function _createForwarderParams(
        address chainContractAddress_,
        uint32 chainSlug_
    ) internal view returns (bytes32 salt, bytes memory initData) {
        bytes memory constructorArgs = abi.encode(chainSlug_, chainContractAddress_, address(this));
        initData = abi.encodeWithSelector(
            Forwarder.initialize.selector,
            chainSlug_,
            chainContractAddress_,
            address(this)
        );
        salt = keccak256(constructorArgs);
    }

    function _createAsyncPromiseParams(
        address invoker_
    ) internal view returns (bytes32 salt, bytes memory initData) {
        bytes memory constructorArgs = abi.encode(invoker_, msg.sender, address(this));
        initData = abi.encodeWithSelector(
            AsyncPromise.initialize.selector,
            invoker_,
            msg.sender,
            address(this)
        );

        salt = keccak256(abi.encodePacked(constructorArgs, asyncPromiseCounter));
    }

    /// @notice Deploys an AsyncPromise proxy contract
    /// @param invoker_ The address of the invoker
    /// @return newAsyncPromise The address of the deployed AsyncPromise proxy contract
    function deployAsyncPromiseContract(
        address invoker_
    ) external returns (address newAsyncPromise) {
        (bytes32 salt, bytes memory initData) = _createAsyncPromiseParams(invoker_);
        asyncPromiseCounter++;

        newAsyncPromise = _deployProxy(salt, address(asyncPromiseBeacon), initData);
        _promises.push(newAsyncPromise);

        emit AsyncPromiseDeployed(newAsyncPromise, salt);
    }

    function _deployProxy(
        bytes32 salt_,
        address beacon_,
        bytes memory initData_
    ) internal returns (address) {
        // 1. Deploy proxy without initialization args
        address proxy = LibClone.deployDeterministicERC1967BeaconProxy(beacon_, salt_);

        // 2. Explicitly initialize after deployment
        (bool success, ) = proxy.call(initData_);
        require(success, "Initialization failed");

        return proxy;
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
        (bytes32 salt, ) = _createForwarderParams(chainContractAddress_, chainSlug_);
        return _predictProxyAddress(salt, address(forwarderBeacon));
    }

    /// @notice Gets the predicted address of an AsyncPromise proxy contract
    /// @param invoker_ The address of the invoker
    /// @return The predicted address of the AsyncPromise proxy contract
    function getAsyncPromiseAddress(address invoker_) public view returns (address) {
        (bytes32 salt, ) = _createAsyncPromiseParams(invoker_);
        return _predictProxyAddress(salt, address(asyncPromiseBeacon));
    }

    /// @notice Predicts the address of a proxy contract
    /// @param salt_ The salt used for address prediction
    /// @param beacon_ The beacon used for address prediction
    /// @return The predicted address of the proxy contract
    function _predictProxyAddress(bytes32 salt_, address beacon_) internal view returns (address) {
        return
            LibClone.predictDeterministicAddressERC1967BeaconProxy(beacon_, salt_, address(this));
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
