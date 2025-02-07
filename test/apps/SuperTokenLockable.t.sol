// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenLockableDeployer} from "../../contracts/apps/super-token-lockable/SuperTokenLockableDeployer.sol";
import {SuperTokenLockableAppGateway} from "../../contracts/apps/super-token-lockable/SuperTokenLockableAppGateway.sol";
import {SuperTokenLockable} from "../../contracts/apps/super-token-lockable/SuperTokenLockable.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../../contracts/common/Constants.sol";

import "../DeliveryHelper.t.sol";

contract SuperTokenLockableTest is DeliveryHelperTest {
    struct AppContracts {
        SuperTokenLockableAppGateway superTokenLockableApp;
        SuperTokenLockableDeployer superTokenLockableDeployer;
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
        SuperTokenLockableDeployer superTokenLockableDeployer = new SuperTokenLockableDeployer(
            address(addressResolver),
            owner,
            address(auctionManager),
            FAST,
            SuperTokenLockableDeployer.ConstructorParams({
                _burnLimit: 10000000000000000000000,
                _mintLimit: 10000000000000000000000,
                name_: "SUPER TOKEN",
                symbol_: "SUPER",
                decimals_: 18,
                initialSupplyHolder_: owner,
                initialSupply_: 1000000000 ether
            }),
            createFees(maxFees)
        );
        SuperTokenLockableAppGateway superTokenLockableApp = new SuperTokenLockableAppGateway(
            address(addressResolver),
            address(superTokenLockableDeployer),
            address(auctionManager),
            createFees(maxFees)
        );
        depositFees(address(superTokenLockableApp), createFees(1 ether));

        appContracts = AppContracts({
            superTokenLockableApp: superTokenLockableApp,
            superTokenLockableDeployer: superTokenLockableDeployer,
            superTokenLockable: superTokenLockableDeployer.superTokenLockable(),
            limitHook: superTokenLockableDeployer.limitHook()
        });
    }

    function createDeployPayloadDetailsArray(
        uint32 chainSlug_
    ) internal returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](2);
        payloadDetails[0] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.superTokenLockableDeployer),
            appContracts.superTokenLockableDeployer.creationCodeWithArgs(
                appContracts.superTokenLockable
            )
        );
        payloadDetails[1] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.superTokenLockableDeployer),
            appContracts.superTokenLockableDeployer.creationCodeWithArgs(appContracts.limitHook)
        );

        return payloadDetails;
    }

    function createConfigurePayloadDetailsArray(
        uint32 chainSlug_
    ) internal returns (PayloadDetails[] memory) {
        address superTokenForwarder = appContracts.superTokenLockableDeployer.forwarderAddresses(
            appContracts.superTokenLockable,
            chainSlug_
        );
        address limitHookForwarder = appContracts.superTokenLockableDeployer.forwarderAddresses(
            appContracts.limitHook,
            chainSlug_
        );

        address deployedToken = IForwarder(superTokenForwarder).getOnChainAddress();
        address deployedLimitHook = IForwarder(limitHookForwarder).getOnChainAddress();

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createExecutePayloadDetail(
            chainSlug_,
            deployedToken,
            address(appContracts.superTokenLockableDeployer),
            superTokenForwarder,
            abi.encodeWithSignature("setLimitHook(address)", deployedLimitHook)
        );

        return payloadDetails;
    }

    function testPredictForwarderAddress() external {
        address appDeployer = address(uint160(c++));
        address chainContractAddress = address(uint160(c++));

        address forwarder = addressResolver.getOrDeployForwarderContract(
            appDeployer,
            chainContractAddress,
            vmChainSlug
        );
        address predicted = addressResolver.getForwarderAddress(chainContractAddress, vmChainSlug);

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
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        (address onChainSuperToken, address forwarderSuperToken) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superTokenLockable,
            appContracts.superTokenLockableDeployer
        );

        (address onChainLimitHook, address forwarderLimitHook) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.limitHook,
            appContracts.superTokenLockableDeployer
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

        PayloadDetails[] memory payloadDetails = createDeployPayloadDetailsArray(arbChainSlug);
        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenLockableDeployer)
        );
    }

    function testConfigure() public {
        _deploy(
            contractIds,
            arbChainSlug,
            2,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        bytes32 asyncId = _executeWriteBatchSingleChain(arbChainSlug, 1);

        (address onChainSuperToken, ) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.superTokenLockable,
            appContracts.superTokenLockableDeployer
        );
        (address onChainLimitHook, ) = getOnChainAndForwarderAddresses(
            arbChainSlug,
            appContracts.limitHook,
            appContracts.superTokenLockableDeployer
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
        _deploy(
            contractIds,
            arbChainSlug,
            2,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        _executeWriteBatchSingleChain(arbChainSlug, 1);

        _deploy(
            contractIds,
            optChainSlug,
            2,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        _executeWriteBatchSingleChain(optChainSlug, 1);
    }

    function _bridge() internal returns (bytes32, bytes32[] memory) {
        _deployBridge();

        userOrder = SuperTokenLockableAppGateway.UserOrder({
            srcToken: appContracts.superTokenLockableDeployer.forwarderAddresses(
                appContracts.superTokenLockable,
                arbChainSlug
            ),
            dstToken: appContracts.superTokenLockableDeployer.forwarderAddresses(
                appContracts.superTokenLockable,
                optChainSlug
            ),
            user: owner, // 2 account anvil
            srcAmount: srcAmount, // .01 ETH in wei
            deadline: 1672531199 // Unix timestamp for a future date
        });
        uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();
        uint32 dstChainSlug = IForwarder(userOrder.dstToken).getChainSlug();

        bytes32[] memory payloadIds = new bytes32[](4);
        payloadIds[0] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            writePayloadIdCounter++
        );
        payloadIds[1] = bytes32(readPayloadIdCounter++);
        payloadIds[2] = getWritePayloadId(
            dstChainSlug,
            address(getSocketConfig(dstChainSlug).switchboard),
            writePayloadIdCounter++
        );
        payloadIds[3] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            writePayloadIdCounter++
        );
        writePayloadIdCounter++;

        bytes32 bridgeAsyncId = getCurrentAsyncId();

        bytes memory encodedOrder = abi.encode(userOrder);
        appContracts.superTokenLockableApp.bridge(encodedOrder);
        bidAndEndAuction(bridgeAsyncId);
        return (bridgeAsyncId, payloadIds);
    }

    function testBridge() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();
        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(bridgeAsyncId, 0);

        finalizeAndExecute(payloadIds[0], false);

        payloadDetails = deliveryHelper.getPayloadDetails(bridgeAsyncId, 2);
        vm.expectEmit(true, false, false, false);
        emit FinalizeRequested(
            payloadIds[2],
            AsyncRequest(
                address(0),
                transmitterEOA,
                payloadDetails.target,
                address(0),
                payloadDetails.executionGasLimit,
                bytes32(0),
                payloadDetails.payload,
                payloadDetails.next
            )
        );
        finalizeQuery(payloadIds[1], abi.encode(srcAmount));
        finalizeAndExecute(payloadIds[2], false);

        payloadDetails = deliveryHelper.getPayloadDetails(bridgeAsyncId, 3);
        finalizeAndExecute(payloadIds[3], false);
    }

    function testCancel() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();

        finalizeAndExecute(payloadIds[0], false);

        vm.expectEmit(true, true, false, true);
        emit BatchCancelled(bridgeAsyncId);
        finalizeQuery(payloadIds[1], abi.encode(0.001 ether));

        bytes32[] memory cancelPayloadIds = new bytes32[](1);
        uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();

        cancelPayloadIds[0] = getWritePayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).switchboard),
            writePayloadIdCounter++
        );

        bytes32 cancelAsyncId = getCurrentAsyncId();

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
    //         writePayloadIdCounter++
    //     );
    //     payloadIds[1] = bytes32(readPayloadIdCounter++);
    //     payloadIds[2] = getWritePayloadId(
    //         dstChainSlug,
    //         address(getSocketConfig(dstChainSlug).contractFactoryPlug),
    //         writePayloadIdCounter++
    //     );
    //     payloadIds[3] = getWritePayloadId(
    //         srcChainSlug,
    //         address(getSocketConfig(srcChainSlug).contractFactoryPlug),
    //         writePayloadIdCounter++
    //     );
    //     writePayloadIdCounter++;

    //     PayloadDetails[]
    //         memory payloadDetails = createBridgePayloadDetailsArray(
    //             srcChainSlug,
    //             dstChainSlug
    //         );
    //     bytes32 bridgeAsyncId = getCurrentAsyncId();
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
    //         writePayloadIdCounter++
    //     );

    //     PayloadDetails[]
    //         memory cancelPayloadDetails = createCancelPayloadDetailsArray(
    //             srcChainSlug
    //         );

    //     bytes32 cancelAsyncId = getCurrentAsyncId();
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
