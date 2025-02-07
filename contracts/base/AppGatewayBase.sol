// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../utils/AddressResolverUtil.sol";
import "../interfaces/IDeliveryHelper.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IPromise.sol";
import {Fees} from "../common/Structs.sol";
import {FeesPlugin} from "../utils/FeesPlugin.sol";
import {InvalidPromise, FeesNotSet} from "../common/Errors.sol";

/// @title AppGatewayBase
/// @notice Abstract contract for the app gateway
abstract contract AppGatewayBase is AddressResolverUtil, IAppGateway, FeesPlugin {
    bool public override isReadCall;
    bool public override isCallSequential;
    address public auctionManager;
    bytes public onCompleteData;
    bytes32 public sbType;

    mapping(address => bool) public isValidPromise;

    /// @notice Modifier to treat functions async
    modifier async() {
        if (fees.feePoolChain == 0) revert FeesNotSet();
        deliveryHelper().clearQueue();
        addressResolver__.clearPromises();
        _;
        deliveryHelper().batch(fees, auctionManager, onCompleteData, sbType);
        _markValidPromises();
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
    constructor(address addressResolver_, address auctionManager_) {
        _setAddressResolver(addressResolver_);
        auctionManager = auctionManager_;
        isCallSequential = true;
    }

    function _setIsCallSequential(bool isCallSequential_) internal {
        isCallSequential = isCallSequential_;
    }

    /// @notice Creates a contract ID
    /// @param contractName_ The contract name
    /// @return bytes32 The contract ID
    function _createContractId(string memory contractName_) internal pure returns (bytes32) {
        return keccak256(abi.encode(contractName_));
    }

    /// @notice Sets the auction manager
    /// @param auctionManager_ The auction manager
    function _setAuctionManager(address auctionManager_) internal {
        auctionManager = auctionManager_;
    }

    /// @notice Sets the read call flag
    function _readCallOn() internal {
        isReadCall = true;
    }

    /// @notice Turns off the read call flag
    function _readCallOff() internal {
        isReadCall = false;
    }

    /// @notice Marks the promises as valid
    function _markValidPromises() internal {
        address[] memory promises = addressResolver__.getPromises();
        for (uint256 i = 0; i < promises.length; i++) {
            isValidPromise[promises[i]] = true;
        }
    }

    /// @notice Gets the current async ID
    /// @return bytes32 The current async ID
    function _getCurrentAsyncId() internal view returns (bytes32) {
        return deliveryHelper().getCurrentAsyncId();
    }

    /// @notice Reverts the transaction
    /// @param asyncId_ The async ID
    function _revertTx(bytes32 asyncId_) internal {
        deliveryHelper().cancelTransaction(asyncId_);
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
    ) internal {
        deliveryHelper().withdrawTo(chainSlug_, token_, amount_, receiver_, auctionManager, fees);
    }

    /// @notice Callback in pd promise to be called after all contracts are deployed
    /// @param asyncId_ The async ID
    /// @param payloadBatch_ The payload batch
    function onBatchComplete(
        bytes32 asyncId_,
        PayloadBatch memory payloadBatch_
    ) external virtual onlyDeliveryHelper {}

    function callFromInbox(
        uint32 chainSlug_,
        address plug_,
        bytes calldata payload_,
        bytes32 params_
    ) external virtual onlyWatcherPrecompile {}
}
