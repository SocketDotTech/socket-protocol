// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {ExecuteParams} from "../protocol/utils/common/Structs.sol";

/**
 * @title ISocket
 * @notice An interface for a Chain Abstraction contract
 * @dev This interface provides methods for transmitting and executing payloads,
 * connecting a plug to a remote chain and setting up switchboards for the payload transmission
 * This interface also emits events for important operations such as payload transmission, execution status,
 * and plug connection
 */
interface ISocket {
    /**
     * @notice emits the status of payload after external call
     * @param payloadId msg id which is executed
     */
    event ExecutionSuccess(bytes32 payloadId, bytes returnData);

    /**
     * @notice emits the status of payload after external call
     * @param payloadId msg id which is executed
     */
    event ExecutionFailed(bytes32 payloadId, bytes returnData);

    /**
     * @notice emits the config set by a plug for a remoteChainSlug
     * @param plug address of plug on current chain
     * @param appGateway address of plug on sibling chain
     * @param switchboard outbound switchboard (select from registered options)
     */
    event PlugConnected(address plug, address appGateway, address switchboard);

    /**
     * @notice emits the message details when a new message arrives at outbound
     * @param triggerId call id
     * @param chainSlug local chain slug
     * @param plug local plug address
     * @param params params, for specifying details like fee pool chain, fee pool token and max fees if required
     * @param payload the data which will be used by contracts on chain
     */
    event AppGatewayCallRequested(
        bytes32 triggerId,
        uint32 chainSlug,
        address plug,
        bytes params,
        bytes payload
    );

    /**
     * @notice executes a payload
     */
    function execute(
        ExecuteParams memory executeParams_,
        bytes memory transmitterSignature_
    ) external payable returns (bytes memory);

    /**
     * @notice sets the config specific to the plug
     * @param appGateway_ address of plug present at sibling chain
     * @param switchboard_ the address of switchboard to use for executing payloads
     */
    function connect(address appGateway_, address switchboard_) external;

    function registerSwitchboard() external;

    /**
     * @notice returns the config for given `plugAddress_` and `siblingChainSlug_`
     * @param plugAddress_ address of plug present at current chain
     */
    function getPlugConfig(
        address plugAddress_
    ) external view returns (address appGateway, address switchboard);
}
