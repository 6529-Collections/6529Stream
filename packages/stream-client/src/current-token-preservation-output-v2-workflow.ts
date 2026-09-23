import { Interface, keccak256, id } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as p from "./current-token-preservation-output-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import { requireSafeExecution } from "./safe.js";

const checkpointAbi = new Interface([
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function entropySourceSet() view returns (address)",
  "function entropySourceSetCodeHash() view returns (bytes32)",
  "function factoryDependenciesHash() view returns (bytes32)",
  "function metadataRouter() view returns (address)",
  "function preservationOutputProfile() pure returns (bytes32)",
  "function preservationPolicyProfile() view returns (bytes32)",
  "function routerCodeHash() view returns (bytes32)",
  "function scoped() view returns (bool)",
  "function selectionCheckpoint() view returns (address)",
  "function selectionCodeHash() view returns (bytes32)",
  "function sourceFactory() view returns (address)",
  "function sourceFactoryCodeHash() view returns (bytes32)",
  "function terminalReadiness() view returns (address)",
  "function terminalReadinessCodeHash() view returns (bytes32)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)"
]);

const outputAbi = new Interface([
  "function checkpointCodeHash() view returns (bytes32)",
  "function checkpointProfile() view returns (bytes32)",
  "function core() view returns (address)",
  "function coverageCodeHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function outputProfile() view returns (bytes32)",
  "function schemaCodeHash() view returns (bytes32)",
  "function schemaRegistry() view returns (address)",
  "function contentCheckpoint() view returns (address)",
  "function artifactCoverage() view returns (address)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)"
]);

const selectionAbi = new Interface([
  "function requireCurrentCheckpoint(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot))",
  "function checkpoint(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot))",
  "function selectionAt(bytes32 id, uint256 index) view returns ((uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes))",
  "function scopeMembership() view returns (address)",
  "function metadataHost() view returns (address)"
]);

const sourceAbi = new Interface([
  "function SOURCE_SET_PROFILE() view returns (bytes32)",
  "function core() view returns (address)",
  "function factory() view returns (address)",
  "function sourceScope() view returns ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId))",
  "function scopeMembershipFacts() view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function originalInventoryHash() view returns (bytes32)",
  "function originalPolicyChainHash() view returns (bytes32)",
  "function inventoryPlan() view returns (bytes32)",
  "function requireCurrentSourceSet() view",
  "function tokenEntropyReadiness(uint256 tokenId) view returns ((address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) t)"
]);

const factoryAbi = new Interface([
  "function dependencies() view returns ((address[4] targets, bytes32[4] codeHashes, uint256 chainId, uint32 readGas, uint32 inventoryGas))",
  "function currentInventoryPlan((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function sourceSetForPlan(bytes32 plan) view returns (address sourceSet, bytes32 codeHash)",
  "function requireCurrentRoute((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash))",
  "function scopedPolicyFactoryProfile() pure returns (bytes32)"
]);

const routerAbi = new Interface([
  "function resolvedMetadataConfig(uint256 tokenId) view returns ((bytes32 recordHash, bytes32 previous, uint256 collectionId, uint256 tokenId, uint64 revision, uint64 defaultRevision, uint8 level, bytes32 sourceSnapshotHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, (uint8 mode, address renderer, string baseURI, string pendingURI, uint8 offchainURIIdMode, bool frozen) config))",
  "function staticRenderSourceForConfig(uint256 id, bytes32 hash) view returns ((uint256 chainId, bool configured, string name, string description, string imageURI, string animationBaseURI, string script, (address host, bytes32 codeHash, bytes32 manifestHash) scriptManifest, (address host, bytes32 codeHash, bytes32 manifestHash) mediaManifest) source, (uint8 mode, address renderer, string baseURI, string pendingURI, uint8 offchainURIIdMode, bool frozen) config)"
]);

const readinessAbi = new Interface([
  "function core() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function entropySourceSet() view returns (address)",
  "function requireTerminalRenderReady(uint256 tokenId) view returns (((address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 configRecordHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, address registry, bytes32 registryCodeHash, bytes32 admissionHash, bytes32 policyChainHash, bytes32 evidenceHash) e)"
]);

const registryAbi = new Interface([
  "function requirePreservation(bytes32 versionKey, address producer, bytes32 profile) view returns ((address producer, bytes32 producerCodeHash, bytes32 profile, address core, address router, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash), (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash))"
]);

const producerAbi = new Interface([
  "function preservationBinding() view returns (address, address, address, bytes32, address, bytes32)",
  "function preservationProfile() pure returns (bytes32)",
  "function preservationTokenJSON(uint256 token) view returns (string)",
  "function preservationTokenHTML(uint256 token) view returns (string)"
]);

const coreAbi = new Interface([
  "function coordinatorAtMint(uint256 tokenId) view returns (address)",
  "function tokenData(uint256 tokenId) view returns (bytes)",
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)"
]);

const coverageAbi = new Interface([
  "function core() view returns (address)",
  "function schemaRegistry() view returns (address)",
  "function requireArtifactCoverage(bytes32 hash, bytes32 artistId, bytes32 artifactHash) view returns ((bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) result)",
  "function artifactChunk(bytes32 hash, uint32 index) view returns (address, bytes32)"
]);

const schemaAbi = new Interface([
  "function document(bytes32 id) view returns ((bool exists, uint8 status, bytes32 declarationHash, (string name, uint8 kind, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, string uri, uint32 totalBytes) specification, bytes32[] chunkHashes))",
  "function documentBytes(bytes32 id) view returns (bytes payload)"
]);

const entropyAbi = new Interface(["function staticTokenRenderFacts(uint256 tokenId) view returns (uint8 status, bytes32 seed, address provider)"]);

export type TokenPreservationOutputV2CodePin = io.CodePin;
export interface TokenPreservationOutputV2Deployment {
  readonly chainId: bigint;
  readonly scopeKind: "collection" | "scoped";
  readonly checkpoint: io.CodePin;
  readonly output: io.CodePin;
  /** Complete reviewed release/link roster, including externally linked render/read helpers. */
  readonly linkedDependencies: readonly io.CodePin[];
}
export type TokenPreservationOutputV2ReceiptOptions = io.ReceiptOptions;
type Reader = io.Reader;
type ReceiptReader = io.ReceiptReader;
const { ZERO, ZERO_ADDRESS, coder, equal, same, hash, address, bytes, freeze, read, rpc } = io;
const FAMILY = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2") as Hex;
const MAX_ROWS = 16_384;
const MAX_RENDER = 16_777_216;
const MAX_CALL = 4 * MAX_RENDER + 65_536;
const MAX_OUTER = MAX_CALL + 16_384;
function profile(kind: "collection" | "scoped"): Hex {
  return id(kind === "collection" ? "6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2"
    : "6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2") as Hex;
}
function deployment(value: TokenPreservationOutputV2Deployment): TokenPreservationOutputV2Deployment {
  io.keys(value, ["chainId", "scopeKind", "checkpoint", "output", "linkedDependencies"]);
  if (value.scopeKind !== "collection" && value.scopeKind !== "scoped") throw Error("Unsupported token scope family");
  if (io.uint(value.chainId) === 0n) throw Error("Zero chain");
  return freeze({ chainId: value.chainId, scopeKind: value.scopeKind, checkpoint: io.codePin(value.checkpoint),
    output: io.codePin(value.output), linkedDependencies: io.pinList(value.linkedDependencies) });
}
function count(value: bigint): number {
  if (value < 0n || value > BigInt(MAX_ROWS)) throw Error("Client checkpoint row bound exceeded");
  return Number(value);
}
function iface(kind: "checkpoint" | "output"): Interface { return p.tokenPreservationOutputV2Interface(kind); }
function encode(ifc: Interface, method: string, value: unknown): Hex {
  return coder.encode([ifc.getFunction(method)!.outputs[0]!], [value]) as Hex;
}
function supportedScope(scope: p.TokenPreservationOutputV2Scope, kind: "collection" | "scoped"): void {
  if (scope.collectionId === 0n || (kind === "collection"
    ? scope.scopeType !== 0n || scope.tokenId !== 0n || scope.scopeId !== ZERO
    : scope.scopeType === 1n ? scope.tokenId === 0n || scope.scopeId !== ZERO
      : ![2n, 3n].includes(scope.scopeType) || scope.tokenId !== 0n || scope.scopeId === ZERO)) {
    throw Error("Unsupported full token scope");
  }
}
interface Context {
  readonly coordinates: p.TokenPreservationOutputV2Coordinates;
  readonly core: io.CodePin;
  readonly router: io.CodePin;
  readonly selection: io.CodePin;
  readonly source: io.CodePin;
  readonly readiness: io.CodePin;
  readonly coverage: io.CodePin;
  readonly schema: io.CodePin;
  readonly factory: io.CodePin | null;
  readonly factoryDependenciesHash: Hex;
  readonly readGas: bigint;
  readonly renderGas: bigint;
  readonly outputGas: bigint;
}
async function context(provider: Reader, d: TokenPreservationOutputV2Deployment, tag: number, current = true): Promise<Context> {
  await io.runtimes(provider, [d.checkpoint, d.output, ...d.linkedDependencies], tag);
  const cr = (method: string) => read(provider, d.checkpoint.address, checkpointAbi, method, [], tag);
  const or = (method: string) => read(provider, d.output.address, outputAbi, method, [], tag);
  const pin = async (target: Promise<unknown>, codeHash: Promise<unknown>, required = current): Promise<io.CodePin> => {
    const values = await Promise.all([target, codeHash]);
    const result = { address: address(values[0]), codeHash: hash(values[1]) };
    if (required) await io.runtime(provider, result, tag); return result;
  };
  const core = await pin(cr("core"), cr("coreCodeHash"));
  const router = await pin(cr("metadataRouter"), cr("routerCodeHash"));
  const selection = await pin(cr("selectionCheckpoint"), cr("selectionCodeHash"));
  const source = await pin(cr("entropySourceSet"), cr("entropySourceSetCodeHash"));
  const readiness = await pin(cr("terminalReadiness"), cr("terminalReadinessCodeHash"));
  const coverage = await pin(or("artifactCoverage"), or("coverageCodeHash"), true);
  const schema = await pin(or("schemaRegistry"), or("schemaCodeHash"), true);
  equal([await cr("deploymentChainId"), await or("deploymentChainId"), await cr("scoped"),
    await cr("preservationPolicyProfile"), await cr("preservationOutputProfile"), await or("checkpointProfile"),
    await or("outputProfile"), await or("contentCheckpoint"), await or("checkpointCodeHash"), await or("core")],
  [d.chainId, d.chainId, d.scopeKind === "scoped", profile(d.scopeKind), FAMILY, profile(d.scopeKind),
    id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2"), d.checkpoint.address, d.checkpoint.codeHash, core.address],
  "Fixed producer/output profile or host binding differs");
  if (current) equal([await read(provider, source.address, sourceAbi, "core", [], tag),
    await read(provider, source.address, sourceAbi, "SOURCE_SET_PROFILE", [], tag),
    await read(provider, readiness.address, readinessAbi, "core", [], tag),
    await read(provider, readiness.address, readinessAbi, "metadataRouter", [], tag),
    await read(provider, readiness.address, readinessAbi, "entropySourceSet", [], tag),
    await read(provider, coverage.address, coverageAbi, "core", [], tag),
    await read(provider, coverage.address, coverageAbi, "schemaRegistry", [], tag)],
  [core.address, id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"), core.address, router.address, source.address,
    core.address, schema.address], "Original source/readiness/coverage binding differs");
  const factoryAddress = address(await cr("sourceFactory"), true);
  const factoryHash = hash(await cr("sourceFactoryCodeHash"), true);
  const factoryDependenciesHash = hash(await cr("factoryDependenciesHash"), true);
  let factory: io.CodePin | null = null;
  if (d.scopeKind === "scoped") {
    factory = { address: address(factoryAddress), codeHash: hash(factoryHash) };
    if (current) await io.runtime(provider, factory, tag); hash(factoryDependenciesHash);
  } else equal([factoryAddress, factoryHash, factoryDependenciesHash], [ZERO_ADDRESS, ZERO, ZERO], "Collection factory binding differs");
  const readGas = io.gas(await read(provider, d.checkpoint.address, checkpointAbi, "gasParameter", [id("6529STREAM_GGP_STATIC_CONTENT_READ_GAS")], tag));
  const renderGas = io.gas(await read(provider, d.checkpoint.address, checkpointAbi, "gasParameter", [id("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS")], tag));
  const outputGas = io.gas(await read(provider, d.output.address, outputAbi, "gasParameter", [id("6529STREAM_GGP_STATIC_OUTPUT_MANIFEST_READ_GAS")], tag));
  return freeze({ coordinates: { chainId: d.chainId, core: core.address, metadataRouter: router.address,
    checkpoint: d.checkpoint.address, output: d.output.address, scopeKind: d.scopeKind }, core, router, selection,
    source, readiness, coverage, schema, factory, factoryDependenciesHash, readGas, renderGas, outputGas });
}
async function selected(provider: Reader, c: Context, selectionId: Hex, tag: number) {
  const plan = p.normalizeTokenPreservationOutputV2SelectionPlan(await read(provider, c.selection.address,
    selectionAbi, "requireCurrentCheckpoint", [selectionId], tag, undefined, c.readGas));
  supportedScope(plan.scope, c.coordinates.scopeKind);
  if (plan.tokenCount === 0n || plan.nextIndex !== plan.tokenCount || plan.selectionRoot === ZERO) throw Error("Incomplete Selection");
  count(plan.tokenCount);
  if (c.factory) {
    const dep = await read(provider, c.factory.address, factoryAbi, "dependencies", [], tag, undefined, c.readGas) as {
      targets: readonly Address[]; codeHashes: readonly Hex[]; chainId: bigint };
    equal(keccak256(encode(factoryAbi, "dependencies", dep)), c.factoryDependenciesHash, "Source factory dependencies changed");
    equal([dep.chainId, dep.targets[0], dep.codeHashes[0], dep.targets[1], dep.targets[2]],
      [c.coordinates.chainId, c.core.address, c.core.codeHash,
        await read(provider, c.selection.address, selectionAbi, "metadataHost", [], tag),
        await read(provider, c.selection.address, selectionAbi, "scopeMembership", [], tag)], "Factory constructor binding differs");
    for (let i = 0; i < dep.targets.length; i++) await io.runtime(provider, { address: dep.targets[i]!, codeHash: dep.codeHashes[i]! }, tag);
    const key = hash(await read(provider, c.factory.address, factoryAbi, "currentInventoryPlan", [plan.scope], tag, undefined, c.readGas));
    equal(await rpc(provider, c.factory.address, factoryAbi, "sourceSetForPlan", [key], tag, undefined, c.readGas),
      [c.source.address, c.source.codeHash], "Source set registration differs");
    equal([await read(provider, c.source.address, sourceAbi, "factory", [], tag),
      await read(provider, c.source.address, sourceAbi, "inventoryPlan", [], tag)], [c.factory.address, key], "Source factory identity differs");
    equal(await read(provider, c.factory.address, factoryAbi, "requireCurrentRoute", [plan.scope], tag, undefined, c.readGas),
      { componentType: id("ENTROPY_COORDINATOR"), component: c.source.address, interfaceId: "0x8004d4f5", codeHash: c.source.codeHash },
      "Current scoped source route differs");
  }
  await rpc(provider, c.source.address, sourceAbi, "requireCurrentSourceSet", [], tag, undefined, c.readGas);
  equal(await read(provider, c.source.address, sourceAbi, "sourceScope", [], tag), plan.scope, "Full source scope differs");
  const membership = await read(provider, c.source.address, sourceAbi, "scopeMembershipFacts", [], tag) as { membershipHash: Hex; tokenCount: bigint };
  equal([membership.membershipHash, membership.tokenCount], [plan.membershipHash, plan.tokenCount], "Selection membership differs");
  const inventoryHash = hash(await read(provider, c.source.address, sourceAbi, "originalInventoryHash", [], tag));
  const policyChainHash = hash(await read(provider, c.source.address, sourceAbi, "originalPolicyChainHash", [], tag));
  const rows: p.TokenPreservationOutputV2TokenSelection[] = [];
  for (let i = 0; i < count(plan.tokenCount); i++) {
    const row = p.normalizeTokenPreservationOutputV2TokenSelection(await read(provider, c.selection.address,
      selectionAbi, "selectionAt", [selectionId, BigInt(i)], tag, undefined, c.readGas));
    if (row.tokenId === 0n || (i > 0 && row.tokenId <= rows[i - 1]!.tokenId)
      || (plan.scope.scopeType === 1n && row.tokenId !== plan.scope.tokenId)) throw Error("Selection token order differs");
    rows.push(row);
  }
  return freeze({ plan, rows, inventoryHash, policyChainHash });
}
type Selected = Awaited<ReturnType<typeof selected>>;

async function render(provider: Reader, target: Address, method: string, token: bigint, tag: number, cap: bigint): Promise<Hex> {
  const data = producerAbi.encodeFunctionData(method, [token]);
  const raw = bytes(await provider.call({ to: target, data, blockTag: tag, gasLimit: cap }), MAX_RENDER + 64);
  // EVM string and bytes have the same ABI. Preserve arbitrary original bytes, without a JS UTF-8 assumption.
  const decoded = coder.decode(["bytes"], raw);
  if (!same(coder.encode(["bytes"], decoded), raw)) throw Error("Noncanonical preservation output");
  const output = bytes(decoded[0], MAX_RENDER);
  if (output === "0x") throw Error("Empty preservation render bytes");
  return output;
}
async function observeOutput(provider: Reader, c: Context, plan: p.TokenPreservationOutputV2ContentPlan,
  row: p.TokenPreservationOutputV2TokenSelection, producer: Address, imageHash: Hex,
  animation: Hex | null, tag: number): Promise<p.TokenPreservationOutputV2Output> {
  const producerProfile = hash(await read(provider, producer, producerAbi, "preservationProfile", [], tag, undefined, c.readGas));
  if (![id("6529STREAM_PRESERVATION_RENDER_V1"), id("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1")].includes(producerProfile)) {
    throw Error("Producer is outside the closed token family");
  }
  const code = bytes(await provider.getCode(producer, tag), io.MAX_RUNTIME);
  const producerCodeHash = hash(keccak256(code));
  await io.runtime(provider, { address: producer, codeHash: producerCodeHash }, tag);
  const fields = await rpc(provider, producer, producerAbi, "preservationBinding", [], tag, undefined, c.readGas);
  const preservation = p.normalizeTokenPreservationOutputV2Binding({ producer, producerCodeHash, profile: producerProfile,
    core: address(fields[0]), metadataRouter: address(fields[1]), liveRenderer: address(fields[2]), liveRendererCodeHash: hash(fields[3]),
    attribution: address(fields[4]), attributionCodeHash: hash(fields[5]) });
  equal([preservation.core, preservation.metadataRouter, preservation.liveRenderer, preservation.liveRendererCodeHash,
    row.sources[0], row.sources[1]], [c.core.address, c.router.address, row.selection.renderer, row.selection.rendererCodeHash,
    c.core.address, c.router.address], "Preservation producer binding differs");
  await io.runtimes(provider, [{ address: preservation.liveRenderer, codeHash: preservation.liveRendererCodeHash },
    { address: preservation.attribution, codeHash: preservation.attributionCodeHash },
    { address: row.selection.registry, codeHash: row.selection.registryCodeHash }], tag);
  for (let i = 0; i < row.sources.length; i++) {
    if (row.sources[i] !== ZERO_ADDRESS) await io.runtime(provider, { address: row.sources[i]!, codeHash: row.sourceCodeHashes[i]! }, tag);
  }
  const [binding, admission_] = await rpc(provider, row.selection.registry, registryAbi, "requirePreservation",
    [row.selection.versionKey, producer, producerProfile], tag, undefined, c.readGas);
  const registryBinding = binding as p.TokenPreservationOutputV2RegistryBinding;
  const { router, ...bindingRest } = registryBinding;
  equal({ ...bindingRest, metadataRouter: router }, preservation, "Registry full producer binding differs");
  const admission = p.normalizeTokenPreservationOutputV2Admission(admission_ as p.TokenPreservationOutputV2Admission);
  equal([admission.registry, admission.registryCodeHash, admission.versionKey],
    [row.selection.registry, row.selection.registryCodeHash, row.selection.versionKey], "Selected Registry admission differs");
  for (const value of [admission.registrationHash, admission.readSetHash, admission.analysisHash, admission.goldenHash]) hash(value);
  const config = await read(provider, c.router.address, routerAbi, "resolvedMetadataConfig", [row.tokenId], tag, undefined, c.readGas) as {
    recordHash: Hex; config: { mode: bigint; frozen: boolean }; selection: { rendererId: Hex; rendererVersion: Hex } };
  equal(keccak256(encode(routerAbi, "resolvedMetadataConfig", config)), row.configHash, "STATIC configuration hash differs");
  if (config.recordHash !== row.configRecordHash || config.config.mode !== 1n || !config.config.frozen
    || config.selection.rendererId !== id("6529STREAM_RENDERER_V1")
    || config.selection.rendererVersion !== id("6529STREAM_STATIC_RENDERER_V1")) throw Error("Not frozen STATIC ONCHAIN configuration");
  const source = await rpc(provider, c.router.address, routerAbi, "staticRenderSourceForConfig",
    [plan.scope.collectionId, row.configRecordHash], tag, undefined, c.readGas);
  equal(keccak256(coder.encode([routerAbi.getFunction("staticRenderSourceForConfig")!.outputs[0]!], [source[0]])), row.rawSourceHash,
    "Original raw source differs");
  equal(source[1], config.config, "Selected configuration differs");
  const identity = await rpc(provider, c.core.address, coreAbi, "tokenCollectionIdentity", [row.tokenId], tag, undefined, c.readGas);
  if (identity[0] !== true || identity[1] !== plan.scope.collectionId) throw Error("Permanent token collection identity differs");
  const coordinator = address(await read(provider, c.core.address, coreAbi, "coordinatorAtMint", [row.tokenId], tag, undefined, c.readGas));
  equal(coordinator, row.sources[3], "Original at-mint coordinator differs");
  const entropy = p.normalizeTokenPreservationOutputV2TokenReadiness(await read(provider, c.source.address, sourceAbi,
    "tokenEntropyReadiness", [row.tokenId], tag, undefined, c.readGas));
  equal([entropy.coordinator, entropy.coordinatorCodeHash], [coordinator, row.sourceCodeHashes[3]], "Entropy coordinator differs");
  hash(entropy.policyHash);
  let terminalAdmissionHash = ZERO;
  if (entropy.terminal) {
    if (entropy.finalized || entropy.seed !== ZERO || entropy.renderRequirement !== 1n
      || !((entropy.status === 1n && entropy.mode === 0n) || (entropy.status === 2n && entropy.mode === 2n))) throw Error("Invalid terminal readiness");
    const terminal = p.normalizeTokenPreservationOutputV2TerminalEvidence(await read(provider, c.readiness.address,
      readinessAbi, "requireTerminalRenderReady", [row.tokenId], tag, undefined, c.readGas));
    equal(terminal.entropy, entropy, "Terminal entropy differs");
    for (const key of ["versionKey", "renderer", "rendererCodeHash", "registry", "registryCodeHash"] as const) {
      equal(terminal[key], row.selection[key], "Terminal selected renderer differs");
    }
    equal([terminal.configRecordHash, terminal.policyChainHash], [row.configRecordHash, plan.policyChainHash], "Terminal source differs");
    hash(terminal.admissionHash); hash(terminal.evidenceHash);
    terminalAdmissionHash = keccak256(encode(readinessAbi, "requireTerminalRenderReady", terminal)) as Hex;
  } else {
    if (!entropy.finalized || entropy.status !== 5n || entropy.mode !== 2n || entropy.renderRequirement !== 0n) throw Error("Not finalized required ASYNC");
    const [status, seed] = await rpc(provider, coordinator, entropyAbi, "staticTokenRenderFacts", [row.tokenId], tag, undefined, c.readGas);
    equal([status, seed], [5n, entropy.seed], "Native finalized facts differ");
  }
  const data = bytes(await read(provider, c.core.address, coreAbi, "tokenData", [row.tokenId], tag, undefined, c.readGas), 16_384);
  const json = await render(provider, producer, "preservationTokenJSON", row.tokenId, tag, c.renderGas);
  const html = await render(provider, producer, "preservationTokenHTML", row.tokenId, tag, c.renderGas);
  if (animation !== null) equal(keccak256(animation), keccak256(html), "Supplied animation differs from producer HTML");
  // Original capped append supplies the JSON/data and inline-image pattern admission. Hashes alone do not.
  return p.normalizeTokenPreservationOutputV2Output({
    leaf: { tokenId: row.tokenId, metadataHash: hash(keccak256(json)), imageHash, animationHash: hash(keccak256(html)), contentHash: ZERO, tokenDataHash: hash(keccak256(data)) },
    selectionRowHash: p.tokenPreservationOutputV2SelectionRowHash(c.coordinates.chainId, c.coordinates.core, c.coordinates.metadataRouter, row),
    sourceFactsHash: p.tokenPreservationOutputV2SourceFactsHash(c.coordinates.scopeKind, { preservation, admission,
      configHash: row.configHash, rawSourceHash: row.rawSourceHash, coordinator, entropy,
      entropySourceSet: c.source.address, entropySourceSetCodeHash: c.source.codeHash,
      inventoryHash: plan.inventoryHash, policyChainHash: plan.policyChainHash,
      terminalReadiness: c.readiness.address, terminalReadinessCodeHash: c.readiness.codeHash, terminalAdmissionHash }),
    htmlHash: hash(keccak256(html)), entropy, terminalAdmissionHash, preservation, preservationAdmission: admission });
}
function progressed(c: p.TokenPreservationOutputV2Coordinates, before: p.TokenPreservationOutputV2ContentPlan,
  outputs: readonly p.TokenPreservationOutputV2Output[]): p.TokenPreservationOutputV2ContentPlan {
  let leafChainHash = ZERO; let outputRoot = ZERO;
  for (let i = 0; i < outputs.length; i++) {
    leafChainHash = p.tokenPreservationOutputV2LeafChain(leafChainHash, BigInt(i), p.tokenPreservationOutputV2LeafHash(c.chainId, c.core, outputs[i]!.leaf));
    outputRoot = p.tokenPreservationOutputV2OutputChain(outputRoot, BigInt(i), outputs[i]!);
  }
  return freeze({ ...before, nextIndex: BigInt(outputs.length), leafChainHash, outputRoot,
    contentRoot: BigInt(outputs.length) === before.tokenCount ? p.tokenPreservationOutputV2ContentRoot(c.chainId, c.core, outputs.map(v => v.leaf)) : ZERO });
}
async function localContent(provider: Reader, c: p.TokenPreservationOutputV2Coordinates, key: Hex, tag: number) {
  const plan = p.normalizeTokenPreservationOutputV2ContentPlan(await read(provider, c.checkpoint, iface("checkpoint"), "checkpoint", [key], tag));
  supportedScope(plan.scope, c.scopeKind);
  if (plan.tokenCount === 0n || plan.nextIndex > plan.tokenCount || plan.preservationProfile !== FAMILY) throw Error("Unknown or inconsistent content checkpoint");
  if (plan.scope.scopeType === 1n && plan.tokenCount !== 1n) throw Error("TOKEN checkpoint count differs");
  count(plan.tokenCount);
  for (const value of [plan.selectionId, plan.selectionHash, plan.inventoryHash, plan.policyChainHash]) hash(value);
  const outputs: p.TokenPreservationOutputV2Output[] = [];
  for (let i = 0; i < count(plan.nextIndex); i++) {
    const row = p.validateTokenPreservationOutputV2Output(await read(provider, c.checkpoint, iface("checkpoint"), "outputAt", [key, BigInt(i)], tag));
    equal([row.preservation.core, row.preservation.metadataRouter], [c.core, c.metadataRouter], "Retained producer host identity differs");
    if (row.leaf.tokenId === 0n || (i > 0 && row.leaf.tokenId <= outputs[i - 1]!.leaf.tokenId)
      || (plan.scope.scopeType === 1n && row.leaf.tokenId !== plan.scope.tokenId)) throw Error("Saved token order/full TOKEN identity differs");
    outputs.push(row);
  }
  equal(progressed(c, plan, outputs), plan, "Retained checkpoint roots differ");
  return freeze({ key, plan, outputs });
}
async function currentContent(provider: Reader, c: Context, key: Hex, tag: number, complete: boolean) {
  const saved = await localContent(provider, c.coordinates, key, tag);
  const selection = await selected(provider, c, saved.plan.selectionId, tag);
  equal([saved.plan.scope, saved.plan.selectionHash, saved.plan.inventoryHash, saved.plan.policyChainHash, saved.plan.tokenCount],
    [selection.plan.scope, p.tokenPreservationOutputV2SelectionHash(selection.plan), selection.inventoryHash, selection.policyChainHash, selection.plan.tokenCount],
    "Saved checkpoint source identity differs");
  for (let i = 0; i < saved.outputs.length; i++) {
    const row = saved.outputs[i]!;
    equal(await observeOutput(provider, c, saved.plan, selection.rows[i]!, row.preservation.producer, row.leaf.imageHash, null, tag),
      row, "Previously appended preservation output is stale");
  }
  if (complete) {
    equal(await read(provider, c.coordinates.checkpoint, iface("checkpoint"), "requireCurrentCheckpoint", [key], tag), saved.plan,
      "Original complete checkpoint currentness differs");
    if (saved.plan.nextIndex !== saved.plan.tokenCount) throw Error("Incomplete content checkpoint");
  }
  return freeze({ ...saved, selection });
}
async function definitions(provider: Reader, c: Context, tag: number): Promise<void> {
  for (const [key, kind, expectedHash, expectedBytes] of [
    [p.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA, 0n, p.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_HASH, p.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_BYTES],
    [p.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION, 1n, p.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_HASH, p.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_BYTES]
  ] as const) {
    const d = await read(provider, c.schema.address, schemaAbi, "document", [key], tag, undefined, c.outputGas) as {
      exists: boolean; status: bigint; specification: { name: string; kind: bigint; contentHash: Hex; canonicalizationId: Hex; totalBytes: bigint } };
    equal([d.exists, d.status, id(d.specification.name), d.specification.kind, d.specification.contentHash,
      d.specification.canonicalizationId, d.specification.totalBytes], [true, 0n, key, kind, expectedHash, id("RAW_BYTES"), expectedBytes],
      "Original active interpretation document differs");
    const raw = bytes(await read(provider, c.schema.address, schemaAbi, "documentBytes", [key], tag, undefined, c.outputGas), 8192);
    equal([keccak256(raw), BigInt((raw.length - 2) / 2)], [expectedHash, expectedBytes], "Original definition bytes differ");
  }
}
async function artifact(provider: Reader, c: Context, artifactHash: Hex, byteLength: bigint, tag: number) {
  if (byteLength <= 0n || byteLength > 524_288n) throw Error("Original manifest byte bound exceeded");
  const chunks: { readonly address: Address; readonly codeHash: Hex }[] = [];
  let canonical = "0x";
  for (let i = 0n; i < (byteLength + 8191n) / 8192n; i++) {
    const [target, runtime] = await rpc(provider, c.coverage.address, coverageAbi, "artifactChunk", [artifactHash, i], tag, undefined, c.outputGas);
    const pin = { address: address(target), codeHash: hash(runtime) };
    const raw = bytes(await provider.getCode(pin.address, tag), 8193);
    const remaining = byteLength - i * 8192n;
    if (!raw.startsWith("0x00") || keccak256(raw) !== pin.codeHash
      || BigInt((raw.length - 4) / 2) !== (remaining > 8192n ? 8192n : remaining)) throw Error("Artifact STOP carrier differs");
    canonical += raw.slice(4); chunks.push(pin);
  }
  return freeze({ canonical: canonical as Hex, chunks });
}
async function manifestFacts(provider: Reader, c: Context, checkpointHash: Hex, artifactHash: Hex, coverageHash: Hex, artistId: Hex, tag: number) {
  await definitions(provider, c, tag);
  const content = await currentContent(provider, c, checkpointHash, tag, true);
  const coverage = p.normalizeTokenPreservationOutputV2Coverage(await read(provider, c.coverage.address, coverageAbi,
    "requireArtifactCoverage", [coverageHash, artistId, artifactHash], tag, undefined, c.outputGas));
  equal([coverage.completionHash, coverage.artifactHash, coverage.artistId, coverage.schemaId, coverage.canonicalizationId],
    [coverageHash, artifactHash, artistId, p.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA, p.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION], "Coverage identity differs");
  hash(artistId); hash(coverageHash); hash(artifactHash); hash(coverage.contentHash);
  if (coverage.firstFamilyRecordHash === ZERO || coverage.secondFamilyRecordHash === ZERO
    || coverage.firstFamilyRecordHash === coverage.secondFamilyRecordHash
    || coverage.chunkCount !== (coverage.byteLength + 8191n) / 8192n) throw Error("Invalid full artifact coverage");
  const archive = await artifact(provider, c, artifactHash, coverage.byteLength, tag);
  const canonical = p.tokenPreservationOutputV2ManifestBytes(c.coordinates, checkpointHash, content.plan, c.source.address, content.outputs);
  equal(archive.canonical, canonical, "Preserved canonical manifest differs");
  equal(keccak256(canonical), coverage.contentHash, "Manifest coverage content differs");
  const manifest = p.tokenPreservationOutputV2Manifest(c.coordinates, checkpointHash, content.plan, c.source.address, coverage);
  return freeze({ content, archive, manifest, coverage });
}
async function checkpointStage(provider: Reader, c: Context, request: Extract<p.TokenPreservationOutputV2Request, { kind: "begin" | "append" }>, tag: number) {
  if (request.kind === "begin") {
    const selection = await selected(provider, c, request.selectionId, tag);
    const identity: p.TokenPreservationOutputV2CheckpointIdentity = {
      selectionCheckpoint: c.selection.address, selectionId: request.selectionId, selection: selection.plan,
      entropySourceSet: c.source.address, entropySourceSetCodeHash: c.source.codeHash,
      terminalReadiness: c.readiness.address, terminalReadinessCodeHash: c.readiness.codeHash,
      inventoryHash: selection.inventoryHash, policyChainHash: selection.policyChainHash, salt: request.salt };
    const key = p.tokenPreservationOutputV2CheckpointId(c.coordinates, identity);
    const before = p.normalizeTokenPreservationOutputV2ContentPlan(await read(provider, c.coordinates.checkpoint, iface("checkpoint"), "checkpoint", [key], tag));
    const initial = p.tokenPreservationOutputV2InitialContentPlan(c.coordinates.scopeKind, identity);
    if (before.tokenCount === 0n) {
      if (!/^0x0+$/.test(p.encodeTokenPreservationOutputV2ContentPlan(before))) throw Error("Noncanonical missing checkpoint");
    } else {
      equal({ ...before, nextIndex: 0n, leafChainHash: ZERO, contentRoot: ZERO, outputRoot: ZERO }, initial, "Retained begin identity differs");
      await localContent(provider, c.coordinates, key, tag);
    }
    // Original begin retries recheck Selection/source, but never rerender a retained prefix.
    return freeze({ kind: "checkpoint" as const, key, before, expected: before.tokenCount === 0n ? initial : before,
      selection, outputs: [] as readonly p.TokenPreservationOutputV2Output[], appended: [] as readonly p.TokenPreservationOutputV2Output[] });
  }
  const saved = await currentContent(provider, c, request.id, tag, false);
  if (BigInt(request.payloads.length) > saved.plan.tokenCount - saved.plan.nextIndex) throw Error("Append exceeds remaining rows");
  const appended: p.TokenPreservationOutputV2Output[] = [];
  for (let i = 0; i < request.payloads.length; i++) {
    const payload = request.payloads[i]!;
    const row = saved.selection.rows[saved.outputs.length + i]!;
    equal(payload.tokenId, row.tokenId, "Append token differs from Selection order");
    appended.push(await observeOutput(provider, c, saved.plan, row, payload.producer,
      payload.image === "0x" ? ZERO : keccak256(payload.image) as Hex, payload.animation, tag));
  }
  return freeze({ kind: "checkpoint" as const, key: request.id, before: saved.plan,
    expected: progressed(c.coordinates, saved.plan, [...saved.outputs, ...appended]), selection: saved.selection,
    outputs: saved.outputs, appended });
}
function validateOutputPlan(c: Context, key: Hex, plan: p.TokenPreservationOutputV2OutputPlan): void {
  const m = plan.manifest;
  supportedScope(m.scope, c.coordinates.scopeKind);
  if (m.tokenCount === 0n || m.tokenCount > 454n || plan.nextIndex > m.tokenCount || m.byteLength !== 640n + 1152n * m.tokenCount
    || m.preservationProfile !== FAMILY || m.metadataRouter !== c.router.address) throw Error("Invalid retained manifest plan");
  if (m.scope.scopeType === 1n && m.tokenCount !== 1n) throw Error("TOKEN manifest count differs");
  equal(p.tokenPreservationOutputV2ManifestPlanHash(c.coordinates, c.coverage.address, m), key, "Manifest plan identity differs");
  equal(plan.recordHash, plan.nextIndex === m.tokenCount ? p.tokenPreservationOutputV2RecordHash(key) : ZERO, "Manifest completion differs");
}
async function outputStage(provider: Reader, c: Context, request: Extract<p.TokenPreservationOutputV2Request, { kind: "beginManifest" | "verifyNextOutputs" }>, tag: number) {
  if (request.kind === "beginManifest") {
    const facts = await manifestFacts(provider, c, request.checkpointHash, request.artifactHash, request.coverageHash, request.artistId, tag);
    const key = p.tokenPreservationOutputV2ManifestPlanHash(c.coordinates, c.coverage.address, facts.manifest);
    const before = p.normalizeTokenPreservationOutputV2OutputPlan(await read(provider, c.coordinates.output, iface("output"), "manifestPlan", [key], tag));
    if (before.manifest.tokenCount === 0n) {
      if (!/^0x0+$/.test(p.encodeTokenPreservationOutputV2OutputPlan(before))) throw Error("Noncanonical missing manifest");
    } else { validateOutputPlan(c, key, before); equal(before.manifest, facts.manifest, "Retained manifest identity differs"); }
    return freeze({ kind: "output" as const, key, before, expected: before.manifest.tokenCount === 0n
      ? { manifest: facts.manifest, nextIndex: 0n, recordHash: ZERO } : before, facts, currentAdmission: true as boolean,
      archive: facts.archive, verified: [] as readonly p.TokenPreservationOutputV2Output[] });
  }
  const before = p.normalizeTokenPreservationOutputV2OutputPlan(await read(provider, c.coordinates.output, iface("output"), "manifestPlan", [request.planHash], tag));
  validateOutputPlan(c, request.planHash, before);
  if (request.count > before.manifest.tokenCount - before.nextIndex) throw Error("Verify exceeds remaining rows");
  const m = before.manifest;
  const nextIndex = before.nextIndex + request.count;
  const final = nextIndex === m.tokenCount;
  const facts = final ? await manifestFacts(provider, c, m.checkpointHash, m.artifactHash, m.coverageHash, m.artistId, tag) : null;
  if (facts) equal(facts.manifest, m, "Final manifest current source differs");
  const archive = facts?.archive ?? await artifact(provider, c, m.artifactHash, m.byteLength, tag);
  equal(keccak256(archive.canonical), m.manifestHash, "Retained manifest bytes differ");
  const verified: p.TokenPreservationOutputV2Output[] = [];
  for (let i = before.nextIndex; i < nextIndex; i++) {
    const output = p.normalizeTokenPreservationOutputV2Output(await read(provider, c.coordinates.checkpoint, iface("checkpoint"), "outputAt", [m.checkpointHash, i], tag, undefined, c.outputGas));
    const offset = Number(640n + 1152n * i) * 2 + 2;
    equal(`0x${archive.canonical.slice(offset, offset + 2304)}`, p.encodeTokenPreservationOutputV2Output(output), "Manifest ordered output differs");
    verified.push(output);
  }
  return freeze({ kind: "output" as const, key: request.planHash, before, expected: { manifest: m, nextIndex,
    recordHash: final ? p.tokenPreservationOutputV2RecordHash(request.planHash) : ZERO }, facts,
    currentAdmission: final, archive, verified });
}
type Stage = Awaited<ReturnType<typeof checkpointStage>> | Awaited<ReturnType<typeof outputStage>>;
export interface TokenPreservationOutputV2Capture {
  readonly deployment: TokenPreservationOutputV2Deployment;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly context: Context;
  readonly prepared: p.TokenPreservationOutputV2Call;
  readonly stage: Stage;
  readonly captureHash: Hex;
  readonly originalCallAdmissionRequired: true;
}
export async function captureTokenPreservationOutputV2(provider: Reader, inputDeployment: TokenPreservationOutputV2Deployment,
  inputCaller: Address, inputRequest: p.TokenPreservationOutputV2Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint }): Promise<TokenPreservationOutputV2Capture> {
  const d = deployment(inputDeployment); const caller = address(inputCaller);
  const request = p.normalizeTokenPreservationOutputV2Request(inputRequest);
  io.keys(options, ["blockTag", "gasLimit"]); const tag = io.number(options.blockTag); const gasLimit = io.gas(options.gasLimit);
  const observed = await io.chain(provider, d.chainId, tag);
  let current = true;
  if (request.kind === "verifyNextOutputs") {
    await io.runtime(provider, d.output, tag);
    const prior = p.normalizeTokenPreservationOutputV2OutputPlan(await read(provider, d.output.address, iface("output"), "manifestPlan", [request.planHash], tag));
    current = prior.nextIndex + request.count === prior.manifest.tokenCount;
  }
  const c = await context(provider, d, tag, current);
  const prepared = p.prepareTokenPreservationOutputV2Call(c.coordinates, caller, request);
  bytes(prepared.call.data, MAX_CALL);
  const stage = request.kind === "begin" || request.kind === "append"
    ? await checkpointStage(provider, c, request, tag) : await outputStage(provider, c, request, tag);
  await io.unchanged(provider, observed);
  const value = { deployment: d, observed, gasLimit, context: c, prepared, stage, originalCallAdmissionRequired: true as const };
  return freeze({ ...value, captureHash: io.fingerprint(value) });
}
function snapshot(input: TokenPreservationOutputV2Capture): TokenPreservationOutputV2Capture {
  const owned = structuredClone(input);
  io.keys(owned, ["deployment", "observed", "gasLimit", "context", "prepared", "stage", "captureHash", "originalCallAdmissionRequired"]);
  const { captureHash, ...value } = owned;
  equal(io.fingerprint(value), hash(captureHash), "Capture fingerprint differs");
  equal(p.normalizeTokenPreservationOutputV2Call(owned.prepared), owned.prepared, "Prepared call differs");
  equal(owned.prepared.coordinates, owned.context.coordinates, "Captured coordinates differ");
  equal([owned.prepared.coordinates.chainId, owned.prepared.coordinates.scopeKind, owned.prepared.coordinates.checkpoint, owned.prepared.coordinates.output],
    [owned.deployment.chainId, owned.deployment.scopeKind, owned.deployment.checkpoint.address, owned.deployment.output.address]);
  return freeze(owned);
}
function comparable(c: TokenPreservationOutputV2Capture) { const { observed: _observed, captureHash: _captureHash, ...value } = c; return value; }
async function revalidate(provider: Reader, saved: TokenPreservationOutputV2Capture, tag: number) {
  await io.unchanged(provider, saved.observed);
  const now = await captureTokenPreservationOutputV2(provider, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit });
  equal(comparable(now), comparable(saved), "Captured source/progress changed; recapture"); return now;
}
export async function simulateTokenPreservationOutputV2(provider: Reader, input: TokenPreservationOutputV2Capture,
  options: { readonly blockTag: number }) {
  const saved = snapshot(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await revalidate(provider, saved, saved.observed.blockNumber);
  const current = await revalidate(provider, saved, tag);
  const ifc = iface(saved.stage.kind);
  const raw = bytes(await provider.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: saved.gasLimit }));
  const result = ifc.decodeFunctionResult(saved.prepared.request.kind, raw);
  equal(ifc.encodeFunctionResult(saved.prepared.request.kind, result), raw, "Noncanonical simulation result");
  const expected = saved.prepared.request.kind === "begin" || saved.prepared.request.kind === "beginManifest" ? [saved.stage.key]
    : saved.stage.kind === "output" ? [saved.stage.expected.recordHash] : [];
  equal([...result], expected, "Original simulation result differs");
  await io.unchanged(provider, current.observed);
  return freeze({ capture: current, result: expected, originalCallSucceeded: true as const, nativeExecutionProven: false as const });
}

const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);
/** Same strict transport contract as the shared helper, with the original four large append payloads. */
async function transport(provider: ReceiptReader, saved: TokenPreservationOutputV2Capture, inputHash: Hex, options: io.ReceiptOptions) {
  const transactionHash = hash(inputHash);
  if (options.execution === "direct") io.keys(options, ["execution"]);
  else if (options.execution === "safe") io.keys(options, ["execution", "expectedSafeTxHash"]);
  else throw Error("Unsupported transport");
  const execution = options.execution;
  const expectedSafeTxHash = execution === "safe" ? hash(options.expectedSafeTxHash) : ZERO;
  const r = await provider.getTransactionReceipt(transactionHash);
  if (!r || r.status !== 1 || !same(r.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = io.number(r.blockNumber); const blockHash = hash(r.blockHash);
  const from = address(r.from); const to = address(r.to);
  if (!Array.isArray(r.logs) || r.logs.length > io.MAX_LOGS) throw Error("Receipt log bound exceeded");
  let previous = -1; let total = 0;
  const logs: readonly io.Log[] = freeze(r.logs.map(log => {
    const index = io.number(log.index);
    if (index <= previous || log.removed !== false || !same(log.transactionHash, transactionHash)
      || log.blockNumber !== blockNumber || !same(log.blockHash, blockHash)) throw Error("Receipt log identity/order differs");
    previous = index;
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error("Malformed log topics");
    const data = bytes(log.data); total += (data.length - 2) / 2;
    if (total > io.MAX_RPC) throw Error("Aggregate log byte bound exceeded");
    return { address: address(log.address), topics: log.topics.map((topic: string) => hash(topic, true)), data, index };
  }));
  const tx = await provider.getTransaction(transactionHash);
  if (!tx || !same(tx.hash, transactionHash) || !same(tx.from, from) || !same(tx.to, to) || tx.chainId !== saved.deployment.chainId
    || tx.blockNumber !== blockNumber || !same(tx.blockHash, blockHash)) throw Error("Transaction envelope differs");
  const transaction = freeze({ from, to, data: bytes(tx.data, MAX_OUTER), value: io.uint(tx.value) });
  const observed = await io.chain(provider, saved.deployment.chainId, blockNumber);
  equal(observed.blockHash, blockHash, "Receipt block changed");
  if (blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow capture");
  if (transaction.value !== 0n || saved.prepared.call.value !== 0n) throw Error("Original CALL value must be zero");
  let safeIndex = -1;
  if (execution === "direct") {
    equal([from, to, transaction.data], [saved.prepared.caller, saved.prepared.call.to, saved.prepared.call.data], "Direct caller/target/data differs");
  } else {
    equal(to, saved.prepared.caller, "Safe is not the actual caller");
    const decoded = safeAbi.decodeFunctionData("execTransaction", transaction.data);
    equal(safeAbi.encodeFunctionData("execTransaction", decoded), transaction.data, "Noncanonical Safe calldata");
    equal([decoded.to, decoded.value, decoded.data, decoded.operation], [saved.prepared.call.to, 0n, saved.prepared.call.data, 0n], "Safe inner CALL differs");
    const topics = [safeAbi.getEvent("ExecutionSuccess")!.topicHash, safeAbi.getEvent("ExecutionFailure")!.topicHash];
    const matches = logs.filter(log => same(log.address, to) && topics.some(topic => same(log.topics[0], topic)));
    if (matches.length !== 1) throw Error("Expected exactly one Safe execution event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, data: log.data, topics: [...log.topics] })) }, to, expectedSafeTxHash);
    safeIndex = matches[0]!.index;
  }
  return { transactionHash, observed, logs, safeIndex, execution };
}
function receiptPins(saved: TokenPreservationOutputV2Capture): readonly io.CodePin[] {
  const d = saved.deployment; const c = saved.context;
  const pins: io.CodePin[] = [d.checkpoint, d.output, c.schema, c.coverage, ...d.linkedDependencies];
  const stage = saved.stage;
  if (stage.kind === "checkpoint" || stage.currentAdmission) {
    pins.push(c.core, c.router, c.selection, c.source, c.readiness, ...(c.factory ? [c.factory] : []));
    const selection = stage.kind === "checkpoint" ? stage.selection : stage.facts?.content.selection;
    for (const row of selection?.rows ?? []) {
      pins.push({ address: row.selection.registry, codeHash: row.selection.registryCodeHash },
        { address: row.selection.renderer, codeHash: row.selection.rendererCodeHash });
      for (let i = 0; i < row.sources.length; i++) if (row.sources[i] !== ZERO_ADDRESS) pins.push({ address: row.sources[i]!, codeHash: row.sourceCodeHashes[i]! });
    }
    const outputs = stage.kind === "checkpoint" ? [...stage.outputs, ...stage.appended] : stage.facts?.content.outputs ?? [];
    for (const row of outputs) pins.push({ address: row.preservation.producer, codeHash: row.preservation.producerCodeHash },
      { address: row.preservation.attribution, codeHash: row.preservation.attributionCodeHash });
  }
  if (stage.kind === "output") pins.push(...stage.archive.chunks);
  return pins;
}
export async function reconcileTokenPreservationOutputV2Receipt(provider: ReceiptReader, input: TokenPreservationOutputV2Capture,
  transactionHash: Hex, options: TokenPreservationOutputV2ReceiptOptions) {
  const saved = snapshot(input);
  const t = await transport(provider, saved, transactionHash, options);
  await revalidate(provider, saved, saved.observed.blockNumber);
  const prior = await revalidate(provider, saved, t.observed.blockNumber - 1);
  await io.runtimes(provider, receiptPins(prior), t.observed.blockNumber);
  const stage = prior.stage; const request = prior.prepared.request; const c = prior.context.coordinates;
  const required: { name: string; fields: Record<string, unknown> }[] = [];
  const ifc = iface(stage.kind);
  if (stage.kind === "checkpoint") {
    const actual = p.normalizeTokenPreservationOutputV2ContentPlan(await read(provider, c.checkpoint, ifc, "checkpoint", [stage.key], t.observed.blockNumber));
    equal(actual, stage.expected, "Mined checkpoint state differs");
    if (request.kind === "begin") {
      if (stage.before.tokenCount === 0n) required.push({ name: "StaticContentStarted", fields: { schemaVersion: 1n, id: stage.key, salt: request.salt, plan: stage.expected } });
    } else if (request.kind === "append") {
      for (let i = 0; i < stage.appended.length; i++) {
        const index = stage.before.nextIndex + BigInt(i); const value = stage.appended[i]!;
        equal(await read(provider, c.checkpoint, ifc, "outputAt", [stage.key, index], t.observed.blockNumber), value, "Mined output row differs");
        required.push({ name: "StaticContentAppended", fields: { schemaVersion: 1n, id: stage.key, index, output: value,
          leafHash: p.tokenPreservationOutputV2LeafHash(c.chainId, c.core, value.leaf) } });
      }
      if (stage.expected.nextIndex === stage.expected.tokenCount) required.push({ name: "StaticContentCompleted", fields: {
        schemaVersion: 1n, id: stage.key, contentRoot: stage.expected.contentRoot, outputRoot: stage.expected.outputRoot, count: stage.expected.tokenCount } });
    } else throw Error("Captured stage differs");
  } else {
    equal(await read(provider, c.output, ifc, "manifestPlan", [stage.key], t.observed.blockNumber), stage.expected, "Mined manifest progress differs");
    if (request.kind === "beginManifest") {
      if (stage.before.manifest.tokenCount === 0n) required.push({ name: "OutputManifestStarted", fields: { schemaVersion: 2n, planHash: stage.key, manifest: stage.expected.manifest } });
    } else if (request.kind === "verifyNextOutputs") {
      required.push({ name: "OutputManifestAdvanced", fields: { schemaVersion: 2n, planHash: stage.key, firstIndex: stage.before.nextIndex, nextIndex: stage.expected.nextIndex } });
      if (stage.expected.recordHash !== ZERO) {
        equal(await read(provider, c.output, ifc, "manifestRecord", [stage.expected.recordHash], t.observed.blockNumber), stage.expected.manifest, "Mined manifest record differs");
        required.push({ name: "OutputManifestVerified", fields: { schemaVersion: 2n, recordHash: stage.expected.recordHash, planHash: stage.key, manifest: stage.expected.manifest } });
      }
    } else throw Error("Captured stage differs");
  }
  const names = stage.kind === "checkpoint" ? ["StaticContentStarted", "StaticContentAppended", "StaticContentCompleted"]
    : ["OutputManifestStarted", "OutputManifestAdvanced", "OutputManifestVerified"];
  const actual = names.flatMap(name => io.events(t.logs, prior.prepared.call.to, ifc, name).map(row => ({ ...row, name }))).sort((a, b) => a.index - b.index);
  equal(actual.map(({ name, fields }) => ({ name, fields })), required, "Original event count/order/schema differs");
  io.finish(t.logs, [c.checkpoint, c.output], t.safeIndex);
  await io.unchanged(provider, t.observed);
  return freeze({ transactionHash: t.transactionHash, observed: t.observed, prior, result: stage.expected,
    eventlessRetry: required.length === 0, execution: t.execution,
    receiptAttribution: "unchanged-preceding-block-and-exact-end-block" as const, finalityEstablished: false as const });
}
export type TokenPreservationOutputV2HistoryRequest = Readonly<
  { kind: "checkpoint"; id: Hex } | { kind: "manifest"; recordHash: Hex }
>;
/** Only immutable local hosts and their reviewed read-helper roster are required. */
export interface TokenPreservationOutputV2HistoryDeployment extends TokenPreservationOutputV2Deployment {}
async function historyCoordinates(provider: Reader, d: TokenPreservationOutputV2HistoryDeployment, tag: number) {
  await io.runtimes(provider, [d.checkpoint, d.output, ...d.linkedDependencies], tag);
  const core = address(await read(provider, d.checkpoint.address, checkpointAbi, "core", [], tag));
  const metadataRouter = address(await read(provider, d.checkpoint.address, checkpointAbi, "metadataRouter", [], tag));
  equal([await read(provider, d.checkpoint.address, checkpointAbi, "deploymentChainId", [], tag),
    await read(provider, d.checkpoint.address, checkpointAbi, "preservationPolicyProfile", [], tag),
    await read(provider, d.output.address, outputAbi, "deploymentChainId", [], tag),
    await read(provider, d.output.address, outputAbi, "contentCheckpoint", [], tag)],
    [d.chainId, profile(d.scopeKind), d.chainId, d.checkpoint.address], "Local profile/host differs");
  return p.normalizeTokenPreservationOutputV2Coordinates({ chainId: d.chainId, core, metadataRouter,
    checkpoint: d.checkpoint.address, output: d.output.address, scopeKind: d.scopeKind });
}
function historyRequest(value: TokenPreservationOutputV2HistoryRequest): TokenPreservationOutputV2HistoryRequest {
  if (value.kind === "checkpoint") { io.keys(value, ["kind", "id"]); return { kind: value.kind, id: hash(value.id) }; }
  if (value.kind === "manifest") { io.keys(value, ["kind", "recordHash"]); return { kind: value.kind, recordHash: hash(value.recordHash) }; }
  throw Error("Unknown history request");
}
export async function inspectTokenPreservationOutputV2History(provider: Reader, inputDeployment: TokenPreservationOutputV2HistoryDeployment,
  inputRequest: TokenPreservationOutputV2HistoryRequest, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment); const request = historyRequest(inputRequest);
  io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag); const observed = await io.chain(provider, d.chainId, tag);
  const c = await historyCoordinates(provider, d, tag);
  if (request.kind === "checkpoint") {
    const retained = await localContent(provider, c, request.id, tag);
    await io.unchanged(provider, observed);
    return freeze({ kind: "checkpoint" as const, observed, retained, currentAdmissionChecked: false as const });
  }
  const manifest = p.normalizeTokenPreservationOutputV2Manifest(await read(provider, c.output, iface("output"), "manifestRecord", [request.recordHash], tag));
  supportedScope(manifest.scope, c.scopeKind);
  const coverage = address(await read(provider, c.output, outputAbi, "artifactCoverage", [], tag));
  const key = p.tokenPreservationOutputV2ManifestPlanHash(c, coverage, manifest);
  equal(p.tokenPreservationOutputV2RecordHash(key), request.recordHash, "Retained manifest record hash differs");
  const plan = p.normalizeTokenPreservationOutputV2OutputPlan(await read(provider, c.output, iface("output"), "manifestPlan", [key], tag));
  equal(plan, { manifest, nextIndex: manifest.tokenCount, recordHash: request.recordHash }, "Retained manifest completion differs");
  if (manifest.tokenCount === 0n || manifest.tokenCount > 454n || manifest.byteLength !== 640n + 1152n * manifest.tokenCount
    || manifest.preservationProfile !== FAMILY || manifest.metadataRouter !== c.metadataRouter) throw Error("Retained manifest profile differs");
  if (manifest.scope.scopeType === 1n && manifest.tokenCount !== 1n) throw Error("TOKEN manifest count differs");
  await io.unchanged(provider, observed);
  return freeze({ kind: "manifest" as const, observed, key, plan, currentAdmissionChecked: false as const });
}
export async function inspectTokenPreservationOutputV2Current(provider: Reader, inputDeployment: TokenPreservationOutputV2Deployment,
  inputRequest: TokenPreservationOutputV2HistoryRequest, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment); const request = historyRequest(inputRequest);
  io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag); const observed = await io.chain(provider, d.chainId, tag);
  const c = await context(provider, d, tag);
  if (request.kind === "checkpoint") {
    const retained = await currentContent(provider, c, request.id, tag, true); await io.unchanged(provider, observed);
    return freeze({ kind: "checkpoint" as const, observed, retained, originalCurrentnessChecked: true as const });
  }
  const m = p.normalizeTokenPreservationOutputV2Manifest(await read(provider, c.coordinates.output, iface("output"), "manifestRecord", [request.recordHash], tag));
  const facts = await manifestFacts(provider, c, m.checkpointHash, m.artifactHash, m.coverageHash, m.artistId, tag);
  equal(facts.manifest, m, "Current manifest source differs");
  equal(p.tokenPreservationOutputV2RecordHash(p.tokenPreservationOutputV2ManifestPlanHash(c.coordinates, c.coverage.address, m)), request.recordHash);
  equal(await read(provider, c.coordinates.output, iface("output"), "requireCurrentManifest", [request.recordHash, m.artistId], tag), m);
  await io.unchanged(provider, observed);
  return freeze({ kind: "manifest" as const, observed, facts, originalCurrentnessChecked: true as const });
}
async function localState(provider: Reader, saved: TokenPreservationOutputV2Capture, tag: number) {
  return read(provider, saved.prepared.call.to, iface(saved.stage.kind), saved.stage.kind === "checkpoint" ? "checkpoint" : "manifestPlan", [saved.stage.key], tag);
}
export async function observeTokenPreservationOutputV2Refusal(provider: Reader, input: TokenPreservationOutputV2Capture,
  options: { readonly blockTag: number }) {
  const saved = snapshot(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  await revalidate(provider, saved, saved.observed.blockNumber);
  const observed = await io.chain(provider, saved.deployment.chainId, tag);
  await io.runtimes(provider, [saved.deployment.checkpoint, saved.deployment.output, ...saved.deployment.linkedDependencies], tag);
  const before = await localState(provider, saved, tag);
  let error: unknown; let succeeded = false;
  try { await provider.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: saved.gasLimit }); succeeded = true; }
  catch (cause) { error = cause; }
  const after = await localState(provider, saved, tag); await io.unchanged(provider, observed);
  const code = error && typeof error === "object" && "code" in error ? error.code : undefined;
  return freeze({ observed, error, outcome: succeeded ? "succeeded" as const : code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: io.stable(before) === io.stable(after), nativeRollbackProven: false as const });
}
