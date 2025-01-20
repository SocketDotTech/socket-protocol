// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./interfaces/IAddressResolver.sol";
import {Forwarder} from "./Forwarder.sol";
import {AsyncPromise} from "./AsyncPromise.sol";
import {Ownable} from "./utils/Ownable.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title AddressResolver Contract
/// @notice This contract is responsible for fetching latest core addresses and deploying Forwarder and AsyncPromise contracts.
/// @dev Inherits the Ownable contract and implements the IAddressResolver interface.
contract AddressResolver is Ownable, IAddressResolver {
    IWatcherPrecompile public override watcherPrecompile;
    address public override deliveryHelper;
    address public override feesManager;

    uint256 public asyncPromiseCounter;
    address[] internal promises;

    // Implementation contracts
    address public forwarderImplementation;
    address public asyncPromiseImplementation;
    // Proxy admin for managing upgrades
    address public proxyAdmin;

    // contracts to gateway map
    mapping(address => address) public override contractsToGateways;
    // gateway to contract map
    mapping(address => address) public override gatewaysToContracts;

    event PlugAdded(address appGateway, uint32 chainSlug, address plug);
    event ForwarderDeployed(address newForwarder, bytes32 salt);
    event AsyncPromiseDeployed(address newAsyncPromise, bytes32 salt);
    event ImplementationUpdated(string contractName, address newImplementation);

    /// @notice Error thrown if AppGateway contract was already set by a different address
    error AppGatewayContractAlreadySetByDifferentSender(address contractAddress_);
    /// @notice Error thrown if it failed to deploy the create2 contract
    error DeploymentFailed();

    /// @notice Constructor to initialize the AddressResolver contract
    /// @param _owner The address of the contract owner
    constructor(
        address _owner,
        address _proxyAdmin,
        address _forwarderImplementation,
        address _asyncPromiseImplementation
    ) {
        proxyAdmin = (_proxyAdmin);
        _claimOwner(_owner);

        // Deploy implementation contracts
        forwarderImplementation = _forwarderImplementation;
        asyncPromiseImplementation = _asyncPromiseImplementation;

        emit ImplementationUpdated("Forwarder", forwarderImplementation);
        emit ImplementationUpdated("AsyncPromise", asyncPromiseImplementation);
    }

    /// @notice Updates the implementation contract for Forwarder
    /// @param _implementation The new implementation address
    function setForwarderImplementation(address _implementation) external onlyOwner {
        forwarderImplementation = _implementation;
        emit ImplementationUpdated("Forwarder", _implementation);
    }

    /// @notice Updates the implementation contract for AsyncPromise
    /// @param _implementation The new implementation address
    function setAsyncPromiseImplementation(address _implementation) external onlyOwner {
        asyncPromiseImplementation = _implementation;
        emit ImplementationUpdated("AsyncPromise", _implementation);
    }

    /// @notice Updates the address of the delivery helper
    /// @param _deliveryHelper The address of the delivery helper
    function setDeliveryHelper(address _deliveryHelper) external onlyOwner {
        deliveryHelper = _deliveryHelper;
    }

    /// @notice Updates the address of the delivery helper
    /// @param _feesManager The address of the fees manager
    function setFeesManager(address _feesManager) external onlyOwner {
        feesManager = _feesManager;
    }

    /// @notice Updates the address of the watcher precompile contract
    /// @param _watcherPrecompile The address of the watcher precompile contract
    function setWatcherPrecompile(address _watcherPrecompile) external onlyOwner {
        watcherPrecompile = IWatcherPrecompile(_watcherPrecompile);
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

        // Deploy proxy with CREATE2
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{salt: salt}(
            forwarderImplementation,
            proxyAdmin,
            initData
        );

        address newForwarder = address(proxy);
        _setConfig(appDeployer_, newForwarder);
        emit ForwarderDeployed(newForwarder, salt);
        return newForwarder;
    }

    function _setConfig(address appDeployer_, address newForwarder_) internal {
        address gateway = contractsToGateways[appDeployer_];
        gatewaysToContracts[gateway] = newForwarder_;
        contractsToGateways[newForwarder_] = gateway;
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

        // Deploy proxy with CREATE2
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{salt: salt}(
            asyncPromiseImplementation,
            proxyAdmin,
            initData
        );

        address newAsyncPromise = address(proxy);
        emit AsyncPromiseDeployed(newAsyncPromise, salt);
        promises.push(newAsyncPromise);
        return newAsyncPromise;
    }

    /// @notice Clears the list of promises
    /// @dev this function helps in queueing the promises and whitelisting on gateway at the end.
    function clearPromises() external {
        delete promises;
    }

    /// @notice Gets the list of promises
    /// @return array of promises deployed while queueing async calls
    function getPromises() external view returns (address[] memory) {
        return promises;
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
        bytes memory proxyBytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt_, keccak256(proxyBytecode))
        );
        return address(uint160(uint256(hash)));
    }
}
