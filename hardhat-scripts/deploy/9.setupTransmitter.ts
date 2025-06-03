import { Contract, Wallet } from "ethers";
import { ChainSlug, Contracts, EVMxAddressesObj } from "../../src";
import {
  EVMX_CHAIN_ID,
  mode,
  TRANSMITTER_CREDIT_THRESHOLD,
  TRANSMITTER_NATIVE_THRESHOLD,
} from "../config/config";
import { getAddresses } from "../utils/address";
import { getInstance } from "../utils/deployUtils";
import { overrides } from "../utils/overrides";
import { getTransmitterSigner, getWatcherSigner } from "../utils/sign";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

let evmxAddresses: EVMxAddressesObj;
let feesManagerContract: Contract;
let transmitterSigner: SignerWithAddress | Wallet;
let transmitterAddress: string;

export const main = async () => {
  console.log("Setting up transmitter...");
  await init();
  await approveAuctionManager();
  await checkAndDepositCredits();

  console.log("Transmitter setup complete!");
};

export const init = async () => {
  const addresses = getAddresses(mode);
  evmxAddresses = addresses[EVMX_CHAIN_ID] as EVMxAddressesObj;
  feesManagerContract = await getInstance(
    Contracts.FeesManager,
    evmxAddresses[Contracts.FeesManager]
  );
  transmitterSigner = getTransmitterSigner(EVMX_CHAIN_ID as ChainSlug);
  transmitterAddress = await transmitterSigner.getAddress();
};

export const approveAuctionManager = async () => {
  console.log("Approving auction manager");
  const auctionManagerAddress = evmxAddresses[Contracts.AuctionManager];
  const isAlreadyApproved = await feesManagerContract
    .connect(transmitterSigner)
    .isApproved(transmitterAddress, auctionManagerAddress);

  if (!isAlreadyApproved) {
    console.log("Approving auction manager");
    const tx = await feesManagerContract
      .connect(transmitterSigner)
      .approveAppGateways(
        [
          {
            appGateway: auctionManagerAddress,
            approval: true,
          },
        ],
        await overrides(EVMX_CHAIN_ID as ChainSlug)
      );
    console.log("Auction manager approval tx hash:", tx.hash);
    await tx.wait();
    console.log("Auction manager approved");
  } else {
    console.log("Auction manager already approved");
  }
};

export const checkAndDepositCredits = async () => {
  console.log("Checking and depositing credits");
  const credits = await feesManagerContract
    .connect(transmitterSigner)
    .getAvailableCredits(transmitterAddress);

  if (credits.lt(TRANSMITTER_CREDIT_THRESHOLD)) {
    console.log("Depositing credits for transmitter...");
    const tx = await feesManagerContract
      .connect(getWatcherSigner())
      .wrap(transmitterAddress, {
        ...(await overrides(EVMX_CHAIN_ID as ChainSlug)),
        value: TRANSMITTER_CREDIT_THRESHOLD,
      });
    console.log("Credits wrap tx hash:", tx.hash);
    await tx.wait();
    console.log("Credits wrapped");
  }
};

export const checkAndDepositNative = async () => {
  console.log("Checking and depositing native");
  const nativeBalance = await transmitterSigner.provider!.getBalance(
    transmitterAddress
  );

  if (nativeBalance.lt(TRANSMITTER_NATIVE_THRESHOLD)) {
    console.log("Depositing native for transmitter...");
    const tx = await getWatcherSigner().sendTransaction({
      to: transmitterAddress,
      value: TRANSMITTER_NATIVE_THRESHOLD,
      ...(await overrides(EVMX_CHAIN_ID as ChainSlug)),
    });
    console.log("Native deposit tx hash:", tx.hash);
    await tx.wait();
    console.log("Native deposited");
  }
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
