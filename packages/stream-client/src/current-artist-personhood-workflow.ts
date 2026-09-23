import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256,
  toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { CurrentArtistDeployment } from "./current-artist-workflow.js";
import { currentArtistTypedData } from "./current-artist.js";
import { requireSafeExecution } from "./safe.js";
import { ARTIST_RECOVERY_NOTICE_TUPLE, ARTIST_RECOVERY_TERMINAL_TUPLE } from "./current-artist-recovery-adjudication.js";
import * as personhood from "./current-artist-personhood.js";

const BINDING = "(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const AUTH = "(uint256 nonce,uint64 time,bytes signature)";
const TERMS = "(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI)";
const PROOF = "(address signer,bytes32 digest,bool direct)";
const AUTHORITY = "(bytes32 artistId,address authorityAddress,uint8 authorityClass,uint8 status)";
const SNAPSHOT = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const GENERAL_RECORD = "(address attester,uint256 collectionId,bytes32 subjectId,bytes32 attestationType,string attesterDID,bytes32 schemaId,bytes32 canonicalizationId,string statementURI,bytes32 statementHash,bytes32 supersedes,bytes32 artistAuthorizationRecordHash,uint64 effectiveAt)";
const GENERAL_RECEIPT = "(address recorder,uint8 verificationClass,uint8 authorityQualification,uint64 recordedAt,uint64 recordIndex,bytes32 recordChainHash,bytes32 authorizationDigest,uint256 nonce,uint64 deadline,bytes32 signatureScheme,bytes32 signatureBundleHash,bytes32 schemaDefinitionHash,bytes32 canonicalizationDefinitionHash,bytes32 profileDefinitionHash,bytes32 authorityFamily,uint8 authorizationClass,uint256 grantCollectionId,uint64 grantRevision,address identityRegistry,bytes32 identityRegistryCodeHash,bytes32 artistId,bytes32 operativeIdentityRecordHash,bytes32 nativeArtistEvidenceHash,uint8 nativeArtistAuthorityClass)";
const SUBJECT = "(uint8 kind,uint256 collectionId,uint256 tokenId,bytes32 objectId)";
const MODULE = "(uint8 status,bytes32 moduleType,bytes32 moduleVersion,bytes4 interfaceId,uint32 moduleGasLimit,bytes32 runtimeCodeHash,bytes32 deploymentManifestHash,bytes32 moduleManifestHash,string moduleManifestURI,uint64 registeredAt,uint64 statusUpdatedAt,uint64 revision)";
const DOCUMENT = "(bool exists,uint8 kind,uint8 status,bytes32 contentHash,bytes32 canonicalizationId,bytes32 supersedesId,uint32 totalBytes,uint256 chunkCount,bytes32 declarationHash)";
const NATIVE = "(uint16 operation,bytes32 artistId,uint256 collectionId,bytes32 recordHash)";
const coder = AbiCoder.defaultAbiCoder();
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(v => id(`domain:${v}`) as Hex);

// Frozen ABI102. Personhood adds derived evidence to the original principal op24.
const abi = new Interface([
  ...personhood.CURRENT_ARTIST_PERSONHOOD_ABI,
  "function core() view returns(address)",
  "function coreCodeHash() view returns(bytes32)",
  "function mintManager() view returns(address)",
  "function artistRegistry() view returns(address)",
  "function operationCoordinator() view returns(address)",
  "function archiveV2() view returns(address)",
  "function reads() view returns(address)",
  "function configurationHash() view returns(bytes32)",
  "function deploymentChainId() view returns(uint256)",
  "function domainId() view returns(bytes32)",
  "function suiteConfiguration() view returns((address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator))",
  "function getSatellitePointer(bytes32 pointerType) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  "function collectionExists(uint256) view returns(bool)",
  `function binding(uint256) view returns(${BINDING})`,
  `function acceptedBinding(uint256) view returns(${BINDING})`,
  "function attributionState(uint256) view returns(uint8,uint64)",
  "function authorityState(bytes32) view returns(address,uint8,uint8,bytes32)",
  "function currentAuthorityCapabilities(bytes32) view returns((address authorityAddress,uint8 authorityClass,uint8 status,uint32 effectiveCapabilities,bytes32 activationRecordHash))",
  "function operativeIdentityRecord(bytes32) view returns(bytes32)",
  "function artistAuthorizationState(bytes32,bytes32,uint256) view returns((bool digestObserved,bool digestRevoked,bool nonceConsumed,bool nonceRevoked,uint256 nextUnusedNonce))",
  "function replayCell(bytes32) view returns((bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status))",
  `function ownerStateSnapshotV2() view returns(${SNAPSHOT})`,
  "function artistNativeReceiptCount() view returns(uint256)",
  `function artistNativeReceiptAt(uint256 index) view returns(${NATIVE})`,
  "function artistNativeReceiptRevisionAt(uint256 index) view returns(uint64)",
  "function storedPayloadCount() view returns(uint256)",
  "function storedPayloadAt(uint256 index) view returns(address,bytes32,bytes32)",
  "function signatureBundle(bytes32) view returns(bytes)",
  "function dormancyNotice(bytes32) view returns(bytes32,uint8,bytes32)",
  `function dormancyRecord(bytes32) view returns(${ARTIST_RECOVERY_NOTICE_TUPLE},uint8,${ARTIST_RECOVERY_TERMINAL_TUPLE})`,
  `function attestationRecord(bytes32) view returns(${personhood.PERSONHOOD_NATIVE_RECORD_TUPLE})`,
  "function attestationAuthorityClass(bytes32) view returns(uint8)",
  "function statementBytes(bytes32) view returns(bytes)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns(uint256)",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes)",
  "function gasParameterInfo(bytes32) view returns(uint256,uint256,uint8,uint64)",
  "function schemaRegistry() view returns(address)",
  "function schemaRegistryCodeHash() view returns(bytes32)",
  "function chunkStore() view returns(address)",
  "function chunkStoreCodeHash() view returns(bytes32)",
  "function streamModuleType() pure returns(bytes32)",
  "function streamModuleVersion() pure returns(bytes32)",
  `function moduleRecord(address) view returns(${MODULE})`,
  `function attestation(bytes32 recordHash) view returns(${GENERAL_RECORD},${GENERAL_RECEIPT})`,
  `function recordSubject(bytes32 recordHash) view returns(${SUBJECT})`,
  "function recordPayload(bytes32 recordHash) view returns(address pointer,bytes payload)",
  "function recordSignatureBundle(bytes32 recordHash) view returns(address pointer,bytes bundle)",
  "function recordHashAt(uint256 collectionId,bytes32 attestationType,uint256 index) view returns(bytes32)",
  "function latestAttestationHashFor(uint256 collectionId,bytes32 attestationType,bytes32 subjectId,address attester) view returns(bytes32)",
  `function documentFacts(bytes32) view returns(${DOCUMENT})`,
  "function documentChunkHashAt(bytes32,uint256) view returns(bytes32)",
  "function chunk(bytes32) view returns(address,uint32)",
  "function readChunk(bytes32) view returns(bytes)",
  "event ArtistAttestationRecorded(uint16 schemaVersion,uint256 indexed collectionId,uint8 indexed subjectKind,address indexed signer,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 attestationRecordHash)",
  "event ArtistStoredPayload(uint16 schemaVersion,uint256 indexed index,bytes32 indexed payloadType,bytes32 indexed payloadHash,address pointer)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)",
  "event ArtistDormancyCancelled(uint16 schemaVersion,bytes32 indexed artistId,bytes32 indexed noticeHash,address canceller,uint8 authorityClass,bytes32 cancellationHash)",
  `event ArtistDormancyCancellationContext(uint16 schemaVersion,bytes32 indexed artistId,bytes32 indexed recordHash,(uint256 chainId,address registry,address identityOwner,address recorder,uint8 recorderAuthorityClass) context,${ARTIST_RECOVERY_TERMINAL_TUPLE} terminal,uint256 activityCount)`,
]);

export interface ArtistPersonhoodCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

export interface ArtistPersonhoodDeployment {
  readonly artist: CurrentArtistDeployment & { readonly reads: ArtistPersonhoodCodePin };
  readonly general: ArtistPersonhoodCodePin;
  readonly moduleRegistry: ArtistPersonhoodCodePin;
  readonly schemaRegistry: ArtistPersonhoodCodePin;
  readonly chunkStore: ArtistPersonhoodCodePin;
}

export interface ArtistPersonhoodReader {
  getNetwork(): Promise<{ chainId: bigint }>;
  getBlock(blockTag: number): Promise<{ number: number; hash: string | null; timestamp: number } | null>;
  getCode(address: string, blockTag: number): Promise<string>;
  call(transaction: { to: string; data: string; from?: string; value?: bigint; gasLimit?: bigint; blockTag: number }): Promise<string>;
}

export interface ArtistPersonhoodReceiptReader extends ArtistPersonhoodReader {
  getTransaction(hash: string): Promise<any>;
  getTransactionReceipt(hash: string): Promise<any>;
}

export interface ArtistPersonhoodObservation {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

export interface ArtistPersonhoodSnapshot {
  readonly domainId: Hex;
  readonly revision: bigint;
  readonly stateRoot: Hex;
  readonly recordChainTip: Hex;
}

export interface ArtistPersonhoodPayloadRow {
  readonly pointer: Address;
  readonly payloadType: Hex;
  readonly payloadHash: Hex;
}

export interface ArtistPersonhoodOwnerObservation {
  readonly ownerIndex: bigint;
  readonly snapshot: ArtistPersonhoodSnapshot;
  readonly nativeCount: bigint;
  readonly payloads: readonly ArtistPersonhoodPayloadRow[];
}

export interface ArtistPersonhoodCapture {
  readonly deployment: ArtistPersonhoodDeployment;
  readonly prepared: personhood.ArtistPersonhoodPrepared;
  readonly observed: ArtistPersonhoodObservation;
  readonly configurationHash: Hex;
  readonly binding: Readonly<Record<string, unknown>>;
  readonly authority: { readonly artistId: Hex; readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint };
  readonly direct: boolean;
  readonly effectiveTime: bigint;
  readonly effectiveDigest: Hex;
  readonly expectedRecordHash: Hex;
  /** Complete original documentary preimage observed before the actual Registry call. */
  readonly documentary: Readonly<Record<string, unknown>>;
  readonly owners: readonly ArtistPersonhoodOwnerObservation[];
  readonly archivePayloads: readonly ArtistPersonhoodPayloadRow[];
  readonly archiveLimit: bigint;
  readonly notice: { readonly recordHash: Hex; readonly phase: bigint; readonly terminalHash: Hex };
  readonly captureHash: Hex;
}

function address(value: unknown, allowZero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Zero address");
  return result;
}

function bytes(value: unknown, maximum = 262144): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > maximum) {
    throw Error("Invalid or oversized bytes");
  }
  return value.toLowerCase() as Hex;
}

function hash(value: unknown, allowZero = false): Hex {
  const result = bytes(value, 32);
  if (result.length !== 66 || (!allowZero && result === ZeroHash)) throw Error("Invalid hash");
  return result;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error("Invalid unsigned bigint");
  return value;
}

function blockNumber(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw Error("Concrete block required");
  return value;
}

function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}

function stable(value: any): string {
  if (typeof value === "bigint") return `bigint:${value}`;
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(k => `${k}:${stable(value[k])}`).join(",")}}`;
  return JSON.stringify(value);
}

function equal(a: unknown, b: unknown, message = "Observed facts differ"): void {
  if (stable(a) !== stable(b)) throw Error(message);
}

function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}

function keys(value: unknown, names: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...names].sort().join(",")) throw Error("Unexpected fields");
}

function plain(type: ParamType, value: any): any {
  if (type.baseType === "array") return Array.from(value, v => plain(type.arrayChildren!, v));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((c, i) => [c.name || String(i), plain(c, value[i])]));
  return value;
}

function tuple(type: string, value: any): any {
  const raw = coder.encode([type], [value]);
  return plain(ParamType.from(type), coder.decode([type], raw)[0]);
}

function decode(types: readonly string[], raw: Hex): any {
  const result = coder.decode(types, raw);
  if (!same(coder.encode(types, result), raw)) throw Error("Noncanonical ABI bytes");
  return result;
}

function normalizePin(value: ArtistPersonhoodCodePin): ArtistPersonhoodCodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function deployment(input: ArtistPersonhoodDeployment): ArtistPersonhoodDeployment {
  keys(input, ["artist", "general", "moduleRegistry", "schemaRegistry", "chunkStore"]);
  keys(input.artist, ["chainId", "registry", "coordinator", "components", "reads"]);
  if (!Array.isArray(input.artist.components) || input.artist.components.length !== 16
    || Object.keys(input.artist.components).length !== 16) throw Error("Exact sixteen components required");
  const artist = {
    chainId: uint(input.artist.chainId),
    registry: normalizePin(input.artist.registry),
    coordinator: normalizePin(input.artist.coordinator),
    components: input.artist.components.map(normalizePin),
    reads: normalizePin(input.artist.reads),
  };
  if (!artist.chainId || !same(artist.components[7]!.address, artist.registry.address)
    || !same(artist.components[7]!.codeHash, artist.registry.codeHash)
    || new Set(artist.components.map(v => v.address)).size !== 16) throw Error("Artist component binding differs");
  return freeze({ artist, general: normalizePin(input.general), moduleRegistry: normalizePin(input.moduleRegistry),
    schemaRegistry: normalizePin(input.schemaRegistry), chunkStore: normalizePin(input.chunkStore) });
}

async function read(p: ArtistPersonhoodReader, to: Address, method: string, args: readonly unknown[], tag: number): Promise<any> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(method, args), blockTag: tag }));
  const result = abi.decodeFunctionResult(method, raw);
  if (!same(abi.encodeFunctionResult(method, result), raw)) throw Error(`Noncanonical ${method} return`);
  return result;
}

async function header(p: ArtistPersonhoodReader, tag: number): Promise<ArtistPersonhoodObservation> {
  const block = await p.getBlock(tag);
  if (!block || block.number !== tag || !Number.isSafeInteger(block.timestamp) || block.timestamp < 0) throw Error("Block unavailable");
  return { blockNumber: tag, blockHash: hash(block.hash), timestamp: BigInt(block.timestamp) };
}

async function unchanged(p: ArtistPersonhoodReader, observed: ArtistPersonhoodObservation): Promise<void> {
  equal(await header(p, observed.blockNumber), observed, "Block changed");
}

async function code(p: ArtistPersonhoodReader, pin: ArtistPersonhoodCodePin, tag: number): Promise<void> {
  const runtime = bytes(await p.getCode(pin.address, tag), 65536);
  if (runtime === "0x" || (runtime.length === 48 && runtime.startsWith("0xef0100"))
    || !same(keccak256(runtime), pin.codeHash)) throw Error("Pinned runtime changed");
}

async function context(p: ArtistPersonhoodReader, d: ArtistPersonhoodDeployment, tag: number, current: boolean) {
  const a = d.artist;
  if ((await p.getNetwork()).chainId !== a.chainId) throw Error("Chain differs");
  const observed = await header(p, tag);
  await Promise.all([a.coordinator, a.reads, ...a.components].map(v => code(p, v, tag)));
  const [suite] = await read(p, a.coordinator.address, "suiteConfiguration", [], tag);
  equal([...suite.owners, suite.registry, suite.archive, suite.core, suite.mintManager, suite.roleRegistry,
    suite.metadata, suite.primaryResolver, suite.royaltyResolver, suite.validator].map(v => address(v)), a.components.map(v => v.address), "Suite differs");
  equal((await read(p, a.coordinator.address, "deploymentChainId", [], tag))[0], a.chainId);
  equal(address((await read(p, a.coordinator.address, "reads", [], tag))[0]), a.reads.address);
  for (const [method, expected] of [["core", suite.core], ["mintManager", suite.mintManager], ["operationCoordinator", a.coordinator.address]]) {
    if (!same((await read(p, a.registry.address, method, [], tag))[0], expected)) throw Error("Facade binding differs");
  }
  for (let i = 0; i < 7; i++) {
    for (const [method, expected] of [["core", suite.core], ["mintManager", suite.mintManager], ["artistRegistry", a.registry.address],
      ["operationCoordinator", a.coordinator.address], ["archiveV2", suite.archive], ["domainId", domains[i]]]) {
      if (!same((await read(p, a.components[i]!.address, method!, [], tag))[0], expected)) throw Error("Owner binding differs");
    }
    equal((await read(p, a.components[i]!.address, "deploymentChainId", [], tag))[0], a.chainId);
  }
  if (current) {
    const pointer = await read(p, suite.core, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
    if (!same(pointer[0], a.registry.address) || !same(pointer[1], a.registry.codeHash)
      || (await read(p, a.registry.address, "artistRegistryCutover", [], tag))[0] !== false) throw Error("Registry is not current");
  }
  return { observed, configurationHash: hash((await read(p, a.coordinator.address, "configurationHash", [], tag))[0]) };
}

async function catalog(p: ArtistPersonhoodReader, host: Address, tag: number): Promise<readonly ArtistPersonhoodPayloadRow[]> {
  const count = uint((await read(p, host, "storedPayloadCount", [], tag))[0]);
  if (count > 4096n) throw Error("Payload catalog exceeds client bound");
  const result: ArtistPersonhoodPayloadRow[] = [];
  const seen = new Set<string>();
  for (let i = 0n; i < count; i++) {
    const [pointer, kind, content] = await read(p, host, "storedPayloadAt", [i], tag);
    const row = { pointer: address(pointer), payloadType: hash(kind), payloadHash: hash(content) };
    const key = `${row.payloadType}:${row.payloadHash}`;
    if (seen.has(key)) throw Error("Duplicate payload catalog entry");
    seen.add(key);
    result.push(row);
  }
  return result;
}

const definitionPins = [
  { id: id("STREAM_IDENTITY_NOTARIZATION_V1"), kind: 0n, hash: "0x11a81f69ded4ebd38a35ece1efe185e1d7c42414678b988c3064c2983ced9b2a", length: 4236n },
  { id: id("STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1"), kind: 2n, hash: "0x17c1c2815ee237ba26bc0017eaf1c8491aa640c173b9840924ec0f8fb8bdd93b", length: 1488n },
  { id: id("RFC8785_JCS"), kind: 1n, hash: "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9", length: 362n },
  { id: id("STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1"), kind: 2n, hash: "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3", length: 1837n },
] as const;

function digest(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

async function carrier(p: ArtistPersonhoodReader, pointer: Address, payload: Hex, tag: number): Promise<Hex> {
  const runtime = bytes(await p.getCode(pointer, tag), 24576);
  if (runtime !== `0x00${payload.slice(2)}`) throw Error("Retained STOP carrier differs");
  return keccak256(runtime) as Hex;
}

/** Rebuilds original immutable documentary preimages; never revalidates an old wallet signature. */
async function documentary(
  p: ArtistPersonhoodReader,
  d: ArtistPersonhoodDeployment,
  reference: personhood.ArtistPersonhoodReference,
  tag: number,
) {
  const core = d.artist.components[9]!;
  const pins = [d.general, d.moduleRegistry, d.schemaRegistry, d.chunkStore];
  await Promise.all(pins.map(v => code(p, v, tag)));
  if (!same(reference.notarizationHost, d.general.address)
    || !same(reference.notarizationRuntimeHash, d.general.codeHash)) throw Error("General reference pin differs");
  const pointer = await read(p, core.address, "getSatellitePointer", [id("MODULE_REGISTRY")], tag);
  if (!same(pointer[0], d.moduleRegistry.address) || !same(pointer[1], d.moduleRegistry.codeHash)) throw Error("Module Registry selection differs");
  const [moduleRaw] = await read(p, d.moduleRegistry.address, "moduleRecord", [d.general.address], tag);
  const module = tuple(MODULE, moduleRaw);
  if (module.status !== 1n || module.revision === 0n || module.moduleType !== id("GENERAL_ATTESTATIONS")
    || module.moduleVersion !== id("6529stream.general-attestations.v2") || module.interfaceId !== "0xb4afac56"
    || !same(module.runtimeCodeHash, d.general.codeHash)) throw Error("General module is not admitted ACTIVE identity");
  for (const [method, expected] of [
    ["core", core.address], ["coreCodeHash", core.codeHash], ["artistRegistry", d.artist.registry.address],
    ["schemaRegistry", d.schemaRegistry.address], ["schemaRegistryCodeHash", d.schemaRegistry.codeHash],
    ["chunkStore", d.chunkStore.address], ["chunkStoreCodeHash", d.chunkStore.codeHash],
    ["streamModuleType", module.moduleType], ["streamModuleVersion", module.moduleVersion],
  ]) {
    if (!same((await read(p, d.general.address, method!, [], tag))[0], expected)) throw Error("General immutable binding differs");
  }
  if (!same((await read(p, d.schemaRegistry.address, "chunkStore", [], tag))[0], d.chunkStore.address)) throw Error("Schema Store binding differs");
  const [recordRaw, receiptRaw] = await read(p, d.general.address, "attestation", [reference.notarizationRecordHash], tag);
  const record = tuple(GENERAL_RECORD, recordRaw);
  const receipt = tuple(GENERAL_RECEIPT, receiptRaw);
  if (![id("INSTITUTIONAL_VERIFICATION"), id("ESTATE_VERIFICATION")].includes(record.attestationType)
    || record.attester === ZeroAddress || !same(receipt.recorder, record.attester)
    || receipt.verificationClass !== 1n || receipt.authorityQualification !== 1n
    || record.schemaId !== definitionPins[0].id || record.canonicalizationId !== definitionPins[2].id
    || receipt.schemaDefinitionHash !== definitionPins[0].hash || receipt.profileDefinitionHash !== definitionPins[1].hash
    || receipt.canonicalizationDefinitionHash !== definitionPins[2].hash
    || !same(receipt.identityRegistry, reference.artistRegistry)
    || !same(receipt.identityRegistryCodeHash, d.artist.registry.codeHash)
    || receipt.artistId !== reference.artistId || receipt.operativeIdentityRecordHash !== reference.operativeIdentityRecordHash
    || receipt.recordedAt === 0n || receipt.authorizationDigest === ZeroHash || receipt.signatureBundleHash === ZeroHash
    || record.subjectId === ZeroHash || record.statementHash === ZeroHash || record.artistAuthorizationRecordHash !== ZeroHash
    || receipt.nativeArtistEvidenceHash !== ZeroHash || receipt.nativeArtistAuthorityClass !== 0n
    || receipt.authorityFamily !== ZeroHash || receipt.authorizationClass !== 0n || receipt.grantCollectionId !== 0n
    || receipt.grantRevision !== 0n) throw Error("Original notarization receipt differs");
  const recordHash = digest(["bytes32", "uint256", "address", GENERAL_RECORD, GENERAL_RECEIPT],
    [id("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"), d.artist.chainId, d.general.address, record,
      { ...receipt, recordIndex: 0n, recordChainHash: ZeroHash }]);
  equal(recordHash, reference.notarizationRecordHash, "Original General record hash differs");
  equal((await read(p, d.general.address, "recordHashAt", [record.collectionId, record.attestationType, receipt.recordIndex], tag))[0], recordHash);
  const [subjectRaw] = await read(p, d.general.address, "recordSubject", [recordHash], tag);
  const subject = tuple(SUBJECT, subjectRaw);
  if (subject.collectionId !== record.collectionId || ![0n, 1n, 2n].includes(subject.kind)) throw Error("Original subject differs");
  let subjectId: Hex;
  if (subject.kind === 0n) {
    if (subject.tokenId !== 0n || subject.objectId !== ZeroHash) throw Error("Collection subject differs");
    subjectId = digest(["bytes32", "uint256", "address", "uint256"],
      ["0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16", d.artist.chainId, core.address, subject.collectionId]);
  } else if (subject.kind === 1n) {
    if (subject.collectionId === 0n || subject.tokenId === 0n || subject.objectId !== ZeroHash) throw Error("Token subject differs");
    subjectId = digest(["bytes32", "uint256", "address", "uint256"],
      ["0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e", d.artist.chainId, core.address, subject.tokenId]);
  } else {
    if (subject.collectionId === 0n || subject.tokenId !== 0n || subject.objectId === ZeroHash) throw Error("Media subject differs");
    subjectId = digest(["bytes32", "uint256", "address", "uint256", "bytes32"],
      ["0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b", d.artist.chainId, core.address, subject.collectionId, subject.objectId]);
  }
  equal(subjectId, record.subjectId);
  const [payloadPointerRaw, payloadRaw] = await read(p, d.general.address, "recordPayload", [recordHash], tag);
  const [signaturePointerRaw, bundleRaw] = await read(p, d.general.address, "recordSignatureBundle", [recordHash], tag);
  const payload = bytes(payloadRaw, 8192);
  const bundle = bytes(bundleRaw, 8192);
  if (payload === "0x" || bundle === "0x" || keccak256(payload) !== record.statementHash
    || keccak256(bundle) !== receipt.signatureBundleHash) throw Error("Original documentary bytes differ");
  const [domain, words, signature] = decode(["bytes32", "bytes32[15]", "bytes"], bundle);
  if (bytes(signature, 4096) === "0x" || ![id("EIP712"), id("ERC1271")].includes(receipt.signatureScheme)) throw Error("Original signature bundle differs");
  const expectedDomain = digest(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamGeneralAttestations"), id("1"), d.artist.chainId, d.general.address]);
  const word = (v: bigint | string) => coder.encode([typeof v === "bigint" ? "uint256" : "address"], [v]);
  const expectedWords = [id("StreamGeneralAttestation(address attester,uint256 collectionId,bytes32 subjectId,bytes32 attestationType,string attesterDID,bytes32 schemaId,bytes32 canonicalizationId,string statementURI,bytes payload,bytes32 supersedes,bytes32 artistAuthorizationRecordHash,uint64 effectiveAt,uint256 nonce,uint64 deadline)"),
    word(record.attester), word(record.collectionId), record.subjectId, record.attestationType, keccak256(toUtf8Bytes(record.attesterDID)),
    record.schemaId, record.canonicalizationId, keccak256(toUtf8Bytes(record.statementURI)), record.statementHash, record.supersedes,
    record.artistAuthorizationRecordHash, word(record.effectiveAt), word(receipt.nonce), word(receipt.deadline)];
  equal(Array.from(words), expectedWords, "Original authorization words differ");
  equal(domain, expectedDomain);
  equal(keccak256(`0x1901${domain.slice(2)}${digest(["bytes32[15]"], [expectedWords]).slice(2)}`), receipt.authorizationDigest);
  const carriers: Address[] = [address(payloadPointerRaw), address(signaturePointerRaw)];
  const carrierCodeHashes: Hex[] = [await carrier(p, carriers[0]!, payload, tag), await carrier(p, carriers[1]!, bundle, tag)];
  const definitions: any[] = [];
  const definitionFactsHashes: Hex[] = [];
  for (const expected of definitionPins) {
    const [raw] = await read(p, d.schemaRegistry.address, "documentFacts", [expected.id], tag);
    const fact = tuple(DOCUMENT, raw);
    if (!fact.exists || fact.kind !== expected.kind || fact.contentHash !== expected.hash
      || fact.canonicalizationId !== id("RAW_BYTES") || fact.supersedesId !== ZeroHash
      || fact.declarationHash === ZeroHash || fact.totalBytes !== expected.length || fact.chunkCount !== 1n) throw Error("Exact definition differs");
    const [chunkHash] = await read(p, d.schemaRegistry.address, "documentChunkHashAt", [expected.id, 0n], tag);
    const [pointer, length] = await read(p, d.chunkStore.address, "chunk", [chunkHash], tag);
    const [rawChunk] = await read(p, d.chunkStore.address, "readChunk", [chunkHash], tag);
    const chunk = bytes(rawChunk, 8192);
    if (chunkHash !== expected.hash || length !== expected.length || BigInt((chunk.length - 2) / 2) !== expected.length
      || keccak256(chunk) !== expected.hash) throw Error("Definition bytes differ");
    carriers.push(address(pointer));
    carrierCodeHashes.push(await carrier(p, address(pointer), chunk, tag));
    definitions.push(fact);
    definitionFactsHashes.push(digest(["bool", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32"],
      [fact.exists, fact.kind, fact.contentHash, fact.canonicalizationId, fact.supersedesId, fact.totalBytes, fact.chunkCount, fact.declarationHash]));
  }
  const head = (await read(p, d.general.address, "latestAttestationHashFor", [record.collectionId, record.attestationType, record.subjectId, receipt.recorder], tag))[0];
  equal(head, recordHash, "Referenced recorder head is stale");
  const moduleIdentityHash = digest(["bytes32", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"],
    [module.moduleType, module.moduleVersion, module.interfaceId, module.runtimeCodeHash, module.deploymentManifestHash,
      module.moduleManifestHash, keccak256(toUtf8Bytes(module.moduleManifestURI)), module.registeredAt]);
  const documentaryHash = digest(["bytes32", "uint256", "address", personhood.PERSONHOOD_REFERENCE_TUPLE, GENERAL_RECORD,
    GENERAL_RECEIPT, "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", "bytes32[4]"],
  [id("6529STREAM_ARTIST_PERSONHOOD_DOCUMENTARY_PROOF_V1"), d.artist.chainId, core.address, reference, record, receipt,
    digest([SUBJECT], [subject]), digest(["bytes", "bytes"], [payload, bundle]), d.schemaRegistry.address,
    d.schemaRegistry.codeHash, d.chunkStore.address, d.chunkStore.codeHash, definitionFactsHashes]);
  return freeze({ record, receipt, subject, payload, bundle, module, definitions, definitionFactsHashes,
    carriers, carrierCodeHashes, moduleIdentityHash, documentaryHash });
}

function timeFacts(prepared: personhood.ArtistPersonhoodPrepared, authority: ArtistPersonhoodCapture["authority"], timestamp: bigint) {
  const q = prepared.request;
  const direct = same(q.caller, authority.authorityAddress) && q.signature === "0x";
  const effectiveTime = direct && q.signedAt === 0n ? timestamp : q.signedAt;
  if (effectiveTime === 0n || effectiveTime > timestamp || (direct && effectiveTime !== timestamp)) throw Error("Original op24 time is not executable at this block");
  const effectiveDigest = currentArtistTypedData("artistAttestation", q.chainId, q.registry,
    { ...prepared.message, signedAt: effectiveTime }).digest as Hex;
  const expectedRecordHash = personhood.artistPersonhoodNativeRecordHash(prepared, authority.authorityAddress,
    authority.authorityClass, effectiveTime);
  return { direct, effectiveTime, effectiveDigest, expectedRecordHash };
}

function captured(input: ArtistPersonhoodCapture): ArtistPersonhoodCapture {
  keys(input, ["deployment", "prepared", "observed", "configurationHash", "binding", "authority", "direct", "effectiveTime", "effectiveDigest",
    "expectedRecordHash", "documentary", "owners", "archivePayloads", "archiveLimit", "notice", "captureHash"]);
  const result = { ...structuredClone(input), deployment: deployment(input.deployment),
    prepared: personhood.normalizeArtistPersonhoodCall(input.prepared) };
  const { captureHash, ...body } = result;
  equal(keccak256(toUtf8Bytes(stable(body))), hash(captureHash), "Capture was changed");
  return freeze(result);
}

function reviewed(c: ArtistPersonhoodCapture) {
  const { observed: _observed, direct: _direct, effectiveTime: _time, effectiveDigest: _digest,
    expectedRecordHash: _record, captureHash: _hash, ...body } = c;
  return body;
}

/** Capture facts at one concrete block. Admission remains the original Registry simulation. */
export async function captureArtistPersonhood(
  p: ArtistPersonhoodReader,
  inputDeployment: ArtistPersonhoodDeployment,
  inputPrepared: personhood.ArtistPersonhoodPrepared,
  options: { readonly blockTag: number },
): Promise<ArtistPersonhoodCapture> {
  keys(options, ["blockTag"]);
  const tag = blockNumber(options.blockTag);
  const d = deployment(inputDeployment);
  const prepared = personhood.normalizeArtistPersonhoodCall(inputPrepared);
  const q = prepared.request;
  const a = d.artist;
  if (q.chainId !== a.chainId || !same(q.registry, a.registry.address)
    || !same(q.core, a.components[9]!.address)) throw Error("Prepared environment differs");
  const ctx = await context(p, d, tag, true);
  const [bindingRaw] = await read(p, a.components[0]!.address, "binding", [q.collectionId], tag);
  const binding = tuple(BINDING, bindingRaw);
  const [accepted] = await read(p, a.reads.address, "acceptedBinding", [q.collectionId], tag);
  equal(tuple(BINDING, accepted), binding, "Accepted binding differs");
  if (!binding.accepted || ![1n, 2n].includes(binding.consentMode) || binding.generation === 0n
    || binding.artistId !== q.reference.artistId || binding.bindingHash === ZeroHash
    || (await read(p, q.core, "collectionExists", [q.collectionId], tag))[0] !== true) throw Error("Original accepted collection differs");
  const attribution = await read(p, a.components[4]!.address, "attributionState", [q.collectionId], tag);
  if (![2n, 3n].includes(attribution[0]) || attribution[1] !== binding.generation) throw Error("Attribution is not accepted or sanctioned");
  const auth = await read(p, a.components[2]!.address, "authorityState", [binding.artistId], tag);
  const authority = { artistId: hash(binding.artistId), authorityAddress: address(auth[0]), authorityClass: uint(auth[1], 8), status: uint(auth[2], 8) };
  if (!(authority.authorityClass === 1n && [1n, 2n].includes(authority.status))
    && !([3n, 4n].includes(authority.authorityClass) && authority.status === 3n)) throw Error("Original ordinary authority is unavailable");
  if (authority.authorityClass !== 1n) {
    const [capability] = await read(p, a.components[2]!.address, "currentAuthorityCapabilities", [binding.artistId], tag);
    if (!same(capability.authorityAddress, authority.authorityAddress) || capability.authorityClass !== authority.authorityClass
      || capability.status !== authority.status || (capability.effectiveCapabilities & 1n) === 0n
      || capability.activationRecordHash === ZeroHash) throw Error("Original CAP_ATTEST authority differs");
  }
  if ((await read(p, a.components[2]!.address, "operativeIdentityRecord", [binding.artistId], tag))[0]
    !== q.reference.operativeIdentityRecordHash) throw Error("Operative identity differs");
  const time = timeFacts(prepared, authority, ctx.observed.timestamp);
  if (!time.direct && q.signature === "0x" && bytes(await p.getCode(authority.authorityAddress, tag), 65536) === "0x") throw Error("Empty relayed proof requires contract authority");
  const [replay] = await read(p, a.registry.address, "artistAuthorizationState", [binding.artistId, time.effectiveDigest, q.nonce], tag);
  if (replay.digestRevoked || replay.nonceConsumed || replay.nonceRevoked || (time.direct && replay.nextUnusedNonce !== q.nonce)) throw Error("Original principal replay is unavailable");
  const digestRaw = bytes(await p.call({ ...prepared.operation.digestCall, blockTag: tag }), 32);
  equal(decode(["bytes32"], digestRaw)[0], prepared.operation.payload.digest, "Original digest getter differs");
  const cap = await read(p, a.registry.address, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS")], tag);
  if (cap[0] === 0n || cap[0] === (1n << 256n) - 1n || cap[2] !== 2n || cap[3] === 0n) throw Error("Original proof gas row differs");
  const proof = await documentary(p, d, q.reference, tag);
  const owners: ArtistPersonhoodOwnerObservation[] = [];
  for (const ownerIndex of [0, 1, 2, 4]) {
    const owner = a.components[ownerIndex]!.address;
    const snapshot = tuple(SNAPSHOT, (await read(p, owner, "ownerStateSnapshotV2", [], tag))[0]);
    if (snapshot.domainId !== domains[ownerIndex] || snapshot.stateRoot === ZeroHash || snapshot.recordChainTip === ZeroHash) throw Error("Owner snapshot differs");
    owners.push({ ownerIndex: BigInt(ownerIndex), snapshot,
      nativeCount: uint((await read(p, owner, "artistNativeReceiptCount", [], tag))[0]),
      payloads: ownerIndex === 2 || ownerIndex === 4 ? await catalog(p, owner, tag) : [] });
  }
  const archivePayloads = await catalog(p, a.components[8]!.address, tag);
  for (const owner of owners) for (const payload of owner.payloads) {
    if (!archivePayloads.some(row => row.payloadType === payload.payloadType && row.payloadHash === payload.payloadHash)) throw Error("Original owner payload has not been synchronized");
  }
  const archiveLimit = uint((await read(p, a.components[8]!.address, "artistArchiveMaxEvidenceBytesV2", [], tag))[0]);
  const [noticeHash, phase, terminalHash] = await read(p, a.components[2]!.address, "dormancyNotice", [binding.artistId], tag);
  const notice = { recordHash: hash(noticeHash, true), phase: uint(phase, 8), terminalHash: hash(terminalHash, true) };
  const body = { deployment: d, prepared, ...ctx, binding, authority, ...time, documentary: proof,
    owners, archivePayloads, archiveLimit, notice };
  await unchanged(p, ctx.observed);
  return freeze({ ...body, captureHash: keccak256(toUtf8Bytes(stable(body))) as Hex });
}

export interface ArtistPersonhoodSimulation {
  readonly capture: ArtistPersonhoodCapture;
  readonly gasLimit: bigint;
  readonly returnData: Hex;
  readonly recordHash: Hex;
  readonly nestedGasEquivalenceClaimed: false;
}

export async function simulateArtistPersonhood(
  p: ArtistPersonhoodReader,
  input: ArtistPersonhoodCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<ArtistPersonhoodSimulation> {
  keys(options, ["blockTag", "gasLimit"]);
  const c = captured(input);
  const tag = blockNumber(options.blockTag);
  const gasLimit = uint(options.gasLimit);
  if (gasLimit === 0n || gasLimit > 100000000n || tag < c.observed.blockNumber) throw Error("Invalid simulation bounds");
  equal(await captureArtistPersonhood(p, c.deployment, c.prepared, { blockTag: c.observed.blockNumber }), c, "Historical capture differs");
  const current = await captureArtistPersonhood(p, c.deployment, c.prepared, { blockTag: tag });
  equal(reviewed(current), reviewed(c), "Reviewed facts changed; recapture required");
  const returnData = bytes(await p.call({ ...current.prepared.call, from: current.prepared.request.caller, gasLimit, blockTag: tag }), 32);
  equal(decode(["bytes32"], returnData)[0], current.expectedRecordHash, "Original op24 result differs");
  await unchanged(p, current.observed);
  return freeze({ capture: current, gasLimit, returnData, recordHash: current.expectedRecordHash, nestedGasEquivalenceClaimed: false });
}

export interface ArtistPersonhoodReadDeployment {
  readonly chainId: bigint;
  readonly attribution: ArtistPersonhoodCodePin;
}

export type ArtistPersonhoodInspectionRequest =
  | { readonly method: "personhoodEvidence" | "personhoodEvidenceStatus"; readonly collectionId: bigint; readonly artistId: Hex }
  | { readonly method: "personhoodProofSummary" | "personhoodProofSummaryHash" | "auditPersonhoodEvidence"; readonly nativeRecordHash: Hex };

export interface ArtistPersonhoodInspection {
  readonly observed: ArtistPersonhoodObservation;
  readonly request: ArtistPersonhoodInspectionRequest;
  readonly selection: personhood.ArtistPersonhoodSelection | null;
  readonly summary: personhood.ArtistPersonhoodSummary | null;
  readonly summaryHash: Hex;
  readonly audit: { readonly documentaryHash: Hex; readonly attestationType: Hex; readonly recorder: Address; readonly head: Hex; readonly current: boolean } | null;
}

async function storedSummary(p: ArtistPersonhoodReader, owner: Address, recordHash: Hex, tag: number) {
  const [raw] = await read(p, owner, "personhoodProofSummary", [recordHash], tag);
  const summary = personhood.decodeArtistPersonhoodSummary(coder.encode([personhood.PERSONHOOD_SUMMARY_TUPLE], [raw]) as Hex);
  const summaryHash = hash((await read(p, owner, "personhoodProofSummaryHash", [recordHash], tag))[0], true);
  if (summary.version === 0n) {
    if (summaryHash !== ZeroHash) throw Error("Empty summary hash differs");
    return { summary: null, summaryHash };
  }
  equal(personhood.artistPersonhoodSummaryHash(summary), summaryHash, "Retained summary hash differs");
  equal(summary.nativeRecordHash, recordHash, "Summary native key differs");
  const [native] = await read(p, owner, "attestationRecord", [recordHash], tag);
  equal([native.recordHash, native.subjectStateHash, native.schemaId, native.statementHash, native.generation],
    [recordHash, summary.identityRecordHash, personhood.PERSONHOOD_EVIDENCE_SCHEMA, summary.statementHash, summary.generation], "Summary native record differs");
  const statement = bytes((await read(p, owner, "statementBytes", [summary.statementHash], tag))[0], 8192);
  equal(statement, personhood.encodeArtistPersonhoodReference(summary.evidenceReference), "Summary native statement differs");
  return { summary, summaryHash };
}

/** Local immutable reads do not require former documentary dependencies to remain available. */
export async function inspectArtistPersonhood(
  p: ArtistPersonhoodReader,
  inputDeployment: ArtistPersonhoodReadDeployment,
  inputRequest: ArtistPersonhoodInspectionRequest,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<ArtistPersonhoodInspection> {
  keys(inputDeployment, ["chainId", "attribution"]);
  keys(options, ["blockTag", "gasLimit"]);
  const chainId = uint(inputDeployment.chainId);
  const pin = normalizePin(inputDeployment.attribution);
  const tag = blockNumber(options.blockTag);
  const gasLimit = uint(options.gasLimit);
  if (!chainId || !gasLimit || gasLimit > 100000000n) throw Error("Invalid read bounds");
  const request = structuredClone(inputRequest);
  const bySubject = request.method === "personhoodEvidence" || request.method === "personhoodEvidenceStatus";
  keys(request, bySubject ? ["method", "collectionId", "artistId"] : ["method", "nativeRecordHash"]);
  const call = personhood.prepareArtistPersonhoodRead(pin.address, request.method,
    "collectionId" in request ? [request.collectionId, request.artistId] : [request.nativeRecordHash]);
  freeze(request);
  if ((await p.getNetwork()).chainId !== chainId) throw Error("Chain differs");
  const observed = await header(p, tag);
  await code(p, pin, tag);
  equal((await read(p, pin.address, "deploymentChainId", [], tag))[0], chainId);
  let selection: personhood.ArtistPersonhoodSelection | null = null;
  let summary: personhood.ArtistPersonhoodSummary | null = null;
  let summaryHash = ZeroHash as Hex;
  let audit: ArtistPersonhoodInspection["audit"] = null;
  if ("collectionId" in request) {
    const raw = bytes(await p.call({ to: pin.address, data: abi.encodeFunctionData("personhoodEvidence", [request.collectionId, request.artistId]), gasLimit, blockTag: tag }), 704);
    selection = personhood.decodeArtistPersonhoodSelection(raw);
    if (selection.evidenceReference.version === 1n && !same(selection.evidenceReference.artistId, request.artistId)) throw Error("Personhood selection belongs to another Artist");
    const compactRaw = bytes(await p.call({ to: pin.address, data: abi.encodeFunctionData("personhoodEvidenceStatus", [request.collectionId, request.artistId]), gasLimit, blockTag: tag }), 64);
    equal(Array.from(decode(["bytes32", "uint8"], compactRaw)), [selection.nativeRecord.recordHash, selection.status], "Compact personhood status differs");
    // These serving reads deliberately do not fetch full General evidence or invoke its verifier.
  } else {
    ({ summary, summaryHash } = await storedSummary(p, pin.address, hash(request.nativeRecordHash, true), tag));
    if (summary && summary.chainId !== chainId) throw Error("Summary chain differs");
    if (request.method === "auditPersonhoodEvidence") {
      const raw = bytes(await p.call({ ...call, gasLimit, blockTag: tag }), 160);
      const [documentaryHash, facts] = decode(["bytes32", "(bytes32 attestationType,address recorder,bytes32 head,bool current)"], raw);
      if (!summary || documentaryHash !== summary.documentaryHash || facts.attestationType !== summary.attestationType
        || !same(facts.recorder, summary.recorder) || facts.current !== (facts.head === summary.evidenceReference.notarizationRecordHash)) throw Error("Original documentary audit differs");
      audit = { documentaryHash, attestationType: facts.attestationType, recorder: address(facts.recorder), head: hash(facts.head, true), current: facts.current };
    }
  }
  await unchanged(p, observed);
  return freeze({ observed, request, selection, summary, summaryHash, audit });
}

export type ArtistPersonhoodReceiptOptions =
  | { readonly execution: "direct" }
  | { readonly execution: "safe"; readonly expectedSafeTxHash: Hex };

export interface ArtistPersonhoodEventReference {
  readonly address: Address;
  readonly event: string;
  readonly logIndex: number;
}

export interface ArtistPersonhoodReceipt {
  readonly transactionHash: Hex;
  readonly observed: ArtistPersonhoodObservation;
  readonly recordHash: Hex;
  readonly effectiveTime: bigint;
  readonly effectiveDigest: Hex;
  readonly summary: personhood.ArtistPersonhoodSummary;
  readonly summaryHash: Hex;
  readonly evidenceId: Hex;
  readonly archiveBytes: Hex;
  readonly before: readonly ArtistPersonhoodSnapshot[];
  readonly after: readonly ArtistPersonhoodSnapshot[];
  readonly events: readonly ArtistPersonhoodEventReference[];
  /** Original creation evidence; no claim about today's bounded documentary status. */
  readonly currentnessClaimed: false;
}

const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
]);
const safePlain = new Interface([
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const safeIndexed = new Interface([
  "event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)",
]);

function replayKey(c: ArtistPersonhoodCapture, surface: string, scope: Hex): Hex {
  const a = c.deployment.artist;
  return digest(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), a.chainId, a.registry.address, a.coordinator.address,
      a.components[8]!.address, a.components[2]!.address, domains[2], id(surface), scope]);
}

function expectedSummary(c: ArtistPersonhoodCapture, recordHash: Hex): personhood.ArtistPersonhoodSummary {
  const d = c.deployment;
  const q = c.prepared.request;
  const proof = c.documentary as any;
  return personhood.normalizeArtistPersonhoodSummary({
    version: 1n, chainId: q.chainId, nativeRecordHash: recordHash, statementHash: c.prepared.message.statementHash,
    artistId: q.reference.artistId, bindingHash: c.binding.bindingHash as Hex, generation: c.binding.generation as bigint,
    collectionId: q.collectionId, identityRecordHash: q.reference.operativeIdentityRecordHash,
    evidenceReference: q.reference, originalRegistryCodeHash: d.artist.registry.codeHash,
    core: q.core, coreCodeHash: d.artist.components[9]!.codeHash,
    moduleRegistry: d.moduleRegistry.address, moduleRegistryCodeHash: d.moduleRegistry.codeHash,
    schemaRegistry: d.schemaRegistry.address, schemaRegistryCodeHash: d.schemaRegistry.codeHash,
    chunkStore: d.chunkStore.address, chunkStoreCodeHash: d.chunkStore.codeHash,
    definitionFactsHashes: proof.definitionFactsHashes, notarizationCollectionId: proof.record.collectionId,
    attestationType: proof.record.attestationType, subjectId: proof.record.subjectId, recorder: proof.receipt.recorder,
    documentaryHash: proof.documentaryHash, moduleIdentityHash: proof.moduleIdentityHash,
    carriers: proof.carriers, carrierCodeHashes: proof.carrierCodeHashes,
  });
}

/** Conservative prestate attribution: the reviewed context must still match the prior block. */
export async function reconcileArtistPersonhoodReceipt(
  p: ArtistPersonhoodReceiptReader,
  input: ArtistPersonhoodCapture,
  inputTransactionHash: Hex,
  inputOptions: ArtistPersonhoodReceiptOptions,
): Promise<ArtistPersonhoodReceipt> {
  if (inputOptions.execution !== "direct" && inputOptions.execution !== "safe") throw Error("Unknown receipt transport");
  keys(inputOptions, inputOptions.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const execution = inputOptions.execution;
  const expectedSafeTxHash = execution === "safe" ? hash((inputOptions as Extract<ArtistPersonhoodReceiptOptions, { execution: "safe" }>).expectedSafeTxHash) : null;
  const c = captured(input);
  const transactionHash = hash(inputTransactionHash);
  const a = c.deployment.artist;
  const q = c.prepared.request;
  equal(await captureArtistPersonhood(p, c.deployment, c.prepared, { blockTag: c.observed.blockNumber }), c, "Historical capture differs");
  const [tx, receipt] = await Promise.all([p.getTransaction(transactionHash), p.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || receipt.status !== 1 || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash)
    || tx.chainId !== q.chainId || tx.value !== 0n || !same(tx.from, receipt.from) || !same(tx.to, receipt.to)
    || tx.blockNumber !== receipt.blockNumber || !same(tx.blockHash, receipt.blockHash)) throw Error("Successful original transaction required");
  const tag = blockNumber(receipt.blockNumber);
  const blockHash = hash(receipt.blockHash);
  const sender = address(tx.from);
  const target = address(tx.to);
  const data = bytes(tx.data, 524288);
  if (tag <= c.observed.blockNumber) throw Error("Receipt must follow captured block");
  if (execution === "direct") {
    if (!same(sender, q.caller) || !same(target, q.registry) || !same(data, c.prepared.call.data)) throw Error("Direct op24 CALL differs");
  } else {
    const call = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(target, q.caller) || !same(safeAbi.encodeFunctionData("execTransaction", call), data)
      || !same(call.to, q.registry) || call.value !== 0n || call.operation !== 0n
      || !same(call.data, c.prepared.call.data)) throw Error("Safe ordinary op24 CALL differs");
  }
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 512) throw Error("Receipt log bound exceeded");
  let previous = -1;
  // Own the complete log snapshot before any further asynchronous provider reads.
  const logs = receipt.logs.map((entry: any) => {
    const index = blockNumber(entry.index);
    if (entry.removed || index <= previous || (entry.blockNumber !== undefined && entry.blockNumber !== tag)
      || (entry.blockHash !== undefined && !same(entry.blockHash, blockHash))
      || (entry.transactionHash !== undefined && !same(entry.transactionHash, transactionHash))
      || !Array.isArray(entry.topics) || entry.topics.length > 4) throw Error("Malformed receipt log");
    previous = index;
    return freeze({ address: address(entry.address), index, data: bytes(entry.data, 65536), topics: entry.topics.map((v: unknown) => hash(v, true)) });
  });
  const events: ArtistPersonhoodEventReference[] = [];
  const found = (host: Address, name: string) => {
    const fragment = abi.getEvent(name)!;
    return logs.filter((entry: any) => same(entry.address, host) && same(entry.topics[0], fragment.topicHash)).map((entry: any) => {
      const args = abi.decodeEventLog(fragment, entry.data, entry.topics);
      const canonical = abi.encodeEventLog(fragment, args);
      equal(canonical.topics.map(v => v.toLowerCase()), entry.topics);
      equal(canonical.data.toLowerCase(), entry.data, "Noncanonical event");
      return { entry, args };
    });
  };
  const one = (host: Address, name: string, expected?: readonly unknown[]) => {
    const matches = found(host, name);
    if (matches.length !== 1) throw Error(`Expected one ${name}`);
    const match = matches[0]!;
    if (expected) {
      const wanted = abi.encodeEventLog(abi.getEvent(name)!, expected);
      equal(wanted.data.toLowerCase(), match.entry.data, `${name} values differ`);
      equal(wanted.topics.map(v => v.toLowerCase()), match.entry.topics, `${name} topics differ`);
    }
    events.push({ address: host, event: name, logIndex: match.entry.index });
    return match;
  };
  const prior = await captureArtistPersonhood(p, c.deployment, c.prepared, { blockTag: tag - 1 });
  equal(reviewed(prior), reviewed(c), "Prior-block context changed; recapture required");
  const ctx = await context(p, c.deployment, tag, false);
  equal(ctx.observed.blockHash, blockHash);
  equal(ctx.configurationHash, c.configurationHash);
  const time = timeFacts(c.prepared, c.authority, ctx.observed.timestamp);
  const recordHash = time.expectedRecordHash;
  const attribution = a.components[4]!.address;
  const identity = a.components[2]!.address;
  const archive = a.components[8]!.address;
  const t = abi.decodeFunctionData("recordArtistAttestation", c.prepared.call.data);
  const recorded = one(attribution, "ArtistAttestationRecorded", [1n, q.collectionId, 10n, c.authority.authorityAddress,
    q.reference.artistId, q.reference.operativeIdentityRecordHash, personhood.PERSONHOOD_EVIDENCE_SCHEMA,
    c.prepared.message.statementHash, c.prepared.message.statementURIHash, c.authority.authorityClass, q.nonce,
    time.effectiveTime, recordHash]);
  const native = tuple(personhood.PERSONHOOD_NATIVE_RECORD_TUPLE, (await read(p, attribution, "attestationRecord", [recordHash], tag))[0]);
  equal(native, { recordHash, subjectStateHash: q.reference.operativeIdentityRecordHash,
    schemaId: personhood.PERSONHOOD_EVIDENCE_SCHEMA, statementHash: c.prepared.message.statementHash,
    generation: c.binding.generation, signedAt: time.effectiveTime, signer: c.authority.authorityAddress });
  equal((await read(p, attribution, "attestationAuthorityClass", [recordHash], tag))[0], c.authority.authorityClass);
  equal((await read(p, attribution, "statementBytes", [native.statementHash], tag))[0], c.prepared.statement);
  equal((await read(p, identity, "signatureBundle", [recordHash], tag))[0], q.signature);
  const summary = expectedSummary(c, recordHash);
  const summaryHash = personhood.artistPersonhoodSummaryHash(summary);
  equal(await storedSummary(p, attribution, recordHash, tag), { summary, summaryHash }, "Stored summary differs");
  const retained = one(attribution, "ArtistPersonhoodProofRetained", [1n, recordHash, q.registry, summaryHash, summary]);
  if (retained.entry.index <= recorded.entry.index) throw Error("Summary event must follow original attestation");
  const evidenceId = digest(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), q.chainId, q.registry, a.coordinator.address, 24n, q.caller, recordHash]);
  const metadata = await read(p, archive, "artistEvidenceMetadataV2", [evidenceId, 1n], tag);
  const archiveBytes = bytes((await read(p, archive, "artistEvidenceBytesV2", [evidenceId, 1n], tag))[0], 24575);
  if (BigInt((archiveBytes.length - 2) / 2) > c.archiveLimit || metadata[0] !== keccak256(archiveBytes)
    || metadata[2] !== BigInt((archiveBytes.length - 2) / 2) || metadata[3] !== BigInt(tag)) throw Error("Archive metadata differs");
  await carrier(p, address(metadata[1]), archiveBytes, tag);
  const appended = one(archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], metadata[1], metadata[2]]);
  if (appended.entry.index <= retained.entry.index) throw Error("Archive precedes derived proof");
  const envelope = decode(["uint16", "bytes32", "uint16", "address", "bytes32", `${SNAPSHOT}[7]`, `${SNAPSHOT}[7]`, "bytes"], archiveBytes);
  equal(Array.from(envelope).slice(0, 5), [1n, c.configurationHash, 24n, q.caller, recordHash], "Archive header differs");
  const before = Array.from(envelope[5], v => tuple(SNAPSHOT, v)) as ArtistPersonhoodSnapshot[];
  const after = Array.from(envelope[6], v => tuple(SNAPSHOT, v)) as ArtistPersonhoodSnapshot[];
  const empty = { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash };
  for (let i = 0; i < 7; i++) {
    const original = c.owners.find(o => o.ownerIndex === BigInt(i));
    if (!original) {
      equal(before[i], empty, "Unexpected Archive owner");
      equal(after[i], empty, "Unexpected Archive owner");
      continue;
    }
    equal(before[i], original.snapshot, "Archive prestate differs from reviewed prior block");
    if (i === 2 || i === 4) {
      if (after[i]!.domainId !== domains[i] || after[i]!.revision !== before[i]!.revision + 1n
        || after[i]!.stateRoot === ZeroHash || after[i]!.recordChainTip === ZeroHash) throw Error("Original write mask/revision differs");
      if (i === 2) equal(after[i]!.recordChainTip, before[i]!.recordChainTip, "Identity op24 must not append semantic receipt");
    } else equal(after[i], before[i], "Read-only owner changed");
    const observed = tuple(SNAPSHOT, (await read(p, a.components[i]!.address, "ownerStateSnapshotV2", [], tag))[0]);
    if (observed.revision < after[i]!.revision) throw Error("Owner revision regressed");
    if (observed.revision === after[i]!.revision) equal(observed, after[i]);
  }
  const proof = [c.authority.authorityAddress, time.effectiveDigest, time.direct];
  const innerTypes = [BINDING, TERMS, AUTH, "bytes", PROOF];
  const innerValues: unknown[] = [c.binding, t[0], t[1], c.prepared.statement, proof];
  if (q.signedAt !== time.effectiveTime) {
    innerTypes.push(AUTH);
    innerValues.push([q.nonce, time.effectiveTime, q.signature]);
  }
  const base = coder.encode(innerTypes, innerValues);
  const operative = coder.encode(["bytes", "bytes32"], [base, q.reference.operativeIdentityRecordHash]);
  equal(envelope[7], coder.encode(["bytes", AUTHORITY], [operative, c.authority]), "Original principal Archive payload differs");
  const identityAfter = after[2]!;
  for (const [surface, scope, commitment, priorAllowed] of [
    ["nonce_allocator", digest(["bytes32", "uint256"], [q.reference.artistId, q.nonce]), time.effectiveDigest, false],
    ["attestation_key", digest(["bytes32"], [recordHash]), recordHash, false],
    ["authorization_consumed_digest", digest(["bytes32", "bytes32"], [q.reference.artistId, time.effectiveDigest]), time.effectiveDigest, true],
  ] as const) {
    const [cell] = await read(p, identity, "replayCell", [replayKey(c, `identity_authority.replay.${surface}`, scope)], tag);
    if (cell.kind !== 1n || cell.status !== 2n || cell.commitment !== commitment || !cell.touchedRevision
      || (priorAllowed ? cell.touchedRevision > identityAfter.revision : cell.touchedRevision !== identityAfter.revision)) throw Error("Original consumed replay differs");
  }
  const attrBefore = c.owners.find(o => o.ownerIndex === 4n)!;
  equal(tuple(NATIVE, (await read(p, attribution, "artistNativeReceiptAt", [attrBefore.nativeCount], tag))[0]),
    { operation: 24n, artistId: q.reference.artistId, collectionId: q.collectionId, recordHash });
  equal((await read(p, attribution, "artistNativeReceiptRevisionAt", [attrBefore.nativeCount], tag))[0], after[4]!.revision);
  if ((await read(p, attribution, "artistNativeReceiptCount", [], tag))[0] < attrBefore.nativeCount + 1n) throw Error("Native op24 occurrence missing");
  const identityBefore = c.owners.find(o => o.ownerIndex === 2n)!;
  const cancellations = found(identity, "ArtistDormancyCancelled");
  const expectedCancellation = c.authority.authorityClass === 1n && c.notice.phase === 1n;
  if (expectedCancellation) {
    const contextual = one(identity, "ArtistDormancyCancellationContext");
    const terminal = tuple(ARTIST_RECOVERY_TERMINAL_TUPLE, contextual.args.terminal);
    const emptyTerminal = tuple(ARTIST_RECOVERY_TERMINAL_TUPLE, coder.decode([ARTIST_RECOVERY_TERMINAL_TUPLE], `0x${"00".repeat(608)}`)[0]);
    const canonical = { ...emptyTerminal, noticeHash: c.notice.recordHash, actor: c.authority.authorityAddress,
      authorityClass: 1n, observedAt: ctx.observed.timestamp };
    equal({ ...terminal, recordHash: ZeroHash }, canonical, "Cancellation terminal differs");
    const cancellationHash = digest(["bytes32", "uint256", "address", "address", ARTIST_RECOVERY_TERMINAL_TUPLE, "uint256"],
      [id("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"), q.chainId, q.registry, identity, canonical, contextual.args.activityCount]);
    equal(terminal.recordHash, cancellationHash);
    if (contextual.args.activityCount === 0n) throw Error("Cancellation activity missing");
    equal(Array.from(contextual.args.context), [q.chainId, q.registry, identity, c.authority.authorityAddress, 1n]);
    equal([contextual.args.schemaVersion, contextual.args.artistId, contextual.args.recordHash], [1n, q.reference.artistId, cancellationHash]);
    const cancelled = one(identity, "ArtistDormancyCancelled", [1n, q.reference.artistId, c.notice.recordHash,
      c.authority.authorityAddress, 1n, cancellationHash]);
    if (cancelled.entry.index >= contextual.entry.index || contextual.entry.index >= recorded.entry.index) throw Error("Dormancy cancellation order differs");
    const [savedNotice, phase, savedTerminal] = await read(p, identity, "dormancyRecord", [c.notice.recordHash], tag);
    if (savedNotice.recordHash !== c.notice.recordHash || phase !== 2n) throw Error("Original cancelled notice not retained");
    equal(tuple(ARTIST_RECOVERY_TERMINAL_TUPLE, savedTerminal), terminal);
    equal(tuple(NATIVE, (await read(p, identity, "artistNativeReceiptAt", [identityBefore.nativeCount], tag))[0]),
      { operation: 42n, artistId: q.reference.artistId, collectionId: 0n, recordHash: cancellationHash });
    equal((await read(p, identity, "artistNativeReceiptRevisionAt", [identityBefore.nativeCount], tag))[0], identityAfter.revision);
    const [cell] = await read(p, identity, "replayCell", [replayKey(c, "identity_authority.replay.dormancy_cancellation_key", c.notice.recordHash)], tag);
    if (cell.commitment !== cancellationHash || cell.touchedRevision !== identityAfter.revision || cell.kind !== 1n || cell.status !== 2n) throw Error("Cancellation replay differs");
  } else if (cancellations.length || found(identity, "ArtistDormancyCancellationContext").length) throw Error("Unexpected dormancy cancellation");
  if ((await read(p, identity, "artistNativeReceiptCount", [], tag))[0] < identityBefore.nativeCount + (expectedCancellation ? 1n : 0n)) throw Error("Identity native count regressed");
  const summaryBytes = coder.encode(["bytes32", personhood.PERSONHOOD_SUMMARY_TUPLE], [personhood.PERSONHOOD_SUMMARY_TAG, summary]) as Hex;
  const ownerPayloads = [
    { host: identity, before: identityBefore.payloads, additions: [{ kind: id("ARTIST_SIGNATURE_BUNDLE") as Hex, bytes: q.signature }] },
    { host: attribution, before: attrBefore.payloads, additions: [
      { kind: id("ARTIST_PUBLICATION_STATEMENT") as Hex, bytes: c.prepared.statement },
      { kind: personhood.PERSONHOOD_PAYLOAD_TYPE, bytes: summaryBytes },
    ] },
  ];
  const archiveAdditions: { kind: Hex; bytes: Hex; pointer: Address }[] = [];
  for (const owner of ownerPayloads) {
    const keys = new Set(owner.before.map(v => `${v.payloadType}:${v.payloadHash}`));
    const additions = owner.additions.filter(item => {
      const key = `${item.kind}:${keccak256(item.bytes)}`;
      if (keys.has(key)) return false;
      keys.add(key);
      return true;
    });
    const matches = found(owner.host, "ArtistStoredPayload");
    if (matches.length !== additions.length) throw Error("Complete owner payload additions required");
    let lastIndex = -1;
    for (let i = 0; i < additions.length; i++) {
      const payload = additions[i]!;
      const row = BigInt(owner.before.length + i);
      const [pointer, kind, payloadHash] = await read(p, owner.host, "storedPayloadAt", [row], tag);
      equal([kind, payloadHash], [payload.kind, keccak256(payload.bytes)]);
      await carrier(p, address(pointer), payload.bytes, tag);
      const match = matches[i]!;
      equal(Array.from(match.args), [1n, row, kind, payloadHash, pointer]);
      if (match.entry.index <= lastIndex || match.entry.index >= appended.entry.index
        || (owner.host === identity && match.entry.index >= recorded.entry.index)
        || (payload.kind === id("ARTIST_PUBLICATION_STATEMENT") && match.entry.index >= recorded.entry.index)
        || (payload.kind === personhood.PERSONHOOD_PAYLOAD_TYPE
          && (match.entry.index <= recorded.entry.index || match.entry.index >= retained.entry.index))) throw Error("Owner payload order differs");
      lastIndex = match.entry.index;
      events.push({ address: owner.host, event: "ArtistStoredPayload", logIndex: match.entry.index });
      archiveAdditions.push({ ...payload, pointer: address(pointer) });
    }
    if ((await read(p, owner.host, "storedPayloadCount", [], tag))[0] < BigInt(owner.before.length + additions.length)) throw Error("Owner payload count regressed");
  }
  const archiveKeys = new Set(c.archivePayloads.map(v => `${v.payloadType}:${v.payloadHash}`));
  const additions = archiveAdditions.filter(item => {
    const key = `${item.kind}:${keccak256(item.bytes)}`;
    if (archiveKeys.has(key)) return false;
    archiveKeys.add(key);
    return true;
  });
  const syncs = found(archive, "ArtistStoredPayload");
  if (syncs.length !== additions.length) throw Error("Complete Archive payload synchronization required");
  let lastRequired = appended.entry.index;
  for (let i = 0; i < additions.length; i++) {
    const item = additions[i]!;
    const row = BigInt(c.archivePayloads.length + i);
    equal(Array.from(await read(p, archive, "storedPayloadAt", [row], tag)), [item.pointer, item.kind, keccak256(item.bytes)]);
    const sync = syncs[i]!;
    equal(Array.from(sync.args), [1n, row, item.kind, keccak256(item.bytes), item.pointer]);
    if (sync.entry.index <= lastRequired) throw Error("Archive payload order differs");
    lastRequired = sync.entry.index;
    events.push({ address: archive, event: "ArtistStoredPayload", logIndex: sync.entry.index });
  }
  if ((await read(p, archive, "storedPayloadCount", [], tag))[0] < BigInt(c.archivePayloads.length + additions.length)) throw Error("Archive payload count regressed");
  if (execution === "safe") {
    requireSafeExecution({ status: 1, logs: logs.map((v: any) => ({ address: v.address, topics: [...v.topics], data: v.data })) }, q.caller, expectedSafeTxHash!);
    const successes = logs.filter((v: any) => same(v.address, q.caller) && same(v.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1) throw Error("Expected exactly one Safe success");
    const success = successes[0]!;
    const iface = success.topics.length === 2 ? safeIndexed : safePlain;
    const decoded = iface.decodeEventLog("ExecutionSuccess", success.data, success.topics);
    const canonical = iface.encodeEventLog(iface.getEvent("ExecutionSuccess")!, decoded);
    equal(canonical.data.toLowerCase(), success.data);
    equal(canonical.topics.map(v => v.toLowerCase()), success.topics);
    if (events.some(v => v.logIndex >= success.index)) throw Error("Safe success precedes required operation evidence");
    events.push({ address: q.caller, event: "ExecutionSuccess", logIndex: success.index });
  }
  await unchanged(p, ctx.observed);
  return freeze({ transactionHash, observed: ctx.observed, recordHash, effectiveTime: time.effectiveTime,
    effectiveDigest: time.effectiveDigest, summary, summaryHash, evidenceId, archiveBytes, before, after,
    events: events.sort((x, y) => x.logIndex - y.logIndex), currentnessClaimed: false });
}
