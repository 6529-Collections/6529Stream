/** Sealed original Executor lifecycle. Target effect verification remains a separate client. */
import { AbiCoder, Interface, TypedDataEncoder, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import * as gov from "./current-governance-executor-v2.js";

export type GovernanceExecutorV2Reader = io.Reader;
export type GovernanceExecutorV2ReceiptReader = io.ReceiptReader;
export interface GovernanceExecutorV2Deployment {
  readonly chainId: bigint;
  readonly executor: io.CodePin;
  /** Reviewed deployed linkage, including all reached transitive library runtimes. */
  readonly linkedDependencies: readonly io.CodePin[];
  readonly roleRegistry: io.CodePin;
  /** Exact code-bearing targets; native receivers are independently observed as empty code. */
  readonly targets: readonly io.CodePin[];
}
export interface GovernanceExecutorV2HistoryDeployment {
  readonly chainId: bigint;
  readonly executor: io.CodePin;
  /** Local getter closure only, principally the original Bootstrap library. */
  readonly historyDependencies: readonly io.CodePin[];
}
export interface GovernanceExecutorV2ScheduleLocator { readonly transactionHash: Hex; readonly logIndex: number }
export interface GovernanceExecutorV2MembershipLocator extends GovernanceExecutorV2ScheduleLocator { readonly actionId: Hex }
export interface GovernanceExecutorV2WorkflowOptions {
  readonly blockTag: number;
  readonly gasLimit: bigint;
  readonly schedule?: GovernanceExecutorV2ScheduleLocator;
  readonly membershipSchedules?: readonly GovernanceExecutorV2MembershipLocator[];
}
export type GovernanceExecutorV2ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex; nonce: bigint; outerValue: bigint; safeCodeHash: Hex }
>;
const coder = AbiCoder.defaultAbiCoder(), ZERO = io.ZERO, ZA = io.ZERO_ADDRESS;
const MAX_CALLS = 256, MAX_SCOPES = 64, MAX_MEMBERSHIPS = 64, MAX_LOCATORS = 4096, MAX_GUARDIANS = 256;
const VETO = id("ROLE_TERMINAL_FREEZE_VETO") as Hex;
const rolesABI = new Interface([
  "function owner() view returns(address)",
  "function hasRole(bytes32 role,address account) view returns(bool)",
  "function isRoleRedundant(bytes32 role) view returns(bool)",
  "function roleMutationState(bytes32 role) view returns(bytes32 chainHash,uint64 revision)",
  "function roleHolderCount(bytes32 role) view returns(uint256)",
  "function roleHolderAt(bytes32 role,uint256 index) view returns(address)"
]);
const safeABI = new Interface([
  "function nonce() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);
const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
const safeFields = ["to", "value", "data", "operation", "safeTxGas", "baseGas", "gasPrice", "gasToken", "refundReceiver", "nonce"] as const;
const safeTypes = { SafeTx: safeFields.map((name, index) => ({ name, type: ["address", "uint256", "bytes", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256"][index]! })) };
const own = <T>(value: T): T => io.freeze(structuredClone(value));
const ownedCaptures = new WeakSet<object>();
function deployment(raw: GovernanceExecutorV2Deployment): GovernanceExecutorV2Deployment {
  io.keys(raw, ["chainId", "executor", "linkedDependencies", "roleRegistry", "targets"]);
  return own({ chainId: io.uint(raw.chainId), executor: io.codePin(raw.executor), linkedDependencies: io.pinList(raw.linkedDependencies), roleRegistry: io.codePin(raw.roleRegistry), targets: io.pinList(raw.targets) });
}
function historyDeployment(raw: GovernanceExecutorV2HistoryDeployment): GovernanceExecutorV2HistoryDeployment {
  io.keys(raw, ["chainId", "executor", "historyDependencies"]);
  return own({ chainId: io.uint(raw.chainId), executor: io.codePin(raw.executor), historyDependencies: io.pinList(raw.historyDependencies) });
}
function locator(raw: GovernanceExecutorV2ScheduleLocator): GovernanceExecutorV2ScheduleLocator {
  io.keys(raw, ["transactionHash", "logIndex"]); return { transactionHash: io.hash(raw.transactionHash), logIndex: io.number(raw.logIndex) };
}
function options(raw: GovernanceExecutorV2WorkflowOptions) {
  io.keys(raw, ["blockTag", "gasLimit"], ["schedule", "membershipSchedules"]);
  const memberships = raw.membershipSchedules ?? [];
  if (!Array.isArray(memberships) || memberships.length > MAX_LOCATORS) throw Error("Membership locator client bound");
  const seen = new Set<string>();
  return own({ blockTag: io.number(raw.blockTag), gasLimit: io.gas(raw.gasLimit), schedule: raw.schedule ? locator(raw.schedule) : null,
    membershipSchedules: memberships.map(v => { io.keys(v, ["actionId", "transactionHash", "logIndex"]); const actionId = io.hash(v.actionId); if (seen.has(actionId)) throw Error("Duplicate membership locator"); seen.add(actionId); return { actionId, ...locator({ transactionHash: v.transactionHash, logIndex: v.logIndex }) }; }) });
}
function coordinates(d: { chainId: bigint; executor: io.CodePin }) { return { chainId: d.chainId, executor: d.executor.address }; }
function iface() { return gov.governanceExecutorV2Interface(); }
async function rows(p: io.Reader, d: { executor: io.CodePin }, method: string, args: readonly unknown[], tag: number, gasLimit?: bigint) { return io.rpc(p, d.executor.address, iface(), method, args, tag, undefined, gasLimit); }
async function read<T>(p: io.Reader, d: { executor: io.CodePin }, method: string, args: readonly unknown[], tag: number, gasLimit?: bigint): Promise<T> { return (await rows(p, d, method, args, tag, gasLimit))[0] as T; }
async function roleRows(p: io.Reader, d: GovernanceExecutorV2Deployment, method: string, args: readonly unknown[], tag: number) { return io.rpc(p, d.roleRegistry.address, rolesABI, method, args, tag); }
function uniqueScopes(calls: readonly { scopeHash: Hex }[]): readonly Hex[] {
  const result = [...new Set(calls.map(c => io.hash(c.scopeHash, true)))]; if (result.length > MAX_SCOPES) throw Error("Distinct scope client bound"); return result;
}
function onlyEvents(logs: readonly io.Log[], d: { executor: io.CodePin }, name: string) { return io.events(logs, d.executor.address, iface(), name); }
function expectedEvents(logs: readonly io.Log[], d: { executor: io.CodePin }, name: string, count: number) { const r = onlyEvents(logs, d, name); if (r.length !== count) throw Error(`Unexpected ${name} event count`); return r; }

export interface GovernanceExecutorV2Membership {
  readonly scopeHash: Hex; readonly actionId: Hex; readonly proposer: Address;
  readonly usesRootCapacity: boolean; readonly vetoDeadline: bigint;
}
export interface GovernanceExecutorV2ScheduleEvidence {
  readonly locator: GovernanceExecutorV2ScheduleLocator;
  readonly block: io.Block;
  readonly actionId: Hex; readonly nonce: bigint;
  readonly action: gov.GovernanceExecutorV2Action;
  readonly catalog: { readonly candidateProfileHash: Hex; readonly catalogHash: Hex };
  readonly guardianCommitment: Hex | null;
  readonly memberships: readonly GovernanceExecutorV2Membership[];
}
function identity(a: gov.GovernanceExecutorV2Action, nonce: bigint): gov.GovernanceExecutorV2ActionIdentity {
  return { actionClass: a.actionClass, callsHash: a.callHash, scopeHash: a.scopeHash, oldValueHash: a.oldValueHash, newValueHash: a.newValueHash,
    nonce, notBefore: a.notBefore, expiresAfter: a.expiresAfter, reasonHash: a.reasonHash, manifestHash: a.manifestHash };
}
function immutableAction(a: gov.GovernanceExecutorV2Action) {
  const { status: _status, executor: _executor, canceller: _canceller, vetoer: _vetoer, ...result } = a; return result;
}
async function scheduleEvidence(p: io.ReceiptReader, d: GovernanceExecutorV2HistoryDeployment, at: GovernanceExecutorV2ScheduleLocator): Promise<GovernanceExecutorV2ScheduleEvidence> {
  const m = await io.mined(p, d.chainId, at.transactionHash);
  await io.runtimes(p, [d.executor, ...d.historyDependencies], m.observed.blockNumber);
  const events = onlyEvents(m.logs, d, "GovernanceActionScheduled"), selected = events.find(e => e.index === at.logIndex);
  if (!selected || events.length !== 1) throw Error("Expected one authenticated Scheduled locator");
  const e = selected.fields;
  if (e.schemaVersion !== 1n) throw Error("Scheduled schema differs");
  const actionId = io.hash(e.actionId), nonce = io.uint(e.nonce);
  const action = gov.normalizeGovernanceExecutorV2Action({ status: 1n, actionClass: e.actionClass, target: e.target, value: e.value, selector: e.selector,
    callHash: e.callHash, scopeHash: e.scopeHash, oldValueHash: e.oldValueHash, newValueHash: e.newValueHash,
    notBefore: e.notBefore, expiresAfter: e.expiresAfter, proposer: e.proposer, executor: ZA, canceller: ZA, vetoer: ZA,
    reasonHash: e.reasonHash, reasonURI: e.reasonURI, manifestHash: e.manifestHash } as gov.GovernanceExecutorV2Action);
  io.equal(gov.governanceExecutorV2ActionId(coordinates(d), identity(action, nonce)), actionId, "Historical action identity differs");
  const policy = expectedEvents(m.logs, d, "GovernanceActionPolicyValidated", 1)[0]!;
  if (policy.index <= selected.index || policy.fields.schemaVersion !== 1n || policy.fields.phase !== 1n || policy.fields.actionId !== actionId) throw Error("Scheduled policy event differs");
  const rawMemberships = onlyEvents(m.logs, d, "TerminalFreezeActionMembershipUpdated");
  const memberships: GovernanceExecutorV2Membership[] = [];
  for (const row of rawMemberships) {
    const f = row.fields;
    if (f.actionId !== actionId) continue; // elapsed compaction may concern older actions.
    if (row.index >= selected.index || f.schemaVersion !== 1n || f.present !== true || f.mutationCause !== 1n
      || f.proposer !== action.proposer || f.vetoDeadline !== action.notBefore || typeof f.usesRootCapacity !== "boolean") throw Error("Historical membership append differs");
    memberships.push({ scopeHash: io.hash(f.scopeHash, true), actionId, proposer: action.proposer, usesRootCapacity: f.usesRootCapacity, vetoDeadline: action.notBefore });
  }
  if (memberships.length > MAX_SCOPES || new Set(memberships.map(v => v.scopeHash)).size !== memberships.length) throw Error("Historical membership scope bound");
  const guardians = expectedEvents(m.logs, d, "TerminalFreezeGuardianConfigCommitted", action.actionClass === 2n ? 1 : 0);
  let guardianCommitment: Hex | null = null;
  if (action.actionClass === 2n) {
    if (!memberships.length || guardians[0]!.index >= selected.index || rawMemberships.some(v => v.index >= guardians[0]!.index)
      || guardians[0]!.fields.schemaVersion !== 1n || guardians[0]!.fields.actionId !== actionId) throw Error("Historical guardian event differs");
    guardianCommitment = io.hash(guardians[0]!.fields.commitment);
  } else if (memberships.length) throw Error("Nonterminal action has terminal memberships");
  await io.unchanged(p, m.observed);
  return own({ locator: at, block: m.observed, actionId, nonce, action,
    catalog: { candidateProfileHash: io.hash(policy.fields.candidateProfileHash), catalogHash: io.hash(policy.fields.catalogHash) }, guardianCommitment, memberships });
}
async function actionState(p: io.Reader, d: { executor: io.CodePin }, actionId: Hex, at: io.Block, gasLimit: bigint) {
  const action = gov.normalizeGovernanceExecutorV2Action(await read(p, d, "governanceAction", [actionId], at.blockNumber, gasLimit));
  const facts = gov.normalizeGovernanceExecutorV2ActionFacts(await read(p, d, "governanceActionFacts", [actionId], at.blockNumber, gasLimit));
  const virtualStatus = facts.status === 1n && at.timestamp > facts.expiresAfter ? 4n : facts.status;
  if (action.status !== virtualStatus || action.actionClass !== facts.actionClass || action.callHash !== facts.callHash
    || action.notBefore !== facts.notBefore || action.expiresAfter !== facts.expiresAfter) throw Error("Raw versus virtual action state differs");
  return { action, facts };
}
async function carrier(p: io.Reader, pointer: Address, callDatas: readonly Hex[], tag: number) {
  if (pointer === ZA) throw Error("Scheduled calldata carrier missing");
  const payload = coder.encode(["bytes[]"], [callDatas]);
  if ((payload.length - 2) / 2 > 24575) throw Error("Original calldata publication size exceeded");
  io.equal(io.bytes(await p.getCode(pointer, tag), 24576), `0x00${payload.slice(2)}`, "Original STOP calldata carrier differs");
}
export interface GovernanceExecutorV2History {
  readonly observed: io.Block; readonly schedule: GovernanceExecutorV2ScheduleEvidence;
  readonly action: gov.GovernanceExecutorV2Action; readonly facts: gov.GovernanceExecutorV2ActionFacts;
  readonly callDatas: readonly Hex[]; readonly pointer: Address;
  readonly currentAuthorityChecked: false; readonly targetEffectsIndependentlyVerified: false;
}
async function historyAt(p: io.ReceiptReader, d: GovernanceExecutorV2HistoryDeployment, actionId: Hex, at: io.Block, where: GovernanceExecutorV2ScheduleLocator, gasLimit: bigint): Promise<GovernanceExecutorV2History> {
  const schedule = await scheduleEvidence(p, d, where);
  if (schedule.actionId !== actionId || schedule.block.blockNumber > at.blockNumber) throw Error("Historical schedule subject/block differs");
  const state = await actionState(p, d, actionId, at, gasLimit);
  io.equal(immutableAction(state.action), immutableAction(schedule.action), "Retained action differs from original schedule");
  const raw = await read<readonly Hex[]>(p, d, "scheduledCallData", [actionId], at.blockNumber, gasLimit);
  if (!Array.isArray(raw) || !raw.length || raw.length > MAX_CALLS) throw Error("Call count client bound");
  const callDatas = raw.map(v => io.bytes(v, 24575));
  const pointer = io.address(await read(p, d, "scheduledCallDataPointer", [actionId], at.blockNumber, gasLimit));
  await carrier(p, pointer, callDatas, at.blockNumber);
  return own({ observed: at, schedule, ...state, callDatas, pointer, currentAuthorityChecked: false, targetEffectsIndependentlyVerified: false });
}
export async function inspectGovernanceExecutorV2History(p: io.ReceiptReader, input: GovernanceExecutorV2HistoryDeployment, inputActionId: Hex,
  inputOptions: { readonly blockTag: number; readonly gasLimit: bigint; readonly schedule: GovernanceExecutorV2ScheduleLocator }): Promise<GovernanceExecutorV2History> {
  const d = historyDeployment(input), actionId = io.hash(inputActionId); io.keys(inputOptions, ["blockTag", "gasLimit", "schedule"]);
  const o = own({ blockTag: io.number(inputOptions.blockTag), gasLimit: io.gas(inputOptions.gasLimit), schedule: locator(inputOptions.schedule) });
  const at = await io.chain(p, d.chainId, o.blockTag); await io.runtimes(p, [d.executor, ...d.historyDependencies], o.blockTag);
  const result = await historyAt(p, d, actionId, at, o.schedule, o.gasLimit); await io.unchanged(p, at); return result;
}

type Request = gov.GovernanceExecutorV2Request;
type Prepared = gov.GovernanceExecutorV2PreparedCall;
type CheckedOptions = ReturnType<typeof options>;
function descriptor(request: gov.GovernanceExecutorV2ScheduleAction): gov.GovernanceExecutorV2CallDescriptor {
  return { target: request.target, value: request.value, selector: request.selector, callDataHash: keccak256(request.callData) as Hex,
    scopeHash: request.scopeHash, oldValueHash: request.oldValueHash, newValueHash: request.newValueHash };
}
function callWitness(q: Request): readonly gov.GovernanceExecutorV2CallDescriptor[] {
  if (q.method === "scheduleGovernanceAction") return [descriptor(q.request)];
  if (q.method === "executeGovernanceAction") return [q.call];
  if (q.method === "scheduleGovernanceBatch" || q.method === "executeGovernanceBatch") return q.calls;
  return [];
}
function calldataWitness(q: Request): readonly Hex[] {
  if (q.method === "publishGovernanceCallData" || q.method === "executeGovernanceBatch") return q.callDatas;
  if (q.method === "scheduleGovernanceAction") return [q.request.callData];
  if (q.method === "executeGovernanceAction") return [q.callData];
  return [];
}
function scheduleRequest(q: Request) {
  if (q.method === "scheduleGovernanceAction") return { ...q.request, ...gov.governanceExecutorV2BatchHashes([descriptor(q.request)]) };
  if (q.method === "scheduleGovernanceBatch") return { ...q, callsHash: gov.governanceExecutorV2CallsHash(q.calls) };
  return null;
}
function validateWindow(actionClass: bigint, notBefore: bigint, expiresAfter: bigint, now: bigint) {
  const delay = [0n, 172800n, 259200n, 172800n, 1209600n, 2592000n][Number(actionClass)];
  if (delay === undefined || now > (1n << 64n) - 1n - 31536000n || notBefore < now + delay
    || expiresAfter <= notBefore || (delay > 0n && expiresAfter - notBefore < 604800n) || expiresAfter > now + 31536000n) throw Error("Original scheduling window differs");
}
interface MembershipPage { readonly scopeHash: Hex; readonly rows: readonly GovernanceExecutorV2Membership[] }
interface GuardianState { readonly commitment: Hex; readonly rows: readonly { readonly role: Hex; readonly chainHash: Hex; readonly revision: bigint; readonly holders: readonly io.CodePin[] }[] }
async function guardian(p: io.Reader, d: GovernanceExecutorV2Deployment, scopes: readonly Hex[], tag: number): Promise<GuardianState> {
  io.equal((await roleRows(p, d, "isRoleRedundant", [VETO], tag))[0], true, "Original global guardian redundancy required");
  const domain = id("6529STREAM_TERMINAL_GUARDIAN_CONFIG_V1"), holderDomain = id("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1");
  const roleKeys = [VETO, ...scopes.map(scope => keccak256(coder.encode(["bytes32", "bytes32"], [VETO, scope])) as Hex)];
  const rowsOut: { role: Hex; chainHash: Hex; revision: bigint; holders: io.CodePin[] }[] = [];
  let commitment = ZERO;
  for (let i = 0; i < roleKeys.length; i++) {
    const role = roleKeys[i]!, state = await roleRows(p, d, "roleMutationState", [role], tag);
    const chainHash = io.hash(state[0], true), revision = io.uint(state[1], 64), count = io.uint((await roleRows(p, d, "roleHolderCount", [role], tag))[0]);
    if (count > BigInt(MAX_GUARDIANS)) throw Error("Guardian allocation client bound");
    const holders: io.CodePin[] = [];
    for (let j = 0n; j < count; j++) {
      const address = io.address((await roleRows(p, d, "roleHolderAt", [role, j], tag))[0]);
      const code = io.bytes(await p.getCode(address, tag), io.MAX_RUNTIME);
      holders.push({ address, codeHash: keccak256(code) as Hex });
    }
    if (new Set(holders.map(v => v.address)).size !== holders.length) throw Error("Duplicate guardian holder");
    if (i === 0) commitment = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64"], [domain, d.chainId, d.executor.address, d.roleRegistry.address, d.roleRegistry.codeHash, chainHash, revision])) as Hex;
    else commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"], [id("6529STREAM_TERMINAL_GUARDIAN_SCOPE_V1"), commitment, scopes[i - 1], role, chainHash, revision])) as Hex;
    commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256"], [holderDomain, commitment, role, count])) as Hex;
    holders.forEach((h, index) => { commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address", "bytes32"], [holderDomain, commitment, role, index, h.address, h.codeHash])) as Hex; });
    rowsOut.push({ role, chainHash, revision, holders });
  }
  return own({ commitment: keccak256(coder.encode(["bytes32", "bytes32", "uint256"], [domain, commitment, scopes.length])) as Hex, rows: rowsOut });
}
async function pages(p: io.ReceiptReader, d: GovernanceExecutorV2Deployment, scopes: readonly Hex[], tag: number, supplied: CheckedOptions,
  known: GovernanceExecutorV2ScheduleEvidence | null): Promise<readonly MembershipPage[]> {
  if (!scopes.length) return [];
  io.equal(await rows(p, d, "terminalFreezeLiveActionCaps", [], tag), [64n, 48n, 8n], "Original terminal caps differ");
  const cache = new Map<Hex, GovernanceExecutorV2ScheduleEvidence>(); if (known) cache.set(known.actionId, known);
  const result: MembershipPage[] = [];
  for (const scopeHash of scopes) {
    const raw = await rows(p, d, "terminalFreezeActionPage", [scopeHash, 0n, 64n], tag);
    const ids = raw[0] as readonly Hex[], deadlines = raw[1] as readonly bigint[];
    if (!Array.isArray(ids) || !Array.isArray(deadlines) || ids.length !== deadlines.length || ids.length > MAX_MEMBERSHIPS || raw[2] !== BigInt(ids.length) || new Set(ids).size !== ids.length) throw Error("Raw membership page differs");
    const members: GovernanceExecutorV2Membership[] = [];
    for (let i = 0; i < ids.length; i++) {
      const actionId = io.hash(ids[i]); let evidence = cache.get(actionId);
      if (!evidence) { const at = supplied.membershipSchedules.find(v => v.actionId === actionId); if (!at) throw Error("Authenticated membership schedule locator required");
        evidence = await scheduleEvidence(p, { chainId: d.chainId, executor: d.executor, historyDependencies: d.linkedDependencies }, locator({ transactionHash: at.transactionHash, logIndex: at.logIndex })); cache.set(actionId, evidence); }
      if (evidence.block.blockNumber > tag) throw Error("Membership schedule follows observation");
      const member = evidence.memberships.find(v => v.scopeHash === scopeHash);
      if (!member || member.vetoDeadline !== deadlines[i]) throw Error("Raw membership differs from historical append"); members.push(member);
    }
    const nonRoot = members.filter(v => !v.usesRootCapacity).length;
    for (const proposer of new Set(members.map(v => v.proposer))) {
      io.equal(await rows(p, d, "terminalFreezeLiveActionUsage", [scopeHash, proposer], tag), [BigInt(members.length), BigInt(nonRoot), BigInt(members.filter(v => v.proposer === proposer && !v.usesRootCapacity).length)], "Raw membership usage differs");
    }
    result.push({ scopeHash, rows: members });
  }
  return own(result);
}
export interface GovernanceExecutorV2Observation {
  readonly nonce: bigint; readonly pending: bigint; readonly publication: Address;
  readonly actionId: Hex | null; readonly history: GovernanceExecutorV2History | null;
  readonly catalog: readonly [Hex, Hex, bigint, bigint] | null;
  readonly root: (io.CodePin & { readonly revision: bigint }) | null;
  readonly proposerConfig: readonly unknown[] | null;
  readonly guardian: GuardianState | null;
  readonly memberships: readonly MembershipPage[];
  readonly callDatas: readonly Hex[];
  readonly targetRuntimes: readonly (io.CodePin & { readonly empty: boolean })[];
  readonly originalCallAdmissionChecked: false;
}
async function observe(p: io.ReceiptReader, d: GovernanceExecutorV2Deployment, prepared: Prepared, at: io.Block, o: CheckedOptions): Promise<GovernanceExecutorV2Observation> {
  const q = prepared.request, tag = at.blockNumber, calls = callWitness(q);
  if (calls.length > MAX_CALLS) throw Error("Call allocation client bound");
  await io.runtimes(p, [d.executor, ...d.linkedDependencies], tag);
  const bootstrap = await rows(p, d, "systemManifestBootstrapState", [], tag);
  if (bootstrap[0] !== true || bootstrap[1] !== true) throw Error("Client requires sealed original Executor");
  io.equal(await rows(p, d, "currentAction", [], tag), [false, ZERO, 0n, ZERO, ZERO, ZERO], "Executor in-flight context is not clear");
  const nonce = io.uint(await read(p, d, "governanceNonce", [], tag)), pending = io.uint(await read(p, d, "pendingScheduledActionCount", [], tag));
  const scheduling = scheduleRequest(q), executing = q.method === "executeGovernanceAction" || q.method === "executeGovernanceBatch";
  let history: GovernanceExecutorV2History | null = null, actionId: Hex | null = null;
  if ("actionId" in q) {
    if (!o.schedule) throw Error("Authenticated schedule locator required"); actionId = q.actionId;
    history = await historyAt(p, { chainId: d.chainId, executor: d.executor, historyDependencies: d.linkedDependencies }, actionId, at, o.schedule, o.gasLimit);
  }
  let callDatas = calldataWitness(q), publication = ZA;
  if (q.method === "scheduleGovernanceBatch") {
    const key = keccak256(`0x${q.calls.map(c => c.callDataHash.slice(2)).join("")}`) as Hex;
    publication = io.address(await read(p, d, "publishedCallData", [key], tag), true); if (publication === ZA) throw Error("Batch calldata must be published");
    const bytes = io.bytes(await p.getCode(publication, tag), 24576); if (!bytes.startsWith("0x00")) throw Error("Published carrier lacks STOP prefix");
    callDatas = (io.decode(["bytes[]"], `0x${bytes.slice(4)}` as Hex)[0] as readonly Hex[]).map(v => io.bytes(v, 24575));
    if (callDatas.length !== q.calls.length || callDatas.some((v, i) => keccak256(v) !== q.calls[i]!.callDataHash)) throw Error("Published ordered calldata differs");
  } else if (q.method === "publishGovernanceCallData" || q.method === "scheduleGovernanceAction") publication = io.address(await read(p, d, "publishedCallData", [gov.governanceExecutorV2PublicationKey(callDatas)], tag), true);
  else if (history) publication = history.pointer;
  if (executing && history) {
    io.equal(callDatas, history.callDatas, "Execution bytes differ from scheduled carrier");
    gov.authenticateGovernanceExecutorV2Action(coordinates(d), actionId!, history.schedule.nonce, history.action, calls, callDatas);
    if (history.action.actionClass === 2n) io.equal(uniqueScopes(calls), history.schedule.memberships.map(v => v.scopeHash), "Original per-call scopes differ");
  }
  let catalog: GovernanceExecutorV2Observation["catalog"] = null, root: GovernanceExecutorV2Observation["root"] = null, proposerConfig: readonly unknown[] | null = null;
  const targetRuntimes: (io.CodePin & { empty: boolean })[] = [];
  if (scheduling || executing) {
    const r = await rows(p, d, "governanceRootState", [], tag); root = { address: io.address(r[0]), codeHash: io.hash(r[1]), revision: io.uint(r[2], 64) };
    if (!root.revision) throw Error("Root revision missing"); await io.runtime(p, root, tag); io.equal(await read(p, d, "owner", [], tag), root.address, "Root owner differs");
    const c = await rows(p, d, "governanceActionPolicyState", [], tag); catalog = [io.hash(c[0]), io.hash(c[1]), io.uint(c[2]), io.uint(c[3], 64)]; if (!catalog[2] || catalog[2] > 1024n) throw Error("Original catalog bound");
    for (let i = 0; i < calls.length; i++) { const call = calls[i]!, code = io.bytes(await p.getCode(call.target, tag), io.MAX_RUNTIME);
      if (callDatas[i] === "0x" && code === "0x") { targetRuntimes.push({ address: call.target, codeHash: keccak256(code) as Hex, empty: true }); continue; }
      const pin = [d.executor, d.roleRegistry, ...d.targets].find(v => io.same(v.address, call.target)); if (!pin) throw Error("Reviewed target runtime pin required"); await io.runtime(p, pin, tag); }
    for (const call of calls) if (!targetRuntimes.some(v => v.address === call.target)) {
      const pin = [d.executor, d.roleRegistry, ...d.targets].find(v => io.same(v.address, call.target))!; targetRuntimes.push({ ...pin, empty: false });
    }
    if (scheduling) {
      if (!io.same(prepared.caller, root.address) && await read(p, d, "isProposer", [prepared.caller], tag) !== true) throw Error("Scheduling caller is not a root/proposer");
      proposerConfig = await rows(p, d, "proposerConfig", [prepared.caller], tag); validateWindow(scheduling.actionClass, scheduling.notBefore, scheduling.expiresAfter, at.timestamp);
      actionId = gov.governanceExecutorV2ActionId(coordinates(d), { actionClass: scheduling.actionClass, callsHash: scheduling.callsHash, scopeHash: scheduling.scopeHash, oldValueHash: scheduling.oldValueHash, newValueHash: scheduling.newValueHash, nonce, notBefore: scheduling.notBefore, expiresAfter: scheduling.expiresAfter, reasonHash: scheduling.reasonHash, manifestHash: scheduling.manifestHash });
      if ((await actionState(p, d, actionId, at, o.gasLimit)).facts.status !== 0n) throw Error("Scheduled identity already exists");
    } else if (history) { proposerConfig = await rows(p, d, "proposerConfig", [history.action.proposer], tag); io.equal(catalog.slice(0, 2), [history.schedule.catalog.candidateProfileHash, history.schedule.catalog.catalogHash], "Scheduled catalog changed"); }
  }
  const classId = scheduling?.actionClass ?? history?.action.actionClass;
  const scopes = q.method === "pruneElapsedTerminalFreezeActions" ? [q.scopeHash] : classId === 2n ? (scheduling ? uniqueScopes(calls) : history!.schedule.memberships.map(v => v.scopeHash)) : [];
  let guardians: GuardianState | null = null;
  if (classId === 2n && (scheduling || executing) || q.method === "vetoTerminalFreeze") {
    io.equal([bootstrap[2], bootstrap[3]], [d.roleRegistry.address, d.roleRegistry.codeHash], "Bound RoleRegistry differs"); await io.runtime(p, d.roleRegistry, tag);
    io.equal(await read(p, d, "roleRegistry", [], tag), d.roleRegistry.address, "RoleRegistry address differs"); io.equal((await roleRows(p, d, "owner", [], tag))[0], d.executor.address, "RoleRegistry owner differs");
    if (q.method !== "vetoTerminalFreeze") { guardians = await guardian(p, d, scopes, tag); if (history) io.equal(guardians.commitment, history.schedule.guardianCommitment, "Scheduled guardian commitment changed"); }
  }
  if (history) {
    if (history.facts.status !== 1n) throw Error("Action storage is not SCHEDULED"); const a = history.action;
    if (executing && (at.timestamp < a.notBefore || at.timestamp > a.expiresAfter)) throw Error("Outside inclusive execution window");
    if (q.method === "cancelGovernanceAction") {
      if (at.timestamp > a.expiresAfter) throw Error("Cancellation after expiry"); const r = await rows(p, d, "governanceRootState", [], tag);
      const isRoot = io.same(prepared.caller, r[0]); if (isRoot) await io.runtime(p, { address: io.address(r[0]), codeHash: io.hash(r[1]) }, tag);
      const restricted = io.same(a.target, d.executor.address) && a.selector === id("registerCanceller(address,bool)").slice(0, 10) && a.actionClass === 1n;
      if (!isRoot && !io.same(prepared.caller, a.proposer) && (restricted || await read(p, d, "isCanceller", [prepared.caller], tag) !== true)) throw Error("Cancellation caller lacks original authority");
    }
    if (q.method === "vetoTerminalFreeze") {
      if (a.actionClass !== 2n || at.timestamp >= a.notBefore) throw Error("Veto deadline/class differs"); let granted = false;
      for (const role of [VETO, ...scopes.map(scope => keccak256(coder.encode(["bytes32", "bytes32"], [VETO, scope])) as Hex)]) if ((await roleRows(p, d, "hasRole", [role, prepared.caller], tag))[0] === true) { granted = true; break; }
      if (!granted) throw Error("Actual caller is not a current veto guardian");
    }
    if (q.method === "materializeExpiredAction" && at.timestamp <= a.expiresAfter) throw Error("Action has not strictly expired");
  }
  const memberships = await pages(p, d, scopes, tag, o, history?.schedule ?? null);
  return own({ nonce, pending, publication, actionId, history, catalog, root, proposerConfig, guardian: guardians, memberships, callDatas, targetRuntimes, originalCallAdmissionChecked: false });
}

export interface GovernanceExecutorV2Capture {
  readonly deployment: GovernanceExecutorV2Deployment;
  readonly prepared: Prepared;
  readonly options: CheckedOptions;
  readonly observed: io.Block;
  readonly observation: GovernanceExecutorV2Observation;
  readonly captureHash: Hex;
  readonly deploymentProvenanceIndependentlyVerified: false;
  readonly targetEffectsIndependentlyVerified: false;
}
function captureValue(d: GovernanceExecutorV2Deployment, prepared: Prepared, o: CheckedOptions, at: io.Block, observation: GovernanceExecutorV2Observation) {
  const value = { deployment: d, prepared, options: o, observed: at, observation,
    deploymentProvenanceIndependentlyVerified: false as const, targetEffectsIndependentlyVerified: false as const };
  return own({ ...value, captureHash: io.fingerprint(value) });
}
function savedCapture(raw: GovernanceExecutorV2Capture): GovernanceExecutorV2Capture {
  if (!ownedCaptures.has(raw)) throw Error("Capture must be produced by this workflow instance");
  io.keys(raw, ["deployment", "prepared", "options", "observed", "observation", "captureHash", "deploymentProvenanceIndependentlyVerified", "targetEffectsIndependentlyVerified"]);
  const copied = own(raw), d = deployment(copied.deployment), prepared = gov.verifyGovernanceExecutorV2Call(copied.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Capture coordinates differ");
  const o = options({ blockTag: copied.options.blockTag, gasLimit: copied.options.gasLimit,
    ...(copied.options.schedule ? { schedule: copied.options.schedule } : {}), membershipSchedules: copied.options.membershipSchedules });
  const rebuilt = captureValue(d, prepared, o, copied.observed, copied.observation);
  io.equal(copied, rebuilt, "Capture was substituted"); return rebuilt;
}
/** All observations are anchored before returning. Original host simulation remains the admission test. */
export async function captureGovernanceExecutorV2(p: io.ReceiptReader, input: GovernanceExecutorV2Deployment, caller: Address,
  request: Request, inputOptions: GovernanceExecutorV2WorkflowOptions): Promise<GovernanceExecutorV2Capture> {
  const d = deployment(input), prepared = gov.prepareGovernanceExecutorV2Call(coordinates(d), io.address(caller), request), o = options(inputOptions);
  const at = await io.chain(p, d.chainId, o.blockTag), observation = await observe(p, d, prepared, at, o);
  await io.unchanged(p, at); const capture = captureValue(d, prepared, o, at, observation); ownedCaptures.add(capture); return capture;
}
function comparable(observation: GovernanceExecutorV2Observation) {
  return { ...observation, history: observation.history ? { ...observation.history, observed: null,
    action: { ...observation.history.action, status: observation.history.facts.status } } : null };
}
async function revalidate(p: io.ReceiptReader, saved: GovernanceExecutorV2Capture, at: io.Block) {
  if (at.blockNumber < saved.observed.blockNumber) throw Error("Observation predates capture");
  await io.unchanged(p, saved.observed);
  const fresh = await observe(p, saved.deployment, saved.prepared, at, { ...saved.options, blockTag: at.blockNumber });
  io.equal(comparable(fresh), comparable(saved.observation), "Captured lifecycle observations changed; recapture"); return fresh;
}
async function originalCall(p: io.Reader, saved: GovernanceExecutorV2Capture, at: io.Block, gasLimit: bigint, checkPrediction: boolean) {
  const { prepared } = saved, data = io.bytes(await p.call({ from: prepared.caller, to: prepared.call.to, data: prepared.call.data,
    value: prepared.call.value, blockTag: at.blockNumber, gasLimit }), io.MAX_RPC);
  const f = iface().getFunction(prepared.request.method)!;
  const result = iface().decodeFunctionResult(f, data);
  if (!io.same(iface().encodeFunctionResult(f, result), data)) throw Error("Noncanonical original lifecycle result");
  const values = f.outputs.map((v, i) => io.plain(v, result[i]));
  if (checkPrediction) {
    if (scheduleRequest(prepared.request)) io.equal(values, [saved.observation.actionId], "Simulated action identity differs");
    else if (prepared.request.method === "publishGovernanceCallData") {
      io.address(values[0]); if (saved.observation.publication !== ZA) io.equal(values, [saved.observation.publication], "Retained publication pointer differs");
    } else if (prepared.request.method === "pruneElapsedTerminalFreezeActions") {
      const count = saved.observation.memberships.flatMap(v => v.rows).filter(v => at.timestamp >= v.vetoDeadline).length;
      io.equal(values, [BigInt(count)], "Pruned count differs");
    }
  }
  return own(values);
}
export async function simulateGovernanceExecutorV2(p: io.ReceiptReader, input: GovernanceExecutorV2Capture,
  inputOptions: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input); io.keys(inputOptions, ["blockTag", "gasLimit"]);
  const tag = io.number(inputOptions.blockTag), gasLimit = io.gas(inputOptions.gasLimit);
  const at = await io.chain(p, saved.deployment.chainId, tag); await revalidate(p, saved, at);
  const result = await originalCall(p, saved, at, gasLimit, true); await io.unchanged(p, at);
  return own({ observed: at, captureHash: saved.captureHash, result, originalCallAdmissionChecked: true as const,
    targetEffectsIndependentlyVerified: false as const });
}
export async function inspectGovernanceExecutorV2Current(p: io.ReceiptReader, input: GovernanceExecutorV2Deployment, caller: Address,
  request: Request, inputOptions: GovernanceExecutorV2WorkflowOptions) {
  const capture = await captureGovernanceExecutorV2(p, input, caller, request, inputOptions);
  const result = await originalCall(p, capture, capture.observed, capture.options.gasLimit, true); await io.unchanged(p, capture.observed);
  return own({ capture, result, originalCallAdmissionChecked: true as const, targetEffectsIndependentlyVerified: false as const });
}
/** Observes the unchanged original call; a successful result can differ from a stale capture. */
export async function observeGovernanceExecutorV2Refusal(p: io.Reader, input: GovernanceExecutorV2Capture,
  inputOptions: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input); io.keys(inputOptions, ["blockTag", "gasLimit"]);
  const tag = io.number(inputOptions.blockTag), gasLimit = io.gas(inputOptions.gasLimit);
  const at = await io.chain(p, saved.deployment.chainId, tag);
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  await io.unchanged(p, saved.observed);
  await io.runtimes(p, [saved.deployment.executor, ...saved.deployment.linkedDependencies], tag);
  const binding = await rows(p, saved.deployment, "systemManifestBootstrapState", [], tag, gasLimit);
  if (binding[0] !== true || binding[1] !== true) throw Error("Client requires sealed original Executor");
  try {
    const result = await originalCall(p, saved, at, gasLimit, false); await io.unchanged(p, at);
    return own({ observed: at, status: "succeeded" as const, result, capturePredictionChecked: false as const, targetEffectsIndependentlyVerified: false as const });
  } catch (error) {
    const e = error as { code?: unknown; data?: unknown };
    const code = e?.code === "CALL_EXCEPTION" ? "CALL_EXCEPTION" : "RPC_ERROR";
    const revertData = typeof e?.data === "string" && /^0x[0-9a-f]*$/i.test(e.data) && e.data.length <= 8194 && e.data.length % 2 === 0 ? e.data.toLowerCase() as Hex : null;
    await io.unchanged(p, at);
    return own({ observed: at, status: code === "CALL_EXCEPTION" ? "reverted" as const : "rpc-failed" as const, code, revertData,
      capturePredictionChecked: false as const, targetEffectsIndependentlyVerified: false as const });
  }
}
function receiptOptions(raw: GovernanceExecutorV2ReceiptOptions): GovernanceExecutorV2ReceiptOptions {
  if (raw.execution === "direct") { io.keys(raw, ["execution"]); return { execution: "direct" }; }
  io.keys(raw, ["execution", "expectedSafeTxHash", "nonce", "outerValue", "safeCodeHash"]);
  if (raw.execution !== "safe") throw Error("Unsupported transport");
  return own({ execution: "safe", expectedSafeTxHash: io.hash(raw.expectedSafeTxHash), nonce: io.uint(raw.nonce), outerValue: io.uint(raw.outerValue), safeCodeHash: io.hash(raw.safeCodeHash) });
}
async function payableTransport(p: io.ReceiptReader, saved: GovernanceExecutorV2Capture, hash: Hex, o: GovernanceExecutorV2ReceiptOptions) {
  const mined = await io.mined(p, saved.deployment.chainId, hash), { transaction: tx, observed: at, logs } = mined;
  if (at.blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow captured block");
  let safeIndex = -1;
  const { prepared } = saved;
  if (o.execution === "direct") {
    if (!io.same(tx.from, prepared.caller) || !io.same(tx.to, prepared.call.to) || !io.same(tx.data, prepared.call.data) || tx.value !== prepared.call.value) throw Error("Direct caller/target/data/value differs");
  } else {
    if (!io.same(tx.to, prepared.caller) || tx.value !== o.outerValue) throw Error("Safe target/outer value differs");
    const fn = safeABI.getFunction("execTransaction")!, decoded = safeABI.decodeFunctionData(fn, tx.data);
    if (!io.same(safeABI.encodeFunctionData(fn, decoded), tx.data) || !io.same(decoded.to, prepared.call.to)
      || !io.same(decoded.data, prepared.call.data) || decoded.value !== prepared.call.value || decoded.operation !== 0n) throw Error("Safe inner payable CALL differs");
    if (io.bytes(decoded.signatures, 16384) === "0x") throw Error("Safe signature bytes required");
    const previous = at.blockNumber - 1;
    await io.runtimes(p, [{ address: prepared.caller, codeHash: o.safeCodeHash }], previous);
    await io.runtimes(p, [{ address: prepared.caller, codeHash: o.safeCodeHash }], at.blockNumber);
    io.equal(await io.read(p, prepared.caller, safeABI, "nonce", [], previous), o.nonce, "Safe preceding nonce differs");
    io.equal(await io.read(p, prepared.caller, safeABI, "nonce", [], at.blockNumber), o.nonce + 1n, "Safe ending nonce differs");
    const values = [...Array.from(decoded).slice(0, 9), o.nonce];
    const calculated = TypedDataEncoder.hash({ chainId: saved.deployment.chainId, verifyingContract: prepared.caller }, safeTypes,
      Object.fromEntries(safeFields.map((key, i) => [key, values[i]])));
    io.equal(calculated, o.expectedSafeTxHash, "Independent Safe hash differs");
    io.equal(await io.read(p, prepared.caller, safeABI, "getTransactionHash", values, previous), o.expectedSafeTxHash, "Original Safe hash differs");
    const topic = safeABI.getEvent("ExecutionSuccess")!.topicHash, failure = safeABI.getEvent("ExecutionFailure")!.topicHash;
    const matching = logs.filter(v => io.same(v.address, prepared.caller) && [topic, failure].some(t => io.same(t, v.topics[0])));
    if (matching.length !== 1 || !io.same(matching[0]!.topics[0], topic)) throw Error("Exactly one successful Safe execution required");
    const selected = matching[0]!, eventABI = selected.topics.length === 1 ? safeABI : indexedSafe;
    const ev = io.events([selected], prepared.caller, eventABI, "ExecutionSuccess")[0]!;
    io.equal(ev.fields.txHash, o.expectedSafeTxHash, "Safe success hash differs"); safeIndex = selected.index;
  }
  return { ...mined, safeIndex };
}
interface MembershipMutation extends GovernanceExecutorV2Membership {
  readonly schemaVersion: bigint; readonly present: boolean; readonly mutationCause: bigint;
  readonly rawIndex: bigint; readonly remainingCount: bigint;
}
function membershipTransition(saved: GovernanceExecutorV2Capture, timestamp: bigint) {
  const q = saved.prepared.request, scheduling = scheduleRequest(q), pageRows = saved.observation.memberships.map(v => ({ scopeHash: v.scopeHash, rows: [...v.rows] }));
  const events: MembershipMutation[] = [];
  for (const page of pageRows) {
    const remove = (index: number, cause: bigint) => {
      const row = page.rows[index]!; page.rows[index] = page.rows[page.rows.length - 1]!; page.rows.pop();
      events.push({ ...row, schemaVersion: 1n, present: false, mutationCause: cause, rawIndex: BigInt(index), remainingCount: BigInt(page.rows.length) });
    };
    if (scheduling || q.method === "pruneElapsedTerminalFreezeActions") {
      for (let i = 0; i < page.rows.length;) { if (timestamp >= page.rows[i]!.vetoDeadline) remove(i, 2n); else i++; }
      if (scheduling) {
        const member = { scopeHash: page.scopeHash, actionId: saved.observation.actionId!, proposer: saved.prepared.caller,
          usesRootCapacity: io.same(saved.prepared.caller, saved.observation.root!.address), vetoDeadline: scheduling.notBefore };
        const index = page.rows.length; page.rows.push(member);
        events.push({ ...member, schemaVersion: 1n, present: true, mutationCause: 1n, rawIndex: BigInt(index), remainingCount: BigInt(page.rows.length) });
      }
    } else if ("actionId" in q) {
      const index = page.rows.findIndex(v => v.actionId === q.actionId); if (index >= 0) remove(index, 3n);
    }
  }
  return { pages: pageRows, events };
}
async function endingPages(p: io.Reader, d: GovernanceExecutorV2Deployment, expected: readonly MembershipPage[], prior: readonly MembershipPage[], tag: number) {
  for (const page of expected) {
    io.equal(await rows(p, d, "terminalFreezeActionPage", [page.scopeHash, 0n, 64n], tag), [page.rows.map(v => v.actionId), page.rows.map(v => v.vetoDeadline), BigInt(page.rows.length)], "Ending raw membership order differs");
    const proposers = [...new Set([...page.rows, ...(prior.find(v => v.scopeHash === page.scopeHash)?.rows ?? [])].map(v => v.proposer))];
    for (const proposer of proposers) io.equal(await rows(p, d, "terminalFreezeLiveActionUsage", [page.scopeHash, proposer], tag),
      [BigInt(page.rows.length), BigInt(page.rows.filter(v => !v.usesRootCapacity).length), BigInt(page.rows.filter(v => !v.usesRootCapacity && v.proposer === proposer).length)], "Ending membership usage differs");
  }
}
function actionForSchedule(saved: GovernanceExecutorV2Capture) {
  const q = scheduleRequest(saved.prepared.request)!; const calls = callWitness(saved.prepared.request);
  return gov.normalizeGovernanceExecutorV2Action({ status: 1n, actionClass: q.actionClass, target: calls[0]!.target,
    value: calls.reduce((sum, c) => sum + c.value, 0n), selector: calls[0]!.selector, callHash: q.callsHash,
    scopeHash: q.scopeHash, oldValueHash: q.oldValueHash, newValueHash: q.newValueHash, notBefore: q.notBefore, expiresAfter: q.expiresAfter,
    proposer: saved.prepared.caller, executor: ZA, canceller: ZA, vetoer: ZA, reasonHash: q.reasonHash, reasonURI: q.reasonURI, manifestHash: q.manifestHash });
}
const lifecycleEvents = ["GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceActionCancelled", "GovernanceActionVetoed", "GovernanceActionExpired", "GovernanceCallDataPublished", "TerminalFreezeActionMembershipUpdated", "TerminalFreezeGuardianConfigCommitted", "GovernanceActionPolicyValidated"] as const;
/** Conservative attribution: exact preceding-block capture state and exact ending lifecycle state.
 * Target side effects, intermediate traces and same-block compensating changes are not proven. */
export async function reconcileGovernanceExecutorV2Receipt(p: io.ReceiptReader, input: GovernanceExecutorV2Capture,
  transactionHash: Hex, inputOptions: GovernanceExecutorV2ReceiptOptions) {
  const saved = savedCapture(input), hash = io.hash(transactionHash), transportOptions = receiptOptions(inputOptions);
  const m = await payableTransport(p, saved, hash, transportOptions), d = saved.deployment, q = saved.prepared.request;
  const prior = await io.chain(p, d.chainId, m.observed.blockNumber - 1); await revalidate(p, saved, prior);
  await io.runtimes(p, [d.executor, ...d.linkedDependencies], m.observed.blockNumber);
  const scheduling = scheduleRequest(q), executing = q.method === "executeGovernanceAction" || q.method === "executeGovernanceBatch";
  if (scheduling) validateWindow(scheduling.actionClass, scheduling.notBefore, scheduling.expiresAfter, m.observed.timestamp);
  if (saved.observation.history) {
    const a = saved.observation.history.action, now = m.observed.timestamp;
    if (executing && (now < a.notBefore || now > a.expiresAfter) || q.method === "cancelGovernanceAction" && now > a.expiresAfter
      || q.method === "vetoTerminalFreeze" && now >= a.notBefore || q.method === "materializeExpiredAction" && now <= a.expiresAfter) throw Error("Mined lifecycle time window differs");
  }
  // Re-pin reached original runtime facts, not unrelated deployment targets.
  if (saved.observation.root) await io.runtime(p, saved.observation.root, m.observed.blockNumber);
  if (saved.observation.guardian || q.method === "vetoTerminalFreeze") await io.runtime(p, d.roleRegistry, m.observed.blockNumber);
  for (const pin of saved.observation.targetRuntimes) {
    if (pin.empty) io.equal(await p.getCode(pin.address, m.observed.blockNumber), "0x", "Native receiver runtime changed");
    else await io.runtime(p, pin, m.observed.blockNumber);
  }
  const membership = membershipTransition(saved, m.observed.timestamp), actualMembership = expectedEvents(m.logs, d, "TerminalFreezeActionMembershipUpdated", membership.events.length);
  actualMembership.forEach((e, index) => io.equal(e.fields, membership.events[index], "Membership mutation/order differs"));
  await endingPages(p, d, membership.pages, saved.observation.memberships, m.observed.blockNumber);
  const expected = new Map<string, readonly (readonly unknown[])[]>();
  const add = (name: string, fields: readonly unknown[]) => expected.set(name, [...(expected.get(name) ?? []), fields]);
  let action: gov.GovernanceExecutorV2Action | null = null, pointer = saved.observation.publication;
  const callKey = (q.method === "publishGovernanceCallData" || q.method === "scheduleGovernanceAction" || q.method === "scheduleGovernanceBatch") ? gov.governanceExecutorV2PublicationKey(saved.observation.callDatas) : null;
  if (callKey) {
    pointer = io.address(await read(p, d, "publishedCallData", [callKey], m.observed.blockNumber));
    if (saved.observation.publication !== ZA) io.equal(pointer, saved.observation.publication, "Publication retry pointer changed");
    else {
      await carrier(p, pointer, saved.observation.callDatas, m.observed.blockNumber);
      add("GovernanceCallDataPublished", [1n, callKey, pointer, saved.prepared.caller]);
    }
  }
  if (scheduling) {
    action = actionForSchedule(saved); const a = action, actionId = saved.observation.actionId!;
    add("GovernanceActionScheduled", [1n, actionId, a.actionClass, a.target, a.value, a.selector, a.callHash, a.scopeHash, a.oldValueHash, a.newValueHash, a.notBefore, a.expiresAfter, saved.observation.nonce, a.proposer, a.reasonHash, a.reasonURI, a.manifestHash]);
    if (a.actionClass === 2n) add("TerminalFreezeGuardianConfigCommitted", [1n, actionId, saved.observation.guardian!.commitment]);
    add("GovernanceActionPolicyValidated", [1n, actionId, 1n, saved.observation.catalog![0], saved.observation.catalog![1]]);
    io.equal(await read(p, d, "scheduledCallDataPointer", [actionId], m.observed.blockNumber), pointer, "Scheduled pointer differs");
    io.equal(await read(p, d, "scheduledCallData", [actionId], m.observed.blockNumber), saved.observation.callDatas, "Scheduled calldata differs");
  } else if (saved.observation.history) {
    const old = saved.observation.history.action, actionId = saved.observation.actionId!;
    if (executing) {
      action = { ...old, status: 2n, executor: saved.prepared.caller };
      add("GovernanceActionExecuted", [1n, actionId, old.actionClass, old.target, old.value, old.selector, old.callHash, old.scopeHash, old.oldValueHash, old.newValueHash, saved.prepared.caller, old.manifestHash]);
      add("GovernanceActionPolicyValidated", [1n, actionId, 2n, saved.observation.catalog![0], saved.observation.catalog![1]]);
    } else if (q.method === "cancelGovernanceAction") {
      action = { ...old, status: 3n, canceller: saved.prepared.caller };
      add("GovernanceActionCancelled", [1n, actionId, old.actionClass, old.target, old.selector, old.callHash, old.scopeHash, saved.prepared.caller, q.reasonHash, ""]);
    } else if (q.method === "vetoTerminalFreeze") {
      action = { ...old, status: 5n, vetoer: saved.prepared.caller };
      add("GovernanceActionVetoed", [1n, actionId, old.actionClass, saved.prepared.caller, old.scopeHash, q.reasonHash]);
    } else if (q.method === "materializeExpiredAction") {
      action = { ...old, status: 4n }; add("GovernanceActionExpired", [1n, actionId, old.actionClass, saved.prepared.caller]);
    }
  }
  const indexes = new Map<string, number[]>();
  for (const name of lifecycleEvents) {
    if (name === "TerminalFreezeActionMembershipUpdated") continue;
    const want = expected.get(name) ?? [], actual = expectedEvents(m.logs, d, name, want.length);
    actual.forEach((e, index) => io.equal(e.fields, Object.fromEntries(iface().getEvent(name)!.inputs.map((field, i) => [field.name, want[index]![i]])), `${name} differs`));
    indexes.set(name, actual.map(e => e.index));
  }
  const main = ["GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceActionCancelled", "GovernanceActionVetoed", "GovernanceActionExpired"].flatMap(name => indexes.get(name) ?? []);
  const guardianIndex = indexes.get("TerminalFreezeGuardianConfigCommitted")?.[0], policyIndex = indexes.get("GovernanceActionPolicyValidated")?.[0], pubIndex = indexes.get("GovernanceCallDataPublished")?.[0];
  if (main.length && actualMembership.some(e => e.index >= (guardianIndex ?? main[0]!)) || guardianIndex !== undefined && guardianIndex >= main[0]!
    || policyIndex !== undefined && policyIndex <= main[0]! || pubIndex !== undefined && main.length && pubIndex >= (actualMembership[0]?.index ?? guardianIndex ?? main[0]!)) throw Error("Original lifecycle event order differs");
  if (action) {
    const end = await actionState(p, d, saved.observation.actionId!, m.observed, saved.options.gasLimit);
    io.equal(end.action, action, "Ending action differs"); io.equal(end.facts.status, action.status, "Ending raw action status differs");
    if (action.actionClass === 2n) io.equal(await read(p, d, "terminalFreezeGuardianConfigCommitment", [saved.observation.actionId!], m.observed.blockNumber), scheduling ? saved.observation.guardian!.commitment : saved.observation.history!.schedule.guardianCommitment, "Stored guardian commitment differs");
  }
  const terminal = !!saved.observation.history;
  io.equal(await read(p, d, "governanceNonce", [], m.observed.blockNumber), saved.observation.nonce + (scheduling ? 1n : 0n), "Ending governance nonce differs");
  io.equal(await read(p, d, "pendingScheduledActionCount", [], m.observed.blockNumber), saved.observation.pending + (scheduling ? 1n : terminal ? -1n : 0n), "Ending pending count differs");
  io.equal(await rows(p, d, "currentAction", [], m.observed.blockNumber), [false, ZERO, 0n, ZERO, ZERO, ZERO], "Ending executing context is not clear");
  io.finish(m.logs, [d.executor.address], m.safeIndex);
  await io.unchanged(p, prior); await io.unchanged(p, m.observed);
  return own({ observed: m.observed, prior, transactionHash: hash, captureHash: saved.captureHash, execution: transportOptions.execution,
    action, publication: pointer, memberships: membership.pages, originalCallReceiptAuthenticated: true as const,
    targetEffectsIndependentlyVerified: false as const, sameBlockIntermediateEffectsIndependentlyVerified: false as const,
    ownerSignaturesIndependentlyVerified: false as const, safeImplementationIndependentlyVerified: false as const });
}
