// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

import "../../../../contracts/evmx/base/AppGatewayBase.sol";
import "../../../../contracts/evmx/interfaces/IForwarder.sol";
import "../../../../contracts/evmx/interfaces/IPromise.sol";
import "./Counter.sol";
import "./ICounter.sol";

contract CounterAppGateway is AppGatewayBase, Ownable {
    bytes32 public counter = _createContractId("counter");
    bytes32 public counter1 = _createContractId("counter1");

    uint256 public counterVal;
    uint256 public arbCounter;
    uint256 public optCounter;

    event CounterScheduleResolved(uint256 creationTimestamp, uint256 executionTimestamp);

    constructor(address addressResolver_, uint256 fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[counter] = abi.encodePacked(type(Counter).creationCode);
        creationCodeWithArgs[counter1] = abi.encodePacked(type(Counter).creationCode);
        _setMaxFees(fees_);
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
            then(this.setCounterValues.selector, abi.encode(chainSlug));
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
    function setIsValidPlug(uint32 chainSlug_, bytes32 contractId_) public {
        _setValidPlug(true, chainSlug_, contractId_);
    }

    function increase(uint256 value_) external onlyWatcher {
        counterVal += value_;
    }

    // Schedule
    function setSchedule(uint256 delayInSeconds_) public async {
        _setSchedule(delayInSeconds_);
        then(this.resolveSchedule.selector, abi.encode(block.timestamp));
    }

    function resolveSchedule(uint256 creationTimestamp_) external onlyPromises {
        emit CounterScheduleResolved(creationTimestamp_, block.timestamp);
    }

    // UTILS
    function setMaxFees(uint256 fees_) public {
        maxFees = fees_;
    }

    function withdrawCredits(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        uint256 maxFees_,
        address receiver_
    ) external {
        _withdrawCredits(chainSlug_, token_, amount_, maxFees_, receiver_);
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
        IPromise(instance).then(this.withdrawCredits.selector, abi.encode(chainSlug));
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) public {
        _increaseFees(requestCount_, newMaxFees_);
    }
}
