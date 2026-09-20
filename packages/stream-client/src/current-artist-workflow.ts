import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { prepareCurrentArtistAction, normalizeCurrentArtistAction, currentArtistOperationTypedData, CURRENT_ARTIST_OPERATION_ABI } from "./current-artist-operation.js";
import type { CurrentArtistOperationRequest } from "./current-artist-operation.js";
import { createSafeCallPlan, type SafeCallPlan } from "./safe-plan.js";
export interface CurrentArtistCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}
/** Components follow the Coordinator order: seven owners, Registry, Archive, Core, Manager, roles, metadata, primary, royalty, validator. */
export interface CurrentArtistDeployment {
  readonly chainId: bigint;
  readonly registry: CurrentArtistCodePin;
  readonly coordinator: CurrentArtistCodePin;
  readonly components: readonly CurrentArtistCodePin[];
  /** Required for delegated economics and royalty-freeze admission through the original Reads helper. */
  readonly reads?: CurrentArtistCodePin;
}
type Action = ReturnType<typeof prepareCurrentArtistAction>;
export interface CurrentArtistAuthority {
  readonly address: Address;
  readonly authorityClass: bigint;
  readonly status: bigint;
  readonly identityRecordHash: Hex;
}
export interface CurrentArtistReplay {
  readonly digestObserved: boolean;
  readonly digestRevoked: boolean;
  readonly nonceConsumed: boolean;
  readonly nonceRevoked: boolean;
  readonly nextUnusedNonce: bigint;
}
export interface CurrentArtistBinding {
  readonly artistId: Hex;
  readonly artistAddress: Address;
  readonly identityRecordHash: Hex;
  readonly bindingHash: Hex;
  readonly generation: bigint;
  readonly consentMode: bigint;
  readonly saleConsentScope: bigint;
  readonly registryImmutabilityElection: bigint;
  readonly proposer: Address;
  readonly accepted: boolean;
}
export interface CurrentArtistTiming {
  readonly kind: "deadline" | "dated" | "nonce-only";
  readonly submittedTime: bigint;
  readonly effectiveTime: bigint;
  /** For direct dated time zero, this digest belongs only to the captured block. */
  readonly effectiveDigest: Hex;
}
export interface CurrentArtistDelegationRecord {
  readonly grant: {
    readonly artistId: Hex;
    readonly delegate: Address;
    readonly collectionId: bigint;
    readonly capabilities: bigint;
    readonly notBefore: bigint;
    readonly expiresAt: bigint;
    readonly maxUses: bigint;
    readonly constraintsHash: Hex;
  };
  readonly grantor: Address;
  readonly nonce: bigint;
  readonly uses: bigint;
  readonly revoked: boolean;
  readonly revocationRecordHash: Hex;
}
export interface CurrentArtistDelegatedObservation {
  readonly nonceUsed: boolean;
  readonly nextUnusedNonce: bigint;
  readonly digestRevoked: boolean;
  readonly epochRecorded: bigint;
  readonly epochCurrent: bigint;
  readonly usesRemaining: bigint;
}
export interface CurrentArtistEconomicsObservation {
  readonly payout: { readonly account: Address; readonly recordHash: Hex };
  /** Original helper evidence; its format depends on the selected economics provider. */
  readonly candidateEvidence: Hex;
}
export interface CurrentArtistEconomicsAssociation {
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly payloadHash: Hex;
  readonly originalRecord: Hex;
}
export interface CurrentArtistCapture {
  readonly deployment: CurrentArtistDeployment;
  readonly action: Action;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
  readonly configurationHash: Hex;
  readonly authority: CurrentArtistAuthority;
  readonly binding: CurrentArtistBinding | null;
  readonly replay: CurrentArtistReplay;
  readonly revocationTarget: CurrentArtistReplay | null;
  readonly timing: CurrentArtistTiming;
  readonly revision: {
    readonly operativeDocumentHash: Hex;
  } | null;
  readonly delegation: CurrentArtistDelegationRecord | null;
  readonly delegated: CurrentArtistDelegatedObservation | null;
  readonly economics: CurrentArtistEconomicsObservation | null;
  /** Authority/replay observation only; exact write simulation performs operation-specific admission. */
  readonly simulationRequired: true;
  readonly captureHash: Hex;
}
export interface CurrentArtistEventReference {
  readonly address: Address;
  readonly event: string;
  readonly logIndex: number;
  readonly transactionHash: Hex;
  readonly blockHash: Hex;
}
export interface CurrentArtistReceipt {
  readonly capture: CurrentArtistCapture;
  readonly transactionHash: Hex;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly recordHash: Hex;
  readonly evidenceId: Hex;
  readonly events: readonly CurrentArtistEventReference[];
  readonly observedReplay: CurrentArtistReplay;
  readonly observedDelegated: { readonly nonceUsed: boolean; readonly nextUnusedNonce: bigint } | null;
  readonly effectiveDigest: Hex;
  /** Actual archived economics facts at execution, independently of later operative payout changes. */
  readonly economics: (CurrentArtistEconomicsObservation & { readonly association: CurrentArtistEconomicsAssociation }) | null;
}
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const B = "(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const A = "(uint256 nonce,uint64 time,bytes signature)";
const S = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const P = "(address signer,bytes32 digest,bool direct)";
const F = "(bytes32 artistId,address authorityAddress,uint8 authorityClass,uint8 status)";
const R = "(bool digestObserved,bool digestRevoked,bool nonceConsumed,bool nonceRevoked,uint256 nextUnusedNonce)";
const G = "(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash)";
const D = `(${G} grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash)`;
const E = "(uint256 collectionId,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)";
const C = "(bytes32 profileHash,bytes32 policyHash,uint16 royaltyBps,bool frozen)";
const AF = "(address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)";
const PAYOUT = "(address account,bytes32 recordHash)";
const EA = "(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 payloadHash,bytes32 originalRecord)";
const terms = {
  bindingRefusal: "(uint256 collectionId,uint64 generation,bytes32 bindingHash,bytes32 reasonHash,string reasonURI)",
  saleConsent: "(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)",
  royaltyFreeze: "(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)",
  contentFreeze: "(uint256 collectionId,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash)",
  authorizationRevocation: "(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce)",
  identityRevision: "(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,string identityRecordURI)",
  delegatedPolicyConsent: "(uint256 collectionId,bytes32 phaseId,bytes32 policyHash)",
  delegatedSaleConsent: "(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)",
  delegatedEconomicsConsent: E,
  delegatedProspectiveEconomicsConsent: E,
  delegatedRoyaltyFreeze: "(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)",
  delegationGrant: G,
  delegationRevocation: "(bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash)"
} as const;
const abi = new Interface([...CURRENT_ARTIST_OPERATION_ABI,
  "function reads() view returns(address)",
  `function acceptedBinding(uint256) view returns(${B})`,
  `function defensiveBinding(uint256) view returns(${B})`,
  "function artistPayoutAccount(bytes32) view returns(address,bytes32)",
  `function requireCurrentEconomics(${E},address) view returns(bytes)`,
  `function requireProspectiveEconomicsWithEvidence(${E},${C},address) view returns(${AF} fact,bytes32 previousHash)`,
  `function requireRoyaltyFreezeProposal(${terms.royaltyFreeze}) view`,
  "function designationRecord(bytes32) view returns((bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash))",
  `function economicsRecord(${E}) view returns(bytes32)`,
  `function economicsRecordForBinding(${E},bytes32,uint64,bytes32) view returns(bytes32)`,
  `function economicsRecordAssociation(bytes32) view returns(${EA})`,
  "event ArtistEconomicsConsentRecorded(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed assignmentHash,address indexed signer,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 payoutDesignationRecordHash,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 consentRecordHash)",
  "event ArtistEconomicsConsentAssociated(uint16 schemaVersion,bytes32 indexed recordHash,bytes32 indexed artistId,bytes32 indexed bindingHash,uint64 bindingGeneration,bytes32 payloadHash,bytes32 originalRecord)",
  "event ArtistRecordDelegation(uint16 schemaVersion,bytes32 indexed recordHash,bytes32 indexed delegationRecordHash,bytes32 indexed artistId,address resolver,bytes32 revenueClass,uint8 authorityClass)",
  "function policyRecord(uint256,bytes32,bytes32) view returns(bytes32)",
  "function recordDelegation(bytes32) view returns(bytes32)",
  "function saleConsentAt(uint256,bytes32,bytes32) view returns(bytes32)",
  "function requireSaleConsent(uint256,bytes32,bytes32) view",
  "function delegationEpochState(bytes32) view returns(bool,uint64,uint64)",
  "function delegatedNonceState(bytes32,address,uint256) view returns(bool,uint256)",
  "function delegationState(bytes32) view returns(bool,address,uint256,uint32,uint64,uint64,uint64)",
  "function replayCell(bytes32) view returns((bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status))",
  "event ArtistPolicyConsentRecorded(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed policyHash,address indexed signer,bytes32 phaseId,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 consentRecordHash)",
  "event ArtistConsentDelegationRecorded(uint16 schemaVersion,bytes32 indexed recordHash,bytes32 indexed delegationRecordHash,bytes32 indexed artistId,uint16 operationId)",
  "function operativeIdentityRecord(bytes32) view returns(bytes32)",
  "function identityDocumentBytes(bytes32) view returns(bytes)",
  "function identityRevisionRecord(bytes32) view returns((bytes32 recordHash,bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,bytes32 previousRevisionRecord,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,string identityRecordURI,string displayName))",
  `function delegationRecord(bytes32) view returns(${D})`,
  "event ArtistIdentityRevisionRecorded(uint16 schemaVersion,bytes32 indexed artistId,address indexed signer,bytes32 previousRecordHash,bytes32 revisedRecordHash,string identityRecordURI,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 revisionRecordHash)",
  "event ArtistIdentityDisplayNameStored(bytes32 indexed artistId,bytes32 indexed identityRecordHash,string displayName)",
  "event ArtistDelegationGranted(uint16 schemaVersion,bytes32 indexed artistId,address indexed delegate,uint256 indexed collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce,bytes32 delegationRecordHash)",
  "event ArtistDelegationRevoked(uint16 schemaVersion,bytes32 indexed artistId,address indexed delegate,bytes32 indexed delegationRecordHash,bytes32 reasonHash,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt)",
  "function core() view returns(address)", "function mintManager() view returns(address)", "function operationCoordinator() view returns(address)", "function artistRegistry() view returns(address)", "function archiveV2() view returns(address)", "function deploymentChainId() view returns(uint256)", "function domainId() view returns(bytes32)", "function configurationHash() view returns(bytes32)",
  "function suiteConfiguration() view returns((address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator))",
  `function binding(uint256) view returns(${B})`, "function attributionState(uint256) view returns(uint8,uint64)", "function bindingTerms(uint256,uint64) view returns((bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count))", "function acceptedCount(bytes32) view returns(uint32)",
  "function authorityState(bytes32) view returns(address,uint8,uint8,bytes32)", `function artistAuthorizationState(bytes32,bytes32,uint256) view returns(${R})`, "function currentAuthorityCapabilities(bytes32) view returns((address authorityAddress,uint8 authorityClass,uint8 status,uint32 effectiveCapabilities,bytes32 activationRecordHash))",
  "function artistRegistryCutover() view returns(bool,address,uint64)", "function gasParameterInfo(bytes32) view returns(uint256,uint256,uint8,uint64)", "function collectionExists(uint256) view returns(bool)", "function getSatellitePointer(bytes32) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function bindingTermination(uint256,uint64) view returns((uint8 kind,bytes32 reasonHash,bytes32 recordHash))", `function royaltyFreezeRecord(${terms.royaltyFreeze},bytes32,uint64) view returns((bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration))`,
  `function saleConsentRecord(bytes32) view returns((bytes32 recordHash,${terms.saleConsent} terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash))`,
  "function contentFreezeAuthorization(bytes32) view returns((bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass))",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)", "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes)",
  "event ArtistBindingTerminationContext(uint16 schemaVersion,uint256 indexed collectionId,uint64 indexed bindingGeneration,bytes32 indexed recordReference,bytes32 bindingHash,bytes32 artistId,address signer,uint256 nonce,uint64 signedAt)",
  "event ArtistAttributionStateChanged(uint16 schemaVersion,uint256 indexed collectionId,uint8 indexed newState,uint64 bindingGeneration,uint8 oldState,address actor,uint8 authorityClass,bytes32 recordHash,bytes32 reasonHash,string reasonURI)",
  "event ArtistSaleConsentRecorded(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed saleConfigHash,address indexed signer,bytes32 saleId,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 consentRecordHash)",
  "event ArtistRoyaltyFreezeAuthorized(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed expectedAssignmentHash,address indexed signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 freezeRecordHash)",
  "event ArtistContentFreezeAuthorized(uint16 schemaVersion,uint256 indexed collectionId,address indexed signer,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 freezeRecordHash)",
  "event ArtistContentRecordContext(uint16 schemaVersion,bytes32 indexed recordHash,address metadataContract,bytes32 artistId)",
  "event ArtistAuthorizationRevoked(uint16 schemaVersion,bytes32 indexed artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 revokedAt,bytes32 revocationRecordHash)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)"]);
const safe = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safe0 = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safe1 = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
function address(v: unknown): Address {
  if (typeof v !== "string") {
    throw Error("Expected address");
  }
  const x = getAddress(v) as Address;
  if (x === ZeroAddress) {
    throw Error("Zero address");
  }
  return x;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v === ZeroHash)) {
    throw Error("Expected bytes32");
  }
  return v.toLowerCase() as Hex;
}
function bytes(v: unknown, max = 262144): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) {
    throw Error("Malformed/oversized bytes");
  }
  return v.toLowerCase() as Hex;
}
function uint(v: unknown): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << 256n) {
    throw Error("Expected uint256");
  }
  return v;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) {
    throw Error("Expected concrete block");
  }
  return v;
}
function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
function stable(v: unknown): string {
  const tagged = (value: unknown): unknown => {
    if (value === null) {
      return ["null"];
    }
    if (typeof value === "string" || typeof value === "boolean") {
      return [typeof value, value];
    }
    if (typeof value === "bigint") {
      return ["bigint", value.toString()];
    }
    if (typeof value === "number" && Number.isFinite(value)) {
      return ["number", value];
    }
    if (Array.isArray(value)) {
      return ["array", value.map(tagged)];
    }
    if (value && typeof value === "object") {
      return ["object", Object.keys(value).sort().map(key => [key, tagged((value as Record<string, unknown>)[key])])];
    }
    throw Error("Unsupported canonical value");
  };
  return JSON.stringify(tagged(v));
}
function equal(a: unknown, b: unknown, label = "Canonical reconstruction differs"): void {
  if (stable(a) !== stable(b)) {
    throw Error(label);
  }
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") {
    Object.values(v).forEach(freeze);
    Object.freeze(v);
  }
  return v;
}
function copy<T>(v: T): T {
  if (Array.isArray(v)) {
    return v.map(copy) as T;
  }
  if (v && typeof v === "object") {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, copy(x)])) as T;
  }
  return v;
}
function keys(value: unknown, expected: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value) || Reflect.ownKeys(value).some(k => typeof k !== "string") || Object.keys(value).sort().join() !== [...expected].sort().join()) {
    throw Error("Missing/unknown properties");
  }
}
function pin(p: CurrentArtistCodePin): CurrentArtistCodePin {
  keys(p, ["address", "codeHash"]);
  return {
    address: address(p.address), codeHash: hash(p.codeHash)
  };
}
function deployment(v: CurrentArtistDeployment): CurrentArtistDeployment {
  keys(v, ["chainId", "registry", "coordinator", "components", ...(v.reads === undefined ? [] : ["reads"])]);
  if (!Array.isArray(v.components) || v.components.length !== 16) {
    throw Error("Expected exactly16 component pins");
  }
  const d = {
    chainId: uint(v.chainId), registry: pin(v.registry), coordinator: pin(v.coordinator), components: v.components.map(pin),
    ...(v.reads === undefined ? {} : { reads: pin(v.reads) })
  };
  if (d.chainId === 0n || !same(d.components[7]!.address, d.registry.address) || !same(d.components[7]!.codeHash, d.registry.codeHash) || new Set([d.coordinator.address, ...d.components.map(p => p.address)]).size !== 17) {
    throw Error("Invalid exact Artist deployment pins");
  }
  return freeze(d);
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, from?: Address): Promise<any> {
  const raw = bytes(await p.call({
    to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, ...(from ? { from } : {})
  }));
  const out = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, out), raw)) {
    throw Error(`Noncanonical ${name} return`);
  }
  return out;
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag) {
    throw Error("Missing/mismatched block");
  }
  return {
    blockNumber: tag, blockHash: hash(b.hash), timestamp: BigInt(number(b.timestamp))
  };
}
async function unchanged(p: Reader, h: {
  blockNumber: number;
  blockHash: Hex;
}) {
  if (!same((await header(p, h.blockNumber)).blockHash, h.blockHash)) {
    throw Error("Pinned block changed");
  }
}
async function context(p: Reader, d: CurrentArtistDeployment, tag: number, current: boolean) {
  if ((await p.getNetwork()).chainId !== d.chainId) {
    throw Error("RPC chain mismatch");
  }
  const h = await header(p, tag);
  await Promise.all([d.coordinator, ...d.components, ...(d.reads ? [d.reads] : [])].map(async (x) => {
    const code = bytes(await p.getCode(x.address, tag), 65536);
    if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), x.codeHash)) {
      throw Error("Pinned Artist runtime differs");
    }
  }));
  const [suite] = await read(p, d.coordinator.address, "suiteConfiguration", [], tag);
  const ordered = [...suite.owners, suite.registry, suite.archive, suite.core, suite.mintManager, suite.roleRegistry, suite.metadata, suite.primaryResolver, suite.royaltyResolver, suite.validator];
  equal(ordered.map(address), d.components.map(p => p.address), "Suite component pins differ");
  if (d.reads && !same((await read(p, d.coordinator.address, "reads", [], tag))[0], d.reads.address)) {
    throw Error("Coordinator Reads binding differs");
  }
  if ((await read(p, d.coordinator.address, "deploymentChainId", [], tag))[0] !== d.chainId) {
    throw Error("Coordinator chain differs");
  }
  const core = d.components[9]!.address;
  const manager = d.components[10]!.address;
  for (const [name, expected] of [["core", core], ["mintManager", manager], ["operationCoordinator", d.coordinator.address]]) {
    if (!same((await read(p, d.registry.address, name!, [], tag))[0], expected)) {
      throw Error("Facade binding differs");
    }
  }
  for (let i = 0; i < 7; i++) {
    const owner = d.components[i]!.address;
    for (const [name, expected] of [["core", core], ["mintManager", manager], ["artistRegistry", d.registry.address], ["operationCoordinator", d.coordinator.address], ["archiveV2", d.components[8]!.address], ["domainId", domains[i]!]]) {
      if (!same((await read(p, owner, name!, [], tag))[0], expected)) {
        throw Error("Owner binding differs");
      }
    }
    if ((await read(p, owner, "deploymentChainId", [], tag))[0] !== d.chainId) {
      throw Error("Owner chain differs");
    }
  }
  if (current) {
    const pointer = await read(p, core, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
    if (!same(pointer[0], d.registry.address) || !same(pointer[1], d.registry.codeHash) || (await read(p, d.registry.address, "artistRegistryCutover", [], tag))[0] !== false) {
      throw Error("Artist registry is not current");
    }
  }
  return {
    ...h, configurationHash: hash((await read(p, d.coordinator.address, "configurationHash", [], tag))[0])
  };
}
function replay(v: any): CurrentArtistReplay {
  return {
    digestObserved: v[0], digestRevoked: v[1], nonceConsumed: v[2], nonceRevoked: v[3], nextUnusedNonce: v[4]
  };
}
async function replayRead(p: Reader, d: CurrentArtistDeployment, artistId: Hex, digest: Hex, nonce: bigint, tag: number) {
  return replay((await read(p, d.registry.address, "artistAuthorizationState", [artistId, digest, nonce], tag))[0]);
}
function binding(v: any): CurrentArtistBinding {
  return {
    artistId: v[0], artistAddress: v[1], identityRecordHash: v[2], bindingHash: v[3], generation: v[4], consentMode: v[5], saleConsentScope: v[6], registryImmutabilityElection: v[7], proposer: v[8], accepted: v[9]
  };
}
function ordinary(a: CurrentArtistAuthority, defensive: boolean) {
  return a.authorityClass === 1n && (a.status === 1n || a.status === 2n) || [3n, 4n].includes(a.authorityClass) && a.status === 3n || defensive && a.status === 4n && [1n, 3n, 4n].includes(a.authorityClass);
}
function captureHash(v: unknown): Hex {
  return keccak256(new TextEncoder().encode(stable(v))) as Hex;
}
function saved(v: CurrentArtistCapture): CurrentArtistCapture {
  keys(v, ["deployment", "action", "blockNumber", "blockHash", "timestamp", "configurationHash", "authority", "binding", "replay", "revocationTarget", "timing", "revision", "delegation", "delegated", "economics", "simulationRequired", "captureHash"]);
  const d = deployment(v.deployment);
  const a = normalizeCurrentArtistAction(v.action);
  const c = copy(v);
  const { captureHash: expected, ...body } = c;
  equal(d, c.deployment);
  equal(a, c.action);
  if (!same(captureHash(body), expected)) {
    throw Error("Captured Artist facts changed");
  }
  return freeze(c);
}
function delegatedConsent(q: CurrentArtistOperationRequest): q is Extract<CurrentArtistOperationRequest, { kind: "delegatedPolicyConsent" | "delegatedSaleConsent" }> {
  return q.kind === "delegatedPolicyConsent" || q.kind === "delegatedSaleConsent";
}
function economicsOperation(q: CurrentArtistOperationRequest): q is Extract<CurrentArtistOperationRequest, { kind: "delegatedEconomicsConsent" | "delegatedProspectiveEconomicsConsent" }> {
  return q.kind === "delegatedEconomicsConsent" || q.kind === "delegatedProspectiveEconomicsConsent";
}
function economicsOrFreeze(q: CurrentArtistOperationRequest): q is Extract<CurrentArtistOperationRequest, { kind: "delegatedEconomicsConsent" | "delegatedProspectiveEconomicsConsent" | "delegatedRoyaltyFreeze" }> {
  return economicsOperation(q) || q.kind === "delegatedRoyaltyFreeze";
}
function delegatedOperation(q: CurrentArtistOperationRequest): q is Extract<CurrentArtistOperationRequest, { kind: "delegatedPolicyConsent" | "delegatedSaleConsent" | "delegatedEconomicsConsent" | "delegatedProspectiveEconomicsConsent" | "delegatedRoyaltyFreeze" }> {
  return delegatedConsent(q) || economicsOrFreeze(q);
}
function collectionId(q: CurrentArtistOperationRequest): bigint | undefined {
  return economicsOperation(q) ? q.details.collectionId : "collectionId" in q.message ? q.message.collectionId : undefined;
}
function prospectiveEvidence(q: Extract<CurrentArtistOperationRequest, { kind: "delegatedProspectiveEconomicsConsent" }>, t: any, raw: Hex): Hex {
  const [candidate, fact, previousHash] = decode([C, AF, "bytes32"], raw);
  if (!same(coder.encode([C], [candidate]), coder.encode([C], [q.details.candidate]))
    || !same(coder.encode([AF], [fact]), coder.encode([AF], [[t.resolver, t.revenueClass, t.scope, t.scopeId, t.assignmentHash]]))
    || (t.assignmentHash === ZeroHash ? previousHash === ZeroHash : previousHash !== ZeroHash)) {
    throw Error("Prospective economics evidence differs");
  }
  return raw;
}
function delegatedDenyKey(d: CurrentArtistDeployment, artistId: Hex, delegate: Address, digest: Hex): Hex {
  const lane = keccak256(coder.encode(["bytes32", "bytes32", "address"],
    [id("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artistId, delegate]));
  const scope = keccak256(coder.encode(["bytes32", "bytes32"], [lane, digest]));
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), d.chainId, d.registry.address,
      d.coordinator.address, d.components[8]!.address, d.components[2]!.address, domains[2],
      id("identity_authority.replay.delegated_digest_revocation"), scope]
  )) as Hex;
}
async function delegatedReplay(p: Reader, d: CurrentArtistDeployment, q: CurrentArtistOperationRequest, digest: Hex, tag: number) {
  const [nonceUsed, nextUnusedNonce] = await read(p, d.registry.address, "delegatedNonceState", [q.artistId, q.signer, q.message.nonce], tag);
  const [deny] = await read(p, d.components[2]!.address, "replayCell", [delegatedDenyKey(d, q.artistId, q.signer, digest)], tag);
  return { nonceUsed: nonceUsed as boolean, nextUnusedNonce: nextUnusedNonce as bigint, digestRevoked: deny.status !== 0n };
}
function liveDelegation(record: CurrentArtistDelegationRecord, timestamp: bigint): boolean {
  return !record.revoked && timestamp >= record.grant.notBefore && timestamp < record.grant.expiresAt
    && (record.grant.maxUses === 0n || record.uses < record.grant.maxUses);
}
function timing(action: Action, timestamp: bigint): CurrentArtistTiming {
  const q = action.request;
  if (timestamp > (1n << 64n) - 1n) {
    throw Error("Artist timestamp exceeds uint64");
  }
  if (q.kind === "delegationGrant") {
    if (timestamp >= q.message.expiresAt || same(q.message.delegate, q.signer)) {
      throw Error("Delegation grant expired or self-directed");
    }
    return {
      kind: "nonce-only", submittedTime: 0n, effectiveTime: 0n, effectiveDigest: action.payload.digest
    };
  }
  if (q.kind === "identityRevision") {
    const submittedTime = q.message.signedAt;
    const effectiveTime = q.mode === "direct" && submittedTime === 0n ? timestamp : submittedTime;
    if (effectiveTime === 0n || effectiveTime > timestamp || (q.mode === "direct" && effectiveTime !== timestamp)) {
      throw Error("Identity revision signedAt differs from execution timing");
    }
    const effectiveDigest = currentArtistOperationTypedData("identityRevision", q.chainId, q.registry, {
      ...q.message, signedAt: effectiveTime
    }).digest;
    return {
      kind: "dated", submittedTime, effectiveTime, effectiveDigest
    };
  }
  if (q.message.deadline < timestamp) {
    throw Error("Artist authorization exceeded deadline");
  }
  return {
    kind: "deadline", submittedTime: q.message.deadline, effectiveTime: q.message.deadline, effectiveDigest: action.payload.digest
  };
}
function delegationRecord(v: any): CurrentArtistDelegationRecord {
  return {
    grant: {
      artistId: v.grant.artistId, delegate: v.grant.delegate, collectionId: v.grant.collectionId,
      capabilities: v.grant.capabilities, notBefore: v.grant.notBefore, expiresAt: v.grant.expiresAt,
      maxUses: v.grant.maxUses, constraintsHash: v.grant.constraintsHash
    },
    grantor: v.grantor, nonce: v.nonce, uses: v.uses, revoked: v.revoked,
    revocationRecordHash: v.revocationRecordHash
  };
}
function delegationHash(d: CurrentArtistDeployment, grant: CurrentArtistDelegationRecord["grant"], nonce: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256"], [id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), d.chainId, d.registry.address, grant.artistId,
    grant.delegate, grant.collectionId, grant.capabilities, grant.notBefore, grant.expiresAt,
    grant.maxUses, grant.constraintsHash, nonce])) as Hex;
}
function validateDelegation(d: CurrentArtistDeployment, record: CurrentArtistDelegationRecord, expected: Hex): void {
  address(record.grantor);
  address(record.grant.delegate);
  hash(record.grant.artistId);
  if (!same(delegationHash(d, record.grant, record.nonce), expected)
    || record.grant.capabilities === 0n || (record.grant.capabilities & ~1143n) !== 0n
    || record.grant.expiresAt <= record.grant.notBefore || same(record.grant.delegate, record.grantor)
    || (record.grant.maxUses !== 0n && record.uses > record.grant.maxUses)
    || record.revoked !== (record.revocationRecordHash !== ZeroHash)) {
    throw Error("Original delegation record differs");
  }
}
/** Pinned authority/replay/digest observation; adapter, content and royalty admission is established by exact-call simulation. */
export async function captureCurrentArtistOperation(p: Reader, input: CurrentArtistDeployment, request: CurrentArtistOperationRequest, options: {
  readonly blockTag: number;
}): Promise<CurrentArtistCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input);
  const action = prepareCurrentArtistAction(request);
  const q = action.request;
  const tag = number(options.blockTag);
  const m = q.message as any;
  const cid = collectionId(q);
  if (q.chainId !== d.chainId || !same(q.registry, d.registry.address)) {
    throw Error("Action deployment differs");
  }
  if (economicsOrFreeze(q) && !d.reads) {
    throw Error("Delegated economics/freeze requires the Coordinator Reads runtime pin");
  }
  const h = await context(p, d, tag, true);
  if (m.mintManager !== undefined && !same(m.mintManager, d.components[10]!.address)) {
    throw Error("Signed Mint Manager differs");
  }
  if (m.core !== undefined && !same(m.core, d.components[9]!.address)) {
    throw Error("Signed Core differs");
  }
  const observedTiming = timing(action, h.timestamp);
  let b: CurrentArtistBinding | null = null;
  if (["bindingRefusal", "saleConsent", "royaltyFreeze", "contentFreeze", "delegatedPolicyConsent", "delegatedSaleConsent"].includes(q.kind) || economicsOrFreeze(q) || (q.kind === "delegationGrant" && m.collectionId !== 0n)) {
    if ((await read(p, d.components[9]!.address, "collectionExists", [cid], tag))[0] !== true) {
      throw Error("Unknown collection");
    }
    b = binding((await read(p, d.components[0]!.address, "binding", [cid], tag))[0]);
    if (!same(b.artistId, q.artistId) || b.bindingHash === ZeroHash) {
      throw Error("Binding/replay identity differs");
    }
    const [state, generation] = await read(p, d.components[4]!.address, "attributionState", [cid], tag);
    if (generation !== b.generation) {
      throw Error("Binding generation differs");
    }
    if (q.kind === "bindingRefusal") {
      const [t] = abi.decodeFunctionData(action.method, action.call.data);
      if (b.accepted || state !== 1n || t.generation !== b.generation || !same(t.bindingHash, b.bindingHash)) {
        throw Error("Refusal requires exact pending binding");
      }
    }
    else {
      if (!b.accepted || !([2n, 3n].includes(state) || ["royaltyFreeze", "contentFreeze", "delegatedRoyaltyFreeze"].includes(q.kind) && state === 4n)) {
        throw Error("Binding is not eligible");
      }
    }
    if ((q.kind === "saleConsent" || q.kind === "delegatedSaleConsent") && b.saleConsentScope > 1n) {
      throw Error("Unsupported sale consent scope");
    }
    if (delegatedConsent(q) && b.consentMode !== 2n) {
      throw Error("Delegated consent requires mode 2");
    }
    if (economicsOrFreeze(q)) {
      if (![1n, 2n].includes(b.consentMode)) {
        throw Error("Delegated economics/freeze requires mode 1 or 2");
      }
      const name = q.kind === "delegatedRoyaltyFreeze" ? "defensiveBinding" : "acceptedBinding";
      equal(binding((await read(p, d.reads!.address, name, [cid], tag))[0]), b, "Reads binding differs");
    }
    if (q.kind === "saleConsent" || q.kind === "contentFreeze" || q.kind === "delegatedSaleConsent") {
      const [t] = await read(p, d.components[0]!.address, "bindingTerms", [m.collectionId, b.generation], tag);
      if (![1n, 2n].includes(b.consentMode) || t.mode !== 0n || t.threshold !== 0n || t.count > 32n || (await read(p, d.components[1]!.address, "acceptedCount", [b.bindingHash], tag))[0] !== t.count) {
        throw Error("Collaborator/consent profile is not ready");
      }
    }
  }
  let economics: CurrentArtistEconomicsObservation | null = null;
  if (economicsOrFreeze(q)) {
    const [t] = abi.decodeFunctionData(action.method, action.call.data);
    if (!same(t.resolver, d.components[13]!.address) && !same(t.resolver, d.components[14]!.address)) {
      throw Error("Signed economics resolver differs from Coordinator suite");
    }
    if (same(t.resolver, d.components[14]!.address)) {
      const pointer = await read(p, d.components[9]!.address, "getSatellitePointer", [id("ROYALTY_RESOLVER")], tag);
      if (!same(pointer[0], d.components[14]!.address) || !same(pointer[1], d.components[14]!.codeHash)) {
        throw Error("Royalty resolver is not selected");
      }
    }
    if (q.kind === "delegatedRoyaltyFreeze") {
      if (!same(t.resolver, d.components[14]!.address)) {
        throw Error("Royalty freeze requires the suite royalty resolver");
      }
      await read(p, d.reads!.address, "requireRoyaltyFreezeProposal", [t], tag);
    } else {
      const [account, recordHash] = await read(p, d.reads!.address, "artistPayoutAccount", [q.artistId], tag);
      const payout = { account: address(account), recordHash: hash(recordHash) };
      let candidateEvidence: Hex;
      if (q.kind === "delegatedEconomicsConsent") {
        candidateEvidence = bytes((await read(p, d.reads!.address, "requireCurrentEconomics", [t, payout.account], tag))[0]);
      } else {
        const [fact, previousHash] = await read(p, d.reads!.address, "requireProspectiveEconomicsWithEvidence", [t, q.details.candidate, payout.account], tag);
        candidateEvidence = prospectiveEvidence(q, t, coder.encode([C, AF, "bytes32"], [q.details.candidate, fact, previousHash]) as Hex);
      }
      economics = { payout, candidateEvidence };
    }
  }
  const raw = await read(p, d.components[2]!.address, "authorityState", [q.artistId], tag);
  const authority = {
    address: address(raw[0]), authorityClass: raw[1] as bigint, status: raw[2] as bigint, identityRecordHash: hash(raw[3])
  };
  let revision: CurrentArtistCapture["revision"] = null;
  let delegation: CurrentArtistDelegationRecord | null = null;
  let delegated: CurrentArtistDelegatedObservation | null = null;
  if (q.kind === "identityRevision") {
    const operativeDocumentHash = hash((await read(p, d.components[2]!.address, "operativeIdentityRecord", [q.artistId], tag))[0]);
    if (!same(operativeDocumentHash, q.message.previousRecordHash)) {
      throw Error("Operative identity document changed");
    }
    revision = { operativeDocumentHash };
  }
  if (q.kind === "delegationRevocation") {
    delegation = delegationRecord((await read(p, d.components[2]!.address, "delegationRecord", [q.message.delegationRecordHash], tag))[0]);
    validateDelegation(d, delegation, q.message.delegationRecordHash);
    if (delegation.revoked || !same(delegation.grant.artistId, q.artistId)
      || !same(delegation.grant.delegate, q.message.delegate) || !same(delegation.grantor, q.signer)) {
      throw Error("Stored delegation grantor or target differs");
    }
  }
  if (delegatedOperation(q)) {
    delegation = delegationRecord((await read(p, d.components[2]!.address, "delegationRecord", [q.details.grant], tag))[0]);
    validateDelegation(d, delegation, q.details.grant);
    const capability = q.kind === "delegatedPolicyConsent" ? 2n : q.kind === "delegatedSaleConsent" ? 1024n : q.kind === "delegatedRoyaltyFreeze" ? 32n : 4n;
    if (!same(delegation.grant.artistId, q.artistId) || !same(delegation.grant.delegate, q.signer)
      || (delegation.grant.collectionId !== 0n && delegation.grant.collectionId !== collectionId(q))
      || (delegation.grant.capabilities & capability) !== capability || !liveDelegation(delegation, h.timestamp)) {
      throw Error("Delegation scope, capability or live window unavailable");
    }
    const [valid, recorded, current] = await read(p, d.components[2]!.address, "delegationEpochState", [q.details.grant], tag);
    if (!valid || recorded !== current) {
      throw Error("Delegation epoch changed");
    }
    const remaining = delegation.grant.maxUses === 0n ? (1n << 64n) - 1n : delegation.grant.maxUses - delegation.uses;
    const status = await read(p, d.registry.address, "delegationState", [q.details.grant], tag);
    equal(Array.from(status), [true, delegation.grant.delegate, delegation.grant.collectionId,
      delegation.grant.capabilities, delegation.grant.notBefore, delegation.grant.expiresAt, remaining], "Delegation state differs");
    const replay = await delegatedReplay(p, d, q, observedTiming.effectiveDigest, tag);
    if (replay.nonceUsed || replay.digestRevoked || (q.mode === "direct" && replay.nextUnusedNonce !== q.message.nonce)) {
      throw Error("Delegate authorization consumed/revoked or direct nonce differs");
    }
    delegated = { ...replay, epochRecorded: recorded, epochCurrent: current, usesRemaining: remaining };
  }
  const expectedSigner = delegatedOperation(q) ? delegation!.grant.delegate : delegation?.grantor ?? authority.address;
  if (!same(expectedSigner, q.signer) || !ordinary(authority, [20, 21, 27, 54].includes(Number(action.operationId)))
    || ((q.kind === "delegationGrant" || delegatedOperation(q)) && authority.authorityClass !== 1n)) {
    throw Error("Current Artist authority differs");
  }
  if (authority.authorityClass !== 1n) {
    const [caps] = await read(p, d.registry.address, "currentAuthorityCapabilities", [q.artistId], tag);
    const required = action.operationId === 16n ? 1024n : action.operationId === 20n ? 32n : action.operationId === 21n ? 128n : action.operationId === 25n ? 512n : 0n;
    if (!same(caps.authorityAddress, authority.address) || caps.authorityClass !== authority.authorityClass || caps.status !== authority.status || caps.activationRecordHash === ZeroHash || (caps.effectiveCapabilities & required) !== required) {
      throw Error("Artist capability unavailable");
    }
  }
  const actual = await p.call({
    ...action.digestCall, blockTag: tag
  });
  if (!isHexString(actual, 32) || !same(actual, action.payload.digest)) {
    throw Error("Original facade digest differs");
  }
  if (!same(observedTiming.effectiveDigest, action.payload.digest)) {
    const [term, auth] = abi.decodeFunctionData(action.digestMethod, action.digestCall.data);
    const effective = [auth.nonce, observedTiming.effectiveTime, auth.signature];
    const value = await read(p, d.registry.address, action.digestMethod, [term, effective], tag);
    if (!same(value[0], observedTiming.effectiveDigest)) {
      throw Error("Effective identity revision digest differs");
    }
  }
  const state = await replayRead(p, d, q.artistId, observedTiming.effectiveDigest, m.nonce, tag);
  if (state.digestRevoked || (!delegatedOperation(q) && (state.nonceConsumed || state.nonceRevoked))) {
    throw Error("Artist authorization consumed/revoked");
  }
  if (!delegatedOperation(q) && q.mode === "direct" && m.nonce !== state.nextUnusedNonce) {
    throw Error("Direct nonce differs from current hint");
  }
  if (q.mode === "signature") {
    const [cap, , failure, revision] = await read(p, d.registry.address, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS")], tag);
    if (cap < 90000n || failure !== 2n || revision === 0n) {
      throw Error("Invalid signature validation gas policy");
    }
  }
  let revocationTarget: CurrentArtistReplay | null = null;
  if (q.kind === "authorizationRevocation") {
    revocationTarget = await replayRead(p, d, q.artistId, m.revokedDigest, m.revokedNonce, tag);
    if (m.revokedDigest !== ZeroHash ? (revocationTarget.digestObserved || revocationTarget.digestRevoked) : (revocationTarget.nonceConsumed || revocationTarget.nonceRevoked)) {
      throw Error("Revocation target already consumed/revoked");
    }
  }
  await unchanged(p, h);
  const body = {
    deployment: d, action, ...h, authority, binding: b, replay: state, revocationTarget, timing: observedTiming, revision, delegation, delegated, economics, simulationRequired: true as const
  };
  return freeze({
    ...body, captureHash: captureHash(body)
  });
}
/** Revalidate saved historical facts and refresh admission at a concrete block without changing calldata. */
export async function simulateCurrentArtistCall(p: Reader, input: CurrentArtistCapture, options: {
  readonly blockTag: number;
}): Promise<{
  readonly capture: CurrentArtistCapture;
  readonly observation: CurrentArtistCapture;
  readonly recordHash: Hex;
}> {
  keys(options, ["blockTag"]);
  const c = saved(input);
  const tag = number(options.blockTag);
  if (tag < c.blockNumber) {
    throw Error("Simulation predates capture");
  }
  equal(await captureCurrentArtistOperation(p, c.deployment, c.action.request, { blockTag: c.blockNumber }), c, "Historical capture differs");
  const fresh = await captureCurrentArtistOperation(p, c.deployment, c.action.request, { blockTag: tag });
  equal(fresh.binding, c.binding, "Binding changed; capture again");
  equal(fresh.authority, c.authority, "Authority changed; capture again");
  equal(fresh.revision, c.revision, "Identity revision state changed; capture again");
  equal(fresh.delegation, c.delegation, "Delegation state changed; capture again");
  equal(fresh.delegated, c.delegated, "Delegate replay or epoch changed; capture again");
  equal(fresh.economics, c.economics, "Economics admission facts changed; capture again");
  const raw = await p.call({
    ...c.action.call, from: c.action.request.caller, blockTag: tag
  });
  const result = hash(raw);
  if (!same(result, originalRecord(fresh, fresh.timestamp))) {
    throw Error("Simulated original record differs");
  }
  await unchanged(p, fresh);
  return freeze({
    capture: c, observation: fresh, recordHash: result
  });
}
/**
* Independent ordered ordinary CALLs; dependent state must be mined and recaptured between steps.
* Direct dated-zero calls have no fixed future digest. Only known nonce/digest conflicts are checked;
* their effective digest and full admission must be revalidated at the execution block.
*/
export function createCurrentArtistSafePlan(captures: readonly CurrentArtistCapture[], title: string): SafeCallPlan {
  if (!Array.isArray(captures) || !captures.length || captures.length > 256) {
    throw Error("Expected 1..256 Artist calls");
  }
  const items = captures.map(saved);
  const chainId = items[0]!.deployment.chainId;
  if (items.some(c => c.deployment.chainId !== chainId)) {
    throw Error("Mixed chains");
  }
  const authorizations = new Set<string>();
  const authorizationDigests = new Set<string>();
  const revocationTargets = new Set<string>();
  const delegationRevocations = new Set<string>();
  const lane = (c: CurrentArtistCapture) => c.action.request.registry.toLowerCase() + ":" + c.action.request.artistId.toLowerCase();
  for (const c of items) {
    const nonceLane = delegatedOperation(c.action.request) ? lane(c) + ":delegate:" + c.action.request.signer.toLowerCase() : lane(c);
    const nonceKey = nonceLane + ":nonce:" + c.action.request.message.nonce.toString();
    if (authorizations.has(nonceKey)) {
      throw Error("Duplicate Artist authorization nonce in Safe plan");
    }
    authorizations.add(nonceKey);
    if (c.action.request.kind === "identityRevision" && c.action.request.mode === "direct" && c.action.request.message.signedAt === 0n) {
    }
    else {
      authorizationDigests.add(lane(c) + ":digest:" + c.action.payload.digest.toLowerCase());
    }
  }
  for (const c of items) {
    const q = c.action.request;
    if (delegatedOperation(q) && delegationRevocations.has(q.registry.toLowerCase() + ":" + q.details.grant.toLowerCase())) {
      throw Error("Delegated consent follows its grant revocation in Safe plan");
    }
    if (q.kind === "delegationRevocation") {
      const target = q.registry.toLowerCase() + ":" + q.message.delegationRecordHash.toLowerCase();
      if (delegationRevocations.has(target)) {
        throw Error("Repeated delegation revocation target in Safe plan");
      }
      delegationRevocations.add(target);
    }
    if (q.kind !== "authorizationRevocation") {
      continue;
    }
    const target = q.message.revokedDigest !== ZeroHash
      ? lane(c) + ":digest:" + q.message.revokedDigest.toLowerCase()
      : lane(c) + ":nonce:" + q.message.revokedNonce.toString();
    if (revocationTargets.has(target) || authorizations.has(target) || authorizationDigests.has(target)) {
      throw Error("Conflicting Artist revocation target in Safe plan");
    }
    revocationTargets.add(target);
  }
  return createSafeCallPlan(chainId, title, items.map(c => ({
    safe: c.action.request.caller, intent: `Artist operation ${c.action.operationId}: ${c.action.method}`, call: c.action.call, abi: abi.fragments
  })));
}
function originalRecord(c: CurrentArtistCapture, time: bigint, payoutHash?: Hex): Hex {
  const q = c.action.request;
  const m = q.message as any;
  const [t] = abi.decodeFunctionData(c.action.method, c.action.call.data);
  const chain = c.deployment.chainId;
  const host = c.deployment.registry.address;
  const core = c.deployment.components[9]!.address;
  const artist = q.artistId;
  const signer = q.signer;
  const cl = delegatedOperation(q) ? 2n : c.authority.authorityClass;
  const n = m.nonce;
  const common = [chain, host];
  let types: string[];
  let values: unknown[];
  switch (q.kind) {
    case "bindingRefusal":
      types = ["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "bytes32", "address", "uint8", "bytes32", "uint256", "uint64"];
      values = ["0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed", ...common, core, t.collectionId, t.generation, t.bindingHash, artist, signer, cl, t.reasonHash, n, time];
      break;
    case "delegatedSaleConsent":
    case "saleConsent":
      types = ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"), ...common, t.saleAdapter, core, t.collectionId, t.saleId, t.saleConfigHash, artist, signer, cl, n, time];
      break;
    case "delegatedPolicyConsent":
      types = ["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1"), chain, host, c.deployment.components[10]!.address,
        t.collectionId, t.phaseId, t.policyHash, artist, signer, cl, n, time];
      break;
    case "delegatedEconomicsConsent":
    case "delegatedProspectiveEconomicsConsent":
      types = ["bytes32", "uint256", "address", "address", "bytes32", "uint8", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1"), ...common, t.resolver, t.revenueClass,
        t.scope, t.scopeId, t.assignmentHash, payoutHash ?? c.economics!.payout.recordHash, artist, signer, cl, n, time];
      break;
    case "delegatedRoyaltyFreeze":
    case "royaltyFreeze":
      types = ["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"), ...common, t.resolver, t.collectionId, t.revenueClass, t.expectedAssignmentHash, artist, signer, cl, n, time];
      break;
    case "contentFreeze":
      types = ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32[]", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"), ...common, t.metadataContract, core, t.collectionId, t.lockClasses, t.expectedStateHash, artist, signer, cl, n, time];
      break;
    case "identityRevision": {
      const effective = timing(c.action, time);
      types = ["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = ["0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4", ...common,
        artist, t.previousRecordHash, t.revisedRecordHash, signer, cl, n, effective.effectiveTime];
      break;
    }
    case "delegationGrant":
      return delegationHash(c.deployment, t, n);
    case "delegationRevocation":
      types = ["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "address", "uint8", "bytes32", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_DELEGATION_REVOCATION_RECORD_V1"), ...common, artist, t.delegate,
        t.delegationRecordHash, signer, 1, t.reasonHash, n, time];
      break;
    case "authorizationRevocation":
      types = ["bytes32", "uint256", "address", "bytes32", "bytes32", "uint256", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1"), ...common, artist, t.revokedDigest, t.revokedNonce, n, time];
      break;
  }
  return keccak256(coder.encode(types, values)) as Hex;
}
function decode(types: readonly string[], raw: string): any {
  const v = coder.decode(types, bytes(raw));
  if (!same(coder.encode(types, v), raw)) {
    throw Error("Noncanonical Archive evidence");
  }
  return v;
}
function bindingArray(b: CurrentArtistBinding): readonly unknown[] {
  return [b.artistId, b.artistAddress, b.identityRecordHash, b.bindingHash, b.generation, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection, b.proposer, b.accepted];
}
function saleFacts(raw: Hex, terms: any): void {
  const facts = decode(["address", "bytes32", "bytes32", "bytes32", "bytes4", "uint256", "bytes32"], raw);
  if (facts[5] !== terms.collectionId || !same(facts[6], terms.saleConfigHash) || facts[4] === "0x00000000" || facts[4] === "0xffffffff") {
    throw Error("Archive sale facts differ");
  }
  address(facts[0]);
  hash(facts[1]);
  hash(facts[2]);
  hash(facts[3]);
}
/** Verify a singleton direct or ordinary Safe CALL, original owner records and exact Archive evidence. */
export async function inspectCurrentArtistReceipt(p: ReceiptReader, input: CurrentArtistCapture, evidence: {
  readonly transactionHash: Hex;
  readonly execution: "direct" | "safe";
}): Promise<CurrentArtistReceipt> {
  keys(evidence, ["transactionHash", "execution"]);
  const c = saved(input);
  const transactionHash = hash(evidence.transactionHash);
  const execution = evidence.execution;
  if (execution !== "direct" && execution !== "safe") {
    throw Error("Unknown receipt mode");
  }
  const d = c.deployment;
  const a = c.action;
  const q = a.request;
  const m = q.message as any;
  const decodedCall = abi.decodeFunctionData(a.method, a.call.data);
  const t = decodedCall[0];
  const auth = decodedCall[q.kind === "delegatedProspectiveEconomicsConsent" ? 3 : delegatedOperation(q) ? 2 : 1];
  equal(await captureCurrentArtistOperation(p, d, q, { blockTag: c.blockNumber }), c, "Historical capture differs");
  const [tx, r] = await Promise.all([p.getTransaction(transactionHash), p.getTransactionReceipt(transactionHash)]);
  if (!tx || !r || !same(tx.hash, transactionHash) || !same(r.hash, transactionHash) || r.status !== 1 || tx.chainId !== d.chainId || tx.blockNumber === null || r.blockNumber !== tx.blockNumber || !same(tx.blockHash, r.blockHash) || !same(tx.from, r.from) || !same(tx.to, r.to) || tx.value !== 0n || r.blockNumber <= c.blockNumber) {
    throw Error("Successful receipt must follow captured block");
  }
  const tag = number(r.blockNumber);
  const blockHash = hash(r.blockHash);
  const data = bytes(tx.data, 524288);
  if (execution === "direct") {
    if (!same(tx.from, q.caller) || !same(tx.to, a.call.to) || !same(data, a.call.data)) {
      throw Error("Direct Artist CALL differs");
    }
  }
  else {
    if (!same(tx.to, q.caller)) {
      throw Error("Safe caller differs");
    }
    const v = safe.decodeFunctionData("execTransaction", data);
    if (!same(safe.encodeFunctionData("execTransaction", v), data) || !same(v.to, a.call.to) || v.value !== 0n || v.operation !== 0n || !same(v.data, a.call.data)) {
      throw Error("Safe ordinary CALL differs");
    }
  }
  const h = await context(p, d, tag, false);
  const executedTiming = timing(a, h.timestamp);
  if (!same(h.blockHash, blockHash) || !same(h.configurationHash, c.configurationHash)) {
    throw Error("Receipt block/configuration differs");
  }
  if (!Array.isArray(r.logs) || r.logs.length > 512) {
    throw Error("Receipt log bound exceeded");
  }
  let previous = -1;
  const logs = r.logs.map(l => {
    if (l.removed || l.blockNumber !== tag || !same(l.blockHash, blockHash) || !same(l.transactionHash, transactionHash) || number(l.index) <= previous || !Array.isArray(l.topics) || l.topics.length > 4) {
      throw Error("Malformed receipt log");
    }
    previous = l.index;
    return {
      address: address(l.address), index: l.index, data: bytes(l.data, 65536), topics: l.topics.map((v: string) => hash(v, true))
    };
  });
  const refs: CurrentArtistEventReference[] = [];
  let payoutHash: Hex | undefined;
  if (economicsOperation(q)) {
    const fragment = abi.getEvent("ArtistEconomicsConsentRecorded")!;
    const hits = logs.filter(l => same(l.address, d.components[6]!.address) && same(l.topics[0], fragment.topicHash));
    if (hits.length !== 1) {
      throw Error("Expected one ArtistEconomicsConsentRecorded");
    }
    const v = abi.decodeEventLog(fragment, hits[0]!.data, hits[0]!.topics);
    payoutHash = hash(v.payoutDesignationRecordHash);
  }
  const recordHash = originalRecord(c, h.timestamp, payoutHash);
  const event = (target: Address, name: string, expected: readonly unknown[], iface = abi) => {
    const f = iface.getEvent(name)!;
    const hits = logs.filter(l => same(l.address, target) && same(l.topics[0], f.topicHash));
    if (hits.length !== 1) {
      throw Error(`Expected one ${name}`);
    }
    const l = hits[0]!;
    const v = iface.decodeEventLog(f, l.data, l.topics);
    const encoded = iface.encodeEventLog(f, v);
    const wanted = iface.encodeEventLog(f, expected);
    if (!same(encoded.data, l.data) || !same(wanted.data, l.data) || stable(encoded.topics.map(v => v.toLowerCase())) !== stable(l.topics) || stable(wanted.topics.map(v => v.toLowerCase())) !== stable(l.topics)) {
      throw Error(`${name} differs`);
    }
    refs.push({
      address: target, event: name, logIndex: l.index, transactionHash, blockHash
    });
    return l.index;
  };
  const cl = delegatedOperation(q) ? 2n : c.authority.authorityClass;
  const n = m.nonce;
  const at = h.timestamp;
  const owner = d.components[6]!.address;
  const identityOwner = d.components[2]!.address;
  let revokedReadback: CurrentArtistDelegationRecord | null = null;
  let economicsAssociation: CurrentArtistEconomicsAssociation | null = null;
  let economics: CurrentArtistReceipt["economics"] = null;
  switch (q.kind) {
    case "identityRevision": {
      const first = event(identityOwner, "ArtistIdentityRevisionRecorded", [1, q.artistId, q.signer,
        t.previousRecordHash, t.revisedRecordHash, t.identityRecordURI, cl, n, executedTiming.effectiveTime, recordHash]);
      const last = event(identityOwner, "ArtistIdentityDisplayNameStored", [q.artistId, t.revisedRecordHash, q.details.displayName]);
      if (first >= last) {
        throw Error("Identity revision event order differs");
      }
      const [record] = await read(p, identityOwner, "identityRevisionRecord", [recordHash], tag);
      const expected = [recordHash, q.artistId, t.previousRecordHash, t.revisedRecordHash,
        record.previousRevisionRecord, q.signer, 1n, n, executedTiming.effectiveTime,
        t.identityRecordURI, q.details.displayName];
      const type = abi.getFunction("identityRevisionRecord")!.outputs![0]!;
      if (!same(coder.encode([type], [record]), coder.encode([type], [expected]))) {
        throw Error("Historical identity revision differs");
      }
      if (record.previousRevisionRecord === ZeroHash && !same(t.previousRecordHash, c.authority.identityRecordHash)) {
        throw Error("Zero revision predecessor differs from original registration");
      }
      if (record.previousRevisionRecord !== ZeroHash) {
        if (same(record.previousRevisionRecord, recordHash)) {
          throw Error("Identity revision cannot precede itself");
        }
        const [prior] = await read(p, identityOwner, "identityRevisionRecord", [record.previousRevisionRecord], tag);
        if (!same(prior.recordHash, record.previousRevisionRecord) || !same(prior.artistId, q.artistId)
          || !same(prior.revisedRecordHash, t.previousRecordHash)) {
          throw Error("Historical revision predecessor differs");
        }
      }
      const [document] = await read(p, identityOwner, "identityDocumentBytes", [t.revisedRecordHash], tag);
      if (!same(bytes(document, 8192), q.details.document)) {
        throw Error("Historical identity document differs");
      }
      break;
    }
    case "delegationGrant": {
      event(identityOwner, "ArtistDelegationGranted", [1, q.artistId, t.delegate, t.collectionId,
        t.capabilities, t.notBefore, t.expiresAt, t.maxUses, t.constraintsHash, n, recordHash]);
      const record = delegationRecord((await read(p, identityOwner, "delegationRecord", [recordHash], tag))[0]);
      validateDelegation(d, record, recordHash);
      if (!same(coder.encode([G], [record.grant]), coder.encode([G], [t]))
        || !same(record.grantor, q.signer) || record.nonce !== n) {
        throw Error("Historical delegation grant differs");
      }
      break;
    }
    case "delegationRevocation": {
      event(identityOwner, "ArtistDelegationRevoked", [1, q.artistId, t.delegate, t.delegationRecordHash,
        t.reasonHash, q.signer, 1, n, at]);
      revokedReadback = delegationRecord((await read(p, identityOwner, "delegationRecord", [t.delegationRecordHash], tag))[0]);
      validateDelegation(d, revokedReadback, t.delegationRecordHash);
      if (!revokedReadback.revoked || !same(revokedReadback.revocationRecordHash, recordHash)
        || !same(revokedReadback.grantor, q.signer) || !same(revokedReadback.grant.artistId, q.artistId)
        || !same(revokedReadback.grant.delegate, t.delegate)) {
        throw Error("Historical delegation revocation differs");
      }
      break;
    }
    case "bindingRefusal": {
      const first = event(d.components[4]!.address, "ArtistAttributionStateChanged", [1, t.collectionId, 5, t.generation, 1, q.caller, cl, recordHash, t.reasonHash, t.reasonURI]);
      const last = event(d.components[4]!.address, "ArtistBindingTerminationContext", [1, t.collectionId, t.generation, recordHash, t.bindingHash, q.artistId, q.signer, n, at]);
      if (first >= last) {
        throw Error("Refusal event order differs");
      }
      const [terminal] = await read(p, d.registry.address, "bindingTermination", [t.collectionId, t.generation], tag);
      equal(Array.from(terminal), [1n, t.reasonHash, recordHash], "Historical binding refusal differs");
      break;
    }
    case "delegatedSaleConsent":
    case "saleConsent": {
      event(owner, "ArtistSaleConsentRecorded", [1, t.collectionId, t.saleConfigHash, q.signer, t.saleId, cl, n, at, recordHash]);
      const [v] = await read(p, d.registry.address, "saleConsentRecord", [recordHash], tag);
      const expected = [recordHash, t, q.artistId, q.signer, cl, n, at, c.binding!.generation, c.binding!.bindingHash];
      if (!same(coder.encode([abi.getFunction("saleConsentRecord")!.outputs![0]!], [v]), coder.encode([abi.getFunction("saleConsentRecord")!.outputs![0]!], [expected]))) {
        throw Error("Historical sale consent differs");
      }
      break;
    }
    case "delegatedPolicyConsent": {
      event(owner, "ArtistPolicyConsentRecorded", [1, t.collectionId, t.policyHash, q.signer, t.phaseId, cl, n, at, recordHash]);
      if (!same((await read(p, owner, "policyRecord", [t.collectionId, t.phaseId, t.policyHash], tag))[0], recordHash)) {
        throw Error("Historical policy consent differs");
      }
      break;
    }
    case "delegatedEconomicsConsent":
    case "delegatedProspectiveEconomicsConsent": {
      const primary = event(owner, "ArtistEconomicsConsentRecorded", [1, t.collectionId, t.assignmentHash,
        q.signer, t.revenueClass, t.scope, t.scopeId, payoutHash, 2, n, at, recordHash]);
      const grantEvent = event(owner, "ArtistRecordDelegation", [1, recordHash, q.details.grant,
        q.artistId, t.resolver, t.revenueClass, 2]);
      const [association] = await read(p, owner, "economicsRecordAssociation", [recordHash], tag);
      const original = hash(association.originalRecord);
      const payloadHash = keccak256(coder.encode([E], [t])) as Hex;
      const expected = [q.artistId, c.binding!.generation, c.binding!.bindingHash, payloadHash, original];
      if (!same(coder.encode([EA], [association]), coder.encode([EA], [expected]))
        || !same((await read(p, owner, "economicsRecordForBinding", [t, q.artistId, c.binding!.generation, c.binding!.bindingHash], tag))[0], recordHash)
        || !same((await read(p, owner, "economicsRecord", [t], tag))[0], original)) {
        throw Error("Historical economics binding association differs");
      }
      if (!same(original, recordHash)) {
        const [first] = await read(p, owner, "economicsRecordAssociation", [original], tag);
        if (!same(first.originalRecord, original) || !same(first.payloadHash, payloadHash)
          || first.artistId === ZeroHash || first.bindingHash === ZeroHash || first.bindingGeneration === 0n
          || first.bindingGeneration >= c.binding!.generation) {
          throw Error("Original economics continuation association differs");
        }
      }
      const associated = event(owner, "ArtistEconomicsConsentAssociated", [1, recordHash, q.artistId,
        c.binding!.bindingHash, c.binding!.generation, payloadHash, original]);
      if (primary >= grantEvent || grantEvent >= associated
        || !same((await read(p, owner, "recordDelegation", [recordHash], tag))[0], q.details.grant)) {
        throw Error("Economics delegation event order/association differs");
      }
      economicsAssociation = {
        artistId: q.artistId, bindingGeneration: c.binding!.generation, bindingHash: c.binding!.bindingHash,
        payloadHash, originalRecord: original
      };
      break;
    }
    case "delegatedRoyaltyFreeze":
    case "royaltyFreeze": {
      event(owner, "ArtistRoyaltyFreezeAuthorized", [1, t.collectionId, t.expectedAssignmentHash, q.signer, cl, n, at, recordHash]);
      const [v] = await read(p, owner, "royaltyFreezeRecord", [t, q.artistId, c.binding!.generation], tag);
      equal(Array.from(v), [recordHash, q.artistId, c.binding!.generation], "Historical royalty freeze differs");
      break;
    }
    case "contentFreeze": {
      const first = event(owner, "ArtistContentFreezeAuthorized", [1, t.collectionId, q.signer, t.lockClasses, t.expectedStateHash, cl, n, at, recordHash]);
      const last = event(owner, "ArtistContentRecordContext", [1, recordHash, t.metadataContract, q.artistId]);
      if (first >= last) {
        throw Error("Content event order differs");
      }
      const [v] = await read(p, d.registry.address, "contentFreezeAuthorization", [recordHash], tag);
      const type = abi.getFunction("contentFreezeAuthorization")!.outputs![0]!;
      if (!same(coder.encode([type], [v]), coder.encode([type], [[recordHash, q.artistId, c.binding!.generation, t.metadataContract, t.lockClasses, t.expectedStateHash, cl]]))) {
        throw Error("Historical content freeze differs");
      }
      break;
    }
    case "authorizationRevocation":
      event(d.components[2]!.address, "ArtistAuthorizationRevoked", [1, q.artistId, t.revokedDigest, t.revokedNonce, n, at, recordHash]);
      break;
  }
  if (delegatedConsent(q)) {
    const previous = refs[refs.length - 1]!.logIndex;
    const association = event(owner, "ArtistConsentDelegationRecorded", [1, recordHash, q.details.grant, q.artistId, a.operationId]);
    if (association <= previous || !same((await read(p, owner, "recordDelegation", [recordHash], tag))[0], q.details.grant)) {
      throw Error("Consent delegation association differs");
    }
  }
  if (q.kind === "delegatedRoyaltyFreeze") {
    const previous = refs[refs.length - 1]!.logIndex;
    const association = event(owner, "ArtistRecordDelegation", [1, recordHash, q.details.grant,
      q.artistId, t.resolver, t.revenueClass, 2]);
    if (association <= previous || !same((await read(p, owner, "recordDelegation", [recordHash], tag))[0], q.details.grant)) {
      throw Error("Royalty freeze delegation association differs");
    }
  }
  const evidenceId = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), d.chainId, d.registry.address, d.coordinator.address, a.operationId, q.caller, recordHash])) as Hex;
  const archive = d.components[8]!.address;
  const metadata = await read(p, archive, "artistEvidenceMetadataV2", [evidenceId, 1], tag);
  const [raw] = await read(p, archive, "artistEvidenceBytesV2", [evidenceId, 1], tag);
  if (metadata[3] !== BigInt(tag) || metadata[2] !== BigInt((bytes(raw).length - 2) / 2) || !same(metadata[0], keccak256(raw))) {
    throw Error("Archive metadata differs");
  }
  address(metadata[1]);
  const archiveIndex = event(archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1, metadata[0], metadata[1], metadata[2]]);
  if (refs.some(e => e.event !== "ArtistArchiveEvidenceAppendedV2" && e.logIndex >= archiveIndex)) {
    throw Error("Archive precedes owner evidence");
  }
  const v = decode(["uint16", "bytes32", "uint16", "address", "bytes32", `${S}[7]`, `${S}[7]`, "bytes"], raw);
  if (v[0] !== 1n || !same(v[1], c.configurationHash) || v[2] !== a.operationId || !same(v[3], q.caller) || !same(v[4], recordHash)) {
    throw Error("Archive operation envelope differs");
  }
  const identityOnly = ["identityRevision", "delegationGrant", "delegationRevocation", "authorizationRevocation"].includes(q.kind);
  const mask = identityOnly ? 4 : q.kind === "bindingRefusal" ? 21 : economicsOperation(q) ? 119 : 87;
  const writeMask = identityOnly ? 4 : q.kind === "bindingRefusal" ? 21 : 68;
  for (let i = 0; i < 7; i++) {
    const before = v[5][i];
    const after = v[6][i];
    if (mask & (1 << i)) {
      if (!same(before.domainId, domains[i]) || !same(after.domainId, domains[i]) || before.stateRoot === ZeroHash || after.stateRoot === ZeroHash) {
        throw Error("Archive owner snapshots differ");
      }
      if (writeMask & (1 << i)) {
        if (after.revision !== before.revision + 1n || after.recordChainTip === ZeroHash) {
          throw Error("Archive written owner must advance exactly once");
        }
      }
      else {
        if (!same(coder.encode([S], [before]), coder.encode([S], [after]))) {
          throw Error("Archive read-only owner changed");
        }
      }
    }
    else {
      if (!same(coder.encode([S], [before]), coder.encode([S], [[ZeroHash, 0, ZeroHash, ZeroHash]])) || !same(coder.encode([S], [after]), coder.encode([S], [[ZeroHash, 0, ZeroHash, ZeroHash]]))) {
        throw Error("Unexpected Archive owner snapshot");
      }
    }
  }
  const proof = [q.signer, executedTiming.effectiveDigest, q.mode === "direct"];
  const authority = [q.artistId, q.signer, cl, c.authority.status];
  let payloadTypes: string[];
  let payloadValues: unknown[];
  let priorGrant: CurrentArtistDelegationRecord | null = null;
  if (delegatedOperation(q)) {
    const decoded = economicsOrFreeze(q)
      ? decode(["bytes", "bytes32", D], v[7])
      : decode([B, terms[q.kind], A, P, "bytes32", D, "bytes"], v[7]);
    const prior = delegationRecord(decoded[economicsOrFreeze(q) ? 2 : 5]);
    validateDelegation(d, prior, q.details.grant);
    if (!liveDelegation(prior, h.timestamp) || prior.uses < c.delegation!.uses
      || !same(prior.grantor, c.delegation!.grantor) || prior.nonce !== c.delegation!.nonce
      || !same(coder.encode([G], [prior.grant]), coder.encode([G], [c.delegation!.grant]))) {
      throw Error("Archive delegated consent grant differs");
    }
    const after = delegationRecord((await read(p, identityOwner, "delegationRecord", [q.details.grant], tag))[0]);
    validateDelegation(d, after, q.details.grant);
    if (after.uses < prior.uses + 1n || !same(after.grantor, prior.grantor) || after.nonce !== prior.nonce
      || !same(coder.encode([G], [after.grant]), coder.encode([G], [prior.grant]))) {
      throw Error("Delegation consumption readback differs");
    }
    priorGrant = prior;
  }
  if (economicsOrFreeze(q)) {
    payloadTypes = ["bytes", "bytes32", D];
    const [inner] = decode(payloadTypes, v[7]);
    let expectedInner: Hex;
    if (economicsOperation(q)) {
      const decoded = decode([B, E, PAYOUT, A, P, "bytes", EA], inner);
      const payout = { account: address(decoded[2].account), recordHash: hash(decoded[2].recordHash) };
      const [designation] = await read(p, d.components[5]!.address, "designationRecord", [payout.recordHash], tag);
      if (!same(payout.recordHash, payoutHash) || !same(designation.artistId, q.artistId)
        || !same(designation.payoutAccount, payout.account)) {
        throw Error("Historical economics payout designation differs");
      }
      let candidateEvidence = bytes(decoded[5]);
      if (q.kind === "delegatedProspectiveEconomicsConsent") {
        candidateEvidence = prospectiveEvidence(q, t, candidateEvidence);
      }
      economics = { payout, candidateEvidence, association: economicsAssociation! };
      expectedInner = coder.encode([B, E, PAYOUT, A, P, "bytes", EA],
        [bindingArray(c.binding!), t, payout, auth, proof, candidateEvidence, economicsAssociation!]) as Hex;
    } else {
      expectedInner = coder.encode([B, terms.royaltyFreeze, A, P], [bindingArray(c.binding!), t, auth, proof]) as Hex;
    }
    payloadValues = [expectedInner, q.details.grant, priorGrant];
  }
  else if (delegatedConsent(q)) {
    payloadTypes = [B, terms[q.kind], A, P, "bytes32", D, "bytes"];
    const decoded = decode(payloadTypes, v[7]);
    if (q.kind === "delegatedPolicyConsent") {
      if (decoded[6] !== "0x") {
        throw Error("Policy consent facts must be empty");
      }
    } else {
      saleFacts(decoded[6], t);
    }
    payloadValues = [bindingArray(c.binding!), t, auth, proof, q.details.grant, priorGrant, decoded[6]];
  }
  else if (q.kind === "identityRevision") {
    payloadTypes = [terms.identityRevision, A, "bytes", "string", P, A];
    payloadValues = [t, auth, q.details.document, q.details.displayName, proof,
      [auth.nonce, executedTiming.effectiveTime, auth.signature]];
  }
  else {
    if (q.kind === "delegationRevocation") {
      payloadTypes = [D, terms.delegationRevocation, A, P];
      const decoded = decode(payloadTypes, v[7]);
      const prior = delegationRecord(decoded[0]);
      validateDelegation(d, prior, t.delegationRecordHash);
      if (prior.revoked || prior.uses < c.delegation!.uses || prior.uses !== revokedReadback!.uses
        || !same(prior.grantor, c.delegation!.grantor) || prior.nonce !== c.delegation!.nonce
        || !same(coder.encode([G], [prior.grant]), coder.encode([G], [c.delegation!.grant]))) {
        throw Error("Archive prior delegation differs");
      }
      payloadValues = [prior, t, auth, proof];
    }
    else {
      if (q.kind === "authorizationRevocation" || q.kind === "delegationGrant") {
        payloadTypes = [terms[q.kind], A, P];
        payloadValues = [t, auth, proof];
      }
      else {
        payloadTypes = [B, terms[q.kind], A, P];
        payloadValues = [bindingArray(c.binding!), t, auth, proof];
        if (q.kind === "bindingRefusal" || q.kind === "saleConsent") {
          payloadTypes.push(F);
          payloadValues.push(authority);
        }
        if (q.kind === "saleConsent") {
          payloadTypes.push("bytes");
          const decoded = decode(payloadTypes, v[7]);
          saleFacts(decoded[5], t);
          payloadValues.push(decoded[5]);
        }
      }
    }
  }
  if (!same(coder.encode(payloadTypes, payloadValues), v[7])) {
    throw Error("Archive request/authority/proof differs");
  }
  const observedReplay = await replayRead(p, d, q.artistId, executedTiming.effectiveDigest, m.nonce, tag);
  let observedDelegated: CurrentArtistReceipt["observedDelegated"] = null;
  if (delegatedOperation(q)) {
    const state = await delegatedReplay(p, d, q, executedTiming.effectiveDigest, tag);
    if (!state.nonceUsed || state.digestRevoked) {
      throw Error("Executed delegate authorization not consumed");
    }
    observedDelegated = { nonceUsed: state.nonceUsed, nextUnusedNonce: state.nextUnusedNonce };
  }
  if (!observedReplay.digestObserved || observedReplay.digestRevoked
    || (!delegatedOperation(q) && (!observedReplay.nonceConsumed || observedReplay.nonceRevoked))) {
    throw Error("Executed Artist authorization not consumed");
  }
  if (q.kind === "authorizationRevocation") {
    const target = await replayRead(p, d, q.artistId, t.revokedDigest, t.revokedNonce, tag);
    if (t.revokedDigest !== ZeroHash ? (!target.digestRevoked || target.digestObserved) : (!target.nonceRevoked || !target.nonceConsumed)) {
      throw Error("Revocation target not retained");
    }
  }
  if (execution === "safe") {
    const successes = logs.filter(l => same(l.address, q.caller) && same(l.topics[0], safe0.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1 || logs.some(l => same(l.address, q.caller) && same(l.topics[0], safe0.getEvent("ExecutionFailure")!.topicHash))) {
      throw Error("Expected Safe success and no failure");
    }
    const l = successes[0]!;
    const iface = l.topics.length === 2 ? safe1 : safe0;
    const f = iface.getEvent("ExecutionSuccess")!;
    const values = iface.decodeEventLog(f, l.data, l.topics);
    hash(values[0]);
    const success = event(q.caller, "ExecutionSuccess", Array.from(values), iface);
    if (refs.some(e => e.event !== "ExecutionSuccess" && e.logIndex >= success)) {
      throw Error("Safe success must follow operation evidence");
    }
  }
  await unchanged(p, h);
  return freeze({
    capture: c, transactionHash, blockNumber: tag, blockHash, recordHash, evidenceId, events: refs.sort((a, b) => a.logIndex - b.logIndex), observedReplay, observedDelegated, effectiveDigest: executedTiming.effectiveDigest, economics
  });
}

export type CurrentArtistRecordedConsentRequest = {
  readonly kind: "policy";
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly policyHash: Hex;
  readonly recordHash: Hex;
} | {
  readonly kind: "sale";
  readonly collectionId: bigint;
  readonly saleAdapter: Address;
  readonly saleId: Hex;
  readonly saleConfigHash: Hex;
  readonly recordHash: Hex;
};
export interface CurrentArtistRecordedConsentObservation {
  readonly deployment: CurrentArtistDeployment;
  readonly request: CurrentArtistRecordedConsentRequest;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
  readonly configurationHash: Hex;
  readonly recordHash: Hex;
  /** Zero for an original principal consent; nonzero binds the creation grant without rereading its liveness. */
  readonly delegationRecordHash: Hex;
  readonly applicability: "policy-record-only" | "sale-consent-checked-for-adapter";
  readonly checkedCall: {
    readonly to: Address;
    readonly data: Hex;
    readonly value: 0n;
    readonly from: Address;
  } | null;
}
function recordedRequest(input: CurrentArtistRecordedConsentRequest): CurrentArtistRecordedConsentRequest {
  if (input.kind === "policy") {
    keys(input, ["kind", "collectionId", "phaseId", "policyHash", "recordHash"]);
    const result = {
      kind: "policy" as const, collectionId: uint(input.collectionId), phaseId: hash(input.phaseId),
      policyHash: hash(input.policyHash), recordHash: hash(input.recordHash)
    };
    if (result.collectionId === 0n) {
      throw Error("Expected nonzero collection");
    }
    return freeze(result);
  }
  if (input.kind === "sale") {
    keys(input, ["kind", "collectionId", "saleAdapter", "saleId", "saleConfigHash", "recordHash"]);
    const result = {
      kind: "sale" as const, collectionId: uint(input.collectionId), saleAdapter: address(input.saleAdapter),
      saleId: hash(input.saleId), saleConfigHash: hash(input.saleConfigHash), recordHash: hash(input.recordHash)
    };
    if (result.collectionId === 0n) {
      throw Error("Expected nonzero collection");
    }
    return freeze(result);
  }
  throw Error("Unsupported recorded consent kind");
}
/**
 * Observe the exact durable consent independently of its creation grant.
 * Policy is a record lookup only, not complete mint admission. Sale invokes the original caller-sensitive
 * requireSaleConsent from the supplied adapter and verifies its stored terms and delegation association.
 */
export async function inspectCurrentArtistRecordedConsent(
  p: Reader,
  input: CurrentArtistDeployment,
  request: CurrentArtistRecordedConsentRequest,
  options: { readonly blockTag: number }
): Promise<CurrentArtistRecordedConsentObservation> {
  keys(options, ["blockTag"]);
  const d = deployment(input);
  const q = recordedRequest(request);
  const tag = number(options.blockTag);
  const h = await context(p, d, tag, true);
  const owner = d.components[6]!.address;
  const recordHash = hash((await read(p, owner, q.kind === "policy" ? "policyRecord" : "saleConsentAt",
    q.kind === "policy" ? [q.collectionId, q.phaseId, q.policyHash] : [q.collectionId, q.saleId, q.saleConfigHash], tag))[0]);
  if (!same(recordHash, q.recordHash)) {
    throw Error("Recorded consent identity differs");
  }
  const delegationRecordHash = hash((await read(p, owner, "recordDelegation", [recordHash], tag))[0], true);
  let checkedCall: CurrentArtistRecordedConsentObservation["checkedCall"] = null;
  if (q.kind === "sale") {
    const [record] = await read(p, owner, "saleConsentRecord", [recordHash], tag);
    const term = [q.collectionId, q.saleAdapter, q.saleId, q.saleConfigHash];
    const expectedHash = keccak256(coder.encode(
      ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
      [id("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"), d.chainId, d.registry.address, record.terms.saleAdapter,
        d.components[9]!.address, record.terms.collectionId, record.terms.saleId, record.terms.saleConfigHash,
        record.artistId, record.signer, record.authorityClass, record.nonce, record.signedAt]
    ));
    const associationValid = record.authorityClass === 2n
      ? delegationRecordHash !== ZeroHash
      : [1n, 3n, 4n].includes(record.authorityClass) && delegationRecordHash === ZeroHash;
    if (!same(record.recordHash, recordHash)
      || !same(expectedHash, recordHash)
      || !same(coder.encode([terms.saleConsent], [record.terms]), coder.encode([terms.saleConsent], [term]))
      || !associationValid) {
      throw Error("Recorded sale consent terms or delegation differ");
    }
    checkedCall = {
      to: d.registry.address,
      data: abi.encodeFunctionData("requireSaleConsent", [q.collectionId, q.saleId, q.saleConfigHash]) as Hex,
      value: 0n, from: q.saleAdapter
    };
    const raw = bytes(await p.call({ ...checkedCall, blockTag: tag }), 32);
    if (raw !== "0x") {
      throw Error("Noncanonical requireSaleConsent return");
    }
  }
  await unchanged(p, h);
  return freeze({
    deployment: d, request: q, ...h, recordHash, delegationRecordHash,
    applicability: q.kind === "policy" ? "policy-record-only" : "sale-consent-checked-for-adapter", checkedCall
  });
}
