// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {OpToken} from "./OpToken.sol";
import {Test} from "forge-std/Test.sol";
import {Socket} from "../../../../contracts/protocol/socket/Socket.sol";
import {OpInteropSwitchboard} from "../../../../contracts/protocol/socket/switchboard/OpInteropSwitchboard.sol";
import {OpTokenAppGateway} from "./OpTokenAppGateway.sol";
import {Fees, ExecuteParams, CallType, WriteFinality} from "../../../../contracts/protocol/utils/common/Structs.sol";
import {IAddressResolver} from "../../../../contracts/interfaces/IAddressResolver.sol";
import {IWatcherPrecompile} from "../../../../contracts/interfaces/IWatcherPrecompile.sol";
import {ISocket} from "../../../../contracts/interfaces/ISocket.sol";
import {IMiddleware} from "../../../../contracts/interfaces/IMiddleware.sol";
import {IOpToken} from "./IOpToken.sol";
import {console} from "forge-std/console.sol";
import {SocketBatcher} from "../../../../contracts/protocol/socket/SocketBatcher.sol";
import {WATCHER_ROLE} from "../../../../contracts/protocol/utils/common/AccessRoles.sol";
import {Predeploys} from "optimism/src/libraries/Predeploys.sol";
import {IL2ToL2CrossDomainMessenger} from "optimism/interfaces/L2/IL2ToL2CrossDomainMessenger.sol";

contract OpSbTest is Test {
    uint256 public c = 1;
    string _version = "1.0.0";
    uint256 immutable _ownerPrivateKey = c++;
    uint256 immutable _transmitterPrivateKey = c++;
    uint256 immutable _watcherPrivateKey = c++;
    address _owner;
    address _transmitter;
    address _watcher;
    address _ramu = address(uint160(c++));
    uint256 _amount = 10e18;
    uint256 _totalSupply = 100e18;
    uint256 _requestCount = 0;
    struct ChainDetails {
        Socket socket;
        SocketBatcher batcher;
        OpInteropSwitchboard switchboard;
        OpToken token;
    }

    struct EVMxChainDetails {
        address forwarder;
        address asyncPromise;
    }
    struct EVMxDetails {
        OpTokenAppGateway appGateway;
        address addressResolver;
        address deliveryHelper;
        address watcherPrecompile;
        mapping(uint32 => EVMxChainDetails) chainDetails;
    }

    struct PayloadExecDetails {
        ExecuteParams executeParams;
        bytes32[] previousPayloadIds;
        bytes32 digest;
        bytes32 payloadId;
        bytes proof;
        bytes transmitterSignature;
    }

    // chainSlug => ChainDetails
    mapping(uint256 => ChainDetails) public chainDetails;
    EVMxDetails public evmxDetails;

    function setUp() public {
        _owner = vm.addr(_ownerPrivateKey);
        _transmitter = vm.addr(_transmitterPrivateKey);
        _watcher = vm.addr(_watcherPrivateKey);
        vm.startPrank(_owner);

        for (uint32 i = 0; i < 3; i++) {
            Socket socket = new Socket(i, _owner, _version);
            chainDetails[i] = ChainDetails({
                socket: socket,
                batcher: new SocketBatcher(_owner, socket),
                switchboard: new OpInteropSwitchboard(i, socket, _owner),
                token: new OpToken("Test Token", "TEST", 18, _owner, _totalSupply)
            });
            evmxDetails.chainDetails[i] = EVMxChainDetails({
                forwarder: address(uint160(c++)),
                asyncPromise: address(uint160(c++))
            });
            chainDetails[i].switchboard.grantRole(WATCHER_ROLE, _watcher);
        }

        evmxDetails.addressResolver = address(uint160(c++));
        evmxDetails.deliveryHelper = address(uint160(c++));
        evmxDetails.watcherPrecompile = address(uint160(c++));

        evmxDetails.appGateway = new OpTokenAppGateway(
            evmxDetails.addressResolver,
            _owner,
            Fees({feePoolChain: uint32(c++), feePoolToken: address(uint160(c++)), amount: c++}),
            OpTokenAppGateway.ConstructorParams({
                name_: "Test Token",
                symbol_: "TEST",
                decimals_: 18,
                initialSupplyHolder_: _owner,
                initialSupply_: _totalSupply
            })
        );
        chainDetails[0].switchboard.registerSwitchboard();
        chainDetails[1].switchboard.registerSwitchboard();
        chainDetails[2].switchboard.registerSwitchboard();

        chainDetails[0].token.initSocket(
            address(evmxDetails.appGateway),
            address(chainDetails[0].socket),
            address(chainDetails[0].switchboard)
        );
        chainDetails[1].token.initSocket(
            address(evmxDetails.appGateway),
            address(chainDetails[1].socket),
            address(chainDetails[1].switchboard)
        );
        chainDetails[2].token.initSocket(
            address(evmxDetails.appGateway),
            address(chainDetails[2].socket),
            address(chainDetails[2].switchboard)
        );
        chainDetails[0].switchboard.addRemoteEndpoint(1, 1, address(chainDetails[1].switchboard));
        chainDetails[0].switchboard.addRemoteEndpoint(2, 2, address(chainDetails[2].switchboard));
        chainDetails[1].switchboard.addRemoteEndpoint(0, 0, address(chainDetails[0].switchboard));
        chainDetails[1].switchboard.addRemoteEndpoint(2, 2, address(chainDetails[2].switchboard));
        chainDetails[2].switchboard.addRemoteEndpoint(0, 0, address(chainDetails[0].switchboard));
        chainDetails[2].switchboard.addRemoteEndpoint(1, 1, address(chainDetails[1].switchboard));
        vm.stopPrank();
    }

    function testTokensMinted() public view {
        uint256 ownerAmount = chainDetails[0].token.balanceOf(_owner);
        assertEq(ownerAmount, _totalSupply);
        ownerAmount = chainDetails[1].token.balanceOf(_owner);
        assertEq(ownerAmount, _totalSupply);
        ownerAmount = chainDetails[2].token.balanceOf(_owner);
        assertEq(ownerAmount, _totalSupply);
    }

    function testTokenTransfer() public {
        _distributeTokens();
        _mockEVMxCalls();
        OpTokenAppGateway.TransferOrder memory t = _getTransferOrder();
        vm.prank(_ramu);
        evmxDetails.appGateway.transfer(abi.encode(t));

        PayloadExecDetails[] memory p = _getPayloadExecDetails();

        vm.expectEmit(true, true, false, false);
        emit ISocket.ExecutionSuccess(p[0].payloadId, "");
        chainDetails[0].batcher.attestOPProveAndExecute(
            p[0].executeParams,
            p[0].previousPayloadIds,
            p[0].digest,
            p[0].proof,
            p[0].transmitterSignature
        );

        vm.expectEmit(true, true, false, false);
        emit ISocket.ExecutionSuccess(p[1].payloadId, "");
        chainDetails[1].batcher.attestOPProveAndExecute(
            p[1].executeParams,
            p[1].previousPayloadIds,
            p[1].digest,
            p[1].proof,
            p[1].transmitterSignature
        );

        _sync(p);

        vm.expectEmit(true, true, false, false);
        emit ISocket.ExecutionSuccess(p[2].payloadId, "");
        chainDetails[2].batcher.attestOPProveAndExecute(
            p[2].executeParams,
            p[2].previousPayloadIds,
            p[2].digest,
            p[2].proof,
            p[2].transmitterSignature
        );
    }

    function _sync(PayloadExecDetails[] memory p) private {
        bytes memory syncPayloadA = abi.encodeWithSelector(
            OpInteropSwitchboard.syncIn.selector,
            p[0].payloadId,
            p[0].digest
        );
        vm.mockCall(
            address(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER),
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.sendMessage.selector,
                2,
                address(chainDetails[2].switchboard),
                syncPayloadA
            ),
            abi.encode(true)
        );
        chainDetails[0].switchboard.syncOut(p[0].payloadId, 2);
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector),
            abi.encode(address(chainDetails[0].switchboard))
        );
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(IL2ToL2CrossDomainMessenger.crossDomainMessageSource.selector),
            abi.encode(0)
        );
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        (bool successA, ) = address(chainDetails[2].switchboard).call(syncPayloadA);
        require(successA);

        bytes memory syncPayloadB = abi.encodeWithSelector(
            OpInteropSwitchboard.syncIn.selector,
            p[1].payloadId,
            p[1].digest
        );
        vm.mockCall(
            address(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER),
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.sendMessage.selector,
                2,
                address(chainDetails[2].switchboard),
                syncPayloadB
            ),
            abi.encode(true)
        );
        chainDetails[1].switchboard.syncOut(p[1].payloadId, 2);
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector),
            abi.encode(address(chainDetails[1].switchboard))
        );
        vm.mockCall(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(IL2ToL2CrossDomainMessenger.crossDomainMessageSource.selector),
            abi.encode(1)
        );
        vm.prank(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
        (bool successB, ) = address(chainDetails[2].switchboard).call(syncPayloadB);
        require(successB);
    }

    function _distributeTokens() private {
        vm.startPrank(_owner);
        chainDetails[0].token.transfer(_ramu, _amount);
        chainDetails[1].token.transfer(_ramu, _amount);
        vm.stopPrank();

        assertEq(chainDetails[0].token.balanceOf(_ramu), _amount);
        assertEq(chainDetails[1].token.balanceOf(_ramu), _amount);
    }

    function _getTransferOrder() private view returns (OpTokenAppGateway.TransferOrder memory t) {
        address[] memory srcTokens = new address[](2);
        uint256[] memory srcAmounts = new uint256[](2);
        address[] memory dstTokens = new address[](1);
        uint256[] memory dstAmounts = new uint256[](1);

        srcTokens[0] = address(evmxDetails.chainDetails[0].forwarder);
        srcAmounts[0] = _amount;

        srcTokens[1] = address(evmxDetails.chainDetails[1].forwarder);
        srcAmounts[1] = _amount;

        dstTokens[0] = address(evmxDetails.chainDetails[2].forwarder);
        dstAmounts[0] = 2 * _amount;

        t = OpTokenAppGateway.TransferOrder({
            srcTokens: srcTokens,
            dstTokens: dstTokens,
            user: _ramu,
            srcAmounts: srcAmounts,
            dstAmounts: dstAmounts
        });
    }

    function _mockEVMxCalls() private {
        vm.mockCall(
            evmxDetails.addressResolver,
            abi.encodeWithSelector(IAddressResolver.deliveryHelper.selector),
            abi.encode(evmxDetails.deliveryHelper)
        );
        vm.mockCall(
            evmxDetails.deliveryHelper,
            abi.encodeWithSelector(IMiddleware.clearQueue.selector),
            abi.encode(true)
        );
        vm.mockCall(
            evmxDetails.addressResolver,
            abi.encodeWithSelector(IAddressResolver.clearPromises.selector),
            abi.encode(true)
        );
        vm.mockCall(
            evmxDetails.chainDetails[0].forwarder,
            abi.encodeWithSelector(IOpToken.burn.selector),
            abi.encode(true)
        );
        vm.mockCall(
            evmxDetails.chainDetails[1].forwarder,
            abi.encodeWithSelector(IOpToken.burn.selector),
            abi.encode(true)
        );
        vm.mockCall(
            evmxDetails.chainDetails[2].forwarder,
            abi.encodeWithSelector(IOpToken.mint.selector),
            abi.encode(true)
        );
        vm.mockCall(
            evmxDetails.addressResolver,
            abi.encodeWithSelector(IAddressResolver.watcherPrecompile__.selector),
            abi.encode(evmxDetails.watcherPrecompile)
        );
        vm.mockCall(
            evmxDetails.watcherPrecompile,
            abi.encodeWithSelector(IWatcherPrecompile.getCurrentRequestCount.selector),
            abi.encode(_requestCount)
        );
        vm.mockCall(
            evmxDetails.deliveryHelper,
            abi.encodeWithSelector(IMiddleware.batch.selector),
            abi.encode(_requestCount)
        );

        address[] memory promises = new address[](3);
        promises[0] = evmxDetails.chainDetails[0].asyncPromise;
        promises[1] = evmxDetails.chainDetails[1].asyncPromise;
        promises[2] = evmxDetails.chainDetails[2].asyncPromise;
        vm.mockCall(
            evmxDetails.addressResolver,
            abi.encodeWithSelector(IAddressResolver.getPromises.selector),
            abi.encode(promises)
        );
    }

    function _getPayloadExecDetails() private view returns (PayloadExecDetails[] memory) {
        PayloadExecDetails[] memory p = new PayloadExecDetails[](3);
        ExecuteParams memory executeParams = ExecuteParams({
            deadline: block.timestamp + 1000,
            callType: CallType.WRITE,
            writeFinality: WriteFinality.LOW,
            gasLimit: 1000000,
            readAt: 0,
            payload: abi.encodeWithSelector(IOpToken.burn.selector, _ramu, _amount),
            target: address(chainDetails[0].token),
            requestCount: 0,
            batchCount: 0,
            payloadCount: 0,
            prevDigestsHash: bytes32(0),
            switchboard: address(chainDetails[0].switchboard)
        });
        bytes32 payloadId = _createPayloadId(executeParams, chainDetails[0].socket.chainSlug());
        bytes32 digest = _createDigest(
            _transmitter,
            payloadId,
            address(evmxDetails.appGateway),
            executeParams
        );
        bytes memory proof = _signDigest(
            keccak256(abi.encode(chainDetails[0].switchboard, digest)),
            _watcherPrivateKey
        );
        bytes memory transmitterSignature = _signDigest(
            keccak256(abi.encode(address(chainDetails[0].socket), payloadId)),
            _transmitterPrivateKey
        );
        p[0] = PayloadExecDetails({
            executeParams: executeParams,
            previousPayloadIds: new bytes32[](0),
            digest: digest,
            payloadId: payloadId,
            proof: proof,
            transmitterSignature: transmitterSignature
        });

        executeParams = ExecuteParams({
            deadline: block.timestamp + 1000,
            callType: CallType.WRITE,
            writeFinality: WriteFinality.LOW,
            gasLimit: 1000000,
            readAt: 0,
            payload: abi.encodeWithSelector(IOpToken.burn.selector, _ramu, _amount),
            target: address(chainDetails[1].token),
            requestCount: 0,
            batchCount: 0,
            payloadCount: 0,
            prevDigestsHash: bytes32(0),
            switchboard: address(chainDetails[1].switchboard)
        });
        payloadId = _createPayloadId(executeParams, chainDetails[1].socket.chainSlug());
        digest = _createDigest(
            _transmitter,
            payloadId,
            address(evmxDetails.appGateway),
            executeParams
        );
        proof = _signDigest(
            keccak256(abi.encode(chainDetails[1].switchboard, digest)),
            _watcherPrivateKey
        );
        transmitterSignature = _signDigest(
            keccak256(abi.encode(address(chainDetails[1].socket), payloadId)),
            _transmitterPrivateKey
        );
        p[1] = PayloadExecDetails({
            executeParams: executeParams,
            previousPayloadIds: new bytes32[](0),
            digest: digest,
            payloadId: payloadId,
            proof: proof,
            transmitterSignature: transmitterSignature
        });

        executeParams = ExecuteParams({
            deadline: block.timestamp + 1000,
            callType: CallType.WRITE,
            writeFinality: WriteFinality.LOW,
            gasLimit: 1000000,
            readAt: 0,
            payload: abi.encodeWithSelector(IOpToken.mint.selector, _ramu, 2 * _amount),
            target: address(chainDetails[2].token),
            requestCount: 0,
            batchCount: 0,
            payloadCount: 0,
            prevDigestsHash: keccak256(
                abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), p[0].digest)), p[1].digest)
            ),
            switchboard: address(chainDetails[2].switchboard)
        });
        payloadId = _createPayloadId(executeParams, chainDetails[2].socket.chainSlug());
        digest = _createDigest(
            _transmitter,
            payloadId,
            address(evmxDetails.appGateway),
            executeParams
        );
        proof = _signDigest(
            keccak256(abi.encode(chainDetails[2].switchboard, digest)),
            _watcherPrivateKey
        );
        transmitterSignature = _signDigest(
            keccak256(abi.encode(address(chainDetails[2].socket), payloadId)),
            _transmitterPrivateKey
        );
        bytes32[] memory previousPayloadIds = new bytes32[](2);
        previousPayloadIds[0] = p[0].payloadId;
        previousPayloadIds[1] = p[1].payloadId;
        p[2] = PayloadExecDetails({
            executeParams: executeParams,
            previousPayloadIds: previousPayloadIds,
            digest: digest,
            payloadId: payloadId,
            proof: proof,
            transmitterSignature: transmitterSignature
        });
        return p;
    }

    function _signDigest(bytes32 digest_, uint256 privateKey_) private pure returns (bytes memory) {
        digest_ = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey_, digest_);
        return abi.encodePacked(r, s, v);
    }

    function _createDigest(
        address transmitter_,
        bytes32 payloadId_,
        address appGateway_,
        ExecuteParams memory executeParams_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    transmitter_,
                    payloadId_,
                    executeParams_.deadline,
                    executeParams_.callType,
                    executeParams_.writeFinality,
                    executeParams_.gasLimit,
                    msg.value,
                    executeParams_.readAt,
                    executeParams_.payload,
                    executeParams_.target,
                    appGateway_,
                    executeParams_.prevDigestsHash
                )
            );
    }

    function _createPayloadId(
        ExecuteParams memory executeParams_,
        uint32 chainSlug_
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    executeParams_.requestCount,
                    executeParams_.batchCount,
                    executeParams_.payloadCount,
                    executeParams_.switchboard,
                    chainSlug_
                )
            );
    }
}
