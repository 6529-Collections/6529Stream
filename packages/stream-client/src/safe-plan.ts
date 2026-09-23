import { AbiCoder, FallbackFragment, FunctionFragment, Interface, getAddress, id, keccak256, toUtf8Bytes, ZeroAddress } from "ethers";
import type { InterfaceAbi, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { toSafeCall } from "./safe.js";
import type { SafeCall } from "./safe.js";

export type SafeArgument = string | boolean | readonly SafeArgument[];
export type SafePlanRoute = "receive" | "fallback";
export interface SafePlanInput {
  /** The actual target caller, including for approve, owner/admin and value-bearing actions. */
  readonly safe: Address;
  readonly intent: string;
  readonly call: UnsignedCall;
  readonly abi: InterfaceAbi;
  /** Explicit route for Solidity's non-function receive/fallback entry points. Omit for ABI functions. */
  readonly route?: SafePlanRoute;
}
export interface SafePlanStep {
  readonly index: number;
  readonly safe: Address;
  readonly intent: string;
  readonly method: string;
  readonly arguments: readonly SafeArgument[];
  /** Present only for explicitly selected receive/fallback routes; function plans keep their original shape. */
  readonly route?: SafePlanRoute;
  readonly transaction: SafeCall;
  readonly hash: Hex;
}
export interface SafeCallPlan {
  readonly schemaVersion: 1;
  readonly chainId: bigint;
  readonly title: string;
  /** Ordered independent CALLs. Prior state must be mined/read back before simulating a dependent step. */
  readonly steps: readonly SafePlanStep[];
  /** Application review hash, not a Safe signing digest or an authorization. */
  readonly hash: Hex;
}

const coder = AbiCoder.defaultAbiCoder();
function uint(v: unknown): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << 256n) throw Error("Expected uint256 bigint");
  return v;
}
function text(v: unknown): string {
  if (typeof v !== "string" || !v.trim() || v.length > 4096) throw Error("Expected a nonempty bounded human-readable intent");
  return v;
}
function argument(v: unknown): SafeArgument {
  if (typeof v === "bigint") return v.toString();
  if (typeof v === "string" || typeof v === "boolean") return v;
  if (Array.isArray(v)) return Object.freeze(v.map(argument));
  throw Error("Unsupported decoded ABI argument");
}
function hashStep(chain: bigint, index: number, safe: Address, intent: string, method: string, call: SafeCall): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_SAFE_CALL_PLAN_STEP_V1"), chain, index, safe, call.to, BigInt(call.value), keccak256(call.data), id(method), keccak256(toUtf8Bytes(intent))])) as Hex;
}
function hashPlan(chain: bigint, title: string, steps: readonly SafePlanStep[]): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "bytes32", "bytes32[]"],
    [id("6529STREAM_SAFE_CALL_PLAN_V1"), chain, keccak256(toUtf8Bytes(title)), steps.map(s => s.hash)])) as Hex;
}

function receiveFragment(iface: Interface): FallbackFragment | undefined {
  return iface.fragments.find((f): f is FallbackFragment => {
    if (f.type !== "fallback") return false;
    return JSON.parse(f.format("json")).type === "receive";
  });
}

function fallbackFragment(iface: Interface): FallbackFragment | null {
  return iface.fallback;
}

function describeStep(input: SafePlanInput, transaction: SafeCall, iface: Interface): {
  method: string; arguments: readonly SafeArgument[]; route?: SafePlanRoute;
} {
  if (input.route === undefined) {
    const parsed = iface.parseTransaction({ data: transaction.data, value: transaction.value });
    if (!parsed || parsed.fragment.constant) throw Error("Plan requires a known state-changing ABI function or an explicit receive/fallback route");
    if (input.call.value !== 0n && !parsed.fragment.payable) throw Error("Nonpayable CALL cannot carry value");
    if (iface.encodeFunctionData(parsed.fragment, parsed.args).toLowerCase() !== transaction.data.toLowerCase()) throw Error("Noncanonical or trailing CALL bytes");
    return { method: parsed.fragment.format("sighash"), arguments: Object.freeze(Array.from(parsed.args, argument)) };
  }

  if (input.route === "receive") {
    const fragment = receiveFragment(iface);
    if (!fragment) throw Error("Receive route requires a compiled ABI receive entry");
    if (!fragment.payable) throw Error("Receive route requires a payable receive entry");
    if (transaction.data !== "0x") throw Error("Receive route requires empty calldata");
    return { method: "receive()", arguments: Object.freeze([]), route: "receive" };
  }

  if (input.route !== "fallback") throw Error("Unknown Safe plan route");
  const fragment = fallbackFragment(iface);
  if (!fragment) throw Error("Fallback route requires a compiled ABI fallback entry");
  if (transaction.data === "0x" && receiveFragment(iface)) throw Error("Empty calldata dispatches to receive when the ABI declares receive");
  if (transaction.data.length >= 10) {
    const selector = transaction.data.slice(0, 10).toLowerCase();
    const matched = iface.fragments.filter((f): f is FunctionFragment => f.type === "function").some(f => f.selector.toLowerCase() === selector);
    if (matched) throw Error("Fallback route cannot use a known function selector");
  }
  if (input.call.value !== 0n && !fragment.payable) throw Error("Nonpayable fallback cannot carry value");
  return { method: "fallback(bytes)", arguments: Object.freeze([transaction.data]), route: "fallback" };
}

/**
 * Make a reviewable, ordered plan for any state-changing function in a caller-selected compiled ABI.
 * No signer, Safe service, MultiSend, DELEGATECALL, owner impersonation or automatic retry is involved.
 */
export function createSafeCallPlan(chainId: bigint, title: string, inputs: readonly SafePlanInput[]): SafeCallPlan {
  if (uint(chainId) === 0n) throw Error("Expected positive chain ID"); text(title);
  if (!Array.isArray(inputs) || inputs.length === 0 || inputs.length > 256) throw Error("Expected 1 to 256 ordered CALLs");
  const steps = inputs.map((input, index): SafePlanStep => {
    const safe = getAddress(input.safe) as Address;
    if (safe === ZeroAddress) throw Error("Safe caller must be nonzero"); text(input.intent);
    const transaction = toSafeCall(input.call), iface = new Interface(input.abi);
    const described = describeStep(input, transaction, iface);
    return Object.freeze({ index, safe, intent: input.intent, ...described, transaction,
      hash: hashStep(chainId, index, safe, input.intent, described.method, transaction) });
  });
  return Object.freeze({ schemaVersion: 1, chainId, title, steps: Object.freeze(steps), hash: hashPlan(chainId, title, steps) });
}

/** Re-decode and independently reconstruct every plan field from reviewed ABIs and executable bytes. */
export function verifySafeCallPlan(plan: SafeCallPlan, abis: readonly InterfaceAbi[]): SafeCallPlan {
  if (!plan || plan.schemaVersion !== 1 || !Array.isArray(plan.steps) || plan.steps.length !== abis.length) throw Error("Plan/catalog shape differs");
  const rebuilt = createSafeCallPlan(plan.chainId, plan.title, plan.steps.map((s, i) => {
    if (s.transaction.operation !== 0 || typeof s.transaction.value !== "string" || !/^(0|[1-9][0-9]*)$/.test(s.transaction.value)) throw Error("Expected canonical Safe CALL");
    return { safe: s.safe, intent: s.intent, abi: abis[i]!, ...(s.route === undefined ? {} : { route: s.route }),
      call: { to: s.transaction.to, data: s.transaction.data, value: BigInt(s.transaction.value) } };
  }));
  const encode = (v: unknown) => JSON.stringify(v, (_, x) => typeof x === "bigint" ? x.toString() : x);
  // Compare explicit fields, independent of JSON property order.
  if (rebuilt.hash !== plan.hash || rebuilt.steps.some((s, i) => {
    const old = plan.steps[i]!;
    return s.index !== old.index || s.hash !== old.hash || s.method !== old.method || encode(s.arguments) !== encode(old.arguments);
  })) throw Error("Safe plan differs from independently decoded CALLs");
  return rebuilt;
}

/**
 * Simulate one exact CALL from the selected Safe. Each invocation preserves its bytes and value.
 * This is target-level eth_call only: it does not execute prior steps or verify Safe owners/threshold.
 */
export async function simulateSafePlanStep(provider: Pick<Provider, "getNetwork" | "call">, plan: SafeCallPlan, abis: readonly InterfaceAbi[], index: number): Promise<Hex> {
  const checked = verifySafeCallPlan(plan, abis);
  if (!Number.isInteger(index) || index < 0 || index >= checked.steps.length) throw Error("Invalid plan step");
  if ((await provider.getNetwork()).chainId !== checked.chainId) throw Error("RPC chain differs from Safe plan");
  const step = checked.steps[index]!;
  return await provider.call({ from: step.safe, to: step.transaction.to, data: step.transaction.data, value: BigInt(step.transaction.value) }) as Hex;
}

/** All state-changing selectors in each supplied ABI; inventory does not claim runtime Safe acceptance. */
export function safeCallInventory(abi: InterfaceAbi): readonly { readonly method: string; readonly selector: string; readonly payable: boolean }[] {
  const iface = new Interface(abi);
  return Object.freeze(iface.fragments.filter((f): f is FunctionFragment => f.type === "function")
    .filter(f => !f.constant).map(f => Object.freeze({ method: f.format("sighash"), selector: f.selector, payable: f.payable }))
    .sort((a, b) => a.method.localeCompare(b.method)));
}
