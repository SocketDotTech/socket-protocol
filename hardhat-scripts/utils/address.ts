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

// TODO: move this to socket-common
export function toBytes32FormatHexString(hexString: string): string {
  // this means that the string is already in bytes32 format with or without 0x prefix
  if (hexString.length == 64 || hexString.length == 66) {
    return hexString;
  }
  // Remove the '0x' prefix from the input string if it's present
  const cleanedHexString = hexString.startsWith("0x")
    ? hexString.slice(2)
    : hexString;

  const buffer = Buffer.alloc(32);
  buffer.write(cleanedHexString, 32 - cleanedHexString.length / 2, "hex"); // each hex char is 2 bytes

  return "0x" + buffer.toString("hex");
}

export function toBytes32Format(hexString: string): number[] {
  const hex32Format = toBytes32FormatHexString(hexString);
  const cleanedHex32String = hex32Format.startsWith("0x")
    ? hex32Format.slice(2)
    : hex32Format;

  return Array.from(Buffer.from(cleanedHex32String, "hex"));
}
