// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "../../base/AppGatewayBase.sol";
import "../../interfaces/ISuperToken.sol";
import "../../utils/Ownable.sol";

contract SuperTokenAppGateway is AppGatewayBase, Ownable {
    event Transferred(bytes32 asyncId);

    struct TransferOrder {
        address srcToken;
        address dstToken;
        address user;
        uint256 srcAmount;
        uint256 deadline;
    }

    constructor(
        address addressResolver_,
        address deployerContract_,
        FeesData memory feesData_,
        address auctionManager_
    ) AppGatewayBase(addressResolver_, auctionManager_) {
        // called to connect the deployer contract with this app
        addressResolver__.setContractsToGateways(deployerContract_);

        // sets the fees data like max fees, chain and token for all transfers
        // they can be updated for each transfer as well
        _setFeesData(feesData_);
        _claimOwner(msg.sender);
    }

    function transfer(bytes memory order_) external async {
        TransferOrder memory order = abi.decode(order_, (TransferOrder));
        ISuperToken(order.srcToken).burn(order.user, order.srcAmount);
        ISuperToken(order.dstToken).mint(order.user, order.srcAmount);

        emit Transferred(_getCurrentAsyncId());
    }
}
