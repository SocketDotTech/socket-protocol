// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../contracts/utils/common/Structs.sol";
import "../contracts/utils/common/Errors.sol";
import "../contracts/utils/common/Constants.sol";
import "../contracts/utils/common/AccessRoles.sol";
import "../contracts/utils/common/IdUtils.sol";

import "../contracts/evmx/interfaces/IForwarder.sol";

import "../contracts/protocol/Socket.sol";
import "../contracts/protocol/switchboard/FastSwitchboard.sol";
import "../contracts/protocol/switchboard/CCTPSwitchboard.sol";
import "../contracts/protocol/SocketBatcher.sol";
import "../contracts/protocol/SocketFeeManager.sol";

import "../contracts/evmx/watcher/Watcher.sol";
import "../contracts/evmx/watcher/Configurations.sol";
import "../contracts/evmx/watcher/RequestHandler.sol";
import "../contracts/evmx/watcher/PromiseResolver.sol";
import "../contracts/evmx/watcher/precompiles/WritePrecompile.sol";
import "../contracts/evmx/watcher/precompiles/ReadPrecompile.sol";
import "../contracts/evmx/watcher/precompiles/SchedulePrecompile.sol";

import "../contracts/evmx/helpers/AddressResolver.sol";
import "../contracts/evmx/helpers/AsyncDeployer.sol";
import "../contracts/evmx/helpers/DeployForwarder.sol";
import "../contracts/evmx/plugs/ContractFactoryPlug.sol";
import "../contracts/evmx/fees/FeesManager.sol";
import "../contracts/evmx/fees/FeesPool.sol";
import "../contracts/evmx/plugs/FeesPlug.sol";
import "../contracts/evmx/AuctionManager.sol";
import "../contracts/evmx/mocks/TestUSDC.sol";
import "./mock/CCTPMessageTransmitter.sol";

import "solady/utils/ERC1967Factory.sol";

contract SetupStore is Test {
    uint256 c = 1;
    uint64 version = 1;

    uint256 watcherPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 transmitterPrivateKey =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address watcherEOA = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address transmitterEOA = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address socketOwner = address(uint160(c++));

    uint32 arbChainSlug = 421614;
    uint32 optChainSlug = 11155420;
    uint32 evmxSlug = 1;

    uint256 expiryTime = 864000;
    uint256 bidTimeout = 86400;
    uint256 maxReAuctionCount = 10;
    uint256 auctionEndDelaySeconds = 0;
    uint256 maxScheduleDelayInSeconds = 86400;
    uint256 maxMsgValueLimit = 1 ether;

    uint256 writeFees = 10000;
    uint256 readFees = 10000;
    uint256 scheduleCallbackFees = 10000;
    uint256 scheduleFeesPerSecond = 10000;
    uint256 triggerFees = 10000;
    uint256 socketFees = 0;

    uint256 public watcherNonce;
    uint256 public payloadIdCounter;
    uint256 public triggerCounter;
    uint256 public asyncPromiseCounter;

    struct SocketContracts {
        uint32 chainSlug;
        Socket socket;
        SocketFeeManager socketFeeManager;
        FastSwitchboard switchboard;
        CCTPSwitchboard cctpSwitchboard;
        CCTPMessageTransmitter cctpMessageTransmitter;
        SocketBatcher socketBatcher;
        ContractFactoryPlug contractFactoryPlug;
        FeesPlug feesPlug;
        TestUSDC testUSDC;
    }
    SocketContracts public arbConfig;
    SocketContracts public optConfig;

    FeesManager feesManagerImpl;
    AddressResolver addressResolverImpl;
    AsyncDeployer asyncDeployerImpl;
    Watcher watcherImpl;
    AuctionManager auctionManagerImpl;
    DeployForwarder deployForwarderImpl;
    Configurations configurationsImpl;
    RequestHandler requestHandlerImpl;
    WritePrecompile writePrecompileImpl;

    ERC1967Factory public proxyFactory;
    FeesManager feesManager;
    FeesPool feesPool;
    AddressResolver public addressResolver;
    AsyncDeployer public asyncDeployer;
    DeployForwarder public deployForwarder;
    AuctionManager auctionManager;

    Watcher public watcher;
    Configurations public configurations;
    RequestHandler public requestHandler;
    PromiseResolver public promiseResolver;
    WritePrecompile public writePrecompile;
    ReadPrecompile public readPrecompile;
    SchedulePrecompile public schedulePrecompile;
}

contract DeploySetup is SetupStore {
    event Initialized(uint64 version);

    //////////////////////////////////// Setup ////////////////////////////////////
    function _deploy() internal {
        _deployEVMxCore();

        // chain core contracts
        arbConfig = _deploySocket(arbChainSlug);
        _configureChain(arbChainSlug);
        optConfig = _deploySocket(optChainSlug);
        _configureChain(optChainSlug);

        vm.startPrank(socketOwner);
        arbConfig.cctpSwitchboard.addRemoteEndpoint(
            optChainSlug,
            optChainSlug,
            address(optConfig.cctpSwitchboard),
            optChainSlug
        );
        optConfig.cctpSwitchboard.addRemoteEndpoint(
            arbChainSlug,
            arbChainSlug,
            address(arbConfig.cctpSwitchboard),
            arbChainSlug
        );
        vm.stopPrank();
        // transfer eth to fees pool for native fee payouts
        vm.deal(address(feesPool), 100000 ether);

        vm.startPrank(watcherEOA);
        auctionManager.grantRole(TRANSMITTER_ROLE, transmitterEOA);
        feesPool.grantRole(FEE_MANAGER_ROLE, address(feesManager));

        // setup address resolver
        addressResolver.setWatcher(address(watcher));
        addressResolver.setAsyncDeployer(address(asyncDeployer));
        addressResolver.setDefaultAuctionManager(address(auctionManager));
        addressResolver.setFeesManager(address(feesManager));
        addressResolver.setDeployForwarder(address(deployForwarder));

        requestHandler.setPrecompile(WRITE, writePrecompile);
        requestHandler.setPrecompile(READ, readPrecompile);
        requestHandler.setPrecompile(SCHEDULE, schedulePrecompile);

        watcher.setCoreContracts(
            address(requestHandler),
            address(configurations),
            address(promiseResolver)
        );
        vm.stopPrank();

        _connectCorePlugs();
        _setupTransmitter();
    }

    function _setupTransmitter() internal {
        vm.startPrank(transmitterEOA);
        arbConfig.testUSDC.mint(address(transmitterEOA), 100 ether);
        arbConfig.testUSDC.approve(address(arbConfig.feesPlug), 100 ether);

        arbConfig.feesPlug.depositCreditAndNative(
            address(arbConfig.testUSDC),
            address(transmitterEOA),
            100 ether
        );

        feesManager.approveAppGateway(address(auctionManager), true);
        vm.stopPrank();
    }

    function _connectCorePlugs() internal {
        AppGatewayConfig[] memory configs = new AppGatewayConfig[](4);
        configs[0] = AppGatewayConfig({
            chainSlug: arbChainSlug,
            plug: address(arbConfig.feesPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(feesManager)),
                switchboard: address(arbConfig.switchboard)
            })
        });
        configs[1] = AppGatewayConfig({
            chainSlug: optChainSlug,
            plug: address(optConfig.feesPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(feesManager)),
                switchboard: address(optConfig.switchboard)
            })
        });
        configs[2] = AppGatewayConfig({
            chainSlug: arbChainSlug,
            plug: address(arbConfig.contractFactoryPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(writePrecompile)),
                switchboard: address(arbConfig.switchboard)
            })
        });
        configs[3] = AppGatewayConfig({
            chainSlug: optChainSlug,
            plug: address(optConfig.contractFactoryPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(writePrecompile)),
                switchboard: address(optConfig.switchboard)
            })
        });

        watcherMultiCall(
            address(configurations),
            abi.encodeWithSelector(Configurations.setAppGatewayConfigs.selector, configs)
        );
    }

    function _deploySocket(uint32 chainSlug_) internal returns (SocketContracts memory) {
        // socket
        Socket socket = new Socket(chainSlug_, socketOwner, "test");
        CCTPMessageTransmitter cctpMessageTransmitter = new CCTPMessageTransmitter(
            chainSlug_,
            address(0)
        );
        return
            SocketContracts({
                chainSlug: chainSlug_,
                socket: socket,
                socketFeeManager: new SocketFeeManager(socketOwner, socketFees),
                switchboard: new FastSwitchboard(chainSlug_, socket, socketOwner),
                cctpSwitchboard: new CCTPSwitchboard(
                    chainSlug_,
                    socket,
                    socketOwner,
                    address(cctpMessageTransmitter)
                ),
                cctpMessageTransmitter: cctpMessageTransmitter,
                socketBatcher: new SocketBatcher(socketOwner, socket),
                contractFactoryPlug: new ContractFactoryPlug(address(socket), socketOwner),
                feesPlug: new FeesPlug(address(socket), socketOwner),
                testUSDC: new TestUSDC("USDC", "USDC", 6, socketOwner, 1000000000000000000000000)
            });
    }

    function _configureChain(uint32 chainSlug_) internal {
        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        Socket socket = socketConfig.socket;
        FastSwitchboard switchboard = socketConfig.switchboard;
        CCTPSwitchboard cctpSwitchboard = socketConfig.cctpSwitchboard;
        FeesPlug feesPlug = socketConfig.feesPlug;
        ContractFactoryPlug contractFactoryPlug = socketConfig.contractFactoryPlug;

        vm.startPrank(socketOwner);
        // socket
        socket.grantRole(GOVERNANCE_ROLE, address(socketOwner));
        socket.grantRole(RESCUE_ROLE, address(socketOwner));
        socket.grantRole(SWITCHBOARD_DISABLER_ROLE, address(socketOwner));

        // switchboard
        switchboard.registerSwitchboard();
        switchboard.grantRole(WATCHER_ROLE, watcherEOA);
        switchboard.grantRole(RESCUE_ROLE, address(socketOwner));

        cctpSwitchboard.registerSwitchboard();
        cctpSwitchboard.grantRole(WATCHER_ROLE, watcherEOA);

        feesPlug.grantRole(RESCUE_ROLE, address(socketOwner));
        feesPlug.whitelistToken(address(socketConfig.testUSDC));
        feesPlug.connectSocket(
            encodeAppGatewayId(address(feesManager)),
            address(socket),
            address(switchboard)
        );

        contractFactoryPlug.grantRole(RESCUE_ROLE, address(socketOwner));
        contractFactoryPlug.connectSocket(
            encodeAppGatewayId(address(writePrecompile)),
            address(socket),
            address(switchboard)
        );

        vm.stopPrank();

        vm.startPrank(watcherEOA);
        configurations.setSocket(chainSlug_, address(socket));
        configurations.setSwitchboard(chainSlug_, FAST, address(switchboard));
        configurations.setSwitchboard(chainSlug_, CCTP, address(cctpSwitchboard));

        // plugs
        feesManager.setFeesPlug(chainSlug_, address(feesPlug));

        // precompiles
        writePrecompile.updateChainMaxMsgValueLimits(chainSlug_, maxMsgValueLimit);
        writePrecompile.setContractFactoryPlugs(chainSlug_, address(contractFactoryPlug));

        vm.stopPrank();
    }

    function _deployEVMxCore() internal {
        proxyFactory = new ERC1967Factory();
        feesPool = new FeesPool(watcherEOA);

        // Deploy implementations for upgradeable contracts
        feesManagerImpl = new FeesManager();
        addressResolverImpl = new AddressResolver();
        asyncDeployerImpl = new AsyncDeployer();
        watcherImpl = new Watcher();
        auctionManagerImpl = new AuctionManager();
        deployForwarderImpl = new DeployForwarder();
        configurationsImpl = new Configurations();
        requestHandlerImpl = new RequestHandler();
        writePrecompileImpl = new WritePrecompile();

        // Deploy and initialize proxies
        address addressResolverProxy = _deployAndVerifyProxy(
            address(addressResolverImpl),
            watcherEOA,
            abi.encodeWithSelector(AddressResolver.initialize.selector, watcherEOA)
        );
        addressResolver = AddressResolver(addressResolverProxy);

        address feesManagerProxy = _deployAndVerifyProxy(
            address(feesManagerImpl),
            watcherEOA,
            abi.encodeWithSelector(
                FeesManager.initialize.selector,
                evmxSlug,
                address(addressResolver),
                address(feesPool),
                watcherEOA,
                FAST
            )
        );
        feesManager = FeesManager(feesManagerProxy);

        address asyncDeployerProxy = _deployAndVerifyProxy(
            address(asyncDeployerImpl),
            watcherEOA,
            abi.encodeWithSelector(
                AsyncDeployer.initialize.selector,
                watcherEOA,
                address(addressResolver)
            )
        );
        asyncDeployer = AsyncDeployer(asyncDeployerProxy);

        address auctionManagerProxy = _deployAndVerifyProxy(
            address(auctionManagerImpl),
            watcherEOA,
            abi.encodeWithSelector(
                AuctionManager.initialize.selector,
                evmxSlug,
                uint128(bidTimeout),
                maxReAuctionCount,
                auctionEndDelaySeconds,
                address(addressResolver),
                watcherEOA
            )
        );
        auctionManager = AuctionManager(auctionManagerProxy);

        address deployForwarderProxy = _deployAndVerifyProxy(
            address(deployForwarderImpl),
            watcherEOA,
            abi.encodeWithSelector(
                DeployForwarder.initialize.selector,
                watcherEOA,
                address(addressResolver),
                FAST
            )
        );
        deployForwarder = DeployForwarder(deployForwarderProxy);

        address watcherProxy = _deployAndVerifyProxy(
            address(watcherImpl),
            watcherEOA,
            abi.encodeWithSelector(
                Watcher.initialize.selector,
                evmxSlug,
                triggerFees,
                watcherEOA,
                address(addressResolver)
            )
        );
        watcher = Watcher(watcherProxy);

        address requestHandlerProxy = _deployAndVerifyProxy(
            address(requestHandlerImpl),
            watcherEOA,
            abi.encodeWithSelector(
                RequestHandler.initialize.selector,
                watcherEOA,
                address(addressResolver)
            )
        );
        requestHandler = RequestHandler(requestHandlerProxy);

        address configurationsProxy = _deployAndVerifyProxy(
            address(configurationsImpl),
            watcherEOA,
            abi.encodeWithSelector(Configurations.initialize.selector, address(watcher), watcherEOA)
        );
        configurations = Configurations(configurationsProxy);

        address writePrecompileProxy = _deployAndVerifyProxy(
            address(writePrecompileImpl),
            watcherEOA,
            abi.encodeWithSelector(
                WritePrecompile.initialize.selector,
                watcherEOA,
                address(watcher),
                writeFees,
                expiryTime
            )
        );
        writePrecompile = WritePrecompile(writePrecompileProxy);

        // non proxy contracts
        promiseResolver = new PromiseResolver(address(watcher));
        readPrecompile = new ReadPrecompile(address(watcher), readFees, expiryTime);
        schedulePrecompile = new SchedulePrecompile(
            address(watcher),
            maxScheduleDelayInSeconds,
            scheduleFeesPerSecond,
            scheduleCallbackFees,
            expiryTime
        );
    }

    function _deployAndVerifyProxy(
        address implementation_,
        address owner_,
        bytes memory data_
    ) internal returns (address) {
        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        return address(proxyFactory.deployAndCall(implementation_, owner_, data_));
    }

    function getSocketConfig(uint32 chainSlug_) internal view returns (SocketContracts memory) {
        return chainSlug_ == arbChainSlug ? arbConfig : optConfig;
    }

    function watcherMultiCall(address contractAddress_, bytes memory data_) internal {
        WatcherMultiCallParams[] memory params = new WatcherMultiCallParams[](1);
        params[0] = WatcherMultiCallParams({
            contractAddress: contractAddress_,
            data: data_,
            nonce: watcherNonce,
            signature: _createWatcherSignature(contractAddress_, data_)
        });
        watcherNonce++;
        watcher.watcherMultiCall(params);
    }

    function _createWatcherSignature(
        address contractAddress_,
        bytes memory data_
    ) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encode(address(watcher), evmxSlug, watcherNonce, contractAddress_, data_)
        );
        return _createSignature(digest, watcherPrivateKey);
    }

    function _createSignature(
        bytes32 digest_,
        uint256 privateKey_
    ) internal pure returns (bytes memory sig) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(privateKey_, digest);
        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);
        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }

    function predictAsyncPromiseAddress(
        address invoker_,
        address forwarder_
    ) internal returns (address) {
        bytes memory asyncPromiseBytecode = type(AsyncPromise).creationCode;
        bytes memory constructorArgs = abi.encode(invoker_, forwarder_, address(addressResolver));
        bytes memory combinedBytecode = abi.encodePacked(asyncPromiseBytecode, constructorArgs);

        bytes32 salt = keccak256(abi.encodePacked(constructorArgs, asyncPromiseCounter++));

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
}

contract FeesSetup is DeploySetup {
    event Deposited(
        uint32 indexed chainSlug,
        address indexed token,
        address indexed appGateway,
        uint256 creditAmount,
        uint256 nativeAmount
    );
    event CreditsWrapped(address indexed consumeFrom, uint256 amount);
    event CreditsUnwrapped(address indexed consumeFrom, uint256 amount);
    event CreditsTransferred(address indexed from, address indexed to, uint256 amount);

    function deploy() internal {
        _deploy();

        depositNativeAndCredits(arbChainSlug, 100 ether, 100 ether, address(transmitterEOA));
        approveAppGateway(address(auctionManager), address(transmitterEOA));
    }

    // mints test token and deposits the given  native and credits to given `user_`
    function depositNativeAndCredits(
        uint32 chainSlug_,
        uint256 credits_,
        uint256 native_,
        address user_
    ) internal {
        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        TestUSDC token = socketConfig.testUSDC;

        uint256 userBalance = token.balanceOf(user_);
        uint256 feesPlugBalance = token.balanceOf(address(socketConfig.feesPlug));

        token.mint(address(user_), 100 ether);
        assertEq(
            token.balanceOf(user_),
            userBalance + 100 ether,
            "User should have 100 more test tokens"
        );

        vm.startPrank(user_);
        token.approve(address(socketConfig.feesPlug), 100 ether);
        socketConfig.feesPlug.depositCreditAndNative(address(token), address(user_), 100 ether);
        vm.stopPrank();

        assertEq(
            token.balanceOf(address(socketConfig.feesPlug)),
            feesPlugBalance + 100 ether,
            "Fees plug should have 100 more test tokens"
        );

        uint256 currentCredits = feesManager.getAvailableCredits(user_);
        uint256 currentNative = address(user_).balance;

        vm.expectEmit(true, true, true, false);
        emit Deposited(chainSlug_, address(token), user_, credits_, native_);

        watcherMultiCall(
            address(feesManager),
            abi.encodeWithSelector(
                Credit.deposit.selector,
                chainSlug_,
                address(token),
                user_,
                native_,
                credits_
            )
        );

        assertEq(
            feesManager.getAvailableCredits(user_),
            currentCredits + credits_,
            "User should have more credits"
        );
        assertEq(address(user_).balance, currentNative + native_, "User should have more native");
    }

    function approveAppGateway(address appGateway_, address user_) internal {
        bool approval = feesManager.isApproved(user_, appGateway_);
        if (approval) return;

        AppGatewayApprovals[] memory approvals = new AppGatewayApprovals[](1);
        approvals[0] = AppGatewayApprovals({appGateway: appGateway_, approval: true});

        hoax(user_);
        feesManager.approveAppGateways(approvals);

        assertEq(
            feesManager.isApproved(user_, appGateway_),
            true,
            "App gateway should be approved"
        );
    }

    function approveAppGatewayWithSignature(
        address appGateway_,
        address user_,
        uint256 userPrivateKey_
    ) internal {
        bool approval = feesManager.isApproved(user_, appGateway_);
        if (approval) return;

        // Create fee approval data with signature
        bytes32 digest = keccak256(
            abi.encode(address(feesManager), evmxSlug, appGateway_, block.timestamp, true)
        );

        // Sign with consumeFrom's private key
        bytes memory signature = _createSignature(digest, userPrivateKey_);

        // Encode approval data
        bytes memory feeApprovalData = abi.encode(appGateway_, true, block.timestamp, signature);

        // Call whitelistAppGatewayWithSignature with approval data
        feesManager.approveAppGatewayWithSignature(feeApprovalData);
        assertEq(
            feesManager.isApproved(user_, appGateway_),
            true,
            "App gateway should be approved"
        );
    }
}

contract AuctionSetup is FeesSetup {
    event BidPlaced(uint40 requestCount, Bid bid);
    event AuctionStarted(uint40 requestCount);
    event AuctionEnded(uint40 requestCount, Bid winningBid);

    function getBidAmount(uint40 requestCount) internal view returns (uint256) {
        return watcher.getRequestParams(requestCount).requestFeesDetails.maxFees / 2;
    }

    function placeBid(uint40 requestCount) internal {
        uint256 bidAmount = getBidAmount(requestCount);

        bytes memory transmitterSignature = _createSignature(
            keccak256(abi.encode(address(auctionManager), evmxSlug, requestCount, bidAmount, "")),
            transmitterPrivateKey
        );

        if (auctionEndDelaySeconds == 0) {
            vm.expectEmit(true, true, true, false);
            emit AuctionEnded(
                requestCount,
                Bid({fee: bidAmount, transmitter: transmitterEOA, extraData: bytes("")})
            );
        } else {
            vm.expectEmit(true, true, true, false);
            emit AuctionStarted(requestCount);
        }

        vm.expectEmit(true, true, true, false);
        emit BidPlaced(
            requestCount,
            Bid({transmitter: transmitterEOA, fee: bidAmount, extraData: bytes("")})
        );
        auctionManager.bid(requestCount, bidAmount, transmitterSignature, bytes(""));
    }

    function endAuction(uint40 requestCount_) internal {
        if (auctionEndDelaySeconds == 0) return;

        // todo: handle other cases

        uint256 bidAmount = getBidAmount(requestCount_);
        // bytes memory watcherSignature = _createSignature(
        //     keccak256(abi.encode(address(watcher), evmxSlug, requestCount_, bidAmount, "")),
        //     watcherPrivateKey
        // );

        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(
            requestCount_,
            Bid({fee: bidAmount, transmitter: transmitterEOA, extraData: ""})
        );

        // promiseResolver.resolvePromises();
    }

    function bidAndEndAuction(uint40 requestCount) internal {
        placeBid(requestCount);
        endAuction(requestCount);
    }

    // tests:
    // bid and end auction with delay
    // bid and end auction with delay and expire bid
}

contract WatcherSetup is AuctionSetup {
    event ReadRequested(Transaction transaction, uint256 readAtBlockNumber, bytes32 payloadId);
    event ScheduleRequested(bytes32 payloadId, uint256 deadline);
    event ScheduleResolved(bytes32 payloadId);
    event WriteProofRequested(
        address transmitter,
        bytes32 digest,
        bytes32 prevBatchDigestHash,
        uint256 deadline,
        PayloadParams payloadParams
    );
    event WriteProofUploaded(bytes32 indexed payloadId, bytes proof);

    function executeDeployMultiChain(
        IAppGateway appGateway_,
        uint32[] memory chainSlugs_,
        bytes32[] memory contractIds_
    ) internal returns (uint40 requestCount) {
        return _executeDeploy(appGateway_, chainSlugs_, contractIds_);
    }

    function executeDeploy(
        IAppGateway appGateway_,
        uint32 chainSlug_,
        bytes32[] memory contractIds_
    ) internal returns (uint40 requestCount) {
        uint32[] memory chainSlugs = new uint32[](1);
        chainSlugs[0] = chainSlug_;
        return _executeDeploy(appGateway_, chainSlugs, contractIds_);
    }

    function _executeDeploy(
        IAppGateway appGateway_,
        uint32[] memory chainSlugs_,
        bytes32[] memory contractIds_
    ) internal returns (uint40 requestCount) {
        requestCount = executeRequest();
        for (uint i = 0; i < chainSlugs_.length; i++) {
            setupGatewayAndPlugs(chainSlugs_[i], appGateway_, contractIds_);
        }
    }

    function executeRequest() internal returns (uint40 requestCount) {
        requestCount = watcher.getCurrentRequestCount();
        requestCount = requestCount == 0 ? 0 : requestCount - 1;

        RequestParams memory requestParams = requestHandler.getRequest(requestCount);
        uint40[] memory batches = requestHandler.getRequestBatchIds(requestCount);

        // bids and executes schedule request if created for endAuction
        if (requestParams.writeCount != 0) bidAndEndAuction(requestCount);

        bool isRequestExecuted;
        for (uint i = 0; i < batches.length; i++) {
            isRequestExecuted = _processBatch(batches[i]);
            if (!isRequestExecuted) break;
        }

        requestParams = requestHandler.getRequest(requestCount);
        assertEq(requestParams.requestTrackingParams.isRequestExecuted, isRequestExecuted);
    }

    function _processBatch(uint40 batchCount_) internal returns (bool) {
        bytes32[] memory payloadIds = requestHandler.getBatchPayloadIds(batchCount_);

        PromiseReturnData[] memory promiseReturnData = new PromiseReturnData[](1);
        bool success;
        for (uint i = 0; i < payloadIds.length; i++) {
            PayloadParams memory payloadParams = watcher.getPayloadParams(payloadIds[i]);

            if (payloadParams.callType == READ) {
                (success, promiseReturnData[0]) = _processRead(payloadParams);
            } else if (payloadParams.callType == WRITE) {
                (success, promiseReturnData[0]) = _processWrite(payloadParams);
            } else if (payloadParams.callType == SCHEDULE) {
                vm.warp(payloadParams.deadline - expiryTime);
                promiseReturnData[0] = PromiseReturnData({
                    exceededMaxCopy: false,
                    payloadId: payloadParams.payloadId,
                    returnData: bytes("")
                });
                success = true;
            }

            if (success) {
                _resolvePromise(promiseReturnData);
            } else {
                vm.warp(payloadParams.deadline);
                _markRevert(promiseReturnData[0], true);
                return false;
            }
        }

        return true;
    }

    function _processRead(
        PayloadParams memory payloadParams
    ) internal returns (bool success, PromiseReturnData memory promiseReturnData) {
        (Transaction memory transaction, ) = abi.decode(
            payloadParams.precompileData,
            (Transaction, uint256)
        );

        bytes memory returnData;
        (success, returnData) = transaction.target.call(transaction.payload);
        promiseReturnData = PromiseReturnData({
            exceededMaxCopy: false,
            payloadId: payloadParams.payloadId,
            returnData: returnData
        });
    }

    function _processWrite(
        PayloadParams memory payloadParams
    ) internal returns (bool success, PromiseReturnData memory promiseReturnData) {
        bytes32 payloadId = payloadParams.payloadId;

        (
            uint32 chainSlug,
            address switchboard,
            bytes32 digest,
            DigestParams memory digestParams
        ) = _validateAndGetDigest(payloadParams);

        bytes memory watcherProof = _uploadProof(payloadId, digest, switchboard, chainSlug);

        return
            _executeWrite(
                chainSlug,
                switchboard,
                digest,
                digestParams,
                payloadParams,
                watcherProof
            );
    }

    function _uploadProof(
        bytes32 payloadId,
        bytes32 digest,
        address switchboard,
        uint32 chainSlug
    ) internal returns (bytes memory proof) {
        proof = _createSignature(
            keccak256(abi.encode(address(switchboard), chainSlug, digest)),
            watcherPrivateKey
        );

        vm.expectEmit(true, true, true, false);
        emit WriteProofUploaded(payloadId, proof);
        watcherMultiCall(
            address(writePrecompile),
            abi.encodeWithSelector(WritePrecompile.uploadProof.selector, payloadId, proof)
        );
        assertEq(writePrecompile.watcherProofs(payloadId), proof);
    }

    function _validateAndGetDigest(
        PayloadParams memory payloadParams
    )
        internal
        view
        returns (
            uint32 chainSlug,
            address switchboard,
            bytes32 digest,
            DigestParams memory digestParams
        )
    {
        (
            address appGateway,
            Transaction memory transaction,
            ,
            uint256 gasLimit,
            uint256 value,
            address switchboard_
        ) = abi.decode(
                payloadParams.precompileData,
                (address, Transaction, WriteFinality, uint256, uint256, address)
            );

        chainSlug = transaction.chainSlug;
        switchboard = switchboard_;

        bytes32 prevBatchDigestHash = writePrecompile.getPrevBatchDigestHash(
            payloadParams.requestCount,
            payloadParams.batchCount
        );
        digestParams = DigestParams(
            address(getSocketConfig(transaction.chainSlug).socket),
            transmitterEOA,
            payloadParams.payloadId,
            payloadParams.deadline,
            payloadParams.callType,
            gasLimit,
            value,
            transaction.payload,
            transaction.target,
            encodeAppGatewayId(appGateway),
            prevBatchDigestHash,
            bytes("")
        );

        digest = writePrecompile.getDigest(digestParams);
        assertEq(writePrecompile.digestHashes(payloadParams.payloadId), digest);
    }

    function _executeWrite(
        uint32 chainSlug,
        address switchboard,
        bytes32 digest,
        DigestParams memory digestParams,
        PayloadParams memory payloadParams,
        bytes memory watcherProof
    ) internal returns (bool success, PromiseReturnData memory promiseReturnData) {
        bytes memory transmitterSig = _createSignature(
            keccak256(
                abi.encode(address(getSocketConfig(chainSlug).socket), payloadParams.payloadId)
            ),
            transmitterPrivateKey
        );
        bytes memory returnData;
        ExecuteParams memory executeParams = ExecuteParams({
            callType: digestParams.callType,
            deadline: digestParams.deadline,
            gasLimit: digestParams.gasLimit,
            value: digestParams.value,
            payload: digestParams.payload,
            target: digestParams.target,
            requestCount: payloadParams.requestCount,
            batchCount: payloadParams.batchCount,
            payloadCount: payloadParams.payloadCount,
            prevBatchDigestHash: digestParams.prevBatchDigestHash,
            extraData: digestParams.extraData
        });
        if (switchboard == address(getSocketConfig(chainSlug).switchboard)) {
            (success, returnData) = getSocketConfig(chainSlug).socketBatcher.attestAndExecute(
                executeParams,
                switchboard,
                digest,
                watcherProof,
                transmitterSig,
                transmitterEOA
            );
        } else if (switchboard == address(getSocketConfig(chainSlug).cctpSwitchboard)) {
            (success, returnData) = _executeWithCCTPBatcher(
                chainSlug,
                executeParams,
                digest,
                watcherProof,
                transmitterSig,
                payloadParams
            );
        }
        promiseReturnData = PromiseReturnData({
            exceededMaxCopy: false,
            payloadId: payloadParams.payloadId,
            returnData: returnData
        });
    }
    function _executeWithCCTPBatcher(
        uint32 chainSlug,
        ExecuteParams memory executeParams,
        bytes32 digest,
        bytes memory watcherProof,
        bytes memory transmitterSig,
        PayloadParams memory payloadParams
    ) internal returns (bool success, bytes memory returnData) {
        CCTPBatchParams memory cctpBatchParams = _prepareCCTPBatchData(chainSlug, payloadParams);

        return
            getSocketConfig(chainSlug).socketBatcher.attestCCTPAndProveAndExecute(
                CCTPExecutionParams({
                    executeParams: executeParams,
                    digest: digest,
                    proof: watcherProof,
                    transmitterSignature: transmitterSig,
                    refundAddress: transmitterEOA
                }),
                cctpBatchParams,
                address(getSocketConfig(chainSlug).cctpSwitchboard)
            );
    }

    function _prepareCCTPBatchData(
        uint32 chainSlug,
        PayloadParams memory payloadParams
    ) internal view returns (CCTPBatchParams memory cctpBatchParams) {
        uint40[] memory requestBatchIds = requestHandler.getRequestBatchIds(
            payloadParams.requestCount
        );
        uint40 currentBatchCount = payloadParams.batchCount;

        bytes32[] memory prevBatchPayloadIds = _getPrevBatchPayloadIds(
            currentBatchCount,
            requestBatchIds
        );
        bytes32[] memory nextBatchPayloadIds = _getNextBatchPayloadIds(
            currentBatchCount,
            requestBatchIds
        );

        uint32[] memory prevBatchRemoteChainSlugs = _getRemoteChainSlugs(prevBatchPayloadIds);
        uint32[] memory nextBatchRemoteChainSlugs = _getRemoteChainSlugs(nextBatchPayloadIds);

        bytes[] memory messages = _createCCTPMessages(
            prevBatchPayloadIds,
            prevBatchRemoteChainSlugs,
            chainSlug
        );

        cctpBatchParams = CCTPBatchParams({
            previousPayloadIds: prevBatchPayloadIds,
            nextBatchRemoteChainSlugs: nextBatchRemoteChainSlugs,
            messages: messages,
            attestations: new bytes[](prevBatchPayloadIds.length) // using mock attestations for now
        });
    }

    function _getPrevBatchPayloadIds(
        uint40 currentBatchCount,
        uint40[] memory requestBatchIds
    ) internal view returns (bytes32[] memory) {
        if (currentBatchCount == requestBatchIds[0]) {
            return new bytes32[](0);
        }
        return requestHandler.getBatchPayloadIds(currentBatchCount - 1);
    }

    function _getNextBatchPayloadIds(
        uint40 currentBatchCount,
        uint40[] memory requestBatchIds
    ) internal view returns (bytes32[] memory) {
        if (currentBatchCount == requestBatchIds[requestBatchIds.length - 1]) {
            return new bytes32[](0);
        }
        return requestHandler.getBatchPayloadIds(currentBatchCount + 1);
    }

    function _getRemoteChainSlugs(
        bytes32[] memory payloadIds
    ) internal view returns (uint32[] memory) {
        uint32[] memory chainSlugs = new uint32[](payloadIds.length);
        for (uint i = 0; i < payloadIds.length; i++) {
            PayloadParams memory params = requestHandler.getPayload(payloadIds[i]);
            (, Transaction memory transaction, , , , ) = abi.decode(
                params.precompileData,
                (address, Transaction, WriteFinality, uint256, uint256, address)
            );
            chainSlugs[i] = transaction.chainSlug;
        }
        return chainSlugs;
    }

    function _createCCTPMessages(
        bytes32[] memory payloadIds,
        uint32[] memory remoteChainSlugs,
        uint32 chainSlug
    ) internal view returns (bytes[] memory) {
        bytes[] memory messages = new bytes[](payloadIds.length);
        for (uint i = 0; i < payloadIds.length; i++) {
            messages[i] = abi.encode(
                remoteChainSlugs[i],
                addressToBytes32(address(getSocketConfig(remoteChainSlugs[i]).cctpSwitchboard)),
                chainSlug,
                addressToBytes32(address(getSocketConfig(chainSlug).cctpSwitchboard)),
                abi.encode(payloadIds[i], writePrecompile.digestHashes(payloadIds[i]))
            );
        }
        return messages;
    }

    function addressToBytes32(address addr_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr_)));
    }
    function bytes32ToAddress(bytes32 addrBytes32_) internal pure returns (address) {
        return address(uint160(uint256(addrBytes32_)));
    }

    function _resolvePromise(PromiseReturnData[] memory promiseReturnData) internal {
        watcherMultiCall(
            address(promiseResolver),
            abi.encodeWithSelector(PromiseResolver.resolvePromises.selector, promiseReturnData)
        );
    }

    function _markRevert(
        PromiseReturnData memory promiseReturnData,
        bool isRevertingOnchain_
    ) internal {
        watcherMultiCall(
            address(promiseResolver),
            abi.encodeWithSelector(
                PromiseResolver.markRevert.selector,
                promiseReturnData,
                isRevertingOnchain_
            )
        );
    }

    function setupGatewayAndPlugs(
        uint32 chainSlug_,
        IAppGateway appGateway_,
        bytes32[] memory contractIds_
    ) internal {
        AppGatewayConfig[] memory configs = new AppGatewayConfig[](contractIds_.length);

        for (uint i = 0; i < contractIds_.length; i++) {
            address plug = appGateway_.getOnChainAddress(contractIds_[i], chainSlug_);
            address switchboard = configurations.switchboards(chainSlug_, appGateway_.sbType());
            configs[i] = AppGatewayConfig({
                plug: plug,
                chainSlug: chainSlug_,
                plugConfig: PlugConfig({
                    appGatewayId: encodeAppGatewayId(address(appGateway_)),
                    switchboard: switchboard
                })
            });
        }
        watcherMultiCall(
            address(configurations),
            abi.encodeWithSelector(Configurations.setAppGatewayConfigs.selector, configs)
        );
    }
}
contract AppGatewayBaseSetup is WatcherSetup {
    function getOnChainAndForwarderAddresses(
        uint32 chainSlug_,
        bytes32 contractId_,
        IAppGateway appGateway_
    ) internal view returns (address, address) {
        address app = appGateway_.getOnChainAddress(contractId_, chainSlug_);
        address forwarder = appGateway_.forwarderAddresses(contractId_, chainSlug_);
        return (app, forwarder);
    }

    // todo: add checks for request params and payload params created to match what is expected

    function checkRequestParams(
        uint40 requestCount,
        RequestParams memory expectedRequest
    ) internal view {
        RequestParams memory actualRequest = watcher.getRequestParams(requestCount);
        // RequestParams checks
        assertEq(
            actualRequest.appGateway,
            expectedRequest.appGateway,
            "Request: appGateway mismatch"
        );
        assertEq(
            actualRequest.auctionManager,
            expectedRequest.auctionManager,
            "Request: auctionManager mismatch"
        );
        assertEq(
            actualRequest.writeCount,
            expectedRequest.writeCount,
            "Request: writeCount mismatch"
        );
        assertEq(
            keccak256(actualRequest.onCompleteData),
            keccak256(expectedRequest.onCompleteData),
            "Request: onCompleteData mismatch"
        );
        // Nested struct checks (RequestTrackingParams)
        assertEq(
            actualRequest.requestTrackingParams.isRequestCancelled,
            expectedRequest.requestTrackingParams.isRequestCancelled,
            "RequestTrackingParams: isRequestCancelled mismatch"
        );
        assertEq(
            actualRequest.requestTrackingParams.isRequestExecuted,
            expectedRequest.requestTrackingParams.isRequestExecuted,
            "RequestTrackingParams: isRequestExecuted mismatch"
        );
        assertEq(
            actualRequest.requestTrackingParams.currentBatch,
            expectedRequest.requestTrackingParams.currentBatch,
            "RequestTrackingParams: currentBatch mismatch"
        );
        assertEq(
            actualRequest.requestTrackingParams.currentBatchPayloadsLeft,
            expectedRequest.requestTrackingParams.currentBatchPayloadsLeft,
            "RequestTrackingParams: currentBatchPayloadsLeft mismatch"
        );
        assertEq(
            actualRequest.requestTrackingParams.payloadsRemaining,
            expectedRequest.requestTrackingParams.payloadsRemaining,
            "RequestTrackingParams: payloadsRemaining mismatch"
        );
        // Nested struct checks (RequestFeesDetails)
        assertEq(
            actualRequest.requestFeesDetails.maxFees,
            expectedRequest.requestFeesDetails.maxFees,
            "RequestFeesDetails: maxFees mismatch"
        );
        assertEq(
            actualRequest.requestFeesDetails.consumeFrom,
            expectedRequest.requestFeesDetails.consumeFrom,
            "RequestFeesDetails: consumeFrom mismatch"
        );
        assertEq(
            actualRequest.requestFeesDetails.winningBid.fee,
            expectedRequest.requestFeesDetails.winningBid.fee,
            "RequestFeesDetails: winningBid.fee mismatch"
        );
        assertEq(
            actualRequest.requestFeesDetails.winningBid.transmitter,
            expectedRequest.requestFeesDetails.winningBid.transmitter,
            "RequestFeesDetails: winningBid.transmitter mismatch"
        );
        assertEq(
            keccak256(actualRequest.requestFeesDetails.winningBid.extraData),
            keccak256(expectedRequest.requestFeesDetails.winningBid.extraData),
            "RequestFeesDetails: winningBid.extraData mismatch"
        );
    }

    function checkPayloadParams(PayloadParams[] memory expectedPayloads) internal view {
        for (uint i = 0; i < expectedPayloads.length; i++) {
            PayloadParams memory expectedPayload = expectedPayloads[i];
            PayloadParams memory actualPayload = watcher.getPayloadParams(
                expectedPayload.payloadId
            );
            // PayloadParams checks
            assertEq(
                actualPayload.requestCount,
                expectedPayload.requestCount,
                "Payload: requestCount mismatch"
            );
            assertEq(
                actualPayload.batchCount,
                expectedPayload.batchCount,
                "Payload: batchCount mismatch"
            );
            assertEq(
                actualPayload.payloadCount,
                expectedPayload.payloadCount,
                "Payload: payloadCount mismatch"
            );
            assertEq(
                actualPayload.callType,
                expectedPayload.callType,
                "Payload: callType mismatch"
            );
            assertEq(
                actualPayload.asyncPromise,
                expectedPayload.asyncPromise,
                "Payload: asyncPromise mismatch"
            );
            assertEq(
                actualPayload.appGateway,
                expectedPayload.appGateway,
                "Payload: appGateway mismatch"
            );
            assertEq(
                actualPayload.payloadId,
                expectedPayload.payloadId,
                "Payload: payloadId mismatch"
            );
            assertEq(
                actualPayload.resolvedAt,
                expectedPayload.resolvedAt,
                "Payload: resolvedAt mismatch"
            );
            assertEq(
                actualPayload.deadline,
                expectedPayload.deadline,
                "Payload: deadline mismatch"
            );
            assertEq(
                keccak256(actualPayload.precompileData),
                keccak256(expectedPayload.precompileData),
                "Payload: precompileData mismatch"
            );
        }
    }
}
