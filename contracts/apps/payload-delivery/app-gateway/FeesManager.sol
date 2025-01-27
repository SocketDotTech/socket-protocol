// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableTwoStep} from "../../../utils/OwnableTwoStep.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {Bid, FeesData, PayloadDetails, CallType, FinalizeParams, PayloadBatch} from "../../../common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";
import {IFeesPlug} from "../../../interfaces/IFeesPlug.sol";
import {IFeesManager} from "../../../interfaces/IFeesManager.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is IFeesManager, AddressResolverUtil, OwnableTwoStep, Initializable {
    uint256 public feesCounter;
    mapping(uint32 => uint256) public feeCollectionGasLimit;

    /// @notice Struct containing fee amounts and status
    struct FeeInfo {
        uint256 deposited; // Amount deposited
        uint256 blocked; // Amount blocked
    }

    /// @notice Master mapping tracking all fee information
    /// @dev appGateway => chainSlug => token => FeeInfo
    mapping(address => mapping(uint32 => mapping(address => FeeInfo))) public feesInfo;

    /// @notice Mapping to track blocked fees for each async id
    /// @dev asyncId => FeesData
    mapping(bytes32 => FeesData) public asyncIdBlockedFees;

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

    error InsufficientFeesAvailable();
    error NoFeesForTransmitter();
    error NoFeesBlocked();

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    /// @notice Initializer function to replace constructor
    /// @param addressResolver_ The address of the address resolver
    /// @param owner_ The address of the owner
    function initialize(address addressResolver_, address owner_) public initializer {
        _setAddressResolver(addressResolver_);
        _claimOwner(owner_);
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
        FeeInfo memory feeInfo = feesInfo[appGateway_][chainSlug_][token_];
        if (feeInfo.deposited == 0 || feeInfo.deposited <= feeInfo.blocked) return 0;
        return feeInfo.deposited - feeInfo.blocked;
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
        FeeInfo storage feeInfo = feesInfo[appGateway_][chainSlug_][token_];
        feeInfo.deposited += amount_;
        emit FeesDepositedUpdated(chainSlug_, appGateway_, token_, amount_);
    }

    /// @notice Blocks fees for transmitter
    /// @param appGateway_ The app gateway address
    /// @param feesData_ The fees data struct
    /// @param asyncId_ The batch identifier
    /// @dev Only callable by delivery helper
    function blockFees(
        address appGateway_,
        FeesData memory feesData_,
        bytes32 asyncId_
    ) external onlyDeliveryHelper {
        // Block fees
        uint256 availableFees = getAvailableFees(
            feesData_.feePoolChain,
            appGateway_,
            feesData_.feePoolToken
        );
        if (availableFees < feesData_.maxFees) revert InsufficientFeesAvailable();

        FeeInfo storage feeInfo = feesInfo[appGateway_][feesData_.feePoolChain][
            feesData_.feePoolToken
        ];
        feeInfo.blocked += feesData_.maxFees;

        asyncIdBlockedFees[asyncId_] = feesData_;
        emit FeesBlocked(
            asyncId_,
            feesData_.feePoolChain,
            feesData_.feePoolToken,
            feesData_.maxFees
        );
    }

    function updateTransmitterFees(
        Bid memory winningBid_,
        bytes32 asyncId_,
        address appGateway_
    ) external onlyDeliveryHelper {
        FeesData storage feesData = asyncIdBlockedFees[asyncId_];
        FeeInfo storage feeInfo = feesInfo[appGateway_][feesData.feePoolChain][
            feesData.feePoolToken
        ];

        // if no transmitter assigned after auction, unblock fees
        if (winningBid_.transmitter == address(0)) {
            feeInfo.blocked -= feesData.maxFees;
            delete asyncIdBlockedFees[asyncId_];
            return;
        }

        // update new maxFees
        feesData.maxFees = winningBid_.fee;
        feeInfo.blocked = feeInfo.blocked - feesData.maxFees + winningBid_.fee;

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
        FeesData memory feesData = asyncIdBlockedFees[asyncId_];
        if (feesData.maxFees == 0) revert NoFeesBlocked();

        FeeInfo storage feeInfo = feesInfo[appGateway_][feesData.feePoolChain][
            feesData.feePoolToken
        ];

        // Unblock fees from deposit
        feeInfo.blocked -= feesData.maxFees;
        feeInfo.deposited -= feesData.maxFees;

        // Assign fees to transmitter
        transmitterFees[transmitter_][feesData.feePoolChain][feesData.feePoolToken] += feesData
            .maxFees;

        // Clean up storage
        delete asyncIdBlockedFees[asyncId_];
        emit FeesUnblockedAndAssigned(asyncId_, transmitter_, feesData.maxFees);
    }

    /// @notice Withdraws fees to a specified receiver
    /// @param chainSlug_ The chain identifier
    /// @param token_ The token address
    /// @param receiver_ The address of the receiver
    function withdrawTransmitterFees(
        uint32 chainSlug_,
        address token_,
        address receiver_
    )
        external
        onlyDeliveryHelper
        returns (bytes32 payloadId, bytes32 root, PayloadDetails memory payloadDetails)
    {
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
        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            transmitter: transmitter
        });

        (payloadId, root) = watcherPrecompile__().finalize(finalizeParams, address(this));
    }

    function _createPayloadDetails(
        CallType callType_,
        uint32 chainSlug_,
        bytes memory payload_
    ) internal view returns (PayloadDetails memory payloadDetails) {
        payloadDetails = PayloadDetails({
            appGateway: address(this),
            chainSlug: chainSlug_,
            target: _getFeesPlugAddress(chainSlug_),
            payload: payload_,
            callType: callType_,
            executionGasLimit: 1000000,
            next: new address[](2),
            isSequential: true
        });
    }

    /// @notice Updates blocked fees in case of failed execution
    /// @param asyncId_ The batch identifier
    /// @dev Only callable by delivery helper
    function updateBlockedFees(bytes32 asyncId_, uint256 feesUsed_) external onlyOwner {
        PayloadBatch memory batch = IDeliveryHelper(deliveryHelper()).getAsyncBatchDetails(
            asyncId_
        );

        FeesData storage feesData = asyncIdBlockedFees[asyncId_];
        FeeInfo storage feeInfo = feesInfo[batch.appGateway][batch.feesData.feePoolChain][
            batch.feesData.feePoolToken
        ];

        // Unblock unused fees
        uint256 unusedFees = feesData.maxFees - feesUsed_;
        feeInfo.blocked -= unusedFees;

        // Update feesData with actual fees used
        feesData.maxFees = feesUsed_;
        asyncIdBlockedFees[asyncId_] = feesData;
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
        // Check if amount is available in fees plug
        uint256 availableAmount = getAvailableFees(chainSlug_, appGateway_, token_);
        if (availableAmount < amount_) revert InsufficientFeesAvailable();

        FeeInfo storage feeInfo = feesInfo[appGateway_][chainSlug_][token_];
        feeInfo.deposited -= amount_;

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
        return watcherPrecompile__().appGatewayPlugs(address(this), chainSlug_);
    }
}
