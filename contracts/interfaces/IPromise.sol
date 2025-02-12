// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;

interface IPromise {
    function then(bytes4 selector_, bytes memory data_) external returns (address _promise);

    function markResolved(
        bytes32 asyncId_,
        bytes32 payloadId_,
        bytes memory returnData_
    ) external returns (bool success);

    function markOnchainRevert(
        bytes32 asyncId_,
        bytes32 payloadId_
    ) external;

    function resolved() external view returns (bool);
}
