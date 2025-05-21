// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./CreditUtils.sol";

/// @title FeesManager
/// @notice Contract for managing fees
contract FeesManager is CreditUtils, Initializable, Ownable, AddressResolverUtil {
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

    // /// @notice Withdraws funds to a specified receiver
    // /// @dev This function is used to withdraw fees from the fees plug
    // /// @param originAppGatewayOrUser_ The address of the app gateway
    // /// @param chainSlug_ The chain identifier
    // /// @param token_ The address of the token
    // /// @param amount_ The amount of tokens to withdraw
    // /// @param receiver_ The address of the receiver
    // function withdrawCredits(
    //     address originAppGatewayOrUser_,
    //     uint32 chainSlug_,
    //     address token_,
    //     uint256 amount_,
    //     address receiver_
    // ) public {
    //     if (msg.sender != address(deliveryHelper__())) originAppGatewayOrUser_ = msg.sender;
    //     address source = _getCoreAppGateway(originAppGatewayOrUser_);

    //     // Check if amount is available in fees plug
    //     uint256 availableAmount = getAvailableCredits(source);
    //     if (availableAmount < amount_) revert InsufficientCreditsAvailable();

    //     _useAvailableUserCredits(source, amount_);
    //     tokenPoolBalances[chainSlug_][token_] -= amount_;

    //     // Add it to the queue and submit request
    //     _queue(chainSlug_, abi.encodeCall(IFeesPlug.withdrawFees, (token_, receiver_, amount_)));
    // }

    // /// @notice Withdraws fees to a specified receiver
    // /// @param chainSlug_ The chain identifier
    // /// @param token_ The token address
    // /// @param receiver_ The address of the receiver
    // function getWithdrawTransmitterCreditsPayloadParams(
    //     address transmitter_,
    //     uint32 chainSlug_,
    //     address token_,
    //     address receiver_,
    //     uint256 amount_
    // ) external onlyWatcher returns (PayloadSubmitParams[] memory) {
    //     uint256 maxCreditsAvailableForWithdraw = getMaxCreditsAvailableForWithdraw(transmitter_);
    //     if (amount_ > maxCreditsAvailableForWithdraw) revert InsufficientCreditsAvailable();

    //     // Clean up storage
    //     _useAvailableUserCredits(transmitter_, amount_);
    //     tokenPoolBalances[chainSlug_][token_] -= amount_;

    //     bytes memory payload = abi.encodeCall(IFeesPlug.withdrawFees, (token_, receiver_, amount_));
    //     PayloadSubmitParams[] memory payloadSubmitParamsArray = new PayloadSubmitParams[](1);
    //     payloadSubmitParamsArray[0] = PayloadSubmitParams({
    //         levelNumber: 0,
    //         chainSlug: chainSlug_,
    //         callType: WRITE,
    //         isParallel: Parallel.OFF,
    //         writeFinality: WriteFinality.LOW,
    //         asyncPromise: address(0),
    //         switchboard: _getSwitchboard(chainSlug_),
    //         target: _getFeesPlugAddress(chainSlug_),
    //         appGateway: address(this),
    //         gasLimit: 10000000,
    //         value: 0,
    //         readAtBlockNumber: 0,
    //         payload: payload
    //     });
    //     return payloadSubmitParamsArray;
    // }

    // function getMaxCreditsAvailableForWithdraw(address transmitter_) public view returns (uint256) {
    //     uint256 watcherFees = watcherPrecompileLimits().getTotalFeesRequired(0, 1, 0, 1);
    //     uint256 transmitterCredits = userCredits[transmitter_].totalCredits;
    //     return transmitterCredits > watcherFees ? transmitterCredits - watcherFees : 0;
    // }
}
