// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import {LibCall} from "solady/utils/LibCall.sol";
import "../../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../../utils/common/AccessRoles.sol";
import "../../utils/RescueFundsLib.sol";
import {NotSocket} from "../../utils/common/Errors.sol";
import {MAX_COPY_BYTES} from "../../utils/common/Constants.sol";
import "../interfaces/IContractFactoryPlug.sol";
import "../../protocol/base/PlugBase.sol";

/// @title ContractFactory
/// @notice Abstract contract for deploying contracts
contract ContractFactoryPlug is PlugBase, AccessControl, IContractFactoryPlug {
    using LibCall for address;

    event Deployed(address addr, bytes32 salt, bytes returnData);

    /// @notice Error thrown if it failed to deploy the create2 contract
    error DeploymentFailed();
    error ExecutionFailed(bytes32 appGatewayId, bytes returnData);

    /// @notice Constructor for the ContractFactoryPlug
    /// @param socket_ The socket address
    /// @param owner_ The owner address
    constructor(address socket_, address owner_) {
        _initializeOwner(owner_);
        _setSocket(socket_);

        isSocketInitialized = 1;
    }

    /// @notice Deploys a contract
    /// @param isPlug_ Whether the contract to be deployed is a plug
    /// @param salt_ The salt used for create 2
    /// @param appGatewayId_ The app gateway id
    /// @param switchboard_ The switchboard address
    /// @param creationCode_ The creation code
    /// @param initCallData_ The init call data
    /// @return addr The address of the deployed contract
    function deployContract(
        IsPlug isPlug_,
        bytes32 salt_,
        bytes32 appGatewayId_,
        address switchboard_,
        bytes memory creationCode_,
        bytes memory initCallData_
    ) public override onlySocket returns (address addr) {
        assembly {
            addr := create2(callvalue(), add(creationCode_, 0x20), mload(creationCode_), salt_)
            if iszero(addr) {
                mstore(0, 0x30116425) // Error selector for DeploymentFailed
                revert(0x1C, 0x04) // reverting with just 4 bytes
            }
        }

        if (isPlug_ == IsPlug.YES) IPlug(addr).initSocket(appGatewayId_, msg.sender, switchboard_);

        bytes memory returnData;
        if (initCallData_.length > 0) {
            // Capture more detailed error information
            (bool success, , bytes memory returnData_) = addr.tryCall(
                0,
                gasleft(),
                MAX_COPY_BYTES,
                initCallData_
            );

            if (!success) revert ExecutionFailed(appGatewayId_, returnData_);
            returnData = returnData_;
        }

        emit Deployed(addr, salt_, returnData);
    }

    /// @notice Gets the address for a deployed contract
    /// @param creationCode_ The creation code
    /// @param salt_ The salt
    /// @return address The deployed address
    function getAddress(bytes memory creationCode_, uint256 salt_) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt_, keccak256(creationCode_))
        );

        return address(uint160(uint256(hash)));
    }

    function connectSocket(
        bytes32 appGatewayId_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGatewayId_, socket_, switchboard_);
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
