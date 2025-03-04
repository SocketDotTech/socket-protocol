// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {FastSwitchboard} from "./FastSwitchboard.sol";
import {SuperchainEnabled} from "./SuperchainEnabled.sol";
import {ISocket} from "../../../interfaces/ISocket.sol";

contract OpInteropSwitchboard is FastSwitchboard, SuperchainEnabled {
    mapping(bytes32 => bool) public isSyncedOut;
    mapping(bytes32 => bytes32) public payloadIdToDigest;
    mapping(address => uint256) public unminted;
    address public token;
    address public remoteAddress;
    uint256 public remoteChainId;

    modifier onlyToken() {
        if (msg.sender != token) revert OnlyTokenAllowed();
        _;
    }

    error OnlyTokenAllowed();

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

    function attest(bytes32 payloadId_, bytes32 digest_, bytes calldata proof_) external override {
        address watcher = _recoverSigner(keccak256(abi.encode(address(this), digest_)), proof_);

        if (isAttested[digest_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, watcher)) revert WatcherNotFound();

        isAttested[digest_] = true;
        payloadIdToDigest[payloadId_] = digest_;
        emit Attested(payloadId_, digest_, watcher);
    }

    function syncOut(
        bytes32 digest_,
        bytes32 payloadId_,
        PayloadParams calldata payloadParams_
    ) external override {
        if (isSyncedOut[digest_]) return;
        isSyncedOut[digest_] = true;

        if (!isAttested[digest_]) return;

        bytes32 digest = payloadIdToDigest[payloadId_];
        if (digest != digest_) return;

        bytes32 expectedDigest = _packPayload(payloadParams_);
        if (expectedDigest != digest_) return;

        ISocket.ExecutionStatus isExecuted = socket__.payloadExecuted(payloadId_);
        if (isExecuted != ISocket.ExecutionStatus.Executed) return;

        (address user, uint256 amount, bool isBurn) = _decodeBurn(payloadParams_.payload);

        if (!isBurn) return;
        _xMessageContract(
            remoteChainId,
            remoteAddress,
            abi.encodeWithSelector(this.syncIn.selector, user, amount)
        );
    }

    function syncIn(
        address user_,
        uint256 amount_
    ) external xOnlyFromContract(remoteAddress, remoteChainId) {
        unminted[user_] += amount_;
    }

    function _decodeBurn(
        bytes memory payload
    ) internal pure returns (address user, uint256 amount, bool isBurn) {
        // Extract function selector from payload
        bytes4 selector;
        assembly {
            // Load first 4 bytes from payload data
            selector := mload(add(payload, 32))
        }
        // Check if selector matches burn()
        if (selector != bytes4(0x9dc29fac)) return (user, amount, false);

        // Decode the payload after the selector (skip first 4 bytes)
        assembly {
            user := mload(add(add(payload, 36), 0)) // 32 + 4 bytes offset for first param
            amount := mload(add(add(payload, 68), 0)) // 32 + 4 + 32 bytes offset for second param
        }
        isBurn = true;
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
