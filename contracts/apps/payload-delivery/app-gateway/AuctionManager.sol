// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "../../../utils/Ownable.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {Bid, FeesData} from "../../../common/Structs.sol";
import {IAuctionContract} from "../../../interfaces/IAuctionContract.sol";
import {IAuctionHouse} from "../../../interfaces/IAuctionHouse.sol";

/// @title AuctionHouse
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is AddressResolverUtil, Ownable(msg.sender) {
    SignatureVerifier public immutable signatureVerifier__;
    mapping(bytes32 => Bid) public winningBids;
    // asyncId => auction status
    mapping(bytes32 => bool) public auctionClosed;
    mapping(bytes32 => bool) public auctionStarted;

    /// @notice Constructor for AuctionHouse
    /// @param addressResolver_ The address of the address resolver
    /// @param signatureVerifier_ The address of the signature verifier
    constructor(
        address addressResolver_,
        SignatureVerifier signatureVerifier_
    ) AddressResolverUtil(addressResolver_) {
        signatureVerifier__ = signatureVerifier_;
    }

    event AuctionStarted(bytes32 asyncId_);
    event AuctionEnded(bytes32 asyncId_, Bid winningBid);
    event BidPlaced(bytes32 asyncId_, Bid bid);

    function startAuction(bytes32 asyncId_) external {
        require(!auctionClosed[asyncId_], "Auction closed");
        require(!auctionStarted[asyncId_], "Auction already started");

        auctionStarted[asyncId_] = true;
        emit AuctionStarted(asyncId_);
        uint256 auctionEndDelaySeconds = IAuctionContract(address(this))
            .auctionEndDelaySeconds();
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
            keccak256(abi.encode(address(this), asyncId_, fee)),
            transmitterSignature
        );

        Bid memory newBid = Bid({
            fee: fee,
            transmitter: transmitter,
            extraData: extraData
        });
        (address auctionContract, FeesData memory feesData) = AuctionHouse()
            .getAuctionContractAndFeesData(asyncId_);
        require(fee <= feesData.maxFees, "Bid exceeds max fees");
        require(
            IAuctionContract(auctionContract).isNewBidBetter(
                winningBids[asyncId_],
                newBid
            ),
            "Bid is not better"
        );
        winningBids[asyncId_] = newBid;
        emit BidPlaced(asyncId_, newBid);
    }

    /// @notice Ends an auction
    /// @param asyncId_ The ID of the auction
    function endAuction(bytes32 asyncId_) external onlyWatcherPrecompile {
        auctionClosed[asyncId_] = true;
        Bid memory winningBid = winningBids[asyncId_];
        emit AuctionEnded(asyncId_, winningBid);

        AuctionHouse().startBatchProcessing(asyncId_);
    }

    function AuctionHouse()
        internal
        view
        returns (IAuctionHouse auctionHouse_)
    {
        return IAuctionHouse(addressResolver.auctionHouse());
    }
}
