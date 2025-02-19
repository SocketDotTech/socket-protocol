import fs from "fs";
import path from "path";
import { ethers } from "ethers";

// Function to recursively get all .sol files
function getSolFiles(dir: string, fileList: string[] = []): string[] {
  const files = fs.readdirSync(dir);

  files.forEach((file) => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      fileList = getSolFiles(filePath, fileList);
    } else if (path.extname(file) === ".sol") {
      fileList.push(filePath);
    }
  });

  return fileList;
}

// Function to extract event topics from contract file
function extractEventTopics(filePath: string): string[] {
  const content = fs.readFileSync(filePath, "utf8");
  const eventRegex = /event\s+(\w+)\s*\(([\s\S]*?)\);/g;
  const topics: string[] = [];

  let match;
  while ((match = eventRegex.exec(content)) !== null) {
    const eventName = match[1];
    const params = match[2]
      .split(",")
      .map((param) => param.trim().split(" ")[0]) // Extract only the type
      .join(",");
    const topic = ethers.utils.id(`${eventName}(${params})`);
    topics.push(`${eventName} -> ${topic}`);
  }

  return topics;
}

// Main function
async function main() {
  const contractsDir = path.join(__dirname, "../../contracts");
  const topicsDir = path.join(__dirname, "../../EventTopics.md");
  const solFiles = getSolFiles(contractsDir);

  console.log("Event Topics Found:");
  console.log("-------------------");

  let mdContent = "# Event Topics\n\n";

  for (const file of solFiles) {
    const topics = extractEventTopics(file);
    if (topics.length > 0) {
      console.log(`\nIn ${path.relative(contractsDir, file)}:`);
      mdContent += `\n## ${path.relative(contractsDir, file)}\n\n`;
      mdContent += "| Event | Topic |\n|-------|-------|";

      for (const topic of topics) {
        console.log(topic);
        const [eventName, topicHash] = topic.split(" -> ");
        mdContent += `\n| \`${eventName}\` | \`${topicHash}\` |`;
      }
      mdContent += "\n";
    }
  }

  // Write to EventTopics.md file
  fs.writeFileSync(topicsDir, mdContent);
  console.log("\nEvent topics have been written to EventTopics.md");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
