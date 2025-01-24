// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
interface IERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256);

    function balanceOf(address account_) external view returns (uint256);

    function allowance(address owner_, address spender_) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender_, uint256 amount_) external returns (bool);

    function transfer(address to_, uint256 amount_) external returns (bool);

    function transferFrom(address from_, address to_, uint256 amount_) external returns (bool);
}
