import { config as dotenvConfig } from "dotenv";
dotenvConfig();
import { ChainSlug, DeploymentMode, version } from "@socket.tech/dl-core";
import { ethers } from "ethers";

export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

export const logConfig = () => {
  console.log(
    "================================================================================================================"
  );
  console.log("");
  console.log(`Mode: ${mode}`);
  console.log(`Version: ${version[mode]}`);
  console.log("");
  console.log(
    `Make sure ${mode}_addresses.json and ${mode}_verification.json is cleared for given networks if redeploying!!`
  );
  console.log("");
  console.log(
    "================================================================================================================"
  );
};

export const chains: Array<ChainSlug> = [
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.OPTIMISM_SEPOLIA,
  // ChainSlug.SEPOLIA,
  // BASE_SEPOLIA_CHAIN_ID as ChainSlug,
];

export const auctionEndDelaySeconds = 0;
export const watcher = "0xb62505feacC486e809392c65614Ce4d7b051923b";
export const MAX_FEES = ethers.utils.parseEther("0.001");
export const EVMX_CHAIN_ID = 7625382;
export const MAX_LIMIT = 100;
export const BID_TIMEOUT = 600;
export const EXPIRY_TIME = 300;
export const UPGRADE_VERSION = 1;
