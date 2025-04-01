import { ethers } from "ethers";
import fs from "fs";
import { artifacts } from "hardhat";
import path from "path";

async function main() {
  console.log("Event Topics:\n");

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

    // Get all contracts and interfaces in file
    const matches = content.matchAll(
      /(?:abstract\s+)?(?:contract|interface)\s+(\w+)(?:\s+is\s+[\w,\s]+)?{/g
    );
    const contractsInFile = Array.from(matches).map((match) => ({
      name: match[1],
      isAbstract: match[0].startsWith("abstract"),
    }));

    // Skip if all contracts in file are abstract
    if (contractsInFile.every((c) => c.isAbstract)) {
      console.log("Skipping file with only abstract contracts:", file);
      continue;
    }

    // Add non-abstract contracts and interfaces
    const validContracts = contractsInFile.filter((c) => !c.isAbstract);
    contracts.push(...validContracts.map((c) => c.name));
  }

  let mdContent = "# Event Topics\n\n";

  for (const contractName of contracts) {
    console.log(`\n${contractName}:`);
    console.log("-".repeat(contractName.length + 1));

    mdContent += `## ${contractName}\n\n`;
    mdContent += "| Event | Arguments | Topic |\n";
    mdContent += "| ----- | --------- | ----- |\n";

    const artifact = await artifacts.readArtifact(contractName);
    const iface = new ethers.utils.Interface(artifact.abi);

    const events = iface.events;
    Object.values(events).forEach((event) => {
      const topic = iface.getEventTopic(event.name);
      const args = event.inputs
        .map((input) => `${input.name}: ${input.type}`)
        .join(", ");
      console.log(`${event.name}(${args}): ${topic}`);
      mdContent += `| \`${event.name}\` | \`(${args})\` | \`${topic}\` |\n`;
    });

    mdContent += "\n";
  }

  // Write to file
  const outputPath = path.join(__dirname, "../../EventTopics.md");
  fs.writeFileSync(outputPath, mdContent);
  console.log("\nEvent topics written to EventTopics.md");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
