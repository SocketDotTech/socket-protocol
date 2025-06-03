import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { Contracts, EVMxAddressesObj, READ, SCHEDULE, WRITE } from "../../src";
import { Wallet } from "ethers";
import { EVMX_CHAIN_ID, mode } from "../config";
import { DeploymentAddresses } from "../constants";
import {
  getAddresses,
  getInstance,
  getWatcherSigner,
  updateContractSettings,
} from "../utils";

export const main = async () => {
  let addresses: DeploymentAddresses;
  try {
    console.log("Configuring EVMx contracts");
    addresses = getAddresses(mode) as unknown as DeploymentAddresses;
    const evmxAddresses = addresses[EVMX_CHAIN_ID] as EVMxAddressesObj;

    await configureEVMx(evmxAddresses);
  } catch (error) {
    console.log("Error:", error);
  }
};

export const configureEVMx = async (evmxAddresses: EVMxAddressesObj) => {
  const signer: Wallet = getWatcherSigner();

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.AddressResolver,
    "asyncDeployer__",
    [],
    evmxAddresses[Contracts.AsyncDeployer],
    "setAsyncDeployer",
    [evmxAddresses[Contracts.AsyncDeployer]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.AddressResolver,
    "feesManager__",
    [],
    evmxAddresses[Contracts.FeesManager],
    "setFeesManager",
    [evmxAddresses[Contracts.FeesManager]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.AddressResolver,
    "defaultAuctionManager",
    [],
    evmxAddresses[Contracts.AuctionManager],
    "setDefaultAuctionManager",
    [evmxAddresses[Contracts.AuctionManager]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.AddressResolver,
    "watcher__",
    [],
    evmxAddresses[Contracts.Watcher],
    "setWatcher",
    [evmxAddresses[Contracts.Watcher]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.AddressResolver,
    "deployForwarder__",
    [],
    evmxAddresses[Contracts.DeployForwarder],
    "setDeployForwarder",
    [evmxAddresses[Contracts.DeployForwarder]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.RequestHandler,
    "precompiles",
    [READ],
    evmxAddresses[Contracts.ReadPrecompile],
    "setPrecompile",
    [READ, evmxAddresses[Contracts.ReadPrecompile]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.RequestHandler,
    "precompiles",
    [WRITE],
    evmxAddresses[Contracts.WritePrecompile],
    "setPrecompile",
    [WRITE, evmxAddresses[Contracts.WritePrecompile]],
    signer
  );

  await updateContractSettings(
    EVMX_CHAIN_ID,
    Contracts.RequestHandler,
    "precompiles",
    [SCHEDULE],
    evmxAddresses[Contracts.SchedulePrecompile],
    "setPrecompile",
    [SCHEDULE, evmxAddresses[Contracts.SchedulePrecompile]],
    signer
  );

  await setWatcherCoreContracts(evmxAddresses);
};

export const setWatcherCoreContracts = async (
  evmxAddresses: EVMxAddressesObj
) => {
  const watcherContract = (
    await getInstance(Contracts.Watcher, evmxAddresses[Contracts.Watcher])
  ).connect(getWatcherSigner());

  const requestHandlerSet = await watcherContract.requestHandler__();
  const PromiseResolverSet = await watcherContract.promiseResolver__();
  const ConfigurationsSet = await watcherContract.configurations__();

  if (
    requestHandlerSet.toLowerCase() !==
      evmxAddresses[Contracts.RequestHandler].toLowerCase() ||
    PromiseResolverSet.toLowerCase() !==
      evmxAddresses[Contracts.PromiseResolver].toLowerCase() ||
    ConfigurationsSet.toLowerCase() !==
      evmxAddresses[Contracts.Configurations].toLowerCase()
  ) {
    console.log("Setting watcher core contracts");
    const tx = await watcherContract.setCoreContracts(
      evmxAddresses[Contracts.RequestHandler],
      evmxAddresses[Contracts.Configurations],
      evmxAddresses[Contracts.PromiseResolver]
    );
    console.log("Watcher core contracts set tx: ", tx.hash);
    await tx.wait();
  } else {
    console.log("Watcher core contracts are already set");
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
