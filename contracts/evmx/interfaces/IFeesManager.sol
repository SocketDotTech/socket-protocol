// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;
import {WriteFinality, UserCredits, AppGatewayApprovals, OverrideParams, Transaction, QueueParams, RequestParams} from "../../utils/common/Structs.sol";

interface IFeesManager {
    function deposit(
        address depositTo_,
        uint32 chainSlug_,
        address token_,
        uint256 nativeAmount_,
        uint256 creditAmount_
    ) external payable;

    function wrap(address receiver_) external payable;

    function unwrap(uint256 amount_, address receiver_) external;

    function getAvailableCredits(address consumeFrom_) external view returns (uint256);

    function isCreditSpendable(
        address consumeFrom_,
        address spender_,
        uint256 amount_
    ) external view returns (bool);

    function transferCredits(address from_, address to_, uint256 amount_) external;

    function approveAppGateways(AppGatewayApprovals[] calldata params_) external;

    function approveAppGatewayWithSignature(
        bytes memory feeApprovalData_
    ) external returns (address consumeFrom, address spender, bool approval);

    function withdrawCredits(
        uint32 chainSlug_,
        address token_,
        uint256 credits_,
        uint256 maxFees_,
        address receiver_
    ) external;

    function blockCredits(uint40 requestCount_, address consumeFrom_, uint256 credits_) external;

    function unblockAndAssignCredits(uint40 requestCount_, address assignTo_) external;

    function unblockCredits(uint40 requestCount_) external;
}
