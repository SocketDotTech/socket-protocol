// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {Initializable} from "solady/utils/Initializable.sol";
import {IAppGateway} from "../interfaces/IAppGateway.sol";
import {IContractFactoryPlug} from "../interfaces/IContractFactoryPlug.sol";
import {IDeployForwarder} from "../interfaces/IDeployForwarder.sol";
import {AsyncModifierNotSet} from "../../utils/common/Errors.sol";
import {QueueParams, OverrideParams, Transaction} from "../../utils/common/Structs.sol";
import {WRITE} from "../../utils/common/Constants.sol";
import {encodeAppGatewayId} from "../../utils/common/IdUtils.sol";
import {RESCUE_ROLE} from "../../utils/common/AccessRoles.sol";
import "../../utils/RescueFundsLib.sol";
import "../../utils/AccessControl.sol";
import "./AddressResolverUtil.sol";

/// @title DeployForwarder
/// @notice contract responsible for handling deployment requests
contract DeployForwarder is IDeployForwarder, Initializable, AddressResolverUtil, AccessControl {
    // slots [0-49] 50 slots reserved for address resolver util

    // slots [50-99] reserved for gap
    uint256[50] _gap_before;

    // slot 100
    /// @notice The counter for the salt used to generate/deploy the contract address
    uint256 public override saltCounter;

    // slot 101
    bytes32 public override deployerSwitchboardType;

    constructor() {
        _disableInitializers(); // disable for implementation
    }

    function initialize(
        address owner_,
        address addressResolver_,
        bytes32 deployerSwitchboardType_
    ) public reinitializer(1) {
        deployerSwitchboardType = deployerSwitchboardType_;
        _setAddressResolver(addressResolver_);
        _initializeOwner(owner_);
    }

    /// @notice Deploys a contract
    /// @param chainSlug_ The chain slug
    function deploy(
        IsPlug isPlug_,
        uint32 chainSlug_,
        bytes memory initCallData_,
        bytes memory payload_
    ) external {
        address msgSender = msg.sender;
        bool isAsyncModifierSet = IAppGateway(msgSender).isAsyncModifierSet();
        if (!isAsyncModifierSet) revert AsyncModifierNotSet();

        // fetch the override params from app gateway
        (OverrideParams memory overrideParams, bytes32 plugSwitchboardType) = IAppGateway(msgSender)
            .getOverrideParams();

        QueueParams memory queueParams;
        queueParams.overrideParams = overrideParams;
        queueParams.overrideParams.callType = WRITE;
        queueParams.switchboardType = deployerSwitchboardType;
        queueParams.transaction = Transaction({
            chainSlug: chainSlug_,
            target: address(0),
            payload: _createPayload(
                isPlug_,
                plugSwitchboardType,
                msgSender,
                chainSlug_,
                payload_,
                initCallData_
            )
        });

        watcher__().queue(queueParams, msg.sender);
    }

    function _createPayload(
        IsPlug isPlug_,
        bytes32 plugSwitchboardType_,
        address appGateway_,
        uint32 chainSlug_,
        bytes memory payload_,
        bytes memory initCallData_
    ) internal returns (bytes memory payload) {
        bytes32 salt = keccak256(abi.encode(appGateway_, chainSlug_, saltCounter++));

        // app gateway is set in the plug deployed on chain
        payload = abi.encodeWithSelector(
            IContractFactoryPlug.deployContract.selector,
            isPlug_,
            salt,
            encodeAppGatewayId(appGateway_),
            watcher__().configurations__().switchboards(chainSlug_, plugSwitchboardType_),
            payload_,
            initCallData_
        );
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake. This contract does not
     * theoretically need this function but it is added for safety.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }
}
