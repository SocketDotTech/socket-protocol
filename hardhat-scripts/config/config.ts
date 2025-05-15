import { config as dotenvConfig } from "dotenv";
dotenvConfig();
import { ethers, utils } from "ethers";
import { ChainSlug, DeploymentMode } from "../../src";

export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

export const logConfig = () => {
  console.log(
    "================================================================================================================"
  );
  console.log("");
  console.log(`Mode: ${mode}`);
  console.log("");
  console.log(
    `Make sure ${mode}_addresses.json and ${mode}_verification.json is cleared for given networks if redeploying!!`
  );
  console.log("");
  console.log(
    "================================================================================================================"
  );
};

export const getChains = () => {
  switch (mode) {
    case DeploymentMode.LOCAL:
      // return [ChainSlug.ARBITRUM_SEPOLIA, ChainSlug.OPTIMISM_SEPOLIA, ChainSlug.SOLANA_DEVNET];
      return [ChainSlug.ARBITRUM_SEPOLIA, ChainSlug.OPTIMISM_SEPOLIA];
    case DeploymentMode.DEV:
      return [ChainSlug.ARBITRUM_SEPOLIA, ChainSlug.OPTIMISM_SEPOLIA];
    case DeploymentMode.STAGE:
      return [
        ChainSlug.OPTIMISM_SEPOLIA,
        ChainSlug.ARBITRUM_SEPOLIA,
        ChainSlug.BASE_SEPOLIA,
      ];
    case DeploymentMode.PROD:
      return [
        ChainSlug.OPTIMISM_SEPOLIA,
        ChainSlug.ARBITRUM_SEPOLIA,
        ChainSlug.BASE_SEPOLIA,
        ChainSlug.SEPOLIA,
      ];
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

export const chains: Array<ChainSlug> = getChains();
export const EVM_CHAIN_ID_MAP: Record<DeploymentMode, number> = {
  [DeploymentMode.LOCAL]: 7625382,
  [DeploymentMode.DEV]: 7625382,
  [DeploymentMode.STAGE]: 43,
  [DeploymentMode.PROD]: 3605,
};
// Addresses
export const watcher = "0xb62505feacC486e809392c65614Ce4d7b051923b";
export const transmitter = "0x138e9840861C983DC0BB9b3e941FB7C0e9Ade320";

// Chain config
export const EVMX_CHAIN_ID = EVM_CHAIN_ID_MAP[mode];
export const MAX_FEES = ethers.utils.parseEther("0.001");

// Auction parameters
export const auctionEndDelaySeconds = 0;
export const BID_TIMEOUT = 600; // 10 minutes
export const EXPIRY_TIME = 300; // 5 minutes
export const MAX_RE_AUCTION_COUNT = 5;
export const AUCTION_MANAGER_FUNDING_AMOUNT = ethers.utils.parseEther("100");
// TestUSDC
export const TEST_USDC_NAME = "testUSDC";
export const TEST_USDC_SYMBOL = "testUSDC";
export const TEST_USDC_INITIAL_SUPPLY = ethers.utils.parseEther(
  "1000000000000000000000000"
);
export const TEST_USDC_DECIMALS = 6;

// Watcher Precompile Fees
export const QUERY_FEES = utils.parseEther("0.000001");
export const FINALIZE_FEES = utils.parseEther("0.000001");
export const TIMEOUT_FEES = utils.parseEther("0.000001");
export const CALLBACK_FEES = utils.parseEther("0.000001");

// Other constants
export const DEFAULT_MAX_LIMIT = 100;
export const UPGRADE_VERSION = 1;
