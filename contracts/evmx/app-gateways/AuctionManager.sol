// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "solady/utils/Initializable.sol";
import "../interfaces/IAuctionManager.sol";
import "../../utils/AccessControl.sol";
import {AuctionClosed, AuctionAlreadyStarted, BidExceedsMaxFees, LowerBidAlreadyExists, InvalidTransmitter} from "../../utils/common/Errors.sol";
import {TRANSMITTER_ROLE} from "../../utils/common/AccessRoles.sol";
import {AppGatewayBase} from "../base/AppGatewayBase.sol";

/// @title AuctionManagerStorage
/// @notice Storage for the AuctionManager contract
abstract contract AuctionManagerStorage is IAuctionManager {
    // slot 50
    uint32 public evmxSlug;

    // slot 50
    /// @notice The timeout after which a bid expires
    uint128 public bidTimeout;

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
}

/// @title AuctionManager
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is AuctionManagerStorage, Initializable, AccessControl, AppGatewayBase {
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
    /// @param auctionEndDelaySeconds_ The delay in seconds before an auction can end
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the contract owner
    /// @param maxReAuctionCount_ The maximum number of re-auctions allowed
    function initialize(
        uint32 evmxSlug_,
        uint256 auctionEndDelaySeconds_,
        uint256 bidTimeout_,
        uint256 maxReAuctionCount_,
        address addressResolver_,
        address owner_
    ) public reinitializer(1) {
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);

        evmxSlug = evmxSlug_;
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
        bidTimeout = bidTimeout_;
        maxReAuctionCount = maxReAuctionCount_;
    }

    function setAuctionEndDelaySeconds(uint256 auctionEndDelaySeconds_) external onlyOwner {
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
        emit AuctionEndDelaySecondsSet(auctionEndDelaySeconds_);
    }

    function setMaxReAuctionCount(uint256 maxReAuctionCount_) external onlyOwner {
        maxReAuctionCount = maxReAuctionCount_;
        emit MaxReAuctionCountSet(maxReAuctionCount_);
    }

    /// @notice Places a bid for an auction
    /// @param requestCount_ The ID of the auction
    /// @param bidFees The bid amount
    /// @param transmitterSignature The signature of the transmitter
    function bid(
        uint40 requestCount_,
        uint256 bidFees,
        address scheduleFees_,
        bytes memory transmitterSignature,
        bytes memory extraData
    ) external {
        if (auctionClosed[requestCount_]) revert AuctionClosed();

        // check if the transmitter is valid
        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(this), evmxSlug, requestCount_, bidFees, extraData)),
            transmitterSignature
        );
        if (!_hasRole(TRANSMITTER_ROLE, transmitter)) revert InvalidTransmitter();

        // check if the bid is lower than the existing bid
        if (
            winningBids[requestCount_].transmitter != address(0) &&
            bidFees >= winningBids[requestCount_].fee
        ) revert LowerBidAlreadyExists();

        uint256 transmitterCredits = quotedTransmitterFees(requestCount_);
        if (bidFees > transmitterCredits) revert BidExceedsMaxFees();

        // create a new bid
        Bid memory newBid = Bid({fee: bidFees, transmitter: transmitter, extraData: extraData});
        winningBids[requestCount_] = newBid;

        // end the auction if the no auction end delay
        if (auctionEndDelaySeconds > 0) {
            _startAuction(requestCount_);
            _createRequest(
                auctionEndDelaySeconds,
                scheduleFees_,
                transmitter,
                abi.encodeWithSelector(this.endAuction.selector, requestCount_, scheduleFees_)
            );
        } else {
            _endAuction(requestCount_, scheduleFees_);
        }

        emit BidPlaced(requestCount_, newBid);
    }

    function _startAuction(uint40 requestCount_) internal {
        if (auctionClosed[requestCount_]) revert AuctionClosed();
        if (auctionStarted[requestCount_]) revert AuctionAlreadyStarted();

        auctionStarted[requestCount_] = true;
        emit AuctionStarted(requestCount_);
    }

    /// @notice Ends an auction
    /// @param requestCount_ The ID of the auction
    function endAuction(
        uint40 requestCount_,
        uint256 scheduleFees_
    ) external onlyWatcherPrecompile {
        if (auctionClosed[requestCount_]) return;
        _endAuction(requestCount_, scheduleFees_);
    }

    function _endAuction(uint40 requestCount_, uint256 scheduleFees_) internal {
        // get the winning bid, if no transmitter is set, revert
        Bid memory winningBid = winningBids[requestCount_];
        if (winningBid.transmitter == address(0)) revert InvalidTransmitter();

        auctionClosed[requestCount_] = true;
        RequestParams memory requestParams = _getRequestParams(requestCount_);

        // todo: block fees in watcher in startRequestProcessing
        // feesManager__().blockCredits(
        //     requestMetadata.consumeFrom,
        //     winningBid.fee,
        //     requestCount_
        // );

        // set the timeout for the bid expiration
        // useful in case a transmitter did bid but did not execute payloads
        _createRequest(
            bidTimeout,
            scheduleFees_,
            winningBid.transmitter,
            abi.encodeWithSelector(this.expireBid.selector, requestCount_)
        );

        // todo: merge them and create a single function call
        // start the request processing, it will queue the request
        if (requestParams.requestFeesDetails.bid.transmitter != address(0)) {
            IWatcher(watcherPrecompile__()).updateTransmitter(requestCount_, winningBid);
        } else {
            IWatcher(watcherPrecompile__()).startRequestProcessing(requestCount_, winningBid);
        }

        emit AuctionEnded(requestCount_, winningBid);
    }

    /// @notice Expires a bid and restarts an auction in case a request is not fully executed.
    /// @dev Auction can be restarted only for `maxReAuctionCount` times.
    /// @dev It also unblocks the fees from last transmitter to be assigned to the new winner.
    /// @param requestCount_ The request id
    function expireBid(uint40 requestCount_) external onlyWatcherPrecompile {
        if (reAuctionCount[requestCount_] >= maxReAuctionCount) revert MaxReAuctionCountReached();
        RequestParams memory requestParams = _getRequestParams(requestCount_);

        // if executed, bid is not expired
        if (
            requestParams.requestTrackingParams.payloadsRemaining == 0 ||
            requestParams.requestTrackingParams.isRequestCancelled
        ) return;

        delete winningBids[requestCount_];
        auctionClosed[requestCount_] = false;
        reAuctionCount[requestCount_]++;

        // todo: unblock credits by calling watcher for updating transmitter to addr(0)
        // feesManager__().unblockCredits(requestCount_);

        emit AuctionRestarted(requestCount_);
    }

    function _createRequest(
        uint256 delayInSeconds_,
        uint256 maxFees_,
        address consumeFrom_,
        bytes memory payload_
    ) internal {
        QueueParams memory queueParams = QueueParams({
            overrideParams: OverrideParams({
                isPlug: IsPlug.NO,
                callType: CallType.WRITE,
                isParallelCall: Parallel.OFF,
                gasLimit: 0,
                value: 0,
                readAtBlockNumber: 0,
                writeFinality: WriteFinality.LOW,
                delayInSeconds: delayInSeconds_
            }),
            transaction: Transaction({
                chainSlug: evmxSlug,
                target: address(this),
                payload: payload_
            }),
            asyncPromise: address(0),
            switchboardType: sbType
        });

        // queue and create request
        watcherPrecompile__().queueAndRequest(
            queueParams,
            maxFees_,
            address(this),
            consumeFrom_,
            bytes("")
        );
    }

    /// @notice Returns the quoted transmitter fees for a request
    /// @dev returns the max fees quoted by app gateway subtracting the watcher fees
    /// @param requestCount_ The request id
    /// @return The quoted transmitter fees
    function quotedTransmitterFees(uint40 requestCount_) public view returns (uint256) {
        RequestParams memory requestParams = _getRequestParams(requestCount_);
        // check if the bid is for this auction manager
        if (requestParams.auctionManager != address(this)) revert InvalidBid();
        // get the total fees required for the watcher precompile ops
        return
            requestParams.requestFeesDetails.maxFees - requestParams.requestFeesDetails.watcherFees;
    }

    function _getRequestParams(uint40 requestCount_) internal view returns (RequestParams memory) {
        return watcherPrecompile__().getRequestParams(requestCount_);
    }

    /// @notice Recovers the signer of a message
    /// @param digest_ The digest of the message
    /// @param signature_ The signature of the message
    /// @return The signer of the message
    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }
}
