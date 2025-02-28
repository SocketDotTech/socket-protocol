import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import {
  ChainAddressesObj,
  EVMxAddressesObj,
  ChainSlug,
  DeploymentMode,
} from "@socket.tech/socket-protocol-common";
import { config as dotenvConfig } from "dotenv";
import fs from "fs";
import path from "path";
import { EVMX_CHAIN_ID, mode, chains } from "../config/config";

dotenvConfig();

const getBucketName = () => {
  switch (mode) {
    case DeploymentMode.DEV:
      return "socketpoc";
    case DeploymentMode.STAGE:
      return "socket-stage";
    case DeploymentMode.PROD:
      return "socket-prod";
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

const getFileName = () => {
  switch (mode) {
    case DeploymentMode.DEV:
      return "devConfig.json";
    case DeploymentMode.STAGE:
      return "stageConfig.json";
    case DeploymentMode.PROD:
      return "prodConfig.json";
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

const getAddressesPath = () => {
  switch (mode) {
    case DeploymentMode.DEV:
      return "../../deployments/dev_addresses.json";
    case DeploymentMode.STAGE:
      return "../../deployments/stage_addresses.json";
    case DeploymentMode.PROD:
      return "../../deployments/prod_addresses.json";
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};
type ConfigEntry = {
  eventBlockRangePerCron: number;
  rpc: string | undefined;
  wssRpc: string | undefined;
  confirmations: number;
  eventBlockRange: number;
  addresses?: ChainAddressesObj | EVMxAddressesObj;
};

type S3Config = {
  [chainId: string]: ConfigEntry;
};
export let config: S3Config = {
  [ChainSlug.ARBITRUM_SEPOLIA]: {
    eventBlockRangePerCron: 5000,
    rpc: process.env.ARBITRUM_SEPOLIA_RPC,
    wssRpc: process.env.ARBITRUM_SEPOLIA_WSS_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  [ChainSlug.OPTIMISM_SEPOLIA]: {
    eventBlockRangePerCron: 5000,
    rpc: process.env.OPTIMISM_SEPOLIA_RPC,
    wssRpc: process.env.OPTIMISM_SEPOLIA_WSS_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  [ChainSlug.SEPOLIA]: {
    eventBlockRangePerCron: 5000,
    rpc: process.env.SEPOLIA_RPC,
    wssRpc: process.env.SEPOLIA_WSS_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  [EVMX_CHAIN_ID]: {
    eventBlockRangePerCron: 5000,
    rpc: process.env.EVMX_RPC,
    wssRpc: process.env.EVMX_WSS_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  [ChainSlug.BASE_SEPOLIA]: {
    eventBlockRangePerCron: 5000,
    rpc: process.env.BASE_SEPOLIA_RPC,
    wssRpc: process.env.BASE_SEPOLIA_WSS_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  //@ts-ignore
  supportedChainSlugs: [
    ...chains,
    EVMX_CHAIN_ID,
  ],
};
// Read the addresses.json file
const addressesPath = path.join(__dirname, getAddressesPath());
const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));

// Update config with addresses
for (const chainId in config) {
  if (addresses[chainId]) {
    console.log(`Updating addresses for chainId ${chainId}`);
    config[chainId].addresses = addresses[chainId];
  }
}
console.log(JSON.stringify(config, null, 2));
// Initialize S3 client
const s3Client = new S3Client({ region: "us-east-1" }); // Replace with your preferred region

// Function to upload to S3
async function uploadToS3(data: any, fileName: string = getFileName()) {
  const params = {
    Bucket: getBucketName(),
    Key: fileName,
    Body: JSON.stringify(data, null, 2),
    ContentType: "application/json",
  };

  try {
    const command = new PutObjectCommand(params);
    await s3Client.send(command);
    console.log(`Successfully uploaded ${fileName} to S3`);
  } catch (error) {
    console.error(`Error uploading ${fileName} to S3:`, error);
  }
}

// Upload config to S3
// uploadToS3(config, "pocConfig.json");
uploadToS3(config);
