// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import "solady/utils/ECDSA.sol";
import "../interfaces/IFeesManager.sol";
import {AddressResolverUtil} from "../AddressResolverUtil.sol";
import {NotAuctionManager, InvalidWatcherSignature, NonceUsed} from "../../utils/common/Errors.sol";
import {Bid, CallType, Parallel, WriteFinality, QueuePayloadParams, IsPlug, PayloadSubmitParams, RequestMetadata, UserCredits} from "../../utils/common/Structs.sol";

abstract contract FeesManagerStorage is IFeesManager {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    //===== user =====
    // user credits => stores fees for user, app gateway, transmitters and watcher precompile
    mapping(address => UserCredits) public userFees;
    // user approved app gateways
    // userAddress => appGateway => isWhitelisted
    mapping(address => mapping(address => bool)) public isAppGatewayWhitelisted;

    // token pool balances
    //  chainSlug => token address  => amount
    mapping(uint32 => mapping(address => uint256)) public tokenPoolBalances;

    // slot 54
    /// @notice Mapping to track request credits details for each request count
    /// @dev requestCount => RequestFee
    mapping(uint40 => uint256) public requestCountCredits;

    // slot 56
    /// @notice Mapping to track nonce to whether it has been used
    /// @dev address => signatureNonce => isNonceUsed
    /// @dev used by watchers or other users in signatures
    mapping(address => mapping(uint256 => bool)) public isNonceUsed;

    uint256 public withdrawCounter;

    // slots [57-106] reserved for gap
    uint256[50] _gap_after;

    // slots 107-157 (51) reserved for addr resolver util
}

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is FeesManagerStorage, Initializable, Ownable, AddressResolverUtil {
    /// @notice Emitted when fees are blocked for a batch
    /// @param requestCount The batch identifier
    /// @param consumeFrom The consume from address
    /// @param amount The blocked amount
    event CreditsBlocked(uint40 indexed requestCount, address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when transmitter fees are updated
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The new amount deposited
    event TransmitterCreditsUpdated(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );
    event WatcherPrecompileCreditsAssigned(uint256 amount, address consumeFrom);
    /// @notice Emitted when fees deposited are updated
    /// @param chainSlug The chain identifier
    /// @param appGateway The app gateway address
    /// @param token The token address
    /// @param amount The new amount deposited
    event CreditsDeposited(
        uint32 indexed chainSlug,
        address indexed appGateway,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked and assigned to a transmitter
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The unblocked amount
    event CreditsUnblockedAndAssigned(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked
    /// @param requestCount The batch identifier
    /// @param appGateway The app gateway address
    event CreditsUnblocked(uint40 indexed requestCount, address indexed appGateway);

    /// @notice Emitted when insufficient watcher precompile fees are available
    event InsufficientWatcherPrecompileCreditsAvailable(
        uint32 chainSlug,
        address token,
        address consumeFrom
    );

    /// @notice Emitted when credits are wrapped
    event CreditsWrapped(address indexed consumeFrom, uint256 amount);

    /// @notice Emitted when credits are unwrapped
    event CreditsUnwrapped(address indexed consumeFrom, uint256 amount);

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the owner
    /// @param evmxSlug_ The evmx chain slug
    function initialize(
        address addressResolver_,
        address owner_,
        uint32 evmxSlug_,
        bytes32 sbType_
    ) public reinitializer(1) {
        evmxSlug = evmxSlug_;
        sbType = sbType_;
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
    }

    /// @notice Returns available (unblocked) fees for a gateway
    /// @param consumeFrom_ The app gateway address
    /// @return The available fee amount
    function getAvailableCredits(address consumeFrom_) public view returns (uint256) {
        UserCredits memory userCredit = userCredits[consumeFrom_];
        if (userCredit.totalCredits == 0 || userCredit.totalCredits <= userCredit.blockedCredits)
            return 0;
        return userCredit.totalCredits - userCredit.blockedCredits;
    }

    /// @notice Adds the fees deposited for an app gateway on a chain
    /// @param depositTo_ The app gateway address
    // @dev only callable by watcher precompile
    // @dev will need tokenAmount_ and creditAmount_ when introduce tokens except stables
    function depositCredits(
        address depositTo_,
        uint32 chainSlug_,
        address token_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external payable {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        uint256 amount = msg.value;

        // check signature
        bytes32 digest = keccak256(
            abi.encode(depositTo_, chainSlug_, token_, amount, address(this), evmxSlug)
        );

        if (_recoverSigner(digest, signature_) != owner()) revert InvalidWatcherSignature();

        UserCredits storage userCredit = userCredits[depositTo_];
        userCredit.totalCredits += amount;
        tokenPoolBalances[chainSlug_][token_] += amount;
        emit CreditsDeposited(chainSlug_, depositTo_, token_, amount);
    }

    function wrap() external payable {
        UserCredits storage userCredit = userCredits[msg.sender];
        userCredit.totalCredits += msg.value;
        emit CreditsWrapped(msg.sender, msg.value);
    }

    function unwrap(uint256 amount_) external {
        UserCredits storage userCredit = userCredits[msg.sender];
        if (userCredit.totalCredits < amount_) revert InsufficientCreditsAvailable();
        userCredit.totalCredits -= amount_;

        // todo: if contract balance not enough, take from our pool?
        if (address(this).balance < amount_) revert InsufficientBalance();
        payable(msg.sender).transfer(amount_);
        emit CreditsUnwrapped(msg.sender, amount_);
    }

    function isUserCreditsEnough(
        address consumeFrom_,
        address appGateway_,
        uint256 amount_
    ) external view returns (bool) {
        // If consumeFrom is not appGateway, check if it is whitelisted
        if (consumeFrom_ != appGateway_ && !isAppGatewayWhitelisted[consumeFrom_][appGateway_])
            revert AppGatewayNotWhitelisted();
        return getAvailableCredits(consumeFrom_) >= amount_;
    }

    function _processFeeApprovalData(
        bytes memory feeApprovalData_
    ) internal returns (address, address, bool) {
        (address consumeFrom, address appGateway, bool isApproved, bytes memory signature_) = abi
            .decode(feeApprovalData_, (address, address, bool, bytes));
        if (signature_.length == 0) {
            // If no signature, consumeFrom is appGateway
            return (appGateway, appGateway, isApproved);
        }
        bytes32 digest = keccak256(
            abi.encode(
                address(this),
                evmxSlug,
                consumeFrom,
                appGateway,
                userNonce[consumeFrom],
                isApproved
            )
        );
        if (_recoverSigner(digest, signature_) != consumeFrom) revert InvalidUserSignature();
        isAppGatewayWhitelisted[consumeFrom][appGateway] = isApproved;
        userNonce[consumeFrom]++;

        return (consumeFrom, appGateway, isApproved);
    }

    function whitelistAppGatewayWithSignature(
        bytes memory feeApprovalData_
    ) external returns (address consumeFrom, address appGateway, bool isApproved) {
        return _processFeeApprovalData(feeApprovalData_);
    }

    /// @notice Whitelists multiple app gateways for the caller
    /// @param params_ Array of app gateway addresses to whitelist
    function whitelistAppGateways(AppGatewayWhitelistParams[] calldata params_) external {
        for (uint256 i = 0; i < params_.length; i++) {
            isAppGatewayWhitelisted[msg.sender][params_[i].appGateway] = params_[i].isApproved;
        }
    }

    modifier onlyAuctionManager(uint40 requestCount_) {
        if (msg.sender != deliveryHelper__().getRequestMetadata(requestCount_).auctionManager)
            revert NotAuctionManager();
        _;
    }

    /// @notice Blocks fees for a request count
    /// @param consumeFrom_ The fees payer address
    /// @param transmitterCredits_ The total fees to block
    /// @param requestCount_ The batch identifier
    /// @dev Only callable by delivery helper
    function blockCredits(
        address consumeFrom_,
        uint256 transmitterCredits_,
        uint40 requestCount_
    ) external onlyAuctionManager(requestCount_) {
        // Block fees
        if (getAvailableCredits(consumeFrom_) < transmitterCredits_)
            revert InsufficientCreditsAvailable();

        UserCredits storage userCredit = userCredits[consumeFrom_];
        userCredit.blockedCredits += transmitterCredits_;

        requestCountCredits[requestCount_] = transmitterCredits_;

        emit CreditsBlocked(requestCount_, consumeFrom_, transmitterCredits_);
    }

    /// @notice Unblocks fees after successful execution and assigns them to the transmitter
    /// @param requestCount_ The async ID of the executed batch
    /// @param transmitter_ The address of the transmitter who executed the batch
    function unblockAndAssignCredits(
        uint40 requestCount_,
        address transmitter_
    ) external override onlyDeliveryHelper {
        uint256 blockedCredits = requestCountCredits[requestCount_];
        if (blockedCredits == 0) return;
        RequestMetadata memory requestMetadata = deliveryHelper__().getRequestMetadata(
            requestCount_
        );
        uint256 fees = requestMetadata.winningBid.fee;

        // Unblock fees from deposit
        _useBlockedUserCredits(requestMetadata.consumeFrom, blockedCredits, fees);

        // Assign fees to transmitter
        userCredits[transmitter_].totalCredits += fees;

        // Clean up storage
        delete requestCountCredits[requestCount_];
        emit CreditsUnblockedAndAssigned(requestCount_, transmitter_, fees);
    }

    function _useBlockedUserCredits(
        address consumeFrom_,
        uint256 toConsumeFromBlocked_,
        uint256 toConsumeFromTotal_
    ) internal {
        UserCredits storage userCredit = userCredits[consumeFrom_];
        userCredit.blockedCredits -= toConsumeFromBlocked_;
        userCredit.totalCredits -= toConsumeFromTotal_;
    }

    function _useAvailableUserCredits(address consumeFrom_, uint256 toConsume_) internal {
        UserCredits storage userCredit = userCredits[consumeFrom_];
        if (userCredit.totalCredits < toConsume_) revert InsufficientCreditsAvailable();
        userCredit.totalCredits -= toConsume_;
    }

    function assignWatcherPrecompileCreditsFromRequestCount(
        uint256 amount_,
        uint40 requestCount_
    ) external onlyWatcherPrecompile {
        RequestMetadata memory requestMetadata = deliveryHelper__().getRequestMetadata(
            requestCount_
        );
        _assignWatcherPrecompileCredits(amount_, requestMetadata.consumeFrom);
    }

    function assignWatcherPrecompileCreditsFromAddress(
        uint256 amount_,
        address consumeFrom_
    ) external onlyWatcherPrecompile {
        _assignWatcherPrecompileCredits(amount_, consumeFrom_);
    }

    function _assignWatcherPrecompileCredits(uint256 amount_, address consumeFrom_) internal {
        // deduct the fees from the user
        _useAvailableUserCredits(consumeFrom_, amount_);
        // add the fees to the watcher precompile
        watcherPrecompileCredits += amount_;
        emit WatcherPrecompileCreditsAssigned(amount_, consumeFrom_);
    }

    function unblockCredits(uint40 requestCount_) external {
        RequestMetadata memory requestMetadata = deliveryHelper__().getRequestMetadata(
            requestCount_
        );

        if (
            msg.sender != requestMetadata.auctionManager &&
            msg.sender != address(deliveryHelper__())
        ) revert InvalidCaller();

        uint256 blockedCredits = requestCountCredits[requestCount_];
        if (blockedCredits == 0) return;

        // Unblock fees from deposit
        UserCredits storage userCredit = userCredits[requestMetadata.consumeFrom];
        userCredit.blockedCredits -= blockedCredits;

        delete requestCountCredits[requestCount_];
        emit CreditsUnblocked(requestCount_, requestMetadata.consumeFrom);
    }

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @param originAppGatewayOrUser_ The address of the app gateway
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    function withdrawCredits(
        address originAppGatewayOrUser_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) public {
        if (msg.sender != address(deliveryHelper__())) originAppGatewayOrUser_ = msg.sender;
        address source = _getCoreAppGateway(originAppGatewayOrUser_);

        // Check if amount is available in fees plug
        uint256 availableAmount = getAvailableCredits(source);
        if (availableAmount < amount_) revert InsufficientCreditsAvailable();

        _useAvailableUserCredits(source, amount_);
        tokenPoolBalances[chainSlug_][token_] -= amount_;

        // Add it to the queue and submit request
        _queue(chainSlug_, abi.encodeCall(IFeesPlug.withdrawFees, (token_, receiver_, amount_)));
    }

    /// @notice Withdraws fees to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The token address
    /// @param receiver_ The address of the receiver
    function getWithdrawTransmitterCreditsPayloadParams(
        address transmitter_,
        uint32 chainSlug_,
        address token_,
        address receiver_,
        uint256 amount_
    ) external onlyDeliveryHelper returns (PayloadSubmitParams[] memory) {
        uint256 maxCreditsAvailableForWithdraw = getMaxCreditsAvailableForWithdraw(transmitter_);
        if (amount_ > maxCreditsAvailableForWithdraw) revert InsufficientCreditsAvailable();

        // Clean up storage
        _useAvailableUserCredits(transmitter_, amount_);
        tokenPoolBalances[chainSlug_][token_] -= amount_;

        bytes memory payload = abi.encodeCall(IFeesPlug.withdrawFees, (token_, receiver_, amount_));
        PayloadSubmitParams[] memory payloadSubmitParamsArray = new PayloadSubmitParams[](1);
        payloadSubmitParamsArray[0] = PayloadSubmitParams({
            levelNumber: 0,
            chainSlug: chainSlug_,
            callType: CallType.WRITE,
            isParallel: Parallel.OFF,
            writeFinality: WriteFinality.LOW,
            asyncPromise: address(0),
            switchboard: _getSwitchboard(chainSlug_),
            target: _getFeesPlugAddress(chainSlug_),
            appGateway: address(this),
            gasLimit: 10000000,
            value: 0,
            readAt: 0,
            payload: payload
        });
        return payloadSubmitParamsArray;
    }

    function getMaxCreditsAvailableForWithdraw(address transmitter_) public view returns (uint256) {
        uint256 watcherFees = watcherPrecompileLimits().getTotalFeesRequired(0, 1, 0, 1);
        uint256 transmitterCredits = userCredits[transmitter_].totalCredits;
        return transmitterCredits > watcherFees ? transmitterCredits - watcherFees : 0;
    }

    function _getSwitchboard(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompile__().watcherPrecompileConfig__().switchboards(chainSlug_, sbType);
    }

    function _createQueuePayloadParams(
        uint32 chainSlug_,
        bytes memory payload_
    ) internal view returns (QueuePayloadParams memory) {
        return
            QueuePayloadParams({
                chainSlug: chainSlug_,
                callType: CallType.WRITE,
                isParallel: Parallel.OFF,
                isPlug: IsPlug.NO,
                writeFinality: WriteFinality.LOW,
                asyncPromise: address(0),
                switchboard: _getSwitchboard(chainSlug_),
                target: _getFeesPlugAddress(chainSlug_),
                appGateway: address(this),
                gasLimit: 10000000,
                value: 0,
                readAt: 0,
                payload: payload_,
                initCallData: bytes("")
            });
    }

    /// @notice hook called by watcher precompile when request is finished
    function onRequestComplete(uint40 requestCount_, bytes memory) external {}

    function _queue(uint32 chainSlug_, bytes memory payload_) internal {
        QueuePayloadParams memory queuePayloadParams = _createQueuePayloadParams(
            chainSlug_,
            payload_
        );
        deliveryHelper__().queue(queuePayloadParams);
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompileConfig().feesPlug(chainSlug_);
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

//  /// @notice Withdraws funds to a specified receiver
//     /// @param chainSlug_ The chain identifier
//     /// @param token_ The address of the token
//     /// @param amount_ The amount of tokens to withdraw
//     /// @param receiver_ The address of the receiver
//     /// @param fees_ The fees data
//     function withdrawTo(
//         uint32 chainSlug_,
//         address token_,
//         uint256 amount_,
//         address receiver_,
//         address auctionManager_,
//         uint256 fees_
//     ) external returns (uint40) {
//         IFeesManager(addressResolver__.feesManager()).withdrawCredits(
//             msg.sender,
//             chainSlug_,
//             token_,
//             amount_,
//             receiver_
//         );
//         return _batch(msg.sender, auctionManager_, msg.sender, fees_, bytes(""));
//     }

//     /// @notice Withdraws fees to a specified receiver
//     /// @param chainSlug_ The chain identifier
//     /// @param token_ The token address
//     /// @param receiver_ The address of the receiver
//     function withdrawTransmitterFees(
//         uint32 chainSlug_,
//         address token_,
//         address receiver_,
//         uint256 amount_
//     ) external returns (uint40 requestCount) {
//         address transmitter = msg.sender;

//         PayloadSubmitParams[] memory payloadSubmitParamsArray = IFeesManager(
//             addressResolver__.feesManager()
//         ).getWithdrawTransmitterCreditsPayloadParams(
//                 transmitter,
//                 chainSlug_,
//                 token_,
//                 receiver_,
//                 amount_
//             );

//         RequestMetadata memory requestMetadata = RequestMetadata({
//             appGateway: addressResolver__.feesManager(),
//             auctionManager: address(0),
//             maxFees: 0,
//             winningBid: Bid({transmitter: transmitter, fee: 0, extraData: new bytes(0)}),
//             onCompleteData: bytes(""),
//             onlyReadRequests: false,
//             consumeFrom: transmitter,
//             queryCount: 0,
//             finalizeCount: 1
//         }); // finalize for plug contract
//         requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
//         requests[requestCount] = requestMetadata;
//         // same transmitter can execute requests without auction
//         watcherPrecompile__().startProcessingRequest(requestCount, transmitter);
//     }