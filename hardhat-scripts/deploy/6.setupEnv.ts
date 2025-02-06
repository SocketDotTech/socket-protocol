import fs from "fs";
import dev_addresses from "../../deployments/dev_addresses.json";
import { OFF_CHAIN_VM_CHAIN_ID } from "../constants/constants";
import path from "path";
import { ChainSlug } from "@socket.tech/dl-core";

const envFilePath = path.join(__dirname, "../../.env");
const encoding = "utf8";

// Read the .env file
const envContent = fs.readFileSync(envFilePath, encoding);

// Parse the .env content into an array of lines
const lines = envContent.split("\n");

// Get the latest addresses from dev_addresses
const latestAddresses = dev_addresses[OFF_CHAIN_VM_CHAIN_ID];

// Create a new array to hold the updated lines
const updatedLines = lines.map((line) => {
  if (line.startsWith("ADDRESS_RESOLVER=")) {
    return `ADDRESS_RESOLVER=${latestAddresses["AddressResolver"]}`;
  } else if (line.startsWith("WATCHER_PRECOMPILE=")) {
    return `WATCHER_PRECOMPILE=${latestAddresses["WatcherPrecompile"]}`;
  } else if (line.startsWith("AUCTION_MANAGER=")) {
    return `AUCTION_MANAGER=${latestAddresses["AuctionManager"]}`;
  } else if (line.startsWith("SOCKET=")) {
    return `SOCKET=${dev_addresses[ChainSlug.ARBITRUM_SEPOLIA]["Socket"]}`;
  } else if (line.startsWith("SWITCHBOARD=")) {
    return `SWITCHBOARD=${
      dev_addresses[ChainSlug.ARBITRUM_SEPOLIA]["FastSwitchboard"]
    }`;
  }
  return line; // Return the line unchanged if it doesn't match any of the above
});

// Join the updated lines back into a single string
const newEnvContent = updatedLines.join("\n");

// Write the new .env content back to the file
fs.writeFileSync(envFilePath, newEnvContent, encoding);

console.log(".env file updated successfully");
