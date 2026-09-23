/** Original ABI129 scoped finality composition; no new Artist authorization or publication. */
import { Interface, id, keccak256, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as finality from "./current-scoped-policy-finality-v2.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import { inspectScopedPolicyGraphV2Discovery, type ScopedPolicyGraphV2DiscoveryDeployment } from "./current-scoped-policy-graph-v2-workflow.js";
import * as inventory from "./current-scoped-policy-inventory-v2.js";
import * as bundle from "./current-scoped-policy-bundle-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

const abi = new Interface([
  "function document(bytes32 id) view returns ((bool exists, uint8 status, bytes32 declarationHash, (string name, uint8 kind, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, string uri, uint32 totalBytes) specification, bytes32[] chunkHashes))",
  "function dependencyHash() view returns (bytes32)",
  "function owner() view returns (address)",
  "function roleRegistry() view returns (address)",
  "function governanceRootState() view returns (address governanceRoot_, bytes32 codeHash, uint64 revision)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeVetoGuardianSet(bytes32 scopeHash) view returns (address roleRegistryAddress, bytes32 scopedRole, uint256 scopedHolderCount, bytes32 globalRole, uint256 globalHolderCount, uint64 vetoDeadline)",
  "function terminalFreezeActionPage(bytes32 scopeHash, uint256 cursor, uint256 limit) view returns (bytes32[] actionIds, uint64[] vetoDeadlines, uint256 nextCursor)",
  "function terminalFreezeLiveActionUsage(bytes32 scopeHash, address proposer) view returns (uint256 totalMemberships, uint256 nonRootMemberships, uint256 proposerMemberships)",
  "function terminalFreezeLiveActionCaps() pure returns (uint256 totalCap, uint256 nonRootCap, uint256 perNonRootProposerCap)",
  "function freezeSelectorConfig(address target, bytes4 selector) view returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "function roleMutationState(bytes32 role) view returns (bytes32 chainHash, uint64 revision)",
  "function roleHolderCount(bytes32 role) view returns (uint256)",
  "function roleHolderAt(bytes32 role, uint256 index) view returns (address)",
  "function coreReads() view returns (address)",
  "function coreFinalityAdapter() view returns (address)",
  "function metadataReads() view returns (address)",
  "function sanctionReads() view returns (address)",
  "function scopeEvidenceProvider() view returns (address)",
  "function scopeEvidenceProviderCodeHash() view returns (bytes32)",
  "function finalityDiscovery() view returns (address)",
  "function finalityRoleRegistry() view returns (address)",
  "function governanceAuthority() view returns (address)",
  "function artifactCoverage() view returns (address)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function GGP_FINALITY_COMPONENT_READ_GAS_KEY() view returns (bytes32)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function core() view returns (address)",
  "function collectionMetadata() view returns (address)",
  "function evidenceProvider() view returns (address)",
  "function scopedCoreFinalityFacts((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bool scopeExists, uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId, bool tokenMappingExists, uint256 collectionSerial, uint8 tokenLifecycle, bool burned, uint8 collectionStatus, uint8 collectionSupplyMode, bytes32 collectionConfigHash, bytes32 scopeManifestHash) facts)",
  "function finalityRegistry() view returns (address)",
  "function finalityRegistryCodeHash() view returns (bytes32)",
  "function sanctionArchiveFacts(bytes32 sanctionRecordHash) view returns ((bytes32 sanctionRecordHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength))",
  "function requireArtifactCoverage(bytes32 hash, bytes32 artistId, bytes32 artifactHash) view returns ((bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) result)",
  "function schemaRegistry() view returns (address)",
  "function documentFacts(bytes32 id) view returns ((bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash) facts)",
  "function documentBytes(bytes32 id) view returns (bytes payload)",
  "function readChunk(bytes32 hash) view returns (bytes payload)",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function requireCoverage((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 id, bytes32 expectedHash) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage) result)",
  "function nativeConfiguration() view returns ((address[22] targets, bytes32[22] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 componentSourceGas, bytes32 inventoryDependencyHash))",
  "function inputManifestBytes((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)"
]);

type Reader = io.Reader;
type ReceiptReader = io.ReceiptReader;
type Plan = finality.ScopedPolicyFinalityV2Finalization;
type Batch = finality.ScopedPolicyFinalityV2GovernanceBatch;
type Prepared = finality.ScopedPolicyFinalityV2Call;
type Scope = finality.ScopedPolicyFinalityV2Scope;
export type ScopedPolicyFinalityV2CodePin = io.CodePin;
export type ScopedPolicyFinalityV2Block = io.Block;
export type ScopedPolicyFinalityV2ReceiptOptions = io.ReceiptOptions;

/** Pins require reviewed deployment/link metadata; caller-supplied hashes are trust inputs. */
export interface ScopedPolicyFinalityV2Deployment {
  readonly chainId: bigint;
  readonly core: io.CodePin;
  readonly metadata: io.CodePin;
  readonly registry: io.CodePin;
  readonly executor: io.CodePin;
  readonly roles: io.CodePin;
  readonly artist: io.CodePin;
  readonly artifactCoverage: io.CodePin;
  readonly source: ScopedPolicyGraphV2DiscoveryDeployment;
  readonly linkedDependencies: readonly io.CodePin[];
}

/** Historical reads authenticate retained local bytes, not today's source admission. */
export interface ScopedPolicyFinalityV2HistoryDeployment {
  readonly coordinates: finality.ScopedPolicyFinalityV2Coordinates;
  readonly registry: io.CodePin;
}

/** Current diagnostics execute the original linked verifier; retained history does not. */
export interface ScopedPolicyFinalityV2DiagnosticDeployment extends ScopedPolicyFinalityV2HistoryDeployment {
  readonly linkedDependencies: readonly io.CodePin[];
}

const VETO = id("ROLE_TERMINAL_FREEZE_VETO") as Hex;
const ADMIN = id("ROLE_COLLECTION_FINALITY_ADMIN") as Hex;
const MAX_GUARDIANS = 16n;
const MAX_MEMBERSHIPS = 256n;
const DAY = 86400n;
const { ZERO, ZERO_ADDRESS, coder } = io;

function copy<T>(value: T): T { return structuredClone(value); }
function registry() { return finality.scopedPolicyFinalityV2Interface("registry"); }
function executor() { return finality.scopedPolicyFinalityV2Interface("executor"); }
function coordinates(d: ScopedPolicyFinalityV2Deployment) {
  return {
    chainId: d.chainId, core: d.core.address, metadata: d.metadata.address,
    registry: d.registry.address, executor: d.executor.address, artist: d.artist.address,
    artifactCoverage: d.artifactCoverage.address
  };
}

function deployment(input: ScopedPolicyFinalityV2Deployment): ScopedPolicyFinalityV2Deployment {
  io.keys(input, ["chainId", "core", "metadata", "registry", "executor", "roles", "artist", "artifactCoverage", "source", "linkedDependencies"]);
  const s = input.source;
  io.keys(s, ["graph", "provider", "discovery", "configurationHash", "sourceConfigurationHash", "linkedDependencies"]);
  io.keys(s.graph, ["chainId", "sourceFactory", "publicationFactory", "recipeHash", "sourceFactoryDependenciesHash", "linkedDependencies"]);
  const chainId = io.uint(input.chainId);
  if (!chainId || s.graph.chainId !== chainId) throw Error("Deployment chain differs");
  return io.freeze({
    chainId, core: io.codePin(input.core), metadata: io.codePin(input.metadata),
    registry: io.codePin(input.registry), executor: io.codePin(input.executor), roles: io.codePin(input.roles),
    artist: io.codePin(input.artist), artifactCoverage: io.codePin(input.artifactCoverage),
    linkedDependencies: io.pinList(input.linkedDependencies),
    source: {
      graph: {
        chainId, sourceFactory: io.codePin(s.graph.sourceFactory), publicationFactory: io.codePin(s.graph.publicationFactory),
        recipeHash: io.hash(s.graph.recipeHash), sourceFactoryDependenciesHash: io.hash(s.graph.sourceFactoryDependenciesHash),
        linkedDependencies: io.pinList(s.graph.linkedDependencies)
      },
      provider: io.codePin(s.provider), discovery: io.codePin(s.discovery),
      configurationHash: io.hash(s.configurationHash), sourceConfigurationHash: io.hash(s.sourceConfigurationHash),
      linkedDependencies: io.pinList(s.linkedDependencies)
    }
  });
}

function read<T>(p: Reader, target: Address, method: string, args: readonly unknown[], tag: number, cap?: bigint) {
  return io.read<T>(p, target, abi, method, args, tag, undefined, cap);
}
function rows(p: Reader, target: Address, method: string, args: readonly unknown[], tag: number, cap?: bigint) {
  return io.rpc(p, target, abi, method, args, tag, undefined, cap);
}
async function capabilities(p: Reader, target: Address, wanted: readonly Hex[], tag: number) {
  for (const capability of ["0x01ffc9a7", ...wanted, "0xffffffff"] as Hex[]) {
    io.equal(await read(p, target, "supportsInterface", [capability], tag), capability !== "0xffffffff", "Original capability differs");
  }
}
function oneInterfaceId(iface: Interface): Hex {
  // Used only for source interfaces whose sole own selector is explicitly named below.
  const selectors = iface.fragments.filter(f => f.type === "function").map(f => iface.getFunction(f.format("sighash"))!.selector);
  return `0x${selectors.reduce((a, b) => a ^ BigInt(b), 0n).toString(16).padStart(8, "0")}` as Hex;
}

export interface ScopedPolicyFinalityV2Route {
  readonly deployment: ScopedPolicyFinalityV2Deployment;
  readonly observed: io.Block;
  readonly plan: Plan;
  readonly discovery: Awaited<ReturnType<typeof inspectScopedPolicyGraphV2Discovery>>;
  readonly inventory: inventory.ScopedPolicyInventoryV2Evidence;
  readonly bundle: bundle.ScopedPolicyBundleV2Evidence;
  readonly componentReadGas: bigint;
  readonly runtimePins: readonly io.CodePin[];
  readonly execution: finality.ScopedPolicyFinalityV2ExecutionContext;
  readonly actualCallAdmissionRequired: true;
}

/** Complete original current-source profile. It does not simulate an executing Executor. */
export async function inspectScopedPolicyFinalityV2Route(
  provider: Reader,
  inputDeployment: ScopedPolicyFinalityV2Deployment,
  inputPlan: Plan,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
): Promise<ScopedPolicyFinalityV2Route> {
  const d = deployment(inputDeployment);
  const plan = finality.normalizeScopedPolicyFinalityV2Finalization(inputPlan);
  const tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  io.equal(plan.coordinates, coordinates(d), "Finality plan deployment differs");
  const observed = await io.chain(provider, d.chainId, tag);
  const fixed = [d.core, d.metadata, d.registry, d.artist, d.artifactCoverage, d.executor, d.roles, ...d.linkedDependencies];
  await io.runtimes(provider, fixed, tag);
  const discovered = await inspectScopedPolicyGraphV2Discovery(provider, d.source, plan.scope, {
    blockTag: tag, includeRoutes: true, includeSanction: true
  });
  if (discovered.selection !== "scoped-policy-v2" || !discovered.routes) throw Error("Actual tagged V2 root required");
  const original = graph.normalizeScopedPolicyGraphV2NativeConfiguration(
    await read<graph.ScopedPolicyGraphV2NativeConfiguration>(provider, d.source.provider.address, "nativeConfiguration", [], tag)
  );
  const providerInterface = finality.scopedPolicyFinalityV2Interface("provider");
  const profiles = await Promise.all([0n, 1n, 2n].map(async index =>
    finality.normalizeScopedPolicyFinalityV2Profile(await io.read<finality.ScopedPolicyFinalityV2Profile>(
      provider, d.source.provider.address, providerInterface, "finalitySourceProfile", [index], tag))));
  const sourceConfiguration: finality.ScopedPolicyFinalityV2SourceConfiguration = {
    core: original.targets[0], router: original.targets[2], routerCodeHash: original.codeHashes[2],
    chainId: original.chainId, readGas: original.readGas,
    policyOutput: io.address(await io.read(provider, d.source.provider.address, providerInterface, "policyOutputManifestV2", [], tag)),
    policyOutputCodeHash: io.hash(await io.read(provider, d.source.provider.address, providerInterface, "policyOutputManifestV2CodeHash", [], tag)),
    profiles: [profiles[0]!, profiles[1]!, profiles[2]!]
  };
  const factoryBinding = await io.read<finality.ScopedPolicyFinalityV2FactoryBinding>(provider,
    d.source.provider.address, providerInterface, "scopedPolicyPublicationBinding", [], tag);
  io.equal(finality.scopedPolicyFinalityV2SourceConfigurationHash(d.source.provider.address, sourceConfiguration, factoryBinding),
    d.source.sourceConfigurationHash, "Provider source configuration commitment differs");
  const discoveryConfiguration = finality.normalizeScopedPolicyFinalityV2DiscoveryConfiguration(
    await io.read<finality.ScopedPolicyFinalityV2DiscoveryConfiguration>(provider, d.source.discovery.address,
      finality.scopedPolicyFinalityV2Interface("discovery"), "configuration", [], tag));
  io.equal([discoveryConfiguration.core, discoveryConfiguration.metadata, discoveryConfiguration.router,
    discoveryConfiguration.provider, discoveryConfiguration.membership, discoveryConfiguration.artist,
    discoveryConfiguration.finalityRegistry, discoveryConfiguration.finalityRegistryCodeHash],
  [d.core.address, d.metadata.address, original.targets[2], d.source.provider.address, original.targets[3],
    d.artist.address, d.registry.address, d.registry.codeHash], "Discovery constructor bindings differ");
  for (const [family, address] of [
    ...["METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE"]
      .map((name, i) => [name, discoveryConfiguration.routerAdapters[i]!] as const),
    ["COLLECTION_METADATA", discoveryConfiguration.metadataAdapter] as const
  ]) io.equal(plan.components.find(row => row.componentType === id(family))?.component, address,
    "Discovery original adapter differs");
  const targets = [...original.targets], hashes = [...original.codeHashes];
  for (const [role, child] of [[6, 2], [7, 1], [8, 3], [9, 4], [18, 5], [19, 6]]) {
    targets[role!] = discovered.graph.children[child!]!;
    hashes[role!] = discovered.graph.codeHashes[child!]!;
  }
  targets[10] = d.source.graph.sourceFactory.address;
  hashes[10] = d.source.graph.sourceFactory.codeHash;
  for (const [index, expected] of [[0, d.core], [1, d.metadata], [11, d.artist], [12, d.registry],
    [13, d.source.discovery], [20, d.artifactCoverage]] as const) {
    io.equal([targets[index], hashes[index]], [expected.address, expected.codeHash], "Provider fixed dependency differs");
  }
  const runtimePins = targets.map((address, i) => io.codePin({ address: address!, codeHash: hashes[i]! }));
  await io.runtimes(provider, runtimePins, tag);
  const cap = io.gas(await read<bigint>(provider, d.registry.address, "gasParameter", [
    await read<Hex>(provider, d.registry.address, "GGP_FINALITY_COMPONENT_READ_GAS_KEY", [], tag)
  ], tag));
  const joins: ReadonlyArray<readonly [Address, string, unknown]> = [
    [d.registry.address, "coreReads", d.core.address], [d.registry.address, "metadataReads", d.metadata.address],
    [d.registry.address, "sanctionReads", d.artist.address], [d.registry.address, "scopeEvidenceProvider", d.source.provider.address],
    [d.registry.address, "scopeEvidenceProviderCodeHash", d.source.provider.codeHash],
    [d.registry.address, "coreFinalityAdapter", targets[14]], [d.registry.address, "finalityDiscovery", d.source.discovery.address],
    [d.registry.address, "artifactCoverage", d.artifactCoverage.address], [d.registry.address, "governanceAuthority", d.executor.address],
    [d.registry.address, "finalityRoleRegistry", d.roles.address], [d.artist.address, "finalityRegistry", d.registry.address],
    [d.artist.address, "finalityRegistryCodeHash", d.registry.codeHash], [targets[14]!, "core", d.core.address],
    [targets[14]!, "collectionMetadata", d.metadata.address], [targets[14]!, "evidenceProvider", d.source.provider.address]
  ];
  for (const [target, method, expected] of joins) io.equal(await read(provider, target, method, [], tag, cap), expected, "Registry dependency reciprocity differs");
  for (const [kind, expected] of [["ARTWORK_FINALITY_REGISTRY", d.registry], ["COLLECTION_METADATA", d.metadata], ["ARTIST_REGISTRY", d.artist]] as const) {
    const pointer = await rows(provider, d.core.address, "getSatellitePointer", [id(kind)], tag, cap);
    io.equal(pointer.slice(0, 2), [expected.address, expected.codeHash], "Selected Registry/Metadata/Artist differs");
  }
  const coreFacts = finality.normalizeScopedPolicyFinalityV2ScopedCoreFacts(
    await read<finality.ScopedPolicyFinalityV2ScopedCoreFacts>(provider, targets[14]!, "scopedCoreFinalityFacts", [plan.scope], tag, cap)
  );
  io.equal([coreFacts.scopeExists, coreFacts.scopeType, coreFacts.collectionId, coreFacts.tokenId, coreFacts.scopeId],
    [true, plan.scope.scopeType, plan.scope.collectionId, plan.scope.tokenId, plan.scope.scopeId], "Actual Core scope facts differ");
  io.equal(finality.scopedPolicyFinalityV2ScopedCoreFactsHash(coordinates(d), plan.scope, coreFacts),
    plan.statement.coreFactsHash, "Actual Core facts hash differs");
  const routeInterface = new Interface(["function finalityStateForScope((uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope) view returns ((bool frozen,bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash,bytes32 moduleVersion,bytes32 manifestHash,bytes32 dataHash))"]);
  const componentId = oneInterfaceId(routeInterface);
  for (let i = 0; i < plan.components.length; i++) {
    const expected = plan.components[i]!;
    io.equal(discovered.routes[i], {
      componentType: expected.componentType, component: expected.component,
      interfaceId: expected.interfaceId, codeHash: expected.codeHash
    }, "Discovered component route differs");
    await capabilities(provider, expected.component, [componentId], tag);
    const state = await io.read<finality.ScopedPolicyFinalityV2ComponentState>(provider, expected.component,
      routeInterface, "finalityStateForScope", [plan.scope], tag, undefined, cap);
    io.equal(state, { frozen: true, ...expected }, "Current component facts differ");
  }
  const inv = inventory.normalizeScopedPolicyInventoryV2Evidence(await read<inventory.ScopedPolicyInventoryV2Evidence>(
    provider, targets[18]!, "requireCurrent", [plan.scope], tag, original.sourceGas
  ));
  inventory.validateScopedPolicyInventoryV2Evidence({ chainId: d.chainId, core: d.core.address, inventory: targets[18]! },
    io.hash(await read(provider, targets[18]!, "dependencyHash", [], tag)), inv);
  const coverage = bundle.normalizeScopedPolicyBundleV2Evidence(await read<bundle.ScopedPolicyBundleV2Evidence>(provider,
    targets[19]!, "requireCoverage", [plan.scope, inv.inventory.planId, inv.inventory.renderCriticalEvidenceHash], tag, original.sourceGas));
  io.equal(inv.scope, plan.scope, "Inventory scope differs");
  io.equal(coverage.scope, plan.scope, "Bundle scope differs");
  io.equal([coverage.coverage.inventoryPlan, coverage.coverage.renderCriticalEvidenceHash, coverage.coverage.itemCount],
    [inv.inventory.planId, inv.inventory.renderCriticalEvidenceHash, inv.inventory.itemCount], "Bundle inventory join differs");
  io.hash(coverage.coverage.evidenceChainHash);
  io.hash(coverage.coverage.bundleCoverageHash);
  bundle.validateScopedPolicyBundleV2Evidence({ chainId: d.chainId, core: d.core.address, bundle: targets[19]! },
    io.hash(await read(provider, targets[19]!, "dependencyHash", [], tag)), inv, coverage);
  io.equal(plan.statement.inputs, { ...inv.inventory.originals,
    renderCriticalEvidenceHash: inv.inventory.renderCriticalEvidenceHash, bundleCoverageHash: coverage.coverage.bundleCoverageHash },
  "Manifest original evidence joins differ");
  const manifestBytes = io.bytes(await read(provider, d.source.provider.address, "inputManifestBytes", [plan.scope], tag, original.sourceGas), 8192);
  io.equal(manifestBytes, plan.manifestBytes, "Current canonical manifest differs");
  io.equal(io.bytes(await read(provider, targets[5]!, "readChunk", [plan.manifest.contentHash], tag, original.readGas), 8192),
    plan.manifestBytes, "Schema Store manifest bytes differ");
  io.equal(await io.read(provider, d.registry.address, registry(), "finalityManifestBytes", [plan.manifest.contentHash], tag),
    plan.manifestBytes, "Registry staged manifest differs");
  await manifestDefinitions(provider, targets[4]!, tag, original.readGas);
  await sanctionArchive(provider, d, plan, inv.inventory.artistId, tag, cap);
  const execution = finality.normalizeScopedPolicyFinalityV2ExecutionContext(
    await io.read<finality.ScopedPolicyFinalityV2ExecutionContext>(provider, d.registry.address, registry(),
      "finalityExecutionContextWithArchive", [plan.scope, plan.components, plan.execution.finalityRecordHash, plan.manifest, plan.proof], tag,
      undefined, gasLimit)
  );
  io.equal(execution, plan.execution, "Original archived execution context differs");
  await io.unchanged(provider, observed);
  return io.freeze({ deployment: d, observed, plan, discovery: discovered, inventory: inv, bundle: coverage,
    componentReadGas: cap, runtimePins, execution, actualCallAdmissionRequired: true });
}

interface DefinitionFacts {
  readonly exists: boolean;
  readonly kind: bigint;
  readonly status: bigint;
  readonly contentHash: Hex;
  readonly totalBytes: bigint;
  readonly canonicalizationId: Hex;
  readonly chunkCount: bigint;
  readonly declarationHash: Hex;
}

async function manifestDefinitions(provider: Reader, schemas: Address, tag: number, cap: bigint) {
  const definitions = [
    [finality.SCOPED_POLICY_FINALITY_V2_SCHEMA, 0n, finality.SCOPED_POLICY_FINALITY_V2_SCHEMA_HASH, finality.SCOPED_POLICY_FINALITY_V2_SCHEMA_BYTES],
    [finality.SCOPED_POLICY_FINALITY_V2_CANONICALIZATION, 1n, finality.SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_HASH,
      finality.SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_BYTES]
  ] as const;
  for (const [key, kind, hash, length] of definitions) {
    const facts = await read<DefinitionFacts>(provider, schemas, "documentFacts", [key], tag, cap);
    io.equal([facts.exists, facts.kind, facts.status, facts.contentHash, facts.totalBytes, facts.canonicalizationId, facts.chunkCount],
      [true, kind, 0n, hash, length, id("RAW_BYTES"), 1n], "Active finality manifest definition differs");
    io.hash(facts.declarationHash);
    const raw = io.bytes(await read(provider, schemas, "documentBytes", [key], tag, cap), 8192);
    io.equal([keccak256(raw), BigInt((raw.length - 2) / 2)], [hash, length], "Finality definition bytes differ");
  }
}

interface ArchiveFacts {
  readonly sanctionRecordHash: Hex;
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
}

async function sanctionArchive(provider: Reader, d: ScopedPolicyFinalityV2Deployment, plan: Plan, artistId: Hex, tag: number, cap: bigint) {
  const facts = await read<ArchiveFacts>(provider, d.artist.address, "sanctionArchiveFacts", [plan.proof.sanctionRecordHash], tag, cap);
  io.equal([facts.sanctionRecordHash, facts.artistId, facts.schemaId, facts.canonicalizationId],
    [plan.proof.sanctionRecordHash, artistId, id("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"), id("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")],
    "Original Artist sanction archive facts differ");
  io.hash(facts.contentHash);
  if (facts.byteLength <= 0n || facts.byteLength > 13120n) throw Error("Sanction archive original byte bound exceeded");
  const covered = await read<{
    completionHash: Hex; artifactHash: Hex; artistId: Hex; schemaId: Hex; canonicalizationId: Hex;
    contentHash: Hex; byteLength: bigint; chunkCount: bigint; firstFamilyRecordHash: Hex; secondFamilyRecordHash: Hex;
  }>(provider, d.artifactCoverage.address, "requireArtifactCoverage", [plan.proof.completionHash, artistId, plan.proof.artifactHash], tag, cap);
  io.equal([covered.completionHash, covered.artifactHash, covered.artistId, covered.schemaId, covered.canonicalizationId,
    covered.contentHash, covered.byteLength, covered.chunkCount],
  [plan.proof.completionHash, plan.proof.artifactHash, artistId, facts.schemaId, facts.canonicalizationId,
    facts.contentHash, facts.byteLength, (facts.byteLength + 8191n) / 8192n], "Sanction archive coverage differs");
  io.hash(covered.firstFamilyRecordHash);
  io.hash(covered.secondFamilyRecordHash);
  if (covered.firstFamilyRecordHash === covered.secondFamilyRecordHash) throw Error("Distinct sanction archive families required");
  const schemas = io.address(await read(provider, d.artifactCoverage.address, "schemaRegistry", [], tag, cap));
  const definitions = [
    ["6529STREAM_ARTIST_SANCTION_ARCHIVE_V1", 0n, "0xd55474e8f3ce5aacaa70ca4a40aee030b39b366143118c9d27ff2547e85efb1a", 2574n],
    ["6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1", 1n, "0x4b09880c931db919d35159b9974e21dcf1583bfaa65c18e3636e8721140cc690", 1221n],
    ["6529STREAM_ARTIST_SANCTION_CEREMONY_V1", 0n, "0xd964c877b4256e4e829aa2630470b85832e4aa1e8a59da32094334550341600a", 3687n],
    ["6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1", 1n, "0x0d8a4197d8a294bd36eb4fd400c1ecc88ac8104c7091223b5436892a4797eef4", 1246n]
  ] as const;
  for (const [name, kind, expectedHash, length] of definitions) {
    const doc = await read<{ exists: boolean; specification: { name: string; kind: bigint; contentHash: Hex; totalBytes: bigint; canonicalizationId: Hex } }>(
      provider, schemas, "document", [id(name)], tag, cap);
    io.equal([doc.exists, id(doc.specification.name), doc.specification.kind, doc.specification.contentHash,
      doc.specification.totalBytes, doc.specification.canonicalizationId],
    [true, id(name), kind, expectedHash, length, id("RAW_BYTES")], "Retained sanction definition differs");
    // Definition retirement does not invalidate existing sanction interpretation.
    const raw = io.bytes(await read(provider, schemas, "documentBytes", [id(name)], tag, cap), 8192);
    io.equal([keccak256(raw), BigInt((raw.length - 2) / 2)], [expectedHash, length], "Sanction definition bytes differ");
  }
}

export interface ScopedPolicyFinalityV2GuardianObservation {
  readonly commitment: Hex;
  readonly targetScope: Hex;
  readonly scopedRole: Hex;
  readonly mutationStates: readonly (readonly [Hex, bigint])[];
  readonly holders: readonly (readonly io.CodePin[])[];
}

async function guardianObservation(
  provider: Reader, d: ScopedPolicyFinalityV2Deployment, scope: Hex, tag: number
): Promise<ScopedPolicyFinalityV2GuardianObservation> {
  const scopedRole = keccak256(coder.encode(["bytes32", "bytes32"], [VETO, scope])) as Hex;
  const roles = [VETO, scopedRole];
  const mutationStates: [Hex, bigint][] = [];
  const holders: io.CodePin[][] = [];
  io.equal(await read(provider, d.roles.address, "owner", [], tag), d.executor.address, "Role registry owner differs");
  io.equal(await read(provider, d.roles.address, "isRoleRedundant", [VETO], tag), true, "Original global veto redundancy required");
  for (const role of roles) {
    const mutation = await rows(provider, d.roles.address, "roleMutationState", [role], tag);
    mutationStates.push([io.hash(mutation[0], true), io.uint(mutation[1], 64)]);
    const count = io.uint(await read(provider, d.roles.address, "roleHolderCount", [role], tag));
    if (count > MAX_GUARDIANS) throw Error("Guardian count exceeds original bound");
    const group: io.CodePin[] = [];
    for (let i = 0n; i < count; i++) {
      const address = io.address(await read(provider, d.roles.address, "roleHolderAt", [role, i], tag));
      const code = io.bytes(await provider.getCode(address, tag), io.MAX_RUNTIME);
      // This current profile requires live original contract guardians; it does not classify EOAs.
      if (code === "0x" || code.length === 48 && code.startsWith("0xef0100")) throw Error("Guardian runtime unavailable or delegated");
      group.push({ address, codeHash: keccak256(code) as Hex });
    }
    if (new Set(group.map(p => p.address)).size !== group.length) throw Error("Duplicate guardian");
    holders.push(group);
  }
  const domain = id("6529STREAM_TERMINAL_GUARDIAN_CONFIG_V1");
  let commitment = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64"],
    [domain, d.chainId, d.executor.address, d.roles.address, d.roles.codeHash, ...mutationStates[0]!]
  )) as Hex;
  for (let j = 0; j < 2; j++) {
    if (j === 1) commitment = keccak256(coder.encode(
      ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"],
      [id("6529STREAM_TERMINAL_GUARDIAN_SCOPE_V1"), commitment, scope, scopedRole, ...mutationStates[j]!]
    )) as Hex;
    commitment = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256"],
      [id("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1"), commitment, roles[j], holders[j]!.length])) as Hex;
    for (let i = 0; i < holders[j]!.length; i++) commitment = keccak256(coder.encode(
      ["bytes32", "bytes32", "bytes32", "uint256", "address", "bytes32"],
      [id("6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1"), commitment, roles[j], i, holders[j]![i]!.address, holders[j]![i]!.codeHash]
    )) as Hex;
  }
  commitment = keccak256(coder.encode(["bytes32", "bytes32", "uint256"], [domain, commitment, 1n])) as Hex;
  const observed = await rows(provider, d.executor.address, "terminalFreezeVetoGuardianSet", [scope], tag);
  io.equal(observed.slice(0, 5), [d.roles.address, scopedRole, BigInt(holders[1]!.length), VETO, BigInt(holders[0]!.length)],
    "Original target-scope guardian set differs");
  return { commitment, targetScope: scope, scopedRole, mutationStates, holders };
}

export interface ScopedPolicyFinalityV2GovernanceObservation {
  readonly publication: Address;
  readonly catalog: readonly [Hex, Hex, bigint, bigint] | null;
  readonly root: io.CodePin | null;
  readonly governanceNonce: bigint | null;
  readonly action: finality.ScopedPolicyFinalityV2GovernanceAction;
  readonly guardian: ScopedPolicyFinalityV2GuardianObservation | null;
  readonly membershipIds: readonly Hex[];
  readonly membershipDeadlines: readonly bigint[];
  readonly usesRootCapacity: boolean | null;
  readonly adminMutation: readonly [Hex, bigint] | null;
}

function windowAt(batch: Batch, now: bigint, stage: "schedule" | "execute") {
  const w = batch.window;
  if (stage === "execute") {
    if (now < w.notBefore || now > w.expiresAfter) throw Error("Execution outside inclusive action window");
  } else if (now + 365n * DAY >= 1n << 64n || w.notBefore < now + 3n * DAY
    || w.expiresAfter - w.notBefore < 7n * DAY || w.expiresAfter > now + 365n * DAY) {
    throw Error("Original class-2 scheduling window differs");
  }
}

async function publicationPointer(provider: Reader, d: ScopedPolicyFinalityV2Deployment, batch: Batch, tag: number) {
  const pointer = io.address(await read(provider, d.executor.address, "publishedCallData", [batch.publicationKey], tag), true);
  if (pointer !== ZERO_ADDRESS) io.equal(io.bytes(await provider.getCode(pointer, tag), io.MAX_CALL + 16384),
    `0x00${coder.encode(["bytes[]"], [batch.callDatas]).slice(2)}`, "Published original calldata carrier differs");
  return pointer;
}

function matchAction(action: finality.ScopedPolicyFinalityV2GovernanceAction, batch: Batch) {
  const target = batch.calls[0]!;
  const expected = {
    actionClass: 2n, target: target.target, value: 0n, selector: target.selector,
    callHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
    notBefore: batch.window.notBefore, expiresAfter: batch.window.expiresAfter, reasonHash: batch.window.reasonHash,
    reasonURI: batch.window.reasonURI, manifestHash: batch.window.manifestHash
  };
  for (const [key, value] of Object.entries(expected)) io.equal(action[key as keyof typeof action], value, `Scheduled action ${key} differs`);
}

async function memberships(provider: Reader, d: ScopedPolicyFinalityV2Deployment, targetScope: Hex, tag: number) {
  const caps = await rows(provider, d.executor.address, "terminalFreezeLiveActionCaps", [], tag);
  const cap = io.uint(caps[0]);
  if (!cap || cap > MAX_MEMBERSHIPS) throw Error("Client terminal membership bound exceeded");
  const page = await rows(provider, d.executor.address, "terminalFreezeActionPage", [targetScope, 0n, cap], tag);
  const ids = (page[0] as readonly Hex[]).map(h => io.hash(h));
  const deadlines = (page[1] as readonly bigint[]).map(n => io.uint(n, 64));
  if (ids.length !== deadlines.length || page[2] !== BigInt(ids.length) || ids.length > Number(cap)
    || new Set(ids).size !== ids.length) throw Error("Terminal membership page differs");
  return { ids, deadlines };
}

async function governance(
  provider: Reader, d: ScopedPolicyFinalityV2Deployment, prepared: Prepared, observed: io.Block
): Promise<ScopedPolicyFinalityV2GovernanceObservation> {
  const request = prepared.request;
  if (request.kind === "stageFinalityManifest") throw Error("No Executor stage");
  const batch = request.batch, tag = observed.blockNumber;
  await io.runtimes(provider, [d.executor, ...d.linkedDependencies], tag);
  const bootstrap = await rows(provider, d.executor.address, "systemManifestBootstrapState", [], tag);
  if (bootstrap[0] !== true) throw Error("Executor bootstrap not bound");
  const publication = await publicationPointer(provider, d, batch, tag);
  const action = finality.normalizeScopedPolicyFinalityV2GovernanceAction(
    await read<finality.ScopedPolicyFinalityV2GovernanceAction>(provider, d.executor.address, "governanceAction", [batch.actionId], tag)
  );
  if (request.kind === "publishGovernanceCallData") return {
    publication, action, catalog: null, root: null, governanceNonce: null, guardian: null,
    membershipIds: [], membershipDeadlines: [], usesRootCapacity: null, adminMutation: null
  };
  if (bootstrap[1] !== true) throw Error("Client requires ordinary sealed Executor");
  const rawCatalog = await rows(provider, d.executor.address, "governanceActionPolicyState", [], tag);
  const catalog = [io.hash(rawCatalog[0]), io.hash(rawCatalog[1]), io.uint(rawCatalog[2]), io.uint(rawCatalog[3], 64)] as const;
  if (!catalog[2] || catalog[2] > 1024n) throw Error("Original catalog bound exceeded");
  const rootState = await rows(provider, d.executor.address, "governanceRootState", [], tag);
  const root = io.codePin({ address: io.address(rootState[0]), codeHash: io.hash(rootState[1]) });
  if (!io.uint(rootState[2], 64)) throw Error("Governance root revision missing");
  await io.runtime(provider, root, tag);
  io.equal(await read(provider, d.executor.address, "owner", [], tag), root.address, "Governance root owner differs");
  await io.runtime(provider, d.roles, tag);
  io.equal(await read(provider, d.executor.address, "roleRegistry", [], tag), d.roles.address, "Executor roles differ");
  const guardian = await guardianObservation(provider, d, batch.plan.execution.scopeHash, tag);
  const member = await memberships(provider, d, batch.plan.execution.scopeHash, tag);
  let governanceNonce: bigint | null = null;
  let adminMutation: readonly [Hex, bigint] | null = null;
  let usesRootCapacity: boolean | null = null;
  if (request.kind === "scheduleGovernanceBatch") {
    if (action.status !== 0n || publication === ZERO_ADDRESS) throw Error("Schedule requires unused action and retained calldata");
    governanceNonce = io.uint(await read(provider, d.executor.address, "governanceNonce", [], tag));
    io.equal(governanceNonce, batch.nonce, "Governance nonce changed");
    usesRootCapacity = io.same(prepared.caller, root.address);
    if (!usesRootCapacity && await read(provider, d.executor.address, "isProposer", [prepared.caller], tag) !== true) {
      throw Error("Actual scheduling caller lacks proposer authority");
    }
    io.equal(await read(provider, d.executor.address, "minimumDelay", [2n], tag), 3n * DAY, "Original class delay differs");
    windowAt(batch, observed.timestamp, "schedule");
  } else {
    if (action.status !== 1n) throw Error("Action is not scheduled");
    matchAction(action, batch);
    windowAt(batch, observed.timestamp, "execute");
    io.equal(await read(provider, d.executor.address, "scheduledCallData", [batch.actionId], tag), batch.callDatas, "Scheduled exact calldata differs");
    io.equal(await read(provider, d.executor.address, "scheduledCallDataPointer", [batch.actionId], tag), publication, "Scheduled pointer differs");
    if (publication === ZERO_ADDRESS) throw Error("Scheduled carrier missing");
    io.equal(await read(provider, d.executor.address, "terminalFreezeGuardianConfigCommitment", [batch.actionId], tag),
      guardian.commitment, "Scheduled guardian configuration drifted");
    io.equal(await read(provider, d.roles.address, "hasRole", [ADMIN, action.proposer], tag), true, "Stored proposer lacks finality-admin role");
    const mutation = await rows(provider, d.roles.address, "roleMutationState", [ADMIN], tag);
    adminMutation = [io.hash(mutation[0]), io.uint(mutation[1], 64)];
    if (!adminMutation[1]) throw Error("Finality role mutation revision missing");
  }
  // The catalog has no entry getter; original schedule/execute simulation authenticates its exact selected entry.
  const classifier = await rows(provider, d.executor.address, "freezeSelectorConfig", [d.registry.address, batch.calls[0]!.selector], tag);
  if (classifier[0] === true) io.equal(classifier[1], d.registry.codeHash, "Registered freeze selector runtime differs");
  return { publication, action, catalog, root, governanceNonce, guardian, membershipIds: member.ids,
    membershipDeadlines: member.deadlines, usesRootCapacity, adminMutation };
}

export interface ScopedPolicyFinalityV2WorkflowCapture {
  readonly deployment: ScopedPolicyFinalityV2Deployment;
  readonly prepared: Prepared;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly manifestStored: boolean | null;
  readonly route: ScopedPolicyFinalityV2Route | null;
  readonly governance: ScopedPolicyFinalityV2GovernanceObservation | null;
  readonly captureHash: Hex;
}

export async function captureScopedPolicyFinalityV2(
  provider: Reader,
  inputDeployment: ScopedPolicyFinalityV2Deployment,
  inputPrepared: Prepared,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
): Promise<ScopedPolicyFinalityV2WorkflowCapture> {
  const d = deployment(inputDeployment), prepared = finality.normalizeScopedPolicyFinalityV2Call(inputPrepared);
  io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  io.equal(prepared.coordinates, coordinates(d), "Call deployment differs");
  const observed = await io.chain(provider, d.chainId, tag);
  let manifestStored: boolean | null = null;
  let route: ScopedPolicyFinalityV2Route | null = null;
  let governed: ScopedPolicyFinalityV2GovernanceObservation | null = null;
  if (prepared.request.kind === "stageFinalityManifest") {
    await io.runtime(provider, d.registry, tag);
    const contentHash = keccak256(prepared.request.manifestBytes);
    manifestStored = await io.read<boolean>(provider, d.registry.address, registry(), "finalityManifestStored", [contentHash], tag);
    const retained = io.bytes(await io.read(provider, d.registry.address, registry(), "finalityManifestBytes", [contentHash], tag), 32768);
    io.equal(retained, manifestStored ? prepared.request.manifestBytes : "0x", "Manifest staging state differs");
  } else {
    if (prepared.request.kind !== "publishGovernanceCallData") {
      route = await inspectScopedPolicyFinalityV2Route(provider, d, prepared.request.batch.plan, { blockTag: tag, gasLimit });
    }
    governed = await governance(provider, d, prepared, observed);
  }
  await io.unchanged(provider, observed);
  const value = { deployment: d, prepared, observed, gasLimit, manifestStored, route, governance: governed };
  return io.freeze({ ...value, captureHash: io.fingerprint(value) });
}

function snapshot(input: ScopedPolicyFinalityV2WorkflowCapture): ScopedPolicyFinalityV2WorkflowCapture {
  const value = copy(input);
  io.keys(value, ["deployment", "prepared", "observed", "gasLimit", "manifestStored", "route", "governance", "captureHash"]);
  const { captureHash, ...rest } = value;
  io.equal(io.fingerprint(rest), io.hash(captureHash), "Capture fingerprint differs");
  const d = deployment(value.deployment), prepared = finality.normalizeScopedPolicyFinalityV2Call(value.prepared);
  io.equal(d, value.deployment);
  io.equal(prepared, value.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Captured call deployment differs");
  io.number(value.observed.blockNumber);
  io.hash(value.observed.blockHash);
  io.uint(value.observed.timestamp);
  io.gas(value.gasLimit);
  return io.freeze(value);
}

function withoutHeaders(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(withoutHeaders);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value)
    .filter(([key]) => key !== "observed" && key !== "captureHash").map(([key, v]) => [key, withoutHeaders(v)]));
  return value;
}

async function authenticate(provider: Reader, saved: ScopedPolicyFinalityV2WorkflowCapture) {
  await io.unchanged(provider, saved.observed);
  const original = await captureScopedPolicyFinalityV2(provider, saved.deployment, saved.prepared,
    { blockTag: saved.observed.blockNumber, gasLimit: saved.gasLimit });
  io.equal(original, saved, "Reviewed capture differs");
}

export async function simulateScopedPolicyFinalityV2(
  provider: Reader,
  input: ScopedPolicyFinalityV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = snapshot(input), tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await authenticate(provider, saved);
  const current = await captureScopedPolicyFinalityV2(provider, saved.deployment, saved.prepared, { blockTag: tag, gasLimit });
  if (saved.route) io.equal(withoutHeaders(current.route), withoutHeaders(saved.route), "Source changed; rebuild finality plan");
  if (saved.governance?.catalog) io.equal(current.governance?.catalog, saved.governance.catalog, "Catalog changed; recapture");
  const call = current.prepared.call;
  const raw = io.bytes(await provider.call({ ...call, from: current.prepared.caller, gasLimit, blockTag: tag }), 32768);
  const kind = current.prepared.request.kind;
  const iface = kind === "stageFinalityManifest" ? registry() : executor();
  const decoded = iface.decodeFunctionResult(kind, raw);
  io.equal(iface.encodeFunctionResult(kind, decoded), raw, "Noncanonical simulation result");
  if (kind === "stageFinalityManifest") io.equal(decoded[0], keccak256(current.prepared.request.manifestBytes), "Staged manifest return differs");
  else if (kind === "scheduleGovernanceBatch") io.equal(decoded[0], current.prepared.request.batch.actionId, "Scheduled action return differs");
  else if (kind === "publishGovernanceCallData") {
    io.address(decoded[0]);
    if (current.governance!.publication !== ZERO_ADDRESS) io.equal(decoded[0], current.governance!.publication, "Retained publication return differs");
  }
  await io.unchanged(provider, current.observed);
  return io.freeze({ capture: current, returnData: raw, gasLimit, originalCallSimulated: true as const, submitted: false as const });
}

function historyDeployment(input: ScopedPolicyFinalityV2HistoryDeployment): ScopedPolicyFinalityV2HistoryDeployment {
  io.keys(input, ["coordinates", "registry"]);
  const coordinates = finality.normalizeScopedPolicyFinalityV2Coordinates(input.coordinates);
  const registry = io.codePin(input.registry);
  io.equal(registry.address, coordinates.registry, "Historical registry differs");
  return io.freeze({ coordinates, registry });
}

export async function inspectScopedPolicyFinalityV2History(
  provider: Reader,
  inputDeployment: ScopedPolicyFinalityV2HistoryDeployment,
  inputScope: Scope,
  options: { readonly blockTag: number }
) {
  const d = historyDeployment(inputDeployment);
  const scope = finality.validateScopedPolicyFinalityV2Scope(inputScope);
  const tag = io.number(options.blockTag);
  const observed = await io.chain(provider, d.coordinates.chainId, tag);
  await io.runtime(provider, d.registry, tag);
  const record = finality.normalizeScopedPolicyFinalityV2ScopedRecord(await io.read<finality.ScopedPolicyFinalityV2ScopedRecord>(
    provider, d.registry.address, registry(), "artworkScopeFinalityRecord", [scope], tag));
  const count = io.uint(await io.read(provider, d.registry.address, registry(), "finalityComponentCountForScope", [scope], tag));
  if (count > 32n) throw Error("Historical component bound exceeded");
  const components = (await io.read<readonly finality.ScopedPolicyFinalityV2Component[]>(provider, d.registry.address, registry(),
    "finalityComponentsForScope", [scope, 0n, count], tag)).map(finality.normalizeScopedPolicyFinalityV2Component);
  if (BigInt(components.length) !== count) throw Error("Stored component count differs");
  if (!record.finalized) {
    io.equal(record, {
      finalized: false, scope: { scopeType: 0n, collectionId: 0n, tokenId: 0n, scopeId: ZERO },
      finalityRecordHash: ZERO, manifestContentHash: ZERO, manifestURIHash: ZERO, componentsHash: ZERO,
      finalityManifestURI: "", manifestPointer: ZERO_ADDRESS, finalizedAt: 0n
    }, "Noncanonical empty finality record");
    if (count !== 0n) throw Error("Empty record retains components");
    await io.unchanged(provider, observed);
    return io.freeze({ status: "empty" as const, deployment: d, observed, scope,
      record, components, currentnessChecked: false as const, transactionAuthenticated: false as const });
  }
  io.equal(record.scope, scope, "Historical full scope differs");
  if (record.finalizedAt > observed.timestamp) throw Error("Finality record is from the future");
  const manifestBytes = io.bytes(await io.read(provider, d.registry.address, registry(), "finalityManifestBytes", [record.manifestContentHash], tag), 8192);
  io.equal(await io.read(provider, d.registry.address, registry(), "finalityManifestStored", [record.manifestContentHash], tag), true);
  const authenticated = finality.authenticateScopedPolicyFinalityV2History(d.coordinates, { manifestBytes, record, components });
  const executionWitness = finality.normalizeScopedPolicyFinalityV2ExecutionWitness(
    await io.read<finality.ScopedPolicyFinalityV2ExecutionWitness>(provider, d.registry.address, registry(),
      "finalityExecutionWitness", [record.finalityRecordHash], tag));
  const archiveWitness = finality.normalizeScopedPolicyFinalityV2ArchiveWitness(
    await io.read<finality.ScopedPolicyFinalityV2ArchiveWitness>(provider, d.registry.address, registry(),
      "finalitySanctionArchiveWitness", [record.finalityRecordHash], tag));
  io.hash(executionWitness.actionId);
  io.address(executionWitness.proposer);
  io.hash(executionWitness.roleMutationHash);
  if (!executionWitness.roleRevision) throw Error("Historical finality-admin revision missing");
  for (const proofHash of Object.values(archiveWitness.proof)) io.hash(proofHash);
  io.equal(archiveWitness.evidenceHash, finality.scopedPolicyFinalityV2ArchiveEvidenceHash(d.coordinates, archiveWitness.proof),
    "Historical archive witness hash differs");
  const sanction = components.find(c => io.same(c.componentType, id("ARTIST_SANCTION")));
  if (!sanction) throw Error("Historical Artist component missing");
  io.equal([sanction.component, sanction.dataHash], [d.coordinates.artist, archiveWitness.proof.sanctionRecordHash],
    "Historical archive sanction differs");
  await io.unchanged(provider, observed);
  return io.freeze({ status: "finalized" as const, deployment: d, observed, scope, record, components,
    manifestBytes, authenticated, executionWitness, archiveWitness,
    currentnessChecked: false as const, transactionAuthenticated: false as const });
}

/** Diagnostic equality is distinct from immutable finalization and from fresh admission. */
export async function inspectScopedPolicyFinalityV2Current(
  provider: Reader,
  inputDeployment: ScopedPolicyFinalityV2DiagnosticDeployment,
  inputScope: Scope,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly range?: Readonly<{ start: bigint; limit: bigint }> }
) {
  io.keys(inputDeployment, ["coordinates", "registry", "linkedDependencies"]);
  const d = historyDeployment({ coordinates: inputDeployment.coordinates, registry: inputDeployment.registry });
  const links = io.pinList(inputDeployment.linkedDependencies);
  const scope = finality.validateScopedPolicyFinalityV2Scope(inputScope);
  const tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  const range = options.range ? { start: io.uint(options.range.start), limit: io.uint(options.range.limit) } : null;
  if (range && (!range.limit || range.limit > 32n)) throw Error("Diagnostic range bound exceeded");
  const historical = await inspectScopedPolicyFinalityV2History(provider, d, scope, { blockTag: tag });
  await io.runtimes(provider, links, tag);
  const result = await io.rpc(provider, d.registry.address, registry(), range ? "verifyArtworkScopeFinalityRange" : "verifyArtworkScopeFinality",
    range ? [scope, range.start, range.limit] : [scope], tag, undefined, gasLimit);
  io.equal(result[1], historical.status === "empty" ? ZERO : historical.record.finalityRecordHash, "Diagnostic historical record differs");
  if (!range) io.equal(result[2], historical.status === "empty" ? ZERO : historical.record.componentsHash, "Diagnostic stored components differ");
  await io.unchanged(provider, historical.observed);
  return io.freeze({ historical, range, result, matches: result[0] === true,
    scope: range ? "selected-component-range" as const : "original-current-route-diagnostic" as const,
    freshFinalizationAdmissionChecked: false as const });
}

async function pinReceipt(provider: Reader, saved: ScopedPolicyFinalityV2WorkflowCapture, tag: number) {
  const d = saved.deployment;
  await io.runtime(provider, d.registry, tag);
  if (saved.prepared.request.kind === "stageFinalityManifest") return;
  await io.runtimes(provider, [d.executor, ...d.linkedDependencies], tag);
  if (!saved.route) return;
  const currentGraph = saved.route.discovery.graph;
  const children = currentGraph.children.map((address, i) => ({ address, codeHash: currentGraph.codeHashes[i]! }));
  if (!saved.route.discovery.routes) throw Error("Captured component routes missing");
  const routes = saved.route.discovery.routes.map(row => ({ address: row.component, codeHash: row.codeHash }));
  await io.runtimes(provider, [d.roles, d.source.provider, d.source.discovery, d.source.graph.sourceFactory,
    d.source.graph.publicationFactory, ...d.source.linkedDependencies, ...d.source.graph.linkedDependencies,
    ...saved.route.runtimePins, ...children, ...routes,
    { address: currentGraph.sourceSet, codeHash: currentGraph.sourceSetCodeHash },
    ...saved.governance!.guardian!.holders.flat(), saved.governance!.root!], tag);
}

function eventCount(logs: readonly io.Log[], target: Address, iface: Interface, name: string, expected: number) {
  const values = io.events(logs, target, iface, name);
  if (values.length !== expected) throw Error(`Unexpected ${name} event count`);
  return values;
}

function membershipReceipt(
  logs: readonly io.Log[], d: ScopedPolicyFinalityV2Deployment, batch: Batch,
  before: ScopedPolicyFinalityV2GovernanceObservation, kind: "scheduleGovernanceBatch" | "executeGovernanceBatch",
  caller: Address, timestamp: bigint
) {
  const sequence = io.events(logs, d.executor.address, executor(), "TerminalFreezeActionMembershipUpdated");
  const ids = [...before.membershipIds], deadlines = [...before.membershipDeadlines];
  let cursor = 0;
  function removal(index: number, cause: bigint) {
    const row = sequence[cursor++];
    if (!row) throw Error("Missing terminal membership removal");
    const f = row.fields;
    io.equal([f.schemaVersion, f.scopeHash, f.actionId, f.present, f.mutationCause, f.vetoDeadline, f.rawIndex, f.remainingCount],
      [1n, batch.plan.execution.scopeHash, ids[index], false, cause, deadlines[index], BigInt(index), BigInt(ids.length - 1)],
      "Terminal membership removal differs");
    io.address(f.proposer);
    if (f.actionId === batch.actionId) io.equal(f.proposer, before.action.proposer, "Pruned action proposer differs");
    ids[index] = ids[ids.length - 1]!;
    deadlines[index] = deadlines[deadlines.length - 1]!;
    ids.pop(); deadlines.pop();
  }
  if (kind === "scheduleGovernanceBatch") {
    let i = 0;
    while (i < ids.length) {
      if (timestamp >= deadlines[i]!) removal(i, 2n); else i++;
    }
    const row = sequence[cursor++];
    if (!row) throw Error("Missing terminal membership append");
    io.equal(row.fields, {
      schemaVersion: 1n, scopeHash: batch.plan.execution.scopeHash, actionId: batch.actionId, proposer: caller,
      present: true, mutationCause: 1n, usesRootCapacity: before.usesRootCapacity,
      vetoDeadline: batch.window.notBefore, rawIndex: BigInt(ids.length), remainingCount: BigInt(ids.length + 1)
    }, "Terminal membership append differs");
    ids.push(batch.actionId); deadlines.push(batch.window.notBefore);
  } else {
    const index = ids.indexOf(batch.actionId);
    if (index >= 0) removal(index, 3n);
  }
  if (sequence.length !== cursor) throw Error("Extra terminal membership event");
  return { ids, deadlines, finalIndex: sequence.at(-1)?.index ?? -1 };
}

export async function reconcileScopedPolicyFinalityV2Receipt(
  provider: ReceiptReader,
  input: ScopedPolicyFinalityV2WorkflowCapture,
  transactionHash: Hex,
  inputOptions: io.ReceiptOptions
) {
  const saved = snapshot(input), options = copy(inputOptions), txHash = io.hash(transactionHash);
  const d = saved.deployment, prepared = saved.prepared;
  const transport = await io.transport(provider, { chainId: d.chainId, caller: prepared.caller,
    call: prepared.call, observed: saved.observed }, txHash, options);
  await authenticate(provider, saved);
  const tag = transport.observed.blockNumber;
  const prior = await captureScopedPolicyFinalityV2(provider, d, prepared, { blockTag: tag - 1, gasLimit: saved.gasLimit });
  io.equal(withoutHeaders(prior), withoutHeaders(saved), "Preceding-block state changed; receipt attribution refused");
  await pinReceipt(provider, prior, tag);
  const logs = transport.logs, request = prepared.request, kind = request.kind;
  let history: Awaited<ReturnType<typeof inspectScopedPolicyFinalityV2History>> | null = null;
  let action: finality.ScopedPolicyFinalityV2GovernanceAction | null = null;
  if (kind === "stageFinalityManifest") {
    const contentHash = keccak256(request.manifestBytes);
    const staged = eventCount(logs, d.registry.address, registry(), "FinalityManifestStaged", prior.manifestStored ? 0 : 1);
    if (staged.length) io.equal(staged[0]!.fields, {
      schemaVersion: 1n, manifestContentHash: contentHash, byteLength: BigInt((request.manifestBytes.length - 2) / 2), actor: prepared.caller
    }, "Staged manifest event differs");
    io.equal(await io.read(provider, d.registry.address, registry(), "finalityManifestBytes", [contentHash], tag), request.manifestBytes);
    io.equal(await io.read(provider, d.registry.address, registry(), "finalityManifestStored", [contentHash], tag), true);
  } else {
    const batch = request.batch, g = prior.governance!;
    const pointer = await publicationPointer(provider, d, batch, tag);
    if (pointer === ZERO_ADDRESS) throw Error("Mined governance publication missing");
    const published = eventCount(logs, d.executor.address, executor(), "GovernanceCallDataPublished",
      kind === "publishGovernanceCallData" && g.publication === ZERO_ADDRESS ? 1 : 0);
    if (published.length) io.equal(published[0]!.fields,
      { schemaVersion: 1n, callDataKey: batch.publicationKey, pointer, publisher: prepared.caller }, "Governance publication event differs");
    if (g.publication !== ZERO_ADDRESS) io.equal(pointer, g.publication, "Retained governance pointer changed");
    action = finality.normalizeScopedPolicyFinalityV2GovernanceAction(
      await read<finality.ScopedPolicyFinalityV2GovernanceAction>(provider, d.executor.address, "governanceAction", [batch.actionId], tag));
    const schedule = kind === "scheduleGovernanceBatch", execute = kind === "executeGovernanceBatch";
    eventCount(logs, d.executor.address, executor(), "GovernanceActionScheduled", schedule ? 1 : 0);
    eventCount(logs, d.executor.address, executor(), "GovernanceActionExecuted", execute ? 1 : 0);
    eventCount(logs, d.executor.address, executor(), "GovernanceActionPolicyValidated", schedule || execute ? 1 : 0);
    if (!schedule && !execute) io.equal(action, g.action, "Publication unexpectedly changed action");
    else {
      matchAction(action, batch);
      io.equal(action.status, schedule ? 1n : 2n, "Mined governance status differs");
      io.equal([action.proposer, action.executor, action.canceller, action.vetoer],
        [schedule ? prepared.caller : g.action.proposer, execute ? prepared.caller : ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS],
        "Mined governance actor fields differ");
      windowAt(batch, transport.observed.timestamp, schedule ? "schedule" : "execute");
      io.equal(await rows(provider, d.executor.address, "governanceActionPolicyState", [], tag), g.catalog, "Mined governance catalog differs");
      io.equal(await read(provider, d.executor.address, "scheduledCallData", [batch.actionId], tag), batch.callDatas);
      io.equal(await read(provider, d.executor.address, "scheduledCallDataPointer", [batch.actionId], tag), pointer);
      io.equal(await read(provider, d.executor.address, "terminalFreezeGuardianConfigCommitment", [batch.actionId], tag), g.guardian!.commitment);
      const expectedMemberships = membershipReceipt(logs, d, batch, g, kind, prepared.caller, transport.observed.timestamp);
      const member = await memberships(provider, d, batch.plan.execution.scopeHash, tag);
      io.equal(member, { ids: expectedMemberships.ids, deadlines: expectedMemberships.deadlines }, "Mined membership state differs");
      const common = [1n, batch.actionId, 2n, batch.calls[0]!.target, 0n, batch.calls[0]!.selector,
        batch.callsHash, batch.scopeHash, batch.oldValueHash, batch.newValueHash];
      const policy = io.one(logs, d.executor.address, executor(), "GovernanceActionPolicyValidated",
        [1n, batch.actionId, schedule ? 1n : 2n, g.catalog![0], g.catalog![1]]);
      if (schedule) {
        const scheduled = io.one(logs, d.executor.address, executor(), "GovernanceActionScheduled",
          [...common, batch.window.notBefore, batch.window.expiresAfter, batch.nonce, prepared.caller,
            batch.window.reasonHash, batch.window.reasonURI, batch.window.manifestHash]);
        const committed = io.one(logs, d.executor.address, executor(), "TerminalFreezeGuardianConfigCommitted", [1n, batch.actionId, g.guardian!.commitment]);
        if (!(expectedMemberships.finalIndex < committed.index && committed.index < scheduled.index && scheduled.index < policy.index)) {
          throw Error("Original schedule event order differs");
        }
        io.equal(await read(provider, d.executor.address, "governanceNonce", [], tag), batch.nonce + 1n, "Mined governance nonce differs");
      } else {
        eventCount(logs, d.executor.address, executor(), "TerminalFreezeGuardianConfigCommitted", 0);
        history = await inspectScopedPolicyFinalityV2History(provider, { coordinates: coordinates(d), registry: d.registry }, batch.plan.scope, { blockTag: tag });
        if (history.status !== "finalized") throw Error("Mined finality record missing");
        io.equal([history.record.finalityRecordHash, history.record.finalizedAt, history.components, history.manifestBytes],
          [batch.plan.execution.finalityRecordHash, transport.observed.timestamp, batch.plan.components, batch.plan.manifestBytes], "Mined finality history differs");
        io.equal(history.archiveWitness, { evidenceHash: finality.scopedPolicyFinalityV2ArchiveEvidenceHash(coordinates(d), batch.plan.proof), proof: batch.plan.proof });
        io.equal(history.executionWitness, { actionId: batch.actionId, proposer: g.action.proposer, reasonHash: batch.window.reasonHash,
          roleMutationHash: g.adminMutation![0], roleRevision: g.adminMutation![1] }, "Mined original execution witness differs");
        const targetEnd = targetEvents(logs, d, batch.plan, history, batch.actionId);
        const executed = io.one(logs, d.executor.address, executor(), "GovernanceActionExecuted",
          [...common, prepared.caller, batch.window.manifestHash]);
        if (!(expectedMemberships.finalIndex < targetEnd.first && targetEnd.last < executed.index && executed.index < policy.index)) {
          throw Error("Original execution event order differs");
        }
      }
    }
    if (!execute) {
      for (const name of ["ArtworkScopeFinalized", "FinalityExecutionWitnessRecorded", "FinalitySanctionArchiveWitnessRecorded"]) {
        eventCount(logs, d.registry.address, registry(), name, 0);
      }
    }
  }
  io.finish(logs, [d.registry.address, d.executor.address], transport.safeIndex);
  await io.unchanged(provider, transport.observed);
  return io.freeze({ capture: saved, observed: transport.observed, transactionHash: transport.transactionHash,
    kind, history, action, exactCallAuthenticated: true as const,
    receiptAttribution: "unchanged-preceding-block-and-exact-end-block" as const });
}

function targetEvents(
  logs: readonly io.Log[], d: ScopedPolicyFinalityV2Deployment, plan: Plan,
  history: Extract<Awaited<ReturnType<typeof inspectScopedPolicyFinalityV2History>>, { status: "finalized" }>, actionId: Hex
) {
  const r = history.record, e = history.executionWitness;
  const first = io.one(logs, d.registry.address, registry(), "ArtworkScopeFinalized",
    [1n, plan.scope.scopeType, plan.scope.collectionId, r.finalityRecordHash, plan.scope.tokenId, plan.scope.scopeId,
      r.componentsHash, r.manifestContentHash, r.finalityManifestURI]);
  const pointer = io.one(logs, d.registry.address, registry(), "FinalityManifestPointerRecorded",
    [1n, r.finalityRecordHash, d.registry.address, r.manifestContentHash]);
  const terminal = io.one(logs, d.registry.address, registry(), "ArtworkTerminalFreezeExecuted",
    [1n, finality.scopedPolicyFinalityV2ScopeKey(plan.scope), r.finalityRecordHash, d.executor.address]);
  const witness = io.one(logs, d.registry.address, registry(), "FinalityExecutionWitnessRecorded",
    [1n, r.finalityRecordHash, actionId, e.proposer, e.reasonHash, e.roleMutationHash, e.roleRevision, plan.execution.inputsHash]);
  const archive = io.one(logs, d.registry.address, registry(), "FinalitySanctionArchiveWitnessRecorded",
    [1n, r.finalityRecordHash, history.archiveWitness.evidenceHash, plan.proof.sanctionRecordHash, plan.proof.artifactHash, plan.proof.completionHash]);
  if (!(first.index < pointer.index && pointer.index < terminal.index && terminal.index < witness.index && witness.index < archive.index)) {
    throw Error("Original Registry event order differs");
  }
  return { first: first.index, last: archive.index };
}

export async function observeScopedPolicyFinalityV2Refusal(
  provider: Reader,
  input: ScopedPolicyFinalityV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = snapshot(input), tag = io.number(options.blockTag), gasLimit = io.gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Refusal observation predates capture");
  await authenticate(provider, saved);
  const observed = await io.chain(provider, saved.deployment.chainId, tag);
  const p = saved.prepared, d = saved.deployment;
  await io.runtime(provider, { address: p.call.to,
    codeHash: p.request.kind === "stageFinalityManifest" ? d.registry.codeHash : d.executor.codeHash }, tag);
  await io.runtime(provider, d.registry, tag);
  async function retained() {
    if (p.request.kind === "stageFinalityManifest") return io.read(provider, d.registry.address, registry(),
      "finalityManifestBytes", [keccak256(p.request.manifestBytes)], tag);
    return {
      action: await read(provider, d.executor.address, "governanceAction", [p.request.batch.actionId], tag),
      record: await io.read(provider, d.registry.address, registry(), "artworkScopeFinalityRecord", [p.request.batch.plan.scope], tag),
      publication: await read(provider, d.executor.address, "publishedCallData", [p.request.batch.publicationKey], tag)
    };
  }
  const before = copy(await retained());
  let failure: { code: string | null; message: string; data: Hex | null } | null = null;
  try {
    await provider.call({ ...p.call, from: p.caller, gasLimit, blockTag: tag });
  } catch (error) {
    const e = error as { code?: unknown; message?: unknown; data?: unknown };
    failure = { code: typeof e.code === "string" ? e.code : null,
      message: typeof e.message === "string" ? e.message.slice(0, 8192) : String(error).slice(0, 8192),
      data: typeof e.data === "string" && /^0x(?:[0-9a-f]{2})*$/i.test(e.data) ? io.bytes(e.data, 65536) : null };
  }
  if (!failure) throw Error("Original call did not refuse");
  const after = copy(await retained());
  io.equal(after, before, "Selected retained observations changed");
  await io.unchanged(provider, observed);
  return io.freeze({ capture: saved, observed, failure,
    outcome: failure.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    before, after, selectedRetainedStateUnchanged: true as const, nativeRollbackProven: false as const });
}
