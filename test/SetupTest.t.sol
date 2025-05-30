// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../contracts/utils/common/Structs.sol";
import "../contracts/utils/common/Errors.sol";
import "../contracts/utils/common/Constants.sol";
import "../contracts/evmx/watcher/Watcher.sol";
import "../contracts/evmx/watcher/Configurations.sol";
import "../contracts/evmx/interfaces/IForwarder.sol";
import "../contracts/utils/common/AccessRoles.sol";
import {Socket} from "../contracts/protocol/Socket.sol";
import "../contracts/protocol/switchboard/FastSwitchboard.sol";
import "../contracts/protocol/SocketBatcher.sol";
import "../contracts/evmx/helpers/AddressResolver.sol";
import {ContractFactoryPlug} from "../contracts/evmx/plugs/ContractFactoryPlug.sol";
import {FeesPlug} from "../contracts/evmx/plugs/FeesPlug.sol";
import {SocketFeeManager} from "../contracts/protocol/SocketFeeManager.sol";
import "../contracts/utils/common/Structs.sol";

import "../contracts/evmx/helpers/AsyncDeployer.sol";

import "solady/utils/ERC1967Factory.sol";
import "./apps/app-gateways/USDC.sol";

contract SetupTest is Test {
    uint public c = 1;
    address owner = address(uint160(c++));

    uint256 watcherPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 transmitterPrivateKey =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    address watcherEOA = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address transmitterEOA = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint32 arbChainSlug = 421614;
    uint32 optChainSlug = 11155420;
    uint32 evmxSlug = 1;
    uint256 expiryTime = 10000000;
    uint256 maxReAuctionCount = 10;
    uint256 socketFees = 0.01 ether;
    uint256 public signatureNonce;
    uint256 public payloadIdCounter;
    uint256 public timeoutIdCounter;
    uint256 public triggerCounter;
    uint256 public defaultLimit = 1000;

    bytes public asyncPromiseBytecode = type(AsyncPromise).creationCode;
    uint64 public version = 1;

    struct SocketContracts {
        uint32 chainSlug;
        Socket socket;
        SocketFeeManager socketFeeManager;
        FastSwitchboard switchboard;
        SocketBatcher socketBatcher;
        ContractFactoryPlug contractFactoryPlug;
        FeesPlug feesPlug;
        ERC20 feesTokenUSDC;
    }

    AddressResolver public addressResolver;
    Watcher public watcher;
    Configurations public configurations;
    AsyncDeployer public asyncDeployer;
    AsyncPromise public asyncPromise;

    SocketContracts public arbConfig;
    SocketContracts public optConfig;

    // Add new variables for proxy admin and implementation contracts
    Watcher public watcherImpl;
    Configurations public configurationsImpl;
    AsyncDeployer public asyncDeployerImpl;
    AsyncPromise public asyncPromiseImpl;
    AddressResolver public addressResolverImpl;
    ERC1967Factory public proxyFactory;

    event Initialized(uint64 version);
    event FinalizeRequested(bytes32 digest, PayloadParams payloadParams);

    //////////////////////////////////// Setup ////////////////////////////////////

    function deploySocket(uint32 chainSlug_) internal returns (SocketContracts memory) {
        Socket socket = new Socket(chainSlug_, owner, "test");
        SocketBatcher socketBatcher = new SocketBatcher(owner, socket);
        FastSwitchboard switchboard = new FastSwitchboard(chainSlug_, socket, owner);

        ERC20 feesTokenUSDC = new USDC("USDC", "USDC", 6, owner, 1000000000000000000000000);
        FeesPlug feesPlug = new FeesPlug(address(socket), owner);
        ContractFactoryPlug contractFactoryPlug = new ContractFactoryPlug(address(socket), owner);
        vm.startPrank(owner);
        // feePlug whitelist token
        feesPlug.whitelistToken(address(feesTokenUSDC));
        // socket
        socket.grantRole(GOVERNANCE_ROLE, address(owner));

        // switchboard
        switchboard.registerSwitchboard();
        switchboard.grantRole(WATCHER_ROLE, watcherEOA);
        vm.stopPrank();

        hoax(watcherEOA);
        configurations.setSocket(chainSlug_, address(socket));
        
        // todo: setters
        // address(contractFactoryPlug),
        //     address(feesPlug)
        SocketFeeManager socketFeeManager = new SocketFeeManager(owner, socketFees);
        hoax(watcherEOA);
        configurations.setSwitchboard(chainSlug_, FAST, address(switchboard));

        return
            SocketContracts({
                chainSlug: chainSlug_,
                socket: socket,
                socketFeeManager: socketFeeManager,
                switchboard: switchboard,
                socketBatcher: socketBatcher,
                contractFactoryPlug: contractFactoryPlug,
                feesPlug: feesPlug,
                feesTokenUSDC: feesTokenUSDC
            });
    }

    function deployEVMxCore() internal {
        // Deploy implementations
        addressResolverImpl = new AddressResolver();
        watcherImpl = new Watcher();
        configurationsImpl = new Configurations();
        asyncDeployerImpl = new AsyncDeployer();
        asyncPromiseImpl = new AsyncPromise();
        proxyFactory = new ERC1967Factory();

        // Deploy and initialize proxies
        bytes memory addressResolverData = abi.encodeWithSelector(
            AddressResolver.initialize.selector,
            watcherEOA
        );
        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address addressResolverProxy = proxyFactory.deployAndCall(
            address(addressResolverImpl),
            watcherEOA,
            addressResolverData
        );

        bytes memory configurationsData = abi.encodeWithSelector(
            Configurations.initialize.selector,
            watcherEOA,
            address(addressResolverProxy),
            evmxSlug
        );
        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address configurationsProxy = proxyFactory.deployAndCall(
            address(configurationsImpl),
            watcherEOA,
            configurationsData
        );

        bytes memory watcherData = abi.encodeWithSelector(
            Watcher.initialize.selector,
            watcherEOA,
            address(addressResolverProxy),
            expiryTime,
            evmxSlug,
            address(configurationsProxy)
        );
        vm.expectEmit(true, true, true, false);
        emit Initialized(version);
        address watcherProxy = proxyFactory.deployAndCall(
            address(watcherImpl),
            watcherEOA,
            watcherData
        );

        // Assign proxy addresses to public variables
        addressResolver = AddressResolver(address(addressResolverProxy));
        watcher = Watcher(address(watcherProxy));
        configurations = Configurations(address(configurationsProxy));
        // asyncDeployer = AsyncDeployer(address(asyncDeployerProxy));
        // asyncPromise = AsyncPromise(address(asyncPromiseProxy));

        vm.startPrank(watcherEOA);
        addressResolver.setWatcher(address(watcher));
        watcher.setCallBackFees(1);
        watcher.setFinalizeFees(1);
        watcher.setQueryFees(1);
        watcher.setTimeoutFees(1);

        vm.stopPrank();
    }

    //////////////////////////////////// Watcher precompiles ////////////////////////////////////

    function _checkIfOnlyReads(uint40 batchCount_) internal view returns (bool) {
        bytes32[] memory payloadIds = watcher.getBatchPayloadIds(batchCount_);

        for (uint i = 0; i < payloadIds.length; i++) {
            PayloadParams memory payloadParams = watcher.getPayloadParams(payloadIds[i]);
            if (payloadParams.payloadHeader.getCallType() != READ) {
                return false;
            }
        }

        return true;
    }

    function _resolveAndExpectFinalizeRequested(
        bytes32 payloadId_,
        PayloadParams memory payloadParams,
        bytes memory returnData,
        bool isLastPayload
    ) internal {
        if (isLastPayload) {
            vm.expectEmit(false, false, false, false);
            emit FinalizeRequested(payloadId_, payloadParams);
        }

        _resolvePromise(payloadId_, returnData);
    }

    function _finalizeBatch(
        uint40 batchCount_,
        bytes[] memory readReturnData_,
        uint256 readCount_,
        bool hasMoreBatches
    ) internal returns (uint256) {
        bytes32[] memory payloadIds = watcher.getBatchPayloadIds(batchCount_);

        for (uint i = 0; i < payloadIds.length; i++) {
            PayloadParams memory payloadParams = watcher.getPayloadParams(payloadIds[i]);
            bool isLastPayload = i == payloadIds.length - 1 && hasMoreBatches;

            if (payloadParams.payloadHeader.getCallType() == READ) {
                _resolveAndExpectFinalizeRequested(
                    payloadParams.payloadId,
                    payloadParams,
                    readReturnData_[readCount_++],
                    isLastPayload
                );
            } else {
                (, bytes memory returnData) = _uploadProofAndExecute(payloadParams);
                _resolveAndExpectFinalizeRequested(
                    payloadParams.payloadId,
                    payloadParams,
                    returnData,
                    isLastPayload
                );
            }
        }
        return readCount_;
    }

    function _uploadProofAndExecute(
        PayloadParams memory payloadParams
    ) internal returns (bool, bytes memory) {
        (bytes memory watcherProof, bytes32 digest) = _generateWatcherProof(payloadParams);
        _writeProof(payloadParams.payloadId, watcherProof);

        (
            ExecuteParams memory params,
            SocketBatcher socketBatcher,
            ,
            bytes memory transmitterSig,
            address refundAddress
        ) = _getExecuteParams(payloadParams);

        return
            socketBatcher.attestAndExecute(
                params,
                payloadParams.switchboard,
                digest,
                watcherProof,
                transmitterSig,
                refundAddress
            );
    }

    function resolvePromises(bytes32[] memory payloadIds, bytes[] memory returnData) internal {
        for (uint i = 0; i < payloadIds.length; i++) {
            _resolvePromise(payloadIds[i], returnData[i]);
        }
    }

    //////////////////////////////////// Helpers ////////////////////////////////////
    function getSocketConfig(uint32 chainSlug_) internal view returns (SocketContracts memory) {
        return chainSlug_ == arbChainSlug ? arbConfig : optConfig;
    }

    function _generateWatcherProof(
        PayloadParams memory params_
    ) internal view returns (bytes memory, bytes32) {
        SocketContracts memory socketConfig = getSocketConfig(params_.payloadHeader.getChainSlug());
        DigestParams memory digestParams_ = DigestParams(
            address(socketConfig.socket),
            transmitterEOA,
            params_.payloadId,
            params_.deadline,
            params_.payloadHeader.getCallType(),
            params_.gasLimit,
            params_.value,
            params_.payload,
            params_.target,
            _encodeAppGatewayId(params_.appGateway),
            params_.prevDigestsHash
        );
        bytes32 digest = watcher.getDigest(digestParams_);

        bytes32 sigDigest = keccak256(
            abi.encode(address(socketConfig.switchboard), socketConfig.chainSlug, digest)
        );
        bytes memory proof = _createSignature(sigDigest, watcherPrivateKey);
        return (proof, digest);
    }

    function _writeProof(bytes32 payloadId_, bytes memory watcherProof_) internal {
        bytes memory bytesInput = abi.encode(
            IWatcher.finalized.selector,
            payloadId_,
            watcherProof_
        );
        bytes memory watcherSignature = _createWatcherSignature(address(watcher), bytesInput);
        watcher.finalized(payloadId_, watcherProof_, signatureNonce++, watcherSignature);
        assertEq(watcher.watcherProofs(payloadId_), watcherProof_);
    }

    function _getExecuteParams(
        PayloadParams memory payloadParams
    )
        internal
        view
        returns (
            ExecuteParams memory params,
            SocketBatcher socketBatcher,
            uint256 value,
            bytes memory transmitterSig,
            address refundAddress
        )
    {
        SocketContracts memory socketConfig = getSocketConfig(
            payloadParams.payloadHeader.getChainSlug()
        );
        bytes32 transmitterDigest = keccak256(
            abi.encode(address(socketConfig.socket), payloadParams.payloadId)
        );
        transmitterSig = _createSignature(transmitterDigest, transmitterPrivateKey);

        params = ExecuteParams({
            callType: payloadParams.payloadHeader.getCallType(),
            deadline: payloadParams.deadline,
            gasLimit: payloadParams.gasLimit,
            value: payloadParams.value,
            payload: payloadParams.payload,
            target: payloadParams.target,
            requestCount: payloadParams.payloadHeader.getRequestCount(),
            batchCount: payloadParams.payloadHeader.getBatchCount(),
            payloadCount: payloadParams.payloadHeader.getPayloadCount(),
            prevDigestsHash: payloadParams.prevDigestsHash,
            extraData: bytes("")
        });

        value = payloadParams.value;
        socketBatcher = socketConfig.socketBatcher;
        refundAddress = transmitterEOA;
    }

    function _resolvePromise(bytes32 payloadId, bytes memory returnData) internal {
        PromiseReturnData[] memory promiseReturnData = new PromiseReturnData[](1);
        promiseReturnData[0] = PromiseReturnData({payloadId: payloadId, returnData: returnData});

        bytes memory watcherSignature = _createWatcherSignature(
            address(watcher),
            abi.encode(Watcher.resolvePromises.selector, promiseReturnData)
        );
        watcher.resolvePromises(promiseReturnData, signatureNonce++, watcherSignature);
    }

    function _createWatcherSignature(
        address watcherPrecompile_,
        bytes memory params_
    ) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encode(watcherPrecompile_, evmxSlug, signatureNonce, params_)
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

    function _encodeAppGatewayId(address appGateway_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(appGateway_)));
    }

    function _decodeAppGatewayId(bytes32 appGatewayId_) internal pure returns (address) {
        return address(uint160(uint256(appGatewayId_)));
    }
}
