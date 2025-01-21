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
import { auctionEndDelaySeconds, chains } from "./config";
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
            [],
            deployUtils
          );
          deployUtils.addresses[contractName] = signatureVerifier.address;

          await updateContractSettings(
            signatureVerifier,
            "owner",
            "initialize",
            socketOwner,
            deployUtils.signer
          );

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

  if (currentValue.toLowerCase() !== requiredAddress.toLowerCase()) {
    console.log({
      setterMethod,
      current: currentValue,
      required: requiredAddress,
    });
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

      // Deploy proxy admin contract
      const proxyAdmin = await getOrDeploy(
        "ProxyAdmin",
        "contracts/proxy/ProxyAdmin.sol",
        [offChainVMOwner],
        deployUtils
      );
      deployUtils.addresses["ProxyAdmin"] = proxyAdmin.address;

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.SignatureVerifier,
        `contracts/socket/utils/SignatureVerifier.sol`,
        proxyAdmin.address,
        [offChainVMOwner],
        deployUtils
      );
      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.AddressResolver,
        `contracts/AddressResolver.sol`,
        proxyAdmin.address,
        [offChainVMOwner],
        deployUtils
      );

      const addressResolver = deployUtils.addresses[OffChainVMCoreContracts.AddressResolver]
      const signatureVerifier = deployUtils.addresses[OffChainVMCoreContracts.SignatureVerifier]

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.WatcherPrecompile,
        `contracts/watcherPrecompile/WatcherPrecompile.sol`,
        proxyAdmin.address,
        [offChainVMOwner, addressResolver],
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.AuctionManager,
        `contracts/apps/payload-delivery/app-gateway/AuctionManager.sol`,
        proxyAdmin.address,
        [
          OFF_CHAIN_VM_CHAIN_ID,
          auctionEndDelaySeconds,
          addressResolver,
          signatureVerifier,
          offChainVMOwner,
        ],
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.FeesManager,
        `contracts/apps/payload-delivery/app-gateway/FeesManager.sol`,
        proxyAdmin.address,
        [addressResolver, offChainVMOwner],
        deployUtils
      );
      const feesManager = deployUtils.addresses[OffChainVMCoreContracts.FeesManager]

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.DeliveryHelper,
        `contracts/apps/payload-delivery/app-gateway/DeliveryHelper.sol`,
        proxyAdmin.address,
        [addressResolver, feesManager, offChainVMOwner],
        deployUtils
      );

      const deliveryHelper = deployUtils.addresses[OffChainVMCoreContracts.DeliveryHelper]

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.Forwarder,
        `contracts/apps/payload-delivery/app-gateway/Forwarder.sol`,
        proxyAdmin.address,
        [addressResolver, deliveryHelper, offChainVMOwner],
        deployUtils
      );
      const forwarder = deployUtils.addresses[OffChainVMCoreContracts.Forwarder]

      await updateContractSettings(
        addressResolver,
        "deliveryHelper",
        "setDeliveryHelper",
        deliveryHelper,
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "feesManager",
        "setFeesManager",
        feesManager,
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "watcherPrecompile",
        "setWatcherPrecompile",
        watcherPrecompile,
        deployUtils.signer
      );


      deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
        ? deployUtils.addresses.startBlock
        : await deployUtils.signer.provider?.getBlockNumber();

      await storeAddresses(
        deployUtils.addresses,
        chain as ChainSlug,
        DeploymentMode.DEV
      );
    } catch (error) {
      await storeAddresses(
        deployUtils.addresses,
        chain as ChainSlug,
        DeploymentMode.DEV
      );
      console.log("Error:", error);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

/**
 * @notice Deploys a contract implementation and its transparent proxy, then initializes it
 * @param contractName The name of the contract to deploy
 * @param proxyAdmin The proxy admin contract address
 * @param initParams Array of parameters for initialization
 * @param signer The signer to execute transactions
 * @returns Object containing both implementation and proxy contract instances
 */
const deployContractWithProxy = async (
  contractName: string,
  contractPath: string,
  proxyAdmin: string,
  initParams: any[],
  deployUtils: DeployParams
): Promise<DeployParams> => {
  // Deploy implementation
  const implementation = await getOrDeploy(
    contractName,
    contractPath,
    [],
    deployUtils
  );
  deployUtils.addresses[`${contractName}Impl`] = implementation.address;

  // Create initialization data
  const initializeFn = implementation.interface.getFunction("initialize");
  const initData = implementation.interface.encodeFunctionData(
    initializeFn,
    initParams
  );

  // Deploy transparent proxy
  const proxy = await getOrDeploy(
    "TransparentUpgradeableProxy",
    "contracts/proxy/TransparentUpgradeableProxy.sol",
    [implementation.address, proxyAdmin, initData],
    deployUtils
  );
  deployUtils.addresses[contractName] = proxy.address;

  return deployUtils;
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
