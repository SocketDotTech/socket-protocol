// scripts/generate-labels.ts
import fs from 'fs';
import path from 'path';
import { getAddresses } from '../utils';
import { mode } from '../config';


function generateFoundryLabels() {
  // Read deployed addresses
  const deployedAddresses = getAddresses(mode);

  // Read existing foundry.toml
  const foundryPath = path.join(__dirname, "../../foundry.toml");
  let foundryContent = fs.existsSync(foundryPath) 
    ? fs.readFileSync(foundryPath, 'utf8') 
    : '';

  // Remove existing [labels] section
  foundryContent = foundryContent.replace(/\[labels\][\s\S]*?(?=\[|$)/g, '');

  // Generate new labels section
  let labelsSection = '\n[labels]\n';

  // Track seen addresses to avoid duplicates
  const seenAddresses = new Set<string>();

  // Loop through each chain's addresses
  for (const [chainId, contracts] of Object.entries(deployedAddresses)) {
    // Loop through each contract in the chain
    for (const [contractName, address] of Object.entries(contracts)) {
      if (typeof address === 'string' && !seenAddresses.has(address)) {
        seenAddresses.add(address);
        labelsSection += `${address} = "${contractName}"\n`;
      }
    }
  }

  // Append labels section
  foundryContent += labelsSection;

  // Write back to foundry.toml
  fs.writeFileSync(foundryPath, foundryContent);
  console.log('✅ Updated foundry.toml with contract labels');
}

generateFoundryLabels();