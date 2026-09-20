import { AbiCoder, Interface, ParamType, ZeroAddress as ETH_ZERO_ADDRESS, ZeroHash as ETH_ZERO_HASH, getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { requireSafeExecution } from "./safe.js";
import * as museum from "./current-museum-anchor-master.js";

export interface MuseumCodePin { readonly address: Address; readonly codeHash: Hex }
export interface MuseumAnchorDeployment { readonly chainId: bigint; readonly core: MuseumCodePin; readonly executor: MuseumCodePin }
export interface MuseumMasterDeployment extends MuseumAnchorDeployment {
  readonly metadata: MuseumCodePin; readonly masterSelection: MuseumCodePin; readonly schemaRegistry: MuseumCodePin;
  readonly externalCoverage: MuseumCodePin; readonly store: MuseumCodePin;
  readonly artist: { readonly registry: MuseumCodePin; readonly coordinator: MuseumCodePin; readonly identity: MuseumCodePin; readonly binding: MuseumCodePin; readonly attribution: MuseumCodePin };
}
export interface MuseumBlock { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
export interface MuseumGovernanceCatalog { readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly entryCount: bigint; readonly revision: bigint; readonly rowAdmission: "original-call-simulation-required" }
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const ZeroHash = ETH_ZERO_HASH as Hex;
const ZeroAddress = ETH_ZERO_ADDRESS as Address;
const coder = AbiCoder.defaultAbiCoder();
const abi = new Interface([
  "function requireRecordPublication(bytes32 attestationRecordHash, (address metadataHost, address recorder, uint256 collectionId, bytes32 subjectId, bytes32 recordType, bytes32 schemaId, bytes32 canonicalizationId, uint16 payloadAlgorithm, bytes32 payloadHash, bytes32 uriHash, uint64 effectiveAt, bytes32 candidateRecordHash) publication) view returns ((bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash))",
  "function conditionSources() view returns (address catalog, bytes32 runtimeCodeHash)",
  "function conservationFloor() view returns (address ledger, bytes32 runtimeCodeHash)",
  "function conditionSourcesTransition(address candidate) view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)",
  "function conservationFloorTransition(address candidate) view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)",
  "function collectionExists(uint256 collectionId) view returns (bool)",
  "function collectionMintedEver(uint256 collectionId) view returns (uint256)",
  "function declaredConservationTier(uint256 collectionId) view returns (bytes32)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "event ConditionSourcesBound(uint16 schemaVersion, address indexed catalog, bytes32 runtimeCodeHash, bytes32 indexed actionId)",
  "event ConservationFloorBound(uint16 schemaVersion, address indexed ledger, bytes32 runtimeCodeHash, bytes32 indexed actionId)",
  "event ConservationTierRecorded(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed tier, address indexed metadataHost)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function schemaRegistry() view returns (address)",
  "function schemaRegistryCodeHash() view returns (bytes32)",
  "function chunkStore() view returns (address)",
  "function chunkStoreCodeHash() view returns (bytes32)",
  "function artistRegistry() view returns (address)",
  "function artistRegistryCodeHash() view returns (bytes32)",
  "function governanceAuthority() view returns (address)",
  "function executorCodeHash() view returns (bytes32)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function gasParameterInfo(bytes32 parameterId) view returns (uint256 value, uint256 floor, uint8 failureClass, uint64 revision)",
  "function conservationTier(uint256 collectionId) view returns (bytes32 declared, bytes32 effective)",
  "function declareConservationTier(uint256 collectionId, bytes32 tier)",
  "function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account) view returns (bool, uint64)",
  "function recordPolicy(bytes32 recordType) view returns ((bytes32 family, uint16 authorizationMask, bool admitted))",
  "function recordCollectionRecordWithPayload(uint256 collectionId, (bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt) record, bytes payload) returns (bytes32)",
  "function recordArtistCollectionRecordWithPayload(address recorder, uint256 collectionId, (bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt) record, bytes payload, bytes32 authorization) returns (bytes32 hash)",
  "function collectionRecord(bytes32 hash) view returns ((bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt) record, (uint256 collectionId, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 schemaDefinitionHash, bytes32 canonicalizationDefinitionHash, bytes32 artistAuthorization) receipt)",
  "function collectionRecordReceipt(bytes32 hash) view returns ((uint256 collectionId, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 schemaDefinitionHash, bytes32 canonicalizationDefinitionHash, bytes32 artistAuthorization))",
  "function recordHashAt(uint256 collectionId, bytes32 recordType, uint256 index) view returns (bytes32)",
  "function recordChainHash(uint256 collectionId, bytes32 recordType) view returns (bytes32, uint64)",
  "function consumedArtistAuthorization(bytes32) view returns (bool)",
  "function mediaManifestHash(uint256 collectionId) view returns (bytes32)",
  "function mediaManifest(uint256 collectionId) view returns ((uint8 imageSourceType, string imageURI, bytes32 imageHash, string imageMimeType, uint8 animationSourceType, string animationURI, bytes32 animationHash, string animationMimeType, uint8 contentSourceType, string contentURI, bytes32 contentHash, string contentMimeType, string manifestURI, bytes32 manifestHash, string alternatesURI, bytes32 alternatesHash))",
  "event CollectionConservationTierDeclared(uint256 indexed collectionId, bytes32 indexed tier, uint16 schemaVersion)",
  "event CollectionRecordRecorded(uint256 indexed collectionId, bytes32 indexed recordType, bytes32 indexed subjectId, (bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt) record, bytes32 recordHash, bytes32 recordChainHash, address recorder, bytes32 authorizationClass, uint16 schemaVersion)",
  "event ArtistRecordAuthorizationConsumed(bytes32 indexed authorization, bytes32 indexed recordHash, address indexed recorder, address relayer)",
  "function metadata() view returns (address)",
  "function externalCoverage() view returns (address)",
  "function profileHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function adoptMaster(uint256 collectionId, bytes32 recordHash, uint64 expectedRevision, (bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt) original, (bytes32 subjectId, bytes32 selectedMediaManifestHash, uint8 mediaSlot, bytes32 displayHash, uint8 masterRole, bytes32 masterObjectHash, bytes32 coverageHash, bytes32 predecessor) witness) returns ((uint8 status, bytes32 subjectId, bytes32 manifestHash, uint8 mediaSlot, bytes32 displayHash, bytes32 objectId, (bytes32 recordHash, bytes32 payloadHash, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) original, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, bytes32 masterObjectHash, bytes32 coverageHash, uint8 masterRole, bytes32 predecessor, uint64 revision, bytes32 selectionHash) s)",
  "function adoptWaiver(uint256 collectionId, uint8 slot, bytes32 manifestHash, bytes32 recordHash, uint64 expectedRevision, (bytes32 recordType, bytes32 subjectId, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) contentHash, string uri, bytes32 schemaId, bytes32 signatureScheme, (uint16 algorithm, bytes digest, bytes32 canonicalizationId) signatureHash, uint64 effectiveAt) original, (bytes32 subjectId, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash) artist, bytes32 scopeSubjectId, (bytes32 objectId, uint8 mediaClass, uint8[] masterRoles)[] mediaObjects, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, string reason, bytes32 predecessor) witness) returns ((uint8 status, bytes32 subjectId, bytes32 manifestHash, uint8 mediaSlot, bytes32 displayHash, bytes32 objectId, (bytes32 recordHash, bytes32 payloadHash, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) original, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, bytes32 masterObjectHash, bytes32 coverageHash, uint8 masterRole, bytes32 predecessor, uint64 revision, bytes32 selectionHash) s)",
  "function currentMaster(uint256 collectionId, bytes32 subjectId, uint8 slot) view returns ((uint8 status, bytes32 subjectId, bytes32 manifestHash, uint8 mediaSlot, bytes32 displayHash, bytes32 objectId, (bytes32 recordHash, bytes32 payloadHash, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) original, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, bytes32 masterObjectHash, bytes32 coverageHash, uint8 masterRole, bytes32 predecessor, uint64 revision, bytes32 selectionHash) s)",
  "function masterSelectionAt(uint256 collectionId, bytes32 subjectId, uint8 slot, uint64 revision) view returns ((uint8 status, bytes32 subjectId, bytes32 manifestHash, uint8 mediaSlot, bytes32 displayHash, bytes32 objectId, (bytes32 recordHash, bytes32 payloadHash, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) original, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, bytes32 masterObjectHash, bytes32 coverageHash, uint8 masterRole, bytes32 predecessor, uint64 revision, bytes32 selectionHash))",
  "function collectionMediaContext(uint256 collectionId) view returns (bytes32 subjectId, bytes32 manifestHash, bytes32 inventoryHash, uint8 occupiedMask)",
  "function mediaObjectId(uint256 collectionId, bytes32 subjectId, bytes32 manifestHash, uint8 slot, bytes32 displayHash) view returns (bytes32)",
  "function requireCollectionMasters(uint256 collectionId, bytes32 subjectId) view returns (bytes32 factsHash)",
  "event MediaMasterSelected(uint256 indexed collectionId, bytes32 indexed subjectId, uint8 indexed slot, (uint8 status, bytes32 subjectId, bytes32 manifestHash, uint8 mediaSlot, bytes32 displayHash, bytes32 objectId, (bytes32 recordHash, bytes32 payloadHash, address recorder, uint8 authorizationClass, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) original, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, bytes32 masterObjectHash, bytes32 coverageHash, uint8 masterRole, bytes32 predecessor, uint64 revision, bytes32 selectionHash) selection)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function sourceSetHead() view returns (uint64 count, bytes32 head)",
  "function documentFacts(bytes32 id) view returns ((bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash) facts)",
  "function documentChunkHashAt(bytes32 id, uint256 index) view returns (bytes32)",
  "function chunk(bytes32) view returns (address pointer, uint32 length)",
  "function readChunk(bytes32 hash) view returns (bytes payload)",
  "function collectionServingSource(uint256 collectionId) view returns ((string name, string description, string imageURI, string animationBaseURI, string script))",
  "function objectIdentity(bytes32 objectHash) view returns ((bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 formatId, bytes32 formatCatalogId, bytes32 formatCatalogHash))",
  "function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 objectHash) view returns ((bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash))",
  "function operationCoordinator() view returns (address)",
  "function artistRegistry() view returns (address)",
  "function suiteConfiguration() view returns ((address registry, address archive, address[7] owners, address core, address mintManager, address roleRegistry, address metadata, address primaryResolver, address royaltyResolver, bytes32 primaryRevenueClass, address validator))",
  "function authorityState(bytes32 artistId) view returns (address authorityAddress, uint8 authorityClass, uint8 status, bytes32 identityRecordHash)",
  "function binding(uint256 collectionId) view returns ((bytes32 artistId, address artistAddress, bytes32 identityRecordHash, bytes32 bindingHash, uint64 generation, uint8 consentMode, uint8 saleConsentScope, uint8 registryImmutabilityElection, address proposer, bool accepted))",
  "function attributionState(uint256 collectionId) view returns (uint8, uint64)",
  "function attestationRecord(bytes32 record) view returns ((bytes32 recordHash, bytes32 subjectStateHash, bytes32 schemaId, bytes32 statementHash, uint64 generation, uint64 signedAt, address signer))",
  "function statementBytes(bytes32 hash) view returns (bytes)",
  "function publicationAttestation(bytes32 recordHash) view returns (((address metadataHost, address recorder, uint256 collectionId, bytes32 subjectId, bytes32 recordType, bytes32 schemaId, bytes32 canonicalizationId, uint16 payloadAlgorithm, bytes32 payloadHash, bytes32 uriHash, uint64 effectiveAt, bytes32 candidateRecordHash) publication, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) evidence, bytes32 metadataHostCodeHash))",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function governanceNonce() view returns (uint256)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function owner() view returns (address)",
  "function isProposer(address account) view returns (bool)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)"
]);
function keys(v: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).some(k => typeof k !== "string" || ![...required, ...optional].includes(k))
    || required.some(k => !Object.hasOwn(v, k))) throw Error("Missing/unknown properties");
}
function address(v: unknown): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (a === ZeroAddress) throw Error("Zero address");
  return a;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error("Expected bounded unsigned bigint");
  return v;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index");
  return v;
}
function bytes(v: unknown, max = 32768): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes");
  return v.toLowerCase() as Hex;
}
function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
function stable(v: unknown): string {
  const tagged = (x: unknown): unknown => {
    if (x === null) return ["null"];
    if (typeof x === "string" || typeof x === "boolean") return [typeof x, x];
    if (typeof x === "bigint") return ["bigint", x.toString()];
    if (typeof x === "number" && Number.isFinite(x)) return ["number", x];
    if (Array.isArray(x)) return ["array", x.map(tagged)];
    if (x && typeof x === "object") return ["object", Object.keys(x).sort().map(k => [k, tagged((x as Record<string, unknown>)[k])])];
    throw Error("Unsupported canonical value");
  };
  return JSON.stringify(tagged(v));
}
function equal(a: unknown, b: unknown, reason = "Prepared facts differ; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(b.hash), timestamp: BigInt(b.timestamp) };
}
async function unchanged(p: Reader, h: { blockNumber: number; blockHash: Hex; timestamp: bigint }): Promise<void> {
  equal(await header(p, h.blockNumber), { blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp }, "Pinned block changed");
}
async function runtime(p: Reader, v: MuseumCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}

function plain(t: ParamType, value: any): any {
  if (t.baseType === "array") return Array.from(value, item => plain(t.arrayChildren!, item));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((part, i) => [part.name, plain(part, value[i])]));
  return value;
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, from?: Address, maximum = 32768): Promise<any[]> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, ...(from ? { from } : {}) }), maximum);
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error(`Noncanonical ${name} return`);
  return abi.getFunction(name)!.outputs!.map((part, i) => plain(part, decoded[i]));
}
function pin(v: MuseumCodePin): MuseumCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}

function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function anchorDeployment(v: MuseumAnchorDeployment): MuseumAnchorDeployment {
  keys(v, ["chainId", "core", "executor"]);
  if (!uint(v.chainId)) throw Error("Zero chain");
  return freeze({ chainId: v.chainId, core: pin(v.core), executor: pin(v.executor) });
}
function masterDeployment(v: MuseumMasterDeployment): MuseumMasterDeployment {
  const names = ["core", "executor", "metadata", "masterSelection", "schemaRegistry", "externalCoverage", "store"] as const;
  keys(v, ["chainId", ...names, "artist"]);
  keys(v.artist, ["registry", "coordinator", "identity", "binding", "attribution"]);
  if (!uint(v.chainId)) throw Error("Zero chain");
  const artist = Object.fromEntries(Object.entries(v.artist).map(([k, a]) => [k, pin(a)])) as unknown as MuseumMasterDeployment["artist"];
  return freeze({ chainId: v.chainId, ...Object.fromEntries(names.map(k => [k, pin(v[k])])), artist }) as MuseumMasterDeployment;
}
function coordinates(d: MuseumMasterDeployment): museum.MuseumAnchorMasterCoordinates {
  return { chainId: d.chainId, core: d.core.address, executor: d.executor.address, metadata: d.metadata.address,
    masterSelection: d.masterSelection.address, schemaRegistry: d.schemaRegistry.address, externalCoverage: d.externalCoverage.address };
}
async function base(p: Reader, d: MuseumAnchorDeployment, tag: number): Promise<MuseumBlock> {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([runtime(p, d.core, tag), runtime(p, d.executor, tag)]);
  return h;
}
async function governance(p: Reader, d: MuseumAnchorDeployment, tag: number) {
  const b = await read(p, d.executor.address, "systemManifestBootstrapState", [], tag);
  if (b[0] !== true || b[1] !== true || (await read(p, d.executor.address, "minimumDelay", [1n], tag))[0] !== 172800n) throw Error("Only sealed ordinary class1 governance is supported");
  const [profile, catalogHash, count, revision] = await read(p, d.executor.address, "governanceActionPolicyState", [], tag);
  if (count === 0n || count > 1024n) throw Error("Unbound/oversized catalog");
  return { governanceNonce: uint((await read(p, d.executor.address, "governanceNonce", [], tag))[0]),
    catalog: { candidateProfileHash: hash(profile), catalogHash: hash(catalogHash), entryCount: uint(count), revision: uint(revision, 64),
      rowAdmission: "original-call-simulation-required" as const } };
}
export interface MuseumAnchorCapture extends MuseumBlock {
  readonly deployment: MuseumAnchorDeployment; readonly kind: "conditionSources" | "conservationFloor";
  readonly candidate: MuseumCodePin; readonly previous: museum.MuseumAnchorBindingState;
  readonly sourceHead: { readonly count: bigint; readonly head: Hex };
  readonly plan: museum.MuseumAnchorBindingPlan; readonly governanceNonce: bigint; readonly catalog: MuseumGovernanceCatalog;
  readonly captureHash: Hex;
}
/** Direct candidate observations do not prove Core's bounded nested STATICCALL admission. */
export async function captureMuseumAnchorBinding(p: Reader, input: MuseumAnchorDeployment,
  kind: MuseumAnchorCapture["kind"], candidateInput: MuseumCodePin, options: { readonly blockTag: number }): Promise<MuseumAnchorCapture> {
  keys(options, ["blockTag"]);
  const d = anchorDeployment(input), candidate = pin(candidateInput), tag = number(options.blockTag);
  if (kind !== "conditionSources" && kind !== "conservationFloor") throw Error("Unknown permanent anchor");
  const h = await base(p, d, tag);
  await runtime(p, candidate, tag);
  for (const [name, expected] of [["core", d.core.address], ["coreCodeHash", d.core.codeHash],
    ["governanceAuthority", d.executor.address], ["executorCodeHash", d.executor.codeHash]] as const) {
    if (!same((await read(p, candidate.address, name, [], tag))[0], expected)) throw Error(`Candidate ${name} differs`);
  }
  if ((await read(p, candidate.address, "deploymentChainId", [], tag))[0] !== d.chainId
    || (await read(p, candidate.address, "supportsInterface", [kind === "conditionSources" ? "0xa621c1b7" : "0xaf0adf33"], tag))[0] !== true) throw Error("Candidate chain/interface differs");
  const [count, head] = await read(p, candidate.address, "sourceSetHead", [], tag);
  const sourceHead = { count: uint(count, 64), head: hash(head) };
  const [target, runtimeCodeHash] = await read(p, d.core.address, kind, [], tag);
  const previous = museum.normalizeMuseumAnchorBindingState({ target, runtimeCodeHash });
  const plan = museum.prepareMuseumAnchorBinding({ chainId: d.chainId, core: d.core.address, executor: d.executor.address },
    { kind, candidate: candidate.address, runtimeCodeHash: candidate.codeHash, previous });
  equal(await read(p, d.core.address, `${kind}Transition`, [candidate.address], tag),
    [plan.transition.scope, plan.transition.oldHash, plan.transition.newHash], "Original anchor transition differs");
  const g = await governance(p, d, tag);
  await unchanged(p, h);
  const facts = { deployment: d, kind, candidate, previous, sourceHead, plan, ...g, ...h };
  return freeze({ ...facts, captureHash: digest(facts) });
}
function savedAnchor(v: MuseumAnchorCapture): MuseumAnchorCapture {
  keys(v, ["deployment", "kind", "candidate", "previous", "sourceHead", "plan", "governanceNonce", "catalog", "blockNumber", "blockHash", "timestamp", "captureHash"]);
  const out = structuredClone(v);
  const { captureHash, ...facts } = out;
  anchorDeployment(out.deployment); pin(out.candidate); museum.normalizeMuseumAnchorBindingPlan(out.plan);
  if (!same(digest(facts), hash(captureHash))) throw Error("Anchor capture changed");
  return freeze(out);
}
async function originalAnchor(p: Reader, c: MuseumAnchorCapture): Promise<void> {
  equal(await captureMuseumAnchorBinding(p, c.deployment, c.kind, c.candidate, { blockTag: c.blockNumber }), c, "Historical anchor capture changed");
}
export interface MuseumConservationTierRead extends MuseumBlock {
  readonly deployment: MuseumAnchorDeployment; readonly collectionId: bigint; readonly exists: boolean;
  readonly completedMints: bigint; readonly declared: Hex; readonly effective: Hex;
}
/** Raw zero for an unknown collection is kept distinct from an undeclared known collection. */
export async function readMuseumConservationTier(p: Reader, input: MuseumAnchorDeployment, collection: bigint,
  options: { readonly blockTag: number }): Promise<MuseumConservationTierRead> {
  keys(options, ["blockTag"]);
  const d = anchorDeployment(input), collectionId = uint(collection), tag = number(options.blockTag), h = await base(p, d, tag);
  const exists = (await read(p, d.core.address, "collectionExists", [collectionId], tag))[0];
  const declared = hash((await read(p, d.core.address, "declaredConservationTier", [collectionId], tag))[0], true);
  const completedMints = exists ? uint((await read(p, d.core.address, "collectionMintedEver", [collectionId], tag))[0]) : 0n;
  if (!exists && declared !== ZeroHash) throw Error("Unknown collection has a declaration");
  const tier = museum.museumConservationTier(declared, completedMints);
  await unchanged(p, h);
  return freeze({ deployment: d, collectionId, exists, completedMints, ...tier, ...h });
}
async function selected(p: Reader, d: MuseumMasterDeployment, kind: string, expected: MuseumCodePin, tag: number): Promise<void> {
  const raw = await read(p, d.core.address, "getSatellitePointer", [id(kind)], tag);
  const v = { target: raw[0], codeHash: raw[1], moduleType: raw[3], registryStatus: raw[6] };
  if (!same(v.target, expected.address) || !same(v.codeHash, expected.codeHash) || !same(v.moduleType, id(kind)) || v.registryStatus !== 1n) throw Error(`Current ${kind} pointer differs`);
}
async function bindings(p: Reader, d: MuseumMasterDeployment, tag: number, artists: boolean): Promise<void> {
  await Promise.all([d.metadata, d.masterSelection, d.schemaRegistry, d.store, d.externalCoverage].map(x => runtime(p, x, tag)));
  for (const [host, name, expected] of [
    [d.metadata, "core", d.core.address], [d.metadata, "coreCodeHash", d.core.codeHash],
    [d.metadata, "schemaRegistry", d.schemaRegistry.address], [d.metadata, "schemaRegistryCodeHash", d.schemaRegistry.codeHash],
    [d.metadata, "chunkStore", d.store.address], [d.metadata, "chunkStoreCodeHash", d.store.codeHash],
    [d.schemaRegistry, "chunkStore", d.store.address], [d.masterSelection, "core", d.core.address],
    [d.masterSelection, "metadata", d.metadata.address], [d.masterSelection, "schemaRegistry", d.schemaRegistry.address],
    [d.masterSelection, "chunkStore", d.store.address], [d.masterSelection, "externalCoverage", d.externalCoverage.address],
    [d.masterSelection, "profileHash", museum.MUSEUM_MASTER_PROFILE_HASH], [d.externalCoverage, "core", d.core.address]
  ] as const) if (!same((await read(p, host.address, name, [], tag))[0], expected)) throw Error(`Pinned ${name} binding differs`);
  if ((await read(p, d.masterSelection.address, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Master deployment chain differs");
  if (!artists) return;
  await Promise.all(Object.values(d.artist).map(x => runtime(p, x, tag)));
  for (const [host, name, expected] of [[d.metadata, "artistRegistry", d.artist.registry.address],
    [d.metadata, "artistRegistryCodeHash", d.artist.registry.codeHash], [d.artist.registry, "core", d.core.address],
    [d.artist.registry, "operationCoordinator", d.artist.coordinator.address]] as const) {
    if (!same((await read(p, host.address, name, [], tag))[0], expected)) throw Error(`Artist ${name} differs`);
  }
  if ((await read(p, d.artist.coordinator.address, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Artist coordinator chain differs");
  const [suite] = await read(p, d.artist.coordinator.address, "suiteConfiguration", [], tag);
  if (!same(suite.registry, d.artist.registry.address) || !same(suite.core, d.core.address)
    || !same(suite.owners[0], d.artist.binding.address) || !same(suite.owners[2], d.artist.identity.address)
    || !same(suite.owners[4], d.artist.attribution.address)) throw Error("Artist original suite differs");
  for (const owner of [d.artist.identity, d.artist.binding, d.artist.attribution]) {
    for (const [name, expected] of [["core", d.core.address], ["artistRegistry", d.artist.registry.address],
      ["operationCoordinator", d.artist.coordinator.address]] as const) {
      if (!same((await read(p, owner.address, name, [], tag))[0], expected)) throw Error("Artist owner binding differs");
    }
    if ((await read(p, owner.address, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Artist owner chain differs");
  }
}
async function gas(p: Reader, d: MuseumMasterDeployment, tag: number): Promise<void> {
  const cap = (await read(p, d.metadata.address, "gasParameter", [id("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS")], tag))[0];
  if (cap === 0n || cap > (1n << 64n) - 1n) throw Error("Dependency read cap differs");
  for (const name of ["6529STREAM_GGP_MEDIA_MASTER_MANIFEST_READ_GAS", "6529STREAM_GGP_MEDIA_MASTER_COVERAGE_READ_GAS"]) {
    const [value, floor, failureClass, revision] = await read(p, d.masterSelection.address, "gasParameterInfo", [id(name)], tag);
    if (value < floor || floor < 500000n || value > (1n << 64n) - 1n || failureClass !== 2n || revision === 0n) throw Error("Master read cap differs");
  }
}
async function currentContext(p: Reader, d: MuseumMasterDeployment, tag: number): Promise<void> {
  await bindings(p, d, tag, true);
  await selected(p, d, "COLLECTION_METADATA", d.metadata, tag);
  await selected(p, d, "ARTIST_REGISTRY", d.artist.registry, tag);
  await gas(p, d, tag);
}
async function chunk(p: Reader, d: MuseumMasterDeployment, contentHash: Hex, tag: number): Promise<Hex> {
  const [pointer, length] = await read(p, d.store.address, "chunk", [contentHash], tag);
  address(pointer);
  if (length === 0n || length > 8192n) throw Error("Stored payload length differs");
  const data = bytes((await read(p, d.store.address, "readChunk", [contentHash], tag, undefined, 8256))[0], 8192);
  if (BigInt((data.length - 2) / 2) !== length || !same(keccak256(data), contentHash)
    || !same(bytes(await p.getCode(pointer, tag), 8193), `0x00${data.slice(2)}`)) throw Error("Stored payload bytes/runtime differ");
  return data;
}
async function definitions(p: Reader, d: MuseumMasterDeployment, waiver: boolean, tag: number): Promise<void> {
  const rows = [[waiver ? museum.MUSEUM_MASTER_WAIVER_SCHEMA_ID : museum.MUSEUM_MASTER_SCHEMA_ID,
    0n, waiver ? museum.MUSEUM_MASTER_WAIVER_SCHEMA_HASH : museum.MUSEUM_MASTER_SCHEMA_HASH, waiver ? 2121n : 1042n],
    [id("STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1"), 2n, museum.MUSEUM_MASTER_PROFILE_HASH, 2039n],
    [museum.MUSEUM_MASTER_CANONICALIZATION_ID, 1n, museum.MUSEUM_MASTER_CANONICALIZATION_HASH, 362n]] as const;
  for (const [documentId, kind, expectedHash, length] of rows) {
    const [v] = await read(p, d.schemaRegistry.address, "documentFacts", [documentId], tag);
    if (!v.exists || v.kind !== kind || v.status !== 0n || !same(v.contentHash, expectedHash)
      || !same(v.canonicalizationId, id("RAW_BYTES")) || v.supersedesId !== ZeroHash || v.totalBytes !== length
      || v.chunkCount === 0n || v.chunkCount > 64n) throw Error("Original ACTIVE definition differs");
    hash(v.declarationHash);
    let raw = "0x";
    for (let index = 0n; index < v.chunkCount; ++index) {
      const part = await chunk(p, d, hash((await read(p, d.schemaRegistry.address, "documentChunkHashAt", [documentId, index], tag))[0]), tag);
      if (index + 1n < v.chunkCount && part.length !== 16386) throw Error("Short intermediate document chunk");
      raw += part.slice(2);
      if ((raw.length - 2) / 2 > Number(length)) throw Error("Oversized definition");
    }
    if (BigInt((raw.length - 2) / 2) !== length || !same(keccak256(raw), expectedHash)) throw Error("Retained definition differs");
  }
}
export interface MuseumMasterMediaFacts {
  readonly context: museum.MuseumMasterMediaContext; readonly displayHashes: readonly [Hex, Hex, Hex];
  readonly association: museum.MuseumMasterAssociation;
}
async function association(p: Reader, d: MuseumMasterDeployment, cid: bigint, tag: number): Promise<museum.MuseumMasterAssociation> {
  const [b] = await read(p, d.artist.binding.address, "binding", [cid], tag);
  if (b.artistId === ZeroHash) {
    if (Object.values(b).some(v => v !== ZeroHash && v !== ZeroAddress && v !== false && v !== 0n)) throw Error("Nonempty zero-Artist binding");
    return { artistId: ZeroHash, bindingHash: ZeroHash, generation: 0n, identityRecordHash: ZeroHash };
  }
  const [status, generation] = await read(p, d.artist.attribution.address, "attributionState", [cid], tag);
  const [, , , identityRecordHash] = await read(p, d.artist.identity.address, "authorityState", [b.artistId], tag);
  if (!b.accepted || ![2n, 3n].includes(status) || generation === 0n || generation !== b.generation
    || !same(hash(identityRecordHash), hash(b.identityRecordHash))) throw Error("Current Artist association differs");
  address(b.artistAddress);
  return { artistId: hash(b.artistId), bindingHash: hash(b.bindingHash), generation, identityRecordHash: hash(identityRecordHash) };
}
async function media(p: Reader, d: MuseumMasterDeployment, cid: bigint, tag: number): Promise<MuseumMasterMediaFacts> {
  const manifestHash = hash((await read(p, d.metadata.address, "mediaManifestHash", [cid], tag))[0]);
  const [m] = await read(p, d.metadata.address, "mediaManifest", [cid], tag, undefined, 16384);
  if (m.manifestURI !== "" || m.manifestHash !== ZeroHash || m.alternatesURI !== "" || m.alternatesHash !== ZeroHash) throw Error("Opaque media denominator is unsupported");
  const raw = await read(p, d.core.address, "getSatellitePointer", [id("METADATA_ROUTER")], tag);
  const router = { target: raw[0], codeHash: raw[1], registryStatus: raw[6] };
  if (router.registryStatus !== 1n) throw Error("Router is not ACTIVE");
  const routerPin = pin({ address: router.target, codeHash: router.codeHash });
  await runtime(p, routerPin, tag);
  const [serving] = await read(p, routerPin.address, "collectionServingSource", [cid], tag, undefined, 16384);
  if (serving.animationBaseURI !== "" || serving.imageURI !== m.imageURI) throw Error("Serving media denominator differs");
  let occupiedMask = 0n;
  const displayHashes = ["image", "animation", "content"].map((key, index) => {
    const source = m[`${key}SourceType`], uri = m[`${key}URI`], h = hash(m[`${key}Hash`], true);
    if (source > 8n || (source === 0n ? uri !== "" || h !== ZeroHash : uri === "" || h === ZeroHash)) throw Error("Invalid native media slot");
    if (source !== 0n) occupiedMask |= 1n << BigInt(index);
    return h;
  }) as [Hex, Hex, Hex];
  const inventoryHash = keccak256(coder.encode(["bytes32", abi.getFunction("mediaManifest")!.outputs[0]!], [id("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), m])) as Hex;
  const context = { subjectId: museum.museumMasterCollectionSubject(d.chainId, d.core.address, cid), manifestHash, inventoryHash, occupiedMask };
  equal(await read(p, d.masterSelection.address, "collectionMediaContext", [cid], tag), [context.subjectId, context.manifestHash, context.inventoryHash, context.occupiedMask], "Original media context differs");
  return { context, displayHashes, association: await association(p, d, cid, tag) };
}
function blankPublication(): museum.MuseumMasterPublicationEvidence {
  return { attestationRecordHash: ZeroHash, artistId: ZeroHash, bindingHash: ZeroHash, bindingGeneration: 0n,
    signer: ZeroAddress, authorityClass: 0n, requiredCapability: 0n, signedAt: 0n, publicationHash: ZeroHash };
}
async function publicationEvidence(p: Reader, d: MuseumMasterDeployment, cid: bigint, r: museum.MuseumMasterCollectionRecord,
  recorder: Address, authorization: Hex, tag: number, recordedAt?: bigint): Promise<museum.MuseumMasterPublicationEvidence> {
  const expected = museum.museumMasterPublication(coordinates(d), recorder, cid, r);
  const [saved] = await read(p, d.artist.attribution.address, "publicationAttestation", [authorization], tag);
  equal(saved.publication, expected.publication, "Original op24 publication differs");
  if (!same(saved.metadataHostCodeHash, d.metadata.codeHash)) throw Error("Original publication host runtime differs");
  const e = museum.normalizeMuseumMasterPublicationEvidence(saved.evidence);
  if (!same(e.attestationRecordHash, authorization) || e.authorityClass !== 1n || e.requiredCapability !== 1n
    || !same(e.signer, recorder) || e.bindingGeneration === 0n || e.signedAt === 0n
    || (recordedAt !== undefined && e.signedAt > recordedAt)
    || !same(e.publicationHash, keccak256(museum.encodeMuseumMasterPublication(expected.publication)))) throw Error("Waiver requires original principal class1 publication evidence");
  hash(e.artistId); hash(e.bindingHash);
  const [a] = await read(p, d.artist.attribution.address, "attestationRecord", [authorization], tag);
  equal(a, { recordHash: authorization, subjectStateHash: ZeroHash, schemaId: id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
    statementHash: expected.statementHash, generation: e.bindingGeneration, signedAt: e.signedAt, signer: e.signer }, "Original op24 record differs");
  equal((await read(p, d.artist.attribution.address, "statementBytes", [expected.statementHash], tag, undefined, 480))[0], expected.statement, "Original publication statement differs");
  return e;
}
async function recordPolicy(p: Reader, d: MuseumMasterDeployment, waiver: boolean, tag: number) {
  const [policy] = await read(p, d.metadata.address, "recordPolicy", [id(waiver ? "ARTIST_STATEMENT" : "MEDIA_RELATIONSHIP")], tag);
  if (!policy.admitted || !same(policy.family, id(waiver ? "6529STREAM_RECORD_FAMILY_ARTIST_V1" : "6529STREAM_RECORD_FAMILY_MEDIA_RELATIONSHIP_V1"))) throw Error("Original record policy differs");
  return museum.normalizeMuseumMasterRecordPolicy(policy);
}
export interface MuseumMasterStoredRecord {
  readonly record: museum.MuseumMasterCollectionRecord; readonly receipt: museum.MuseumMasterRecordReceipt;
  readonly evidence: museum.MuseumMasterRecordEvidence; readonly payload: Hex;
}
async function storedRecord(p: Reader, d: MuseumMasterDeployment, cid: bigint, recordHash: Hex,
  original: museum.MuseumMasterCollectionRecord, waiver: boolean, tag: number, livePolicy: boolean): Promise<MuseumMasterStoredRecord> {
  const [saved, receiptRaw] = await read(p, d.metadata.address, "collectionRecord", [recordHash], tag);
  const r = museum.normalizeMuseumMasterCollectionRecord(saved), receipt = museum.normalizeMuseumMasterRecordReceipt(receiptRaw);
  equal(r, original, "Original CollectionRecord differs");
  equal((await read(p, d.metadata.address, "collectionRecordReceipt", [recordHash], tag))[0], receipt);
  const schemaHash = waiver ? museum.MUSEUM_MASTER_WAIVER_SCHEMA_HASH : museum.MUSEUM_MASTER_SCHEMA_HASH;
  if (receipt.collectionId !== cid || receipt.recordedAt === 0n
    || !(waiver ? receipt.authorizationClass === 1n : [6n, 7n].includes(receipt.authorizationClass))
    || (!waiver && receipt.artistAuthorization !== ZeroHash) || !same(receipt.schemaDefinitionHash, schemaHash)
    || !same(receipt.canonicalizationDefinitionHash, museum.MUSEUM_MASTER_CANONICALIZATION_HASH)
    || !same(museum.museumMasterRecordHash(coordinates(d), receipt.recorder, cid, r), recordHash)) throw Error("Original record receipt differs");
  if (livePolicy) {
    const policy = await recordPolicy(p, d, waiver, tag);
    if ((policy.authorizationMask & (1n << receipt.authorizationClass)) === 0n) throw Error("Original record class no longer admitted");
  }
  if (!same((await read(p, d.metadata.address, "recordHashAt", [cid, r.recordType, receipt.recordIndex], tag))[0], recordHash)) throw Error("Original record lane differs");
  let previous = ZeroHash as Hex;
  if (receipt.recordIndex > 0n) {
    const priorHash = hash((await read(p, d.metadata.address, "recordHashAt", [cid, r.recordType, receipt.recordIndex - 1n], tag))[0]);
    const [prior] = await read(p, d.metadata.address, "collectionRecordReceipt", [priorHash], tag);
    if (prior.collectionId !== cid || prior.recordIndex + 1n !== receipt.recordIndex) throw Error("Prior native record differs");
    previous = hash(prior.recordChainHash);
  }
  if (!same(museum.museumMasterRecordChainHash(coordinates(d), cid, r.recordType, previous, recordHash, receipt.recordIndex), receipt.recordChainHash)) throw Error("Original record chain differs");
  const payloadHash = hash(r.contentHash.digest), payload = await chunk(p, d, payloadHash, tag);
  let publication = blankPublication(), publicationEvidenceHash = ZeroHash as Hex;
  if (waiver) {
    hash(receipt.artistAuthorization);
    if ((await read(p, d.metadata.address, "consumedArtistAuthorization", [receipt.artistAuthorization], tag))[0] !== true) throw Error("Artist publication was not consumed");
    publication = await publicationEvidence(p, d, cid, r, receipt.recorder, receipt.artistAuthorization, tag, receipt.recordedAt);
    const [savedPublication] = await read(p, d.artist.attribution.address, "publicationAttestation", [receipt.artistAuthorization], tag);
    publicationEvidenceHash = keccak256(coder.encode([abi.getFunction("publicationAttestation")!.outputs[0]!], [savedPublication])) as Hex;
  }
  const evidence = { recordHash, payloadHash, recorder: receipt.recorder, authorizationClass: receipt.authorizationClass,
    recordedAt: receipt.recordedAt, recordIndex: receipt.recordIndex, recordChainHash: receipt.recordChainHash,
    receiptHash: keccak256(museum.encodeMuseumMasterRecordReceipt(receipt)) as Hex, publication, publicationEvidenceHash };
  return { record: r, receipt, evidence, payload };
}
async function coverage(p: Reader, d: MuseumMasterDeployment, s: museum.MuseumMasterSelection, tag: number): Promise<Hex> {
  hash(s.association.artistId); hash(s.masterObjectHash); hash(s.coverageHash);
  const [o] = await read(p, d.externalCoverage.address, "objectIdentity", [s.masterObjectHash], tag);
  if (!same(o.artistId, s.association.artistId) || o.contentHash === ZeroHash || same(o.contentHash, s.displayHash)
    || o.sha256Digest === ZeroHash || o.arweaveDataRoot === ZeroHash || o.byteSize === 0n) throw Error("Original master object differs");
  const [c] = await read(p, d.externalCoverage.address, "requireCoverage", [s.coverageHash, s.association.artistId, s.masterObjectHash], tag);
  for (const name of ["artistId", "contentHash", "sha256Digest", "arweaveDataRoot", "byteSize"]) equal(c[name], o[name], "Original coverage/object differs");
  if (!same(c.coverageHash, s.coverageHash) || !same(c.objectHash, s.masterObjectHash)
    || !same(c.profileHash, id("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1"))) throw Error("Original coverage identity differs");
  return keccak256(coder.encode([abi.getFunction("objectIdentity")!.outputs[0]!, abi.getFunction("requireCoverage")!.outputs[0]!], [o, c])) as Hex;
}
function selection(c: museum.MuseumAnchorMasterCoordinates, cid: bigint, value: unknown): museum.MuseumMasterSelection {
  const s = museum.normalizeMuseumMasterSelection(value as museum.MuseumMasterSelection);
  if (s.status === 0n) {
    const zero = coder.getDefaultValue([museum.MUSEUM_MASTER_SELECTION_TUPLE])[0];
    equal(museum.encodeMuseumMasterSelection(s), coder.encode([museum.MUSEUM_MASTER_SELECTION_TUPLE], [zero]), "Malformed absent selection");
  } else if (s.revision === 0n || !same(museum.museumMasterSelectionHash(c, cid, s), s.selectionHash)) throw Error("Selection hash/revision differs");
  return s;
}
export interface MuseumMasterCapture extends MuseumBlock {
  readonly deployment: MuseumMasterDeployment; readonly prepared: museum.MuseumAnchorMasterCall;
  readonly media: MuseumMasterMediaFacts | null; readonly original: MuseumMasterStoredRecord | null;
  readonly previous: museum.MuseumMasterSelection | null; readonly expectedSelection: museum.MuseumMasterSelection | null;
  readonly publicationEvidence: museum.MuseumMasterPublicationEvidence | null; readonly authorizationClass: bigint | null;
  readonly captureHash: Hex;
}
export async function captureMuseumAnchorMaster(p: Reader, deploymentInput: MuseumMasterDeployment,
  callInput: museum.MuseumAnchorMasterCall, options: { readonly blockTag: number }): Promise<MuseumMasterCapture> {
  keys(options, ["blockTag"]);
  const d = masterDeployment(deploymentInput), prepared = museum.normalizeMuseumAnchorMasterCall(callInput), tag = number(options.blockTag);
  equal(prepared.coordinates, coordinates(d), "Call coordinates differ");
  const r = prepared.request, cid = r.collectionId, h = await base(p, d, tag);
  if (r.kind !== "declareConservationTier") await bindings(p, d, tag, true);
  else {
    await runtime(p, d.metadata, tag);
    equal(await read(p, d.metadata.address, "core", [], tag), [d.core.address]);
    equal(await read(p, d.metadata.address, "coreCodeHash", [], tag), [d.core.codeHash]);
  }
  if ((await read(p, d.core.address, "collectionExists", [cid], tag))[0] !== true) throw Error("Unknown collection");
  let mediaFacts: MuseumMasterMediaFacts | null = null, original: MuseumMasterStoredRecord | null = null;
  let previous: museum.MuseumMasterSelection | null = null, expectedSelection: museum.MuseumMasterSelection | null = null;
  let publication: museum.MuseumMasterPublicationEvidence | null = null, authorizationClass: bigint | null = null;
  if (r.kind === "declareConservationTier") {
    await selected(p, d, "COLLECTION_METADATA", d.metadata, tag);
    const tier = await readMuseumConservationTier(p, { chainId: d.chainId, core: d.core, executor: d.executor }, cid, { blockTag: tag });
    if (tier.declared !== ZeroHash || tier.completedMints !== 0n) throw Error("Tier already declared or collection minted");
    const [local] = await read(p, d.metadata.address, "familyWriter", [cid, id("6529STREAM_RECORD_FAMILY_CONSERVATION_V1"), 7n, prepared.caller], tag);
    const [global] = await read(p, d.metadata.address, "familyWriter", [0n, id("6529STREAM_RECORD_FAMILY_CONSERVATION_V1"), 8n, prepared.caller], tag);
    if (!local && !global) throw Error("Conservation7/global8 writer required");
  } else if (r.kind === "recordCollectionRecordWithPayload" || r.kind === "recordArtistCollectionRecordWithPayload") {
    await selected(p, d, "COLLECTION_METADATA", d.metadata, tag);
    const waiver = r.kind === "recordArtistCollectionRecordWithPayload";
    await definitions(p, d, waiver, tag);
    const policy = await recordPolicy(p, d, waiver, tag);
    if (waiver) {
      await selected(p, d, "ARTIST_REGISTRY", d.artist.registry, tag);
      if ((await read(p, d.metadata.address, "consumedArtistAuthorization", [r.authorization], tag))[0] !== false) throw Error("Artist authorization already consumed");
      publication = await publicationEvidence(p, d, cid, r.record, r.recorder, r.authorization, tag);
      const pub = museum.museumMasterPublication(coordinates(d), r.recorder, cid, r.record).publication;
      equal((await read(p, d.artist.registry.address, "requireRecordPublication", [r.authorization, pub], tag, d.metadata.address))[0], publication, "Live Artist publication admission differs");
      authorizationClass = 1n;
    } else {
      for (const cl of [3n, 4n, 6n, 7n, 8n]) {
        if (!(policy.authorizationMask & (1n << cl))) continue;
        const [local] = await read(p, d.metadata.address, "familyWriter", [cid, policy.family, cl, prepared.caller], tag);
        const [global] = await read(p, d.metadata.address, "familyWriter", [0n, policy.family, cl, prepared.caller], tag);
        if (local || global) { authorizationClass = cl; break; }
      }
      if (authorizationClass !== 6n && authorizationClass !== 7n) throw Error("Master publication needs original MEDIA6/7 writer");
    }
    if (!(policy.authorizationMask & (1n << authorizationClass))) throw Error("Record class is not admitted");
  } else {
    await currentContext(p, d, tag);
    const waiver = r.kind === "adoptWaiver";
    await definitions(p, d, waiver, tag);
    mediaFacts = await media(p, d, cid, tag);
    const slot = waiver ? r.slot : r.witness.mediaSlot, displayHash = mediaFacts.displayHashes[Number(slot) - 1]!;
    if (displayHash === ZeroHash || !(mediaFacts.context.occupiedMask & (1n << (slot - 1n)))) throw Error("Unoccupied media slot");
    const manifestHash = waiver ? r.manifestHash : r.witness.selectedMediaManifestHash;
    if (!same(manifestHash, mediaFacts.context.manifestHash) || !same(r.original.subjectId, mediaFacts.context.subjectId)) throw Error("Current media/subject differs");
    original = await storedRecord(p, d, cid, r.recordHash, r.original, waiver, tag, true);
    equal(original.payload, prepared.payload!.canonical, "Original canonical witness differs");
    previous = selection(coordinates(d), cid, (await read(p, d.masterSelection.address, "currentMaster", [cid, mediaFacts.context.subjectId, slot], tag))[0]);
    if (previous.revision !== r.expectedRevision || !same(r.witness.predecessor, previous.original.recordHash)
      || same(r.recordHash, previous.original.recordHash) || r.expectedRevision === (1n << 64n) - 1n) throw Error("Master predecessor/revision differs");
    const status = waiver ? 2n : 1n;
    if (previous.status !== 0n && (original.evidence.recordedAt < previous.original.recordedAt
      || (previous.status === status && original.evidence.recordIndex <= previous.original.recordIndex))) throw Error("Original record lineage regressed");
    const objectId = museum.museumMasterObjectId(coordinates(d), cid, mediaFacts.context.subjectId, manifestHash, slot, displayHash);
    let masterRole: 0n | 1n;
    if (waiver) {
      hash(mediaFacts.association.artistId);
      equal(r.witness.artist, { artistId: mediaFacts.association.artistId, bindingGeneration: mediaFacts.association.generation, bindingHash: mediaFacts.association.bindingHash }, "Waiver current association differs");
      const e = original.evidence.publication;
      if (!same(e.artistId, mediaFacts.association.artistId) || !same(e.bindingHash, mediaFacts.association.bindingHash)
        || e.bindingGeneration !== mediaFacts.association.generation) throw Error("Waiver publication association differs");
      const object = r.witness.mediaObjects.find(x => same(x.objectId, objectId));
      if (!object) throw Error("Waiver omits selected media object");
      masterRole = object.masterRoles[0]!;
    } else {
      if (!same(r.witness.displayHash, displayHash)) throw Error("Master display hash differs");
      masterRole = r.witness.masterRole;
    }
    const next: museum.MuseumMasterSelection = { status, subjectId: mediaFacts.context.subjectId, manifestHash, mediaSlot: slot,
      displayHash, objectId, original: original.evidence, association: mediaFacts.association,
      masterObjectHash: waiver ? ZeroHash : r.witness.masterObjectHash, coverageHash: waiver ? ZeroHash : r.witness.coverageHash,
      masterRole, predecessor: r.witness.predecessor, revision: r.expectedRevision + 1n, selectionHash: ZeroHash };
    expectedSelection = { ...next, selectionHash: museum.museumMasterSelectionHash(coordinates(d), cid, next) };
    if (!waiver) await coverage(p, d, expectedSelection, tag);
  }
  await unchanged(p, h);
  const facts = { deployment: d, prepared, media: mediaFacts, original, previous, expectedSelection, publicationEvidence: publication, authorizationClass, ...h };
  return freeze({ ...facts, captureHash: digest(facts) });
}
function savedMaster(v: MuseumMasterCapture): MuseumMasterCapture {
  keys(v, ["deployment", "prepared", "media", "original", "previous", "expectedSelection", "publicationEvidence", "authorizationClass", "blockNumber", "blockHash", "timestamp", "captureHash"]);
  const out = structuredClone(v), { captureHash, ...facts } = out;
  masterDeployment(out.deployment); museum.normalizeMuseumAnchorMasterCall(out.prepared);
  if (!same(digest(facts), hash(captureHash))) throw Error("Master capture changed");
  return freeze(out);
}
async function originalMaster(p: Reader, c: MuseumMasterCapture): Promise<void> {
  equal(await captureMuseumAnchorMaster(p, c.deployment, c.prepared, { blockTag: c.blockNumber }), c, "Historical Museum capture changed");
}
export interface MuseumMasterSimulation extends MuseumBlock {
  readonly capture: MuseumMasterCapture; readonly observed: MuseumMasterCapture; readonly returnData: Hex;
  readonly admission: "original-call simulation; direct dependency reads do not establish nested gas equivalence";
}
export async function simulateMuseumAnchorMaster(p: Reader, input: MuseumMasterCapture,
  options: { readonly blockTag: number }): Promise<MuseumMasterSimulation> {
  keys(options, ["blockTag"]);
  const c = savedMaster(input), tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await originalMaster(p, c);
  const observed = await captureMuseumAnchorMaster(p, c.deployment, c.prepared, { blockTag: tag });
  equal(observed.expectedSelection, c.expectedSelection, "Adoption facts changed; recapture");
  equal(observed.authorizationClass, c.authorizationClass, "Writer class changed; recapture");
  const raw = bytes(await p.call({ ...c.prepared.call, from: c.prepared.caller, blockTag: tag }), 262144);
  const name = c.prepared.request.kind, decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error("Noncanonical original call return");
  if (name === "adoptMaster" || name === "adoptWaiver") equal(plain(abi.getFunction(name)!.outputs[0]!, decoded[0]), c.expectedSelection, "Simulated selection differs");
  else if (name !== "declareConservationTier" && !same(decoded[0], c.prepared.recordHash)) throw Error("Simulated record differs");
  await unchanged(p, observed);
  return freeze({ capture: c, observed, returnData: raw, blockNumber: observed.blockNumber, blockHash: observed.blockHash,
    timestamp: observed.timestamp, admission: "original-call simulation; direct dependency reads do not establish nested gas equivalence" });
}
export interface MuseumMasterSelectionRead extends MuseumBlock {
  readonly deployment: MuseumMasterDeployment; readonly collectionId: bigint; readonly subjectId: Hex; readonly slot: bigint;
  readonly revision: bigint | null; readonly selection: museum.MuseumMasterSelection;
  readonly interpretation: "retained selection; no current closure claim";
}
/** Original raw getters remain available after current manifest, Artist, catalog or coverage changes. */
export async function readMuseumMasterSelection(p: Reader, input: MuseumMasterDeployment,
  request: { readonly collectionId: bigint; readonly subjectId: Hex; readonly slot: bigint; readonly revision?: bigint },
  options: { readonly blockTag: number }): Promise<MuseumMasterSelectionRead> {
  keys(request, ["collectionId", "subjectId", "slot"], ["revision"]); keys(options, ["blockTag"]);
  const d = masterDeployment(input), cid = uint(request.collectionId), subjectId = hash(request.subjectId, true), slot = uint(request.slot, 8);
  const revision = request.revision === undefined ? null : uint(request.revision, 64), tag = number(options.blockTag);
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await runtime(p, d.masterSelection, tag);
  const s = selection(coordinates(d), cid, (await read(p, d.masterSelection.address, revision === null ? "currentMaster" : "masterSelectionAt",
    revision === null ? [cid, subjectId, slot] : [cid, subjectId, slot, revision], tag))[0]);
  if (s.status !== 0n && (!same(s.subjectId, subjectId) || s.mediaSlot !== slot || (revision !== null && s.revision !== revision))) throw Error("Selection coordinates differ");
  await unchanged(p, h);
  return freeze({ deployment: d, collectionId: cid, subjectId, slot, revision, selection: s, ...h, interpretation: "retained selection; no current closure claim" });
}
export interface MuseumCollectionMastersRead extends MuseumBlock {
  readonly deployment: MuseumMasterDeployment; readonly collectionId: bigint; readonly media: MuseumMasterMediaFacts;
  readonly selections: readonly museum.MuseumMasterSelection[]; readonly factsHash: Hex;
}
export async function requireMuseumCollectionMasters(p: Reader, input: MuseumMasterDeployment, collection: bigint,
  options: { readonly blockTag: number }): Promise<MuseumCollectionMastersRead> {
  keys(options, ["blockTag"]);
  const d = masterDeployment(input), cid = uint(collection), tag = number(options.blockTag), h = await base(p, d, tag);
  await currentContext(p, d, tag);
  const m = await media(p, d, cid, tag), selections: museum.MuseumMasterSelection[] = [];
  let factsHash = museum.museumMasterFactsHash(coordinates(d), cid, m.context, m.displayHashes, m.association);
  for (let slot = 1n; slot <= 3n; ++slot) {
    if (!(m.context.occupiedMask & (1n << (slot - 1n)))) continue;
    const s = selection(coordinates(d), cid, (await read(p, d.masterSelection.address, "currentMaster", [cid, m.context.subjectId, slot], tag))[0]);
    if (s.status === 0n || !same(s.subjectId, m.context.subjectId) || s.mediaSlot !== slot
      || !same(s.manifestHash, m.context.manifestHash) || !same(s.displayHash, m.displayHashes[Number(slot) - 1])) throw Error("Current master denominator is incomplete");
    equal(s.association, m.association, "Current master association changed");
    await definitions(p, d, s.status === 2n, tag);
    if (s.status === 2n) hash(s.association.artistId);
    const archiveHash = s.status === 1n ? await coverage(p, d, s, tag) : ZeroHash;
    factsHash = museum.museumMasterAppendFactsHash(factsHash, slot, s.selectionHash, archiveHash);
    selections.push(s);
  }
  equal(await read(p, d.masterSelection.address, "requireCollectionMasters", [cid, m.context.subjectId], tag), [factsHash], "Original closure facts differ");
  await unchanged(p, h);
  return freeze({ deployment: d, collectionId: cid, media: m, selections, factsHash, ...h });
}
export interface PreparedMuseumAnchorGovernance { readonly capture: MuseumAnchorCapture; readonly proposer: Address; readonly batch: museum.MuseumAnchorGovernanceBatch }
export interface MuseumAnchorGovernanceOperation {
  readonly prepared: PreparedMuseumAnchorGovernance; readonly stage: "publish" | "schedule" | "execute";
  readonly caller: Address; readonly call: UnsignedCall;
}
export function prepareMuseumAnchorGovernance(input: MuseumAnchorCapture, proposer: Address,
  window: museum.MuseumAnchorGovernanceWindow): PreparedMuseumAnchorGovernance {
  const c = savedAnchor(input), batch = museum.museumAnchorGovernanceBatch(c.plan, c.governanceNonce, window);
  museum.assertMuseumAnchorGovernanceWindow(batch.window, c.timestamp);
  if (toUtf8Bytes(batch.window.reasonURI).length > 2048) throw Error("Reason URI exceeds client bound");
  return freeze({ capture: c, proposer: address(proposer), batch });
}
function preparedGovernance(v: PreparedMuseumAnchorGovernance): PreparedMuseumAnchorGovernance {
  keys(v, ["capture", "proposer", "batch"]);
  const b = museum.normalizeMuseumAnchorGovernanceBatch(v.batch), out = prepareMuseumAnchorGovernance(v.capture, v.proposer, b.window);
  equal(out, v);
  return out;
}
export function prepareMuseumAnchorGovernanceOperation(input: PreparedMuseumAnchorGovernance,
  stage: MuseumAnchorGovernanceOperation["stage"], caller: Address): MuseumAnchorGovernanceOperation {
  const prepared = preparedGovernance(input), actor = address(caller);
  if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unknown governance stage");
  if (stage === "schedule" && !same(actor, prepared.proposer)) throw Error("Schedule caller differs");
  return freeze({ prepared, stage, caller: actor, call: stage === "publish" ? prepared.batch.publicationCall
    : stage === "schedule" ? prepared.batch.scheduleCall : prepared.batch.executionCall });
}
function governanceOperation(v: MuseumAnchorGovernanceOperation): MuseumAnchorGovernanceOperation {
  keys(v, ["prepared", "stage", "caller", "call"]);
  const out = prepareMuseumAnchorGovernanceOperation(v.prepared, v.stage, v.caller);
  equal(out, v);
  return out;
}
async function publication(p: Reader, b: museum.MuseumAnchorGovernanceBatch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.plan.coordinates.executor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = coder.encode(["bytes[]"], [[b.plan.call.data]]);
  if (!same(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`)) throw Error("Published bytes differ");
  return pointer;
}
async function action(p: Reader, o: MuseumAnchorGovernanceOperation, tag: number) {
  const b = o.prepared.batch, [a] = await read(p, b.plan.coordinates.executor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: 1n, target: b.plan.call.to, value: 0n, selector: b.plan.governanceCall.selector,
    callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash,
    notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer,
    reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) {
    if (a[key] !== value && (key === "reasonURI" || !same(a[key], value))) throw Error(`Scheduled ${key} differs`);
  }
  equal((await read(p, b.plan.coordinates.executor, "scheduledCallData", [b.actionId], tag))[0], [b.plan.call.data]);
  const ptr = await publication(p, b, tag);
  if (!ptr || !same((await read(p, b.plan.coordinates.executor, "scheduledCallDataPointer", [b.actionId], tag))[0], ptr)) throw Error("Scheduled pointer differs");
  return a;
}
export interface MuseumAnchorGovernanceSimulation extends MuseumBlock {
  readonly operation: MuseumAnchorGovernanceOperation; readonly returnData: Hex;
}
export async function simulateMuseumAnchorGovernance(p: Reader, input: MuseumAnchorGovernanceOperation,
  options: { readonly blockTag: number }): Promise<MuseumAnchorGovernanceSimulation> {
  keys(options, ["blockTag"]);
  const o = governanceOperation(input), c = o.prepared.capture, d = c.deployment, b = o.prepared.batch, tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await originalAnchor(p, c);
  const h = await base(p, d, tag);
  if (o.stage !== "publish") {
    const fresh = await captureMuseumAnchorBinding(p, d, c.kind, c.candidate, { blockTag: tag });
    equal(fresh.plan, c.plan, "Permanent anchor changed");
    equal(fresh.catalog, c.catalog, "Catalog changed; rebuild and reschedule");
    if (o.stage === "schedule") {
      museum.assertMuseumAnchorGovernanceWindow(b.window, h.timestamp);
      if (fresh.governanceNonce !== b.nonce || !await publication(p, b, tag)) throw Error("Nonce changed or call data not published");
      const [owner] = await read(p, d.executor.address, "owner", [], tag);
      if (!same(owner, o.caller) && (await read(p, d.executor.address, "isProposer", [o.caller], tag))[0] !== true) throw Error("Unauthorized proposer");
    } else {
      const a = await action(p, o, tag);
      if (a.status !== 1n || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Action is not executable");
    }
  }
  const previous = o.stage === "publish" ? await publication(p, b, tag) : null;
  const raw = bytes(await p.call({ ...o.call, from: o.caller, blockTag: tag }));
  if (o.stage === "execute") { if (raw !== "0x") throw Error("Noncanonical execution return"); }
  else {
    const name = o.stage === "publish" ? "publishGovernanceCallData" : "scheduleGovernanceBatch", result = abi.decodeFunctionResult(name, raw);
    if (!same(abi.encodeFunctionResult(name, result), raw)) throw Error("Noncanonical governance return");
    if (o.stage === "schedule" && !same(result[0], b.actionId)) throw Error("Simulated action differs");
    if (o.stage === "publish") { address(result[0]); if (previous && !same(previous, result[0])) throw Error("Publication pointer changed"); }
  }
  await unchanged(p, h);
  return freeze({ operation: o, ...h, returnData: raw });
}
export type MuseumReceiptOptions = { readonly transactionHash: Hex; readonly execution: "direct" }
  | { readonly transactionHash: Hex; readonly execution: "safe"; readonly expectedSafeTxHash: Hex };
export interface MuseumEventReference { readonly address: Address; readonly event: string; readonly logIndex: number; readonly transactionHash: Hex; readonly blockHash: Hex }
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
async function receipt(p: ReceiptReader, chainId: bigint, captureBlock: number, caller: Address, call: UnsignedCall,
  transactionHash: Hex, execution: "direct" | "safe", expectedSafeTxHash?: Hex) {
  const [r, tx] = await Promise.all([p.getTransactionReceipt(transactionHash), p.getTransaction(transactionHash)]);
  if (!r || !tx || r.status !== 1 || !same(r.hash, transactionHash) || !same(tx.hash, transactionHash)
    || tx.chainId !== chainId || tx.value !== 0n || r.blockNumber <= captureBlock || tx.blockNumber !== r.blockNumber
    || !same(tx.blockHash, r.blockHash) || !same(tx.to, r.to) || !same(tx.from, r.from)) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 262144);
  if (execution === "direct") {
    if (!same(tx.from, caller) || !same(tx.to, call.to) || !same(data, call.data)) throw Error("Direct call differs");
  } else if (execution === "safe") {
    const v = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(tx.to, caller) || !same(safeAbi.encodeFunctionData("execTransaction", v), data)
      || !same(v[0], call.to) || v[1] !== 0n || !same(v[2], call.data) || v[3] !== 0n) throw Error("Safe requires exact ordinary zero-value CALL");
  } else throw Error("Unknown execution transport");
  const tag = number(r.blockNumber), h = await header(p, tag);
  if (!same(h.blockHash, r.blockHash)) throw Error("Receipt block changed");
  if (!Array.isArray(r.logs) || r.logs.length > 256) throw Error("Receipt exceeds256 logs");
  const logs: Log[] = r.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== tag || !same(l.blockHash, h.blockHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed log identity");
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 32768), index: number(l.index) };
  });
  if (logs.some((l, i) => i > 0 && l.index <= logs[i - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const events: MuseumEventReference[] = [];
  function found(target: Address, name: string, iface = abi) {
    const f = iface.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], f.topicHash)).map(log => {
      const args = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, args);
      if (!same(encoded.data, log.data)) throw Error(`Noncanonical ${name} event`);
      equal(encoded.topics.map(v => v.toLowerCase()), log.topics);
      return { log, args: f.inputs.map((part, index) => plain(part, args[index])) };
    });
  }
  function one(target: Address, name: string, expected: readonly unknown[]) {
    const rows = found(target, name);
    if (rows.length !== 1) throw Error(`Expected exactly one ${name}`);
    equal(rows[0]!.args, expected, `${name} fields differ`);
    const log = rows[0]!.log;
    events.push({ address: log.address, event: name, logIndex: log.index, transactionHash, blockHash: h.blockHash });
    return log.index;
  }
  function finish() {
    if (execution === "safe") {
      requireSafeExecution({ status: 1, logs: logs.map(({ address, topics, data }) => ({ address, topics: [...topics], data })) }, caller, expectedSafeTxHash!);
      const successes = logs.filter(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
      if (successes.length !== 1 || logs.some(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionFailure")!.topicHash))) throw Error("Safe requires one success and no failure");
      const log = successes[0]!, iface = log.topics.length === 2 ? safeIndexed : safePlain;
      const f = iface.getEvent("ExecutionSuccess")!, args = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, args);
      if (!same(encoded.data, log.data)) throw Error("Noncanonical Safe success");
      equal(encoded.topics.map(x => x.toLowerCase()), log.topics);
      if (events.some(e => e.logIndex >= log.index)) throw Error("Safe success precedes required events");
      events.push({ address: log.address, event: "ExecutionSuccess", logIndex: log.index, transactionHash, blockHash: h.blockHash });
    }
    return events.sort((a, b) => a.logIndex - b.logIndex);
  }
  return { ...h, found, one, finish };
}
export interface MuseumAnchorMasterReceipt extends MuseumBlock {
  readonly capture: MuseumMasterCapture; readonly transactionHash: Hex; readonly events: readonly MuseumEventReference[];
  readonly selection: museum.MuseumMasterSelection | null; readonly original: MuseumMasterStoredRecord | null;
  readonly stateAttribution: "operation events and immutable records; no latest-state or collection-finality claim";
}
export async function inspectMuseumAnchorMasterReceipt(p: ReceiptReader, input: MuseumMasterCapture,
  options: MuseumReceiptOptions): Promise<MuseumAnchorMasterReceipt> {
  keys(options, ["transactionHash", "execution"], options.execution === "safe" ? ["expectedSafeTxHash"] : []);
  const expectedSafeTxHash = options.execution === "safe" ? hash(options.expectedSafeTxHash) : undefined;
  const c = savedMaster(input), d = c.deployment, prepared = c.prepared, transactionHash = hash(options.transactionHash);
  const execution = options.execution;
  if (execution !== "direct" && execution !== "safe") throw Error("Unknown execution");
  await originalMaster(p, c);
  const m = await receipt(p, d.chainId, c.blockNumber, prepared.caller, prepared.call, transactionHash, execution, expectedSafeTxHash), tag = m.blockNumber;
  await base(p, d, tag);
  const r = prepared.request, cid = r.collectionId;
  await runtime(p, d.metadata, tag);
  let retained: museum.MuseumMasterSelection | null = null, original: MuseumMasterStoredRecord | null = null;
  if (r.kind === "declareConservationTier") {
    const coreIndex = m.one(d.core.address, "ConservationTierRecorded", [1n, cid, r.tier, d.metadata.address]);
    const metadataIndex = m.one(d.metadata.address, "CollectionConservationTierDeclared", [cid, r.tier, 1n]);
    if (coreIndex >= metadataIndex) throw Error("Tier event order differs");
    if (!same((await read(p, d.core.address, "declaredConservationTier", [cid], tag))[0], r.tier)) throw Error("Permanent tier readback differs");
  } else if (r.kind === "adoptMaster" || r.kind === "adoptWaiver") {
    await runtime(p, d.masterSelection, tag);
    const expected = c.expectedSelection!;
    m.one(d.masterSelection.address, "MediaMasterSelected", [cid, expected.subjectId, expected.mediaSlot, expected]);
    retained = selection(coordinates(d), cid, (await read(p, d.masterSelection.address, "masterSelectionAt",
      [cid, expected.subjectId, expected.mediaSlot, expected.revision], tag))[0]);
    equal(retained, expected, "Retained historical selection differs");
    await runtime(p, d.store, tag);
    if (r.kind === "adoptWaiver") await runtime(p, d.artist.attribution, tag);
    original = await storedRecord(p, d, cid, r.recordHash, r.original, r.kind === "adoptWaiver", tag, false);
    equal(original.evidence, expected.original, "Historical original record changed");
    equal(original.payload, prepared.payload!.canonical);
  } else {
    const waiver = r.kind === "recordArtistCollectionRecordWithPayload", recorder = waiver ? r.recorder : prepared.caller;
    await runtime(p, d.store, tag);
    if (waiver) await runtime(p, d.artist.attribution, tag);
    original = await storedRecord(p, d, cid, prepared.recordHash!, r.record, waiver, tag, false);
    if (original.receipt.recordedAt !== m.timestamp || original.receipt.authorizationClass !== c.authorizationClass
      || !same(original.receipt.recorder, recorder)) throw Error("Published record timestamp/writer differs");
    equal(original.payload, prepared.payload!.canonical);
    const cl = `0x${original.receipt.authorizationClass.toString(16).padStart(64, "0")}`;
    const publishedIndex = m.one(d.metadata.address, "CollectionRecordRecorded", [cid, r.record.recordType, r.record.subjectId,
      r.record, prepared.recordHash, original.receipt.recordChainHash, recorder, cl, 1n]);
    const consumptions = m.found(d.metadata.address, "ArtistRecordAuthorizationConsumed");
    if (waiver) {
      if (!same(original.receipt.artistAuthorization, r.authorization)) throw Error("Consumed Artist authorization differs");
      const consumedIndex = m.one(d.metadata.address, "ArtistRecordAuthorizationConsumed", [r.authorization, prepared.recordHash, recorder, prepared.caller]);
      if (consumedIndex <= publishedIndex) throw Error("Artist authorization event order differs");
    } else if (consumptions.length) throw Error("MEDIA publication cannot consume an Artist authorization");
  }
  const events = m.finish();
  await unchanged(p, m);
  return freeze({ capture: c, transactionHash, blockNumber: tag, blockHash: m.blockHash, timestamp: m.timestamp, events,
    selection: retained, original, stateAttribution: "operation events and immutable records; no latest-state or collection-finality claim" });
}
export interface MuseumAnchorGovernanceReceipt extends MuseumBlock {
  readonly operation: MuseumAnchorGovernanceOperation; readonly transactionHash: Hex; readonly events: readonly MuseumEventReference[];
  readonly binding: museum.MuseumAnchorBindingState | null;
}
export async function inspectMuseumAnchorGovernanceReceipt(p: ReceiptReader, input: MuseumAnchorGovernanceOperation,
  options: MuseumReceiptOptions): Promise<MuseumAnchorGovernanceReceipt> {
  keys(options, ["transactionHash", "execution"], options.execution === "safe" ? ["expectedSafeTxHash"] : []);
  const expectedSafeTxHash = options.execution === "safe" ? hash(options.expectedSafeTxHash) : undefined;
  const o = governanceOperation(input), c = o.prepared.capture, d = c.deployment, b = o.prepared.batch;
  const transactionHash = hash(options.transactionHash), execution = options.execution;
  if (execution !== "direct" && execution !== "safe") throw Error("Unknown execution");
  await originalAnchor(p, c);
  const m = await receipt(p, d.chainId, c.blockNumber, o.caller, o.call, transactionHash, execution, expectedSafeTxHash), tag = m.blockNumber;
  await base(p, d, tag);
  let binding: museum.MuseumAnchorBindingState | null = null;
  if (o.stage === "publish") {
    const pointer = await publication(p, b, tag);
    if (!pointer) throw Error("Publication not retained");
    const prior = await header(p, tag - 1);
    await runtime(p, d.executor, tag - 1);
    const previousPointer = await publication(p, b, tag - 1);
    if (previousPointer && !same(previousPointer, pointer)) throw Error("Immutable pointer changed");
    if (m.found(d.executor.address, "GovernanceCallDataPublished").length) {
      if (previousPointer) throw Error("Retry cannot emit first publication");
      m.one(d.executor.address, "GovernanceCallDataPublished", [1n, b.publicationKey, pointer, o.caller]);
    } else if (!previousPointer) throw Error("Eventless publication needs prior-block proof");
    await unchanged(p, prior);
  } else {
    const g = await governance(p, d, tag), state = await action(p, o, tag);
    equal(g.catalog, c.catalog, "Catalog changed after review");
    const common = [1n, b.actionId, 1n, d.core.address, 0n, c.plan.governanceCall.selector,
      b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
    const validated = m.one(d.executor.address, "GovernanceActionPolicyValidated", [1n, b.actionId,
      o.stage === "schedule" ? 1n : 2n, c.catalog.candidateProfileHash, c.catalog.catalogHash]);
    if (o.stage === "schedule") {
      museum.assertMuseumAnchorGovernanceWindow(b.window, m.timestamp);
      if (![1n, 2n].includes(state.status) || g.governanceNonce < b.nonce + 1n) throw Error("Scheduled action/nonce differs");
      const scheduled = m.one(d.executor.address, "GovernanceActionScheduled", [...common, b.window.notBefore, b.window.expiresAfter,
        b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      if (validated <= scheduled) throw Error("Policy event must follow Scheduled");
      if (m.found(d.core.address, "ConditionSourcesBound").length || m.found(d.core.address, "ConservationFloorBound").length) throw Error("Scheduling cannot bind an anchor");
    } else {
      if (state.status !== 3n || !same(state.executor, o.caller) || m.timestamp < b.window.notBefore || m.timestamp > b.window.expiresAfter) throw Error("Executed action/window differs");
      const bound = m.one(d.core.address, c.kind === "conditionSources" ? "ConditionSourcesBound" : "ConservationFloorBound",
        [1n, c.candidate.address, c.candidate.codeHash, b.actionId]);
      const executed = m.one(d.executor.address, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]);
      if (!(bound < executed && executed < validated)) throw Error("Anchor/governance event order differs");
      const [target, runtimeCodeHash] = await read(p, d.core.address, c.kind, [], tag);
      binding = museum.normalizeMuseumAnchorBindingState({ target, runtimeCodeHash });
      equal(binding, { target: c.candidate.address, runtimeCodeHash: c.candidate.codeHash }, "Permanent anchor differs");
      await runtime(p, c.candidate, tag);
    }
  }
  const events = m.finish();
  await unchanged(p, m);
  return freeze({ operation: o, transactionHash, blockNumber: tag, blockHash: m.blockHash, timestamp: m.timestamp, events, binding });
}
