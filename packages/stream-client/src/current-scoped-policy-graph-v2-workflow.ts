import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress as ETH_ZERO_ADDRESS,
  ZeroHash as ETH_ZERO_HASH,
  getAddress,
  id,
  isHexString,
  keccak256,
  toUtf8Bytes,
  type Provider
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { requireSafeExecution } from "./safe.js";
import * as graph from "./current-scoped-policy-graph-v2.js";

type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;

export interface ScopedPolicyGraphV2CodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

export interface ScopedPolicyGraphV2Block {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

/** Release and link metadata must authenticate these pins; supplied hashes do not prove source. */
export interface ScopedPolicyGraphV2Deployment {
  readonly chainId: bigint;
  readonly sourceFactory: ScopedPolicyGraphV2CodePin;
  readonly publicationFactory: ScopedPolicyGraphV2CodePin;
  readonly recipeHash: Hex;
  readonly sourceFactoryDependenciesHash: Hex;
  readonly linkedDependencies: readonly ScopedPolicyGraphV2CodePin[];
}

/** Local factory getters do not require former source, child, or selected-host runtimes. */
export interface ScopedPolicyGraphV2HistoryDeployment {
  readonly chainId: bigint;
  readonly publicationFactory: ScopedPolicyGraphV2CodePin;
  readonly recipeHash: Hex;
  readonly sourceFactoryDependenciesHash: Hex;
}

export interface ScopedPolicyGraphV2DiscoveryDeployment {
  readonly graph: ScopedPolicyGraphV2Deployment;
  readonly provider: ScopedPolicyGraphV2CodePin;
  readonly discovery: ScopedPolicyGraphV2CodePin;
  readonly configurationHash: Hex;
  readonly sourceConfigurationHash: Hex;
  readonly linkedDependencies: readonly ScopedPolicyGraphV2CodePin[];
}

const ZERO = ETH_ZERO_HASH as Hex;
const ZERO_ADDRESS = ETH_ZERO_ADDRESS as Address;
const coder = AbiCoder.defaultAbiCoder();
const MAX_RPC = 1_048_576;
const MAX_RUNTIME = 131_072;
const MAX_LOGS = 4096;
const MAX_CALL = 65_536;
const MAX_SOURCES = 256;

function keys(value: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || required.some(key => !Object.hasOwn(value, key))
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || ![...required, ...optional].includes(key))) {
    throw Error("Missing or unknown properties");
  }
}

function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!zero && result === ZERO_ADDRESS) throw Error("Zero address");
  return result;
}

function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!zero && value.toLowerCase() === ZERO)) throw Error("Expected bytes32");
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, maximum = MAX_RPC): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw Error("Expected bounded unsigned bigint");
  }
  return value;
}

function number(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw Error("Expected concrete block/index");
  }
  return value;
}

function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}

function stable(value: unknown): string {
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

function equal(a: unknown, b: unknown, reason = "Observed facts changed; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}

function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}

function fingerprint(value: unknown): Hex {
  return keccak256(toUtf8Bytes(stable(value))) as Hex;
}

function codePin(value: ScopedPolicyGraphV2CodePin): ScopedPolicyGraphV2CodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function pinList(value: readonly ScopedPolicyGraphV2CodePin[]): readonly ScopedPolicyGraphV2CodePin[] {
  if (!Array.isArray(value) || value.length > 256) throw Error("Linked dependency limit exceeded");
  const pins = value.map(codePin);
  if (new Set(pins.map(pin => pin.address)).size !== pins.length) throw Error("Duplicate linked dependency");
  return pins;
}

function deployment(value: ScopedPolicyGraphV2Deployment): ScopedPolicyGraphV2Deployment {
  keys(value, ["chainId", "sourceFactory", "publicationFactory", "recipeHash", "sourceFactoryDependenciesHash", "linkedDependencies"]);
  const chainId = uint(value.chainId);
  if (chainId === 0n) throw Error("Zero chain ID");
  return freeze({ chainId, sourceFactory: codePin(value.sourceFactory), publicationFactory: codePin(value.publicationFactory),
    recipeHash: hash(value.recipeHash), sourceFactoryDependenciesHash: hash(value.sourceFactoryDependenciesHash),
    linkedDependencies: pinList(value.linkedDependencies) });
}

function coordinates(d: ScopedPolicyGraphV2Deployment): graph.ScopedPolicyGraphV2Coordinates {
  return { chainId: d.chainId, sourceFactory: d.sourceFactory.address, publicationFactory: d.publicationFactory.address };
}

async function header(provider: Reader, tag: number): Promise<ScopedPolicyGraphV2Block> {
  const value = await provider.getBlock(number(tag));
  if (!value || value.number !== tag) throw Error("Missing or mismatched block");
  return { blockNumber: tag, blockHash: hash(value.hash), timestamp: BigInt(number(value.timestamp)) };
}

async function unchanged(provider: Reader, block: ScopedPolicyGraphV2Block): Promise<void> {
  equal(await header(provider, block.blockNumber), block, "Pinned block changed");
}

async function runtime(provider: Reader, pin: ScopedPolicyGraphV2CodePin, tag: number): Promise<void> {
  const raw = bytes(await provider.getCode(pin.address, tag), MAX_RUNTIME);
  if (raw === "0x" || (raw.length === 48 && raw.startsWith("0xef0100"))
    || !same(keccak256(raw), pin.codeHash)) throw Error("Pinned runtime differs");
}

function plain(param: ParamType, value: unknown): unknown {
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

async function rpc(provider: Reader, target: Address, iface: Interface, method: string,
  args: readonly unknown[], tag: number, from?: Address, gasLimit?: bigint): Promise<readonly unknown[]> {
  const data = iface.encodeFunctionData(method, args);
  const result = bytes(await provider.call({ to: target, data, blockTag: tag, ...(from ? { from } : {}),
    ...(gasLimit ? { gasLimit } : {}) }));
  const decoded = iface.decodeFunctionResult(method, result);
  if (!same(iface.encodeFunctionResult(method, decoded), result)) throw Error("Noncanonical RPC result");
  return iface.getFunction(method)!.outputs.map((param, index) => plain(param, decoded[index]));
}

const abi = new Interface([
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function factory() view returns (address)",
  "function sourceCount() view returns (uint256)",
  "function sourceScope() view returns ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId))",
  "function scopeMembershipFacts() view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function sourcePolicyAt(uint256 index) view returns ((address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy))",
  "function inventoryPlan() view returns (bytes32)",
  "function originalInventoryHash() view returns (bytes32)",
  "function originalPolicyChainHash() view returns (bytes32)",
  "function tokenInventory() view returns (address)",
  "function tokenInventoryCodeHash() view returns (bytes32)",
  "function sourceSetDataHash() view returns (bytes32)",
  "function sourceSetManifestHash() view returns (bytes32)",
  "function requireCurrentSourceSet() view",
  "function requireCurrentSelection() view",
  "function metadataHost() view returns (address)",
  "function requireScopeMembership((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function requireCompleteInventory(bytes32 id) view returns ((bool exists, bool complete, uint256 processedTokens, uint256 tokenCount, uint256 coordinatorCount, bytes32 tokenChain, bytes32 coordinatorChain, bytes32 commitment))",
  "function inventoryScope(bytes32 id) view returns ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId), (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function requireCoordinator(bytes32 id, uint256 index) view returns ((address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex) c)",
  "function scopeMembershipHost() view returns (address)",
  "function deploymentChainId() view returns (uint256)",
  "function scopeMembershipCodeHash() view returns (bytes32)",
  "function streamModuleType() pure returns (bytes32)",
  "function streamModuleInterfaceId() pure returns (bytes4)",
  "function streamModuleCodeHash() view returns (bytes32)",
  "function streamModuleVersion() pure returns (bytes32)",
  "function streamModuleManifest() view returns (string uri, bytes32 hash)",
  "function streamModuleSchemaHash() view returns (bytes32)",
  "function streamModuleDeploymentManifestHash() view returns (bytes32)",
  "function entropyPolicyFrozen(uint256 collectionId) view returns (bool frozen, bytes32 policyManifestHash, address provider, uint32 providerEpoch, bytes32 collectionSaltCommitment)",
  "function collectionEntropyPolicy(uint256) view returns ((bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord))",
  "function schemaRegistry() view returns (address)",
  "function chunkStore() view returns (address)",
  "function governanceAuthority() view returns (address)",
  "function executorCodeHash() view returns (bytes32)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function isModuleEligible(address module, bytes32 expectedModuleType, bytes4 expectedInterfaceId) view returns (bool)",
  "function metadataRouter() view returns (address)",
  "function scopeMembership() view returns (address)",
  "function dependencyHash() view returns (bytes32)",
  "function nativeConfiguration() view returns ((address[22] targets, bytes32[22] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 componentSourceGas, bytes32 inventoryDependencyHash))",
  "function scopedPolicyPublicationBinding() view returns ((address factory, bytes32 factoryCodeHash, bytes32 recipeHash, bytes32 sourceFactoryDependenciesHash, uint256 graphGas, bytes32 configurationHash))",
  "function finalitySourceConfigurationHash() view returns (bytes32)",
  "function scopedPolicySnapshotHost((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (address)",
  "function scopedPolicySnapshotCodeHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function scopedPolicySnapshotProfile() pure returns (bytes32)",
  "function scopedPolicySnapshotValidationGas((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function finalitySourcesForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 profileHash, address referenceRender, bytes32 referenceRenderCodeHash, address snapshots, bytes32 snapshotsCodeHash, address entropyFactory, bytes32 entropyFactoryCodeHash, bytes32 configurationHash) profile))",
  "function scopeEvidenceProvider() view returns (address)",
  "function sourceConfigurationHash() view returns (bytes32)",
  "function configuration() view returns ((address core, address metadata, address router, address provider, address membership, address entropyFactory, address metadataAdapter, address referenceRender, address artist, address finalityRegistry, bytes32 finalityRegistryCodeHash, address[6] routerAdapters, uint32 readGas, uint32 componentGas, uint32 entropyGas))",
  "function dependencyCodeHash(address target) view returns (bytes32)",
  "function requireCurrentRoutes((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bool includeSanction) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash)[] routes)",
  "function scopedPolicyContentRootBinding(bytes32 recordHash) view returns ((bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash))",
  "function scopedContentRootHead((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)) view returns (bytes32)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)"
]);

const sourceAbi = graph.scopedPolicyGraphV2SourceFactoryInterface();
const factoryAbi = graph.scopedPolicyGraphV2PublicationFactoryInterface();

async function read(provider: Reader, target: Address, method: string, args: readonly unknown[], tag: number): Promise<unknown> {
  return (await rpc(provider, target, abi, method, args, tag))[0];
}

async function supports(provider: Reader, target: Address, capability: Hex, tag: number): Promise<void> {
  if (await read(provider, target, "supportsInterface", [capability], tag) !== true
    || await read(provider, target, "supportsInterface", ["0x01ffc9a7"], tag) !== true
    || await read(provider, target, "supportsInterface", ["0xffffffff"], tag) !== false) {
    throw Error("Required original interface is unavailable");
  }
}

async function localRecipe(provider: Reader, d: ScopedPolicyGraphV2HistoryDeployment, tag: number) {
  await runtime(provider, d.publicationFactory, tag);
  const target = d.publicationFactory.address;
  await supports(provider, target, "0x519750f2", tag);
  const recipe = graph.validateScopedPolicyGraphV2Recipe(d.chainId,
    (await rpc(provider, target, factoryAbi, "recipe", [], tag))[0] as graph.ScopedPolicyGraphV2Recipe
  );
  const recipeHash = graph.scopedPolicyGraphV2RecipeHash(d.chainId, recipe);
  if (!same(recipeHash, d.recipeHash)
    || !same((await rpc(provider, target, factoryAbi, "recipeHash", [], tag))[0], recipeHash)
    || !same((await rpc(provider, target, factoryAbi, "sourceFactoryDependenciesHash", [], tag))[0], d.sourceFactoryDependenciesHash)
    || !same((await rpc(provider, target, factoryAbi, "scopedPolicyPublicationFactoryProfile", [], tag))[0], graph.SCOPED_POLICY_GRAPH_V2_PROFILE)
    || !same((await rpc(provider, target, factoryAbi, "core", [], tag))[0], recipe.inventory.targets[0])
    || !same((await rpc(provider, target, factoryAbi, "metadataHost", [], tag))[0], recipe.inventory.targets[1])
    || !same((await rpc(provider, target, factoryAbi, "entropySourceFactory", [], tag))[0], recipe.targets[2])) {
    throw Error("Publication factory recipe binding differs");
  }
  return recipe;
}

async function sourceDependencies(provider: Reader, d: ScopedPolicyGraphV2Deployment,
  recipe: graph.ScopedPolicyGraphV2Recipe, tag: number) {
  await runtime(provider, d.sourceFactory, tag);
  const target = d.sourceFactory.address;
  await supports(provider, target, "0x744da5f2", tag);
  const result = graph.normalizeScopedPolicyGraphV2SourceDependencies(
    (await rpc(provider, target, sourceAbi, "dependencies", [], tag))[0] as graph.ScopedPolicyGraphV2SourceDependencies
  );
  if (result.chainId !== d.chainId || result.readGas < 50000n || result.inventoryGas < result.readGas
    || !same(graph.scopedPolicyGraphV2DependenciesHash(result), d.sourceFactoryDependenciesHash)
    || !same(target, recipe.targets[2]) || !same(d.sourceFactory.codeHash, recipe.codeHashes[2])
    || !same(result.targets[0], recipe.inventory.targets[0]) || !same(result.codeHashes[0], recipe.inventory.codeHashes[0])
    || !same(result.targets[1], recipe.inventory.targets[1]) || !same(result.codeHashes[1], recipe.inventory.codeHashes[1])
    || !same(result.targets[2], recipe.targets[0]) || !same(result.codeHashes[2], recipe.codeHashes[0])
    || !same((await rpc(provider, target, sourceAbi, "scopedPolicyFactoryProfile", [], tag))[0], graph.SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_PROFILE)) {
    throw Error("Source factory dependencies differ");
  }
  for (let i = 0; i < 4; i++) {
    await runtime(provider, { address: result.targets[i]!, codeHash: result.codeHashes[i]! }, tag);
    if (i > 0 && !same(await read(provider, result.targets[i]!, "core", [], tag), result.targets[0])) {
      throw Error("Source dependency Core differs");
    }
  }
  await supports(provider, result.targets[0], "0x80ac58cd", tag);
  await supports(provider, result.targets[2], "0x7a3872e0", tag);
  await supports(provider, result.targets[3], "0xf7b5691a", tag);
  for (const [method, expected] of [
    ["core", result.targets[0]], ["metadataHost", result.targets[1]],
    ["scopeMembershipHost", result.targets[2]], ["coordinatorInventory", result.targets[3]]
  ] as const) {
    if (!same((await rpc(provider, target, sourceAbi, method, [], tag))[0], expected)) {
      throw Error("Source factory immutable getter differs");
    }
  }
  if (!same(await read(provider, result.targets[2], "metadataHost", [], tag), result.targets[1])
    || !same(await read(provider, result.targets[3], "scopeMembershipHost", [], tag), result.targets[2])
    || !same(await read(provider, result.targets[3], "coreCodeHash", [], tag), result.codeHashes[0])
    || !same(await read(provider, result.targets[3], "scopeMembershipCodeHash", [], tag), result.codeHashes[2])
    || await read(provider, result.targets[3], "deploymentChainId", [], tag) !== d.chainId) {
    throw Error("Source inventory reciprocity differs");
  }
  return result;
}

async function coordinatorPolicy(provider: Reader, d: graph.ScopedPolicyGraphV2SourceDependencies,
  scope: graph.ScopedPolicyGraphV2Scope, original: graph.ScopedPolicyGraphV2Coordinator, tag: number) {
  const target = original.coordinator;
  await runtime(provider, { address: target, codeHash: original.indexedCodeHash }, tag);
  for (const capability of ["0x979b977f", "0x16ac15a2", "0x1f04274a"] as const) {
    await supports(provider, target, capability, tag);
  }
  if (!same(await read(provider, target, "core", [], tag), d.targets[0])
    || !same(await read(provider, target, "streamModuleType", [], tag), id("ENTROPY_COORDINATOR"))
    || !same(await read(provider, target, "streamModuleInterfaceId", [], tag), "0x979b977f")
    || !same(await read(provider, target, "streamModuleCodeHash", [], tag), original.indexedCodeHash)) {
    throw Error("Original Coordinator identity differs");
  }
  const manifest = await rpc(provider, target, abi, "streamModuleManifest", [], tag);
  const moduleVersion = hash(await read(provider, target, "streamModuleVersion", [], tag));
  const moduleManifestHash = hash(manifest[1]);
  const moduleSchemaHash = hash(await read(provider, target, "streamModuleSchemaHash", [], tag));
  const deploymentManifestHash = hash(await read(provider, target, "streamModuleDeploymentManifestHash", [], tag));
  // Original StreamEntropyPolicyConsumerTypes.CAPABILITY, distinct from the getter selector.
  const hasExplicit = await read(provider, target, "supportsInterface", ["0x4583f7e1"], tag);
  let collectionPolicy = graph.scopedPolicyGraphV2EmptyPolicy();
  if (hasExplicit === true) {
    collectionPolicy = graph.normalizeScopedPolicyGraphV2Policy(
      await read(provider, target, "collectionEntropyPolicy", [scope.collectionId], tag) as graph.ScopedPolicyGraphV2Policy
    );
  } else if (hasExplicit !== false) throw Error("Malformed policy capability");
  const legacy = await rpc(provider, target, abi, "entropyPolicyFrozen", [scope.collectionId], tag);
  const explicitPolicy = collectionPolicy.explicitPolicy;
  let frozen: boolean;
  let policyHash: Hex;
  let legacyProvider = ZERO_ADDRESS;
  let epoch = 0n;
  let salt = ZERO;
  let componentDataHash: Hex;
  if (explicitPolicy) {
    equal(legacy, [false, ZERO, ZERO_ADDRESS, 0n, ZERO], "Explicit policy must retain unavailable legacy evidence");
    frozen = collectionPolicy.frozen;
    policyHash = collectionPolicy.policyHash;
    componentDataHash = keccak256(coder.encode(
      ["bytes32", "uint256", "address", "address", graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, graph.SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE],
      [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2"), d.chainId, d.targets[0], target, scope, collectionPolicy]
    )) as Hex;
  } else {
    if (typeof legacy[0] !== "boolean") throw Error("Malformed frozen policy");
    frozen = legacy[0];
    policyHash = hash(legacy[1]);
    legacyProvider = address(legacy[2]);
    epoch = uint(legacy[3], 32);
    salt = hash(legacy[4]);
    collectionPolicy = graph.scopedPolicyGraphV2EmptyPolicy();
    componentDataHash = keccak256(coder.encode(
      ["bytes32", "uint256", "address", "address", graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "address", "uint32", "bytes32"],
      [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"), d.chainId, d.targets[0], target, scope, policyHash, legacyProvider, epoch, salt]
    )) as Hex;
  }
  const policy = graph.normalizeScopedPolicyGraphV2CoordinatorPolicy({ ...original, frozen, moduleVersion, moduleManifestHash,
    moduleSchemaHash, deploymentManifestHash, policyHash, provider: legacyProvider, epoch, salt, componentDataHash,
    explicitPolicy, collectionPolicy });
  graph.validateScopedPolicyGraphV2CoordinatorPolicy(d.chainId, d.targets[0], scope, policy);
  if (!policy.frozen) throw Error("Every original policy must be frozen");
  return policy;
}

async function inventory(provider: Reader, d: ScopedPolicyGraphV2Deployment,
  dependencies: graph.ScopedPolicyGraphV2SourceDependencies, scope: graph.ScopedPolicyGraphV2Scope, tag: number) {
  const membership = graph.normalizeScopedPolicyGraphV2Membership(
    await read(provider, dependencies.targets[2], "requireScopeMembership", [scope], tag) as graph.ScopedPolicyGraphV2Membership
  );
  const plan = graph.scopedPolicyGraphV2InventoryPlan(dependencies, scope, membership);
  if (!same((await rpc(provider, d.sourceFactory.address, sourceAbi, "currentInventoryPlan", [scope], tag))[0], plan)) {
    throw Error("Current inventory plan differs");
  }
  const progress = graph.normalizeScopedPolicyGraphV2InventoryProgress(
    await read(provider, dependencies.targets[3], "requireCompleteInventory", [plan], tag) as graph.ScopedPolicyGraphV2InventoryProgress
  );
  const saved = await rpc(provider, dependencies.targets[3], abi, "inventoryScope", [plan], tag);
  equal(saved, [scope, membership], "Inventory saved scope/membership differs");
  if (!progress.exists || !progress.complete || progress.processedTokens !== progress.tokenCount
    || progress.tokenCount !== membership.tokenCount || progress.coordinatorCount === 0n
    || progress.coordinatorCount > progress.tokenCount || progress.coordinatorCount > BigInt(MAX_SOURCES)
    || !same(progress.commitment, graph.scopedPolicyGraphV2InventoryCommitment(plan, progress))) {
    throw Error("Complete nonempty bounded inventory required");
  }
  const originals: graph.ScopedPolicyGraphV2Coordinator[] = [];
  const policies: graph.ScopedPolicyGraphV2CoordinatorPolicy[] = [];
  for (let i = 0n; i < progress.coordinatorCount; i++) {
    const original = graph.normalizeScopedPolicyGraphV2Coordinator(
      await read(provider, dependencies.targets[3], "requireCoordinator", [plan, i], tag) as graph.ScopedPolicyGraphV2Coordinator
    );
    if (original.firstTokenIndex >= progress.tokenCount
      || (i === 0n ? original.firstTokenIndex !== 0n : original.firstTokenIndex <= originals[Number(i) - 1]!.firstTokenIndex)
      || originals.some(row => same(row.coordinator, original.coordinator))) throw Error("Original Coordinator order differs");
    originals.push(original);
    policies.push(await coordinatorPolicy(provider, dependencies, scope, original, tag));
  }
  if (!same(graph.scopedPolicyGraphV2CoordinatorChain(plan, originals), progress.coordinatorChain)) {
    throw Error("Complete Coordinator chain differs");
  }
  const policyChainHash = graph.scopedPolicyGraphV2PolicyChain(dependencies, scope, plan, progress.commitment, policies);
  const tokenInventory = address(await read(provider, dependencies.targets[2], "tokenInventory", [], tag));
  const tokenRuntime = bytes(await provider.getCode(tokenInventory, tag), MAX_RUNTIME);
  const tokenInventoryCodeHash = keccak256(tokenRuntime) as Hex;
  await runtime(provider, { address: tokenInventory, codeHash: tokenInventoryCodeHash }, tag);
  if (!same(await read(provider, tokenInventory, "core", [], tag), dependencies.targets[0])) throw Error("Token inventory Core differs");
  const sourceSetDataHash = graph.scopedPolicyGraphV2SourceSetDataHash(scope, plan, progress.commitment, policyChainHash,
    membership, tokenInventory, tokenInventoryCodeHash);
  const sourceSetManifestHash = graph.scopedPolicyGraphV2SourceSetManifestHash(dependencies, tokenInventory, tokenInventoryCodeHash);
  return freeze({ membership, plan, progress, policies, policyChainHash, tokenInventory, tokenInventoryCodeHash,
    sourceSetDataHash, sourceSetManifestHash });
}

type Inventory = Readonly<Omit<Awaited<ReturnType<typeof inventory>>, "policies"> & {
  readonly policies: readonly graph.ScopedPolicyGraphV2CoordinatorPolicy[];
}>;

async function sourceSet(provider: Reader, d: ScopedPolicyGraphV2Deployment,
  dependencies: graph.ScopedPolicyGraphV2SourceDependencies, scope: graph.ScopedPolicyGraphV2Scope, facts: Inventory,
  tag: number, currentRoute: boolean): Promise<ScopedPolicyGraphV2CodePin | null> {
  const pair = await rpc(provider, d.sourceFactory.address, sourceAbi, "sourceSetForPlan", [facts.plan], tag);
  const target = address(pair[0], true);
  const codeHash = hash(pair[1], true);
  if (target === ZERO_ADDRESS) {
    if (codeHash !== ZERO || currentRoute) throw Error("Current source set is missing");
    return null;
  }
  const pin = codePin({ address: target, codeHash });
  await runtime(provider, pin, tag);
  const expected: ReadonlyArray<readonly [string, unknown]> = [
    ["factory", d.sourceFactory.address], ["core", dependencies.targets[0]], ["coreCodeHash", dependencies.codeHashes[0]],
    ["inventoryPlan", facts.plan], ["originalInventoryHash", facts.progress.commitment], ["originalPolicyChainHash", facts.policyChainHash],
    ["tokenInventory", facts.tokenInventory], ["tokenInventoryCodeHash", facts.tokenInventoryCodeHash],
    ["sourceSetDataHash", facts.sourceSetDataHash], ["sourceSetManifestHash", facts.sourceSetManifestHash],
    ["sourceScope", scope], ["scopeMembershipFacts", facts.membership], ["sourceCount", BigInt(facts.policies.length)]
  ];
  for (const [method, value] of expected) equal(await read(provider, target, method, [], tag), value, "Source set retained evidence differs");
  for (let i = 0; i < facts.policies.length; i++) {
    equal(await read(provider, target, "sourcePolicyAt", [i], tag), facts.policies[i], "Source set policy order differs");
  }
  await rpc(provider, target, abi, "requireCurrentSourceSet", [], tag);
  if (currentRoute) {
    const route = (await rpc(provider, d.sourceFactory.address, sourceAbi, "requireCurrentRoute", [scope], tag))[0] as graph.ScopedPolicyGraphV2CurrentRoute;
    if (!same(route.component, target) || !same(route.codeHash, codeHash)
      || !same(route.interfaceId, "0x8004d4f5")
      || !same(route.componentType, id("ENTROPY_COORDINATOR"))) throw Error("Source current route differs");
  }
  return freeze(pin);
}

async function selectedHost(provider: Reader, core: Address, pin: ScopedPolicyGraphV2CodePin,
  kind: Hex, capability: Hex, tag: number) {
  const pointer = await rpc(provider, core, abi, "getSatellitePointer", [kind], tag);
  if (!same(pointer[0], pin.address) || !same(pointer[1], pin.codeHash) || !same(pointer[3], kind)
    || !same(pointer[4], capability) || (pointer[6] !== 1n && pointer[6] !== 2n)
    || hash(pointer[7]) === ZERO || hash(pointer[8]) === ZERO || uint(pointer[9], 64) === 0n) {
    throw Error("Actual selected host differs");
  }
  const registry = address(pointer[5]);
  const registryPointer = await rpc(provider, core, abi, "getSatellitePointer", [id("MODULE_REGISTRY")], tag);
  if (!same(registryPointer[0], registry)) throw Error("Selected ModuleRegistry differs");
  await runtime(provider, { address: registry, codeHash: hash(registryPointer[1]) }, tag);
  await supports(provider, pin.address, capability, tag);
  if (!same(await read(provider, pin.address, "streamModuleType", [], tag), kind)
    || !same(await read(provider, pin.address, "streamModuleInterfaceId", [], tag), capability)
    || await read(provider, registry, "isModuleEligible", [pin.address, kind, capability], tag) !== true) {
    throw Error("Selected host is not currently eligible");
  }
  return pointer;
}

async function operativeRecipe(provider: Reader, recipe: graph.ScopedPolicyGraphV2Recipe, tag: number) {
  for (let i = 0; i < 4; i++) await runtime(provider, { address: recipe.targets[i]!, codeHash: recipe.codeHashes[i]! }, tag);
  for (let i = 0; i < 12; i++) {
    if (i !== 5 && i !== 6) await runtime(provider, {
      address: recipe.inventory.targets[i]!, codeHash: recipe.inventory.codeHashes[i]!
    }, tag);
  }
  for (let i = 0; i < 5; i++) await runtime(provider, {
    address: recipe.inventory.artistTargets[i]!, codeHash: recipe.inventory.artistCodeHashes[i]!
  }, tag);
  await runtime(provider, { address: recipe.inventory.artistContentOwner, codeHash: recipe.inventory.artistContentOwnerCodeHash }, tag);
  const d = recipe.inventory;
  const metadata = await selectedHost(provider, d.targets[0], { address: d.targets[1], codeHash: d.codeHashes[1] },
    id("COLLECTION_METADATA") as Hex, "0x7e8260f8", tag);
  const router = await selectedHost(provider, d.targets[0], { address: d.targets[4], codeHash: d.codeHashes[4] },
    id("METADATA_ROUTER") as Hex, "0x222d4427", tag);
  const joins: ReadonlyArray<readonly [Address, string, unknown]> = [
    [d.targets[1], "core", d.targets[0]], [d.targets[1], "schemaRegistry", d.targets[2]],
    [d.targets[1], "chunkStore", d.targets[3]], [d.targets[1], "governanceAuthority", recipe.targets[3]],
    [d.targets[1], "executorCodeHash", recipe.codeHashes[3]], [d.targets[4], "core", d.targets[0]],
    [recipe.targets[0], "core", d.targets[0]], [recipe.targets[0], "metadataHost", d.targets[1]],
    [recipe.targets[1], "core", d.targets[0]], [recipe.targets[1], "metadataHost", d.targets[1]],
    [recipe.targets[1], "metadataRouter", d.targets[4]], [recipe.targets[1], "scopeMembership", recipe.targets[0]]
  ];
  for (const [target, method, expected] of joins) equal(await read(provider, target, method, [], tag), expected, "Recipe reciprocity differs");
  return freeze({ metadata, router });
}

const snapshotAbi = new Interface([`function dependencies() view returns (${graph.SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE})`]);
const referenceAbi = new Interface([`function dependencies() view returns (${graph.SCOPED_POLICY_GRAPH_V2_REFERENCE_DEPENDENCIES_TUPLE})`]);

async function children(provider: Reader, recipe: graph.ScopedPolicyGraphV2Recipe, g: graph.ScopedPolicyGraphV2Graph, tag: number) {
  for (let i = 0; i < Number(g.preparedChildren); i++) {
    await runtime(provider, { address: g.children[i]!, codeHash: g.codeHashes[i]! }, tag);
  }
  let snapshot: graph.ScopedPolicyGraphV2SnapshotDependencies | null = null;
  let reference: graph.ScopedPolicyGraphV2ReferenceDependencies | null = null;
  if (g.preparedChildren > 3n) {
    snapshot = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(
      (await rpc(provider, g.children[3], snapshotAbi, "dependencies", [], tag))[0] as graph.ScopedPolicyGraphV2SnapshotDependencies
    );
    const expected = graph.scopedPolicyGraphV2SnapshotDependencies(recipe, g);
    if (snapshot.readGas < expected.readGas || snapshot.sourceGas < expected.sourceGas || snapshot.inventoryGas < expected.inventoryGas) {
      throw Error("Snapshot gas was lowered");
    }
    equal({ ...snapshot, readGas: expected.readGas, sourceGas: expected.sourceGas, inventoryGas: expected.inventoryGas }, expected,
      "Snapshot fixed dependencies differ");
  }
  if (g.preparedChildren > 4n) {
    reference = graph.normalizeScopedPolicyGraphV2ReferenceDependencies(
      (await rpc(provider, g.children[4], referenceAbi, "dependencies", [], tag))[0] as graph.ScopedPolicyGraphV2ReferenceDependencies
    );
    const expected = graph.scopedPolicyGraphV2ReferenceDependencies(recipe, g);
    if (reference.readGas < expected.readGas || reference.sourceGas < expected.sourceGas
      || reference.snapshotGas < expected.snapshotGas || reference.archiveGas < expected.archiveGas) throw Error("Reference gas was lowered");
    equal({ ...reference, readGas: expected.readGas, sourceGas: expected.sourceGas,
      snapshotGas: expected.snapshotGas, archiveGas: expected.archiveGas }, expected, "Reference fixed dependencies differ");
  }
  if (g.preparedChildren > 5n) {
    equal(await read(provider, g.children[5], "dependencyHash", [], tag),
      keccak256(coder.encode([graph.SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE], [graph.scopedPolicyGraphV2InventoryDependencies(recipe, g)])),
      "Inventory child dependency hash differs");
  }
  if (g.preparedChildren > 6n) {
    equal(await read(provider, g.children[6], "dependencyHash", [], tag),
      keccak256(coder.encode([graph.SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE], [graph.scopedPolicyGraphV2BundleDependencies(recipe, g)])),
      "Bundle child dependency hash differs");
  }
  return freeze({ snapshot, reference });
}

export interface ScopedPolicyGraphV2Capture {
  readonly deployment: ScopedPolicyGraphV2Deployment;
  readonly prepared: graph.ScopedPolicyGraphV2Call;
  readonly observed: ScopedPolicyGraphV2Block;
  readonly recipe: graph.ScopedPolicyGraphV2Recipe;
  readonly sourceDependencies: graph.ScopedPolicyGraphV2SourceDependencies;
  readonly inventory: Inventory;
  readonly sourceSet: ScopedPolicyGraphV2CodePin | null;
  readonly graph: graph.ScopedPolicyGraphV2Graph;
  readonly selectedHosts: Awaited<ReturnType<typeof operativeRecipe>> | null;
  readonly childDependencies: Awaited<ReturnType<typeof children>>;
  readonly captureHash: Hex;
}

/** Source preparation intentionally has no selected Metadata/Router admission gate. */
export async function captureScopedPolicyGraphV2(provider: Reader, inputDeployment: ScopedPolicyGraphV2Deployment,
  caller: Address, request: graph.ScopedPolicyGraphV2Request, options: { readonly blockTag: number }): Promise<ScopedPolicyGraphV2Capture> {
  const d = deployment(inputDeployment);
  const prepared = graph.prepareScopedPolicyGraphV2Call(coordinates(d), caller, request);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("Chain differs");
  const observed = await header(provider, tag);
  for (const pin of d.linkedDependencies) await runtime(provider, pin, tag);
  const recipe = await localRecipe(provider, d, tag);
  const dependencies = await sourceDependencies(provider, d, recipe, tag);
  const scope = prepared.request.scope;
  const facts = await inventory(provider, d, dependencies, scope, tag);
  const isGraph = prepared.request.kind === "prepareGraph";
  const set = await sourceSet(provider, d, dependencies, scope, facts, tag, isGraph);
  const saved = graph.normalizeScopedPolicyGraphV2Graph(
    (await rpc(provider, d.publicationFactory.address, factoryAbi, "graphForPlan", [facts.plan], tag))[0] as graph.ScopedPolicyGraphV2Graph
  );
  graph.validateScopedPolicyGraphV2Graph(coordinates(d), recipe, dependencies, saved, { expectedPlan: facts.plan, expectedScope: scope });
  if (saved.graphId !== ZERO && (!set || !same(saved.sourceSet, set.address) || !same(saved.sourceSetCodeHash, set.codeHash))) {
    throw Error("Saved graph source differs");
  }
  const selectedHosts = isGraph ? await operativeRecipe(provider, recipe, tag) : null;
  const childDependencies = isGraph ? await children(provider, recipe, saved, tag) : { snapshot: null, reference: null };
  await unchanged(provider, observed);
  const body = { deployment: d, prepared, observed, recipe, sourceDependencies: dependencies, inventory: facts,
    sourceSet: set, graph: saved, selectedHosts, childDependencies };
  return freeze({ ...body, captureHash: fingerprint(body) });
}

function snapshotCapture(value: ScopedPolicyGraphV2Capture): ScopedPolicyGraphV2Capture {
  const copy = structuredClone(value);
  keys(copy, ["deployment", "prepared", "observed", "recipe", "sourceDependencies", "inventory", "sourceSet", "graph",
    "selectedHosts", "childDependencies", "captureHash"]);
  const { captureHash, ...body } = copy;
  equal(fingerprint(body), hash(captureHash), "Capture fingerprint differs");
  const d = deployment(copy.deployment);
  const prepared = graph.normalizeScopedPolicyGraphV2Call(copy.prepared);
  equal(prepared.coordinates, coordinates(d), "Prepared coordinates differ");
  return freeze(copy);
}

function comparable(value: ScopedPolicyGraphV2Capture): unknown {
  const { observed: _observed, captureHash: _captureHash, ...body } = value;
  return body;
}

async function revalidate(provider: Reader, saved: ScopedPolicyGraphV2Capture, tag: number): Promise<ScopedPolicyGraphV2Capture> {
  await unchanged(provider, saved.observed);
  const original = await captureScopedPolicyGraphV2(provider, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: saved.observed.blockNumber });
  equal(original, saved, "Saved capture is not authentic at its pinned block");
  if (tag < saved.observed.blockNumber) throw Error("Cannot revalidate before capture");
  const current = tag === saved.observed.blockNumber ? original : await captureScopedPolicyGraphV2(provider, saved.deployment,
    saved.prepared.caller, saved.prepared.request, { blockTag: tag });
  equal(comparable(current), comparable(saved));
  return current;
}

function gas(value: unknown): bigint {
  const result = uint(value);
  if (result === 0n || result > 100_000_000n) throw Error("Gas limit must be 1..100000000");
  return result;
}

function graphPrefix(before: graph.ScopedPolicyGraphV2Graph, after: graph.ScopedPolicyGraphV2Graph, expectedCount: bigint): void {
  if (after.preparedChildren !== expectedCount) throw Error("Graph progress differs");
  if (before.graphId !== ZERO) {
    for (const key of ["scope", "inventoryPlan", "sourceSet", "sourceSetCodeHash", "graphId"] as const) {
      equal(after[key], before[key], "Graph immutable identity differs");
    }
  }
  for (let i = 0; i < Number(before.preparedChildren); i++) {
    equal([after.children[i], after.codeHashes[i]], [before.children[i], before.codeHashes[i]], "Saved child prefix differs");
  }
}

export async function simulateScopedPolicyGraphV2(provider: Reader, input: ScopedPolicyGraphV2Capture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = snapshotCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const tag = number(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  const capture = await revalidate(provider, saved, tag);
  const p = capture.prepared;
  const iface = p.request.kind === "prepareGraph" ? factoryAbi : sourceAbi;
  const raw = bytes(await provider.call({ from: p.caller, to: p.call.to, data: p.call.data, value: 0n, gasLimit, blockTag: tag }));
  const decoded = iface.decodeFunctionResult(p.request.kind, raw);
  if (!same(iface.encodeFunctionResult(p.request.kind, decoded), raw)) throw Error("Noncanonical original call result");
  let result: graph.ScopedPolicyGraphV2Graph | Address;
  if (p.request.kind === "prepareGraph") {
    result = graph.normalizeScopedPolicyGraphV2Graph(plain(iface.getFunction(p.request.kind)!.outputs[0]!, decoded[0]) as graph.ScopedPolicyGraphV2Graph);
    graph.validateScopedPolicyGraphV2Graph(coordinates(capture.deployment), capture.recipe, capture.sourceDependencies, result,
      { expectedPlan: capture.inventory.plan, expectedScope: p.request.scope });
    const expected = capture.graph.preparedChildren + p.request.maximumChildren;
    graphPrefix(capture.graph, result, expected > 7n ? 7n : expected);
    equal([result.sourceSet, result.sourceSetCodeHash], [capture.sourceSet!.address, capture.sourceSet!.codeHash]);
  } else {
    result = address(decoded[0]);
    if (capture.sourceSet && !same(result, capture.sourceSet.address)) throw Error("Retained source set result differs");
  }
  await unchanged(provider, capture.observed);
  return freeze({ capture, gasLimit, result, returnData: raw, simulated: true as const, persisted: false as const });
}

export async function inspectScopedPolicyGraphV2History(provider: Reader, inputDeployment: ScopedPolicyGraphV2HistoryDeployment,
  inputPlan: Hex, options: { readonly blockTag: number }) {
  keys(inputDeployment, ["chainId", "publicationFactory", "recipeHash", "sourceFactoryDependenciesHash"]);
  const d = freeze({ chainId: uint(inputDeployment.chainId), publicationFactory: codePin(inputDeployment.publicationFactory),
    recipeHash: hash(inputDeployment.recipeHash), sourceFactoryDependenciesHash: hash(inputDeployment.sourceFactoryDependenciesHash) });
  const plan = hash(inputPlan, true);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  if (d.chainId === 0n || (await provider.getNetwork()).chainId !== d.chainId) throw Error("Chain differs");
  const observed = await header(provider, tag);
  const recipe = await localRecipe(provider, d, tag);
  const saved = graph.normalizeScopedPolicyGraphV2Graph(
    (await rpc(provider, d.publicationFactory.address, factoryAbi, "graphForPlan", [plan], tag))[0] as graph.ScopedPolicyGraphV2Graph
  );
  if (saved.graphId !== ZERO) {
    graph.validateScopedPolicyGraphV2Scope(saved.scope);
    hash(saved.inventoryPlan);
    address(saved.sourceSet);
    hash(saved.sourceSetCodeHash);
    if (!same(saved.inventoryPlan, plan) || saved.preparedChildren === 0n
      || saved.preparedChildren > 7n
      || !same(saved.graphId, graph.scopedPolicyGraphV2GraphId({ chainId: d.chainId, sourceFactory: recipe.targets[2],
        publicationFactory: d.publicationFactory.address }, d.recipeHash, d.sourceFactoryDependenciesHash,
      saved.scope, plan, saved.sourceSet, saved.sourceSetCodeHash))) throw Error("Historical graph identity differs");
    for (let i = 0; i < 7; i++) {
      if (BigInt(i) < saved.preparedChildren) {
        address(saved.children[i]);
        hash(saved.codeHashes[i]);
      } else if (saved.children[i] !== ZERO_ADDRESS || saved.codeHashes[i] !== ZERO) throw Error("Historical child prefix differs");
    }
  } else if (!/^0x0+$/.test(graph.encodeScopedPolicyGraphV2Graph(saved))) {
    throw Error("Noncanonical missing graph");
  }
  await unchanged(provider, observed);
  return freeze({ deployment: d, observed, plan, recipe, graph: saved,
    status: saved.graphId === ZERO ? "missing" as const : saved.preparedChildren === 7n ? "complete" as const : "partial" as const,
    currentnessChecked: false as const });
}

export async function inspectScopedPolicyGraphV2Current(provider: Reader, inputDeployment: ScopedPolicyGraphV2Deployment,
  inputScope: graph.ScopedPolicyGraphV2Scope, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment);
  const scope = graph.validateScopedPolicyGraphV2Scope(inputScope);
  const capture = await captureScopedPolicyGraphV2(provider, d, d.publicationFactory.address,
    { kind: "prepareGraph", scope, maximumChildren: 1n }, options);
  const current = graph.normalizeScopedPolicyGraphV2Graph((await rpc(provider, d.publicationFactory.address, factoryAbi,
    "requireCurrentGraph", [scope], capture.observed.blockNumber))[0] as graph.ScopedPolicyGraphV2Graph);
  if (current.preparedChildren !== 7n) throw Error("Current graph is incomplete");
  equal(current, capture.graph, "Current graph differs from saved graph");
  await unchanged(provider, capture.observed);
  return freeze({ capture, graph: current, currentnessChecked: true as const });
}

export interface ScopedPolicyGraphV2SourceProfile {
  readonly profileHash: Hex;
  readonly referenceRender: Address;
  readonly referenceRenderCodeHash: Hex;
  readonly snapshots: Address;
  readonly snapshotsCodeHash: Hex;
  readonly entropyFactory: Address;
  readonly entropyFactoryCodeHash: Hex;
  readonly configurationHash: Hex;
}

/** Source discovery calls the original provider/discovery, and confers no finality authority. */
export async function inspectScopedPolicyGraphV2Discovery(provider: Reader, inputDeployment: ScopedPolicyGraphV2DiscoveryDeployment,
  inputScope: graph.ScopedPolicyGraphV2Scope,
  options: { readonly blockTag: number; readonly includeRoutes: boolean; readonly includeSanction: boolean }) {
  keys(inputDeployment, ["graph", "provider", "discovery", "configurationHash", "sourceConfigurationHash", "linkedDependencies"]);
  const d = freeze({ graph: deployment(inputDeployment.graph), provider: codePin(inputDeployment.provider),
    discovery: codePin(inputDeployment.discovery), configurationHash: hash(inputDeployment.configurationHash),
    sourceConfigurationHash: hash(inputDeployment.sourceConfigurationHash), linkedDependencies: pinList(inputDeployment.linkedDependencies) });
  const scope = graph.validateScopedPolicyGraphV2Scope(inputScope);
  keys(options, ["blockTag", "includeRoutes", "includeSanction"]);
  const tag = number(options.blockTag);
  const includeRoutes = options.includeRoutes;
  const includeSanction = options.includeSanction;
  if (typeof includeRoutes !== "boolean" || typeof includeSanction !== "boolean") throw Error("Expected discovery flags");
  const current = await inspectScopedPolicyGraphV2Current(provider, d.graph, scope, { blockTag: tag });
  for (const pin of [d.provider, d.discovery, ...d.linkedDependencies]) await runtime(provider, pin, tag);
  const capture = current.capture;
  const r = capture.recipe;
  const g = current.graph;
  const binding = graph.normalizeScopedPolicyGraphV2FactoryBinding(
    await read(provider, d.provider.address, "scopedPolicyPublicationBinding", [], tag) as graph.ScopedPolicyGraphV2FactoryBinding
  );
  equal([binding.factory, binding.factoryCodeHash, binding.recipeHash, binding.sourceFactoryDependenciesHash, binding.configurationHash],
    [d.graph.publicationFactory.address, d.graph.publicationFactory.codeHash, d.graph.recipeHash,
      d.graph.sourceFactoryDependenciesHash, d.configurationHash], "Stable provider binding differs");
  const original = await read(provider, d.provider.address, "nativeConfiguration", [], tag) as {
    targets: readonly Address[]; codeHashes: readonly Hex[]; chainId: bigint; readGas: bigint;
    sourceGas: bigint; componentSourceGas: bigint; inventoryDependencyHash: Hex;
  };
  if (original.chainId !== d.graph.chainId || binding.graphGas < original.readGas || binding.graphGas > 0xffffffffn
    || original.componentSourceGas <= binding.graphGas + binding.graphGas / 63n + original.readGas + 200000n) {
    throw Error("Provider graph gas/deployment binding differs");
  }
  const originalType = abi.getFunction("nativeConfiguration")!.outputs[0]!;
  const expectedConfiguration = keccak256(coder.encode(
    ["bytes32", "uint256", "address", originalType, "address", "bytes32", "bytes32", "bytes32", "uint256"],
    [id("6529STREAM_SCOPED_POLICY_PROVIDER_CONFIGURATION_V2"), d.graph.chainId, d.provider.address, original,
      binding.factory, binding.factoryCodeHash, binding.recipeHash, binding.sourceFactoryDependenciesHash, binding.graphGas]
  ));
  if (!same(expectedConfiguration, binding.configurationHash)) throw Error("Provider configuration preimage differs");
  const indexes = [0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
  for (let i = 0; i < 12; i++) {
    if (i !== 5 && i !== 6) equal([r.inventory.targets[i], r.inventory.codeHashes[i]],
      [original.targets[indexes[i]!], original.codeHashes[indexes[i]!]], "Provider recipe projection differs");
  }
  equal([r.targets[0], r.codeHashes[0], r.inventory.artistTargets[0], r.inventory.artistCodeHashes[0]],
    [original.targets[3], original.codeHashes[3], original.targets[11], original.codeHashes[11]], "Provider fixed roles differ");
  const joins: ReadonlyArray<readonly [Address, string, unknown]> = [
    [d.provider.address, "core", r.inventory.targets[0]], [d.provider.address, "metadataHost", r.inventory.targets[1]],
    [d.provider.address, "metadataRouter", r.inventory.targets[4]], [d.provider.address, "scopeMembershipHost", r.targets[0]],
    [d.provider.address, "finalitySourceConfigurationHash", d.sourceConfigurationHash],
    [d.discovery.address, "core", r.inventory.targets[0]], [d.discovery.address, "metadataHost", r.inventory.targets[1]],
    [d.discovery.address, "scopeEvidenceProvider", d.provider.address], [d.discovery.address, "sourceConfigurationHash", d.sourceConfigurationHash],
    [d.discovery.address, "deploymentChainId", d.graph.chainId]
  ];
  for (const [target, method, expected] of joins) equal(await read(provider, target, method, [], tag), expected, "Discovery reciprocity differs");
  const snapshot = address(await read(provider, d.provider.address, "scopedPolicySnapshotHost", [scope], tag));
  const snapshotCodeHash = hash(await read(provider, d.provider.address, "scopedPolicySnapshotCodeHash", [scope], tag));
  equal([snapshot, snapshotCodeHash], [g.children[3], g.codeHashes[3]], "Prepublication snapshot route differs");
  if (!same(await read(provider, d.provider.address, "scopedPolicySnapshotProfile", [], tag), id("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2"))
    || await read(provider, d.provider.address, "scopedPolicySnapshotValidationGas", [scope], tag) !== original.componentSourceGas) {
    throw Error("Snapshot capability/budget differs");
  }
  const sources = await read(provider, d.provider.address, "finalitySourcesForScope", [scope], tag) as {
    scope: graph.ScopedPolicyGraphV2Scope; profile: ScopedPolicyGraphV2SourceProfile;
  };
  equal(sources.scope, scope, "Selected source scope differs");
  const head = hash(await read(provider, r.inventory.targets[4], "scopedContentRootHead", [scope], tag), true);
  const root = head === ZERO ? null : await read(provider, r.inventory.targets[4], "scopedPolicyContentRootBinding", [head], tag) as Record<string, unknown>;
  const isPolicy = root !== null && !same(root.profileId, ZERO);
  if (root !== null && !isPolicy
    && !/^0x0+$/.test(coder.encode([abi.getFunction("scopedPolicyContentRootBinding")!.outputs[0]!], [root]))) {
    throw Error("Noncanonical absent V2 root binding");
  }
  if (isPolicy) {
    const expectedRoot: Record<string, unknown> = {
      profileId: id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2"), outputManifest: g.children[2], outputManifestCodeHash: g.codeHashes[2],
      checkpoint: g.children[1], checkpointCodeHash: g.codeHashes[1], entropySourceSet: g.sourceSet, entropySourceSetCodeHash: g.sourceSetCodeHash,
      sourceFactory: d.graph.sourceFactory.address, sourceFactoryCodeHash: d.graph.sourceFactory.codeHash,
      factoryDependenciesHash: d.graph.sourceFactoryDependenciesHash,
      snapshotProfileHash: "0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b"
    };
    for (const [key, value] of Object.entries(expectedRoot)) equal(root![key], value, "Tagged root graph binding differs");
    equal(sources.profile, { profileHash: expectedRoot.snapshotProfileHash, referenceRender: g.children[4], referenceRenderCodeHash: g.codeHashes[4],
      snapshots: g.children[3], snapshotsCodeHash: g.codeHashes[3], entropyFactory: d.graph.sourceFactory.address,
      entropyFactoryCodeHash: d.graph.sourceFactory.codeHash, configurationHash: binding.configurationHash }, "Selected V2 source profile differs");
  } else if (same(sources.profile.profileHash, "0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b")) {
    throw Error("Graph preparation alone cannot select the V2 publication profile");
  }
  let routes: readonly graph.ScopedPolicyGraphV2CurrentRoute[] | null = null;
  if (includeRoutes) {
    routes = (await read(provider, d.discovery.address, "requireCurrentRoutes", [scope, includeSanction], tag) as readonly graph.ScopedPolicyGraphV2CurrentRoute[])
      .map(graph.normalizeScopedPolicyGraphV2CurrentRoute);
    if (routes.length !== (includeSanction ? 10 : 9)) throw Error("Discovery route count differs");
    const families = ["METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE",
      "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER", ...(includeSanction ? ["ARTIST_SANCTION"] : [])]
      .map(name => id(name)).sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1);
    equal(routes.map(row => row.componentType), families, "Discovery component families differ");
    for (let i = 0; i < routes.length; i++) {
      const row = routes[i]!;
      if (row.interfaceId !== "0x8004d4f5" || row.componentType === ZERO
        || (i > 0 && BigInt(routes[i - 1]!.componentType) >= BigInt(row.componentType))) throw Error("Discovery route ordering differs");
      await runtime(provider, { address: row.component, codeHash: row.codeHash }, tag);
      if (isPolicy && same(row.componentType, id("ENTROPY_COORDINATOR"))) equal([row.component, row.codeHash], [g.sourceSet, g.sourceSetCodeHash]);
      if (isPolicy && same(row.componentType, id("REFERENCE_RENDER"))) equal([row.component, row.codeHash], [g.children[4], g.codeHashes[4]]);
    }
  }
  await unchanged(provider, capture.observed);
  return freeze({ deployment: d, observed: capture.observed, graph: g, binding, snapshot: { address: snapshot, codeHash: snapshotCodeHash },
    selectedSources: sources, selection: isPolicy ? "scoped-policy-v2" as const : "prior-profile" as const, routes,
    finalityEstablished: false as const });
}

const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);

export type ScopedPolicyGraphV2ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex }
>;

interface CopiedLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

async function transport(provider: ReceiptReader, saved: ScopedPolicyGraphV2Capture,
  transactionHash: Hex, options: ScopedPolicyGraphV2ReceiptOptions) {
  const raw = await provider.getTransactionReceipt(transactionHash);
  if (!raw || raw.status !== 1 || !same(raw.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = number(raw.blockNumber);
  const blockHash = hash(raw.blockHash);
  const from = address(raw.from);
  const to = address(raw.to);
  if (blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow captured block");
  if (!Array.isArray(raw.logs) || raw.logs.length > MAX_LOGS) throw Error("Receipt log limit exceeded");
  let priorIndex = -1;
  let total = 0;
  const logs: CopiedLog[] = raw.logs.map(log => {
    const index = number(log.index);
    if (index <= priorIndex || log.removed !== false || !same(log.transactionHash, transactionHash)
      || log.blockNumber !== blockNumber || !same(log.blockHash, blockHash)) throw Error("Receipt log identity/order differs");
    priorIndex = index;
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error("Malformed log topics");
    const data = bytes(log.data, 65536);
    total += (data.length - 2) / 2;
    if (total > 1_048_576) throw Error("Receipt aggregate log bound exceeded");
    return { address: address(log.address), topics: log.topics.map((topic: string) => hash(topic, true)), data, index };
  });
  const tx = await provider.getTransaction(transactionHash);
  if (!tx || !same(tx.hash, transactionHash) || !same(tx.from, from) || !same(tx.to, to)
    || tx.blockNumber !== blockNumber || !same(tx.blockHash, blockHash)
    || tx.chainId !== saved.deployment.chainId) throw Error("Transaction envelope differs");
  const data = bytes(tx.data, MAX_CALL + 16384);
  const call = saved.prepared.call;
  const caller = saved.prepared.caller;
  if (tx.value !== 0n) throw Error("Outer value must be zero");
  let safeIndex = -1;
  if (options.execution === "direct") {
    if (!same(from, caller) || !same(to, call.to) || !same(data, call.data)) throw Error("Direct caller/target/data differs");
  } else {
    if (!same(to, caller)) throw Error("Safe is not the actual factory caller");
    const decoded = safe.decodeFunctionData("execTransaction", data);
    if (!same(safe.encodeFunctionData("execTransaction", decoded), data) || !same(decoded.to, call.to)
      || decoded.value !== 0n || !same(decoded.data, call.data) || decoded.operation !== 0n) throw Error("Safe inner CALL differs");
    const executionTopics = [safe.getEvent("ExecutionSuccess")!.topicHash, safe.getEvent("ExecutionFailure")!.topicHash];
    const matches = logs.filter(log => same(log.address, caller) && executionTopics.some(topic => same(topic, log.topics[0])));
    if (matches.length !== 1) throw Error("Expected exactly one Safe execution event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) },
      caller, options.expectedSafeTxHash);
    safeIndex = matches[0]!.index;
  }
  const observed = await header(provider, blockNumber);
  if (!same(observed.blockHash, blockHash)) throw Error("Receipt block changed");
  return { observed, logs, safeIndex };
}

function events(logs: readonly CopiedLog[], target: Address, iface: Interface, name: string) {
  const fragment = iface.getEvent(name)!;
  return logs.filter(log => same(log.address, target) && same(log.topics[0], fragment.topicHash)).map(row => {
    const decoded = iface.decodeEventLog(fragment, row.data, [...row.topics]);
    const encoded = iface.encodeEventLog(fragment, decoded);
    equal(encoded.topics.map(topic => topic.toLowerCase()), row.topics, `${name} topics differ`);
    if (!same(encoded.data, row.data)) throw Error(`Noncanonical ${name}`);
    return { index: row.index, fields: Object.fromEntries(fragment.inputs.map((param, index) => [param.name, plain(param, decoded[index])])) };
  });
}

/** Exact prior/end-block attribution deliberately refuses concurrent source/progress changes. */
export async function reconcileScopedPolicyGraphV2Receipt(provider: ReceiptReader, input: ScopedPolicyGraphV2Capture,
  inputTransactionHash: Hex, inputOptions: ScopedPolicyGraphV2ReceiptOptions) {
  const saved = snapshotCapture(input);
  const transactionHash = hash(inputTransactionHash);
  if (inputOptions.execution !== "direct" && inputOptions.execution !== "safe") throw Error("Unknown execution transport");
  keys(inputOptions, inputOptions.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const options: ScopedPolicyGraphV2ReceiptOptions = inputOptions.execution === "safe"
    ? { execution: "safe", expectedSafeTxHash: hash(inputOptions.expectedSafeTxHash) } : { execution: "direct" };
  const t = await transport(provider, saved, transactionHash, options);
  const prior = await revalidate(provider, saved, t.observed.blockNumber - 1);
  const after = await captureScopedPolicyGraphV2(provider, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: t.observed.blockNumber });
  equal([after.recipe, after.sourceDependencies, after.inventory, after.selectedHosts],
    [prior.recipe, prior.sourceDependencies, prior.inventory, prior.selectedHosts], "End-block source context differs");
  const d = prior.deployment;
  const request = prior.prepared.request;
  const childEvents = events(t.logs, d.publicationFactory.address, factoryAbi, "ScopedPolicyPublicationChildPrepared");
  const setEvents = events(t.logs, d.sourceFactory.address, sourceAbi, "EntropySourceSetPrepared");
  let lastRequired = -1;
  let createdChildren: readonly ScopedPolicyGraphV2CodePin[] = [];
  if (request.kind === "prepareSourceSet") {
    equal(after.graph, prior.graph, "Source preparation changed publication graph");
    if (!after.sourceSet || childEvents.length !== 0) throw Error("Source preparation receipt differs");
    if (prior.sourceSet) {
      equal(after.sourceSet, prior.sourceSet, "Eventless source retry changed immutable entry");
      if (setEvents.length !== 0) throw Error("Retained source retry emitted creation");
    } else {
      if (setEvents.length !== 1) throw Error("Expected exactly one source creation event");
      equal(setEvents[0]!.fields, { planId: prior.inventory.plan, sourceSet: after.sourceSet.address,
        scopeSubject: prior.inventory.membership.scopeSubject, sourceSetCodeHash: after.sourceSet.codeHash,
        dataHash: after.inventory.sourceSetDataHash }, "Source creation event differs");
      lastRequired = setEvents[0]!.index;
    }
  } else {
    equal(after.sourceSet, prior.sourceSet, "Graph preparation replaced source set");
    if (setEvents.length !== 0) throw Error("Graph preparation unexpectedly created a source set");
    const sum = prior.graph.preparedChildren + request.maximumChildren;
    const expectedCount = sum > 7n ? 7n : sum;
    graphPrefix(prior.graph, after.graph, expectedCount);
    const added = Number(expectedCount - prior.graph.preparedChildren);
    if (childEvents.length !== added) throw Error("Child creation event count differs");
    const pins: ScopedPolicyGraphV2CodePin[] = [];
    for (let i = 0; i < added; i++) {
      const index = Number(prior.graph.preparedChildren) + i;
      const row = childEvents[i]!;
      const pin = { address: after.graph.children[index]!, codeHash: after.graph.codeHashes[index]! };
      equal(row.fields, { schemaVersion: 2n, graphId: after.graph.graphId, inventoryPlan: prior.inventory.plan,
        childIndex: BigInt(index), child: pin.address, codeHash: pin.codeHash }, "Child creation event/order differs");
      if (row.index <= lastRequired) throw Error("Child event order differs");
      lastRequired = row.index;
      pins.push(pin);
    }
    createdChildren = pins;
    if (prior.childDependencies.snapshot !== null) equal(after.childDependencies.snapshot, prior.childDependencies.snapshot,
      "Existing snapshot changed in receipt block");
    if (prior.childDependencies.reference !== null) equal(after.childDependencies.reference, prior.childDependencies.reference,
      "Existing reference changed in receipt block");
  }
  if (t.safeIndex >= 0 && t.safeIndex <= lastRequired) throw Error("Safe success precedes factory events");
  await unchanged(provider, t.observed);
  return freeze({ transactionHash, observed: t.observed, prior, after, createdChildren,
    createdSourceSet: request.kind === "prepareSourceSet" && prior.sourceSet === null ? after.sourceSet : null,
    eventlessRetry: lastRequired < 0, execution: options.execution, evidence: "prior-and-end-block-reconciliation" as const });
}

/** A reverted eth_call and unchanged observed getters do not independently prove native rollback. */
export async function observeScopedPolicyGraphV2Refusal(provider: Reader, input: ScopedPolicyGraphV2Capture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = snapshotCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const tag = number(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber || (await provider.getNetwork()).chainId !== saved.deployment.chainId) throw Error("Refusal block/chain differs");
  await revalidate(provider, saved, saved.observed.blockNumber);
  const observed = await header(provider, tag);
  const before = await rpc(provider, saved.deployment.publicationFactory.address, factoryAbi, "graphForPlan", [saved.inventory.plan], tag);
  const beforeSource = await rpc(provider, saved.deployment.sourceFactory.address, sourceAbi, "sourceSetForPlan", [saved.inventory.plan], tag);
  for (const pin of [saved.deployment.publicationFactory, saved.deployment.sourceFactory, ...saved.deployment.linkedDependencies]) {
    await runtime(provider, pin, tag);
  }
  let error: unknown;
  let succeeded = false;
  try {
    await provider.call({ ...saved.prepared.call, from: saved.prepared.caller, gasLimit, blockTag: tag });
    succeeded = true;
  } catch (cause) {
    error = cause;
  }
  const after = await rpc(provider, saved.deployment.publicationFactory.address, factoryAbi, "graphForPlan", [saved.inventory.plan], tag);
  const afterSource = await rpc(provider, saved.deployment.sourceFactory.address, sourceAbi, "sourceSetForPlan", [saved.inventory.plan], tag);
  await unchanged(provider, observed);
  if (succeeded) throw Error("Original preparation did not refuse");
  const code = error && typeof error === "object" && "code" in error ? error.code : undefined;
  return freeze({ observed, outcome: code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    error, retainedGraphUnchanged: stable(before) === stable(after), retainedSourceUnchanged: stable(beforeSource) === stable(afterSource),
    rollbackProven: false as const });
}
