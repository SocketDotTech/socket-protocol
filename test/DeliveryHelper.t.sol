// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../contracts/evmx/payload-delivery/app-gateway/DeliveryHelper.sol";
import "../contracts/evmx/payload-delivery/FeesManager.sol";
import "../contracts/evmx/payload-delivery/AuctionManager.sol";

import "../contracts/evmx/Forwarder.sol";
import "../contracts/evmx/interfaces/IAppGateway.sol";

import "./SetupTest.t.sol";

interface IAppGatewayDeployer {
    function deployContracts(uint32 chainSlug_) external;
}

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
        uint40 indexed requestCount,
        address indexed appGateway,
        PayloadSubmitParams[] payloadSubmitParams,
        uint256 maxFees,
        address auctionManager,
        bool onlyReadRequests
    );
    event BidPlaced(uint40 requestCount, Bid bid);
    event AuctionEnded(uint40 indexed requestCount, Bid winningBid);
    event RequestCancelled(uint40 indexed requestCount);
    event QueryRequested(uint32 chainSlug, address targetAddress, bytes32 payloadId, bytes payload);

    //////////////////////////////////// Setup ////////////////////////////////////
    function setUpDeliveryHelper() internal {
        // core
        deployEVMxCore();
        // Deploy implementations
        FeesManager feesManagerImpl = new FeesManager();
        DeliveryHelper deliveryHelperImpl = new DeliveryHelper();
        AuctionManager auctionManagerImpl = new AuctionManager();

        // Deploy and initialize proxies
        bytes memory feesManagerData = abi.encodeWithSelector(
            FeesManager.initialize.selector,
            address(addressResolver),
            watcherEOA,
            evmxSlug,
            FAST
        );

        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address feesManagerProxy = proxyFactory.deployAndCall(
            address(feesManagerImpl),
            watcherEOA,
            feesManagerData
        );

        bytes memory auctionManagerData = abi.encodeWithSelector(
            AuctionManager.initialize.selector,
            evmxSlug,
            auctionEndDelaySeconds,
            address(addressResolver),
            owner,
            maxReAuctionCount
        );
        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address auctionManagerProxy = proxyFactory.deployAndCall(
            address(auctionManagerImpl),
            watcherEOA,
            auctionManagerData
        );

        bytes memory deliveryHelperData = abi.encodeWithSelector(
            DeliveryHelper.initialize.selector,
            address(addressResolver),
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

        // Assign proxy addresses to contract variables
        feesManager = FeesManager(address(feesManagerProxy));
        deliveryHelper = DeliveryHelper(address(deliveryHelperProxy));
        auctionManager = AuctionManager(address(auctionManagerProxy));

        vm.startPrank(watcherEOA);
        addressResolver.setDeliveryHelper(address(deliveryHelper));
        addressResolver.setDefaultAuctionManager(address(auctionManager));
        addressResolver.setFeesManager(address(feesManager));
        vm.stopPrank();

        hoax(owner);
        auctionManager.grantRole(TRANSMITTER_ROLE, transmitterEOA);

        // chain core contracts
        arbConfig = deploySocket(arbChainSlug);
        optConfig = deploySocket(optChainSlug);
        connectDeliveryHelper();

        depositUSDCFees(
            address(auctionManager),
            OnChainFees({
                chainSlug: arbChainSlug,
                token: address(arbConfig.feesTokenUSDC),
                amount: 1 ether
            })
        );
    }

    function connectDeliveryHelper() internal {
        vm.startPrank(owner);
        arbConfig.contractFactoryPlug.initSocket(
            _encodeAppGatewayId(address(deliveryHelper)),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );
        optConfig.contractFactoryPlug.initSocket(
            _encodeAppGatewayId(address(deliveryHelper)),
            address(optConfig.socket),
            address(optConfig.switchboard)
        );

        arbConfig.feesPlug.initSocket(
            _encodeAppGatewayId(address(feesManager)),
            address(arbConfig.socket),
            address(arbConfig.switchboard)
        );
        optConfig.feesPlug.initSocket(
            _encodeAppGatewayId(address(feesManager)),
            address(optConfig.socket),
            address(optConfig.switchboard)
        );
        vm.stopPrank();

        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](4);
        gateways[0] = AppGatewayConfig({
            plug: address(arbConfig.contractFactoryPlug),
            chainSlug: arbChainSlug,
            appGatewayId: _encodeAppGatewayId(address(deliveryHelper)),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[1] = AppGatewayConfig({
            plug: address(optConfig.contractFactoryPlug),
            chainSlug: optChainSlug,
            appGatewayId: _encodeAppGatewayId(address(deliveryHelper)),
            switchboard: address(optConfig.switchboard)
        });
        gateways[2] = AppGatewayConfig({
            plug: address(arbConfig.feesPlug),
            chainSlug: arbChainSlug,
            appGatewayId: _encodeAppGatewayId(address(feesManager)),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[3] = AppGatewayConfig({
            plug: address(optConfig.feesPlug),
            chainSlug: optChainSlug,
            appGatewayId: _encodeAppGatewayId(address(feesManager)),
            switchboard: address(optConfig.switchboard)
        });

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcherPrecompileConfig),
            abi.encode(IWatcherPrecompileConfig.setAppGateways.selector, gateways)
        );
        watcherPrecompileConfig.setAppGateways(gateways, signatureNonce++, watcherSignature);
    }

    //////////////////////////////////// Fees ////////////////////////////////////

    function depositUSDCFees(address appGateway_, OnChainFees memory fees_) internal {
        SocketContracts memory socketConfig = getSocketConfig(fees_.chainSlug);
        vm.startPrank(owner);
        ERC20(fees_.token).approve(address(socketConfig.feesPlug), fees_.amount);
        socketConfig.feesPlug.depositToFeeAndNative(fees_.token, appGateway_, fees_.amount);
        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                appGateway_,
                fees_.chainSlug,
                fees_.token,
                fees_.amount,
                address(feesManager),
                evmxSlug
            )
        );

        feesManager.depositCredits{value: fees_.amount}(
            appGateway_,
            fees_.chainSlug,
            fees_.token,
            signatureNonce++,
            _createSignature(digest, watcherPrivateKey)
        );
    }

    function whitelistAppGateway(
        address appGateway_,
        address user_,
        uint256 userPrivateKey_,
        uint32 chainSlug_
    ) internal {
        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        // Create fee approval data with signature
        bytes32 digest = keccak256(
            abi.encode(
                address(feesManager),
                evmxSlug,
                user_,
                appGateway_,
                feesManager.userNonce(user_),
                true
            )
        );

        // Sign with consumeFrom's private key
        bytes memory signature = _createSignature(digest, userPrivateKey_);

        // Encode approval data
        bytes memory feeApprovalData = abi.encode(user_, appGateway_, true, signature);

        // Call whitelistAppGatewayWithSignature with approval data
        feesManager.whitelistAppGatewayWithSignature(feeApprovalData);
    }

    ////////////////////////////////// Deployment helpers ////////////////////////////////////
    function _deploy(
        uint32 chainSlug_,
        IAppGateway appGateway_,
        bytes32[] memory contractIds_
    ) internal returns (uint40 requestCount) {
        requestCount = watcherPrecompile.nextRequestCount();
        IAppGatewayDeployer(address(appGateway_)).deployContracts(chainSlug_);

        finalizeRequest(requestCount, new bytes[](0));
        setupGatewayAndPlugs(chainSlug_, appGateway_, contractIds_);
    }

    function finalizeRequest(uint40 requestCount_, bytes[] memory readReturnData_) internal {
        uint40[] memory batches = watcherPrecompile.getBatches(requestCount_);

        bool onlyReads = _checkIfOnlyReads(batches[0]);
        if (!(onlyReads && batches.length == 1)) {
            bidAndEndAuction(requestCount_);
        }

        uint256 readCount = 0;
        for (uint i = 0; i < batches.length; i++) {
            bool hasMoreBatches = i < batches.length - 1;
            readCount = _finalizeBatch(batches[i], readReturnData_, readCount, hasMoreBatches);
        }
    }

    function executeRequest(bytes[] memory readReturnData_) internal {
        uint40 requestCount = watcherPrecompile.nextRequestCount();
        requestCount = requestCount == 0 ? 0 : requestCount - 1;
        finalizeRequest(requestCount, readReturnData_);
    }

    function setupGatewayAndPlugs(
        uint32 chainSlug_,
        IAppGateway appGateway_,
        bytes32[] memory contractIds_
    ) internal {
        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](contractIds_.length);

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        for (uint i = 0; i < contractIds_.length; i++) {
            address plug = appGateway_.getOnChainAddress(contractIds_[i], chainSlug_);

            gateways[i] = AppGatewayConfig({
                plug: plug,
                chainSlug: chainSlug_,
                appGatewayId: _encodeAppGatewayId(address(appGateway_)),
                switchboard: address(socketConfig.switchboard)
            });
        }

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcherPrecompileConfig),
            abi.encode(IWatcherPrecompileConfig.setAppGateways.selector, gateways)
        );
        watcherPrecompileConfig.setAppGateways(gateways, signatureNonce++, watcherSignature);
    }

    //////////////////////////////////// Auction ////////////////////////////////////
    function placeBid(uint40 requestCount) internal {
        bytes memory transmitterSignature = _createSignature(
            keccak256(abi.encode(address(auctionManager), evmxSlug, requestCount, bidAmount, "")),
            transmitterPrivateKey
        );

        vm.expectEmit(false, false, false, false);
        emit BidPlaced(
            requestCount,
            Bid({transmitter: transmitterEOA, fee: bidAmount, extraData: bytes("")})
        );
        auctionManager.bid(requestCount, bidAmount, transmitterSignature, bytes(""));
    }

    function endAuction(uint40 requestCount_) internal {
        if (auctionEndDelaySeconds == 0) return;
        bytes32 timeoutId = _encodeTimeoutId(
            evmxSlug,
            address(watcherPrecompile),
            timeoutIdCounter++
        );

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcherPrecompile),
            abi.encode(IWatcherPrecompile.resolveTimeout.selector, timeoutId)
        );

        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(
            requestCount_,
            Bid({fee: bidAmount, transmitter: transmitterEOA, extraData: ""})
        );
        watcherPrecompile.resolveTimeout(timeoutId, signatureNonce++, watcherSignature);
    }

    function bidAndEndAuction(uint40 requestCount) internal {
        placeBid(requestCount);
        endAuction(requestCount);
    }

    //////////////////////////////////// Utils ///////////////////////////////////
    function _encodeTimeoutId(
        uint32 chainSlug_,
        address sbOrWatcher_,
        uint256 counter_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug_) << 224) | (uint256(uint160(sbOrWatcher_)) << 64) | counter_
            );
    }

    function getOnChainAndForwarderAddresses(
        uint32 chainSlug_,
        bytes32 contractId_,
        IAppGateway appGateway_
    ) internal view returns (address, address) {
        address app = appGateway_.getOnChainAddress(contractId_, chainSlug_);
        address forwarder = appGateway_.forwarderAddresses(contractId_, chainSlug_);
        return (app, forwarder);
    }

    function getContractFactoryPlug(uint32 chainSlug_) internal view returns (address) {
        return address(getSocketConfig(chainSlug_).contractFactoryPlug);
    }

    //////////////////////////////////// Helpers ////////////////////////////////////
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

    //////////////////////////////////// Validators ////////////////////////////////////

    function checkPayloadRequestAndDetails(
        PayloadSubmitParams[] memory payloadSubmitParams,
        uint40 requestCount,
        address appGateway_
    ) internal view {
        for (uint i = 0; i < payloadSubmitParams.length; i++) {
            PayloadSubmitParams memory payloadSubmitParam = payloadSubmitParams[i];

            assertEq(
                payloadSubmitParam.chainSlug,
                payloadSubmitParams[i].chainSlug,
                "ChainSlug mismatch"
            );
            // todo
            assertEq(payloadSubmitParam.target, payloadSubmitParams[i].target, "Target mismatch");
            assertEq(
                keccak256(payloadSubmitParam.payload),
                keccak256(payloadSubmitParams[i].payload),
                "Payload mismatch"
            );
            assertEq(
                uint(payloadSubmitParam.callType),
                uint(payloadSubmitParams[i].callType),
                "CallType mismatch"
            );
            assertEq(
                payloadSubmitParam.gasLimit,
                payloadSubmitParams[i].gasLimit,
                "gasLimit mismatch"
            );
        }

        RequestMetadata memory payloadRequest = deliveryHelper.getRequestMetadata(requestCount);

        assertEq(payloadRequest.appGateway, appGateway_, "AppGateway mismatch");
        assertEq(payloadRequest.auctionManager, address(auctionManager), "AuctionManager mismatch");
        assertEq(payloadRequest.winningBid.fee, bidAmount, "WinningBid mismatch");
        assertEq(
            payloadRequest.winningBid.transmitter,
            transmitterEOA,
            "WinningBid transmitter mismatch"
        );
    }
}
