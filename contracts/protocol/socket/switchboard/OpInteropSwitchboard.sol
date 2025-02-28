// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {FastSwitchboard} from "./FastSwitchboard.sol";
import {SuperchainEnabled} from "./SuperchainEnabled.sol";
import {ISocket} from "../../../interfaces/ISocket.sol";

contract OpInteropSwitchboard is FastSwitchboard, SuperchainEnabled {
    mapping(bytes32 => bool) public isSyncedOut;
    mapping(bytes32 => bytes32) public payloadIdToDigest;
    mapping(bytes32 => bool) public unopenedDigests;
    mapping(address => uint256) public unminted;
    address public token;
    address public remoteAddress;
    uint256 public remoteChainId;

    struct PayloadParams {
        bytes32 payloadId;
        address appGateway;
        address transmitter;
        address target;
        uint256 value;
        uint256 deadline;
        uint256 executionGasLimit;
        bytes payload;
    }

    modifier onlyToken() {
        if (msg.sender != token) revert OnlyTokenAllowed();
        _;
    }

    error OnlyTokenAllowed();

    constructor(
        uint32 chainSlug_,
        ISocket socket_,
        address owner_
    ) FastSwitchboard(chainSlug_, socket_, owner_) {}

    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata proof_) external override {
        address watcher = _recoverSigner(keccak256(abi.encode(address(this), digest_)), proof_);

        if (isAttested[digest_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_] = true;
        payloadIdToDigest[payloadId_] = digest_;
        emit Attested(payloadId_, digest_, watcher);
    }

    function syncOut(bytes32 digest_, bytes32 payloadId_) external {
        if (isSyncedOut[digest_]) return;
        isSyncedOut[digest_] = true;

        if (!isAttested[digest_]) return;

        bytes32 digest = payloadIdToDigest[payloadId_];
        if (digest != digest_) return;

        ISocket.ExecutionStatus isExecuted = socket__.payloadExecuted(payloadId_);
        if (isExecuted != ISocket.ExecutionStatus.Executed) return;

        _xMessageContract(
            remoteChainId,
            remoteAddress,
            abi.encodeWithSelector(this.syncIn.selector, digest_)
        );
    }

    function syncIn(bytes32 digest_) external xOnlyFromContract(remoteAddress, remoteChainId) {
        unopenedDigests[digest_] = true;
    }

    function openDigest(bytes32 digest_, PayloadParams calldata payloadParams_) external {
        bytes32 expectedDigest = _packPayload(payloadParams_);
        if (expectedDigest != digest_) return;

        if (!unopenedDigests[digest_]) return;
        unopenedDigests[digest_] = false;

        (address user, uint256 amount) = _decodeMint(payloadParams_.payload);
        unminted[user] += amount;
    }

    function _decodeMint(
        bytes memory payload
    ) internal pure returns (address user, uint256 amount) {
        return abi.decode(payload, (address, uint256));
    }

    function _packPayload(PayloadParams memory payloadParams_) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    payloadParams_.payloadId,
                    payloadParams_.appGateway,
                    payloadParams_.transmitter,
                    payloadParams_.target,
                    payloadParams_.value,
                    payloadParams_.deadline,
                    payloadParams_.executionGasLimit,
                    payloadParams_.payload
                )
            );
    }

    function checkAndConsume(address user_, uint256 amount_) external onlyToken {
        unminted[user_] -= amount_;
    }

    function setToken(address token_) external onlyOwner {
        token = token_;
    }

    function setRemoteAddress(address _remoteAddress) external onlyOwner {
        remoteAddress = _remoteAddress;
    }

    function setRemoteChainId(uint256 _remoteChainId) external onlyOwner {
        remoteChainId = _remoteChainId;
    }
}
