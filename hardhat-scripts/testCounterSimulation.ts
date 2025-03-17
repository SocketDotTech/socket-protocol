import { ethers } from "hardhat";
import dotenv from "dotenv";
import { TestCounter__factory, MultiCall__factory } from "../typechain-types";

dotenv.config();

async function main() {
  // Get RPC and addresses from env
  const rpc = process.env.EVMX_RPC;
  const testCounterAddress = process.env.TEST_COUNTER_ADDRESS;
  const multiCallAddress = process.env.MULTI_CALL_ADDRESS;

  if (!rpc || !testCounterAddress || !multiCallAddress) {
    throw new Error("Required environment variables not set");
  }

  // Connect to provider
  const provider = new ethers.providers.JsonRpcProvider(rpc);
  const signer = await provider.getSigner();

  // Get contract instances
  const testCounter = TestCounter__factory.connect(testCounterAddress, signer);
  const multiCall = MultiCall__factory.connect(multiCallAddress, signer);

  console.log("Starting simulations...");

  // Simulate switchOn using MultiCall
  console.log("\nSimulating switchOn via MultiCall...");
  try {
    const switchOnData = testCounter.interface.encodeFunctionData("switchOn");
    const switchOnResult = await multiCall.callStatic.multiCall(
      [testCounterAddress],
      [switchOnData]
    );
    console.log("switchOn simulation successful");
    console.log("Result:", switchOnResult);
  } catch (error) {
    console.error("switchOn simulation failed:", error);
  }

  // Simulate switchOff using MultiCall
  console.log("\nSimulating switchOff via MultiCall...");
  try {
    const switchOffData = testCounter.interface.encodeFunctionData("switchOff");
    const switchOffResult = await multiCall.callStatic.multiCall(
      [testCounterAddress],
      [switchOffData]
    );
    console.log("switchOff simulation successful");
    console.log("Result:", switchOffResult);
  } catch (error) {
    console.error("switchOff simulation failed:", error);
  }

  // Simulate both functions in sequence using MultiCall
  console.log("\nSimulating both functions in sequence using MultiCall...");
  try {
    const targets = [testCounterAddress, testCounterAddress];
    const data = [
      testCounter.interface.encodeFunctionData("switchOn"),
      testCounter.interface.encodeFunctionData("switchOff")
    ];

    const multiCallResult = await multiCall.callStatic.multiCall(targets, data);
    console.log("Sequential MultiCall simulation successful");
    console.log("Results:", multiCallResult);
  } catch (error) {
    console.error("Sequential MultiCall simulation failed:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
