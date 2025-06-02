import { ChainSlug, Contracts } from "../../src";
import fs from "fs";
import path from "path";
import { EVMX_CHAIN_ID, mode } from "../config/config";
import { getAddresses } from "../utils";
import { getFeeTokens } from "../constants";

const envFilePath = path.join(__dirname, "../../.env");
const encoding = "utf8";

// Read the .env file
const envContent = fs.readFileSync(envFilePath, encoding);

// Parse the .env content into an array of lines
const lines = envContent.split("\n");

// Get the latest addresses
const latestAddresses = getAddresses(mode);
const latestEVMxAddresses = latestAddresses[EVMX_CHAIN_ID];

// Create a new array to hold the updated lines
const updatedLines = lines.map((line) => {
  if (line.startsWith("ADDRESS_RESOLVER=")) {
    return `ADDRESS_RESOLVER=${latestEVMxAddresses[Contracts.AddressResolver]}`;
  } else if (line.startsWith("WATCHER=")) {
    return `WATCHER=${latestEVMxAddresses[Contracts.Watcher]}`;
  } else if (line.startsWith("AUCTION_MANAGER=")) {
    return `AUCTION_MANAGER=${latestEVMxAddresses[Contracts.AuctionManager]}`;
  } else if (line.startsWith("FEES_MANAGER=")) {
    return `FEES_MANAGER=${latestEVMxAddresses[Contracts.FeesManager]}`;
  } else if (line.startsWith("ARBITRUM_SOCKET=")) {
    return `ARBITRUM_SOCKET=${
      latestAddresses[ChainSlug.ARBITRUM_SEPOLIA][Contracts.Socket]
    }`;
  } else if (line.startsWith("ARBITRUM_SWITCHBOARD=")) {
    return `ARBITRUM_SWITCHBOARD=${
      latestAddresses[ChainSlug.ARBITRUM_SEPOLIA][Contracts.FastSwitchboard]
    }`;
  } else if (
    line.startsWith("ARBITRUM_FEES_PLUG=") &&
    latestAddresses[ChainSlug.ARBITRUM_SEPOLIA][Contracts.FeesPlug]
  ) {
    return `ARBITRUM_FEES_PLUG=${
      latestAddresses[ChainSlug.ARBITRUM_SEPOLIA][Contracts.FeesPlug]
    }`;
  } else if (
    line.startsWith("ARBITRUM_TEST_USDC=") &&
    getFeeTokens(mode, ChainSlug.ARBITRUM_SEPOLIA).length > 0
  ) {
    return `ARBITRUM_TEST_USDC=${
      getFeeTokens(mode, ChainSlug.ARBITRUM_SEPOLIA)[0]
    }`;
  }
  return line; // Return the line unchanged if it doesn't match any of the above
});

// Join the updated lines back into a single string
const newEnvContent = updatedLines.join("\n");

// Write the new .env content back to the file
fs.writeFileSync(envFilePath, newEnvContent, encoding);

console.log(".env file updated successfully");
