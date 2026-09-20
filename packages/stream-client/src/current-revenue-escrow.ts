import {
  AbiCoder,
  Interface,
  ParamType,
  TypedDataEncoder,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  keccak256,
  toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import {
  ARTIST_RECOVERY_GOVERNANCE_CALL_TUPLE,
  CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI,
} from "./current-artist-recovery-adjudication.js";
import {
  normalizeMintFallbackGovernanceWindow,
  type MintFallbackGovernanceWindow,
} from "./current-mint-fallback.js";

export const REVENUE_ESCROW_SOURCE = "d88ee108080ba1e66f1b8a9b49e3fd9a59d35c4a";
export interface RevenueEscrowCoordinates {
  readonly chainId: bigint;
  readonly escrow: Address;
}
export interface RevenueEscrowCreditKey {
  readonly revenueClass: Hex;
  readonly profileId: Hex;
  readonly wallet: Address;
  readonly asset: Address;
}
export interface RevenueEscrowManifestRef {
  readonly uri: string;
  readonly uriHash: Hex;
  readonly contentHash: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationHash: Hex;
}
export interface RevenueEscrowEntry {
  readonly account: Address;
  readonly sharePpm: bigint;
  readonly labelId: Hex;
}
export interface RevenueEscrowRecipientNotice {
  readonly account: Address;
  readonly evidenceHash: Hex;
  readonly noticedAt: bigint;
}
export interface RevenueEscrowCollectionNotice {
  readonly core: Address;
  readonly collectionId: bigint;
  readonly artistBound: boolean;
  readonly artistAuthority: Address;
  readonly evidenceHash: Hex;
  readonly noticedAt: bigint;
}
export interface RevenueEscrowSourceCredit {
  readonly producer: Address;
  readonly transactionHash: Hex;
  readonly blockHash: Hex;
  readonly blockNumber: bigint;
  readonly logIndex: bigint;
  readonly collectionIndex: bigint;
}
export interface RevenueEscrowDocument {
  readonly creditKey: RevenueEscrowCreditKey;
  readonly successorFactory: Address;
  readonly successorWallet: Address;
  readonly successorProfileId: Hex;
  readonly successorRuntimeCodeHash: Hex;
  readonly expectedAmount: bigint;
  readonly route: bigint;
  readonly oldEntries: readonly RevenueEscrowEntry[];
  readonly oldMetadataURIHash: Hex;
  readonly successorEntries: readonly RevenueEscrowEntry[];
  readonly recipientNotices: readonly RevenueEscrowRecipientNotice[];
  readonly collectionNotices: readonly RevenueEscrowCollectionNotice[];
  readonly sourceCredits: readonly RevenueEscrowSourceCredit[];
  readonly incidentEvidenceHash: Hex;
  readonly coverageStatementHash: Hex;
}
export interface RevenueEscrowRecoveryTerms {
  readonly creditKey: RevenueEscrowCreditKey;
  readonly successorWallet: Address;
  readonly successorProfileId: Hex;
  readonly successorRuntimeCodeHash: Hex;
  readonly expectedAmount: bigint;
  readonly recoveryManifest: RevenueEscrowManifestRef;
  readonly executeAfter: bigint;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
}
export interface RevenueEscrowRecoveryRecord extends RevenueEscrowRecoveryTerms {
  readonly status: bigint;
  readonly storedFactory: Address;
}
export interface RevenueEscrowConsent {
  readonly account: Address;
  readonly recoveryId: Hex;
  readonly nonce: Hex;
  readonly deadline: bigint;
}
export type RevenueEscrowRequest =
  | { readonly kind: "flushEscrow" | "flushToVerifiedWalletBestEffort"; readonly creditKey: RevenueEscrowCreditKey }
  | { readonly kind: "publishEscrowRecoveryManifest"; readonly document: RevenueEscrowDocument; readonly manifest: RevenueEscrowManifestRef }
  | { readonly kind: "executeEscrowRecovery" | "authorizeTerminalEscrowRecovery" | "revokeEscrowRecoveryConsent"; readonly recoveryId: Hex }
  | { readonly kind: "recordEscrowRecoveryConsent"; readonly recoveryId: Hex; readonly nonce: Hex }
  | { readonly kind: "submitEscrowRecoveryConsent"; readonly consent: RevenueEscrowConsent; readonly signature: Hex }
  | { readonly kind: "scheduleEscrowRecovery"; readonly terms: RevenueEscrowRecoveryTerms }
  | { readonly kind: "cancelEscrowRecovery"; readonly recoveryId: Hex; readonly reasonHash: Hex; readonly reasonURI: string };
export interface RevenueEscrowCall {
  readonly coordinates: RevenueEscrowCoordinates;
  readonly caller: Address;
  readonly request: RevenueEscrowRequest;
  readonly actionClass: 0n | 2n | 4n | null;
  readonly call: UnsignedCall;
  readonly expectedReturn: Hex | null;
  readonly factsVerified: false;
}

export const REVENUE_ESCROW_KEY_TUPLE = "tuple(bytes32 revenueClass,bytes32 profileId,address wallet,address asset)";
export const REVENUE_ESCROW_REF_TUPLE = "tuple(string uri,bytes32 uriHash,bytes32 contentHash,bytes32 schemaId,bytes32 canonicalizationHash)";
export const REVENUE_ESCROW_ENTRY_TUPLE = "tuple(address account,uint32 sharePpm,bytes32 labelId)";
export const REVENUE_ESCROW_DOCUMENT_TUPLE = `tuple(${REVENUE_ESCROW_KEY_TUPLE} creditKey,address successorFactory,address successorWallet,bytes32 successorProfileId,bytes32 successorRuntimeCodeHash,uint256 expectedAmount,uint8 route,${REVENUE_ESCROW_ENTRY_TUPLE}[] oldEntries,bytes32 oldMetadataURIHash,${REVENUE_ESCROW_ENTRY_TUPLE}[] successorEntries,tuple(address account,bytes32 evidenceHash,uint64 noticedAt)[] recipientNotices,tuple(address core,uint256 collectionId,bool artistBound,address artistAuthority,bytes32 evidenceHash,uint64 noticedAt)[] collectionNotices,tuple(address producer,bytes32 transactionHash,bytes32 blockHash,uint64 blockNumber,uint32 logIndex,uint32 collectionIndex)[] sourceCredits,bytes32 incidentEvidenceHash,bytes32 coverageStatementHash)`;
export const REVENUE_ESCROW_TERMS_TUPLE = `tuple(${REVENUE_ESCROW_KEY_TUPLE} creditKey,address successorWallet,bytes32 successorProfileId,bytes32 successorRuntimeCodeHash,uint256 expectedAmount,${REVENUE_ESCROW_REF_TUPLE} recoveryManifest,uint64 executeAfter,bytes32 reasonHash,string reasonURI)`;
export const REVENUE_ESCROW_RECORD_TUPLE = `tuple(uint8 status,${REVENUE_ESCROW_KEY_TUPLE} creditKey,address storedFactory,address successorWallet,bytes32 successorProfileId,bytes32 successorRuntimeCodeHash,uint256 expectedAmount,${REVENUE_ESCROW_REF_TUPLE} recoveryManifest,uint64 executeAfter,bytes32 reasonHash,string reasonURI)`;
export const REVENUE_ESCROW_CONSENT_TUPLE = "tuple(address account,bytes32 recoveryId,bytes32 nonce,uint64 deadline)";
export const CURRENT_REVENUE_ESCROW_ABI = Object.freeze([
  "function flushEscrow(bytes32 revenueClass,bytes32 profileId,address wallet,address asset)",
  "function flushToVerifiedWalletBestEffort(bytes32 revenueClass,bytes32 profileId,address wallet,address asset)",
  `function publishEscrowRecoveryManifest(${REVENUE_ESCROW_DOCUMENT_TUPLE} document,${REVENUE_ESCROW_REF_TUPLE} manifest) returns(bytes32 contentHash)`,
  "function executeEscrowRecovery(bytes32 recoveryId)",
  "function submitEscrowRecoveryConsent(address account,bytes32 recoveryId,bytes32 nonce,uint64 deadline,bytes signature)",
  "function recordEscrowRecoveryConsent(bytes32 recoveryId,bytes32 nonce)",
  "function revokeEscrowRecoveryConsent(bytes32 recoveryId)",
  `function scheduleEscrowRecovery(${REVENUE_ESCROW_KEY_TUPLE} creditKey,address successorWallet,bytes32 successorProfileId,bytes32 successorRuntimeCodeHash,uint256 expectedAmount,${REVENUE_ESCROW_REF_TUPLE} recoveryManifest,uint64 executeAfter,bytes32 reasonHash,string reasonURI) returns(bytes32 recoveryId)`,
  "function cancelEscrowRecovery(bytes32 recoveryId,bytes32 reasonHash,string reasonURI)",
  "function authorizeTerminalEscrowRecovery(bytes32 recoveryId)",
]);
const coder = AbiCoder.defaultAbiCoder();
const abi = new Interface(CURRENT_REVENUE_ESCROW_ABI);
const gov = new Interface(CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI);
const ZERO = ZeroHash as Hex;
const hash = (types: readonly string[], values: readonly unknown[]) => keccak256(coder.encode(types, values)) as Hex;
const fieldKeys = (type: string) => ParamType.from(type).components!.map(field => field.name);
function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    for (const item of Object.values(value)) freeze(item);
    Object.freeze(value);
  }
  return value;
}
function exact(value: unknown, fields: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join() !== [...fields].sort().join()) throw Error("Unexpected escrow fields");
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits}`);
  return value;
}
function address(value: string, zero = false): Address {
  const result = getAddress(value) as Address;
  if (!zero && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function bytes(value: string, length?: number): Hex {
  if (!/^0x(?:[0-9a-fA-F]{2})*$/.test(value) || value.length > 4_194_306
    || length !== undefined && value.length !== 2 + length * 2) throw Error("Invalid escrow bytes");
  return value.toLowerCase() as Hex;
}
function nonzero(value: string): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Zero hash");
  return result;
}
function text(value: string, allowEmpty = false): string {
  if (typeof value !== "string" || (!allowEmpty && !value.length) || toUtf8Bytes(value).length > 2048) throw Error("Invalid bounded URI");
  for (let i = 0; i < value.length; i++) {
    const unit = value.charCodeAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      const next = value.charCodeAt(++i);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw Error("Unpaired Unicode surrogate");
    } else if (unit >= 0xdc00 && unit <= 0xdfff) throw Error("Unpaired Unicode surrogate");
  }
  return value;
}
function normalize(type: ParamType, value: any): any {
  if (type.baseType === "tuple") {
    exact(value, type.components!.map(field => field.name));
    return freeze(Object.fromEntries(type.components!.map(field => [field.name, normalize(field, value[field.name])])));
  }
  if (type.baseType === "array") {
    if (!Array.isArray(value) || value.length > 1024 || Object.keys(value).length !== value.length) throw Error("Invalid bounded array");
    return freeze(value.map(item => normalize(type.arrayChildren!, item)));
  }
  if (type.type === "address") return address(value, true);
  if (type.type === "string") return text(value, true);
  if (type.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected boolean");
    return value;
  }
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  return uint(value, Number(type.type.slice(4)));
}
function plain(type: ParamType, value: any): any {
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((field, i) => [field.name, plain(field, value[i])]));
  if (type.baseType === "array") return Array.from(value, item => plain(type.arrayChildren!, item));
  return value;
}
function tuple<T>(type: string, value: T): T { return normalize(ParamType.from(type), value) as T; }
function decode<T>(type: string, raw: Hex): T {
  const input = bytes(raw), value = coder.decode([type], input);
  if (coder.encode([type], value) !== input) throw Error("Noncanonical escrow tuple");
  return tuple(type, plain(ParamType.from(type), value[0])) as T;
}
export const normalizeRevenueEscrowCreditKey = (value: RevenueEscrowCreditKey) => tuple(REVENUE_ESCROW_KEY_TUPLE, value);
export const normalizeRevenueEscrowRecoveryRecord = (value: RevenueEscrowRecoveryRecord) => tuple(REVENUE_ESCROW_RECORD_TUPLE, value);
export const encodeRevenueEscrowRecoveryRecord = (value: RevenueEscrowRecoveryRecord) => coder.encode([REVENUE_ESCROW_RECORD_TUPLE], [normalizeRevenueEscrowRecoveryRecord(value)]) as Hex;
export const decodeRevenueEscrowRecoveryRecord = (raw: Hex) => decode<RevenueEscrowRecoveryRecord>(REVENUE_ESCROW_RECORD_TUPLE, raw);
export function normalizeRevenueEscrowCoordinates(value: RevenueEscrowCoordinates): RevenueEscrowCoordinates {
  exact(value, ["chainId", "escrow"]);
  if (uint(value.chainId) === 0n) throw Error("Zero chain");
  return freeze({ chainId: value.chainId, escrow: address(value.escrow) });
}
export function normalizeRevenueEscrowManifestRef(value: RevenueEscrowManifestRef): RevenueEscrowManifestRef {
  const r = tuple(REVENUE_ESCROW_REF_TUPLE, value);
  text(r.uri); nonzero(r.contentHash);
  if (r.uriHash !== keccak256(toUtf8Bytes(r.uri)) || r.schemaId !== id("STREAM_ESCROW_RECOVERY_MANIFEST_V1")
    || r.canonicalizationHash !== id("6529STREAM_ESCROW_RECOVERY_ABI_V1")) throw Error("Original escrow reference differs");
  return r;
}
export function revenueEscrowEntriesHash(value: readonly RevenueEscrowEntry[]): Hex {
  const rows = tuple(`${REVENUE_ESCROW_ENTRY_TUPLE}[]`, value);
  if (!rows.length || rows.length > 64) throw Error("Original entries bound");
  let total = 0n;
  rows.forEach((row, i) => {
    address(row.account);
    if (!row.sharePpm || row.sharePpm > 1_000_000n) throw Error("Invalid share");
    const previous = rows[i - 1];
    if (previous && (BigInt(previous.account) > BigInt(row.account)
      || previous.account === row.account && BigInt(previous.labelId) >= BigInt(row.labelId))) throw Error("Noncanonical entry order");
    total += row.sharePpm;
  });
  if (total !== 1_000_000n) throw Error("Shares must total one million");
  return hash([`${REVENUE_ESCROW_ENTRY_TUPLE}[]`], [rows]);
}
export function revenueEscrowAffectedAccounts(document: RevenueEscrowDocument): readonly Address[] {
  const oldEntries = tuple(`${REVENUE_ESCROW_ENTRY_TUPLE}[]`, document.oldEntries);
  const successorEntries = tuple(`${REVENUE_ESCROW_ENTRY_TUPLE}[]`, document.successorEntries);
  revenueEscrowEntriesHash(oldEntries);
  revenueEscrowEntriesHash(successorEntries);
  const shares = (rows: readonly RevenueEscrowEntry[]) => {
    const result = new Map<Address, bigint>();
    rows.forEach(row => result.set(row.account, (result.get(row.account) ?? 0n) + row.sharePpm));
    return result;
  };
  const old = shares(oldEntries), next = shares(successorEntries);
  return Object.freeze([...old.keys()].filter(account => old.get(account)! > (next.get(account) ?? 0n)));
}
export function normalizeRevenueEscrowDocument(value: RevenueEscrowDocument): RevenueEscrowDocument {
  const d = tuple(REVENUE_ESCROW_DOCUMENT_TUPLE, value);
  nonzero(d.creditKey.revenueClass); nonzero(d.creditKey.profileId); address(d.creditKey.wallet);
  address(d.successorFactory); address(d.successorWallet); nonzero(d.successorProfileId);
  nonzero(d.successorRuntimeCodeHash); nonzero(d.incidentEvidenceHash);
  if (!d.expectedAmount || d.route > 2n || d.successorWallet === d.creditKey.wallet) throw Error("Invalid recovery document");
  const old = revenueEscrowEntriesHash(d.oldEntries), next = revenueEscrowEntriesHash(d.successorEntries);
  if ((d.route === 0n) !== (old === next)) throw Error("Recovery route and entries differ");
  const affected = revenueEscrowAffectedAccounts(d);
  if (d.route !== 2n) {
    if (d.recipientNotices.length || d.collectionNotices.length || d.sourceCredits.length || d.coverageStatementHash !== ZERO) throw Error("Unexpected terminal notices");
  } else {
    nonzero(d.coverageStatementHash);
    if (!d.collectionNotices.length || !d.sourceCredits.length || affected.length !== d.recipientNotices.length) throw Error("Incomplete notice inventory");
    d.recipientNotices.forEach((notice, i) => {
      if (notice.account !== affected[i] || !notice.noticedAt) throw Error("Affected recipient differs");
      nonzero(notice.evidenceHash);
    });
    d.collectionNotices.forEach((notice, i) => {
      address(notice.core);
      const previous = d.collectionNotices[i - 1];
      if (!notice.collectionId || previous && (BigInt(previous.core) > BigInt(notice.core)
        || previous.core === notice.core && previous.collectionId >= notice.collectionId)) throw Error("Collection notice order differs");
      if (notice.artistBound) { address(notice.artistAuthority); nonzero(notice.evidenceHash); if (!notice.noticedAt) throw Error("Missing Artist notice"); }
      else if (notice.artistAuthority !== ZeroAddress || notice.evidenceHash !== ZERO || notice.noticedAt !== 0n) throw Error("Noncanonical unbound notice");
    });
    const represented = new Set<bigint>();
    d.sourceCredits.forEach((credit, i) => {
      address(credit.producer); nonzero(credit.transactionHash); nonzero(credit.blockHash);
      const previous = d.sourceCredits[i - 1];
      if (!credit.blockNumber || credit.collectionIndex >= BigInt(d.collectionNotices.length)
        || previous && (BigInt(previous.transactionHash) > BigInt(credit.transactionHash)
          || previous.transactionHash === credit.transactionHash && previous.logIndex >= credit.logIndex)) throw Error("Credit citation order differs");
      represented.add(credit.collectionIndex);
    });
    if (represented.size !== d.collectionNotices.length) throw Error("Unrepresented collection");
  }
  return d;
}
export const encodeRevenueEscrowDocument = (value: RevenueEscrowDocument) => coder.encode([REVENUE_ESCROW_DOCUMENT_TUPLE], [normalizeRevenueEscrowDocument(value)]) as Hex;
export const decodeRevenueEscrowDocument = (raw: Hex) => normalizeRevenueEscrowDocument(decode<RevenueEscrowDocument>(REVENUE_ESCROW_DOCUMENT_TUPLE, raw));
export function revenueEscrowManifestHash(coordinates: RevenueEscrowCoordinates, value: RevenueEscrowDocument): Hex {
  const c = normalizeRevenueEscrowCoordinates(coordinates);
  return hash(["bytes32", "uint256", "address", REVENUE_ESCROW_DOCUMENT_TUPLE], [id("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"), c.chainId, c.escrow, normalizeRevenueEscrowDocument(value)]);
}
export function revenueEscrowRecoveryId(
  coordinates: RevenueEscrowCoordinates,
  value: RevenueEscrowRecoveryTerms,
): Hex {
  const c = normalizeRevenueEscrowCoordinates(coordinates), p = tuple(REVENUE_ESCROW_TERMS_TUPLE, value), k = p.creditKey;
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "address", "address", "address", "bytes32", "bytes32", "uint256", "bytes32", "uint64", "bytes32"],
    [id("6529STREAM_ESCROW_RECOVERY_V1"), c.chainId, c.escrow, k.revenueClass, k.profileId, k.wallet, k.asset,
      p.successorWallet, p.successorProfileId, p.successorRuntimeCodeHash, p.expectedAmount, p.recoveryManifest.contentHash, p.executeAfter, p.reasonHash]);
}
export function revenueEscrowConsentTypedData(
  coordinates: RevenueEscrowCoordinates,
  value: RevenueEscrowConsent,
) {
  const c = normalizeRevenueEscrowCoordinates(coordinates), message = tuple(REVENUE_ESCROW_CONSENT_TUPLE, value);
  address(message.account); nonzero(message.recoveryId);
  const domain = { name: "6529StreamRevenueEscrow", version: "1", chainId: c.chainId, verifyingContract: c.escrow };
  const types = { StreamEscrowRecoveryConsent: [{ name: "account", type: "address" }, { name: "recoveryId", type: "bytes32" }, { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" }] };
  return freeze({ domain, types, message, digest: TypedDataEncoder.hash(domain, types, message) as Hex });
}
export function prepareRevenueEscrowCall(
  coordinates: RevenueEscrowCoordinates,
  callerInput: Address,
  input: RevenueEscrowRequest,
): RevenueEscrowCall {
  const c = normalizeRevenueEscrowCoordinates(coordinates), caller = address(callerInput);
  let request: RevenueEscrowRequest, args: readonly unknown[], actionClass: RevenueEscrowCall["actionClass"] = null;
  let expectedReturn: Hex | null = "0x";
  switch (input.kind) {
    case "flushEscrow": case "flushToVerifiedWalletBestEffort": {
      exact(input, ["kind", "creditKey"]);
      request = { kind: input.kind, creditKey: normalizeRevenueEscrowCreditKey(input.creditKey) };
      args = [request.creditKey.revenueClass, request.creditKey.profileId, request.creditKey.wallet, request.creditKey.asset];
      break;
    }
    case "publishEscrowRecoveryManifest": {
      exact(input, ["kind", "document", "manifest"]);
      const document = normalizeRevenueEscrowDocument(input.document), manifest = normalizeRevenueEscrowManifestRef(input.manifest);
      if (revenueEscrowManifestHash(c, document) !== manifest.contentHash) throw Error("Manifest content hash differs");
      request = { kind: input.kind, document, manifest }; args = [document, manifest];
      expectedReturn = coder.encode(["bytes32"], [manifest.contentHash]) as Hex;
      break;
    }
    case "scheduleEscrowRecovery": {
      exact(input, ["kind", "terms"]);
      const terms = tuple(REVENUE_ESCROW_TERMS_TUPLE, input.terms);
      normalizeRevenueEscrowManifestRef(terms.recoveryManifest); nonzero(terms.reasonHash); text(terms.reasonURI);
      request = { kind: input.kind, terms }; args = fieldKeys(REVENUE_ESCROW_TERMS_TUPLE).map(key => (terms as any)[key]);
      actionClass = 4n; expectedReturn = coder.encode(["bytes32"], [revenueEscrowRecoveryId(c, terms)]) as Hex;
      break;
    }
    case "submitEscrowRecoveryConsent": {
      exact(input, ["kind", "consent", "signature"]);
      const consent = revenueEscrowConsentTypedData(c, input.consent).message, signature = bytes(input.signature);
      if ((signature.length - 2) / 2 > 65_536) throw Error("Signature exceeds client bound");
      request = { kind: input.kind, consent, signature }; args = [consent.account, consent.recoveryId, consent.nonce, consent.deadline, signature];
      break;
    }
    case "recordEscrowRecoveryConsent": {
      exact(input, ["kind", "recoveryId", "nonce"]);
      request = { kind: input.kind, recoveryId: nonzero(input.recoveryId), nonce: bytes(input.nonce, 32) };
      args = [request.recoveryId, request.nonce]; break;
    }
    case "cancelEscrowRecovery": {
      exact(input, ["kind", "recoveryId", "reasonHash", "reasonURI"]);
      request = { kind: input.kind, recoveryId: nonzero(input.recoveryId), reasonHash: nonzero(input.reasonHash), reasonURI: text(input.reasonURI) };
      args = [request.recoveryId, request.reasonHash, request.reasonURI]; actionClass = 0n; break;
    }
    case "executeEscrowRecovery": case "authorizeTerminalEscrowRecovery": case "revokeEscrowRecoveryConsent": {
      exact(input, ["kind", "recoveryId"]);
      request = { kind: input.kind, recoveryId: nonzero(input.recoveryId) }; args = [request.recoveryId];
      if (input.kind === "authorizeTerminalEscrowRecovery") actionClass = 2n;
      break;
    }
    default: throw Error("Unsupported escrow operation");
  }
  const data = bytes(abi.encodeFunctionData(request.kind, args));
  return freeze({ coordinates: c, caller, request, actionClass, call: { to: c.escrow, value: 0n, data }, expectedReturn, factsVerified: false });
}
function same(a: unknown, b: unknown): boolean {
  const canonical = (value: any): any => {
    if (typeof value === "bigint") return ["bigint", value.toString()];
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === "object") return Object.keys(value).sort().map(key => [key, canonical(value[key])]);
    return value;
  };
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}
export function normalizeRevenueEscrowCall(value: RevenueEscrowCall): RevenueEscrowCall {
  const expected = prepareRevenueEscrowCall(value.coordinates, value.caller, value.request);
  exact(value, Object.keys(expected));
  if (!same(value, expected)) throw Error("Escrow call differs from immutable reconstruction");
  return expected;
}
export interface RevenueEscrowTransition {
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
}
export interface RevenueEscrowGovernanceBatch {
  readonly prepared: RevenueEscrowCall;
  readonly executor: Address;
  readonly transition: RevenueEscrowTransition;
  readonly nonce: bigint;
  readonly window: MintFallbackGovernanceWindow;
  readonly governanceCall: { readonly target: Address; readonly value: bigint; readonly selector: Hex; readonly callDataHash: Hex } & RevenueEscrowTransition;
  readonly callsHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly actionId: Hex;
  readonly publicationKey: Hex;
  readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall;
  readonly executionCall: UnsignedCall;
  readonly factsVerified: false;
}
export function prepareRevenueEscrowGovernanceBatch(
  input: RevenueEscrowCall,
  executorInput: Address,
  transitionInput: RevenueEscrowTransition,
  nonce: bigint,
  window: MintFallbackGovernanceWindow,
): RevenueEscrowGovernanceBatch {
  const prepared = normalizeRevenueEscrowCall(input), executor = address(executorInput), w = normalizeMintFallbackGovernanceWindow(window);
  if (prepared.actionClass === null || prepared.caller !== executor) throw Error("Governed escrow target requires actual Executor caller");
  exact(transitionInput, ["scopeHash", "oldValueHash", "newValueHash"]);
  const transition = { scopeHash: nonzero(transitionInput.scopeHash), oldValueHash: nonzero(transitionInput.oldValueHash), newValueHash: nonzero(transitionInput.newValueHash) };
  const governanceCall = { target: prepared.coordinates.escrow, value: 0n, selector: prepared.call.data.slice(0, 10) as Hex,
    callDataHash: keccak256(prepared.call.data) as Hex, ...transition };
  const calls = [governanceCall], callDatas = [prepared.call.data];
  const callsHash = hash(["bytes32", `${ARTIST_RECOVERY_GOVERNANCE_CALL_TUPLE}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: string, field: keyof RevenueEscrowTransition) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [transition[field]]]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = hash(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", prepared.coordinates.chainId, executor, prepared.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, uint(nonce), w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]);
  const call = (method: string, values: readonly unknown[]): UnsignedCall => ({ to: executor, value: 0n, data: bytes(gov.encodeFunctionData(method, values)) });
  return freeze({ prepared, executor, transition, nonce, window: w, governanceCall, callsHash, scopeHash, oldValueHash, newValueHash,
    actionId, publicationKey: keccak256(governanceCall.callDataHash) as Hex,
    publicationCall: call("publishGovernanceCallData", [callDatas]),
    scheduleCall: call("scheduleGovernanceBatch", [prepared.actionClass, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]),
    executionCall: call("executeGovernanceBatch", [actionId, calls, callDatas]), factsVerified: false });
}
export function normalizeRevenueEscrowGovernanceBatch(value: RevenueEscrowGovernanceBatch): RevenueEscrowGovernanceBatch {
  const expected = prepareRevenueEscrowGovernanceBatch(value.prepared, value.executor, value.transition, value.nonce, value.window);
  exact(value, Object.keys(expected));
  if (!same(value, expected)) throw Error("Governance batch differs");
  return expected;
}
