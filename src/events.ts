import { Events } from "./enums";

export const socketEvents = [
  Events.ExecutionSuccess,
  Events.ExecutionFailed,
  Events.PlugConnected,
  Events.AppGatewayCallRequested,
];

export const feesPlugEvents = [Events.FeesDeposited];

export const watcherPrecompileEvents = [
  Events.QueryRequested,
  Events.FinalizeRequested,
  Events.Finalized,
  Events.PromiseResolved,
  Events.TimeoutRequested,
  Events.TimeoutResolved,
  Events.CalledAppGateway,
  Events.PromiseNotResolved,
];

export const deliveryHelperEvents = [
  Events.PayloadSubmitted,
  Events.PayloadAsyncRequested,
  Events.FeesIncreased,
];

export const auctionManagerEvents = [
  Events.AuctionEnded,
  Events.AuctionRestarted,
];
