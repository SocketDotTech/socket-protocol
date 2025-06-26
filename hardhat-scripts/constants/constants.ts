import { constants, ethers } from "ethers";
import { id } from "ethers/lib/utils";

export const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

export const IMPLEMENTATION_SLOT =
  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

export const FAST_SWITCHBOARD_TYPE = id("FAST");
export const CCTP_SWITCHBOARD_TYPE = id("CCTP");

export const ZERO_APP_GATEWAY_ID = ethers.utils.hexZeroPad(
  constants.AddressZero,
  32
);
