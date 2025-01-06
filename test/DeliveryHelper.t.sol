// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/apps/payload-delivery/app-gateway/DeliveryHelper.sol";
import "../contracts/apps/payload-delivery/app-gateway/FeesManager.sol";
import "../contracts/apps/payload-delivery/app-gateway/AuctionManager.sol";

import "../contracts/Forwarder.sol";
import "../contracts/interfaces/IAppDeployer.sol";

import "./SetupTest.t.sol";

contract DeliveryHelperTest is SetupTest {
    uint256 public maxFees = 0.0001 ether;
    uint256 public bidAmount = maxFees / 100;
    uint256 public deployCounter;
    uint256 public asyncPromiseCounterLocal = 0;
    uint256 public asyncCounterTest;

    DeliveryHelper deliveryHelper;
    FeesManager feesManager;
    AuctionManager auctionManager;
    event PayloadSubmitted(
        bytes32 indexed asyncId,
        address indexed appGateway,
        PayloadDetails[] payloads,
        FeesData feesData,
        uint256 auctionEndDelay
    );
    event BidPlaced(bytes32 indexed asyncId, Bid bid);
    event AuctionEnded(bytes32 indexed asyncId, Bid winningBid);

    function setUpDeliveryHelper() internal {
        // core
        deployOffChainVMCore();
        feesManager = new FeesManager(address(addressResolver), owner);
        deliveryHelper = new DeliveryHelper(
            address(addressResolver),
            address(feesManager),
            owner
        );
        auctionManager = new AuctionManager(
            vmChainSlug,
            address(addressResolver),
            signatureVerifier,
            owner
        );

        hoax(watcherEOA);
        addressResolver.setDeliveryHelper(address(deliveryHelper));

        // chain core contracts
        arbConfig = deploySocket(arbChainSlug);
        optConfig = deploySocket(optChainSlug);

        connectDeliveryHelper();
    }

    function connectDeliveryHelper() internal {
        vm.startPrank(owner);
        arbConfig.contractFactoryPlug.connect(
            address(deliveryHelper),
            address(arbConfig.switchboard)
        );
        optConfig.contractFactoryPlug.connect(
            address(deliveryHelper),
            address(optConfig.switchboard)
        );

        arbConfig.feesPlug.connect(
            address(feesManager),
            address(arbConfig.switchboard)
        );
        optConfig.feesPlug.connect(
            address(feesManager),
            address(optConfig.switchboard)
        );
        vm.stopPrank();

        IWatcherPrecompile.AppGatewayConfig[]
            memory gateways = new IWatcherPrecompile.AppGatewayConfig[](4);
        gateways[0] = IWatcherPrecompile.AppGatewayConfig({
            plug: address(arbConfig.contractFactoryPlug),
            chainSlug: arbChainSlug,
            appGateway: address(deliveryHelper),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[1] = IWatcherPrecompile.AppGatewayConfig({
            plug: address(optConfig.contractFactoryPlug),
            chainSlug: optChainSlug,
            appGateway: address(deliveryHelper),
            switchboard: address(optConfig.switchboard)
        });
        gateways[2] = IWatcherPrecompile.AppGatewayConfig({
            plug: address(arbConfig.feesPlug),
            chainSlug: arbChainSlug,
            appGateway: address(feesManager),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[3] = IWatcherPrecompile.AppGatewayConfig({
            plug: address(optConfig.feesPlug),
            chainSlug: optChainSlug,
            appGateway: address(feesManager),
            switchboard: address(optConfig.switchboard)
        });

        hoax(watcherEOA);
        watcherPrecompile.setAppGateways(gateways);
    }

    //// BATCH DEPLOY AND EXECUTE HELPERS ////
    function getContractFactoryPlug(
        uint32 chainSlug_
    ) internal view returns (address) {
        return address(getSocketConfig(chainSlug_).contractFactoryPlug);
    }

    function checkPayloadBatchAndDetails(
        PayloadDetails[] memory payloadDetails,
        bytes32 asyncId,
        address appGateway_
    ) internal view {
        for (uint i = 0; i < payloadDetails.length; i++) {
            PayloadDetails memory payloadDetail = deliveryHelper
                .getPayloadDetails(asyncId, i);

            assertEq(
                payloadDetail.chainSlug,
                payloadDetails[i].chainSlug,
                "ChainSlug mismatch"
            );
            // todo
            // assertEq(
            //     payloadDetail.target,
            //     payloadDetails[i].target,
            //     "Target mismatch"
            // );
            // assertEq(
            //     keccak256(payloadDetail.payload),
            //     keccak256(payloadDetails[i].payload),
            //     "Payload mismatch"
            // );
            assertEq(
                uint(payloadDetail.callType),
                uint(payloadDetails[i].callType),
                "CallType mismatch"
            );
            assertEq(
                payloadDetail.executionGasLimit,
                payloadDetails[i].executionGasLimit,
                "ExecutionGasLimit mismatch"
            );
        }

        (
            address appGateway,
            FeesData memory feesData,
            uint256 currentPayloadIndex,
            address _auctionManager,
            Bid memory winningBid,
            bool isBatchCancelled,
            uint256 totalPayloadsRemaining,
            bytes memory onCompleteData
        ) = deliveryHelper.payloadBatches(asyncId);

        assertEq(appGateway_, appGateway, "AppGateway mismatch");
        assertEq(
            _auctionManager,
            address(auctionManager),
            "AuctionManager mismatch"
        );
        assertEq(winningBid.fee, bidAmount, "WinningBid mismatch");
        assertEq(
            winningBid.transmitter,
            transmitterEOA,
            "WinningBid transmitter mismatch"
        );
        assertEq(isBatchCancelled, false, "IsBatchCancelled mismatch");
    }

    function bidAndEndAuction(bytes32 asyncId) internal {
        placeBid(asyncId);

        bytes32 timeoutId = encodeTimeoutId(timeoutPayloadIdCounter++);
        endAuction(timeoutId);
    }

    function bidAndExecute(
        bytes32[] memory payloadIds,
        bytes32 asyncId_
    ) internal {
        bidAndEndAuction(asyncId_);
        for (uint i = 0; i < payloadIds.length; i++) {
            finalizeAndExecute(asyncId_, payloadIds[i], false);
        }
    }

    function _deploy(
        bytes32[] memory contractIds,
        bytes32[] memory payloadIds,
        uint32 chainSlug_,
        IAppDeployer appDeployer_,
        address appGateway_
    ) internal returns (bytes32 asyncId) {
        asyncId = getCurrentAsyncId();
        asyncCounterTest++;

        appDeployer_.deployContracts(chainSlug_);
        bidAndExecute(payloadIds, asyncId);
        setupGatewayAndPlugs(
            chainSlug_,
            appDeployer_,
            appGateway_,
            contractIds
        );
    }

    function setupGatewayAndPlugs(
        uint32 chainSlug_,
        IAppDeployer appDeployer_,
        address appGateway_,
        bytes32[] memory contractIds
    ) internal {
        IWatcherPrecompile.AppGatewayConfig[]
            memory gateways = new IWatcherPrecompile.AppGatewayConfig[](
                contractIds.length
            );

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        for (uint i = 0; i < contractIds.length; i++) {
            address plug = appDeployer_.getOnChainAddress(
                contractIds[i],
                chainSlug_
            );

            gateways[i] = IWatcherPrecompile.AppGatewayConfig({
                plug: plug,
                chainSlug: chainSlug_,
                appGateway: appGateway_,
                switchboard: address(socketConfig.switchboard)
            });
        }

        hoax(watcherEOA);
        watcherPrecompile.setAppGateways(gateways);
    }

    function _configure(
        bytes32[] memory payloadIds,
        address appDeployer_
    ) internal returns (bytes32 asyncId) {
        asyncId = getCurrentAsyncId();
        asyncCounterTest++;
        bidAndExecute(payloadIds, asyncId);
    }

    function createDeployPayloadDetail(
        uint32 chainSlug_,
        address appDeployer_,
        bytes memory bytecode_
    ) internal returns (PayloadDetails memory payloadDetails) {
        bytes32 salt = keccak256(
            abi.encode(appDeployer_, chainSlug_, deployCounter++)
        );
        bytes memory payload = abi.encodeWithSelector(
            IContractFactoryPlug.deployContract.selector,
            bytecode_,
            salt
        );

        address asyncPromise = predictAsyncPromiseAddress(
            address(deliveryHelper),
            address(deliveryHelper)
        );
        address[] memory next = new address[](2);
        next[0] = asyncPromise;

        payloadDetails = createPayloadDetails(
            chainSlug_,
            address(appDeployer_),
            address(0),
            payload,
            CallType.DEPLOY,
            1_000_000_0,
            next
        );

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        payloadDetails.target = address(socketConfig.contractFactoryPlug);
        payloadDetails.payload = abi.encode(DEPLOY, payloadDetails.payload);
    }

    function createPayloadDetails(
        uint32 chainSlug_,
        address appGateway_,
        address target_,
        bytes memory payload_,
        CallType callType_,
        uint256 executionGasLimit_,
        address[] memory next_
    ) internal pure returns (PayloadDetails memory) {
        return
            PayloadDetails({
                appGateway: appGateway_,
                chainSlug: chainSlug_,
                target: target_,
                payload: payload_,
                callType: callType_,
                executionGasLimit: executionGasLimit_,
                next: next_,
                isSequential: false
            });
    }

    //// AUCTION RELATED FUNCTIONS ////
    function placeBid(bytes32 asyncId) internal {
        // todo:
        // vm.expectEmit(false, false, false, false);
        // emit BidPlaced(
        //     asyncId,
        //     Bid({fee: bidAmount, transmitter: transmitterEOA, extraData: ""})
        // );

        vm.prank(transmitterEOA);
        bytes memory transmitterSignature = _createSignature(
            keccak256(
                abi.encode(
                    address(auctionManager),
                    vmChainSlug,
                    asyncId,
                    bidAmount,
                    ""
                )
            ),
            transmitterPrivateKey
        );
        auctionManager.bid(asyncId, bidAmount, transmitterSignature, "");
    }

    function endAuction(bytes32 timeoutId) internal {
        // todo:
        // vm.expectEmit(true, false, false, true);
        // emit AuctionEnded(
        //     asyncId,
        //     Bid({fee: bidAmount, transmitter: transmitterEOA, extraData: ""})
        // );

        hoax(watcherEOA);
        watcherPrecompile.resolveTimeout(timeoutId);
    }

    function finalize(
        bytes32 payloadId
    ) internal view returns (bytes memory, bytes32) {
        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(
            payloadId
        );
        SocketContracts memory socketConfig = getSocketConfig(
            payloadDetails.chainSlug
        );

        PayloadRootParams memory rootParams_ = PayloadRootParams(
            payloadId,
            payloadDetails.appGateway,
            transmitterEOA,
            payloadDetails.target,
            payloadDetails.executionGasLimit,
            payloadDetails.payload
        );
        bytes32 root = watcherPrecompile.getRoot(rootParams_);

        bytes32 digest = keccak256(
            abi.encode(address(socketConfig.switchboard), root)
        );
        bytes memory watcherSig = _createSignature(digest, watcherPrivateKey);
        return (watcherSig, root);
    }

    function createWithdrawPayloadDetail(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address forwarder_,
        bytes memory payload_
    ) internal returns (PayloadDetails memory) {
        return
            createWritePayloadDetail(
                chainSlug_,
                target_,
                appGateway_,
                forwarder_,
                WITHDRAW,
                payload_
            );
    }

    function createExecutePayloadDetail(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address forwarder_,
        bytes memory payload_
    ) internal returns (PayloadDetails memory) {
        return
            createWritePayloadDetail(
                chainSlug_,
                target_,
                appGateway_,
                forwarder_,
                FORWARD_CALL,
                payload_
            );
    }

    function createWritePayloadDetail(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address forwarder_,
        bytes32 callType_,
        bytes memory payload_
    ) internal returns (PayloadDetails memory payloadDetails) {
        address asyncPromise = predictAsyncPromiseAddress(
            appGateway_,
            forwarder_
        );
        address[] memory next = new address[](2);
        next[0] = asyncPromise;

        payloadDetails = createPayloadDetails(
            chainSlug_,
            appGateway_,
            target_,
            payload_,
            CallType.WRITE,
            CONFIGURE_GAS_LIMIT,
            next
        );

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        payloadDetails.target = address(socketConfig.contractFactoryPlug);
    }

    function createReadPayloadDetail(
        uint32 chainSlug_,
        address target_,
        address appGateway_,
        address forwarder_,
        bytes memory payload_
    ) internal returns (PayloadDetails memory) {
        address asyncPromise = predictAsyncPromiseAddress(
            appGateway_,
            forwarder_
        );
        address[] memory next = new address[](2);
        next[0] = asyncPromise;

        return
            createPayloadDetails(
                chainSlug_,
                appGateway_,
                target_,
                payload_,
                CallType.READ,
                CONFIGURE_GAS_LIMIT,
                next
            );
    }

    function finalizeQuery(
        bytes32 payloadId,
        bytes memory returnData_
    ) internal {
        resolvePromise(payloadId, returnData_);
    }

    function finalizeAndExecute(
        bytes32 asyncId,
        bytes32 payloadId,
        bool isWithdraw
    ) internal {
        (bytes memory watcherSig, bytes32 root) = finalize(payloadId);

        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(
            payloadId
        );
        bytes memory returnData = relayTx(
            payloadDetails.chainSlug,
            payloadId,
            root,
            payloadDetails,
            watcherSig
        );

        if (!isWithdraw) {
            resolvePromise(payloadId, returnData);
        }
    }

    function predictAsyncPromiseAddress(
        address invoker_,
        address forwarder_
    ) internal returns (address) {
        bytes memory constructorArgs = abi.encode(
            invoker_,
            forwarder_,
            address(addressResolver)
        );
        bytes memory combinedBytecode = abi.encodePacked(
            asyncPromiseBytecode,
            constructorArgs
        );

        bytes32 salt = keccak256(
            abi.encodePacked(constructorArgs, asyncPromiseCounterLocal++)
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(addressResolver),
                salt,
                keccak256(combinedBytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }

    function getCurrentAsyncId() public view returns (bytes32) {
        return
            bytes32(
                (uint256(uint160(address(deliveryHelper))) << 64) |
                    asyncCounterTest
            );
    }

    function getTimeoutPayloadId(
        uint256 counter_
    ) internal view returns (bytes32) {
        return
            bytes32(
                (uint256(uint160(address(deliveryHelper))) << 64) | counter_
            );
    }
}
