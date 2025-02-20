import { ChainSlug } from "@socket.tech/dl-core";
import fs from "fs";
import path from "path";
import dev_addresses from "../../deployments/dev_addresses.json";
import { EVMX_CHAIN_ID } from "../config/config";

const envFilePath = path.join(__dirname, "../../.env");
const encoding = "utf8";

// Read the .env file
const envContent = fs.readFileSync(envFilePath, encoding);

// Parse the .env content into an array of lines
const lines = envContent.split("\n");

// Get the latest addresses from dev_addresses
const latestAddresses = dev_addresses[EVMX_CHAIN_ID];

// Create a new array to hold the updated lines
const updatedLines = lines.map((line) => {
  if (line.startsWith("ADDRESS_RESOLVER=")) {
    return `ADDRESS_RESOLVER=${latestAddresses["AddressResolver"]}`;
  } else if (line.startsWith("WATCHER_PRECOMPILE=")) {
    return `WATCHER_PRECOMPILE=${latestAddresses["WatcherPrecompile"]}`;
  } else if (line.startsWith("AUCTION_MANAGER=")) {
    return `AUCTION_MANAGER=${latestAddresses["AuctionManager"]}`;
  } else if (line.startsWith("ARBITRUM_FEES_PLUG=")) {
    return `ARBITRUM_FEES_PLUG=${latestAddresses["FeesManager"]}`;
  } else if (line.startsWith("SOCKET=")) {
    return `SOCKET=${dev_addresses[ChainSlug.ARBITRUM_SEPOLIA]["Socket"]}`;
  } else if (line.startsWith("SWITCHBOARD=")) {
    return `SWITCHBOARD=${
      dev_addresses[ChainSlug.ARBITRUM_SEPOLIA]["FastSwitchboard"]
    }`;
  } else if (line.startsWith("ARBITRUM_FEES_PLUG=")) {
    return `ARBITRUM_FEES_PLUG=${
      dev_addresses[ChainSlug.ARBITRUM_SEPOLIA]["FeesPlug"]
    }`;
  }
  return line; // Return the line unchanged if it doesn't match any of the above
});

// Join the updated lines back into a single string
const newEnvContent = updatedLines.join("\n");

// Write the new .env content back to the file
fs.writeFileSync(envFilePath, newEnvContent, encoding);

console.log(".env file updated successfully");
