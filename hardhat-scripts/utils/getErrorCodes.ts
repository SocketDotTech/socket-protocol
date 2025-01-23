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

// Function to extract custom errors from contract file
function extractCustomErrors(filePath: string): string[] {
  const content = fs.readFileSync(filePath, "utf8");
  const errorRegex = /error\s+(\w+)\s*\(([\s\S]*?)\)/g;
  const errors: string[] = [];

  let match;
  while ((match = errorRegex.exec(content)) !== null) {
    const errorName = match[1];
    const params = match[2]
      .split(',')
      .map(param => param.trim().split(' ')[0]) // Extract only the type
      .join(',');
    errors.push(`${errorName}(${params})`);
  }

  return errors;
}

// Main function
async function main() {
  const contractsDir = path.join(__dirname, "../../contracts");
  const errorsDir = path.join(__dirname, "../../Errors.md");
  const solFiles = getSolFiles(contractsDir);

  console.log("Custom Errors Found:");
  console.log("-------------------");

  let mdContent = "# Custom Error Codes\n\n";

  for (const file of solFiles) {
    const errors = extractCustomErrors(file);
    if (errors.length > 0) {
      console.log(`\nIn ${path.relative(contractsDir, file)}:`);
      mdContent += `\n## ${path.relative(contractsDir, file)}\n\n`;
      mdContent += "| Error | Signature |\n|-------|-----------|";

      for (const error of errors) {
        const signature = ethers.utils.id(`${error}`).slice(0, 10);
        console.log(`${error} -> ${signature}`);
        mdContent += `\n| \`${error}\` | \`${signature}\` |`;
      }
      mdContent += "\n";
    }
  }

  // Write to Errors.md file
  fs.writeFileSync(errorsDir, mdContent);
  console.log("\nError codes have been written to Errors.md");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
