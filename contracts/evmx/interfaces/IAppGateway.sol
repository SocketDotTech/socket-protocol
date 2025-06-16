// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Read, Parallel, QueuePayloadParams, OverrideParams, WriteFinality, PayloadParams} from "../../utils/common/Structs.sol";

/// @title IAppGateway
/// @notice Interface for the app gateway
interface IAppGateway {
    /// @notice Checks if the async modifier is set
    /// @return isAsyncModifierSet_ True if the async modifier is set, false otherwise
    function isAsyncModifierSet() external view returns (bool);

    /// @notice Gets the override parameters
    /// @return read_ The read parameters
    /// @return parallel_ The parallel parameters
    /// @return writeFinality_ The write finality parameters
    /// @return readTimeout_ The read timeout
    /// @return writeTimeout_ The write timeout
    /// @return writeFinalityTimeout_ The write finality timeout
    /// @return sbType_ The switchboard type
    function getOverrideParams()
        external
        view
        returns (Read, Parallel, WriteFinality, uint256, uint256, uint256, bytes32);

    /// @notice Handles the request complete event
    /// @param requestCount_ The request count
    /// @param onCompleteData_ The on complete data
    function onRequestComplete(uint40 requestCount_, bytes calldata onCompleteData_) external;

    /// @notice Handles the revert event
    /// @param requestCount_ The request count
    /// @param payloadId_ The payload id
    function handleRevert(uint40 requestCount_, bytes32 payloadId_) external;

    /// @notice initialize the contracts on chain
    /// @param chainSlug_ The chain slug
    function initialize(uint32 chainSlug_) external;

    /// @notice get the on-chain address of a contract
    /// @param contractId_ The contract id
    /// @param chainSlug_ The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (bytes32 onChainAddress);

    /// @notice get the forwarder address of a contract
    /// @param contractId_ The contract id
    /// @param chainSlug_ The chain slug
    /// @return forwarderAddress The forwarder address
    function forwarderAddresses(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address forwarderAddress);
}
