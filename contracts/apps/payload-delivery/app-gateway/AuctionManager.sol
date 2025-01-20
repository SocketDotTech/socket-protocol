// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "../../../utils/Ownable.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {FeesData} from "../../../common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import "../../../interfaces/IAuctionManager.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @title AuctionManager
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is AddressResolverUtil, Ownable, IAuctionManager, Initializable {
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

    function startAuction(bytes32 asyncId_) external onlyDeliveryHelper returns (uint256) {
        if (auctionClosed[asyncId_]) revert AuctionClosed();
        if (auctionStarted[asyncId_]) revert AuctionAlreadyStarted();

        auctionStarted[asyncId_] = true;
        emit AuctionStarted(asyncId_);

        return auctionEndDelaySeconds;
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

        FeesData memory feesData = IDeliveryHelper(addressResolver.deliveryHelper()).getFeesData(
            asyncId_
        );
        if (fee > feesData.maxFees) revert BidExceedsMaxFees();
        if (fee < winningBids[asyncId_].fee) return;

        winningBids[asyncId_] = newBid;
        emit BidPlaced(asyncId_, newBid);
    }

    /// @notice Ends an auction
    /// @param asyncId_ The ID of the auction
    function endAuction(bytes32 asyncId_) external onlyDeliveryHelper {
        auctionClosed[asyncId_] = true;
        Bid memory winningBid = winningBids[asyncId_];
        if (winningBid.transmitter == address(0)) revert InvalidTransmitter();

        emit AuctionEnded(asyncId_, winningBid);
        IDeliveryHelper(addressResolver.deliveryHelper()).startBatchProcessing(
            asyncId_,
            winningBid
        );
    }
}
