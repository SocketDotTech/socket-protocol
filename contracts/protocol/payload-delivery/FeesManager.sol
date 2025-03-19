// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";
import "solady/utils/ECDSA.sol";

import {IFeesPlug} from "../../interfaces/IFeesPlug.sol";
import {IFeesManager} from "../../interfaces/IFeesManager.sol";

import {AddressResolverUtil} from "../utils/AddressResolverUtil.sol";
import {NotAuctionManager} from "../utils/common/Errors.sol";
import {Bid, Fees, CallType, Parallel, WriteFinality, TokenBalance, QueuePayloadParams, IsPlug, PayloadSubmitParams} from "../utils/common/Structs.sol";

abstract contract FeesManagerStorage is IFeesManager {
    // slots [0-49] reserved for gap
    uint256[50] _gap_before;

    // slot 50
    uint256 public feesCounter;

    // slot 51
    uint32 public evmxSlug;

    // slot 52
    bytes32 public sbType;

    // slot 52
    /// @notice Master mapping tracking all fee information
    /// @dev appGateway => chainSlug => token => TokenBalance
    mapping(address => mapping(uint32 => mapping(address => TokenBalance)))
        public appGatewayFeeBalances;

    // slot 53
    /// @notice Mapping to track blocked fees for each async id
    /// @dev requestCount => Fees
    mapping(uint40 => Fees) public requestCountBlockedFees;

    // slot 54
    /// @notice Mapping to track fees to be distributed to transmitters
    /// @dev transmitter => chainSlug => token => amount
    mapping(address => mapping(uint32 => mapping(address => uint256))) public transmitterFees;

    // slot 55
    /// @notice Mapping to track nonce to whether it has been used
    /// @dev signatureNonce => isNonceUsed
    mapping(uint256 => bool) public isNonceUsed;

    // slots [56-105] reserved for gap
    uint256[50] _gap_after;

    // slots 106-156 reserved for addr resolver util
}

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is FeesManagerStorage, Initializable, Ownable, AddressResolverUtil {
    /// @notice Emitted when fees are blocked for a batch
    /// @param requestCount The batch identifier
    /// @param chainSlug The chain identifier
    /// @param token The token address
    /// @param amount The blocked amount
    event FeesBlocked(
        uint40 indexed requestCount,
        uint32 indexed chainSlug,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when transmitter fees are updated
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The new amount deposited
    event TransmitterFeesUpdated(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );

    /// @notice Emitted when fees deposited are updated
    /// @param chainSlug The chain identifier
    /// @param appGateway The app gateway address
    /// @param token The token address
    /// @param amount The new amount deposited
    event FeesDepositedUpdated(
        uint32 indexed chainSlug,
        address indexed appGateway,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked and assigned to a transmitter
    /// @param requestCount The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The unblocked amount
    event FeesUnblockedAndAssigned(
        uint40 indexed requestCount,
        address indexed transmitter,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked
    /// @param requestCount The batch identifier
    /// @param appGateway The app gateway address
    event FeesUnblocked(uint40 indexed requestCount, address indexed appGateway);

    /// @notice Error thrown when insufficient fees are available
    error InsufficientFeesAvailable();
    /// @notice Error thrown when no fees are available for a transmitter
    error NoFeesForTransmitter();
    /// @notice Error thrown when no fees was blocked
    error NoFeesBlocked();
    /// @notice Error thrown when watcher signature is invalid
    error InvalidWatcherSignature();
    /// @notice Error thrown when nonce is used
    error NonceUsed();

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
    /// @param chainSlug_ The chain identifier
    /// @param appGateway_ The app gateway address
    /// @param token_ The token address
    /// @return The available fee amount
    function getAvailableFees(
        uint32 chainSlug_,
        address appGateway_,
        address token_
    ) public view returns (uint256) {
        TokenBalance memory tokenBalance = appGatewayFeeBalances[appGateway_][chainSlug_][token_];
        if (tokenBalance.deposited == 0 || tokenBalance.deposited <= tokenBalance.blocked) return 0;
        return tokenBalance.deposited - tokenBalance.blocked;
    }

    /// @notice Adds the fees deposited for an app gateway on a chain
    /// @param chainSlug_ The chain identifier
    /// @param originAppGateway_ The app gateway address
    /// @param token_ The token address
    /// @param amount_ The amount deposited
    function incrementFeesDeposited(
        uint32 chainSlug_,
        address originAppGateway_,
        address token_,
        uint256 amount_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external {
        _isWatcherSignatureValid(
            abi.encode(chainSlug_, originAppGateway_, token_, amount_),
            signatureNonce_,
            signature_
        );

        address appGateway = _getCoreAppGateway(originAppGateway_);

        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][chainSlug_][token_];
        tokenBalance.deposited += amount_;
        emit FeesDepositedUpdated(chainSlug_, appGateway, token_, amount_);
    }

    function isFeesEnough(
        address originAppGateway_,
        Fees memory fees_
    ) external view returns (bool) {
        address appGateway = _getCoreAppGateway(originAppGateway_);
        uint256 availableFees = getAvailableFees(
            fees_.feePoolChain,
            appGateway,
            fees_.feePoolToken
        );
        return availableFees >= fees_.amount;
    }

    /// @notice Blocks fees for transmitter
    /// @param originAppGateway_ The app gateway address
    /// @param feesGivenByApp_ The fees data struct given by the app gateway
    /// @param requestCount_ The batch identifier
    /// @dev Only callable by delivery helper
    function blockFees(
        address originAppGateway_,
        Fees memory feesGivenByApp_,
        Bid memory winningBid_,
        uint40 requestCount_
    ) external {
        if (msg.sender != deliveryHelper__().getRequestMetadata(requestCount_).auctionManager)
            revert NotAuctionManager();

        address appGateway = _getCoreAppGateway(originAppGateway_);
        // Block fees
        uint256 availableFees = getAvailableFees(
            feesGivenByApp_.feePoolChain,
            appGateway,
            feesGivenByApp_.feePoolToken
        );

        if (requestCountBlockedFees[requestCount_].amount > 0)
            availableFees += requestCountBlockedFees[requestCount_].amount;

        if (availableFees < winningBid_.fee) revert InsufficientFeesAvailable();
        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][
            feesGivenByApp_.feePoolChain
        ][feesGivenByApp_.feePoolToken];

        tokenBalance.blocked =
            tokenBalance.blocked +
            winningBid_.fee -
            requestCountBlockedFees[requestCount_].amount;

        requestCountBlockedFees[requestCount_] = Fees({
            feePoolChain: feesGivenByApp_.feePoolChain,
            feePoolToken: feesGivenByApp_.feePoolToken,
            amount: winningBid_.fee
        });

        emit FeesBlocked(
            requestCount_,
            feesGivenByApp_.feePoolChain,
            feesGivenByApp_.feePoolToken,
            winningBid_.fee
        );
    }

    /// @notice Unblocks fees after successful execution and assigns them to the transmitter
    /// @param requestCount_ The async ID of the executed batch
    /// @param transmitter_ The address of the transmitter who executed the batch
    function unblockAndAssignFees(
        uint40 requestCount_,
        address transmitter_,
        address originAppGateway_
    ) external override onlyDeliveryHelper {
        Fees memory fees = requestCountBlockedFees[requestCount_];
        if (fees.amount == 0) revert NoFeesBlocked();

        address appGateway = _getCoreAppGateway(originAppGateway_);
        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][fees.feePoolChain][
            fees.feePoolToken
        ];

        // Unblock fees from deposit
        tokenBalance.blocked -= fees.amount;
        tokenBalance.deposited -= fees.amount;

        // Assign fees to transmitter
        transmitterFees[transmitter_][fees.feePoolChain][fees.feePoolToken] += fees.amount;

        // Clean up storage
        delete requestCountBlockedFees[requestCount_];
        emit FeesUnblockedAndAssigned(requestCount_, transmitter_, fees.amount);
    }

    function unblockFees(
        uint40 requestCount_,
        address originAppGateway_
    ) external onlyDeliveryHelper {
        Fees memory fees = requestCountBlockedFees[requestCount_];
        if (fees.amount == 0) revert NoFeesBlocked();

        address appGateway = _getCoreAppGateway(originAppGateway_);
        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][fees.feePoolChain][
            fees.feePoolToken
        ];

        // Unblock fees from deposit
        tokenBalance.blocked -= fees.amount;
        tokenBalance.deposited += fees.amount;

        delete requestCountBlockedFees[requestCount_];
        emit FeesUnblocked(requestCount_, appGateway);
    }

    /// @notice Withdraws fees to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The token address
    /// @param receiver_ The address of the receiver
    function withdrawTransmitterFees(
        uint32 chainSlug_,
        address token_,
        address receiver_
    ) external returns (uint40 requestCount) {
        address transmitter = msg.sender;
        // Get total fees for the transmitter in given chain and token
        uint256 totalFees = transmitterFees[transmitter][chainSlug_][token_];
        if (totalFees == 0) revert NoFeesForTransmitter();

        // Clean up storage
        transmitterFees[transmitter][chainSlug_][token_] = 0;

        // Create fee distribution payload
        bytes32 feesId = _encodeFeesId(feesCounter++);
        bytes memory payload = abi.encodeCall(
            IFeesPlug.distributeFee,
            (token_, totalFees, receiver_, feesId)
        );

        // finalize for plug contract
        return _submitAndStartProcessing(chainSlug_, payload, transmitter);
    }

    function _submitAndStartProcessing(
        uint32 chainSlug_,
        bytes memory payload_,
        address transmitter_
    ) internal returns (uint40 requestCount) {
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
            payload: payload_
        });
        requestCount = watcherPrecompile__().submitRequest(payloadSubmitParamsArray);
        watcherPrecompile__().startProcessingRequest(requestCount, transmitter_);
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

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @param originAppGateway_ The address of the app gateway
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    function withdrawFees(
        address originAppGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) public {
        address appGateway = _getCoreAppGateway(originAppGateway_);

        // Check if amount is available in fees plug
        uint256 availableAmount = getAvailableFees(chainSlug_, appGateway, token_);
        if (availableAmount < amount_) revert InsufficientFeesAvailable();

        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][chainSlug_][token_];
        tokenBalance.deposited -= amount_;

        // Add it to the queue and submit request
        _queue(chainSlug_, abi.encodeCall(IFeesPlug.withdrawFees, (token_, amount_, receiver_)));
    }

    function _queue(uint32 chainSlug_, bytes memory payload_) internal {
        QueuePayloadParams memory queuePayloadParams = _createQueuePayloadParams(
            chainSlug_,
            payload_
        );
        deliveryHelper__().queue(queuePayloadParams);
    }

    function _encodeFeesId(uint256 feesCounter_) internal view returns (bytes32) {
        // watcher address (160 bits) | counter (64 bits)
        return bytes32((uint256(uint160(address(this))) << 64) | feesCounter_);
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompileConfig().feesPlug(chainSlug_);
    }

    function _isWatcherSignatureValid(
        bytes memory digest_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) internal {
        if (isNonceUsed[signatureNonce_]) revert NonceUsed();
        isNonceUsed[signatureNonce_] = true;

        bytes32 digest = keccak256(abi.encode(address(this), evmxSlug, signatureNonce_, digest_));
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        // recovered signer is checked for the valid roles later
        address signer = ECDSA.recover(digest, signature_);
        if (signer != owner()) revert InvalidWatcherSignature();
    }
}
