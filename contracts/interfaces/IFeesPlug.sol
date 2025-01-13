// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IFeesPlug {
    function balanceOf(address appGateway, address token) external view returns (uint256);
    function feesRedeemed(uint256 feesCounter) external view returns (bool);

    function deposit(address token, uint256 amount, address appGateway_) external payable;

    function connect(address appGateway_, address switchboard_) external;

    function distributeFee(
        address appGateway,
        address feeToken,
        uint256 fee,
        address transmitter,
        bytes32 feesCounter
    ) external returns (bytes memory);

    function withdrawFees(
        address appGateway,
        address token,
        uint256 amount,
        address receiver
    ) external returns (bytes memory);
}
