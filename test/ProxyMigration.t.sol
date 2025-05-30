// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./ProxyStorage.t.sol";
import "./mock/MockWatcherPrecompile.sol";

contract MigrationTest is ProxyStorageAssertions {
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

    function upgradeAndCall(address proxy, address newImpl, bytes memory data) internal {
        address oldImpl = getImplementation(proxy);

        hoax(watcherEOA);
        vm.expectEmit(true, true, true, true, address(proxyFactory));
        emit Upgraded(proxy, address(newImpl));
        proxyFactory.upgradeAndCall(proxy, address(newImpl), data);

        // Verify upgrade was successful
        address newImplAddr = getImplementation(address(proxy));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");
    }

    function testFeesManagerUpgrade() public {
        FeesManager newImpl = new FeesManager();
        upgradeAndCall(address(feesManager), address(newImpl), "");
        assertFeesManagerSlot();
    }

    function testAddressResolverUpgrade() public {
        AddressResolver newImpl = new AddressResolver();
        upgradeAndCall(address(addressResolver), address(newImpl), "");
        assertAddressResolverSlot();
    }

    function testAsyncDeployerUpgrade() public {
        AsyncDeployer newImpl = new AsyncDeployer();
        upgradeAndCall(address(asyncDeployer), address(newImpl), "");
        assertAsyncDeployerSlot();
    }

    function testWatcherUpgrade() public {
        Watcher newImpl = new Watcher();
        upgradeAndCall(address(watcher), address(newImpl), "");
        assertWatcherSlot();
    }

    function testAuctionManagerUpgrade() public {
        AuctionManager newImpl = new AuctionManager();
        upgradeAndCall(address(auctionManager), address(newImpl), "");
        assertAuctionManagerSlot();
    }

    function testDeployForwarderUpgrade() public {
        DeployForwarder newImpl = new DeployForwarder();
        upgradeAndCall(address(deployForwarder), address(newImpl), "");
        assertDeployForwarderSlot();
    }

    function testConfigurationsUpgrade() public {
        Configurations newImpl = new Configurations();
        upgradeAndCall(address(configurations), address(newImpl), "");
        assertConfigurationsSlot();
    }

    function testRequestHandlerUpgrade() public {
        RequestHandler newImpl = new RequestHandler();
        upgradeAndCall(address(requestHandler), address(newImpl), "");
        assertRequestHandlerSlot();
    }

    function testWritePrecompileUpgrade() public {
        WritePrecompile newImpl = new WritePrecompile();
        upgradeAndCall(address(writePrecompile), address(newImpl), "");
        assertWritePrecompileSlot();
    }

    function testUpgradeWithInitializationData() public {
        // Deploy new implementation
        MockWatcherPrecompile newImpl = new MockWatcherPrecompile();

        // Prepare initialization data with new defaultLimit
        uint256 newValue = 2000;
        bytes memory initData = abi.encodeWithSelector(
            MockWatcherPrecompile.initialize.selector,
            newValue
        );

        upgradeAndCall(address(watcher), address(newImpl), initData);
        assertWatcherSlot();

        // Verify new value is set
        bytes32 slotValue = vm.load(address(watcher), bytes32(uint256(160)));
        assertEq(uint256(slotValue), newValue, "newValue mismatch");
    }

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
