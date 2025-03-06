import SocketABI from "../artifacts/abi/Socket.json";
import SocketBatcherABI from "../artifacts/abi/SocketBatcher.json";
import FastSwitchboardABI from "../artifacts/abi/FastSwitchboard.json";
import FeesPlugABI from "../artifacts/abi/FeesPlug.json";
import ContractFactoryPlugABI from "../artifacts/abi/ContractFactoryPlug.json";
import AddressResolverABI from "../artifacts/abi/AddressResolver.json";
import WatcherPrecompileABI from "../artifacts/abi/WatcherPrecompile.json";
import AuctionManagerABI from "../artifacts/abi/AuctionManager.json";
import FeesManagerABI from "../artifacts/abi/FeesManager.json";
import DeliveryHelperABI from "../artifacts/abi/DeliveryHelper.json";
import AppGatewayBaseABI from "../artifacts/abi/AppGatewayBase.json";

export class ABI {
  public static readonly AddressResolverABI = AddressResolverABI;
  public static readonly DeliveryHelperABI = DeliveryHelperABI;
  public static readonly FastSwitchboardABI = FastSwitchboardABI;
  public static readonly SocketABI = SocketABI;
  public static readonly SocketBatcherABI = SocketBatcherABI;
  public static readonly WatcherPrecompileABI = WatcherPrecompileABI;
  public static readonly AuctionManagerABI = AuctionManagerABI;
  public static readonly FeesManagerABI = FeesManagerABI;
  public static readonly FeesPlugABI = FeesPlugABI;
  public static readonly ContractFactoryPlugABI = ContractFactoryPlugABI;
  public static readonly AppGatewayBaseABI = AppGatewayBaseABI;
}
