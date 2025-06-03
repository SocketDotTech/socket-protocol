// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../contracts/evmx/watcher/Trigger.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract MockWatcherPrecompile is Trigger {
    uint256 public newValue;

    function initialize(uint256 newValue_) external reinitializer(2) {
        newValue = newValue_;
    }

    function getRequestParams(
        uint40 requestCount_
    ) external view override returns (RequestParams memory) {}

    function getPayloadParams(
        bytes32 payloadId_
    ) external view override returns (PayloadParams memory) {}

    function getCurrentRequestCount() external view override returns (uint40) {}

    function queue(
        QueueParams calldata queueParams_,
        address appGateway_
    ) external override returns (address, uint40) {}

    function clearQueue() external override {}

    function submitRequest(
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes calldata onCompleteData
    ) external override returns (uint40 requestCount, address[] memory promises) {}

    function queueAndSubmit(
        QueueParams memory queue_,
        uint256 maxFees,
        address auctionManager,
        address consumeFrom,
        bytes calldata onCompleteData
    ) external override returns (uint40 requestCount, address[] memory promises) {}

    function getPrecompileFees(
        bytes4 precompile_,
        bytes memory precompileData_
    ) external view override returns (uint256) {}

    function cancelRequest(uint40 requestCount_) external override {}

    function increaseFees(uint40 requestCount_, uint256 newFees_) external override {}

    function setIsValidPlug(
        bool isValid_,
        uint32 chainSlug_,
        address onchainAddress_
    ) external override {}

    function isWatcher(address account_) external view override returns (bool) {}

    function watcherMultiCall(WatcherMultiCallParams[] memory params_) external payable {
        if (isNonceUsed[params_[0].nonce]) revert NonceUsed();
        isNonceUsed[params_[0].nonce] = true;
    }
}
