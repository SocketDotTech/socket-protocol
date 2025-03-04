import {
  ChainSlug,
  ChainAddressesObj,
  DeploymentMode,
} from "@socket.tech/socket-protocol-common";

import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { constants, Wallet } from "ethers";
import { ethers } from "hardhat";
import { chains, EVMX_CHAIN_ID, mode } from "../config";
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  EVMxCoreContracts,
} from "../constants";
import {
  getAddresses,
  getInstance,
  getProviderFromChainSlug,
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

      const providerInstance = getProviderFromChainSlug(chain);
      const signer: Wallet = new ethers.Wallet(
        process.env.SOCKET_SIGNER_KEY as string,
        providerInstance
      );

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

      const remoteChain =
        chain.toString() == "420120000"
          ? (420120001 as ChainSlug)
          : (420120000 as ChainSlug);

      await addRemoteAddress(
        chainAddresses[CORE_CONTRACTS.OpInteropSwitchboard],
        addresses[remoteChain]?.[CORE_CONTRACTS.OpInteropSwitchboard],
        chain,
        signer,
        socketContract
      );

      await setSwitchboard(
        chain,
        addresses,
        "FAST",
        CORE_CONTRACTS.FastSwitchboard
      );

      if (chainAddresses[CORE_CONTRACTS.OpInteropSwitchboard]) {
        await setSwitchboard(
          chain,
          addresses,
          "OP_INTEROP",
          CORE_CONTRACTS.OpInteropSwitchboard
        );

        await registerSb(
          chainAddresses[CORE_CONTRACTS.OpInteropSwitchboard],
          signer,
          socketContract
        );
      }

      await setOnchainContracts(chain, addresses);
      await storeAddresses(chainAddresses, chain, mode);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

async function setOnchainContracts(chain, addresses) {
  const providerInstance = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);
  const signer: Wallet = new ethers.Wallet(
    process.env.WATCHER_PRIVATE_KEY as string,
    providerInstance
  );
  const EVMxAddresses = addresses[EVMX_CHAIN_ID]!;
  const watcherPrecompile = (
    await getInstance(
      EVMxCoreContracts.WatcherPrecompile,
      EVMxAddresses[EVMxCoreContracts.WatcherPrecompile]
    )
  ).connect(signer);

  const socketAddress = addresses[chain][CORE_CONTRACTS.Socket];
  const contractFactoryPlugAddress =
    addresses[chain][CORE_CONTRACTS.ContractFactoryPlug];
  const feesPlugAddress = addresses[chain][CORE_CONTRACTS.FeesPlug];
  const currentSocket = await watcherPrecompile.sockets(chain);
  const currentContractFactoryPlug =
    await watcherPrecompile.contractFactoryPlug(chain);
  const currentFeesPlug = await watcherPrecompile.feesPlug(chain);

  if (
    currentSocket.toLowerCase() !== socketAddress.toLowerCase() ||
    currentContractFactoryPlug.toLowerCase() !==
    contractFactoryPlugAddress.toLowerCase() ||
    currentFeesPlug.toLowerCase() !== feesPlugAddress.toLowerCase()
  ) {
    const tx = await watcherPrecompile
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
}

async function setSwitchboard(chain, addresses, sbType, contractName) {
  const providerInstance = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);
  const signer: Wallet = new ethers.Wallet(
    process.env.WATCHER_PRIVATE_KEY as string,
    providerInstance
  );
  const EVMxAddresses = addresses[EVMX_CHAIN_ID]!;
  const watcherPrecompile = (
    await getInstance(
      EVMxCoreContracts.WatcherPrecompile,
      EVMxAddresses[EVMxCoreContracts.WatcherPrecompile]
    )
  ).connect(signer);

  const sbTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(sbType));
  const sbAddress = addresses[chain][contractName];
  const currentSbAddress = await watcherPrecompile.switchboards(
    chain,
    sbTypeHash
  );

  if (currentSbAddress.toLowerCase() !== sbAddress.toLowerCase()) {
    const tx = await watcherPrecompile
      .connect(signer)
      .setSwitchboard(chain, sbTypeHash, sbAddress);

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

const addRemoteAddress = async (
  sbAddress,
  remoteAddress,
  chain,
  signer,
  socket
) => {
  try {
    // used fast switchboard here as all have same function signature
    const switchboard = (
      await getInstance(CORE_CONTRACTS.OpInteropSwitchboard, sbAddress)
    ).connect(signer);

    // send overrides while reading capacitor to avoid errors on mantle chain
    // some chains give balance error if gas price is used with from address as zero
    // therefore override from address as well
    const remoteAddressContract = await socket.remoteAddress();
    if (remoteAddressContract == constants.AddressZero) {
      console.log(
        `Adding remote address ${remoteAddress} to Switchboard ${sbAddress} on ${chain}`
      );
      const registerTx = await switchboard.setRemoteAddress(remoteAddress);

      console.log(`Tx: ${registerTx.hash}`);
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
