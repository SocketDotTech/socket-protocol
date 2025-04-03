// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {Fees, Read, Parallel, QueuePayloadParams, OverrideParams, CallType, WriteFinality, PayloadParams} from "../protocol/utils/common/Structs.sol";

interface IAppGateway {
    function isAsyncModifierSet() external view returns (bool);

    function getOverrideParams()
        external
        view
        returns (Read, Parallel, WriteFinality, uint256, uint256, bytes32);

    function onRequestComplete(uint40 requestCount_, bytes calldata onCompleteData_) external;

    function handleRevert(uint40 requestCount_, bytes32 payloadId_) external;

    /// @notice initialize the contracts on chain
    function initialize(uint32 chainSlug_) external;

    /// @notice deploy contracts to chain
    function deployContracts(uint32 chainSlug_) external;

    /// @notice get the on-chain address of a contract
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address onChainAddress);

    /// @notice get the forwarder address of a contract
    function forwarderAddresses(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address forwarderAddress);
}
