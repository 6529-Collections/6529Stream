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
import * as view from "./current-tagged-policy-view-v2.js";

type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;

export interface TaggedPolicyViewV2CodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

export interface TaggedPolicyViewV2Block {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

/** Pins come from reviewed release/link metadata; a supplied hash is not a source proof. */
export interface TaggedPolicyViewV2Deployment {
  readonly chainId: bigint;
  readonly core: TaggedPolicyViewV2CodePin;
  readonly router: TaggedPolicyViewV2CodePin;
  readonly artist: TaggedPolicyViewV2CodePin;
  readonly artistCoordinator: TaggedPolicyViewV2CodePin;
  readonly artistConsentOwner: TaggedPolicyViewV2CodePin;
  readonly finality: TaggedPolicyViewV2CodePin;
  readonly provider: TaggedPolicyViewV2CodePin;
  readonly metadata: TaggedPolicyViewV2CodePin;
  readonly schemas: TaggedPolicyViewV2CodePin;
  readonly store: TaggedPolicyViewV2CodePin;
  readonly views: TaggedPolicyViewV2CodePin;
  readonly membership: TaggedPolicyViewV2CodePin;
  readonly moduleRegistry: TaggedPolicyViewV2CodePin;
  readonly rendererRegistry: TaggedPolicyViewV2CodePin;
  readonly renderer: TaggedPolicyViewV2CodePin;
  readonly policyFactory: TaggedPolicyViewV2CodePin;
  readonly sourceSet: TaggedPolicyViewV2CodePin;
  readonly inventory: TaggedPolicyViewV2CodePin;
  readonly encoding: TaggedPolicyViewV2CodePin;
  readonly liveAttribution: TaggedPolicyViewV2CodePin;
  readonly linkedDependencies: readonly TaggedPolicyViewV2CodePin[];
}

/** Local history needs only the original Router and its fixed history-reader links. */
export interface TaggedPolicyViewV2HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly router: TaggedPolicyViewV2CodePin;
  readonly linkedDependencies: readonly TaggedPolicyViewV2CodePin[];
}

/** Serving pins include the actual fixed Router routing workers. */
export interface TaggedPolicyViewV2ServingDeployment extends TaggedPolicyViewV2HistoryDeployment {
  readonly coreCodeHash: Hex;
}

const ZERO = ETH_ZERO_HASH as Hex;
const ZERO_ADDRESS = ETH_ZERO_ADDRESS as Address;
const FAMILY = id("RENDERER_CONFIG") as Hex;
const IDENTITY_FAMILY = id("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1") as Hex;
const coder = AbiCoder.defaultAbiCoder();
const MAX_RPC = 1_048_576;
const MAX_RUNTIME = 131_072;
const MAX_LOGS = 4096;
const MAX_CALL = 1_048_576;

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

function codePin(value: TaggedPolicyViewV2CodePin): TaggedPolicyViewV2CodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function pinList(value: readonly TaggedPolicyViewV2CodePin[]): readonly TaggedPolicyViewV2CodePin[] {
  if (!Array.isArray(value) || value.length > 256) throw Error("Linked dependency limit exceeded");
  const pins = value.map(codePin);
  if (new Set(pins.map(pin => pin.address)).size !== pins.length) throw Error("Duplicate linked dependency");
  return pins;
}

const DEPLOYMENT_PINS = [
  "core", "router", "artist", "artistCoordinator", "artistConsentOwner", "finality", "provider", "metadata", "schemas", "store",
  "views", "membership", "moduleRegistry", "rendererRegistry", "renderer", "policyFactory",
  "sourceSet", "inventory", "encoding", "liveAttribution"
] as const;

function deployment(value: TaggedPolicyViewV2Deployment): TaggedPolicyViewV2Deployment {
  keys(value, ["chainId", ...DEPLOYMENT_PINS, "linkedDependencies"]);
  const result = { chainId: uint(value.chainId), linkedDependencies: pinList(value.linkedDependencies) } as
    Record<string, unknown>;
  if (result.chainId === 0n) throw Error("Zero chain ID");
  for (const key of DEPLOYMENT_PINS) result[key] = codePin(value[key]);
  return freeze(result as unknown as TaggedPolicyViewV2Deployment);
}

async function header(provider: Reader, tag: number): Promise<TaggedPolicyViewV2Block> {
  const value = await provider.getBlock(number(tag));
  if (!value || value.number !== tag) throw Error("Missing or mismatched block");
  return { blockNumber: tag, blockHash: hash(value.hash), timestamp: BigInt(number(value.timestamp)) };
}

async function unchanged(provider: Reader, block: TaggedPolicyViewV2Block): Promise<void> {
  equal(await header(provider, block.blockNumber), block, "Pinned block changed");
}

async function runtime(provider: Reader, pin: TaggedPolicyViewV2CodePin, tag: number): Promise<void> {
  const raw = bytes(await provider.getCode(pin.address, tag), MAX_RUNTIME);
  if (raw === "0x" || (raw.length === 48 && raw.startsWith("0xef0100"))
    || !same(keccak256(raw), pin.codeHash)) throw Error("Pinned runtime differs");
}

async function carrier(provider: Reader, pointer: Address, contentHash: Hex, size: bigint, tag: number): Promise<Hex> {
  if (size === 0n || size > 8192n) throw Error("Invalid STOP carrier size");
  const raw = bytes(await provider.getCode(address(pointer), tag), 8193);
  const body = `0x${raw.slice(4)}` as Hex;
  if (!raw.startsWith("0x00") || BigInt((body.length - 2) / 2) !== size
    || !same(keccak256(body), contentHash)) throw Error("STOP carrier differs");
  return body;
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
  "function artistRegistry() view returns (address)",
  "function authority() view returns (address)",
  "function staticMetadataActivation(uint256 id) view returns (bytes32, uint64, bytes32)",
  "function artistContentLockState(uint256 collectionId, bytes32 lockClass) view returns (bool supported, bool locked)",
  "function artistContentFamilyState(uint256 collectionId, bytes32 familyId) view returns (bool supported, bytes32 currentStateHash)",
  "function currentArtistContentState(uint256 collectionId) view returns (address metadataContract, bytes32 contentStateHash)",
  "function consumedArtistContentConsent(bytes32) view returns (bool)",
  "function artistContentEvolution(uint256 collectionId) view returns (bytes32, bytes32)",
  "function collectionExists(uint256 collectionId) view returns (bool)",
  "function collectionFreezeStatus(uint256 collectionId) view returns (bool)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)",
  "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)",
  "function finalityRegistry() view returns (address)",
  "function finalityRegistryCodeHash() view returns (bytes32)",
  "function operationCoordinator() view returns (address)",
  "function collectionArtistState(uint256 collectionId) view returns (uint8 attributionState, uint64 bindingGeneration, bytes32 artistId, uint8 authorityStatus, bytes32 bindingHash)",
  "function contentConsentEvidence(uint256 collectionId, bytes32 familyId, bytes32 newStateHash) view returns (bytes32)",
  "function firstReleaseRatification(uint256 collectionId) view returns (bool, bytes32, bytes32)",
  "function suiteConfiguration() view returns ((address registry, address archive, address[7] owners, address core, address mintManager, address roleRegistry, address metadata, address primaryResolver, address royaltyResolver, bytes32 primaryRevenueClass, address validator))",
  "function contentConsentRecord(bytes32 recordHash) view returns ((bytes32 recordHash, bytes32 artistId, uint64 bindingGeneration, (uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) terms, uint8 authorityClass))",
  "function contentConsentAt((uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) p, uint64 generation) view returns ((bytes32 recordHash, bytes32 artistId, uint64 bindingGeneration, (uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) terms, uint8 authorityClass))",
  "function coreReads() view returns (address)",
  "function sanctionReads() view returns (address)",
  "function metadataReads() view returns (address)",
  "function scopeEvidenceProvider() view returns (address)",
  "function scopeEvidenceProviderCodeHash() view returns (bytes32)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function artworkFreezeMode((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint8)",
  "function metadataHost() view returns (address)",
  "function viewSourceBinding() view returns ((address views, bytes32 viewsCodeHash, address membership, bytes32 membershipCodeHash, uint32 readGas, uint32 sourceGas))",
  "function viewPolicySourceFactoryV2() view returns (address)",
  "function viewPolicySourceFactoryV2CodeHash() view returns (bytes32)",
  "function governanceAuthority() view returns (address)",
  "function schemaRegistry() view returns (address)",
  "function chunkStore() view returns (address)",
  "function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account) view returns (bool, uint64)",
  "function selectedViewRecord(uint256 id, bytes32 viewId) view returns (bytes32, bool)",
  "function viewRecord(bytes32 hash) view returns ((bytes32 viewId, bytes32 schemaId, string uri, bytes32 contentHash, string mimeType, bool defaultForView), (uint256 collectionId, bytes32 viewId, uint64 revision, bytes32 previousRecordHash, address recorder, uint8 authorizationClass, uint256 grantCollectionId, uint64 grantRevision, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 viewSchemaDefinitionHash, bytes32 manifestSchemaDefinitionHash, bytes32 canonicalizationDefinitionHash), (bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt))",
  "function recordHashAt(uint256 id, uint256 index) view returns (bytes32)",
  "function manifestPayload(bytes32 hash) view returns (address, bytes)",
  "function viewPayload(bytes32 hash) view returns (address, bytes)",
  "function isModuleEligible(address module, bytes32 expectedModuleType, bytes4 expectedInterfaceId) view returns (bool)",
  "function documentFacts(bytes32 id) view returns ((bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash) facts)",
  "function documentBytes(bytes32 id) view returns (bytes payload)",
  "function chunk(bytes32) view returns (address pointer, uint32 length)",
  "event ChunkPublished(bytes32 indexed hash, address indexed pointer, uint32 length)",
  "function version(bytes32 key) view returns ((bool exists, bool deprecated, address renderer, bytes32 runtimeHash, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash, bytes32 actionId))",
  "function registration(bytes32 key) view returns ((address renderer, (bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 rendererClass, bytes32 schemaHash, string schemaURI, string manifestURI, bytes32 manifestHash, uint32 maxJSONBytes, uint32 maxHTMLBytes, bool deprecated) manifest, bytes32 schemaDocument, bytes32 contextDocument, bytes32 manifestDocument, bytes32 analysisDocument, bytes32 goldenDocument))",
  "function reads(bytes32 key) view returns ((uint16 targetIndex, bytes4 selector, uint32 maxReturnBytes, bool exact)[])",
  "function targetCount() view returns (uint256)",
  "function targetAt(uint256 index) view returns ((address target, bytes32 codeHash, bytes32 role))",
  "function requireAssignable(bytes32 key) view returns (address renderer, bytes32 runtimeHash)",
  "function requireRetained(bytes32 key) view returns (address renderer, bytes32 runtimeHash)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function sourceBindings() view returns (address[4], bytes32[4])",
  "function policyViewBinding() view returns ((address core, bytes32 coreCodeHash, address factory, bytes32 factoryCodeHash, address sourceSet, bytes32 sourceSetCodeHash, uint256 chainId, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, bytes32 inventoryPlan, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount))",
  "function encodingBinding() view returns (address, bytes32)",
  "function rendererManifest() view returns ((bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 rendererClass, bytes32 schemaHash, string schemaURI, string manifestURI, bytes32 manifestHash, uint32 maxJSONBytes, uint32 maxHTMLBytes, bool deprecated))",
  "function dependencies() view returns ((address[4] targets, bytes32[4] codeHashes, uint256 chainId, uint32 readGas, uint32 inventoryGas))",
  "function scopedPolicyFactoryProfile() pure returns (bytes32)",
  "function sourceSetForPlan(bytes32 plan) view returns (address sourceSet, bytes32 codeHash)",
  "function currentInventoryPlan((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function SOURCE_SET_PROFILE() view returns (bytes32)",
  "function factory() view returns (address)",
  "function sourceScope() view returns ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId))",
  "function inventoryPlan() view returns (bytes32)",
  "function originalInventoryHash() view returns (bytes32)",
  "function originalPolicyChainHash() view returns (bytes32)",
  "function scopeMembershipFacts() view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function sourceCount() view returns (uint256)",
  "function sourcePolicyAt(uint256 index) view returns ((address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy))",
  "function requireCurrentSelection() view",
  "function requireScopeMembership((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function scopeCoversToken((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 tokenId) view returns (bool)",
  "function requireCompleteInventory(bytes32 id) view returns ((bool exists, bool complete, uint256 processedTokens, uint256 tokenCount, uint256 coordinatorCount, bytes32 tokenChain, bytes32 coordinatorChain, bytes32 commitment))",
  "function inventoryScope(bytes32 id) view returns ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId), (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function requireCoordinator(bytes32 id, uint256 index) view returns ((address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex) c)",
  "event ViewAdopted(uint16 schemaVersion, bytes32 profile, uint256 indexed collectionId, bytes32 indexed scopeSubject, bytes32 indexed recordHash, (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 viewId, bytes32 viewRecordHash, bytes32 expectedPrevious, address rendererRegistry, bytes32 rendererVersionKey, bytes32 expectedSourceHash) input, ((address core, bytes32 coreCodeHash, address router, bytes32 routerCodeHash, address artist, bytes32 artistCodeHash, address finality, bytes32 finalityCodeHash, address provider, bytes32 providerCodeHash, address metadata, bytes32 metadataCodeHash, address schemas, bytes32 schemasCodeHash, address store, bytes32 storeCodeHash, (address views, bytes32 viewsCodeHash, address membership, bytes32 membershipCodeHash, uint32 readGas, uint32 sourceGas) binding) route, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) renderer, bytes32 schemaHash, bytes32 manifestSchemaHash, bytes32 canonicalizationHash, bytes32 manifestPayloadHash, bytes32 viewReceiptHash, bytes32 payloadHash, uint32 payloadBytes, address[5] payloadPointers, bytes32[5] payloadChunkHashes) source, bytes32 sourceHash, bytes32 recordHash, uint64 revision, address actor, uint8 authorizationClass, uint256 grantCollectionId, uint64 grantRevision, bytes32 artistConsent, uint64 adoptedAt, (uint64 revision, bytes32 transitionChain) aggregate) record)",
  "event ArtistContentConsentApplied(uint256 indexed collectionId,bytes32 indexed familyId,bytes32 indexed consentRecordHash,bytes32 resultingContentStateHash,uint16 schemaVersion)"
]);

async function read<T>(provider: Reader, target: Address, method: string,
  args: readonly unknown[], tag: number): Promise<T> {
  return (await rpc(provider, target, abi, method, args, tag))[0] as T;
}

async function selected(provider: Reader, d: TaggedPolicyViewV2Deployment, role: string,
  expected: TaggedPolicyViewV2CodePin, tag: number): Promise<void> {
  const value = await rpc(provider, d.core.address, abi, "getSatellitePointer", [id(role)], tag);
  if (!same(value[0], expected.address) || !same(value[1], expected.codeHash)
    || value[6] !== 1n || value[9] === 0n) throw Error(`Selected ${role} differs`);
}

interface ViewManifest {
  readonly viewId: Hex;
  readonly schemaId: Hex;
  readonly uri: string;
  readonly contentHash: Hex;
  readonly mimeType: string;
  readonly defaultForView: boolean;
}

interface ViewReceipt {
  readonly collectionId: bigint;
  readonly viewId: Hex;
  readonly revision: bigint;
  readonly previousRecordHash: Hex;
  readonly recorder: Address;
  readonly authorizationClass: bigint;
  readonly grantCollectionId: bigint;
  readonly grantRevision: bigint;
  readonly recordedAt: bigint;
  readonly recordIndex: bigint;
  readonly recordChainHash: Hex;
  readonly viewSchemaDefinitionHash: Hex;
  readonly manifestSchemaDefinitionHash: Hex;
  readonly canonicalizationDefinitionHash: Hex;
}

interface HashReference {
  readonly algorithm: bigint;
  readonly digest: Hex;
  readonly canonicalizationId: Hex;
}

interface CollectionRecord {
  readonly recordType: Hex;
  readonly subjectId: Hex;
  readonly contentHash: HashReference;
  readonly uri: string;
  readonly schemaId: Hex;
  readonly signatureScheme: Hex;
  readonly signatureHash: HashReference;
  readonly effectiveAt: bigint;
}

interface DocumentFacts {
  readonly exists: boolean;
  readonly kind: bigint;
  readonly status: bigint;
  readonly contentHash: Hex;
  readonly canonicalizationId: Hex;
  readonly supersedesId: Hex;
  readonly totalBytes: bigint;
  readonly chunkCount: bigint;
  readonly declarationHash: Hex;
}

interface RendererManifest {
  readonly rendererId: Hex;
  readonly rendererVersion: Hex;
  readonly contextVersion: Hex;
  readonly rendererClass: Hex;
  readonly schemaHash: Hex;
  readonly schemaURI: string;
  readonly manifestURI: string;
  readonly manifestHash: Hex;
  readonly maxJSONBytes: bigint;
  readonly maxHTMLBytes: bigint;
  readonly deprecated: boolean;
}

interface RendererVersion {
  readonly exists: boolean;
  readonly deprecated: boolean;
  readonly renderer: Address;
  readonly runtimeHash: Hex;
  readonly registrationHash: Hex;
  readonly readSetHash: Hex;
  readonly analysisHash: Hex;
  readonly goldenHash: Hex;
  readonly actionId: Hex;
}

export interface TaggedPolicyViewV2ConsentTerms {
  readonly collectionId: bigint;
  readonly metadataContract: Address;
  readonly familyId: Hex;
  readonly newStateHash: Hex;
}

export interface TaggedPolicyViewV2ConsentRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly terms: TaggedPolicyViewV2ConsentTerms;
  readonly authorityClass: bigint;
}

export interface TaggedPolicyViewV2Preflight {
  readonly deployment: TaggedPolicyViewV2Deployment;
  readonly caller: Address;
  readonly input: view.TaggedPolicyViewV2Input;
  readonly observed: TaggedPolicyViewV2Block;
  readonly source: view.TaggedPolicyViewV2Source;
  readonly policyBinding: view.TaggedPolicyViewV2PolicyBinding;
  readonly policies: readonly view.TaggedPolicyViewV2CoordinatorPolicy[];
  readonly payload: view.TaggedPolicyViewV2Payload;
  readonly declaration: { readonly manifest: ViewManifest; readonly receipt: ViewReceipt; readonly record: CollectionRecord };
  readonly head: Hex;
  readonly previousRevision: bigint;
  readonly aggregate: view.TaggedPolicyViewV2Aggregate;
  readonly authorizationClass: bigint;
  readonly grantCollectionId: bigint;
  readonly grantRevision: bigint;
  readonly familyStateHash: Hex;
  readonly currentFamilyStateHash: Hex;
  readonly consentTerms: TaggedPolicyViewV2ConsentTerms;
  readonly evidence: {
    readonly rendererRegistration: unknown;
    readonly rendererReads: readonly unknown[];
    readonly rendererTargets: readonly unknown[];
    readonly inventory: unknown;
  };
  readonly admission: "original-adoption-simulation-required";
  readonly preflightHash: Hex;
}

export interface TaggedPolicyViewV2Capture {
  readonly preflight: TaggedPolicyViewV2Preflight;
  readonly consent: TaggedPolicyViewV2ConsentRecord;
  readonly currentContentStateHash: Hex;
  readonly ratification: readonly [boolean, Hex, Hex];
  readonly evolution: readonly [Hex, Hex];
  readonly prepared: view.TaggedPolicyViewV2Call;
  readonly captureHash: Hex;
}

async function route(provider: Reader, d: TaggedPolicyViewV2Deployment, tag: number): Promise<view.TaggedPolicyViewV2Route> {
  for (const key of DEPLOYMENT_PINS) await runtime(provider, d[key], tag);
  for (const pin of d.linkedDependencies) await runtime(provider, pin, tag);
  for (const [role, pin] of [
    ["METADATA_ROUTER", d.router], ["ARTWORK_FINALITY_REGISTRY", d.finality],
    ["COLLECTION_METADATA", d.metadata], ["MODULE_REGISTRY", d.moduleRegistry]
  ] as const) await selected(provider, d, role, pin, tag);
  // Original Artist content selection checks target/runtime without an ACTIVE-row gate.
  const artistPointer = await rpc(provider, d.core.address, abi, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
  if (!same(artistPointer[0], d.artist.address) || !same(artistPointer[1], d.artist.codeHash)) {
    throw Error("Selected ARTIST_REGISTRY differs");
  }
  const checks: readonly [TaggedPolicyViewV2CodePin, string, unknown][] = [
    [d.router, "core", d.core.address], [d.router, "artistRegistry", d.artist.address],
    [d.artist, "finalityRegistry", d.finality.address], [d.artist, "finalityRegistryCodeHash", d.finality.codeHash],
    [d.artist, "operationCoordinator", d.artistCoordinator.address],
    [d.finality, "coreReads", d.core.address], [d.finality, "sanctionReads", d.artist.address],
    [d.finality, "metadataReads", d.metadata.address], [d.finality, "scopeEvidenceProvider", d.provider.address],
    [d.finality, "scopeEvidenceProviderCodeHash", d.provider.codeHash], [d.provider, "metadataHost", d.metadata.address],
    [d.metadata, "schemaRegistry", d.schemas.address], [d.metadata, "chunkStore", d.store.address],
    [d.views, "core", d.core.address], [d.views, "metadataHost", d.metadata.address],
    [d.views, "schemaRegistry", d.schemas.address], [d.views, "chunkStore", d.store.address],
    [d.membership, "core", d.core.address], [d.membership, "metadataHost", d.metadata.address],
    [d.rendererRegistry, "schemaRegistry", d.schemas.address]
  ];
  for (const [pin, method, expected] of checks) {
    if (!same(await read(provider, pin.address, method, [], tag), expected)) throw Error(`Route ${method} differs`);
  }
  const authority = address(await read(provider, d.router.address, "authority", [], tag));
  for (const target of [d.metadata, d.rendererRegistry]) {
    if (!same(await read(provider, target.address, "governanceAuthority", [], tag), authority)) throw Error("Authority binding differs");
  }
  for (const [pin, role, capability] of [
    [d.metadata, "COLLECTION_METADATA", "0x7e8260f8"],
    [d.views, "COLLECTION_VIEWS", "0xf3e43c45"],
    [d.rendererRegistry, "RENDERER_REGISTRY", "0x9caa6e5d"]
  ] as const) {
    if (await read(provider, d.moduleRegistry.address, "isModuleEligible", [pin.address, id(role), capability], tag) !== true) {
      throw Error(`Original ${role} module is ineligible`);
    }
  }
  for (const capability of ["0x58f06b17", "0x5e2d44b0"]) {
    if (await read(provider, d.provider.address, "supportsInterface", [capability], tag) !== true) {
      throw Error("Combined provider capability unavailable");
    }
  }
  const suite = await read<{ registry: Address; core: Address; metadata: Address; owners: readonly Address[] }>(provider,
    d.artistCoordinator.address, "suiteConfiguration", [], tag);
  if (!same(suite.registry, d.artist.address) || !same(suite.core, d.core.address)
    || !same(suite.metadata, d.router.address)
    || !same(suite.owners[6], d.artistConsentOwner.address)) throw Error("Original Artist suite differs");
  const cap = uint(await read(provider, d.finality.address, "gasParameter", [id("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS")], tag), 32);
  if (cap < 50000n) throw Error("Finality read gas unavailable");
  const binding = view.normalizeTaggedPolicyViewV2Binding(await read(provider, d.provider.address, "viewSourceBinding", [], tag));
  if (!same(binding.views, d.views.address) || !same(binding.viewsCodeHash, d.views.codeHash)
    || !same(binding.membership, d.membership.address) || !same(binding.membershipCodeHash, d.membership.codeHash)
    || binding.readGas < 50000n || binding.sourceGas < binding.readGas) throw Error("VIEW provider binding differs");
  return view.normalizeTaggedPolicyViewV2Route({
    core: d.core.address, coreCodeHash: d.core.codeHash, router: d.router.address, routerCodeHash: d.router.codeHash,
    artist: d.artist.address, artistCodeHash: d.artist.codeHash, finality: d.finality.address, finalityCodeHash: d.finality.codeHash,
    provider: d.provider.address, providerCodeHash: d.provider.codeHash, metadata: d.metadata.address, metadataCodeHash: d.metadata.codeHash,
    schemas: d.schemas.address, schemasCodeHash: d.schemas.codeHash, store: d.store.address, storeCodeHash: d.store.codeHash, binding
  });
}

async function definition(provider: Reader, d: TaggedPolicyViewV2Deployment, key: Hex, kind: bigint,
  expected: Hex | null, tag: number): Promise<Hex> {
  const facts = await read<DocumentFacts>(provider, d.schemas.address, "documentFacts", [key], tag);
  if (!facts.exists || facts.kind !== kind || facts.status !== 0n || facts.totalBytes === 0n || facts.totalBytes > 8192n
    || facts.contentHash === ZERO || (expected !== null && !same(facts.contentHash, expected))
    || (kind === 0n && !same(facts.canonicalizationId, id("RAW_BYTES")))) throw Error("Interpretation document unavailable");
  const body = bytes(await read(provider, d.schemas.address, "documentBytes", [key], tag), 8192);
  if (BigInt((body.length - 2) / 2) !== facts.totalBytes || !same(keccak256(body), facts.contentHash)) {
    throw Error("Interpretation document bytes differ");
  }
  return hash(facts.contentHash);
}

async function declaration(provider: Reader, d: TaggedPolicyViewV2Deployment,
  input: view.TaggedPolicyViewV2Input, block: TaggedPolicyViewV2Block) {
  const tag = block.blockNumber;
  const [selectedRecord] = await rpc(provider, d.views.address, abi, "selectedViewRecord", [input.scope.collectionId, input.viewId], tag);
  if (!same(selectedRecord, input.viewRecordHash)) throw Error("Selected VIEW declaration changed");
  const raw = await rpc(provider, d.views.address, abi, "viewRecord", [input.viewRecordHash], tag);
  const [manifest, receipt, record] = raw as unknown as [ViewManifest, ViewReceipt, CollectionRecord];
  if (receipt.collectionId !== input.scope.collectionId || !same(receipt.viewId, input.viewId)
    || !same(manifest.viewId, input.viewId) || receipt.revision === 0n || receipt.recorder === ZERO_ADDRESS
    || receipt.grantRevision === 0n || ![7n, 8n].includes(receipt.authorizationClass)
    || ![0n, input.scope.collectionId].includes(receipt.grantCollectionId) || receipt.recordedAt > block.timestamp
    || !same(manifest.schemaId, view.TAGGED_POLICY_VIEW_V2_SCHEMA_ID) || manifest.mimeType !== "application/octet-stream") {
    throw Error("Invalid VIEW declaration");
  }
  const schemaHash = await definition(provider, d, manifest.schemaId, 0n, view.TAGGED_POLICY_VIEW_V2_PAYLOAD_SCHEMA_HASH, tag);
  const manifestSchema = id("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1") as Hex;
  const manifestSchemaHash = await definition(provider, d, manifestSchema, 0n, view.TAGGED_POLICY_VIEW_V2_MANIFEST_SCHEMA_HASH, tag);
  const canonicalizationHash = await definition(provider, d, id("RAW_BYTES") as Hex, 1n, null, tag);
  if (!same(receipt.viewSchemaDefinitionHash, schemaHash) || !same(receipt.manifestSchemaDefinitionHash, manifestSchemaHash)
    || !same(receipt.canonicalizationDefinitionHash, canonicalizationHash)) throw Error("Declaration interpretation hashes differ");
  const manifestTuple = abi.getFunction("viewRecord")!.outputs[0]!;
  const receiptTuple = abi.getFunction("viewRecord")!.outputs[1]!;
  const encodedManifest = coder.encode(["uint256", "uint64", "bytes32", manifestTuple],
    [input.scope.collectionId, receipt.revision, receipt.previousRecordHash, manifest]) as Hex;
  const manifestPayloadHash = keccak256(encodedManifest) as Hex;
  const subject = keccak256(coder.encode(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), d.chainId, d.core.address, input.scope.collectionId, 4, input.viewId]));
  if (!same(record.recordType, id("DISPLAY_VIEW_MANIFEST")) || !same(record.subjectId, subject)
    || !same(record.schemaId, manifestSchema) || record.contentHash.algorithm !== 1n
    || !same(record.contentHash.canonicalizationId, id("RAW_BYTES")) || !same(record.contentHash.digest, manifestPayloadHash)
    || record.uri !== manifest.uri || record.signatureScheme !== ZERO || record.signatureHash.algorithm !== 0n
    || record.signatureHash.digest !== "0x" || record.signatureHash.canonicalizationId !== ZERO || record.effectiveAt !== 0n) {
    throw Error("Original declaration record differs");
  }
  const hashRef = (value: HashReference) => keccak256(coder.encode(["uint16", "bytes32", "bytes32"],
    [value.algorithm, keccak256(value.digest), value.canonicalizationId]));
  const expectedRecord = keccak256(coder.encode([
    "bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"
  ], [id("6529stream.preservation-record.v2"), d.chainId, d.views.address, d.core.address, receipt.recorder,
    input.scope.collectionId, record.recordType, record.subjectId, hashRef(record.contentHash), keccak256(toUtf8Bytes(record.uri)),
    record.schemaId, ZERO, hashRef(record.signatureHash), 0n]));
  if (!same(expectedRecord, input.viewRecordHash)
    || !same(await read(provider, d.views.address, "recordHashAt", [input.scope.collectionId, receipt.recordIndex], tag), input.viewRecordHash)) {
    throw Error("Original declaration record hash differs");
  }
  const [manifestPointer, savedManifest] = await rpc(provider, d.views.address, abi, "manifestPayload", [input.viewRecordHash], tag);
  if (!same(savedManifest, encodedManifest)) throw Error("Manifest payload differs");
  await carrier(provider, address(manifestPointer), manifestPayloadHash, BigInt((encodedManifest.length - 2) / 2), tag);
  const [pointer, saved] = await rpc(provider, d.views.address, abi, "viewPayload", [input.viewRecordHash], tag);
  const payloadBytes = bytes(saved, 40960);
  const payload = view.validateTaggedPolicyViewV2PayloadAdmission(view.decodeTaggedPolicyViewV2Payload(payloadBytes));
  const payloadHash = keccak256(payloadBytes) as Hex;
  if (!same(payloadHash, manifest.contentHash)) throw Error("VIEW payload hash differs");
  const payloadPointers = Array<Address>(5).fill(ZERO_ADDRESS);
  const payloadChunkHashes = Array<Hex>(5).fill(ZERO);
  const length = (payloadBytes.length - 2) / 2;
  for (let i = 0; i < Math.ceil(length / 8192); i++) {
    const chunk = `0x${payloadBytes.slice(2 + i * 16384, 2 + Math.min(length, (i + 1) * 8192) * 2)}` as Hex;
    const digest = keccak256(chunk) as Hex;
    const [location, size] = await rpc(provider, d.store.address, abi, "chunk", [digest], tag);
    const original = await carrier(provider, address(location), digest, uint(size, 32), tag);
    if (!same(original, chunk)) throw Error("VIEW chunk differs");
    payloadPointers[i] = address(location);
    payloadChunkHashes[i] = digest;
  }
  if (!same(pointer, payloadPointers[0])) throw Error("VIEW first carrier differs");
  return {
    declaration: { manifest, receipt, record }, payload,
    source: { schemaHash, manifestSchemaHash, canonicalizationHash, manifestPayloadHash,
      viewReceiptHash: keccak256(coder.encode([receiptTuple], [receipt])) as Hex,
      payloadHash, payloadBytes: BigInt(length),
      payloadPointers: payloadPointers as [Address, Address, Address, Address, Address],
      payloadChunkHashes: payloadChunkHashes as [Hex, Hex, Hex, Hex, Hex] }
  };
}

async function renderer(provider: Reader, d: TaggedPolicyViewV2Deployment,
  input: view.TaggedPolicyViewV2Input, tag: number) {
  if (!same(input.rendererRegistry, d.rendererRegistry.address)) throw Error("Renderer registry differs");
  if (await read(provider, d.renderer.address, "supportsInterface", ["0x2b6ffc1e"], tag) !== true) {
    throw Error("Original V2 renderer capability unavailable");
  }
  const version = await read<RendererVersion>(provider, d.rendererRegistry.address, "version", [input.rendererVersionKey], tag);
  if (!version.exists || version.deprecated || !same(version.renderer, d.renderer.address)
    || !same(version.runtimeHash, d.renderer.codeHash) || version.registrationHash === ZERO || version.readSetHash === ZERO) {
    throw Error("Renderer version unavailable");
  }
  const registration = await read<{ renderer: Address; manifest: RendererManifest }>(provider,
    d.rendererRegistry.address, "registration", [input.rendererVersionKey], tag);
  const manifest = await read<RendererManifest>(provider, d.renderer.address, "rendererManifest", [], tag);
  equal(registration.manifest, manifest, "Renderer manifest differs");
  if (!same(registration.renderer, d.renderer.address) || !same(manifest.rendererClass, id("STATIC"))
    || manifest.deprecated || !same(manifest.contextVersion, view.TAGGED_POLICY_VIEW_V2_CONTEXT)
    || !same(manifest.schemaHash, view.TAGGED_POLICY_VIEW_V2_OUTPUT_SCHEMA_HASH)
    || !same(input.rendererVersionKey, keccak256(coder.encode(["bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_RENDERER_VERSION_V1"), manifest.rendererId, manifest.rendererVersion])))) {
    throw Error("Renderer interpretation differs");
  }
  const assigned = await rpc(provider, d.rendererRegistry.address, abi, "requireAssignable", [input.rendererVersionKey], tag);
  equal(assigned, [d.renderer.address, d.renderer.codeHash], "Assignable renderer differs");
  const sources = await rpc(provider, d.renderer.address, abi, "sourceBindings", [], tag);
  equal(sources, [[d.core.address, d.router.address, d.sourceSet.address, d.liveAttribution.address],
    [d.core.codeHash, d.router.codeHash, d.sourceSet.codeHash, d.liveAttribution.codeHash]], "Renderer source bindings differ");
  equal(await rpc(provider, d.renderer.address, abi, "encodingBinding", [], tag),
    [d.encoding.address, d.encoding.codeHash], "Compiler-linked formatter differs");
  const targetCount = uint(await read(provider, d.rendererRegistry.address, "targetCount", [], tag));
  if (targetCount > 128n) throw Error("Renderer target limit exceeded");
  const targets: unknown[] = [];
  for (let index = 0n; index < targetCount; index++) {
    const target = await read<TaggedPolicyViewV2CodePin & { target: Address }>(provider, d.rendererRegistry.address, "targetAt", [index], tag);
    targets.push(target);
  }
  const reads = await read<readonly { targetIndex: bigint }[]>(provider, d.rendererRegistry.address, "reads", [input.rendererVersionKey], tag);
  if (reads.length > 128 || reads.some(row => row.targetIndex >= targetCount)) throw Error("Renderer read roster exceeds bounds");
  return {
    selection: view.normalizeTaggedPolicyViewV2Selection({ registry: d.rendererRegistry.address,
      registryCodeHash: d.rendererRegistry.codeHash, versionKey: input.rendererVersionKey,
      renderer: d.renderer.address, rendererCodeHash: d.renderer.codeHash, rendererId: manifest.rendererId,
      rendererVersion: manifest.rendererVersion, contextVersion: manifest.contextVersion, schemaHash: manifest.schemaHash,
      readSetHash: version.readSetHash, registrationHash: version.registrationHash }),
    registration, reads, targets
  };
}

async function policySource(provider: Reader, d: TaggedPolicyViewV2Deployment,
  input: view.TaggedPolicyViewV2Input, tag: number) {
  for (const [method, expected] of [["viewPolicySourceFactoryV2", d.policyFactory.address],
    ["viewPolicySourceFactoryV2CodeHash", d.policyFactory.codeHash]] as const) {
    if (!same(await read(provider, d.provider.address, method, [], tag), expected)) throw Error("Provider-owned policy factory differs");
  }
  const dependencies = await read<{ targets: readonly Address[]; codeHashes: readonly Hex[]; chainId: bigint;
    readGas: bigint; inventoryGas: bigint }>(provider, d.policyFactory.address, "dependencies", [], tag);
  equal(dependencies.targets, [d.core.address, d.metadata.address, d.membership.address, d.inventory.address], "Factory source roster differs");
  equal(dependencies.codeHashes, [d.core.codeHash, d.metadata.codeHash, d.membership.codeHash, d.inventory.codeHash], "Factory source runtimes differ");
  if (dependencies.chainId !== d.chainId || dependencies.readGas < 50000n || dependencies.inventoryGas < dependencies.readGas) {
    throw Error("Factory source context differs");
  }
  const binding = view.normalizeTaggedPolicyViewV2PolicyBinding(await read(provider, d.renderer.address, "policyViewBinding", [], tag));
  if (!same(binding.factory, d.policyFactory.address) || !same(binding.factoryCodeHash, d.policyFactory.codeHash)
    || !same(binding.sourceSet, d.sourceSet.address) || !same(binding.sourceSetCodeHash, d.sourceSet.codeHash)
    || !same(binding.core, d.core.address) || !same(binding.coreCodeHash, d.core.codeHash) || binding.chainId !== d.chainId) {
    throw Error("Renderer immutable policy binding differs");
  }
  equal(binding.scope, input.scope, "Policy scope differs");
  const checks: readonly [TaggedPolicyViewV2CodePin, string, unknown][] = [
    [d.policyFactory, "scopedPolicyFactoryProfile", id("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")],
    [d.policyFactory, "core", d.core.address], [d.sourceSet, "SOURCE_SET_PROFILE", id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")],
    [d.sourceSet, "factory", d.policyFactory.address], [d.sourceSet, "core", d.core.address],
    [d.sourceSet, "inventoryPlan", binding.inventoryPlan], [d.sourceSet, "originalInventoryHash", binding.inventoryHash],
    [d.sourceSet, "originalPolicyChainHash", binding.policyChainHash]
  ];
  for (const [pin, method, expected] of checks) {
    if (!same(await read(provider, pin.address, method, [], tag), expected)) throw Error(`Policy source ${method} differs`);
  }
  equal(await read(provider, d.sourceSet.address, "sourceScope", [], tag), input.scope, "Saved policy scope differs");
  equal(await rpc(provider, d.policyFactory.address, abi, "sourceSetForPlan", [binding.inventoryPlan], tag),
    [d.sourceSet.address, d.sourceSet.codeHash], "Factory plan source differs");
  if (!same(await read(provider, d.policyFactory.address, "currentInventoryPlan", [input.scope], tag), binding.inventoryPlan)) {
    throw Error("Policy inventory plan changed");
  }
  await rpc(provider, d.sourceSet.address, abi, "requireCurrentSelection", [], tag);
  const membership = view.normalizeTaggedPolicyViewV2Membership(await read(provider, d.membership.address,
    "requireScopeMembership", [input.scope], tag));
  equal(await read(provider, d.sourceSet.address, "scopeMembershipFacts", [], tag), membership, "Saved policy membership differs");
  equal(binding.membership, membership, "Renderer membership differs");
  const count = uint(await read(provider, d.sourceSet.address, "sourceCount", [], tag));
  if (count === 0n || count > 256n || count !== binding.policyCount || count > membership.tokenCount) {
    throw Error("Policy inventory exceeds finite client bound");
  }
  const progress = await read<{ exists: boolean; complete: boolean; processedTokens: bigint;
    tokenCount: bigint; coordinatorCount: bigint; commitment: Hex }>(provider, d.inventory.address,
    "requireCompleteInventory", [binding.inventoryPlan], tag);
  if (!progress.exists || !progress.complete || progress.processedTokens !== membership.tokenCount
    || progress.tokenCount !== membership.tokenCount || progress.coordinatorCount !== count
    || !same(progress.commitment, binding.inventoryHash)) throw Error("Complete original inventory differs");
  equal(await rpc(provider, d.inventory.address, abi, "inventoryScope", [binding.inventoryPlan], tag),
    [input.scope, membership], "Original inventory membership differs");
  const policies: view.TaggedPolicyViewV2CoordinatorPolicy[] = [];
  const seen = new Set<string>();
  for (let index = 0n; index < count; index++) {
    const policy = view.normalizeTaggedPolicyViewV2CoordinatorPolicy(await read(provider, d.sourceSet.address,
      "sourcePolicyAt", [index], tag));
    const original = await read<{ coordinator: Address; indexedCodeHash: Hex; firstTokenIndex: bigint }>(provider,
      d.inventory.address, "requireCoordinator", [binding.inventoryPlan, index], tag);
    equal(original, { coordinator: policy.coordinator, indexedCodeHash: policy.indexedCodeHash,
      firstTokenIndex: policy.firstTokenIndex }, "Original coordinator order differs");
    if (seen.has(policy.coordinator)) throw Error("Duplicate original coordinator");
    seen.add(policy.coordinator);
    await runtime(provider, { address: policy.coordinator, codeHash: policy.indexedCodeHash }, tag);
    if (!policy.frozen || policy.policyHash === ZERO || policy.componentDataHash === ZERO || policy.moduleVersion === ZERO
      || policy.moduleManifestHash === ZERO || policy.moduleSchemaHash === ZERO || policy.deploymentManifestHash === ZERO) {
      throw Error("Unfrozen or incomplete original policy");
    }
    const p = policy.collectionPolicy;
    if (policy.explicitPolicy) {
      if (!p.configured || !p.explicitPolicy || !p.frozen || p.mode > 2n || p.securityClass > 1n
        || p.renderRequirement > 1n || p.revision === 0n || p.policyHash !== policy.policyHash
        || p.lastActionId === ZERO || p.artistConsentRecord === ZERO || policy.provider !== ZERO_ADDRESS
        || policy.epoch !== 0n || policy.salt !== ZERO
        || !same(p.contentStateHash, keccak256(coder.encode(["bytes32", "bytes32", "bool"],
          [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, p.frozen])))) throw Error("Explicit retained policy differs");
    } else if (policy.provider === ZERO_ADDRESS || policy.epoch === 0n || policy.salt === ZERO
      || Object.values(p).some(value => value !== false && value !== 0n && value !== ZERO)) {
      throw Error("Legacy policy projection differs");
    }
    policies.push(policy);
  }
  return { binding, membership, policies, inventory: progress };
}

function coordinates(d: TaggedPolicyViewV2Deployment | TaggedPolicyViewV2HistoryDeployment): view.TaggedPolicyViewV2Coordinates {
  return { chainId: d.chainId, core: typeof d.core === "string" ? d.core : d.core.address, router: d.router.address };
}

function historyDeployment(value: TaggedPolicyViewV2HistoryDeployment): TaggedPolicyViewV2HistoryDeployment {
  keys(value, ["chainId", "core", "router", "linkedDependencies"]);
  return freeze({ chainId: uint(value.chainId), core: address(value.core), router: codePin(value.router),
    linkedDependencies: pinList(value.linkedDependencies) });
}

async function historyAt(provider: Reader, d: TaggedPolicyViewV2HistoryDeployment, key: Hex, tag: number) {
  await runtime(provider, d.router, tag);
  for (const dependency of d.linkedDependencies) await runtime(provider, dependency, tag);
  const iface = view.taggedPolicyViewV2RouterInterface();
  const saved = await rpc(provider, d.router.address, iface, "viewAdoptionCarrier", [key], tag);
  const recordCarrier = view.normalizeTaggedPolicyViewV2Carrier({ pointer: saved[0] as Address,
    contentHash: saved[1] as Hex, byteSize: saved[2] as bigint });
  const raw = await carrier(provider, recordCarrier.pointer, recordCarrier.contentHash, recordCarrier.byteSize, tag);
  const encoded = (await rpc(provider, d.router.address, iface, "viewAdoptionEncoded", [key], tag))[0];
  if (!same(encoded, raw)) throw Error("Retained record bytes differ");
  const profile = hash((await rpc(provider, d.router.address, iface, "viewAdoptionProfile", [key], tag))[0], true);
  const { record } = view.authenticateTaggedPolicyViewV2Record(coordinates(d), profile, key, raw, recordCarrier);
  return { profile, record, carrier: recordCarrier, encoded: raw };
}

export async function inspectTaggedPolicyViewV2History(provider: Reader,
  inputDeployment: TaggedPolicyViewV2HistoryDeployment, inputKey: Hex, options: { readonly blockTag: number }) {
  const d = historyDeployment(inputDeployment);
  const key = hash(inputKey);
  const tag = number(options.blockTag);
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("Wrong chain");
  const observed = await header(provider, tag);
  const result = await historyAt(provider, d, key, tag);
  await unchanged(provider, observed);
  return freeze({ ...result, observed, currentAdmission: "not-queried" as const });
}

export async function preflightTaggedPolicyViewV2(provider: Reader, inputDeployment: TaggedPolicyViewV2Deployment,
  inputCaller: Address, originalInput: view.TaggedPolicyViewV2Input, options: { readonly blockTag: number }): Promise<TaggedPolicyViewV2Preflight> {
  const d = deployment(inputDeployment);
  const caller = address(inputCaller);
  const input = view.normalizeTaggedPolicyViewV2Input(originalInput);
  const tag = number(options.blockTag);
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("Wrong chain");
  const observed = await header(provider, tag);
  const originalRoute = await route(provider, d, tag);
  if (await read(provider, d.core.address, "collectionExists", [input.scope.collectionId], tag) !== true
    || await read(provider, d.core.address, "collectionFreezeStatus", [input.scope.collectionId], tag) !== false
    || await read(provider, d.finality.address, "artworkFreezeMode", [input.scope], tag) !== 0n) throw Error("VIEW scope is unavailable or frozen");
  const activation = await rpc(provider, d.router.address, abi, "staticMetadataActivation", [input.scope.collectionId], tag);
  if (activation[0] === ZERO) throw Error("STATIC metadata has not been activated");
  equal(await rpc(provider, d.router.address, abi, "artistContentLockState", [input.scope.collectionId, FAMILY], tag),
    [true, false], "Renderer configuration is content-locked");
  const declared = await declaration(provider, d, input, observed);
  const rendererFacts = await renderer(provider, d, input, tag);
  const policy = await policySource(provider, d, input, tag);
  const source = view.normalizeTaggedPolicyViewV2Source({ route: originalRoute, membership: policy.membership,
    renderer: rendererFacts.selection, ...declared.source } as view.TaggedPolicyViewV2Source);
  const checked = view.validateTaggedPolicyViewV2Source(coordinates(d), input, source, policy.binding);
  const actualInput = view.normalizeTaggedPolicyViewV2Input({ ...input, expectedSourceHash: checked.sourceHash });
  const router = view.taggedPolicyViewV2RouterInterface();
  const head = hash((await rpc(provider, d.router.address, router, "viewAdoptionHead", [input.scope], tag))[0], true);
  if (!same(input.expectedPrevious, head)) throw Error("VIEW predecessor changed");
  let previousRevision = 0n;
  if (head !== ZERO) {
    const prior = await historyAt(provider, { chainId: d.chainId, core: d.core.address, router: d.router,
      linkedDependencies: d.linkedDependencies }, head, tag);
    equal(prior.record.input.scope, input.scope, "Predecessor belongs to another VIEW scope");
    previousRevision = prior.record.revision;
  }
  const aggregate = view.normalizeTaggedPolicyViewV2Aggregate((await rpc(provider, d.router.address, router,
    "viewAdoptionAggregate", [input.scope.collectionId], tag))[0] as view.TaggedPolicyViewV2Aggregate);
  let authority: { authorizationClass: bigint; grantCollectionId: bigint; grantRevision: bigint } | null = null;
  for (const cls of [7n, 8n]) {
    for (const cid of [input.scope.collectionId, 0n]) {
      const [enabled, revision] = await rpc(provider, d.metadata.address, abi, "familyWriter", [cid, IDENTITY_FAMILY, cls, caller], tag);
      if (enabled === true && revision !== 0n) { authority = { authorizationClass: cls, grantCollectionId: cid, grantRevision: uint(revision, 64) }; break; }
    }
    if (authority) break;
  }
  if (!authority) throw Error("Actual caller lacks original DISPLAY writer authority");
  const [familyState, sourceHash] = await rpc(provider, d.router.address, router, "previewPolicyViewAdoption", [actualInput, caller], tag, caller);
  if (!same(sourceHash, checked.sourceHash)) throw Error("Original preview source differs");
  const currentFamily = await rpc(provider, d.router.address, abi, "artistContentFamilyState", [input.scope.collectionId, FAMILY], tag);
  if (currentFamily[0] !== true) throw Error("Renderer family unsupported");
  const value = { deployment: d, caller, input: actualInput, observed, source, policyBinding: policy.binding,
    policies: policy.policies, payload: declared.payload, declaration: declared.declaration, head, previousRevision, aggregate,
    ...authority, familyStateHash: hash(familyState), currentFamilyStateHash: hash(currentFamily[1]),
    consentTerms: { collectionId: input.scope.collectionId, metadataContract: d.router.address, familyId: FAMILY, newStateHash: hash(familyState) },
    evidence: { rendererRegistration: rendererFacts.registration, rendererReads: rendererFacts.reads,
      rendererTargets: rendererFacts.targets, inventory: policy.inventory }, admission: "original-adoption-simulation-required" as const };
  await unchanged(provider, observed);
  return freeze({ ...value, preflightHash: fingerprint(value) });
}

export async function captureTaggedPolicyViewV2(provider: Reader, inputDeployment: TaggedPolicyViewV2Deployment,
  caller: Address, input: view.TaggedPolicyViewV2Input, options: { readonly blockTag: number }): Promise<TaggedPolicyViewV2Capture> {
  // preflight snapshots every caller-owned input before its first await.
  const preflight = await preflightTaggedPolicyViewV2(provider, inputDeployment, caller, input, options);
  const d = preflight.deployment;
  const tag = preflight.observed.blockNumber;
  const cid = preflight.input.scope.collectionId;
  const terms = preflight.consentTerms;
  const key = hash(await read(provider, d.artist.address, "contentConsentEvidence", [cid, FAMILY, terms.newStateHash], tag));
  const consent = await read<TaggedPolicyViewV2ConsentRecord>(provider, d.artistConsentOwner.address, "contentConsentRecord", [key], tag);
  equal(consent.terms, terms, "Stored original op17 terms differ");
  if (!same(consent.recordHash, key) || consent.artistId === ZERO || consent.bindingGeneration === 0n
    || ![1n, 3n].includes(consent.authorityClass)) throw Error("Unsupported original op17 evidence");
  equal(await read(provider, d.artistConsentOwner.address, "contentConsentAt", [terms, consent.bindingGeneration], tag),
    consent, "Current original op17 record differs");
  const binding = await rpc(provider, d.artist.address, abi, "collectionArtistState", [cid], tag);
  if (![2n, 3n].includes(binding[0] as bigint) || binding[1] !== consent.bindingGeneration
    || !same(binding[2], consent.artistId) || binding[4] === ZERO) throw Error("Artist binding generation differs");
  if (await read(provider, d.router.address, "consumedArtistContentConsent", [key], tag) !== false) {
    throw Error("Original op17 consent already consumed");
  }
  const current = await rpc(provider, d.router.address, abi, "currentArtistContentState", [cid], tag);
  if (!same(current[0], d.router.address)) throw Error("Current content host differs");
  const currentContentStateHash = hash(current[1]);
  const ratificationRaw = await rpc(provider, d.artist.address, abi, "firstReleaseRatification", [cid], tag);
  const ratification = [ratificationRaw[0] as boolean, hash(ratificationRaw[1], true), hash(ratificationRaw[2], true)] as const;
  const evolutionRaw = await rpc(provider, d.router.address, abi, "artistContentEvolution", [cid], tag);
  const evolution = [hash(evolutionRaw[0], true), hash(evolutionRaw[1], true)] as const;
  if (ratification[0] && (ratification[2] === ZERO || (!same(currentContentStateHash, ratification[1])
    && (!same(evolution[0], ratification[2]) || !same(evolution[1], currentContentStateHash))))) {
    throw Error("Artist content evolution is broken");
  }
  const prepared = view.prepareTaggedPolicyViewV2Call(coordinates(d), preflight.caller,
    { kind: "adoptPolicyView", input: preflight.input });
  const result = { preflight, consent, currentContentStateHash, ratification, evolution, prepared };
  await unchanged(provider, preflight.observed);
  return freeze({ ...result, captureHash: fingerprint(result) });
}

function snapshotCapture(value: TaggedPolicyViewV2Capture): TaggedPolicyViewV2Capture {
  const snapshot = structuredClone(value);
  keys(snapshot, ["preflight", "consent", "currentContentStateHash", "ratification", "evolution", "prepared", "captureHash"]);
  const { captureHash, ...body } = snapshot;
  if (!same(fingerprint(body), captureHash)) throw Error("Captured facts changed");
  const { preflightHash, ...preflightBody } = snapshot.preflight;
  if (!same(fingerprint(preflightBody), preflightHash)) throw Error("Preflight changed");
  const prepared = view.normalizeTaggedPolicyViewV2Call(snapshot.prepared);
  equal(prepared, view.prepareTaggedPolicyViewV2Call(coordinates(snapshot.preflight.deployment), snapshot.preflight.caller,
    { kind: "adoptPolicyView", input: snapshot.preflight.input }), "Prepared call does not match captured VIEW");
  return freeze(snapshot);
}

function comparable(value: TaggedPolicyViewV2Capture): unknown {
  const { observed: _observed, preflightHash: _preflightHash, ...preflight } = value.preflight;
  const { captureHash: _captureHash, preflight: _old, ...rest } = value;
  return { preflight, ...rest };
}

async function revalidate(provider: Reader, saved: TaggedPolicyViewV2Capture, tag: number): Promise<TaggedPolicyViewV2Capture> {
  const p = saved.preflight;
  await unchanged(provider, p.observed);
  const current = await captureTaggedPolicyViewV2(provider, p.deployment, p.caller, p.input, { blockTag: tag });
  equal(comparable(current), comparable(saved));
  return current;
}

function gas(value: bigint): bigint {
  const result = uint(value);
  if (result === 0n || result > 100_000_000n) throw Error("Gas limit outside finite client bound");
  return result;
}

function expectedRecord(capture: TaggedPolicyViewV2Capture, timestamp: bigint): view.TaggedPolicyViewV2Record {
  if (timestamp === 0n) throw Error("Original adoption requires a nonzero timestamp");
  const p = capture.preflight;
  const draft = view.normalizeTaggedPolicyViewV2Record({ input: p.input, source: p.source,
    sourceHash: p.input.expectedSourceHash, recordHash: ZERO, revision: uint(p.previousRevision + 1n, 64),
    actor: p.caller, authorizationClass: p.authorizationClass, grantCollectionId: p.grantCollectionId,
    grantRevision: p.grantRevision, artistConsent: capture.consent.recordHash,
    adoptedAt: uint(timestamp, 64), aggregate: p.aggregate });
  const next = { ...draft, aggregate: view.taggedPolicyViewV2NextAggregate(coordinates(p.deployment), p.aggregate, draft) };
  return view.normalizeTaggedPolicyViewV2Record({ ...next,
    recordHash: view.taggedPolicyViewV2RecordHash(coordinates(p.deployment), next) });
}

export interface TaggedPolicyViewV2Simulation {
  readonly capture: TaggedPolicyViewV2Capture;
  readonly observed: TaggedPolicyViewV2Block;
  readonly gasLimit: bigint;
  readonly recordHash: Hex;
  readonly admission: "original-router-eth-call";
}

export async function simulateTaggedPolicyViewV2(provider: Reader, inputCapture: TaggedPolicyViewV2Capture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }): Promise<TaggedPolicyViewV2Simulation> {
  const saved = snapshotCapture(inputCapture);
  const tag = number(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.preflight.observed.blockNumber) throw Error("Simulation precedes capture");
  await revalidate(provider, saved, saved.preflight.observed.blockNumber);
  const capture = await revalidate(provider, saved, tag);
  const iface = view.taggedPolicyViewV2RouterInterface();
  const raw = bytes(await provider.call({ ...capture.prepared.call, from: capture.prepared.caller, gasLimit, blockTag: tag }));
  const result = iface.decodeFunctionResult("adoptPolicyView", raw);
  if (!same(iface.encodeFunctionResult("adoptPolicyView", result), raw)) throw Error("Noncanonical adoption simulation");
  const recordHash = hash(result[0]);
  if (!same(recordHash, expectedRecord(capture, capture.preflight.observed.timestamp).recordHash)) {
    throw Error("Original simulation record hash differs");
  }
  await unchanged(provider, capture.preflight.observed);
  return freeze({ capture, observed: capture.preflight.observed, gasLimit, recordHash, admission: "original-router-eth-call" as const });
}

/** The returned equality is an RPC observation at one block, not native rollback evidence. */
export async function observeTaggedPolicyViewV2Refusal(provider: Reader, inputCapture: TaggedPolicyViewV2Capture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = snapshotCapture(inputCapture);
  const tag = number(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.preflight.observed.blockNumber) throw Error("Refusal observation precedes capture");
  const d = saved.preflight.deployment;
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("Wrong chain");
  await unchanged(provider, saved.preflight.observed);
  const observed = await header(provider, tag);
  const retained = async () => ({
    head: (await rpc(provider, d.router.address, view.taggedPolicyViewV2RouterInterface(), "viewAdoptionHead", [saved.preflight.input.scope], tag))[0],
    aggregate: (await rpc(provider, d.router.address, view.taggedPolicyViewV2RouterInterface(), "viewAdoptionAggregate", [saved.preflight.input.scope.collectionId], tag))[0],
    consentConsumed: await read(provider, d.router.address, "consumedArtistContentConsent", [saved.consent.recordHash], tag)
  });
  await runtime(provider, d.router, tag);
  for (const dependency of d.linkedDependencies) await runtime(provider, dependency, tag);
  const before = await retained();
  let failure: unknown;
  try {
    await provider.call({ ...saved.prepared.call, from: saved.prepared.caller, gasLimit, blockTag: tag });
  } catch (error) { failure = error; }
  if (failure === undefined) throw Error("Original call did not refuse");
  const after = await retained();
  await unchanged(provider, observed);
  const outcome = failure && typeof failure === "object" && "code" in failure && failure.code === "CALL_EXCEPTION"
    ? "execution-reverted" as const : "rpc-failed" as const;
  return Object.freeze({ observed, before: freeze(before), after: freeze(after), unchanged: stable(before) === stable(after),
    outcome, error: failure, evidence: "same-block-rpc-observation-only" as const });
}

export type TaggedPolicyViewV2RenderSelection = Readonly<
  { kind: "tokenJSONForView" | "tokenHTMLForView"; tokenId: bigint; scopeId: Hex }
  | { kind: "historicalTokenJSONForView" | "historicalTokenHTMLForView"; tokenId: bigint; recordHash: Hex }
>;

export async function renderTaggedPolicyViewV2(provider: Reader, inputDeployment: TaggedPolicyViewV2ServingDeployment,
  inputCaller: Address, inputRequest: TaggedPolicyViewV2RenderSelection, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  keys(inputDeployment, ["chainId", "core", "coreCodeHash", "router", "linkedDependencies"]);
  const { coreCodeHash: originalHash, ...history } = inputDeployment;
  const d = historyDeployment(history);
  const coreCodeHash = hash(originalHash);
  const caller = address(inputCaller, true);
  const request = structuredClone(inputRequest);
  const tag = number(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  const prepared = view.prepareTaggedPolicyViewV2Read(coordinates(d), caller, request);
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("Wrong chain");
  const observed = await header(provider, tag);
  await runtime(provider, d.router, tag);
  await runtime(provider, { address: d.core, codeHash: coreCodeHash }, tag);
  for (const dependency of d.linkedDependencies) await runtime(provider, dependency, tag);
  const token = await rpc(provider, d.core, abi, "tokenCollectionIdentity", [request.tokenId], tag);
  const historical = request.kind.startsWith("historical");
  if (token[0] !== true || (!historical && token[3] === true)) throw Error("Token unavailable for this serving route");
  const lifecycle = await read(provider, d.core, "tokenLifecycle", [request.tokenId], tag);
  if (lifecycle !== (token[3] === true ? 3n : 2n)) throw Error("Token mint is not complete");
  const iface = view.taggedPolicyViewV2RouterInterface();
  const recordHash = "recordHash" in request ? hash(request.recordHash) : hash((await rpc(provider, d.router.address, iface,
    "viewAdoptionHead", [{ scopeType: 4n, collectionId: token[1], tokenId: 0n, scopeId: request.scopeId }], tag))[0]);
  const retained = await historyAt(provider, d, recordHash, tag);
  if (retained.record.input.scope.collectionId !== token[1]) throw Error("VIEW record collection differs");
  if ("scopeId" in request && !same(retained.record.input.scope.scopeId, request.scopeId)) {
    throw Error("Current VIEW head belongs to another scope");
  }
  const raw = bytes(await provider.call({ ...prepared.call, from: caller, gasLimit, blockTag: tag }), 262208);
  const decoded = iface.decodeFunctionResult(request.kind, raw);
  if (!same(iface.encodeFunctionResult(request.kind, decoded), raw)) throw Error("Noncanonical rendered output");
  const output = decoded[0] as string;
  if (toUtf8Bytes(output).length > 262144) throw Error("Rendered output exceeds original bound");
  await unchanged(provider, observed);
  return freeze({ observed, request, output, retained, evidence: "original-router-serving-call" as const });
}

const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);

export type TaggedPolicyViewV2ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex }
>;

interface CopiedLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

async function transport(provider: ReceiptReader, saved: TaggedPolicyViewV2Capture,
  transactionHash: Hex, options: TaggedPolicyViewV2ReceiptOptions) {
  const raw = await provider.getTransactionReceipt(transactionHash);
  if (!raw || raw.status !== 1 || !same(raw.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = number(raw.blockNumber);
  const blockHash = hash(raw.blockHash);
  const from = address(raw.from);
  const to = address(raw.to);
  if (blockNumber <= saved.preflight.observed.blockNumber) throw Error("Receipt must follow captured block");
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
    || tx.chainId !== saved.preflight.deployment.chainId) throw Error("Transaction envelope differs");
  const data = bytes(tx.data, MAX_CALL + 16384);
  const call = saved.prepared.call;
  const caller = saved.prepared.caller;
  if (tx.value !== 0n) throw Error("Outer value must be zero");
  let safeIndex = -1;
  if (options.execution === "direct") {
    if (!same(from, caller) || !same(to, call.to) || !same(data, call.data)) throw Error("Direct caller/target/data differs");
  } else {
    if (!same(to, caller)) throw Error("Safe is not the actual adoption caller");
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

function event(logs: readonly CopiedLog[], target: Address, name: string, expected: Record<string, unknown>) {
  const fragment = abi.getEvent(name)!;
  const rows = logs.filter(log => same(log.address, target) && same(log.topics[0], fragment.topicHash));
  if (rows.length !== 1) throw Error(`Expected exactly one ${name}`);
  const row = rows[0]!;
  const decoded = abi.decodeEventLog(fragment, row.data, [...row.topics]);
  const encoded = abi.encodeEventLog(fragment, decoded);
  equal(encoded.topics.map(topic => topic.toLowerCase()), row.topics, `${name} topics differ`);
  if (!same(encoded.data, row.data)) throw Error(`Noncanonical ${name}`);
  const fields = Object.fromEntries(fragment.inputs.map((param, index) => [param.name, plain(param, decoded[index])]));
  for (const [key, value] of Object.entries(expected)) equal(fields[key], value, `${name}.${key} differs`);
  return { index: row.index, fields };
}

export async function reconcileTaggedPolicyViewV2Receipt(provider: ReceiptReader, inputCapture: TaggedPolicyViewV2Capture,
  inputTransactionHash: Hex, inputOptions: TaggedPolicyViewV2ReceiptOptions) {
  const saved = snapshotCapture(inputCapture);
  const transactionHash = hash(inputTransactionHash);
  if (inputOptions.execution !== "direct" && inputOptions.execution !== "safe") throw Error("Unknown execution transport");
  keys(inputOptions, inputOptions.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const options: TaggedPolicyViewV2ReceiptOptions = inputOptions.execution === "safe"
    ? { execution: "safe", expectedSafeTxHash: hash(inputOptions.expectedSafeTxHash) } : { execution: "direct" };
  const t = await transport(provider, saved, transactionHash, options);
  await revalidate(provider, saved, saved.preflight.observed.blockNumber);
  const prior = await revalidate(provider, saved, t.observed.blockNumber - 1);
  const p = prior.preflight;
  const d = p.deployment;
  const tag = t.observed.blockNumber;
  await runtime(provider, d.router, tag);
  await runtime(provider, d.store, tag);
  await runtime(provider, d.artistConsentOwner, tag);
  for (const dependency of d.linkedDependencies) await runtime(provider, dependency, tag);
  const expected = expectedRecord(prior, t.observed.timestamp);
  const adopted = event(t.logs, d.router.address, "ViewAdopted", { schemaVersion: 2n,
    profile: view.TAGGED_POLICY_VIEW_V2_PROFILE, collectionId: p.input.scope.collectionId,
    scopeSubject: view.taggedPolicyViewV2ScopeSubject(coordinates(d), p.input.scope), recordHash: expected.recordHash, record: expected });
  const stored = await historyAt(provider, { chainId: d.chainId, core: d.core.address, router: d.router,
    linkedDependencies: d.linkedDependencies }, expected.recordHash, tag);
  equal(stored.record, expected, "Recorded VIEW adoption differs");
  if (!same(stored.profile, view.TAGGED_POLICY_VIEW_V2_PROFILE)) throw Error("Stored profile tag differs");
  const current = await rpc(provider, d.router.address, abi, "currentArtistContentState", [p.input.scope.collectionId], tag);
  if (!same(current[0], d.router.address)) throw Error("Post-write content host differs");
  const application = event(t.logs, d.router.address, "ArtistContentConsentApplied", { collectionId: p.input.scope.collectionId,
    familyId: FAMILY, consentRecordHash: prior.consent.recordHash, resultingContentStateHash: hash(current[1]), schemaVersion: 1n });
  if (application.index >= adopted.index || (t.safeIndex >= 0 && t.safeIndex <= adopted.index)) throw Error("Adoption event ordering differs");
  const router = view.taggedPolicyViewV2RouterInterface();
  if (!same((await rpc(provider, d.router.address, router, "viewAdoptionHead", [p.input.scope], tag))[0], expected.recordHash)) {
    throw Error("End-block VIEW head differs");
  }
  equal((await rpc(provider, d.router.address, router, "viewAdoptionAggregate", [p.input.scope.collectionId], tag))[0], expected.aggregate,
    "End-block VIEW aggregate differs");
  equal(await rpc(provider, d.router.address, abi, "artistContentFamilyState", [p.input.scope.collectionId, FAMILY], tag),
    [true, p.familyStateHash], "Post-write family state differs");
  if (await read(provider, d.router.address, "consumedArtistContentConsent", [prior.consent.recordHash], tag) !== true) {
    throw Error("Original op17 was not consumed");
  }
  equal(await read(provider, d.artistConsentOwner.address, "contentConsentRecord", [prior.consent.recordHash], tag),
    prior.consent, "Original op17 evidence changed");
  if (prior.ratification[0]) equal(await rpc(provider, d.router.address, abi, "artistContentEvolution", [p.input.scope.collectionId], tag),
    [prior.ratification[2], hash(current[1])], "Ratification continuity differs");
  const chunk = await rpc(provider, d.store.address, abi, "chunk", [stored.carrier.contentHash], tag);
  equal(chunk, [stored.carrier.pointer, stored.carrier.byteSize], "Stored record chunk differs");
  const published = t.logs.filter(log => same(log.address, d.store.address)
    && same(log.topics[0], abi.getEvent("ChunkPublished")!.topicHash) && same(log.topics[1], stored.carrier.contentHash));
  if (published.length > 1) throw Error("Duplicate record publication");
  if (published.length === 1) {
    const e = event(published, d.store.address, "ChunkPublished", { hash: stored.carrier.contentHash,
      pointer: stored.carrier.pointer, length: stored.carrier.byteSize });
    if (e.index >= application.index) throw Error("Record publication follows application");
  } else {
    equal(await rpc(provider, d.store.address, abi, "chunk", [stored.carrier.contentHash], tag - 1), chunk,
      "Eventless publication needs retained prior-block evidence");
    await carrier(provider, stored.carrier.pointer, stored.carrier.contentHash, stored.carrier.byteSize, tag - 1);
  }
  await unchanged(provider, t.observed);
  return freeze({ transactionHash, observed: t.observed, record: expected, profile: stored.profile,
    carrier: stored.carrier, consent: prior.consent, contentStateHash: hash(current[1]),
    attribution: "exact-prior-and-end-block-observation" as const });
}
