// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../contracts/evmx/interfaces/IAppGateway.sol";
import "../../contracts/evmx/interfaces/IWatcher.sol";
import "../../contracts/evmx/interfaces/IPromise.sol";

import "../../contracts/utils/common/Structs.sol";
import "../../contracts/utils/common/Constants.sol";
import "../../contracts/utils/common/Errors.sol";
import "solady/utils/ERC1967Factory.sol";

/// @title WatcherPrecompile
/// @notice Contract that handles payload verification, execution and app configurations
contract MockWatcherPrecompile {
    /// @notice Counter for tracking payload execution requests
    uint256 public payloadCounter;

    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;

    event CalledAppGateway(bytes32 triggerId);

    /// @notice Emitted when a new query is requested
    /// @param chainSlug The identifier of the destination chain
    /// @param targetAddress The address of the target contract
    /// @param payloadId The unique identifier for the query
    /// @param payload The query data
    event QueryRequested(uint32 chainSlug, address targetAddress, bytes32 payloadId, bytes payload);

    /// @notice Emitted when a finalize request is made
    event FinalizeRequested(bytes32 digest, PayloadParams params);

    /// @notice Emitted when a request is finalized
    /// @param payloadId The unique identifier for the request
    /// @param proof The proof from the watcher
    event Finalized(bytes32 indexed payloadId, bytes proof);

    /// @notice Emitted when a promise is resolved
    /// @param payloadId The unique identifier for the resolved promise
    event PromiseResolved(bytes32 indexed payloadId);

    event TimeoutRequested(
        bytes32 timeoutId,
        address target,
        bytes payload,
        uint256 executeAt // Epoch time when the task should execute
    );

    /// @notice Emitted when a timeout is resolved
    /// @param timeoutId The unique identifier for the timeout
    /// @param target The target address for the timeout
    /// @param payload The payload data
    /// @param executedAt The epoch time when the task was executed
    event TimeoutResolved(bytes32 timeoutId, address target, bytes payload, uint256 executedAt);

    /// @notice Contract constructor
    /// @param _owner Address of the contract owner
    constructor(address _owner, address addressResolver_) {}

    /// @notice Resolves multiple promises with their return data
    /// @param promiseReturnData_ Array of resolved promises and their return data
    /// @dev Only callable by the contract owner
    function resolvePromises(PromiseReturnData[] calldata promiseReturnData_) external {
        for (uint256 i = 0; i < promiseReturnData_.length; i++) {
            emit PromiseResolved(promiseReturnData_[i].payloadId);
        }
    }

    // ================== On-Chain Trigger ==================

    function callAppGateways(TriggerParams[] calldata params_) external {
        for (uint256 i = 0; i < params_.length; i++) {
            emit CalledAppGateway(params_[i].triggerId);
        }
    }

    /// @notice Retrieves the configuration for a specific plug on a network
    /// @param chainSlug_ The identifier of the network
    /// @param plug_ The address of the plug
    /// @return The app gateway address and switchboard address for the plug
    /// @dev Returns zero addresses if configuration doesn't exist
    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) public view returns (bytes32, address) {
        return (
            _plugConfigs[chainSlug_][plug_].appGatewayId,
            _plugConfigs[chainSlug_][plug_].switchboard
        );
    }
}
