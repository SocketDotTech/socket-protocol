import { config as dotenvConfig } from "dotenv";
dotenvConfig();
import { ethers } from "ethers";
import { ChainSlug, DeploymentMode } from "@socket.tech/socket-protocol-common";

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

export const chains: Array<ChainSlug> = [
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.OPTIMISM_SEPOLIA,
  // ChainSlug.SEPOLIA,
  ChainSlug.BASE_SEPOLIA,
];
export const EVM_CHAIN_ID_MAP: Record<DeploymentMode, number> = {
  [DeploymentMode.LOCAL]: 7625382,
  [DeploymentMode.DEV]: 7625382,
  [DeploymentMode.STAGE]: 43,
  [DeploymentMode.PROD]: 3605,
}
export const auctionEndDelaySeconds = 0;
export const watcher = "0xb62505feacC486e809392c65614Ce4d7b051923b";
export const MAX_FEES = ethers.utils.parseEther("0.001");
export const EVMX_CHAIN_ID = EVM_CHAIN_ID_MAP[mode];
export const MAX_LIMIT = 100;
export const BID_TIMEOUT = 600;
export const EXPIRY_TIME = 300;
export const UPGRADE_VERSION = 1;
