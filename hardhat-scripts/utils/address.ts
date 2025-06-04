import dev_addresses from "../../deployments/dev_addresses.json";
import stage_addresses from "../../deployments/stage_addresses.json";
import local_addresses from "../../deployments/local_addresses.json";
import { ChainAddressesObj, EVMxAddressesObj } from "../../src/types";
import { DeploymentMode } from "../../src/enums";

export const getAddresses = (
  mode: DeploymentMode
): { [chainSlug: string | number]: ChainAddressesObj | EVMxAddressesObj } => {
  switch (mode) {
    case DeploymentMode.LOCAL:
      // @ts-ignore
      return local_addresses;
    case DeploymentMode.DEV:
      // @ts-ignore
      return dev_addresses;
    case DeploymentMode.STAGE:
      // @ts-ignore
      return stage_addresses;
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

export const checkIfAddressExists = (address: string, name: string) => {
  if (
    address == "0x0000000000000000000000000000000000000000" ||
    !address ||
    address == "0x" ||
    address.length != 42
  ) {
    throw Error(`${name} not found : ${address}`);
  }
  return address;
};
