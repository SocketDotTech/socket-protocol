// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "solady/utils/Initializable.sol";
import "../utils/AccessControl.sol";
import "../../interfaces/IAuctionManager.sol";
import {IMiddleware} from "../../interfaces/IMiddleware.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import {AuctionClosed, AuctionAlreadyStarted, BidExceedsMaxFees, LowerBidAlreadyExists, InvalidTransmitter} from "../utils/common/Errors.sol";
import {TRANSMITTER_ROLE} from "../utils/common/AccessRoles.sol";

/// @title AuctionManagerStorage
/// @notice Storage for the AuctionManager contract
abstract contract AuctionManagerStorage is IAuctionManager {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    uint32 public evmxSlug;

    // slot 51
    uint256 public maxReAuctionCount;

    // slot 52
    uint256 public auctionEndDelaySeconds;

    // slot 53
    mapping(uint40 => Bid) public winningBids;

    // slot 54
    // requestCount => auction status
    mapping(uint40 => bool) public override auctionClosed;

    // slot 55
    mapping(uint40 => bool) public override auctionStarted;

    // slot 56
    mapping(uint40 => uint256) public reAuctionCount;

    // slots [57-106] reserved for gap
    uint256[50] _gap_after;

    // slots 107-157 (51) reserved for access control
    // slots 158-208 (51) reserved for addr resolver util
}

/// @title AuctionManager
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is
    AuctionManagerStorage,
    Initializable,
    AccessControl,
    AddressResolverUtil
{
    event AuctionRestarted(uint40 requestCount);
    event AuctionStarted(uint40 requestCount);
    event AuctionEnded(uint40 requestCount, Bid winningBid);
    event BidPlaced(uint40 requestCount, Bid bid);
    event AuctionEndDelaySecondsSet(uint256 auctionEndDelaySeconds);

    error InvalidBid();
    error MaxReAuctionCountReached();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param evmxSlug_ The chain slug for the VM
    /// @param auctionEndDelaySeconds_ The delay in seconds before an auction can end
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the contract owner
    /// @param maxReAuctionCount_ The maximum number of re-auctions allowed
    function initialize(
        uint32 evmxSlug_,
        uint256 auctionEndDelaySeconds_,
        address addressResolver_,
        address owner_,
        uint256 maxReAuctionCount_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);

        evmxSlug = evmxSlug_;
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
        maxReAuctionCount = maxReAuctionCount_;
    }

    function setAuctionEndDelaySeconds(uint256 auctionEndDelaySeconds_) external onlyOwner {
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
        emit AuctionEndDelaySecondsSet(auctionEndDelaySeconds_);
    }

    /// @notice Places a bid for an auction
    /// @param requestCount_ The ID of the auction
    /// @param fee The bid amount
    /// @param transmitterSignature The signature of the transmitter
    function bid(
        uint40 requestCount_,
        uint256 fee,
        bytes memory transmitterSignature,
        bytes memory extraData
    ) external {
        if (auctionClosed[requestCount_]) revert AuctionClosed();

        // check if the transmitter is valid
        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(this), evmxSlug, requestCount_, fee, extraData)),
            transmitterSignature
        );
        if (!_hasRole(TRANSMITTER_ROLE, transmitter)) revert InvalidTransmitter();

        // create a new bid
        Bid memory newBid = Bid({fee: fee, transmitter: transmitter, extraData: extraData});
        // get the request metadata
        RequestMetadata memory requestMetadata = IMiddleware(addressResolver__.deliveryHelper())
            .getRequestMetadata(requestCount_);

        // check if the bid is for this auction manager
        if (requestMetadata.auctionManager != address(this)) revert InvalidBid();
        // check if the bid exceeds the max fees quoted by app gateway
        if (fee > requestMetadata.fees.amount) revert BidExceedsMaxFees();

        // check if the bid is lower than the existing bid
        if (
            winningBids[requestCount_].transmitter != address(0) &&
            fee >= winningBids[requestCount_].fee
        ) revert LowerBidAlreadyExists();

        // update the winning bid
        winningBids[requestCount_] = newBid;

        // block the fees
        IFeesManager(addressResolver__.feesManager()).blockFees(
            requestMetadata.appGateway,
            requestMetadata.fees,
            newBid,
            requestCount_
        );

        // end the auction if the no auction end delay
        if (auctionEndDelaySeconds > 0) {
            _startAuction(requestCount_);
            watcherPrecompile__().setTimeout(
                auctionEndDelaySeconds,
                abi.encodeWithSelector(this.endAuction.selector, requestCount_)
            );
        } else {
            _endAuction(requestCount_);
        }

        emit BidPlaced(requestCount_, newBid);
    }

    /// @notice Ends an auction
    /// @param requestCount_ The ID of the auction
    function endAuction(uint40 requestCount_) external onlyWatcherPrecompile {
        if (auctionClosed[requestCount_]) return;
        _endAuction(requestCount_);
    }

    function _endAuction(uint40 requestCount_) internal {
        // get the winning bid, if no transmitter is set, revert
        Bid memory winningBid = winningBids[requestCount_];
        if (winningBid.transmitter == address(0)) revert InvalidTransmitter();

        auctionClosed[requestCount_] = true;

        // set the timeout for the bid expiration
        // useful in case a transmitter did bid but did not execute payloads
        watcherPrecompile__().setTimeout(
            IMiddleware(addressResolver__.deliveryHelper()).bidTimeout(),
            abi.encodeWithSelector(this.expireBid.selector, requestCount_)
        );

        // start the request processing, it will finalize the request
        IMiddleware(addressResolver__.deliveryHelper()).startRequestProcessing(
            requestCount_,
            winningBid
        );

        emit AuctionEnded(requestCount_, winningBid);
    }

    /// @notice Expires a bid and restarts an auction in case a request is not fully executed.
    /// @dev Auction can be restarted only for `maxReAuctionCount` times.
    /// @dev It also unblocks the fees from last transmitter to be assigned to the new winner.
    /// @param requestCount_ The request id
    function expireBid(uint40 requestCount_) external onlyWatcherPrecompile {
        if (reAuctionCount[requestCount_] >= maxReAuctionCount) revert MaxReAuctionCountReached();
        RequestParams memory requestParams = watcherPrecompile__().getRequestParams(requestCount_);

        // if executed, bid is not expired
        if (requestParams.payloadsRemaining == 0 || requestParams.isRequestCancelled) return;
        winningBids[requestCount_] = Bid({fee: 0, transmitter: address(0), extraData: ""});
        auctionClosed[requestCount_] = false;
        reAuctionCount[requestCount_]++;

        IFeesManager(addressResolver__.feesManager()).unblockFees(requestCount_);
        emit AuctionRestarted(requestCount_);
    }

    function _startAuction(uint40 requestCount_) internal {
        if (auctionClosed[requestCount_]) revert AuctionClosed();
        if (auctionStarted[requestCount_]) revert AuctionAlreadyStarted();

        auctionStarted[requestCount_] = true;
        emit AuctionStarted(requestCount_);
    }

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }
}
