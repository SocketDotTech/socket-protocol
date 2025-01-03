const fs = require('fs');
const path = require('path');

// Read script name from command-line arguments
const scriptName = process.argv[2]; // The argument passed to the script
if (!scriptName) {
  console.error('Usage: node checkTransactions.js <scriptName>');
  console.error('Example: node checkTransactions.js deployOnchain');
  process.exit(1);
}

// Construct the JSON file path dynamically
const jsonFilePath = path.join(
  'broadcast',
  `${scriptName}.s.sol`,
  '7625382',
  'run-latest.json'
);

// Validate that the file exists
if (!fs.existsSync(jsonFilePath)) {
  console.error(`Error: File not found at path '${jsonFilePath}'.`);
  process.exit(1);
}

// Load JSON file
const jsonData = JSON.parse(fs.readFileSync(jsonFilePath, 'utf-8'));

// Extract transaction hashes
const transactions = jsonData.transactions.map(tx => tx.hash);
console.log(`Found ${transactions.length} transactions to process.`);

const apiUrl = 'https://apiv2.dev.socket.tech/getDetailsByTxHash?txHash=';
let intervalId;

// Track statuses for each hash
let statusTracker = transactions.map(hash => ({
  hash,
  status: 'PENDING',
  printed: false,
  printedPayloads: new Set()
}));
let allDonePrinted = false; // Prevent multiple prints of the final message

// Function to perform API requests
const fetchTransactionStatus = async (hash) => {
  try {
    const response = await fetch(`${apiUrl}${hash}`);
    if (!response.ok) throw new Error(`HTTP Error: ${response.status}`);
    const data = await response.json();
    return data;
  } catch (error) {
    console.error(`Error fetching status for hash ${hash}: ${error.message}`);
    return null; // Handle errors gracefully
  }
};

const processMultiplePayloads = (payloads, tx) => {
  if (payloads.length > 1) {
    payloads.forEach(payload => {
      // Create a unique key for the payload to track printed status
      const payloadKey = `${payload.executeDetails.executeTxHash}-${payload.callBackDetails.callbackStatus}`;

      if (payload.callBackDetails.callbackStatus === 'PROMISE_RESOLVED' &&
        payload.executeDetails.executeTxHash &&
        !tx.printedPayloads.has(payloadKey)) {
        console.log(`Hash: ${payload.executeDetails.executeTxHash}, Status: ${payload.callBackDetails.callbackStatus}, ChainId: ${payload.chainSlug}`);

        tx.printedPayloads.add(payloadKey);
      }
    });
  }
};

// Function to check transaction status
const checkTransactionStatus = async () => {
  let allCompleted = true;
  for (let i = 0; i < statusTracker.length; i++) {
    const tx = statusTracker[i];

    // Skip already printed transactions
    if (tx.status === 'COMPLETED' && tx.printed) continue;

    const data = await fetchTransactionStatus(tx.hash);

    if (data && data.status === 'SUCCESS') {
      if (data.response.length === 0) {
        if (tx.printed === false) {
          console.log(`Hash: ${tx.hash}, There are no logs for this transaction hash.`);
          tx.status = 'NO_LOGS';
          tx.printed = true;
          continue;
        } else {
          continue;
        }
      }

      const transactionResponse = data.response[0]; // First response object
      const status = transactionResponse.status || 'UNKNOWN';
      const payloads = transactionResponse.payloads || [];

      // Update tracker
      tx.status = status;
      if (status === 'COMPLETED' && !tx.printed) {
        processMultiplePayloads(payloads, tx);

        const deployerDetails = payloads[0].deployerDetails || {};

        if (Object.keys(deployerDetails).length !== 0) {
          console.log(`Hash: ${tx.hash}, Status: ${status}, ChainId: ${payloads[0].chainSlug}`);
          console.log(`OnChainAddress: ${deployerDetails.onChainAddress}`);
          console.log(`ForwarderAddress: ${deployerDetails.forwarderAddress}`);
        } else {
          console.log(`Hash: ${tx.hash}, Status: ${status}, ChainId: 7625382`);
        }

        tx.printed = true;
      }
      else if (status === 'IN_PROGRESS') {
        processMultiplePayloads(payloads, tx);
      }
    } else {
      console.error(`Invalid or empty response for hash: ${tx.hash}`);
    }

    // Check if any are still pending
    if (tx.status !== 'COMPLETED' && tx.status !== 'NO_LOGS') allCompleted = false;
  }

  // Stop script and print final message if all transactions are COMPLETED
  if (allCompleted && !allDonePrinted) {
    console.log('All transactions are COMPLETED. Stopping script.');
    allDonePrinted = true; // Prevent duplicate final messages
    clearInterval(intervalId);
  }
};

// Start periodic polling every second
console.log('Starting to monitor transaction statuses...');
intervalId = setInterval(checkTransactionStatus, 2000);
