// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface IFeesPool {
    event NativeDeposited(address indexed from, uint256 amount);
    event NativeWithdrawn(bool success, address indexed to, uint256 amount);

    function withdraw(address to_, uint256 amount_) external returns (bool success);

    function getBalance() external view returns (uint256);
}
