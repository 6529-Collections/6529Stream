import {
  AbiCoder,
  Interface,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { Provider, TransactionReceipt, TransactionResponse } from "ethers";
import type { UnsignedCall } from "./client.js";
import type { Address, Hex } from "./generated/contracts.js";
import {
  REFERENCE_METRIC_MAX_CANONICAL_BYTES,
  REFERENCE_METRIC_MAX_CHUNK_BYTES,
  REFERENCE_METRIC_CANONICALIZATION_HASH,
  REFERENCE_METRIC_PROFILE_HASH,
  REFERENCE_METRIC_SCHEMA_HASH,
  referenceMetricSupplementHash,
  referenceMetricSupplementChunks,
  validateReferenceMetricReceipt,
  validateReferenceMetricSupplement,
} from "./current-reference-metric.js";
import type {
  ReferenceMetricAuthority,
  ReferenceMetricCanonicalSupplement,
  ReferenceMetricOriginalContext,
  ReferenceMetricReceipt,
  ReferenceMetricSupplement,
} from "./current-reference-metric.js";

export interface ReferenceMetricOriginalLocator {
  readonly collectionId: bigint;
  readonly revision: bigint;
}

export interface PreparedReferenceMetricChunkUpload {
  readonly index: number;
  readonly offset: number;
  readonly hash: Hex;
  readonly bytes: Hex;
  readonly caller: Address;
  readonly call: UnsignedCall;
}

export interface PreparedReferenceMetricSupplementPlan {
  readonly chainId: bigint;
  readonly producer: Address;
  readonly store: Address;
  readonly core: Address;
  readonly metadata: Address;
  readonly caller: Address;
  readonly locator: ReferenceMetricOriginalLocator;
  readonly maximumExecutedAt: bigint;
  readonly artifact: ReferenceMetricCanonicalSupplement;
  readonly chunks: readonly PreparedReferenceMetricChunkUpload[];
  readonly publication: UnsignedCall;
}

export interface ReferenceMetricChunkAvailability {
  readonly index: number;
  readonly hash: Hex;
  readonly pointer: Address;
  readonly byteLength: number;
}

export interface ReferenceMetricOriginalFacts {
  readonly collectionId: bigint;
  readonly revision: bigint;
  readonly originalRecorder: Address;
  readonly evidenceHash: Hex;
  readonly contextHash: Hex;
}

export interface ReferenceMetricPublicationInspection {
  readonly plan: PreparedReferenceMetricSupplementPlan;
  readonly authority: ReferenceMetricAuthority;
  readonly original: ReferenceMetricOriginalFacts;
  readonly chunks: readonly ReferenceMetricChunkAvailability[];
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

export interface ReferenceMetricPublicationReceiptEvidence {
  readonly transactionHash: Hex;
  readonly execution: "direct" | "safe";
}

const packageFileTuple = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)";
const captureTuple = "tuple(uint256 tokenId,uint256 collectionSerial,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,bytes animationHTML,bytes32 objectHash,bytes32 coverageHash,bytes32 sourceSha256,bytes32[2] repeatCaptureSha256,bytes32 environmentManifestHash,uint64 capturedAt)";
const environmentTuple = `tuple(bytes32 objectHash,bytes32 coverageHash,bytes32 manifestHash,uint32 manifestBytes,string engineName,string engineVersion,bytes32 engineExecutableSha256,string toolchainName,string toolchainVersion,bytes32 toolchainSha256,string engineExecutablePath,string toolchainPath,${packageFileTuple}[] packageFiles,${packageFileTuple}[] platformPrerequisites,string operatingSystem,string operatingSystemVersion,string architecture,uint16 viewportWidth,uint16 viewportHeight,uint8 devicePixelRatio,string colorSpace,bool softwareRasterization,bytes32 captureProfile,string licenseNote)`;
const publicationTuple = `tuple(uint256 collectionId,bytes32 referenceId,bytes32 expectedHead,uint64 expectedRevision,bytes32 snapshotRecordHash,uint64 snapshotRevision,bytes32 expectedSourcesHash,${captureTuple}[] captures,${environmentTuple} environment,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
const originalReceiptTuple = "tuple(bytes32 recordHash,bytes32 recordChainHash,uint256 collectionId,bytes32 referenceId,bytes32 predecessor,uint64 revision,bytes32 payloadHash,uint32 payloadBytes,bytes32 sourcesHash,bytes32 snapshotRecordHash,uint64 snapshotRevision,address recorder,uint8 authorizationClass,uint64 grantRevision,uint64 effectiveAt,uint64 recordedAt,bytes32 reasonHash,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
const supplementReceiptTuple = "tuple(bytes32 supplementHash,bytes32 referenceRecordHash,bytes32 payloadHash,uint32 payloadBytes,bytes32 runtimeHash,bytes32 replayHash,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash,address recorder,uint8 authorizationClass,uint64 grantRevision,uint64 recordedAt)";
const sourceFileTuple = "tuple(string path,bytes content)";
const runtimeTuple = `tuple(bytes32 environmentObjectHash,bytes32 environmentManifestHash,string entrypoint,string interpreter,string launcher,string sourceRoot,string[] argv,${packageFileTuple}[] members)`;
const replayTuple = "tuple(bytes32 runtimeHash,bytes32 contextHash,bytes32 reportHash,bytes32 inputsHash,bytes inputManifest,bytes transcript,uint64 executedAt,uint32 exitCode)";
const supplementTuple = `tuple(bytes implementationIndex,bytes parameters,${sourceFileTuple}[4] sources,${runtimeTuple} runtime,${replayTuple} replay)`;
const dependenciesTuple = "tuple(address[7] targets,bytes32[7] codeHashes,uint256 chainId,bytes32 rendererCatalogId,bytes32 rendererCatalogHash,uint32 rendererCatalogBytes,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas)";
const referenceTuple = "tuple(uint16 algorithm,bytes32 canonicalizationId,bytes digest,string uri)";
const artistClaimTuple = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,uint8 origin)";
const displayTuple = `tuple(${referenceTuple} scale,${referenceTuple} timing,${referenceTuple} color,${referenceTuple} interaction,${referenceTuple} motion,${referenceTuple} frameRate)`;
const interviewRecordTuple = `tuple(uint256 chainId,address core,address host,bytes32 recordHash,bytes32 schemaId,bytes32 profileHash,${referenceTuple} payload)`;
const interviewEntryTuple = `tuple(uint8 status,${interviewRecordTuple} record,${referenceTuple} waiverStatement)`;
const intentTuple = `tuple(bytes32 subjectId,bytes32 profileHash,bytes32 predecessor,${artistClaimTuple} artist,${displayTuple} display,${referenceTuple} variabilityTolerances,${referenceTuple} dependencyAging,${referenceTuple} significantProperties,${interviewEntryTuple} interview)`;
const propertyTuple = "tuple(bytes32 id,string name,string significantValue)";
const assessmentTuple = "tuple(bytes32 propertyId,bool conforms,string observation)";
const conditionTuple = `tuple(bytes32 contextHash,bytes32 intentRecordHash,bytes32 intentSelectionHash,bytes32 propertiesHash,address examiner,string examinerName,${referenceTuple} institution,${referenceTuple} credentials,uint64 examinedAt,${assessmentTuple}[] assessments)`;
const metricTuple = "tuple(bytes32 metricId,bytes32 algorithm,string tool,string version,bytes32 implementationHash,bytes32 parametersHash,uint64 scale)";
const perceptualTuple = `tuple(${metricTuple} metric,int64 threshold,int64[] scores,bytes32 reportHash,string reportURI,uint64 evaluatedAt)`;
const curatedTuple = `tuple(bytes32 conditionRecordHash,bytes32 intentRecordHash,uint64 intentRevision,${intentTuple} intent,${propertyTuple}[] properties,${conditionTuple} condition)`;
const evidenceTuple = `tuple(uint8 mode,tuple(bytes32 objectHash,bytes32 coverageHash)[] repeats,${perceptualTuple} perceptual,${curatedTuple} curated)`;
const coverageTuple = "tuple(bytes32 coverageHash,bytes32 objectHash,bytes32 artistId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,bytes32 firstReceiptHash,bytes32 secondReceiptHash,bytes32 firstFixityHash,bytes32 secondFixityHash,bytes32 checkpointHash,bytes32 profileHash)";
const factsTuple = `tuple(uint8 mode,bytes32 evidenceHash,bytes32 interpretationHash,bytes32 conditionRecordHash,bytes32 conditionReceiptHash,bytes32 intentSelectionHash,${coverageTuple}[] repeats)`;

const publicationAbi = new Interface([
  `event ReferenceMetricSupplementPublished(uint16 schemaVersion,bytes32 indexed referenceRecordHash,bytes32 indexed supplementHash,${supplementReceiptTuple} receipt)`,
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function deploymentChainId() view returns (uint256)",
  `function dependencies() view returns (${dependenciesTuple})`,
  `function publishMetricSupplement(bytes32,${supplementTuple}) returns (bytes32)`,
  `function metricSupplement(bytes32) view returns (bytes,${supplementReceiptTuple})`,
  `function requireMetricSupplement(bytes32) view returns (${supplementReceiptTuple})`,
  `function referenceRecord(bytes32) view returns (${publicationTuple},${originalReceiptTuple})`,
  `function currentReference(uint256) view returns (${originalReceiptTuple})`,
  `function requireCurrent(uint256,bytes32,uint64) view returns (${originalReceiptTuple})`,
  "function referenceLock(uint256) view returns (tuple(bytes32 recordHash,uint64 revision,bytes32 actionId,uint64 lockedAt))",
  "function referenceMode(bytes32) view returns (uint8,bytes32)",
  `function referenceModeEvidence(bytes32) view returns (${evidenceTuple},${factsTuple})`,
  `function modeContextHash(${publicationTuple}) view returns (bytes32)`,
]);

const storeAbi = new Interface([
  "event ChunkPublished(bytes32 indexed hash,address indexed pointer,uint32 length)",
  "function MAX_CHUNK_BYTES() view returns (uint256)",
  "function chunk(bytes32) view returns (address pointer,uint32 length)",
  "function publishChunk(bytes) returns (bytes32 hash,address pointer)",
  "function readChunk(bytes32) view returns (bytes)",
]);

const metadataAbi = new Interface([
  "function familyWriter(uint256,bytes32,uint8,address) view returns (bool,uint64)",
]);
const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns (bool success)",
]);

const CURATOR = id("6529STREAM_RECORD_FAMILY_CURATOR_V1") as Hex;
const MAX_RPC_BYTES = 1_100_000;
const coder = AbiCoder.defaultAbiCoder();

function exactKeys(
  value: unknown,
  expected: readonly string[],
  label: string,
): asserts value is Record<string, unknown> {
  if (
    value === null
    || typeof value !== "object"
    || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...expected].sort().join(",")
  ) {
    throw new Error(`${label} contains missing or unknown properties`);
  }
}

function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (
    typeof value !== "bigint"
    || value < 0n
    || value >= 1n << BigInt(bits)
    || (positive && value === 0n)
  ) {
    throw new Error(`${label} must be a ${positive ? "positive" : "nonnegative"} uint${bits} bigint`);
  }
  return value;
}

function address(value: unknown, label: string, allowZero = false): Address {
  if (typeof value !== "string") throw new Error(`${label} must be an address`);
  let result: string;
  try {
    result = getAddress(value);
  } catch {
    throw new Error(`${label} must be an address`);
  }
  if (!allowZero && result === ZeroAddress) throw new Error(`${label} cannot be zero`);
  return result as Address;
}

function hash(value: unknown, label: string, allowZero = false): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZeroHash)
  ) {
    throw new Error(`${label} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  }
  return value.toLowerCase() as Hex;
}

function same(left: unknown, right: unknown): boolean {
  return typeof left === "string" && typeof right === "string"
    ? left.toLowerCase() === right.toLowerCase()
    : left === right;
}

function render(value: unknown): string {
  return JSON.stringify(value, (_, child) => (
    typeof child === "bigint" ? `${child.toString()}n` : child
  ));
}

function concreteBlock(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) {
    throw new Error("Reference metric reads require a concrete nonnegative block number");
  }
  return value as number;
}

function unsignedCall(to: Address, data: string): UnsignedCall {
  return Object.freeze({ to, data: data as Hex, value: 0n });
}

async function rpc(
  provider: Pick<Provider, "call">,
  target: Address,
  iface: Interface,
  method: string,
  args: readonly unknown[],
  blockTag: number,
  maximumBytes = MAX_RPC_BYTES,
): Promise<readonly unknown[]> {
  const raw = await provider.call({
    to: target,
    data: iface.encodeFunctionData(method, args),
    blockTag,
  });
  if (
    typeof raw !== "string"
    || (raw.length - 2) / 2 > maximumBytes
    || !isHexString(raw, true)
  ) {
    throw new Error(`Malformed or oversized ${method} return`);
  }
  const decoded = iface.decodeFunctionResult(method, raw);
  if (iface.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) {
    throw new Error(`Noncanonical ${method} return`);
  }
  return decoded;
}

function tuple(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object") {
    throw new Error(`Malformed ${label} tuple`);
  }
  return value as Record<string, unknown>;
}

function locator(value: ReferenceMetricOriginalLocator): ReferenceMetricOriginalLocator {
  exactKeys(value, ["collectionId", "revision"], "reference metric original locator");
  return Object.freeze({
    collectionId: uint(value.collectionId, 256, "collectionId", true),
    revision: uint(value.revision, 64, "revision", true),
  });
}

export function prepareReferenceMetricSupplementPlan(
  chainId: bigint,
  producer: Address,
  store: Address,
  core: Address,
  metadata: Address,
  caller: Address,
  originalLocator: ReferenceMetricOriginalLocator,
  original: ReferenceMetricOriginalContext,
  supplement: ReferenceMetricSupplement,
  maximumExecutedAt: bigint,
): PreparedReferenceMetricSupplementPlan {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedProducer = address(producer, "producer");
  const normalizedStore = address(store, "store");
  const normalizedCore = address(core, "core");
  const normalizedMetadata = address(metadata, "metadata");
  const normalizedCaller = address(caller, "caller");
  const normalizedLocator = locator(originalLocator);
  const maximum = uint(maximumExecutedAt, 64, "maximumExecutedAt");
  const artifact = validateReferenceMetricSupplement(original, supplement, maximum);
  const chunks = referenceMetricSupplementChunks(artifact.canonical).map((chunk) => Object.freeze({
    index: chunk.index,
    offset: chunk.offset,
    hash: chunk.hash,
    bytes: chunk.bytes,
    caller: normalizedCaller,
    call: unsignedCall(
      normalizedStore,
      storeAbi.encodeFunctionData("publishChunk", [chunk.bytes]),
    ),
  }));
  return Object.freeze({
    chainId: normalizedChainId,
    producer: normalizedProducer,
    store: normalizedStore,
    core: normalizedCore,
    metadata: normalizedMetadata,
    caller: normalizedCaller,
    locator: normalizedLocator,
    maximumExecutedAt: maximum,
    artifact,
    chunks: Object.freeze(chunks),
    publication: unsignedCall(
      normalizedProducer,
      publicationAbi.encodeFunctionData("publishMetricSupplement", [
        artifact.original.referenceRecordHash,
        artifact.supplement,
      ]),
    ),
  });
}

function samePlan(input: PreparedReferenceMetricSupplementPlan): PreparedReferenceMetricSupplementPlan {
  exactKeys(
    input,
    [
      "chainId",
      "producer",
      "store",
      "core",
      "metadata",
      "caller",
      "locator",
      "maximumExecutedAt",
      "artifact",
      "chunks",
      "publication",
    ],
    "prepared reference metric plan",
  );
  const rebuilt = prepareReferenceMetricSupplementPlan(
    input.chainId,
    input.producer,
    input.store,
    input.core,
    input.metadata,
    input.caller,
    input.locator,
    input.artifact.original,
    input.artifact.supplement,
    input.maximumExecutedAt,
  );
  if (render(input) !== render(rebuilt)) {
    throw new Error("Prepared reference metric plan differs from canonical reconstruction");
  }
  return rebuilt;
}

function decodeSupplementReceipt(value: unknown): ReferenceMetricReceipt {
  const row = tuple(value, "reference metric supplement receipt");
  return Object.freeze({
    supplementHash: hash(row.supplementHash, "supplementHash"),
    referenceRecordHash: hash(row.referenceRecordHash, "referenceRecordHash"),
    payloadHash: hash(row.payloadHash, "payloadHash"),
    payloadBytes: uint(BigInt(row.payloadBytes as bigint), 32, "payloadBytes", true),
    runtimeHash: hash(row.runtimeHash, "runtimeHash"),
    replayHash: hash(row.replayHash, "replayHash"),
    schemaHash: hash(row.schemaHash, "schemaHash"),
    profileHash: hash(row.profileHash, "profileHash"),
    canonicalizationHash: hash(row.canonicalizationHash, "canonicalizationHash"),
    recorder: address(row.recorder, "recorder"),
    authorizationClass: uint(
      BigInt(row.authorizationClass as bigint),
      8,
      "authorizationClass",
      true,
    ),
    grantRevision: uint(BigInt(row.grantRevision as bigint), 64, "grantRevision", true),
    recordedAt: uint(BigInt(row.recordedAt as bigint), 64, "recordedAt", true),
  });
}

function assertOriginalReceipt(
  value: unknown,
  plan: PreparedReferenceMetricSupplementPlan,
): { readonly recorder: Address; readonly encoded: string } {
  const row = tuple(value, "original reference receipt");
  if (
    !same(row.recordHash, plan.artifact.original.referenceRecordHash)
    || BigInt(row.collectionId as bigint) !== plan.locator.collectionId
    || BigInt(row.revision as bigint) !== plan.locator.revision
  ) {
    throw new Error("Original reference receipt differs from the reviewed locator");
  }
  return Object.freeze({
    recorder: address(row.recorder, "original reference recorder"),
    encoded: publicationAbi.encodeFunctionResult("currentReference", [value]),
  });
}

function assertOriginalProjection(
  publicationValue: unknown,
  evidenceValue: unknown,
  factsValue: unknown,
  contextValue: unknown,
  dependenciesValue: unknown,
  plan: PreparedReferenceMetricSupplementPlan,
): { readonly evidenceHash: Hex; readonly contextHash: Hex } {
  const publication = tuple(publicationValue, "original reference publication");
  const environment = tuple(publication.environment, "original reference environment");
  const evidence = tuple(evidenceValue, "original mode evidence");
  const facts = tuple(factsValue, "original mode facts");
  const dependencies = tuple(dependenciesValue, "reference dependencies");
  const perceptual = tuple(evidence.perceptual, "original perceptual evidence");
  const metric = tuple(perceptual.metric, "original metric");
  const original = plan.artifact.original;
  const packageFiles = Array.from(environment.packageFiles as ArrayLike<Record<string, unknown>>);
  const captures = Array.from(publication.captures as ArrayLike<Record<string, unknown>>);
  const packageProjection = packageFiles.map((member) => ({
    path: member.path,
    byteSize: BigInt(member.byteSize as bigint),
    sha256Digest: String(member.sha256Digest).toLowerCase(),
  }));
  const captureProjection = captures.map((capture) => {
    const pair = Array.from(capture.repeatCaptureSha256 as ArrayLike<string>);
    return { firstSha256: pair[0]?.toLowerCase(), secondSha256: pair[1]?.toLowerCase() };
  });
  const contextHash = hash(contextValue, "mode context hash");
  const evidenceHash = hash(facts.evidenceHash, "mode evidence hash");
  const targets = Array.from(dependencies.targets as ArrayLike<string>);
  const codeHashes = Array.from(dependencies.codeHashes as ArrayLike<string>);
  const independentContextHash = keccak256(coder.encode(
    [
      "bytes32",
      "uint256",
      "address",
      "address[7]",
      "bytes32[7]",
      "uint256",
      "bytes32",
      "bytes32",
      "uint64",
      `${captureTuple}[]`,
      environmentTuple,
    ],
    [
      id("6529STREAM_REFERENCE_MODE_CONTEXT_V1"),
      BigInt(dependencies.chainId as bigint),
      plan.producer,
      targets,
      codeHashes,
      BigInt(publication.collectionId as bigint),
      publication.referenceId,
      publication.snapshotRecordHash,
      BigInt(publication.snapshotRevision as bigint),
      publication.captures,
      publication.environment,
    ],
  ));
  const independentEvidenceHash = keccak256(
    coder.encode([evidenceTuple], [evidenceValue]),
  );
  if (
    BigInt(publication.collectionId as bigint) !== plan.locator.collectionId
    || BigInt(evidence.mode as bigint) !== 1n
    || BigInt(facts.mode as bigint) !== 1n
    || !same(environment.objectHash, original.environmentObjectHash)
    || !same(environment.manifestHash, original.environmentManifestHash)
    || BigInt(environment.viewportWidth as bigint) !== original.viewportWidth
    || BigInt(environment.viewportHeight as bigint) !== original.viewportHeight
    || BigInt(environment.devicePixelRatio as bigint) !== original.devicePixelRatio
    || render(packageProjection) !== render(original.packageFiles)
    || render(captureProjection) !== render(original.captures)
    || !same(metric.implementationHash, original.metricImplementationHash)
    || !same(metric.parametersHash, original.metricParametersHash)
    || !same(perceptual.reportHash, original.reportHash)
    || BigInt(perceptual.threshold as bigint) !== original.threshold
    || BigInt(perceptual.evaluatedAt as bigint) !== original.evaluatedAt
    || !same(contextHash, original.contextHash)
    || !same(contextHash, independentContextHash)
    || !same(evidenceHash, independentEvidenceHash)
  ) {
    throw new Error("Original reference projection differs from the supplement preimage");
  }
  return Object.freeze({ evidenceHash, contextHash });
}

async function readAuthority(
  provider: Pick<Provider, "call">,
  plan: PreparedReferenceMetricSupplementPlan,
  blockTag: number,
): Promise<ReferenceMetricAuthority> {
  const read = async (collectionId: bigint, authorizationClass: bigint) => {
    const [enabled, revision] = await rpc(
      provider,
      plan.metadata,
      metadataAbi,
      "familyWriter",
      [collectionId, CURATOR, authorizationClass, plan.caller],
      blockTag,
      64,
    );
    return { enabled: Boolean(enabled), revision: BigInt(revision as bigint) };
  };
  const local = await read(plan.locator.collectionId, 3n);
  if (local.enabled && local.revision !== 0n) {
    return Object.freeze({ recorder: plan.caller, authorizationClass: 3n, grantRevision: local.revision });
  }
  const global = await read(0n, 8n);
  if (!global.enabled || global.revision === 0n) {
    throw new Error("Publisher lacks current Metadata CURATOR class 3 or class 8 authority");
  }
  return Object.freeze({ recorder: plan.caller, authorizationClass: 8n, grantRevision: global.revision });
}

export async function inspectReferenceMetricChunkAvailability(
  provider: Pick<Provider, "call" | "getCode">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  options: { readonly blockTag: number },
): Promise<readonly ReferenceMetricChunkAvailability[]> {
  const plan = samePlan(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const maximumResult = await rpc(provider, plan.store, storeAbi, "MAX_CHUNK_BYTES", [], blockTag, 32);
  if (BigInt(maximumResult[0] as bigint) !== BigInt(REFERENCE_METRIC_MAX_CHUNK_BYTES)) {
    throw new Error("Store chunk limit differs from the supplement profile");
  }
  const rows: ReferenceMetricChunkAvailability[] = [];
  for (const chunk of plan.chunks) {
    const [pointerValue, lengthValue] = await rpc(
      provider,
      plan.store,
      storeAbi,
      "chunk",
      [chunk.hash],
      blockTag,
      64,
    );
    const pointer = address(pointerValue, "chunk pointer");
    const byteLength = Number(BigInt(lengthValue as bigint));
    if (byteLength !== (chunk.bytes.length - 2) / 2) {
      throw new Error(`Stored metric chunk ${chunk.index} has an unexpected length`);
    }
    const code = await provider.getCode(pointer, blockTag);
    if (
      typeof code !== "string"
      || code.length !== 2 + 2 * (byteLength + 1)
      || !isHexString(code, true)
      || code.slice(0, 4).toLowerCase() !== "0x00"
      || `0x${code.slice(4)}`.toLowerCase() !== chunk.bytes.toLowerCase()
    ) {
      throw new Error(`Stored metric chunk ${chunk.index} code differs from the reviewed bytes`);
    }
    rows.push(Object.freeze({ index: chunk.index, hash: chunk.hash, pointer, byteLength }));
  }
  return Object.freeze(rows);
}

export async function simulateReferenceMetricChunkUpload(
  provider: Pick<Provider, "call">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  chunkIndex: number,
  options: { readonly blockTag: number },
): Promise<{ readonly hash: Hex; readonly pointer: Address }> {
  const plan = samePlan(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if (!Number.isSafeInteger(chunkIndex) || chunkIndex < 0 || chunkIndex >= plan.chunks.length) {
    throw new Error("Metric chunk index is outside the prepared plan");
  }
  const chunk = plan.chunks[chunkIndex]!;
  const raw = await provider.call({ ...chunk.call, from: chunk.caller, blockTag });
  if (typeof raw !== "string" || !isHexString(raw, 64)) {
    throw new Error("Malformed metric chunk upload simulation return");
  }
  const decoded = storeAbi.decodeFunctionResult("publishChunk", raw);
  const canonical = storeAbi.encodeFunctionResult("publishChunk", decoded);
  const resultHash = hash(decoded[0], "published chunk hash");
  const pointer = address(decoded[1], "published chunk pointer");
  if (canonical.toLowerCase() !== raw.toLowerCase() || !same(resultHash, chunk.hash)) {
    throw new Error("Metric chunk upload simulation differs from the prepared chunk");
  }
  return Object.freeze({ hash: resultHash, pointer });
}

export async function inspectReferenceMetricSupplementPublication(
  provider: Pick<Provider, "getNetwork" | "call" | "getCode">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  options: { readonly blockTag: number },
): Promise<ReferenceMetricPublicationInspection> {
  const plan = samePlan(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== plan.chainId) {
    throw new Error("RPC chain differs from the prepared metric supplement plan");
  }
  const referenceHash = plan.artifact.original.referenceRecordHash;
  const [
    [dependenciesValue],
    [coreValue],
    [metadataValue],
    [deploymentChainId],
    record,
    [currentValue],
    [requiredValue],
    [lockValue],
    mode,
    evidence,
  ] = await Promise.all([
    rpc(provider, plan.producer, publicationAbi, "dependencies", [], blockTag, 704),
    rpc(provider, plan.producer, publicationAbi, "core", [], blockTag, 32),
    rpc(provider, plan.producer, publicationAbi, "metadataHost", [], blockTag, 32),
    rpc(provider, plan.producer, publicationAbi, "deploymentChainId", [], blockTag, 32),
    rpc(provider, plan.producer, publicationAbi, "referenceRecord", [referenceHash], blockTag),
    rpc(provider, plan.producer, publicationAbi, "currentReference", [plan.locator.collectionId], blockTag, 640),
    rpc(
      provider,
      plan.producer,
      publicationAbi,
      "requireCurrent",
      [plan.locator.collectionId, referenceHash, plan.locator.revision],
      blockTag,
      640,
    ),
    rpc(provider, plan.producer, publicationAbi, "referenceLock", [plan.locator.collectionId], blockTag, 128),
    rpc(provider, plan.producer, publicationAbi, "referenceMode", [referenceHash], blockTag, 64),
    rpc(provider, plan.producer, publicationAbi, "referenceModeEvidence", [referenceHash], blockTag),
  ]);
  const dependencies = tuple(dependenciesValue, "reference dependencies");
  const targets = Array.from(dependencies.targets as ArrayLike<string>);
  if (
    BigInt(dependencies.chainId as bigint) !== plan.chainId
    || BigInt(deploymentChainId as bigint) !== plan.chainId
    || !same(targets[0], plan.core)
    || !same(targets[1], plan.metadata)
    || !same(targets[3], plan.store)
    || !same(coreValue, plan.core)
    || !same(metadataValue, plan.metadata)
  ) {
    throw new Error("Metric producer dependencies differ from the reviewed coordinates");
  }
  const publicationValue = record[0];
  const storedReceiptValue = record[1];
  const storedReceipt = assertOriginalReceipt(storedReceiptValue, plan);
  const currentReceipt = assertOriginalReceipt(currentValue, plan);
  const requiredReceipt = assertOriginalReceipt(requiredValue, plan);
  if (
    storedReceipt.encoded !== currentReceipt.encoded
    || storedReceipt.encoded !== requiredReceipt.encoded
  ) {
    throw new Error("Original reference is not the exact current source record");
  }
  const [contextValue] = await rpc(
    provider,
    plan.producer,
    publicationAbi,
    "modeContextHash",
    [publicationValue],
    blockTag,
    32,
  );
  const projection = assertOriginalProjection(
    publicationValue,
    evidence[0],
    evidence[1],
    contextValue,
    dependenciesValue,
    plan,
  );
  if (BigInt(mode[0] as bigint) !== 1n || !same(mode[1], projection.evidenceHash)) {
    throw new Error("Original reference mode differs from the perceptual evidence");
  }
  const lock = tuple(lockValue, "reference lock");
  if (
    !same(lock.recordHash, ZeroHash)
    || BigInt(lock.revision as bigint) !== 0n
    || !same(lock.actionId, ZeroHash)
    || BigInt(lock.lockedAt as bigint) !== 0n
  ) {
    throw new Error("Original reference is already locked");
  }
  const authority = await readAuthority(provider, plan, blockTag);
  const chunks = await inspectReferenceMetricChunkAvailability(provider, plan, { blockTag });
  return Object.freeze({
    plan,
    authority,
    original: Object.freeze({
      collectionId: plan.locator.collectionId,
      revision: plan.locator.revision,
      originalRecorder: storedReceipt.recorder,
      evidenceHash: projection.evidenceHash,
      contextHash: projection.contextHash,
    }),
    chunks,
    checked: Object.freeze([
      "producer dependency coordinates and exact current original reference",
      "PERCEPTUAL evidence projection and onchain mode context",
      "unlocked state, actual class 3/8 writer and every retained chunk occurrence",
    ]),
    limitations: Object.freeze([
      "numeric block pin has no reorg hash check",
      "read-only inspection cannot prove once-only publication absence; exact target simulation enforces it",
      "simulation does not establish Safe threshold authority, inclusion or external replay honesty",
    ]),
  });
}

export async function simulateReferenceMetricSupplementPublication(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call" | "getCode">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectReferenceMetricSupplementPublication(
    provider,
    preparedInput,
    { blockTag },
  );
  const raw = await provider.call({
    ...inspected.plan.publication,
    from: inspected.plan.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, 32)) {
    throw new Error("Malformed metric supplement publication simulation return");
  }
  const decoded = publicationAbi.decodeFunctionResult("publishMetricSupplement", raw);
  const canonical = publicationAbi.encodeFunctionResult("publishMetricSupplement", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical metric supplement publication simulation return");
  }
  const block = await provider.getBlock(blockTag);
  if (
    block === null
    || typeof block.timestamp !== "number"
    || !Number.isSafeInteger(block.timestamp)
    || block.timestamp <= 0
    || BigInt(block.timestamp) < inspected.plan.artifact.supplement.replay.executedAt
  ) {
    throw new Error("Pinned metric publication timestamp is unavailable");
  }
  const expectedReceipt: ReferenceMetricReceipt = {
    supplementHash: ZeroHash as Hex,
    referenceRecordHash: inspected.plan.artifact.original.referenceRecordHash,
    payloadHash: inspected.plan.artifact.payloadHash,
    payloadBytes: BigInt((inspected.plan.artifact.canonical.length - 2) / 2),
    runtimeHash: inspected.plan.artifact.runtimeHash,
    replayHash: inspected.plan.artifact.replayHash,
    schemaHash: REFERENCE_METRIC_SCHEMA_HASH,
    profileHash: REFERENCE_METRIC_PROFILE_HASH,
    canonicalizationHash: REFERENCE_METRIC_CANONICALIZATION_HASH,
    recorder: inspected.authority.recorder,
    authorizationClass: inspected.authority.authorizationClass,
    grantRevision: inspected.authority.grantRevision,
    recordedAt: BigInt(block.timestamp),
  };
  const expectedHash = referenceMetricSupplementHash(
    {
      chainId: inspected.plan.chainId,
      producer: inspected.plan.producer,
      core: inspected.plan.core,
      metadata: inspected.plan.metadata,
      referenceRecordHash: inspected.plan.artifact.original.referenceRecordHash,
    },
    expectedReceipt,
  );
  const result = hash(decoded[0], "simulated supplement hash");
  if (!same(result, expectedHash)) {
    throw new Error("Simulated supplement hash differs from the pinned receipt preimage");
  }
  return result;
}

export async function inspectHistoricalReferenceMetricSupplement(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  expectedAuthority: ReferenceMetricAuthority,
  options: { readonly blockTag: number },
): Promise<ReferenceMetricReceipt> {
  const plan = samePlan(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  exactKeys(
    expectedAuthority,
    ["recorder", "authorizationClass", "grantRevision"],
    "expected metric supplement authority",
  );
  const authority = Object.freeze({
    recorder: address(expectedAuthority.recorder, "expected recorder"),
    authorizationClass: uint(
      expectedAuthority.authorizationClass,
      8,
      "expected authorizationClass",
      true,
    ),
    grantRevision: uint(
      expectedAuthority.grantRevision,
      64,
      "expected grantRevision",
      true,
    ),
  });
  if (authority.authorizationClass !== 3n && authority.authorizationClass !== 8n) {
    throw new Error("Expected metric authority must be class 3 or class 8");
  }
  if ((await provider.getNetwork()).chainId !== plan.chainId) {
    throw new Error("RPC chain differs from the historical metric supplement coordinates");
  }
  const [canonicalValue, receiptValue] = await rpc(
    provider,
    plan.producer,
    publicationAbi,
    "metricSupplement",
    [plan.artifact.original.referenceRecordHash],
    blockTag,
  );
  if (
    typeof canonicalValue !== "string"
    || !isHexString(canonicalValue, true)
    || canonicalValue.toLowerCase() !== plan.artifact.canonical.toLowerCase()
  ) {
    throw new Error("Historical metric supplement bytes differ from the reviewed artifact");
  }
  return validateReferenceMetricReceipt(
    {
      chainId: plan.chainId,
      producer: plan.producer,
      core: plan.core,
      metadata: plan.metadata,
      referenceRecordHash: plan.artifact.original.referenceRecordHash,
    },
    plan.artifact,
    decodeSupplementReceipt(receiptValue),
    authority,
  );
}

export async function inspectCurrentReferenceMetricSupplement(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  expectedAuthority: ReferenceMetricAuthority,
  options: { readonly blockTag: number },
): Promise<ReferenceMetricReceipt> {
  const plan = samePlan(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const historical = await inspectHistoricalReferenceMetricSupplement(
    provider,
    plan,
    expectedAuthority,
    { blockTag },
  );
  const [currentValue] = await rpc(
    provider,
    plan.producer,
    publicationAbi,
    "requireMetricSupplement",
    [plan.artifact.original.referenceRecordHash],
    blockTag,
    416,
  );
  const current = decodeSupplementReceipt(currentValue);
  if (render(current) !== render(historical)) {
    throw new Error("Current metric supplement receipt differs from historical retention");
  }
  return current;
}

export async function inspectReferenceMetricPublicationReceipt(
  provider: Pick<Provider, "getNetwork" | "getTransaction" | "getTransactionReceipt" | "getBlock">,
  preparedInput: PreparedReferenceMetricSupplementPlan,
  evidenceInput: ReferenceMetricPublicationReceiptEvidence,
): Promise<ReferenceMetricReceipt> {
  const plan = samePlan(preparedInput);
  exactKeys(
    evidenceInput,
    ["transactionHash", "execution"],
    "metric publication receipt evidence",
  );
  const transactionHash = hash(evidenceInput.transactionHash, "transactionHash");
  const execution = evidenceInput.execution;
  if (execution !== "direct" && execution !== "safe") {
    throw new Error("Metric publication receipt execution must be direct or safe");
  }
  if ((await provider.getNetwork()).chainId !== plan.chainId) {
    throw new Error("RPC chain differs from metric publication receipt coordinates");
  }
  const [transaction, receipt] = await Promise.all([
    provider.getTransaction(transactionHash),
    provider.getTransactionReceipt(transactionHash),
  ]);
  if (transaction === null || receipt === null) {
    throw new Error("Metric publication transaction receipt is unavailable");
  }
  if (
    !same(transaction.hash, transactionHash)
    || !same(receipt.hash, transactionHash)
  ) {
    throw new Error("Metric publication transaction receipt has an unexpected identity");
  }
  return validateMinedReceipt(provider, plan, transaction, receipt, execution);
}

async function validateMinedReceipt(
  provider: Pick<Provider, "getBlock">,
  plan: PreparedReferenceMetricSupplementPlan,
  transaction: TransactionResponse,
  receipt: TransactionReceipt,
  execution: "direct" | "safe",
): Promise<ReferenceMetricReceipt> {
  if (
    receipt.status !== 1
    || transaction.blockNumber === null
    || transaction.blockHash === null
    || receipt.blockNumber !== transaction.blockNumber
    || !same(receipt.blockHash, transaction.blockHash)
    || transaction.value !== 0n
  ) {
    throw new Error("Mined metric publication transaction differs from the reviewed CALL");
  }
  if (execution === "direct") {
    if (
      transaction.to === null
      || !same(transaction.from, plan.caller)
      || !same(transaction.to, plan.producer)
      || transaction.data.toLowerCase() !== plan.publication.data.toLowerCase()
    ) {
      throw new Error("Mined direct metric transaction differs from the reviewed CALL");
    }
  } else {
    if (transaction.to === null || !same(transaction.to, plan.caller)) {
      throw new Error("Mined Safe metric transaction does not target the reviewed Safe");
    }
    if (
      typeof transaction.data !== "string"
      || (transaction.data.length - 2) / 2
        > REFERENCE_METRIC_MAX_CANONICAL_BYTES + 65_536
      || !isHexString(transaction.data, true)
    ) {
      throw new Error("Mined Safe metric transaction envelope is malformed or oversized");
    }
    let safeCall;
    try {
      safeCall = safeAbi.decodeFunctionData("execTransaction", transaction.data);
    } catch {
      throw new Error("Mined Safe metric transaction is not an execTransaction envelope");
    }
    const canonicalSafeCall = safeAbi.encodeFunctionData("execTransaction", safeCall);
    if (
      canonicalSafeCall.toLowerCase() !== transaction.data.toLowerCase()
      ||
      !same(safeCall.to, plan.producer)
      || BigInt(safeCall.value as bigint) !== 0n
      || String(safeCall.data).toLowerCase() !== plan.publication.data.toLowerCase()
      || BigInt(safeCall.operation as bigint) !== 0n
    ) {
      throw new Error("Mined Safe metric envelope differs from the reviewed CALL");
    }
  }
  const matching = receipt.logs.flatMap((log) => {
    if (!same(log.address, plan.producer)) return [];
    try {
      if (log.topics.length !== 3 || !isHexString(log.data, 448)) return [];
      const parsed = publicationAbi.parseLog({ topics: [...log.topics], data: log.data });
      if (parsed?.name !== "ReferenceMetricSupplementPublished") return [];
      const canonical = publicationAbi.encodeEventLog(parsed.fragment, parsed.args);
      if (
        canonical.data.toLowerCase() !== log.data.toLowerCase()
        || render(canonical.topics.map((topic) => topic.toLowerCase()))
          !== render([...log.topics].map((topic) => topic.toLowerCase()))
      ) {
        return [];
      }
      return [parsed];
    } catch {
      return [];
    }
  });
  if (matching.length !== 1) {
    throw new Error("Mined metric publication must emit exactly one supplement receipt");
  }
  const event = matching[0]!;
  if (
    BigInt(event.args.schemaVersion as bigint) !== 1n
    || !same(event.args.referenceRecordHash, plan.artifact.original.referenceRecordHash)
  ) {
    throw new Error("Mined metric publication event differs from the reviewed reference");
  }
  const decoded = decodeSupplementReceipt(event.args.receipt);
  if (!same(decoded.supplementHash, event.args.supplementHash)) {
    throw new Error("Mined metric receipt hash differs from the indexed event hash");
  }
  const block = await provider.getBlock(receipt.blockNumber);
  if (
    block === null
    || !same(block.hash, receipt.blockHash)
    || !Number.isSafeInteger(block.timestamp)
    || decoded.recordedAt !== BigInt(block.timestamp)
  ) {
    throw new Error("Mined metric receipt timestamp differs from its block");
  }
  return validateReferenceMetricReceipt(
    {
      chainId: plan.chainId,
      producer: plan.producer,
      core: plan.core,
      metadata: plan.metadata,
      referenceRecordHash: plan.artifact.original.referenceRecordHash,
    },
    plan.artifact,
    decoded,
    {
      recorder: plan.caller,
      authorizationClass: decoded.authorizationClass,
      grantRevision: decoded.grantRevision,
    },
  );
}
