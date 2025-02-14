import {
  ChainSlug,
  ChainSocketAddresses,
  CORE_CONTRACTS,
  DeploymentAddresses,
  DeploymentMode,
} from "@socket.tech/dl-core";

import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ethers } from "hardhat";
import dev_addresses from "../../deployments/dev_addresses.json";
import { chains } from "./config";
import { getProviderFromChainSlug } from "../constants";
import { Wallet } from "ethers";
import { getInstance, storeAddresses } from "./utils";
import { OffChainVMCoreContracts } from "../../src";
import { EVMX_CHAIN_ID } from "../constants/constants";

export const main = async () => {
  let addresses: DeploymentAddresses;
  try {
    console.log("Upgrading Managers");
    addresses = dev_addresses as unknown as DeploymentAddresses;

    for (const chain of chains) {
      let chainAddresses: ChainSocketAddresses = addresses[chain]
        ? (addresses[chain] as ChainSocketAddresses)
        : ({} as ChainSocketAddresses);

      const providerInstance = getProviderFromChainSlug(chain);
      const signer: Wallet = new ethers.Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );

      const socketContract = (
        await getInstance(
          "contracts/socket/Socket.sol:Socket",
          chainAddresses[CORE_CONTRACTS.Socket]
        )
      ).connect(signer);

      await registerSb(
        chainAddresses[CORE_CONTRACTS.FastSwitchboard],
        signer,
        socketContract
      );

      await setSwitchboard(
        chainAddresses[CORE_CONTRACTS.FastSwitchboard],
        chain,
        addresses
      );

      await storeAddresses(chainAddresses, chain, DeploymentMode.DEV);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

async function setSwitchboard(sbAddress, chain, addresses) {
  const providerInstance = getProviderFromChainSlug(
    EVMX_CHAIN_ID as ChainSlug
  );
  const signer: Wallet = new ethers.Wallet(
    process.env.WATCHER_PRIVATE_KEY as string,
    providerInstance
  );
  const watcherVMaddr = addresses[EVMX_CHAIN_ID]!;
  const watcherPrecompile = (
    await getInstance(
      "contracts/watcherPrecompile/WatcherPrecompile.sol:WatcherPrecompile",
      watcherVMaddr[OffChainVMCoreContracts.WatcherPrecompile]
    )
  ).connect(signer);

  const fastSBtype = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("FAST"));
  const currentValue = await watcherPrecompile.switchboards(chain, fastSBtype);
  console.log({ current: currentValue, required: sbAddress });

  if (currentValue.toLowerCase() !== sbAddress.toLowerCase()) {
    const tx = await watcherPrecompile
      .connect(signer)
      .setSwitchboard(chain, fastSBtype, sbAddress);

    console.log(`Setting sb for ${chain} to`, tx.hash);
    await tx.wait();
  }
}

const registerSb = async (sbAddress, signer, socket) => {
  try {
    // used fast switchboard here as all have same function signature
    const switchboard = (
      await getInstance(
        "contracts/socket/switchboard/FastSwitchboard.sol:FastSwitchboard",
        sbAddress
      )
    ).connect(signer);

    // send overrides while reading capacitor to avoid errors on mantle chain
    // some chains give balance error if gas price is used with from address as zero
    // therefore override from address as well
    let sb = await socket.isValidSwitchboard(sbAddress, {
      from: signer.address,
    });

    if (!sb) {
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
