import {
  AbiCoder,
  ZeroAddress,
  getAddress,
  hexlify,
  id,
  isHexString,
  keccak256,
  sha256,
  toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";

export interface ReferenceMetricPackageFile {
  readonly path: string;
  readonly byteSize: bigint;
  readonly sha256Digest: Hex;
}

export interface ReferenceMetricSourceFile {
  readonly path: string;
  readonly content: Hex;
}

export interface ReferenceMetricRuntime {
  readonly environmentObjectHash: Hex;
  readonly environmentManifestHash: Hex;
  readonly entrypoint: string;
  readonly interpreter: string;
  readonly launcher: string;
  readonly sourceRoot: string;
  readonly argv: readonly string[];
  readonly members: readonly ReferenceMetricPackageFile[];
}

export interface ReferenceMetricReplay {
  readonly runtimeHash: Hex;
  readonly contextHash: Hex;
  readonly reportHash: Hex;
  readonly inputsHash: Hex;
  readonly inputManifest: Hex;
  readonly transcript: Hex;
  readonly executedAt: bigint;
  readonly exitCode: bigint;
}

export interface ReferenceMetricSupplement {
  readonly implementationIndex: Hex;
  readonly parameters: Hex;
  readonly sources: readonly [
    ReferenceMetricSourceFile,
    ReferenceMetricSourceFile,
    ReferenceMetricSourceFile,
    ReferenceMetricSourceFile,
  ];
  readonly runtime: ReferenceMetricRuntime;
  readonly replay: ReferenceMetricReplay;
}

export interface ReferenceMetricTranscript {
  readonly runtimeHash: Hex;
  readonly contextHash: Hex;
  readonly reportHash: Hex;
  readonly inputsHash: Hex;
  readonly executedAt: bigint;
  readonly exitCode: bigint;
  readonly diagnostic: Hex;
}

export interface ReferenceMetricOriginalCapture {
  readonly firstSha256: Hex;
  readonly secondSha256: Hex;
}

/** Projection of immutable fields from the original V1 publication and evidence. */
export interface ReferenceMetricOriginalContext {
  readonly referenceRecordHash: Hex;
  readonly contextHash: Hex;
  readonly environmentObjectHash: Hex;
  readonly environmentManifestHash: Hex;
  readonly viewportWidth: bigint;
  readonly viewportHeight: bigint;
  readonly devicePixelRatio: bigint;
  readonly packageFiles: readonly ReferenceMetricPackageFile[];
  readonly captures: readonly ReferenceMetricOriginalCapture[];
  readonly metricImplementationHash: Hex;
  readonly metricParametersHash: Hex;
  readonly reportHash: Hex;
  readonly threshold: bigint;
  readonly evaluatedAt: bigint;
}

export interface ReferenceMetricCanonicalSupplement {
  readonly original: ReferenceMetricOriginalContext;
  readonly supplement: ReferenceMetricSupplement;
  readonly canonical: Hex;
  readonly payloadHash: Hex;
  readonly implementationIndex: Hex;
  readonly inputManifest: Hex;
  readonly runtimeHash: Hex;
  readonly replayHash: Hex;
}

export interface ReferenceMetricReceipt {
  readonly supplementHash: Hex;
  readonly referenceRecordHash: Hex;
  readonly payloadHash: Hex;
  readonly payloadBytes: bigint;
  readonly runtimeHash: Hex;
  readonly replayHash: Hex;
  readonly schemaHash: Hex;
  readonly profileHash: Hex;
  readonly canonicalizationHash: Hex;
  readonly recorder: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
  readonly recordedAt: bigint;
}

export interface ReferenceMetricReceiptCoordinates {
  readonly chainId: bigint;
  readonly producer: Address;
  readonly core: Address;
  readonly metadata: Address;
  readonly referenceRecordHash: Hex;
}

export interface ReferenceMetricAuthority {
  readonly recorder: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
}

export interface ReferenceMetricChunk {
  readonly index: number;
  readonly offset: number;
  readonly bytes: Hex;
  readonly hash: Hex;
}

export const REFERENCE_METRIC_SOURCE_PATHS = Object.freeze([
  "tools/museum/canonical.py",
  "tools/museum/chain_abi.py",
  "tools/preservation/reference_manifest.py",
  "tools/preservation/reference_metric.py",
] as const);
export const REFERENCE_METRIC_SCHEMA_HASH =
  "0xe1d65752e9ccd6217a35d52ac5c3358bd1b22211472b10cd38461bac1795677a" as Hex;
export const REFERENCE_METRIC_PROFILE_HASH =
  "0x9044071059abb70a02df3ebd40ce30ad024203d2058235540ff7c449ea8ef036" as Hex;
export const REFERENCE_METRIC_CANONICALIZATION_HASH =
  "0x88c5f5a1b04f40ebae17a2c6f85ba5cd88c32d9139a809f0a1b209afbe15e883" as Hex;
export const REFERENCE_METRIC_MAX_CANONICAL_BYTES = 524_288;
export const REFERENCE_METRIC_MAX_CHUNK_BYTES = 8_192;

const MAX_SOURCE_BYTES = 131_072;
const MAX_PARAMETERS_BYTES = 65_536;
const MAX_MANIFEST_BYTES = 65_536;
const MAX_TRANSCRIPT_BYTES = 65_536;
const MAX_RUNTIME_MEMBERS = 2_048;
const MAX_PATH_BYTES = 8_192;
const ENTRYPOINT = "metric/source/tools/preservation/reference_metric.py";
const INTERPRETER = "metric/python/python.exe";
const LAUNCHER = "metric/launch.py";
const SOURCE_ROOT = "metric/source";
const ARGV = Object.freeze(["-I", "-S", "-B", LAUNCHER] as const);
const ZERO_HASH = `0x${"00".repeat(32)}`;
const coder = AbiCoder.defaultAbiCoder();
const packageFileTuple = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)";
const sourceFileTuple = "tuple(string path,bytes content)";
const runtimeTuple = `tuple(bytes32 environmentObjectHash,bytes32 environmentManifestHash,string entrypoint,string interpreter,string launcher,string sourceRoot,string[] argv,${packageFileTuple}[] members)`;
const replayTuple = "tuple(bytes32 runtimeHash,bytes32 contextHash,bytes32 reportHash,bytes32 inputsHash,bytes inputManifest,bytes transcript,uint64 executedAt,uint32 exitCode)";
const supplementTuple = `tuple(bytes implementationIndex,bytes parameters,${sourceFileTuple}[4] sources,${runtimeTuple} runtime,${replayTuple} replay)`;
const receiptTuple = "tuple(bytes32 supplementHash,bytes32 referenceRecordHash,bytes32 payloadHash,uint32 payloadBytes,bytes32 runtimeHash,bytes32 replayHash,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash,address recorder,uint8 authorizationClass,uint64 grantRevision,uint64 recordedAt)";

function exactKeys(
  value: unknown,
  names: readonly string[],
  label: string,
): asserts value is Record<string, unknown> {
  if (
    value === null
    || typeof value !== "object"
    || Array.isArray(value)
    || Object.getPrototypeOf(value) !== Object.prototype
    || Object.keys(value).sort().join(",") !== [...names].sort().join(",")
  ) {
    throw new Error(`Invalid ${label} fields`);
  }
}

function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (
    typeof value !== "bigint"
    || value < (positive ? 1n : 0n)
    || value >= 1n << BigInt(bits)
  ) {
    throw new Error(`Invalid ${label} uint${bits}`);
  }
  return value;
}

function nonnegativeInt64(value: unknown, label: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value > 1_000_000_000n) {
    throw new Error(`Invalid ${label} nonnegative int64`);
  }
  return value;
}

function hash(value: unknown, label: string, allowZero = false): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZERO_HASH)
  ) {
    throw new Error(`Invalid ${label} bytes32`);
  }
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, maximum: number, label: string, nonempty = false): Hex {
  if (typeof value !== "string" || !isHexString(value, true)) {
    throw new Error(`Invalid ${label} bytes`);
  }
  const length = (value.length - 2) / 2;
  if (length > maximum || (nonempty && length === 0)) {
    throw new Error(`Invalid ${label} byte length`);
  }
  return value.toLowerCase() as Hex;
}

function address(value: unknown, label: string): Address {
  if (typeof value !== "string") {
    throw new Error(`Invalid ${label} address`);
  }
  const result = getAddress(value) as Address;
  if (result === ZeroAddress) {
    throw new Error(`Invalid ${label} address`);
  }
  return result;
}

function boundedText(value: unknown, label: string): string {
  if (
    typeof value !== "string"
    || value.length === 0
    || toUtf8Bytes(value).length > MAX_PATH_BYTES
  ) {
    throw new Error(`Invalid ${label}`);
  }
  return value;
}

function same(left: string, right: string): boolean {
  return left.toLowerCase() === right.toLowerCase();
}

function pathLess(left: string, right: string): boolean {
  const a = toUtf8Bytes(left);
  const b = toUtf8Bytes(right);
  const length = Math.min(a.length, b.length);
  for (let i = 0; i < length; i += 1) {
    if (a[i] !== b[i]) return a[i]! < b[i]!;
  }
  return a.length < b.length;
}

function isMetricPath(path: string): boolean {
  return path.startsWith("metric/") && toUtf8Bytes(path).length > 7;
}

function normalizePackageFile(value: ReferenceMetricPackageFile): ReferenceMetricPackageFile {
  exactKeys(value, ["path", "byteSize", "sha256Digest"], "metric package file");
  return Object.freeze({
    path: boundedText(value.path, "metric package path"),
    byteSize: uint(value.byteSize, 64, "metric package byteSize"),
    sha256Digest: hash(value.sha256Digest, "metric package SHA256", true),
  });
}

function normalizeMembers(values: readonly ReferenceMetricPackageFile[]): readonly ReferenceMetricPackageFile[] {
  if (!Array.isArray(values) || values.length === 0 || values.length > MAX_RUNTIME_MEMBERS) {
    throw new Error("Invalid metric runtime member count");
  }
  const members = values.map(normalizePackageFile);
  for (let i = 0; i < members.length; i += 1) {
    if (!isMetricPath(members[i]!.path)) {
      throw new Error("Runtime members must be the complete metric/ prefix");
    }
    if (i !== 0 && !pathLess(members[i - 1]!.path, members[i]!.path)) {
      throw new Error("Metric runtime members must be in strict UTF-8 byte order");
    }
  }
  return Object.freeze(members);
}

function requiredMember(
  members: readonly ReferenceMetricPackageFile[],
  path: string,
  byteSize?: bigint,
  digest?: Hex,
): void {
  const found = members.find((member) => member.path === path);
  if (
    !found
    || found.byteSize === 0n
    || same(found.sha256Digest, ZERO_HASH)
    || (byteSize !== undefined && found.byteSize !== byteSize)
    || (digest !== undefined && !same(found.sha256Digest, digest))
  ) {
    throw new Error(`Metric runtime member differs: ${path}`);
  }
}

function normalizeSources(
  values: ReferenceMetricSupplement["sources"],
): ReferenceMetricSupplement["sources"] {
  if (!Array.isArray(values) || values.length !== REFERENCE_METRIC_SOURCE_PATHS.length) {
    throw new Error("Metric supplement requires exactly four source files");
  }
  const normalized = values.map((value, index) => {
    exactKeys(value, ["path", "content"], "metric source file");
    if (value.path !== REFERENCE_METRIC_SOURCE_PATHS[index]) {
      throw new Error("Metric source path or order differs from the closed profile");
    }
    return Object.freeze({
      path: value.path,
      content: bytes(value.content, MAX_SOURCE_BYTES, "metric source", true),
    });
  });
  return Object.freeze(normalized) as unknown as ReferenceMetricSupplement["sources"];
}

function normalizeRuntime(value: ReferenceMetricRuntime): ReferenceMetricRuntime {
  exactKeys(
    value,
    [
      "environmentObjectHash",
      "environmentManifestHash",
      "entrypoint",
      "interpreter",
      "launcher",
      "sourceRoot",
      "argv",
      "members",
    ],
    "metric runtime",
  );
  if (
    value.entrypoint !== ENTRYPOINT
    || value.interpreter !== INTERPRETER
    || value.launcher !== LAUNCHER
    || value.sourceRoot !== SOURCE_ROOT
    || !Array.isArray(value.argv)
    || value.argv.length !== ARGV.length
    || value.argv.some((argument, index) => argument !== ARGV[index])
  ) {
    throw new Error("Metric runtime launch profile differs");
  }
  return Object.freeze({
    environmentObjectHash: hash(value.environmentObjectHash, "environment object hash", true),
    environmentManifestHash: hash(value.environmentManifestHash, "environment manifest hash", true),
    entrypoint: ENTRYPOINT,
    interpreter: INTERPRETER,
    launcher: LAUNCHER,
    sourceRoot: SOURCE_ROOT,
    argv: ARGV,
    members: normalizeMembers(value.members),
  });
}

function normalizeReplay(value: ReferenceMetricReplay): ReferenceMetricReplay {
  exactKeys(
    value,
    [
      "runtimeHash",
      "contextHash",
      "reportHash",
      "inputsHash",
      "inputManifest",
      "transcript",
      "executedAt",
      "exitCode",
    ],
    "metric replay",
  );
  return Object.freeze({
    runtimeHash: hash(value.runtimeHash, "replay runtime hash", true),
    contextHash: hash(value.contextHash, "replay context hash", true),
    reportHash: hash(value.reportHash, "replay report hash", true),
    inputsHash: hash(value.inputsHash, "replay inputs hash", true),
    inputManifest: bytes(value.inputManifest, MAX_MANIFEST_BYTES, "replay input manifest"),
    transcript: bytes(value.transcript, MAX_TRANSCRIPT_BYTES, "replay transcript", true),
    executedAt: uint(value.executedAt, 64, "replay executedAt"),
    exitCode: uint(value.exitCode, 32, "replay exitCode"),
  });
}

function normalizeSupplement(value: ReferenceMetricSupplement): ReferenceMetricSupplement {
  exactKeys(
    value,
    ["implementationIndex", "parameters", "sources", "runtime", "replay"],
    "metric supplement",
  );
  const sources = normalizeSources(value.sources);
  const implementationIndex = bytes(
    value.implementationIndex,
    MAX_MANIFEST_BYTES,
    "implementation index",
    true,
  );
  const parameters = bytes(value.parameters, MAX_PARAMETERS_BYTES, "metric parameters", true);
  const runtime = normalizeRuntime(value.runtime);
  const replay = normalizeReplay(value.replay);
  const expectedIndex = referenceMetricImplementationIndex(sources);
  if (!same(implementationIndex, expectedIndex)) {
    throw new Error("Implementation index differs from the four raw source files");
  }
  sources.forEach((source) => requiredMember(
    runtime.members,
    `metric/source/${source.path}`,
    BigInt((source.content.length - 2) / 2),
    sha256(source.content) as Hex,
  ));
  requiredMember(
    runtime.members,
    "metric/implementation.json",
    BigInt((implementationIndex.length - 2) / 2),
    sha256(implementationIndex) as Hex,
  );
  requiredMember(
    runtime.members,
    "metric/parameters.json",
    BigInt((parameters.length - 2) / 2),
    sha256(parameters) as Hex,
  );
  requiredMember(runtime.members, INTERPRETER);
  requiredMember(runtime.members, LAUNCHER);
  const runtimeHash = referenceMetricRuntimeHash(runtime);
  if (!same(replay.runtimeHash, runtimeHash)) {
    throw new Error("Replay runtime hash differs from the runtime declaration");
  }
  if (!same(replay.inputsHash, keccak256(replay.inputManifest))) {
    throw new Error("Replay input hash differs from its exact manifest bytes");
  }
  const transcript = decodeReferenceMetricTranscript(replay.transcript);
  if (
    !same(transcript.runtimeHash, replay.runtimeHash)
    || !same(transcript.contextHash, replay.contextHash)
    || !same(transcript.reportHash, replay.reportHash)
    || !same(transcript.inputsHash, replay.inputsHash)
    || transcript.executedAt !== replay.executedAt
    || transcript.exitCode !== replay.exitCode
  ) {
    throw new Error("Replay transcript envelope differs from the replay fields");
  }
  return Object.freeze({ implementationIndex, parameters, sources, runtime, replay });
}

function normalizeCapture(value: ReferenceMetricOriginalCapture): ReferenceMetricOriginalCapture {
  exactKeys(value, ["firstSha256", "secondSha256"], "original metric capture");
  return Object.freeze({
    firstSha256: hash(value.firstSha256, "first capture SHA256", true),
    secondSha256: hash(value.secondSha256, "second capture SHA256", true),
  });
}

function normalizeOriginal(value: ReferenceMetricOriginalContext): ReferenceMetricOriginalContext {
  exactKeys(
    value,
    [
      "referenceRecordHash",
      "contextHash",
      "environmentObjectHash",
      "environmentManifestHash",
      "viewportWidth",
      "viewportHeight",
      "devicePixelRatio",
      "packageFiles",
      "captures",
      "metricImplementationHash",
      "metricParametersHash",
      "reportHash",
      "threshold",
      "evaluatedAt",
    ],
    "original metric context",
  );
  if (!Array.isArray(value.captures) || value.captures.length === 0 || value.captures.length > 2) {
    throw new Error("Original metric capture count must be one or two");
  }
  if (!Array.isArray(value.packageFiles) || value.packageFiles.length > 65_536) {
    throw new Error("Invalid original package file count");
  }
  return Object.freeze({
    referenceRecordHash: hash(value.referenceRecordHash, "reference record hash"),
    contextHash: hash(value.contextHash, "original context hash"),
    environmentObjectHash: hash(value.environmentObjectHash, "original environment object hash", true),
    environmentManifestHash: hash(value.environmentManifestHash, "original environment manifest hash", true),
    viewportWidth: uint(value.viewportWidth, 16, "viewport width", true),
    viewportHeight: uint(value.viewportHeight, 16, "viewport height", true),
    devicePixelRatio: uint(value.devicePixelRatio, 8, "device pixel ratio", true),
    packageFiles: Object.freeze(value.packageFiles.map(normalizePackageFile)),
    captures: Object.freeze(value.captures.map(normalizeCapture)),
    metricImplementationHash: hash(value.metricImplementationHash, "metric implementation hash"),
    metricParametersHash: hash(value.metricParametersHash, "metric parameters hash"),
    reportHash: hash(value.reportHash, "metric report hash"),
    threshold: nonnegativeInt64(value.threshold, "metric threshold"),
    evaluatedAt: uint(value.evaluatedAt, 64, "metric evaluatedAt", true),
  });
}

function normalizeReceipt(value: ReferenceMetricReceipt): ReferenceMetricReceipt {
  exactKeys(
    value,
    [
      "supplementHash",
      "referenceRecordHash",
      "payloadHash",
      "payloadBytes",
      "runtimeHash",
      "replayHash",
      "schemaHash",
      "profileHash",
      "canonicalizationHash",
      "recorder",
      "authorizationClass",
      "grantRevision",
      "recordedAt",
    ],
    "metric supplement receipt",
  );
  return Object.freeze({
    supplementHash: hash(value.supplementHash, "supplement hash", true),
    referenceRecordHash: hash(value.referenceRecordHash, "receipt reference record hash"),
    payloadHash: hash(value.payloadHash, "receipt payload hash"),
    payloadBytes: uint(value.payloadBytes, 32, "receipt payloadBytes", true),
    runtimeHash: hash(value.runtimeHash, "receipt runtime hash"),
    replayHash: hash(value.replayHash, "receipt replay hash"),
    schemaHash: hash(value.schemaHash, "receipt schema hash"),
    profileHash: hash(value.profileHash, "receipt profile hash"),
    canonicalizationHash: hash(value.canonicalizationHash, "receipt canonicalization hash"),
    recorder: address(value.recorder, "receipt recorder"),
    authorizationClass: uint(value.authorizationClass, 8, "receipt authorizationClass", true),
    grantRevision: uint(value.grantRevision, 64, "receipt grantRevision", true),
    recordedAt: uint(value.recordedAt, 64, "receipt recordedAt"),
  });
}

export function referenceMetricImplementationIndex(
  sourcesInput: ReferenceMetricSupplement["sources"],
): Hex {
  const sources = normalizeSources(sourcesInput);
  const entries = sources.map((source) => `"${source.path}":"${sha256(source.content).slice(2)}"`);
  return hexlify(toUtf8Bytes(`{${entries.join(",")}}`)) as Hex;
}

export function referenceMetricInputManifest(originalInput: ReferenceMetricOriginalContext): Hex {
  const original = normalizeOriginal(originalInput);
  if (original.devicePixelRatio !== 1n) {
    throw new Error("Metric input manifest requires devicePixelRatio one");
  }
  const captures = original.captures.map((capture) => (
    `{"firstSha256":"${capture.firstSha256}","height":${original.viewportHeight},`
    + `"secondSha256":"${capture.secondSha256}","width":${original.viewportWidth}}`
  ));
  const manifest = `{"captures":[${captures.join(",")}],`
    + `"contextHash":"${original.contextHash}",`
    + `"environmentHash":"${original.environmentManifestHash}",`
    + `"evaluatedAt":${original.evaluatedAt},"threshold":${original.threshold}}`;
  const encoded = hexlify(toUtf8Bytes(manifest)) as Hex;
  if ((encoded.length - 2) / 2 > MAX_MANIFEST_BYTES) {
    throw new Error("Metric input manifest exceeds profile bound");
  }
  return encoded;
}

export function referenceMetricTranscriptBytes(value: ReferenceMetricTranscript): Hex {
  exactKeys(
    value,
    [
      "runtimeHash",
      "contextHash",
      "reportHash",
      "inputsHash",
      "executedAt",
      "exitCode",
      "diagnostic",
    ],
    "metric transcript",
  );
  const normalized = Object.freeze({
    runtimeHash: hash(value.runtimeHash, "transcript runtime hash", true),
    contextHash: hash(value.contextHash, "transcript context hash", true),
    reportHash: hash(value.reportHash, "transcript report hash", true),
    inputsHash: hash(value.inputsHash, "transcript inputs hash", true),
    executedAt: uint(value.executedAt, 64, "transcript executedAt"),
    exitCode: uint(value.exitCode, 32, "transcript exitCode"),
    diagnostic: bytes(value.diagnostic, MAX_TRANSCRIPT_BYTES, "transcript diagnostic", true),
  });
  const encoded = coder.encode(
    ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint32", "bytes"],
    [
      id("6529STREAM_METRIC_TRANSCRIPT_V1"),
      normalized.runtimeHash,
      normalized.contextHash,
      normalized.reportHash,
      normalized.inputsHash,
      normalized.executedAt,
      normalized.exitCode,
      normalized.diagnostic,
    ],
  ) as Hex;
  if ((encoded.length - 2) / 2 > MAX_TRANSCRIPT_BYTES) {
    throw new Error("Wrapped metric transcript exceeds profile bound");
  }
  return encoded;
}

export function decodeReferenceMetricTranscript(encodedInput: Hex): ReferenceMetricTranscript {
  const encoded = bytes(encodedInput, MAX_TRANSCRIPT_BYTES, "metric transcript", true);
  const decoded = coder.decode(
    ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint32", "bytes"],
    encoded,
  );
  if (!same(decoded[0], id("6529STREAM_METRIC_TRANSCRIPT_V1"))) {
    throw new Error("Metric transcript domain differs");
  }
  const transcript = Object.freeze({
    runtimeHash: hash(decoded[1], "transcript runtime hash", true),
    contextHash: hash(decoded[2], "transcript context hash", true),
    reportHash: hash(decoded[3], "transcript report hash", true),
    inputsHash: hash(decoded[4], "transcript inputs hash", true),
    executedAt: uint(BigInt(decoded[5]), 64, "transcript executedAt"),
    exitCode: uint(BigInt(decoded[6]), 32, "transcript exitCode"),
    diagnostic: bytes(decoded[7], MAX_TRANSCRIPT_BYTES, "transcript diagnostic", true),
  });
  if (!same(referenceMetricTranscriptBytes(transcript), encoded)) {
    throw new Error("Metric transcript is not canonical ABI encoding");
  }
  return transcript;
}

export function referenceMetricRuntimeHash(runtimeInput: ReferenceMetricRuntime): Hex {
  const runtime = normalizeRuntime(runtimeInput);
  return keccak256(coder.encode(
    ["bytes32", runtimeTuple],
    [id("6529STREAM_METRIC_RUNTIME_V1"), runtime],
  )) as Hex;
}

export function referenceMetricReplayHash(replayInput: ReferenceMetricReplay): Hex {
  const replay = normalizeReplay(replayInput);
  return keccak256(coder.encode(
    ["bytes32", replayTuple],
    [id("6529STREAM_METRIC_REPLAY_V1"), replay],
  )) as Hex;
}

export function referenceMetricPayloadHash(supplementInput: ReferenceMetricSupplement): Hex {
  return keccak256(encodeReferenceMetricSupplement(supplementInput)) as Hex;
}

export function encodeReferenceMetricSupplement(input: ReferenceMetricSupplement): Hex {
  const supplement = normalizeSupplement(input);
  const canonical = coder.encode([supplementTuple], [supplement]) as Hex;
  if ((canonical.length - 2) / 2 > REFERENCE_METRIC_MAX_CANONICAL_BYTES) {
    throw new Error("Metric supplement exceeds canonical payload bound");
  }
  return canonical;
}

export function decodeReferenceMetricSupplement(canonicalInput: Hex): ReferenceMetricSupplement {
  const canonical = bytes(
    canonicalInput,
    REFERENCE_METRIC_MAX_CANONICAL_BYTES,
    "canonical metric supplement",
    true,
  );
  const raw = coder.decode([supplementTuple], canonical)[0];
  const mapped = {
    implementationIndex: raw.implementationIndex,
    parameters: raw.parameters,
    sources: Array.from(raw.sources, (source: Record<string, unknown>) => ({
      path: source.path,
      content: source.content,
    })),
    runtime: {
      environmentObjectHash: raw.runtime.environmentObjectHash,
      environmentManifestHash: raw.runtime.environmentManifestHash,
      entrypoint: raw.runtime.entrypoint,
      interpreter: raw.runtime.interpreter,
      launcher: raw.runtime.launcher,
      sourceRoot: raw.runtime.sourceRoot,
      argv: Array.from(raw.runtime.argv),
      members: Array.from(raw.runtime.members, (member: Record<string, unknown>) => ({
        path: member.path,
        byteSize: BigInt(member.byteSize as bigint),
        sha256Digest: member.sha256Digest,
      })),
    },
    replay: {
      runtimeHash: raw.replay.runtimeHash,
      contextHash: raw.replay.contextHash,
      reportHash: raw.replay.reportHash,
      inputsHash: raw.replay.inputsHash,
      inputManifest: raw.replay.inputManifest,
      transcript: raw.replay.transcript,
      executedAt: BigInt(raw.replay.executedAt),
      exitCode: BigInt(raw.replay.exitCode),
    },
  } as unknown as ReferenceMetricSupplement;
  const supplement = normalizeSupplement(mapped);
  if (!same(coder.encode([supplementTuple], [supplement]), canonical)) {
    throw new Error("Metric supplement is not canonical ABI encoding");
  }
  return supplement;
}

export function validateReferenceMetricSupplement(
  originalInput: ReferenceMetricOriginalContext,
  supplementInput: ReferenceMetricSupplement,
  maximumExecutedAt: bigint,
): ReferenceMetricCanonicalSupplement {
  const original = normalizeOriginal(originalInput);
  const supplement = normalizeSupplement(supplementInput);
  const maximum = uint(maximumExecutedAt, 64, "maximum replay timestamp");
  const metricMembers = original.packageFiles.filter((member) => isMetricPath(member.path));
  if (
    metricMembers.length !== supplement.runtime.members.length
    || metricMembers.some((member, index) => {
      const runtimeMember = supplement.runtime.members[index]!;
      return member.path !== runtimeMember.path
        || member.byteSize !== runtimeMember.byteSize
        || !same(member.sha256Digest, runtimeMember.sha256Digest);
    })
  ) {
    throw new Error("Metric runtime is not the complete original metric/ package prefix");
  }
  const implementationIndex = referenceMetricImplementationIndex(supplement.sources);
  const inputManifest = referenceMetricInputManifest(original);
  const runtimeHash = referenceMetricRuntimeHash(supplement.runtime);
  const replayHash = referenceMetricReplayHash(supplement.replay);
  if (
    !same(supplement.runtime.environmentObjectHash, original.environmentObjectHash)
    || !same(supplement.runtime.environmentManifestHash, original.environmentManifestHash)
    || !same(keccak256(implementationIndex), original.metricImplementationHash)
    || !same(keccak256(supplement.parameters), original.metricParametersHash)
    || !same(supplement.replay.runtimeHash, runtimeHash)
    || !same(supplement.replay.contextHash, original.contextHash)
    || !same(supplement.replay.reportHash, original.reportHash)
    || !same(supplement.replay.inputsHash, keccak256(inputManifest))
    || !same(supplement.replay.inputManifest, inputManifest)
    || supplement.replay.exitCode !== 0n
    || supplement.replay.executedAt < original.evaluatedAt
    || supplement.replay.executedAt > maximum
  ) {
    throw new Error("Metric supplement differs from the original reference or replay profile");
  }
  const canonical = encodeReferenceMetricSupplement(supplement);
  return Object.freeze({
    original,
    supplement,
    canonical,
    payloadHash: keccak256(canonical) as Hex,
    implementationIndex,
    inputManifest,
    runtimeHash,
    replayHash,
  });
}

export function referenceMetricSupplementChunks(
  canonicalInput: Hex,
): readonly ReferenceMetricChunk[] {
  const canonical = bytes(
    canonicalInput,
    REFERENCE_METRIC_MAX_CANONICAL_BYTES,
    "canonical metric supplement",
    true,
  );
  const byteLength = (canonical.length - 2) / 2;
  const chunks: ReferenceMetricChunk[] = [];
  for (let offset = 0; offset < byteLength; offset += REFERENCE_METRIC_MAX_CHUNK_BYTES) {
    const end = Math.min(byteLength, offset + REFERENCE_METRIC_MAX_CHUNK_BYTES);
    const content = `0x${canonical.slice(2 + offset * 2, 2 + end * 2)}` as Hex;
    chunks.push(Object.freeze({
      index: chunks.length,
      offset,
      bytes: content,
      hash: keccak256(content) as Hex,
    }));
  }
  return Object.freeze(chunks);
}

export function referenceMetricSupplementHash(
  coordinatesInput: ReferenceMetricReceiptCoordinates,
  receiptInput: ReferenceMetricReceipt,
): Hex {
  exactKeys(
    coordinatesInput,
    ["chainId", "producer", "core", "metadata", "referenceRecordHash"],
    "metric receipt coordinates",
  );
  const coordinates = Object.freeze({
    chainId: uint(coordinatesInput.chainId, 256, "receipt chainId", true),
    producer: address(coordinatesInput.producer, "metric producer"),
    core: address(coordinatesInput.core, "metric Core"),
    metadata: address(coordinatesInput.metadata, "metric Metadata"),
    referenceRecordHash: hash(coordinatesInput.referenceRecordHash, "coordinate reference record hash"),
  });
  const receipt = normalizeReceipt(receiptInput);
  if (!same(receipt.referenceRecordHash, coordinates.referenceRecordHash)) {
    throw new Error("Receipt reference record differs from its coordinates");
  }
  const zeroed = Object.freeze({ ...receipt, supplementHash: ZERO_HASH as Hex });
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "address", receiptTuple],
    [
      id("6529STREAM_METRIC_SUPPLEMENT_V1"),
      coordinates.chainId,
      coordinates.producer,
      coordinates.core,
      coordinates.metadata,
      zeroed,
    ],
  )) as Hex;
}

export function validateReferenceMetricReceipt(
  coordinates: ReferenceMetricReceiptCoordinates,
  canonicalArtifact: ReferenceMetricCanonicalSupplement,
  receiptInput: ReferenceMetricReceipt,
  expectedAuthorityInput: ReferenceMetricAuthority,
): ReferenceMetricReceipt {
  exactKeys(
    canonicalArtifact,
    [
      "original",
      "supplement",
      "canonical",
      "payloadHash",
      "implementationIndex",
      "inputManifest",
      "runtimeHash",
      "replayHash",
    ],
    "canonical metric artifact",
  );
  exactKeys(
    expectedAuthorityInput,
    ["recorder", "authorizationClass", "grantRevision"],
    "metric supplement authority",
  );
  const expectedAuthority = Object.freeze({
    recorder: address(expectedAuthorityInput.recorder, "expected metric recorder"),
    authorizationClass: uint(
      expectedAuthorityInput.authorizationClass,
      8,
      "expected authorizationClass",
      true,
    ),
    grantRevision: uint(expectedAuthorityInput.grantRevision, 64, "expected grantRevision", true),
  });
  if (expectedAuthority.authorizationClass !== 3n && expectedAuthority.authorizationClass !== 8n) {
    throw new Error("Metric supplement requires actual class 3 or class 8 authority");
  }
  const receipt = normalizeReceipt(receiptInput);
  const canonicalBytes = bytes(
    canonicalArtifact.canonical,
    REFERENCE_METRIC_MAX_CANONICAL_BYTES,
    "canonical metric artifact",
    true,
  );
  const decoded = decodeReferenceMetricSupplement(canonicalBytes);
  const rebuilt = validateReferenceMetricSupplement(
    canonicalArtifact.original,
    decoded,
    receipt.recordedAt,
  );
  if (
    !same(rebuilt.canonical, canonicalBytes)
    || !same(encodeReferenceMetricSupplement(canonicalArtifact.supplement), canonicalBytes)
    || !same(canonicalArtifact.payloadHash, rebuilt.payloadHash)
    || !same(canonicalArtifact.implementationIndex, rebuilt.implementationIndex)
    || !same(canonicalArtifact.inputManifest, rebuilt.inputManifest)
    || !same(canonicalArtifact.runtimeHash, rebuilt.runtimeHash)
    || !same(canonicalArtifact.replayHash, rebuilt.replayHash)
    || !same(receipt.referenceRecordHash, rebuilt.original.referenceRecordHash)
    || !same(receipt.payloadHash, rebuilt.payloadHash)
    || receipt.payloadBytes !== BigInt((canonicalBytes.length - 2) / 2)
    || !same(receipt.runtimeHash, rebuilt.runtimeHash)
    || !same(receipt.replayHash, rebuilt.replayHash)
    || !same(receipt.schemaHash, REFERENCE_METRIC_SCHEMA_HASH)
    || !same(receipt.profileHash, REFERENCE_METRIC_PROFILE_HASH)
    || !same(receipt.canonicalizationHash, REFERENCE_METRIC_CANONICALIZATION_HASH)
    || !same(receipt.recorder, expectedAuthority.recorder)
    || receipt.authorizationClass !== expectedAuthority.authorizationClass
    || receipt.grantRevision !== expectedAuthority.grantRevision
  ) {
    throw new Error("Metric supplement receipt differs from canonical bytes or actual authority");
  }
  const expectedHash = referenceMetricSupplementHash(coordinates, receipt);
  if (!same(receipt.supplementHash, expectedHash)) {
    throw new Error("Metric supplement receipt hash differs from its domain preimage");
  }
  return receipt;
}
