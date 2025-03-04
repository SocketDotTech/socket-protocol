// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";

import "../../../../contracts/base/AppGatewayBase.sol";
import "./ISuperToken.sol";
import "./SuperToken.sol";

contract SuperTokenAppGateway is AppGatewayBase, Ownable {
    bytes32 public superToken = _createContractId("superToken");
    string public status;

    event Transferred(bytes32 asyncId);

    struct TransferOrder {
        address srcToken;
        address dstToken;
        address user;
        uint256 amount;
        uint256 deadline;
    }

    constructor(
        address addressResolver_,
        address owner_,
        Fees memory fees_
    ) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[superToken] = abi.encodePacked(
            type(SuperToken).creationCode,
            abi.encode("SUPER TOKEN", "SUPER", 18, owner_, 1000000000 ether)
        );

        // sets the fees data like max fees, chain and token for all transfers
        // they can be updated for each transfer as well
        _setOverrides(fees_);
        _initializeOwner(owner_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        address opInteropSwitchboard = watcherPrecompile__().switchboards(chainSlug_, sbType);
        bytes memory initData = abi.encodeWithSelector(
            SuperToken.setupToken.selector,
            owner(),
            opInteropSwitchboard
        );
        _deploy(superToken, chainSlug_, IsPlug.YES, initData);
    }

    function transfer(bytes memory order_) external async {
        TransferOrder memory order = abi.decode(order_, (TransferOrder));
        status = "Bridging";

        ISuperToken(order.srcToken).burn(order.user, order.amount);
        ISuperToken(order.dstToken).mint(order.user, order.amount);
        IPromise(order.dstToken).then(this.updateStatus.selector, abi.encode("Bridged"));

        emit Transferred(_getCurrentAsyncId());
    }

    function updateStatus(string memory status_, bytes memory) external onlyPromises {
        status = status_;
    }
}
