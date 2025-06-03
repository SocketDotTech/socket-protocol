import { keccak256 } from "ethers/lib/utils";

export const READ = keccak256(Buffer.from("READ")).substring(0, 10);
export const WRITE = keccak256(Buffer.from("WRITE")).substring(0, 10);
export const SCHEDULE = keccak256(Buffer.from("SCHEDULE")).substring(0, 10);
