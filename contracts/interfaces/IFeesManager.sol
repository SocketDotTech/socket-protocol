// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {FeesData, Bid, PayloadDetails} from "../common/Structs.sol";

interface IFeesManager {
    function distributeFees(
        address appGateway_,
        FeesData memory feesData_,
        Bid memory winningBid_
    ) external returns (bytes32 payloadId, bytes32 root, PayloadDetails memory);

    function getWithdrawToPayload(
        address appGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external view returns (PayloadDetails memory);
}
