import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { prepareCurrentArtistOperation, type CurrentCollaboratorIdentityAcceptance, type CurrentCollaboratorAcceptance, type PreparedCurrentArtistOperation } from "./current-artist.js";

/** Original operations 5–7 only. Full compiler witness is reused, not regenerated. */
export const COLLABORATOR_SOURCE = "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b";
export const COLLABORATOR_FIXTURE_SHA256 = "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9";
export const COLLABORATOR_INTEGRATION = "4fd8017505c979da6d8545900b8d6cf5b42003fa";
export interface CollaboratorIdentityProposal {
  readonly account: Address; readonly identityRecordHash: Hex; readonly identityRecordURI: string;
  readonly reasonHash: Hex; readonly reasonURI: string;
}
export interface CollaboratorIdentityProposalState {
  readonly proposal: CollaboratorIdentityProposal; readonly proposer: Address; readonly proposalHash: Hex; readonly acceptedArtistId: Hex;
}
export interface CollaboratorAuthorization { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex }
export interface CollaboratorTerm { readonly account: Address; readonly role: Hex; readonly shareLabelId: Hex }
export interface CollaboratorBindingAcceptance extends CollaboratorTerm {
  readonly collectionId: bigint; readonly generation: bigint; readonly bindingHash: Hex;
}
export interface CollaboratorRow extends CollaboratorTerm {
  readonly collaboratorArtistId: Hex; readonly acceptanceRecordHash: Hex; readonly accepted: boolean;
}
export interface CollaboratorBindingTerms {
  readonly collaboratorSetHash: Hex; readonly capabilityPolicySetHash: Hex; readonly mode: bigint; readonly threshold: bigint; readonly count: bigint;
}
export interface CollaboratorBinding {
  readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex;
  readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint;
  readonly proposer: Address; readonly accepted: boolean;
}
interface Context { readonly chainId: bigint; readonly registry: Address; readonly caller: Address }
export type CollaboratorRequest = Context & (
  | { readonly kind: "proposeIdentity"; readonly proposal: CollaboratorIdentityProposal }
  | { readonly kind: "acceptIdentity"; readonly account: Address; readonly identityRecordHash: Hex;
      readonly authorization: CollaboratorAuthorization; readonly document: Hex; readonly displayName: string }
  | { readonly kind: "acceptRow"; readonly core: Address; readonly terms: CollaboratorBindingAcceptance; readonly authorization: CollaboratorAuthorization }
);
export interface PreparedCollaborator {
  readonly request: CollaboratorRequest; readonly operation: 5 | 6 | 7; readonly call: UnsignedCall;
  /** Existing permanent current-artist.ts signing payloads, not new signature schemas. */
  readonly signing: PreparedCurrentArtistOperation<CurrentCollaboratorIdentityAcceptance | CurrentCollaboratorAcceptance> | null;
  readonly factsVerified: false;
}
export const COLLABORATOR_PROPOSAL_TUPLE = "(address account,bytes32 identityRecordHash,string identityRecordURI,bytes32 reasonHash,string reasonURI)";
export const COLLABORATOR_PROPOSAL_STATE_TUPLE = `(${COLLABORATOR_PROPOSAL_TUPLE} proposal,address proposer,bytes32 proposalHash,bytes32 acceptedArtistId)`;
export const COLLABORATOR_AUTHORIZATION_TUPLE = "(uint256 nonce,uint64 time,bytes signature)";
export const COLLABORATOR_TERM_TUPLE = "(address account,bytes32 role,bytes32 shareLabelId)";
export const COLLABORATOR_ACCEPTANCE_TUPLE = "(uint256 collectionId,uint64 generation,bytes32 bindingHash,address account,bytes32 role,bytes32 shareLabelId)";
export const COLLABORATOR_ROW_TUPLE = "(address account,bytes32 role,bytes32 shareLabelId,bytes32 collaboratorArtistId,bytes32 acceptanceRecordHash,bool accepted)";
export const COLLABORATOR_BINDING_TERMS_TUPLE = "(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count)";
export const COLLABORATOR_BINDING_TUPLE = "(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
export const CURRENT_ARTIST_COLLABORATOR_ABI = Object.freeze([
  `function proposeCollaboratorIdentity(${COLLABORATOR_PROPOSAL_TUPLE}) returns(bytes32)`,
  `function acceptCollaboratorIdentity(address account,bytes32 identityRecordHash,${COLLABORATOR_AUTHORIZATION_TUPLE},bytes document,string displayName) returns(bytes32)`,
  `function acceptCollaborator(${COLLABORATOR_ACCEPTANCE_TUPLE},${COLLABORATOR_AUTHORIZATION_TUPLE}) returns(bytes32)`,
  `function collaboratorIdentityDigest(address account,bytes32 identityRecordHash,${COLLABORATOR_AUTHORIZATION_TUPLE}) view returns(bytes32)`,
  `function collaboratorAcceptanceDigest(${COLLABORATOR_ACCEPTANCE_TUPLE},${COLLABORATOR_AUTHORIZATION_TUPLE}) view returns(bytes32)`,
  `function collaboratorIdentityProposal(address account,bytes32 identityRecordHash) view returns(${COLLABORATOR_PROPOSAL_STATE_TUPLE})`,
  "function collaboratorRegistrationNonceState(address account,uint256 nonce) view returns(bool used,uint256 firstUnused)",
  "function collaboratorCount(uint256 collectionId,uint64 generation) view returns(uint256)",
  `function collaboratorAt(uint256 collectionId,uint64 generation,uint256 index) view returns(${COLLABORATOR_ROW_TUPLE})`,
  "function collaboratorPayoutAccount(bytes32 artistId,address account) view returns(address payoutAccount,bytes32 designationRecordHash)",
  "event CollaboratorIdentityProposed(uint16 schemaVersion,address indexed account,bytes32 identityRecordHash,string identityRecordURI,address proposer,bytes32 reasonHash,string reasonURI)",
]);
const abi = new Interface(CURRENT_ARTIST_COLLABORATOR_ABI), coder = AbiCoder.defaultAbiCoder();
function keys(v: unknown, names: readonly string[]): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).length !== names.length
    || Object.keys(v).sort().join(",") !== [...names].sort().join(",")) throw Error("Unexpected collaborator fields");
}
function uint(v: unknown, bits = 256, positive = false): bigint {
  if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return v;
}
function address(v: unknown): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address; if (a === ZeroAddress) throw Error("Zero address"); return a;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function text(v: unknown, maximum: number, nonempty = false): string {
  if (typeof v !== "string") throw Error("Expected UTF-8 text");
  const length = toUtf8Bytes(v).length;
  if (length > maximum || (nonempty && length === 0)) throw Error("Text byte bound exceeded"); return v;
}
function freeze<T>(v: T): T { if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); } return v; }
function stable(v: any): string {
  if (typeof v === "bigint") return `bigint:${v}`;
  if (Array.isArray(v)) return `[${v.map(stable).join(",")}]`;
  if (v && typeof v === "object") return `{${Object.keys(v).sort().map(k => `${k}:${stable(v[k])}`).join(",")}}`;
  return JSON.stringify(v);
}
export function normalizeCollaboratorProposal(v: CollaboratorIdentityProposal): CollaboratorIdentityProposal {
  keys(v, ["account", "identityRecordHash", "identityRecordURI", "reasonHash", "reasonURI"]);
  return freeze({ account: address(v.account), identityRecordHash: hash(v.identityRecordHash), identityRecordURI: text(v.identityRecordURI, 2048),
    reasonHash: hash(v.reasonHash), reasonURI: text(v.reasonURI, 2048) });
}
export function normalizeCollaboratorAuthorization(v: CollaboratorAuthorization): CollaboratorAuthorization {
  keys(v, ["nonce", "time", "signature"]);
  if (typeof v.signature !== "string" || !isHexString(v.signature, true) || v.signature.length > 8194) throw Error("Invalid bounded signature");
  return freeze({ nonce: uint(v.nonce), time: uint(v.time, 64, true), signature: v.signature.toLowerCase() as Hex });
}
export function normalizeCollaboratorAcceptance(v: CollaboratorBindingAcceptance): CollaboratorBindingAcceptance {
  keys(v, ["collectionId", "generation", "bindingHash", "account", "role", "shareLabelId"]);
  return freeze({ collectionId: uint(v.collectionId, 256, true), generation: uint(v.generation, 64, true), bindingHash: hash(v.bindingHash),
    account: address(v.account), role: hash(v.role, true), shareLabelId: hash(v.shareLabelId, true) });
}
/** Exact source ordering is (account,role), with no duplicate pair even when labels differ. */
export function normalizeCollaboratorTerms(input: readonly CollaboratorTerm[]): readonly CollaboratorTerm[] {
  if (!Array.isArray(input) || input.length > 32 || Reflect.ownKeys(input).length !== input.length + 1) throw Error("Expected dense collaborator terms, at most 32");
  const rows = input.map(v => { keys(v, ["account", "role", "shareLabelId"]); return { account: address(v.account), role: hash(v.role, true), shareLabelId: hash(v.shareLabelId, true) }; });
  for (let i = 1; i < rows.length; i++) {
    const p = rows[i - 1]!, r = rows[i]!;
    if (BigInt(r.account) < BigInt(p.account) || r.account === p.account && BigInt(r.role) <= BigInt(p.role)) throw Error("Collaborator terms must be strictly sorted by account and role");
  }
  return freeze(rows);
}
/** The existing current Artist helper remains the sole signing implementation for 6/7. */
export function prepareCollaboratorCall(input: CollaboratorRequest): PreparedCollaborator {
  if (!input || typeof input !== "object") throw Error("Expected collaborator request");
  const common = ["kind", "chainId", "registry", "caller"], context = { chainId: uint(input.chainId, 256, true), registry: address(input.registry), caller: address(input.caller) };
  let request: CollaboratorRequest, operation: 5 | 6 | 7, call: UnsignedCall, signing: PreparedCollaborator["signing"] = null;
  if (input.kind === "proposeIdentity") {
    keys(input, [...common, "proposal"]);
    const proposal = normalizeCollaboratorProposal(input.proposal);
    request = { ...context, kind: input.kind, proposal }; operation = 5;
    call = { to: context.registry, data: abi.encodeFunctionData("proposeCollaboratorIdentity", [proposal]) as Hex, value: 0n };
  } else if (input.kind === "acceptIdentity") {
    keys(input, [...common, "account", "identityRecordHash", "authorization", "document", "displayName"]);
    const account = address(input.account), identityRecordHash = hash(input.identityRecordHash), authorization = normalizeCollaboratorAuthorization(input.authorization);
    if (!isHexString(input.document, true) || input.document.length <= 2 || input.document.length > 16386 || keccak256(input.document) !== identityRecordHash) throw Error("Identity document must match its hash and contain 1..8192 bytes");
    const document = input.document.toLowerCase() as Hex, displayName = text(input.displayName, 256, true);
    request = { ...context, kind: input.kind, account, identityRecordHash, authorization, document, displayName }; operation = 6;
    signing = prepareCurrentArtistOperation("collaboratorIdentityAcceptance", context.chainId, context.registry,
      { account, identityRecordHash, nonce: authorization.nonce, deadline: authorization.time }, { signature: authorization.signature, document, displayName });
    call = signing.call;
  } else if (input.kind === "acceptRow") {
    keys(input, [...common, "core", "terms", "authorization"]);
    const core = address(input.core), terms = normalizeCollaboratorAcceptance(input.terms), authorization = normalizeCollaboratorAuthorization(input.authorization);
    request = { ...context, kind: input.kind, core, terms, authorization }; operation = 7;
    signing = prepareCurrentArtistOperation("collaboratorAcceptance", context.chainId, context.registry,
      { core, collectionId: terms.collectionId, bindingGeneration: terms.generation, bindingHash: terms.bindingHash, collaborator: terms.account,
        role: terms.role, shareLabelId: terms.shareLabelId, nonce: authorization.nonce, deadline: authorization.time }, { signature: authorization.signature });
    call = signing.call;
  } else throw Error("Unsupported collaborator operation");
  return freeze({ request, operation, call, signing, factsVerified: false as const });
}
export function normalizeCollaboratorCall(v: PreparedCollaborator): PreparedCollaborator {
  keys(v, ["request", "operation", "call", "signing", "factsVerified"]);
  const clean = prepareCollaboratorCall(v.request);
  if (stable(v) !== stable(clean)) throw Error("Changed collaborator call"); return clean;
}
export function collaboratorProposalHash(chainId: bigint, registry: Address, proposal: CollaboratorIdentityProposal, proposer: Address): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", COLLABORATOR_PROPOSAL_TUPLE, "address"],
    [id("6529STREAM_COLLABORATOR_IDENTITY_PROPOSAL_V1"), uint(chainId, 256, true), address(registry), normalizeCollaboratorProposal(proposal), address(proposer)])) as Hex;
}
/** Allocation nonce is the global registration counter, not the account's authorization nonce. */
export function collaboratorIdentityId(chainId: bigint, registry: Address, account: Address, identityRecordHash: Hex, allocationNonce: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "uint256"],
    [id("6529STREAM_ARTIST_ID_V1"), uint(chainId, 256, true), address(registry), address(account), hash(identityRecordHash), uint(allocationNonce)])) as Hex;
}
/** Acceptance belongs to the collaborator's own current principal class, not the collection's primary Artist. */
export function collaboratorAcceptanceRecordHash(chainId: bigint, registry: Address, core: Address, terms: CollaboratorBindingAcceptance, authorityClass: bigint, nonce: bigint, observed: bigint): Hex {
  const p = normalizeCollaboratorAcceptance(terms);
  if (![1n, 3n, 4n].includes(authorityClass)) throw Error("Expected original principal authority class");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "uint8", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"), uint(chainId, 256, true), address(registry), address(core), p.collectionId, p.generation, p.bindingHash, 2, p.account, authorityClass, uint(nonce), uint(observed, 64, true)])) as Hex;
}
export function collaboratorSetHash(rows: readonly CollaboratorTerm[]): Hex {
  return keccak256(coder.encode(["bytes32", `${COLLABORATOR_TERM_TUPLE}[]`], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), normalizeCollaboratorTerms(rows)])) as Hex;
}
/** Fixed original PRIMARY_ONLY terms; no multiparty threshold or capability-policy input exists here. */
export function primaryOnlyCollaboratorBindingHash(chainId: bigint, registry: Address, core: Address, collectionId: bigint, b: CollaboratorBinding, rows: readonly CollaboratorTerm[]): Hex {
  keys(b, ["artistId", "artistAddress", "identityRecordHash", "bindingHash", "generation", "consentMode", "saleConsentScope", "registryImmutabilityElection", "proposer", "accepted"]);
  hash(b.bindingHash, true); address(b.proposer);
  if (typeof b.accepted !== "boolean") throw Error("Expected binding acceptance boolean");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "uint8", "uint32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), uint(chainId, 256, true), address(registry), address(core), uint(collectionId, 256, true), uint(b.generation, 64, true), hash(b.artistId), address(b.artistAddress), hash(b.identityRecordHash),
      uint(b.consentMode, 8), uint(b.saleConsentScope, 8), uint(b.registryImmutabilityElection, 8), 0, 0, collaboratorSetHash(rows),
      keccak256(coder.encode(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []]))])) as Hex;
}
export interface CollaboratorReads {
  collaboratorIdentityProposal: { args: readonly [Address, Hex]; result: CollaboratorIdentityProposalState };
  collaboratorRegistrationNonceState: { args: readonly [Address, bigint]; result: { readonly used: boolean; readonly firstUnused: bigint } };
  collaboratorCount: { args: readonly [bigint, bigint]; result: bigint };
  collaboratorAt: { args: readonly [bigint, bigint, bigint]; result: CollaboratorRow };
  collaboratorPayoutAccount: { args: readonly [Hex, Address]; result: { readonly payoutAccount: Address; readonly designationRecordHash: Hex } };
}
const readMethods = ["collaboratorIdentityProposal", "collaboratorRegistrationNonceState", "collaboratorCount", "collaboratorAt", "collaboratorPayoutAccount"] as const;
function readMethod(method: string): void { if (!(readMethods as readonly string[]).includes(method)) throw Error("Unsupported collaborator read"); }
export function prepareCollaboratorRead<K extends keyof CollaboratorReads>(registry: Address, method: K, args: CollaboratorReads[K]["args"]): UnsignedCall {
  readMethod(method);
  if (!Array.isArray(args) || args.length !== (method === "collaboratorAt" ? 3 : 2)) throw Error("Invalid collaborator read arguments");
  const values = method === "collaboratorIdentityProposal" ? [address(args[0]), hash(args[1])]
    : method === "collaboratorRegistrationNonceState" ? [address(args[0]), uint(args[1])]
    : method === "collaboratorPayoutAccount" ? [hash(args[0]), address(args[1])]
    : [uint(args[0], 256, true), uint(args[1], 64, true), ...(method === "collaboratorAt" ? [uint(args[2])] : [])];
  return freeze({ to: address(registry), data: abi.encodeFunctionData(method, values) as Hex, value: 0n });
}
function plain(t: ParamType, v: any): any {
  if (t.baseType === "array") return Array.from(v, x => plain(t.arrayChildren!, x));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((c, i) => [c.name, plain(c, v[i])])); return v;
}
/** Canonical decoding does not establish live generation, authority or payout entitlement. */
export function decodeCollaboratorRead<K extends keyof CollaboratorReads>(method: K, raw: Hex): CollaboratorReads[K]["result"] {
  readMethod(method);
  if (!isHexString(raw, true) || raw.length > 32770) throw Error("Malformed or oversized collaborator result");
  const values = abi.decodeFunctionResult(method, raw), fields = abi.getFunction(method)!.outputs;
  if (abi.encodeFunctionResult(method, values).toLowerCase() !== raw.toLowerCase()) throw Error("Noncanonical collaborator result");
  return freeze(fields.length === 1 ? plain(fields[0]!, values[0]) : Object.fromEntries(fields.map((f, i) => [f.name, plain(f, values[i])]))) as CollaboratorReads[K]["result"];
}
