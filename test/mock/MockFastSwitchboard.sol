// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/protocol/interfaces/ISwitchboard.sol";
import "../../contracts/protocol/interfaces/ISocket.sol";

contract MockFastSwitchboard is ISwitchboard {
    address public owner;
    ISocket public immutable socket__;

    // chain slug of deployed chain
    uint32 public immutable chainSlug;

    /**
     * @dev Constructor of SwitchboardBase
     * @param chainSlug_ Chain slug of deployment chain
     * @param socket_ socket_ contract
     */
    constructor(uint32 chainSlug_, address socket_, address owner_) {
        chainSlug = chainSlug_;
        socket__ = ISocket(socket_);
        owner = owner_;
    }

    function attest(bytes32, bytes calldata) external {}

    function allowPayload(bytes32, bytes32) external pure returns (bool) {
        // digest has enough attestations
        return true;
    }

    function registerSwitchboard() external {
        socket__.registerSwitchboard();
    }

    function processTrigger(
        address plug_,
        bytes32 triggerId_,
        bytes calldata payload_,
        bytes calldata overrides_
    ) external payable override {}
}
