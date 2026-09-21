/** Fixed-block direct RoleManager observations. No signing or submission. */
import { Interface, TypedDataEncoder } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as p from "./current-role-registry-operational.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import { requireSafeExecution } from "./safe.js";

export type RoleRegistryOperationalReader = io.Reader;
export type RoleRegistryOperationalReceiptReader = io.ReceiptReader;
export interface RoleRegistryOperationalDeployment {
  readonly chainId: bigint;
  readonly registry: io.CodePin;
  readonly executor: io.CodePin;
  /** Caller-reviewed complete linked closure for the original Executor read. Not discovered by this client. */
  readonly executorLinkedDependencies: readonly io.CodePin[];
}
export interface RoleRegistryOperationalSafeDeployment {
  readonly safe: io.CodePin;
  readonly singleton: io.CodePin;
  readonly version: "1.3.0" | "1.4.1" | "1.5.0";
}
export interface RoleRegistryOperationalSafeFacts {
  readonly deployment: RoleRegistryOperationalSafeDeployment;
  readonly owners: readonly Address[];
  readonly threshold: bigint;
  readonly nonce: bigint;
}
export interface RoleRegistryOperationalCapture {
  readonly deployment: RoleRegistryOperationalDeployment;
  readonly prepared: p.RoleRegistryOperationalCall;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly before: p.RoleRegistryOperationalState;
  readonly transition: p.RoleRegistryOperationalTransition;
  readonly safe: RoleRegistryOperationalSafeFacts | null;
  readonly captureHash: Hex;
  readonly originalCallSimulated: false;
  readonly independentRedundancyVerified: false;
}
export type RoleRegistryOperationalReceiptOptions = Readonly<{ execution: "direct" }> | Readonly<{
  execution: "safe";
  safe: RoleRegistryOperationalSafeDeployment;
  expectedSafeTxHash: Hex;
}>;
export interface RoleRegistryOperationalHistory {
  readonly deployment: RoleRegistryOperationalDeployment;
  readonly prepared: p.RoleRegistryOperationalCall;
  readonly transactionHash: Hex;
  readonly observed: io.Block;
  readonly prior: io.Block;
  readonly before: p.RoleRegistryOperationalState;
  readonly after: p.RoleRegistryOperationalState;
  readonly mutationLogIndex: number;
  readonly membershipLogIndex: number;
  readonly safeTxHash: Hex | null;
  readonly safeBefore: RoleRegistryOperationalSafeFacts | null;
  readonly receiptVerified: true;
  readonly currentAuthorityVerified: false;
  readonly ownerSignaturesIndependentlyVerified: false;
  readonly independentRedundancyVerified: false;
  readonly intraBlockTraceProven: false;
}
const registry = p.roleRegistryOperationalInterface();
// Full original flat read ABI: no invented prefix getter or nominal library call.
const executor = new Interface([
  "function roleRegistry() view returns (address)",
  "function systemManifestBootstrapState() view returns (bool,bool,address,bytes32,address,bytes32,uint64,bytes32,uint256,bytes32,uint64,address,bytes32,address,bytes32,bytes32,uint256,bytes32,uint256,bytes32,bytes32,uint256,bytes32,uint256,address,address,bytes32,bytes32,uint256)",
]);
const safeAbi = new Interface([
  "function masterCopy() view returns(address)", "function VERSION() view returns(string)",
  "function nonce() view returns(uint256)", "function getOwners() view returns(address[])",
  "function getThreshold() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const safeTypes = { SafeTx: [
  { name: "to", type: "address" }, { name: "value", type: "uint256" }, { name: "data", type: "bytes" },
  { name: "operation", type: "uint8" }, { name: "safeTxGas", type: "uint256" }, { name: "baseGas", type: "uint256" },
  { name: "gasPrice", type: "uint256" }, { name: "gasToken", type: "address" }, { name: "refundReceiver", type: "address" },
  { name: "nonce", type: "uint256" },
] };
const captures = new WeakSet<object>();
const histories = new WeakSet<object>();
function deployment(v: RoleRegistryOperationalDeployment): RoleRegistryOperationalDeployment {
  io.keys(v, ["chainId", "registry", "executor", "executorLinkedDependencies"]);
  const registry = io.codePin(v.registry), executor = io.codePin(v.executor);
  const chainId = p.normalizeRoleRegistryOperationalCoordinates({ chainId: v.chainId, registry: registry.address, executor: executor.address }).chainId;
  if (!Array.isArray(v.executorLinkedDependencies) || Reflect.ownKeys(v.executorLinkedDependencies).length !== v.executorLinkedDependencies.length + 1) throw Error("Malformed dependency list");
  const dependencies = io.pinList(v.executorLinkedDependencies);
  if (dependencies.some(pin => pin.address === registry.address || pin.address === executor.address)) throw Error("Duplicate host dependency");
  return io.freeze({ chainId, registry, executor, executorLinkedDependencies: dependencies });
}
function safeDeployment(v: RoleRegistryOperationalSafeDeployment, caller: Address): RoleRegistryOperationalSafeDeployment {
  io.keys(v, ["safe", "singleton", "version"]);
  if (!["1.3.0", "1.4.1", "1.5.0"].includes(v.version)) throw Error("Unsupported Safe version");
  const safe = io.codePin(v.safe), singleton = io.codePin(v.singleton);
  if (safe.address !== caller || safe.address === singleton.address) throw Error("Safe actual RoleManager differs");
  return io.freeze({ safe, singleton, version: v.version });
}
function coordinates(d: RoleRegistryOperationalDeployment): p.RoleRegistryOperationalCoordinates {
  return { chainId: d.chainId, registry: d.registry.address, executor: d.executor.address };
}
function bool(v: unknown): boolean { if (typeof v !== "boolean") throw Error("Expected boolean result"); return v; }
async function pins(provider: io.Reader, d: RoleRegistryOperationalDeployment, tag: number): Promise<void> {
  await io.runtimes(provider, [d.registry, d.executor, ...d.executorLinkedDependencies], tag);
  const owner = await io.read<Address>(provider, d.registry.address, registry, "owner", [], tag);
  const reverse = await io.read<Address>(provider, d.executor.address, executor, "roleRegistry", [], tag);
  const state = await io.rpc(provider, d.executor.address, executor, "systemManifestBootstrapState", [], tag);
  if (!io.same(owner, d.executor.address) || !io.same(reverse, d.registry.address)
    || state[0] !== true || state[1] !== true || !io.same(state[2], d.registry.address)
    || !io.same(state[3], d.registry.codeHash)) throw Error("Unsealed or mismatched Executor/RoleRegistry binding");
  if (await io.read<bigint>(provider, d.registry.address, registry, "SCHEMA_VERSION", [], tag) !== 1n) throw Error("Role schema differs");
}
async function state(provider: io.Reader, d: RoleRegistryOperationalDeployment, call: p.RoleRegistryOperationalCall, tag: number): Promise<p.RoleRegistryOperationalState> {
  const role = call.request.role, target = d.registry.address;
  if (await io.read<bigint>(provider, target, registry, "roleGrantClass", [role], tag) !== 2n) throw Error("Not an operational role");
  const count = io.uint(await io.read<bigint>(provider, target, registry, "roleHolderCount", [role], tag));
  if (count > BigInt(p.ROLE_REGISTRY_OPERATIONAL_MAX_HOLDERS)) throw Error("Client holder list limit");
  const holders: Address[] = [];
  for (let i = 0n; i < count; i++) holders.push(io.address(await io.read<Address>(provider, target, registry, "roleHolderAt", [role, i], tag)));
  const member = bool(await io.read<boolean>(provider, target, registry, "hasRole", [role, call.request.holder], tag));
  if (member !== holders.includes(call.request.holder)) throw Error("Holder membership/list differs");
  async function chain(method: string, args: readonly unknown[]): Promise<p.RoleRegistryOperationalChain> {
    const [chainHash, revision] = await io.rpc(provider, target, registry, method, args, tag);
    return p.normalizeRoleRegistryOperationalChain({ chainHash: chainHash as Hex, revision: revision as bigint });
  }
  return p.validateRoleRegistryOperationalState({ holders,
    roleState: await chain("roleMutationState", [role]), globalState: await chain("globalRoleMutationState", []),
    managerState: await chain("roleManagerConfigMutationState", [call.caller]),
    managerEnabled: bool(await io.read<boolean>(provider, target, registry, "isRoleManager", [call.caller], tag)) });
}
async function safeFacts(provider: io.Reader, d: RoleRegistryOperationalSafeDeployment, tag: number): Promise<RoleRegistryOperationalSafeFacts> {
  await io.runtimes(provider, [d.safe, d.singleton], tag);
  const target = d.safe.address;
  if (!io.same(await io.read<Address>(provider, target, safeAbi, "masterCopy", [], tag), d.singleton.address)
    || await io.read<string>(provider, target, safeAbi, "VERSION", [], tag) !== d.version) throw Error("Safe singleton/version differs");
  const owners = await io.read<readonly Address[]>(provider, target, safeAbi, "getOwners", [], tag);
  if (!Array.isArray(owners) || owners.length === 0 || owners.length > 256) throw Error("Safe owner bound");
  const detached = owners.map(owner => io.address(owner));
  if (new Set(detached).size !== detached.length) throw Error("Duplicate Safe owner");
  const threshold = io.uint(await io.read<bigint>(provider, target, safeAbi, "getThreshold", [], tag));
  const nonce = io.uint(await io.read<bigint>(provider, target, safeAbi, "nonce", [], tag));
  if (threshold === 0n || threshold > BigInt(owners.length)) throw Error("Invalid Safe threshold");
  return io.freeze({ deployment: d, owners: detached, threshold, nonce });
}
function checkedCapture(v: RoleRegistryOperationalCapture): RoleRegistryOperationalCapture {
  if (!captures.has(v)) throw Error("Capture must be the unchanged same-instance result");
  return v;
}
async function originalCall(provider: io.Reader, prepared: p.RoleRegistryOperationalCall, tag: number, gasLimit: bigint): Promise<void> {
  const raw = io.bytes(await provider.call({ ...prepared.call, from: prepared.caller, blockTag: tag, gasLimit }), 0);
  if (raw !== "0x") throw Error("Original void call returned data");
}
export async function captureRoleRegistryOperational(
  provider: io.Reader, supplied: RoleRegistryOperationalDeployment, prepared: p.RoleRegistryOperationalCall,
  options: Readonly<{ blockTag: number; gasLimit: bigint; safe?: RoleRegistryOperationalSafeDeployment }>,
): Promise<RoleRegistryOperationalCapture> {
  io.keys(options, ["blockTag", "gasLimit"], ["safe"]);
  const d = deployment(supplied), call = p.normalizeRoleRegistryOperationalCall(prepared), tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  io.equal(call.coordinates, coordinates(d), "Deployment/call differs");
  const sd = options.safe === undefined ? null : safeDeployment(options.safe, call.caller);
  const observed = await io.chain(provider, d.chainId, tag);
  await pins(provider, d, tag);
  const before = await state(provider, d, call, tag), transition = p.roleRegistryOperationalTransition(call, before);
  const safe = sd ? await safeFacts(provider, sd, tag) : null;
  await io.unchanged(provider, observed);
  const body = { deployment: d, prepared: call, observed, gasLimit, before, transition, safe,
    originalCallSimulated: false as const, independentRedundancyVerified: false as const };
  const result = io.freeze({ ...body, captureHash: io.fingerprint(body) }); captures.add(result); return result;
}
export async function simulateRoleRegistryOperational(
  provider: io.Reader, supplied: RoleRegistryOperationalCapture, options: Readonly<{ blockTag: number; gasLimit: bigint }>,
) {
  const saved = checkedCapture(supplied); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await io.unchanged(provider, saved.observed);
  const fresh = await captureRoleRegistryOperational(provider, saved.deployment, saved.prepared,
    { blockTag: tag, gasLimit, ...(saved.safe ? { safe: saved.safe.deployment } : {}) });
  io.equal(fresh.before, saved.before, "Role/global/manager state changed; recapture");
  io.equal(fresh.safe, saved.safe, "Safe state changed; recapture");
  await originalCall(provider, saved.prepared, tag, gasLimit);
  await io.unchanged(provider, fresh.observed);
  return io.freeze({ observed: fresh.observed, captureHash: saved.captureHash, originalCallSimulated: true as const,
    ownerSignaturesIndependentlyVerified: false as const, independentRedundancyVerified: false as const });
}
function receiptOptions(v: RoleRegistryOperationalReceiptOptions, caller: Address): RoleRegistryOperationalReceiptOptions {
  if (v.execution === "direct") { io.keys(v, ["execution"]); return { execution: "direct" }; }
  if (v.execution !== "safe") throw Error("Unsupported receipt transport");
  io.keys(v, ["execution", "safe", "expectedSafeTxHash"]);
  return io.freeze({ execution: "safe", safe: safeDeployment(v.safe, caller), expectedSafeTxHash: io.hash(v.expectedSafeTxHash) });
}
async function receipt(
  provider: io.ReceiptReader, d: RoleRegistryOperationalDeployment, call: p.RoleRegistryOperationalCall,
  transactionHash: Hex, options: RoleRegistryOperationalReceiptOptions,
): Promise<RoleRegistryOperationalHistory> {
  const txHash = io.hash(transactionHash), mode = receiptOptions(options, call.caller);
  const mined = await io.mined(provider, d.chainId, txHash);
  if (mined.observed.blockNumber === 0) throw Error("No prior block for receipt");
  const prior = await io.header(provider, mined.observed.blockNumber - 1);
  await pins(provider, d, prior.blockNumber); await pins(provider, d, mined.observed.blockNumber);
  const before = await state(provider, d, call, prior.blockNumber);
  const transition = p.roleRegistryOperationalTransition(call, before);
  const after = await state(provider, d, call, mined.observed.blockNumber);
  io.equal(after, transition.after, "Receipt end state has role/global/manager interference");
  const tx = mined.transaction;
  if (tx.value !== 0n) throw Error("Operational transaction value must be zero");
  let safeIndex = -1, safeTxHash: Hex | null = null, safeBefore: RoleRegistryOperationalSafeFacts | null = null;
  if (mode.execution === "direct") {
    if (!io.same(tx.from, call.caller) || !io.same(tx.to, call.call.to) || !io.same(tx.data, call.call.data)) throw Error("Direct caller/target/calldata differs");
  } else {
    if (!io.same(tx.to, call.caller)) throw Error("Safe actual caller differs");
    safeBefore = await safeFacts(provider, mode.safe, prior.blockNumber);
    const end = await safeFacts(provider, mode.safe, mined.observed.blockNumber);
    if (safeBefore.nonce === (1n << 256n) - 1n) throw Error("Safe nonce overflow");
    io.equal(end, { ...safeBefore, nonce: safeBefore.nonce + 1n }, "Safe nonce/owners/config interference");
    const decoded = safeAbi.decodeFunctionData("execTransaction", tx.data);
    if (!io.same(safeAbi.encodeFunctionData("execTransaction", decoded), tx.data)
      || !io.same(decoded.to, call.call.to) || decoded.value !== 0n || decoded.operation !== 0n
      || !io.same(decoded.data, call.call.data)) throw Error("Safe inner CALL differs");
    io.bytes(decoded.signatures, 65536);
    const fields = { to: decoded.to, value: decoded.value, data: decoded.data, operation: decoded.operation,
      safeTxGas: decoded.safeTxGas, baseGas: decoded.baseGas, gasPrice: decoded.gasPrice,
      gasToken: decoded.gasToken, refundReceiver: decoded.refundReceiver, nonce: safeBefore.nonce };
    safeTxHash = TypedDataEncoder.hash({ chainId: d.chainId, verifyingContract: call.caller }, safeTypes, fields) as Hex;
    if (!io.same(safeTxHash, mode.expectedSafeTxHash)) throw Error("Independent Safe hash differs");
    const onchainHash = await io.read<Hex>(provider, call.caller, safeAbi, "getTransactionHash",
      [fields.to, fields.value, fields.data, fields.operation, fields.safeTxGas, fields.baseGas, fields.gasPrice, fields.gasToken, fields.refundReceiver, fields.nonce], prior.blockNumber);
    if (!io.same(onchainHash, safeTxHash)) throw Error("Original Safe hash differs");
    const topics = [safeAbi.getEvent("ExecutionSuccess")!.topicHash, safeAbi.getEvent("ExecutionFailure")!.topicHash];
    const rows = mined.logs.filter(log => io.same(log.address, call.caller) && topics.some(topic => io.same(log.topics[0], topic)));
    if (rows.length !== 1) throw Error("Expected one Safe execution event");
    requireSafeExecution({ status: 1, logs: mined.logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) }, call.caller, safeTxHash);
    safeIndex = rows[0]!.index;
  }
  const r = call.request;
  const mutation = io.one(mined.logs, d.registry.address, registry, "RoleMutationCommitted",
    [1n, r.role, r.holder, transition.granted, after.roleState.chainHash, after.roleState.revision,
      after.globalState.chainHash, after.globalState.revision, io.ZERO]);
  const membership = io.one(mined.logs, d.registry.address, registry, transition.granted ? "StreamRoleGranted" : "StreamRoleRevoked",
    [1n, r.role, r.holder, 2n, call.caller, io.ZERO]);
  if (mutation.index >= membership.index || mined.logs.filter(log => io.same(log.address, d.registry.address)).length !== 2) throw Error("Registry event ordering/count differs");
  io.finish(mined.logs, [d.registry.address], safeIndex);
  await io.unchanged(provider, prior); await io.unchanged(provider, mined.observed);
  const result = io.freeze({ deployment: d, prepared: call, transactionHash: txHash, observed: mined.observed, prior, before, after,
    mutationLogIndex: mutation.index, membershipLogIndex: membership.index, safeTxHash, safeBefore,
    receiptVerified: true as const, currentAuthorityVerified: false as const, ownerSignaturesIndependentlyVerified: false as const,
    independentRedundancyVerified: false as const, intraBlockTraceProven: false as const });
  histories.add(result); return result;
}
/** Historical read uses historical prior/end state and events, never today's manager authority.
 * This bounded attribution profile rejects all intervening registry mutations in the receipt block.
 */
export async function inspectRoleRegistryOperationalHistory(
  provider: io.ReceiptReader, supplied: RoleRegistryOperationalDeployment, prepared: p.RoleRegistryOperationalCall,
  transactionHash: Hex, options: RoleRegistryOperationalReceiptOptions,
): Promise<RoleRegistryOperationalHistory> {
  const d = deployment(supplied), call = p.normalizeRoleRegistryOperationalCall(prepared);
  io.equal(call.coordinates, coordinates(d), "Deployment/call differs");
  return receipt(provider, d, call, io.hash(transactionHash), receiptOptions(options, call.caller));
}
export async function reconcileRoleRegistryOperationalReceipt(
  provider: io.ReceiptReader, supplied: RoleRegistryOperationalCapture, transactionHash: Hex, options: RoleRegistryOperationalReceiptOptions,
): Promise<RoleRegistryOperationalHistory> {
  const saved = checkedCapture(supplied), txHash = io.hash(transactionHash), mode = receiptOptions(options, saved.prepared.caller);
  if ((saved.safe !== null) !== (mode.execution === "safe")) throw Error("Captured transport differs");
  if (mode.execution === "safe") io.equal(mode.safe, saved.safe!.deployment, "Captured Safe deployment differs");
  await io.unchanged(provider, saved.observed);
  const result = await receipt(provider, saved.deployment, saved.prepared, txHash, mode);
  if (result.observed.blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow capture");
  io.equal(result.before, saved.before, "Captured role/global/manager prestate changed");
  io.equal(result.safeBefore, saved.safe, "Captured Safe prestate changed");
  await io.unchanged(provider, saved.observed);
  return result;
}
/** Report current loss of membership/authority without invalidating the historical mutation. */
export async function inspectRoleRegistryOperationalCurrent(
  provider: io.Reader, history: RoleRegistryOperationalHistory, options: Readonly<{ blockTag: number }>,
) {
  if (!histories.has(history)) throw Error("History must be the unchanged same-instance result");
  io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  if (tag < history.observed.blockNumber) throw Error("Current observation predates history");
  await io.unchanged(provider, history.observed);
  const observed = await io.chain(provider, history.deployment.chainId, tag);
  await pins(provider, history.deployment, tag);
  const current = await state(provider, history.deployment, history.prepared, tag);
  await io.unchanged(provider, observed);
  return io.freeze({ observed, current, historicalReceiptVerified: true as const,
    holderCurrentlyGranted: current.holders.includes(history.prepared.request.holder),
    managerCurrentlyEnabled: current.managerEnabled,
    roleStateUnchanged: io.stable(current.roleState) === io.stable(history.after.roleState),
    globalStateUnchanged: io.stable(current.globalState) === io.stable(history.after.globalState),
    managerStateUnchanged: io.stable(current.managerState) === io.stable(history.after.managerState),
    independentRedundancyVerified: false as const });
}
/** Probe the actual call at a new block without imposing the saved optimistic prestate. */
export async function probeRoleRegistryOperationalRefusal(
  provider: io.Reader, supplied: RoleRegistryOperationalCapture, options: Readonly<{ blockTag: number; gasLimit: bigint }>,
) {
  const saved = checkedCapture(supplied); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Refusal observation predates capture");
  await io.unchanged(provider, saved.observed);
  const observed = await io.chain(provider, saved.deployment.chainId, tag); await pins(provider, saved.deployment, tag);
  let outcome: "success" | "revert" = "success", revertData: Hex | null = null;
  try { await originalCall(provider, saved.prepared, tag, gasLimit); }
  catch (error: unknown) {
    const e = error as { code?: unknown; data?: unknown };
    if (e?.code !== "CALL_EXCEPTION" || typeof e.data !== "string") throw Error("Provider failure; no protocol refusal established");
    revertData = io.bytes(e.data, 4096); outcome = "revert";
  }
  await io.unchanged(provider, observed);
  return io.freeze({ observed, outcome, revertData, capturePredictionChecked: false as const,
    ownerSignaturesIndependentlyVerified: false as const });
}
