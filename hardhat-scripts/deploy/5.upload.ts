import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import {
  ChainAddressesObj,
  DeploymentMode,
  EVMxAddressesObj,
  chainSlugToHardhatChainName,
  ChainSlug
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

const supportedChainSlugs = [EVMX_CHAIN_ID as ChainSlug, ...chains];

export let config: S3Config = {
  //@ts-ignore
  supportedChainSlugs,
};

// Add config for each supported chain
supportedChainSlugs.forEach(chainSlug => {
  let chainName =
    chainSlug === EVMX_CHAIN_ID ? "EVMX" : chainSlugToHardhatChainName[chainSlug].toString().replace("-", "_");
  let rpcKey = `${chainName.toUpperCase()}_RPC`;
  let wssRpcKey = `${chainName.toUpperCase()}_WSS_RPC`;
  if (!process.env[rpcKey] || !process.env[wssRpcKey]) {
    console.log(`Missing RPC or WSS RPC for chain ${chainName}`);
    return;
  }
  config[chainSlug] = {
    eventBlockRangePerCron: 5000,
    rpc: process.env[rpcKey],
    wssRpc: process.env[wssRpcKey],
    confirmations: 0,
    eventBlockRange: 5000,
  };
});
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
