// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import "solady/utils/ECDSA.sol";
import "../interfaces/IFeesManager.sol";
import {AddressResolverUtil} from "../AddressResolverUtil.sol";
import {NonceUsed} from "../../utils/common/Errors.sol";
import {Bid, Parallel, WriteFinality, QueuePayloadParams, IsPlug, PayloadSubmitParams, RequestMetadata, UserCredits} from "../../utils/common/Structs.sol";
import "../watcher/WatcherBase.sol";

abstract contract FeesManagerStorage is IFeesManager, WatcherBase {
    // user credits => stores fees for user, app gateway, transmitters and watcher precompile
    mapping(address => UserCredits) public userCredits;

    /// @notice Mapping to track request credits details for each request count
    /// @dev requestCount => RequestFee
    mapping(uint40 => uint256) public requestCountCredits;

    // user approved app gateways
    // userAddress => appGateway => isWhitelisted
    mapping(address => mapping(address => bool)) public isAppGatewayWhitelisted;

    // token pool balances
    //  chainSlug => token address  => amount
    mapping(uint32 => mapping(address => uint256)) public tokenPoolBalances;

    /// @notice Mapping to track nonce to whether it has been used
    /// @dev address => signatureNonce => isNonceUsed
    /// @dev used by watchers or other users in signatures
    mapping(address => mapping(uint256 => bool)) public isNonceUsed;
}
