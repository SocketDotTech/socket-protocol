import { Events } from "./enums";

export const socketEvents = [
  Events.ExecutionSuccess,
  Events.ExecutionFailed,
  Events.PlugConnected,
  Events.AppGatewayCallRequested,
];

export const feesPlugEvents = [Events.FeesDeposited];

export const watcherEvents = [Events.TriggerFailed, Events.TriggerSucceeded];

export const promiseResolverEvents = [
  Events.PromiseResolved,
  Events.PromiseNotResolved,
  Events.MarkedRevert,
];

export const requestHandlerEvents = [
  Events.RequestSubmitted,
  Events.FeesIncreased,
  Events.RequestCancelled,
  Events.RequestSettled,
  Events.RequestCompletedWithErrors,
];

export const configurationsEvents = [Events.PlugAdded];

export const writePrecompileEvents = [
  Events.WriteProofRequested,
  Events.WriteProofUploaded,
];

export const readPrecompileEvents = [Events.ReadRequested];

export const schedulePrecompileEvents = [
  Events.ScheduleRequested,
  Events.ScheduleResolved,
];

export const auctionManagerEvents = [
  Events.AuctionEnded,
  Events.AuctionRestarted,
];
