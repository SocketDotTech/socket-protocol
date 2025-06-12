// scripts/generate-labels.ts
import fs from "fs";
import path from "path";
import { getAddresses } from "../utils/address";
import { EVMX_CHAIN_ID, mode } from "../config";

function generateFoundryLabels(chainSlug?: string) {
  // Read deployed addresses
  const deployedAddresses = getAddresses(mode);

  // Read existing foundry.toml
  const foundryPath = path.join(__dirname, "../../foundry.toml");
  let foundryContent = fs.existsSync(foundryPath)
    ? fs.readFileSync(foundryPath, "utf8")
    : "";

  // Remove existing [labels] section
  foundryContent = foundryContent.replace(/\[labels\][\s\S]*?(?=\[|$)/g, "");

  // Generate new labels section
  let labelsSection = "[labels]\n";
  const chainIds = [EVMX_CHAIN_ID];
  if (chainSlug) {
    const additionalChainId = parseInt(chainSlug, 10);
    if (isNaN(additionalChainId)) {
      console.error(`❌ Invalid chain ID: ${chainSlug}`);
      process.exit(1);
    }
    if (additionalChainId !== EVMX_CHAIN_ID) chainIds.push(additionalChainId);
  }

  for (const chainId of chainIds) {
    const chainAddresses = deployedAddresses[chainId];

    if (!chainAddresses) {
      console.error(`❌ No addresses found for chain ${chainId}`);
      continue;
    }

    // Add all addresses to the labels section
    for (const [contractName, address] of Object.entries(chainAddresses)) {
      if (typeof address === "string") {
        labelsSection += `${address} = "${contractName}"\n`;
      }
    }
    console.log(`✅ Added labels for chain ${chainId}`);
  }

  // Add APP_GATEWAY label if environment variable exists
  if (process.env.APP_GATEWAY) {
    labelsSection += `${process.env.APP_GATEWAY} = "APP_GATEWAY"\n`;
  }

  // Append labels section
  foundryContent += labelsSection;

  // Write back to foundry.toml
  fs.writeFileSync(foundryPath, foundryContent);
  console.log("✅ Updated foundry.toml with contract labels");
}

// Get chainSlug from command line arguments
const chainSlug = process.argv[2];
generateFoundryLabels(chainSlug);