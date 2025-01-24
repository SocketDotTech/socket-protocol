// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableTwoStep} from "../../../utils/OwnableTwoStep.sol";
import {SignatureVerifier} from "../../../socket/utils/SignatureVerifier.sol";
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";
import {Bid, FeesData, PayloadDetails, CallType, FinalizeParams} from "../../../common/Structs.sol";
import {IDeliveryHelper} from "../../../interfaces/IDeliveryHelper.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";
import {IFeesPlug} from "../../../interfaces/IFeesPlug.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is AddressResolverUtil, OwnableTwoStep, Initializable {
    uint256 public feesCounter;
    mapping(uint32 => uint256) public feeCollectionGasLimit;

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

    /// @notice Mapping to track fees deposited by app gateways on each chain
    /// @dev chainSlug => appGateway => token => amount 
    mapping(uint32 => mapping(address => mapping(address => uint256))) public feesDeposited;

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

    /// @notice Updates the fees deposited for an app gateway on a chain
    /// @param chainSlug_ The chain identifier
    /// @param appGateway_ The app gateway address
    /// @param token_ The token address
    /// @param amount_ The amount deposited
    function updateFeesDeposited(
        uint32 chainSlug_,
        address appGateway_,
        address token_,
        uint256 amount_
    ) external onlyWatcher {
        feesDeposited[chainSlug_][appGateway_][token_] = amount_;
        emit FeesDepositedUpdated(chainSlug_, appGateway_, token_, amount_);
    }

    /// @notice Mapping to track blocked fees for async batches
    /// @dev asyncId => chainSlug => mapping(token => amount)
    mapping(bytes32 => mapping(uint32 => mapping(address => uint256))) public blockedFees;

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
        uint256 totalBlocked;
        bytes32[] memory activeAsyncIds = IDeliveryHelper(deliveryHelper__()).getActiveAsyncIds();
        
        for(uint256 i = 0; i < activeAsyncIds.length; i++) {
            totalBlocked += blockedFees[activeAsyncIds[i]][chainSlug_][token_];
        }
        
        return feesDeposited[chainSlug_][appGateway_][token_] - totalBlocked;
    }

    /// @notice Blocks fees and creates payload for distribution
    /// @param appGateway_ The app gateway address
    /// @param feesData_ The fees data struct
    /// @param winningBid_ The winning bid struct
    /// @param asyncId_ The batch identifier
    /// @dev Only callable by delivery helper
    function blockAndDistributeFees(
        address appGateway_,
        FeesData memory feesData_,
        Bid memory winningBid_,
        bytes32 asyncId_
    ) external onlyDeliveryHelper returns (PayloadDetails memory payloadDetails) {
        // Block fees
        require(
            getAvailableFees(feesData_.feePoolChain, appGateway_, feesData_.feePoolToken) >= winningBid_.fee,
            "Insufficient available fees"
        );
        
        blockedFees[asyncId_][feesData_.feePoolChain][feesData_.feePoolToken] = winningBid_.fee;

        emit FeesBlocked(asyncId_, feesData_.feePoolChain, feesData_.feePoolToken, winningBid_.fee);

        // Deploy promise for fee distribution
        address promise = IAddressResolver(addressResolver__).deployAsyncPromiseContract(address(this));

        // Create fee distribution payload
        bytes32 feesId = _encodeFeesId(feesCounter++);
        address appGateway = _getCoreAppGateway(appGateway_);
        
        bytes memory payload = abi.encodeCall(
            IFeesPlug.distributeFee,
            (appGateway, feesData_.feePoolToken, winningBid_.fee, winningBid_.transmitter, feesId)
        );

        payloadDetails = PayloadDetails({
            appGateway: address(this),
            chainSlug: feesData_.feePoolChain,
            target: _getFeesPlugAddress(feesData_.feePoolChain),
            payload: payload,
            callType: CallType.WRITE,
            executionGasLimit: 1000000,
            next: new address[](1),
            isSequential: true
        });
        payloadDetails.next[0] = promise;

        return payloadDetails;
    }

    /// @notice Updates blocked fees after distribution
    /// @param asyncId_ The batch identifier
    /// @param chainSlug_ The chain identifier 
    /// @param token_ The token address
    /// @dev Only callable by delivery helper
    function updateBlockedFees(
        bytes32 asyncId_,
        uint32 chainSlug_,
        address token_
    ) external onlyDeliveryHelper {
        uint256 blockedAmount = blockedFees[asyncId_][chainSlug_][token_];
        require(blockedAmount > 0, "No fees blocked");

        // Reduce blocked amount from total fees deposited
        feesDeposited[chainSlug_][msg.sender][token_] -= blockedAmount;
        
        // Clear blocked fees
        delete blockedFees[asyncId_][chainSlug_][token_];

        emit FeesUnblocked(asyncId_, chainSlug_, token_, blockedAmount);
    }
    // function distributeFees(
    //     address appGateway_,
    //     FeesData memory feesData_,
    //     Bid memory winningBid_
    // )
    //     external
    //     onlyDeliveryHelper
    //     returns (bytes32 payloadId, bytes32 root, PayloadDetails memory payloadDetails)
    // {
    //     bytes32 feesId = _encodeFeesId(feesCounter++);

    //     address appGateway = _getCoreAppGateway(appGateway_);
    //     // Create payload for pool contract
    //     bytes memory payload = abi.encodeCall(
    //         IFeesPlug.distributeFee,
    //         (appGateway, feesData_.feePoolToken, winningBid_.fee, winningBid_.transmitter, feesId)
    //     );

    //     payloadDetails = PayloadDetails({
    //         appGateway: address(this),
    //         chainSlug: feesData_.feePoolChain,
    //         target: _getFeesPlugAddress(feesData_.feePoolChain),
    //         payload: payload,
    //         callType: CallType.WRITE,
    //         executionGasLimit: 1000000,
    //         next: new address[](0),
    //         isSequential: true
    //     });

    //     FinalizeParams memory finalizeParams = FinalizeParams({
    //         payloadDetails: payloadDetails,
    //         transmitter: winningBid_.transmitter
    //     });

    //     (payloadId, root) = watcherPrecompile__().finalize(finalizeParams, appGateway);
    //     return (payloadId, root, payloadDetails);
    // }

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
    ) public view returns (PayloadDetails memory) {
        address appGateway = _getCoreAppGateway(appGateway_);
        
        // Check if amount is available in fees plug
        uint256 availableAmount = IFeesPlug(_getFeesPlugAddress(chainSlug_)).getAvailableFees(appGateway, token_);
        require(availableAmount >= amount_, "Insufficient fees available");

        // Create payload for pool contract
        bytes memory payload = abi.encodeCall(
            IFeesPlug.withdrawFees,
            (appGateway, token_, amount_, receiver_)
        );

        return
            PayloadDetails({
                appGateway: address(this),
                chainSlug: chainSlug_,
                target: _getFeesPlugAddress(chainSlug_),
                payload: payload,
                callType: CallType.WITHDRAW,
                executionGasLimit: 1000000,
                next: new address[](2),
                isSequential: true
            });
    }

    function _encodeFeesId(uint256 feesCounter_) internal view returns (bytes32) {
        // watcher address (160 bits) | counter (64 bits)
        return bytes32((uint256(uint160(address(this))) << 64) | feesCounter_);
    }

    function _getFeesPlugAddress(uint32 chainSlug_) internal view returns (address) {
        return watcherPrecompile__().appGatewayPlugs(address(this), chainSlug_);
    }
}
