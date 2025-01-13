import fs from "fs";
import dev_addresses from "../../deployments/dev_addresses.json";
import { OFF_CHAIN_VM_CHAIN_ID } from "../constants/constants";
import path from "path";
import { ChainSlug } from "@socket.tech/dl-core";

const envFilePath = path.join(__dirname, "../../.env");
const encoding = "utf8";

// Read the .env file
const envContent = fs.readFileSync(envFilePath, encoding);

// Parse the .env content into an object
const envVariables = envContent.split("\n").reduce((acc, line) => {
  const [key, value] = line.split("=");
  if (key && value) {
    acc[key] = value;
  }
  return acc;
}, {} as Record<string, string>);

// Get the latest addresses from dev_addresses
const latestAddresses = dev_addresses[OFF_CHAIN_VM_CHAIN_ID];

// Replace the addresses in the envVariables object
envVariables["ADDRESS_RESOLVER"] = latestAddresses["AddressResolver"];
envVariables["WATCHER_PRECOMPILE"] = latestAddresses["WatcherPrecompile"];
envVariables["AUCTION_MANAGER"] = latestAddresses["AuctionManager"];
envVariables["SOCKET"] = dev_addresses[ChainSlug.ARBITRUM_SEPOLIA]["Socket"];
// Convert the envVariables object back to a string
const newEnvContent = Object.entries(envVariables)
  .map(([key, value]) => `${key}=${value}`)
  .join("\n");

// Write the new .env content back to the file
fs.writeFileSync(envFilePath, newEnvContent, encoding);

console.log(".env file updated successfully");
