// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SetupTest.t.sol";
import "../contracts/protocol/AddressResolver.sol";
import "../contracts/protocol/watcherPrecompile/WatcherPrecompile.sol";
import "../contracts/protocol/Forwarder.sol";
import "../contracts/protocol/AsyncPromise.sol";
import "./MockWatcherPrecompileImpl.sol";

contract MigrationTest is SetupTest {
    // ERC1967Factory emits this event with both proxy and implementation addresses
    event Upgraded(address indexed proxy, address indexed implementation);
    event ImplementationUpdated(string contractName, address newImplementation);

    // ERC1967 implementation slot
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Beacon implementation slot
    uint256 internal constant _BEACON_IMPLEMENTATION_SLOT = 0x911c5a209f08d5ec5e;

    // Beacon slot in ERC1967
    bytes32 internal constant _BEACON_SLOT =
        0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    // Error selector for Unauthorized error
    bytes4 internal constant UNAUTHORIZED_SELECTOR = 0x82b42900; // bytes4(keccak256("Unauthorized()"))

    function setUp() public {
        deployOffChainVMCore();
    }

    function getImplementation(address proxy) internal view returns (address) {
        bytes32 value = vm.load(proxy, _IMPLEMENTATION_SLOT);
        return address(uint160(uint256(value)));
    }

    function getBeaconImplementation(address beacon) internal view returns (address) {
        bytes32 value = vm.load(beacon, bytes32(_BEACON_IMPLEMENTATION_SLOT));
        return address(uint160(uint256(value)));
    }

    function getBeacon(address proxy) internal view returns (address) {
        bytes32 value = vm.load(proxy, _BEACON_SLOT);
        return address(uint160(uint256(value)));
    }

    function testAddressResolverUpgrade() public {
        // Deploy new implementation
        AddressResolver newImpl = new AddressResolver();

        // Store old implementation address
        address oldImpl = getImplementation(address(addressResolver));

        // Upgrade proxy to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(proxyFactory));
        emit Upgraded(address(addressResolver), address(newImpl));
        proxyFactory.upgradeAndCall(address(addressResolver), address(newImpl), "");
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getImplementation(address(addressResolver));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Verify state is preserved
        assertEq(addressResolver.owner(), watcherEOA, "Owner should be preserved after upgrade");
        assertEq(
            address(addressResolver.watcherPrecompile__()),
            address(watcherPrecompile),
            "WatcherPrecompile address should be preserved"
        );
    }

    function testWatcherPrecompileUpgrade() public {
        // Deploy new implementation
        WatcherPrecompile newImpl = new WatcherPrecompile();

        // Store old implementation address
        address oldImpl = getImplementation(address(watcherPrecompile));

        // Upgrade proxy to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(proxyFactory));
        emit Upgraded(address(watcherPrecompile), address(newImpl));
        proxyFactory.upgradeAndCall(address(watcherPrecompile), address(newImpl), "");
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getImplementation(address(watcherPrecompile));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Verify state is preserved
        assertEq(watcherPrecompile.owner(), watcherEOA, "Owner should be preserved after upgrade");
        assertEq(
            address(watcherPrecompile.addressResolver__()),
            address(addressResolver),
            "AddressResolver should be preserved"
        );
        assertEq(
            watcherPrecompile.defaultLimit(),
            defaultLimit * 10 ** 18,
            "DefaultLimit should be preserved"
        );
    }

    function testUpgradeWithInitializationData() public {
        // Deploy new implementation
        MockWatcherPrecompileImpl newImpl = new MockWatcherPrecompileImpl();

        // Store old implementation address for verification
        address oldImpl = getImplementation(address(watcherPrecompile));

        // Prepare initialization data with new defaultLimit
        uint256 newDefaultLimit = 2000;
        bytes memory initData = abi.encodeWithSelector(
            MockWatcherPrecompileImpl.mockReinitialize.selector,
            watcherEOA,
            address(addressResolver),
            newDefaultLimit
        );

        // Upgrade proxy with initialization data
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(proxyFactory));
        emit Upgraded(address(watcherPrecompile), address(newImpl));
        proxyFactory.upgradeAndCall(address(watcherPrecompile), address(newImpl), initData);
        vm.stopPrank();

        // Verify upgrade and initialization was successful
        address newImplAddr = getImplementation(address(watcherPrecompile));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");
        assertEq(
            watcherPrecompile.defaultLimit(),
            newDefaultLimit * 10 ** 18,
            "DefaultLimit should be updated"
        );
    }

    function testUnauthorizedUpgrade() public {
        // Deploy new implementation
        WatcherPrecompile newImpl = new WatcherPrecompile();

        // Try to upgrade from unauthorized account
        address unauthorizedUser = address(0xBEEF);
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        proxyFactory.upgradeAndCall(address(watcherPrecompile), address(newImpl), "");
        vm.stopPrank();

        // Verify implementation was not changed
        assertEq(
            getImplementation(address(watcherPrecompile)),
            address(watcherPrecompileImpl),
            "Implementation should not have changed"
        );
    }

    function testForwarderBeaconUpgrade() public {
        // Deploy new implementation
        Forwarder newImpl = new Forwarder();

        // Get current implementation from beacon
        address oldImpl = getBeaconImplementation(address(addressResolver.forwarderBeacon()));

        // Upgrade beacon to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(addressResolver));
        emit ImplementationUpdated("Forwarder", address(newImpl));
        addressResolver.setForwarderImplementation(address(newImpl));
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getBeaconImplementation(address(addressResolver.forwarderBeacon()));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Deploy a new forwarder and verify it uses the correct beacon
        address newForwarder = addressResolver.getOrDeployForwarderContract(
            address(this),
            address(0x123),
            1
        );
        address beacon = getBeacon(newForwarder);
        assertEq(
            beacon,
            address(addressResolver.forwarderBeacon()),
            "Beacon address not set correctly"
        );

        // Get implementation from beacon and verify it matches
        address implFromBeacon = getBeaconImplementation(beacon);
        assertEq(
            implFromBeacon,
            address(newImpl),
            "Beacon implementation should match new implementation"
        );
    }

    function testAsyncPromiseBeaconUpgrade() public {
        // Deploy new implementation
        AsyncPromise newImpl = new AsyncPromise();

        // Get current implementation from beacon
        address oldImpl = getBeaconImplementation(address(addressResolver.asyncPromiseBeacon()));

        // Upgrade beacon to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(addressResolver));
        emit ImplementationUpdated("AsyncPromise", address(newImpl));
        addressResolver.setAsyncPromiseImplementation(address(newImpl));
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getBeaconImplementation(
            address(addressResolver.asyncPromiseBeacon())
        );
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Deploy a new async promise and verify it uses the correct beacon
        address newPromise = addressResolver.deployAsyncPromiseContract(address(this));
        address beacon = getBeacon(newPromise);
        assertEq(
            beacon,
            address(addressResolver.asyncPromiseBeacon()),
            "Beacon address not set correctly"
        );

        // Get implementation from beacon and verify it matches
        address implFromBeacon = getBeaconImplementation(beacon);
        assertEq(
            implFromBeacon,
            address(newImpl),
            "Beacon implementation should match new implementation"
        );
    }

    function testUnauthorizedBeaconUpgrade() public {
        // Deploy new implementations
        Forwarder newForwarderImpl = new Forwarder();
        AsyncPromise newAsyncPromiseImpl = new AsyncPromise();

        // Try to upgrade from unauthorized account
        address unauthorizedUser = address(0xBEEF);

        vm.startPrank(unauthorizedUser);
        // Try upgrading forwarder beacon
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        addressResolver.setForwarderImplementation(address(newForwarderImpl));

        // Try upgrading async promise beacon
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        addressResolver.setAsyncPromiseImplementation(address(newAsyncPromiseImpl));

        vm.stopPrank();

        // Verify implementations were not changed
        assertNotEq(
            getBeaconImplementation(address(addressResolver.forwarderBeacon())),
            address(newForwarderImpl),
            "Forwarder implementation should not have changed"
        );
        assertNotEq(
            getBeaconImplementation(address(addressResolver.asyncPromiseBeacon())),
            address(newAsyncPromiseImpl),
            "AsyncPromise implementation should not have changed"
        );
    }
}
