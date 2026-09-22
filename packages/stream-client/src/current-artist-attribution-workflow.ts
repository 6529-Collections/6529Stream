/** Original Attribution lifecycle. The original Registry/Executor call is the signature and admission boundary. */
import { Interface, TypedDataEncoder, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import * as a from "./current-artist-attribution.js";
import * as executor from "./current-governance-executor-v2-workflow.js";

export type ArtistAttributionReader = io.Reader;
export type ArtistAttributionReceiptReader = io.ReceiptReader;
export interface ArtistAttributionDeployment {
  readonly chainId: bigint;
  readonly registry: io.CodePin;
  readonly coordinator: io.CodePin;
  readonly owners: readonly io.CodePin[];
  readonly archive: io.CodePin;
  readonly core: io.CodePin;
  readonly mintManager: io.CodePin;
  readonly roleRegistry: io.CodePin;
  /** Exact runtime closure reviewed for this deployed suite, including read and writer extensions. */
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface ArtistAttributionHistoryDeployment {
  readonly chainId: bigint;
  readonly registry: Address;
  readonly core: Address;
  readonly mintManager: Address;
  readonly coordinator: Address;
  readonly attribution: io.CodePin;
  readonly archive: io.CodePin;
  /** Only the retained local getter closure; no current Identity or governance admission. */
  readonly historyDependencies: readonly io.CodePin[];
}
export interface ArtistAttributionWorkflowOptions {
  readonly blockTag: number;
  readonly gasLimit: bigint;
  /** Original same-instance single-call Executor execution capture; never a simulated caller override. */
  readonly governance?: executor.GovernanceExecutorV2Capture;
}
export type ArtistAttributionReceiptOptions = Readonly<
  { execution: "direct" } |
  { execution: "safe"; expectedSafeTxHash: Hex; nonce: bigint; safeCodeHash: Hex }
>;
const ZERO = io.ZERO, ZA = io.ZERO_ADDRESS, own = <T>(v: T): T => io.freeze(structuredClone(v));
const SUITE = "tuple(address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator)";
const IDENTITY = "tuple(address authorityAddress,uint8 authorityClass,uint8 status,uint64 registeredAt,uint64 lastAuthorityActionAt,bytes32 identityRecordHash,string identityRecordURI,string displayName,uint256 nonceHint)";
const CONTEST = "tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 subjectRecordHash,bytes32 evidenceHash,bytes32 reasonHash) terms,address contester,uint64 contestedAt,uint8 priorStatus,bytes32 guardianSetRecordHash,bytes32 capturedGuardianSetRecordHash,bytes32 pendingTransitionRecordHash,bytes32 executedTransitionRecordHash,bytes32 governanceWitnessHash)";
const CAUSE = "tuple(bytes32 causeHash,tuple(bytes32 artistId,uint8 kind,bytes32 referenceHash,address actor,bytes32 reasonHash,bytes32 evidenceHash,uint64 enteredAt,address incumbent,uint8 authorityClass,uint8 priorStatus,bytes32 pendingTransitionHash,bytes32 executedTransitionHash,bytes32 previousCauseHash,bytes32 previousResolutionHash,bytes32 actorRetirementHash) facts)";
const DORMANCY_TERMINAL = "tuple(bytes32 recordHash,bytes32 noticeHash,address actor,uint8 authorityClass,uint64 observedAt,uint64 appointmentBlock,tuple(address authority,uint8 authorityClass,uint32 capabilities,bytes32 designation,bytes32 directive,bytes32 guardian,bytes32 stewardGrantRecordHash,uint64 postSeconds,uint64 standingTail) plan,bytes32 evidenceHash,bytes32 actionId,bytes32 witnessHash,uint64 delegationEpoch)";
const DORMANCY_NOTICE = "tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 evidenceHash,string reasonURI) terms,address incumbent,uint64 initiatedAt,uint64 noticeEndsAt,uint64 inactivitySeconds,uint64 noticeSeconds,uint64 timingRevision,uint64 priorLivenessAt,uint256 priorActivity,bytes32 actionId,bytes32 witnessHash)";
const observationABI = new Interface([
  `function suiteConfiguration() view returns(${SUITE})`,
  "function configurationHash() view returns(bytes32)",
  "function deploymentChainId() view returns(uint256)",
  "function core() view returns(address)", "function mintManager() view returns(address)",
  "function artistRegistry() view returns(address)", "function operationCoordinator() view returns(address)",
  "function archiveV2() view returns(address)", "function domainId() view returns(bytes32)",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  `function ownerStateSnapshotV2() view returns(${a.ARTIST_ATTRIBUTION_SNAPSHOT_TUPLE})`,
  `function binding(uint256 collectionId) view returns(${a.ARTIST_ATTRIBUTION_BINDING_TUPLE})`,
  "function collectionExists(uint256 collectionId) view returns(bool)",
  "function getSatellitePointer(bytes32 pointerType) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function governanceAuthority() view returns(address)",
  "function hasRole(bytes32 role,address account) view returns(bool)",
  "function roleMutationState(bytes32 role) view returns(bytes32 chainHash,uint64 revision)",
  `function identity(bytes32 artistId) view returns(${IDENTITY})`,
  "function authorityState(bytes32 artistId) view returns(address,uint8,uint8,bytes32)",
  "function nonceUsed(bytes32 artistId,uint256 nonce) view returns(bool)",
  "function delegatedNonceState(bytes32 artistId,address delegate,uint256 nonce) view returns(bool,uint256)",
  "function lastArtistTransition(bytes32 artistId) view returns(bytes32)",
  "function latestIdentityContest(bytes32 artistId) view returns(bytes32)",
  "function latestIdentityContestDismissal(bytes32 artistId) view returns(bytes32)",
  "function dormancyNotice(bytes32 artistId) view returns(bytes32,uint8,bytes32)",
  `function dormancyRecord(bytes32 noticeHash) view returns(${DORMANCY_NOTICE},uint8,${DORMANCY_TERMINAL})`,
  `function identityContestRecord(bytes32 recordHash) view returns(${CONTEST})`,
  `function identityContestCause(bytes32 causeHash) view returns(${CAUSE})`,
  "function artistNativeReceiptCount() view returns(uint256)",
  "function artistNativeReceiptAt(uint256 index) view returns(tuple(uint16 operation,bytes32 artistId,uint256 collectionId,bytes32 recordHash))",
  "function artistNativeReceiptRevisionAt(uint256 index) view returns(uint64)"
]);
const archiveABI = new Interface([
  "function artistRegistry() view returns(address)", "function operationCoordinator() view returns(address)",
  "function artistEvidenceMetadataV2(bytes32 evidenceId,uint64 evidenceVersion) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32 evidenceId,uint64 evidenceVersion) view returns(bytes evidence)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)"
]);
const identityEvents = new Interface([
  "event ArtistIdentityContested(uint16 schemaVersion,bytes32 indexed artistId,address indexed contester,bytes32 subjectRecordHash,bytes32 evidenceHash,bytes32 reasonHash,uint64 contestedAt,bytes32 contestRecordHash)",
  "event ArtistIdentityContestCauseCaptured(uint16 schemaVersion,bytes32 indexed artistId,bytes32 indexed causeHash,uint8 kind,bytes32 referenceHash,address actor,bytes32 reasonHash,bytes32 evidenceHash,uint64 enteredAt,address incumbent,uint8 authorityClass,uint8 priorStatus,bytes32 pendingTransitionHash,bytes32 executedTransitionHash,bytes32 previousCauseHash,bytes32 previousResolutionHash,bytes32 actorRetirementHash)",
  "event ArtistDormancyCancelled(uint16 schemaVersion,bytes32 indexed artistId,bytes32 indexed noticeHash,address canceller,uint8 authorityClass,bytes32 cancellationHash)",
  `event ArtistDormancyCancellationContext(uint16 schemaVersion,bytes32 indexed artistId,bytes32 indexed recordHash,tuple(uint256 chainId,address registry,address identityOwner,address recorder,uint8 recorderAuthorityClass) context,${DORMANCY_TERMINAL} terminal,uint256 activityCount)`
]);
const safeABI = new Interface([
  "function nonce() view returns(uint256)",
  "function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)",
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool success)"
]);
const safeNames = ["to", "value", "data", "operation", "safeTxGas", "baseGas", "gasPrice", "gasToken", "refundReceiver", "nonce"];
const safeTypes = { SafeTx: safeNames.map((name, i) => ({ name, type: ["address", "uint256", "bytes", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256"][i]! })) };
type Prepared = ReturnType<typeof a.prepareArtistAttributionCall>;
type Request = a.ArtistAttributionRequest;
type Snapshot = a.ArtistAttributionSnapshot;
type Facts = Record<string, unknown>;
const captured = new WeakSet<object>();
const governance = new WeakMap<object, executor.GovernanceExecutorV2Capture>();
function deployment(v: ArtistAttributionDeployment): ArtistAttributionDeployment {
  io.keys(v, ["chainId", "registry", "coordinator", "owners", "archive", "core", "mintManager", "roleRegistry", "linkedDependencies"]);
  if (!Array.isArray(v.owners) || v.owners.length !== 7) throw Error("Exactly seven original owners required");
  return own({ chainId: io.uint(v.chainId), registry: io.codePin(v.registry), coordinator: io.codePin(v.coordinator), owners: io.pinList(v.owners), archive: io.codePin(v.archive), core: io.codePin(v.core), mintManager: io.codePin(v.mintManager), roleRegistry: io.codePin(v.roleRegistry), linkedDependencies: io.pinList(v.linkedDependencies) });
}
function coords(d: ArtistAttributionDeployment | ArtistAttributionHistoryDeployment) {
  return { chainId: d.chainId, registry: typeof d.registry === "string" ? d.registry : d.registry.address, core: typeof d.core === "string" ? d.core : d.core.address };
}
function pins(d: ArtistAttributionDeployment) { return [d.registry, d.coordinator, ...d.owners, d.archive, d.core, d.mintManager, d.roleRegistry, ...d.linkedDependencies]; }
function recipe(p: Prepared) {
  const op = p.operationId;
  const read = op === 10n ? 0x10 : op === 44n || op === 50n || op === 61n ? 0x15 : op === 46n ? 0x11 : op === 48n || op === 49n ? 0x14 : 0x17;
  const write = op === 10n || op === 46n || op === 50n || (op === 44n && p.requiresGovernance) ? 0x10 : 0x14;
  return { read, write };
}
function collection(q: Request): bigint { return "filing" in q ? q.filing.collectionId : "resolution" in q ? q.resolution.collectionId : q.collectionId; }
function zeroSnapshot(): Snapshot { return { domainId: ZERO, revision: 0n, stateRoot: ZERO, recordChainTip: ZERO }; }
async function rows(p: io.Reader, target: Address, name: string, args: readonly unknown[], tag: number, gas: bigint) { return io.rpc(p, target, observationABI, name, args, tag, undefined, gas); }
async function ownerRead<T>(p: io.Reader, d: ArtistAttributionDeployment, method: string, args: readonly unknown[], tag: number, gas: bigint): Promise<T> { return io.read(p, d.owners[4]!.address, a.artistAttributionInterface("owner"), method, args, tag, undefined, gas); }
async function snapshots(p: io.Reader, d: ArtistAttributionDeployment, mask: number, tag: number, gas: bigint): Promise<readonly Snapshot[]> {
  const out: Snapshot[] = [];
  for (let i = 0; i < 7; i++) out.push(mask & (1 << i) ? a.normalizeArtistAttributionSnapshot((await rows(p, d.owners[i]!.address, "ownerStateSnapshotV2", [], tag, gas))[0] as Snapshot) : zeroSnapshot());
  return out;
}
async function binding(p: io.Reader, d: ArtistAttributionDeployment, tag: number, gas: bigint) {
  await io.runtimes(p, pins(d), tag);
  const s = (await rows(p, d.coordinator.address, "suiteConfiguration", [], tag, gas))[0] as { owners: Address[]; registry: Address; archive: Address; core: Address; mintManager: Address; roleRegistry: Address };
  io.equal([s.registry, s.archive, ...s.owners, s.core, s.mintManager, s.roleRegistry].map(v => io.address(v)), [d.registry.address, d.archive.address, ...d.owners.map(v => v.address), d.core.address, d.mintManager.address, d.roleRegistry.address], "Suite bindings differ");
  io.equal(await rows(p, d.coordinator.address, "deploymentChainId", [], tag, gas), [d.chainId], "Coordinator chain differs");
  for (const [method, expected] of [["core", d.core.address], ["mintManager", d.mintManager.address], ["operationCoordinator", d.coordinator.address]] as const) io.equal(await rows(p, d.registry.address, method, [], tag, gas), [expected], "Registry binding differs");
  for (const v of d.owners) {
    for (const [method, expected] of [["artistRegistry", d.registry.address], ["operationCoordinator", d.coordinator.address], ["archiveV2", d.archive.address], ["core", d.core.address], ["mintManager", d.mintManager.address]] as const) io.equal(await rows(p, v.address, method, [], tag, gas), [expected], "Owner binding differs");
    io.equal(await rows(p, v.address, "deploymentChainId", [], tag, gas), [d.chainId], "Owner chain differs");
  }
  for (const [method, expected] of [["artistRegistry", d.registry.address], ["operationCoordinator", d.coordinator.address]] as const) io.equal(await io.rpc(p, d.archive.address, archiveABI, method, [], tag, undefined, gas), [expected], "Archive binding differs");
  const pointer = await rows(p, d.core.address, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag, gas);
  if (!io.same(pointer[0], d.registry.address) || !io.same(pointer[1], d.registry.codeHash) || (await rows(p, d.registry.address, "artistRegistryCutover", [], tag, gas))[0] !== false) throw Error("Registry is not current");
  return io.hash((await rows(p, d.coordinator.address, "configurationHash", [], tag, gas))[0]);
}
async function observe(p: io.Reader, d: ArtistAttributionDeployment, prepared: Prepared, at: io.Block, gas: bigint) {
  const configurationHash = await binding(p, d, at.blockNumber, gas), q = prepared.request, cid = collection(q), tag = at.blockNumber;
  if ((await rows(p, d.core.address, "collectionExists", [cid], tag, gas))[0] !== true) throw Error("Collection unavailable");
  const before = await snapshots(p, d, recipe(prepared).read, tag, gas);
  const counts: bigint[] = [];
  for (const i of [2, 4]) counts.push(recipe(prepared).read & (1 << i) ? io.uint((await rows(p, d.owners[i]!.address, "artistNativeReceiptCount", [], tag, gas))[0]) : 0n);
  if (prepared.operationId === 10n) return own({ configurationHash, before, counts, facts: { claims: await io.rpc(p, d.owners[4]!.address, a.artistAttributionInterface("owner"), "attributionClaims", [cid], tag, undefined, gas) } as Facts, context: null as a.ArtistAttributionContext | null });
  const state = await io.rpc(p, d.owners[4]!.address, a.artistAttributionInterface("owner"), "attributionState", [cid], tag, undefined, gas);
  const terminalRecord = "expectedRepudiation" in q ? a.normalizeArtistAttributionRepudiationRecord(await ownerRead(p, d, "attributionRepudiationRecord", [q.expectedRepudiation], tag, gas)) : null;
  const b = prepared.operationId === 48n || prepared.operationId === 49n ? null : a.normalizeArtistAttributionBinding((await rows(p, d.owners[0]!.address, "binding", [cid], tag, gas))[0] as a.ArtistAttributionBinding);
  const generation = "filing" in q ? q.filing.bindingGeneration : "resolution" in q ? q.resolution.bindingGeneration : terminalRecord!.terms.bindingGeneration;
  io.equal(state[1], generation, "Attribution generation changed");
  if (b) io.equal(b.generation, generation, "Binding generation differs");
  const head = a.normalizeArtistAttributionHead(await ownerRead(p, d, "attributionDispute", [cid, generation], tag, gas));
  const rawPending = io.hash(await ownerRead(p, d, "rawPendingRepudiation", [cid], tag, gas), true);
  const facts: Facts = { state, binding: b, head, rawPending };
  if ((prepared.operationId === 44n || prepared.operationId === 47n) && rawPending !== ZERO) {
    facts.pendingRecord = a.normalizeArtistAttributionRepudiationRecord(await ownerRead(p, d, "attributionRepudiationRecord", [rawPending], tag, gas));
    facts.pendingTerminal = a.normalizeArtistAttributionTerminal(await ownerRead(p, d, "attributionRepudiationTerminal", [rawPending], tag, gas));
  }
  if (prepared.signingPayload) {
    const method = prepared.operationId === 47n ? "attributionRepudiationDigest" : "attributionDisputeDigest";
    if (!("filing" in q)) throw Error("Missing signed filing");
    io.equal(await io.read(p, d.registry.address, a.artistAttributionInterface("registry"), method, [q.filing, q.authorization], tag, undefined, gas), prepared.signingPayload.digest, "Original signing digest differs");
  }
  if (head.disputeRecordHash !== ZERO) facts.opening = a.normalizeArtistAttributionRecord(await ownerRead(p, d, "attributionDisputeRecord", [head.disputeRecordHash], tag, gas));
  if ("expectedRepudiation" in q) {
    facts.repudiation = terminalRecord;
    facts.terminal = a.normalizeArtistAttributionTerminal(await ownerRead(p, d, "attributionRepudiationTerminal", [q.expectedRepudiation], tag, gas));
  }
  const artistId = "standing" in q && q.standing.artistId !== ZERO ? q.standing.artistId : b?.artistId ?? terminalRecord!.artistId;
  if (artistId !== ZERO) {
    facts.artistId = artistId;
    facts.identity = (await rows(p, d.owners[2]!.address, "identity", [artistId], tag, gas))[0];
    facts.authority = await rows(p, d.owners[2]!.address, "authorityState", [artistId], tag, gas);
    facts.identityHead = await Promise.all(["lastArtistTransition", "latestIdentityContest", "latestIdentityContestDismissal"].map(method => rows(p, d.owners[2]!.address, method, [artistId], tag, gas).then(v => v[0])));
    facts.dormancy = await rows(p, d.owners[2]!.address, "dormancyNotice", [artistId], tag, gas);
    if ("authorization" in q && !prepared.requiresGovernance) {
      // Delegated replay is checked by the original Identity admission. The principal lane is independently observed here.
      if (!("standing" in q) || q.standing.delegation === ZERO) {
        facts.nonceUsed = (await rows(p, d.owners[2]!.address, "nonceUsed", [artistId, q.authorization.nonce], tag, gas))[0];
        if (facts.nonceUsed !== false) throw Error("Signed nonce already used");
      }
    }
  }
  let context: a.ArtistAttributionContext | null = null;
  if (prepared.requiresGovernance) {
    const name = q.kind === "resolveAttributionDispute" ? "attributionDisputeResolutionContext" : "attributionDisputeOpeningContext";
    context = a.normalizeArtistAttributionContext(await io.read(p, d.registry.address, a.artistAttributionInterface("registry"), name, ["resolution" in q ? q.resolution : "filing" in q ? q.filing : null], tag, undefined, gas));
  }
  return own({ configurationHash, before, counts, facts, context });
}
export interface ArtistAttributionObservation {
  readonly configurationHash: Hex;
  readonly before: readonly Snapshot[];
  readonly counts: readonly bigint[];
  readonly facts: Readonly<Facts>;
  readonly context: a.ArtistAttributionContext | null;
}
export interface ArtistAttributionCapture {
  readonly deployment: ArtistAttributionDeployment;
  readonly prepared: Prepared;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly observation: ArtistAttributionObservation;
  readonly governanceCaptureHash: Hex | null;
  readonly captureHash: Hex;
  readonly originalCallAdmissionChecked: false;
  readonly privateAuxiliaryEffectsIndependentlyReconstructed: false;
}
function saved(input: ArtistAttributionCapture): ArtistAttributionCapture {
  if (!captured.has(input)) throw Error("Capture must originate from this workflow instance");
  return input;
}
function governanceJoin(d: ArtistAttributionDeployment, prepared: Prepared, observation: ArtistAttributionObservation, at: io.Block, g: executor.GovernanceExecutorV2Capture) {
  if (!prepared.requiresGovernance || !observation.context) throw Error("Unexpected governance route");
  io.equal(g.observed, at, "Executor and Artist captures must share block");
  io.equal(g.deployment.chainId, d.chainId);
  io.equal(g.deployment.executor.address, prepared.caller, "Registry actor must be actual Executor");
  const q = g.prepared.request;
  if (q.method !== "executeGovernanceAction" && q.method !== "executeGovernanceBatch") throw Error("Expected original Executor execution capture");
  const calls = q.method === "executeGovernanceAction" ? [q.call] : q.calls;
  const data = q.method === "executeGovernanceAction" ? [q.callData] : q.callDatas;
  if (calls.length !== 1 || data.length !== 1) throw Error("Attribution workflow supports one governed target per execution");
  const c = calls[0]!, x = observation.context;
  io.equal([c.target, c.value, c.selector, c.callDataHash, c.scopeHash, c.oldValueHash, c.newValueHash], [d.registry.address, 0n, prepared.call.data.slice(0, 10), keccak256(prepared.call.data), x.scopeHash, x.oldValueHash, x.newValueHash], "Governed target context differs");
  io.equal(data[0], prepared.call.data, "Governed call bytes differ");
}
export async function captureArtistAttribution(p: io.ReceiptReader, input: ArtistAttributionDeployment, caller: Address, request: Request, options: ArtistAttributionWorkflowOptions): Promise<ArtistAttributionCapture> {
  const d = deployment(input), prepared = a.prepareArtistAttributionCall(coords(d), io.address(caller), request);
  io.keys(options, ["blockTag", "gasLimit"], ["governance"]);
  const tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit), g = options.governance;
  if (prepared.requiresGovernance !== Boolean(g)) throw Error("Governed operations require actual Executor execution capture");
  const at = await io.chain(p, d.chainId, tag), observation = await observe(p, d, prepared, at, gasLimit);
  if (g) {
    governanceJoin(d, prepared, observation, at, g);
    io.equal(await rows(p, d.mintManager.address, "governanceAuthority", [], tag, gasLimit), [g.deployment.executor.address], "Canonical manager authority differs");
  }
  const body = { deployment: d, prepared, observed: at, gasLimit, observation, governanceCaptureHash: g?.captureHash ?? null, originalCallAdmissionChecked: false as const, privateAuxiliaryEffectsIndependentlyReconstructed: false as const };
  await io.unchanged(p, at);
  const result = own({ ...body, captureHash: io.fingerprint(body) });
  captured.add(result); if (g) governance.set(result, g); return result;
}
async function revalidate(p: io.Reader, s: ArtistAttributionCapture, at: io.Block, gas: bigint) {
  if (at.blockNumber < s.observed.blockNumber) throw Error("Observation predates capture");
  await io.unchanged(p, s.observed);
  io.equal(await observe(p, s.deployment, s.prepared, at, gas), s.observation, "Artist facts changed; recapture");
}
async function originalCall(p: io.Reader, s: ArtistAttributionCapture, at: io.Block, gas: bigint) {
  const f = a.artistAttributionInterface("registry"), method = s.prepared.request.kind;
  const raw = io.bytes(await p.call({ from: s.prepared.caller, to: s.prepared.call.to, data: s.prepared.call.data, value: 0n, blockTag: at.blockNumber, gasLimit: gas }));
  const result = f.decodeFunctionResult(method, raw);
  if (!io.same(f.encodeFunctionResult(method, result), raw)) throw Error("Noncanonical original result");
  return f.getFunction(method)!.outputs.map((v, i) => io.plain(v, result[i]));
}
export async function simulateArtistAttribution(p: io.ReceiptReader, input: ArtistAttributionCapture, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const s = saved(input); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), gas = io.gas(options.gasLimit), at = await io.chain(p, s.deployment.chainId, tag);
  await revalidate(p, s, at, gas);
  const g = governance.get(s), result = g ? await executor.simulateGovernanceExecutorV2(p, g, { blockTag: tag, gasLimit: gas }) : await originalCall(p, s, at, gas);
  await io.unchanged(p, at);
  return own({ observed: at, captureHash: s.captureHash, result, originalCallAdmissionChecked: true as const, privateAuxiliaryEffectsIndependentlyReconstructed: false as const });
}
export async function inspectArtistAttributionCurrent(p: io.ReceiptReader, d: ArtistAttributionDeployment, caller: Address, request: Request, options: ArtistAttributionWorkflowOptions) {
  const capture = await captureArtistAttribution(p, d, caller, request, options);
  return { capture, simulation: await simulateArtistAttribution(p, capture, { blockTag: capture.observed.blockNumber, gasLimit: capture.gasLimit }) };
}
export async function observeArtistAttributionRefusal(p: io.ReceiptReader, input: ArtistAttributionCapture, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const s = saved(input); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), gas = io.gas(options.gasLimit), at = await io.chain(p, s.deployment.chainId, tag);
  if (tag < s.observed.blockNumber) throw Error("Observation predates capture");
  await io.unchanged(p, s.observed); await io.runtimes(p, pins(s.deployment), tag);
  const g = governance.get(s);
  if (g) return executor.observeGovernanceExecutorV2Refusal(p, g, { blockTag: tag, gasLimit: gas });
  try { const result = await originalCall(p, s, at, gas); await io.unchanged(p, at); return own({ status: "succeeded" as const, observed: at, result, capturePredictionChecked: false as const }); }
  catch (error) {
    await io.unchanged(p, at);
    const e = error as { code?: unknown; data?: unknown };
    return own({ status: e.code === "CALL_EXCEPTION" ? "reverted" as const : "rpc-failed" as const, observed: at, data: typeof e.data === "string" && /^0x[0-9a-fA-F]*$/.test(e.data) && e.data.length <= 131074 ? e.data as Hex : null, capturePredictionChecked: false as const });
  }
}

export interface ArtistAttributionHistoryLocator { readonly operationId: bigint; readonly actor: Address; readonly value: Hex }
export interface ArtistAttributionHistoryOptions {
  readonly blockTag: number;
  readonly gasLimit: bigint;
  /** Exact retained producer bytes; does not replace Archive metadata authentication. */
  readonly retainedPayload?: Hex;
}
function historyDeployment(raw: ArtistAttributionHistoryDeployment): ArtistAttributionHistoryDeployment {
  io.keys(raw, ["chainId", "registry", "core", "mintManager", "coordinator", "attribution", "archive", "historyDependencies"]);
  return own({ chainId: io.uint(raw.chainId), registry: io.address(raw.registry), core: io.address(raw.core), mintManager: io.address(raw.mintManager), coordinator: io.address(raw.coordinator), attribution: io.codePin(raw.attribution), archive: io.codePin(raw.archive), historyDependencies: io.pinList(raw.historyDependencies) });
}
function historyFrom(d: ArtistAttributionDeployment): ArtistAttributionHistoryDeployment { return { ...coords(d), mintManager: d.mintManager.address, coordinator: d.coordinator.address, attribution: d.owners[4]!, archive: d.archive, historyDependencies: d.linkedDependencies }; }
type LocalRecord = a.ArtistAttributionClaim | a.ArtistAttributionRecord | a.ArtistAttributionResolution | a.ArtistAttributionRepudiationRecord;
function required(v: unknown): Hex { return io.hash(v); }
async function historyAt(p: io.Reader, d: ArtistAttributionHistoryDeployment, locator: ArtistAttributionHistoryLocator, at: io.Block, gas: bigint, retained?: Hex) {
  await io.runtimes(p, [d.attribution, d.archive, ...d.historyDependencies], at.blockNumber);
  const evidenceId = a.artistAttributionEvidenceId(coords(d), d.coordinator, locator.operationId, locator.actor, locator.value);
  const metadata = await io.rpc(p, d.archive.address, archiveABI, "artistEvidenceMetadataV2", [evidenceId, 1n], at.blockNumber, undefined, gas);
  const [contentHash, pointer, size, appendedAtBlock] = metadata;
  required(contentHash); io.address(pointer);
  if (io.uint(size) === 0n || io.uint(size) > 24575n || io.uint(appendedAtBlock, 64) > BigInt(at.blockNumber)) throw Error("Invalid original Archive metadata");
  const raw = retained ?? io.bytes(await io.read(p, d.archive.address, archiveABI, "artistEvidenceBytesV2", [evidenceId, 1n], at.blockNumber, undefined, gas), 24575);
  if (!io.same(keccak256(raw), contentHash) || BigInt((raw.length - 2) / 2) !== size) throw Error("Archive payload differs");
  if (!retained) {
    const code = io.bytes(await p.getCode(io.address(pointer), at.blockNumber), 24576);
    if (!io.same(code, `0x00${raw.slice(2)}`)) throw Error("Archive STOP carrier differs");
  }
  const e = a.decodeArtistAttributionArchiveEnvelope(raw), op = locator.operationId;
  io.equal([e.version, e.operation, e.actor, e.value], [1n, op, locator.actor, locator.value], "Archive operation identity differs");
  required(e.configurationHash);
  const detail = a.decodeArtistAttributionArchiveDetail(op, e.payload);
  const isGoverned = detail.operationId === 44n && detail.g.actionId !== ZERO;
  const mask = op === 10n ? 0x10 : op === 44n || op === 50n || op === 61n ? 0x15 : op === 46n ? 0x11 : op === 48n || op === 49n ? 0x14 : 0x17;
  const writes = op === 10n || op === 46n || op === 50n || isGoverned ? 0x10 : 0x14;
  for (let i = 0; i < 7; i++) {
    const before = e.before_[i]!, after = e.after_[i]!;
    if (!(mask & (1 << i))) { io.equal(before, zeroSnapshot(), "Unselected before snapshot is not zero"); io.equal(after, before); }
    else if (writes & (1 << i)) {
      if (before.domainId === ZERO || after.domainId !== before.domainId || after.revision !== before.revision + 1n || after.stateRoot === before.stateRoot) throw Error("Retained owner transition differs");
    } else io.equal(after, before, "Retained read-only owner changed");
  }
  let record: LocalRecord;
  const get = <T>(method: string) => io.read<T>(p, d.attribution.address, a.artistAttributionInterface("owner"), method, [locator.value], at.blockNumber, undefined, gas);
  if (detail.operationId === 10n) {
    const r = a.normalizeArtistAttributionClaim(await get("attributionClaimRecord"));
    io.equal([r.recordHash, r.collectionId, r.claimant, r.evidenceHash, r.reasonHash, r.reasonURI], [e.value, detail.id, e.actor, detail.evidence, detail.reason, detail.uri], "Claim Archive fields differ");
    io.equal(a.artistAttributionClaimRecordHash(coords(d), r), e.value, "Claim record hash differs");
    io.equal([detail.e.schemaVersion, detail.r.schemaVersion, detail.e.collectionId, detail.r.collectionId, detail.e.claimRecordHash, detail.r.claimRecordHash, detail.e.proposedArtist, detail.r.proposedArtist], [1n, 1n, r.collectionId, r.collectionId, ZERO, ZERO, r.proposedArtist, r.proposedArtist], "Claim document fields differ");
    io.equal([keccak256(a.encodeArtistAttributionClaimEvidence(detail.e)), keccak256(a.encodeArtistAttributionClaimEvidence(detail.r))], [r.evidenceHash, r.reasonHash], "Claim document hash differs");
    required(detail.ep); required(detail.rp); required(detail.e.narrativeHash); required(detail.r.narrativeHash);
    if (r.index < 1n || r.filedAt === 0n || r.filedAt > at.timestamp) throw Error("Invalid retained claim clock/index");
    record = r;
  } else if (detail.operationId === 44n || detail.operationId === 45n || detail.operationId === 61n) {
    const r = a.normalizeArtistAttributionRecord(await get("attributionDisputeRecord")), x = detail.admission;
    io.equal(detail.p.disputeAction, op === 44n ? 1n : op === 45n ? 3n : 2n, "Operation/action mismatch");
    io.equal(x.binding_.generation, detail.p.bindingGeneration, "Admission generation differs");
    io.equal([r.recordHash, r.terms, r.standing, r.signer, r.authorityClass, r.nonce, r.recordedAt, r.artistId, r.bindingHash], [e.value, detail.p, detail.standing, x.signer, x.authorityClass, detail.a.nonce, x.recordedAt, x.binding_.artistId, x.binding_.bindingHash], "Dispute Archive fields differ");
    io.equal(a.artistAttributionDisputeRecordHash(coords(d), r), e.value, "Dispute record hash differs");
    io.equal(x.standing, detail.standing, "Standing differs");
    const head = detail.head;
    const prior = op === 44n ? head.disputeRecordHash : op === 45n ? head.counterStatementRecordHash : head.counterStatementRecordHash === ZERO ? head.disputeRecordHash : head.counterStatementRecordHash;
    io.equal([r.disputeRecordHash, r.previousRecordHash], [op === 44n ? e.value : head.disputeRecordHash, prior], "Dispute immutable predecessor differs");
    if (r.recordedAt === 0n || r.recordedAt > at.timestamp) throw Error("Invalid retained dispute time");
    required(detail.ep); required(detail.rp);
    const governed = "g" in detail && detail.g.actionId !== ZERO;
    if (governed && "g" in detail) {
      io.equal([r.governanceActionId, r.signer, r.authorityClass, r.nonce], [detail.g.actionId, detail.g.proposer, 0n, 0n], "Governed record identity differs");
      if (op !== 44n || detail.a.time !== 0n || detail.a.signature !== "0x") throw Error("Malformed governed opening");
      required(detail.g.roleMutationHash);
      io.equal(detail.standing, { artistId: ZERO, bindingGeneration: 0n, collaboratorIndex: 0n, delegation: ZERO }, "Governed opening standing must be empty");
      io.equal(detail.proof, { signer: ZA, digest: ZERO, direct: false }, "Governed opening signer proof must be empty");
      io.equal(x.digest, ZERO, "Governed opening digest must be empty");
      io.equal([detail.context.scopeHash, detail.context.oldValueHash, detail.context.newValueHash], [detail.g.scopeHash, detail.g.oldValueHash, detail.g.newValueHash], "Governance witness context differs");
    } else {
      io.equal(r.governanceActionId, ZERO, "Unexpected governed record");
      io.equal([detail.proof.signer, detail.proof.digest], [r.signer, x.digest], "Signer proof differs");
      io.equal(x.digest, a.artistAttributionSigningPayload(coords(d), detail.p, detail.a).digest, "Retained signing digest differs");
      if ("g" in detail) {
        io.equal(detail.g, { actionId: ZERO, proposer: ZA, actionClass: 0n, roleMutationHash: ZERO, roleRevision: 0n, scopeHash: ZERO, oldValueHash: ZERO, newValueHash: ZERO }, "Signed governance witness must be empty");
        io.equal(detail.context, { scopeHash: ZERO, oldValueHash: ZERO, newValueHash: ZERO, requiredClass: 0n, restoredState: 0n }, "Signed governance context must be empty");
      }
      if (r.authorityClass === 0n || (detail.proof.direct && (r.signer !== e.actor || detail.a.signature !== "0x")) || (!detail.proof.direct && detail.a.time === 0n) || (detail.a.time !== 0n && r.recordedAt > detail.a.time)) throw Error("Retained signature time/caller differs");
    }
    record = r;
  } else if (detail.operationId === 46n) {
    const r = a.normalizeArtistAttributionResolution(await get("attributionDisputeResolution"));
    io.equal([r.terms, r.actionId, r.actor, r.proposer, r.actionClass, r.restoredState, r.witnessHash], [detail.p, e.value, e.actor, detail.g.proposer, detail.g.actionClass, detail.context.restoredState, keccak256(a.encodeArtistAttributionGovernanceWitness(detail.g))], "Resolution Archive fields differ");
    io.equal(detail.g.actionId, e.value); required(detail.g.roleMutationHash);
    required(detail.ep); required(detail.rp);
    io.equal([detail.context.scopeHash, detail.context.oldValueHash, detail.context.newValueHash], [detail.g.scopeHash, detail.g.oldValueHash, detail.g.newValueHash], "Resolution governance context differs");
    if (r.resolvedAt === 0n || r.resolvedAt > at.timestamp || r.actionClass < detail.context.requiredClass || r.actionClass > 2n) throw Error("Invalid retained resolution");
    record = r;
  } else {
    const r = a.normalizeArtistAttributionRepudiationRecord(await get("attributionRepudiationRecord"));
    io.equal(r.recordHash, e.value); io.equal(a.artistAttributionRepudiationRecordHash(coords(d), r), e.value, "Repudiation record hash differs");
    if (detail.operationId === 47n) {
      const x = detail.admission;
      io.equal([detail.p.disputeAction, x.binding_.generation], [4n, detail.p.bindingGeneration], "Repudiation action/generation differs");
      io.equal([r.terms, r.artistId, r.signer, r.authorityClass, r.nonce, r.stagedAt, r.executableAt, r.bindingHash, r.authorityHead, r.capturedGuardianSet, r.windowRevision], [detail.p, x.binding_.artistId, x.authorityHead.principal, x.authorityHead.authorityClass, detail.a.nonce, x.stagedAt, x.executableAt, x.binding_.bindingHash, x.authorityHead, x.guardianSet, x.windowRevision], "Stage Archive fields differ");
      io.equal(detail.proof.signer, r.signer);
      io.equal(detail.proof.digest, a.artistAttributionSigningPayload(coords(d), detail.p, detail.a).digest, "Stage signing digest differs");
      if ((detail.proof.direct && (r.signer !== e.actor || detail.a.signature !== "0x")) || (!detail.proof.direct && detail.a.time === 0n) || (detail.a.time !== 0n && r.stagedAt > detail.a.time)) throw Error("Stage signature clock/caller differs");
    } else if ("r" in detail) {
      io.equal(detail.r, r, "Terminal Archive record differs");
      if (detail.operationId === 48n) {
        io.equal([detail.proof.collectionId, detail.proof.repudiationRecordHash, detail.proof.capturedGuardianSet, detail.proof.vetoer], [r.terms.collectionId, r.recordHash, r.capturedGuardianSet, e.actor], "Veto proof differs");
        required(detail.proof.reasonHash); required(detail.contest);
      } else if (detail.operationId === 49n) io.equal(r.signer, e.actor, "Cancellation signer differs");
    }
    if (r.stagedAt === 0n || r.stagedAt > at.timestamp || r.executableAt <= r.stagedAt || r.windowRevision === 0n) throw Error("Invalid retained repudiation time");
    record = r;
  }
  return own({ observed: at, locator, evidenceId, contentHash: io.hash(contentHash), pointer: io.address(pointer), appendedAtBlock: io.uint(appendedAtBlock), raw, envelope: e, detail, record, currentAuthorizationChecked: false as const, privateAuxiliaryEffectsIndependentlyReconstructed: false as const });
}
export async function inspectArtistAttributionHistory(p: io.Reader, input: ArtistAttributionHistoryDeployment, rawLocator: ArtistAttributionHistoryLocator, options: ArtistAttributionHistoryOptions) {
  const d = historyDeployment(input); io.keys(rawLocator, ["operationId", "actor", "value"]); io.keys(options, ["blockTag", "gasLimit"], ["retainedPayload"]);
  const locator = own({ operationId: io.uint(rawLocator.operationId, 16), actor: io.address(rawLocator.actor), value: io.hash(rawLocator.value) });
  if (![10n, 44n, 45n, 46n, 47n, 48n, 49n, 50n, 61n].includes(locator.operationId)) throw Error("Unsupported Attribution operation");
  const tag = io.number(options.blockTag), gas = io.gas(options.gasLimit), raw = options.retainedPayload === undefined ? undefined : io.bytes(options.retainedPayload, 24575);
  const at = await io.chain(p, d.chainId, tag), result = await historyAt(p, d, locator, at, gas, raw);
  await io.unchanged(p, at); return result;
}
function detailRequest(s: ArtistAttributionCapture, h: Awaited<ReturnType<typeof historyAt>>) {
  const q = s.prepared.request, x = h.detail;
  if (q.kind === "fileAttributionClaim" && x.operationId === 10n) io.equal([x.id, x.evidence, x.reason, x.uri], [q.collectionId, q.evidenceHash, q.reasonHash, q.reasonURI], "Claim request changed");
  else if (q.kind === "resolveAttributionDispute" && x.operationId === 46n) io.equal(x.p, q.resolution, "Resolution request changed");
  else if ("filing" in q && "p" in x && "a" in x) {
    io.equal([x.p, x.a], [q.filing, q.authorization], "Signed request changed");
    if ("standing" in q && "standing" in x) io.equal(x.standing, q.standing, "Standing changed");
  } else if ("expectedRepudiation" in q && (x.operationId === 48n || x.operationId === 49n || x.operationId === 50n)) {
    io.equal([x.r.terms.collectionId, x.r.recordHash], [q.collectionId, q.expectedRepudiation]);
    if (q.kind === "vetoAttributionRepudiation" && x.operationId === 48n) io.equal(x.proof.reasonHash, q.reasonHash);
  } else throw Error("Archive detail operation differs from prepared call");
}
async function safeProof(p: io.Reader, s: ArtistAttributionCapture, tx: { readonly data: Hex }, tag: number, end: number, o: Extract<ArtistAttributionReceiptOptions, { execution: "safe" }>) {
  const caller = s.prepared.caller, decoded = safeABI.decodeFunctionData("execTransaction", tx.data);
  const values = safeNames.map((key, i) => i === 9 ? o.nonce : decoded[i]);
  const expected = TypedDataEncoder.hash({ chainId: s.deployment.chainId, verifyingContract: caller }, safeTypes, Object.fromEntries(safeNames.map((key, i) => [key, values[i]])));
  if (!io.same(expected, o.expectedSafeTxHash) || decoded.signatures === "0x") throw Error("Safe signed envelope hash differs");
  for (const block of [tag, end]) await io.runtime(p, { address: caller, codeHash: o.safeCodeHash }, block);
  io.equal(await io.read(p, caller, safeABI, "getTransactionHash", values, tag, undefined, s.gasLimit), o.expectedSafeTxHash, "Original Safe hash differs");
  io.equal(await io.read(p, caller, safeABI, "nonce", [], tag, undefined, s.gasLimit), o.nonce, "Safe prior nonce differs");
  io.equal(await io.read(p, caller, safeABI, "nonce", [], end, undefined, s.gasLimit), o.nonce + 1n, "Safe end nonce differs");
}
function receiptOptions(v: ArtistAttributionReceiptOptions): ArtistAttributionReceiptOptions {
  if (v.execution === "direct") { io.keys(v, ["execution"]); return own({ execution: "direct" }); }
  io.keys(v, ["execution", "expectedSafeTxHash", "nonce", "safeCodeHash"]);
  if (v.execution !== "safe") throw Error("Unsupported receipt transport");
  return own({ execution: "safe", expectedSafeTxHash: io.hash(v.expectedSafeTxHash), nonce: io.uint(v.nonce), safeCodeHash: io.hash(v.safeCodeHash) });
}
/** Strict block-level attribution refuses additional same-block mutations of the operation's captured owner state. */
export async function reconcileArtistAttributionReceipt(p: io.ReceiptReader, input: ArtistAttributionCapture, transactionHash: Hex, options: ArtistAttributionReceiptOptions) {
  const s = saved(input), o = receiptOptions(options), hash = io.hash(transactionHash), d = s.deployment, g = governance.get(s);
  const expected = g ? { chainId: d.chainId, caller: g.prepared.caller, call: g.prepared.call, observed: s.observed } : { chainId: d.chainId, caller: s.prepared.caller, call: s.prepared.call, observed: s.observed };
  const mined = await io.transport(p, expected, hash, o.execution === "direct" ? o : { execution: "safe", expectedSafeTxHash: o.expectedSafeTxHash });
  const prior = await io.chain(p, d.chainId, mined.observed.blockNumber - 1);
  await revalidate(p, s, prior, s.gasLimit);
  await io.runtimes(p, pins(d), mined.observed.blockNumber);
  if (g) await executor.reconcileGovernanceExecutorV2Receipt(p, g, hash, o.execution === "direct" ? o : { ...o, outerValue: 0n });
  else if (o.execution === "safe") await safeProof(p, s, mined.transaction, prior.blockNumber, mined.observed.blockNumber, o);
  const appended = io.one(mined.logs, d.archive.address, archiveABI, "ArtistArchiveEvidenceAppendedV2");
  const id_ = io.hash(appended.fields.evidenceId), meta = await io.rpc(p, d.archive.address, archiveABI, "artistEvidenceMetadataV2", [id_, 1n], mined.observed.blockNumber, undefined, s.gasLimit);
  const raw = io.bytes(await io.read(p, d.archive.address, archiveABI, "artistEvidenceBytesV2", [id_, 1n], mined.observed.blockNumber, undefined, s.gasLimit), 24575);
  const envelope = a.decodeArtistAttributionArchiveEnvelope(raw);
  const h = await historyAt(p, historyFrom(d), { operationId: s.prepared.operationId, actor: s.prepared.caller, value: envelope.value }, mined.observed, s.gasLimit, raw);
  io.equal(h.evidenceId, id_, "Archive event identity differs");
  io.equal(appended.fields, { evidenceId: h.evidenceId, evidenceVersion: 1n, contentHash: h.contentHash, pointer: h.pointer, payloadSize: BigInt((raw.length - 2) / 2) }, "Archive event differs");
  io.equal(meta[3], BigInt(mined.observed.blockNumber), "Archive append block differs");
  const carrier = io.bytes(await p.getCode(h.pointer, mined.observed.blockNumber), 24576);
  if (!io.same(carrier, `0x00${raw.slice(2)}`)) throw Error("Mined Archive carrier differs");
  io.equal(h.envelope.configurationHash, s.observation.configurationHash, "Archive configuration differs");
  io.equal(h.envelope.before_, s.observation.before, "Archive prestate differs");
  const after = await snapshots(p, d, recipe(s.prepared).read, mined.observed.blockNumber, s.gasLimit);
  io.equal(h.envelope.after_, after, "Archive end state differs");
  for (let i = 0; i < 7; i++) {
    const before = s.observation.before[i]!, end = after[i]!;
    if (recipe(s.prepared).write & (1 << i)) {
      if (end.domainId !== before.domainId || end.revision !== before.revision + 1n || end.stateRoot === before.stateRoot) throw Error("Expected one original owner commit");
    } else io.equal(end, before, "Unexpected owner mutation");
  }
  detailRequest(s, h);
  const domain = await domainReceipt(p, s, h, mined.logs, mined.observed);
  if (domain.lastIndex >= appended.index) throw Error("Original application events must precede Archive append");
  io.finish(mined.logs, [d.registry.address, d.coordinator.address, d.archive.address, ...d.owners.map(v => v.address)], mined.safeIndex);
  await io.unchanged(p, prior); await io.unchanged(p, mined.observed);
  return own({ observed: mined.observed, prior, transactionHash: hash, captureHash: s.captureHash, history: h, domain, execution: o.execution,
    originalArchiveAndPublicStateVerified: true as const, privateAuxiliaryEffectsIndependentlyReconstructed: false as const,
    ownerSignaturesIndependentlyVerified: false as const, safeImplementationIndependentlyVerified: false as const });
}

async function domainReceipt(p: io.Reader, s: ArtistAttributionCapture, h: Awaited<ReturnType<typeof historyAt>>, logs: readonly io.Log[], at: io.Block) {
  const d = s.deployment, q = s.prepared.request, op = s.prepared.operationId, x = h.detail, owner = d.owners[4]!.address, iface = a.artistAttributionInterface("owner"), cid = collection(q), tag = at.blockNumber, gas = s.gasLimit;
  const indices: number[] = [], facts = s.observation.facts;
  const one = (name: string, values: readonly unknown[]) => { const e = io.one(logs, owner, iface, name, values); indices.push(e.index); return e; };
  let expectedState: bigint | null = null, expectedHead: a.ArtistAttributionHead | null = null;
  const state = facts.state as readonly bigint[] | undefined;
  const beforeHead = facts.head as a.ArtistAttributionHead | undefined;
  if (op === 10n) {
    const r = h.record as a.ArtistAttributionClaim;
    io.equal(r.filedAt, at.timestamp, "Claim mined time differs");
    const claims = facts.claims as readonly unknown[];
    io.equal([r.index, r.previousRecordHash], [(claims[0] as bigint) + 1n, claims[1]], "Claim predecessor differs");
    io.equal(await io.rpc(p, owner, iface, "attributionClaims", [cid], tag, undefined, gas), [r.index, r.recordHash], "Claim end head differs");
    one("AttributionClaimFiled", [1n, cid, r.claimant, r.evidenceHash, r.reasonHash, r.reasonURI, r.filedAt, r.recordHash]);
  } else if (op === 44n || op === 45n || op === 61n) {
    const r = h.record as a.ArtistAttributionRecord;
    io.equal(r.recordedAt, at.timestamp, "Dispute mined time differs");
    if (!("head" in x) || !("admission" in x) || !("standing" in x)) throw Error("Dispute detail missing");
    io.equal(x.head, beforeHead, "Recorded dispute prehead differs");
    io.equal(x.admission.binding_, facts.binding, "Recorded dispute binding differs");
    if (op === 44n) {
      expectedState = 4n;
      expectedHead = { ...beforeHead!, disputeRecordHash: r.recordHash, counterStatementRecordHash: ZERO, restoreState: state![0] === 5n ? beforeHead!.restoreState : state![0]!, open: true, reopened: state![0] === 5n };
      one("AttributionDisputeOpened", [1n, cid, r.signer, r.terms.bindingGeneration, r.authorityClass, r.terms.evidenceHash, r.terms.reasonHash, r.nonce, at.timestamp, r.recordHash]);
    } else if (op === 45n) {
      expectedState = state![0]!; expectedHead = { ...beforeHead!, counterStatementRecordHash: r.recordHash };
      one("AttributionCounterStatementRecorded", [1n, cid, r.disputeRecordHash, r.signer, r.terms.bindingGeneration, r.authorityClass, r.terms.evidenceHash, r.terms.reasonHash, r.nonce, at.timestamp, r.recordHash]);
    } else {
      const outcome = a.normalizeArtistAttributionWithdrawal(await ownerRead(p, d, "attributionDisputeWithdrawal", [r.disputeRecordHash], tag, gas));
      io.equal(outcome, { recordHash: r.recordHash, counterStatementRecordHash: beforeHead!.counterStatementRecordHash, restoredState: beforeHead!.restoreState }, "Withdrawal outcome differs");
      const opening = facts.opening as a.ArtistAttributionRecord;
      io.equal([r.signer, r.authorityClass, r.standing], [opening.signer, opening.authorityClass, opening.standing], "Withdrawal opener differs");
      if (opening.governanceActionId !== ZERO || beforeHead!.reopened || ![2n, 3n].includes(outcome.restoredState)) throw Error("Withdrawal episode is not original signed accepted opening");
      expectedState = outcome.restoredState; expectedHead = { ...beforeHead!, open: false, revocationReason: 0n };
      one("AttributionDisputeWithdrawn", [1n, cid, r.disputeRecordHash, r.signer, r.terms.bindingGeneration, r.authorityClass, r.terms.evidenceHash, r.terms.reasonHash, r.nonce, at.timestamp, r.recordHash, outcome.counterStatementRecordHash, outcome.restoredState]);
    }
    if (op !== 45n) one("ArtistAttributionStateChanged", [1n, cid, expectedState, r.terms.bindingGeneration, state![0], s.prepared.caller, r.authorityClass, r.recordHash, r.terms.reasonHash, ""]);
    one("AttributionDisputeRecordContext", [1n, d.chainId, d.registry.address, r.recordHash, r.terms.disputeAction, r.artistId, r.bindingHash, r.disputeRecordHash, r.previousRecordHash, r.standing.artistId, r.standing.delegation, r.governanceActionId]);
    if (op === 44n && facts.rawPending !== ZERO) {
      const priorTerminal = facts.pendingTerminal as a.ArtistAttributionTerminal;
      const end = a.normalizeArtistAttributionTerminal(await ownerRead(p, d, "attributionRepudiationTerminal", [facts.rawPending], tag, gas));
      if (priorTerminal.phase === 1n) {
        io.equal(end, { phase: 5n, actor: ZA, reasonHash: r.recordHash, recordedAt: at.timestamp }, "Opening invalidation terminal differs");
        one("AttributionRepudiationInvalidated", [1n, cid, facts.rawPending, ZERO, r.recordHash]);
      } else io.equal(end, priorTerminal, "Closed pending terminal unexpectedly changed");
    }
    if (s.prepared.requiresGovernance) {
      if (!("g" in x) || !("context" in x)) throw Error("Missing governed opening witness");
      io.equal(x.context, s.observation.context);
      governanceDetail(s, x.g);
    }
  } else if (op === 46n && x.operationId === 46n) {
    const r = h.record as a.ArtistAttributionResolution;
    io.equal(r.resolvedAt, at.timestamp, "Resolution mined time differs");
    io.equal([x.b, x.context], [facts.binding, s.observation.context], "Resolution context changed");
    io.equal(r.previousResolutionActionId, beforeHead!.resolutionActionId, "Resolution predecessor differs");
    governanceDetail(s, x.g);
    expectedState = r.restoredState; expectedHead = { ...beforeHead!, resolutionActionId: r.actionId, open: false, revocationReason: r.terms.resolution === 2n ? 4n : 0n };
    one("AttributionDisputeResolved", [1n, cid, r.terms.disputeRecordHash, r.terms.resolution, r.restoredState, r.terms.evidenceHash, r.terms.reasonHash, r.terms.counterStatementRecordHash, r.actionId]);
    one("ArtistAttributionStateChanged", [1n, cid, r.restoredState, r.terms.bindingGeneration, 4n, s.prepared.caller, 0n, r.terms.disputeRecordHash, r.terms.reasonHash, ""]);
  } else {
    const r = h.record as a.ArtistAttributionRepudiationRecord;
    const t = a.normalizeArtistAttributionTerminal(await ownerRead(p, d, "attributionRepudiationTerminal", [r.recordHash], tag, gas));
    if (op === 47n) {
      io.equal(r.stagedAt, at.timestamp, "Stage mined time differs");
      io.equal(t, { phase: 1n, actor: ZA, reasonHash: ZERO, recordedAt: 0n }, "Stage terminal differs");
      if (facts.rawPending !== ZERO && (facts.pendingTerminal as a.ArtistAttributionTerminal).phase === 1n) {
        const old = facts.pendingRecord as a.ArtistAttributionRepudiationRecord, cohort = a.artistAttributionAuthorityHeadHash(r.authorityHead);
        if (old.artistId === r.artistId && old.terms.bindingGeneration === r.terms.bindingGeneration && old.bindingHash === r.bindingHash && a.artistAttributionAuthorityHeadHash(old.authorityHead) === cohort) throw Error("Original active repudiation cannot be replaced");
        io.equal(await ownerRead(p, d, "attributionRepudiationTerminal", [old.recordHash], tag, gas), { phase: 5n, actor: ZA, reasonHash: ZERO, recordedAt: at.timestamp }, "Stage replacement terminal differs");
        one("AttributionRepudiationInvalidated", [1n, cid, old.recordHash, cohort, ZERO]);
      }
      one("AttributionRepudiationStaged", [1n, cid, r.artistId, r.signer, r.terms.bindingGeneration, r.authorityClass, r.terms.evidenceHash, r.terms.reasonHash, r.nonce, at.timestamp, r.executableAt, r.recordHash]);
      one("AttributionRepudiationContext", [1n, d.chainId, d.registry.address, r.recordHash, r.bindingHash, r.authorityHead, r.capturedGuardianSet, r.windowRevision]);
      io.equal(await ownerRead(p, d, "rawPendingRepudiation", [cid], tag, gas), r.recordHash, "Stage pending differs");
    } else {
      const reason = op === 48n && x.operationId === 48n ? x.proof.reasonHash : op === 50n ? r.terms.reasonHash : ZERO;
      io.equal(t, { phase: op === 48n ? 2n : op === 49n ? 3n : 4n, actor: s.prepared.caller, reasonHash: reason, recordedAt: at.timestamp }, "Repudiation terminal differs");
      io.equal(await ownerRead(p, d, "rawPendingRepudiation", [cid], tag, gas), ZERO, "Terminal pending pointer differs");
      if (op === 48n) one("AttributionRepudiationVetoed", [1n, cid, s.prepared.caller, r.recordHash, reason]);
      else if (op === 49n) one("AttributionRepudiationCancelled", [1n, cid, s.prepared.caller, r.recordHash, r.authorityClass]);
      else {
        if (at.timestamp < r.executableAt) throw Error("Repudiation execution precedes deadline");
        expectedState = 5n; expectedHead = { ...beforeHead!, revocationReason: 3n };
        one("ArtistAttributionStateChanged", [1n, cid, 5n, r.terms.bindingGeneration, state![0], s.prepared.caller, r.authorityClass, r.recordHash, r.terms.reasonHash, ""]);
      }
    }
    if (op !== 50n) { expectedState = state![0]!; expectedHead = beforeHead!; }
  }
  if (expectedState !== null) {
    io.equal(await io.rpc(p, owner, iface, "attributionState", [cid], tag, undefined, gas), [expectedState, state![1]], "Attribution end state differs");
    io.equal(await ownerRead(p, d, "attributionDispute", [cid, state![1]], tag, gas), expectedHead, "Dispute end head differs");
  }
  for (let i = 1; i < indices.length; i++) if (indices[i]! <= indices[i - 1]!) throw Error("Original domain event order differs");
  const attributionRows = await nativeRows(p, s, 4, at);
  const needsRecord = [10n, 44n, 45n, 47n, 61n].includes(op);
  io.equal(attributionRows.length, needsRecord ? 1 : 0, "Attribution native count differs");
  if (needsRecord) {
    const artistId = op === 10n ? ZERO : (h.record as a.ArtistAttributionRecord).artistId;
    io.equal(attributionRows[0], { operation: op, artistId, collectionId: cid, recordHash: h.envelope.value }, "Attribution native receipt differs");
  }
  let identityPublicReadback: unknown = null;
  if (recipe(s.prepared).write & 4) {
    const identityRows = await nativeRows(p, s, 2, at);
    if (op === 48n && x.operationId === 48n) {
      const v = await vetoIdentity(p, s, x, identityRows, logs, at);
      if (indices[0]! >= v.firstIndex) throw Error("Veto must precede Identity Contest");
      identityPublicReadback = v; indices.push(v.lastIndex);
    }
    else {
      // Source activity hooks can append their own op42 notice record; those reads are retained without claiming every private effect is reconstructed.
      const artistId = facts.artistId as Hex;
      const identity = (await rows(p, d.owners[2]!.address, "identity", [artistId], tag, gas))[0] as Record<string, unknown>;
      const dormancy = await rows(p, d.owners[2]!.address, "dormancyNotice", [artistId], tag, gas);
      if (op === 49n) {
        const old = facts.identity as Record<string, unknown>;
        if (old.authorityClass === 1n) {
          io.equal(identity.lastAuthorityActionAt, at.timestamp, "Cancellation activity time differs");
          const notice = facts.dormancy as readonly unknown[];
          if (notice[1] === 1n) {
            if (dormancy[0] !== notice[0] || dormancy[1] !== 2n || dormancy[2] === ZERO) throw Error("Cancellation dormancy readback differs");
            const ev = io.one(logs, d.owners[2]!.address, identityEvents, "ArtistDormancyCancelled", [1n, artistId, notice[0], s.prepared.caller, 1n, dormancy[2]]);
            indices.push(ev.index);
          }
        }
      }
      if ("authorization" in q && !s.prepared.requiresGovernance && (!("standing" in q) || q.standing.delegation === ZERO)) io.equal((await rows(p, d.owners[2]!.address, "nonceUsed", [artistId, q.authorization.nonce], tag, gas))[0], true, "Signed nonce not consumed");
      const cancellation = await activityReceipts(p, s, h, artistId, identityRows, logs, at);
      if (cancellation) {
        if (op === 49n ? indices[0]! >= cancellation.firstIndex : cancellation.lastIndex >= indices[0]!) throw Error("Original activity event order differs");
        indices.push(cancellation.lastIndex);
      }
      identityPublicReadback = { identity, dormancy, nativeRows: identityRows, cancellation, privateActivityEffectsIndependentlyReconstructed: false };
    }
  }
  return own({ lastIndex: Math.max(...indices), attributionRows, identityPublicReadback });
}
function governanceDetail(s: ArtistAttributionCapture, witness: a.ArtistAttributionGovernanceWitness) {
  const g = governance.get(s);
  if (!g || !g.observation.history || !s.observation.context) throw Error("Missing original Executor capture");
  const action = g.observation.history.action, context = s.observation.context;
  io.equal([witness.actionId, witness.proposer, witness.actionClass, witness.scopeHash, witness.oldValueHash, witness.newValueHash], [g.observation.actionId, action.proposer, action.actionClass, context.scopeHash, context.oldValueHash, context.newValueHash], "Executed governance witness differs");
  if (witness.actionClass < context.requiredClass || witness.actionClass > 2n || witness.roleRevision === 0n) throw Error("Governance class/role revision differs");
}
async function nativeRows(p: io.Reader, s: ArtistAttributionCapture, index: 2 | 4, at: io.Block) {
  const owner = s.deployment.owners[index]!.address, start = s.observation.counts[index === 2 ? 0 : 1]!, end = io.uint((await rows(p, owner, "artistNativeReceiptCount", [], at.blockNumber, s.gasLimit))[0]);
  if (end < start || end - start > 16n) throw Error("Native receipt delta exceeds client bound");
  const out: { operation: bigint; artistId: Hex; collectionId: bigint; recordHash: Hex }[] = [];
  for (let n = start; n < end; n++) {
    const row = (await rows(p, owner, "artistNativeReceiptAt", [n], at.blockNumber, s.gasLimit))[0] as typeof out[number];
    io.equal((await rows(p, owner, "artistNativeReceiptRevisionAt", [n], at.blockNumber, s.gasLimit))[0], s.observation.before[index]!.revision + 1n, "Native receipt owner revision differs");
    required(row.recordHash); out.push(row);
  }
  return out;
}
async function vetoIdentity(p: io.Reader, s: ArtistAttributionCapture, x: Extract<a.ArtistAttributionArchiveDetail, { operationId: 48n }>, native: Awaited<ReturnType<typeof nativeRows>>, logs: readonly io.Log[], at: io.Block) {
  const owner = s.deployment.owners[2]!.address, d = s.deployment;
  if (native.length !== 2) throw Error("Veto must append original Contest then Cause");
  io.equal(native[0], { operation: 48n, artistId: x.r.artistId, collectionId: x.r.terms.collectionId, recordHash: x.contest }, "Contest native receipt differs");
  const contest = (await rows(p, owner, "identityContestRecord", [x.contest], at.blockNumber, s.gasLimit))[0] as { recordHash: Hex; terms: { artistId: Hex; subjectRecordHash: Hex; evidenceHash: Hex; reasonHash: Hex }; contester: Address; contestedAt: bigint };
  const oldIdentity = s.observation.facts.identity as Record<string, unknown>, fullContest = contest as unknown as Record<string, unknown>;
  io.equal(x.proof.vetoedAt, at.timestamp, "Veto proof mined time differs");
  io.equal([fullContest.priorStatus, fullContest.guardianSetRecordHash], [oldIdentity.status, x.proof.currentGuardianSet], "Contest prior status/guardians differ");
  io.equal([contest.recordHash, contest.terms, contest.contester, contest.contestedAt], [x.contest, { artistId: x.r.artistId, subjectRecordHash: ZERO, evidenceHash: x.r.recordHash, reasonHash: x.proof.reasonHash }, s.prepared.caller, at.timestamp], "Original veto Contest differs");
  const hash = keccak256(io.coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "uint64"], ["0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb", d.chainId, d.registry.address, x.r.artistId, s.prepared.caller, ZERO, x.r.recordHash, x.proof.reasonHash, at.timestamp]));
  io.equal(hash, x.contest, "Contest hash differs");
  const cause = (await rows(p, owner, "identityContestCause", [native[1]!.recordHash], at.blockNumber, s.gasLimit))[0] as { causeHash: Hex; facts: Record<string, unknown> };
  io.equal(native[1], { operation: 48n, artistId: x.r.artistId, collectionId: x.r.terms.collectionId, recordHash: cause.causeHash });
  io.equal([cause.facts.artistId, cause.facts.kind, cause.facts.referenceHash, cause.facts.actor, cause.facts.reasonHash, cause.facts.evidenceHash, cause.facts.enteredAt], [x.r.artistId, 1n, x.contest, s.prepared.caller, x.proof.reasonHash, x.r.recordHash, at.timestamp], "Contest Cause fields differ");
  io.equal([cause.facts.incumbent, cause.facts.authorityClass, cause.facts.priorStatus], [oldIdentity.authorityAddress, oldIdentity.authorityClass, oldIdentity.status], "Cause prior Identity differs");
  const causeType = observationABI.getFunction("identityContestCause")!.outputs[0]!.components![1]!;
  io.equal(keccak256(io.coder.encode(["bytes32", "uint256", "address", "address", causeType], [id("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"), d.chainId, d.registry.address, owner, cause.facts])), cause.causeHash, "Cause hash differs");
  const e1 = io.one(logs, owner, identityEvents, "ArtistIdentityContested", [1n, x.r.artistId, s.prepared.caller, ZERO, x.r.recordHash, x.proof.reasonHash, at.timestamp, x.contest]);
  const e2 = io.one(logs, owner, identityEvents, "ArtistIdentityContestCauseCaptured", [1n, x.r.artistId, cause.causeHash, ...Object.values(cause.facts).slice(1)]);
  if (e1.index >= e2.index) throw Error("Contest/Cause event order differs");
  const authority = await rows(p, owner, "authorityState", [x.r.artistId], at.blockNumber, s.gasLimit);
  io.equal(authority[2], 4n, "Veto did not contest Identity");
  return own({ contest, cause, nativeRows: native, firstIndex: e1.index, lastIndex: e2.index, privateCompositionIndependentlyReconstructed: false as const });
}
async function activityReceipts(p: io.Reader, s: ArtistAttributionCapture, h: Awaited<ReturnType<typeof historyAt>>, artistId: Hex, native: Awaited<ReturnType<typeof nativeRows>>, logs: readonly io.Log[], at: io.Block) {
  const detail = h.detail, old = s.observation.facts.identity as Record<string, unknown>, notice = s.observation.facts.dormancy as readonly unknown[];
  const actor = detail.operationId === 49n ? s.prepared.caller : "proof" in detail && "signer" in detail.proof ? detail.proof.signer : null;
  const authorityClass = "standing" in detail && detail.standing.delegation !== ZERO ? 2n : 1n;
  const expected = old.authorityClass === 1n && notice[1] === 1n && actor !== null && actor !== ZA && (authorityClass === 2n || actor === old.authorityAddress);
  io.equal(native.length, expected ? 1 : 0, "Activity cancellation native count differs");
  if (!expected) return null;
  if (native.length !== 1 || native[0]!.operation !== 42n || native[0]!.artistId !== artistId || native[0]!.collectionId !== 0n) throw Error("Unexpected auxiliary Identity receipt");
  const owner = s.deployment.owners[2]!.address, event = io.one(logs, owner, identityEvents, "ArtistDormancyCancellationContext"), f = event.fields;
  const terminal = f.terminal as Record<string, unknown>, context = f.context as Record<string, unknown>;
  io.equal([f.schemaVersion, f.artistId, f.recordHash, terminal.recordHash, terminal.observedAt], [1n, artistId, native[0]!.recordHash, native[0]!.recordHash, at.timestamp], "Dormancy cancellation receipt differs");
  io.equal(context, { chainId: s.deployment.chainId, registry: s.deployment.registry.address, identityOwner: owner, recorder: terminal.actor, recorderAuthorityClass: terminal.authorityClass }, "Dormancy cancellation context differs");
  io.equal([old.authorityClass, notice[1], terminal.noticeHash, terminal.actor, terminal.authorityClass], [1n, 1n, notice[0], actor, authorityClass], "Activity cancellation admission differs");
  const record = await rows(p, owner, "dormancyRecord", [terminal.noticeHash], at.blockNumber, s.gasLimit);
  io.equal([record[1], record[2]], [2n, terminal], "Dormancy cancellation local record differs");
  const count = io.uint(f.activityCount); if (count === 0n) throw Error("Invalid activity counter");
  const emptyHashTerminal = { ...terminal, recordHash: ZERO };
  io.equal(keccak256(io.coder.encode(["bytes32", "uint256", "address", "address", DORMANCY_TERMINAL, "uint256"], [id("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"), s.deployment.chainId, s.deployment.registry.address, owner, emptyHashTerminal, count])), terminal.recordHash, "Dormancy cancellation hash differs");
  const original = io.one(logs, owner, identityEvents, "ArtistDormancyCancelled", [1n, artistId, terminal.noticeHash, terminal.actor, terminal.authorityClass, terminal.recordHash]);
  if (original.index >= event.index) throw Error("Dormancy event order differs");
  return own({ terminal, activityCount: count, firstIndex: original.index, lastIndex: event.index });
}
