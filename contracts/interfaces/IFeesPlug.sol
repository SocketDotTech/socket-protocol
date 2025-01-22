// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IFeesPlug {
    function balanceOf(address appGateway_, address token_) external view returns (uint256);

    function feesRedeemed(uint256 feesCounter_) external view returns (bool);

    function deposit(address token_, uint256 amount_, address appGateway_) external payable;

    function connect(address appGateway_, address switchboard_) external;

    function distributeFee(
        address appGateway_,
        address feeToken_,
        uint256 fee_,
        address transmitter_,
        bytes32 feesCounter_
    ) external returns (bytes memory);

    function withdrawFees(
        address appGateway_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external returns (bytes memory);
}
