// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../../../contracts/base/AppGatewayBase.sol";
import "../../../../contracts/interfaces/IForwarder.sol";
import "../../../../contracts/interfaces/IPromise.sol";
import "./Counter.sol";
import "./ICounter.sol";

contract CounterAppGateway is AppGatewayBase, Ownable {
    bytes32 public counter = _createContractId("counter");
    bytes32 public counter1 = _createContractId("counter1");

    uint256 public counterVal;

    uint256 public arbCounter;
    uint256 public optCounter;
    event TimeoutResolved(uint256 creationTimestamp, uint256 executionTimestamp);

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[counter] = abi.encodePacked(type(Counter).creationCode);
        creationCodeWithArgs[counter1] = abi.encodePacked(type(Counter).creationCode);
        _setOverrides(fees_);
        _initializeOwner(msg.sender);
    }

    // deploy contracts
    function deployContracts(uint32 chainSlug_) external async {
        _deploy(counter, chainSlug_, IsPlug.YES);
    }

    function deployContractsWithoutAsync(uint32 chainSlug_) external {
        _deploy(counter, chainSlug_, IsPlug.YES);
    }

    function deployParallelContracts(uint32 chainSlug_) external async {
        _setOverrides(Parallel.ON);
        _deploy(counter, chainSlug_, IsPlug.YES);
        _deploy(counter1, chainSlug_, IsPlug.YES);
        _setOverrides(Parallel.OFF);
    }

    function deployMultiChainContracts(uint32[] memory chainSlugs_) external async {
        _setOverrides(Parallel.ON);
        for (uint32 i = 0; i < chainSlugs_.length; i++) {
            _deploy(counter, chainSlugs_[i], IsPlug.YES);
            _deploy(counter1, chainSlugs_[i], IsPlug.YES);
        }
        _setOverrides(Parallel.OFF);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function incrementCounters(address[] memory instances_) public async {
        // the increase function is called on given list of instances
        // this
        for (uint256 i = 0; i < instances_.length; i++) {
            ICounter(instances_[i]).increase();
        }
    }

    // for testing purposes
    function incrementCountersWithoutAsync(address[] memory instances_) public {
        // the increase function is called on given list of instances
        for (uint256 i = 0; i < instances_.length; i++) {
            Counter(instances_[i]).increase();
        }
    }

    function readCounters(address[] memory instances_) public async {
        // the increase function is called on given list of instances
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < instances_.length; i++) {
            uint32 chainSlug = IForwarder(instances_[i]).getChainSlug();
            ICounter(instances_[i]).getCounter();
            IPromise(instances_[i]).then(this.setCounterValues.selector, abi.encode(chainSlug));
        }
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    function readCounterAtBlock(address instance_, uint256 blockNumber_) public async {
        uint32 chainSlug = IForwarder(instance_).getChainSlug();
        _setOverrides(Read.ON, Parallel.ON, blockNumber_);
        ICounter(instance_).getCounter();
        IPromise(instance_).then(this.setCounterValues.selector, abi.encode(chainSlug));
    }

    function setCounterValues(bytes memory data, bytes memory returnData) external onlyPromises {
        uint256 counterValue = abi.decode(returnData, (uint256));
        uint32 chainSlug = abi.decode(data, (uint32));
        if (chainSlug == 421614) {
            arbCounter = counterValue;
        } else if (chainSlug == 11155420) {
            optCounter = counterValue;
        }
    }

    // trigger from a chain
    function setIsValidPlug(uint32 chainSlug_, address plug_) public {
        watcherPrecompileConfig().setIsValidPlug(chainSlug_, plug_, true);
    }

    function increase(uint256 value_) external onlyWatcherPrecompile {
        counterVal += value_;
    }

    // TIMEOUT
    function setTimeout(uint256 delayInSeconds_) public {
        bytes memory payload = abi.encodeWithSelector(
            this.resolveTimeout.selector,
            block.timestamp
        );
        watcherPrecompile__().setTimeout(delayInSeconds_, payload);
    }

    function resolveTimeout(uint256 creationTimestamp_) external onlyWatcherPrecompile {
        emit TimeoutResolved(creationTimestamp_, block.timestamp);
    }

    // UTILS
    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external returns (uint40) {
        return _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }

    function testOnChainRevert(uint32 chainSlug) public async {
        address instance = forwarderAddresses[counter][chainSlug];
        ICounter(instance).wrongFunction();
    }

    function testCallBackRevert(uint32 chainSlug) public async {
        // the increase function is called on given list of instances
        _setOverrides(Read.ON, Parallel.ON);
        address instance = forwarderAddresses[counter][chainSlug];
        ICounter(instance).getCounter();
        // wrong function call in callback so it reverts
        IPromise(instance).then(this.withdrawFeeTokens.selector, abi.encode(chainSlug));
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) public {
        _increaseFees(requestCount_, newMaxFees_);
    }
}
