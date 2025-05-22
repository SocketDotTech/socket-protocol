// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {PayloadParams, ResolvedPromises} from "../../utils/common/Structs.sol";

/// @title IPromiseResolver
/// @notice Interface for resolving async promises
interface IPromiseResolver {
    /// @notice Resolves a promise with the given data
    /// @param resolvedPromises_ The promises to resolve
    function resolvePromises(ResolvedPromises[] memory resolvedPromises_) external;

    /// @notice Rejects a promise with the given reason
    /// @param isRevertingOnchain_ Whether the promise is reverting onchain
    /// @param payloadId_ The ID of the promise to reject
    function markRevert(bool isRevertingOnchain_, bytes32 payloadId_) external;
}
