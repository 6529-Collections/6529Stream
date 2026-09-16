import { AbiCoder, Interface, ZeroAddress, concat, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";

/** Original carrier configuration; carrier-specific mode and window checks remain separate. */
export interface CuratedSaleConfiguration {
  readonly collectionId: bigint; readonly phaseId: Hex; readonly price: bigint; readonly poster: Address;
  readonly startsAt: bigint; readonly endsAt: bigint; readonly mintPolicyHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex; readonly primaryPolicyMode: bigint; readonly contentManifestRoot: Hex;
}
export interface CuratedContentSelection {
  readonly contentId: Hex; readonly tokenDataHash: Hex; readonly proof: readonly Hex[];
}
export interface CuratedSelection {
  readonly content: CuratedContentSelection; readonly tokenData: Hex; readonly mintCommitment: Hex;
  readonly recipient: Address; readonly purchaseNonce: bigint;
}
export interface CuratedDelegationWitness { readonly walletWide: boolean; readonly index: bigint }
export interface CuratedManifestRow { readonly contentId: Hex; readonly tokenDataHash: Hex; readonly previewURI: string }
export interface CuratedManifestCoordinates {
  readonly chainId: bigint; readonly manager: Address; readonly adapter: Address; readonly saleId: Hex;
  readonly collectionId: bigint; readonly phaseId: Hex; readonly counterId: Hex;
}
export interface CuratedPublication {
  readonly chainId: bigint; readonly manager: Address; readonly house: Address; readonly saleId: Hex;
  readonly collectionId: bigint; readonly phaseId: Hex; readonly manifestRoot: Hex;
  readonly manifestHash: Hex; readonly counterId: Hex;
}
export interface CuratedManifest {
  readonly coordinates: CuratedManifestCoordinates; readonly rows: readonly CuratedManifestRow[];
  readonly manifestBytes: Hex; readonly publication: CuratedPublication;
  readonly selections: readonly CuratedContentSelection[];
}

/** Local resource bounds. Only the 8192-byte token-data limit is a carrier rule. */
export const CURATED_CLIENT_MAX_ROWS = 4096;
export const CURATED_CLIENT_MAX_PREVIEW_BYTES = 8192;
export const CURATED_CLIENT_MAX_PROOF_NODES = 256;
export const CURATED_MAX_TOKEN_DATA_BYTES = 8192;
const coder = AbiCoder.defaultAbiCoder();
const zero = `0x${"00".repeat(32)}`;
const publicationTuple = "tuple(uint256 chainId,address manager,address house,bytes32 saleId,uint256 collectionId,bytes32 phaseId,bytes32 manifestRoot,bytes32 manifestHash,bytes32 counterId)";
function keys(value: unknown, names: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...names].sort().join(",")) throw Error(`Invalid ${label} fields`);
}
function uint(value: bigint, bits: number, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= 1n << BigInt(bits)) throw Error(`Invalid ${label} uint${bits}`);
  return value;
}
function hash(value: Hex, label: string, allowZero = false): Hex {
  if (!isHexString(value, 32) || (!allowZero && value.toLowerCase() === zero)) throw Error(`Invalid ${label} bytes32`);
  return value.toLowerCase() as Hex;
}
function address(value: Address, label: string): Address {
  const result = getAddress(value) as Address;
  if (result === ZeroAddress) throw Error(`Invalid ${label} address`);
  return result;
}
function coordinates(chainId: bigint, adapter: Address, saleId: Hex): readonly [bigint, Address, Hex] {
  return [uint(chainId, 256, "chain", true), address(adapter, "adapter"), hash(saleId, "sale ID")];
}
function pair(left: Hex, right: Hex): Hex {
  return keccak256(concat(BigInt(left) < BigInt(right) ? [left, right] : [right, left])) as Hex;
}

export function curatedSaleId(chainId: bigint, adapter: Address, kind: bigint, collectionId: bigint, phaseId: Hex, nonce: bigint): Hex {
  if (kind !== 0n && kind !== 5n) throw Error("Curated sale kind must be FIXED_PRICE 0 or PRIVATE_SALE 5");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), uint(chainId, 256, "chain", true), address(adapter, "adapter"), kind,
      uint(collectionId, 256, "collection", true), hash(phaseId, "phase"), uint(nonce, 256, "sale nonce", true)])) as Hex;
}
/** This is not the official receipt's prepared-native execution ID. */
export function curatedPurchaseId(chainId: bigint, adapter: Address, saleId: Hex, buyer: Address, nonce: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [id("6529STREAM_SALE_PURCHASE_V1"), ...coordinates(chainId, adapter, saleId), address(buyer, "buyer"), uint(nonce, 256, "purchase nonce", true)])) as Hex;
}
export function curatedContentLeaf(chainId: bigint, adapter: Address, saleId: Hex, contentId: Hex, tokenDataHash: Hex): Hex {
  return keccak256(keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_CONTENT_LEAF_V1"), ...coordinates(chainId, adapter, saleId), hash(contentId, "content ID", true), hash(tokenDataHash, "token data hash")]))) as Hex;
}
export function curatedContentContextHash(chainId: bigint, adapter: Address, saleId: Hex, contentId: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32"],
    [id("6529STREAM_CONTENT_CONTEXT_V1"), ...coordinates(chainId, adapter, saleId), hash(contentId, "content ID", true)])) as Hex;
}
export function curatedSelectionCommitment(chainId: bigint, adapter: Address, saleId: Hex, buyer: Address, leaf: Hex, salt: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "bytes32"],
    [id("6529STREAM_CONTENT_COMMIT_V1"), ...coordinates(chainId, adapter, saleId), address(buyer, "buyer"), hash(leaf, "content leaf"), hash(salt, "salt", true)])) as Hex;
}

export function validateCuratedSaleConfiguration(value: CuratedSaleConfiguration): CuratedSaleConfiguration {
  keys(value, ["collectionId", "phaseId", "price", "poster", "startsAt", "endsAt", "mintPolicyHash", "expectedPrimaryPolicyHash", "primaryPolicyMode", "contentManifestRoot"], "sale configuration");
  const startsAt = uint(value.startsAt, 64, "start"), endsAt = uint(value.endsAt, 64, "end");
  if (endsAt <= startsAt || (value.primaryPolicyMode !== 0n && value.primaryPolicyMode !== 1n)) throw Error("Invalid sale window or policy mode");
  return Object.freeze({ collectionId: uint(value.collectionId, 256, "collection", true), phaseId: hash(value.phaseId, "phase"),
    price: uint(value.price, 256, "price", true), poster: address(value.poster, "poster"), startsAt, endsAt,
    mintPolicyHash: hash(value.mintPolicyHash, "mint policy"), expectedPrimaryPolicyHash: hash(value.expectedPrimaryPolicyHash, "primary policy"),
    primaryPolicyMode: value.primaryPolicyMode, contentManifestRoot: hash(value.contentManifestRoot, "manifest root") });
}
export function normalizeCuratedContentSelection(value: CuratedContentSelection): CuratedContentSelection {
  keys(value, ["contentId", "tokenDataHash", "proof"], "content selection");
  if (!Array.isArray(value.proof) || value.proof.length > CURATED_CLIENT_MAX_PROOF_NODES) throw Error("Content proof exceeds client bound");
  return Object.freeze({ contentId: hash(value.contentId, "content ID", true), tokenDataHash: hash(value.tokenDataHash, "token data hash"),
    proof: Object.freeze(value.proof.map(node => hash(node, "proof node", true))) });
}
export function normalizeCuratedSelection(value: CuratedSelection): CuratedSelection {
  keys(value, ["content", "tokenData", "mintCommitment", "recipient", "purchaseNonce"], "selection");
  if (!isHexString(value.tokenData, true) || (value.tokenData.length - 2) / 2 > CURATED_MAX_TOKEN_DATA_BYTES) throw Error("Invalid token data or carrier byte limit");
  const content = normalizeCuratedContentSelection(value.content);
  if (keccak256(value.tokenData).toLowerCase() !== content.tokenDataHash) throw Error("Token data differs from selected hash");
  return Object.freeze({ content, tokenData: value.tokenData.toLowerCase() as Hex, mintCommitment: hash(value.mintCommitment, "mint commitment"),
    recipient: address(value.recipient, "recipient"), purchaseNonce: uint(value.purchaseNonce, 256, "purchase nonce", true) });
}
export function normalizeCuratedDelegationWitness(value: CuratedDelegationWitness): CuratedDelegationWitness {
  keys(value, ["walletWide", "index"], "delegation witness");
  if (typeof value.walletWide !== "boolean") throw Error("walletWide must be boolean");
  return Object.freeze({ walletWide: value.walletWide, index: uint(value.index, 256, "delegation index") });
}
/** Membership only; does not establish publication, availability, admission or uniqueness. */
export function verifyCuratedContentProof(chainId: bigint, adapter: Address, saleId: Hex, root: Hex, selected: CuratedContentSelection): boolean {
  const selection = normalizeCuratedContentSelection(selected);
  let leaf = curatedContentLeaf(chainId, adapter, saleId, selection.contentId, selection.tokenDataHash);
  for (const node of selection.proof) leaf = pair(leaf, node);
  return leaf === hash(root, "manifest root");
}

/** Preserve the gate's strictly increasing content-ID order; never silently sort or omit rows. */
export function buildCuratedManifest(input: CuratedManifestCoordinates & { readonly rows: readonly CuratedManifestRow[] }): CuratedManifest {
  keys(input, ["chainId", "manager", "adapter", "saleId", "collectionId", "phaseId", "counterId", "rows"], "manifest input");
  const [chainId, adapter, saleId] = coordinates(input.chainId, input.adapter, input.saleId);
  const c = Object.freeze({ chainId, adapter, saleId, manager: address(input.manager, "manager"),
    collectionId: uint(input.collectionId, 256, "collection", true), phaseId: hash(input.phaseId, "phase"), counterId: hash(input.counterId, "counter") });
  if (!Array.isArray(input.rows) || input.rows.length === 0 || input.rows.length > CURATED_CLIENT_MAX_ROWS) throw Error("Manifest row count exceeds client bound");
  const rows = input.rows.map((row: CuratedManifestRow, index: number) => {
    keys(row, ["contentId", "tokenDataHash", "previewURI"], "manifest row");
    if (typeof row.previewURI !== "string" || !row.previewURI.length || toUtf8Bytes(row.previewURI).length > CURATED_CLIENT_MAX_PREVIEW_BYTES) throw Error("Invalid preview URI or client byte bound");
    const contentId = hash(row.contentId, "content ID", true);
    if (index && BigInt(input.rows[index - 1]!.contentId) >= BigInt(contentId)) throw Error("Manifest content IDs must be strictly increasing");
    return Object.freeze({ contentId, tokenDataHash: hash(row.tokenDataHash, "token data hash"), previewURI: row.previewURI });
  });
  const leaves = rows.map(row => curatedContentLeaf(chainId, adapter, saleId, row.contentId, row.tokenDataHash));
  const levels: Hex[][] = [leaves];
  while (levels.at(-1)!.length > 1) {
    const previous = levels.at(-1)!, next: Hex[] = [];
    for (let i = 0; i < previous.length; i += 2) next.push(i + 1 < previous.length ? pair(previous[i]!, previous[i + 1]!) : previous[i]!);
    levels.push(next);
  }
  const selections = rows.map((row, index) => {
    const proof: Hex[] = [];
    let position = index;
    for (const level of levels.slice(0, -1)) {
      const sibling = position ^ 1;
      if (sibling < level.length) proof.push(level[sibling]!);
      position = Math.floor(position / 2);
    }
    return Object.freeze({ contentId: row.contentId, tokenDataHash: row.tokenDataHash, proof: Object.freeze(proof) });
  });
  const manifestBytes = coder.encode(["tuple(bytes32 contentId,bytes32 tokenDataHash,string previewURI)[]"], [rows]) as Hex;
  const publication = Object.freeze({ chainId, manager: c.manager, house: adapter, saleId, collectionId: c.collectionId,
    phaseId: c.phaseId, manifestRoot: levels.at(-1)![0]!, manifestHash: keccak256(manifestBytes) as Hex, counterId: c.counterId });
  return Object.freeze({ coordinates: c, rows: Object.freeze(rows), manifestBytes, publication, selections: Object.freeze(selections) });
}
/** Runtime hashes are explicit observations supplied by the caller, never canonical deployment claims. */
export function curatedContentGateConfigHash(manifest: CuratedManifest, managerCodeHash: Hex, adapterCodeHash: Hex): Hex {
  const rebuilt = buildCuratedManifest({ ...manifest.coordinates, rows: manifest.rows });
  if (rebuilt.manifestBytes.toLowerCase() !== manifest.manifestBytes.toLowerCase()
    || coder.encode([publicationTuple], [rebuilt.publication]).toLowerCase() !== coder.encode([publicationTuple], [manifest.publication]).toLowerCase()) throw Error("Manifest publication differs from complete rows");
  return keccak256(coder.encode(["bytes32", publicationTuple, "bytes32", "bytes32"],
    [id("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"), rebuilt.publication, hash(managerCodeHash, "manager runtime hash"), hash(adapterCodeHash, "adapter runtime hash")])) as Hex;
}

const gateInterface = new Interface([
  `function publication() view returns (${publicationTuple})`,
  "function manifestBytes() view returns (bytes)", "function itemCount() view returns (uint256)",
  "function gateConfigHash() view returns (bytes32)", "function managerCodeHash() view returns (bytes32)",
  "function houseCodeHash() view returns (bytes32)", "function contentPurchaseVersion() view returns (bytes32)",
]);
/** Compare complete reviewed publication bytes, hashes and observed bound runtimes at one numeric block. */
export async function inspectCuratedManifest(
  provider: Pick<Provider, "getNetwork" | "call" | "getCode">, gate: Address, expected: CuratedManifest,
  options: { readonly blockTag: number },
): Promise<{ readonly gate: Address; readonly blockTag: number; readonly publication: CuratedPublication;
  readonly gateConfigHash: Hex; readonly evidenceBoundary: string }> {
  const target = address(gate, "gate"), blockTag = options?.blockTag;
  if (!Number.isSafeInteger(blockTag) || blockTag < 0) throw Error("Concrete nonnegative manifest block required");
  const saved = buildCuratedManifest({ ...expected.coordinates, rows: expected.rows });
  if (saved.manifestBytes.toLowerCase() !== expected.manifestBytes.toLowerCase()
    || coder.encode([publicationTuple], [saved.publication]).toLowerCase() !== coder.encode([publicationTuple], [expected.publication]).toLowerCase()) throw Error("Reviewed manifest differs from its rows");
  if ((await provider.getNetwork()).chainId !== saved.coordinates.chainId) throw Error("Manifest RPC chain differs");
  const read = async (method: string, maxBytes = 288): Promise<unknown> => {
    const raw = await provider.call({ to: target, data: gateInterface.encodeFunctionData(method), blockTag });
    if (typeof raw !== "string" || raw.length > 2 + maxBytes * 2 || !isHexString(raw, true)) throw Error(`Malformed or oversized ${method} response`);
    const decoded = gateInterface.decodeFunctionResult(method, raw);
    if (gateInterface.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) throw Error(`Noncanonical ${method} response`);
    return decoded[0];
  };
  const publication = await read("publication");
  if (coder.encode([publicationTuple], [publication]).toLowerCase() !== coder.encode([publicationTuple], [saved.publication]).toLowerCase()) throw Error("Onchain publication differs from reviewed manifest");
  const raw = await read("manifestBytes", 64 + (saved.manifestBytes.length - 2) / 2);
  if (String(raw).toLowerCase() !== saved.manifestBytes.toLowerCase() || await read("itemCount", 32) !== BigInt(saved.rows.length)) throw Error("Stored complete manifest bytes or count differ");
  if (await read("contentPurchaseVersion", 32) !== id("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1")) throw Error("Gate is not the selected-work purchase capability");
  const managerHash = hash(await read("managerCodeHash", 32) as Hex, "saved Manager code hash");
  const adapterHash = hash(await read("houseCodeHash", 32) as Hex, "saved adapter code hash");
  const configHash = curatedContentGateConfigHash(saved, managerHash, adapterHash);
  if (await read("gateConfigHash", 32) !== configHash) throw Error("Stored gate configuration differs from complete publication");
  for (const [contract, expectedHash] of [[saved.coordinates.manager, managerHash], [saved.coordinates.adapter, adapterHash]] as const) {
    const code = await provider.getCode(contract, blockTag);
    if (!isHexString(code, true) || code === "0x" || keccak256(code) !== expectedHash) throw Error("Observed bound runtime differs from gate's saved runtime hash");
  }
  return Object.freeze({ gate: target, blockTag, publication: saved.publication, gateConfigHash: configHash,
    evidenceBoundary: "Reviewed complete publication and observed bound runtimes only; numeric pin has no reorg check and does not prove canonical deployment, live admission or preview availability." });
}
