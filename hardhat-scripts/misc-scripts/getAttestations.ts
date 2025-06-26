import { ethers } from "ethers";
import axios from "axios";

async function getAttestation(messageHash: string): Promise<string | null> {
  try {
    const response = await axios.get(
      `https://iris-api-sandbox.circle.com/v1/attestations/${messageHash}`
    );
    console.log("messageHash", messageHash, "response", response.data);
    if (response.data.status === "complete") {
      return response.data.attestation;
    }
    return null;
  } catch (error) {
    return null;
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 2) {
    console.log("Usage: ts-node getAttestations.ts <txHash> <providerUrl>");
    process.exit(1);
  }

  const [txHash, providerUrl] = args;
  const provider = new ethers.providers.JsonRpcProvider(providerUrl);

  // Get transaction receipt
  const receipt = await provider.getTransactionReceipt(txHash);

  // ABI for MessageSent event
  const messageTransmitterInterface = new ethers.utils.Interface([
    "event MessageSent(bytes message)",
  ]);

  // Filter logs for MessageSent event
  const messageSentLogs = receipt.logs.filter((log) => {
    try {
      const parsedLog = messageTransmitterInterface.parseLog(log);
      return parsedLog.name === "MessageSent";
    } catch {
      return false;
    }
  });

  if (messageSentLogs.length === 0) {
    console.log("No MessageSent events found in transaction");
    process.exit(1);
  }

  const messages: string[] = [];
  const messageHashes: string[] = [];
  const attestations: string[] = [];

  // Get messages and calculate hashes
  for (const log of messageSentLogs) {
    const parsedLog = messageTransmitterInterface.parseLog(log);
    const message = parsedLog.args.message;
    const messageHash = ethers.utils.keccak256(message);

    messages.push(message);
    messageHashes.push(messageHash);
  }

  // Poll for attestations
  let complete = false;
  while (!complete) {
    complete = true;

    for (let i = 0; i < messageHashes.length; i++) {
      if (!attestations[i]) {
        const attestation = await getAttestation(messageHashes[i]);
        if (attestation) {
          attestations[i] = attestation;
        } else {
          complete = false;
        }
      }
    }

    if (!complete) {
      console.log("Waiting for attestations...");
      await new Promise((resolve) => setTimeout(resolve, 5000)); // Wait 5 seconds
    }
  }

  console.log("\nMessages:", messages);
  console.log("\nAttestations:", attestations);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
