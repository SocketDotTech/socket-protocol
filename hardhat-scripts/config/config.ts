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
      return [ChainSlug.ARBITRUM_SEPOLIA, ChainSlug.OPTIMISM_SEPOLIA];
    case DeploymentMode.DEV:
      return [ChainSlug.ARBITRUM_SEPOLIA, ChainSlug.OPTIMISM_SEPOLIA];
    case DeploymentMode.STAGE:
      return [
        ChainSlug.OPTIMISM_SEPOLIA,
        ChainSlug.ARBITRUM_SEPOLIA,
        ChainSlug.BASE_SEPOLIA,
        ChainSlug.BASE,
        ChainSlug.ARBITRUM,
        ChainSlug.OPTIMISM,
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

export const getFeesPlugChains = (): Array<ChainSlug> => {
  switch (mode) {
    case DeploymentMode.LOCAL:
      return getChains();
    case DeploymentMode.DEV:
      return getChains();
    case DeploymentMode.STAGE:
      return [
        ChainSlug.OPTIMISM,
        ChainSlug.ARBITRUM,
        ChainSlug.BASE,
      ];
    case DeploymentMode.PROD:
      return getChains();
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

export const testnetChains: Array<ChainSlug> = [
  ChainSlug.OPTIMISM_SEPOLIA,
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.BASE_SEPOLIA,
];
export const mainnetChains: Array<ChainSlug> = [
  ChainSlug.OPTIMISM,
  ChainSlug.ARBITRUM,
  ChainSlug.BASE,
];

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
export const MAX_MSG_VALUE_LIMIT = ethers.utils.parseEther("0.001");

// Auction parameters
export const AUCTION_END_DELAY_SECONDS = 0;
export const BID_TIMEOUT = 600; // 10 minutes
export const EXPIRY_TIME = 300; // 5 minutes
export const MAX_RE_AUCTION_COUNT = 5;

// Fees Pool Funding Amount
export const FEES_POOL_FUNDING_AMOUNT_THRESHOLD =
  ethers.utils.parseEther("1000");

// Watcher Precompile Fees
export const READ_FEES = utils.parseEther("0.000001");
export const TRIGGER_FEES = utils.parseEther("0.000001");
export const WRITE_FEES = utils.parseEther("0.000001");
export const SCHEDULE_FEES_PER_SECOND = utils.parseEther("0.00000001");
export const SCHEDULE_CALLBACK_FEES = utils.parseEther("0.000001");
export const MAX_SCHEDULE_DELAY_SECONDS = 60 * 60 * 24;

// Other constants
export const UPGRADE_VERSION = 1;

// Transmitter constants
export const TRANSMITTER_CREDIT_THRESHOLD = ethers.utils.parseEther("100"); // 100 ETH threshold
export const TRANSMITTER_NATIVE_THRESHOLD = ethers.utils.parseEther("100"); // 100 ETH threshold
