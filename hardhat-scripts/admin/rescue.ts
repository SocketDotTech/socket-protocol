import { config as dotenvConfig } from "dotenv";

dotenvConfig();

import { formatEther } from "ethers/lib/utils";
import { Contract, ethers } from "ethers";
import { mainnetChains, mode, testnetChains } from "../config";
import { getAddresses, getSocketSigner, overrides } from "../utils";
import { DeploymentAddresses } from "../constants";
import { ChainAddressesObj, ChainSlug } from "../../src";

/**
 * Usable flags
 * --sendtx         Send rescue tx along with checking balance.
 *                  Default is only check balance.
 *                  Eg. npx --sendtx ts-node scripts/admin/rescueFunds.ts
 *
 * --amount         Specify amount to rescue, can be used only with --sendtx
 *                  If this much is not available then less is rescued.
 *                  Full amount is rescued if not mentioned.
 *                  Eg. npx --chains=2999 --sendtx --amount=0.2 ts-node scripts/admin/rescueFunds.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/rescueFunds.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

const addresses: DeploymentAddresses = getAddresses(
  mode
) as unknown as DeploymentAddresses;

const testnets = process.env.npm_config_testnets == "true";
let activeChainSlugs: string[];
if (testnets)
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    testnetChains.includes(parseInt(c) as ChainSlug)
  );
else
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    mainnetChains.includes(parseInt(c) as ChainSlug)
  );

const sendTx = process.env.npm_config_sendtx == "true";
const filterChains = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",")
  : activeChainSlugs;
const maxRescueAmount = ethers.utils.parseEther(
  process.env.npm_config_amount || "0"
);

const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
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

const createContractAddrArray = (chainSlug: number): string[] => {
  let chainAddresses = addresses[chainSlug] as unknown as ChainAddressesObj;
  if (!chainAddresses) {
    console.log("addresses not found for ", chainSlug, chainAddresses);
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
    activeChainSlugs
      .filter((c) => filterChains.includes(c))
      .map(async (chainSlug) => {
        const signer = await getSocketSigner(parseInt(chainSlug));
        const contractAddr = createContractAddrArray(parseInt(chainSlug));

        for (let index = 0; index < contractAddr.length; index++) {
          const rescueableAmount = await signer.provider.getBalance(
            contractAddr[index]
          );
          const fundingAmount = await signer.provider.getBalance(
            "0x0240c3151FE3e5bdBB1894F59C5Ed9fE71ba0a5E"
          );
          console.log(
            `rescueableAmount on ${chainSlug} : ${formatEther(
              rescueableAmount
            )}`
          );
          console.log(
            `fundingAmount on ${chainSlug}: ${formatEther(fundingAmount)}`
          );

          const rescueAmount =
            maxRescueAmount.eq(0) || rescueableAmount.lt(maxRescueAmount)
              ? rescueableAmount
              : maxRescueAmount;
          if (rescueAmount.toString() === "0") continue;

          const contractInstance: Contract = new ethers.Contract(
            contractAddr[index],
            rescueFundsABI,
            signer
          );

          if (sendTx) {
            try {
              const tx = await contractInstance.rescueFunds(
                ETH_ADDRESS,
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
