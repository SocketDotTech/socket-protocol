// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMultichainToken {
    function burn(address user_, uint256 amount_) external;

    function mint(address receiver_, uint256 amount_) external;

    function balanceOf(address account) external;

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);
}
