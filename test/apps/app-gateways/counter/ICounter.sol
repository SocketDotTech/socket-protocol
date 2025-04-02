// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface ICounter {
    function increase() external;

    function getCounter() external;

    // A function that is not part of the interface, used for testing on-chian revert.
    function wrongFunction() external;
}
