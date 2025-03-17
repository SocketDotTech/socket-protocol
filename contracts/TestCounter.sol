pragma solidity ^0.8.0;

contract TestCounter {
    uint256 public isSwitchOn;

    constructor() {}

    function switchOn() public {
        require(isSwitchOn == 0, "Switch is already on");
        isSwitchOn = 1;
    }

    function switchOff() public {
        require(isSwitchOn == 1, "Switch is already off");
        isSwitchOn = 0;
    }

    function getIsSwitchOn() public view returns (uint256) {
        return isSwitchOn;
    }
}