import { Interface, ParamType, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import * as inv from "./current-view-preservation-inventory-v1.js";
import * as retrieval from "./current-view-retrieval-v1.js";

// Reviewed original memory-only public read workers. Nominal compiler selectors stay separate
// from structural ABI witnesses; these are never wallet endpoints. Linked runtime completeness
// is supplied deployment provenance. The original host call is the transaction admission authority.
const workers = {
  "source": {
    "contract": "StreamViewPreservationRenderCriticalSourceReadsV1",
    "method": "current",
    "selector": "0x3a26afec",
    "inputs": [
      "(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) d",
      "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope"
    ],
    "outputs": [
      "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 adoptionRecord, bytes32 viewId, bytes32 payloadHash, bytes32 sourceContextHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 manifestIndexHash, uint64 tokenCount) c"
    ]
  },
  "binding": {
    "contract": "StreamViewRetrievalBindingV1",
    "method": "requireInventory",
    "selector": "0x2d3006a8",
    "inputs": [
      "address inventory",
      "(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) d",
      "uint256 cap"
    ],
    "outputs": [
      "address witness",
      "bytes32 codeHash",
      "(address core, bytes32 coreCodeHash, address router, bytes32 routerCodeHash, address checkpoint, bytes32 checkpointCodeHash, address archive, bytes32 archiveCodeHash, uint256 chainId, uint32 readGas, uint32 sourceGas, uint32 archiveGas, uint32 signatureGas) c"
    ]
  }
} as const;

export type CurrentViewPreservationInventoryV1CodePin = io.CodePin;
export type CurrentViewPreservationInventoryV1ReceiptOptions = io.ReceiptOptions;
export interface CurrentViewPreservationInventoryV1HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly inventory: io.CodePin;
}
export interface CurrentViewPreservationInventoryV1Deployment extends CurrentViewPreservationInventoryV1HistoryDeployment {
  readonly sourceReader: io.CodePin;
  readonly retrievalBindingReader: io.CodePin;
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface CurrentViewPreservationInventoryV1SegmentLocator { readonly transactionHash: Hex; readonly logIndex: number }
export interface CurrentViewPreservationInventoryV1SegmentObservation {
  readonly locator: CurrentViewPreservationInventoryV1SegmentLocator;
  readonly recorded: io.Block;
  readonly planId: Hex;
  readonly index: bigint;
  readonly segment: inv.CurrentViewPreservationInventoryV1Segment;
  readonly items: readonly inv.CurrentViewPreservationInventoryV1Item[];
}
export interface CurrentViewPreservationInventoryV1WorkflowCapture {
  readonly deployment: CurrentViewPreservationInventoryV1Deployment;
  readonly prepared: inv.CurrentViewPreservationInventoryV1Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly stage: {
    readonly dependencies: inv.CurrentViewPreservationInventoryV1Dependencies;
    readonly dependencyHash: Hex;
    readonly companion: { readonly witness: Address; readonly codeHash: Hex; readonly configuration: retrieval.CurrentViewRetrievalV1Configuration };
    readonly planId: Hex;
    readonly context: inv.CurrentViewPreservationInventoryV1Context;
    readonly before: inv.CurrentViewPreservationInventoryV1Plan;
    readonly tokenBefore: inv.CurrentViewPreservationInventoryV1TokenProgress;
    readonly segments: readonly CurrentViewPreservationInventoryV1SegmentObservation[];
    readonly evidence: inv.CurrentViewPreservationInventoryV1Evidence | null;
    readonly existing: boolean;
  };
  readonly originalCallResult: Hex;
  readonly originalCallSimulated: true;
  readonly itemProductionIndependentlyReconstructed: false;
  readonly captureHash: Hex;
}
type Dependencies = inv.CurrentViewPreservationInventoryV1Dependencies;
type Context = inv.CurrentViewPreservationInventoryV1Context;
type Plan = inv.CurrentViewPreservationInventoryV1Plan;
type Token = inv.CurrentViewPreservationInventoryV1TokenProgress;
type Item = inv.CurrentViewPreservationInventoryV1Item;
type Evidence = inv.CurrentViewPreservationInventoryV1Evidence;
type Request = inv.CurrentViewPreservationInventoryV1Request;
const host = () => inv.currentViewPreservationInventoryV1Interface();
const MAX_SEGMENTS = 16384, MAX_ITEMS = 65536;
const eventName = (suffix: string) => `ViewPreservationInventory${suffix}`;
const historyDeployment = (v: CurrentViewPreservationInventoryV1HistoryDeployment): CurrentViewPreservationInventoryV1HistoryDeployment => {
  io.keys(v, ["chainId", "core", "inventory"]);
  return io.freeze({ chainId: io.uint(v.chainId), core: io.address(v.core), inventory: io.codePin(v.inventory) });
};
function deployment(v: CurrentViewPreservationInventoryV1Deployment): CurrentViewPreservationInventoryV1Deployment {
  io.keys(v, ["chainId", "core", "inventory", "sourceReader", "retrievalBindingReader", "linkedDependencies"]);
  return io.freeze({ ...historyDeployment({ chainId: v.chainId, core: v.core, inventory: v.inventory }), sourceReader: io.codePin(v.sourceReader),
    retrievalBindingReader: io.codePin(v.retrievalBindingReader), linkedDependencies: io.pinList(v.linkedDependencies) });
}
const hd = (v: CurrentViewPreservationInventoryV1HistoryDeployment) => historyDeployment({ chainId: v.chainId, core: v.core, inventory: v.inventory });
const coordinates = (d: CurrentViewPreservationInventoryV1HistoryDeployment) => ({ chainId: d.chainId, core: d.core, inventory: d.inventory.address });
const read = <T>(p: io.Reader, d: CurrentViewPreservationInventoryV1HistoryDeployment, name: string, args: readonly unknown[], tag: number, cap?: bigint): Promise<T> =>
  io.read(p, d.inventory.address, host(), name, args, tag, undefined, cap);
function pins(deps: Dependencies) { return [...deps.targets.map((address, i) => ({ address, codeHash: deps.codeHashes[i]! })),
  ...deps.artistTargets.map((address, i) => ({ address, codeHash: deps.artistCodeHashes[i]! })), { address: deps.artistContentOwner, codeHash: deps.artistContentOwnerCodeHash }]; }
function zero(t: ParamType): unknown {
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map(v => [v.name, zero(v)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength!) }, () => zero(t.arrayChildren!));
  if (t.type === "address") return io.ZERO_ADDRESS;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type.startsWith("bytes")) return `0x${"00".repeat(Number(t.type.slice(5)) || 0)}`;
  return 0n;
}
const emptyPlan = () => zero(ParamType.from(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE)) as Plan;
const emptyToken = () => zero(ParamType.from(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE)) as Token;
function locators(v: readonly CurrentViewPreservationInventoryV1SegmentLocator[]) {
  if (!Array.isArray(v) || v.length > MAX_SEGMENTS) throw Error("Segment client allocation limit exceeded");
  const seen = new Set<string>();
  return v.map(row => { io.keys(row, ["transactionHash", "logIndex"]); const r = { transactionHash: io.hash(row.transactionHash), logIndex: io.number(row.logIndex) };
    const key = `${r.transactionHash}:${r.logIndex}`; if (seen.has(key)) throw Error("Duplicate segment locator"); seen.add(key); return r; });
}
function rows(v: unknown): readonly Item[] {
  if (!Array.isArray(v) || v.length > MAX_ITEMS) throw Error("Item client allocation limit exceeded");
  return v.map(row => inv.normalizeCurrentViewPreservationInventoryV1Item(row));
}
async function bindings(p: io.Reader, d: CurrentViewPreservationInventoryV1HistoryDeployment, tag: number) {
  await io.runtime(p, d.inventory, tag);
  const dependencies = inv.normalizeCurrentViewPreservationInventoryV1Dependencies(await read(p, d, "dependencies", [], tag));
  if (dependencies.chainId !== d.chainId || dependencies.targets[0] !== d.core) throw Error("Inventory deployment identity differs");
  const dependencyHash = inv.currentViewPreservationInventoryV1DependencyHash(dependencies);
  io.equal(await read(p, d, "dependencyHash", [], tag), dependencyHash, "Inventory dependency hash differs");
  io.equal(await read(p, d, "inventoryProfile", [], tag), inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROFILE, "Wrong companion-enabled VIEW inventory profile");
  for (const [name, at] of [["core", 0], ["metadataHost", 1], ["metadataRouter", 4], ["snapshots", 5], ["referencePublisher", 6], ["artifactCoverage", 10], ["externalCoverage", 11]] as const)
    io.equal(await read(p, d, name, [], tag), dependencies.targets[at], "Named dependency differs");
  return { dependencies, dependencyHash };
}
function contextJoins(d: CurrentViewPreservationInventoryV1HistoryDeployment, depHash: Hex, planId: Hex, c: Context, plan: Plan) {
  inv.validateCurrentViewPreservationInventoryV1Context(coordinates(d), c);
  const s = c.scope;
  if (s.scopeType !== 4n || s.collectionId === 0n || s.tokenId !== 0n || s.scopeId === io.ZERO || c.tokenCount === 0n) throw Error("Invalid original VIEW scope/count");
  io.equal(plan.scope, s, "Retained full scope differs");
  io.equal(inv.currentViewPreservationInventoryV1PlanId(coordinates(d), depHash, c), planId, "Retained context plan differs");
  io.equal([plan.progress.collectionId, plan.progress.subject, plan.progress.artistId, plan.progress.sourceContextHash, plan.progress.tokenCount],
    [s.collectionId, c.subject, c.artistId, inv.currentViewPreservationInventoryV1ContextHash(c), c.tokenCount], "Retained context identity differs");
  if (plan.progress.completedStages > 11n || plan.progress.nextToken > c.tokenCount || plan.nativeCursor > plan.nativeCount || plan.referenceCursor > plan.referenceCount) throw Error("Invalid retained progress");
}
function completion(d: CurrentViewPreservationInventoryV1HistoryDeployment, dependencyHash: Hex, planId: Hex, c: Context, plan: Plan): Evidence {
  const p = plan.progress;
  const evidence: Evidence = { scope: c.scope, inventory: { planId, collectionId: c.scope.collectionId, scopeSubject: c.subject, artistId: c.artistId,
    originals: { rootRecordHash: c.rootRecordHash, snapshotRecordHash: c.snapshot.recordHash, referenceRenderRecordHash: c.referenceRender.observation.recordHash,
      intentRecordHash: c.conservation.record.kind === 0n ? c.conservation.record.recordHash : io.ZERO,
      intentWaiverRecordHash: c.conservation.record.kind === 1n ? c.conservation.record.recordHash : io.ZERO,
      interviewEvidenceHash: c.interviewEvidenceHash, rightsStatementRecordHash: c.descriptions.rightsStatementRecordHash,
      workDescriptionRecordHash: c.descriptions.workDescriptionRecordHash }, sourceContextHash: p.sourceContextHash,
    tokenInventoryHash: c.tokenInventoryHash, tokenCount: c.tokenCount, segmentCount: p.segmentCount, itemCount: p.itemCount,
    segmentChainHash: p.segmentChainHash, renderCriticalEvidenceHash: io.ZERO } };
  return { ...evidence, inventory: { ...evidence.inventory, renderCriticalEvidenceHash: inv.currentViewPreservationInventoryV1EvidenceHash(coordinates(d), dependencyHash, evidence) } };
}
export async function inspectCurrentViewPreservationInventoryV1Segment(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1HistoryDeployment,
  inputLocator: CurrentViewPreservationInventoryV1SegmentLocator, options: { readonly blockTag: number }): Promise<CurrentViewPreservationInventoryV1SegmentObservation> {
  const d = historyDeployment(input), locator = locators([inputLocator])[0]!; io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  const observed = await io.chain(p, d.chainId, tag); await io.runtime(p, d.inventory, tag);
  const tx = await io.mined(p, d.chainId, locator.transactionHash);
  if (tx.observed.blockNumber > tag) throw Error("Segment is later than history block");
  await io.runtime(p, d.inventory, tx.observed.blockNumber);
  const matches = io.events(tx.logs, d.inventory.address, host(), eventName("SegmentRecorded")).filter(e => e.index === locator.logIndex);
  if (matches.length !== 1) throw Error("Missing exact original segment event");
  const e = matches[0]!.fields; if (e.schemaVersion !== 1n) throw Error("Wrong VIEW segment schema");
  const planId = io.hash(e.id), index = io.uint(e.index, 64), items = rows(e.items);
  const segment = inv.normalizeCurrentViewPreservationInventoryV1Segment(e.segment as inv.CurrentViewPreservationInventoryV1Segment);
  io.equal(segment, inv.currentViewPreservationInventoryV1Segment(inv.currentViewPreservationInventoryV1SegmentKey(planId, index), segment.sourceWitnessHash, items), "Emitted Item chain differs");
  io.equal(await read(p, d, "inventorySegment", [planId, index], tag), segment, "Emitted segment differs from retained getter");
  await io.unchanged(p, observed);
  return io.freeze({ locator, recorded: tx.observed, planId, index, segment, items });
}
async function segments(p: io.ReceiptReader, d: CurrentViewPreservationInventoryV1HistoryDeployment, planId: Hex, plan: Plan,
  retained: readonly CurrentViewPreservationInventoryV1SegmentLocator[], tag: number) {
  if (plan.progress.segmentCount > BigInt(MAX_SEGMENTS) || retained.length !== Number(plan.progress.segmentCount)) throw Error("Complete ordered segment locators required within client bound");
  let chain = io.ZERO, count = 0n, retainedBytes = 0; const result: CurrentViewPreservationInventoryV1SegmentObservation[] = [];
  for (let i = 0; i < retained.length; i++) {
    const value = await inspectCurrentViewPreservationInventoryV1Segment(p, hd(d), retained[i]!, { blockTag: tag });
    retainedBytes += (io.coder.encode([inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, `${inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE}[]`], [value.segment, value.items]).length - 2) / 2;
    if (retainedBytes > inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_HISTORY_BYTES) throw Error("History byte allocation bound exceeded");
    if (value.planId !== planId || value.index !== BigInt(i)) throw Error("Wrong segment plan/order");
    const previous = result.at(-1);
    if (previous && (value.recorded.blockNumber < previous.recorded.blockNumber || (value.recorded.blockNumber === previous.recorded.blockNumber && value.locator.logIndex <= previous.locator.logIndex))) throw Error("Segment chronology differs");
    chain = inv.currentViewPreservationInventoryV1AppendSegment(chain, value.index, value.segment); count += value.segment.itemCount;
    if (count > BigInt(MAX_ITEMS)) throw Error("Total Item client allocation exceeded"); result.push(value);
  }
  io.equal([chain, count], [plan.progress.segmentChainHash, plan.progress.itemCount], "Retained segment chain/count differs");
  return result;
}
async function local(p: io.ReceiptReader, d: CurrentViewPreservationInventoryV1HistoryDeployment, bound: Awaited<ReturnType<typeof bindings>>, planId: Hex,
  retained: readonly CurrentViewPreservationInventoryV1SegmentLocator[], tag: number) {
  const plan = inv.normalizeCurrentViewPreservationInventoryV1Plan(await read(p, d, "plan", [planId], tag));
  const token = inv.normalizeCurrentViewPreservationInventoryV1TokenProgress(await read(p, d, "tokenProgress", [planId], tag));
  if (plan.progress.collectionId === 0n) {
    io.equal(plan, emptyPlan(), "Nondefault missing plan"); io.equal(token, emptyToken(), "Nondefault missing token cursor");
    if (retained.length) throw Error("Missing plan has supplied segments");
    return { plan, token, context: null, segments: [], evidence: null };
  }
  const context = inv.normalizeCurrentViewPreservationInventoryV1Context(await read(p, d, "sourceContext", [planId], tag));
  contextJoins(d, bound.dependencyHash, planId, context, plan);
  if (token.phase !== 0n || token.row > token.count || (token.row === 0n && token.count !== 0n)) throw Error("Invalid retained token cursor");
  const retainedSegments = await segments(p, d, planId, plan, retained, tag);
  let evidence: Evidence | null = null;
  if (plan.progress.renderCriticalEvidenceHash !== io.ZERO) {
    if (plan.progress.completedStages !== 11n || plan.progress.nextToken !== plan.progress.tokenCount
      || plan.nativeCount === 0n || plan.nativeCursor !== plan.nativeCount
      || plan.referenceCount === 0n || plan.referenceCursor !== plan.referenceCount) throw Error("Incomplete sealed plan");
    io.equal(token, emptyToken(), "Incomplete sealed row cursor");
    evidence = inv.normalizeCurrentViewPreservationInventoryV1Evidence(await read(p, d, "inventoryEvidence", [planId], tag));
    io.equal(evidence, completion(d, bound.dependencyHash, planId, context, plan), "Retained evidence differs");
    io.equal(evidence.inventory.renderCriticalEvidenceHash, plan.progress.renderCriticalEvidenceHash, "Evidence/plan commitment differs");
  }
  return { plan, token, context, segments: retainedSegments, evidence };
}
const stageFor = (q: Request): bigint => {
  const stages: Record<string, bigint> = { appendNative: 0n, appendReference: 1n, appendWork: 2n, appendRights: 3n, appendIntent: 4n,
    appendIntentWaiver: 4n, appendInterview: 5n, appendInterviewWaiver: 5n, appendRootAuthorization: 6n, appendDefinition: 7n,
    appendArtwork: 8n, appendRenderer: 9n, appendPreservationAdmission: 10n, appendTokenOutput: 11n, sealInventory: 11n };
  const stage = stages[q.method]; if (stage === undefined) throw Error("Not an append/seal stage"); return stage;
};
function stageCheck(q: Request, c: Context, plan: Plan, token: Token) {
  if (q.method === "beginInventory") return;
  if (plan.progress.collectionId === 0n || plan.progress.completedStages !== stageFor(q) || plan.progress.renderCriticalEvidenceHash !== io.ZERO) throw Error("Wrong original inventory stage");
  if (q.method === "appendIntent" && c.conservation.record.kind !== 0n || q.method === "appendIntentWaiver" && c.conservation.record.kind !== 1n
    || q.method === "appendInterview" && c.conservation.interviewStatus !== 0n || q.method === "appendInterviewWaiver" && (c.conservation.interviewStatus !== 1n || c.conservation.interview.recordHash !== io.ZERO)) throw Error("Wrong selected conservation branch");
  if (q.method === "appendTokenOutput" && plan.progress.nextToken >= plan.progress.tokenCount) throw Error("Token cursor exhausted");
  if (q.method === "sealInventory" && (plan.progress.nextToken !== plan.progress.tokenCount || token.row !== 0n || token.count !== 0n || token.phase !== 0n)) throw Error("Incomplete original inventory");
}
async function original(p: io.Reader, prepared: inv.CurrentViewPreservationInventoryV1Call, tag: number, cap: bigint, expected?: unknown) {
  const raw = io.bytes(await p.call({ ...prepared.call, from: prepared.caller, blockTag: tag, gasLimit: cap }));
  const iface = host(), decoded = iface.decodeFunctionResult(prepared.request.method, raw);
  io.equal(iface.encodeFunctionResult(prepared.request.method, decoded), raw, "Noncanonical original result");
  if (expected !== undefined) io.equal(io.plain(iface.getFunction(prepared.request.method)!.outputs[0]!, decoded[0]), expected, "Original result differs");
  return raw;
}
export async function captureCurrentViewPreservationInventoryV1(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1Deployment, caller: Address, request: Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentViewPreservationInventoryV1SegmentLocator[] }): Promise<CurrentViewPreservationInventoryV1WorkflowCapture> {
  const d = deployment(input), prepared = inv.prepareCurrentViewPreservationInventoryV1Call(coordinates(d), io.address(caller), request);
  io.keys(options, ["blockTag", "gasLimit", "segments"]); const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag), bound = await bindings(p, d, tag), deps = bound.dependencies;
  if (deps.readGas < 50000n || [deps.sourceGas, deps.selectionGas, deps.snapshotGas, deps.referenceGas].some(g => g < deps.readGas)) throw Error("Invalid original read budgets");
  await io.runtimes(p, [...pins(deps), d.sourceReader, d.retrievalBindingReader, ...d.linkedDependencies], tag);
  for (const [capability, expected] of [["0x01ffc9a7", true], ["0xffffffff", false], ["0xb8957a7d", true], ["0xb3df912c", true]] as const)
    io.equal(await read(p, d, "supportsInterface", [capability], tag, deps.readGas), expected, "Original inventory capability differs");
  const q = prepared.request;
  const old = q.method === "beginInventory" ? null : await local(p, hd(d), bound, q.id, retained, tag);
  if (q.method !== "beginInventory" && !old?.context) throw Error("Unknown inventory plan");
  const scope = q.method === "beginInventory" ? q.scope : old!.context!.scope;
  const context = inv.normalizeCurrentViewPreservationInventoryV1Context((await io.worker(p, d.sourceReader, workers.source, [deps, scope], tag, cap))[0] as Context);
  inv.validateCurrentViewPreservationInventoryV1Context(coordinates(d), context);
  io.equal(context.scope, scope, "Current full scope differs");
  const planId = inv.currentViewPreservationInventoryV1PlanId(coordinates(d), bound.dependencyHash, context);
  if (q.method !== "beginInventory") io.equal(planId, q.id, "Original current source changed");
  const saved = old ?? await local(p, hd(d), bound, planId, retained, tag);
  if (saved.context) io.equal(saved.context, context, "Current and retained context differ");
  const binding = await io.worker(p, d.retrievalBindingReader, workers.binding, [d.inventory.address, deps, deps.readGas], tag, cap);
  const companion = { witness: io.address(binding[0]), codeHash: io.hash(binding[1]), configuration: retrieval.normalizeCurrentViewRetrievalV1Configuration(binding[2] as retrieval.CurrentViewRetrievalV1Configuration) };
  await io.runtime(p, { address: companion.witness, codeHash: companion.codeHash }, tag);
  io.equal(await io.rpc(p, d.inventory.address, host(), "retrievalWitnessBinding", [], tag), [companion.witness, companion.codeHash], "Companion binding differs");
  stageCheck(q, context, saved.plan, saved.token);
  const expected = q.method === "beginInventory" ? planId : q.method === "sealInventory" ? completion(d, bound.dependencyHash, planId, context, saved.plan) : undefined;
  const originalCallResult = await original(p, prepared, tag, cap, expected);
  await io.unchanged(p, observed);
  const value = { deployment: d, prepared, observed, gasLimit: cap, stage: { ...bound, companion, planId, context, before: saved.plan,
    tokenBefore: saved.token, segments: saved.segments, evidence: saved.evidence, existing: saved.context !== null }, originalCallResult,
    originalCallSimulated: true as const, itemProductionIndependentlyReconstructed: false as const };
  return io.freeze({ ...value, captureHash: io.fingerprint(value) });
}
function savedCapture(input: CurrentViewPreservationInventoryV1WorkflowCapture) {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "stage", "originalCallResult", "originalCallSimulated", "itemProductionIndependentlyReconstructed", "captureHash"]);
  const copy = structuredClone(input), { captureHash, ...body } = copy;
  io.equal(captureHash, io.fingerprint(body), "Capture fingerprint differs");
  const d = deployment(copy.deployment), prepared = inv.normalizeCurrentViewPreservationInventoryV1Call(copy.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Saved deployment/call differs");
  io.gas(copy.gasLimit); io.number(copy.observed.blockNumber); io.hash(copy.observed.blockHash); io.uint(copy.observed.timestamp);
  if (copy.originalCallSimulated !== true || copy.itemProductionIndependentlyReconstructed !== false) throw Error("Wrong capture qualification");
  return io.freeze({ ...copy, deployment: d, prepared });
}
const comparable = (v: CurrentViewPreservationInventoryV1WorkflowCapture) => {
  const segments = v.stage.segments.map(({ recorded, ...row }) => row);
  return { deployment: v.deployment, prepared: v.prepared, gasLimit: v.gasLimit, stage: { ...v.stage, segments }, originalCallResult: v.originalCallResult };
};
async function revalidate(p: io.ReceiptReader, saved: CurrentViewPreservationInventoryV1WorkflowCapture, tag: number) {
  await io.unchanged(p, saved.observed); if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  const actual = await captureCurrentViewPreservationInventoryV1(p, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, segments: saved.stage.segments.map(s => s.locator) });
  io.equal(comparable(actual), comparable(saved), "Inventory facts changed; recapture"); return actual;
}
export async function simulateCurrentViewPreservationInventoryV1(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1WorkflowCapture, options: { readonly blockTag: number }) {
  const saved = savedCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  await revalidate(p, saved, saved.observed.blockNumber); const capture = await revalidate(p, saved, tag);
  return io.freeze({ capture, result: capture.originalCallResult, originalCallSucceeded: true as const, stateChangesPersisted: false as const, itemProductionIndependentlyReconstructed: false as const });
}
export async function inspectCurrentViewPreservationInventoryV1History(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1HistoryDeployment, inputId: Hex,
  options: { readonly blockTag: number; readonly segments: readonly CurrentViewPreservationInventoryV1SegmentLocator[] }) {
  const d = historyDeployment(input), planId = io.hash(inputId); io.keys(options, ["blockTag", "segments"]); const tag = io.number(options.blockTag), retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag), bound = await bindings(p, d, tag), saved = await local(p, d, bound, planId, retained, tag);
  if (!saved.context) throw Error("Unknown inventory plan"); await io.unchanged(p, observed);
  return io.freeze({ observed, planId, ...bound, ...saved, currentSourceChecked: false as const, itemProductionIndependentlyReconstructed: false as const });
}
export async function inspectCurrentViewPreservationInventoryV1Current(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1Deployment, inputId: Hex,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentViewPreservationInventoryV1SegmentLocator[]; readonly fullDefinitionBytes?: boolean }) {
  const d = deployment(input), planId = io.hash(inputId); io.keys(options, ["blockTag", "gasLimit", "segments"], ["fullDefinitionBytes"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  if (options.fullDefinitionBytes !== undefined && typeof options.fullDefinitionBytes !== "boolean") throw Error("Expected diagnostic flag"); const full = options.fullDefinitionBytes === true;
  const history = await inspectCurrentViewPreservationInventoryV1History(p, hd(d), planId, { blockTag: tag, segments: retained });
  if (!history.evidence) throw Error("Inventory incomplete");
  const capture = await captureCurrentViewPreservationInventoryV1(p, d, d.inventory.address, { method: "beginInventory", scope: history.context.scope }, { blockTag: tag, gasLimit: cap, segments: retained });
  io.equal(await read(p, d, "requireCurrent", [history.context.scope], tag, cap), history.evidence, "Original current evidence differs");
  if (full) await io.rpc(p, d.inventory.address, host(), "requireFullDefinitionBytes", [planId], tag, undefined, cap);
  await io.unchanged(p, history.observed);
  return io.freeze({ history, capture, currentSourceChecked: true as const, fullDefinitionBytesChecked: full, itemProductionIndependentlyReconstructed: false as const });
}
function transition(saved: CurrentViewPreservationInventoryV1WorkflowCapture, actualPlan: Plan, actualToken: Token,
  appended: CurrentViewPreservationInventoryV1SegmentObservation | null): Plan {
  const q = saved.prepared.request, s = saved.stage, before = s.before;
  const expected = structuredClone(before) as { -readonly [K in keyof Plan]: Plan[K] };
  const p = { ...before.progress }; expected.progress = p;
  const token = { ...s.tokenBefore };
  if (q.method === "beginInventory") {
    if (!s.existing) {
      const empty = emptyPlan();
      io.equal(actualPlan, { ...empty, scope: s.context.scope, progress: { ...empty.progress,
        collectionId: s.context.scope.collectionId, subject: s.context.subject, artistId: s.context.artistId,
        sourceContextHash: inv.currentViewPreservationInventoryV1ContextHash(s.context), tokenCount: s.context.tokenCount } }, "New inventory state differs");
      io.equal(actualToken, emptyToken(), "New token cursor differs"); return actualPlan;
    }
  } else if (q.method === "sealInventory") {
    p.renderCriticalEvidenceHash = completion(saved.deployment, s.dependencyHash, s.planId, s.context, before).inventory.renderCriticalEvidenceHash;
  } else {
    if (!appended || appended.items.length === 0) throw Error("Expected nonempty original producer segment");
    const segment = appended.segment, items = appended.items, count = BigInt(items.length), stage = stageFor(q);
    let witness: Hex;
    if (q.method === "appendNative" || q.method === "appendReference") {
      const native = q.method === "appendNative", cursor = native ? before.nativeCursor : before.referenceCursor;
      const total = native ? actualPlan.nativeCount : actualPlan.referenceCount;
      if (total === 0n || total > BigInt(MAX_ITEMS) || cursor >= total || (cursor !== 0n && total !== (native ? before.nativeCount : before.referenceCount))
        || count !== (total - cursor < q.maximum ? total - cursor : q.maximum)) throw Error("Original page cursor/count differs");
      witness = keccak256(io.coder.encode(["bytes32", "uint64", "uint64"], [native ? p.sourceContextHash : s.context.referenceRender.observation.payloadHash, cursor, total])) as Hex;
      if (native) { expected.nativeCount = total; expected.nativeCursor = cursor + count; }
      else { expected.referenceCount = total; expected.referenceCursor = cursor + count; }
      if (cursor + count === total) p.completedStages++;
    } else if (q.method === "appendDefinition") {
      let root = -1;
      for (let i = 0; i < s.segments.length; i++) if (s.segments[i]!.segment.sourceWitnessHash === s.context.rootRecordHash) root = i;
      const index = s.segments.length - root - 1;
      if (root < 0 || index < 0 || index >= 36 || count !== 1n) throw Error("Definition stage partition differs");
      const definition = inv.currentViewPreservationInventoryV1Definition(BigInt(index));
      if (items[0]!.kind !== 3n || items[0]!.catalogId !== definition.id || items[0]!.catalogHash !== definition.hash || items[0]!.provenanceHash === io.ZERO) throw Error("Fixed interpretation definition differs");
      witness = keccak256(io.coder.encode(["bytes32", inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE], [definition.id, items[0]])) as Hex;
      if (index === 35) p.completedStages = 8n;
    } else if (stage >= 8n) {
      let index = 0n, total = count;
      if (q.method === "appendRenderer" || q.method === "appendPreservationAdmission") {
        if (count !== 1n) throw Error("Expected one original catalogue row");
        index = token.row;
        total = actualPlan.progress.completedStages === stage + 1n ? index + 1n : actualToken.count;
        if (total === 0n || total > BigInt(MAX_ITEMS) || index >= total || (index !== 0n && token.count !== total)) throw Error("Retained catalogue count changed");
        token.row = index + 1n; token.count = total;
        if (token.row === total) { token.row = 0n; token.count = 0n; p.completedStages++; }
      } else if (q.method === "appendTokenOutput") { index = p.nextToken; p.nextToken++; }
      else p.completedStages = 9n;
      witness = keccak256(io.coder.encode(["bytes32", "bytes32", "bytes32", "bytes32", "uint16", "uint64", "uint64"],
        [id("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"), s.context.adoptionRecord, s.context.checkpointHash, s.context.sourceContextHash, stage, index, total])) as Hex;
    } else {
      witness = q.method === "appendWork" ? s.context.descriptions.workSelectionHash : q.method === "appendRights" ? s.context.descriptions.rightsSelectionHash
        : q.method === "appendIntent" || q.method === "appendIntentWaiver" ? s.context.conservation.selectionHash
        : q.method === "appendRootAuthorization" ? s.context.rootRecordHash : s.context.interviewEvidenceHash;
      if (q.method === "appendInterviewWaiver" || q.method === "appendRootAuthorization") if (count !== 1n) throw Error("Expected one original witness row");
      p.completedStages++;
    }
    io.equal(segment.sourceWitnessHash, witness, "Original segment witness differs");
    if (appended.planId !== s.planId || appended.index !== p.segmentCount) throw Error("Wrong appended segment coordinate");
    p.segmentChainHash = inv.currentViewPreservationInventoryV1AppendSegment(p.segmentChainHash, p.segmentCount, segment);
    p.segmentCount++; p.itemCount += count;
  }
  io.equal(actualPlan, expected, "End-block plan differs; concurrent progress is not attributed");
  io.equal(actualToken, token, "End-block token cursor differs"); return actualPlan;
}
export async function reconcileCurrentViewPreservationInventoryV1Receipt(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1WorkflowCapture,
  inputHash: Hex, options: CurrentViewPreservationInventoryV1ReceiptOptions) {
  const saved = savedCapture(input), tx = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller, call: saved.prepared.call, observed: saved.observed }, io.hash(inputHash), options);
  await revalidate(p, saved, saved.observed.blockNumber);
  const prior = await revalidate(p, saved, tx.observed.blockNumber - 1), d = prior.deployment, s = prior.stage, tag = tx.observed.blockNumber;
  await io.runtimes(p, [d.inventory, d.sourceReader, d.retrievalBindingReader, ...d.linkedDependencies, ...pins(s.dependencies),
    { address: s.companion.witness, codeHash: s.companion.codeHash }], tag);
  const plan = inv.normalizeCurrentViewPreservationInventoryV1Plan(await read(p, d, "plan", [s.planId], tag));
  const token = inv.normalizeCurrentViewPreservationInventoryV1TokenProgress(await read(p, d, "tokenProgress", [s.planId], tag));
  io.equal(await read(p, d, "sourceContext", [s.planId], tag), s.context, "Mined retained context differs");
  const begins = io.events(tx.logs, d.inventory.address, host(), eventName("Started"));
  const appends = io.events(tx.logs, d.inventory.address, host(), eventName("SegmentRecorded"));
  const completes = io.events(tx.logs, d.inventory.address, host(), eventName("Completed"));
  const method = prior.prepared.request.method;
  let appended: CurrentViewPreservationInventoryV1SegmentObservation | null = null;
  let evidence: Evidence | null = null;
  if (method === "beginInventory") {
    if (begins.length !== (s.existing ? 0 : 1) || appends.length || completes.length) throw Error("Wrong inventory begin events");
    if (!s.existing) io.one(tx.logs, d.inventory.address, host(), eventName("Started"), [1n, s.planId, s.context.scope, inv.currentViewPreservationInventoryV1ContextHash(s.context)]);
  } else if (method === "sealInventory") {
    if (begins.length || appends.length) throw Error("Wrong inventory seal events");
    evidence = completion(d, s.dependencyHash, s.planId, s.context, s.before);
    io.one(tx.logs, d.inventory.address, host(), eventName("Completed"), [1n, s.planId, evidence.inventory.renderCriticalEvidenceHash, evidence]);
    io.equal(await read(p, d, "inventoryEvidence", [s.planId], tag), evidence, "Mined inventory evidence differs");
  } else {
    if (begins.length || completes.length || appends.length !== 1) throw Error("Wrong original append events");
    const event = appends[0]!, fields = event.fields;
    if (fields.schemaVersion !== 1n) throw Error("Wrong VIEW segment schema");
    const planId = io.hash(fields.id), index = io.uint(fields.index, 64), items = rows(fields.items);
    const segment = inv.normalizeCurrentViewPreservationInventoryV1Segment(fields.segment as inv.CurrentViewPreservationInventoryV1Segment);
    io.equal(segment, inv.currentViewPreservationInventoryV1Segment(inv.currentViewPreservationInventoryV1SegmentKey(planId, index), segment.sourceWitnessHash, items), "Emitted Item chain differs");
    io.equal(await read(p, d, "inventorySegment", [planId, index], tag), segment, "Emitted segment differs from retained getter");
    appended = { locator: { transactionHash: tx.transactionHash, logIndex: event.index }, recorded: tx.observed, planId, index, segment, items };
  }
  transition(prior, plan, token, appended); io.finish(tx.logs, [d.inventory.address], tx.safeIndex); await io.unchanged(p, tx.observed);
  return io.freeze({ observed: tx.observed, prior: prior.observed, transactionHash: tx.transactionHash, planId: s.planId, plan, token, appended, evidence,
    originalEventAuthenticated: true as const, itemProductionIndependentlyReconstructed: false as const, precedingAndEndBlockAttribution: true as const,
    currentSourceReauthorizedAtEndBlock: false as const, intraBlockTraceProven: false as const });
}
export async function observeCurrentViewPreservationInventoryV1Refusal(p: io.ReceiptReader, input: CurrentViewPreservationInventoryV1WorkflowCapture,
  options: { readonly blockTag: number }) {
  const saved = savedCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  await revalidate(p, saved, saved.observed.blockNumber); if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  const observed = await io.chain(p, saved.deployment.chainId, tag); await io.runtime(p, saved.deployment.inventory, tag);
  const state = async () => ({ plan: await read(p, saved.deployment, "plan", [saved.stage.planId], tag), token: await read(p, saved.deployment, "tokenProgress", [saved.stage.planId], tag) });
  const before = await state(); let result: Hex | null = null, failure: { code: string; revertData: Hex | null } | null = null;
  try { result = await original(p, saved.prepared, tag, saved.gasLimit); } catch (e) {
    const v = e as { code?: unknown; data?: unknown }; const code = typeof v?.code === "string" && ["CALL_EXCEPTION", "NETWORK_ERROR", "SERVER_ERROR", "TIMEOUT"].includes(v.code) ? v.code : "UNKNOWN_ERROR";
    let data: Hex | null = null; try { if (v?.data !== undefined) data = io.bytes(v.data, 4096); } catch { /* opaque transport error */ }
    failure = { code, revertData: data };
  }
  io.equal(await state(), before, "Local state observation changed"); await io.unchanged(p, observed);
  return io.freeze({ observed, result, failure, outcome: failure ? failure.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const : "call-succeeded" as const,
    currentSourceRevalidated: false as const, stateChangesPersisted: false as const, submittedTransactionRollbackProven: false as const });
}
