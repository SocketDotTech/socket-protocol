import {
  ChainAddressesObj,
  ChainSlug
} from "@socket.tech/socket-protocol-common";
import { config } from "dotenv";
import { Contract, Signer, Wallet, providers } from "ethers";
import { formatEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { BID_TIMEOUT, EVMX_CHAIN_ID, EXPIRY_TIME, MAX_LIMIT } from "../config";
import {
  auctionEndDelaySeconds,
  chains,
  logConfig,
  mode,
} from "../config/config";
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  EVMxCoreContracts,
} from "../constants";
import { getImplementationAddress } from "../migration/migrate-proxies";
import {
  DeployParams,
  getAddresses,
  getOrDeploy,
  getProviderFromChainSlug,
  storeAddresses,
} from "../utils";
config();

let EVMxOwner: string;

const main = async () => {
  logConfig();
  await logBalances();
  await deployEVMxContracts();
  await deploySocketContracts();
};

const logBalances = async () => {
  const evmxDeployer = new ethers.Wallet(process.env.WATCHER_PRIVATE_KEY as string);
  const socketDeployer = new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string);
  let provider = getProviderFromChainSlug(EVMX_CHAIN_ID as ChainSlug);  
  const evmxBalance = await provider.getBalance(evmxDeployer.address);
  console.log(`EVMx Deployer ${evmxDeployer.address} balance on ${EVMX_CHAIN_ID}:`,  formatEther(evmxBalance));
  await Promise.all(chains.map(async (chain) => {
    const provider = getProviderFromChainSlug(chain);
    const socketBalance = await provider.getBalance(socketDeployer.address);
    console.log(`Socket Deployer ${socketDeployer.address} balance on ${chain}:`,  formatEther(socketBalance));
  }));
};



const deployEVMxContracts = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainAddressesObj,
      mode,
      signer: new ethers.Wallet(process.env.WATCHER_PRIVATE_KEY as string),
      currentChainSlug: EVMX_CHAIN_ID as ChainSlug,
    };
    const chain = EVMX_CHAIN_ID;
    try {
      console.log("Deploying EVMx contracts");
      addresses = getAddresses(mode) as unknown as DeploymentAddresses;
      let chainAddresses: ChainAddressesObj = addresses[chain]
        ? (addresses[chain] as ChainAddressesObj)
        : ({} as ChainAddressesObj);

      const providerInstance = new providers.StaticJsonRpcProvider(
        process.env.EVMX_RPC as string
      );
      const signer: Wallet = new ethers.Wallet(
        process.env.WATCHER_PRIVATE_KEY as string,
        providerInstance
      );
      EVMxOwner = signer.address;

      deployUtils = {
        addresses: chainAddresses,
        mode,
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
        EVMxCoreContracts.AddressResolver,
        `contracts/protocol/AddressResolver.sol`,
        [EVMxOwner],
        proxyFactory,
        deployUtils
      );

      const addressResolver = await ethers.getContractAt(
        EVMxCoreContracts.AddressResolver,
        deployUtils.addresses[EVMxCoreContracts.AddressResolver]
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.WatcherPrecompile,
        `contracts/protocol/watcherPrecompile/WatcherPrecompile.sol`,
        [
          EVMxOwner,
          addressResolver.address,
          MAX_LIMIT,
          EXPIRY_TIME,
          EVMX_CHAIN_ID,
        ],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.FeesManager,
        `contracts/protocol/payload-delivery/FeesManager.sol`,
        [addressResolver.address, EVMxOwner, EVMX_CHAIN_ID],
        proxyFactory,
        deployUtils
      );
      const feesManagerAddress =
        deployUtils.addresses[EVMxCoreContracts.FeesManager];

      console.log("Deploying DeliveryHelper");

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.DeliveryHelper,
        `contracts/protocol/payload-delivery/app-gateway/DeliveryHelper.sol`,
        [addressResolver.address, EVMxOwner, BID_TIMEOUT],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.AuctionManager,
        `contracts/protocol/payload-delivery/AuctionManager.sol`,
        [
          EVMX_CHAIN_ID,
          auctionEndDelaySeconds,
          addressResolver.address,
          EVMxOwner,
        ],
        proxyFactory,
        deployUtils
      );

      await updateContractSettings(
        addressResolver,
        "deliveryHelper",
        "setDeliveryHelper",
        deployUtils.addresses[EVMxCoreContracts.DeliveryHelper],
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
        deployUtils.addresses[EVMxCoreContracts.WatcherPrecompile],
        deployUtils.signer
      );

      deployUtils.addresses.startBlock =
        (deployUtils.addresses.startBlock
          ? deployUtils.addresses.startBlock
          : await deployUtils.signer.provider?.getBlockNumber()) || 0;

      await storeAddresses(deployUtils.addresses, chain as ChainSlug, mode);
    } catch (error) {
      await storeAddresses(deployUtils.addresses, chain as ChainSlug, mode);
      console.log("Error:", error);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

const deploySocketContracts = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainAddressesObj,
      mode,
      signer: new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string),
      currentChainSlug: EVMX_CHAIN_ID as ChainSlug,
    };
    console.log("Deploying Socket contracts");
    addresses = getAddresses(mode) as unknown as DeploymentAddresses;

    for (const chain of chains) {
      try {
        let chainAddresses: ChainAddressesObj = addresses[chain]
          ? (addresses[chain] as ChainAddressesObj)
          : ({} as ChainAddressesObj);

        const providerInstance = getProviderFromChainSlug(chain);
        const signer: Wallet = new ethers.Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );
        const socketOwner = signer.address;

        deployUtils = {
          addresses: chainAddresses,
          mode,
          signer: signer,
          currentChainSlug: chain as ChainSlug,
        };

        let contractName = CORE_CONTRACTS.Socket;
        const socket: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/socket/${contractName}.sol`,
          [chain as ChainSlug, socketOwner, "EVMX"],
          deployUtils
        );
        deployUtils.addresses[contractName] = socket.address;

        contractName = CORE_CONTRACTS.SocketBatcher;
        const batcher: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/socket/${contractName}.sol`,
          [socketOwner, socket.address],
          deployUtils
        );
        deployUtils.addresses[contractName] = batcher.address;

        contractName = CORE_CONTRACTS.FastSwitchboard;
        const sb: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/socket/switchboard/${contractName}.sol`,
          [chain as ChainSlug, socket.address, socketOwner],
          deployUtils
        );
        deployUtils.addresses[contractName] = sb.address;

        contractName = CORE_CONTRACTS.FeesPlug;
        const feesPlug: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/payload-delivery/${contractName}.sol`,
          [socket.address, socketOwner],
          deployUtils
        );
        deployUtils.addresses[contractName] = feesPlug.address;

        contractName = CORE_CONTRACTS.ContractFactoryPlug;
        const contractFactoryPlug: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/payload-delivery/${contractName}.sol`,
          [socket.address, socketOwner],
          deployUtils
        );
        deployUtils.addresses[contractName] = contractFactoryPlug.address;

        deployUtils.addresses.startBlock =
          (deployUtils.addresses.startBlock
            ? deployUtils.addresses.startBlock
            : await deployUtils.signer.provider?.getBlockNumber()) || 0;

        await storeAddresses(deployUtils.addresses, chain, mode);
      } catch (error) {
        await storeAddresses(deployUtils.addresses, chain, mode);
        console.log(
          "Error while deploying socket contracts on chain",
          chain,
          error
        );
      }
    }
  } catch (error) {
    console.error("Error in socket deployment:", error);
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
    .deployAndCall(implementation.address, EVMxOwner, initData);
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
