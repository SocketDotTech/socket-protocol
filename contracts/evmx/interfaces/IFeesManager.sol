// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.21;

interface IFeesManager {
    // native to credit
    function wrap() external payable;

    function unwrap(uint256 amount) external;

    // credits from vault
    function depositCredits(
        address token,
        address from,
        uint32 chainSlug,
        bytes calldata watcherSignature
    ) external payable;

    function getAvailableCredits(address user) external view returns (uint256);

    // withdraw credits onchain
    // finalize and release sign, no AM needed, can be used by watcher and transmitter
    function withdrawCreditsTo(
        uint32 chainSlug,
        address to,
        uint256 amount,
        bool needAuction
    ) external;

    function withdrawNativeTo(
        uint32 chainSlug,
        address to,
        uint256 amount,
        bool needAuction
    ) external;

    // Fee settlement
    // if addr(0) then settle to original user, onlyWatcherPrecompile can call
    function settleFees(uint40 requestId, address transmitter) external;

    // onlyWatcherPrecompile, request's AM can call
    function blockCredits(uint40 requestId, address user, uint256 amount) external;

    // onlyWatcherPrecompile, request's AM can call
    function unblockCredits(uint40 requestId, address user, uint256 amount) external;

    // msg sender should be user whitelisted app gateway
    function deductCredits(address user, uint256 amount) external;

    // whitelist
    function whitelistAppGatewayWithSignature(bytes calldata signature) external;

    function whitelistAppGateways(address[] calldata appGateways) external;
}
