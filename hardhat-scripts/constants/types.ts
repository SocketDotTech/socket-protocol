import {
  ChainAddressesObj,
  ChainSlug,
} from "@socket.tech/socket-protocol-common";

export type DeploymentAddresses = {
  [chainSlug in ChainSlug]?: ChainAddressesObj;
};
