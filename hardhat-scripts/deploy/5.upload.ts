import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { ChainSlug } from "@socket.tech/dl-core";
import { config as dotenvConfig } from "dotenv";
import fs from "fs";
import path from "path";
import { EVMX_CHAIN_ID } from "../config/config";
import {
  BASE_SEPOLIA_CHAIN_ID,
  ChainAddressesObj,
  CloudAddressesObj,
} from "../constants";

dotenvConfig();

type ConfigEntry = {
  eventBlockRangePerCron: number;
  rpc: string | undefined;
  wssRpc: string | undefined;
  confirmations: number;
  eventBlockRange: number;
  addresses?: ChainAddressesObj | CloudAddressesObj;
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
  [BASE_SEPOLIA_CHAIN_ID]: {
    eventBlockRangePerCron: 5000,
    rpc: process.env.BASE_SEPOLIA_RPC,
    wssRpc: process.env.BASE_SEPOLIA_WSS_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  //@ts-ignore
  supportedChainSlugs: [
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    // ChainSlug.SEPOLIA,
    EVMX_CHAIN_ID,
    // BASE_SEPOLIA_CHAIN_ID,
  ],
};
// Read the dev_addresses.json file
const devAddressesPath = path.join(
  __dirname,
  "../../deployments/dev_addresses.json"
);
const devAddresses = JSON.parse(fs.readFileSync(devAddressesPath, "utf8"));

// Update config with addresses
for (const chainId in config) {
  if (devAddresses[chainId]) {
    console.log(`Updating addresses for chainId ${chainId}`);
    config[chainId].addresses = devAddresses[chainId];
  }
}
console.log(JSON.stringify(config, null, 2));
// Initialize S3 client
const s3Client = new S3Client({ region: "us-east-1" }); // Replace with your preferred region

// Function to upload to S3
async function uploadToS3(data: any, fileName: string) {
  const params = {
    Bucket: "socketpoc",
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
uploadToS3(config, "pocConfig.json");
