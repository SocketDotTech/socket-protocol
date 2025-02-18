// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {Fees, Bid, PayloadDetails} from "../protocol/utils/common/Structs.sol";

interface IFeesManager {
    function blockFees(address appGateway_, Fees memory fees_, Bid memory winningBid_, bytes32 asyncId_) external;

    function updateTransmitterFees(
        Bid memory winningBid_,
        bytes32 asyncId_,
        address appGateway_
    ) external;

    function updateBlockedFees(bytes32 asyncId_, uint256 feesUsed_) external;

    function unblockFees(bytes32 asyncId_, address appGateway_) external;

    function isFeesEnough(address appGateway_, Fees memory fees_) external view returns (bool);
    function unblockAndAssignFees(
        bytes32 asyncId_,
        address transmitter_,
        address appGateway_
    ) external;

    function getWithdrawToPayload(
        address appGateway_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external returns (PayloadDetails memory);
}
