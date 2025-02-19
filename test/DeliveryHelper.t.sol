// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/protocol/payload-delivery/app-gateway/DeliveryHelper.sol";
import "../contracts/protocol/payload-delivery/app-gateway/FeesManager.sol";
import "../contracts/protocol/payload-delivery/app-gateway/AuctionManager.sol";

import "../contracts/protocol/Forwarder.sol";
import "../contracts/interfaces/IAppDeployer.sol";
import "../contracts/interfaces/IMultiChainAppDeployer.sol";

import "./SetupTest.t.sol";

contract DeliveryHelperTest is SetupTest {
    uint256 public maxFees = 0.0001 ether;
    uint256 public bidAmount = maxFees / 100;
    uint256 public deployCounter;
    uint256 public asyncPromiseCounterLocal = 0;
    uint256 public asyncCounterTest;
    uint256 public auctionEndDelaySeconds = 0;
    uint256 public bidTimeout = 86400;

    DeliveryHelper deliveryHelper;
    FeesManager feesManager;
    AuctionManager auctionManager;

    event PayloadSubmitted(
        bytes32 indexed asyncId,
        address indexed appGateway,
        PayloadDetails[] payloads,
        Fees fees,
        uint256 auctionEndDelay
    );
    event BidPlaced(bytes32 indexed asyncId, Bid bid);
    event AuctionEnded(bytes32 indexed asyncId, Bid winningBid);
    event BatchCancelled(bytes32 indexed asyncId);
    event FinalizeRequested(bytes32 indexed payloadId, AsyncRequest asyncRequest);
    event QueryRequested(uint32 chainSlug, address targetAddress, bytes32 payloadId, bytes payload);

    function setUpDeliveryHelper() internal {
        // core
        deployOffChainVMCore();
        // Deploy implementations
        FeesManager feesManagerImpl = new FeesManager();
        DeliveryHelper deliveryHelperImpl = new DeliveryHelper();
        AuctionManager auctionManagerImpl = new AuctionManager();

        // Deploy and initialize proxies
        bytes memory feesManagerData = abi.encodeWithSelector(
            FeesManager.initialize.selector,
            address(addressResolver),
            owner
        );

        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address feesManagerProxy = proxyFactory.deployAndCall(
            address(feesManagerImpl),
            watcherEOA,
            feesManagerData
        );

        bytes memory deliveryHelperData = abi.encodeWithSelector(
            DeliveryHelper.initialize.selector,
            address(addressResolver),
            address(feesManagerProxy),
            owner,
            bidTimeout
        );

        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address deliveryHelperProxy = proxyFactory.deployAndCall(
            address(deliveryHelperImpl),
            watcherEOA,
            deliveryHelperData
        );

        bytes memory auctionManagerData = abi.encodeWithSelector(
            AuctionManager.initialize.selector,
            vmChainSlug,
            auctionEndDelaySeconds,
            address(addressResolver),
            owner,
            version
        );
        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address auctionManagerProxy = proxyFactory.deployAndCall(
            address(auctionManagerImpl),
            watcherEOA,
            auctionManagerData
        );

        // Assign proxy addresses to contract variables
        feesManager = FeesManager(address(feesManagerProxy));
        deliveryHelper = DeliveryHelper(address(deliveryHelperProxy));
        auctionManager = AuctionManager(address(auctionManagerProxy));

        hoax(watcherEOA);
        addressResolver.setDeliveryHelper(address(deliveryHelper));

        hoax(watcherEOA);
        addressResolver.setFeesManager(address(feesManager));

        // chain core contracts
        arbConfig = deploySocket(arbChainSlug);
        optConfig = deploySocket(optChainSlug);

        connectDeliveryHelper();
    }

    function connectDeliveryHelper() internal {
        vm.startPrank(owner);
        arbConfig.contractFactoryPlug.connectSocket(
            address(deliveryHelper),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );
        optConfig.contractFactoryPlug.connectSocket(
            address(deliveryHelper),
            address(optConfig.socket),
            address(optConfig.switchboard)
        );

        arbConfig.feesPlug.connectSocket(
            address(feesManager),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );
        optConfig.feesPlug.connectSocket(
            address(feesManager),
            address(optConfig.socket),
            address(optConfig.switchboard)
        );
        vm.stopPrank();

        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](4);
        gateways[0] = AppGatewayConfig({
            plug: address(arbConfig.contractFactoryPlug),
            chainSlug: arbChainSlug,
            appGateway: address(deliveryHelper),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[1] = AppGatewayConfig({
            plug: address(optConfig.contractFactoryPlug),
            chainSlug: optChainSlug,
            appGateway: address(deliveryHelper),
            switchboard: address(optConfig.switchboard)
        });
        gateways[2] = AppGatewayConfig({
            plug: address(arbConfig.feesPlug),
            chainSlug: arbChainSlug,
            appGateway: address(feesManager),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[3] = AppGatewayConfig({
            plug: address(optConfig.feesPlug),
            chainSlug: optChainSlug,
            appGateway: address(feesManager),
            switchboard: address(optConfig.switchboard)
        });

        hoax(watcherEOA);
        watcherPrecompile.setAppGateways(gateways);
    }

    function setLimit(address appGateway_) internal {
        UpdateLimitParams[] memory params = new UpdateLimitParams[](3);
        params[0] = UpdateLimitParams({
            limitType: QUERY,
            appGateway: appGateway_,
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });
        params[1] = UpdateLimitParams({
            limitType: SCHEDULE,
            appGateway: appGateway_,
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });
        params[2] = UpdateLimitParams({
            limitType: FINALIZE,
            appGateway: appGateway_,
            maxLimit: 10000000000000000000000,
            ratePerSecond: 10000000000000000000000
        });

        hoax(watcherEOA);
        watcherPrecompile.updateLimitParams(params);

        skip(100);
    }

    function depositFees(address appGateway_, Fees memory fees_) internal {
        SocketContracts memory socketConfig = getSocketConfig(fees_.feePoolChain);
        socketConfig.feesPlug.deposit{value: fees_.amount}(
            fees_.feePoolToken,
            appGateway_,
            fees_.amount
        );

        hoax(owner);
        feesManager.incrementFeesDeposited(
            fees_.feePoolChain,
            appGateway_,
            fees_.feePoolToken,
            fees_.amount
        );
    }

    //// BATCH DEPLOY AND EXECUTE HELPERS ////
    function getContractFactoryPlug(uint32 chainSlug_) internal view returns (address) {
        return address(getSocketConfig(chainSlug_).contractFactoryPlug);
    }

    function checkPayloadBatchAndDetails(
        PayloadDetails[] memory payloadDetails,
        bytes32 asyncId,
        address appGateway_
    ) internal view {
        for (uint i = 0; i < payloadDetails.length; i++) {
            PayloadDetails memory payloadDetail = deliveryHelper.getPayloadIndexDetails(asyncId, i);

            assertEq(payloadDetail.chainSlug, payloadDetails[i].chainSlug, "ChainSlug mismatch");
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
            // assertEq(
            //     payloadDetail.executionGasLimit,
            //     payloadDetails[i].executionGasLimit,
            //     "ExecutionGasLimit mismatch"
            // );
        }

        PayloadBatch memory payloadBatch = deliveryHelper.getAsyncBatchDetails(asyncId);

        assertEq(payloadBatch.appGateway, appGateway_, "AppGateway mismatch");
        assertEq(payloadBatch.auctionManager, address(auctionManager), "AuctionManager mismatch");
        assertEq(payloadBatch.winningBid.fee, bidAmount, "WinningBid mismatch");
        assertEq(
            payloadBatch.winningBid.transmitter,
            transmitterEOA,
            "WinningBid transmitter mismatch"
        );
        assertEq(payloadBatch.isBatchCancelled, false, "IsBatchCancelled mismatch");
    }

    function bidAndEndAuction(bytes32 asyncId) internal {
        // for scheduling bid expiry
        payloadIdCounter++;
        placeBid(asyncId);
        endAuction();
    }

    function bidAndExecute(bytes32[] memory payloadIds, bytes32 asyncId_) internal {
        bidAndEndAuction(asyncId_);
        for (uint i = 0; i < payloadIds.length; i++) {
            finalizeAndExecute(payloadIds[i], false);
        }
    }

    function bidAndExecuteParallel(bytes32[] memory payloadIds, bytes32 asyncId_) internal {
        bidAndEndAuction(asyncId_);

        bytes[] memory returnData = new bytes[](payloadIds.length);
        for (uint i = 0; i < payloadIds.length; i++) {
            PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(payloadIds[i]);
            returnData[i] = finalizeAndRelay(payloadIds[i], payloadDetails);
        }

        resolvePromises(payloadIds, returnData);
    }

    function _deploy(
        bytes32[] memory contractIds,
        uint32 chainSlug_,
        uint256 totalPayloads,
        IAppDeployer appDeployer_,
        address appGateway_
    ) internal returns (bytes32 asyncId) {
        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);

        // for scheduling auction
        payloadIdCounter++;
        bytes32[] memory payloadIds = getWritePayloadIds(
            chainSlug_,
            address(socketConfig.switchboard),
            totalPayloads
        );
        asyncId = getCurrentAsyncId();

        appDeployer_.deployContracts(chainSlug_);
        bidAndExecute(payloadIds, asyncId);
        setupGatewayAndPlugs(chainSlug_, appDeployer_, appGateway_, contractIds);
    }

    function _deployParallel(
        bytes32[] memory contractIds,
        uint32[] memory chainSlugs_,
        IMultiChainAppDeployer appDeployer_,
        address appGateway_
    ) internal returns (bytes32 asyncId) {
        payloadIdCounter++;
        asyncId = getCurrentAsyncId();
        bytes32[] memory payloadIds = new bytes32[](contractIds.length * chainSlugs_.length);
        for (uint32 i = 0; i < chainSlugs_.length; i++) {
            for (uint j = 0; j < contractIds.length; j++) {
                payloadIds[i * contractIds.length + j] = getWritePayloadId(
                    chainSlugs_[i],
                    address(getSocketConfig(chainSlugs_[i]).switchboard),
                    i * contractIds.length + j + payloadIdCounter
                );
            }
        }
        // for fees
        payloadIdCounter += chainSlugs_.length * contractIds.length + 1;

        appDeployer_.deployMultiChainContracts(chainSlugs_);
        bidAndExecute(payloadIds, asyncId);
        for (uint i = 0; i < chainSlugs_.length; i++) {
            setupGatewayAndPlugs(chainSlugs_[i], appDeployer_, appGateway_, contractIds);
        }
    }

    function setupGatewayAndPlugs(
        uint32 chainSlug_,
        IAppDeployer appDeployer_,
        address appGateway_,
        bytes32[] memory contractIds
    ) internal {
        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](contractIds.length);

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        for (uint i = 0; i < contractIds.length; i++) {
            address plug = appDeployer_.getOnChainAddress(contractIds[i], chainSlug_);

            gateways[i] = AppGatewayConfig({
                plug: plug,
                chainSlug: chainSlug_,
                appGateway: appGateway_,
                switchboard: address(socketConfig.switchboard)
            });
        }

        hoax(watcherEOA);
        watcherPrecompile.setAppGateways(gateways);
    }

    function _executeReadBatchSingleChain(
        uint32 chainSlug_,
        uint256 totalPayloads
    ) internal returns (bytes32 asyncId) {
        asyncId = getCurrentAsyncId();
    }

    function _executeReadBatchMultiChain(
        uint32[] memory chainSlugs_
    ) internal returns (bytes32 asyncId) {
        asyncId = getCurrentAsyncId();
    }

    function _executeWriteBatchSingleChain(
        uint32 chainSlug_,
        uint256 totalPayloads
    ) internal returns (bytes32 asyncId) {
        asyncId = getCurrentAsyncId();

        payloadIdCounter++;
        bytes32[] memory payloadIds = getWritePayloadIds(
            chainSlug_,
            address(getSocketConfig(chainSlug_).switchboard),
            totalPayloads
        );
        bidAndExecute(payloadIds, asyncId);
    }

    function _executeWriteBatchMultiChain(
        uint32[] memory chainSlugs_
    ) internal returns (bytes32 asyncId) {
        asyncId = getCurrentAsyncId();
        payloadIdCounter++;
        bidAndEndAuction(asyncId);
        for (uint i = 0; i < chainSlugs_.length; i++) {
            bytes32 payloadId = getWritePayloadId(
                chainSlugs_[i],
                address(getSocketConfig(chainSlugs_[i]).switchboard),
                i + payloadIdCounter
            );
            finalizeAndExecute(payloadId, false);
        }

        payloadIdCounter += chainSlugs_.length;
    }

    function createDeployPayloadDetail(
        uint32 chainSlug_,
        address appDeployer_,
        bytes memory bytecode_
    ) internal returns (PayloadDetails memory payloadDetails) {
        bytes32 salt = keccak256(abi.encode(appDeployer_, chainSlug_, deployCounter++));
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
                isParallel: Parallel.ON
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
            keccak256(abi.encode(address(auctionManager), vmChainSlug, asyncId, bidAmount, "")),
            transmitterPrivateKey
        );

        auctionManager.bid(asyncId, bidAmount, transmitterSignature, "");
    }

    function endAuction() internal {
        // todo:
        // vm.expectEmit(true, false, false, true);
        // emit AuctionEnded(
        //     asyncId,
        //     Bid({fee: bidAmount, transmitter: transmitterEOA, extraData: ""})
        // );

        if (auctionEndDelaySeconds == 0) return;
        bytes32 timeoutId = _encodeId(vmChainSlug, address(watcherPrecompile), payloadIdCounter++);

        hoax(watcherEOA);
        watcherPrecompile.resolveTimeout(timeoutId);
    }

    function finalize(
        bytes32 payloadId,
        PayloadDetails memory payloadDetails
    ) internal view returns (bytes memory, bytes32) {
        SocketContracts memory socketConfig = getSocketConfig(payloadDetails.chainSlug);

        PayloadRootParams memory rootParams_ = PayloadRootParams(
            payloadDetails.appGateway,
            transmitterEOA,
            payloadDetails.target,
            payloadId,
            payloadDetails.executionGasLimit,
            block.timestamp + 1000,
            payloadDetails.payload
        );
        bytes32 root = watcherPrecompile.getRoot(rootParams_);

        bytes32 digest = keccak256(abi.encode(address(socketConfig.switchboard), root));
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
        bytes32,
        bytes memory payload_
    ) internal returns (PayloadDetails memory payloadDetails) {
        address asyncPromise = predictAsyncPromiseAddress(appGateway_, forwarder_);
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
        address asyncPromise = predictAsyncPromiseAddress(appGateway_, forwarder_);
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

    function finalizeQuery(bytes32 payloadId, bytes memory returnData_) internal {
        resolvePromise(payloadId, returnData_);
    }

    function finalizeAndExecute(bytes32 payloadId, bool isWithdraw) internal {
        PayloadDetails memory payloadDetails = deliveryHelper.getPayloadDetails(payloadId);
        finalizeAndExecute(payloadId, isWithdraw, payloadDetails);
    }

    function finalizeAndExecute(
        bytes32 payloadId,
        bool isWithdraw,
        PayloadDetails memory payloadDetails
    ) internal {
        bytes memory returnData = finalizeAndRelay(payloadId, payloadDetails);
        if (!isWithdraw) {
            resolvePromise(payloadId, returnData);
        }
    }

    function finalizeAndRelay(
        bytes32 payloadId_,
        PayloadDetails memory payloadDetails
    ) internal returns (bytes memory returnData) {
        (bytes memory watcherSig, bytes32 root) = finalize(payloadId_, payloadDetails);

        returnData = relayTx(
            payloadDetails.chainSlug,
            payloadId_,
            root,
            payloadDetails,
            watcherSig
        );
    }

    function predictAsyncPromiseAddress(
        address invoker_,
        address forwarder_
    ) internal returns (address) {
        bytes memory constructorArgs = abi.encode(invoker_, forwarder_, address(addressResolver));
        bytes memory combinedBytecode = abi.encodePacked(asyncPromiseBytecode, constructorArgs);

        bytes32 salt = keccak256(abi.encodePacked(constructorArgs, asyncPromiseCounterLocal++));

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

    function getCurrentAsyncId() public returns (bytes32) {
        return bytes32((uint256(uint160(address(deliveryHelper))) << 64) | asyncCounterTest++);
    }

    function getLatestAsyncId() public view returns (bytes32) {
        return bytes32((uint256(uint160(address(deliveryHelper))) << 64) | asyncCounterTest);
    }

    function getOnChainAndForwarderAddresses(
        uint32 chainSlug_,
        bytes32 contractId_,
        IAppDeployer deployer_
    ) internal view returns (address, address) {
        address app = deployer_.getOnChainAddress(contractId_, chainSlug_);
        address forwarder = deployer_.forwarderAddresses(contractId_, chainSlug_);
        return (app, forwarder);
    }
}
