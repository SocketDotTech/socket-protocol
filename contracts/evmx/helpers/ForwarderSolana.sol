// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import "./AddressResolverUtil.sol";
import "../interfaces/IAddressResolver.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IForwarder.sol";
import {QueueParams, OverrideParams, Transaction} from "../../utils/common/Structs.sol";
import {AsyncModifierNotSet, WatcherNotSet, InvalidOnChainAddress} from "../../utils/common/Errors.sol";
import "../../utils/RescueFundsLib.sol";
import {toBytes32Format} from "../../utils/common/Converters.sol";
import {SolanaInstruction} from "../../utils/common/Structs.sol";
import {CHAIN_SLUG_SOLANA_MAINNET, CHAIN_SLUG_SOLANA_DEVNET} from "../../utils/common/Constants.sol";
import {ForwarderStorage} from "./Forwarder.sol";

/// @title Forwarder Contract
/// @notice This contract acts as a forwarder for async calls to the on-chain contracts.
contract ForwarderSolana is ForwarderStorage, Initializable, AddressResolverUtil {
    error InvalidSolanaChainSlug();
    error AddressResolverNotSet();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param chainSlug_ chain slug on which the contract is deployed
    //// @param onChainAddress_ on-chain address associated with this forwarder
    /// @param addressResolver_ address resolver contract
    function initialize(
        uint32 chainSlug_,
        bytes32 onChainAddress_, // TODO:GW: after demo remove this param, we take target as param in callSolana()
        address addressResolver_
    ) public initializer {
        if (chainSlug_ == CHAIN_SLUG_SOLANA_MAINNET || chainSlug_ == CHAIN_SLUG_SOLANA_DEVNET) {
            chainSlug = chainSlug_;
        } else {
            revert InvalidSolanaChainSlug();
        }
        onChainAddress = onChainAddress_;
        _setAddressResolver(addressResolver_);
    }

    /// @notice Returns the on-chain address associated with this forwarder.
    /// @return The on-chain address.
    function getOnChainAddress() external view returns (bytes32) {
        return onChainAddress;
    }

    /// @notice Returns the chain slug on which the contract is deployed.
    /// @return chain slug
    function getChainSlug() external view returns (uint32) {
        return chainSlug;
    }

    /// @notice Fallback function to process the contract calls to onChainAddress
    /// @dev It queues the calls in the middleware and deploys the promise contract
    // function callSolana(SolanaInstruction memory solanaInstruction, bytes32 switchboardSolana) external {
    function callSolana(bytes memory solanaPayload, bytes32 target) external {
        if (address(addressResolver__) == address(0)) {
            revert AddressResolverNotSet();
        }
        if (address(watcher__()) == address(0)) {
            revert WatcherNotSet();
        }

        // validates if the async modifier is set
        address msgSender = msg.sender;
        bool isAsyncModifierSet = IAppGateway(msgSender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotSet();

        // fetch the override params from app gateway
        (OverrideParams memory overrideParams, bytes32 sbType) = IAppGateway(msgSender)
            .getOverrideParams();

        // TODO:GW: after POC make it work like below
        // get the switchboard address from the watcher precompile config
        // address switchboard = watcherPrecompileConfig().switchboards(chainSlug, sbType);

        // Queue the call in the middleware.
        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug,
            // target: onChainAddress, // for Solana reads it should be accountToRead
            // TODO: Solana forwarder can be a singleton - does not need to store onChainAddress and can use target as param
            target: target,
            payload: solanaPayload
        });
        queueParams.switchboardType = sbType;
        watcher__().queue(queueParams, msgSender);
    }
}
