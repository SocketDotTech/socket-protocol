// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface ICounter {
    function increase() external;

    function getCounter() external;

    // A function that is not part of the interface, used for testing on-chian revert.
    function wrongFunction() external;
}
