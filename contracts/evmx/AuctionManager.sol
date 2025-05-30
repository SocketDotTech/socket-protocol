// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ECDSA} from "solady/utils/ECDSA.sol";
import "solady/utils/Initializable.sol";
import "./interfaces/IPromise.sol";
import "./interfaces/IAuctionManager.sol";

import "../utils/AccessControl.sol";
import "../utils/RescueFundsLib.sol";
import {AuctionNotOpen, AuctionClosed, BidExceedsMaxFees, LowerBidAlreadyExists, InvalidTransmitter, MaxReAuctionCountReached, InvalidBid} from "../utils/common/Errors.sol";
import {SCHEDULE} from "../utils/common/Constants.sol";

import {TRANSMITTER_ROLE, RESCUE_ROLE} from "../utils/common/AccessRoles.sol";
import {AppGatewayBase} from "./base/AppGatewayBase.sol";

/// @title AuctionManagerStorage
/// @notice Storage for the AuctionManager contract
abstract contract AuctionManagerStorage is IAuctionManager {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50 (32 + 128)
    /// @notice The evmx chain slug
    uint32 public evmxSlug;

    /// @notice The time after which a bid expires
    uint128 public bidTimeout;

    // slot 51
    uint256 public maxReAuctionCount;

    // slot 52
    uint256 public auctionEndDelaySeconds;

    // slot 53
    /// @notice The winning bid for a request (requestCount => Bid)
    mapping(uint40 => Bid) public winningBids;

    // slot 54
    /// @notice The auction status for a request (requestCount => AuctionStatus)
    mapping(uint40 => AuctionStatus) public override auctionStatus;

    // slot 55
    mapping(uint40 => uint256) public reAuctionCount;

    // slots [56-105] reserved for gap
    uint256[50] _gap_after;

    // slots [106-164] 59 slots reserved for app gateway base
    // slots [165-214] 50 slots reserved for access control
}

/// @title AuctionManager
/// @notice Contract for managing auctions and placing bids
contract AuctionManager is AuctionManagerStorage, Initializable, AppGatewayBase, AccessControl {
    event AuctionRestarted(uint40 requestCount);
    event AuctionStarted(uint40 requestCount);
    event AuctionEnded(uint40 requestCount, Bid winningBid);
    event BidPlaced(uint40 requestCount, Bid bid);
    event AuctionEndDelaySecondsSet(uint256 auctionEndDelaySeconds);
    event MaxReAuctionCountSet(uint256 maxReAuctionCount);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @param evmxSlug_ The evmx chain slug
    /// @param bidTimeout_ The timeout after which a bid expires
    /// @param maxReAuctionCount_ The maximum number of re-auctions allowed
    /// @param auctionEndDelaySeconds_ The delay in seconds before an auction can end
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the contract owner

    function initialize(
        uint32 evmxSlug_,
        uint128 bidTimeout_,
        uint256 maxReAuctionCount_,
        uint256 auctionEndDelaySeconds_,
        address addressResolver_,
        address owner_
    ) external reinitializer(1) {
        evmxSlug = evmxSlug_;
        bidTimeout = bidTimeout_;
        maxReAuctionCount = maxReAuctionCount_;
        auctionEndDelaySeconds = auctionEndDelaySeconds_;

        _initializeOwner(owner_);
        _initializeAppGateway(addressResolver_);
    }

    function setAuctionEndDelaySeconds(uint256 auctionEndDelaySeconds_) external onlyWatcher {
        auctionEndDelaySeconds = auctionEndDelaySeconds_;
        emit AuctionEndDelaySecondsSet(auctionEndDelaySeconds_);
    }

    function setMaxReAuctionCount(uint256 maxReAuctionCount_) external onlyWatcher {
        maxReAuctionCount = maxReAuctionCount_;
        emit MaxReAuctionCountSet(maxReAuctionCount_);
    }

    /// @notice Places a bid for an auction
    /// @dev transmitters should approve credits to the auction manager contract for scheduling requests
    /// @param requestCount_ The ID of the auction
    /// @param bidFees The bid amount
    /// @param transmitterSignature The signature of the transmitter
    function bid(
        uint40 requestCount_,
        uint256 bidFees,
        bytes memory transmitterSignature,
        bytes memory extraData
    ) external override {
        if (auctionEndDelaySeconds == 0) {
            // todo: temp fix, can be called for random request
            if (
                auctionStatus[requestCount_] != AuctionStatus.NOT_STARTED &&
                auctionStatus[requestCount_] != AuctionStatus.RESTARTED
            ) revert AuctionNotOpen();
        } else if (
            auctionStatus[requestCount_] != AuctionStatus.OPEN &&
            auctionStatus[requestCount_] != AuctionStatus.RESTARTED
        ) revert AuctionNotOpen();

        // check if the transmitter is valid
        address transmitter = _recoverSigner(
            keccak256(abi.encode(address(this), evmxSlug, requestCount_, bidFees, extraData)),
            transmitterSignature
        );
        if (!_hasRole(TRANSMITTER_ROLE, transmitter)) revert InvalidTransmitter();

        // check if the bid is lower than the existing bid
        if (bidFees > 0 && winningBids[requestCount_].fee >= bidFees)
            revert LowerBidAlreadyExists();

        uint256 transmitterCredits = getMaxFees(requestCount_);
        if (bidFees > transmitterCredits) revert BidExceedsMaxFees();

        // create a new bid
        Bid memory newBid = Bid({fee: bidFees, transmitter: transmitter, extraData: extraData});
        address oldTransmitter = winningBids[requestCount_].transmitter;
        winningBids[requestCount_] = newBid;

        // end the auction if the no auction end delay
        if (auctionEndDelaySeconds > 0 && auctionStatus[requestCount_] != AuctionStatus.OPEN) {
            _startAuction(requestCount_);
            _createRequest(
                auctionEndDelaySeconds,
                deductScheduleFees(
                    transmitter,
                    oldTransmitter == address(0) ? address(this) : newBid.transmitter,
                    auctionEndDelaySeconds
                ),
                address(this),
                this.endAuction.selector,
                abi.encode(requestCount_)
            );
        } else {
            _endAuction(requestCount_);
        }

        emit BidPlaced(requestCount_, newBid);
    }

    function _startAuction(uint40 requestCount_) internal {
        if (auctionStatus[requestCount_] != AuctionStatus.OPEN) revert AuctionNotOpen();
        auctionStatus[requestCount_] = AuctionStatus.OPEN;
        emit AuctionStarted(requestCount_);
    }

    /// @notice Ends an auction
    /// @param requestCount_ The ID of the auction
    function endAuction(uint40 requestCount_) external override onlyWatcher {
        if (
            auctionStatus[requestCount_] == AuctionStatus.CLOSED ||
            auctionStatus[requestCount_] == AuctionStatus.NOT_STARTED
        ) return;
        _endAuction(requestCount_);
    }

    function _endAuction(uint40 requestCount_) internal {
        // get the winning bid, if no transmitter is set, revert
        Bid memory winningBid = winningBids[requestCount_];
        auctionStatus[requestCount_] = AuctionStatus.CLOSED;

        if (winningBid.transmitter != address(0)) {
            // todo: might block the request processing if transmitter don't have enough balance for this schedule
            // this case can hit when bid timeout is more than 0

            // set the bid expiration time
            // useful in case a transmitter did bid but did not execute payloads
            _createRequest(
                bidTimeout,
                deductScheduleFees(winningBid.transmitter, address(this), bidTimeout),
                winningBid.transmitter,
                this.expireBid.selector,
                abi.encode(requestCount_)
            );

            // start the request processing, it will queue the request
            watcher__().requestHandler__().assignTransmitter(requestCount_, winningBid);
        }

        emit AuctionEnded(requestCount_, winningBid);
    }

    /// @notice Expires a bid and restarts an auction in case a request is not fully executed.
    /// @dev Auction can be restarted only for `maxReAuctionCount` times.
    /// @dev It also unblocks the fees from last transmitter to be assigned to the new winner.
    /// @param requestCount_ The request id
    function expireBid(uint40 requestCount_) external override onlyWatcher {
        if (reAuctionCount[requestCount_] >= maxReAuctionCount) revert MaxReAuctionCountReached();
        RequestParams memory requestParams = _getRequestParams(requestCount_);

        // if executed or cancelled, bid is not expired
        if (
            requestParams.requestTrackingParams.payloadsRemaining == 0 ||
            requestParams.requestTrackingParams.isRequestCancelled
        ) return;

        delete winningBids[requestCount_];
        auctionStatus[requestCount_] = AuctionStatus.RESTARTED;
        reAuctionCount[requestCount_]++;

        watcher__().requestHandler__().assignTransmitter(
            requestCount_,
            Bid({fee: 0, transmitter: address(0), extraData: ""})
        );
        emit AuctionRestarted(requestCount_);
    }

    function _createRequest(
        uint256 delayInSeconds_,
        uint256 maxFees_,
        address consumeFrom_,
        bytes4 callbackSelector_,
        bytes memory callbackData_
    ) internal {
        OverrideParams memory overrideParams;
        overrideParams.callType = SCHEDULE;
        overrideParams.delayInSeconds = delayInSeconds_;

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;

        // queue and create request
        watcher__().queue(queueParams, address(this));
        then(callbackSelector_, callbackData_);
        watcher__().submitRequest(maxFees_, address(this), consumeFrom_, bytes(""));
    }

    /// @notice Returns the quoted transmitter fees for a request
    /// @dev returns the max fees quoted by app gateway subtracting the watcher fees
    /// @param requestCount_ The request id
    /// @return The quoted transmitter fees
    function getMaxFees(uint40 requestCount_) internal view returns (uint256) {
        RequestParams memory requestParams = _getRequestParams(requestCount_);
        // check if the bid is for this auction manager
        if (requestParams.auctionManager != address(this)) revert InvalidBid();
        // get the total fees required for the watcher precompile ops
        return requestParams.requestFeesDetails.maxFees;
    }

    function deductScheduleFees(
        address from_,
        address to_,
        uint256 delayInSeconds_
    ) internal returns (uint256 watcherFees) {
        watcherFees = watcher__().getPrecompileFees(SCHEDULE, abi.encode(delayInSeconds_));
        feesManager__().transferCredits(from_, to_, watcherFees);
    }

    function _getRequestParams(uint40 requestCount_) internal view returns (RequestParams memory) {
        return watcher__().getRequestParams(requestCount_);
    }

    /// @notice Recovers the signer of a message
    /// @param digest_ The digest of the message
    /// @param signature_ The signature of the message
    /// @return signer The signer of the message
    function _recoverSigner(
        bytes32 digest_,
        bytes memory signature_
    ) internal view returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_));
        // recovered signer is checked for the valid roles later
        signer = ECDSA.recover(digest, signature_);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
