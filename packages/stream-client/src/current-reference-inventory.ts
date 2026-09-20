import { AbiCoder, ZeroAddress, ZeroHash, getAddress, hexlify, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";

/** Original PackageFile ABI tuple. A zero-byte file is valid; its SHA-256 digest is nonzero. */
export interface ReferenceInventoryPackageFile {
  readonly path: string;
  readonly byteSize: bigint;
  readonly sha256Digest: Hex;
}
export interface ReferenceInventorySnapshot {
  readonly chainId: bigint;
  readonly publicationHost: Address;
  readonly relative: boolean;
  readonly rows: readonly ReferenceInventoryPackageFile[];
  readonly canonical: Hex;
  readonly contentHash: Hex;
  readonly inventoryId: Hex;
  readonly byteLength: bigint;
}
export interface ReferenceInventoryPart {
  readonly index: number;
  readonly rowOffset: number;
  readonly rows: readonly ReferenceInventoryPackageFile[];
  readonly canonical: Hex;
  readonly contentHash: Hex;
  readonly partId: Hex;
  readonly byteLength: bigint;
}

/** Actual retained-byte limit, including both array brackets. */
export const REFERENCE_INVENTORY_MAX_BYTES = 524288;
export const REFERENCE_INVENTORY_PART_ROWS = 64;
const coder = AbiCoder.defaultAbiCoder();
const rowsTuple = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)[]";
const inventoryDomain = id("6529STREAM_REFERENCE_FILE_INVENTORY_V1");
const partDomain = id("6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1");

function uint(value: unknown, bits: number, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= 1n << BigInt(bits)) throw Error(`Expected ${positive ? "positive " : ""}uint${bits} bigint`);
  return value;
}
function host(value: unknown): Address {
  if (typeof value !== "string") throw Error("Publication host must be an address");
  const address = getAddress(value) as Address;
  if (address === ZeroAddress) throw Error("Publication host must be nonzero");
  return address;
}
function exactRow(value: unknown): asserts value is ReferenceInventoryPackageFile {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== "byteSize,path,sha256Digest") throw Error("Inventory row contains missing or unknown properties");
}
function utf8Path(value: unknown, relative: boolean): Uint8Array {
  if (typeof value !== "string" || value.length === 0) throw Error("Inventory path must be a nonempty string");
  // for...of combines valid surrogate pairs; any remaining surrogate is not a Unicode scalar.
  // toUtf8Bytes alone accepts isolated low surrogates, unlike the contract's UTF-8 validator.
  for (const character of value) {
    const point = character.codePointAt(0)!;
    if (point >= 0xd800 && point <= 0xdfff) throw Error("Inventory path must contain valid UTF-8 scalar values");
  }
  let bytes: Uint8Array;
  try { bytes = toUtf8Bytes(value); } catch { throw Error("Inventory path must contain valid UTF-8 scalar values"); }
  if (bytes.length > (relative ? 1024 : 2048)) throw Error(`Inventory path exceeds ${relative ? 1024 : 2048} UTF-8 bytes`);
  if (relative) {
    // Literal _relative rules. Do not add case folding, reserved-name checks or normalization.
    for (const byte of bytes) {
      if (byte < 0x20 || byte >= 0x7f || [0x5c, 0x3a, 0x3c, 0x3e, 0x22, 0x7c, 0x3f, 0x2a].includes(byte)) {
        throw Error("Relative inventory path contains a forbidden byte");
      }
    }
    if (value.split("/").some(segment => segment.length === 0 || segment.endsWith(".") || segment.endsWith(" "))) {
      throw Error("Relative inventory path contains an empty segment or trailing dot/space");
    }
  }
  return bytes;
}
function less(left: Uint8Array, right: Uint8Array): boolean {
  for (let index = 0; index < Math.min(left.length, right.length); index++) {
    if (left[index] !== right[index]) return left[index]! < right[index]!;
  }
  return left.length < right.length;
}
function quote(value: string): string {
  let out = '"';
  // StreamMetadataRenderer.escapeJsonString: short escapes for five controls,
  // quote/backslash escaping, lowercase \u00xx for remaining controls; UTF-8 stays literal.
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
function canonicalInventory(input: readonly ReferenceInventoryPackageFile[], relative: boolean): {
  readonly rows: readonly ReferenceInventoryPackageFile[]; readonly canonical: Hex; readonly byteLength: bigint;
} {
  if (typeof relative !== "boolean") throw Error("Inventory relative mode must be boolean");
  if (!Array.isArray(input)) throw Error("Inventory rows must be an array");
  const rows: ReferenceInventoryPackageFile[] = [], encoded: string[] = [];
  let previous: Uint8Array | undefined, length = 2;
  for (const source of input) {
    exactRow(source);
    const path = source.path, pathBytes = utf8Path(path, relative);
    if (previous && !less(previous, pathBytes)) throw Error("Inventory paths must be strictly increasing in UTF-8 byte order");
    const byteSize = uint(source.byteSize, 64);
    if (typeof source.sha256Digest !== "string" || !isHexString(source.sha256Digest, 32)
      || source.sha256Digest.toLowerCase() === ZeroHash) throw Error("Inventory SHA-256 digest must be a nonzero bytes32");
    const row = Object.freeze({ path, byteSize, sha256Digest: source.sha256Digest.toLowerCase() as Hex });
    const json = `{"byteSize":"${row.byteSize}","path":${relative ? `"${row.path}"` : quote(row.path)},"sha256Digest":"${row.sha256Digest}"}`;
    length += toUtf8Bytes(json).length + (rows.length === 0 ? 0 : 1);
    // The old serializer permits a MAX+1 final array via its prefix check. Retention does not.
    if (length > REFERENCE_INVENTORY_MAX_BYTES) throw Error("Canonical inventory exceeds the 524288-byte retention limit");
    rows.push(row); encoded.push(json); previous = pathBytes;
  }
  return Object.freeze({ rows: Object.freeze(rows), canonical: hexlify(toUtf8Bytes(`[${encoded.join(",")}]`)) as Hex,
    byteLength: BigInt(length) });
}
/** Ordered immutable snapshot with original path/width rules and retained-byte bound. Never sorts. */
export function normalizeReferenceInventoryRows(rows: readonly ReferenceInventoryPackageFile[], relative: boolean): readonly ReferenceInventoryPackageFile[] {
  return canonicalInventory(rows, relative).rows;
}
/** Original complete JSON array, including valid empty monolithic inventories. */
export function referenceInventoryCanonicalBytes(rows: readonly ReferenceInventoryPackageFile[], relative: boolean): Hex {
  return canonicalInventory(rows, relative).canonical;
}
export function referenceInventoryContentHash(rows: readonly ReferenceInventoryPackageFile[], relative: boolean): Hex {
  return keccak256(referenceInventoryCanonicalBytes(rows, relative)) as Hex;
}
function identity(chainId: bigint, publicationHost: Address, relative: boolean, rows: readonly ReferenceInventoryPackageFile[], domain = inventoryDomain): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bool", rowsTuple],
    [domain, chainId, publicationHost, relative, rows])) as Hex;
}
/** Original ABI-keyed inventory identity in the actual reference publication host's namespace. */
export function referenceInventoryId(chainId: bigint, publicationHost: Address, relative: boolean, rows: readonly ReferenceInventoryPackageFile[]): Hex {
  const chain = uint(chainId, 256, true), target = host(publicationHost), normalized = normalizeReferenceInventoryRows(rows, relative);
  return identity(chain, target, relative, normalized);
}
/** No upload, RPC read, writer authority or reference-head publication occurs here. */
export function prepareReferenceInventory(chainId: bigint, publicationHost: Address, relative: boolean, rows: readonly ReferenceInventoryPackageFile[]): ReferenceInventorySnapshot {
  const chain = uint(chainId, 256, true), target = host(publicationHost), saved = canonicalInventory(rows, relative);
  return Object.freeze({ chainId: chain, publicationHost: target, relative, rows: saved.rows, canonical: saved.canonical,
    contentHash: keccak256(saved.canonical) as Hex, inventoryId: identity(chain, target, relative, saved.rows), byteLength: saved.byteLength });
}

/** Disjoint part domain, in the same publication host namespace; exactly 1..64 rows. */
export function referenceInventoryPartId(chainId: bigint, publicationHost: Address, relative: boolean, rows: readonly ReferenceInventoryPackageFile[]): Hex {
  if (!Array.isArray(rows) || rows.length === 0 || rows.length > REFERENCE_INVENTORY_PART_ROWS) throw Error("Inventory part must contain 1..64 rows");
  const chain = uint(chainId, 256, true), target = host(publicationHost), normalized = normalizeReferenceInventoryRows(rows, relative);
  return identity(chain, target, relative, normalized, partDomain);
}
/** Fixed consecutive 64-row parts. Full ordering and every snapshot label are reconstructed first. */
export function referenceInventoryParts(input: ReferenceInventorySnapshot): readonly ReferenceInventoryPart[] {
  if (input === null || typeof input !== "object" || Array.isArray(input)
    || Object.keys(input).sort().join(",") !== "byteLength,canonical,chainId,contentHash,inventoryId,publicationHost,relative,rows") {
    throw Error("Inventory snapshot contains missing or unknown properties");
  }
  const saved = prepareReferenceInventory(input.chainId, input.publicationHost, input.relative, input.rows);
  for (const name of ["canonical", "contentHash", "inventoryId"] as const) {
    if (typeof input[name] !== "string" || input[name].toLowerCase() !== saved[name].toLowerCase()) throw Error("Inventory snapshot labels differ from exact rows and coordinates");
  }
  if (input.byteLength !== saved.byteLength) throw Error("Inventory snapshot byte length differs from exact rows");
  const parts: ReferenceInventoryPart[] = [];
  for (let offset = 0; offset < saved.rows.length; offset += REFERENCE_INVENTORY_PART_ROWS) {
    const part = canonicalInventory(saved.rows.slice(offset, offset + REFERENCE_INVENTORY_PART_ROWS), saved.relative);
    parts.push(Object.freeze({ index: parts.length, rowOffset: offset, rows: part.rows, canonical: part.canonical,
      contentHash: keccak256(part.canonical) as Hex,
      partId: identity(saved.chainId, saved.publicationHost, saved.relative, part.rows, partDomain), byteLength: part.byteLength }));
  }
  return Object.freeze(parts);
}
