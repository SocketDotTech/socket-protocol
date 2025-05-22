// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {PayloadParams, PromiseReturnData} from "../../utils/common/Structs.sol";

/// @title IPromiseResolver
/// @notice Interface for resolving async promises
interface IPromiseResolver {
    /// @notice Resolves a promise with the given data
    /// @param promiseReturnData_ The promises to resolve
    function resolvePromises(PromiseReturnData[] memory promiseReturnData_) external;

    /// @notice Rejects a promise with the given reason
    /// @param isRevertingOnchain_ Whether the promise is reverting onchain
    /// @param resolvedPromise_ The resolved promise
    function markRevert(
        PromiseReturnData memory resolvedPromise_,
        bool isRevertingOnchain_
    ) external;
}
