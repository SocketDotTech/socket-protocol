// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Fees, Bid, QueuePayloadParams} from "../protocol/utils/common/Structs.sol";

interface IFeesManager {
    function blockFees(
        address appGateway_,
        Fees memory fees_,
        Bid memory winningBid_,
        uint40 requestCount_
    ) external;

    function unblockFees(uint40 requestCount_) external;

    function isFeesEnough(address appGateway_, Fees memory fees_) external view returns (bool);

    function unblockAndAssignFees(
        uint40 requestCount_,
        address transmitter_,
        address appGateway_
    ) external;

    function withdrawFees(
        address appGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external;
}
