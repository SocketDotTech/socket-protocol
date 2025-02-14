// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SetupTest.t.sol";
import "../contracts/socket/utils/SignatureVerifier.sol";
import "../contracts/AddressResolver.sol";
import "../contracts/watcherPrecompile/WatcherPrecompile.sol";
import "./MockWatcherPrecompileImpl.sol";

contract MigrationTest is SetupTest {
    // ERC1967Factory emits this event with both proxy and implementation addresses
    event Upgraded(address indexed proxy, address indexed implementation);

    // ERC1967 implementation slot
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Error selector for Unauthorized error
    bytes4 internal constant UNAUTHORIZED_SELECTOR = 0x82b42900; // bytes4(keccak256("Unauthorized()"))

    function setUp() public {
        deployOffChainVMCore();
    }

    function getImplementation(address proxy) internal view returns (address) {
        bytes32 value = vm.load(proxy, _IMPLEMENTATION_SLOT);
        return address(uint160(uint256(value)));
    }

    function testSignatureVerifierUpgrade() public {
        // Deploy new implementation
        SignatureVerifier newImpl = new SignatureVerifier();

        // Store old implementation address
        address oldImpl = getImplementation(address(signatureVerifier));

        // Upgrade proxy to new implementation
        vm.startPrank(watcherEOA);
        vm.expectEmit(true, true, true, true, address(proxyFactory));
        emit Upgraded(address(signatureVerifier), address(newImpl));
        proxyFactory.upgradeAndCall(address(signatureVerifier), address(newImpl), "");
        vm.stopPrank();

        // Verify upgrade was successful
        address newImplAddr = getImplementation(address(signatureVerifier));
        assertNotEq(oldImpl, newImplAddr, "Implementation should have changed");
        assertEq(newImplAddr, address(newImpl), "New implementation not set correctly");
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
        assertEq(watcherPrecompile.maxLimit(), maxLimit * 10 ** 18, "MaxLimit should be preserved");
    }

    function testUpgradeWithInitializationData() public {
        // Deploy new implementation
        MockWatcherPrecompileImpl newImpl = new MockWatcherPrecompileImpl();

        // Store old implementation address for verification
        address oldImpl = getImplementation(address(watcherPrecompile));

        // Prepare initialization data with new maxLimit
        uint256 newMaxLimit = 2000;
        bytes memory initData = abi.encodeWithSelector(
            MockWatcherPrecompileImpl.mockReinitialize.selector,
            watcherEOA,
            address(addressResolver),
            newMaxLimit
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
            watcherPrecompile.maxLimit(),
            newMaxLimit * 10 ** 18,
            "MaxLimit should be updated"
        );
    }

    function testUnauthorizedUpgrade() public {
        // Deploy new implementation
        SignatureVerifier newImpl = new SignatureVerifier();

        // Try to upgrade from unauthorized account
        address unauthorizedUser = address(0xBEEF);
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        proxyFactory.upgradeAndCall(address(signatureVerifier), address(newImpl), "");
        vm.stopPrank();

        // Verify implementation was not changed
        assertEq(
            getImplementation(address(signatureVerifier)),
            address(signatureVerifierImpl),
            "Implementation should not have changed"
        );
    }
}
