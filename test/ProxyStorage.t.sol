// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./SetupTest.t.sol";

contract ProxyStorageAssertions is AppGatewayBaseSetup {
    uint256 public constant FIRST_SLOT = 50;
    uint256 public constant ADDRESS_RESOLVER_SLOT = 59;
    uint256 public constant WATCHER_SLOT = 52;

    function assertAddressResolverUtilSlot(uint256 slot_, address contract_) internal view {
        bytes32 slotValue = vm.load(address(contract_), bytes32(uint256(slot_)));
        assertEq(
            address(uint160(uint256(slotValue))),
            address(addressResolver),
            "address resolver mismatch"
        );
    }

    function assertAccessControlSlot(uint256 slot_, address contract_) internal {
        bytes32 role = keccak256("ADMIN_ROLE");
        address account = address(0xBEEF);
        bool value = true;

        // Compute the slot for _permits[role][account]
        bytes32 outerSlot = keccak256(abi.encode(role, uint256(slot_)));
        bytes32 mappingSlot = keccak256(abi.encode(account, outerSlot));

        // Store the value
        vm.store(address(contract_), mappingSlot, bytes32(uint256(value ? 1 : 0)));

        // Read back and assert
        bytes32 slotValue = vm.load(address(contract_), mappingSlot);
        assertEq(uint256(slotValue), value ? 1 : 0, "_permits mapping slot value mismatch");
    }

    function assertFeesManagerSlot() internal {
        // first
        bytes32 slotValue = vm.load(address(feesManager), bytes32(uint256(FIRST_SLOT)));
        assertEq(uint32(uint256(slotValue)), evmxSlug, "evmxSlug mismatch");

        // last
        hoax(watcherEOA);
        feesManager.setFeesPlug(evmxSlug, address(addressResolver));
        bytes32 mappingSlot = keccak256(abi.encode(uint256(evmxSlug), uint256(57)));
        slotValue = vm.load(address(feesManager), mappingSlot);
        assertEq(
            address(uint160(uint256(slotValue))),
            address(addressResolver),
            "fees plug mismatch"
        );

        // address resolver util slot
        assertAddressResolverUtilSlot(108, address(feesManager));
    }

    function assertAddressResolverSlot() internal {
        // first
        bytes32 slotValue = vm.load(address(addressResolver), bytes32(uint256(FIRST_SLOT)));
        assertEq(address(uint160(uint256(slotValue))), address(watcher), "watcher mismatch");

        // last
        hoax(watcherEOA);
        addressResolver.setContractAddress(keccak256("auctionManager"), address(auctionManager));
        bytes32 mappingSlot = keccak256(abi.encode(keccak256("auctionManager"), uint256(55)));
        slotValue = vm.load(address(addressResolver), mappingSlot);
        assertEq(
            address(uint160(uint256(slotValue))),
            address(auctionManager),
            "auctionManager mismatch"
        );
    }

    function assertAsyncDeployerSlot() internal {
        // first
        bytes32 slotValue = vm.load(address(asyncDeployer), bytes32(uint256(FIRST_SLOT)));
        assertEq(
            address(uint160(uint256(slotValue))),
            address(asyncDeployer.forwarderBeacon()),
            "forwarderBeacon mismatch"
        );

        // last
        hoax(address(watcher));
        asyncDeployer.deployAsyncPromiseContract(address(this), 1);
        slotValue = vm.load(address(asyncDeployer), bytes32(uint256(54)));
        assertEq(uint256(slotValue), 1, "asyncPromiseCounter mismatch");

        // address resolver util slot
        assertAddressResolverUtilSlot(105, address(asyncDeployer));
    }

    function assertWatcherSlot() internal {
        // first
        bytes32 slotValue = vm.load(address(watcher), bytes32(uint256(FIRST_SLOT)));
        assertEq(uint32(uint256(slotValue)), evmxSlug, "evmxSlug mismatch");

        // last
        uint256 nonce = watcherNonce;
        watcherMultiCall(
            address(writePrecompile),
            abi.encodeWithSelector(WritePrecompile.uploadProof.selector, bytes32(0), bytes32(0))
        );
        bytes32 mappingSlot = keccak256(abi.encode(uint256(nonce), uint256(59)));
        slotValue = vm.load(address(watcher), mappingSlot);
        assertEq(uint256(slotValue), 1, "isNonceUsed mismatch");

        // address resolver util slot
        assertAddressResolverUtilSlot(110, address(watcher));
    }

    function assertAuctionManagerSlot() internal {
        // first
        bytes32 slotValue = vm.load(address(auctionManager), bytes32(uint256(FIRST_SLOT)));
        assertEq(uint32(uint256(slotValue)), evmxSlug, "evmxSlug mismatch");

        // last
        uint40 requestCount = 1;
        uint256 reAuctionCount = 100;
        bytes32 mappingSlot = keccak256(abi.encode(uint256(requestCount), uint256(54)));
        vm.store(address(auctionManager), mappingSlot, bytes32(uint256(reAuctionCount)));
        slotValue = vm.load(address(auctionManager), mappingSlot);
        assertEq(uint256(slotValue), reAuctionCount, "reAuctionCount mismatch");

        // address resolver util slot
        assertAddressResolverUtilSlot(106, address(auctionManager));

        // access control slot
        assertAccessControlSlot(165, address(auctionManager));
    }

    function assertDeployForwarderSlot() internal view {
        // address resolver util slot
        assertAddressResolverUtilSlot(0, address(deployForwarder));

        // first
        bytes32 slotValue = vm.load(address(deployForwarder), bytes32(uint256(100)));
        assertEq(uint32(uint256(slotValue)), 0, "saltCounter mismatch");

        slotValue = vm.load(address(deployForwarder), bytes32(uint256(101)));
        assertEq(bytes32(slotValue), FAST, "deployerSwitchboardType mismatch");
    }

    function assertConfigurationsSlot() internal {
        // first
        uint32 chainSlug = 123;
        address plug = address(0xBEEF);
        uint256 testValue = 42;
        // Compute the slot for _plugConfigs[chainSlug][plug]
        bytes32 outerSlot = keccak256(abi.encode(uint256(chainSlug), uint256(50)));
        bytes32 mappingSlot = keccak256(abi.encode(plug, outerSlot));
        vm.store(address(configurations), mappingSlot, bytes32(testValue));
        bytes32 slotValue = vm.load(address(configurations), mappingSlot);
        assertEq(uint256(slotValue), testValue, "_plugConfigs mapping slot value mismatch");

        // last
        address appGateway = address(0xCAFE);
        bool value = true;
        // Compute the slot for isValidPlug[appGateway][chainSlug][plug]
        bytes32 outerSlot1 = keccak256(abi.encode(appGateway, uint256(53)));
        bytes32 outerSlot2 = keccak256(abi.encode(uint256(chainSlug), outerSlot1));
        mappingSlot = keccak256(abi.encode(plug, outerSlot2));
        vm.store(address(configurations), mappingSlot, bytes32(uint256(value ? 1 : 0)));
        slotValue = vm.load(address(configurations), mappingSlot);
        assertEq(uint256(slotValue), value ? 1 : 0, "isValidPlug mapping slot value mismatch");

        // watcher base slot
        slotValue = vm.load(address(configurations), bytes32(uint256(104)));
        assertEq(address(uint160(uint256(slotValue))), address(watcher), "watcher mismatch");
    }

    function assertRequestHandlerSlot() internal {
        // first
        bytes32 slotValue = vm.load(address(requestHandler), bytes32(uint256(FIRST_SLOT)));
        assertEq(
            uint40(uint256(slotValue)),
            requestHandler.nextRequestCount(),
            "nextRequestCount mismatch"
        );

        // last
        uint40 requestCount = 1;
        uint256 testValue = 42;
        // Compute the slot for _requests[requestCount]
        bytes32 mappingSlot = keccak256(abi.encode(uint256(requestCount), uint256(55)));
        vm.store(address(requestHandler), mappingSlot, bytes32(testValue));
        slotValue = vm.load(address(requestHandler), mappingSlot);
        assertEq(uint256(slotValue), testValue, "_requests mapping slot value mismatch");

        // address resolver util slot
        assertAddressResolverUtilSlot(106, address(requestHandler));
    }

    function assertWritePrecompileSlot() internal view {
        // first
        bytes32 slotValue = vm.load(address(writePrecompile), bytes32(uint256(FIRST_SLOT)));
        assertEq(uint256(slotValue), writeFees, "writeFees mismatch");

        // last
        bytes32 mappingSlot = keccak256(abi.encode(uint256(arbChainSlug), uint256(55)));
        slotValue = vm.load(address(writePrecompile), mappingSlot);
        assertEq(
            address(uint160(uint256(slotValue))),
            address(arbConfig.contractFactoryPlug),
            "contractFactoryPlugs mismatch"
        );

        // watcher base slot
        slotValue = vm.load(address(writePrecompile), bytes32(uint256(106)));
        assertEq(address(uint160(uint256(slotValue))), address(watcher), "watcher mismatch");
    }

    function assertForwarderSlot() internal {
        address forwarder = asyncDeployer.getOrDeployForwarderContract(address(this), evmxSlug);

        // first
        bytes32 slotValue = vm.load(address(forwarder), bytes32(uint256(FIRST_SLOT)));
        assertEq(uint32(uint256(slotValue)), evmxSlug);

        assertAddressResolverUtilSlot(101, address(forwarder));
    }

    function assertAsyncPromiseSlot() internal {
        hoax(address(watcher));
        address asyncPromise = asyncDeployer.deployAsyncPromiseContract(address(this), 100);

        // first
        bytes32 slotValue = vm.load(address(asyncPromise), bytes32(uint256(FIRST_SLOT)));
        assertEq(
            bytes4(bytes32(slotValue)),
            bytes4(AsyncPromise(asyncPromise).callbackSelector()),
            "callbackSelector mismatch"
        );

        // last
        slotValue = vm.load(address(asyncPromise), bytes32(uint256(52)));
        assertEq(
            bytes32(slotValue),
            bytes32(AsyncPromise(asyncPromise).callbackData()),
            "callbackData mismatch"
        );

        // address resolver util slot
        assertAddressResolverUtilSlot(103, address(asyncPromise));
    }
}

contract ProxyTest is ProxyStorageAssertions {
    function setUp() public {
        deploy();
    }

    function testFeesManagerSlot() public {
        assertFeesManagerSlot();
    }

    function testAddressResolverSlot() public {
        assertAddressResolverSlot();
    }

    function testAsyncDeployerSlot() public {
        assertAsyncDeployerSlot();
    }

    function testWatcherSlot() public {
        assertWatcherSlot();
    }

    function testAuctionManagerSlot() public {
        assertAuctionManagerSlot();
    }

    function testDeployForwarderSlot() public view {
        assertDeployForwarderSlot();
    }

    function testConfigurationsSlot() public {
        assertConfigurationsSlot();
    }

    function testRequestHandlerSlot() public {
        assertRequestHandlerSlot();
    }

    function testWritePrecompileSlot() public view {
        assertWritePrecompileSlot();
    }

    function testForwarderSlot() public {
        assertForwarderSlot();
    }

    function testAsyncPromiseSlot() public {
        assertAsyncPromiseSlot();
    }
}
