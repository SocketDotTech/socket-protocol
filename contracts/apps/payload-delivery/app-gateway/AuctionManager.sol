// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "../../../utils/Ownable.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {FeesData} from "../../../common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import "../../../interfaces/IAuctionManager.sol";

/// @title DeliveryHelper
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is
    AddressResolverUtil,
    Ownable(msg.sender),
    IAuctionManager
{
    SignatureVerifier public immutable signatureVerifier__;
    uint32 public immutable vmChainSlug;
    mapping(bytes32 => Bid) public winningBids;
    // asyncId => auction status
    mapping(bytes32 => bool) public override auctionClosed;
    mapping(bytes32 => bool) public override auctionStarted;

    uint256 public constant auctionEndDelaySeconds = 0;

    /// @notice Constructor for DeliveryHelper
    /// @param addressResolver_ The address of the address resolver
    /// @param signatureVerifier_ The address of the signature verifier
    constructor(
        uint32 vmChainSlug_,
        address addressResolver_,
        SignatureVerifier signatureVerifier_
    ) AddressResolverUtil(addressResolver_) {
        vmChainSlug = vmChainSlug_;
        signatureVerifier__ = signatureVerifier_;
    }

    event AuctionStarted(bytes32 asyncId_);
    event AuctionEnded(bytes32 asyncId_, Bid winningBid);
    event BidPlaced(bytes32 asyncId, Bid bid);

    function startAuction(bytes32 asyncId_) external onlyPayloadDelivery {
        require(!auctionClosed[asyncId_], "Auction closed");
        require(!auctionStarted[asyncId_], "Auction already started");

        auctionStarted[asyncId_] = true;
        emit AuctionStarted(asyncId_);

        watcherPrecompile().setTimeout(
            abi.encodeWithSelector(this.endAuction.selector, asyncId_),
            auctionEndDelaySeconds
        );
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
        require(!auctionClosed[asyncId_], "Auction closed");

        address transmitter = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(address(this), vmChainSlug, asyncId_, fee, extraData)
            ),
            transmitterSignature
        );

        Bid memory newBid = Bid({
            fee: fee,
            transmitter: transmitter,
            extraData: extraData
        });

        FeesData memory feesData = IDeliveryHelper(
            addressResolver.deliveryHelper()
        ).getFeesData(asyncId_);
        require(fee <= feesData.maxFees, "Bid exceeds max fees");
        if (fee < winningBids[asyncId_].fee) return;

        winningBids[asyncId_] = newBid;
        emit BidPlaced(asyncId_, newBid);
    }

    /// @notice Ends an auction
    /// @param asyncId_ The ID of the auction
    function endAuction(bytes32 asyncId_) external onlyWatcherPrecompile {
        auctionClosed[asyncId_] = true;
        Bid memory winningBid = winningBids[asyncId_];
        emit AuctionEnded(asyncId_, winningBid);

        IDeliveryHelper(addressResolver.deliveryHelper()).startBatchProcessing(
            asyncId_
        );
    }
}
