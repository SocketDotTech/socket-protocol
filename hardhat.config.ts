import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-deploy";
import "hardhat-abi-exporter";
import "hardhat-change-network";
import "hardhat-contract-sizer";

import { config as dotenvConfig } from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import type {
  HardhatNetworkAccountUserConfig,
  NetworkUserConfig,
} from "hardhat/types";
import { resolve } from "path";
import fs from "fs";

import "./hardhat-scripts/utils/accounts";
import { getJsonRpcUrl } from "./hardhat-scripts/utils/networks";
import {
  ChainId,
  ChainSlug,
  ChainSlugToId,
  HardhatChainName,
  hardhatChainNameToSlug,
} from "./src";
import { EVMX_CHAIN_ID } from "./hardhat-scripts/config/config";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
// TODO: fix it for setup scripts
// if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getChainConfig(chainSlug: ChainSlug): NetworkUserConfig {
  return {
    accounts: [`0x${privateKey}`],
    chainId: ChainSlugToId[chainSlug],
    url: getJsonRpcUrl(chainSlug),
  };
}

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

let liveNetworks = {
  [HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(
    ChainSlug.ARBITRUM_SEPOLIA
  ),
  [HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(
    ChainSlug.OPTIMISM_SEPOLIA
  ),
  [HardhatChainName.SEPOLIA]: getChainConfig(ChainSlug.SEPOLIA),
  [HardhatChainName.BASE_SEPOLIA]: getChainConfig(ChainSlug.BASE_SEPOLIA),
  [HardhatChainName.BASE]: getChainConfig(ChainSlug.BASE),
  [HardhatChainName.ARBITRUM]: getChainConfig(ChainSlug.ARBITRUM),
  [HardhatChainName.OPTIMISM]: getChainConfig(ChainSlug.OPTIMISM),
  EVMX: {
    accounts: [`0x${privateKey}`],
    chainId: EVMX_CHAIN_ID,
    url: process.env.EVMX_RPC,
  },
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  abiExporter: {
    path: "artifacts/abi",
    flat: true,
  },
  networks: {
    hardhat: {
      chainId: hardhatChainNameToSlug[HardhatChainName.HARDHAT],
    },
    ...liveNetworks,
  },
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      arbitrumTestnet: process.env.ARBISCAN_API_KEY || "",
      baseTestnet: process.env.BASESCAN_API_KEY || "",
      base: process.env.BASESCAN_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
      optimisticTestnet: process.env.OPTIMISM_API_KEY || "",
      EVMX: "none",
    },
    customChains: [
      {
        network: "optimisticTestnet",
        chainId: ChainId.OPTIMISM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
      {
        network: "arbitrumTestnet",
        chainId: ChainId.ARBITRUM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "baseTestnet",
        chainId: ChainId.BASE_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org/",
        },
      },
      {
        network: "base",
        chainId: ChainId.BASE,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
      {
        network: "EVMX",
        chainId: EVMX_CHAIN_ID,
        urls: {
          apiURL: "https://evmx.cloud.blockscout.com/api",
          browserURL: "https://evmx.cloud.blockscout.com/",
        },
      },
    ],
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
  solidity: {
    version: "0.8.22",
    settings: {
      evmVersion: "paris",
      optimizer: {
        enabled: true,
        runs: 1,
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
          },
        },
      },
      viaIR: false,
    },
  },
};

export default config;
