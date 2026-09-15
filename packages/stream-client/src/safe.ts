import { getAddress, Interface, ZeroAddress } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ReceiptLike, UnsignedCall } from "./client.js";

/** A direct CALL payload for a Safe transaction builder; signing and submission stay with the caller. */
export interface SafeCall {
  readonly to: Address;
  readonly value: string;
  readonly data: Hex;
  readonly operation: 0;
}

/** Preserve the target, calldata and native value of any prepared Stream call. */
export function toSafeCall(call: UnsignedCall): SafeCall {
  const to = getAddress(call.to) as Address;
  if (to === ZeroAddress) throw new Error("Safe call target must be nonzero");
  if (typeof call.value !== "bigint" || call.value < 0n || call.value >= 1n << 256n) throw new Error("Safe call value must fit uint256 bigint");
  if (typeof call.data !== "string" || !/^0x(?:[a-fA-F0-9]{2})*$/.test(call.data)) throw new Error("Safe calldata must contain complete hex bytes");
  return Object.freeze({ to, value: call.value.toString(), data: call.data, operation: 0 });
}

const executions = new Interface([
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
// Safe 1.3.0 leaves the hash in data; 1.4.1 and 1.5.0 index it in topic 1.
const indexedExecutions = new Interface([
  "event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)",
]);
const successTopic = executions.getEvent("ExecutionSuccess")!.topicHash;
const failureTopic = executions.getEvent("ExecutionFailure")!.topicHash;

export interface SafeExecution {
  readonly safe: Address;
  readonly safeTxHash: Hex;
  readonly payment: bigint;
}

/**
 * Require the expected Safe's successful execTransaction event for its independently verified
 * Safe transaction hash. An outer receipt alone can succeed when the target CALL failed.
 * This does not verify arbitrary module/batch internals or the application's expected state.
 */
export function requireSafeExecution(receipt: ReceiptLike, safeAddress: Address, expectedSafeTxHash: Hex): SafeExecution {
  if (receipt.status !== 1) throw new Error("Safe outer receipt is not successful");
  const safe = getAddress(safeAddress) as Address;
  if (safe === ZeroAddress) throw new Error("Safe address must be nonzero");
  if (typeof expectedSafeTxHash !== "string" || !/^0x[a-fA-F0-9]{64}$/.test(expectedSafeTxHash)) throw new Error("Expected Safe transaction hash must be bytes32");
  const expected = expectedSafeTxHash.toLowerCase();
  const matches: { name: string; payment: bigint }[] = [];
  for (const log of receipt.logs) {
    if (getAddress(log.address) !== safe) continue;
    const topic = log.topics[0]?.toLowerCase();
    if (topic !== successTopic && topic !== failureTopic) continue;
    const legacy = log.topics.length === 1 && /^0x[a-fA-F0-9]{128}$/.test(log.data);
    const indexed = log.topics.length === 2 && /^0x[a-fA-F0-9]{64}$/.test(log.topics[1]!) && /^0x[a-fA-F0-9]{64}$/.test(log.data);
    if (!legacy && !indexed) throw new Error("Malformed Safe execution event");
    const parsed = (indexed ? indexedExecutions : executions).parseLog({ topics: [...log.topics], data: log.data });
    if (!parsed) throw new Error("Malformed Safe execution event");
    if ((parsed.args.txHash as string).toLowerCase() === expected) matches.push({ name: parsed.name, payment: parsed.args.payment as bigint });
  }
  if (matches.length !== 1) throw new Error(`Expected one matching Safe execution, got ${matches.length}`);
  const match = matches[0]!;
  if (match.name !== "ExecutionSuccess") throw new Error("Safe target execution failed");
  return Object.freeze({ safe, safeTxHash: expected as Hex, payment: match.payment });
}
