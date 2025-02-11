// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./CounterImpl.sol";
import "../../base/AppDeployerBase.sol";
import "../../utils/OwnableTwoStep.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
contract CounterDeployer is AppDeployerBase, OwnableTwoStep {
    bytes32 public counterImpl = _createContractId("counterImpl");
    bytes32 public proxy = _createContractId("proxy");

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_,
        Fees memory fees_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        creationCodeWithArgs[counterImpl] = abi.encodePacked(type(CounterImpl).creationCode);
        creationCodeWithArgs[proxy] = abi.encodePacked(type(TransparentUpgradeableProxy).creationCode);
        _setFees(fees_);
        _claimOwner(msg.sender);
    }

    function updateImplementation(bytes32 contractId_, bytes memory creationCode_) external onlyOwner {
        creationCodeWithArgs[contractId_] = creationCode_;
    }

    function deployImplementations(uint32 chainSlug_) external async {
        _deployImplementation(counterImpl, chainSlug_);
    }

    function deployProxies(uint32 chainSlug_) external pure override {
        address counterImplAddress = getOnChainAddress(counterImpl, chainSlug_, this.initialize.selector);
        // TODO: update this according to your proxy creation code
        bytes memory counterProxyCreationCode = abi.encodePacked(creationCodeWithArgs[proxy], abi.encode(counterImplAddress));
        _deployProxy(proxy, counterProxyCreationCode);
    }

    function initialize(uint32 chainSlug_) internal pure override {
        // TODO: update this according to your implementation initialization code
    }


    function setFees(Fees memory fees_) public {
        fees = fees_;
    }
}
