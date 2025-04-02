import { ethers } from "ethers";
import fs from "fs";
import { artifacts } from "hardhat";
import path from "path";

async function main() {
  console.log("Function Signatures:\n");

  // Get all contract artifacts
  const contractFiles = fs
    .readdirSync(path.join(__dirname, "../../contracts"), { recursive: true })
    .filter((file) => file.toString().endsWith(".sol"));

  const contracts: string[] = [];

  for (const file of contractFiles) {
    console.log(file);
    const content = fs.readFileSync(
      path.join(__dirname, "../../contracts", file.toString()),
      "utf8"
    );

    // Skip interfaces
    if (content.includes("interface ")) {
      console.log("Skipping interface:", file);
      continue;
    }

    // Get all contracts in file
    const contractMatches = content.matchAll(
      /(?:abstract\s+)?contract\s+(\w+)(?:\s+is\s+[\w,\s]+)?{/g
    );
    const contractsInFile = Array.from(contractMatches).map((match) => ({
      name: match[1],
      isAbstract: match[0].startsWith("abstract"),
    }));

    // Skip if all contracts in file are abstract
    if (contractsInFile.every((c) => c.isAbstract)) {
      console.log("Skipping file with only abstract contracts:", file);
      continue;
    }

    // Only add non-abstract contracts
    const nonAbstractContracts = contractsInFile.filter((c) => !c.isAbstract);
    contracts.push(...nonAbstractContracts.map((c) => c.name));
  }

  let mdContent = "# Function Signatures\n\n";

  for (const contractName of contracts) {
    console.log(`\n${contractName}:`);
    console.log("-".repeat(contractName.length + 1));

    mdContent += `## ${contractName}\n\n`;
    mdContent += "| Function | Signature |\n";
    mdContent += "| -------- | --------- |\n";

    const artifact = await artifacts.readArtifact(contractName);
    const iface = new ethers.utils.Interface(artifact.abi);

    const functions = iface.functions;
    Object.values(functions).forEach((func) => {
      const sig = iface.getSighash(func.name);
      console.log(`${func.name}: ${sig}`);
      mdContent += `| \`${func.name}\` | \`${sig}\` |\n`;
    });

    mdContent += "\n";
  }

  // Write to file
  const outputPath = path.join(__dirname, "../../FunctionSignatures.md");
  fs.writeFileSync(outputPath, mdContent);
  console.log("\nFunction signatures written to FunctionSignatures.md");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
