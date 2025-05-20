// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IWatcher.sol";

/// @title WatcherStorage
/// @notice Storage contract for the WatcherPrecompile system
/// @dev This contract contains all the storage variables used by the WatcherPrecompile system
/// @dev It is inherited by WatcherPrecompileCore and WatcherPrecompile
abstract contract WatcherStorage is IWatcher {
    // slots [0-49]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 50
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;

    // Payload Params
    /// @notice The time from queue for the payload to be executed
    /// @dev Expiry time in seconds for payload execution
    uint256 public expiryTime;

    /// @notice Maps nonce to whether it has been used
    /// @dev Used to prevent replay attacks with signature nonces
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    /// @notice The queue of payloads
    QueueParams[] public payloadQueue;
    address public latestAsyncPromise;
    address public appGatewayTemp;

    // slots [51-100]: gap for future storage variables
    uint256[50] _gap_after;

    // slots 115-165 (51) reserved for access control
    // slots 166-216 (51) reserved for addr resolver util
}
