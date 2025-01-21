// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "../../base/AppGatewayBase.sol";
import {ISuperToken} from "../../interfaces/ISuperToken.sol";
import "../../utils/Ownable.sol";

contract SuperTokenLockableAppGateway is AppGatewayBase, Ownable {
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
        address addressResolver_,
        address deployerContract_,
        address auctionManager_,
        FeesData memory feesData_
    ) AppGatewayBase(addressResolver_, auctionManager_) {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setFeesData(feesData_);
        _claimOwner(msg.sender);
    }

    function checkBalance(bytes memory data_, bytes memory returnData_) external onlyPromises {
        (UserOrder memory order, bytes32 asyncId) = abi.decode(data_, (UserOrder, bytes32));

        uint256 balance = abi.decode(returnData_, (uint256));
        if (balance < order.srcAmount) {
            _revertTx(asyncId);
            return;
        }
        _unlockTokens(order.srcToken, order.user, order.srcAmount);
    }

    function _unlockTokens(address srcToken_, address user_, uint256 amount_) internal async {
        ISuperToken(srcToken_).unlockTokens(user_, amount_);
    }

    function bridge(bytes memory order_) external async returns (bytes32 asyncId_) {
        UserOrder memory order = abi.decode(order_, (UserOrder));
        asyncId_ = _getCurrentAsyncId();
        ISuperToken(order.srcToken).lockTokens(order.user, order.srcAmount);

        _readCallOn();
        // goes to forwarder and deploys promise and stores it
        ISuperToken(order.srcToken).balanceOf(order.user);
        IPromise(order.srcToken).then(this.checkBalance.selector, abi.encode(order, asyncId_));

        _readCallOff();
        ISuperToken(order.dstToken).mint(order.user, order.srcAmount);
        ISuperToken(order.srcToken).burn(order.user, order.srcAmount);

        emit Bridged(asyncId_);
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
