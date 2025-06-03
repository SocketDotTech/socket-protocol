// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {LibClone} from "solady/utils/LibClone.sol";
import {UpgradeableBeacon} from "solady/utils/UpgradeableBeacon.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import "solady/auth/Ownable.sol";
import "../interfaces/IAsyncDeployer.sol";
import {Forwarder} from "./Forwarder.sol";
import {AsyncPromise} from "./AsyncPromise.sol";
import {AddressResolverUtil} from "./AddressResolverUtil.sol";
import "../../utils/RescueFundsLib.sol";

abstract contract AsyncDeployerStorage is IAsyncDeployer {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    UpgradeableBeacon public forwarderBeacon;

    // slot 51
    UpgradeableBeacon public asyncPromiseBeacon;

    // slot 52
    address public forwarderImplementation;

    // slot 53
    address public asyncPromiseImplementation;

    // slot 54
    uint256 public asyncPromiseCounter;

    // slots [55-104] reserved for gap
    uint256[50] _gap_after;

    // slots [105-154] 50 slots reserved for address resolver util
}

/// @title AsyncDeployer Contract
/// @notice This contract is responsible for deploying Forwarder and AsyncPromise contracts.
contract AsyncDeployer is AsyncDeployerStorage, Initializable, AddressResolverUtil, Ownable {
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @dev it deploys the forwarder and async promise implementations and beacons for them
    /// @dev this contract is owner of the beacons for upgrading later
    /// @param owner_ The address of the contract owner
    function initialize(address owner_, address addressResolver_) public reinitializer(1) {
        _initializeOwner(owner_);
        _setAddressResolver(addressResolver_);

        forwarderImplementation = address(new Forwarder());
        asyncPromiseImplementation = address(new AsyncPromise());

        // Deploy beacons with initial implementations
        forwarderBeacon = new UpgradeableBeacon(address(this), forwarderImplementation);
        asyncPromiseBeacon = new UpgradeableBeacon(address(this), asyncPromiseImplementation);
    }

    /// @notice Gets or deploys a Forwarder proxy contract
    /// @dev it checks if the forwarder is already deployed, if yes, it returns the address
    /// @dev it maps the forwarder with the app gateway which is used for verifying if they are linked
    /// @param chainContractAddress_ The address of the chain contract
    /// @param chainSlug_ The chain slug
    /// @return newForwarder The address of the deployed Forwarder proxy contract
    function getOrDeployForwarderContract(
        address chainContractAddress_,
        uint32 chainSlug_
    ) public override returns (address newForwarder) {
        // predict address
        address forwarderAddress = getForwarderAddress(chainContractAddress_, chainSlug_);

        // check if addr has code, if yes, return
        if (forwarderAddress.code.length > 0) {
            return forwarderAddress;
        }

        // creates init data and salt
        (bytes32 salt, bytes memory initData) = _createForwarderParams(
            chainContractAddress_,
            chainSlug_
        );

        // deploys the proxy
        newForwarder = _deployProxy(salt, address(forwarderBeacon), initData);

        // emits the event
        emit ForwarderDeployed(newForwarder, salt);
    }

    /// @notice Deploys an AsyncPromise proxy contract
    /// @param invoker_ The address of the invoker
    /// @return newAsyncPromise The address of the deployed AsyncPromise proxy contract
    function deployAsyncPromiseContract(
        address invoker_,
        uint40 requestCount_
    ) external override onlyWatcher returns (address newAsyncPromise) {
        // creates init data and salt
        (bytes32 salt, bytes memory initData) = _createAsyncPromiseParams(invoker_, requestCount_);
        asyncPromiseCounter++;

        // deploys the proxy
        newAsyncPromise = _deployProxy(salt, address(asyncPromiseBeacon), initData);
        emit AsyncPromiseDeployed(newAsyncPromise, salt);
    }

    function _createForwarderParams(
        address chainContractAddress_,
        uint32 chainSlug_
    ) internal view returns (bytes32 salt, bytes memory initData) {
        bytes memory constructorArgs = abi.encode(
            chainSlug_,
            chainContractAddress_,
            address(addressResolver__)
        );
        initData = abi.encodeWithSelector(
            Forwarder.initialize.selector,
            chainSlug_,
            chainContractAddress_,
            address(addressResolver__)
        );

        // creates salt with constructor args
        salt = keccak256(constructorArgs);
    }

    function _createAsyncPromiseParams(
        address invoker_,
        uint40 requestCount_
    ) internal view returns (bytes32 salt, bytes memory initData) {
        bytes memory constructorArgs = abi.encode(
            requestCount_,
            invoker_,
            address(addressResolver__)
        );

        // creates init data
        initData = abi.encodeWithSelector(
            AsyncPromise.initialize.selector,
            requestCount_,
            invoker_,
            address(addressResolver__)
        );

        // creates salt with a counter
        salt = keccak256(abi.encodePacked(constructorArgs, asyncPromiseCounter));
    }

    function _deployProxy(
        bytes32 salt_,
        address beacon_,
        bytes memory initData_
    ) internal returns (address) {
        // Deploy proxy without initialization args
        address proxy = LibClone.deployDeterministicERC1967BeaconProxy(beacon_, salt_);

        // Explicitly initialize after deployment
        (bool success, ) = proxy.call(initData_);
        require(success, "Initialization failed");

        return proxy;
    }

    /// @notice Gets the predicted address of a Forwarder proxy contract
    /// @param chainContractAddress_ The address of the chain contract
    /// @param chainSlug_ The chain slug
    /// @return The predicted address of the Forwarder proxy contract
    function getForwarderAddress(
        address chainContractAddress_,
        uint32 chainSlug_
    ) public view override returns (address) {
        (bytes32 salt, ) = _createForwarderParams(chainContractAddress_, chainSlug_);
        return _predictProxyAddress(salt, address(forwarderBeacon));
    }

    /// @notice Gets the predicted address of an AsyncPromise proxy contract
    /// @param invoker_ The address of the invoker
    /// @return The predicted address of the AsyncPromise proxy contract
    function getAsyncPromiseAddress(
        address invoker_,
        uint40 requestCount_
    ) public view override returns (address) {
        (bytes32 salt, ) = _createAsyncPromiseParams(invoker_, requestCount_);
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

    /// @notice Updates the implementation contract for Forwarder
    /// @param implementation_ The new implementation address
    function setForwarderImplementation(address implementation_) external override onlyOwner {
        forwarderBeacon.upgradeTo(implementation_);
        emit ImplementationUpdated("Forwarder", implementation_);
    }

    /// @notice Updates the implementation contract for AsyncPromise
    /// @param implementation_ The new implementation address
    function setAsyncPromiseImplementation(address implementation_) external override onlyOwner {
        asyncPromiseBeacon.upgradeTo(implementation_);
        emit ImplementationUpdated("AsyncPromise", implementation_);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
