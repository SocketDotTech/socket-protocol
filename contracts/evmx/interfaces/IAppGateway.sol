// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {OverrideParams} from "../../utils/common/Structs.sol";

/// @title IAppGateway
/// @notice Interface for the app gateway
interface IAppGateway {
    /// @notice Checks if the async modifier is set
    /// @return isAsyncModifierSet_ True if the async modifier is set, false otherwise
    function isAsyncModifierSet() external view returns (bool);

    /// @notice Gets the override parameters
    /// @return overrideParams_ The override parameters
    /// @return sbType_ The switchboard type
    function getOverrideParams() external view returns (OverrideParams memory, bytes32);

    /// @notice Handles the request complete event
    /// @param requestCount_ The request count
    /// @param onCompleteData_ The on complete data
    function onRequestComplete(uint40 requestCount_, bytes calldata onCompleteData_) external;

    /// @notice Handles the revert event
    /// @param payloadId_ The payload id
    function handleRevert(bytes32 payloadId_) external;

    /// @notice initialize the contracts on chain
    /// @param chainSlug_ The chain slug
    function initializeOnChain(uint32 chainSlug_) external;

    /// @notice get the on-chain address of a contract
    /// @param contractId_ The contract id
    /// @param chainSlug_ The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address onChainAddress);

    /// @notice get the forwarder address of a contract
    /// @param contractId_ The contract id
    /// @param chainSlug_ The chain slug
    /// @return forwarderAddress The forwarder address
    function forwarderAddresses(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address forwarderAddress);
}
