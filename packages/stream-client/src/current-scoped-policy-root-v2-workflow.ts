import {
  AbiCoder, Interface, ParamType, ZeroAddress as ETH_ZERO_ADDRESS, ZeroHash as ETH_ZERO_HASH,
  getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { CurrentArtistDeployment, CurrentArtistBinding, CurrentArtistAuthority, CurrentArtistReplay } from "./current-artist-workflow.js";
import { requireSafeExecution } from "./safe.js";
import * as root from "./current-scoped-policy-root-v2.js";
import * as pub from "./current-scoped-policy-publication-v2.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import { inspectScopedPolicyPublicationV2History } from "./current-scoped-policy-publication-v2-workflow.js";
import { ARTIST_RECOVERY_NOTICE_TUPLE, ARTIST_RECOVERY_TERMINAL_TUPLE } from "./current-artist-recovery-adjudication.js";

type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
export interface ScopedPolicyRootV2CodePin { readonly address: Address; readonly codeHash: Hex }
export interface ScopedPolicyRootV2Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
/** Pins require reviewed release/link metadata; caller-supplied hashes do not prove source. */
export interface ScopedPolicyRootV2Deployment {
  readonly chainId: bigint;
  readonly core: ScopedPolicyRootV2CodePin;
  readonly router: ScopedPolicyRootV2CodePin;
  readonly metadata: ScopedPolicyRootV2CodePin;
  readonly finality: ScopedPolicyRootV2CodePin;
  readonly provider: ScopedPolicyRootV2CodePin;
  readonly artist: CurrentArtistDeployment;
  readonly linkedDependencies: {
    readonly root: readonly ScopedPolicyRootV2CodePin[];
    readonly snapshot: readonly ScopedPolicyRootV2CodePin[];
    readonly artist: readonly ScopedPolicyRootV2CodePin[];
  };
}
export interface ScopedPolicyRootV2HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly artistRegistry: Address;
  readonly router: ScopedPolicyRootV2CodePin;
  readonly linkedDependencies: readonly ScopedPolicyRootV2CodePin[];
}
const ZERO = ETH_ZERO_HASH as Hex;
const ZERO_ADDRESS = ETH_ZERO_ADDRESS as Address;
const coder = AbiCoder.defaultAbiCoder();
const MAX_RPC = 2_097_152;
const MAX_CALL = 65_536;
const MAX_RUNTIME = 131_072;
const MAX_LOGS = 4096;
const FAMILY = id("CONTENT_ROOT") as Hex;
const SNAPSHOT_FAMILY = id("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1") as Hex;
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(v => id(`domain:${v}`) as Hex);
const SNAPSHOT = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const BINDING = "(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const TERMS = "(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const AUTH = "(uint256 nonce,uint64 time,bytes signature)";
const PROOF = "(address signer,bytes32 digest,bool direct)";
const NATIVE = "(uint16 operation,bytes32 artistId,uint256 collectionId,bytes32 recordHash)";

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

function codePin(value: ScopedPolicyRootV2CodePin): ScopedPolicyRootV2CodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function pinList(value: readonly ScopedPolicyRootV2CodePin[]): readonly ScopedPolicyRootV2CodePin[] {
  if (!Array.isArray(value) || value.length > 256) throw Error("Linked dependency limit exceeded");
  const pins = value.map(codePin);
  if (new Set(pins.map(pin => pin.address)).size !== pins.length) throw Error("Duplicate linked dependency");
  return pins;
}

async function header(provider: Reader, tag: number): Promise<ScopedPolicyRootV2Block> {
  const value = await provider.getBlock(number(tag));
  if (!value || value.number !== tag) throw Error("Missing or mismatched block");
  return { blockNumber: tag, blockHash: hash(value.hash), timestamp: BigInt(number(value.timestamp)) };
}

async function unchanged(provider: Reader, block: ScopedPolicyRootV2Block): Promise<void> {
  equal(await header(provider, block.blockNumber), block, "Pinned block changed");
}

async function runtime(provider: Reader, pin: ScopedPolicyRootV2CodePin, tag: number): Promise<void> {
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

const routeAbi = new Interface([
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function collectionExists(uint256 collectionId) view returns (bool)",
  "function collectionFreezeStatus(uint256 collectionId) view returns (bool)",
  "function collectionMintedEver(uint256 collectionId) view returns (uint256)",
  "function core() view returns (address)",
  "function artistRegistry() view returns (address)",
  "function scopedContentRootHead((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)) view returns (bytes32)",
  "function scopedContentRootRecord(bytes32) view returns ((((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 expectedPredecessor, bytes32 snapshotRecordHash, uint64 snapshotRevision, string manifestURI) publication, address snapshotHost, bytes32 snapshotCodeHash, bytes32 snapshotManifestHash, bytes32 snapshotSourceHash, bytes32 contentRoot, uint64 leafCount, bytes32 outputManifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt))",
  "function scopedContentRootAggregate(uint256 collectionId) view returns ((uint64 revision, bytes32 transitionChain))",
  "function scopedTokenContentRoot((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)) view returns (bytes32, uint64, bytes32)",
  "function scopedPolicyContentRootBinding(bytes32 recordHash) view returns ((bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash))",
  "function collectionContentRootHead(uint256 collectionId) view returns (bytes32)",
  "function contentRootRecord(bytes32 hash) view returns (((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt))",
  "function artistContentFamilyState(uint256 collectionId, bytes32 familyId) view returns (bool supported, bytes32 currentStateHash)",
  "function currentArtistContentState(uint256 collectionId) view returns (address metadataContract, bytes32 contentStateHash)",
  "function artistContentEvolution(uint256 collectionId) view returns (bytes32, bytes32)",
  "function consumedArtistContentConsent(bytes32) view returns (bool)",
  "function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account) view returns (bool, uint64)",
  "function coreReads() view returns (address)",
  "function sanctionReads() view returns (address)",
  "function scopeEvidenceProvider() view returns (address)",
  "function scopeEvidenceProviderCodeHash() view returns (bytes32)",
  "function metadataReads() view returns (address)",
  "function artworkFreezeMode((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint8)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function metadataHost() view returns (address)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function scopedPolicySnapshotHost((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (address)",
  "function scopedPolicySnapshotCodeHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function scopedPolicySnapshotValidationGas((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function scopedPolicySnapshotProfile() pure returns (bytes32)",
  "function scopedContentRoot((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32, uint64, bytes32)",
  "function finalityRegistry() view returns (address)",
  "function finalityRegistryCodeHash() view returns (bytes32)",
  "function collectionArtistState(uint256 collectionId) view returns (uint8 attributionState, uint64 bindingGeneration, bytes32 artistId, uint8 authorityStatus, bytes32 bindingHash)",
  "function contentConsentEvidence(uint256 collectionId, bytes32 familyId, bytes32 newStateHash) view returns (bytes32)",
  "function firstReleaseRatification(uint256 collectionId) view returns (bool, bytes32, bytes32)",
  "function document(bytes32 id) view returns ((bool exists, uint8 status, bytes32 declarationHash, (string name, uint8 kind, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, string uri, uint32 totalBytes) specification, bytes32[] chunkHashes))",
  "function documentBytes(bytes32 id) view returns (bytes payload)"
]);

const artistAbi = new Interface([
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
  "function operationCoordinator() view returns (address)",
  "function artistRegistryCutover() view returns (bool, address, uint64)",
  "function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce) view returns ((bool digestObserved, bool digestRevoked, bool nonceConsumed, bool nonceRevoked, uint256 nextUnusedNonce))",
  "function gasParameterInfo(bytes32 parameterId) view returns (uint256 value, uint256 floor, uint8 failureClass, uint64 revision)",
  "function collectionArtistState(uint256 collectionId) view returns (uint8 attributionState, uint64 bindingGeneration, bytes32 artistId, uint8 authorityStatus, bytes32 bindingHash)",
  "function contentConsentDigest((uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) p, (uint256 nonce, uint64 time, bytes signature) a) view returns (bytes32)",
  "function suiteConfiguration() view returns ((address registry, address archive, address[7] owners, address core, address mintManager, address roleRegistry, address metadata, address primaryResolver, address royaltyResolver, bytes32 primaryRevenueClass, address validator))",
  "function configurationHash() view returns (bytes32)",
  "function reads() view returns (address)",
  "function deploymentChainId() view returns (uint256)",
  "function artistRegistry() view returns (address)",
  "function archiveV2() view returns (address)",
  "function domainId() view returns (bytes32)",
  "function ownerStateSnapshotV2() view returns ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip))",
  "function binding(uint256 collectionId) view returns ((bytes32 artistId, address artistAddress, bytes32 identityRecordHash, bytes32 bindingHash, uint64 generation, uint8 consentMode, uint8 saleConsentScope, uint8 registryImmutabilityElection, address proposer, bool accepted))",
  "function bindingTerms(uint256 collectionId, uint64 generation) view returns ((bytes32 collaboratorSetHash, bytes32 capabilityPolicySetHash, uint8 mode, uint32 threshold, uint32 count))",
  "function acceptedCount(bytes32 bindingHash) view returns (uint32)",
  "function attributionState(uint256 collectionId) view returns (uint8, uint64)",
  "function authorityState(bytes32 artistId) view returns (address authorityAddress, uint8 authorityClass, uint8 status, bytes32 identityRecordHash)",
  "function currentAuthorityCapabilities(bytes32 artistId) view returns ((address authorityAddress, uint8 authorityClass, uint8 status, uint32 effectiveCapabilities, bytes32 activationRecordHash))",
  "function replayCell(bytes32 key) view returns ((bytes32 commitment, uint64 touchedRevision, uint8 kind, uint8 status))",
  "function signatureBundle(bytes32 recordHash) view returns (bytes)",
  "function dormancyNotice(bytes32 id) view returns (bytes32, uint8, bytes32)",
  "function estateActivationState(bytes32 artistId) view returns (address successor, uint64 noticeEndsAt, bytes32 activationRecordHash)",
  "function dormancyRecord(bytes32 n) view returns ((bytes32 recordHash, (bytes32 artistId, bytes32 evidenceHash, string reasonURI) terms, address incumbent, uint64 initiatedAt, uint64 noticeEndsAt, uint64 inactivitySeconds, uint64 noticeSeconds, uint64 timingRevision, uint64 priorLivenessAt, uint256 priorActivity, bytes32 actionId, bytes32 witnessHash), uint8, (bytes32 recordHash, bytes32 noticeHash, address actor, uint8 authorityClass, uint64 observedAt, uint64 appointmentBlock, (address authority, uint8 authorityClass, uint32 capabilities, bytes32 designation, bytes32 directive, bytes32 guardian, bytes32 stewardGrantRecordHash, uint64 postSeconds, uint64 standingTail) plan, bytes32 evidenceHash, bytes32 actionId, bytes32 witnessHash, uint64 delegationEpoch))",
  "function artistNativeReceiptRevisionAt(uint256 index) view returns (uint64)",
  "function artistNativeReceiptCount() view returns (uint256)",
  "function artistNativeReceiptAt(uint256 index) view returns ((uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash))",
  "function storedPayloadCount() view returns (uint256)",
  "function storedPayloadAt(uint256 index) view returns (address pointer, bytes32 payloadType, bytes32 payloadHash)",
  "function contentConsentRecord(bytes32 recordHash) view returns ((bytes32 recordHash, bytes32 artistId, uint64 bindingGeneration, (uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) terms, uint8 authorityClass))",
  "function contentConsentAt((uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) p, uint64 generation) view returns ((bytes32 recordHash, bytes32 artistId, uint64 bindingGeneration, (uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) terms, uint8 authorityClass))",
  "function artistEvidenceMetadataV2(bytes32 evidenceId, uint64 evidenceVersion) view returns (bytes32 contentHash, address pointer, uint32 payloadSize, uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32 evidenceId, uint64 evidenceVersion) view returns (bytes evidence)"
]);

const eventAbi = new Interface([
  "event ArtistEstateActivationCancelled(uint16 schemaVersion, bytes32 indexed artistId, address indexed canceller, uint8 authorityClass, bytes32 activationRecordHash)",
  "event ArtistUnavailabilityActivityRecorded(uint16 schemaVersion, bytes32 indexed artistId, address indexed signer, uint8 authorityClass, uint16 operationId, uint256 previousEpoch, uint256 nextEpoch)",
  "event ArtistContentConsentRecorded(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed familyId, address indexed signer, bytes32 newStateHash, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 consentRecordHash)",
  "event ArtistContentRecordContext(uint16 schemaVersion, bytes32 indexed recordHash, address metadataContract, bytes32 artistId)",
  "event ArtistStoredPayload(uint16 schemaVersion, uint256 indexed index, bytes32 indexed payloadType, bytes32 indexed payloadHash, address pointer)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId, uint64 indexed evidenceVersion, bytes32 indexed contentHash, address pointer, uint256 payloadSize)",
  "event ArtistDormancyCancelled(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed noticeHash, address canceller, uint8 authorityClass, bytes32 cancellationHash)",
  "event ArtistDormancyCancellationContext(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed recordHash, (uint256 chainId, address registry, address identityOwner, address recorder, uint8 recorderAuthorityClass) context, (bytes32 recordHash, bytes32 noticeHash, address actor, uint8 authorityClass, uint64 observedAt, uint64 appointmentBlock, (address authority, uint8 authorityClass, uint32 capabilities, bytes32 designation, bytes32 directive, bytes32 guardian, bytes32 stewardGrantRecordHash, uint64 postSeconds, uint64 standingTail) plan, bytes32 evidenceHash, bytes32 actionId, bytes32 witnessHash, uint64 delegationEpoch) terminal, uint256 activityCount)",
  "event ScopedContentRootPublished(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed scopeSubject, bytes32 indexed recordHash, (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 expectedPredecessor, bytes32 snapshotRecordHash, uint64 snapshotRevision, string manifestURI) publication, address snapshotHost, bytes32 snapshotCodeHash, bytes32 snapshotManifestHash, bytes32 snapshotSourceHash, bytes32 contentRoot, uint64 leafCount, bytes32 outputManifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) record, (uint64 revision, bytes32 transitionChain) collectionAggregate)",
  "event ScopedPolicyContentRootBindingPublished(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed scopeSubject, bytes32 indexed recordHash, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash) binding)",
  "event ArtistContentConsentApplied(uint256 indexed collectionId, bytes32 indexed familyId, bytes32 indexed consentRecordHash, bytes32 resultingContentStateHash, uint16 schemaVersion)"
]);


function deployment(value: ScopedPolicyRootV2Deployment): ScopedPolicyRootV2Deployment {
  keys(value, ["chainId", "core", "router", "metadata", "finality", "provider", "artist", "linkedDependencies"]);
  const a = value.artist;
  keys(a, ["chainId", "registry", "coordinator", "components"], ["reads"]);
  keys(value.linkedDependencies, ["root", "snapshot", "artist"]);
  if (uint(value.chainId) === 0n || a.chainId !== value.chainId || a.components.length !== 16) throw Error("Artist chain/suite length differs");
  const artist: CurrentArtistDeployment = { chainId: a.chainId, registry: codePin(a.registry), coordinator: codePin(a.coordinator),
    components: a.components.map(codePin), ...(a.reads ? { reads: codePin(a.reads) } : {}) };
  const result = { chainId: value.chainId, core: codePin(value.core), router: codePin(value.router), metadata: codePin(value.metadata),
    finality: codePin(value.finality), provider: codePin(value.provider), artist,
    linkedDependencies: { root: pinList(value.linkedDependencies.root), snapshot: pinList(value.linkedDependencies.snapshot), artist: pinList(value.linkedDependencies.artist) } };
  equal(result.core, artist.components[9], "Artist Core pin differs");
  equal(result.router, artist.components[12], "Artist suite.metadata must be actual Router");
  equal(artist.registry, artist.components[7], "Artist Registry pin differs");
  return freeze(result);
}
function coordinates(d: ScopedPolicyRootV2Deployment): root.ScopedPolicyRootV2Coordinates {
  return { chainId: d.chainId, core: d.core.address, router: d.router.address, artistRegistry: d.artist.registry.address };
}
async function read<T>(p: Reader, target: Address, iface: Interface, method: string, args: readonly unknown[], tag: number,
  from?: Address, cap?: bigint): Promise<T> {
  const result = await rpc(p, target, iface, method, args, tag, from, cap);
  if (result.length !== 1) throw Error("Expected one return field");
  return result[0] as T;
}
function tuple<T>(format: string, value: unknown): T {
  const raw = coder.encode([format], [value]);
  return plain(ParamType.from(format), coder.decode([format], raw)[0]) as T;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode([...types], [...values])) as Hex;
}
function gas(value: bigint): bigint {
  if (uint(value) === 0n || value > 100_000_000n) throw Error("Gas limit outside client bound");
  return value;
}
async function selected(p: Reader, d: ScopedPolicyRootV2Deployment, name: string, expected: ScopedPolicyRootV2CodePin,
  tag: number, strict: boolean, cap?: bigint) {
  const values = await rpc(p, d.core.address, routeAbi, "getSatellitePointer", [id(name)], tag, undefined, cap);
  if (!same(values[0], expected.address) || !same(values[1], expected.codeHash)
    || (strict && (values[6] !== 1n || values[9] === 0n))) throw Error("Selected " + name + " differs");
  await runtime(p, expected, tag);
  return values;
}
async function chain(p: Reader, id_: bigint, tag: number) {
  if ((await p.getNetwork()).chainId !== id_) throw Error("RPC chain mismatch");
  return header(p, tag);
}
async function artistContext(p: Reader, d: ScopedPolicyRootV2Deployment, tag: number, current: boolean) {
  const a = d.artist;
  for (const pin of [a.registry, a.coordinator, ...a.components, ...(a.reads ? [a.reads] : []), ...d.linkedDependencies.artist]) await runtime(p, pin, tag);
  const suite = await read<{ owners: Address[]; registry: Address; archive: Address; core: Address; mintManager: Address; roleRegistry: Address;
    metadata: Address; primaryResolver: Address; royaltyResolver: Address; validator: Address }>(p, a.coordinator.address, artistAbi, "suiteConfiguration", [], tag);
  const ordered = [...suite.owners, suite.registry, suite.archive, suite.core, suite.mintManager, suite.roleRegistry,
    suite.metadata, suite.primaryResolver, suite.royaltyResolver, suite.validator];
  equal(ordered, a.components.map(pin => pin.address), "Actual Artist suite differs");
  if (a.reads) equal(await read(p, a.coordinator.address, artistAbi, "reads", [], tag), a.reads.address);
  equal(await read(p, a.coordinator.address, artistAbi, "deploymentChainId", [], tag), d.chainId);
  for (const [method, expected] of [["core", d.core.address], ["mintManager", suite.mintManager], ["operationCoordinator", a.coordinator.address]] as const) {
    equal(await read(p, a.registry.address, artistAbi, method, [], tag), expected, "Artist facade binding differs");
  }
  for (let i = 0; i < 7; i++) {
    for (const [method, expected] of [["core", suite.core], ["mintManager", suite.mintManager], ["artistRegistry", a.registry.address],
      ["operationCoordinator", a.coordinator.address], ["archiveV2", suite.archive], ["domainId", domains[i]!], ["deploymentChainId", d.chainId]] as const) {
      equal(await read(p, a.components[i]!.address, artistAbi, method, [], tag), expected, "Artist owner binding differs");
    }
  }
  if (current) {
    await selected(p, d, "ARTIST_REGISTRY", a.registry, tag, false);
    if ((await rpc(p, a.registry.address, artistAbi, "artistRegistryCutover", [], tag))[0] !== false) throw Error("Artist facade cut over");
    await selected(p, d, "METADATA_ROUTER", d.router, tag, false);
  }
  return hash(await read(p, a.coordinator.address, artistAbi, "configurationHash", [], tag));
}
async function binding(p: Reader, d: ScopedPolicyRootV2Deployment, cid: bigint, tag: number) {
  const a = d.artist;
  const b = await read<CurrentArtistBinding>(p, a.components[0]!.address, artistAbi, "binding", [cid], tag);
  const state = await rpc(p, a.components[4]!.address, artistAbi, "attributionState", [cid], tag);
  const auth = await rpc(p, a.components[2]!.address, artistAbi, "authorityState", [b.artistId], tag);
  const authority: CurrentArtistAuthority = { address: address(auth[0]), authorityClass: uint(auth[1]), status: uint(auth[2]), identityRecordHash: hash(auth[3]) };
  const ordinary = authority.authorityClass === 1n && [1n, 2n].includes(authority.status)
    || [3n, 4n].includes(authority.authorityClass) && authority.status === 3n;
  if (!b.accepted || b.generation === 0n || ![1n, 2n].includes(b.consentMode) || ![2n, 3n].includes(state[0] as bigint)
    || state[1] !== b.generation || !ordinary) throw Error("Artist accepted binding/current authority unavailable");
  hash(b.artistId); hash(b.bindingHash);
  const terms = await read<{ mode: bigint; threshold: bigint; count: bigint }>(p, a.components[0]!.address, artistAbi, "bindingTerms", [cid, b.generation], tag);
  if (terms.mode !== 0n || terms.threshold !== 0n || terms.count > 32n
    || await read(p, a.components[1]!.address, artistAbi, "acceptedCount", [b.bindingHash], tag) !== terms.count) throw Error("Simple complete collaborator binding required");
  equal(await rpc(p, a.registry.address, artistAbi, "collectionArtistState", [cid], tag),
    [state[0], b.generation, b.artistId, authority.status, b.bindingHash], "Facade Artist state differs");
  return { binding: b, authority };
}

export interface ScopedPolicyRootV2Preview {
  readonly deployment: ScopedPolicyRootV2Deployment;
  readonly observed: ScopedPolicyRootV2Block;
  readonly publication: root.ScopedPolicyRootV2Publication;
  readonly publisher: Address;
  readonly record: root.ScopedPolicyRootV2Record;
  readonly binding: root.ScopedPolicyRootV2Binding;
  readonly previousAggregate: root.ScopedPolicyRootV2Aggregate;
  readonly nextAggregate: root.ScopedPolicyRootV2Aggregate;
  readonly legacyFamily: Hex;
  readonly currentFamily: Hex;
  readonly nextFamily: Hex;
  readonly snapshot: {
    readonly pin: ScopedPolicyRootV2CodePin;
    readonly dependencies: pub.ScopedPolicyPublicationV2Dependencies;
    readonly publication: pub.ScopedPolicyPublicationV2Publication;
    readonly receipt: pub.ScopedPolicyPublicationV2Receipt;
    readonly source: pub.ScopedPolicyPublicationV2Source;
    readonly canonical: Hex;
  };
  readonly previewHash: Hex;
}

async function schemas(p: Reader, target: Address, binding_: root.ScopedPolicyRootV2Binding, tag: number, cap: bigint) {
  const rows = [
    [pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA, binding_.outputSchemaHash, 0n],
    [pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION, binding_.outputCanonicalizationHash, 1n],
    [pub.SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA, binding_.leafSchemaHash, 0n],
    [id("STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"), binding_.rootSchemaHash, 0n],
    [id("STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"), binding_.rootCanonicalizationHash, 1n]
  ] as const;
  for (const [key, expectedHash, kind] of rows) {
    const doc = await read<{ exists: boolean; status: bigint; specification: { name: string; kind: bigint; contentHash: Hex;
      canonicalizationId: Hex; totalBytes: bigint } }>(p, target, routeAbi, "document", [key], tag, undefined, cap);
    if (!doc.exists || doc.status !== 0n || doc.specification.kind !== kind || id(doc.specification.name) !== key
      || doc.specification.contentHash !== expectedHash || doc.specification.canonicalizationId !== id("RAW_BYTES")) throw Error("Original ACTIVE root definition differs");
    const raw = bytes(await read(p, target, routeAbi, "documentBytes", [key], tag, undefined, cap), 8192);
    if (keccak256(raw) !== expectedHash || BigInt((raw.length - 2) / 2) !== doc.specification.totalBytes) throw Error("Definition bytes differ");
  }
}
function interfaceId(iface: Interface): Hex {
  let value = 0n;
  for (const fragment of iface.fragments) if (fragment.type === "function") {
    const selector = iface.getFunction(fragment.format("sighash"))!.selector;
    value ^= BigInt(selector);
  }
  return ("0x" + value.toString(16).padStart(8, "0")) as Hex;
}
const providerCapability = interfaceId(new Interface([
  "function scopedPolicySnapshotHost((uint8,uint256,uint256,bytes32)) view returns(address)",
  "function scopedPolicySnapshotCodeHash((uint8,uint256,uint256,bytes32)) view returns(bytes32)",
  "function scopedPolicySnapshotValidationGas((uint8,uint256,uint256,bytes32)) view returns(uint256)",
  "function scopedPolicySnapshotProfile() view returns(bytes32)"
]));
async function snapshotSource(p: Reader, d: ScopedPolicyRootV2Deployment, publication: root.ScopedPolicyRootV2Publication,
  tag: number) {
  const scope = publication.scope;
  for (const pin of [d.core, d.router, d.metadata, d.finality, d.provider, d.artist.registry,
    ...d.linkedDependencies.root, ...d.linkedDependencies.snapshot]) await runtime(p, pin, tag);
  await selected(p, d, "ARTWORK_FINALITY_REGISTRY", d.finality, tag, true, 100000n);
  for (const [method, value] of [["finalityRegistry", d.finality.address], ["finalityRegistryCodeHash", d.finality.codeHash]] as const) {
    equal(await read(p, d.artist.registry.address, routeAbi, method, [], tag, undefined, 100000n), value);
  }
  const readGas = uint(await read(p, d.finality.address, routeAbi, "gasParameter", [id("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS")], tag, undefined, 100000n));
  if (readGas < 50000n || readGas > 0xffffffffn) throw Error("Root component read gas differs");
  for (const [method, expected] of [["coreReads", d.core.address], ["sanctionReads", d.artist.registry.address],
    ["scopeEvidenceProvider", d.provider.address], ["scopeEvidenceProviderCodeHash", d.provider.codeHash], ["metadataReads", d.metadata.address]] as const) {
    equal(await read(p, d.finality.address, routeAbi, method, [], tag, undefined, readGas), expected, "Finality route differs");
  }
  await selected(p, d, "METADATA_ROUTER", d.router, tag, true, readGas);
  await selected(p, d, "COLLECTION_METADATA", d.metadata, tag, true, readGas);
  await selected(p, d, "ARTIST_REGISTRY", d.artist.registry, tag, false);
  equal(await read(p, d.router.address, routeAbi, "core", [], tag), d.core.address);
  equal(await read(p, d.router.address, routeAbi, "artistRegistry", [], tag), d.artist.registry.address);
  equal(await read(p, d.provider.address, routeAbi, "metadataHost", [], tag, undefined, readGas), d.metadata.address);
  if (await read(p, d.provider.address, routeAbi, "supportsInterface", [providerCapability], tag, undefined, readGas) !== true
    || await read(p, d.provider.address, routeAbi, "scopedPolicySnapshotProfile", [], tag, undefined, readGas) !== pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE) throw Error("Provider scoped snapshot capability differs");
  const validationGas = uint(await read(p, d.provider.address, routeAbi, "scopedPolicySnapshotValidationGas", [scope], tag, undefined, readGas));
  if (validationGas < readGas || validationGas > 0xffffffffn) throw Error("Snapshot validation budget differs");
  const pin = { address: address(await read(p, d.provider.address, routeAbi, "scopedPolicySnapshotHost", [scope], tag, undefined, validationGas)),
    codeHash: hash(await read(p, d.provider.address, routeAbi, "scopedPolicySnapshotCodeHash", [scope], tag, undefined, validationGas)) };
  await runtime(p, pin, tag);
  const iface = pub.scopedPolicyPublicationV2Interface("snapshot");
  equal(await read(p, pin.address, routeAbi, "supportsInterface", [root.SCOPED_POLICY_ROOT_V2_SNAPSHOT_INTERFACE_ID], tag), true);
  equal(await read(p, pin.address, iface, "core", [], tag), d.core.address);
  equal(await read(p, pin.address, iface, "metadataHost", [], tag), d.metadata.address);
  equal(await read(p, pin.address, iface, "scopedPolicySnapshotProfile", [], tag), pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE);
  const deps = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(await read(p, pin.address, iface, "dependencies", [], tag, undefined, readGas));
  equal([deps.chainId, deps.targets[0], deps.targets[1], deps.targets[4]], [d.chainId, d.core.address, d.metadata.address, d.router.address]);
  for (let i = 0; i < 11; i++) await runtime(p, { address: deps.targets[i]!, codeHash: deps.codeHashes[i]! }, tag);
  const history = await inspectScopedPolicyPublicationV2History(p, { chainId: d.chainId, core: d.core.address, metadata: d.metadata.address,
    checkpoint: { address: deps.targets[7], codeHash: deps.codeHashes[7] }, output: { address: deps.targets[8], codeHash: deps.codeHashes[8] },
    snapshot: pin, linkedDependencies: d.linkedDependencies.snapshot }, { kind: "snapshotRecord", recordHash: publication.snapshotRecordHash }, { blockTag: tag });
  if (history.result.kind !== "snapshotRecord") throw Error("Unexpected snapshot history");
  const retained = history.result;
  equal(retained.publication.scope, scope, "Snapshot full scope differs");
  equal([retained.receipt.recordHash, retained.receipt.revision], [publication.snapshotRecordHash, publication.snapshotRevision]);
  equal(await read(p, pin.address, iface, "requireCurrent", [scope, publication.snapshotRecordHash, publication.snapshotRevision], tag, undefined, validationGas), retained.receipt, "Original current snapshot differs");
  await runtime(p, { address: retained.source.sourceFactory, codeHash: retained.source.sourceFactoryCodeHash }, tag);
  return { snapshot: { pin, dependencies: deps, publication: retained.publication, receipt: retained.receipt,
    source: retained.source, canonical: retained.canonical }, readGas, validationGas };
}

/** Preview authenticates original source/authority facts but does not record Artist consent. */
export async function previewScopedPolicyRootV2(p: Reader, input: ScopedPolicyRootV2Deployment, inputPublisher: Address,
  supplied: root.ScopedPolicyRootV2Publication, options: { readonly blockTag: number }): Promise<ScopedPolicyRootV2Preview> {
  const d = deployment(input);
  const publisher = address(inputPublisher);
  const publication = root.normalizeScopedPolicyRootV2Publication(supplied);
  graph.validateScopedPolicyGraphV2Scope(publication.scope);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  const observed = await chain(p, d.chainId, tag);
  const cid = publication.scope.collectionId;
  const facts = await snapshotSource(p, d, publication, tag);
  if (await read(p, d.core.address, routeAbi, "collectionExists", [cid], tag, undefined, facts.readGas) !== true
    || await read(p, d.core.address, routeAbi, "collectionFreezeStatus", [cid], tag, undefined, facts.readGas) !== false
    || await read(p, d.finality.address, routeAbi, "artworkFreezeMode", [publication.scope], tag, undefined, facts.readGas) !== 0n) throw Error("Root scope missing or frozen");
  const artist = await rpc(p, d.artist.registry.address, routeAbi, "collectionArtistState", [cid], tag, undefined, facts.readGas);
  const presentation = facts.snapshot.source.artist;
  if (![2n, 3n].includes(artist[0] as bigint) || artist[1] === 0n || artist[2] === ZERO || artist[4] === ZERO
    || artist[1] !== presentation.bindingGeneration || artist[2] !== presentation.artistId || artist[4] !== presentation.bindingHash) throw Error("Snapshot Artist binding differs");
  let authorizationClass: 7n | 8n = 7n;
  let grant = await rpc(p, d.metadata.address, routeAbi, "familyWriter", [cid, SNAPSHOT_FAMILY, 7n, publisher], tag, undefined, facts.readGas);
  if (grant[0] !== true || grant[1] === 0n) {
    authorizationClass = 8n;
    grant = await rpc(p, d.metadata.address, routeAbi, "familyWriter", [0n, SNAPSHOT_FAMILY, 8n, publisher], tag, undefined, facts.readGas);
  }
  if (grant[0] !== true || grant[1] === 0n) throw Error("Root publisher SNAPSHOT grant unavailable");
  const route = { finality: d.finality.address, provider: d.provider.address, snapshot: facts.snapshot.pin.address,
    codeHashes: [d.core.codeHash, d.artist.registry.codeHash, d.router.codeHash, d.finality.codeHash, d.provider.codeHash, facts.snapshot.pin.codeHash] as const,
    metadata: d.metadata.address, metadataCodeHash: d.metadata.codeHash, scope: publication.scope };
  const prepared = root.scopedPolicyRootV2PreparedRecord(coordinates(d), { publication, route, source: facts.snapshot.source,
    dependencies: facts.snapshot.dependencies, receipt: facts.snapshot.receipt, publisher, authorizationClass, grantRevision: uint(grant[1], 64) });
  await schemas(p, facts.snapshot.dependencies.targets[2], prepared.binding, tag, facts.readGas);
  const previousHead = hash(await read(p, d.router.address, routeAbi, "scopedContentRootHead", [publication.scope], tag), true);
  equal(previousHead, publication.expectedPredecessor, "Root scope predecessor changed");
  const previousAggregate = root.normalizeScopedPolicyRootV2Aggregate(await read(p, d.router.address, routeAbi, "scopedContentRootAggregate", [cid], tag));
  const legacyHead = hash(await read(p, d.router.address, routeAbi, "collectionContentRootHead", [cid], tag), true);
  const legacyFamily = legacyHead === ZERO ? digest(["bytes32", "uint256", "address", "address", "uint256"],
    [id("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"), d.chainId, d.router.address, d.core.address, cid])
    : hash((await read<{ stateHash: Hex }>(p, d.router.address, routeAbi, "contentRootRecord", [legacyHead], tag)).stateHash);
  const currentFamily = root.scopedPolicyRootV2FamilyHash(coordinates(d), cid, legacyFamily, previousAggregate);
  equal(await rpc(p, d.router.address, routeAbi, "artistContentFamilyState", [cid, FAMILY], tag), [true, currentFamily]);
  const nextAggregate = root.scopedPolicyRootV2NextAggregate(coordinates(d), previousAggregate, previousHead, prepared.record);
  const nextFamily = root.scopedPolicyRootV2FamilyHash(coordinates(d), cid, legacyFamily, nextAggregate);
  const original = await read(p, d.router.address, root.scopedPolicyRootV2Interface("router"), "previewScopedPolicyContentRootPublication", [publication, publisher], tag, publisher);
  equal(original, nextFamily, "Original Router family preview differs");
  await unchanged(p, observed);
  const result = { deployment: d, observed, publication, publisher, record: prepared.record, binding: prepared.binding,
    previousAggregate, nextAggregate, legacyFamily, currentFamily, nextFamily, snapshot: facts.snapshot };
  return freeze({ ...result, previewHash: fingerprint(result) });
}

interface OwnerSnapshot { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex }
interface PayloadRow { readonly pointer: Address; readonly payloadType: Hex; readonly payloadHash: Hex }
interface OwnerObservation { readonly index: number; readonly snapshot: OwnerSnapshot; readonly nativeCount: bigint; readonly payloads: readonly PayloadRow[] }
interface ConsentRecord {
  readonly recordHash: Hex; readonly artistId: Hex; readonly bindingGeneration: bigint;
  readonly terms: { readonly collectionId: bigint; readonly metadataContract: Address; readonly familyId: Hex; readonly newStateHash: Hex };
  readonly authorityClass: bigint;
}
export interface ScopedPolicyRootV2ConsentAuthorization {
  readonly signer: Address;
  readonly nonce: bigint;
  readonly deadline: bigint;
  readonly signature: Hex;
}
export interface ScopedPolicyRootV2ConsentCapture {
  readonly kind: "consent";
  readonly preview: ScopedPolicyRootV2Preview;
  readonly prepared: root.ScopedPolicyRootV2Call;
  readonly configurationHash: Hex;
  readonly binding: CurrentArtistBinding;
  readonly authority: CurrentArtistAuthority;
  readonly replay: CurrentArtistReplay;
  readonly owners: readonly OwnerObservation[];
  readonly archivePayloads: readonly PayloadRow[];
  readonly notice: { readonly recordHash: Hex; readonly phase: bigint; readonly terminalHash: Hex };
  readonly pendingEstateActivation: Hex;
  readonly captureHash: Hex;
}
export interface ScopedPolicyRootV2Capture {
  readonly kind: "root";
  readonly preview: ScopedPolicyRootV2Preview;
  readonly prepared: root.ScopedPolicyRootV2Call;
  readonly consent: ConsentRecord;
  readonly currentContentStateHash: Hex;
  readonly ratification: readonly [boolean, Hex, Hex];
  readonly evolution: readonly [Hex, Hex];
  readonly captureHash: Hex;
}
export type ScopedPolicyRootV2WorkflowCapture = ScopedPolicyRootV2Capture | ScopedPolicyRootV2ConsentCapture;
async function catalog(p: Reader, host: Address, tag: number): Promise<readonly PayloadRow[]> {
  const count = uint(await read(p, host, artistAbi, "storedPayloadCount", [], tag));
  if (count > 16384n) throw Error("Payload catalog exceeds client bound");
  const rows: PayloadRow[] = [];
  const seen = new Set<string>();
  for (let i = 0n; i < count; i++) {
    const row = await rpc(p, host, artistAbi, "storedPayloadAt", [i], tag);
    const v = { pointer: address(row[0]), payloadType: hash(row[1]), payloadHash: hash(row[2]) };
    const key = v.payloadType + ":" + v.payloadHash;
    if (seen.has(key)) throw Error("Duplicate catalog key");
    seen.add(key); rows.push(v);
  }
  return rows;
}
function previewSnapshot(input: ScopedPolicyRootV2Preview): ScopedPolicyRootV2Preview {
  const saved = structuredClone(input);
  const { previewHash, ...body } = saved;
  if (fingerprint(body) !== hash(previewHash)) throw Error("Preview facts changed");
  deployment(saved.deployment);
  root.normalizeScopedPolicyRootV2Publication(saved.publication);
  return freeze(saved);
}
function comparablePreview(value: ScopedPolicyRootV2Preview) {
  const { observed: _observed, previewHash: _hash, ...body } = value;
  return body;
}
async function revalidatePreview(p: Reader, saved: ScopedPolicyRootV2Preview, tag: number) {
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  await unchanged(p, saved.observed);
  const original = await previewScopedPolicyRootV2(p, saved.deployment, saved.publisher, saved.publication,
    { blockTag: saved.observed.blockNumber });
  equal(original, saved, "Original preview reconstruction differs");
  const current = tag === saved.observed.blockNumber ? original : await previewScopedPolicyRootV2(p, saved.deployment,
    saved.publisher, saved.publication, { blockTag: tag });
  equal(comparablePreview(current), comparablePreview(saved), "Collection family/source/publisher changed; renew preview and consent");
  return current;
}
/** Coherent root profile accepts principal classes1/3; class4 creation cannot be consumed by this Root. */
export async function captureScopedPolicyRootV2Consent(p: Reader, input: ScopedPolicyRootV2Preview,
  inputCaller: Address, supplied: ScopedPolicyRootV2ConsentAuthorization): Promise<ScopedPolicyRootV2ConsentCapture> {
  const preview = previewSnapshot(input);
  const caller = address(inputCaller);
  keys(supplied, ["signer", "nonce", "deadline", "signature"]);
  const auth = { signer: address(supplied.signer), nonce: uint(supplied.nonce), deadline: uint(supplied.deadline, 64), signature: bytes(supplied.signature, 4096) };
  const d = preview.deployment;
  const tag = preview.observed.blockNumber;
  await revalidatePreview(p, preview, tag);
  const configurationHash = await artistContext(p, d, tag, true);
  const facts = await binding(p, d, preview.publication.scope.collectionId, tag);
  if (auth.signer !== facts.authority.address || ![1n, 3n].includes(facts.authority.authorityClass)) throw Error("Root consent requires actual current principal class1 or3");
  if (auth.deadline < preview.observed.timestamp || auth.deadline === 0n) throw Error("Artist deadline expired");
  if (facts.authority.authorityClass === 3n) {
    const cap = await read<{ authorityAddress: Address; authorityClass: bigint; status: bigint; effectiveCapabilities: bigint; activationRecordHash: Hex }>(p,
      d.artist.components[2]!.address, artistAbi, "currentAuthorityCapabilities", [facts.binding.artistId], tag);
    if (cap.authorityAddress !== auth.signer || cap.authorityClass !== 3n || cap.status !== 3n
      || (cap.effectiveCapabilities & 128n) !== 128n || cap.activationRecordHash === ZERO) throw Error("Current content capability unavailable");
  }
  const prepared = root.prepareScopedPolicyRootV2Call(coordinates(d), caller, { kind: "recordContentConsent",
    collectionId: preview.publication.scope.collectionId, newFamilyStateHash: preview.nextFamily,
    signer: auth.signer, authorityClass: facts.authority.authorityClass as 1n | 3n,
    authorization: { nonce: auth.nonce, deadline: auth.deadline, signature: auth.signature } });
  const consent = prepared.consent!;
  if (!consent.direct) {
    const [cap, , failure, revision] = await rpc(p, d.artist.registry.address, artistAbi, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS")], tag);
    if (cap === 0n || cap === (1n << 256n) - 1n || failure !== 2n || revision === 0n) throw Error("Original signature gas parameters unavailable");
  }
  const actualDigest = bytes(await p.call({ ...consent.digestCall, from: caller, blockTag: tag }), 32);
  equal(actualDigest, coder.encode(["bytes32"], [consent.payload.digest]), "Original op17 digest differs");
  const replay = await read<CurrentArtistReplay>(p, d.artist.registry.address, artistAbi, "artistAuthorizationState",
    [facts.binding.artistId, consent.payload.digest, auth.nonce], tag);
  if (replay.digestObserved || replay.digestRevoked || replay.nonceConsumed || replay.nonceRevoked
    || consent.direct && replay.nextUnusedNonce !== auth.nonce) throw Error("Artist nonce/digest unavailable");
  if (preview.currentFamily === ZERO || preview.currentFamily === preview.nextFamily) throw Error("Content target already current");
  const owners: OwnerObservation[] = [];
  for (const index of [0, 1, 2, 4, 6]) {
    const host = d.artist.components[index]!.address;
    const snapshot = await read<OwnerSnapshot>(p, host, artistAbi, "ownerStateSnapshotV2", [], tag);
    if (snapshot.domainId !== domains[index] || snapshot.stateRoot === ZERO) throw Error("Owner snapshot domain/root differs");
    owners.push({ index, snapshot, nativeCount: uint(await read(p, host, artistAbi, "artistNativeReceiptCount", [], tag)),
      payloads: [2, 4, 6].includes(index) ? await catalog(p, host, tag) : [] });
  }
  const notice = await rpc(p, d.artist.components[2]!.address, artistAbi, "dormancyNotice", [facts.binding.artistId], tag);
  const estate = await rpc(p, d.artist.components[2]!.address, artistAbi, "estateActivationState", [facts.binding.artistId], tag);
  const result = { kind: "consent" as const, preview, prepared, configurationHash, ...facts, replay, owners,
    archivePayloads: await catalog(p, d.artist.components[8]!.address, tag),
    notice: { recordHash: hash(notice[0], true), phase: uint(notice[1], 8), terminalHash: hash(notice[2], true) },
    pendingEstateActivation: hash(estate[2], true) };
  await unchanged(p, preview.observed);
  return freeze({ ...result, captureHash: fingerprint(result) });
}

/** Capture a fresh root after original op17 has been mined. It never recreates or re-signs that record. */
export async function captureScopedPolicyRootV2(p: Reader, supplied: ScopedPolicyRootV2Deployment, publisher: Address,
  publication: root.ScopedPolicyRootV2Publication, options: { readonly blockTag: number }): Promise<ScopedPolicyRootV2Capture> {
  const preview = await previewScopedPolicyRootV2(p, supplied, publisher, publication, options);
  const d = preview.deployment;
  const tag = preview.observed.blockNumber;
  const cid = preview.publication.scope.collectionId;
  await artistContext(p, d, tag, true);
  const facts = await binding(p, d, cid, tag);
  const key = hash(await read(p, d.artist.registry.address, routeAbi, "contentConsentEvidence", [cid, FAMILY, preview.nextFamily], tag, d.router.address));
  const consent = await read<ConsentRecord>(p, d.artist.components[6]!.address, artistAbi, "contentConsentRecord", [key], tag);
  equal(consent, { recordHash: key, artistId: facts.binding.artistId, bindingGeneration: facts.binding.generation,
    terms: { collectionId: cid, metadataContract: d.router.address, familyId: FAMILY, newStateHash: preview.nextFamily }, authorityClass: consent.authorityClass });
  if (![1n, 3n].includes(consent.authorityClass)) throw Error("Root stored consent class unavailable");
  equal(await read(p, d.artist.components[6]!.address, artistAbi, "contentConsentAt", [consent.terms, consent.bindingGeneration], tag), consent);
  if (await read(p, d.router.address, routeAbi, "consumedArtistContentConsent", [key], tag) !== false) throw Error("Content consent already consumed");
  const content = await rpc(p, d.router.address, routeAbi, "currentArtistContentState", [cid], tag);
  equal(content[0], d.router.address);
  const currentContentStateHash = hash(content[1]);
  const rawRatification = await rpc(p, d.artist.registry.address, routeAbi, "firstReleaseRatification", [cid], tag);
  const ratification = [rawRatification[0] as boolean, hash(rawRatification[1], true), hash(rawRatification[2], true)] as const;
  const rawEvolution = await rpc(p, d.router.address, routeAbi, "artistContentEvolution", [cid], tag);
  const evolution = [hash(rawEvolution[0], true), hash(rawEvolution[1], true)] as const;
  if (ratification[0] && (ratification[2] === ZERO || currentContentStateHash !== ratification[1]
    && (evolution[0] !== ratification[2] || evolution[1] !== currentContentStateHash))) throw Error("Artist content evolution broken");
  const prepared = root.prepareScopedPolicyRootV2Call(coordinates(d), preview.publisher,
    { kind: "publishScopedPolicyContentRootPublication", publication: preview.publication });
  const result = { kind: "root" as const, preview, prepared, consent, currentContentStateHash, ratification, evolution };
  await unchanged(p, preview.observed);
  return freeze({ ...result, captureHash: fingerprint(result) });
}
function savedCapture(input: ScopedPolicyRootV2WorkflowCapture): ScopedPolicyRootV2WorkflowCapture {
  const saved = structuredClone(input);
  const { captureHash, ...body } = saved;
  if (fingerprint(body) !== hash(captureHash)) throw Error("Captured facts changed");
  previewSnapshot(saved.preview);
  const prepared = root.normalizeScopedPolicyRootV2Call(saved.prepared);
  equal(prepared.coordinates, coordinates(saved.preview.deployment));
  if (saved.kind === "root") equal(prepared, root.prepareScopedPolicyRootV2Call(coordinates(saved.preview.deployment), saved.preview.publisher,
    { kind: "publishScopedPolicyContentRootPublication", publication: saved.preview.publication }));
  else if (saved.kind === "consent" && prepared.request.kind === "recordContentConsent") {
    equal([prepared.request.collectionId, prepared.request.newFamilyStateHash, prepared.request.signer, prepared.request.authorityClass],
      [saved.preview.publication.scope.collectionId, saved.preview.nextFamily, saved.authority.address, saved.authority.authorityClass]);
  } else throw Error("Captured stage/call differs");
  return freeze(saved);
}
function comparable(c: ScopedPolicyRootV2WorkflowCapture) {
  const { captureHash: _hash, preview, ...rest } = c;
  return { ...rest, preview: comparablePreview(preview) };
}
async function recapture(p: Reader, saved: ScopedPolicyRootV2WorkflowCapture, tag: number) {
  const s = saved.preview;
  if (saved.kind === "root") return captureScopedPolicyRootV2(p, s.deployment, s.publisher, s.publication, { blockTag: tag });
  const q = saved.prepared.request;
  if (q.kind !== "recordContentConsent") throw Error("Not a consent request");
  const preview = await previewScopedPolicyRootV2(p, s.deployment, s.publisher, s.publication, { blockTag: tag });
  return captureScopedPolicyRootV2Consent(p, preview, saved.prepared.caller, { signer: q.signer, ...q.authorization });
}
async function revalidate(p: Reader, saved: ScopedPolicyRootV2WorkflowCapture, tag: number) {
  if (tag < saved.preview.observed.blockNumber) throw Error("Observation predates capture");
  await unchanged(p, saved.preview.observed);
  equal(await recapture(p, saved, saved.preview.observed.blockNumber), saved, "Original capture reconstruction differs");
  const current = tag === saved.preview.observed.blockNumber ? saved : await recapture(p, saved, tag);
  equal(comparable(current), comparable(saved), "Reviewed state changed; recapture");
  return current;
}
function consentRecordHash(c: ScopedPolicyRootV2ConsentCapture, timestamp: bigint): Hex {
  const q = c.prepared.request;
  if (q.kind !== "recordContentConsent") throw Error("Not a consent");
  return digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), c.preview.deployment.chainId, c.prepared.coordinates.artistRegistry,
      c.prepared.coordinates.router, c.prepared.coordinates.core, q.collectionId, FAMILY, q.newFamilyStateHash,
      c.binding.artistId, q.signer, q.authorityClass, q.authorization.nonce, timestamp]);
}
function completedRoot(c: ScopedPolicyRootV2Capture, timestamp: bigint) {
  if (timestamp === 0n || timestamp > 0xffffffffffffffffn) throw Error("Root timestamp outside original bound");
  const record = root.normalizeScopedPolicyRootV2Record({ ...c.preview.record, artistConsent: c.consent.recordHash, publishedAt: timestamp });
  const recordHash = root.scopedPolicyRootV2RecordHash(c.prepared.coordinates, record, c.preview.binding, c.preview.nextAggregate);
  return { record, binding: c.preview.binding, aggregate: c.preview.nextAggregate, recordHash };
}
export async function simulateScopedPolicyRootV2(p: Reader, input: ScopedPolicyRootV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const cap = gas(options.gasLimit);
  const current = await revalidate(p, saved, number(options.blockTag));
  const raw = bytes(await p.call({ ...current.prepared.call, from: current.prepared.caller, blockTag: current.preview.observed.blockNumber, gasLimit: cap }), 32);
  const expected = current.kind === "root" ? completedRoot(current, current.preview.observed.timestamp).recordHash
    : consentRecordHash(current, current.preview.observed.timestamp);
  equal(raw, coder.encode(["bytes32"], [expected]), "Original call result differs");
  await unchanged(p, current.preview.observed);
  return freeze({ capture: current, gasLimit: cap, recordHash: expected, returnData: raw, simulated: true as const, persisted: false as const });
}
const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);

export type ScopedPolicyRootV2ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex }
>;

interface CopiedLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

async function transport(provider: ReceiptReader, saved: ScopedPolicyRootV2WorkflowCapture,
  transactionHash: Hex, options: ScopedPolicyRootV2ReceiptOptions) {
  const raw = await provider.getTransactionReceipt(transactionHash);
  if (!raw || raw.status !== 1 || !same(raw.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = number(raw.blockNumber);
  const blockHash = hash(raw.blockHash);
  const from = address(raw.from);
  const to = address(raw.to);
  if (blockNumber <= saved.preview.observed.blockNumber) throw Error("Receipt must follow captured block");
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
    || tx.chainId !== saved.preview.deployment.chainId) throw Error("Transaction envelope differs");
  const data = bytes(tx.data, MAX_CALL + 16384);
  const call = saved.prepared.call;
  const caller = saved.prepared.caller;
  if (tx.value !== 0n) throw Error("Outer value must be zero");
  let safeIndex = -1;
  if (options.execution === "direct") {
    if (!same(from, caller) || !same(to, call.to) || !same(data, call.data)) throw Error("Direct caller/target/data differs");
  } else {
    if (!same(to, caller)) throw Error("Safe is not the actual publication caller");
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


function one(logs: readonly CopiedLog[], target: Address, name: string, expected?: readonly unknown[]) {
  const matches = events(logs, target, eventAbi, name);
  if (matches.length !== 1) throw Error("Expected exactly one " + name);
  const result = matches[0]!;
  if (expected) {
    const fragment = eventAbi.getEvent(name)!;
    equal(result.fields, Object.fromEntries(fragment.inputs.map((field, i) => [field.name, expected[i]])), name + " differs");
  }
  return result;
}
async function carrier(p: Reader, pointer: Address, content: Hex, tag: number) {
  equal(bytes(await p.getCode(pointer, tag), 24576), "0x00" + content.slice(2), "STOP carrier differs");
}
function replayKey(c: ScopedPolicyRootV2ConsentCapture, index: number, surface: string, scope: Hex): Hex {
  const d = c.preview.deployment;
  return digest(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), d.chainId, d.artist.registry.address, d.artist.coordinator.address,
      d.artist.components[8]!.address, d.artist.components[index]!.address, domains[index], id(surface), scope]);
}
async function consumedCell(p: Reader, c: ScopedPolicyRootV2ConsentCapture, index: number, surface: string,
  scope: Hex, commitment: Hex, revision: bigint, tag: number, earlier = false) {
  const cell = await read<{ commitment: Hex; touchedRevision: bigint; kind: bigint; status: bigint }>(p,
    c.preview.deployment.artist.components[index]!.address, artistAbi, "replayCell", [replayKey(c, index, surface, scope)], tag);
  if (cell.commitment !== commitment || cell.kind !== 1n || cell.status !== 2n || cell.touchedRevision === 0n
    || (earlier ? cell.touchedRevision > revision : cell.touchedRevision !== revision)) throw Error("Consumed original replay cell differs");
}
async function nativeRow(p: Reader, host: Address, index: bigint, revision: bigint,
  value: { operation: bigint; artistId: Hex; collectionId: bigint; recordHash: Hex }, tag: number) {
  equal(await read(p, host, artistAbi, "artistNativeReceiptAt", [index], tag), value, "Native receipt differs");
  equal(await read(p, host, artistAbi, "artistNativeReceiptRevisionAt", [index], tag), revision, "Native revision differs");
}
async function consentReceipt(p: ReceiptReader, c: ScopedPolicyRootV2ConsentCapture,
  t: Awaited<ReturnType<typeof transport>>) {
  const d = c.preview.deployment;
  const q = c.prepared.request;
  if (q.kind !== "recordContentConsent") throw Error("Not op17");
  const tag = t.observed.blockNumber;
  if (q.authorization.deadline < t.observed.timestamp) throw Error("Mined Artist deadline expired");
  equal(await artistContext(p, d, tag, false), c.configurationHash, "Artist configuration changed");
  const identity = d.artist.components[2]!.address;
  const consentOwner = d.artist.components[6]!.address;
  const archive = d.artist.components[8]!.address;
  const recordHash = consentRecordHash(c, t.observed.timestamp);
  const terms = { collectionId: q.collectionId, metadataContract: d.router.address, familyId: FAMILY, newStateHash: q.newFamilyStateHash };
  const recorded = one(t.logs, consentOwner, "ArtistContentConsentRecorded", [1n, q.collectionId, FAMILY, q.signer,
    q.newFamilyStateHash, q.authorityClass, q.authorization.nonce, t.observed.timestamp, recordHash]);
  const contextual = one(t.logs, consentOwner, "ArtistContentRecordContext", [1n, recordHash, d.router.address, c.binding.artistId]);
  if (contextual.index <= recorded.index) throw Error("Content context ordering differs");
  const expectedRecord = { recordHash, artistId: c.binding.artistId, bindingGeneration: c.binding.generation, terms, authorityClass: q.authorityClass };
  equal(await read(p, consentOwner, artistAbi, "contentConsentRecord", [recordHash], tag), expectedRecord);
  equal(await read(p, consentOwner, artistAbi, "contentConsentAt", [terms, c.binding.generation], tag), expectedRecord);
  equal(await read(p, identity, artistAbi, "signatureBundle", [recordHash], tag), q.authorization.signature);
  const replay = await read<CurrentArtistReplay>(p, d.artist.registry.address, artistAbi, "artistAuthorizationState",
    [c.binding.artistId, c.prepared.consent!.payload.digest, q.authorization.nonce], tag);
  if (!replay.digestObserved || !replay.nonceConsumed || replay.digestRevoked || replay.nonceRevoked) throw Error("Mined authorization replay differs");
  const evidenceId = digest(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), d.chainId, d.artist.registry.address,
      d.artist.coordinator.address, 17n, c.prepared.caller, recordHash]);
  const metadata = await rpc(p, archive, artistAbi, "artistEvidenceMetadataV2", [evidenceId, 1n], tag);
  const archiveBytes = bytes(await read(p, archive, artistAbi, "artistEvidenceBytesV2", [evidenceId, 1n], tag), 24575);
  equal([metadata[0], metadata[2], metadata[3]], [keccak256(archiveBytes), BigInt((archiveBytes.length - 2) / 2), BigInt(tag)], "Archive metadata differs");
  const pointer = address(metadata[1]);
  await carrier(p, pointer, archiveBytes, tag);
  const appended = one(t.logs, archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], pointer, metadata[2]]);
  if (appended.index <= contextual.index) throw Error("Archive precedes op17");
  const types = ["uint16", "bytes32", "uint16", "address", "bytes32", SNAPSHOT + "[7]", SNAPSHOT + "[7]", "bytes"];
  const envelope = coder.decode(types, archiveBytes);
  equal(coder.encode(types, envelope), archiveBytes, "Noncanonical Archive bytes");
  equal(Array.from(envelope).slice(0, 5), [1n, c.configurationHash, 17n, c.prepared.caller, recordHash]);
  const before = Array.from(envelope[5], value => tuple<OwnerSnapshot>(SNAPSHOT, value));
  const after = Array.from(envelope[6], value => tuple<OwnerSnapshot>(SNAPSHOT, value));
  const empty = { domainId: ZERO, revision: 0n, stateRoot: ZERO, recordChainTip: ZERO };
  for (let index = 0; index < 7; index++) {
    const observed = c.owners.find(row => row.index === index);
    if (!observed) { equal(before[index], empty); equal(after[index], empty); continue; }
    equal(before[index], observed.snapshot, "Archive prior owner differs");
    if (index === 2 || index === 6) {
      if (after[index]!.domainId !== domains[index] || after[index]!.revision !== before[index]!.revision + 1n
        || after[index]!.stateRoot === ZERO) throw Error("Original owner write mask/revision differs");
      if (index === 2) equal(after[index]!.recordChainTip, before[index]!.recordChainTip, "Identity op17 semantic tip must remain unchanged");
    } else equal(after[index], before[index], "Read-only owner changed");
    equal(await read(p, d.artist.components[index]!.address, artistAbi, "ownerStateSnapshotV2", [], tag), after[index], "End-block owner attribution differs");
  }
  const inner = coder.encode([BINDING, TERMS, AUTH, PROOF, "bytes32"], [c.binding, terms,
    { nonce: q.authorization.nonce, time: q.authorization.deadline, signature: q.authorization.signature },
    { signer: q.signer, digest: c.prepared.consent!.payload.digest, direct: c.prepared.consent!.direct }, c.preview.currentFamily]);
  equal(envelope[7], inner, "Original op17 flat payload differs");
  const identityBefore = c.owners.find(row => row.index === 2)!;
  const consentBefore = c.owners.find(row => row.index === 6)!;
  let firstActivityIndex = recorded.index;
  let lastActivityIndex = -1;
  const estateEvents = events(t.logs, identity, eventAbi, "ArtistEstateActivationCancelled");
  const expectedEstate = q.authorityClass === 1n && c.pendingEstateActivation !== ZERO;
  if (estateEvents.length !== (expectedEstate ? 1 : 0)) throw Error("Estate cancellation event differs");
  if (expectedEstate) {
    const event = one(t.logs, identity, "ArtistEstateActivationCancelled",
      [1n, c.binding.artistId, q.signer, 1n, c.pendingEstateActivation]);
    if (event.index >= recorded.index) throw Error("Estate cancellation order differs");
    const estate = await rpc(p, identity, artistAbi, "estateActivationState", [c.binding.artistId], tag);
    equal(estate, [ZERO_ADDRESS, 0n, ZERO], "Pending estate activation was not cleared");
    await consumedCell(p, c, 2, "identity_authority.replay.activation_cancellation_key", c.pendingEstateActivation,
      c.pendingEstateActivation, after[2]!.revision, tag);
    firstActivityIndex = lastActivityIndex = event.index;
  }
  // The finding-presence flag is private. Authenticate a supplied activity event,
  // without claiming an independently reconstructed private liveness delta.
  const activities = events(t.logs, identity, eventAbi, "ArtistUnavailabilityActivityRecorded");
  if (activities.length > 1) throw Error("Extra unavailability activity event");
  if (activities.length) {
    const previous = uint(activities[0]!.fields.previousEpoch);
    if (previous === (1n << 256n) - 1n) throw Error("Activity epoch overflow");
    const event = one(t.logs, identity, "ArtistUnavailabilityActivityRecorded",
      [1n, c.binding.artistId, q.signer, q.authorityClass, 17n, previous, previous + 1n]);
    if (event.index <= lastActivityIndex || event.index >= recorded.index) throw Error("Activity event ordering differs");
    firstActivityIndex = Math.min(firstActivityIndex, event.index);
    lastActivityIndex = event.index;
  }
  const cancel = q.authorityClass === 1n && c.notice.phase === 1n;
  let cancellationHash = ZERO;
  if (cancel) {
    const contextual = one(t.logs, identity, "ArtistDormancyCancellationContext");
    equal(contextual.fields.context, { chainId: d.chainId, registry: d.artist.registry.address, identityOwner: identity,
      recorder: q.signer, recorderAuthorityClass: 1n }, "Dormancy cancellation context differs");
    const terminal = tuple<Record<string, unknown>>(ARTIST_RECOVERY_TERMINAL_TUPLE, contextual.fields.terminal);
    const zeroTerminal = tuple<Record<string, unknown>>(ARTIST_RECOVERY_TERMINAL_TUPLE,
      coder.decode([ARTIST_RECOVERY_TERMINAL_TUPLE], "0x" + "00".repeat(608))[0]);
    const fields = { ...zeroTerminal, noticeHash: c.notice.recordHash, actor: q.signer, authorityClass: 1n, observedAt: t.observed.timestamp };
    equal({ ...terminal, recordHash: ZERO }, fields, "Dormancy terminal differs");
    const activityCount = uint(contextual.fields.activityCount);
    if (activityCount === 0n) throw Error("Missing original activity count");
    cancellationHash = digest(["bytes32", "uint256", "address", "address", ARTIST_RECOVERY_TERMINAL_TUPLE, "uint256"],
      [id("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"), d.chainId, d.artist.registry.address, identity, fields, activityCount]);
    equal([contextual.fields.schemaVersion, contextual.fields.artistId, contextual.fields.recordHash, terminal.recordHash],
      [1n, c.binding.artistId, cancellationHash, cancellationHash]);
    const cancelled = one(t.logs, identity, "ArtistDormancyCancelled", [1n, c.binding.artistId, c.notice.recordHash, q.signer, 1n, cancellationHash]);
    if (cancelled.index <= lastActivityIndex || cancelled.index >= contextual.index || contextual.index >= recorded.index) throw Error("Dormancy event ordering differs");
    firstActivityIndex = Math.min(firstActivityIndex, cancelled.index);
    const saved = await rpc(p, identity, artistAbi, "dormancyRecord", [c.notice.recordHash], tag);
    if ((saved[0] as { recordHash: Hex }).recordHash !== c.notice.recordHash || saved[1] !== 2n) throw Error("Cancelled notice differs");
    equal(saved[2], terminal);
    equal(await rpc(p, identity, artistAbi, "dormancyNotice", [c.binding.artistId], tag),
      [c.notice.recordHash, 2n, cancellationHash], "Dormancy notice cursor differs");
    await nativeRow(p, identity, identityBefore.nativeCount, after[2]!.revision,
      { operation: 42n, artistId: c.binding.artistId, collectionId: 0n, recordHash: cancellationHash }, tag);
    await consumedCell(p, c, 2, "identity_authority.replay.dormancy_cancellation_key", c.notice.recordHash, cancellationHash, after[2]!.revision, tag);
  } else if (events(t.logs, identity, eventAbi, "ArtistDormancyCancelled").length
    || events(t.logs, identity, eventAbi, "ArtistDormancyCancellationContext").length) throw Error("Unexpected dormancy cancellation");
  await nativeRow(p, consentOwner, consentBefore.nativeCount, after[6]!.revision,
    { operation: 17n, artistId: c.binding.artistId, collectionId: q.collectionId, recordHash }, tag);
  equal(await read(p, identity, artistAbi, "artistNativeReceiptCount", [], tag), identityBefore.nativeCount + (cancel ? 1n : 0n));
  equal(await read(p, consentOwner, artistAbi, "artistNativeReceiptCount", [], tag), consentBefore.nativeCount + 1n);
  if (after[6]!.recordChainTip === ZERO || after[6]!.recordChainTip === before[6]!.recordChainTip) throw Error("Consent semantic tip did not advance");
  await consumedCell(p, c, 2, "identity_authority.replay.nonce_allocator", digest(["bytes32", "uint256"], [c.binding.artistId, q.authorization.nonce]),
    c.prepared.consent!.payload.digest, after[2]!.revision, tag);
  await consumedCell(p, c, 2, "identity_authority.replay.authorization_consumed_digest", digest(["bytes32", "bytes32"], [c.binding.artistId, c.prepared.consent!.payload.digest]),
    c.prepared.consent!.payload.digest, after[2]!.revision, tag, true);
  const scope = digest([TERMS, "uint64"], [terms, c.binding.generation]);
  await consumedCell(p, c, 6, "consent_finality.replay.content_consent_key", digest(["bytes32", "bytes32"], [scope, recordHash]), recordHash, after[6]!.revision, tag);
  const identityRows = [...identityBefore.payloads];
  const sigHash = keccak256(q.authorization.signature) as Hex;
  const sigType = id("ARTIST_SIGNATURE_BUNDLE") as Hex;
  const priorSignature = identityRows.find(row => row.payloadType === sigType && row.payloadHash === sigHash);
  const ownerEvents = events(t.logs, identity, eventAbi, "ArtistStoredPayload");
  if (ownerEvents.length !== (priorSignature ? 0 : 1)) throw Error("Signature catalog events differ");
  if (!priorSignature) {
    const row = await rpc(p, identity, artistAbi, "storedPayloadAt", [BigInt(identityRows.length)], tag);
    equal(row.slice(1), [sigType, sigHash]);
    const stored = { pointer: address(row[0]), payloadType: sigType, payloadHash: sigHash };
    await carrier(p, stored.pointer, q.authorization.signature, tag);
    equal(ownerEvents[0]!.fields, { schemaVersion: 1n, index: BigInt(identityRows.length), payloadType: sigType, payloadHash: sigHash, pointer: stored.pointer });
    if (ownerEvents[0]!.index >= firstActivityIndex) throw Error("Signature storage follows Identity activity or consent");
    identityRows.push(stored);
  } else await carrier(p, priorSignature.pointer, q.authorization.signature, tag);
  equal(await catalog(p, identity, tag), identityRows, "Identity catalog delta differs");
  for (const index of [4, 6]) {
    equal(await catalog(p, d.artist.components[index]!.address, tag), c.owners.find(row => row.index === index)!.payloads);
    if (events(t.logs, d.artist.components[index]!.address, eventAbi, "ArtistStoredPayload").length) throw Error("Unexpected content-owner payload");
  }
  const expectedCatalog = [...c.archivePayloads];
  const additions: { row: PayloadRow; beforeAppend: boolean }[] = [];
  function add(row: PayloadRow, beforeAppend: boolean) {
    if (!expectedCatalog.some(old => old.payloadType === row.payloadType && old.payloadHash === row.payloadHash)) {
      expectedCatalog.push(row); additions.push({ row, beforeAppend });
    }
  }
  add({ pointer, payloadType: id("ARTIST_OPERATION_EVIDENCE") as Hex, payloadHash: keccak256(archiveBytes) as Hex }, true);
  for (const rows of [identityRows, c.owners.find(row => row.index === 4)!.payloads, consentBefore.payloads]) for (const row of rows) add(row, false);
  equal(await catalog(p, archive, tag), expectedCatalog, "Complete Archive payload catalog differs");
  const archiveEvents = events(t.logs, archive, eventAbi, "ArtistStoredPayload");
  if (archiveEvents.length !== additions.length) throw Error("Archive catalog events missing or extra");
  let lastIndex = -1;
  for (let i = 0; i < additions.length; i++) {
    const addition = additions[i]!;
    const event = archiveEvents[i]!;
    equal(event.fields, { schemaVersion: 1n, index: BigInt(c.archivePayloads.length + i), ...addition.row });
    if (event.index <= lastIndex || (addition.beforeAppend ? event.index >= appended.index : event.index <= appended.index)) throw Error("Archive catalog ordering differs");
    lastIndex = event.index;
    const runtimeBytes = bytes(await p.getCode(addition.row.pointer, tag), 24576);
    if (!runtimeBytes.startsWith("0x00") || keccak256("0x" + runtimeBytes.slice(4)) !== addition.row.payloadHash) throw Error("Archive catalog carrier differs");
  }
  if (t.safeIndex >= 0 && t.safeIndex <= Math.max(appended.index, lastIndex)) throw Error("Safe success precedes op17 evidence");
  await unchanged(p, t.observed);
  return { kind: "consent" as const, recordHash, record: expectedRecord, evidenceId, archiveBytes, before, after, cancellationHash };
}

export interface ScopedPolicyRootV2EventLocator { readonly transactionHash: Hex; readonly logIndex: number }
async function rootHistory(p: ReceiptReader, d: ScopedPolicyRootV2HistoryDeployment,
  recordHash: Hex, locator: ScopedPolicyRootV2EventLocator, tag: number) {
  await runtime(p, d.router, tag);
  for (const pin of d.linkedDependencies) await runtime(p, pin, tag);
  const record = root.normalizeScopedPolicyRootV2Record(await read(p, d.router.address, routeAbi, "scopedContentRootRecord", [recordHash], tag));
  const binding = root.normalizeScopedPolicyRootV2Binding(await read(p, d.router.address, routeAbi, "scopedPolicyContentRootBinding", [recordHash], tag));
  const raw = await p.getTransactionReceipt(locator.transactionHash);
  if (!raw || raw.status !== 1 || !same(raw.hash, locator.transactionHash) || number(raw.blockNumber) > tag) throw Error("Missing historical publication receipt");
  const blockNumber = number(raw.blockNumber);
  const blockHash = hash(raw.blockHash);
  const txFrom = address(raw.from);
  const txTo = address(raw.to);
  if (!Array.isArray(raw.logs) || raw.logs.length > MAX_LOGS) throw Error("Historical log bound exceeded");
  let previous = -1;
  let total = 0;
  const logs: CopiedLog[] = raw.logs.map(log => {
    const index = number(log.index);
    if (index <= previous || log.removed !== false || !same(log.transactionHash, locator.transactionHash)
      || log.blockNumber !== blockNumber || !same(log.blockHash, blockHash)) throw Error("Historical log identity/order differs");
    previous = index;
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error("Historical topics differ");
    const data = bytes(log.data, 65536);
    total += (data.length - 2) / 2;
    if (total > 1048576) throw Error("Historical log bytes exceeded");
    return { address: address(log.address), topics: log.topics.map((topic: string) => hash(topic, true)), data, index };
  });
  const tx = await p.getTransaction(locator.transactionHash);
  if (!tx || !same(tx.hash, locator.transactionHash) || tx.chainId !== d.chainId || tx.blockNumber !== blockNumber
    || !same(tx.blockHash, blockHash) || !same(tx.from, txFrom) || !same(tx.to, txTo)) throw Error("Historical transaction identity differs");
  const block = await header(p, blockNumber);
  equal(block.blockHash, blockHash, "Historical receipt block changed");
  if (record.publishedAt !== block.timestamp) throw Error("Historical publication timestamp differs");
  const event = events(logs, d.router.address, eventAbi, "ScopedContentRootPublished").find(e => e.index === locator.logIndex);
  if (!event) throw Error("Historical root event locator missing");
  const aggregate = root.normalizeScopedPolicyRootV2Aggregate(event.fields.collectionAggregate as root.ScopedPolicyRootV2Aggregate);
  const coord = { chainId: d.chainId, core: d.core, router: d.router.address, artistRegistry: d.artistRegistry };
  const profile = root.authenticateScopedPolicyRootV2History(coord, recordHash, record, binding, aggregate);
  const subject = graph.scopedPolicyGraphV2ScopeSubject(d.chainId, d.core, record.publication.scope);
  equal(event.fields, { schemaVersion: profile === "v2" ? 2n : 1n, collectionId: record.publication.scope.collectionId,
    scopeSubject: subject, recordHash, record, collectionAggregate: aggregate }, "Historical event/record/aggregate differs");
  if (profile === "v2") {
    const rows = events(logs, d.router.address, eventAbi, "ScopedPolicyContentRootBindingPublished").filter(row => row.fields.recordHash === recordHash);
    if (rows.length !== 1 || rows[0]!.index <= event.index) throw Error("Historical V2 binding event missing/order differs");
    equal(rows[0]!.fields, { schemaVersion: 2n, collectionId: record.publication.scope.collectionId, scopeSubject: subject, recordHash, binding });
  }
  await unchanged(p, block);
  return { recordHash, record, binding, aggregate, profile, publicationEvent: locator, published: block };
}
/** Immutable local records require their actual historical event aggregate, never the latest getter. */
export async function inspectScopedPolicyRootV2History(p: ReceiptReader, input: ScopedPolicyRootV2HistoryDeployment,
  inputRecordHash: Hex, inputLocator: ScopedPolicyRootV2EventLocator, options: { readonly blockTag: number }) {
  keys(input, ["chainId", "core", "artistRegistry", "router", "linkedDependencies"]);
  keys(inputLocator, ["transactionHash", "logIndex"]);
  keys(options, ["blockTag"]);
  const d = { chainId: uint(input.chainId), core: address(input.core), artistRegistry: address(input.artistRegistry),
    router: codePin(input.router), linkedDependencies: pinList(input.linkedDependencies) };
  const recordHash = hash(inputRecordHash);
  const locator = { transactionHash: hash(inputLocator.transactionHash), logIndex: number(inputLocator.logIndex) };
  const tag = number(options.blockTag);
  const observed = await chain(p, d.chainId, tag);
  const result = await rootHistory(p, d, recordHash, locator, tag);
  await unchanged(p, observed);
  return freeze({ deployment: d, observed, ...result, currentnessChecked: false as const, finalityEstablished: false as const });
}
/** Uses the actual provider's scoped current-root path, without reapplying publisher or Artist signature authority. */
export async function inspectScopedPolicyRootV2Current(p: Reader, input: ScopedPolicyRootV2Deployment,
  suppliedScope: graph.ScopedPolicyGraphV2Scope, options: { readonly blockTag: number }) {
  const d = deployment(input);
  const scope = graph.validateScopedPolicyGraphV2Scope(suppliedScope);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  const observed = await chain(p, d.chainId, tag);
  await runtime(p, d.router, tag);
  const recordHash = hash(await read(p, d.router.address, routeAbi, "scopedContentRootHead", [scope], tag));
  const record = root.normalizeScopedPolicyRootV2Record(await read(p, d.router.address, routeAbi, "scopedContentRootRecord", [recordHash], tag));
  equal(record.publication.scope, scope, "Current root full scope differs");
  const facts = await snapshotSource(p, d, record.publication, tag);
  const binding = root.normalizeScopedPolicyRootV2Binding(await read(p, d.router.address, routeAbi, "scopedPolicyContentRootBinding", [recordHash], tag));
  equal(binding, root.scopedPolicyRootV2BindingFromSnapshot(facts.snapshot.dependencies, facts.snapshot.source, facts.snapshot.receipt));
  equal(root.scopedPolicyRootV2StateHash(coordinates(d), record, binding), record.stateHash);
  equal([record.snapshotHost, record.snapshotCodeHash, record.snapshotManifestHash, record.snapshotSourceHash,
    record.contentRoot, record.leafCount, record.outputManifestHash, record.artistId, record.bindingGeneration, record.bindingHash],
    [facts.snapshot.pin.address, facts.snapshot.pin.codeHash, facts.snapshot.receipt.manifestHash, facts.snapshot.receipt.sourceHash,
      facts.snapshot.source.outputs.contentRoot, facts.snapshot.source.outputs.tokenCount, facts.snapshot.source.outputs.manifestHash,
      facts.snapshot.source.artist.artistId, facts.snapshot.source.artist.bindingGeneration, facts.snapshot.source.artist.bindingHash]);
  const expected = [record.contentRoot, record.leafCount, pub.SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA];
  equal(await rpc(p, d.provider.address, routeAbi, "scopedContentRoot", [scope], tag), expected, "Original provider current root differs");
  equal(await rpc(p, d.router.address, routeAbi, "scopedTokenContentRoot", [scope], tag), expected);
  await unchanged(p, observed);
  return freeze({ deployment: d, observed, recordHash, record, binding, snapshot: facts.snapshot,
    currentnessChecked: true as const, historicalAggregateAuthenticated: false as const, finalityEstablished: false as const });
}
async function rootReceipt(p: ReceiptReader, c: ScopedPolicyRootV2Capture, t: Awaited<ReturnType<typeof transport>>) {
  const d = c.preview.deployment;
  const tag = t.observed.blockNumber;
  const expected = completedRoot(c, t.observed.timestamp);
  for (const pin of [d.router, d.artist.components[6]!, ...d.linkedDependencies.root, ...d.linkedDependencies.artist]) await runtime(p, pin, tag);
  const subject = graph.scopedPolicyGraphV2ScopeSubject(d.chainId, d.core.address, c.preview.publication.scope);
  const cid = c.preview.publication.scope.collectionId;
  const published = one(t.logs, d.router.address, "ScopedContentRootPublished", [2n, cid, subject, expected.recordHash, expected.record, expected.aggregate]);
  const binding = one(t.logs, d.router.address, "ScopedPolicyContentRootBindingPublished", [2n, cid, subject, expected.recordHash, expected.binding]);
  const state = await rpc(p, d.router.address, routeAbi, "currentArtistContentState", [cid], tag);
  equal(state[0], d.router.address);
  const applied = one(t.logs, d.router.address, "ArtistContentConsentApplied", [cid, FAMILY, c.consent.recordHash, hash(state[1]), 1n]);
  if (published.index >= binding.index || binding.index >= applied.index || t.safeIndex >= 0 && t.safeIndex <= applied.index) throw Error("Root/binding/application/Safe ordering differs");
  equal(await read(p, d.router.address, routeAbi, "scopedContentRootHead", [c.preview.publication.scope], tag), expected.recordHash);
  equal(await read(p, d.router.address, routeAbi, "scopedContentRootRecord", [expected.recordHash], tag), expected.record);
  equal(await read(p, d.router.address, routeAbi, "scopedPolicyContentRootBinding", [expected.recordHash], tag), expected.binding);
  equal(await read(p, d.router.address, routeAbi, "scopedContentRootAggregate", [cid], tag), expected.aggregate, "End-block aggregate differs");
  equal(await rpc(p, d.router.address, routeAbi, "artistContentFamilyState", [cid, FAMILY], tag), [true, c.preview.nextFamily], "Post-root family differs");
  equal(await read(p, d.router.address, routeAbi, "consumedArtistContentConsent", [c.consent.recordHash], tag), true);
  equal(await read(p, d.artist.components[6]!.address, artistAbi, "contentConsentRecord", [c.consent.recordHash], tag), c.consent);
  if (c.ratification[0]) equal(await rpc(p, d.router.address, routeAbi, "artistContentEvolution", [cid], tag), [c.ratification[2], state[1]], "Ratification continuity differs");
  await unchanged(p, t.observed);
  return { kind: "root" as const, ...expected, contentStateHash: hash(state[1]),
    publicationEvent: { logIndex: published.index } };
}
/** Strict saved/prior/end-block attribution deliberately refuses unrelated same-block owner or root progress. */
export async function reconcileScopedPolicyRootV2Receipt(p: ReceiptReader, input: ScopedPolicyRootV2WorkflowCapture,
  inputTransactionHash: Hex, suppliedOptions: ScopedPolicyRootV2ReceiptOptions) {
  const saved = savedCapture(input);
  const transactionHash = hash(inputTransactionHash);
  if (suppliedOptions.execution !== "direct" && suppliedOptions.execution !== "safe") throw Error("Unknown execution transport");
  keys(suppliedOptions, suppliedOptions.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const options: ScopedPolicyRootV2ReceiptOptions = suppliedOptions.execution === "safe"
    ? { execution: "safe", expectedSafeTxHash: hash(suppliedOptions.expectedSafeTxHash) } : { execution: "direct" };
  const t = await transport(p, saved, transactionHash, options);
  const prior = await revalidate(p, saved, t.observed.blockNumber - 1);
  const result = prior.kind === "root" ? await rootReceipt(p, prior, t) : await consentReceipt(p, prior, t);
  return freeze({ transactionHash, observed: t.observed, prior, result, execution: options.execution,
    attribution: "exact-prior-and-end-block-observation" as const,
    privateIdentityActivityIndependentlyReconstructed: false as const, finalityEstablished: false as const });
}
async function localState(p: Reader, c: ScopedPolicyRootV2WorkflowCapture, tag: number) {
  const d = c.preview.deployment;
  if (c.kind === "consent") {
    return Promise.all([2, 6].map(index => read(p, d.artist.components[index]!.address, artistAbi, "ownerStateSnapshotV2", [], tag)));
  }
  return { head: await read(p, d.router.address, routeAbi, "scopedContentRootHead", [c.preview.publication.scope], tag),
    aggregate: await read(p, d.router.address, routeAbi, "scopedContentRootAggregate", [c.preview.publication.scope.collectionId], tag),
    consumed: await read(p, d.router.address, routeAbi, "consumedArtistContentConsent", [c.consent.recordHash], tag) };
}
export async function observeScopedPolicyRootV2Refusal(p: Reader, input: ScopedPolicyRootV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const c = savedCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const tag = number(options.blockTag);
  const cap = gas(options.gasLimit);
  if (tag < c.preview.observed.blockNumber) throw Error("Refusal predates capture");
  await revalidate(p, c, c.preview.observed.blockNumber);
  const d = c.preview.deployment;
  const observed = await chain(p, d.chainId, tag);
  const pins = c.kind === "consent" ? [d.artist.registry, d.artist.components[2]!, d.artist.components[6]!, ...d.linkedDependencies.artist]
    : [d.router, ...d.linkedDependencies.root];
  for (const pin of pins) await runtime(p, pin, tag);
  const before = await localState(p, c, tag);
  let failure: unknown;
  try { await p.call({ ...c.prepared.call, from: c.prepared.caller, blockTag: tag, gasLimit: cap }); }
  catch (error) { failure = error; }
  if (failure === undefined) throw Error("Original call did not refuse");
  const after = await localState(p, c, tag);
  await unchanged(p, observed);
  return { observed, error: failure, outcome: (failure as { code?: string })?.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: stable(before) === stable(after), rollbackProven: false as const };
}
