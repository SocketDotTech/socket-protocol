import { Events } from "./enums";

export const socketEvents = [
  Events.ExecutionSuccess,
  Events.ExecutionFailed,
  Events.PlugConnected,
  Events.AppGatewayCallRequested,
];

export const feesPlugEvents = [Events.FeesDeposited];

export const watcherPrecompileEvents = [
  Events.CalledAppGateway,
  Events.QueryRequested,
  Events.FinalizeRequested,
  Events.Finalized,
  Events.PromiseResolved,
  Events.PromiseNotResolved,
  Events.TimeoutRequested,
  Events.TimeoutResolved,
  Events.RequestSubmitted,
];

export const deliveryHelperEvents = [
  Events.PayloadSubmitted,
  Events.FeesIncreased,
];

export const auctionManagerEvents = [
  Events.AuctionEnded,
  Events.AuctionRestarted,
];
