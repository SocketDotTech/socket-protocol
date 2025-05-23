import { Events } from "./enums";

export const socketEvents = [
  Events.ExecutionSuccess,
  Events.ExecutionFailed,
  Events.PlugConnected,
  Events.AppGatewayCallRequested,
];

export const feesPlugEvents = [Events.FeesDeposited];

export const watcherEvents = [
  Events.CalledAppGateway,
  Events.AppGatewayCallFailed,
  Events.TimeoutRequested,
  Events.TimeoutResolved,
];

export const requestHandlerEvents = [
  Events.RequestSubmitted,
  Events.FeesIncreased,
  Events.RequestCancelled
];

export const writePrecompileEvents = [Events.Finalized];

export const readPrecompileEvents = [Events.ReadRequested];

export const promiseResolverEvents = [Events.PromiseResolved, Events.PromiseNotResolved];

export const auctionManagerEvents = [
  Events.AuctionEnded,
  Events.AuctionRestarted,
];
