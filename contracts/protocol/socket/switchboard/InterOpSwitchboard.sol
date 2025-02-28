pragma solidity ^0.8.13;
import {SuperchainEnabled} from "./SuperchainEnabled.sol";

// An LocalAsyncProxy is a local representation of a contract on a remote chain.
// Calling an LocalAsyncProxy triggers an authenticated call to an async function,
// on the remote chain and returns a local Promise contract,
// which will eventually trigger a local callback with the return value of the remote async call.
contract InterOpSwitchboard is SuperchainEnabled {
    // address and chainId of the remote contract triggered by calling this local proxy
    address internal remoteAddress;
    uint256 internal remoteChainId;
    uint256 public root;

    constructor(uint256 _chainId) {
        remoteChainId = _chainId;
    }

    function setRemoteAddress(address _remoteAddress) external {
        remoteAddress = _remoteAddress;
    }

    function getRemoteDetails() external view returns (address, uint256) {
        return (remoteAddress, remoteChainId);
    }

    function syncOut(bytes32 root_) external {
        _xMessageContract(
            remoteChainId,
            remoteAddress,
            abi.encodeWithSelector(this.syncIn.selector, root_)
        );
    }

    function syncIn(uint256 root_) external xOnlyFromContract(remoteAddress, remoteChainId) {
        root = root_;
    }
}
