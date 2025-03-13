// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DeliveryHelper.t.sol";

// contract StorageTest is DeliveryHelperTest {
//     DeliveryHelper public deliveryHelperImpl;

//     function setUp() public {
//         setUpDeliveryHelper();
//     }

//     function testAddressResolverSlot() public view {
//         // Test AddressResolver version at slot 59
//         bytes32 versionSlot = vm.load(address(addressResolver), bytes32(uint256(59)));
//         assertEq(uint64(uint256(versionSlot)), 1);

//         // Test auction manager address at slot 61 in AddressResolver
//         bytes32 slotValue = vm.load(address(addressResolver), bytes32(uint256(61)));
//         assertEq(address(uint160(uint256(slotValue))), address(auctionManager));
//     }

//     function testWatcherPrecompileSlot() public view {
//         // Test AddressResolver address at slot 109 in WatcherPrecompile
//         bytes32 slotValue = vm.load(address(watcherPrecompile), bytes32(uint256(52)));
//         assertEq(uint256(slotValue), evmxSlug);

//         slotValue = vm.load(address(watcherPrecompile), bytes32(uint256(220)));
//         assertEq(address(uint160(uint256(slotValue))), address(addressResolver));
//     }

//     function testFeesManagerSlot() public view {
//         bytes32 slotValue = vm.load(address(feesManager), bytes32(uint256(51)));
//         assertEq(uint32(uint256(slotValue)), evmxSlug);

//         slotValue = vm.load(address(feesManager), bytes32(uint256(106)));
//         assertEq(address(uint160(uint256(slotValue))), address(addressResolver));
//     }

//     function testAuctionManagerSlot() public view {
//         bytes32 slotValue = vm.load(address(auctionManager), bytes32(uint256(50)));
//         assertEq(uint32(uint256(slotValue)), evmxSlug);

//         slotValue = vm.load(address(auctionManager), bytes32(uint256(105)));
//         assertEq(address(uint160(uint256(slotValue))), address(addressResolver));
//     }

//     function testForwarderSlot() public {
//         address forwarder = addressResolver.getOrDeployForwarderContract(
//             address(this),
//             address(this),
//             evmxSlug
//         );

//         bytes32 slotValue = vm.load(address(forwarder), bytes32(uint256(50)));
//         assertEq(uint32(uint256(slotValue)), evmxSlug);

//         slotValue = vm.load(address(forwarder), bytes32(uint256(53)));
//         assertEq(address(uint160(uint256(slotValue))), address(0));
//     }

//     function testAsyncPromiseSlot() public {
//         address asyncPromise = addressResolver.deployAsyncPromiseContract(address(this));

//         bytes32 slotValue = vm.load(address(asyncPromise), bytes32(uint256(51)));
//         assertEq(address(uint160(uint256(slotValue))), address(this));

//         slotValue = vm.load(address(asyncPromise), bytes32(uint256(103)));
//         assertEq(address(uint160(uint256(slotValue))), address(addressResolver));
//     }

//     function testDeliveryHelperSlot() public view {
//         bytes32 slotValue = vm.load(address(deliveryHelper), bytes32(uint256(50)));
//         assertEq(uint256(uint256(slotValue)), 0);

//         slotValue = vm.load(address(deliveryHelper), bytes32(uint256(109)));
//         assertEq(address(uint160(uint256(slotValue))), address(addressResolver));
//     }
// }
