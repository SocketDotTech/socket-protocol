// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Bid, QueuePayloadParams, PayloadSubmitParams, AppGatewayWhitelistParams} from "../utils/common/Structs.sol";

interface IFeesManager {
    function blockCredits(
        address consumeFrom_,
        uint256 transmitterCredits_,
        uint40 requestCount_
    ) external;

    function unblockCredits(uint40 requestCount_) external;

    function isUserCreditsEnough(
        address consumeFrom_,
        address appGateway_,
        uint256 amount_
    ) external view returns (bool);

    function unblockAndAssignCredits(uint40 requestCount_, address transmitter_) external;

    function assignWatcherPrecompileCreditsFromRequestCount(
        uint256 fees_,
        uint40 requestCount_
    ) external;

    function assignWatcherPrecompileCreditsFromAddress(
        uint256 fees_,
        address consumeFrom_
    ) external;

    function whitelistAppGatewayWithSignature(
        bytes memory feeApprovalData_
    ) external returns (address consumeFrom, address appGateway, bool isApproved);

    function whitelistAppGateways(AppGatewayWhitelistParams[] calldata params_) external;

    function getWithdrawTransmitterCreditsPayloadParams(
        address transmitter_,
        uint32 chainSlug_,
        address token_,
        address receiver_,
        uint256 amount_
    ) external returns (PayloadSubmitParams[] memory);

    function getMaxCreditsAvailableForWithdraw(
        address transmitter_
    ) external view returns (uint256);

    function withdrawCredits(
        address originAppGatewayOrUser_,
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external;

    function depositCredits(
        address depositTo_,
        uint32 chainSlug_,
        address token_,
        uint256 signatureNonce_,
        bytes memory signature_
    ) external payable;
}
