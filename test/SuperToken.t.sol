// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SuperTokenDeployer} from "../contracts/apps/super-token/SuperTokenDeployer.sol";
import {SuperTokenAppGateway} from "../contracts/apps/super-token/SuperTokenAppGateway.sol";
import "./DeliveryHelper.t.sol";
import {QUERY, FINALIZE, SCHEDULE} from "../contracts/common/Constants.sol";

contract SuperTokenTest is DeliveryHelperTest {
    struct AppContracts {
        SuperTokenAppGateway superTokenApp;
        SuperTokenDeployer superTokenDeployer;
        bytes32 superToken;
        bytes32 limitHook;
    }

    AppContracts appContracts;
    uint256 srcAmount = 0.01 ether;
    SuperTokenAppGateway.UserOrder userOrder;

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

        contractIds[0] = appContracts.superToken;
        contractIds[1] = appContracts.limitHook;
    }

    function deploySuperTokenApp() internal {
        SuperTokenDeployer superTokenDeployer = new SuperTokenDeployer(
            address(addressResolver),
            owner,
            10000000000000000000000,
            10000000000000000000000,
            "SUPER TOKEN",
            "SUPER",
            18,
            owner,
            1000000000 ether,
            address(auctionManager),
            createFeesData(maxFees)
        );
        SuperTokenAppGateway superTokenApp = new SuperTokenAppGateway(
            address(addressResolver),
            address(superTokenDeployer),
            createFeesData(maxFees),
            address(auctionManager)
        );

        appContracts = AppContracts({
            superTokenApp: superTokenApp,
            superTokenDeployer: superTokenDeployer,
            superToken: superTokenDeployer.superToken(),
            limitHook: superTokenDeployer.limitHook()
        });

        UpdateLimitParams[] memory params = new UpdateLimitParams[](2);
        params[0] = UpdateLimitParams({
            limitType: FINALIZE,
            appGateway: address(appContracts.superTokenDeployer),
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });
        params[1] = UpdateLimitParams({
            limitType: FINALIZE,
            appGateway: address(appContracts.superTokenApp),
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
            address(appContracts.superTokenDeployer),
            appContracts.superTokenDeployer.creationCodeWithArgs(
                appContracts.superToken
            )
        );
        payloadDetails[1] = createDeployPayloadDetail(
            chainSlug_,
            address(appContracts.superTokenDeployer),
            appContracts.superTokenDeployer.creationCodeWithArgs(
                appContracts.limitHook
            )
        );

        return payloadDetails;
    }

    function createConfigurePayloadDetailsArray(
        uint32 chainSlug_
    ) internal returns (PayloadDetails[] memory) {
        address superTokenForwarder = appContracts
            .superTokenDeployer
            .forwarderAddresses(appContracts.superToken, chainSlug_);
        address limitHookForwarder = appContracts
            .superTokenDeployer
            .forwarderAddresses(appContracts.limitHook, chainSlug_);

        address deployedToken = IForwarder(superTokenForwarder)
            .getOnChainAddress();

        address deployedLimitHook = IForwarder(limitHookForwarder)
            .getOnChainAddress();

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createExecutePayloadDetail(
            chainSlug_,
            deployedToken,
            address(appContracts.superTokenDeployer),
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
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenDeployer)
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
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
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
        bytes32 asyncId = _configure(
            payloadIds,
            address(appContracts.superTokenApp)
        );

        checkPayloadBatchAndDetails(
            payloadDetails,
            asyncId,
            address(appContracts.superTokenApp)
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
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        payloadIds = getWritePayloadIds(
            arbChainSlug,
            address(arbConfig.switchboard),
            1
        );
        _configure(payloadIds, address(appContracts.superTokenApp));

        payloadIds = getWritePayloadIds(
            optChainSlug,
            address(optConfig.switchboard),
            2
        );
        _deploy(
            contractIds,
            payloadIds,
            optChainSlug,
            appContracts.superTokenDeployer,
            address(appContracts.superTokenApp)
        );

        payloadIds = getWritePayloadIds(
            optChainSlug,
            address(optConfig.switchboard),
            1
        );
        _configure(payloadIds, address(appContracts.superTokenApp));
    }

    function _bridge() internal returns (bytes32, bytes32[] memory) {
        beforeBridge();

        userOrder = SuperTokenAppGateway.UserOrder({
            srcToken: appContracts.superTokenDeployer.forwarderAddresses(
                appContracts.superToken,
                arbChainSlug
            ),
            dstToken: appContracts.superTokenDeployer.forwarderAddresses(
                appContracts.superToken,
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
        appContracts.superTokenApp.bridge(encodedOrder);
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
}
