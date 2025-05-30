// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SetupTest.t.sol";
import "../contracts/evmx/helpers/AddressResolver.sol";
import "../contracts/evmx/watcher/Watcher.sol";
import "../contracts/evmx/helpers/Forwarder.sol";
import "../contracts/evmx/helpers/AsyncPromise.sol";

contract MigrationTest is AppGatewayBaseSetup {
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
        deploy();
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
            address(addressResolver.watcher__()),
            address(watcher),
            "Watcher address should be preserved"
        );
    }

    function testWatcherUpgrade() public {
        // Deploy new implementation
        Watcher newImpl = new Watcher();

        // Store old implementation address
        address oldImpl = getImplementation(address(watcher));

        // Upgrade proxy to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(proxyFactory));
        emit Upgraded(address(watcher), address(newImpl));
        proxyFactory.upgradeAndCall(address(watcher), address(newImpl), "");
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getImplementation(address(watcher));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Verify state is preserved
        assertEq(watcher.owner(), watcherEOA, "Owner should be preserved after upgrade");
        assertEq(
            address(watcher.configurations__()),
            address(configurations),
            "Configurations should be preserved"
        );
        assertEq(watcher.evmxSlug(), evmxSlug, "EvmxSlug should be preserved");
    }

    // function testUpgradeWithInitializationData() public {
    //     // Deploy new implementation
    //     MockWatcherImpl newImpl = new MockWatcherImpl();

    //     // Store old implementation address for verification
    //     address oldImpl = getImplementation(address(watcher));

    //     // Prepare initialization data with new defaultLimit
    //     uint256 newDefaultLimit = 2000;
    //     bytes memory initData = abi.encodeWithSelector(
    //         MockWatcherImpl.mockReinitialize.selector,
    //         watcherEOA,
    //         address(addressResolver),
    //         newDefaultLimit
    //     );

    //     // Upgrade proxy with initialization data
    //     vm.startPrank(watcherEOA);
    //     vm.expectEmit(true, true, true, true, address(proxyFactory));
    //     emit Upgraded(address(watcher), address(newImpl));
    //     proxyFactory.upgradeAndCall(address(watcher), address(newImpl), initData);
    //     vm.stopPrank();

    //     // Verify upgrade and initialization was successful
    //     address newImplAddr = getImplementation(address(watcher));
    //     assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
    //     assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");
    //     assertEq(watcher.evmxSlug(), evmxSlug, "EvmxSlug should be preserved");
    // }

    function testUnauthorizedUpgrade() public {
        // Deploy new implementation
        Watcher newImpl = new Watcher();
        address oldImpl = getImplementation(address(watcher));

        // Try to upgrade from unauthorized account
        address unauthorizedUser = address(0xBEEF);
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        proxyFactory.upgradeAndCall(address(watcher), address(newImpl), "");
        vm.stopPrank();

        // Verify implementation was not changed
        assertEq(
            getImplementation(address(watcher)),
            oldImpl,
            "Implementation should not have changed"
        );
    }

    function testForwarderBeaconUpgrade() public {
        // Deploy new implementation
        Forwarder newImpl = new Forwarder();

        // Get current implementation from beacon
        address oldImpl = getBeaconImplementation(address(asyncDeployer.forwarderBeacon()));

        // Upgrade beacon to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(asyncDeployer));
        emit ImplementationUpdated("Forwarder", address(newImpl));
        asyncDeployer.setForwarderImplementation(address(newImpl));
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getBeaconImplementation(address(asyncDeployer.forwarderBeacon()));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Deploy a new forwarder and verify it uses the correct beacon
        address newForwarder = asyncDeployer.getOrDeployForwarderContract(address(0x123), 1);
        address beacon = getBeacon(newForwarder);
        assertEq(
            beacon,
            address(asyncDeployer.forwarderBeacon()),
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
        address oldImpl = getBeaconImplementation(address(asyncDeployer.asyncPromiseBeacon()));

        // Upgrade beacon to new implementation
        hoax(watcherEOA);
        vm.expectEmit(true, true, true, false);
        emit ImplementationUpdated("AsyncPromise", address(newImpl));
        asyncDeployer.setAsyncPromiseImplementation(address(newImpl));

        // Verify upgrade was successful
        address newImplAddr = getBeaconImplementation(address(asyncDeployer.asyncPromiseBeacon()));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");

        // Deploy a new async promise and verify it uses the correct beacon
        hoax(address(watcher));
        address newPromise = asyncDeployer.deployAsyncPromiseContract(address(this), 1);
        address beacon = getBeacon(newPromise);
        assertEq(
            beacon,
            address(asyncDeployer.asyncPromiseBeacon()),
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
        asyncDeployer.setForwarderImplementation(address(newForwarderImpl));

        // Try upgrading async promise beacon
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        asyncDeployer.setAsyncPromiseImplementation(address(newAsyncPromiseImpl));

        vm.stopPrank();

        // Verify implementations were not changed
        assertNotEq(
            getBeaconImplementation(address(asyncDeployer.forwarderBeacon())),
            address(newForwarderImpl),
            "Forwarder implementation should not have changed"
        );
        assertNotEq(
            getBeaconImplementation(address(asyncDeployer.asyncPromiseBeacon())),
            address(newAsyncPromiseImpl),
            "AsyncPromise implementation should not have changed"
        );
    }
}
