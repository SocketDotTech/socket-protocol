// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {FastSwitchboard} from "./FastSwitchboard.sol";
import {SuperchainEnabled} from "./SuperchainEnabled.sol";
import {ISocket} from "../../../interfaces/ISocket.sol";
import {ExecuteParams, ExecutionStatus} from "../../utils/common/Structs.sol";

contract OpInteropSwitchboard is FastSwitchboard, SuperchainEnabled {
    address public token;
    address public remoteAddress;
    uint256 public remoteChainId;

    mapping(bytes32 => bool) public isSyncedOut;
    mapping(bytes32 => bytes32) public payloadIdToDigest;
    mapping(address => uint256) public unminted;
    mapping(bytes32 => bytes32) public remoteExecutedDigests;
    mapping(bytes32 => bool) public isRemoteExecuted;

    error OnlyTokenAllowed();
    error RemoteExecutionNotFound();
    error DigestMismatch();
    error PreviousDigestsHashMismatch();
    error NotAttested();
    error NotExecuted();

    event Attested(bytes32 payloadId, bytes32 digest, address watcher);

    modifier onlyToken() {
        if (msg.sender != token) revert OnlyTokenAllowed();
        _;
    }

    constructor(
        uint32 chainSlug_,
        ISocket socket_,
        address owner_
    ) FastSwitchboard(chainSlug_, socket_, owner_) {
        if (chainSlug_ == 420120000) {
            remoteChainId = 420120001;
        } else if (chainSlug_ == 420120001) {
            remoteChainId = 420120000;
        }
    }

    function attest(bytes32 /*digest_*/, bytes calldata /*proof_*/) external override {
        revert("Not implemented");
    }

    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata proof_) external {
        address watcher = _recoverSigner(keccak256(abi.encode(address(this), digest_)), proof_);

        if (isAttested[digest_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_] = true;
        payloadIdToDigest[payloadId_] = digest_;
        emit Attested(payloadId_, digest_, watcher);
    }

    function allowPacket(
        bytes32 digest_,
        bytes32 payloadId_
    ) external view override returns (bool) {
        // digest has enough attestations and is remote executed
        return
            payloadIdToDigest[payloadId_] == digest_ &&
            isAttested[digest_] &&
            isRemoteExecuted[payloadId_];
    }

    function syncOut(bytes32 payloadId_) external {
        bytes32 digest = payloadIdToDigest[payloadId_];

        // not attested
        if (digest == bytes32(0) || !isAttested[digest]) revert NotAttested();

        // already synced out
        if (isSyncedOut[digest]) return;
        isSyncedOut[digest] = true;

        // not executed
        ExecutionStatus isExecuted = socket__.payloadExecuted(payloadId_);
        if (isExecuted != ExecutionStatus.Executed) revert NotExecuted();

        _xMessageContract(
            remoteChainId,
            remoteAddress,
            abi.encodeWithSelector(this.syncIn.selector, payloadId_, digest)
        );
    }

    function syncIn(
        bytes32 payloadId_,
        bytes32 digest_
    ) external xOnlyFromContract(remoteAddress, remoteChainId) {
        remoteExecutedDigests[payloadId_] = digest_;
    }

    function proveRemoteExecutions(
        bytes32[] calldata previousPayloadIds_,
        bytes32 currentPayloadId_,
        address transmitter_,
        ExecuteParams memory executeParams_
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
        if (previousDigestsHash != executeParams_.prevDigestsHash)
            revert PreviousDigestsHashMismatch();

        // Construct current digest
        (address appGateway, ) = socket__.getPlugConfig(executeParams_.target);
        bytes32 constructedDigest = _createDigest(
            transmitter_,
            currentPayloadId_,
            appGateway,
            executeParams_
        );

        // Verify the constructed digest matches the stored one
        bytes32 storedDigest = payloadIdToDigest[currentPayloadId_];
        if (storedDigest == bytes32(0) || !isAttested[storedDigest]) revert NotAttested();
        if (constructedDigest != storedDigest) revert DigestMismatch();

        isRemoteExecuted[currentPayloadId_] = true;
    }

    /**
     * @notice creates the digest for the payload
     * @param transmitter_ The address of the transmitter
     * @param payloadId_ The ID of the payload
     * @param appGateway_ The address of the app gateway
     * @param executeParams_ The parameters of the payload
     * @return The packed payload as a bytes32 hash
     */
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

    /**
     * @notice creates the payload ID
     * @param switchboard_ The address of the switchboard
     * @param executeParams_ The parameters of the payload
     */
    function _createPayloadId(
        address switchboard_,
        ExecuteParams memory executeParams_
    ) internal view returns (bytes32) {
        // todo: match with watcher
        return
            keccak256(
                abi.encode(
                    executeParams_.requestCount,
                    executeParams_.batchCount,
                    executeParams_.payloadCount,
                    switchboard_,
                    chainSlug
                )
            );
    }

    function setRemoteAddress(address _remoteAddress) external onlyOwner {
        remoteAddress = _remoteAddress;
    }

    function setRemoteChainId(uint256 _remoteChainId) external onlyOwner {
        remoteChainId = _remoteChainId;
    }
}
