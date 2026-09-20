import { AbiCoder, ZeroAddress, ZeroHash, getAddress, hexlify, id, isHexString, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { normalizeReferenceInventoryRows, prepareReferenceInventory, referenceInventoryCanonicalBytes,
  type ReferenceInventoryPackageFile, type ReferenceInventorySnapshot } from "./current-reference-inventory.js";

/** Original complete Environment ABI tuple. Coverage and manifest declarations remain identity inputs. */
export interface ReferenceEnvironment {
  readonly objectHash: Hex;
  readonly coverageHash: Hex;
  readonly manifestHash: Hex;
  readonly manifestBytes: bigint;
  readonly engineName: string;
  readonly engineVersion: string;
  readonly engineExecutableSha256: Hex;
  readonly toolchainName: string;
  readonly toolchainVersion: string;
  readonly toolchainSha256: Hex;
  readonly engineExecutablePath: string;
  readonly toolchainPath: string;
  readonly packageFiles: readonly ReferenceInventoryPackageFile[];
  readonly platformPrerequisites: readonly ReferenceInventoryPackageFile[];
  readonly operatingSystem: string;
  readonly operatingSystemVersion: string;
  readonly architecture: string;
  readonly viewportWidth: bigint;
  readonly viewportHeight: bigint;
  readonly devicePixelRatio: bigint;
  readonly colorSpace: string;
  readonly softwareRasterization: boolean;
  readonly captureProfile: Hex;
  readonly licenseNote: string;
}

/** Deterministic bytes and supplied declarations only; no RPC, authority or currentness is authenticated. */
export interface ReferenceEnvironmentSnapshot {
  readonly chainId: bigint;
  readonly publicationHost: Address;
  readonly environment: ReferenceEnvironment;
  readonly canonical: Hex;
  readonly environmentId: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly packageInventory: ReferenceInventorySnapshot;
  readonly platformInventory: ReferenceInventorySnapshot;
}

export const REFERENCE_ENVIRONMENT_MAX_BYTES = 524288;
export const REFERENCE_ENVIRONMENT_PREPARATION_DOMAIN = id("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1") as Hex;
export const REFERENCE_ENVIRONMENT_CAPTURE_PROFILE = id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1") as Hex;
export const REFERENCE_ENVIRONMENT_ABI_TUPLE = "tuple(bytes32 objectHash,bytes32 coverageHash,bytes32 manifestHash,uint32 manifestBytes,string engineName,string engineVersion,bytes32 engineExecutableSha256,string toolchainName,string toolchainVersion,bytes32 toolchainSha256,string engineExecutablePath,string toolchainPath,tuple(string path,uint64 byteSize,bytes32 sha256Digest)[] packageFiles,tuple(string path,uint64 byteSize,bytes32 sha256Digest)[] platformPrerequisites,string operatingSystem,string operatingSystemVersion,string architecture,uint16 viewportWidth,uint16 viewportHeight,uint8 devicePixelRatio,string colorSpace,bool softwareRasterization,bytes32 captureProfile,string licenseNote)";
const coder = AbiCoder.defaultAbiCoder();
const environmentKeys = ["objectHash", "coverageHash", "manifestHash", "manifestBytes", "engineName", "engineVersion",
  "engineExecutableSha256", "toolchainName", "toolchainVersion", "toolchainSha256", "engineExecutablePath", "toolchainPath",
  "packageFiles", "platformPrerequisites", "operatingSystem", "operatingSystemVersion", "architecture", "viewportWidth",
  "viewportHeight", "devicePixelRatio", "colorSpace", "softwareRasterization", "captureProfile", "licenseNote"];

function exact(value: unknown, keys: readonly string[], label: string): void {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) throw Error(`${label} contains missing or unknown properties`);
}
function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= 1n << BigInt(bits)) throw Error(`${label} must be ${positive ? "positive " : ""}uint${bits} bigint`);
  return value;
}
function hash(value: unknown, label: string, nonzero = true): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (nonzero && value.toLowerCase() === ZeroHash)) throw Error(`${label} must be ${nonzero ? "nonzero " : ""}bytes32`);
  return value.toLowerCase() as Hex;
}
function host(value: unknown): Address {
  if (typeof value !== "string") throw Error("Publication host must be an address");
  const result = getAddress(value) as Address;
  if (result === ZeroAddress) throw Error("Publication host must be nonzero");
  return result;
}
function string(value: unknown, maximum: number, label: string): string {
  if (typeof value !== "string" || value.length === 0) throw Error(`${label} must be a nonempty string`);
  // Scalar validation also rejects isolated low surrogates that toUtf8Bytes alone accepts.
  for (const character of value) {
    const point = character.codePointAt(0)!;
    if (point >= 0xd800 && point <= 0xdfff) throw Error(`${label} must contain valid UTF-8 scalar values`);
  }
  if (toUtf8Bytes(value).length > maximum) throw Error(`${label} exceeds ${maximum} UTF-8 bytes`);
  return value;
}
/** Original Renderer escaping: UTF-8 remains literal, five short control escapes, lowercase remaining controls. */
function quote(value: string): string {
  let out = '"';
  for (const character of value) {
    const code = character.codePointAt(0)!;
    switch (code) {
      case 0x22: out += '\\"'; break;
      case 0x5c: out += "\\\\"; break;
      case 0x08: out += "\\b"; break;
      case 0x0c: out += "\\f"; break;
      case 0x0a: out += "\\n"; break;
      case 0x0d: out += "\\r"; break;
      case 0x09: out += "\\t"; break;
      default: out += code < 0x20 ? `\\u00${code.toString(16).padStart(2, "0")}` : character;
    }
  }
  return `${out}"`;
}
function normalizeFields(input: ReferenceEnvironment): ReferenceEnvironment {
  exact(input, environmentKeys, "Environment");
  const e: ReferenceEnvironment = {
    objectHash: hash(input.objectHash, "Runtime object hash"), coverageHash: hash(input.coverageHash, "Coverage hash"),
    manifestHash: hash(input.manifestHash, "Manifest hash", false), manifestBytes: uint(input.manifestBytes, 32, "Manifest bytes"),
    engineName: string(input.engineName, 256, "Engine name"), engineVersion: string(input.engineVersion, 256, "Engine version"),
    engineExecutableSha256: hash(input.engineExecutableSha256, "Engine executable SHA-256"),
    toolchainName: string(input.toolchainName, 256, "Toolchain name"), toolchainVersion: string(input.toolchainVersion, 256, "Toolchain version"),
    toolchainSha256: hash(input.toolchainSha256, "Toolchain SHA-256"),
    engineExecutablePath: string(input.engineExecutablePath, 1024, "Engine executable path"), toolchainPath: string(input.toolchainPath, 1024, "Toolchain path"),
    packageFiles: normalizeReferenceInventoryRows(input.packageFiles, true),
    platformPrerequisites: normalizeReferenceInventoryRows(input.platformPrerequisites, false),
    operatingSystem: string(input.operatingSystem, 64, "Operating system"),
    operatingSystemVersion: string(input.operatingSystemVersion, 128, "Operating system version"),
    architecture: string(input.architecture, 64, "Architecture"),
    viewportWidth: uint(input.viewportWidth, 16, "Viewport width", true), viewportHeight: uint(input.viewportHeight, 16, "Viewport height", true),
    devicePixelRatio: uint(input.devicePixelRatio, 8, "Device pixel ratio"), colorSpace: string(input.colorSpace, 64, "Color space"),
    softwareRasterization: input.softwareRasterization, captureProfile: hash(input.captureProfile, "Capture profile"),
    licenseNote: string(input.licenseNote, 16384, "License note"),
  };
  if (e.packageFiles.length === 0 || e.platformPrerequisites.length === 0) throw Error("Environment requires both complete nonempty inventories");
  if (e.viewportWidth > 4096n || e.viewportHeight > 4096n || e.devicePixelRatio !== 1n || e.softwareRasterization !== true
    || e.colorSpace !== "srgb" || e.operatingSystem !== "Windows" || e.architecture !== "AMD64"
    || e.captureProfile !== REFERENCE_ENVIRONMENT_CAPTURE_PROFILE) throw Error("Environment differs from the original Windows still-capture profile");
  for (const [path, digest] of [[e.engineExecutablePath, e.engineExecutableSha256], [e.toolchainPath, e.toolchainSha256]]) {
    const member = e.packageFiles.find(row => row.path === path);
    if (!member || member.byteSize === 0n || member.sha256Digest !== digest) throw Error("Engine and toolchain must match nonempty original package members");
  }
  return Object.freeze(e);
}
function serialize(e: ReferenceEnvironment): Hex {
  const packageJSON = toUtf8String(referenceInventoryCanonicalBytes(e.packageFiles, true));
  const platformJSON = toUtf8String(referenceInventoryCanonicalBytes(e.platformPrerequisites, false));
  const raw = [
    `{"architecture":${quote(e.architecture)},"captureProfile":"${e.captureProfile}","colorSpace":${quote(e.colorSpace)}`,
    `,"devicePixelRatio":"${e.devicePixelRatio}","engineExecutablePath":${quote(e.engineExecutablePath)},"engineExecutableSha256":"${e.engineExecutableSha256}"`,
    `,"engineName":${quote(e.engineName)},"engineVersion":${quote(e.engineVersion)},"licenseBasis":"undetermined","licenseNote":${quote(e.licenseNote)}`,
    `,"operatingSystem":${quote(e.operatingSystem)},"operatingSystemVersion":${quote(e.operatingSystemVersion)},"packageFiles":${packageJSON}`,
    `,"platformPrerequisites":${platformJSON},"runtimeObjectHash":"${e.objectHash}","softwareRasterization":true`,
    `,"toolchainName":${quote(e.toolchainName)},"toolchainPath":${quote(e.toolchainPath)},"toolchainSha256":"${e.toolchainSha256}"`,
    `,"toolchainVersion":${quote(e.toolchainVersion)},"version":1,"viewportHeight":"${e.viewportHeight}","viewportWidth":"${e.viewportWidth}"}`,
  ].join("");
  const bytes = toUtf8Bytes(raw);
  if (bytes.length > REFERENCE_ENVIRONMENT_MAX_BYTES) throw Error("Canonical environment exceeds the 524288-byte retention limit");
  return hexlify(bytes) as Hex;
}
/** Validate the complete original input and canonical bound without replacing its declared manifest fields. */
export function normalizeReferenceEnvironment(input: ReferenceEnvironment): ReferenceEnvironment {
  const environment = normalizeFields(input); serialize(environment); return environment;
}
/** Compute original JSON before its hash is known. Declared manifest fields are width-checked but are not JSON fields. */
export function referenceEnvironmentCanonicalBytes(input: ReferenceEnvironment): Hex {
  return serialize(normalizeFields(input));
}
function identity(chainId: bigint, publicationHost: Address, environment: ReferenceEnvironment): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", REFERENCE_ENVIRONMENT_ABI_TUPLE],
    [REFERENCE_ENVIRONMENT_PREPARATION_DOMAIN, chainId, publicationHost, environment])) as Hex;
}
/** Complete typed identity, including coverageHash, manifestHash/bytes and both original arrays. */
export function referenceEnvironmentId(chainId: bigint, publicationHost: Address, input: ReferenceEnvironment): Hex {
  return identity(uint(chainId, 256, "Chain ID", true), host(publicationHost), normalizeReferenceEnvironment(input));
}
/** Produces no upload, cache write, publication, source authentication or finality statement. */
export function prepareReferenceEnvironment(chainId: bigint, publicationHost: Address, input: ReferenceEnvironment): ReferenceEnvironmentSnapshot {
  const chain = uint(chainId, 256, "Chain ID", true), target = host(publicationHost), environment = normalizeFields(input);
  const canonical = serialize(environment), contentHash = keccak256(canonical) as Hex, byteLength = BigInt((canonical.length - 2) / 2);
  if (environment.manifestHash !== contentHash || environment.manifestBytes !== byteLength) throw Error("Declared environment manifest hash or byte length differs from original canonical bytes");
  return Object.freeze({ chainId: chain, publicationHost: target, environment, canonical,
    environmentId: identity(chain, target, environment), contentHash, byteLength,
    packageInventory: prepareReferenceInventory(chain, target, true, environment.packageFiles),
    platformInventory: prepareReferenceInventory(chain, target, false, environment.platformPrerequisites) });
}
function canonicalObject(value: unknown): string {
  return JSON.stringify(value, (_, item: unknown) => typeof item === "bigint" ? { uint: item.toString() }
    : item !== null && typeof item === "object" && !Array.isArray(item) ? Object.fromEntries(Object.entries(item).sort(([a], [b]) => a.localeCompare(b))) : item);
}
/** Rebuild every byte, label and inventory from the full copied input before an asynchronous workflow uses it. */
export function normalizeReferenceEnvironmentSnapshot(input: ReferenceEnvironmentSnapshot): ReferenceEnvironmentSnapshot {
  exact(input, ["chainId", "publicationHost", "environment", "canonical", "environmentId", "contentHash", "byteLength", "packageInventory", "platformInventory"], "Environment snapshot");
  const rebuilt = prepareReferenceEnvironment(input.chainId, input.publicationHost, input.environment);
  if (canonicalObject(input) !== canonicalObject(rebuilt)) throw Error("Environment snapshot differs from exact typed input reconstruction");
  return rebuilt;
}
