// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {LimitParams, UpdateLimitParams} from "../../utils/common/Structs.sol";

/// @title IWatcherPrecompileLimits
/// @notice Interface for the Watcher Precompile system that handles payload verification and execution
/// @dev Defines core functionality for payload processing and promise resolution
interface IWatcherPrecompileLimits {
    function getTotalFeesRequired(
        uint256 queryCount_,
        uint256 finalizeCount_,
        uint256 scheduleCount_,
        uint256 callbackCount_
    ) external view returns (uint256);

    function queryFees() external view returns (uint256);

    function finalizeFees() external view returns (uint256);

    function timeoutFees() external view returns (uint256);

    function callBackFees() external view returns (uint256);
}
