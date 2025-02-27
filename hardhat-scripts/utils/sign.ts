import { ethers, Wallet } from "ethers";
import { EVMX_CHAIN_ID, mode } from "../config/config";
import { EVMxCoreContracts } from "../constants";
import { getAddresses } from "./address";

export const signWatcherMessage = async (encodedMessage: string) => {
    const signatureNonce = Date.now();
    const signer = new Wallet(process.env.WATCHER_PRIVATE_KEY!);
    const watcherPrecompileAddress = getAddresses(mode)[EVMX_CHAIN_ID][EVMxCoreContracts.WatcherPrecompile];
    const digest = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint32', 'uint256', 'bytes'],
        [
          watcherPrecompileAddress,
          EVMX_CHAIN_ID,
          signatureNonce,
          encodedMessage,
        ],
      ),
    );
    const signature = await signer.signMessage(ethers.utils.arrayify(digest));
    return { nonce: signatureNonce, signature };
  };
  