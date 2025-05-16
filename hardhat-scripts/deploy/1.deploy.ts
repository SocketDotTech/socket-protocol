import { ChainAddressesObj, ChainId, ChainSlug } from "../../src";
import { config } from "dotenv";
import { BigNumber, Contract, Signer, utils, Wallet } from "ethers";
import { formatEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  ETH_ADDRESS,
  EVMxCoreContracts,
  FAST_SWITCHBOARD_TYPE,
  IMPLEMENTATION_SLOT,
} from "../constants";
import {
  DeployParams,
  getAddresses,
  getInstance,
  getOrDeploy,
  storeAddresses,
} from "../utils";
import { getSocketSigner, getWatcherSigner } from "../utils/sign";
import {
  auctionEndDelaySeconds,
  BID_TIMEOUT,
  chains,
  EVMX_CHAIN_ID,
  EXPIRY_TIME,
  logConfig,
  DEFAULT_MAX_LIMIT,
  MAX_RE_AUCTION_COUNT,
  mode,
  TEST_USDC_INITIAL_SUPPLY,
  TEST_USDC_DECIMALS,
  TEST_USDC_NAME,
  TEST_USDC_SYMBOL,
  QUERY_FEES,
  FINALIZE_FEES,
  TIMEOUT_FEES,
  CALLBACK_FEES,
  AUCTION_MANAGER_FUNDING_AMOUNT,
} from "../config/config";
config();

let EVMxOwner: string;

export const mockForwarderSolanaOnChainAddress32Bytes = Buffer.from(
  "55d893e742d43eafc1e6509eefca9ceb635a39bd3394041d334203ed35720922",
  "hex"
);

export const mockSwitchboardSolanaAddress32Bytes = Buffer.from(
//"111893e742d43eafc1e6509eefca9ceb635a39bd3394041d334203ed35720333",
  "0000000000000000000000000000000000000000000000000000000000000001",  //Make sure this is the same as in ForwarderSolana.sol (mocked address)
  "hex"
);

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
      console.log("chain: ", chain);
      // TODO:GW: if I add Solana chain slug in config.ts it will not work as there is no RPC in env vars for it (on the other hand, should there be if EVMx can't do anything on it?)
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

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.AddressResolver,
        `contracts/evmx/AddressResolver.sol`,
        [EVMxOwner],
        proxyFactory,
        deployUtils
      );

      const addressResolver = await ethers.getContractAt(
        EVMxCoreContracts.AddressResolver,
        deployUtils.addresses[EVMxCoreContracts.AddressResolver]
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.WatcherPrecompileLimits,
        `contracts/evmx/watcherPrecompile/WatcherPrecompileLimits.sol`,
        [EVMxOwner, addressResolver.address, DEFAULT_MAX_LIMIT],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.WatcherPrecompileConfig,
        `contracts/evmx/watcherPrecompile/WatcherPrecompileConfig.sol`,
        [EVMxOwner, addressResolver.address, EVMX_CHAIN_ID],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.WatcherPrecompile,
        `contracts/evmx/watcherPrecompile/core/WatcherPrecompile.sol`,
        [
          EVMxOwner,
          addressResolver.address,
          EXPIRY_TIME,
          EVMX_CHAIN_ID,
          deployUtils.addresses[EVMxCoreContracts.WatcherPrecompileLimits],
          deployUtils.addresses[EVMxCoreContracts.WatcherPrecompileConfig],
        ],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.FeesManager,
        `contracts/evmx/payload-delivery/FeesManager.sol`,
        [
          addressResolver.address,
          EVMxOwner,
          EVMX_CHAIN_ID,
          FAST_SWITCHBOARD_TYPE,
        ],
        proxyFactory,
        deployUtils
      );
      const feesManagerAddress =
        deployUtils.addresses[EVMxCoreContracts.FeesManager];

      console.log("Deploying DeliveryHelper");

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.DeliveryHelper,
        `contracts/evmx/payload-delivery/app-gateway/DeliveryHelper.sol`,
        [addressResolver.address, EVMxOwner, BID_TIMEOUT],
        proxyFactory,
        deployUtils
      );

      deployUtils = await deployContractWithProxy(
        EVMxCoreContracts.AuctionManager,
        `contracts/evmx/payload-delivery/AuctionManager.sol`,
        [
          EVMX_CHAIN_ID,
          auctionEndDelaySeconds,
          addressResolver.address,
          EVMxOwner,
          MAX_RE_AUCTION_COUNT,
        ],
        proxyFactory,
        deployUtils
      );

      // fix this is not 32 bytes if as string literal
      try {
        console.log("AddressResolver address:", addressResolver.address);

        
        deployUtils = await deployContractWithProxy(
          EVMxCoreContracts.ForwarderSolana,
          // "ForwarderSolanaTest",
          // `contracts/evmx/ForwarderSolanaTest.sol`,
          `contracts/evmx/ForwarderSolana.sol`,
          [
            ChainId.SOLANA_DEVNET,
            // Uint8Array.from(mockForwarderSolanaAddress32Bytes),
            mockForwarderSolanaOnChainAddress32Bytes,
            addressResolver.address,
          ],
          proxyFactory,
          deployUtils
        );
        const forwarderSolanaAddress = deployUtils.addresses[EVMxCoreContracts.ForwarderSolana];
        console.log("ForwarderSolana Proxy:", forwarderSolanaAddress);
      } catch (error) {
        console.log("Error deploying ForwarderSolana:", error);
      }

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
        "defaultAuctionManager",
        "setDefaultAuctionManager",
        deployUtils.addresses[EVMxCoreContracts.AuctionManager],
        deployUtils.signer
      );

      await updateContractSettings(
        addressResolver,
        "watcherPrecompile__",
        "setWatcherPrecompile",
        deployUtils.addresses[EVMxCoreContracts.WatcherPrecompile],
        deployUtils.signer
      );

      let watcherPrecompileLimits = await getInstance(
        EVMxCoreContracts.WatcherPrecompileLimits,
        deployUtils.addresses[EVMxCoreContracts.WatcherPrecompileLimits]
      );
      watcherPrecompileLimits = watcherPrecompileLimits.connect(
        deployUtils.signer
      );
      await updateContractSettings(
        watcherPrecompileLimits,
        "queryFees",
        "setQueryFees",
        QUERY_FEES,
        deployUtils.signer
      );

      await updateContractSettings(
        watcherPrecompileLimits,
        "finalizeFees",
        "setFinalizeFees",
        FINALIZE_FEES,
        deployUtils.signer
      );

      await updateContractSettings(
        watcherPrecompileLimits,
        "timeoutFees",
        "setTimeoutFees",
        TIMEOUT_FEES,
        deployUtils.signer
      );

      await updateContractSettings(
        watcherPrecompileLimits,
        "callBackFees",
        "setCallBackFees",
        CALLBACK_FEES,
        deployUtils.signer
      );

      const feesManager = await getInstance(
        EVMxCoreContracts.FeesManager,
        deployUtils.addresses[EVMxCoreContracts.FeesManager]
      );
      await fundAuctionManager(
        feesManager.connect(deployUtils.signer),
        deployUtils.addresses[EVMxCoreContracts.AuctionManager],
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

export const fundAuctionManager = async (
  feesManager: Contract,
  auctionManagerAddress: string,
  watcherSigner: Signer
) => {
  const currentCredits = await feesManager.getAvailableCredits(
    auctionManagerAddress
  );
  console.log("Current credits:", currentCredits.toString());
  if (currentCredits.gte(BigNumber.from(AUCTION_MANAGER_FUNDING_AMOUNT))) {
    console.log(
      `Auction manager ${auctionManagerAddress} already has credits, skipping funding`
    );
    return;
  }
  const signatureNonce = Date.now();
  const digest = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address", "uint32", "address", "uint256", "address", "uint32"],
      [
        auctionManagerAddress,
        EVMX_CHAIN_ID,
        ETH_ADDRESS,
        AUCTION_MANAGER_FUNDING_AMOUNT,
        feesManager.address,
        EVMX_CHAIN_ID,
      ]
    )
  );
  const signature = await watcherSigner.signMessage(
    ethers.utils.arrayify(digest)
  );
  const tx = await feesManager
    .connect(watcherSigner)
    .depositCredits(
      auctionManagerAddress,
      EVMX_CHAIN_ID,
      ETH_ADDRESS,
      signatureNonce,
      signature,
      {
        value: AUCTION_MANAGER_FUNDING_AMOUNT,
      }
    );
  console.log(
    `Funding auction manager ${auctionManagerAddress} with ${AUCTION_MANAGER_FUNDING_AMOUNT} ETH, txHash: `,
    tx.hash
  );
  await tx.wait();
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

        console.log(
          "XXX Signer balance:",
          (await signer.getBalance()).toBigInt()
        );

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
          `contracts/protocol/${contractName}.sol`,
          [chain as ChainSlug, socketOwner, "EVMX"],
          deployUtils
        );
        deployUtils.addresses[contractName] = socket.address;

        contractName = CORE_CONTRACTS.SocketBatcher;
        const batcher: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/${contractName}.sol`,
          [socketOwner, socket.address],
          deployUtils
        );
        deployUtils.addresses[contractName] = batcher.address;

        contractName = CORE_CONTRACTS.FastSwitchboard;
        const sb: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/protocol/switchboard/${contractName}.sol`,
          [chain as ChainSlug, socket.address, socketOwner],
          deployUtils
        );
        deployUtils.addresses[contractName] = sb.address;

        contractName = CORE_CONTRACTS.TestUSDC;

        const testUSDC: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/evmx/helpers/${contractName}.sol`,
          [
            TEST_USDC_NAME,
            TEST_USDC_SYMBOL,
            TEST_USDC_DECIMALS,
            socketOwner,
            TEST_USDC_INITIAL_SUPPLY,
          ],
          deployUtils
        );
        deployUtils.addresses[contractName] = testUSDC.address;

        contractName = CORE_CONTRACTS.FeesPlug;
        const feesPlug: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/evmx/payload-delivery/${contractName}.sol`,
          [socket.address, socketOwner],
          deployUtils
        );
        deployUtils.addresses[contractName] = feesPlug.address;

        await whitelistToken(feesPlug, testUSDC.address, deployUtils.signer);

        contractName = CORE_CONTRACTS.ContractFactoryPlug;
        const contractFactoryPlug: Contract = await getOrDeploy(
          contractName,
          contractName,
          `contracts/evmx/payload-delivery/${contractName}.sol`,
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

async function whitelistToken(
  feesPlug: Contract,
  tokenAddress: string,
  signer: Signer
) {
  const isWhitelisted = await feesPlug
    .connect(signer)
    .whitelistedTokens(tokenAddress);
  if (!isWhitelisted) {
    const tx = await feesPlug.connect(signer).whitelistToken(tokenAddress);
    console.log(
      `Whitelisting token ${tokenAddress} for ${feesPlug.address}`,
      tx.hash
    );
    await tx.wait();
  }
}

async function updateContractSettings(
  contract: Contract,
  getterMethod: string,
  setterMethod: string,
  requiredValue: string | BigNumber,
  signer: Signer
) {
  const currentValue = await contract.connect(signer)[getterMethod]();

  if (
    (typeof currentValue === "string" &&
      currentValue.toLowerCase() !== String(requiredValue).toLowerCase()) ||
    (BigNumber.isBigNumber(currentValue) &&
      currentValue.toString() !== requiredValue.toString())
  ) {
    console.log({
      setterMethod,
      current: currentValue,
      required: requiredValue,
    });
    const tx = await contract.connect(signer)[setterMethod](requiredValue);
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
