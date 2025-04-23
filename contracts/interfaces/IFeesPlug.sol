// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface IFeesPlug {
    function balanceOf(address token_) external view returns (uint256);

    function feesRedeemed(bytes32 feesId_) external view returns (bool);

    function deposit(address token_, address appGateway_, uint256 amount_) external payable;

    function distributeFee(
        address feeToken_,
        uint256 fee_,
        address transmitter_,
        bytes32 feesId_
    ) external;

    function withdrawFees(address token_, uint256 amount_, address receiver_) external;
}
