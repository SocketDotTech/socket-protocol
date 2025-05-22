// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../utils/common/Structs.sol";
import "../interfaces/IPrecompile.sol";

interface IRequestHandler {
    function setPrecompile(bytes4 callType_, IPrecompile precompile_) external;

    function submitRequest(
        uint256 maxFees_,
        address auctionManager_,
        address consumeFrom_,
        address appGateway_,
        QueueParams[] calldata queuePayloadParams_,
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount, address[] memory promiseList);

    function assignTransmitter(uint40 requestCount_, Bid memory bid_) external;

    function updateRequestAndProcessBatch(uint40 requestCount_, bytes32 payloadId_) external;

    function cancelRequest(uint40 requestCount) external;

    function handleRevert(uint40 requestCount) external;

    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external;
}
