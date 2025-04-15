// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AddressResolverUtil} from "../../utils/AddressResolverUtil.sol";
import "./DeliveryHelperStorage.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract DeliveryUtils is
    DeliveryHelperStorage,
    Initializable,
    Ownable,
    AddressResolverUtil
{
    // slots [156-206] reserved for gap
    uint256[50] _gap_delivery_utils;

    /// @notice Error thrown if payload is too large
    error PayloadTooLarge();
    /// @notice Error thrown if trying to cancel a batch without being the application gateway
    error OnlyAppGateway();
    /// @notice Error thrown when a winning bid exists
    error WinningBidExists();
    /// @notice Error thrown when a bid is insufficient
    error InsufficientFees();
    /// @notice Error thrown when a request contains only reads
    error ReadOnlyRequests();

    /// @notice Error thrown when a request contains more than 10 payloads
    error RequestPayloadCountLimitExceeded();
    /// @notice Error thrown when a maximum message value limit is exceeded
    error MaxMsgValueLimitExceeded();

    event BidTimeoutUpdated(uint256 newBidTimeout);
    event PayloadSubmitted(
        uint40 indexed requestCount,
        address indexed appGateway,
        PayloadSubmitParams[] payloadSubmitParams,
        Fees fees,
        address auctionManager,
        bool onlyReadRequests
    );
    /// @notice Emitted when fees are increased
    event FeesIncreased(
        address indexed appGateway,
        uint40 indexed requestCount,
        uint256 newMaxFees
    );
    /// @notice Emitted when chain max message value limits are updated
    event ChainMaxMsgValueLimitsUpdated(uint32[] chainSlugs, uint256[] maxMsgValueLimits);
    /// @notice Emitted when a request is cancelled
    event RequestCancelled(uint40 indexed requestCount);

    modifier onlyAuctionManager(uint40 requestCount_) {
        if (msg.sender != requests[requestCount_].auctionManager) revert NotAuctionManager();
        _;
    }

    /// @notice Gets the payload delivery plug address
    /// @param chainSlug_ The chain identifier
    /// @return address The address of the payload delivery plug
    function getDeliveryHelperPlugAddress(uint32 chainSlug_) public view returns (address) {
        return watcherPrecompileConfig().contractFactoryPlug(chainSlug_);
    }

    /// @notice Updates the bid timeout
    /// @param newBidTimeout_ The new bid timeout value
    function updateBidTimeout(uint128 newBidTimeout_) external onlyOwner {
        bidTimeout = newBidTimeout_;
        emit BidTimeoutUpdated(newBidTimeout_);
    }

    /// @notice Updates the maximum message value limit for multiple chains
    /// @param chainSlugs_ Array of chain identifiers
    /// @param maxMsgValueLimits_ Array of corresponding maximum message value limits
    function updateChainMaxMsgValueLimits(
        uint32[] calldata chainSlugs_,
        uint256[] calldata maxMsgValueLimits_
    ) external onlyOwner {
        if (chainSlugs_.length != maxMsgValueLimits_.length) revert InvalidIndex();

        for (uint256 i = 0; i < chainSlugs_.length; i++) {
            chainMaxMsgValueLimit[chainSlugs_[i]] = maxMsgValueLimits_[i];
        }

        emit ChainMaxMsgValueLimitsUpdated(chainSlugs_, maxMsgValueLimits_);
    }
}
