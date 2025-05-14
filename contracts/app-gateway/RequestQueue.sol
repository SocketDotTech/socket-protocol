// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "./DeliveryUtils.sol";

/// @notice Abstract contract for managing asynchronous payloads
abstract contract RequestQueue is DeliveryUtils {
    function _submitBatchRequest(
        PayloadSubmitParams[] memory payloadSubmitParamsArray,
        address consumeFrom_,
        BatchParams memory params
    ) internal returns (uint40 requestCount) {
        emit PayloadSubmitted(
            requestCount,
            params.appGateway,
            payloadSubmitParamsArray,
            params.maxFees - watcherFees,
            params.auctionManager,
            params.onlyReadRequests
        );
    }

    function _createDeployPayloadDetails(
        QueuePayloadParams memory queuePayloadParams_
    ) internal returns (bytes memory payload, address target) {
        bytes32 salt = keccak256(
            abi.encode(queuePayloadParams_.appGateway, queuePayloadParams_.chainSlug, saltCounter++)
        );

        // app gateway is set in the plug deployed on chain
        payload = abi.encodeWithSelector(
            IContractFactoryPlug.deployContract.selector,
            queuePayloadParams_.isPlug,
            salt,
            bytes32(uint256(uint160(queuePayloadParams_.appGateway))),
            queuePayloadParams_.switchboard,
            queuePayloadParams_.payload,
            queuePayloadParams_.initCallData
        );

        // getting app gateway for deployer as the plug is connected to the app gateway
        target = getDeliveryHelperPlugAddress(queuePayloadParams_.chainSlug);
    }
}
