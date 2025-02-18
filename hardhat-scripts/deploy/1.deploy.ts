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
import {
  MAX_LIMIT,
  EVMX_CHAIN_ID,
  BID_TIMEOUT,
  VERSION,
} from "../constants/constants";
import { CORE_CONTRACTS, OffChainVMCoreContracts } from "../../src";
import { getImplementationAddress } from "./migration/migrate-proxies";

let offChainVMOwner: string;
const main = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainSocketAddresses,
      mode: DeploymentMode.DEV,
      signer: new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string),
      currentChainSlug: EVMX_CHAIN_ID as ChainSlug,
    };
    try {
      await deployWatcherVMContracts();

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
            contractName,
            `contracts/socket/utils/${contractName}.sol`,
            [],
            deployUtils
          );
          deployUtils.addresses[contractName] = signatureVerifier.address;

          await initializeSigVerifier(
            signatureVerifier,
            "owner",
            "initialize",
            socketOwner,
            [socketOwner, VERSION],
            deployUtils.signer
          );

          contractName = CORE_CONTRACTS.Hasher;
          const hasher: Contract = await getOrDeploy(
            contractName,
            contractName,
            `contracts/socket/utils/${contractName}.sol`,
            [socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = hasher.address;

          contractName = CORE_CONTRACTS.Socket;
          const socket: Contract = await getOrDeploy(
            contractName,
            contractName,
            `contracts/socket/${contractName}.sol`,
            [
              chain as ChainSlug,
              hasher.address,
              signatureVerifier.address,
              socketOwner,
              "EVMX",
            ],
            deployUtils
          );
          deployUtils.addresses[contractName] = socket.address;

          contractName = CORE_CONTRACTS.SocketBatcher;
          const batcher: Contract = await getOrDeploy(
            contractName,
            contractName,
            `contracts/socket/${contractName}.sol`,
            [socketOwner, socket.address],
            deployUtils
          );
          deployUtils.addresses[contractName] = batcher.address;

          contractName = CORE_CONTRACTS.FastSwitchboard;
          const sb: Contract = await getOrDeploy(
            contractName,
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
            contractName,
            `contracts/apps/payload-delivery/${contractName}.sol`,
            [socket.address, socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = feesPlug.address;

          contractName = CORE_CONTRACTS.ContractFactoryPlug;
          const contractFactoryPlug: Contract = await getOrDeploy(
            contractName,
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
  } catch (error) {
    console.error("Error in overall deployment process:", error);
  }
};

const deployWatcherVMContracts = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainSocketAddresses,
      mode: DeploymentMode.DEV,
      signer: new ethers.Wallet(process.env.WATCHER_PRIVATE_KEY as string),
      currentChainSlug: EVMX_CHAIN_ID as ChainSlug,
    };
    const chain = EVMX_CHAIN_ID;
    try {
      console.log("Deploying OffChainVM contracts");
      addresses = dev_addresses as unknown as DeploymentAddresses;
      let chainAddresses: ChainSocketAddresses = addresses[chain]
        ? (addresses[chain] as ChainSocketAddresses)
        : ({} as ChainSocketAddresses);

      const providerInstance = new providers.StaticJsonRpcProvider(
        process.env.EVMX_RPC as string
      );
      const signer: Wallet = new ethers.Wallet(
        process.env.WATCHER_PRIVATE_KEY as string,
        providerInstance
      );
      offChainVMOwner = signer.address;

      deployUtils = {
        addresses: chainAddresses,
        mode: DeploymentMode.DEV,
        signer: signer,
        currentChainSlug: chain as ChainSlug,
      };

      // Deploy proxy admin contract
      const contractName = "ERC1967Factory";
      const proxyFactory = await getOrDeploy(
        contractName,
        contractName,
        "lib/solady/src/utils/ERC1967Factory.sol",
        [],
        deployUtils
      );
      deployUtils.addresses[contractName] = proxyFactory.address;

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.SignatureVerifier,
        `contracts/socket/utils/SignatureVerifier.sol`,
        [offChainVMOwner, VERSION],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.AddressResolver,
        `contracts/AddressResolver.sol`,
        [offChainVMOwner, VERSION],
        proxyFactory,
        deployUtils
      );

      const addressResolver = await ethers.getContractAt(
        OffChainVMCoreContracts.AddressResolver,
        deployUtils.addresses[OffChainVMCoreContracts.AddressResolver]
      );

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.WatcherPrecompile,
        `contracts/watcherPrecompile/WatcherPrecompile.sol`,
        [offChainVMOwner, addressResolver.address, MAX_LIMIT, VERSION],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.FeesManager,
        `contracts/apps/payload-delivery/app-gateway/FeesManager.sol`,
        [addressResolver.address, offChainVMOwner, VERSION],
        proxyFactory,
        deployUtils
      );
      const feesManagerAddress =
        deployUtils.addresses[OffChainVMCoreContracts.FeesManager];

      console.log("Deploying DeliveryHelper");

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.DeliveryHelper,
        `contracts/apps/payload-delivery/app-gateway/DeliveryHelper.sol`,
        [addressResolver.address, offChainVMOwner, BID_TIMEOUT, VERSION],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        OffChainVMCoreContracts.AuctionManager,
        `contracts/apps/payload-delivery/app-gateway/AuctionManager.sol`,
        [
          EVMX_CHAIN_ID,
          auctionEndDelaySeconds,
          addressResolver.address,
          deployUtils.addresses[OffChainVMCoreContracts.SignatureVerifier],
          offChainVMOwner,
          VERSION,
        ],
        proxyFactory,
        deployUtils
      );

      await updateContractSettings(
        addressResolver,
        "deliveryHelper",
        "setDeliveryHelper",
        deployUtils.addresses[OffChainVMCoreContracts.DeliveryHelper],
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "feesManager",
        "setFeesManager",
        feesManagerAddress,
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "watcherPrecompile__",
        "setWatcherPrecompile",
        deployUtils.addresses[OffChainVMCoreContracts.WatcherPrecompile],
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

async function initializeSigVerifier(
  contract: Contract,
  getterMethod: string,
  setterMethod: string,
  requiredAddress: string,
  initParams: any[],
  signer: Signer
) {
  const currentValue = await contract.connect(signer)[getterMethod]();

  if (currentValue.toLowerCase() !== requiredAddress.toLowerCase()) {
    console.log({
      setterMethod,
      current: currentValue,
      required: requiredAddress,
    });
    const tx = await contract.connect(signer)[setterMethod](...initParams);
    console.log(`Setting ${getterMethod} for ${contract.address} to`, tx.hash);
    await tx.wait();
  }
}

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
  initParams: any[],
  proxyFactory: Contract,
  deployUtils: DeployParams
): Promise<DeployParams> => {
  // Deploy implementation
  const keyName = `${contractName}Impl`;
  const implementation = await getOrDeploy(
    keyName,
    contractName,
    contractPath,
    [],
    deployUtils
  );
  deployUtils.addresses[keyName] = implementation.address;

  if (deployUtils.addresses[contractName] !== undefined) {
    const currentImplAddress = await getImplementationAddress(
      deployUtils.addresses[contractName]
    );
    const newImplementation = implementation.address;

    console.log("Current implementation:", currentImplAddress);
    console.log("New implementation:", newImplementation);

    if (currentImplAddress.toLowerCase() === newImplementation.toLowerCase())
      return deployUtils;

    console.log("Upgrading contract");

    const tx = await proxyFactory
      .connect(deployUtils.signer)
      .upgrade(deployUtils.addresses[contractName], newImplementation);

    console.log("Upgraded contract", tx.hash);

    await tx.wait();

    return deployUtils;
  }

  // Create initialization data
  const initializeFn = implementation.interface.getFunction("initialize");
  const initData = implementation.interface.encodeFunctionData(
    initializeFn,
    initParams
  );

  // Deploy transparent proxy
  const tx = await proxyFactory
    .connect(deployUtils.signer)
    .deployAndCall(implementation.address, offChainVMOwner, initData);
  const receipt = await tx.wait();
  const proxyAddress = receipt.events?.find((e) => e.event === "Deployed")?.args
    ?.proxy;
  deployUtils.addresses[contractName] = proxyAddress;

  return deployUtils;
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
