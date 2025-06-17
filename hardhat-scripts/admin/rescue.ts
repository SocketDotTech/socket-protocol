import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { formatUnits } from "ethers/lib/utils";
import { Contract, ethers } from "ethers";
import { EVMX_CHAIN_ID, mainnetChains, mode, testnetChains } from "../config";
import { getAddresses, getSocketSigner, overrides } from "../utils";
import { DeploymentAddresses, getFeeTokens } from "../constants";
import { ChainAddressesObj } from "../../src";

const rescueConfig = {
  sendTx: false,
  chains: [...mainnetChains, ...testnetChains],
};

const activeChainSlugs: string[] = rescueConfig.chains.map((c) => c.toString());
const sendTx = rescueConfig.sendTx;

const rescueFundsABI = [
  {
    inputs: [
      {
        internalType: "address",
        name: "token_",
        type: "address",
      },
      {
        internalType: "address",
        name: "rescueTo_",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount_",
        type: "uint256",
      },
    ],
    name: "rescueFunds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const tokenABI = [
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
];

const createContractAddrArray = (chainSlug: number): string[] => {
  const addresses: DeploymentAddresses = getAddresses(
    mode
  ) as unknown as DeploymentAddresses;

  let chainAddresses = addresses[chainSlug] as unknown as ChainAddressesObj;
  if (!chainAddresses) {
    console.log("addresses not found for ", chainSlug);
    return [];
  }

  let addressArray: string[] = [];
  if (chainAddresses.SocketFeesManager)
    addressArray.push(chainAddresses.SocketFeesManager);
  if (chainAddresses.FeesPlug) addressArray.push(chainAddresses.FeesPlug);
  addressArray.push(chainAddresses.Socket);
  addressArray.push(chainAddresses.SocketBatcher);
  addressArray.push(chainAddresses.FastSwitchboard);
  addressArray.push(chainAddresses.ContractFactoryPlug);
  return addressArray;
};

export const main = async () => {
  // parallelize chains
  await Promise.all(
    activeChainSlugs.map(async (chainSlug) => {
      if (chainSlug === EVMX_CHAIN_ID.toString()) return;
      const signer = await getSocketSigner(parseInt(chainSlug));
      const contractAddr = createContractAddrArray(parseInt(chainSlug));
      if (contractAddr.length === 0) return;

      // rescue first token
      const tokenAddr = getFeeTokens(parseInt(chainSlug))[0];
      if (!tokenAddr) return;
      const tokenInstance: Contract = new ethers.Contract(
        tokenAddr,
        tokenABI,
        signer
      );

      for (let index = 0; index < contractAddr.length; index++) {
        const rescueAmount = await tokenInstance.balanceOf(contractAddr[index]);

        console.log(
          `rescueAmount on ${
            contractAddr[index]
          } on ${chainSlug} : ${formatUnits(rescueAmount.toString(), 6)}`
        );
        if (rescueAmount.toString() === "0") continue;
        const contractInstance: Contract = new ethers.Contract(
          contractAddr[index],
          rescueFundsABI,
          signer
        );

        if (sendTx) {
          console.log("rescuing funds for: ", chainSlug);
          try {
            const tx = await contractInstance.rescueFunds(
              tokenAddr,
              signer.address,
              rescueAmount,
              { ...(await overrides(parseInt(chainSlug))) }
            );
            console.log(
              `Rescuing ${rescueAmount} from ${contractAddr[index]} on ${chainSlug}: ${tx.hash}`
            );

            await tx.wait();
          } catch (e) {
            console.log(
              `Error while rescuing ${rescueAmount} from ${contractAddr[index]} on ${chainSlug}`
            );
          }
        }
      }
    })
  );
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
