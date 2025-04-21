// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../../../contracts/base/AppGatewayBase.sol";
import "./ISuperToken.sol";
import "./SuperToken.sol";

contract SuperTokenAppGateway is AppGatewayBase, Ownable {
    bytes32 public superToken = _createContractId("superToken");
    event Transferred(uint40 requestCount);

    struct ConstructorParams {
        string name_;
        string symbol_;
        uint8 decimals_;
        address initialSupplyHolder_;
        uint256 initialSupply_;
    }

    struct TransferOrder {
        address srcToken;
        address dstToken;
        address user;
        uint256 srcAmount;
        uint256 deadline;
    }

    constructor(
        address addressResolver_,
        address owner_,
        uint256 fees_,
        ConstructorParams memory params_
    ) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[superToken] = abi.encodePacked(
            type(SuperToken).creationCode,
            abi.encode(
                params_.name_,
                params_.symbol_,
                params_.decimals_,
                params_.initialSupplyHolder_,
                params_.initialSupply_
            )
        );

        // sets the fees data like max fees, chain and token for all transfers
        // they can be updated for each transfer as well
        _setOverrides(fees_);
        _initializeOwner(owner_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        bytes memory initData = abi.encodeWithSelector(SuperToken.setOwner.selector, owner());
        _deploy(superToken, chainSlug_, IsPlug.YES, initData);
    }

    // no need to call this directly, will be called automatically after all contracts are deployed.
    // check AppGatewayBase._deploy and AppGatewayBase.onRequestComplete
    function initialize(uint32) public pure override {
        return;
    }

    function transfer(bytes memory order_) external async {
        TransferOrder memory order = abi.decode(order_, (TransferOrder));
        ISuperToken(order.srcToken).burn(order.user, order.srcAmount);
        ISuperToken(order.dstToken).mint(order.user, order.srcAmount);

        emit Transferred(_getCurrentAsyncId());
    }
}
