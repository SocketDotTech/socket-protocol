// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import "solady/utils/Initializable.sol";

import {AddressResolverUtil} from "../../../protocol/utils/AddressResolverUtil.sol";
import {Bid, Fees, PayloadDetails, CallType, FinalizeParams, PayloadBatch, Parallel} from "../../../protocol/utils/common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../protocol/utils/common/Constants.sol";
import {IFeesPlug} from "../../../interfaces/IFeesPlug.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is IFeesManager, AddressResolverUtil, Ownable, Initializable {
    uint256 public feesCounter;
    mapping(uint32 => uint256) public feeCollectionGasLimit;
    uint64 public version;

    /// @notice Struct containing fee amounts and status
    struct TokenBalance {
        uint256 deposited; // Amount deposited
        uint256 blocked; // Amount blocked
    }

    /// @notice Master mapping tracking all fee information
    /// @dev appGateway => chainSlug => token => TokenBalance
    mapping(address => mapping(uint32 => mapping(address => TokenBalance)))
        public appGatewayFeeBalances;

    /// @notice Mapping to track blocked fees for each async id
    /// @dev asyncId => Fees
    mapping(bytes32 => Fees) public asyncIdBlockedFees;

    /// @notice Mapping to track fees to be distributed to transmitters
    /// @dev transmitter => chainSlug => token => amount
    mapping(address => mapping(uint32 => mapping(address => uint256))) public transmitterFees;

    /// @notice Emitted when fees are blocked for a batch
    /// @param asyncId The batch identifier
    /// @param chainSlug The chain identifier
    /// @param token The token address
    /// @param amount The blocked amount
    event FeesBlocked(
        bytes32 indexed asyncId,
        uint32 indexed chainSlug,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when transmitter fees are updated
    /// @param asyncId The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The new amount deposited
    event TransmitterFeesUpdated(
        bytes32 indexed asyncId,
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
    /// @param asyncId The batch identifier
    /// @param transmitter The transmitter address
    /// @param amount The unblocked amount
    event FeesUnblockedAndAssigned(
        bytes32 indexed asyncId,
        address indexed transmitter,
        uint256 amount
    );

    /// @notice Emitted when fees are unblocked
    /// @param asyncId The batch identifier
    /// @param appGateway The app gateway address
    event FeesUnblocked(bytes32 indexed asyncId, address indexed appGateway);

    /// @notice Error thrown when insufficient fees are available
    error InsufficientFeesAvailable();
    /// @notice Error thrown when no fees are available for a transmitter
    error NoFeesForTransmitter();
    /// @notice Error thrown when no fees was blocked
    error NoFeesBlocked();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the owner
    function initialize(address addressResolver_, address owner_) public reinitializer(1) {
        version = 1;
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
    /// @param appGateway_ The app gateway address
    /// @param token_ The token address
    /// @param amount_ The amount deposited
    function incrementFeesDeposited(
        uint32 chainSlug_,
        address appGateway_,
        address token_,
        uint256 amount_
    ) external onlyOwner {
        address appGateway = _getCoreAppGateway(appGateway_);

        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][chainSlug_][token_];
        tokenBalance.deposited += amount_;
        emit FeesDepositedUpdated(chainSlug_, appGateway, token_, amount_);
    }

    function isFeesEnough(address appGateway_, Fees memory fees_) external view returns (bool) {
        address appGateway = _getCoreAppGateway(appGateway_);
        uint256 availableFees = getAvailableFees(
            fees_.feePoolChain,
            appGateway,
            fees_.feePoolToken
        );
        return availableFees >= fees_.amount;
    }

    /// @notice Blocks fees for transmitter
    /// @param appGateway_ The app gateway address
    /// @param fees_ The fees data struct
    /// @param asyncId_ The batch identifier
    /// @dev Only callable by delivery helper
    function blockFees(
        address appGateway_,
        Fees memory fees_,
        Bid memory winningBid_,
        bytes32 asyncId_
    ) external {
        // todo: only auction manager can call this
        address appGateway = _getCoreAppGateway(appGateway_);
        // Block fees
        uint256 availableFees = getAvailableFees(
            fees_.feePoolChain,
            appGateway,
            fees_.feePoolToken
        );
        if (availableFees < winningBid_.fee) revert InsufficientFeesAvailable();

        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][fees_.feePoolChain][
            fees_.feePoolToken
        ];
        tokenBalance.blocked += winningBid_.fee;

        asyncIdBlockedFees[asyncId_] = fees_;
        emit FeesBlocked(asyncId_, fees_.feePoolChain, fees_.feePoolToken, winningBid_.fee);
    }

    function updateTransmitterFees(
        Bid memory winningBid_,
        bytes32 asyncId_,
        address appGateway_
    ) external onlyDeliveryHelper {
        address appGateway = _getCoreAppGateway(appGateway_);

        Fees storage fees = asyncIdBlockedFees[asyncId_];
        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][fees.feePoolChain][
            fees.feePoolToken
        ];

        // if no transmitter assigned after auction, unblock fees
        if (winningBid_.transmitter == address(0)) {
            tokenBalance.blocked -= fees.amount;
            delete asyncIdBlockedFees[asyncId_];
            return;
        }

        // update new amount
        fees.amount = winningBid_.fee;
        tokenBalance.blocked = tokenBalance.blocked - fees.amount + winningBid_.fee;

        emit TransmitterFeesUpdated(asyncId_, winningBid_.transmitter, winningBid_.fee);
    }

    /// @notice Unblocks fees after successful execution and assigns them to the transmitter
    /// @param asyncId_ The async ID of the executed batch
    /// @param transmitter_ The address of the transmitter who executed the batch
    function unblockAndAssignFees(
        bytes32 asyncId_,
        address transmitter_,
        address appGateway_
    ) external override onlyDeliveryHelper {
        Fees memory fees = asyncIdBlockedFees[asyncId_];
        if (fees.amount == 0) revert NoFeesBlocked();

        address appGateway = _getCoreAppGateway(appGateway_);
        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][fees.feePoolChain][
            fees.feePoolToken
        ];

        // Unblock fees from deposit
        tokenBalance.blocked -= fees.amount;
        tokenBalance.deposited -= fees.amount;

        // Assign fees to transmitter
        transmitterFees[transmitter_][fees.feePoolChain][fees.feePoolToken] += fees.amount;

        // Clean up storage
        delete asyncIdBlockedFees[asyncId_];
        emit FeesUnblockedAndAssigned(asyncId_, transmitter_, fees.amount);
    }

    function unblockFees(bytes32 asyncId_, address appGateway_) external onlyDeliveryHelper {
        Fees memory fees = asyncIdBlockedFees[asyncId_];
        if (fees.amount == 0) revert NoFeesBlocked();

        address appGateway = _getCoreAppGateway(appGateway_);
        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][fees.feePoolChain][
            fees.feePoolToken
        ];

        // Unblock fees from deposit
        tokenBalance.blocked -= fees.amount;
        tokenBalance.deposited += fees.amount;

        delete asyncIdBlockedFees[asyncId_];
        emit FeesUnblocked(asyncId_, appGateway);
    }

    /// @notice Withdraws fees to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The token address
    /// @param receiver_ The address of the receiver
    function withdrawTransmitterFees(
        uint32 chainSlug_,
        address token_,
        address receiver_
    ) external returns (bytes32 payloadId, bytes32 root, PayloadDetails memory payloadDetails) {
        address transmitter = msg.sender;
        // Get all asyncIds for the transmitter
        uint256 totalFees = transmitterFees[transmitter][chainSlug_][token_];
        if (totalFees == 0) revert NoFeesForTransmitter();

        transmitterFees[transmitter][chainSlug_][token_] = 0;

        // Create fee distribution payload
        bytes32 feesId = _encodeFeesId(feesCounter++);
        bytes memory payload = abi.encodeCall(
            IFeesPlug.distributeFee,
            (token_, totalFees, receiver_, feesId)
        );

        // Create payload for plug contract
        payloadDetails = _createPayloadDetails(CallType.WRITE, chainSlug_, payload);

        // todo: revisit
        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            asyncId: bytes32(0),
            transmitter: transmitter
        });

        (payloadId, root) = watcherPrecompile__().finalize(address(this), finalizeParams);
    }

    function _createPayloadDetails(
        CallType callType_,
        uint32 chainSlug_,
        bytes memory payload_
    ) internal view returns (PayloadDetails memory) {
        return
            PayloadDetails({
                appGateway: address(this),
                chainSlug: chainSlug_,
                target: _getFeesPlugAddress(chainSlug_),
                payload: payload_,
                callType: callType_,
                value: 0,
                executionGasLimit: 1000000,
                next: new address[](2),
                isParallel: Parallel.OFF
            });
    }

    /// @notice Updates blocked fees in case of failed execution
    /// @param asyncId_ The batch identifier
    /// @dev Only callable by delivery helper
    function updateBlockedFees(bytes32 asyncId_, uint256 feesUsed_) external onlyOwner {
        PayloadBatch memory batch = IDeliveryHelper(deliveryHelper()).getAsyncBatchDetails(
            asyncId_
        );

        Fees storage fees = asyncIdBlockedFees[asyncId_];
        TokenBalance storage tokenBalance = appGatewayFeeBalances[batch.appGateway][
            batch.fees.feePoolChain
        ][batch.fees.feePoolToken];

        // todo how to settle fees here?
        // Unblock unused fees
        uint256 unusedFees = fees.amount - feesUsed_;
        tokenBalance.blocked -= unusedFees;

        // Update fees with actual fees used
        fees.amount = feesUsed_;
        asyncIdBlockedFees[asyncId_] = fees;
    }

    /// @notice Withdraws funds to a specified receiver
    /// @dev This function is used to withdraw fees from the fees plug
    /// @param appGateway_ The address of the app gateway
    /// @param chainSlug_ The chain identifier
    /// @param token_ The address of the token
    /// @param amount_ The amount of tokens to withdraw
    /// @param receiver_ The address of the receiver
    function getWithdrawToPayload(
        address appGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) public returns (PayloadDetails memory) {
        address appGateway = _getCoreAppGateway(appGateway_);

        // Check if amount is available in fees plug
        uint256 availableAmount = getAvailableFees(chainSlug_, appGateway, token_);
        if (availableAmount < amount_) revert InsufficientFeesAvailable();

        TokenBalance storage tokenBalance = appGatewayFeeBalances[appGateway][chainSlug_][token_];
        tokenBalance.deposited -= amount_;

        // Create payload for pool contract
        return
            _createPayloadDetails(
                CallType.WITHDRAW,
                chainSlug_,
                abi.encodeCall(IFeesPlug.withdrawFees, (token_, amount_, receiver_))
            );
    }

    function _encodeFeesId(uint256 feesCounter_) internal view returns (bytes32) {
        // watcher address (160 bits) | counter (64 bits)
        return bytes32((uint256(uint160(address(this))) << 64) | feesCounter_);
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompile__().feesPlug(chainSlug_);
    }
}
