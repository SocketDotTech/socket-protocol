// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "../../../../contracts/base/AppGatewayBase.sol";
import "./IOpToken.sol";
import "./OpToken.sol";

contract OpTokenAppGateway is AppGatewayBase, Ownable {
    bytes32 public opToken = _createContractId("opToken");
    event Transferred(uint40 requestCount);

    struct ConstructorParams {
        string name_;
        string symbol_;
        uint8 decimals_;
        address initialSupplyHolder_;
        uint256 initialSupply_;
    }

    struct TransferOrder {
        address[] srcTokens;
        address[] dstTokens;
        address user;
        uint256[] srcAmounts;
        uint256[] dstAmounts;
    }

    constructor(
        address addressResolver_,
        address owner_,
        Fees memory fees_,
        ConstructorParams memory params_
    ) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[opToken] = abi.encodePacked(
            type(OpToken).creationCode,
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
        bytes memory initData = abi.encodeWithSelector(OpToken.setOwner.selector, owner());
        _deploy(opToken, chainSlug_, IsPlug.YES, initData);
    }

    // no need to call this directly, will be called automatically after all contracts are deployed.
    // check AppGatewayBase._deploy and AppGatewayBase.onRequestComplete
    function initialize(uint32) public pure override {
        return;
    }

    function transfer(bytes memory order_) external async {
        TransferOrder memory order = abi.decode(order_, (TransferOrder));
        for (uint256 i = 0; i < order.srcTokens.length; i++) {
            IOpToken(order.srcTokens[i]).burn(order.user, order.srcAmounts[i]);
        }
        for (uint256 i = 0; i < order.dstTokens.length; i++) {
            IOpToken(order.dstTokens[i]).mint(order.user, order.dstAmounts[i]);
        }

        emit Transferred(_getCurrentAsyncId());
    }
}
