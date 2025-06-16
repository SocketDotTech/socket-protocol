// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./FastSwitchboard.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {ExecuteParams, ExecutionStatus} from "../../utils/common/Structs.sol";
import {IMessageTransmitter} from "../interfaces/IMessageTransmitter.sol";
import {IMessageHandler} from "../interfaces/IMessageHandler.sol";

contract CCTPSwitchboard is FastSwitchboard, IMessageHandler {
    struct RemoteEndpoint {
        uint256 remoteChainId;
        address remoteAddress;
        uint32 remoteDomain;
    }

    // remoteChainSlug => remoteEndpoint
    mapping(uint32 => RemoteEndpoint) public remoteEndpoints;
    // remoteDomain => remoteAddress
    mapping(uint32 => address) public remoteAddresses;

    mapping(bytes32 => bool) public isSyncedOut;
    mapping(bytes32 => bytes32) public payloadIdToDigest;
    mapping(bytes32 => bytes32) public remoteExecutedDigests;
    mapping(bytes32 => bool) public isRemoteExecuted;

    IMessageTransmitter public immutable messageTransmitter;

    error RemoteExecutionNotFound();
    error DigestMismatch();
    error PreviousDigestsHashMismatch();
    error NotAttested();
    error NotExecuted();
    error InvalidDomain();
    error InvalidSender();
    error OnlyMessageTransmitter();
    event Attested(bytes32 payloadId, bytes32 digest, address watcher);

    constructor(
        uint32 chainSlug_,
        ISocket socket_,
        address owner_,
        address messageTransmitter_
    ) FastSwitchboard(chainSlug_, socket_, owner_) {
        messageTransmitter = IMessageTransmitter(messageTransmitter_);
    }

    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata proof_) external {
        address watcher = _recoverSigner(
            keccak256(abi.encode(address(this), chainSlug, digest_)),
            proof_
        );

        if (isAttested[digest_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_] = true;
        payloadIdToDigest[payloadId_] = digest_;
        emit Attested(payloadId_, digest_, watcher);
    }

    function allowPacket(bytes32 digest_, bytes32 payloadId_) external view returns (bool) {
        // digest has enough attestations and is remote executed
        return
            payloadIdToDigest[payloadId_] == digest_ &&
            isAttested[digest_] &&
            isRemoteExecuted[payloadId_];
    }

    function syncOut(bytes32 payloadId_, uint32[] calldata remoteChainSlugs_) external {
        bytes32 digest = payloadIdToDigest[payloadId_];

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
            RemoteEndpoint memory endpoint = remoteEndpoints[remoteChainSlugs_[i]];
            if (endpoint.remoteDomain == 0) revert InvalidDomain();

            messageTransmitter.sendMessage(
                endpoint.remoteDomain,
                addressToBytes32(endpoint.remoteAddress),
                message
            );
        }
    }

    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool) {
        if (msg.sender != address(messageTransmitter)) revert OnlyMessageTransmitter();

        (bytes32 payloadId, bytes32 digest) = abi.decode(messageBody, (bytes32, bytes32));
        if (remoteAddresses[sourceDomain] != bytes32ToAddress(sender)) {
            revert InvalidSender();
        }

        remoteExecutedDigests[payloadId] = digest;
        return true;
    }

    function verifyAttestations(bytes[] calldata messages, bytes[] calldata attestations) external {
        for (uint256 i = 0; i < messages.length; i++) {
            messageTransmitter.receiveMessage(messages[i], attestations[i]);
        }
    }

    function proveRemoteExecutions(
        bytes32[] calldata previousPayloadIds_,
        bytes32 payloadId_,
        bytes calldata transmitterSignature_,
        ExecuteParams calldata executeParams_
    ) external {
        // Calculate previousDigestsHash from stored remoteExecutedDigests
        bytes32 previousDigestsHash = bytes32(0);
        for (uint256 i = 0; i < previousPayloadIds_.length; i++) {
            if (remoteExecutedDigests[previousPayloadIds_[i]] == bytes32(0))
                revert RemoteExecutionNotFound();
            previousDigestsHash = keccak256(
                abi.encodePacked(previousDigestsHash, remoteExecutedDigests[previousPayloadIds_[i]])
            );
        }
        // Check if the calculated previousDigestsHash matches the one in executeParams_
        if (previousDigestsHash != executeParams_.prevBatchDigestHash)
            revert PreviousDigestsHashMismatch();

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

        bytes32 storedDigest = payloadIdToDigest[payloadId_];
        // Verify the constructed digest matches the stored one
        if (storedDigest == bytes32(0) || !isAttested[storedDigest]) revert NotAttested();
        if (constructedDigest != storedDigest) revert DigestMismatch();

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
        uint256 remoteChainId_,
        address remoteAddress_,
        uint32 remoteDomain_
    ) external onlyOwner {
        remoteEndpoints[remoteChainSlug_] = RemoteEndpoint({
            remoteChainId: remoteChainId_,
            remoteAddress: remoteAddress_,
            remoteDomain: remoteDomain_
        });
        remoteAddresses[remoteDomain_] = remoteAddress_;
    }

    function removeRemoteEndpoint(uint32 remoteChainSlug_) external onlyOwner {
        uint32 remoteDomain = remoteEndpoints[remoteChainSlug_].remoteDomain;
        delete remoteEndpoints[remoteChainSlug_];
        delete remoteAddresses[remoteDomain];
    }

    function addressToBytes32(address addr_) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr_)));
    }
    function bytes32ToAddress(bytes32 addrBytes32_) public pure returns (address) {
        return address(uint160(uint256(addrBytes32_)));
    }
}
