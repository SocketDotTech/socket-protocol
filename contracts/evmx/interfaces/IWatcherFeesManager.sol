// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

/// @title IWatcherFeesManager
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherFeesManager {
    // Watcher precompile fees
    function getWatcherFees(bytes32 feeType) external view returns (uint256);

    function setWatcherFees(bytes32 feeType, uint256 fees) external;

    // Watcher fees
    function getTotalWatcherFeesRequired(
        bytes32[] memory feeTypes_,
        uint256[] memory counts_
    ) external view returns (uint256);

    function payWatcherFees(
        bytes32[] memory feeTypes_,
        uint256[] memory counts_,
        address consumeFrom_
    ) external;
}
