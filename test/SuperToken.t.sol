// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenLockableDeployer} from "../contracts/apps/super-token-lockable/SuperTokenLockableDeployer.sol";
import {SuperTokenLockableAppGateway} from "../contracts/apps/super-token-lockable/SuperTokenLockableAppGateway.sol";
import "./DeliveryHelper.t.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../contracts/common/Constants.sol";

contract SuperTokenTest is DeliveryHelperTest {
    struct AppContracts {
        SuperTokenLockableAppGateway superTokenLockableApp;
        SuperTokenLockableDeployer superTokenLockableDeployer;
        bytes32 superTokenLockable;
        bytes32 limitHook;
    }

    AppContracts appContracts;
    uint256 srcAmount = 0.01 ether;
    SuperTokenLockableAppGateway.UserOrder userOrder;

    bytes32[] contractIds = new bytes32[](2);

    event BatchCancelled(bytes32 indexed asyncId);
    event FinalizeRequested(
        bytes32 indexed payloadId,
        AsyncRequest asyncRequest
    );
    event QueryRequested(
        uint32 chainSlug,
        address targetAddress,
        bytes32 payloadId,
        bytes payload
    );

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
            createFeesData(maxFees)
        );
        SuperTokenLockableAppGateway superTokenLockableApp = new SuperTokenLockableAppGateway(
            address(addressResolver),
            address(superTokenLockableDeployer),
            createFeesData(maxFees),
            address(auctionManager)
        );

        appContracts = AppContracts({
            superTokenLockableApp: superTokenLockableApp,
            superTokenLockableDeployer: superTokenLockableDeployer,
            superTokenLockable: superTokenLockableDeployer.superTokenLockable(),
            limitHook: superTokenLockableDeployer.limitHook()
        });

        UpdateLimitParams[] memory params = new UpdateLimitParams[](3);
        params[0] = UpdateLimitParams({
            limitType: QUERY,
            appGateway: address(appContracts.superTokenLockableApp),
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });
        params[1] = UpdateLimitParams({
            limitType: SCHEDULE,
            appGateway: address(appContracts.superTokenLockableApp),
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });
        params[2] = UpdateLimitParams({
            limitType: FINALIZE,
            appGateway: address(appContracts.superTokenLockableApp),
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });

        hoax(watcherEOA);
        watcherPrecompile.updateLimitParams(params);

        skip(100);
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
            appContracts.superTokenLockableDeployer.creationCodeWithArgs(
                appContracts.limitHook
            )
        );

        return payloadDetails;
    }

    function createConfigurePayloadDetailsArray(
        uint32 chainSlug_
    ) internal returns (PayloadDetails[] memory) {
        address superTokenForwarder = appContracts
            .superTokenLockableDeployer
            .forwarderAddresses(appContracts.superTokenLockable, chainSlug_);
        address limitHookForwarder = appContracts
            .superTokenLockableDeployer
            .forwarderAddresses(appContracts.limitHook, chainSlug_);

        address deployedToken = IForwarder(superTokenForwarder)
            .getOnChainAddress();

        address deployedLimitHook = IForwarder(limitHookForwarder)
            .getOnChainAddress();

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

    function testContractDeployment() public {
        bytes32[] memory payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            2
        );
        PayloadDetails[]
            memory payloadDetails = createDeployPayloadDetailsArray(
                arbChainSlug
            );

        bytes32 asyncId = _deploy(
            contractIds,
            payloadIds,
            arbChainSlug,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenLockableDeployer)
        );
    }

    function testConfigure() public {
        writePayloadIdCounter = 0;
        bytes32[] memory payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            2
        );
        _deploy(
            contractIds,
            payloadIds,
            arbChainSlug,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            1
        );

        PayloadDetails[]
            memory payloadDetails = createConfigurePayloadDetailsArray(
                arbChainSlug
            );
        bytes32 asyncId = _configure(payloadIds);

        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenLockableApp)
        );
    }

    function beforeBridge() internal {
        writePayloadIdCounter = 0;
        bytes32[] memory payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            2
        );
        _deploy(
            contractIds,
            payloadIds,
            arbChainSlug,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            1
        );
        _configure(payloadIds);

        payloadIds = getWritePayloadIds(
            optChainSlug,
            address(optConfig.switchboard),
            2
        );
        _deploy(
            contractIds,
            payloadIds,
            optChainSlug,
            appContracts.superTokenLockableDeployer,
            address(appContracts.superTokenLockableApp)
        );

        payloadIds = getWritePayloadIds(
            optChainSlug,
            address(optConfig.switchboard),
            1
        );
        _configure(payloadIds);
    }

    function _bridge() internal returns (bytes32, bytes32[] memory) {
        beforeBridge();

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
        asyncCounterTest++;

        bytes memory encodedOrder = abi.encode(userOrder);
        appContracts.superTokenLockableApp.bridge(encodedOrder);
        bidAndEndAuction(bridgeAsyncId);
        return (bridgeAsyncId, payloadIds);
    }

    function testBridge() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();
        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(
            bridgeAsyncId,
            0
        );

        finalizeAndExecute(bridgeAsyncId, payloadIds[0], false);

        payloadDetails = deliveryHelper.getPayloadDetails(bridgeAsyncId, 2);
        vm.expectEmit(true, false, false, false);
        emit FinalizeRequested(
            payloadIds[2],
            AsyncRequest(
                payloadDetails.next,
                address(0),
                transmitterEOA,
                payloadDetails.target,
                payloadDetails.executionGasLimit,
                payloadDetails.payload,
                address(0),
                bytes32(0)
            )
        );
        finalizeQuery(payloadIds[1], abi.encode(srcAmount));
        finalizeAndExecute(bridgeAsyncId, payloadIds[2], false);

        payloadDetails = deliveryHelper.getPayloadDetails(bridgeAsyncId, 3);
        finalizeAndExecute(bridgeAsyncId, payloadIds[3], false);
    }

    function testCancel() public {
        (bytes32 bridgeAsyncId, bytes32[] memory payloadIds) = _bridge();

        finalizeAndExecute(bridgeAsyncId, payloadIds[0], false);

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
        asyncCounterTest++;

        bidAndEndAuction(cancelAsyncId);
        // finalizeAndExecute(
        //     cancelAsyncId,
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

    // function beforeBridge() internal {
    //     writePayloadIdCounter = 0;
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
    //     _configure(
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
    //     _configure(
    //         payloadIds
    //     );
    // }

    // function _bridge()
    //     internal
    //     returns (bytes32, bytes32[] memory, PayloadDetails[] memory)
    // {
    //     beforeBridge();

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
    //         bridgeAsyncId,
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
    //         bridgeAsyncId,
    //         payloadIds[2],
    //         false,
    //         payloadDetails[2]
    //     );
    //     finalizeAndExecute(
    //         bridgeAsyncId,
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
    //         bridgeAsyncId,
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
    //         cancelAsyncId,
    //         cancelPayloadIds[0],
    //         false,
    //         cancelPayloadDetails[0]
    //     );
    // }

    // function testWithdrawTo() public {
    //     uint32 chainSlug = arbChainSlug;
    //     address token = ETH_ADDRESS;
    //     uint256 depositAmount = 1 ether;
    //     uint256 withdrawAmount = 0.1 ether;
    //     address appGateway = address(appContracts.superTokenApp);
    //     address receiver = address(uint160(c++));

    //     SocketContracts memory socketConfig = getSocketConfig(chainSlug);
    //     socketConfig.feesPlug.deposit{value: depositAmount}(
    //         token,
    //         depositAmount,
    //         appGateway
    //     );
    //     assertEq(
    //         depositAmount,
    //         socketConfig.feesPlug.balanceOf(appGateway, token),
    //         "Balance should be correct"
    //     );

    //     appContracts.superTokenApp.withdrawFeeTokens(
    //         chainSlug,
    //         token,
    //         withdrawAmount,
    //         receiver
    //     );

    //     bytes32[] memory withdrawPayloadIds = new bytes32[](1);
    //     withdrawPayloadIds[0] = getWritePayloadId(
    //         chainSlug,
    //         address(getSocketConfig(chainSlug).contractFactoryPlug),
    //         writePayloadIdCounter++
    //     );
    //     bytes32 withdrawAsyncId = getCurrentAsyncId();
    //     asyncCounterTest++;

    //     bytes memory withdrawPayload = abi.encode(
    //         WITHDRAW,
    //         abi.encode(appGateway, token, withdrawAmount, receiver)
    //     );

    //     PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
    //     payloadDetails[0] = PayloadDetails({
    //         chainSlug: chainSlug,
    //         target: address(getSocketConfig(chainSlug).contractFactoryPlug),
    //         payload: withdrawPayload,
    //         callType: CallType.WITHDRAW,
    //         executionGasLimit: 0,
    //         next: new address[](2),
    //         isSequential: false
    //     });

    //     payloadDetails[0].next[1] = predictAsyncPromiseAddress(
    //         address(deliveryHelper),
    //         address(deliveryHelper)
    //     );

    //     bidAndValidate(
    //         maxFees,
    //         0,
    //         withdrawAsyncId,
    //         address(appContracts.superTokenApp),
    //         payloadDetails
    //     );
    //     finalizeAndExecute(
    //         withdrawAsyncId,
    //         withdrawPayloadIds[0],
    //         true,
    //         payloadDetails[0]
    //     );
    // }
}
