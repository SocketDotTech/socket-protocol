import { config } from "dotenv";
import { Contract, utils, Wallet } from "ethers";
import { formatEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { ChainAddressesObj, ChainSlug, Contracts } from "../../src";
import {
  AUCTION_END_DELAY_SECONDS,
  BID_TIMEOUT,
  chains,
  EVMX_CHAIN_ID,
  EXPIRY_TIME,
  getFeesPlugChains,
  logConfig,
  MAX_RE_AUCTION_COUNT,
  MAX_SCHEDULE_DELAY_SECONDS,
  mode,
  READ_FEES,
  SCHEDULE_CALLBACK_FEES,
  SCHEDULE_FEES_PER_SECOND,
  TRIGGER_FEES,
  WRITE_FEES,
} from "../config/config";
import {
  DeploymentAddresses,
  FAST_SWITCHBOARD_TYPE,
  getFeePool,
  IMPLEMENTATION_SLOT,
} from "../constants";
import {
  DeployParams,
  getAddresses,
  getOrDeploy,
  storeAddresses,
} from "../utils";
import { getSocketSigner, getWatcherSigner } from "../utils/sign";
config();

let EVMxOwner: string;

const main = async () => {
  logConfig();
  await logBalances();
  await deployEVMxContracts();
  await deploySocketContracts();
};

const logBalances = async () => {
  const evmxDeployer = await getWatcherSigner();
  const evmxBalance = await evmxDeployer.provider.getBalance(
    evmxDeployer.address
  );
  console.log(
    `EVMx Deployer ${evmxDeployer.address} balance on ${EVMX_CHAIN_ID}:`,
    formatEther(evmxBalance)
  );
  await Promise.all(
    chains.map(async (chain) => {
      const socketDeployer = await getSocketSigner(chain as ChainSlug);
      const socketBalance = await socketDeployer.provider.getBalance(
        socketDeployer.address
      );
      console.log(
        `Socket Deployer ${socketDeployer.address} balance on ${chain}:`,
        formatEther(socketBalance)
      );
    })
  );
};

const deployEVMxContracts = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainAddressesObj,
      mode,
      signer: await getWatcherSigner(),
      currentChainSlug: EVMX_CHAIN_ID as ChainSlug,
    };
    const chain = EVMX_CHAIN_ID;
    try {
      console.log("Deploying EVMx contracts");
      addresses = getAddresses(mode) as unknown as DeploymentAddresses;
      let chainAddresses: ChainAddressesObj = addresses[chain]
        ? (addresses[chain] as ChainAddressesObj)
        : ({} as ChainAddressesObj);

      const signer: Wallet = getWatcherSigner();
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

      const feePool = getFeePool(mode);
      if (feePool.length == 0) {
        const feesPool = await getOrDeploy(
          Contracts.FeesPool,
          Contracts.FeesPool,
          "contracts/evmx/fees/FeesPool.sol",
          [EVMxOwner],
          deployUtils
        );
        deployUtils.addresses[Contracts.FeesPool] = feesPool.address;
      } else {
        deployUtils.addresses[Contracts.FeesPool] = feePool;
      }

      deployUtils = await deployContractWithProxy(
        Contracts.AddressResolver,
        `contracts/evmx/helpers/AddressResolver.sol`,
        [EVMxOwner],
        proxyFactory,
        deployUtils
      );

      const addressResolver = await ethers.getContractAt(
        Contracts.AddressResolver,
        deployUtils.addresses[Contracts.AddressResolver]
      );

      deployUtils = await deployContractWithProxy(
        Contracts.FeesManager,
        `contracts/evmx/fees/FeesManager.sol`,
        [
          EVMX_CHAIN_ID,
          addressResolver.address,
          deployUtils.addresses[Contracts.FeesPool],
          EVMxOwner,
          FAST_SWITCHBOARD_TYPE,
        ],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        Contracts.AsyncDeployer,
        `contracts/evmx/helpers/AsyncDeployer.sol`,
        [EVMxOwner, addressResolver.address],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        Contracts.Watcher,
        `contracts/evmx/watcher/Watcher.sol`,
        [EVMX_CHAIN_ID, TRIGGER_FEES, EVMxOwner, addressResolver.address],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        Contracts.AuctionManager,
        `contracts/evmx/AuctionManager.sol`,
        [
          EVMX_CHAIN_ID,
          BID_TIMEOUT,
          MAX_RE_AUCTION_COUNT,
          AUCTION_END_DELAY_SECONDS,
          addressResolver.address,
          EVMxOwner,
        ],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        Contracts.DeployForwarder,
        `contracts/evmx/helpers/DeployForwarder.sol`,
        [EVMxOwner, addressResolver.address, FAST_SWITCHBOARD_TYPE],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        Contracts.Configurations,
        `contracts/evmx/watcher/Configurations.sol`,
        [deployUtils.addresses[Contracts.Watcher], EVMxOwner],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        Contracts.RequestHandler,
        `contracts/evmx/watcher/RequestHandler.sol`,
        [EVMxOwner, addressResolver.address],
        proxyFactory,
        deployUtils
      );

      const promiseResolver = await getOrDeploy(
        Contracts.PromiseResolver,
        Contracts.PromiseResolver,
        "contracts/evmx/watcher/PromiseResolver.sol",
        [deployUtils.addresses[Contracts.Watcher]],
        deployUtils
      );
      deployUtils.addresses[Contracts.PromiseResolver] =
        promiseResolver.address;

      deployUtils = await deployContractWithProxy(
        Contracts.WritePrecompile,
        `contracts/evmx/watcher/precompiles/WritePrecompile.sol`,
        [
          EVMxOwner,
          deployUtils.addresses[Contracts.Watcher],
          WRITE_FEES,
          EXPIRY_TIME,
        ],
        proxyFactory,
        deployUtils
      );

      const readPrecompile = await getOrDeploy(
        Contracts.ReadPrecompile,
        Contracts.ReadPrecompile,
        "contracts/evmx/watcher/precompiles/ReadPrecompile.sol",
        [deployUtils.addresses[Contracts.Watcher], READ_FEES, EXPIRY_TIME],
        deployUtils
      );
      deployUtils.addresses[Contracts.ReadPrecompile] = readPrecompile.address;

      const schedulePrecompile = await getOrDeploy(
        Contracts.SchedulePrecompile,
        Contracts.SchedulePrecompile,
        "contracts/evmx/watcher/precompiles/SchedulePrecompile.sol",
        [
          deployUtils.addresses[Contracts.Watcher],
          MAX_SCHEDULE_DELAY_SECONDS,
          SCHEDULE_FEES_PER_SECOND,
          SCHEDULE_CALLBACK_FEES,
          EXPIRY_TIME,
        ],
        deployUtils
      );
      deployUtils.addresses[Contracts.SchedulePrecompile] =
        schedulePrecompile.address;

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
      signer: getSocketSigner(EVMX_CHAIN_ID as ChainSlug),
      currentChainSlug: EVMX_CHAIN_ID as ChainSlug,
    };
    console.log("Deploying Socket contracts");
    addresses = getAddresses(mode) as unknown as DeploymentAddresses;

    for (const chain of chains) {
      try {
        let chainAddresses: ChainAddressesObj = addresses[chain]
          ? (addresses[chain] as ChainAddressesObj)
          : ({} as ChainAddressesObj);

        const signer: Wallet = getSocketSigner(chain as ChainSlug);
        const socketOwner = signer.address;

        deployUtils = {
          addresses: chainAddresses,
          mode,
          signer: signer,
          currentChainSlug: chain as ChainSlug,
        };

        let contractName = Contracts.Socket;
        const socket: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/${contractName}.sol`,
          [chain as ChainSlug, socketOwner, "EVMX"],
          deployUtils
        );
        deployUtils.addresses[contractName] = socket.address;

        contractName = Contracts.SocketBatcher;
        const batcher: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/${contractName}.sol`,
          [socketOwner, socket.address],
          deployUtils
        );
        deployUtils.addresses[contractName] = batcher.address;

        contractName = Contracts.FastSwitchboard;
        const sb: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/switchboard/${contractName}.sol`,
          [chain as ChainSlug, socket.address, socketOwner],
          deployUtils
        );
        deployUtils.addresses[contractName] = sb.address;

        if (getFeesPlugChains().includes(chain as ChainSlug)) {
          contractName = Contracts.FeesPlug;
          const feesPlug: Contract = await getOrDeploy(
            contractName,
            contractName,
            `contracts/evmx/plugs/${contractName}.sol`,
            [socket.address, socketOwner],
            deployUtils
          );
          deployUtils.addresses[contractName] = feesPlug.address;
        }

        contractName = Contracts.ContractFactoryPlug;
        const contractFactoryPlug: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/evmx/plugs/${contractName}.sol`,
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

    console.log(
      "Current implementation for",
      contractName,
      ":",
      currentImplAddress
    );
    console.log("New implementation for", contractName, ":", newImplementation);

    if (currentImplAddress.toLowerCase() === newImplementation.toLowerCase())
      return deployUtils;

    console.log("Upgrading contract: ", contractName);

    const tx = await proxyFactory
      .connect(deployUtils.signer)
      .upgrade(deployUtils.addresses[contractName], newImplementation);

    console.log("Upgraded contract", contractName, tx.hash);

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

export async function getImplementationAddress(
  proxyAddress: string
): Promise<string> {
  const customProvider = new ethers.providers.JsonRpcProvider(
    process.env.EVMX_RPC as string
  );

  // Fallback to standard storage slot for other proxy types
  const implHex = await customProvider.getStorageAt(
    proxyAddress,
    IMPLEMENTATION_SLOT
  );

  return utils.getAddress("0x" + implHex.slice(-40));
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
