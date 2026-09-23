import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

/** Original operations 28–32. ABI evidence is c636, not a deployment approval. */
export const GUARDIAN_ROTATION_SOURCE = "c636a5f176c5765d80d15ee20f41355a8911ea9c";
export const GUARDIAN_ROTATION_INTEGRATION = "9a1a3d299d796a3907c58fb68a497bd9fb8ab457";
export const GUARDIAN_ROTATION_FIXTURE_SHA256 = "fd13d766e7358355e995f1ec9ef6db3010eca5383f2506b0963c3c49916a8463";
export interface ArtistGuardianSet {
  readonly artistId: Hex; readonly guardians: readonly Address[];
  readonly approvalThreshold: bigint; readonly minContestSeconds: bigint;
}
export interface ArtistRotationTerms {
  readonly artistId: Hex; readonly oldAddress: Address; readonly newAddress: Address;
  readonly reasonHash: Hex; readonly expectedPreviousTransitionRecordHash: Hex;
}
/** time is signedAt for guardian sets, deadline for each rotation side. */
export interface ArtistRotationAuthorization { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex }
export interface ArtistRotationTransition {
  readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint;
  readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint;
}
export interface ArtistRotationAssociation { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint }
export interface ArtistGuardianRecord {
  readonly recordHash: Hex; readonly terms: ArtistGuardianSet; readonly signer: Address; readonly authorityClass: bigint;
  readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: ArtistRotationAssociation;
}
export interface ArtistRotationRecord {
  readonly recordHash: Hex; readonly terms: ArtistRotationTerms; readonly guardianSetRecordHash: Hex;
  readonly approvalThreshold: bigint; readonly guardianApprovals: bigint; readonly oldNonce: bigint; readonly newNonce: bigint;
  readonly effectiveWindow: bigint; readonly standingTail: bigint; readonly timingRevision: bigint; readonly transition: ArtistRotationTransition;
}
interface GuardianRotationContext { readonly chainId: bigint; readonly registry: Address; readonly caller: Address }
export type GuardianRotationRequest = GuardianRotationContext & (
  | { readonly kind: "setGuardians"; readonly terms: ArtistGuardianSet; readonly authorization: ArtistRotationAuthorization }
  | { readonly kind: "stageRotation"; readonly terms: ArtistRotationTerms; readonly oldAuthorization: ArtistRotationAuthorization; readonly newAuthorization: ArtistRotationAuthorization }
  | { readonly kind: "approveRotation" | "executeRotation"; readonly artistId: Hex; readonly expectedRotationRecordHash: Hex }
  | { readonly kind: "vetoRotation"; readonly artistId: Hex; readonly expectedRotationRecordHash: Hex; readonly reasonHash: Hex }
);
export interface ArtistGuardianSetMessage extends ArtistGuardianSet { readonly nonce: bigint; readonly signedAt: bigint }
export interface ArtistRotationMessage {
  readonly artistId: Hex; readonly oldAddress: Address; readonly newAddress: Address; readonly reasonHash: Hex;
  readonly nonce: bigint; readonly deadline: bigint;
}
export type ArtistRotationAcceptanceMessage = Omit<ArtistRotationMessage, "reasonHash">;
export interface GuardianRotationSigning {
  readonly side: "principal" | "acceptance";
  /** Guardian signer is selected from actual authority state during capture. */
  readonly signer?: Address;
  readonly digest: Hex;
  readonly typedData: SigningPayload<ArtistGuardianSetMessage | ArtistRotationMessage | ArtistRotationAcceptanceMessage>;
  readonly nonceLane: { readonly kind: 1 | 4; readonly scope: Hex };
  readonly digestCall: UnsignedCall;
}
export interface PreparedGuardianRotation {
  readonly request: GuardianRotationRequest; readonly operation: 28 | 29 | 30 | 31 | 32;
  readonly call: UnsignedCall; readonly signing: readonly GuardianRotationSigning[]; readonly factsVerified: false;
}

export const ARTIST_GUARDIAN_SET_TUPLE = "(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds)";
export const ARTIST_ROTATION_TERMS_TUPLE = "(bytes32 artistId,address oldAddress,address newAddress,bytes32 reasonHash,bytes32 expectedPreviousTransitionRecordHash)";
export const ARTIST_ROTATION_AUTHORIZATION_TUPLE = "(uint256 nonce,uint64 time,bytes signature)";
export const ARTIST_ROTATION_TRANSITION_TUPLE = "(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase)";
export const ARTIST_ROTATION_ASSOCIATION_TUPLE = "(bytes32 transitionRecordHash,uint64 windowEndsAt)";
export const ARTIST_GUARDIAN_RECORD_TUPLE = `(bytes32 recordHash,${ARTIST_GUARDIAN_SET_TUPLE} terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,${ARTIST_ROTATION_ASSOCIATION_TUPLE} provisional)`;
export const ARTIST_ROTATION_RECORD_TUPLE = `(bytes32 recordHash,${ARTIST_ROTATION_TERMS_TUPLE} terms,bytes32 guardianSetRecordHash,uint32 approvalThreshold,uint32 guardianApprovals,uint256 oldNonce,uint256 newNonce,uint64 effectiveWindow,uint64 standingTail,uint64 timingRevision,${ARTIST_ROTATION_TRANSITION_TUPLE} transition)`;
export const CURRENT_ARTIST_GUARDIAN_ROTATION_ABI = Object.freeze([
  `function setArtistGuardians(${ARTIST_GUARDIAN_SET_TUPLE},${ARTIST_ROTATION_AUTHORIZATION_TUPLE}) returns(bytes32)`,
  `function rotateArtistAddress(${ARTIST_ROTATION_TERMS_TUPLE},${ARTIST_ROTATION_AUTHORIZATION_TUPLE},${ARTIST_ROTATION_AUTHORIZATION_TUPLE}) returns(bytes32)`,
  "function approveArtistRotation(bytes32 artistId,bytes32 expectedRotationRecordHash)",
  "function vetoArtistRotation(bytes32 artistId,bytes32 expectedRotationRecordHash,bytes32 reasonHash)",
  "function executeArtistRotation(bytes32 artistId,bytes32 expectedRotationRecordHash)",
  `function guardianSetDigest(${ARTIST_GUARDIAN_SET_TUPLE},${ARTIST_ROTATION_AUTHORIZATION_TUPLE}) view returns(bytes32)`,
  `function rotationDigest(${ARTIST_ROTATION_TERMS_TUPLE},${ARTIST_ROTATION_AUTHORIZATION_TUPLE}) view returns(bytes32)`,
  `function rotationAcceptanceDigest(${ARTIST_ROTATION_TERMS_TUPLE},${ARTIST_ROTATION_AUTHORIZATION_TUPLE}) view returns(bytes32)`,
  "function guardianSet(bytes32 artistId) view returns(address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,bytes32 recordHash)",
  "function pendingRotation(bytes32 artistId) view returns(address oldAddress,address newAddress,uint64 contestEndsAt,uint32 guardianApprovals,bytes32 recordHash)",
  `function guardianSetRecord(bytes32 recordHash) view returns(${ARTIST_GUARDIAN_RECORD_TUPLE})`,
  `function rotationRecord(bytes32 recordHash) view returns(${ARTIST_ROTATION_RECORD_TUPLE})`,
  `function artistTransitionState(bytes32 recordHash) view returns(${ARTIST_ROTATION_TRANSITION_TUPLE})`,
  "function lastArtistTransition(bytes32 artistId) view returns(bytes32)",
  "function activeAuthorityWindow(bytes32 artistId) view returns(bytes32 transitionRecordHash,uint64 windowEndsAt,bool contested)",
  "function rotationAcceptanceNonceState(bytes32 artistId,address newAddress,uint256 nonce) view returns(bool used,uint256 nextNonce)",
  "event ArtistGuardianSetUpdated(uint16 schemaVersion,bytes32 indexed artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 guardianSetRecordHash)",
  "event ArtistRotationStaged(uint16 schemaVersion,bytes32 indexed artistId,address indexed oldAddress,address indexed newAddress,uint64 stagedAt,uint64 contestEndsAt,uint256 nonce,bytes32 reasonHash,bytes32 rotationRecordHash)",
  "event ArtistRotationGuardianApproved(uint16 schemaVersion,bytes32 indexed artistId,address indexed guardian,bytes32 indexed rotationRecordHash,uint32 approvals)",
  "event ArtistRotationVetoed(uint16 schemaVersion,bytes32 indexed artistId,address indexed vetoer,bytes32 indexed rotationRecordHash,bytes32 reasonHash)",
  "event ArtistAddressRotated(uint16 schemaVersion,bytes32 indexed artistId,address indexed oldAddress,address indexed newAddress,uint8 authorityClass,bytes32 reasonHash,bytes32 rotationRecordHash)",
]);
const abi = new Interface(CURRENT_ARTIST_GUARDIAN_ROTATION_ABI), coder = AbiCoder.defaultAbiCoder();
function keys(v: unknown, names: readonly string[]): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).length !== names.length
    || Object.keys(v).sort().join(",") !== [...names].sort().join(",")) throw Error("Unexpected fields");
}
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return v;
}
function address(v: unknown): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const result = getAddress(v) as Address;
  if (result === ZeroAddress) throw Error("Zero address");
  return result;
}
function hash(v: unknown, allowZero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!allowZero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
function stable(v: any): string {
  if (typeof v === "bigint") return `bigint:${v}`;
  if (Array.isArray(v)) return `[${v.map(stable).join(",")}]`;
  if (v && typeof v === "object") return `{${Object.keys(v).sort().map(k => `${k}:${stable(v[k])}`).join(",")}}`;
  return JSON.stringify(v);
}
export function normalizeArtistGuardianSet(v: ArtistGuardianSet): ArtistGuardianSet {
  keys(v, ["artistId", "guardians", "approvalThreshold", "minContestSeconds"]);
  if (!Array.isArray(v.guardians) || v.guardians.length > 8 || Reflect.ownKeys(v.guardians).length !== v.guardians.length + 1) throw Error("Expected dense guardian array of at most eight addresses");
  const guardians = v.guardians.map(address);
  for (let i = 1; i < guardians.length; i++) if (BigInt(guardians[i]!) <= BigInt(guardians[i - 1]!)) throw Error("Guardians must be strictly ascending and unique");
  const approvalThreshold = uint(v.approvalThreshold, 32), minContestSeconds = uint(v.minContestSeconds, 64);
  if (guardians.length === 0 ? approvalThreshold !== 0n : approvalThreshold === 0n || approvalThreshold > BigInt(guardians.length)) throw Error("Invalid guardian threshold");
  if (minContestSeconds > 30n * 86400n) throw Error("Guardian contest floor exceeds thirty days");
  return freeze({ artistId: hash(v.artistId), guardians, approvalThreshold, minContestSeconds });
}
export function normalizeArtistRotationTerms(v: ArtistRotationTerms): ArtistRotationTerms {
  keys(v, ["artistId", "oldAddress", "newAddress", "reasonHash", "expectedPreviousTransitionRecordHash"]);
  const oldAddress = address(v.oldAddress), newAddress = address(v.newAddress);
  if (oldAddress === newAddress) throw Error("Rotation needs a different new address");
  return freeze({ artistId: hash(v.artistId), oldAddress, newAddress, reasonHash: hash(v.reasonHash, true),
    expectedPreviousTransitionRecordHash: hash(v.expectedPreviousTransitionRecordHash, true) });
}
export function normalizeArtistRotationAuthorization(v: ArtistRotationAuthorization): ArtistRotationAuthorization {
  keys(v, ["nonce", "time", "signature"]);
  if (typeof v.signature !== "string" || !isHexString(v.signature, true) || v.signature.length > 8194) throw Error("Signature must be complete hex bytes of at most 4096 bytes");
  return freeze({ nonce: uint(v.nonce), time: uint(v.time, 64), signature: v.signature.toLowerCase() as Hex });
}
/** Same numeric nonce may be used independently in principal kind1 and acceptance kind4. */
export function rotationAcceptanceLane(artistId: Hex, newAddress: Address): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32", "address"], [id("rotation_acceptance"), hash(artistId), address(newAddress)])) as Hex;
}
type SigningKind = "guardianSet" | "rotation" | "rotationAcceptance";
interface SigningTerms { guardianSet: ArtistGuardianSet; rotation: ArtistRotationTerms; rotationAcceptance: ArtistRotationTerms }
interface SigningMessages { guardianSet: ArtistGuardianSetMessage; rotation: ArtistRotationMessage; rotationAcceptance: ArtistRotationAcceptanceMessage }
/** Exact Registry domain v1. The concurrency guard is deliberately outside both rotation signatures. */
export function guardianRotationTypedData<K extends SigningKind>(kind: K, chainId: bigint, registry: Address, terms: SigningTerms[K], authorization: ArtistRotationAuthorization): SigningPayload<SigningMessages[K]> {
  const a = normalizeArtistRotationAuthorization(authorization), host = address(registry);
  let primaryType: string, declaration: string, message: object;
  if (kind === "guardianSet") {
    const p = normalizeArtistGuardianSet(terms as ArtistGuardianSet);
    primaryType = "StreamArtistGuardianSet";
    declaration = "bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt";
    message = { ...p, nonce: a.nonce, signedAt: a.time };
  } else if (kind === "rotation" || kind === "rotationAcceptance") {
    const p = normalizeArtistRotationTerms(terms as ArtistRotationTerms);
    primaryType = kind === "rotation" ? "StreamArtistKeyRotation" : "StreamArtistRotationAcceptance";
    declaration = `bytes32 artistId,address oldAddress,address newAddress,${kind === "rotation" ? "bytes32 reasonHash," : ""}uint256 nonce,uint64 deadline`;
    message = { artistId: p.artistId, oldAddress: p.oldAddress, newAddress: p.newAddress,
      ...(kind === "rotation" ? { reasonHash: p.reasonHash } : {}), nonce: a.nonce, deadline: a.time };
  } else throw Error("Unknown guardian/rotation signing kind");
  const fields = declaration.split(",").map(v => { const [type, name] = v.split(" "); return { type: type!, name: name! }; });
  return buildSigningPayload(chainId, host, "6529StreamArtistRegistry", primaryType, fields, message as SigningMessages[K], kind === "guardianSet" ? { guardians: { minimum: 0, maximum: 8 } } : {});
}
export function guardianRotationDigest<K extends SigningKind>(kind: K, chainId: bigint, registry: Address, terms: SigningTerms[K], authorization: ArtistRotationAuthorization): Hex {
  return guardianRotationTypedData(kind, chainId, registry, terms, authorization).digest;
}
/** Pure preparation does not verify authority, timing, nonces, signer proofs or execution readiness. */
export function prepareGuardianRotationCall(input: GuardianRotationRequest): PreparedGuardianRotation {
  if (!input || typeof input !== "object") throw Error("Expected guardian/rotation request");
  const common = ["kind", "chainId", "registry", "caller"], registry = address(input.registry), caller = address(input.caller), chainId = uint(input.chainId);
  if (chainId === 0n) throw Error("Zero chain ID");
  const context = { chainId, registry, caller }, signing: GuardianRotationSigning[] = [];
  let request: GuardianRotationRequest, operation: PreparedGuardianRotation["operation"], method: string, args: unknown[];
  function sign(kind: SigningKind, p: ArtistGuardianSet | ArtistRotationTerms, a: ArtistRotationAuthorization, signer?: Address): void {
    const typedData = guardianRotationTypedData(kind, chainId, registry, p, a);
    const getter = kind === "guardianSet" ? "guardianSetDigest" : kind === "rotation" ? "rotationDigest" : "rotationAcceptanceDigest";
    signing.push({ side: kind === "rotationAcceptance" ? "acceptance" : "principal", ...(signer ? { signer } : {}),
      typedData, digest: typedData.digest, nonceLane: { kind: kind === "rotationAcceptance" ? 4 : 1,
        scope: kind === "rotationAcceptance" ? rotationAcceptanceLane(p.artistId, (p as ArtistRotationTerms).newAddress) : p.artistId },
      digestCall: { to: registry, data: abi.encodeFunctionData(getter, [p, { ...a, signature: "0x" }]) as Hex, value: 0n } });
  }
  switch (input.kind) {
    case "setGuardians": {
      keys(input, [...common, "terms", "authorization"]);
      const terms = normalizeArtistGuardianSet(input.terms), authorization = normalizeArtistRotationAuthorization(input.authorization);
      if (authorization.time === 0n && authorization.signature !== "0x") throw Error("Signed guardian set requires explicit signedAt");
      request = { ...context, kind: input.kind, terms, authorization }; operation = 28; method = "setArtistGuardians"; args = [terms, authorization];
      sign("guardianSet", terms, authorization); break;
    }
    case "stageRotation": {
      keys(input, [...common, "terms", "oldAuthorization", "newAuthorization"]);
      const terms = normalizeArtistRotationTerms(input.terms), oldAuthorization = normalizeArtistRotationAuthorization(input.oldAuthorization), newAuthorization = normalizeArtistRotationAuthorization(input.newAuthorization);
      if (oldAuthorization.time === 0n || newAuthorization.time === 0n) throw Error("Both rotation sides require deadlines, including direct calls");
      request = { ...context, kind: input.kind, terms, oldAuthorization, newAuthorization }; operation = 29; method = "rotateArtistAddress"; args = [terms, oldAuthorization, newAuthorization];
      sign("rotation", terms, oldAuthorization, terms.oldAddress); sign("rotationAcceptance", terms, newAuthorization, terms.newAddress); break;
    }
    case "approveRotation": case "executeRotation": case "vetoRotation": {
      keys(input, [...common, "artistId", "expectedRotationRecordHash", ...(input.kind === "vetoRotation" ? ["reasonHash"] : [])]);
      const artistId = hash(input.artistId), expectedRotationRecordHash = hash(input.expectedRotationRecordHash);
      if (input.kind === "vetoRotation") {
        const reasonHash = hash(input.reasonHash, true);
        request = { ...context, kind: input.kind, artistId, expectedRotationRecordHash, reasonHash }; operation = 31; method = "vetoArtistRotation"; args = [artistId, expectedRotationRecordHash, reasonHash];
      } else {
        request = { ...context, kind: input.kind, artistId, expectedRotationRecordHash };
        operation = input.kind === "approveRotation" ? 30 : 32; method = input.kind === "approveRotation" ? "approveArtistRotation" : "executeArtistRotation"; args = [artistId, expectedRotationRecordHash];
      }
      break;
    }
    default: throw Error("Unknown guardian/rotation operation");
  }
  return freeze({ request, operation, call: { to: registry, value: 0n, data: abi.encodeFunctionData(method, args) as Hex }, signing, factsVerified: false as const });
}
export function normalizeGuardianRotationCall(input: PreparedGuardianRotation): PreparedGuardianRotation {
  keys(input, ["request", "operation", "call", "signing", "factsVerified"]);
  const clean = prepareGuardianRotationCall(input.request);
  if (stable(clean) !== stable(input)) throw Error("Changed guardian/rotation prepared call");
  return clean;
}
/** Immutable original record hash. Effective signedAt is inclusion time for a direct zero-time guardian call. */
export function artistGuardianRecordHash(chainId: bigint, registry: Address, terms: ArtistGuardianSet, nonce: bigint, effectiveSignedAt: bigint): Hex {
  const p = normalizeArtistGuardianSet(terms);
  if (uint(chainId) === 0n || uint(effectiveSignedAt, 64) === 0n) throw Error("Expected positive chain and effective time");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address[]", "uint32", "uint64", "uint256", "uint64"],
    ["0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297", chainId, address(registry), p.artistId, p.guardians, p.approvalThreshold, p.minContestSeconds, uint(nonce), effectiveSignedAt])) as Hex;
}
export function artistRotationRecordHash(chainId: bigint, registry: Address, terms: ArtistRotationTerms, oldNonce: bigint, stagedAt: bigint, contestEndsAt: bigint): Hex {
  const p = normalizeArtistRotationTerms(terms);
  if (uint(chainId) === 0n || uint(stagedAt, 64) === 0n || uint(contestEndsAt, 64) <= stagedAt) throw Error("Invalid rotation record time");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256", "uint64", "uint64"],
    ["0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5", chainId, address(registry), p.artistId, p.oldAddress, p.newAddress, p.reasonHash, uint(oldNonce), stagedAt, contestEndsAt])) as Hex;
}

export interface GuardianRotationReads {
  guardianSet: { args: readonly [Hex]; result: { readonly guardians: readonly Address[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; readonly recordHash: Hex } };
  pendingRotation: { args: readonly [Hex]; result: { readonly oldAddress: Address; readonly newAddress: Address; readonly contestEndsAt: bigint; readonly guardianApprovals: bigint; readonly recordHash: Hex } };
  guardianSetRecord: { args: readonly [Hex]; result: ArtistGuardianRecord };
  rotationRecord: { args: readonly [Hex]; result: ArtistRotationRecord };
  artistTransitionState: { args: readonly [Hex]; result: ArtistRotationTransition };
  lastArtistTransition: { args: readonly [Hex]; result: Hex };
  activeAuthorityWindow: { args: readonly [Hex]; result: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; readonly contested: boolean } };
  rotationAcceptanceNonceState: { args: readonly [Hex, Address, bigint]; result: { readonly used: boolean; readonly nextNonce: bigint } };
}
const readMethods = ["guardianSet", "pendingRotation", "guardianSetRecord", "rotationRecord", "artistTransitionState", "lastArtistTransition", "activeAuthorityWindow", "rotationAcceptanceNonceState"] as const;
function readMethod(method: string): void { if (!(readMethods as readonly string[]).includes(method)) throw Error("Unsupported guardian/rotation read"); }
export function prepareGuardianRotationRead<K extends keyof GuardianRotationReads>(registry: Address, method: K, args: GuardianRotationReads[K]["args"]): UnsignedCall {
  readMethod(method);
  if (!Array.isArray(args) || args.length !== (method === "rotationAcceptanceNonceState" ? 3 : 1)) throw Error("Invalid read arguments");
  const values = method === "rotationAcceptanceNonceState" ? [hash(args[0]), address(args[1]), uint(args[2])] : [hash(args[0], true)];
  return freeze({ to: address(registry), value: 0n, data: abi.encodeFunctionData(method, values) as Hex });
}
function plain(type: ParamType, value: any): any {
  if (type.baseType === "array") return Array.from(value, v => plain(type.arrayChildren!, v));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((c, i) => [c.name, plain(c, value[i])]));
  return value;
}
/** Canonical ABI decoding is an encoding check; capture joins records to actual owner state. */
export function decodeGuardianRotationRead<K extends keyof GuardianRotationReads>(method: K, raw: Hex): GuardianRotationReads[K]["result"] {
  readMethod(method);
  if (!isHexString(raw, true) || raw.length > 32770) throw Error("Invalid or oversized read bytes");
  const values = abi.decodeFunctionResult(method, raw);
  if (abi.encodeFunctionResult(method, values).toLowerCase() !== raw.toLowerCase()) throw Error("Noncanonical read bytes");
  const fields = abi.getFunction(method)!.outputs;
  const result = fields.length === 1 ? plain(fields[0]!, values[0]) : Object.fromEntries(fields.map((f, i) => [f.name, plain(f, values[i])]));
  if (method === "guardianSet" || method === "guardianSetRecord") {
    const terms = method === "guardianSet" ? result : result.terms;
    if (terms.guardians.length > 8) throw Error("Invalid guardian count");
    if (result.recordHash !== ZeroHash) normalizeArtistGuardianSet({ artistId: method === "guardianSet" ? id("read-shape") as Hex : terms.artistId, guardians: terms.guardians, approvalThreshold: terms.approvalThreshold, minContestSeconds: terms.minContestSeconds });
  }
  if ((method === "artistTransitionState" && result.phase > 3n) || (method === "rotationRecord" && result.transition.phase > 3n)) throw Error("Unknown rotation phase");
  return freeze(result) as GuardianRotationReads[K]["result"];
}
