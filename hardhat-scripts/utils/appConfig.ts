import { Contract } from "ethers";

export const isConfigSetOnSocket = async (
  plug: Contract,
  socket: Contract,
  appGatewayId: string,
  switchboard: string
) => {
  const plugConfigRegistered = await socket.getPlugConfig(plug.address);
  return (
    plugConfigRegistered.appGatewayId.toLowerCase() ===
      appGatewayId.toLowerCase() &&
    plugConfigRegistered.switchboard.toLowerCase() === switchboard.toLowerCase()
  );
};

export const isConfigSetOnEVMx = async (
  watcher: Contract,
  chain: number,
  plug: string,
  appGatewayId: string,
  switchboard: string
) => {
  const plugConfigRegistered = await watcher.getPlugConfigs(chain, plug);
  return (
    plugConfigRegistered[0].toLowerCase() === appGatewayId?.toLowerCase() &&
    plugConfigRegistered[1].toLowerCase() === switchboard.toLowerCase()
  );
};
