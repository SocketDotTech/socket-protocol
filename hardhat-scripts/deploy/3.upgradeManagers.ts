import { ChainAddressesObj, ChainSlug, EVMxAddressesObj } from "../../src";

import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { Wallet } from "ethers";
import { chains, EVMX_CHAIN_ID, mode } from "../config";
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  EVMxCoreContracts,
  FAST_SWITCHBOARD_TYPE,
} from "../constants";
import {
  getAddresses,
  getInstance,
  getSocketSigner,
  getWatcherSigner,
  storeAddresses,
} from "../utils";

export const main = async () => {
  let addresses: DeploymentAddresses;
  try {
    console.log("Upgrading Managers");
    addresses = getAddresses(mode) as unknown as DeploymentAddresses;

    for (const chain of chains) {
      let chainAddresses: ChainAddressesObj = addresses[chain]
        ? (addresses[chain] as ChainAddressesObj)
        : ({} as ChainAddressesObj);

      const signer: Wallet = getSocketSigner(chain as ChainSlug);

      const socketContract = (
        await getInstance(
          CORE_CONTRACTS.Socket,
          chainAddresses[CORE_CONTRACTS.Socket]
        )
      ).connect(signer);

      await registerSb(
        chainAddresses[CORE_CONTRACTS.FastSwitchboard],
        signer,
        socketContract
      );

      await setOnchainContracts(chain, addresses);

      await storeAddresses(chainAddresses, chain, mode);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

async function setOnchainContracts(chain: number, addresses) {
  const signer: Wallet = getWatcherSigner();
  const EVMxAddresses = addresses[EVMX_CHAIN_ID] as EVMxAddressesObj;
  const chainAddresses = addresses[chain] as ChainAddressesObj;
  const watcherPrecompileConfig = (
    await getInstance(
      EVMxCoreContracts.WatcherPrecompileConfig,
      EVMxAddresses[EVMxCoreContracts.WatcherPrecompileConfig]
    )
  ).connect(signer);

  const sbAddress = chainAddresses[CORE_CONTRACTS.FastSwitchboard];
  const socketAddress = chainAddresses[CORE_CONTRACTS.Socket];
  const contractFactoryPlugAddress =
    chainAddresses[CORE_CONTRACTS.ContractFactoryPlug];
  const feesPlugAddress = chainAddresses[CORE_CONTRACTS.FeesPlug];

  const currentSbAddress = await watcherPrecompileConfig.switchboards(
    chain,
    FAST_SWITCHBOARD_TYPE
  );
  const currentSocket = await watcherPrecompileConfig.sockets(chain);
  const currentContractFactoryPlug =
    await watcherPrecompileConfig.contractFactoryPlug(chain);
  const currentFeesPlug = await watcherPrecompileConfig.feesPlug(chain);

  console.log("Setting onchain contracts for", chain);
  if (
    currentSocket.toLowerCase() !== socketAddress.toLowerCase() ||
    currentContractFactoryPlug.toLowerCase() !==
      contractFactoryPlugAddress.toLowerCase() ||
    currentFeesPlug.toLowerCase() !== feesPlugAddress.toLowerCase()
  ) {
    const tx = await watcherPrecompileConfig
      .connect(signer)
      .setOnChainContracts(
        chain,
        socketAddress,
        contractFactoryPlugAddress,
        feesPlugAddress
      );

    console.log(`Setting onchain contracts for ${chain}, txHash: `, tx.hash);
    await tx.wait();
  }

  console.log("Setting switchboard for", chain);
  if (currentSbAddress.toLowerCase() !== sbAddress.toLowerCase()) {
    const tx = await watcherPrecompileConfig
      .connect(signer)
      .setSwitchboard(chain, FAST_SWITCHBOARD_TYPE, sbAddress);

    console.log(`Setting switchboard for ${chain}, txHash: `, tx.hash);
    await tx.wait();
  }
}

const registerSb = async (sbAddress, signer, socket) => {
  try {
    // used fast switchboard here as all have same function signature
    const switchboard = (
      await getInstance(CORE_CONTRACTS.FastSwitchboard, sbAddress)
    ).connect(signer);

    // send overrides while reading capacitor to avoid errors on mantle chain
    // some chains give balance error if gas price is used with from address as zero
    // therefore override from address as well
    let sb = await socket.isValidSwitchboard(sbAddress, {
      from: signer.address,
    });

    if (Number(sb) == 0) {
      const registerTx = await switchboard.registerSwitchboard();
      console.log(`Registering Switchboard ${sbAddress}: ${registerTx.hash}`);
      await registerTx.wait();
    }
  } catch (error) {
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
