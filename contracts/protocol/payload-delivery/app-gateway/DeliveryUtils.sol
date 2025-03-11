// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import {AddressResolverUtil} from "../../utils/AddressResolverUtil.sol";
import "./DeliveryHelperStorage.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract DeliveryUtils is
    DeliveryHelperStorage,
    Initializable,
    Ownable,
    AddressResolverUtil
{
    // slots [0-108] reserved for delivery helper storage and [109-159] reserved for addr resolver util
    // slots [160-209] reserved for gap
    uint256[50] _gap_queue_async;

    /// @notice Error thrown when attempting to executed payloads after all have been executed
    error AllPayloadsExecuted();
    /// @notice Error thrown request did not come from Forwarder address
    error NotFromForwarder();
    /// @notice Error thrown when a payload call fails
    error CallFailed(bytes32 payloadId);
    /// @notice Error thrown if payload is too large
    error PayloadTooLarge();
    /// @notice Error thrown if trying to cancel a batch without being the application gateway
    error OnlyAppGateway();
    /// @notice Error thrown when a winning bid exists
    error WinningBidExists();
    /// @notice Error thrown when a bid is insufficient
    error InsufficientFees();

    event CallBackReverted(bytes32 asyncId_, bytes32 payloadId_);
    event RequestCancelled(bytes32 indexed asyncId);
    event BidTimeoutUpdated(uint256 newBidTimeout);
    event PayloadSubmitted(
        bytes32 indexed asyncId,
        address indexed appGateway,
        PayloadDetails[] payloads,
        Fees fees,
        address auctionManager
    );
    /// @notice Emitted when fees are increased
    event FeesIncreased(address indexed appGateway, bytes32 indexed asyncId, uint256 newMaxFees);
    /// @notice Emitted when a payload is requested asynchronously
    event PayloadAsyncRequested(
        bytes32 indexed asyncId,
        bytes32 indexed payloadId,
        bytes32 indexed digest,
        PayloadDetails payloadDetails
    );

    modifier onlyAuctionManager(bytes32 asyncId_) {
        if (msg.sender != requestParams[asyncId_].auctionManager) revert NotAuctionManager();
        _;
    }

    /// @notice Gets the payload delivery plug address
    /// @param chainSlug_ The chain identifier
    /// @return address The address of the payload delivery plug
    function getDeliveryHelperPlugAddress(uint32 chainSlug_) public view returns (address) {
        return watcherPrecompile__().contractFactoryPlug(chainSlug_);
    }

    /// @notice Updates the bid timeout
    /// @param newBidTimeout_ The new bid timeout value
    function updateBidTimeout(uint128 newBidTimeout_) external onlyOwner {
        bidTimeout = newBidTimeout_;
        emit BidTimeoutUpdated(newBidTimeout_);
    }
}
