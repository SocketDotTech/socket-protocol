// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import {ISuperToken} from "../super-token/ISuperToken.sol";
import "../../../../contracts/base/AppGatewayBase.sol";
import "./SuperTokenLockable.sol";
import "./LimitHook.sol";

contract SuperTokenLockableAppGateway is AppGatewayBase, Ownable {
    bytes32 public superTokenLockable = _createContractId("superTokenLockable");
    bytes32 public limitHook = _createContractId("limitHook");

    event Bridged(bytes32 asyncId);

    struct UserOrder {
        address srcToken;
        address dstToken;
        address user;
        uint256 srcAmount;
        uint256 deadline;
    }

    struct ConstructorParams {
        uint256 _burnLimit;
        uint256 _mintLimit;
        string name_;
        string symbol_;
        uint8 decimals_;
        address initialSupplyHolder_;
        uint256 initialSupply_;
    }

    constructor(
        address addressResolver_,
        address owner_,
        Fees memory fees_,
        ConstructorParams memory params
    ) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[superTokenLockable] = abi.encodePacked(
            type(SuperTokenLockable).creationCode,
            abi.encode(
                params.name_,
                params.symbol_,
                params.decimals_,
                params.initialSupplyHolder_,
                params.initialSupply_
            )
        );

        creationCodeWithArgs[limitHook] = abi.encodePacked(
            type(LimitHook).creationCode,
            abi.encode(params._burnLimit, params._mintLimit)
        );

        _setOverrides(fees_);
        _initializeOwner(owner_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        bytes memory initData = abi.encodeWithSelector(
            SuperTokenLockable.setOwner.selector,
            owner()
        );
        _deploy(superTokenLockable, chainSlug_, IsPlug.YES, initData);
        _deploy(limitHook, chainSlug_, IsPlug.YES, initData);
    }

    // don't need to call this directly, will be called automatically after all contracts are deployed.
    // check AppGatewayBase.onRequestComplete
    function initialize(uint32 chainSlug_) public override async {
        address limitHookContract = getOnChainAddress(limitHook, chainSlug_);
        SuperTokenLockable(forwarderAddresses[superTokenLockable][chainSlug_]).setLimitHook(
            limitHookContract
        );
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

        _setOverrides(Read.ON);
        // goes to forwarder and deploys promise and stores it
        ISuperToken(order.srcToken).balanceOf(order.user);
        IPromise(order.srcToken).then(this.checkBalance.selector, abi.encode(order, asyncId_));

        _setOverrides(Read.OFF);
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
