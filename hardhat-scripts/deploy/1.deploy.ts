import { config } from "dotenv";
config();

import { Contract, Signer, Wallet, providers } from "ethers";
import { DeployParams, getOrDeploy, storeAddresses } from "./utils";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  DeploymentMode,
} from "@socket.tech/dl-core";
import { getProviderFromChainSlug } from "../constants";
import { ethers } from "hardhat";
import dev_addresses from "../../deployments/dev_addresses.json";
import { chains } from "./config";
import { OFF_CHAIN_VM_CHAIN_ID } from "../constants/constants";
import { CORE_CONTRACTS, OffChainVMCoreContracts } from "../../src";

const main = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainSocketAddresses,
      mode: DeploymentMode.DEV,
      signer: new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string),
      currentChainSlug: OFF_CHAIN_VM_CHAIN_ID as ChainSlug,
    };
    try {
      console.log("Deploying Socket contracts");
      addresses = dev_addresses as unknown as DeploymentAddresses;
      for (const chain of chains) {
        try {
          let chainAddresses: ChainSocketAddresses = addresses[chain]
            ? (addresses[chain] as ChainSocketAddresses)
            : ({} as ChainSocketAddresses);

          const providerInstance = getProviderFromChainSlug(chain);
          const signer: Wallet = new ethers.Wallet(
            process.env.SOCKET_SIGNER_KEY as string,
            providerInstance
          );
          const socketOwner = signer.address;

          deployUtils = {
            addresses: chainAddresses,
            mode: DeploymentMode.DEV,
            signer: signer,
            currentChainSlug: chain as ChainSlug,
          };
          let contractName: string = CORE_CONTRACTS.SignatureVerifier;
          const signatureVerifier: Contract = await getOrDeploy(
            contractName,
            `contracts/socket/utils/${contractName}.sol`,
            [socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = signatureVerifier.address;

          contractName = CORE_CONTRACTS.Hasher;
          const hasher: Contract = await getOrDeploy(
            contractName,
            `contracts/socket/utils/${contractName}.sol`,
            [socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = hasher.address;

          contractName = CORE_CONTRACTS.Socket;
          const socket: Contract = await getOrDeploy(
            contractName,
            `contracts/socket/${contractName}.sol`,
            [
              chain as ChainSlug,
              hasher.address,
              signatureVerifier.address,
              socketOwner,
              "OFF_CHAIN_VM",
            ],
            deployUtils
          );
          deployUtils.addresses[contractName] = socket.address;

          contractName = CORE_CONTRACTS.SocketBatcher;
          const batcher: Contract = await getOrDeploy(
            contractName,
            `contracts/socket/${contractName}.sol`,
            [socketOwner, socket.address],
            deployUtils
          );
          deployUtils.addresses[contractName] = batcher.address;

          contractName = CORE_CONTRACTS.FastSwitchboard;
          const sb: Contract = await getOrDeploy(
            contractName,
            `contracts/socket/switchboard/${contractName}.sol`,
            [
              chain as ChainSlug,
              socket.address,
              signatureVerifier.address,
              socketOwner,
            ],
            deployUtils
          );
          deployUtils.addresses[contractName] = sb.address;

          contractName = CORE_CONTRACTS.FeesPlug;
          const feesPlug: Contract = await getOrDeploy(
            contractName,
            `contracts/apps/payload-delivery/${contractName}.sol`,
            [socket.address, socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = feesPlug.address;

          contractName = CORE_CONTRACTS.ContractFactoryPlug;
          const contractFactoryPlug: Contract = await getOrDeploy(
            contractName,
            `contracts/apps/payload-delivery/${contractName}.sol`,
            [socket.address, socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = contractFactoryPlug.address;

          deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
            ? deployUtils.addresses.startBlock
            : await deployUtils.signer.provider?.getBlockNumber();

          await storeAddresses(
            deployUtils.addresses,
            chain,
            DeploymentMode.DEV
          );
        } catch (error) {
          await storeAddresses(
            deployUtils.addresses,
            chain,
            DeploymentMode.DEV
          );
          console.log("Error:", error);
        }
      }
    } catch (error) {
      console.error("Error in main deployment:", error);
    }

    await deployWatcherVMContracts();
  } catch (error) {
    console.error("Error in overall deployment process:", error);
  }
};

async function updateContractSettings(
  contract: Contract,
  getterMethod: string,
  setterMethod: string,
  requiredAddress: string,
  signer: Signer
) {
  const currentValue = await contract.connect(signer)[getterMethod]();
  console.log({ current: currentValue, required: requiredAddress });

  if (currentValue.toLowerCase() !== requiredAddress.toLowerCase()) {
    const tx = await contract.connect(signer)[setterMethod](requiredAddress);
    console.log(`Setting ${getterMethod} for ${contract.address} to`, tx.hash);
    await tx.wait();
  }
}

const deployWatcherVMContracts = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainSocketAddresses,
      mode: DeploymentMode.DEV,
      signer: new ethers.Wallet(process.env.WATCHER_PRIVATE_KEY as string),
      currentChainSlug: OFF_CHAIN_VM_CHAIN_ID as ChainSlug,
    };
    const chain = OFF_CHAIN_VM_CHAIN_ID;
    try {
      console.log("Deploying OffChainVM contracts");
      addresses = dev_addresses as unknown as DeploymentAddresses;
      let chainAddresses: ChainSocketAddresses = addresses[chain]
        ? (addresses[chain] as ChainSocketAddresses)
        : ({} as ChainSocketAddresses);

      const providerInstance = new providers.StaticJsonRpcProvider(
        process.env.OFF_CHAIN_VM_RPC as string
      );
      const signer: Wallet = new ethers.Wallet(
        process.env.WATCHER_PRIVATE_KEY as string,
        providerInstance
      );
      const offChainVMOwner = signer.address;

      deployUtils = {
        addresses: chainAddresses,
        mode: DeploymentMode.DEV,
        signer: signer,
        currentChainSlug: chain as ChainSlug,
      };
      let contractName: string = OffChainVMCoreContracts.AddressResolver;
      let addressResolver: Contract = await getOrDeploy(
        contractName,
        `contracts/${contractName}.sol`,
        [offChainVMOwner],
        deployUtils
      );
      deployUtils.addresses[contractName] = addressResolver.address;

      contractName = OffChainVMCoreContracts.WatcherPrecompile;
      let watcherPrecompile: Contract = await getOrDeploy(
        contractName,
        `contracts/watcherPrecompile/${contractName}.sol`,
        [offChainVMOwner, addressResolver.address],
        deployUtils
      );
      deployUtils.addresses[contractName] = watcherPrecompile.address;

      contractName = OffChainVMCoreContracts.SignatureVerifier;
      const signatureVerifier: Contract = await getOrDeploy(
        contractName,
        `contracts/socket/utils/${contractName}.sol`,
        [offChainVMOwner],
        deployUtils
      );
      deployUtils.addresses[contractName] = signatureVerifier.address;

      contractName = OffChainVMCoreContracts.AuctionManager;
      let auctionManager: Contract = await getOrDeploy(
        contractName,
        `contracts/apps/payload-delivery/app-gateway/${contractName}.sol`,
        [
          OFF_CHAIN_VM_CHAIN_ID,
          addressResolver.address,
          signatureVerifier.address,
          offChainVMOwner,
        ],
        deployUtils
      );
      deployUtils.addresses[contractName] = auctionManager.address;

      contractName = OffChainVMCoreContracts.FeesManager;
      let feesManager: Contract = await getOrDeploy(
        contractName,
        `contracts/apps/payload-delivery/app-gateway/${contractName}.sol`,
        [addressResolver.address, offChainVMOwner],
        deployUtils
      );
      deployUtils.addresses[contractName] = feesManager.address;

      contractName = OffChainVMCoreContracts.DeliveryHelper;
      let deliveryHelper: Contract = await getOrDeploy(
        contractName,
        `contracts/apps/payload-delivery/app-gateway/${contractName}.sol`,
        [addressResolver.address, feesManager.address, offChainVMOwner],
        deployUtils
      );
      deployUtils.addresses[contractName] = deliveryHelper.address;

      await updateContractSettings(
        addressResolver,
        "deliveryHelper",
        "setDeliveryHelper",
        deliveryHelper.address,
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "feesManager",
        "setFeesManager",
        feesManager.address,
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "watcherPrecompile",
        "setWatcherPrecompile",
        watcherPrecompile.address,
        deployUtils.signer
      );

      // deployUtils = await deploySuperTokenAppContracts(deployUtils, signer);

      deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
        ? deployUtils.addresses.startBlock
        : await deployUtils.signer.provider?.getBlockNumber();

      await storeAddresses(
        deployUtils.addresses,
        chain as ChainSlug,
        DeploymentMode.DEV
      );
    } catch (error) {
      // await storeAddresses(
      //   deployUtils.addresses,
      //   chain as ChainSlug,
      //   DeploymentMode.DEV
      // );
      console.log("Error:", error);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
