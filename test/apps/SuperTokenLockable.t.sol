// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenLockableAppGateway} from "./app-gateways/super-token-lockable/SuperTokenLockableAppGateway.sol";
import {SuperTokenLockable} from "./app-gateways/super-token-lockable/SuperTokenLockable.sol";
import {LimitHook} from "./app-gateways/super-token-lockable/LimitHook.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../../contracts/protocol/utils/common/Constants.sol";

import "../DeliveryHelper.t.sol";

contract SuperTokenLockableTest is DeliveryHelperTest {
    struct AppContracts {
        SuperTokenLockableAppGateway superTokenLockableApp;
        bytes32 superTokenLockable;
        bytes32 limitHook;
    }
    AppContracts appContracts;
    bytes32[] contractIds = new bytes32[](2);

    uint256 srcAmount = 0.01 ether;
    SuperTokenLockableAppGateway.UserOrder userOrder;

    function setUp() public {
        // core
        setUpDeliveryHelper();

        // app specific
        deploySuperTokenApp();

        contractIds[0] = appContracts.superTokenLockable;
        contractIds[1] = appContracts.limitHook;
    }

    function deploySuperTokenApp() internal {
        SuperTokenLockableAppGateway superTokenLockableApp = new SuperTokenLockableAppGateway(
            address(addressResolver),
            owner,
            createFees(maxFees),
            SuperTokenLockableAppGateway.ConstructorParams({
                _burnLimit: 10000000000000000000000,
                _mintLimit: 10000000000000000000000,
                name_: "SUPER TOKEN",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000 ether
            })
        );
        depositFees(address(superTokenLockableApp), createFees(1 ether));

        appContracts = AppContracts({
            superTokenLockableApp: superTokenLockableApp,
            superTokenLockable: superTokenLockableApp.superTokenLockable(),
            limitHook: superTokenLockableApp.limitHook()
        });
    }

    function createDeployPayloadDetailsArray(
        uint32 chainSlug_
    ) internal returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](2);
        payloadDetails[0] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.superTokenLockableApp),
            appContracts.superTokenLockableApp.creationCodeWithArgs(appContracts.superTokenLockable)
        );
        payloadDetails[1] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.superTokenLockableApp),
            appContracts.superTokenLockableApp.creationCodeWithArgs(appContracts.limitHook)
        );

        return payloadDetails;
    }

    function createConfigurePayloadDetailsArray(
        uint32 chainSlug_
    ) internal returns (PayloadDetails[] memory) {
        address superTokenForwarder = appContracts.superTokenLockableApp.forwarderAddresses(
            appContracts.superTokenLockable,
            chainSlug_
        );
        address limitHookForwarder = appContracts.superTokenLockableApp.forwarderAddresses(
            appContracts.limitHook,
            chainSlug_
        );

        address deployedToken = IForwarder(superTokenForwarder).getOnChainAddress();
        address deployedLimitHook = IForwarder(limitHookForwarder).getOnChainAddress();

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createExecutePayloadDetail(
            chainSlug_,
            deployedToken,
            address(appContracts.superTokenLockableApp),
            superTokenForwarder,
            abi.encodeWithSignature("setLimitHook(address)", deployedLimitHook)
        );

        return payloadDetails;
    }

    function testPredictForwarderAddress() external {
        address appDeployer = address(uint160(c++));
        address chainContractAddress = address(uint160(c++));

        address predicted = addressResolver.getForwarderAddress(chainContractAddress, evmxSlug);
        address forwarder = addressResolver.getOrDeployForwarderContract(
            appDeployer,
            chainContractAddress,
            evmxSlug
        );

        assertEq(forwarder, predicted);
    }

    function testPredictPromiseAddress() external {
        address invoker = address(uint160(c++));

        address predicted = addressResolver.getAsyncPromiseAddress(invoker);
        address asyncPromise = addressResolver.deployAsyncPromiseContract(invoker);

        assertEq(asyncPromise, predicted);
    }

    function testContractDeployment() public {
        bytes32 asyncId = _deploy(
            contractIds,
            arbChainSlug,
            2,
            IAppGateway(appContracts.superTokenLockableApp)
        );

        (address onChainSuperToken, address forwarderSuperToken) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superTokenLockable,
            IAppGateway(appContracts.superTokenLockableApp)
        );

        (address onChainLimitHook, address forwarderLimitHook) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.limitHook,
            IAppGateway(appContracts.superTokenLockableApp)
        );

        assertEq(
            SuperTokenLockable(onChainSuperToken).name(),
            "SUPER TOKEN",
            "Token name should be correct"
        );
        assertEq(
            SuperTokenLockable(onChainSuperToken).decimals(),
            18,
            "Token decimals should be correct"
        );
        assertEq(
            SuperTokenLockable(onChainSuperToken).symbol(),
            "SUPER",
            "Token symbol should be correct"
        );

        assertEq(
            IForwarder(forwarderSuperToken).getChainSlug(),
            arbChainSlug,
            "Forwarder chainSlug should be correct"
        );
        assertEq(
            IForwarder(forwarderSuperToken).getOnChainAddress(),
            onChainSuperToken,
            "Forwarder onChainAddress should be correct"
        );

        assertEq(
            IForwarder(forwarderLimitHook).getChainSlug(),
            arbChainSlug,
            "Forwarder chainSlug should be correct"
        );
        assertEq(
            IForwarder(forwarderLimitHook).getOnChainAddress(),
            onChainLimitHook,
            "Forwarder onChainAddress should be correct"
        );
        assertEq(
            SuperTokenLockable(onChainSuperToken).owner(),
            owner,
            "SuperToken owner should be correct"
        );
        assertEq(LimitHook(onChainLimitHook).owner(), owner, "LimitHook owner should be correct");

        PayloadDetails[] memory payloadDetails = createDeployPayloadDetailsArray(arbChainSlug);
        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenLockableApp)
        );
    }

    function testConfigure() public {
        _deploy(contractIds, arbChainSlug, 2, IAppGateway(appContracts.superTokenLockableApp));

        bytes32 asyncId = _executeWriteBatchSingleChain(arbChainSlug, 1);

        (address onChainSuperToken, ) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superTokenLockable,
            IAppGateway(appContracts.superTokenLockableApp)
        );
        (address onChainLimitHook, ) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.limitHook,
            IAppGateway(appContracts.superTokenLockableApp)
        );
        assertEq(
            address(SuperTokenLockable(onChainSuperToken).limitHook__()),
            address(onChainLimitHook),
            "Limit hook should be correct"
        );

        PayloadDetails[] memory payloadDetails = createConfigurePayloadDetailsArray(arbChainSlug);
        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenLockableApp)
        );
    }

    function _deployBridge() internal {
        _deploy(contractIds, arbChainSlug, 2, IAppGateway(appContracts.superTokenLockableApp));

        _executeWriteBatchSingleChain(arbChainSlug, 1);

        _deploy(contractIds, optChainSlug, 2, IAppGateway(appContracts.superTokenLockableApp));

        _executeWriteBatchSingleChain(optChainSlug, 1);
    }

    function _bridge() internal returns (bytes32, bytes32[] memory) {
        _deployBridge();

        userOrder = SuperTokenLockableAppGateway.UserOrder({
            srcToken: appContracts.superTokenLockableApp.forwarderAddresses(
                appContracts.superTokenLockable,
                arbChainSlug
            ),
            dstToken: appContracts.superTokenLockableApp.forwarderAddresses(
                appContracts.superTokenLockable,
                optChainSlug
            ),
            user: owner, // 2 account anvil
            srcAmount: srcAmount, // .01 ETH in wei
            deadline: 1672531199 // Unix timestamp for a future date
        });
        uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();
        uint32 dstChainSlug = IForwarder(userOrder.dstToken).getChainSlug();
        bytes32 bridgeAsyncId = getNextAsyncId();

        bytes32[] memory payloadIds = new bytes32[](4);
        payloadIds[0] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            payloadIdCounter++
        );
        payloadIds[1] = _encodeId(evmxSlug, address(watcherPrecompile), payloadIdCounter++);
        payloadIds[2] = getWritePayloadId(
            dstChainSlug,
            address(getSocketConfig(dstChainSlug).switchboard),
            payloadIdCounter++
        );
        payloadIds[3] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            payloadIdCounter++
        );
        payloadIdCounter++;

        bytes memory encodedOrder = abi.encode(userOrder);
        appContracts.superTokenLockableApp.bridge(encodedOrder);
        bidAndEndAuction(bridgeAsyncId);
        return (bridgeAsyncId, payloadIds);
    }

    function testBridge() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();

        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadIndexDetails(
            bridgeAsyncId,
            0
        );
        finalizeAndExecute(payloadIds[0]);

        payloadDetails = deliveryHelper.getPayloadIndexDetails(bridgeAsyncId, 2);
        vm.expectEmit(true, false, false, false);
        emit FinalizeRequested(
            payloadIds[2],
            AsyncRequest(
                address(deliveryHelper),
                address(0),
                transmitterEOA,
                payloadDetails.target,
                address(0),
                payloadDetails.executionGasLimit,
                0,
                bridgeAsyncId,
                bytes32(0),
                payloadDetails.payload,
                payloadDetails.next
            )
        );
        finalizeQuery(payloadIds[1], abi.encode(srcAmount));
        finalizeAndExecute(payloadIds[2]);

        payloadDetails = deliveryHelper.getPayloadIndexDetails(bridgeAsyncId, 3);
        finalizeAndExecute(payloadIds[3]);
    }

    function testCancel() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();

        finalizeAndExecute(payloadIds[0]);

        vm.expectEmit(true, true, false, true);
        emit BatchCancelled(bridgeAsyncId);
        finalizeQuery(payloadIds[1], abi.encode(0.001 ether));

        bytes32[] memory cancelPayloadIds = new bytes32[](1);
        uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();

        cancelPayloadIds[0] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            payloadIdCounter++
        );

        // bytes32 cancelAsyncId = getNextAsyncId();
        // bidAndEndAuction(cancelAsyncId);
        // finalizeAndExecute(
        //     cancelPayloadIds[0],
        //     false
        // );
    }

    //   function createBridgePayloadDetailsArray(
    //     uint32 srcChainSlug_,
    //     uint32 dstChainSlug_
    // ) internal returns (PayloadDetails[] memory) {
    //     PayloadDetails[] memory payloadDetails = new PayloadDetails[](4);

    //     address deployedSrcToken = IForwarder(userOrder.srcToken)
    //         .getOnChainAddress();
    //     address deployedDstToken = IForwarder(userOrder.dstToken)
    //         .getOnChainAddress();

    //     payloadDetails[0] = createExecutePayloadDetail(
    //         srcChainSlug_,
    //         deployedSrcToken,
    //         address(appContracts.superTokenApp),
    //         userOrder.srcToken,
    //         abi.encodeWithSignature(
    //             "lockTokens(address,uint256)",
    //             userOrder.user,
    //             userOrder.srcAmount
    //         )
    //     );

    //     payloadDetails[1] = createReadPayloadDetail(
    //         srcChainSlug_,
    //         deployedSrcToken,
    //         address(appContracts.superTokenApp),
    //         userOrder.srcToken,
    //         abi.encodeWithSignature("balanceOf(address)", userOrder.user)
    //     );

    //     payloadDetails[2] = createExecutePayloadDetail(
    //         dstChainSlug_,
    //         deployedDstToken,
    //         address(appContracts.superTokenApp),
    //         userOrder.dstToken,
    //         abi.encodeWithSignature(
    //             "mint(address,uint256)",
    //             userOrder.user,
    //             userOrder.srcAmount
    //         )
    //     );

    //     payloadDetails[3] = createExecutePayloadDetail(
    //         srcChainSlug_,
    //         deployedSrcToken,
    //         address(appContracts.superTokenApp),
    //         userOrder.srcToken,
    //         abi.encodeWithSignature(
    //             "burn(address,uint256)",
    //             userOrder.user,
    //             userOrder.srcAmount
    //         )
    //     );

    //     for (uint i = 0; i < payloadDetails.length; i++) {
    //         payloadDetails[i].next[1] = predictAsyncPromiseAddress(
    //             address(deliveryHelper),
    //             address(deliveryHelper)
    //         );
    //     }

    //     return payloadDetails;
    // }

    // function createCancelPayloadDetailsArray(
    //     uint32 srcChainSlug_
    // ) internal returns (PayloadDetails[] memory) {
    //     PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);

    //     address deployedSrcToken = IForwarder(userOrder.srcToken)
    //         .getOnChainAddress();

    //     payloadDetails[0] = createExecutePayloadDetail(
    //         srcChainSlug_,
    //         deployedSrcToken,
    //         address(appContracts.superTokenApp),
    //         userOrder.srcToken,
    //         abi.encodeWithSignature(
    //             "unlockTokens(address,uint256)",
    //             userOrder.user,
    //             userOrder.srcAmount
    //         )
    //     );

    //     payloadDetails[0].next[1] = predictAsyncPromiseAddress(
    //         address(deliveryHelper),
    //         address(deliveryHelper)
    //     );
    //     return payloadDetails;
    // }

    // function _deployBridge() internal {
    //     bytes32[] memory payloadIds = getWritePayloadIds(
    //         optChainSlug,
    //         getContractFactoryPlug(optChainSlug),
    //         2
    //     );
    //     PayloadDetails[]
    //         memory payloadDetails = createDeployPayloadDetailsArray(
    //             optChainSlug
    //         );
    //     _deploy(
    //         payloadIds,
    //         optChainSlug,
    //         maxFees,
    //         0,
    //         appContracts.superTokenDeployer,
    //         payloadDetails
    //     );

    //     payloadIds = getWritePayloadIds(
    //         optChainSlug,
    //         getContractFactoryPlug(optChainSlug),
    //         1
    //     );
    //     payloadDetails = createConfigurePayloadDetailsArray(optChainSlug);
    //     _executeBatchSingleChain(
    //         payloadIds
    //     );

    //     payloadIds = getWritePayloadIds(
    //         arbChainSlug,
    //         getContractFactoryPlug(arbChainSlug),
    //         2
    //     );

    //     payloadDetails = createDeployPayloadDetailsArray(arbChainSlug);
    //     _deploy(
    //         payloadIds,
    //         arbChainSlug,
    //         maxFees,
    //         0,
    //         appContracts.superTokenDeployer,
    //         payloadDetails
    //     );

    //     payloadIds = getWritePayloadIds(
    //         arbChainSlug,
    //         getContractFactoryPlug(arbChainSlug),
    //         1
    //     );
    //     payloadDetails = createConfigurePayloadDetailsArray(arbChainSlug);
    //     _executeBatchSingleChain(
    //         payloadIds
    //     );
    // }

    // function _bridge()
    //     internal
    //     returns (bytes32, bytes32[] memory, PayloadDetails[] memory)
    // {
    //     _deployBridge();

    //     userOrder = SuperTokenApp.UserOrder({
    //         srcToken: appContracts.superTokenDeployer.forwarderAddresses(
    //             appContracts.superToken,
    //             arbChainSlug
    //         ),
    //         dstToken: appContracts.superTokenDeployer.forwarderAddresses(
    //             appContracts.superToken,
    //             optChainSlug
    //         ),
    //         user: owner, // 2 account anvil
    //         srcAmount: srcAmount, // .01 ETH in wei
    //         deadline: 1672531199 // Unix timestamp for a future date
    //     });
    //     uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();
    //     uint32 dstChainSlug = IForwarder(userOrder.dstToken).getChainSlug();

    //     bytes32[] memory payloadIds = new bytes32[](4);
    //     payloadIds[0] = getWritePayloadId(
    //         srcChainSlug,
    //         address(getSocketConfig(srcChainSlug).contractFactoryPlug),
    //         payloadIdCounter++
    //     );
    //     payloadIds[1] = _encodeId(evmxSlug, address(watcherPrecompile), payloadIdCounter++);
    //     payloadIds[2] = getWritePayloadId(
    //         dstChainSlug,
    //         address(getSocketConfig(dstChainSlug).contractFactoryPlug),
    //         payloadIdCounter++
    //     );
    //     payloadIds[3] = getWritePayloadId(
    //         srcChainSlug,
    //         address(getSocketConfig(srcChainSlug).contractFactoryPlug),
    //         payloadIdCounter++
    //     );
    //     payloadIdCounter++;

    //     PayloadDetails[]
    //         memory payloadDetails = createBridgePayloadDetailsArray(
    //             srcChainSlug,
    //             dstChainSlug
    //         );
    //     bytes32 bridgeAsyncId = getNextAsyncId();
    //     asyncCounterTest++;

    //     bytes memory encodedOrder = abi.encode(userOrder);
    //     appContracts.superTokenApp.bridge(encodedOrder);
    //     bidAndValidate(
    //         maxFees,
    //         0,
    //         bridgeAsyncId,
    //         address(appContracts.superTokenApp),
    //         payloadDetails
    //     );
    //     return (bridgeAsyncId, payloadIds, payloadDetails);
    // }

    // function testBridge() public {
    //     (
    //         bytes32 bridgeAsyncId,
    //         bytes32[] memory payloadIds,
    //         PayloadDetails[] memory payloadDetails
    //     ) = _bridge();

    //     finalizeAndExecute(
    //         payloadIds[0],
    //         false,
    //         payloadDetails[0]
    //     );

    //     vm.expectEmit(true, false, false, false);
    //     emit FinalizeRequested(
    //         payloadIds[2],
    //         AsyncRequest(
    //             payloadDetails[2].next,
    //             address(0),
    //             transmitterEOA,
    //             payloadDetails[2].executionGasLimit,
    //             payloadDetails[2].payload,
    //             address(0),
    //             bytes32(0)
    //         )
    //     );
    //     finalizeQuery(payloadIds[1], abi.encode(srcAmount));
    //     finalizeAndExecute(
    //         payloadIds[2],
    //         false,
    //         payloadDetails[2]
    //     );
    //     finalizeAndExecute(
    //         payloadIds[3],
    //         false,
    //         payloadDetails[3]
    //     );
    // }

    // function testCancel() public {
    //     (
    //         bytes32 bridgeAsyncId,
    //         bytes32[] memory payloadIds,
    //         PayloadDetails[] memory payloadDetails
    //     ) = _bridge();

    //     finalizeAndExecute(
    //         payloadIds[0],
    //         false,
    //         payloadDetails[0]
    //     );

    //     vm.expectEmit(true, true, false, true);
    //     emit BatchCancelled(bridgeAsyncId);
    //     finalizeQuery(payloadIds[1], abi.encode(0.001 ether));

    //     bytes32[] memory cancelPayloadIds = new bytes32[](1);
    //     uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();

    //     cancelPayloadIds[0] = getWritePayloadId(
    //         srcChainSlug,
    //         address(getSocketConfig(srcChainSlug).contractFactoryPlug),
    //         payloadIdCounter++
    //     );

    //     PayloadDetails[]
    //         memory cancelPayloadDetails = createCancelPayloadDetailsArray(
    //             srcChainSlug
    //         );

    //     bytes32 cancelAsyncId = getNextAsyncId();
    //     asyncCounterTest++;

    //     bidAndValidate(
    //         maxFees,
    //         0,
    //         cancelAsyncId,
    //         address(appContracts.superTokenApp),
    //         cancelPayloadDetails
    //     );
    //     finalizeAndExecute(
    //         cancelPayloadIds[0],
    //         false,
    //         cancelPayloadDetails[0]
    //     );
    // }
}
