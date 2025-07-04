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

/// @title Forwarder Storage
/// @notice Storage contract for the Forwarder contract that contains the state variables
abstract contract ForwarderStorage is IForwarder {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    /// @notice chain slug on which the contract is deployed
    uint32 public chainSlug;

    /// @notice old on-chain address kep for storage compatibility - can be removed after redeployment
    address internal oldOnChainAddress;

    // slot 51
    /// @notice on-chain address associated with this forwarder
    bytes32 public onChainAddress;

    // slots [52-100] reserved for gap
    uint256[49] _gap_after;

    // slots [101-150] 50 slots reserved for address resolver util
}

/// @title Forwarder Contract
/// @notice This contract acts as a forwarder for async calls to the on-chain contracts.
contract Forwarder is ForwarderStorage, Initializable, AddressResolverUtil {
    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer to replace constructor for upgradeable contracts
    /// @param chainSlug_ chain slug on which the contract is deployed
    /// @param onChainAddress_ on-chain address associated with this forwarder
    /// @param addressResolver_ address resolver contract
    function initialize(
        uint32 chainSlug_,
        bytes32 onChainAddress_,
        address addressResolver_
    ) public reinitializer(1) {
        if (onChainAddress_ == bytes32(0)) revert InvalidOnChainAddress();
        chainSlug = chainSlug_;
        onChainAddress = onChainAddress_;
        _setAddressResolver(addressResolver_);
    }

    /// @notice Returns the on-chain address associated with this forwarder.
    /// @return The on-chain address.
    function getOnChainAddress() public view override returns (bytes32) {
        if (oldOnChainAddress != address(0)) {
            return toBytes32Format(oldOnChainAddress);
        }
        return onChainAddress;
    }

    /// @notice Returns the chain slug on which the contract is deployed.
    /// @return chain slug
    function getChainSlug() external view override returns (uint32) {
        return chainSlug;
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(address token_, address rescueTo_, uint256 amount_) external onlyWatcher {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }

    /// @notice Fallback function to process the contract calls to onChainAddress
    /// @dev It queues the calls in the middleware and deploys the promise contract
    fallback() external {
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

        // Queue the call in the middleware.
        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug,
            target: getOnChainAddress(),
            payload: msg.data
        });
        queueParams.switchboardType = sbType;
        watcher__().queue(queueParams, msgSender);
    }
}
