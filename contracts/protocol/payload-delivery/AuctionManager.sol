// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "solady/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {IDeliveryHelper} from "../../interfaces/IDeliveryHelper.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";
import {IAuctionManager} from "../../interfaces/IAuctionManager.sol";

import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import {Fees, Bid, PayloadBatch} from "../utils/common/Structs.sol";
import {AuctionClosed, AuctionAlreadyStarted, BidExceedsMaxFees, LowerBidAlreadyExists, InvalidTransmitter} from "../utils/common/Errors.sol";

abstract contract AuctionManagerStorage is IAuctionManager {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    uint32 public evmxSlug;

    // slot 51
    mapping(bytes32 => Bid) public winningBids;

    // slot 52
    // asyncId => auction status
    mapping(bytes32 => bool) public override auctionClosed;

    // slot 53
    mapping(bytes32 => bool) public override auctionStarted;

    // slot 54
    uint256 public auctionEndDelaySeconds;

    // slots [55-104] reserved for gap
    uint256[50] _gap_after;

    // slots 105-155 reserved for addr resolver util
}

/// @title AuctionManager
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is AuctionManagerStorage, Initializable, Ownable, AddressResolverUtil {
    event AuctionRestarted(bytes32 asyncId);
    event AuctionStarted(bytes32 asyncId);
    event AuctionEnded(bytes32 asyncId, Bid winningBid);
    event BidPlaced(bytes32 asyncId, Bid bid);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param evmxSlug_ The chain slug for the VM
    /// @param auctionEndDelaySeconds_ The delay in seconds before an auction can end
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the contract owner
    function initialize(
        uint32 evmxSlug_,
        uint256 auctionEndDelaySeconds_,
        address addressResolver_,
        address owner_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
        evmxSlug = evmxSlug_;
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
    }

    function setAuctionEndDelaySeconds(uint256 auctionEndDelaySeconds_) external onlyOwner {
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
    }

    function startAuction(bytes32 asyncId_) internal {
        if (auctionClosed[asyncId_]) revert AuctionClosed();
        if (auctionStarted[asyncId_]) revert AuctionAlreadyStarted();

        auctionStarted[asyncId_] = true;
        emit AuctionStarted(asyncId_);
    }

    /// @notice Places a bid for an auction
    /// @param asyncId_ The ID of the auction
    /// @param fee The bid amount
    /// @param transmitterSignature The signature of the transmitter
    function bid(
        bytes32 asyncId_,
        uint256 fee,
        bytes memory transmitterSignature,
        bytes memory extraData
    ) external {
        if (auctionClosed[asyncId_]) revert AuctionClosed();

        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(this), evmxSlug, asyncId_, fee, extraData)),
            transmitterSignature
        );

        Bid memory newBid = Bid({fee: fee, transmitter: transmitter, extraData: extraData});

        PayloadBatch memory payloadBatch = IDeliveryHelper(addressResolver__.deliveryHelper())
            .payloadBatches(asyncId_);
        if (fee > payloadBatch.fees.amount) revert BidExceedsMaxFees();

        if (winningBids[asyncId_].transmitter != address(0) && fee >= winningBids[asyncId_].fee)
            revert LowerBidAlreadyExists();

        winningBids[asyncId_] = newBid;

        IFeesManager(addressResolver__.feesManager()).blockFees(
            payloadBatch.appGateway,
            payloadBatch.fees,
            newBid,
            asyncId_
        );

        if (auctionEndDelaySeconds > 0) {
            startAuction(asyncId_);
            watcherPrecompile__().setTimeout(
                payloadBatch.appGateway,
                abi.encodeWithSelector(this.endAuction.selector, asyncId_),
                auctionEndDelaySeconds
            );
        } else {
            _endAuction(asyncId_);
        }

        emit BidPlaced(asyncId_, newBid);
        auctionClosed[asyncId_] = true;
    }

    /// @notice Ends an auction
    /// @param asyncId_ The ID of the auction
    function endAuction(bytes32 asyncId_) external onlyWatcherPrecompile {
        _endAuction(asyncId_);
    }

    function _endAuction(bytes32 asyncId_) internal {
        auctionClosed[asyncId_] = true;
        Bid memory winningBid = winningBids[asyncId_];
        if (winningBid.transmitter == address(0)) revert InvalidTransmitter();

        emit AuctionEnded(asyncId_, winningBid);

        PayloadBatch memory payloadBatch = IDeliveryHelper(addressResolver__.deliveryHelper())
            .payloadBatches(asyncId_);

        watcherPrecompile__().setTimeout(
            payloadBatch.appGateway,
            abi.encodeWithSelector(this.expireBid.selector, asyncId_),
            IDeliveryHelper(addressResolver__.deliveryHelper()).bidTimeout()
        );

        IDeliveryHelper(addressResolver__.deliveryHelper()).startBatchProcessing(
            asyncId_,
            winningBid
        );
    }

    function expireBid(bytes32 asyncId_) external onlyWatcherPrecompile {
        PayloadBatch memory batch = IDeliveryHelper(addressResolver__.deliveryHelper())
            .payloadBatches(asyncId_);

        // if executed, bid is not expired
        if (batch.totalPayloadsRemaining == 0 || batch.isBatchCancelled) return;

        IFeesManager(addressResolver__.feesManager()).unblockFees(asyncId_, batch.appGateway);
        winningBids[asyncId_] = Bid({fee: 0, transmitter: address(0), extraData: ""});
        auctionClosed[asyncId_] = false;

        emit AuctionRestarted(asyncId_);
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
