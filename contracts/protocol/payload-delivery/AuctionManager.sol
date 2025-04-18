// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "solady/utils/Initializable.sol";
import "../utils/AccessControl.sol";

import {IMiddleware} from "../../interfaces/IMiddleware.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import {IAuctionManager} from "../../interfaces/IAuctionManager.sol";

import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import {Fees, Bid, RequestMetadata, RequestParams} from "../utils/common/Structs.sol";
import {AuctionClosed, AuctionAlreadyStarted, BidExceedsMaxFees, LowerBidAlreadyExists, InvalidTransmitter} from "../utils/common/Errors.sol";
import {TRANSMITTER_ROLE} from "../utils/common/AccessRoles.sol";

abstract contract AuctionManagerStorage is IAuctionManager {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    uint32 public evmxSlug;

    // slot 51
    mapping(uint40 => Bid) public winningBids;

    // slot 52
    // requestCount => auction status
    mapping(uint40 => bool) public override auctionClosed;

    // slot 53
    mapping(uint40 => bool) public override auctionStarted;

    // slot 54
    uint256 public auctionEndDelaySeconds;

    // slot 55
    mapping(address => bool) public whitelistedTransmitters;

    // slot 56
    mapping(uint40 => uint256) public reAuctionCount;

    // slot 57
    uint256 public maxReAuctionCount;

    // slots [57-104] reserved for gap
    uint256[48] _gap_after;

    // slots 105-155 reserved for addr resolver util
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
    }

    function startAuction(uint40 requestCount_) internal {
        if (auctionClosed[requestCount_]) revert AuctionClosed();
        if (auctionStarted[requestCount_]) revert AuctionAlreadyStarted();

        auctionStarted[requestCount_] = true;
        emit AuctionStarted(requestCount_);
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

        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(this), evmxSlug, requestCount_, fee, extraData)),
            transmitterSignature
        );
        if (!_hasRole(TRANSMITTER_ROLE, transmitter)) revert InvalidTransmitter();

        Bid memory newBid = Bid({fee: fee, transmitter: transmitter, extraData: extraData});
        RequestMetadata memory requestMetadata = IMiddleware(addressResolver__.deliveryHelper())
            .getRequestMetadata(requestCount_);
        if (fee > requestMetadata.fees.amount) revert BidExceedsMaxFees();
        if (requestMetadata.auctionManager != address(this)) revert InvalidBid();

        if (
            winningBids[requestCount_].transmitter != address(0) &&
            fee >= winningBids[requestCount_].fee
        ) revert LowerBidAlreadyExists();

        winningBids[requestCount_] = newBid;

        IFeesManager(addressResolver__.feesManager()).blockFees(
            requestMetadata.appGateway,
            requestMetadata.fees,
            newBid,
            requestCount_
        );

        if (auctionEndDelaySeconds > 0) {
            startAuction(requestCount_);
            watcherPrecompile__().setTimeout(
                auctionEndDelaySeconds,
                abi.encodeWithSelector(this.endAuction.selector, requestCount_)
            );
        } else {
            _endAuction(requestCount_);
        }

        emit BidPlaced(requestCount_, newBid);
        auctionClosed[requestCount_] = true;
    }

    /// @notice Ends an auction
    /// @param requestCount_ The ID of the auction
    function endAuction(uint40 requestCount_) external onlyWatcherPrecompile {
        _endAuction(requestCount_);
    }

    function _endAuction(uint40 requestCount_) internal {
        auctionClosed[requestCount_] = true;
        Bid memory winningBid = winningBids[requestCount_];
        if (winningBid.transmitter == address(0)) revert InvalidTransmitter();

        watcherPrecompile__().setTimeout(
            IMiddleware(addressResolver__.deliveryHelper()).bidTimeout(),
            abi.encodeWithSelector(this.expireBid.selector, requestCount_)
        );
        IMiddleware(addressResolver__.deliveryHelper()).startRequestProcessing(
            requestCount_,
            winningBid
        );
        emit AuctionEnded(requestCount_, winningBid);
    }

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

    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }
}
