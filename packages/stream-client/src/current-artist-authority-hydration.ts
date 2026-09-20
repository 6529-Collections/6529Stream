import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";

export type ArtistHydrationProfile = "baseline" | "multiple" | "delegation";
export type ArtistHydrationOwnerIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6;
export type ArtistHydrationSeven<T> = readonly [T, T, T, T, T, T, T];
export interface ArtistHydrationSnapshot { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex }
export interface ArtistHydrationCheckpoint {
  readonly schema: Hex; readonly ownerState: ArtistHydrationSnapshot; readonly replayRoot: Hex;
  readonly replayCount: bigint; readonly nonceRoot: Hex; readonly nonceIndexCount: bigint;
}
export interface ArtistHydrationOrigin { readonly surface: Hex; readonly scope: Hex }
export interface ArtistHydrationPolicyKey { readonly phaseId: Hex; readonly policyHash: Hex }
export interface ArtistHydrationReplayCell { readonly commitment: Hex; readonly touchedRevision: bigint; readonly kind: bigint; readonly status: bigint }
export interface ArtistHydrationNativeReceipt { readonly operation: bigint; readonly artistId: Hex; readonly collectionId: bigint; readonly recordHash: Hex }
export interface ArtistHydrationNonceWord { readonly prefix: bigint; readonly words: readonly bigint[]; readonly exhausted: boolean }
export interface ArtistHydrationNonceIndex { readonly kind: bigint; readonly key: Hex; readonly prefixCount: bigint }
export interface ArtistHydrationSuite {
  readonly registry: Address; readonly archive: Address; readonly owners: ArtistHydrationSeven<Address>;
  readonly core: Address; readonly mintManager: Address; readonly roleRegistry: Address; readonly metadata: Address;
  readonly primaryResolver: Address; readonly royaltyResolver: Address; readonly primaryRevenueClass: Hex; readonly validator: Address;
}
export interface ArtistSingleHydrationRequest {
  readonly bindingIndex: bigint; readonly artistId: Hex; readonly collectionId: bigint;
  readonly expectedSource: ArtistHydrationSeven<ArtistHydrationCheckpoint>;
  readonly replayOrigins: ArtistHydrationSeven<readonly ArtistHydrationOrigin[]>; readonly policies: readonly ArtistHydrationPolicyKey[];
}
export interface ArtistMultipleHydrationCollection { readonly artistId: Hex; readonly collectionId: bigint; readonly policies: readonly ArtistHydrationPolicyKey[] }
export interface ArtistMultipleHydrationRequest {
  readonly bindingIndex: bigint; readonly artistIds: readonly Hex[]; readonly collections: readonly ArtistMultipleHydrationCollection[];
  readonly expectedSource: ArtistHydrationSeven<ArtistHydrationCheckpoint>; readonly replayOrigins: ArtistHydrationSeven<readonly ArtistHydrationOrigin[]>;
}
export type ArtistAuthorityHydrationRequest =
  | { readonly kind: "baseline" | "delegation"; readonly request: ArtistSingleHydrationRequest }
  | { readonly kind: "multiple"; readonly request: ArtistMultipleHydrationRequest };
export interface ArtistHydrationQuery {
  readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex;
  readonly policies: readonly ArtistHydrationPolicyKey[]; readonly records: readonly Hex[];
}
export interface ArtistHydrationOwnerData {
  readonly typedState: Hex; readonly origins: readonly ArtistHydrationOrigin[]; readonly sourceKeys: readonly Hex[];
  readonly cells: readonly ArtistHydrationReplayCell[]; readonly nonces: readonly ArtistHydrationNonceWord[];
}
export interface ArtistHydrationIdentity {
  readonly item: { readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint;
    readonly registeredAt: bigint; readonly lastAuthorityActionAt: bigint; readonly identityRecordHash: Hex;
    readonly identityRecordURI: string; readonly displayName: string; readonly nonceHint: bigint };
  readonly document: Hex; readonly nextRegistrationNonce: bigint; readonly estateActivity: bigint;
  readonly dormancyActivity: bigint; readonly findingActivity: bigint; readonly signatures: readonly Hex[];
}
export interface ArtistHydrationBinding {
  readonly item: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex;
    readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint;
    readonly proposer: Address; readonly accepted: boolean };
  readonly terms: { readonly collaboratorSetHash: Hex; readonly capabilityPolicySetHash: Hex; readonly mode: bigint; readonly threshold: bigint; readonly count: bigint };
}
export interface ArtistHydrationAcceptance { readonly record: Hex; readonly acceptedAt: bigint }
export interface ArtistHydrationAttribution { readonly state: bigint; readonly generation: bigint }
export interface ArtistHydrationMultipleRow { readonly query: ArtistHydrationQuery; readonly state: Hex; readonly nonces: readonly ArtistHydrationNonceWord[] }
export interface ArtistHydrationMultipleBundle {
  readonly rows: readonly ArtistHydrationMultipleRow[]; readonly artistIds: readonly Hex[]; readonly collectionIds: readonly bigint[]; readonly registrationCount: bigint;
}
export interface ArtistHydrationRevision {
  readonly item: { readonly recordHash: Hex; readonly artistId: Hex; readonly previousRecordHash: Hex; readonly revisedRecordHash: Hex;
    readonly previousRevisionRecord: Hex; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint;
    readonly signedAt: bigint; readonly identityRecordURI: string; readonly displayName: string }; readonly document: Hex;
}
export interface ArtistHydrationGrant {
  readonly recordHash: Hex;
  readonly item: { readonly grant: { readonly artistId: Hex; readonly delegate: Address; readonly collectionId: bigint; readonly capabilities: bigint;
    readonly notBefore: bigint; readonly expiresAt: bigint; readonly maxUses: bigint; readonly constraintsHash: Hex };
    readonly grantor: Address; readonly nonce: bigint; readonly uses: bigint; readonly revoked: boolean; readonly revocationRecordHash: Hex };
  readonly epoch: bigint; readonly current: Hex;
}
export interface ArtistHydrationDelegateNonceLane { readonly key: Hex; readonly hint: bigint; readonly words: readonly ArtistHydrationNonceWord[] }
export interface ArtistHydrationDelegationIdentity {
  readonly baseline: Hex; readonly epoch: bigint; readonly revisions: readonly ArtistHydrationRevision[];
  readonly grants: readonly ArtistHydrationGrant[]; readonly delegateNonces: readonly ArtistHydrationDelegateNonceLane[];
}
export interface ArtistHydrationSale {
  readonly item: { readonly recordHash: Hex; readonly terms: { readonly collectionId: bigint; readonly saleAdapter: Address; readonly saleId: Hex; readonly saleConfigHash: Hex };
    readonly artistId: Hex; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint;
    readonly bindingGeneration: bigint; readonly bindingHash: Hex }; readonly grant: Hex; readonly current: Hex;
}
export interface ArtistHydrationDelegationConsent { readonly policies: readonly { readonly recordHash: Hex; readonly grant: Hex }[]; readonly sales: readonly ArtistHydrationSale[] }
export interface ArtistHydrationOwnerStates {
  readonly baseline: { readonly 0: ArtistHydrationBinding; readonly 1: null; readonly 2: ArtistHydrationIdentity; readonly 3: ArtistHydrationAcceptance;
    readonly 4: ArtistHydrationAttribution; readonly 5: null; readonly 6: readonly Hex[] };
  readonly multiple: { readonly 0: ArtistHydrationMultipleBundle; readonly 1: null; readonly 2: ArtistHydrationMultipleBundle;
    readonly 3: ArtistHydrationMultipleBundle; readonly 4: ArtistHydrationMultipleBundle; readonly 5: null; readonly 6: ArtistHydrationMultipleBundle };
  readonly delegation: { readonly 0: ArtistHydrationBinding; readonly 1: null; readonly 2: ArtistHydrationDelegationIdentity; readonly 3: ArtistHydrationAcceptance;
    readonly 4: ArtistHydrationAttribution; readonly 5: null; readonly 6: ArtistHydrationDelegationConsent };
}
export type ArtistHydrationOwnerState<P extends ArtistHydrationProfile = ArtistHydrationProfile, O extends ArtistHydrationOwnerIndex = ArtistHydrationOwnerIndex> = ArtistHydrationOwnerStates[P][O];
export interface ArtistAuthorityHydrationCoordinates {
  readonly chainId: bigint; readonly registry: Address; readonly coordinator: Address; readonly predecessorRegistry: Address; readonly sourceCoordinator: Address;
}
export interface ArtistHydrationOwnerEnvironment {
  readonly chainId: bigint; readonly registry: Address; readonly coordinator: Address; readonly archive: Address; readonly owner: Address; readonly domain: Hex;
}
export interface ArtistAuthorityHydrationCall {
  readonly registry: Address; readonly caller: Address; readonly input: ArtistAuthorityHydrationRequest;
  readonly profile: Hex; readonly capabilityId: Hex; readonly call: UnsignedCall; readonly factsVerified: false;
}
export interface ArtistAuthorityHydrationProfileEvidence {
  readonly profile: Hex; readonly predecessorRegistry: Address; readonly sourceCoordinator: Address;
  readonly expectedSource: ArtistHydrationSeven<ArtistHydrationCheckpoint>; readonly query: ArtistHydrationQuery;
  readonly ownerData: ArtistHydrationSeven<ArtistHydrationOwnerData>;
}
export interface ArtistAuthorityHydrationEvidence {
  readonly schemaVersion: bigint; readonly configurationHash: Hex; readonly operationId: bigint; readonly actor: Address; readonly commitment: Hex;
  readonly before: ArtistHydrationSeven<ArtistHydrationSnapshot>; readonly after: ArtistHydrationSeven<ArtistHydrationSnapshot>; readonly profileData: Hex;
}

export const ARTIST_HYDRATION_PROFILES = Object.freeze({ baseline: id("6529STREAM_ARTIST_LIVING_BASELINE_HYDRATION_V1") as Hex,
  multiple: id("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1") as Hex, delegation: id("6529STREAM_ARTIST_LIVING_DELEGATION_HYDRATION_V1") as Hex });
export const ARTIST_HYDRATION_CAPABILITY_IDS = Object.freeze({ baseline: "0x1f51c336", multiple: "0x4739d03d", delegation: "0xe17666b4" } as const);
export const ARTIST_HYDRATION_CHECKPOINT_SCHEMA = id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1") as Hex;
export const ARTIST_HYDRATION_MAX_EVIDENCE_BYTES = 24_575n;
export const ARTIST_HYDRATION_SNAPSHOT_TUPLE = "tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
export const ARTIST_HYDRATION_CHECKPOINT_TUPLE = `tuple(bytes32 schema,${ARTIST_HYDRATION_SNAPSHOT_TUPLE} ownerState,bytes32 replayRoot,uint256 replayCount,bytes32 nonceRoot,uint256 nonceIndexCount)`;
export const ARTIST_HYDRATION_REPLAY_CELL_TUPLE = "tuple(bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status)";
export const ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE = "tuple(uint16 operation,bytes32 artistId,uint256 collectionId,bytes32 recordHash)";
export const ARTIST_HYDRATION_NONCE_WORD_TUPLE = "tuple(uint256 prefix,uint256[32] words,bool exhausted)";
export const ARTIST_HYDRATION_NONCE_INDEX_TUPLE = "tuple(uint8 kind,bytes32 key,uint256 prefixCount)";
export const ARTIST_HYDRATION_ORIGIN_TUPLE = "tuple(bytes32 surface,bytes32 scope)";
export const ARTIST_HYDRATION_POLICY_TUPLE = "tuple(bytes32 phaseId,bytes32 policyHash)";
export const ARTIST_HYDRATION_SUITE_TUPLE = "tuple(address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator)";
export const ARTIST_HYDRATION_SINGLE_REQUEST_TUPLE = `tuple(uint256 bindingIndex,bytes32 artistId,uint256 collectionId,${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7] expectedSource,${ARTIST_HYDRATION_ORIGIN_TUPLE}[][7] replayOrigins,${ARTIST_HYDRATION_POLICY_TUPLE}[] policies)`;
export const ARTIST_HYDRATION_MULTIPLE_REQUEST_TUPLE = `tuple(uint256 bindingIndex,bytes32[] artistIds,tuple(bytes32 artistId,uint256 collectionId,${ARTIST_HYDRATION_POLICY_TUPLE}[] policies)[] collections,${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7] expectedSource,${ARTIST_HYDRATION_ORIGIN_TUPLE}[][7] replayOrigins)`;
export const ARTIST_HYDRATION_QUERY_TUPLE = `tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash,${ARTIST_HYDRATION_POLICY_TUPLE}[] policies,bytes32[] records)`;
export const ARTIST_HYDRATION_OWNER_DATA_TUPLE = `tuple(bytes typedState,${ARTIST_HYDRATION_ORIGIN_TUPLE}[] origins,bytes32[] sourceKeys,${ARTIST_HYDRATION_REPLAY_CELL_TUPLE}[] cells,${ARTIST_HYDRATION_NONCE_WORD_TUPLE}[] nonces)`;
// Original internal return-byte schemas; no fabricated external getter exposes these tuples.
export const ARTIST_HYDRATION_IDENTITY_TUPLE = "tuple(tuple(address authorityAddress,uint8 authorityClass,uint8 status,uint64 registeredAt,uint64 lastAuthorityActionAt,bytes32 identityRecordHash,string identityRecordURI,string displayName,uint256 nonceHint) item,bytes document,uint256 nextRegistrationNonce,uint256 estateActivity,uint256 dormancyActivity,uint256 findingActivity,bytes[] signatures)";
export const ARTIST_HYDRATION_BINDING_TUPLE = "tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) item,tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count) terms)";
export const ARTIST_HYDRATION_ACCEPTANCE_TUPLE = "tuple(bytes32 record,uint64 acceptedAt)";
export const ARTIST_HYDRATION_ATTRIBUTION_TUPLE = "tuple(uint8 state,uint64 generation)";
export const ARTIST_HYDRATION_MULTIPLE_BUNDLE_TUPLE = `tuple(tuple(${ARTIST_HYDRATION_QUERY_TUPLE} query,bytes state,${ARTIST_HYDRATION_NONCE_WORD_TUPLE}[] nonces)[] rows,bytes32[] artistIds,uint256[] collectionIds,uint256 registrationCount)`;
const revision = "tuple(tuple(bytes32 recordHash,bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,bytes32 previousRevisionRecord,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,string identityRecordURI,string displayName) item,bytes document)";
const grant = "tuple(bytes32 recordHash,tuple(tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash) grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash) item,uint64 epoch,bytes32 current)";
export const ARTIST_HYDRATION_DELEGATION_IDENTITY_TUPLE = `tuple(bytes baseline,uint64 epoch,${revision}[] revisions,${grant}[] grants,tuple(bytes32 key,uint256 hint,${ARTIST_HYDRATION_NONCE_WORD_TUPLE}[] words)[] delegateNonces)`;
export const ARTIST_HYDRATION_DELEGATION_CONSENT_TUPLE = "tuple(tuple(bytes32 recordHash,bytes32 grant)[] policies,tuple(tuple(bytes32 recordHash,tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash) item,bytes32 grant,bytes32 current)[] sales)";
const multipleTag = id("6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1");
const delegationTags: Readonly<Partial<Record<ArtistHydrationOwnerIndex, string>>> = Object.freeze({
  0: id("6529STREAM_ARTIST_LIVING_DELEGATION_BINDING_V1"), 2: id("6529STREAM_ARTIST_LIVING_DELEGATION_IDENTITY_V1"), 6: id("6529STREAM_ARTIST_LIVING_DELEGATION_CONSENT_V1") });
const methods = Object.freeze({ baseline: "hydrateArtistAuthority", multiple: "hydrateMultipleArtistAuthority", delegation: "hydrateArtistAuthorityWithDelegations" });
export const CURRENT_ARTIST_AUTHORITY_HYDRATION_ABI: readonly string[] = Object.freeze([
  `function hydrateArtistAuthority(${ARTIST_HYDRATION_SINGLE_REQUEST_TUPLE} request) returns(bytes32)`,
  `function hydrateMultipleArtistAuthority(${ARTIST_HYDRATION_MULTIPLE_REQUEST_TUPLE} request) returns(bytes32)`,
  `function hydrateArtistAuthorityWithDelegations(${ARTIST_HYDRATION_SINGLE_REQUEST_TUPLE} request) returns(bytes32)`,
]);
const abi = new Interface(CURRENT_ARTIST_AUTHORITY_HYDRATION_ABI), coder = AbiCoder.defaultAbiCoder();
function exact(v: unknown, keys: readonly string[]): asserts v is Record<string, unknown> {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).length !== keys.length
    || Reflect.ownKeys(v).some(k => typeof k !== "string" || !keys.includes(k))) throw Error("Expected exact object fields");
}
function list(v: unknown, maximum: number, size?: number): asserts v is readonly unknown[] {
  if (!Array.isArray(v) || v.length > maximum || (size !== undefined && v.length !== size) || Reflect.ownKeys(v).length !== v.length + 1
    || Array.from({ length: v.length }, (_, i) => i).some(i => !Object.hasOwn(v, i))) throw Error("Expected dense bounded array of original length");
}
function uint(v: unknown, bits = 256): bigint { if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`); return v; }
function address(v: unknown, nonzero = false): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (nonzero && a === ZeroAddress) throw Error("Expected nonzero address"); return a; }
function hex(v: unknown, width?: number): Hex { if (typeof v !== "string" || !isHexString(v, width ?? true)) throw Error("Expected original bytes width"); return v.toLowerCase() as Hex; }
function nonzero(v: Hex): void { if (v === ZeroHash) throw Error("Expected nonzero original identity"); }
function textValue(v: unknown): string {
  if (typeof v !== "string") throw Error("Expected UTF-8 text");
  for (const point of v) { const n = point.codePointAt(0)!; if (n >= 0xd800 && n <= 0xdfff) throw Error("Expected Unicode scalar text"); }
  toUtf8Bytes(v); return v;
}
function norm(p: ParamType, v: unknown): unknown {
  if (p.baseType === "array") { list(v, 4096, p.arrayLength === -1 ? undefined : p.arrayLength!); return Object.freeze(v.map(x => norm(p.arrayChildren!, x))); }
  if (p.baseType === "tuple") { exact(v, p.components!.map(c => c.name)); return Object.freeze(Object.fromEntries(p.components!.map(c => [c.name, norm(c, v[c.name])]))); }
  if (p.type.startsWith("uint")) return uint(v, Number(p.type.slice(4)));
  if (p.type === "address") return address(v);
  if (p.type === "bool") { if (typeof v !== "boolean") throw Error("Expected boolean"); return v; }
  if (p.type === "string") return textValue(v);
  return hex(v, p.type === "bytes" ? undefined : Number(p.type.slice(5)));
}
function normalize<T>(type: string, v: T): T { return norm(ParamType.from(type), v) as T; }
function plain(p: ParamType, v: any): unknown {
  if (p.baseType === "array") return Array.from(v, x => plain(p.arrayChildren!, x));
  if (p.baseType === "tuple") return Object.fromEntries(p.components!.map((c, i) => [c.name, plain(c, v[i])]));
  return v;
}
function decode<T>(types: readonly string[], raw: Hex): T {
  const bytes = hex(raw), values = coder.decode(types, bytes);
  const normalized = types.map((type, i) => { const p = ParamType.from(type); return norm(p, plain(p, values[i])); });
  if (coder.encode(types, normalized) !== bytes) throw Error("Noncanonical hydration ABI bytes");
  return normalized as T;
}
function hash(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function profile(v: ArtistHydrationProfile): ArtistHydrationProfile { if (!Object.hasOwn(ARTIST_HYDRATION_PROFILES, v)) throw Error("Unsupported hydration profile"); return v; }
function owner(v: ArtistHydrationOwnerIndex): ArtistHydrationOwnerIndex { if (!Number.isInteger(v) || v < 0 || v > 6) throw Error("Expected fixed owner index"); return v; }
function policies(p: readonly ArtistHydrationPolicyKey[]): void {
  list(p, 128); const seen = new Set<string>();
  for (const k of p) { nonzero(k.phaseId); nonzero(k.policyHash); const key = k.phaseId + k.policyHash; if (seen.has(key)) throw Error("Duplicate policy selector"); seen.add(key); }
}
export const normalizeArtistHydrationSnapshot = (v: ArtistHydrationSnapshot): ArtistHydrationSnapshot => normalize(ARTIST_HYDRATION_SNAPSHOT_TUPLE, v);
export const normalizeArtistHydrationCheckpoint = (v: ArtistHydrationCheckpoint): ArtistHydrationCheckpoint => normalize(ARTIST_HYDRATION_CHECKPOINT_TUPLE, v);
export const normalizeArtistHydrationSuite = (v: ArtistHydrationSuite): ArtistHydrationSuite => normalize(ARTIST_HYDRATION_SUITE_TUPLE, v);
export const normalizeArtistHydrationNativeReceipt = (v: ArtistHydrationNativeReceipt): ArtistHydrationNativeReceipt => normalize(ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE, v);
export const normalizeArtistHydrationNonceWord = (v: ArtistHydrationNonceWord): ArtistHydrationNonceWord => normalize(ARTIST_HYDRATION_NONCE_WORD_TUPLE, v);
export function normalizeArtistHydrationQuery(input: ArtistHydrationQuery): ArtistHydrationQuery {
  const q = normalize(ARTIST_HYDRATION_QUERY_TUPLE, input); policies(q.policies); list(q.records, 896); return q;
}
export function normalizeArtistHydrationOwnerData(input: ArtistHydrationOwnerData): ArtistHydrationOwnerData {
  const d = normalize(ARTIST_HYDRATION_OWNER_DATA_TUPLE, input);
  list(d.cells, 512); list(d.origins, 512, d.cells.length); list(d.sourceKeys, 512, d.cells.length); list(d.nonces, 256);
  const seen = new Set<Hex>();
  for (let i = 0; i < d.cells.length; i++) { nonzero(d.sourceKeys[i]!); if (seen.has(d.sourceKeys[i]!) || d.cells[i]!.status === 0n) throw Error("Invalid source replay cell"); seen.add(d.sourceKeys[i]!); }
  return d;
}
export function normalizeArtistAuthorityHydrationRequest(input: ArtistAuthorityHydrationRequest): ArtistAuthorityHydrationRequest {
  exact(input, ["kind", "request"]); const kind = profile(input.kind);
  const r = kind === "multiple" ? normalize(ARTIST_HYDRATION_MULTIPLE_REQUEST_TUPLE, input.request as ArtistMultipleHydrationRequest)
    : normalize(ARTIST_HYDRATION_SINGLE_REQUEST_TUPLE, input.request as ArtistSingleHydrationRequest);
  if (r.bindingIndex !== 0n) throw Error("Only first predecessor binding is supported");
  for (let i = 0; i < 7; i++) {
    const h = r.expectedSource[i]!; if (h.schema !== ARTIST_HYDRATION_CHECKPOINT_SCHEMA || h.replayCount > 512n || h.nonceIndexCount > (kind === "baseline" ? 1n : 128n)) throw Error("Unsupported source checkpoint");
    list(r.replayOrigins[i], 512, Number(h.replayCount));
  }
  if (kind === "multiple") {
    const m = r as ArtistMultipleHydrationRequest; list(m.artistIds, 128); list(m.collections, 128);
    if (!m.artistIds.length || !m.collections.length) throw Error("Empty multiple profile");
    let total = 0;
    m.artistIds.forEach((a, i) => { nonzero(a); if (i && BigInt(a) <= BigInt(m.artistIds[i - 1]!)) throw Error("Artist IDs must be strictly increasing");
      if (!m.collections.some(c => c.artistId === a)) throw Error("Artist missing from collection inventory"); });
    m.collections.forEach((c, i) => { if (c.collectionId === 0n || (i && c.collectionId <= m.collections[i - 1]!.collectionId)) throw Error("Collection IDs must be strictly increasing");
      if (!m.artistIds.includes(c.artistId)) throw Error("Collection references unknown Artist"); policies(c.policies); total += c.policies.length; });
    if (total > 128) throw Error("Too many policy selectors"); return Object.freeze({ kind, request: m });
  }
  const s = r as ArtistSingleHydrationRequest; nonzero(s.artistId); if (s.collectionId === 0n) throw Error("Expected collectionId"); policies(s.policies);
  return Object.freeze({ kind, request: s });
}
export function prepareArtistAuthorityHydrationCall(registry: Address, caller: Address, input: ArtistAuthorityHydrationRequest): ArtistAuthorityHydrationCall {
  const target = address(registry, true), actor = address(caller, true), normalized = normalizeArtistAuthorityHydrationRequest(input);
  return Object.freeze({ registry: target, caller: actor, input: normalized, profile: ARTIST_HYDRATION_PROFILES[normalized.kind],
    capabilityId: ARTIST_HYDRATION_CAPABILITY_IDS[normalized.kind], factsVerified: false,
    call: Object.freeze({ to: target, value: 0n, data: abi.encodeFunctionData(methods[normalized.kind], [normalized.request]) as Hex }) });
}
export function normalizeArtistAuthorityHydrationCall(input: ArtistAuthorityHydrationCall): ArtistAuthorityHydrationCall {
  exact(input, ["registry", "caller", "input", "profile", "capabilityId", "call", "factsVerified"]); exact(input.call, ["to", "value", "data"]);
  const p = prepareArtistAuthorityHydrationCall(input.registry, input.caller, input.input);
  if (hex(input.profile, 32) !== p.profile || hex(input.capabilityId, 4) !== p.capabilityId || input.factsVerified !== false
    || address(input.call.to) !== p.call.to || input.call.value !== 0n || hex(input.call.data) !== p.call.data) throw Error("Hydration call differs from original request");
  return p;
}
function validateIdentity(p: ArtistHydrationIdentity, single: boolean): void {
  if (p.item.authorityAddress === ZeroAddress || p.item.authorityClass !== 1n || p.item.status !== 1n || p.document === "0x"
    || keccak256(p.document) !== p.item.identityRecordHash || (single && p.nextRegistrationNonce !== 1n)) throw Error("Unsupported living Identity state");
  list(p.signatures, 896);
}
/** Original untagged Identity tuple, also used inside multiple bundles with their full allocator. */
export function encodeArtistHydrationIdentity(input: ArtistHydrationIdentity): Hex {
  const value = normalize(ARTIST_HYDRATION_IDENTITY_TUPLE, input); validateIdentity(value, false);
  return coder.encode([ARTIST_HYDRATION_IDENTITY_TUPLE], [value]) as Hex;
}
export function decodeArtistHydrationIdentity(raw: Hex): ArtistHydrationIdentity {
  const [value] = decode<[ArtistHydrationIdentity]>([ARTIST_HYDRATION_IDENTITY_TUPLE], raw); validateIdentity(value, false); return value;
}
function validateBinding(b: ArtistHydrationBinding, delegated: boolean): void {
  if (b.item.generation !== 1n || !b.item.accepted || (b.item.consentMode !== 1n && !(delegated && b.item.consentMode === 2n))
    || b.terms.count !== 0n || b.terms.mode !== 0n || b.terms.threshold !== 0n) throw Error("Unsupported generation-one PRIMARY_ONLY binding");
}
function stateType(p: ArtistHydrationProfile, i: ArtistHydrationOwnerIndex): string | null {
  if (i === 1 || i === 5) return null;
  if (p === "multiple") return ARTIST_HYDRATION_MULTIPLE_BUNDLE_TUPLE;
  if (i === 0) return ARTIST_HYDRATION_BINDING_TUPLE;
  if (i === 2) return p === "delegation" ? ARTIST_HYDRATION_DELEGATION_IDENTITY_TUPLE : ARTIST_HYDRATION_IDENTITY_TUPLE;
  if (i === 3) return ARTIST_HYDRATION_ACCEPTANCE_TUPLE;
  if (i === 4) return ARTIST_HYDRATION_ATTRIBUTION_TUPLE;
  return p === "delegation" ? ARTIST_HYDRATION_DELEGATION_CONSENT_TUPLE : "bytes32[]";
}
function validateState(p: ArtistHydrationProfile, i: ArtistHydrationOwnerIndex, value: any): void {
  if (p === "multiple") { validateMultiple(i, value); return; }
  if (i === 0) validateBinding(value, p === "delegation");
  if (i === 2 && p === "baseline") validateIdentity(value, true);
  if (i === 3 && (value.record === ZeroHash || value.acceptedAt === 0n)) throw Error("Invalid acceptance state");
  if (i === 4 && (value.state !== 2n || value.generation !== 1n)) throw Error("Unsupported attribution state");
  if (i === 6 && p === "baseline") { list(value, 128); value.forEach(v => nonzero(hex(v, 32))); }
  if (i === 2 && p === "delegation") {
    const v = value as ArtistHydrationDelegationIdentity;
    const [baseline] = decode<[ArtistHydrationIdentity]>([ARTIST_HYDRATION_IDENTITY_TUPLE], v.baseline); validateIdentity(baseline, true);
    if (v.epoch !== 0n) throw Error("Only original living delegation epoch is supported");
    list(v.revisions, 128); list(v.grants, 128); list(v.delegateNonces, 127);
    for (const row of v.revisions) if (row.document === "0x" || keccak256(row.document) !== row.item.revisedRecordHash || row.item.authorityClass !== 1n || row.item.signedAt === 0n) throw Error("Invalid original identity revision");
    for (const row of v.grants) { const g = row.item.grant;
      if (row.epoch !== 0n || g.delegate === ZeroAddress || g.delegate === row.item.grantor || g.capabilities === 0n || (g.capabilities & ~1143n) !== 0n
        || g.expiresAt <= g.notBefore || (g.maxUses !== 0n && row.item.uses > g.maxUses) || row.item.revoked !== (row.item.revocationRecordHash !== ZeroHash)) throw Error("Invalid historical grant"); }
    let prefixes = 0; for (const lane of v.delegateNonces) { list(lane.words, 256); if (!lane.words.length) throw Error("Empty delegate nonce lane"); prefixes += lane.words.length; }
    if (prefixes > 256) throw Error("Too many delegate nonce prefixes");
  }
  if (i === 6 && p === "delegation") {
    const v = value as ArtistHydrationDelegationConsent; list(v.policies, 128); list(v.sales, 128);
    if (v.policies.length + v.sales.length > 128) throw Error("Too many native consent records");
    v.policies.forEach(row => nonzero(row.recordHash));
    for (const row of v.sales) if (row.item.bindingGeneration !== 1n || row.item.signedAt === 0n || (row.item.authorityClass !== 1n && row.item.authorityClass !== 2n)) throw Error("Unsupported sale authority history");
  }
}
function validateMultiple(i: ArtistHydrationOwnerIndex, b: ArtistHydrationMultipleBundle): void {
  list(b.rows, 128); list(b.artistIds, 128); list(b.collectionIds, 128); if (!b.rows.length) throw Error("Empty multiple state");
  if (i === 2) {
    if (b.rows.length !== b.artistIds.length || b.registrationCount !== BigInt(b.artistIds.length) || !b.collectionIds.length) throw Error("Invalid multiple Identity inventory");
    b.artistIds.forEach((a, j) => { nonzero(a); if (j && BigInt(a) <= BigInt(b.artistIds[j - 1]!)) throw Error("Unordered multiple Artist IDs"); });
    b.collectionIds.forEach((c, j) => { if (c === 0n || (j && c <= b.collectionIds[j - 1]!)) throw Error("Unordered multiple collection IDs"); });
  } else if (b.artistIds.length || b.collectionIds.length || b.registrationCount !== 0n) throw Error("Unexpected collection-bundle identity inventory");
  let prefixes = 0;
  b.rows.forEach((row, j) => {
    normalizeArtistHydrationQuery(row.query); list(row.nonces, 256); prefixes += row.nonces.length;
    if (i === 2) {
      const [s] = decode<[ArtistHydrationIdentity]>([ARTIST_HYDRATION_IDENTITY_TUPLE], row.state); validateIdentity(s, false);
      if (row.query.artistId !== b.artistIds[j] || row.query.collectionId !== 0n || row.query.bindingHash !== ZeroHash || row.query.policies.length
        || !row.nonces.length || s.nextRegistrationNonce !== b.registrationCount || s.signatures.length !== row.query.records.length) throw Error("Invalid multiple Identity row");
    } else {
      nonzero(row.query.artistId); nonzero(row.query.bindingHash);
      if (row.query.collectionId === 0n || (j && row.query.collectionId <= b.rows[j - 1]!.query.collectionId)
        || row.nonces.length || row.query.records.length || (i !== 6 && row.query.policies.length)) throw Error("Invalid multiple collection row");
      const state = decodeArtistHydrationOwnerState("baseline", i, row.state);
      if (i === 0) { const b = state as ArtistHydrationBinding; if (b.item.artistId !== row.query.artistId || b.item.bindingHash !== row.query.bindingHash) throw Error("Binding/query mismatch"); }
      if (i === 6 && (state as readonly Hex[]).length !== row.query.policies.length) throw Error("Policy records differ from selectors");
    }
  });
  if (prefixes > 256) throw Error("Too many nonce prefixes");
}
export function encodeArtistHydrationOwnerState<P extends ArtistHydrationProfile, O extends ArtistHydrationOwnerIndex>(p: P, i: O, input: ArtistHydrationOwnerState<P, O>): Hex {
  profile(p); owner(i); const type = stateType(p, i);
  if (type === null) { if (input !== null) throw Error("Empty profile owner must be null"); return "0x"; }
  const value = normalize(type, input); validateState(p, i, value);
  const tag = p === "multiple" ? multipleTag : p === "delegation" ? delegationTags[i] : undefined;
  return coder.encode(tag ? ["bytes32", type] : [type], tag ? [tag, value] : [value]) as Hex;
}
export function decodeArtistHydrationOwnerState<P extends ArtistHydrationProfile, O extends ArtistHydrationOwnerIndex>(p: P, i: O, raw: Hex): ArtistHydrationOwnerState<P, O> {
  profile(p); owner(i); const type = stateType(p, i);
  if (type === null) { if (hex(raw) !== "0x") throw Error("Unsupported state in empty profile owner"); return null as ArtistHydrationOwnerState<P, O>; }
  const tag = p === "multiple" ? multipleTag : p === "delegation" ? delegationTags[i] : undefined;
  const values = decode<readonly unknown[]>(tag ? ["bytes32", type] : [type], raw);
  if (tag && values[0] !== tag) throw Error("Wrong hydration owner-state tag");
  const state = values[tag ? 1 : 0] as ArtistHydrationOwnerState<P, O>; validateState(p, i, state); return state;
}
export function encodeArtistHydrationMultipleBundle(i: Exclude<ArtistHydrationOwnerIndex, 1 | 5>, b: ArtistHydrationMultipleBundle): Hex { return encodeArtistHydrationOwnerState("multiple", i, b); }
export function decodeArtistHydrationMultipleBundle(i: Exclude<ArtistHydrationOwnerIndex, 1 | 5>, raw: Hex): ArtistHydrationMultipleBundle { return decodeArtistHydrationOwnerState("multiple", i, raw); }
function coordinates(input: ArtistAuthorityHydrationCoordinates): ArtistAuthorityHydrationCoordinates {
  exact(input, ["chainId", "registry", "coordinator", "predecessorRegistry", "sourceCoordinator"]);
  return Object.freeze({ chainId: uint(input.chainId), registry: address(input.registry, true), coordinator: address(input.coordinator, true),
    predecessorRegistry: address(input.predecessorRegistry, true), sourceCoordinator: address(input.sourceCoordinator, true) });
}
/** Original commitment anchor; multiple arrays remain bound in the original tagged owner bundles. */
export function artistAuthorityHydrationBaseRequest(input: ArtistAuthorityHydrationRequest): ArtistSingleHydrationRequest {
  const p = normalizeArtistAuthorityHydrationRequest(input); if (p.kind !== "multiple") return p.request;
  const first = p.request.collections[0]!;
  return Object.freeze({ bindingIndex: 0n, artistId: first.artistId, collectionId: first.collectionId,
    expectedSource: p.request.expectedSource, replayOrigins: p.request.replayOrigins, policies: first.policies });
}
function ownerData(profile: ArtistHydrationProfile, data: readonly ArtistHydrationOwnerData[]): ArtistHydrationSeven<ArtistHydrationOwnerData> {
  list(data, 7, 7); const result = data.map((v, i) => {
    const d = normalizeArtistHydrationOwnerData(v); decodeArtistHydrationOwnerState(profile, i as ArtistHydrationOwnerIndex, d.typedState);
    if ((i !== 2 || profile === "multiple") && d.nonces.length) throw Error("Nonce words on wrong owner/profile"); return d;
  });
  return Object.freeze(result) as unknown as ArtistHydrationSeven<ArtistHydrationOwnerData>;
}
function profileJoins(p: ArtistAuthorityHydrationRequest, q: ArtistHydrationQuery, d: ArtistHydrationSeven<ArtistHydrationOwnerData>): void {
  if (p.kind === "multiple") {
    const identities = decodeArtistHydrationMultipleBundle(2, d[2].typedState), r = p.request;
    if (coder.encode(["bytes32[]", "uint256[]"], [identities.artistIds, identities.collectionIds])
      !== coder.encode(["bytes32[]", "uint256[]"], [r.artistIds, r.collections.map(c => c.collectionId)])) throw Error("Multiple state differs from complete request inventory");
    for (const i of [0, 3, 4, 6] as const) {
      const b = decodeArtistHydrationMultipleBundle(i, d[i].typedState);
      if (b.rows.length !== r.collections.length) throw Error("Incomplete multiple collection state");
      b.rows.forEach((row, j) => {
        const c = r.collections[j]!;
        if (row.query.artistId !== c.artistId || row.query.collectionId !== c.collectionId
          || (j === 0 && row.query.bindingHash !== q.bindingHash)
          || (i === 6 && coder.encode([`${ARTIST_HYDRATION_POLICY_TUPLE}[]`], [row.query.policies]) !== coder.encode([`${ARTIST_HYDRATION_POLICY_TUPLE}[]`], [c.policies]))) throw Error("Multiple collection query differs from request");
      });
    }
    return;
  }
  const b = decodeArtistHydrationOwnerState(p.kind, 0, d[0].typedState);
  const identity = p.kind === "baseline" ? decodeArtistHydrationOwnerState("baseline", 2, d[2].typedState)
    : decodeArtistHydrationIdentity(decodeArtistHydrationOwnerState("delegation", 2, d[2].typedState).baseline);
  if (b.item.artistId !== q.artistId || b.item.bindingHash !== q.bindingHash || b.item.artistAddress !== identity.item.authorityAddress
    || b.item.identityRecordHash !== identity.item.identityRecordHash || identity.signatures.length !== q.records.length || !d[2].nonces.length) throw Error("Incomplete single-profile Identity/binding join");
  const n = p.kind === "baseline" ? decodeArtistHydrationOwnerState("baseline", 6, d[6].typedState).length
    : decodeArtistHydrationOwnerState("delegation", 6, d[6].typedState).policies.length;
  if (n !== q.policies.length) throw Error("Policy records differ from selectors");
  if (p.kind === "delegation") {
    const state = decodeArtistHydrationOwnerState("delegation", 2, d[2].typedState);
    if (d[2].nonces.length + state.delegateNonces.reduce((total, lane) => total + lane.words.length, 0) > 256) throw Error("Too many total nonce prefixes");
  }
}
/** Pure supplied-facts recomputation. It cannot establish source completeness or authorize hydration. */
export function artistAuthorityHydrationCommitment(input: ArtistAuthorityHydrationCoordinates, request: ArtistAuthorityHydrationRequest,
  query: ArtistHydrationQuery, data: readonly ArtistHydrationOwnerData[]): Hex {
  const c = coordinates(input), p = normalizeArtistAuthorityHydrationRequest(request), base = artistAuthorityHydrationBaseRequest(p), q = normalizeArtistHydrationQuery(query), d = ownerData(p.kind, data);
  if (q.artistId !== base.artistId || q.collectionId !== base.collectionId || q.bindingHash === ZeroHash
    || coder.encode([`${ARTIST_HYDRATION_POLICY_TUPLE}[]`], [q.policies]) !== coder.encode([`${ARTIST_HYDRATION_POLICY_TUPLE}[]`], [base.policies])
    || (p.kind === "multiple" && q.records.length)) throw Error("Hydration query differs from request anchor");
  for (let i = 0; i < 7; i++) if (coder.encode([`${ARTIST_HYDRATION_ORIGIN_TUPLE}[]`], [d[i]!.origins]) !== coder.encode([`${ARTIST_HYDRATION_ORIGIN_TUPLE}[]`], [base.replayOrigins[i]])) throw Error("Replay origins differ from request");
  profileJoins(p, q, d);
  return hash(["bytes32", "uint256", "address", "address", "address", "address", ARTIST_HYDRATION_SINGLE_REQUEST_TUPLE, ARTIST_HYDRATION_QUERY_TUPLE, `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`],
    [ARTIST_HYDRATION_PROFILES[p.kind], c.chainId, c.registry, c.coordinator, c.predecessorRegistry, c.sourceCoordinator, base, q, d]);
}
function environment(v: ArtistHydrationOwnerEnvironment): ArtistHydrationOwnerEnvironment {
  exact(v, ["chainId", "registry", "coordinator", "archive", "owner", "domain"]);
  return Object.freeze({ chainId: uint(v.chainId), registry: address(v.registry, true), coordinator: address(v.coordinator, true), archive: address(v.archive, true), owner: address(v.owner, true), domain: hex(v.domain, 32) });
}
export function artistAuthorityHydrationReplayKey(input: ArtistHydrationOwnerEnvironment, origin: ArtistHydrationOrigin): Hex {
  const e = environment(input), o = normalize(ARTIST_HYDRATION_ORIGIN_TUPLE, origin);
  return hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), e.chainId, e.registry, e.coordinator, e.archive, e.owner, e.domain, o.surface, o.scope]);
}
export function artistAuthorityHydrationReplayDelta(input: ArtistHydrationOwnerEnvironment, data: ArtistHydrationOwnerData): Hex {
  const e = environment(input), d = normalizeArtistHydrationOwnerData(data); let delta = ZeroHash as Hex; const keys = new Set<Hex>();
  for (let i = 0; i < d.origins.length; i++) {
    const o = d.origins[i]!, terminal = o.surface === id("identity_authority.replay.one_way_cutover_latch");
    if (terminal && (e.domain !== id("domain:identity_authority") || o.scope !== ZeroHash)) throw Error("Invalid historical cutover latch");
    const key = terminal ? d.sourceKeys[i]! : artistAuthorityHydrationReplayKey(e, o);
    if (!terminal && keys.has(key)) throw Error("Duplicate successor replay key"); keys.add(key);
    delta = hash(["bytes32", "bytes32", ARTIST_HYDRATION_REPLAY_CELL_TUPLE], [delta, key, d.cells[i]]);
  }
  return delta;
}
/** Predicts the original one-step owner accumulator; record-chain tip is unchanged for op60. */
export function artistAuthorityHydrationOwnerAfter(input: ArtistHydrationOwnerEnvironment, before: ArtistHydrationSnapshot, actor: Address,
  query: ArtistHydrationQuery, data: ArtistHydrationOwnerData, commitment: Hex): ArtistHydrationSnapshot {
  const e = environment(input), b = normalizeArtistHydrationSnapshot(before), a = address(actor, true), q = normalizeArtistHydrationQuery(query), d = normalizeArtistHydrationOwnerData(data), value = hex(commitment, 32); nonzero(value);
  if (b.domainId !== e.domain) throw Error("Owner snapshot domain mismatch"); const revision = uint(b.revision + 1n, 64);
  const stateRoot = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), e.chainId, e.registry, e.coordinator, e.archive, e.owner, e.domain, b.revision, revision, b.stateRoot,
      hash(["uint16", "address", "bytes32"], [60n, a, value]), hash([ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, "bytes32"], [q, d, value]),
      artistAuthorityHydrationReplayDelta(e, d), hash(["bytes32"], [ZeroHash])]);
  return Object.freeze({ domainId: b.domainId, revision, stateRoot, recordChainTip: b.recordChainTip });
}
export function artistAuthorityHydrationEvidenceId(input: ArtistAuthorityHydrationCoordinates, actor: Address, commitment: Hex): Hex {
  const c = coordinates(input), a = address(actor, true), value = hex(commitment, 32); nonzero(value);
  return hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.registry, c.coordinator, 60n, a, value]);
}
const profileTypes = ["bytes32", "address", "address", `${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7]`, ARTIST_HYDRATION_QUERY_TUPLE, `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`];
const evidenceTypes = ["uint16", "bytes32", "uint16", "address", "bytes32", `${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, `${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, "bytes"];
export function encodeArtistAuthorityHydrationProfileEvidence(input: ArtistAuthorityHydrationProfileEvidence): Hex {
  exact(input, ["profile", "predecessorRegistry", "sourceCoordinator", "expectedSource", "query", "ownerData"]);
  const selected = (Object.keys(ARTIST_HYDRATION_PROFILES) as ArtistHydrationProfile[]).find(p => ARTIST_HYDRATION_PROFILES[p] === hex(input.profile, 32));
  if (!selected) throw Error("Unsupported hydration evidence profile");
  const headers = normalize(`${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7]`, input.expectedSource), q = normalizeArtistHydrationQuery(input.query), d = ownerData(selected, input.ownerData);
  return coder.encode(profileTypes, [ARTIST_HYDRATION_PROFILES[selected], address(input.predecessorRegistry, true), address(input.sourceCoordinator, true), headers, q, d]) as Hex;
}
export function decodeArtistAuthorityHydrationProfileEvidence(raw: Hex): ArtistAuthorityHydrationProfileEvidence {
  const [profile, predecessorRegistry, sourceCoordinator, expectedSource, query, ownerData] = decode<readonly [Hex, Address, Address, ArtistHydrationSeven<ArtistHydrationCheckpoint>, ArtistHydrationQuery, ArtistHydrationSeven<ArtistHydrationOwnerData>]>(profileTypes, raw);
  const value = Object.freeze({ profile, predecessorRegistry, sourceCoordinator, expectedSource, query, ownerData });
  encodeArtistAuthorityHydrationProfileEvidence(value); return value;
}
/** Checks the complete eight-field Archive carrier, not merely its inner profile bytes. */
export function encodeArtistAuthorityHydrationEvidence(input: ArtistAuthorityHydrationEvidence, maximumBytes: bigint = ARTIST_HYDRATION_MAX_EVIDENCE_BYTES): Hex {
  exact(input, ["schemaVersion", "configurationHash", "operationId", "actor", "commitment", "before", "after", "profileData"]);
  if (input.schemaVersion !== 1n || input.operationId !== 60n) throw Error("Expected original operation60 evidence");
  const before = normalize(`${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, input.before), after = normalize(`${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, input.after);
  const profileData = hex(input.profileData); decodeArtistAuthorityHydrationProfileEvidence(profileData);
  const value = hex(input.commitment, 32); nonzero(value);
  const encoded = coder.encode(evidenceTypes, [1n, hex(input.configurationHash, 32), 60n, address(input.actor, true), value, before, after, profileData]) as Hex;
  if (uint(maximumBytes) > ARTIST_HYDRATION_MAX_EVIDENCE_BYTES || BigInt((encoded.length - 2) / 2) > maximumBytes) throw Error("Complete hydration evidence exceeds Archive carrier");
  return encoded;
}
export function decodeArtistAuthorityHydrationEvidence(raw: Hex, maximumBytes: bigint = ARTIST_HYDRATION_MAX_EVIDENCE_BYTES): ArtistAuthorityHydrationEvidence {
  const [schemaVersion, configurationHash, operationId, actor, commitment, before, after, profileData] = decode<readonly [bigint, Hex, bigint, Address, Hex, ArtistHydrationSeven<ArtistHydrationSnapshot>, ArtistHydrationSeven<ArtistHydrationSnapshot>, Hex]>(evidenceTypes, raw);
  const value = Object.freeze({ schemaVersion, configurationHash, operationId, actor, commitment, before, after, profileData });
  encodeArtistAuthorityHydrationEvidence(value, maximumBytes); return value;
}
