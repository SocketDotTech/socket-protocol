// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../interfaces/IWatcher.sol";
import "../helpers/AddressResolverUtil.sol";
import "solady/utils/ECDSA.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @title WatcherStorage
/// @notice Storage contract for the WatcherPrecompile system
/// @dev This contract contains all the storage variables used by the WatcherPrecompile system
/// @dev It is inherited by WatcherPrecompileCore and WatcherPrecompile
abstract contract WatcherStorage is IWatcher, Initializable, Ownable {
    // slots [0-49]: gap for future storage variables
    uint256[50] _gap_before;

    // slot 50 (32 + 32 + 160)
    /// @notice The chain slug of the watcher precompile
    uint32 public evmxSlug;
    /// @notice stores temporary chainSlug of the trigger from a chain
    uint32 public triggerFromChainSlug;
    /// @notice stores temporary plug of the trigger from a chain
    address public triggerFromPlug;

    // slot 51
    /// @notice Stores the trigger fees
    uint256 public triggerFees;

    // slot 52
    IRequestHandler public override requestHandler__;

    // slot 53
    IConfigurations public override configurations__;

    // slot 54
    IPromiseResolver public override promiseResolver__;

    // slot 55
    address public latestAsyncPromise;

    // slot 56
    address public appGatewayTemp;

    // slot 57
    /// @notice The queue of payloads
    QueueParams[] public payloadQueue;

    // slot 58
    /// @notice Maps nonce to whether it has been used
    /// @dev Used to prevent replay attacks with signature nonces
    /// @dev signatureNonce => isValid
    mapping(uint256 => bool) public isNonceUsed;

    // slot 59
    /// @notice Mapping to store if appGateway has been called with trigger from on-chain Inbox
    /// @dev Maps call ID to boolean indicating if the appGateway has been called
    /// @dev callId => bool
    mapping(bytes32 => bool) public isAppGatewayCalled;

    // slots [60-109]: gap for future storage variables
    uint256[50] _gap_after;

    // slots [110-159] 50 slots reserved for address resolver util
}
