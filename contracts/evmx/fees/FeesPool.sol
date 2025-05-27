// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../utils/AccessControl.sol";
import "../../utils/common/AccessRoles.sol";
import "../interfaces/IFeesPool.sol";

/**
 * @title FeesPool
 * @notice Contract to store native fees that can be pulled by fees manager
 */
contract FeesPool is IFeesPool, AccessControl {
    error TransferFailed();

    /**
     * @param owner_ The address of the owner
     */
    constructor(address owner_) {
        _setOwner(owner_);

        // to rescue funds
        _grantRole(FEE_MANAGER_ROLE, owner_);
    }

    /**
     * @notice Allows fees manager to withdraw native tokens
     * @param to_ The address to withdraw to
     * @param amount_ The amount to withdraw
     * @return success Whether the withdrawal was successful
     */
    function withdraw(
        address to_,
        uint256 amount_
    ) external onlyRole(FEE_MANAGER_ROLE) returns (bool success) {
        (success, ) = to_.call{value: amount_}("");
        emit NativeWithdrawn(success, to_, amount_);
    }

    /**
     * @notice Returns the current balance of native tokens in the pool
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        emit NativeDeposited(msg.sender, msg.value);
    }
}
