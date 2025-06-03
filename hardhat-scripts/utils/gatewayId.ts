import { constants, ethers } from "ethers";
import { Contracts } from "../../src";
import { EVMX_CHAIN_ID } from "../config";
import { DeploymentAddresses } from "../constants";

export const getAppGatewayId = (
  plug: string,
  addresses: DeploymentAddresses
) => {
  let address: string = "";
  switch (plug) {
    case Contracts.ContractFactoryPlug:
      address = addresses?.[EVMX_CHAIN_ID]?.[Contracts.WritePrecompile];
      if (!address) throw new Error(`WritePrecompile not found on EVMX`);
      return ethers.utils.hexZeroPad(address, 32);
    case Contracts.FeesPlug:
      address = addresses?.[EVMX_CHAIN_ID]?.[Contracts.FeesManager];
      if (!address) throw new Error(`FeesManager not found on EVMX`);
      return ethers.utils.hexZeroPad(address, 32);
    default:
      throw new Error(`Unknown plug: ${plug}`);
  }
};

export const checkIfAppGatewayIdExists = (
  appGatewayId: string,
  name: string
) => {
  if (
    appGatewayId == constants.HashZero ||
    !appGatewayId ||
    appGatewayId == "0x" ||
    appGatewayId.length != 66
  ) {
    throw Error(`${name} not found : ${appGatewayId}`);
  }
  return appGatewayId;
};
