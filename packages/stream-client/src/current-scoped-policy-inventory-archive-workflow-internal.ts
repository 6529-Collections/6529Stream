/** Private bounded RPC and transport support for the two frozen ABI129 profiles. */
import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress,
  ZeroHash,
  getAddress,
  isHexString,
  keccak256,
  toUtf8Bytes,
  type Provider
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { requireSafeExecution } from "./safe.js";

export type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
export type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
export interface CodePin { readonly address: Address; readonly codeHash: Hex }
export interface Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
export interface Call { readonly to: Address; readonly data: Hex; readonly value: bigint }
export type ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex }
>;
export interface Log {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}
export const ZERO = ZeroHash as Hex;
export const ZERO_ADDRESS = ZeroAddress as Address;
export const coder = AbiCoder.defaultAbiCoder();
export const MAX_RPC = 16_777_216;
export const MAX_CALL = 2_097_152;
export const MAX_RUNTIME = 131_072;
export const MAX_LOGS = 65_536;
export const MAX_ROWS = 16_384;

export function keys(value: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || required.some(key => !Object.hasOwn(value, key))
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || ![...required, ...optional].includes(key))) {
    throw Error("Missing or unknown properties");
  }
}
export function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!zero && result === ZERO_ADDRESS) throw Error("Zero address");
  return result;
}
export function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!zero && value.toLowerCase() === ZERO)) throw Error("Expected bytes32");
  return value.toLowerCase() as Hex;
}
export function bytes(value: unknown, maximum = MAX_RPC): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}
export function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw Error("Expected bounded unsigned bigint");
  }
  return value;
}
export function number(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw Error("Expected concrete block/index");
  }
  return value;
}
export function gas(value: unknown): bigint {
  const result = uint(value);
  if (result < 21_000n || result > 100_000_000n) throw Error("Client gas limit exceeded");
  return result;
}
export function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
export function stable(value: unknown): string {
  function convert(v: unknown): unknown {
    if (v === null) return ["null"];
    if (typeof v === "string" || typeof v === "boolean") return [typeof v, v];
    if (typeof v === "bigint") return ["bigint", v.toString()];
    if (typeof v === "number" && Number.isFinite(v)) return ["number", v];
    if (Array.isArray(v)) return ["array", v.map(convert)];
    if (v && typeof v === "object") {
      return ["object", Object.keys(v).sort().map(key => [key, convert((v as Record<string, unknown>)[key])])];
    }
    throw Error("Unsupported canonical value");
  }
  return JSON.stringify(convert(value));
}
export function equal(a: unknown, b: unknown, reason = "Observed facts changed; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}
export function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}
export function fingerprint(value: unknown): Hex {
  return keccak256(toUtf8Bytes(stable(value))) as Hex;
}
export function codePin(value: CodePin): CodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}
export function pinList(value: readonly CodePin[]): readonly CodePin[] {
  if (!Array.isArray(value) || value.length > 256) throw Error("Linked dependency limit exceeded");
  const pins = value.map(codePin);
  if (new Set(pins.map(pin => pin.address)).size !== pins.length) throw Error("Duplicate linked dependency");
  return pins;
}
export async function header(provider: Reader, tag: number): Promise<Block> {
  const result = await provider.getBlock(number(tag));
  if (!result || result.number !== tag) throw Error("Missing or mismatched block");
  return { blockNumber: tag, blockHash: hash(result.hash), timestamp: BigInt(number(result.timestamp)) };
}
export async function chain(provider: Reader, chainId: bigint, tag: number): Promise<Block> {
  if ((await provider.getNetwork()).chainId !== chainId) throw Error("Wrong chain");
  return header(provider, tag);
}
export async function unchanged(provider: Reader, block: Block): Promise<void> {
  equal(await header(provider, block.blockNumber), block, "Pinned block changed");
}
export async function runtime(provider: Reader, pin: CodePin, tag: number): Promise<void> {
  const raw = bytes(await provider.getCode(pin.address, tag), MAX_RUNTIME);
  if (raw === "0x" || (raw.length === 48 && raw.startsWith("0xef0100"))
    || !same(keccak256(raw), pin.codeHash)) throw Error("Pinned runtime differs");
}
export async function runtimes(provider: Reader, pins: readonly CodePin[], tag: number): Promise<void> {
  for (const pin of pins) await runtime(provider, pin, tag);
}
export function plain(param: ParamType, value: unknown): unknown {
  if (param.baseType === "array") return (value as readonly unknown[]).map(item => plain(param.arrayChildren!, item));
  if (param.baseType === "tuple") {
    const fields = param.components!;
    if (fields.every(field => field.name !== "")) {
      return Object.fromEntries(fields.map((field, index) => [field.name, plain(field, (value as readonly unknown[])[index])]));
    }
    return fields.map((field, index) => plain(field, (value as readonly unknown[])[index]));
  }
  return value;
}
export function decode(types: readonly string[], raw: Hex): readonly unknown[] {
  const decoded = coder.decode(types, bytes(raw));
  if (!same(coder.encode(types, decoded), raw)) throw Error("Noncanonical encoded values");
  return types.map((type, index) => plain(ParamType.from(type), decoded[index]));
}
export async function rpc(
  provider: Reader, target: Address, iface: Interface, method: string,
  args: readonly unknown[], tag: number, from?: Address, gasLimit?: bigint
): Promise<readonly unknown[]> {
  const data = iface.encodeFunctionData(method, args);
  const raw = bytes(await provider.call({ to: target, data, blockTag: tag,
    ...(from ? { from } : {}), ...(gasLimit ? { gasLimit } : {}) }));
  const decoded = iface.decodeFunctionResult(method, raw);
  if (!same(iface.encodeFunctionResult(method, decoded), raw)) throw Error("Noncanonical RPC result");
  return iface.getFunction(method)!.outputs.map((param, index) => plain(param, decoded[index]));
}
export async function read<T>(
  provider: Reader, target: Address, iface: Interface, method: string,
  args: readonly unknown[], tag: number, from?: Address, gasLimit?: bigint
): Promise<T> {
  return (await rpc(provider, target, iface, method, args, tag, from, gasLimit))[0] as T;
}

const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);
export async function mined(provider: ReceiptReader, chainId: bigint, inputHash: Hex) {
  const transactionHash = hash(inputHash);
  const receipt = await provider.getTransactionReceipt(transactionHash);
  if (!receipt || receipt.status !== 1 || !same(receipt.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = number(receipt.blockNumber);
  const blockHash = hash(receipt.blockHash);
  const from = address(receipt.from);
  const to = address(receipt.to);
  if (!Array.isArray(receipt.logs) || receipt.logs.length > MAX_LOGS) throw Error("Receipt log limit exceeded");
  let priorIndex = -1;
  let total = 0;
  // Copy the entire provider-owned log snapshot before the next await.
  const logs: readonly Log[] = freeze(receipt.logs.map(log => {
    const index = number(log.index);
    if (index <= priorIndex || log.removed !== false || !same(log.transactionHash, transactionHash)
      || log.blockNumber !== blockNumber || !same(log.blockHash, blockHash)) throw Error("Receipt log identity/order differs");
    priorIndex = index;
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error("Malformed log topics");
    const data = bytes(log.data);
    total += (data.length - 2) / 2;
    if (total > MAX_RPC) throw Error("Receipt aggregate log bound exceeded");
    return { address: address(log.address), topics: log.topics.map((topic: string) => hash(topic, true)), data, index };
  }));
  const tx = await provider.getTransaction(transactionHash);
  if (!tx || !same(tx.hash, transactionHash) || !same(tx.from, from) || !same(tx.to, to)
    || tx.blockNumber !== blockNumber || !same(tx.blockHash, blockHash) || tx.chainId !== chainId) {
    throw Error("Transaction envelope differs");
  }
  const transaction = freeze({ from, to, data: bytes(tx.data, MAX_CALL + 16384), value: uint(tx.value) });
  const observed = await chain(provider, chainId, blockNumber);
  if (!same(observed.blockHash, blockHash)) throw Error("Receipt block changed");
  return { observed, transactionHash, transaction, logs };
}
export async function transport(
  provider: ReceiptReader,
  expected: { readonly chainId: bigint; readonly caller: Address; readonly call: Call; readonly observed: Block },
  transactionHash: Hex,
  options: ReceiptOptions
) {
  if (options.execution === "direct") keys(options, ["execution"]);
  else if (options.execution === "safe") keys(options, ["execution", "expectedSafeTxHash"]);
  else throw Error("Unsupported execution transport");
  const checkedOptions = options.execution === "safe"
    ? { execution: "safe" as const, expectedSafeTxHash: hash(options.expectedSafeTxHash) }
    : { execution: "direct" as const };
  const result = await mined(provider, expected.chainId, transactionHash);
  if (result.observed.blockNumber <= expected.observed.blockNumber) throw Error("Receipt must follow captured block");
  const { transaction: tx, logs } = result;
  if (tx.value !== 0n || expected.call.value !== 0n) throw Error("Original CALL value must be zero");
  let safeIndex = -1;
  if (checkedOptions.execution === "direct") {
    if (!same(tx.from, expected.caller) || !same(tx.to, expected.call.to) || !same(tx.data, expected.call.data)) {
      throw Error("Direct caller/target/data differs");
    }
  } else {
    if (!same(tx.to, expected.caller)) throw Error("Safe is not the actual caller");
    const decoded = safe.decodeFunctionData("execTransaction", tx.data);
    if (!same(safe.encodeFunctionData("execTransaction", decoded), tx.data)
      || !same(decoded.to, expected.call.to) || decoded.value !== 0n
      || !same(decoded.data, expected.call.data) || decoded.operation !== 0n) throw Error("Safe inner CALL differs");
    const topics = [safe.getEvent("ExecutionSuccess")!.topicHash, safe.getEvent("ExecutionFailure")!.topicHash];
    const matches = logs.filter(log => same(log.address, expected.caller) && topics.some(topic => same(topic, log.topics[0])));
    if (matches.length !== 1) throw Error("Expected exactly one Safe execution event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) },
      expected.caller, checkedOptions.expectedSafeTxHash);
    safeIndex = matches[0]!.index;
  }
  return { ...result, safeIndex };
}
export function events(logs: readonly Log[], target: Address, iface: Interface, name: string) {
  const fragment = iface.getEvent(name)!;
  return logs.filter(log => same(log.address, target) && same(log.topics[0], fragment.topicHash)).map(row => {
    const decoded = iface.decodeEventLog(fragment, row.data, [...row.topics]);
    const encoded = iface.encodeEventLog(fragment, decoded);
    equal(encoded.topics.map(topic => topic.toLowerCase()), row.topics, `${name} topics differ`);
    if (!same(encoded.data, row.data)) throw Error(`Noncanonical ${name}`);
    return { index: row.index, fields: Object.fromEntries(fragment.inputs.map((param, index) => [param.name, plain(param, decoded[index])])) };
  });
}
export function one(logs: readonly Log[], target: Address, iface: Interface, name: string, expected?: readonly unknown[]) {
  const matches = events(logs, target, iface, name);
  if (matches.length !== 1) throw Error("Expected exactly one " + name);
  const result = matches[0]!;
  if (expected) equal(result.fields, Object.fromEntries(iface.getEvent(name)!.inputs.map((field, i) => [field.name, expected[i]])), name + " differs");
  return result;
}
export function finish(logs: readonly Log[], targets: readonly Address[], safeIndex: number): void {
  if (safeIndex >= 0 && logs.some(log => targets.some(target => same(target, log.address)) && log.index >= safeIndex)) {
    throw Error("Original events must precede Safe success");
  }
}

/** Original public-view library transport. Selector and tuple witnesses are separate. */
export interface WorkerMethod {
  readonly selector: Hex;
  readonly inputs: readonly string[];
  readonly outputs: readonly string[];
}
export async function worker(
  provider: Reader, pin: CodePin, method: WorkerMethod, args: readonly unknown[], tag: number, cap: bigint
): Promise<readonly unknown[]> {
  await runtime(provider, pin, tag);
  const encoded = bytes(coder.encode(method.inputs, args), MAX_RPC);
  const data = `${method.selector}${encoded.slice(2)}`;
  const result = bytes(await provider.call({ to: pin.address, data, blockTag: tag, gasLimit: cap }));
  return decode(method.outputs, result);
}
