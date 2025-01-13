// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../../base/AppGatewayBase.sol";
import {ISuperToken} from "../../interfaces/ISuperToken.sol";
import "../../utils/Ownable.sol";

contract SuperTokenAppGateway is AppGatewayBase, Ownable {
    uint256 public idCounter;

    event Bridged(bytes32 asyncId);

    struct UserOrder {
        address srcToken;
        address dstToken;
        address user;
        uint256 srcAmount;
        uint256 deadline;
    }

    constructor(
        address _addressResolver,
        address deployerContract_,
        FeesData memory feesData_,
        address _auctionManager
    ) AppGatewayBase(_addressResolver, _auctionManager) Ownable(msg.sender) {
        addressResolver.setContractsToGateways(deployerContract_);
        _setFeesData(feesData_);
    }

    function bridge(bytes memory _order) external async returns (bytes32 asyncId) {
        UserOrder memory order = abi.decode(_order, (UserOrder));
        asyncId = _getCurrentAsyncId();
        ISuperToken(order.dstToken).mint(order.user, order.srcAmount);
        ISuperToken(order.srcToken).burn(order.user, order.srcAmount);

        emit Bridged(asyncId);
    }

    function withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external onlyOwner {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
