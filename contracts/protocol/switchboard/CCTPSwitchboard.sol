// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./FastSwitchboard.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {ExecuteParams, ExecutionStatus, CCTPExecutionParams, CCTPBatchParams} from "../../utils/common/Structs.sol";
import {IMessageTransmitter} from "../interfaces/IMessageTransmitter.sol";
import {IMessageHandler} from "../interfaces/IMessageHandler.sol";

contract CCTPSwitchboard is FastSwitchboard, IMessageHandler {
    struct RemoteEndpoint {
        bytes32 remoteAddress;
        uint32 remoteDomain;
    }
    IMessageTransmitter public immutable messageTransmitter;

    // remoteChainSlug => remoteEndpoint
    mapping(uint32 => RemoteEndpoint) public chainSlugToRemoteEndpoint;
    // remoteDomain => remoteEndpoint
    mapping(uint32 => RemoteEndpoint) public domainToRemoteEndpoint;

    mapping(bytes32 => bool) public isSyncedOut;
    mapping(bytes32 => bytes32) public remoteExecutedDigests;
    mapping(bytes32 => bool) public isRemoteExecuted;

    error RemoteExecutionNotFound();
    error PrevBatchDigestHashMismatch();
    error NotAttested();
    error NotExecuted();
    error InvalidSender();
    error OnlyMessageTransmitter();

    constructor(
        uint32 chainSlug_,
        ISocket socket_,
        address owner_,
        address messageTransmitter_
    ) FastSwitchboard(chainSlug_, socket_, owner_) {
        messageTransmitter = IMessageTransmitter(messageTransmitter_);
    }

    function allowPacket(bytes32 digest_, bytes32 payloadId_) external view returns (bool) {
        // digest has enough attestations and is remote executed
        return isAttested[digest_] && isRemoteExecuted[payloadId_];
    }

    function syncOut(bytes32 payloadId_, uint32[] calldata remoteChainSlugs_) external {
        bytes32 digest = socket__.payloadIdToDigest(payloadId_);
        // not attested
        if (digest == bytes32(0) || !isAttested[digest]) revert NotAttested();

        // already synced out
        if (isSyncedOut[digest]) return;
        isSyncedOut[digest] = true;

        // not executed
        ExecutionStatus isExecuted = socket__.payloadExecuted(payloadId_);
        if (isExecuted != ExecutionStatus.Executed) revert NotExecuted();

        bytes memory message = abi.encode(payloadId_, digest);
        for (uint256 i = 0; i < remoteChainSlugs_.length; i++) {
            RemoteEndpoint memory endpoint = chainSlugToRemoteEndpoint[remoteChainSlugs_[i]];
            messageTransmitter.sendMessage(endpoint.remoteDomain, endpoint.remoteAddress, message);
        }
    }

    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool) {
        if (msg.sender != address(messageTransmitter)) revert OnlyMessageTransmitter();
        if (domainToRemoteEndpoint[sourceDomain].remoteAddress != sender) revert InvalidSender();

        (bytes32 payloadId, bytes32 digest) = abi.decode(messageBody, (bytes32, bytes32));
        remoteExecutedDigests[payloadId] = digest;
        return true;
    }

    function verifyAttestations(bytes[] calldata messages, bytes[] calldata attestations) public {
        for (uint256 i = 0; i < messages.length; i++) {
            messageTransmitter.receiveMessage(messages[i], attestations[i]);
        }
    }

    function proveRemoteExecutions(
        bytes32[] calldata previousPayloadIds_,
        bytes32 payloadId_,
        bytes calldata transmitterSignature_,
        ExecuteParams calldata executeParams_
    ) public {
        // Calculate prevBatchDigestHash from stored remoteExecutedDigests
        bytes32 prevBatchDigestHash = bytes32(0);
        for (uint256 i = 0; i < previousPayloadIds_.length; i++) {
            if (remoteExecutedDigests[previousPayloadIds_[i]] == bytes32(0))
                revert RemoteExecutionNotFound();
            prevBatchDigestHash = keccak256(
                abi.encodePacked(prevBatchDigestHash, remoteExecutedDigests[previousPayloadIds_[i]])
            );
        }
        // Check if the calculated prevBatchDigestHash matches the one in executeParams_
        if (prevBatchDigestHash != executeParams_.prevBatchDigestHash)
            revert PrevBatchDigestHashMismatch();

        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(socket__), payloadId_)),
            transmitterSignature_
        );

        // Construct current digest
        (bytes32 appGatewayId, ) = socket__.getPlugConfig(executeParams_.target);
        bytes32 constructedDigest = _createDigest(
            transmitter,
            payloadId_,
            appGatewayId,
            executeParams_
        );

        // Verify the constructed digest matches the stored one
        if (!isAttested[constructedDigest]) revert NotAttested();
        isRemoteExecuted[payloadId_] = true;
    }

    /**
     * @notice creates the digest for the payload
     * @param transmitter_ The address of the transmitter
     * @param payloadId_ The ID of the payload
     * @param appGatewayId_ The id of the app gateway
     * @param executeParams_ The parameters of the payload
     * @return The packed payload as a bytes32 hash
     */
    function _createDigest(
        address transmitter_,
        bytes32 payloadId_,
        bytes32 appGatewayId_,
        ExecuteParams calldata executeParams_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    address(socket__),
                    transmitter_,
                    payloadId_,
                    executeParams_.deadline,
                    executeParams_.callType,
                    executeParams_.gasLimit,
                    executeParams_.value,
                    executeParams_.payload,
                    executeParams_.target,
                    appGatewayId_,
                    executeParams_.prevBatchDigestHash,
                    executeParams_.extraData
                )
            );
    }

    function addRemoteEndpoint(
        uint32 remoteChainSlug_,
        bytes32 remoteAddress_,
        uint32 remoteDomain_
    ) external onlyOwner {
        chainSlugToRemoteEndpoint[remoteChainSlug_] = RemoteEndpoint({
            remoteAddress: remoteAddress_,
            remoteDomain: remoteDomain_
        });
        domainToRemoteEndpoint[remoteDomain_] = RemoteEndpoint({
            remoteAddress: remoteAddress_,
            remoteDomain: remoteDomain_
        });
    }

    function attestVerifyAndProveExecutions(
        CCTPExecutionParams calldata execParams_,
        CCTPBatchParams calldata cctpParams_,
        bytes32 payloadId_
    ) external {
        attest(execParams_.digest, execParams_.proof);
        verifyAttestations(cctpParams_.messages, cctpParams_.attestations);
        proveRemoteExecutions(
            cctpParams_.previousPayloadIds,
            payloadId_,
            execParams_.transmitterSignature,
            execParams_.executeParams
        );
    }
}
