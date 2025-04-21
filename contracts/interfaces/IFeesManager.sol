// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Bid, QueuePayloadParams} from "../protocol/utils/common/Structs.sol";

interface IFeesManager {
    function blockFees(
        address consumeFrom_,
        uint256 transmitterCredits_,
        uint40 requestCount_
    ) external;

    function unblockFees(uint40 requestCount_) external;

    function isFeesEnough(
        address consumeFrom_,
        address appGateway_,
        uint256 amount_
    ) external view returns (bool);

    function unblockAndAssignFees(uint40 requestCount_, address transmitter_) external;

    function withdrawFees(
        address appGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external;

    function assignWatcherPrecompileFeesFromRequestCount(
        uint256 fees_,
        uint40 requestCount_
    ) external;

    function assignWatcherPrecompileFeesFromAddress(uint256 fees_, address consumeFrom_) external;

    function setAppGatewayWhitelist(
        bytes memory feeApprovalData_
    ) external returns (address consumeFrom, address appGateway, bool isApproved);
}
