// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../AddressResolverUtil.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/IMiddleware.sol";
import "../interfaces/IPromise.sol";

import {InvalidPromise, FeesNotSet, AsyncModifierNotUsed} from "../../utils/common/Errors.sol";
import {FAST} from "../../utils/common/Constants.sol";

/// @title AppGatewayBase
/// @notice Abstract contract for the app gateway
/// @dev This contract contains helpers for contract deployment, overrides, hooks and request processing
abstract contract AppGatewayBase is AddressResolverUtil, IAppGateway {
    OverrideParams public overrideParams;
    bool public isAsyncModifierSet;
    address public auctionManager;
    bytes32 public sbType;
    bytes public onCompleteData;
    uint256 public maxFees;

    mapping(address => bool) public isValidPromise;
    mapping(bytes32 => mapping(uint32 => address)) public override forwarderAddresses;
    mapping(bytes32 => bytes) public creationCodeWithArgs;

    address public consumeFrom;

    /// @notice Modifier to treat functions async
    modifier async(bytes memory feesApprovalData_) {
        _preAsync(feesApprovalData_);
        _;
        _postAsync();
    }

    // todo: can't overload modifier with same name, can rename later
    /// @notice Modifier to treat functions async with consume from address
    modifier asyncWithConsume(address consumeFrom_) {
        _preAsync(new bytes(0));
        consumeFrom = consumeFrom_;
        _;
        _postAsync();
    }

    function _postAsync() internal {
        isAsyncModifierSet = false;

        watcher__().submitRequest(maxFees, auctionManager, consumeFrom, onCompleteData);
        _markValidPromises();
        onCompleteData = bytes("");
    }

    function _preAsync(bytes memory feesApprovalData_) internal {
        isAsyncModifierSet = true;
        _clearOverrides();
        watcher__().clearQueue();
        addressResolver__.clearPromises();

        _handleFeesApproval(feesApprovalData_);
    }

    function _handleFeesApproval(bytes memory feesApprovalData_) internal {
        if (feesApprovalData_.length > 0) {
            (consumeFrom, , ) = IFeesManager(addressResolver__.feesManager())
                .whitelistAppGatewayWithSignature(feesApprovalData_);
        } else consumeFrom = address(this);
    }

    /// @notice Modifier to ensure only valid promises can call the function
    /// @dev only valid promises can call the function
    modifier onlyPromises() {
        if (!isValidPromise[msg.sender]) revert InvalidPromise();
        // remove promise once resolved
        isValidPromise[msg.sender] = false;
        _;
    }

    /// @notice Constructor for AppGatewayBase
    /// @param addressResolver_ The address resolver address
    constructor(address addressResolver_) {
        _setAddressResolver(addressResolver_);
        sbType = FAST;
    }

    /// @notice Sets the switchboard type
    /// @param sbType_ The switchboard type
    function _setSbType(bytes32 sbType_) internal {
        sbType = sbType_;
    }

    /// @notice Creates a contract ID
    /// @param contractName_ The contract name
    /// @return bytes32 The contract ID
    function _createContractId(string memory contractName_) internal pure returns (bytes32) {
        return keccak256(abi.encode(contractName_));
    }

    /// @notice Gets the current async ID
    /// @return uint40 The current async ID
    function _getCurrentAsyncId() internal view returns (uint40) {
        return watcherPrecompile__().getCurrentRequestCount();
    }

    /// @notice Sets the auction manager
    /// @param auctionManager_ The auction manager
    function _setAuctionManager(address auctionManager_) internal {
        auctionManager = auctionManager_;
    }

    /// @notice Marks the promises as valid
    function _markValidPromises() internal {
        address[] memory promises = addressResolver__.getPromises();
        for (uint256 i = 0; i < promises.length; i++) {
            isValidPromise[promises[i]] = true;
        }
    }

    /// @notice Sets the validity of an onchain contract (plug) to authorize it to send information to a specific AppGateway
    /// @param chainSlug_ The unique identifier of the chain where the contract resides
    /// @param contractId The bytes32 identifier of the contract to be validated
    /// @param isValid Boolean flag indicating whether the contract is authorized (true) or not (false)
    /// @dev This function retrieves the onchain address using the contractId and chainSlug, then calls the watcher precompile to update the plug's validity status
    function _setValidPlug(uint32 chainSlug_, bytes32 contractId, bool isValid) internal {
        address onchainAddress = getOnChainAddress(contractId, chainSlug_);
        watcherPrecompileConfig().setIsValidPlug(chainSlug_, onchainAddress, isValid);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////   DEPLOY HELPERS ///////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploys a contract
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    function _deploy(bytes32 contractId_, uint32 chainSlug_, IsPlug isPlug_) internal {
        _deploy(contractId_, chainSlug_, isPlug_, new bytes(0));
    }

    /// @notice Gets the socket address
    /// @param chainSlug_ The chain slug
    /// @return socketAddress_ The socket address
    function getSocketAddress(uint32 chainSlug_) public view returns (address) {
        return watcherPrecompileConfig().sockets(chainSlug_);
    }

    /// @notice Gets the on-chain address
    /// @param contractId_ The contract ID
    /// @param chainSlug_ The chain slug
    /// @return onChainAddress The on-chain address
    function getOnChainAddress(
        bytes32 contractId_,
        uint32 chainSlug_
    ) public view returns (address onChainAddress) {
        if (forwarderAddresses[contractId_][chainSlug_] == address(0)) {
            return address(0);
        }

        onChainAddress = IForwarder(forwarderAddresses[contractId_][chainSlug_])
            .getOnChainAddress();
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// TX OVERRIDE HELPERS ///////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Sets multiple overrides in one call
    /// @param isReadCall_ The read call flag
    /// @param fees_ The maxFees configuration
    /// @param gasLimit_ The gas limit
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(
        Read isReadCall_,
        Parallel isParallelCall_,
        uint256 gasLimit_,
        uint256 fees_
    ) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.gasLimit = gasLimit_;
        maxFees = fees_;
    }

    function _clearOverrides() internal {
        overrideParams.isReadCall = Read.OFF;
        overrideParams.isParallelCall = Parallel.OFF;
        overrideParams.gasLimit = 0;
        overrideParams.value = 0;
        overrideParams.readAt = 0;
        overrideParams.writeFinality = WriteFinality.LOW;
    }

    /// @notice Sets isReadCall, maxFees and gasLimit overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    /// @param gasLimit_ The gas limit
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_, uint256 gasLimit_) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.gasLimit = gasLimit_;
    }

    /// @notice Sets isReadCall and isParallelCall overrides
    /// @param isReadCall_ The read call flag
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Read isReadCall_, Parallel isParallelCall_) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.isParallelCall = isParallelCall_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param writeFinality_ The write finality
    function _setOverrides(WriteFinality writeFinality_) internal {
        overrideParams.writeFinality = writeFinality_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param isParallelCall_ The sequential call flag
    function _setOverrides(Parallel isParallelCall_) internal {
        overrideParams.isParallelCall = isParallelCall_;
    }

    /// @notice Sets isParallelCall overrides
    /// @param isParallelCall_ The sequential call flag
    /// @param readAt_ The read anchor value. Currently block number.
    function _setOverrides(Parallel isParallelCall_, uint256 readAt_) internal {
        overrideParams.isParallelCall = isParallelCall_;
        overrideParams.readAt = readAt_;
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    function _setOverrides(Read isReadCall_) internal {
        overrideParams.isReadCall = isReadCall_;
    }

    /// @notice Sets isReadCall overrides
    /// @param isReadCall_ The read call flag
    /// @param readAt_ The read anchor value. Currently block number.
    function _setOverrides(Read isReadCall_, uint256 readAt_) internal {
        overrideParams.isReadCall = isReadCall_;
        overrideParams.readAt = readAt_;
    }

    /// @notice Sets gasLimit overrides
    /// @param gasLimit_ The gas limit
    function _setOverrides(uint256 gasLimit_) internal {
        overrideParams.gasLimit = gasLimit_;
    }

    function _setMsgValue(uint256 value_) internal {
        overrideParams.value = value_;
    }

    /// @notice Sets maxFees overrides
    /// @param fees_ The maxFees configuration
    function _setMaxFees(uint256 fees_) internal {
        maxFees = fees_;
    }

    function getOverrideParams()
        public
        view
        returns (Read, Parallel, WriteFinality, uint256, uint256, uint256, bytes32)
    {
        return (
            overrideParams.isReadCall,
            overrideParams.isParallelCall,
            overrideParams.writeFinality,
            overrideParams.readAt,
            overrideParams.gasLimit,
            overrideParams.value,
            sbType
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// ASYNC BATCH HELPERS /////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Reverts the transaction
    /// @param requestCount_ The async ID
    function _revertTx(uint40 requestCount_) internal {
        deliveryHelper__().cancelRequest(requestCount_);
    }

    /// @notice increases the transaction maxFees
    /// @param requestCount_ The async ID
    function _increaseFees(uint40 requestCount_, uint256 newMaxFees_) internal {
        deliveryHelper__().increaseFees(requestCount_, newMaxFees_);
    }

    /// @notice Withdraws fee tokens
    /// @param chainSlug_ The chain slug
    /// @param token_ The token address
    /// @param amount_ The amount
    /// @param receiver_ The receiver address
    function _withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) internal returns (uint40) {
        return
            deliveryHelper__().withdrawTo(
                chainSlug_,
                token_,
                amount_,
                receiver_,
                auctionManager,
                maxFees
            );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// HOOKS /////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Callback in pd promise to be called after all contracts are deployed
    /// @param onCompleteData_ The on complete data
    /// @dev only payload delivery can call this
    /// @dev callback in pd promise to be called after all contracts are deployed
    function onRequestComplete(
        uint40,
        bytes calldata onCompleteData_
    ) external override onlyDeliveryHelper {
        if (onCompleteData_.length == 0) return;
        (uint32 chainSlug, bool isDeploy) = abi.decode(onCompleteData_, (uint32, bool));
        if (isDeploy) {
            initialize(chainSlug);
        }
    }

    /// @notice Initializes the contract after deployment
    /// @dev can be overridden by the app gateway to add custom logic
    /// @param chainSlug_ The chain slug
    function initialize(uint32 chainSlug_) public virtual {}

    /// @notice hook to handle the revert in callbacks or onchain executions
    /// @dev can be overridden by the app gateway to add custom logic
    /// @param requestCount_ The async ID
    /// @param payloadId_ The payload ID
    function handleRevert(
        uint40 requestCount_,
        bytes32 payloadId_
    ) external override onlyPromises {}
}
