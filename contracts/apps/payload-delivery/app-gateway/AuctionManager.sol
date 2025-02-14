// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableTwoStep} from "../../../utils/OwnableTwoStep.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {Fees, Bid, PayloadBatch} from "../../../common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";
import "../../../interfaces/IAuctionManager.sol";
import "solady/utils/Initializable.sol";

/// @title AuctionManager
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is AddressResolverUtil, OwnableTwoStep, IAuctionManager, Initializable {
    SignatureVerifier public signatureVerifier;
    uint32 public vmChainSlug;
    mapping(bytes32 => Bid) public winningBids;
    // asyncId => auction status
    mapping(bytes32 => bool) public override auctionClosed;
    mapping(bytes32 => bool) public override auctionStarted;

    uint256 public auctionEndDelaySeconds;

    /// @notice Error thrown when trying to start or bid a closed auction
    error AuctionClosed();
    /// @notice Error thrown when trying to start an ongoing auction
    error AuctionAlreadyStarted();
    /// @notice Error thrown if fees exceed the maximum set fees
    error BidExceedsMaxFees();
    /// @notice Error thrown if winning bid is assigned to an invalid transmitter
    error InvalidTransmitter();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param vmChainSlug_ The chain slug for the VM
    /// @param auctionEndDelaySeconds_ The delay in seconds before an auction can end
    /// @param addressResolver_ The address of the address resolver
    /// @param signatureVerifier_ The address of the signature verifier
    /// @param owner_ The address of the contract owner
    function initialize(
        uint32 vmChainSlug_,
        uint256 auctionEndDelaySeconds_,
        address addressResolver_,
        SignatureVerifier signatureVerifier_,
        address owner_
    ) public initializer {
        _setAddressResolver(addressResolver_);
        _claimOwner(owner_);
        vmChainSlug = vmChainSlug_;
        signatureVerifier = signatureVerifier_;
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
    }

    event AuctionStarted(bytes32 asyncId);
    event AuctionEnded(bytes32 asyncId, Bid winningBid);
    event BidPlaced(bytes32 asyncId, Bid bid);

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

        address transmitter = signatureVerifier.recoverSigner(
            keccak256(abi.encode(address(this), vmChainSlug, asyncId_, fee, extraData)),
            transmitterSignature
        );

        Bid memory newBid = Bid({fee: fee, transmitter: transmitter, extraData: extraData});

        PayloadBatch memory payloadBatch = IDeliveryHelper(addressResolver__.deliveryHelper())
            .payloadBatches(asyncId_);
        if (fee > payloadBatch.fees.amount) revert BidExceedsMaxFees();
        if (fee < winningBids[asyncId_].fee) return;

        winningBids[asyncId_] = newBid;
        IFeesManager(addressResolver__.feesManager()).blockFees(
            payloadBatch.appGateway,
            payloadBatch.fees,
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

        emit AuctionEnded(asyncId_, newBid);
    }

    /// @notice Ends an auction
    /// @param asyncId_ The ID of the auction
    function endAuction(bytes32 asyncId_) external onlyDeliveryHelper {
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

        // todo: add scheduler for a time to retry auction
    }

    function expireBid(bytes32 asyncId_) external onlyWatcherPrecompile {
        PayloadBatch memory batch = IDeliveryHelper(addressResolver__.deliveryHelper())
            .payloadBatches(asyncId_);
        // if executed, bid is not expired
        // todo: should be less than total payloads in batch or zero?
        if (batch.totalPayloadsRemaining == 0) return;

        IFeesManager(addressResolver__.feesManager()).unblockFees(asyncId_, batch.appGateway);
        winningBids[asyncId_] = Bid({fee: 0, transmitter: address(0), extraData: ""});
        auctionClosed[asyncId_] = false;
    }
}
