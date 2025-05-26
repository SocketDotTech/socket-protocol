// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../contracts/utils/common/Structs.sol";
import "../contracts/utils/common/Errors.sol";
import "../contracts/utils/common/Constants.sol";
import "../contracts/utils/common/AccessRoles.sol";
import "../contracts/utils/common/IdUtils.sol";

import "../contracts/protocol/Socket.sol";
import "../contracts/protocol/switchboard/FastSwitchboard.sol";
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
import "../contracts/evmx/plugs/FeesPlug.sol";
import "../contracts/evmx/AuctionManager.sol";
import "../contracts/evmx/mocks/TestUSDC.sol";

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

    uint256 writeFees = 0.01 ether;
    uint256 readFees = 0.01 ether;
    uint256 scheduleCallbackFees = 0.01 ether;
    uint256 scheduleFeesPerSecond = 0.01 ether;
    uint256 triggerFees = 0.01 ether;
    uint256 socketFees = 0.01 ether;

    uint256 public signatureNonce;
    uint256 public payloadIdCounter;
    uint256 public triggerCounter;
    struct SocketContracts {
        uint32 chainSlug;
        Socket socket;
        SocketFeeManager socketFeeManager;
        FastSwitchboard switchboard;
        SocketBatcher socketBatcher;
        ContractFactoryPlug contractFactoryPlug;
        FeesPlug feesPlug;
        TestUSDC testUSDC;
    }
    SocketContracts public arbConfig;
    SocketContracts public optConfig;

    ERC1967Factory public proxyFactory;
    FeesManager feesManager;
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

contract DeployAndSetupTest is SetupStore {
    event Initialized(uint64 version);
    event FinalizeRequested(bytes32 digest, PayloadParams payloadParams);

    //////////////////////////////////// Setup ////////////////////////////////////
    function deploy() internal {
        _deployEVMxCore();

        // chain core contracts
        arbConfig = _deploySocket(arbChainSlug);
        _configureChain(arbChainSlug);
        optConfig = _deploySocket(optChainSlug);
        _configureChain(optChainSlug);

        vm.startPrank(watcherEOA);
        auctionManager.grantRole(TRANSMITTER_ROLE, transmitterEOA);

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

        _connectPlugs();

        vm.startPrank(transmitterEOA);
        arbConfig.testUSDC.mint(address(transmitterEOA), 100 ether);
        arbConfig.testUSDC.approve(address(arbConfig.feesPlug), 100 ether);

        arbConfig.feesPlug.depositCreditAndNative(
            address(arbConfig.testUSDC),
            address(transmitterEOA),
            100 ether
        );

        AppGatewayApprovals[] memory approvals = new AppGatewayApprovals[](1);
        approvals[0] = AppGatewayApprovals({appGateway: address(auctionManager), approval: true});
        feesManager.approveAppGateways(approvals);
        vm.stopPrank();
    }

    function _connectPlugs() internal {
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
        configs[0] = AppGatewayConfig({
            chainSlug: arbChainSlug,
            plug: address(arbConfig.contractFactoryPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(writePrecompile)),
                switchboard: address(arbConfig.switchboard)
            })
        });
        configs[1] = AppGatewayConfig({
            chainSlug: optChainSlug,
            plug: address(optConfig.contractFactoryPlug),
            plugConfig: PlugConfig({
                appGatewayId: encodeAppGatewayId(address(writePrecompile)),
                switchboard: address(optConfig.switchboard)
            })
        });

        hoax(address(watcher));
        configurations.setPlugConfigs(configs);
    }

    function _deploySocket(uint32 chainSlug_) internal returns (SocketContracts memory) {
        // socket
        Socket socket = new Socket(chainSlug_, socketOwner, "test");

        return
            SocketContracts({
                chainSlug: chainSlug_,
                socket: socket,
                socketFeeManager: new SocketFeeManager(socketOwner, socketFees),
                switchboard: new FastSwitchboard(chainSlug_, socket, socketOwner),
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
        FeesPlug feesPlug = socketConfig.feesPlug;
        ERC20 testUSDC = socketConfig.testUSDC;
        ContractFactoryPlug contractFactoryPlug = socketConfig.contractFactoryPlug;

        vm.startPrank(socketOwner);
        // socket
        socket.grantRole(GOVERNANCE_ROLE, address(socketOwner));

        // switchboard
        switchboard.registerSwitchboard();
        switchboard.grantRole(WATCHER_ROLE, watcherEOA);

        feesPlug.whitelistToken(address(testUSDC));

        feesPlug.connectSocket(
            encodeAppGatewayId(address(auctionManager)),
            address(socket),
            address(switchboard)
        );

        contractFactoryPlug.connectSocket(
            encodeAppGatewayId(address(writePrecompile)),
            address(socket),
            address(switchboard)
        );

        vm.stopPrank();

        vm.startPrank(watcherEOA);
        configurations.setSocket(chainSlug_, address(socket));
        configurations.setSwitchboard(chainSlug_, FAST, address(switchboard));

        // plugs
        feesManager.setFeesPlug(chainSlug_, address(feesPlug));

        // precompiles
        writePrecompile.updateChainMaxMsgValueLimits(chainSlug_, maxMsgValueLimit);
        writePrecompile.setContractFactoryPlugs(chainSlug_, address(contractFactoryPlug));

        vm.stopPrank();
    }

    function _deployEVMxCore() internal {
        proxyFactory = new ERC1967Factory();

        // Deploy implementations for upgradeable contracts
        FeesManager feesManagerImpl = new FeesManager();
        AddressResolver addressResolverImpl = new AddressResolver();
        AsyncDeployer asyncDeployerImpl = new AsyncDeployer();
        Watcher watcherImpl = new Watcher();

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

        // non proxy contracts
        auctionManager = new AuctionManager(
            evmxSlug,
            uint128(bidTimeout),
            maxReAuctionCount,
            auctionEndDelaySeconds,
            address(addressResolver),
            watcherEOA
        );
        deployForwarder = new DeployForwarder(address(addressResolver), FAST);
        configurations = new Configurations(address(watcher), watcherEOA);
        requestHandler = new RequestHandler(watcherEOA, address(addressResolver));
        promiseResolver = new PromiseResolver(address(watcher));
        writePrecompile = new WritePrecompile(watcherEOA, address(watcher), writeFees, expiryTime);
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

    function testDeployAndSetup() public {
        deploy();

        vm.assertEq(address(arbConfig.feesPlug.socket__()), address(arbConfig.socket));
        vm.assertEq(address(optConfig.feesPlug.socket__()), address(optConfig.socket));

        vm.assertEq(address(arbConfig.contractFactoryPlug.socket__()), address(arbConfig.socket));
        vm.assertEq(address(optConfig.contractFactoryPlug.socket__()), address(optConfig.socket));
    }
}

// contract SetupUtilsTest is DeployAndSetupTest {
//     function setUp() public {
//         deploy();
//     }

//     function _checkIfOnlyReads(uint40 batchCount_) internal view returns (bool) {
//         (bytes32[] memory payloadIds, ) = watcher.getBatchPayloadIds(batchCount_);

//         for (uint i = 0; i < payloadIds.length; i++) {
//             PayloadParams memory payloadParams = watcher.getPayloadParams(payloadIds[i]);
//             if (payloadParams.payloadHeader.getCallType() != READ) {
//                 return false;
//             }
//         }

//         return true;
//     }

//     function _resolveAndExpectFinalizeRequested(
//         bytes32 payloadId_,
//         PayloadParams memory payloadParams,
//         bytes memory returnData,
//         bool isLastPayload
//     ) internal {
//         if (isLastPayload) {
//             vm.expectEmit(false, false, false, false);
//             emit FinalizeRequested(payloadId_, payloadParams);
//         }

//         _resolvePromise(payloadId_, returnData);
//     }

//     function _finalizeBatch(
//         uint40 batchCount_,
//         bytes[] memory readReturnData_,
//         uint256 readCount_,
//         bool hasMoreBatches
//     ) internal returns (uint256) {
//         bytes32[] memory payloadIds = watcher.getBatchPayloadIds(batchCount_);

//         for (uint i = 0; i < payloadIds.length; i++) {
//             PayloadParams memory payloadParams = watcher.getPayloadParams(payloadIds[i]);
//             bool isLastPayload = i == payloadIds.length - 1 && hasMoreBatches;

//             if (payloadParams.payloadHeader.getCallType() == READ) {
//                 _resolveAndExpectFinalizeRequested(
//                     payloadParams.payloadId,
//                     payloadParams,
//                     readReturnData_[readCount_++],
//                     isLastPayload
//                 );
//             } else {
//                 (, bytes memory returnData) = _uploadProofAndExecute(payloadParams);
//                 _resolveAndExpectFinalizeRequested(
//                     payloadParams.payloadId,
//                     payloadParams,
//                     returnData,
//                     isLastPayload
//                 );
//             }
//         }
//         return readCount_;
//     }

//     function _uploadProofAndExecute(
//         PayloadParams memory payloadParams
//     ) internal returns (bool, bytes memory) {
//         (bytes memory watcherProof, bytes32 digest) = _generateWatcherProof(payloadParams);
//         _writeProof(payloadParams.payloadId, watcherProof);

//         (
//             ExecuteParams memory params,
//             SocketBatcher socketBatcher,
//             ,
//             bytes memory transmitterSig,
//             address refundAddress
//         ) = _getExecuteParams(payloadParams);

//         return
//             socketBatcher.attestAndExecute(
//                 params,
//                 payloadParams.switchboard,
//                 digest,
//                 watcherProof,
//                 transmitterSig,
//                 refundAddress
//             );
//     }

//     function resolvePromises(bytes32[] memory payloadIds, bytes[] memory returnData) internal {
//         for (uint i = 0; i < payloadIds.length; i++) {
//             _resolvePromise(payloadIds[i], returnData[i]);
//         }
//     }

//     //////////////////////////////////// Helpers ////////////////////////////////////
//

//     function _generateWatcherProof(
//         PayloadParams memory params_
//     ) internal view returns (bytes memory, bytes32) {
//         SocketContracts memory socketConfig = getSocketConfig(params_.payloadHeader.getChainSlug());
//         DigestParams memory digestParams_ = DigestParams(
//             address(socketConfig.socket),
//             transmitterEOA,
//             params_.payloadId,
//             params_.deadline,
//             params_.payloadHeader.getCallType(),
//             params_.gasLimit,
//             params_.value,
//             params_.payload,
//             params_.target,
//             encodeAppGatewayId(params_.appGateway),
//             params_.prevDigestsHash
//         );
//         bytes32 digest = watcher.getDigest(digestParams_);

//         bytes32 sigDigest = keccak256(
//             abi.encode(address(socketConfig.switchboard), socketConfig.chainSlug, digest)
//         );
//         bytes memory proof = _createSignature(sigDigest, watcherPrivateKey);
//         return (proof, digest);
//     }

//     function _writeProof(bytes32 payloadId_, bytes memory watcherProof_) internal {
//         bytes memory bytesInput = abi.encode(
//             IWatcher.finalized.selector,
//             payloadId_,
//             watcherProof_
//         );
//         bytes memory watcherSignature = _createWatcherSignature(address(watcher), bytesInput);
//         watcher.finalized(payloadId_, watcherProof_, signatureNonce++, watcherSignature);
//         assertEq(watcher.watcherProofs(payloadId_), watcherProof_);
//     }

//     function _getExecuteParams(
//         PayloadParams memory payloadParams
//     )
//         internal
//         view
//         returns (
//             ExecuteParams memory params,
//             SocketBatcher socketBatcher,
//             uint256 value,
//             bytes memory transmitterSig,
//             address refundAddress
//         )
//     {
//         SocketContracts memory socketConfig = getSocketConfig(
//             payloadParams.payloadHeader.getChainSlug()
//         );
//         bytes32 transmitterDigest = keccak256(
//             abi.encode(address(socketConfig.socket), payloadParams.payloadId)
//         );
//         transmitterSig = _createSignature(transmitterDigest, transmitterPrivateKey);

//         params = ExecuteParams({
//             callType: payloadParams.payloadHeader.getCallType(),
//             deadline: payloadParams.deadline,
//             gasLimit: payloadParams.gasLimit,
//             value: payloadParams.value,
//             payload: payloadParams.payload,
//             target: payloadParams.target,
//             requestCount: payloadParams.payloadHeader.getRequestCount(),
//             batchCount: payloadParams.payloadHeader.getBatchCount(),
//             payloadCount: payloadParams.payloadHeader.getPayloadCount(),
//             prevDigestsHash: payloadParams.prevDigestsHash,
//             extraData: bytes("")
//         });

//         value = payloadParams.value;
//         socketBatcher = socketConfig.socketBatcher;
//         refundAddress = transmitterEOA;
//     }

//     function _resolvePromise(bytes32 payloadId, bytes memory returnData) internal {
//         PromiseReturnData[] memory promiseReturnData = new PromiseReturnData[](1);
//         promiseReturnData[0] = PromiseReturnData({payloadId: payloadId, returnData: returnData});

//         bytes memory watcherSignature = _createWatcherSignature(
//             address(watcher),
//             abi.encode(Watcher.resolvePromises.selector, promiseReturnData)
//         );
//         watcher.resolvePromises(promiseReturnData, signatureNonce++, watcherSignature);
//     }

//     function _createWatcherSignature(
//         address watcherPrecompile_,
//         bytes memory params_
//     ) internal view returns (bytes memory) {
//         bytes32 digest = keccak256(
//             abi.encode(watcherPrecompile_, evmxSlug, signatureNonce, params_)
//         );
//         return _createSignature(digest, watcherPrivateKey);
//     }

//     function _createSignature(
//         bytes32 digest_,
//         uint256 privateKey_
//     ) internal pure returns (bytes memory sig) {
//         bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
//         (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(privateKey_, digest);
//         sig = new bytes(65);
//         bytes1 v32 = bytes1(sigV);

//         assembly {
//             mstore(add(sig, 96), v32)
//             mstore(add(sig, 32), sigR)
//             mstore(add(sig, 64), sigS)
//         }
//     }
// }
