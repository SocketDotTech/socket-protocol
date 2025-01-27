// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {FeesData, Bid, PayloadDetails} from "../common/Structs.sol";

interface IFeesManager {
    function blockFees(address appGateway_, FeesData memory feesData_, bytes32 asyncId_) external;

    function updateTransmitterFees(
        Bid memory winningBid_,
        bytes32 asyncId_,
        address appGateway_
    ) external;

    function updateBlockedFees(bytes32 asyncId_, uint256 feesUsed_) external;

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
