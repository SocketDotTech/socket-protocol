// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../utils/common/Structs.sol";
import "../interfaces/IPrecompile.sol";

interface IRequestHandler {
    function requestBatchIds(uint40 batchCount_) external view returns (uint40[] memory);

    function batchPayloadIds(uint40 batchCount_) external view returns (bytes32[] memory);

    function requests(uint40 requestCount_) external view returns (RequestParams memory);

    function payloads(bytes32 payloadId_) external view returns (PayloadParams memory);

    function getPrecompileFees(bytes4 precompile_, bytes memory precompileData_) external view returns (uint256);

    function nextRequestCount() external view returns (uint40);

    function setPrecompile(bytes4 callType_, IPrecompile precompile_) external;

    function submitRequest(
        uint256 maxFees_,
        address auctionManager_,
        address consumeFrom_,
        address appGateway_,
        QueueParams[] calldata queueParams_,
        bytes memory onCompleteData_
    ) external returns (uint40 requestCount, address[] memory promiseList);

    function assignTransmitter(uint40 requestCount_, Bid memory bid_) external;

    function updateRequestAndProcessBatch(uint40 requestCount_, bytes32 payloadId_) external;

    function cancelRequestForReverts(uint40 requestCount) external;

    function cancelRequest(uint40 requestCount) external;

    function handleRevert(uint40 requestCount) external;

    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) external;
}
