import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { CurrentArtistDeployment, CurrentArtistBinding, CurrentArtistAuthority, CurrentArtistReplay } from "./current-artist-workflow.js";
import * as policy from "./current-entropy-instant.js";
import * as base from "./current-entropy-collection-policy.js";

type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
export interface EntropyInstantPolicyCodePin { readonly address: Address; readonly codeHash: Hex }
export interface EntropyInstantPolicyDeployment {
  readonly chainId: bigint;
  readonly core: EntropyInstantPolicyCodePin;
  readonly coordinator: EntropyInstantPolicyCodePin;
  readonly moduleRegistry: EntropyInstantPolicyCodePin;
  readonly governance: EntropyInstantPolicyCodePin;
  readonly roleRegistry: EntropyInstantPolicyCodePin;
  readonly artist: CurrentArtistDeployment;
}
export interface EntropyInstantPolicyCatalog {
  readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly entryCount: bigint; readonly revision: bigint;
  readonly rowAdmission: "original-call-simulation-required";
}
export interface EntropyInstantPolicyCapture {
  readonly deployment: EntropyInstantPolicyDeployment;
  readonly snapshot: base.EntropyCollectionPolicySnapshot;
  readonly record: base.EntropyCollectionPolicyRecord;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly catalog: EntropyInstantPolicyCatalog; readonly governanceNonce: bigint;
  readonly captureHash: Hex;
}
export type EntropyInstantPolicyRequest =
  | { readonly kind: "configure"; readonly input: policy.EntropyInstantPolicyInput }
  | { readonly kind: "freeze" };
export interface EntropyInstantPolicyInspection {
  readonly capture: EntropyInstantPolicyCapture;
  readonly request: EntropyInstantPolicyRequest;
  readonly plan: policy.EntropyInstantPolicyPlan;
  /** Direct original calls; not a claim of equivalence to nested gas forwarding. */
  readonly admission: "original-execution-simulation-required";
  readonly inspectionHash: Hex;
}
const coder = AbiCoder.defaultAbiCoder();
const B = "(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const A = "(uint256 nonce,uint64 time,bytes signature)";
const S = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const PROOF = "(address signer,bytes32 digest,bool direct)";
const CONSENT = "(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const GOVERNANCE_CALL = "(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
const abi = new Interface([
  "function coordinator() view returns(address)",
  "function isStreamInstantEntropyProvider() view returns(bool)",
  "function streamEntropyProviderFamily() pure returns(bytes32)",
  "function streamEntropyProviderVersion() pure returns(bytes32)",
  "function instantEntropyProfile() view returns(uint8,bytes32)",
  "function instantEntropy(bytes32,bytes) view returns(bytes32,bytes32)",
  "function coordinatorAtMint(uint256) view returns(address)",
  "function tokenLifecycle(uint256) view returns(uint8)",
  "function tokenCollectionIdentity(uint256) view returns(bool mappingExists,uint256 collectionId,uint256 collectionSerial,bool burned)",
  "function scopeEntropy(bytes32) view returns((uint256 collectionId,bytes32 inputsHash,bytes32 requestKey,bytes32 seed,uint8 status))",
  "function tokenEntropy(uint256) view returns(uint8,bytes32,address,uint32,bytes32,bytes32,uint256,uint16)",
  "function registeredAtBlock(uint256) view returns(uint64)",
  "function requesters(address) view returns(bool)",
  "function requestEntropy(uint256) payable returns(bytes32,uint256)",
  "function requests(bytes32) view returns(bytes32 subjectKey,uint256 tokenId,bytes32 scopeId,address provider,uint64 requestedAtBlock,uint256 providerRequestId,bytes32 rawRandomness)",
  "function providerRequestKeys(address,uint256) view returns(bytes32)",
  "function requestPolicySnapshot(bytes32) view returns((address provider,bytes32 providerCodeHash,uint32 providerEpoch,bytes32 providerConfigHash,bytes32 collectionSalt,bytes32 inputsHash,uint16 requestAttempt))",
  "function entropyFeeCredit(address) view returns(uint256)",
  "function totalFeeCredits() view returns(uint256)",
  "function pendingRequestCount() view returns(uint256)",
  "function nonterminalTokenCount(uint256) view returns(uint256)",
  "function metadataNotificationPending(uint256) view returns(bool)",
  "event EntropyRequested(bytes32 indexed requestKey,uint256 indexed tokenId,bytes32 indexed scopeId,address provider,uint256 providerRequestId)",
  "event InstantEntropyProduced(uint16 schemaVersion,bytes32 indexed requestKey,uint256 indexed providerRequestId,bytes32 rawRandomness,bytes32 provenanceHash,uint8 mode,bytes32 assumptionsHash)",
  "event EntropyFinalized(bytes32 indexed requestKey,uint256 indexed tokenId,bytes32 indexed scopeId,bytes32 seed,bytes32 rawRandomness)",
  "event EntropyFeeCredited(address indexed payer,uint256 amount)",
  "event MetadataNotificationFailed(uint256 indexed tokenId,bytes32 indexed requestKey)",

  "function artistContentFamilyState(uint256, bytes32) view returns (bool, bytes32)",
  "function authority() view returns (address)",
  "function collectionEntropyConfig(uint256) view returns (address provider, bool publicRequests, bool locked, uint64 timeoutBlocks, bytes32 providerConfigHash, bytes32 providerCodeHash, bytes32 collectionSalt)",
  "function collectionEntropyPolicy(uint256) view returns ((bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord))",
  "function collectionEntropyPolicyTransition(uint256, (uint8 mode, uint8 securityClass, uint8 renderRequirement, address provider, bytes32 collectionSalt, bool publicRequests, uint64 timeoutBlocks, (bool declared, uint8 requestMode, bytes32 revealOwnerRole, uint64 requestSLOBlocks, uint256 revealFeePerTokenWei) reveal, uint16 maxFreshRecoveryAttempts, bytes32 recoveryPolicyId)) view returns (bytes32, bytes32, bytes32, bytes32)",
  "function collectionFreshRecovery(uint256) view returns ((bytes32 policyId, bytes32 policyHash, uint16 maxFreshRecoveryAttempts, uint64 revision, bytes32 lastActionId))",
  "function collectionProviderEpoch(uint256) view returns (uint32)",
  "function collectionRevealPolicy(uint256 collectionId) view returns ((bool declared, uint8 requestMode, bytes32 revealOwnerRole, uint64 requestSLOBlocks, uint256 revealFeePerTokenWei))",
  "function configureCollectionEntropyPolicy(uint256, (uint8 mode, uint8 securityClass, uint8 renderRequirement, address provider, bytes32 collectionSalt, bool publicRequests, uint64 timeoutBlocks, (bool declared, uint8 requestMode, bytes32 revealOwnerRole, uint64 requestSLOBlocks, uint256 revealFeePerTokenWei) reveal, uint16 maxFreshRecoveryAttempts, bytes32 recoveryPolicyId))",
  "function entropyProviderRecord(address provider) view returns ((uint8 state, bytes32 runtimeCodeHash, uint64 revision, bytes32 reasonHash, bytes32 lastActionId))",
  "function freezeCollectionEntropyPolicy(uint256)",
  "function freezeCollectionEntropyPolicyTransition(uint256) view returns (bytes32, bytes32, bytes32, bytes32)",
  "function freshRecoveryPolicy(bytes32) view returns ((bool exists, bool frozen, uint16 maxFreshRecoveryAttempts, bytes32 incidentDeclarerRole, bytes32 reasonSchemaHash, bytes32 policyManifestHash, (address provider, uint32 providerEpoch, bytes32 providerConfigHash, uint64 notBeforeBlocks, bool acceptLateOriginalFulfillment)[] steps), bytes32, uint64, bytes32)",
  "function governanceAuthority() view returns (address)",
  "function revealFeeEscrow(uint256) view returns (uint256)",
  "function roleRegistry() view returns (address)",
  "function roleRegistryCodeHash() view returns (bytes32)",
  "function collectionArtistState(uint256 collectionId) view returns (uint8 attributionState, uint64 bindingGeneration, bytes32 artistId, uint8 authorityStatus, bytes32 bindingHash)",
  "function contentConsentDigest((uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) p, (uint256 nonce, uint64 time, bytes signature) a) view returns (bytes32)",
  "function contentConsentEvidenceForHost(uint256 collectionId, address contentHost, bytes32 familyId, bytes32 newStateHash) view returns (bytes32)",
  "function recordContentConsent((uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) p, (uint256 nonce, uint64 time, bytes signature) a) returns (bytes32)",
  "function contentConsentAt((uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) p, uint64 generation) view returns ((bytes32 recordHash, bytes32 artistId, uint64 bindingGeneration, (uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) terms, uint8 authorityClass))",
  "function contentConsentRecord(bytes32 recordHash) view returns ((bytes32 recordHash, bytes32 artistId, uint64 bindingGeneration, (uint256 collectionId, address metadataContract, bytes32 familyId, bytes32 newStateHash) terms, uint8 authorityClass))",
  "function isStreamEntropyProvider() view returns (bool)",
  "function streamEntropyProviderConfigHash() view returns (bytes32)",
  "function contextIndependentRequestFee() view returns (uint256)",
  "event CollectionEntropyPolicyConfigured(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed policyHash, uint64 revision, uint32 providerEpoch, (uint8 mode, uint8 securityClass, uint8 renderRequirement, address provider, bytes32 collectionSalt, bool publicRequests, uint64 timeoutBlocks, (bool declared, uint8 requestMode, bytes32 revealOwnerRole, uint64 requestSLOBlocks, uint256 revealFeePerTokenWei) reveal, uint16 maxFreshRecoveryAttempts, bytes32 recoveryPolicyId) policy, bytes32 providerCodeHash, bytes32 providerConfigHash, bytes32 recoveryPolicyHash, bytes32 actionId, bytes32 artistConsentRecord)",
  "event CollectionEntropyPolicyFrozen(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed policyHash, uint64 revision, bytes32 actionId, bytes32 artistConsentRecord)",
  "function owner() view returns(address)",
  "function governanceExecutor() view returns(address)",
  "function supportsInterface(bytes4) view returns(bool)",
  "function collectionFreezeStatus(uint256) view returns(bool)",
  "function collectionMintedEver(uint256) view returns(uint256)",
  "event ArtistContentConsentRecorded(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed familyId,address indexed signer,bytes32 newStateHash,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 consentRecordHash)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeVetoGuardianSet(bytes32 scopeHash) view returns (address roleRegistryAddress, bytes32 scopedRole, uint256 scopedHolderCount, bytes32 globalRole, uint256 globalHolderCount, uint64 vetoDeadline)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "function roleHolderCount(bytes32 role) view returns (uint256)",
  "function core() view returns(address)",
  "function mintManager() view returns(address)",
  "function operationCoordinator() view returns(address)",
  "function artistRegistry() view returns(address)",
  "function archiveV2() view returns(address)",
  "function deploymentChainId() view returns(uint256)",
  "function domainId() view returns(bytes32)",
  "function configurationHash() view returns(bytes32)",
  "function suiteConfiguration() view returns((address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator))",
  `function binding(uint256) view returns(${B})`,
  "function attributionState(uint256) view returns(uint8,uint64)",
  "function bindingTerms(uint256,uint64) view returns((bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count))",
  "function acceptedCount(bytes32) view returns(uint32)",
  "function authorityState(bytes32) view returns(address,uint8,uint8,bytes32)",
  `function artistAuthorizationState(bytes32,bytes32,uint256) view returns((bool digestObserved,bool digestRevoked,bool nonceConsumed,bool nonceRevoked,uint256 nextUnusedNonce))`,
  "function currentAuthorityCapabilities(bytes32) view returns((address authorityAddress,uint8 authorityClass,uint8 status,uint32 effectiveCapabilities,bytes32 activationRecordHash))",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  "function gasParameterInfo(bytes32) view returns(uint256,uint256,uint8,uint64)",
  "function collectionExists(uint256) view returns(bool)",
  "function getSatellitePointer(bytes32) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes)",
  "event ArtistContentRecordContext(uint16 schemaVersion,bytes32 indexed recordHash,address metadataContract,bytes32 artistId)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)",
]);
function keys(v: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).some(k => typeof k !== "string" || ![...required, ...optional].includes(k))
    || required.some(k => !Object.hasOwn(v, k))) throw Error("Missing/unknown properties");
}
function address(v: unknown): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (a === ZeroAddress) throw Error("Zero address");
  return a;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error("Expected bounded unsigned bigint");
  return v;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index");
  return v;
}
function bytes(v: unknown, max = 32768): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes");
  return v.toLowerCase() as Hex;
}
function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
function stable(v: unknown): string {
  const tagged = (x: unknown): unknown => {
    if (x === null) return ["null"];
    if (typeof x === "string" || typeof x === "boolean") return [typeof x, x];
    if (typeof x === "bigint") return ["bigint", x.toString()];
    if (typeof x === "number" && Number.isFinite(x)) return ["number", x];
    if (Array.isArray(x)) return ["array", x.map(tagged)];
    if (x && typeof x === "object") return ["object", Object.keys(x).sort().map(k => [k, tagged((x as Record<string, unknown>)[k])])];
    throw Error("Unsupported canonical value");
  };
  return JSON.stringify(tagged(v));
}
function equal(a: unknown, b: unknown, reason = "Prepared facts differ; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(b.hash), timestamp: BigInt(b.timestamp) };
}
async function unchanged(p: Reader, h: { blockNumber: number; blockHash: Hex; timestamp: bigint }): Promise<void> {
  equal(await header(p, h.blockNumber), { blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp }, "Pinned block changed");
}
async function runtime(p: Reader, v: EntropyInstantPolicyCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}

function plain(t: ParamType, value: any): any {
  if (t.baseType === "array") return Array.from(value, item => plain(t.arrayChildren!, item));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((part, i) => [part.name, plain(part, value[i])]));
  return value;
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, from?: Address, maximum = 32768): Promise<any[]> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, ...(from ? { from } : {}) }), maximum);
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error(`Noncanonical ${name} return`);
  return abi.getFunction(name)!.outputs!.map((part, i) => plain(part, decoded[i]));
}

const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function pin(v: EntropyInstantPolicyCodePin): EntropyInstantPolicyCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}
function deployment(v: EntropyInstantPolicyDeployment): EntropyInstantPolicyDeployment {
  keys(v, ["chainId", "core", "coordinator", "moduleRegistry", "governance", "roleRegistry", "artist"]);
  keys(v.artist, ["chainId", "registry", "coordinator", "components"], ["reads"]);
  if (!Array.isArray(v.artist.components) || v.artist.components.length !== 16) throw Error("Exactly16 Artist component pins required");
  const d = { chainId: uint(v.chainId), core: pin(v.core), coordinator: pin(v.coordinator),
    moduleRegistry: pin(v.moduleRegistry), governance: pin(v.governance), roleRegistry: pin(v.roleRegistry),
    artist: { chainId: uint(v.artist.chainId), registry: pin(v.artist.registry), coordinator: pin(v.artist.coordinator),
      components: v.artist.components.map(pin), ...(v.artist.reads ? { reads: pin(v.artist.reads) } : {}) } };
  if (!d.chainId || d.chainId !== d.artist.chainId || !same(d.artist.components[9]!.address, d.core.address)
    || !same(d.artist.components[9]!.codeHash, d.core.codeHash)
    || !same(d.artist.components[7]!.address, d.artist.registry.address)
    || !same(d.artist.components[7]!.codeHash, d.artist.registry.codeHash)
    || new Set(d.artist.components.map(p => p.address)).size !== 16) throw Error("Deployment Artist pins differ");
  return freeze(d);
}
function decode(types: readonly string[], raw: Hex): any[] {
  const values = coder.decode(types, raw);
  if (!same(coder.encode(types, values), raw)) throw Error("Noncanonical ABI bytes");
  return types.map((t, i) => plain(ParamType.from(t), values[i]));
}
async function selected(p: Reader, d: EntropyInstantPolicyDeployment, name: string,
  expected: EntropyInstantPolicyCodePin, tag: number): Promise<void> {
  const v = await read(p, d.core.address, "getSatellitePointer", [id(name)], tag);
  if (!same(v[0], expected.address) || !same(v[1], expected.codeHash) || v[6] !== 1n || v[9] === 0n) {
    throw Error(`Current ACTIVE ${name} pointer differs`);
  }
}
async function context(p: Reader, d: EntropyInstantPolicyDeployment, tag: number, current = true) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([d.core, d.coordinator, d.moduleRegistry, d.governance, d.roleRegistry].map(v => runtime(p, v, tag)));
  for (const [target, method, expected] of [
    [d.coordinator.address, "core", d.core.address], [d.coordinator.address, "authority", d.governance.address],
    [d.coordinator.address, "roleRegistry", d.roleRegistry.address], [d.coordinator.address, "roleRegistryCodeHash", d.roleRegistry.codeHash],
    [d.moduleRegistry.address, "governanceExecutor", d.governance.address], [d.governance.address, "roleRegistry", d.roleRegistry.address],
    [d.roleRegistry.address, "owner", d.governance.address]
  ] as const) {
    if (!same((await read(p, target, method, [], tag))[0], expected)) throw Error("Immutable/governance binding differs");
  }
  if ((await read(p, d.coordinator.address, "supportsInterface", ["0x4583f7e1"], tag))[0] !== true
    || (await read(p, d.coordinator.address, "supportsInterface", ["0xffffffff"], tag))[0] !== false) throw Error("Policy capability unavailable");
  if (current) {
    await selected(p, d, "ENTROPY_COORDINATOR", d.coordinator, tag);
    await selected(p, d, "ARTIST_REGISTRY", d.artist.registry, tag);
    await selected(p, d, "MODULE_REGISTRY", d.moduleRegistry, tag);
  }
  const boot = await read(p, d.governance.address, "systemManifestBootstrapState", [], tag);
  if (boot[0] !== true || boot[1] !== true || !same(boot[2], d.roleRegistry.address) || !same(boot[3], d.roleRegistry.codeHash)) {
    throw Error("Ordinary sealed governance required");
  }
  for (const [cls, delay] of [[1n, 172800n], [2n, 259200n]]) {
    equal((await read(p, d.governance.address, "minimumDelay", [cls], tag))[0], delay, "Governance delay differs");
  }
  const [candidateProfileHash, catalogHash, entryCount, revision] = await read(p, d.governance.address, "governanceActionPolicyState", [], tag);
  if (!entryCount || entryCount > 1024n) throw Error("Governance catalog bound exceeded");
  return { ...h, governanceNonce: uint((await read(p, d.governance.address, "governanceNonce", [], tag))[0]),
    catalog: { candidateProfileHash: hash(candidateProfileHash), catalogHash: hash(catalogHash), entryCount: uint(entryCount),
      revision: uint(revision, 64), rowAdmission: "original-call-simulation-required" as const } };
}
function saved(v: EntropyInstantPolicyCapture): EntropyInstantPolicyCapture {
  keys(v, ["deployment", "snapshot", "record", "blockNumber", "blockHash", "timestamp", "catalog", "governanceNonce", "captureHash"]);
  const d = deployment(v.deployment), snapshot = base.normalizeEntropyCollectionPolicySnapshot(v.snapshot);
  const record = base.entropyCollectionPolicyRecord(snapshot);
  const copy = structuredClone(v);
  equal(d, copy.deployment); equal(snapshot, copy.snapshot); equal(record, copy.record);
  const { captureHash, ...body } = copy;
  if (!same(digest(body), captureHash)) throw Error("Capture reconstruction differs");
  number(copy.blockNumber); hash(copy.blockHash); uint(copy.timestamp, 64);
  return freeze(copy);
}
/** Complete twelve-word producer record and its original configuration inputs at one concrete block. */
export async function captureEntropyInstantPolicy(p: Reader, input: EntropyInstantPolicyDeployment,
  collectionId: bigint, options: { readonly blockTag: number }): Promise<EntropyInstantPolicyCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), cid = uint(collectionId), tag = number(options.blockTag);
  if (!cid) throw Error("Zero collection");
  return captureAt(p, d, cid, tag, true);
}
async function captureAt(p: Reader, d: EntropyInstantPolicyDeployment, cid: bigint, tag: number, current: boolean): Promise<EntropyInstantPolicyCapture> {
  const h = await context(p, d, tag, current);
  const configValues = await read(p, d.coordinator.address, "collectionEntropyConfig", [cid], tag);
  const config = Object.fromEntries(["provider", "publicRequests", "locked", "timeoutBlocks", "providerConfigHash", "providerCodeHash", "collectionSalt"].map((k, i) => [k, configValues[i]]));
  const record = (await read(p, d.coordinator.address, "collectionEntropyPolicy", [cid], tag))[0];
  const snapshot = base.normalizeEntropyCollectionPolicySnapshot({ chainId: d.chainId, coordinator: d.coordinator.address,
    core: d.core.address, governanceExecutor: d.governance.address, collectionId: cid,
    config, providerEpoch: (await read(p, d.coordinator.address, "collectionProviderEpoch", [cid], tag))[0],
    reveal: (await read(p, d.coordinator.address, "collectionRevealPolicy", [cid], tag))[0],
    recovery: (await read(p, d.coordinator.address, "collectionFreshRecovery", [cid], tag))[0],
    entry: base.entropyCollectionPolicyEntryFromRecord(record),
    collectionExists: (await read(p, d.core.address, "collectionExists", [cid], tag))[0],
    collectionFrozen: (await read(p, d.core.address, "collectionFreezeStatus", [cid], tag))[0],
    collectionMintedEver: (await read(p, d.core.address, "collectionMintedEver", [cid], tag))[0],
    revealEscrow: (await read(p, d.coordinator.address, "revealFeeEscrow", [cid], tag))[0]
  } as base.EntropyCollectionPolicySnapshot);
  equal(record, base.entropyCollectionPolicyRecord(snapshot), "Full policy record differs from original inputs");
  const [supported, content] = await read(p, d.coordinator.address, "artistContentFamilyState", [cid, id("6529STREAM_ENTROPY_CONFIGURATION_V1")], tag);
  if (!supported || !same(content, record.contentStateHash)) throw Error("Content family record differs");
  await unchanged(p, h);
  const body = { deployment: d, snapshot, record, ...h };
  return freeze({ ...body, captureHash: digest(body) });
}
async function original(p: Reader, c: EntropyInstantPolicyCapture): Promise<void> {
  equal(await captureEntropyInstantPolicy(p, c.deployment, c.snapshot.collectionId, { blockTag: c.blockNumber }), c, "Historical capture differs");
}
function request(v: EntropyInstantPolicyRequest): EntropyInstantPolicyRequest {
  if (v.kind === "freeze") { keys(v, ["kind"]); return freeze({ kind: "freeze" }); }
  keys(v, ["kind", "input"]);
  if (v.kind !== "configure") throw Error("Unsupported policy operation");
  return freeze({ kind: "configure", input: policy.normalizeEntropyInstantPolicyInput(v.input) });
}
async function activeProvider(p: Reader, c: EntropyInstantPolicyCapture, provider: Address) {
  const [r] = await read(p, c.deployment.coordinator.address, "entropyProviderRecord", [provider], c.blockNumber);
  if (r.state !== 1n) throw Error("Provider is not ACTIVE");
  await runtime(p, { address: address(provider), codeHash: hash(r.runtimeCodeHash) }, c.blockNumber);
  return r;
}
async function resolution(p: Reader, c: EntropyInstantPolicyCapture, input: policy.EntropyInstantPolicyInput) {
  const observed = await instantProfile(p, c.deployment.coordinator.address, input.provider, c.blockNumber, true);
  return { providerCodeHash: observed.codeHash, providerConfigHash: observed.configHash,
    recoveryPolicyHash: ZeroHash as Hex, instantMode: 1n as const, assumptionsHash: observed.assumptionsHash };
}

function inspection(v: EntropyInstantPolicyInspection): EntropyInstantPolicyInspection {
  keys(v, ["capture", "request", "plan", "admission", "inspectionHash"]);
  const c = saved(v.capture), q = request(v.request), plan = policy.normalizeEntropyInstantPolicyPlan(v.plan);
  equal(plan.snapshot, c.snapshot); equal(q.kind, plan.kind);
  if (q.kind === "configure") equal(q.input, (plan as any).input);
  const body = { capture: c, request: q, plan, admission: "original-execution-simulation-required" as const };
  if (!same(digest(body), v.inspectionHash) || v.admission !== body.admission) throw Error("Inspection reconstruction differs");
  return freeze({ ...body, inspectionHash: v.inspectionHash });
}
/** Exact transition comparison. A transition does not consume Artist consent or governance replay. */
export async function inspectEntropyInstantPolicy(p: Reader, input: EntropyInstantPolicyCapture,
  supplied: EntropyInstantPolicyRequest): Promise<EntropyInstantPolicyInspection> {
  const c = saved(input), q = request(supplied);
  await original(p, c);
  const plan = q.kind === "freeze" ? policy.prepareEntropyInstantPolicyFreeze(c.snapshot)
    : policy.prepareEntropyInstantPolicyConfigure(c.snapshot, q.input, await resolution(p, c, q.input));
  const raw = bytes(await p.call({ ...plan.previewCall, blockTag: c.blockNumber }));
  equal(decode(["bytes32", "bytes32", "bytes32", "bytes32"], raw),
    [plan.transition.scopeHash, plan.transition.oldValueHash, plan.transition.newValueHash, plan.transition.artistContentStateHash], "Original four-word transition differs");
  await unchanged(p, c);
  const body = { capture: c, request: q, plan, admission: "original-execution-simulation-required" as const };
  return freeze({ ...body, inspectionHash: digest(body) });
}
export interface EntropyInstantPolicyConsentCapture {
  readonly inspection: EntropyInstantPolicyInspection;
  readonly consent: policy.EntropyInstantPolicyArtistConsent;
  readonly configurationHash: Hex;
  readonly binding: CurrentArtistBinding;
  readonly authority: CurrentArtistAuthority;
  readonly replay: CurrentArtistReplay;
  readonly currentContentStateHash: Hex;
  readonly captureHash: Hex;
}
function consentTerms(plan: policy.EntropyInstantPolicyPlan) {
  return { collectionId: plan.snapshot.collectionId, metadataContract: plan.snapshot.coordinator,
    familyId: base.ENTROPY_COLLECTION_POLICY_FAMILY, newStateHash: plan.transition.artistContentStateHash };
}
async function artistGas(p: Reader, d: EntropyInstantPolicyDeployment, tag: number): Promise<void> {
  const [cap, floor, failure, revision] = await read(p, d.artist.registry.address, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS")], tag);
  if (!cap || cap === (1n << 256n) - 1n || !floor || cap < floor || failure !== 2n || !revision) throw Error("Artist bounded read parameters differ");
}
async function artistBinding(p: Reader, d: EntropyInstantPolicyDeployment, cid: bigint, tag: number) {
  const a = d.artist;
  await artistGas(p, d, tag);
  const [b] = await read(p, a.components[0]!.address, "binding", [cid], tag);
  const [state, generation] = await read(p, a.components[4]!.address, "attributionState", [cid], tag);
  const [signer, authorityClass, status, identityRecordHash] = await read(p, a.components[2]!.address, "authorityState", [b.artistId], tag);
  const ordinary = authorityClass === 1n && [1n, 2n].includes(status) || [3n, 4n].includes(authorityClass) && status === 3n;
  if (!b.accepted || ![2n, 3n].includes(state) || generation === 0n || generation !== b.generation
    || ![1n, 2n].includes(b.consentMode) || !ordinary) throw Error("Artist binding/current authority unavailable");
  address(signer); hash(b.artistId); hash(b.bindingHash);
  const [terms] = await read(p, a.components[0]!.address, "bindingTerms", [cid, generation], tag);
  if (terms.mode !== 0n || terms.threshold !== 0n || terms.count > 32n
    || (await read(p, a.components[1]!.address, "acceptedCount", [b.bindingHash], tag))[0] !== terms.count) throw Error("Incomplete/simple collaborator binding required");
  const observed = await read(p, a.registry.address, "collectionArtistState", [cid], tag);
  equal(observed, [state, generation, b.artistId, status, b.bindingHash], "Facade Artist state differs");
  return { binding: b as CurrentArtistBinding, authority: { address: address(signer), authorityClass, status, identityRecordHash: hash(identityRecordHash) } };
}
async function replayRead(p: Reader, d: EntropyInstantPolicyDeployment, artistId: Hex, digest_: Hex, nonce: bigint, tag: number): Promise<CurrentArtistReplay> {
  return (await read(p, d.artist.registry.address, "artistAuthorizationState", [artistId, digest_, nonce], tag))[0];
}
function normalizeConsent(v: policy.EntropyInstantPolicyArtistConsent) {
  bytes(v.authorization.signature, 65536);
  return policy.normalizeEntropyInstantPolicyArtistConsent(v);
}
function savedConsent(v: EntropyInstantPolicyConsentCapture): EntropyInstantPolicyConsentCapture {
  keys(v, ["inspection", "consent", "configurationHash", "binding", "authority", "replay", "currentContentStateHash", "captureHash"]);
  const i = inspection(v.inspection), consent = normalizeConsent(v.consent), copy = structuredClone(v);
  equal(i, copy.inspection); equal(consent, copy.consent); equal(consent.plan, i.plan);
  const { captureHash, ...body } = copy;
  if (!same(digest(body), captureHash)) throw Error("Consent capture reconstruction differs");
  return freeze(copy);
}
/** Normal original operation17. Empty ERC1271 proof may be relayed; direct is determined by actual caller. */
export async function captureEntropyInstantPolicyConsent(p: Reader, input: EntropyInstantPolicyInspection,
  supplied: policy.EntropyInstantPolicyArtistConsent): Promise<EntropyInstantPolicyConsentCapture> {
  const i = inspection(input), q = normalizeConsent(supplied), c = i.capture, d = c.deployment, tag = c.blockNumber;
  equal(q.plan, i.plan);
  if (!same(q.registry, d.artist.registry.address)) throw Error("Consent facade differs");
  if (!q.authorization.deadline || c.timestamp > q.authorization.deadline) throw Error("Artist deadline expired");
  await original(p, c);
  const h = await artistContext(p, d.artist, tag, true);
  const a = await artistBinding(p, d, c.snapshot.collectionId, tag);
  if (!same(a.authority.address, q.signer)) throw Error("Signer is not current Artist authority");
  if (a.authority.authorityClass !== 1n) {
    const [caps] = await read(p, d.artist.components[2]!.address, "currentAuthorityCapabilities", [a.binding.artistId], tag);
    if (!same(caps.authorityAddress, q.signer) || caps.authorityClass !== a.authority.authorityClass || caps.status !== a.authority.status
      || (caps.effectiveCapabilities & 128n) !== 128n || same(caps.activationRecordHash, ZeroHash)) throw Error("Artist content capability unavailable");
  }
  if (!q.direct) {
    const [cap, , failure, revision] = await read(p, q.registry, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS")], tag);
    if (!cap || failure !== 2n || !revision) throw Error("Artist proof parameters unavailable");
  }
  const actualDigest = decode(["bytes32"], bytes(await p.call({ ...q.digestCall, from: q.caller, blockTag: tag })))[0];
  if (!same(actualDigest, q.payload.digest)) throw Error("Original op17 digest differs");
  const replay = await replayRead(p, d, a.binding.artistId, q.payload.digest, q.authorization.nonce, tag);
  if (replay.digestObserved || replay.digestRevoked || replay.nonceConsumed || replay.nonceRevoked
    || (q.direct && replay.nextUnusedNonce !== q.authorization.nonce)) throw Error("Artist authorization unavailable");
  const currentContentStateHash = hash(c.record.contentStateHash);
  if (same(currentContentStateHash, i.plan.transition.artistContentStateHash)) throw Error("Content consent target already current");
  await unchanged(p, h);
  const body = { inspection: i, consent: q, configurationHash: h.configurationHash, ...a, replay, currentContentStateHash };
  return freeze({ ...body, captureHash: digest(body) });
}
function artistRecord(c: EntropyInstantPolicyConsentCapture, at: bigint): Hex {
  return policy.entropyInstantPolicyArtistRecordHash(c.consent.plan, { registry: c.consent.registry,
    artistId: c.binding.artistId, signer: c.consent.signer, authorityClass: c.authority.authorityClass,
    nonce: c.consent.authorization.nonce, observedAt: at });
}
export interface EntropyInstantPolicyConsentSimulation {
  readonly capture: EntropyInstantPolicyConsentCapture;
  readonly observed: EntropyInstantPolicyConsentCapture;
  readonly recordHash: Hex;
}
export async function simulateEntropyInstantPolicyConsent(p: Reader, input: EntropyInstantPolicyConsentCapture,
  options: { readonly blockTag: number }): Promise<EntropyInstantPolicyConsentSimulation> {
  keys(options, ["blockTag"]);
  const c = savedConsent(input), tag = number(options.blockTag), old = c.inspection.capture;
  if (tag < old.blockNumber) throw Error("Simulation predates capture");
  equal(await captureEntropyInstantPolicyConsent(p, c.inspection, c.consent), c, "Historical consent capture differs");
  const fresh = await captureEntropyInstantPolicy(p, old.deployment, old.snapshot.collectionId, { blockTag: tag });
  const i = await inspectEntropyInstantPolicy(p, fresh, c.inspection.request);
  equal(i.plan, c.inspection.plan, "Policy transition changed; renew consent");
  const observed = await captureEntropyInstantPolicyConsent(p, i, c.consent);
  equal(observed.binding, c.binding); equal(observed.authority, c.authority);
  const q = c.consent, raw = bytes(await p.call({ ...q.call, from: q.caller, blockTag: tag }));
  const recordHash = hash(decode(["bytes32"], raw)[0]);
  equal(recordHash, artistRecord(observed, fresh.timestamp), "Simulated original content record differs");
  await unchanged(p, fresh);
  return freeze({ capture: c, observed, recordHash });
}
/** Exact recorded evidence prerequisite; original host call checks current binding/authority, not signature replay. */
async function consentEvidence(p: Reader, i: EntropyInstantPolicyInspection, tag: number): Promise<Hex> {
  const d = i.capture.deployment;
  await artistContext(p, d.artist, tag, true);
  const a = await artistBinding(p, d, i.plan.snapshot.collectionId, tag);
  const terms = consentTerms(i.plan);
  const [recordHash] = await read(p, d.artist.registry.address, "contentConsentEvidenceForHost",
    [terms.collectionId, terms.metadataContract, terms.familyId, terms.newStateHash], tag, d.coordinator.address);
  const [record] = await read(p, d.artist.components[6]!.address, "contentConsentRecord", [hash(recordHash)], tag);
  equal(record, { recordHash: hash(recordHash), artistId: a.binding.artistId, bindingGeneration: a.binding.generation,
    terms, authorityClass: record.authorityClass }, "Original content record differs");
  if (![1n, 3n].includes(record.authorityClass)) throw Error("Content evidence authority class unavailable");
  return hash(recordHash);
}
export interface PreparedEntropyInstantPolicyGovernance {
  readonly inspection: EntropyInstantPolicyInspection;
  readonly proposer: Address;
  readonly batch: policy.EntropyInstantPolicyGovernanceBatch;
}
export interface EntropyInstantPolicyOperation {
  readonly prepared: PreparedEntropyInstantPolicyGovernance;
  readonly stage: "publish" | "schedule" | "execute";
  readonly caller: Address;
  readonly call: UnsignedCall;
}
export function prepareEntropyInstantPolicyGovernance(input: EntropyInstantPolicyInspection, proposer: Address,
  window: base.EntropyCollectionPolicyGovernanceWindow): PreparedEntropyInstantPolicyGovernance {
  const i = inspection(input), batch = policy.entropyInstantPolicyGovernanceBatch(i.plan, i.capture.governanceNonce, window);
  policy.assertEntropyInstantPolicyGovernanceWindow(batch.plan.actionClass, batch.window, i.capture.timestamp);
  if (toUtf8Bytes(batch.window.reasonURI).length > 2048) throw Error("Reason URI exceeds2048 bytes");
  return freeze({ inspection: i, proposer: address(proposer), batch });
}
function prepared(v: PreparedEntropyInstantPolicyGovernance): PreparedEntropyInstantPolicyGovernance {
  keys(v, ["inspection", "proposer", "batch"]);
  const batch = policy.normalizeEntropyInstantPolicyGovernanceBatch(v.batch);
  const out = prepareEntropyInstantPolicyGovernance(v.inspection, v.proposer, batch.window);
  equal(out, v);
  return out;
}
export function prepareEntropyInstantPolicyOperation(input: PreparedEntropyInstantPolicyGovernance,
  stage: EntropyInstantPolicyOperation["stage"], caller: Address): EntropyInstantPolicyOperation {
  const p = prepared(input), actor = address(caller);
  if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unsupported governance stage");
  if (stage === "schedule" && !same(actor, p.proposer)) throw Error("Schedule caller differs from proposer");
  return freeze({ prepared: p, stage, caller: actor, call: stage === "publish" ? p.batch.publicationCall
    : stage === "schedule" ? p.batch.scheduleCall : p.batch.executionCall });
}
function operation(v: EntropyInstantPolicyOperation): EntropyInstantPolicyOperation {
  keys(v, ["prepared", "stage", "caller", "call"]);
  const out = prepareEntropyInstantPolicyOperation(v.prepared, v.stage, v.caller);
  equal(out, v);
  return out;
}
export interface EntropyInstantPolicyGuardians {
  readonly scopedRole: Hex; readonly scopedHolderCount: bigint;
  readonly globalRole: Hex; readonly globalHolderCount: bigint; readonly earliestVetoDeadline: bigint;
  readonly admission: "original-call-simulation-required";
}
async function guardians(p: Reader, i: EntropyInstantPolicyInspection, tag: number): Promise<EntropyInstantPolicyGuardians | null> {
  if (i.plan.kind !== "freeze") return null;
  const d = i.capture.deployment, scope = i.plan.transition.scopeHash;
  const [registry, scopedRole, scopedCount, globalRole, globalCount, deadline] = await read(p, d.governance.address, "terminalFreezeVetoGuardianSet", [scope], tag);
  const role = id("ROLE_TERMINAL_FREEZE_VETO");
  if (!same(registry, d.roleRegistry.address) || !same(globalRole, role)
    || !same(scopedRole, keccak256(coder.encode(["bytes32", "bytes32"], [role, scope])))
    || scopedCount > 64n || globalCount > 64n || globalCount < 2n) throw Error("Bounded guardian set differs");
  equal((await read(p, registry, "roleHolderCount", [role], tag))[0], globalCount);
  equal((await read(p, registry, "roleHolderCount", [scopedRole], tag))[0], scopedCount);
  if ((await read(p, registry, "isRoleRedundant", [role], tag))[0] !== true) throw Error("Global freeze guardians are not redundant");
  return freeze({ scopedRole, scopedHolderCount: scopedCount, globalRole, globalHolderCount: globalCount,
    earliestVetoDeadline: deadline, admission: "original-call-simulation-required" });
}
export interface EntropyInstantPolicySimulation {
  readonly operation: EntropyInstantPolicyOperation;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly observed: EntropyInstantPolicyInspection | null;
  readonly artistConsentRecord: Hex | null;
  readonly guardians: EntropyInstantPolicyGuardians | null;
  readonly guardianCommitment: Hex | null;
  readonly returnData: Hex;
}
export async function simulateEntropyInstantPolicyOperation(p: Reader, input: EntropyInstantPolicyOperation,
  options: { readonly blockTag: number }): Promise<EntropyInstantPolicySimulation> {
  keys(options, ["blockTag"]);
  const o = operation(input), i = o.prepared.inspection, c = i.capture, d = c.deployment, b = o.prepared.batch, tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await original(p, c);
  const h = await context(p, d, tag, o.stage !== "publish");
  let observed: EntropyInstantPolicyInspection | null = null, artistConsentRecord: Hex | null = null;
  let guardianSet: EntropyInstantPolicyGuardians | null = null, guardianCommitment: Hex | null = null;
  if (o.stage !== "publish") {
    equal(h.catalog, c.catalog, "Governance catalog changed; reschedule");
    const fresh = await captureEntropyInstantPolicy(p, d, c.snapshot.collectionId, { blockTag: tag });
    observed = await inspectEntropyInstantPolicy(p, fresh, i.request);
    equal(observed.plan, i.plan, "Committed policy transition changed; recapture and reschedule");
    artistConsentRecord = await consentEvidence(p, observed, tag);
    guardianSet = await guardians(p, observed, tag);
    if (o.stage === "schedule") {
      if (h.governanceNonce !== b.nonce) throw Error("Governance nonce changed");
      policy.assertEntropyInstantPolicyGovernanceWindow(b.plan.actionClass, b.window, h.timestamp);
      if (!await publication(p, b, tag)) throw Error("Publish exact call data first");
      const [owner] = await read(p, d.governance.address, "owner", [], tag);
      if (!same(owner, o.caller) && (await read(p, d.governance.address, "isProposer", [o.caller], tag))[0] !== true) throw Error("Caller is not an authorized proposer");
    } else {
      const a = await action(p, o, tag);
      if (a.status !== 1n || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Action outside scheduled execution window");
      if (b.plan.kind === "freeze") guardianCommitment = hash((await read(p, d.governance.address, "terminalFreezeGuardianConfigCommitment", [b.actionId], tag))[0]);
    }
  }
  const priorPointer = o.stage === "publish" ? await publication(p, b, tag) : null;
  const returned = bytes(await p.call({ ...o.call, from: o.caller, blockTag: tag }));
  if (o.stage === "execute") {
    if (returned !== "0x") throw Error("Noncanonical void execution return");
  } else {
    const name = o.stage === "publish" ? "publishGovernanceCallData" : "scheduleGovernanceBatch";
    const v = abi.decodeFunctionResult(name, returned);
    if (!same(abi.encodeFunctionResult(name, v), returned)) throw Error("Noncanonical simulation return");
    if (o.stage === "schedule" && !same(v[0], b.actionId)) throw Error("Simulated action differs");
    if (o.stage === "publish" && (!address(v[0]) || (priorPointer && !same(v[0], priorPointer)))) throw Error("Publication pointer differs");
  }
  await unchanged(p, h);
  return freeze({ operation: o, blockNumber: tag, blockHash: h.blockHash, timestamp: h.timestamp, observed,
    artistConsentRecord, guardians: guardianSet, guardianCommitment, returnData: returned });
}

async function artistContext(p: Reader, d: CurrentArtistDeployment, tag: number, current: boolean) {
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

async function publication(p: Reader, b: policy.EntropyInstantPolicyGovernanceBatch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.plan.snapshot.governanceExecutor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = coder.encode(["bytes[]"], [[b.plan.targetCall.data]]);
  if (!same(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`)) throw Error("Published call data differs");
  return pointer;
}
async function action(p: Reader, o: EntropyInstantPolicyOperation, tag: number) {
  const b = o.prepared.batch, executor = b.plan.snapshot.governanceExecutor;
  const [a] = await read(p, executor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: b.plan.actionClass, target: b.plan.targetCall.to, value: 0n, selector: b.plan.governanceCall.selector,
    callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash,
    notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer,
    reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) {
    if (a[key] !== value && (key === "reasonURI" || !same(a[key], value))) throw Error(`Scheduled ${key} differs`);
  }
  const [data] = await read(p, executor, "scheduledCallData", [b.actionId], tag);
  equal(Array.from(data), [b.plan.targetCall.data], "Scheduled bytes differ");
  const ptr = await publication(p, b, tag);
  if (!ptr || !same((await read(p, executor, "scheduledCallDataPointer", [b.actionId], tag))[0], ptr)) throw Error("Scheduled pointer differs");
  return a;
}

export interface EntropyInstantPolicyEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
interface ReceiptOptions { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }
async function mined(p: ReceiptReader, d: EntropyInstantPolicyDeployment | EntropyInstantRequestDeployment, caller: Address, call: UnsignedCall, before: number,
  options: ReceiptOptions) {
  const transactionHash = options.transactionHash, execution = options.execution;
  const [r, tx] = await Promise.all([p.getTransactionReceipt(transactionHash), p.getTransaction(transactionHash)]);
  if (!r || !tx || r.status !== 1 || !same(r.hash, transactionHash) || !same(tx.hash, transactionHash)
    || tx.chainId !== d.chainId || tx.value !== (execution === "direct" ? call.value : 0n) || r.blockNumber <= before || tx.blockNumber !== r.blockNumber
    || !same(tx.blockHash, r.blockHash) || !same(tx.to, r.to) || !same(tx.from, r.from)) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 524288);
  if (execution === "direct") {
    if (!same(tx.from, caller) || !same(tx.to, call.to) || !same(data, call.data)) throw Error("Direct call differs");
  } else {
    const decoded = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(tx.to, caller) || !same(safeAbi.encodeFunctionData("execTransaction", decoded), data)
      || !same(decoded[0], call.to) || decoded[1] !== call.value || !same(decoded[2], call.data) || decoded[3] !== 0n) throw Error("Safe requires exact ordinary CALL");
  }
  const tag = number(r.blockNumber), h = "artist" in d ? await context(p, d, tag, false) : await requestContext(p, d, tag);
  if (!same(h.blockHash, r.blockHash)) throw Error("Receipt block differs");
  if (!Array.isArray(r.logs) || r.logs.length > 256) throw Error("Receipt exceeds256 logs");
  const logs: Log[] = r.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== tag || !same(l.blockHash, h.blockHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log identity");
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 65536), index: number(l.index) };
  });
  if (logs.some((l, n) => n > 0 && l.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const refs: EntropyInstantPolicyEventReference[] = [];
  const found = (target: Address, name: string, iface = abi) => {
    const f = iface.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], f.topicHash)).map(log => {
      const args = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, args);
      if (!same(encoded.data, log.data)) throw Error(`Noncanonical ${name} event data`);
      equal(encoded.topics.map(v => v.toLowerCase()), log.topics, `Noncanonical ${name} topics`);
      return { log, args };
    });
  };
  const reference = (log: Log, name: string) => {
    refs.push({ address: log.address, event: name, logIndex: log.index, transactionHash, blockHash: h.blockHash });
  };
  const one = (target: Address, name: string, expected: readonly unknown[]) => {
    const list = found(target, name);
    if (list.length !== 1) throw Error(`Expected exactly one ${name}`);
    const encoded = abi.encodeEventLog(abi.getEvent(name)!, expected);
    if (!same(encoded.data, list[0]!.log.data)) throw Error(`${name} fields differ`);
    equal(encoded.topics.map(v => v.toLowerCase()), list[0]!.log.topics, `${name} indexed fields differ`);
    reference(list[0]!.log, name);
    return list[0]!.log.index;
  };
  const finish = async () => {
    if (execution === "safe") {
      const successes = logs.filter(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
      if (successes.length !== 1 || logs.some(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionFailure")!.topicHash))) throw Error("Safe requires one success and no failure");
      const log = successes[0]!, iface = log.topics.length === 2 ? safeIndexed : safePlain;
      const parsed = found(caller, "ExecutionSuccess", iface);
      hash(parsed[0]!.args[0]);
      if (refs.some(v => v.logIndex >= log.index)) throw Error("Safe success must follow protocol events");
      reference(log, "ExecutionSuccess");
    }
    await unchanged(p, h);
    return refs.sort((a, b) => a.logIndex - b.logIndex);
  };
  return { tag, h, transactionHash, found, reference, one, finish };
}
function receiptOptions(v: ReceiptOptions): ReceiptOptions {
  keys(v, ["transactionHash", "execution"]);
  if (v.execution !== "direct" && v.execution !== "safe") throw Error("Unsupported receipt execution");
  return freeze({ transactionHash: hash(v.transactionHash), execution: v.execution });
}

export interface EntropyInstantPolicyReceipt {
  readonly operation: EntropyInstantPolicyOperation;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly events: readonly EntropyInstantPolicyEventReference[]; readonly observed: EntropyInstantPolicyCapture | null;
  readonly stateAttribution: "events identify this operation; exact end-of-block policy state required";
}
export interface EntropyInstantPolicyConsentReceipt {
  readonly capture: EntropyInstantPolicyConsentCapture;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly recordHash: Hex; readonly evidenceId: Hex; readonly archiveBytes: Hex;
  readonly events: readonly EntropyInstantPolicyEventReference[];
}
/** Original op17 owner event, permanent record and full seven-owner Archive envelope. */
export async function inspectEntropyInstantPolicyConsentReceipt(p: ReceiptReader, input: EntropyInstantPolicyConsentCapture,
  supplied: ReceiptOptions): Promise<EntropyInstantPolicyConsentReceipt> {
  const c = savedConsent(input), options = receiptOptions(supplied), i = c.inspection, old = i.capture, d = old.deployment, q = c.consent;
  equal(await captureEntropyInstantPolicyConsent(p, i, q), c, "Historical consent capture differs");
  const m = await mined(p, d, q.caller, q.call, old.blockNumber, options), { h, tag, one } = m;
  if (h.timestamp > q.authorization.deadline) throw Error("Artist execution exceeded signed deadline");
  const artist = await artistContext(p, d.artist, tag, false);
  equal(artist.configurationHash, c.configurationHash, "Artist configuration changed");
  const recordHash = artistRecord(c, h.timestamp), terms = consentTerms(i.plan), owner = d.artist.components[6]!.address;
  const recorded = one(owner, "ArtistContentConsentRecorded", [1n, terms.collectionId, terms.familyId, q.signer,
    terms.newStateHash, c.authority.authorityClass, q.authorization.nonce, h.timestamp, recordHash]);
  const contextual = one(owner, "ArtistContentRecordContext", [1n, recordHash, terms.metadataContract, c.binding.artistId]);
  if (contextual <= recorded) throw Error("Content context event order differs");
  const [retained] = await read(p, owner, "contentConsentRecord", [recordHash], tag);
  equal(retained, { recordHash, artistId: c.binding.artistId, bindingGeneration: c.binding.generation,
    terms, authorityClass: c.authority.authorityClass }, "Stored content consent differs");
  const replay = await replayRead(p, d, c.binding.artistId, q.payload.digest, q.authorization.nonce, tag);
  if (!replay.digestObserved || !replay.nonceConsumed || replay.digestRevoked || replay.nonceRevoked) throw Error("Consumed Artist authorization differs");
  const evidenceId = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), d.chainId, q.registry, d.artist.coordinator.address, 17n, q.caller, recordHash])) as Hex;
  const archive = d.artist.components[8]!.address;
  const metadata = await read(p, archive, "artistEvidenceMetadataV2", [evidenceId, 1n], tag);
  const [archiveBytes] = await read(p, archive, "artistEvidenceBytesV2", [evidenceId, 1n], tag);
  bytes(archiveBytes, 24575);
  if (metadata[3] !== BigInt(tag) || metadata[2] !== BigInt((archiveBytes.length - 2) / 2) || !same(metadata[0], keccak256(archiveBytes))) throw Error("Archive metadata differs");
  const pointer = address(metadata[1]);
  if (!same(bytes(await p.getCode(pointer, tag), 24576), `0x00${archiveBytes.slice(2)}`)) throw Error("Archive stored bytes differ");
  const archived = one(archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], pointer, metadata[2]]);
  if (archived <= contextual) throw Error("Archive precedes content evidence");
  const envelope = decode(["uint16", "bytes32", "uint16", "address", "bytes32", `${S}[7]`, `${S}[7]`, "bytes"], archiveBytes);
  equal(envelope.slice(0, 5), [1n, c.configurationHash, 17n, q.caller, recordHash], "Archive operation differs");
  for (let n = 0; n < 7; n++) {
    const before = envelope[5][n], after = envelope[6][n];
    if (0x57 & (1 << n)) {
      if (!same(before.domainId, domains[n]) || !same(after.domainId, domains[n])
        || same(before.stateRoot, ZeroHash) || same(after.stateRoot, ZeroHash)) throw Error("Archive owner domain/root differs");
      if (0x44 & (1 << n)) {
        if (after.revision !== before.revision + 1n || same(after.recordChainTip, ZeroHash)) throw Error("Written owner did not advance exactly once");
      } else equal(before, after, "Read-only owner changed");
    } else {
      const zero = { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash };
      equal(before, zero); equal(after, zero);
    }
  }
  const expectedPayload = coder.encode([B, CONSENT, A, PROOF, "bytes32"], [c.binding, terms,
    { nonce: q.authorization.nonce, time: q.authorization.deadline, signature: q.authorization.signature },
    { signer: q.signer, digest: q.payload.digest, direct: q.direct }, c.currentContentStateHash]);
  equal(envelope[7], expectedPayload.toLowerCase(), "Archive consent payload differs");
  const events = await m.finish();
  return freeze({ capture: c, transactionHash: m.transactionHash, blockNumber: tag, blockHash: h.blockHash, recordHash,
    evidenceId, archiveBytes, events });
}
/** Policy events and exact end-of-block readback; repeated configure/freeze are not idempotent. */
export async function inspectEntropyInstantPolicyReceipt(p: ReceiptReader, input: EntropyInstantPolicyOperation,
  supplied: ReceiptOptions): Promise<EntropyInstantPolicyReceipt> {
  const o = operation(input), options = receiptOptions(supplied), i = o.prepared.inspection, c = i.capture, d = c.deployment, b = o.prepared.batch;
  await original(p, c);
  const m = await mined(p, d, o.caller, o.call, c.blockNumber, options), { tag, one, found } = m;
  const h = await context(p, d, tag, false);
  let observed: EntropyInstantPolicyCapture | null = null;
  if (o.stage === "publish") {
    const pointer = await publication(p, b, tag);
    if (!pointer) throw Error("Publication not retained");
    const prior = await header(p, tag - 1);
    await runtime(p, d.governance, tag - 1);
    const previousPointer = await publication(p, b, tag - 1);
    if (previousPointer && !same(previousPointer, pointer)) throw Error("Immutable publication pointer changed");
    if (found(d.governance.address, "GovernanceCallDataPublished").length) {
      if (previousPointer) throw Error("Repeat publication cannot emit first-save event");
      one(d.governance.address, "GovernanceCallDataPublished", [1n, b.publicationKey, pointer, o.caller]);
    } else if (!previousPointer) throw Error("Eventless publication requires previous-block proof");
    await unchanged(p, prior);
  } else {
    equal(h.catalog, c.catalog, "Receipt catalog differs from reviewed catalog");
    const state = await action(p, o, tag);
    const common = [1n, b.actionId, b.plan.actionClass, b.plan.targetCall.to, 0n, b.plan.governanceCall.selector,
      b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
    const policyIndex = one(d.governance.address, "GovernanceActionPolicyValidated", [1n, b.actionId,
      o.stage === "schedule" ? 1n : 2n, c.catalog.candidateProfileHash, c.catalog.catalogHash]);
    if (o.stage === "schedule") {
      policy.assertEntropyInstantPolicyGovernanceWindow(b.plan.actionClass, b.window, h.timestamp);
      const statuses = b.plan.kind === "freeze" ? [1n, 2n, 5n] : [1n, 2n];
      if (!statuses.includes(state.status) || h.governanceNonce < b.nonce + 1n) throw Error("Scheduled action/nonce not retained");
      const scheduled = one(d.governance.address, "GovernanceActionScheduled", [...common, b.window.notBefore,
        b.window.expiresAfter, b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      if (b.plan.kind === "freeze") {
        const commitment = hash((await read(p, d.governance.address, "terminalFreezeGuardianConfigCommitment", [b.actionId], tag))[0]);
        const committed = one(d.governance.address, "TerminalFreezeGuardianConfigCommitted", [1n, b.actionId, commitment]);
        const memberships = found(d.governance.address, "TerminalFreezeActionMembershipUpdated")
          .filter(v => same(v.args[2], b.actionId) && v.args[4] === true);
        if (memberships.length !== 1) throw Error("Expected original freeze membership append");
        const entry = memberships[0]!, a = entry.args;
        if (a[0] !== 1n || !same(a[1], b.plan.transition.scopeHash) || !same(a[3], o.caller) || a[5] !== 1n
          || a[7] !== b.window.notBefore || a[9] !== a[8] + 1n || a[9] > 64n) throw Error("Freeze membership fields differ");
        m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
        if (!(entry.log.index < committed && committed < scheduled)) throw Error("Freeze membership/commitment event order differs");
      }
      if (policyIndex <= scheduled) throw Error("Catalog validation event must follow scheduling");
    } else {
      if (state.status !== 3n || !same(state.executor, o.caller) || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Executed action/window differs");
      const executed = one(d.governance.address, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]);
      observed = await captureAt(p, d, c.snapshot.collectionId, tag, false);
      const eventName = b.plan.kind === "configure" ? "CollectionEntropyPolicyConfigured" : "CollectionEntropyPolicyFrozen";
      const hits = found(d.coordinator.address, eventName);
      if (hits.length !== 1) throw Error(`Expected one ${eventName}`);
      const consentRecord = hash(hits[0]!.args[b.plan.kind === "configure" ? 10 : 5]);
      const next = { ...b.plan.next, entry: { ...b.plan.next.entry, lastActionId: b.actionId, artistConsentRecord: consentRecord },
        recovery: { ...b.plan.next.recovery, lastActionId: b.plan.next.recovery.revision !== c.snapshot.recovery.revision
          ? b.actionId : b.plan.next.recovery.lastActionId } };
      const expected = { ...c.snapshot, ...next, collectionExists: observed.snapshot.collectionExists,
        collectionFrozen: observed.snapshot.collectionFrozen, collectionMintedEver: observed.snapshot.collectionMintedEver,
        revealEscrow: observed.snapshot.revealEscrow };
      equal(observed.snapshot, expected, "Receipt-block policy changed; exact state unavailable");
      const index = b.plan.kind === "configure"
        ? one(d.coordinator.address, eventName, [2n, c.snapshot.collectionId, next.entry.policyHash, next.entry.revision,
          next.providerEpoch, b.plan.input, next.config.providerCodeHash, next.config.providerConfigHash,
          next.recovery.policyHash, b.actionId, consentRecord])
        : one(d.coordinator.address, eventName, [2n, c.snapshot.collectionId, next.entry.policyHash, next.entry.revision, b.actionId, consentRecord]);
      if (index >= executed) throw Error("Policy event must precede governance execution");
      // Durable original op17 record; current Artist status and provider availability may have changed.
      await artistContext(p, d.artist, tag, false);
      const [record] = await read(p, d.artist.components[6]!.address, "contentConsentRecord", [consentRecord], tag);
      if (!same(record.recordHash, consentRecord) || ![1n, 3n].includes(record.authorityClass)
        || !record.bindingGeneration) throw Error("Historical Artist evidence differs");
      hash(record.artistId);
      equal(record.terms, consentTerms(b.plan), "Historical content terms differ");
      if (b.plan.kind === "freeze") {
        const removals = found(d.governance.address, "TerminalFreezeActionMembershipUpdated")
          .filter(v => same(v.args[2], b.actionId) && v.args[4] === false);
        if (removals.length > 1) throw Error("Duplicate freeze membership removal");
        if (removals.length) {
          const entry = removals[0]!, a = entry.args;
          if (a[0] !== 1n || !same(a[1], b.plan.transition.scopeHash) || !same(a[3], o.prepared.proposer)
            || a[5] !== 3n || a[7] !== b.window.notBefore || a[8] > a[9] || a[9] >= 64n
            || entry.log.index >= index) throw Error("Freeze membership removal differs");
          m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
        }
      }
      if (policyIndex <= executed) throw Error("Catalog validation event must follow execution");
    }
  }
  const events = await m.finish();
  return freeze({ operation: o, transactionHash: m.transactionHash, blockNumber: tag, blockHash: h.blockHash, events, observed,
    stateAttribution: "events identify this operation; exact end-of-block policy state required" });
}

/** Source-valid delayed providers; direct observations do not prove nested gas forwarding. */
export interface EntropyInstantProviderObservation {
  readonly address: Address; readonly codeHash: Hex; readonly configHash: Hex;
  readonly family: Hex; readonly version: Hex; readonly mode: 1n; readonly assumptionsHash: Hex;
  readonly noNestedGasEquivalence: true;
}
async function instantProfile(p: Reader, host: Address, provider: Address, tag: number,
  active: boolean): Promise<EntropyInstantProviderObservation> {
  const [r] = await read(p, host, "entropyProviderRecord", [provider], tag);
  if (active && r.state !== 1n) throw Error("Provider is not ACTIVE");
  const codeHash = hash(r.runtimeCodeHash);
  await runtime(p, { address: provider, codeHash }, tag);
  for (const [iid, expected] of [["0x01ffc9a7", true], ["0x5d42f023", true], ["0xb8bedf9e", true],
    ["0xffffffff", false], ["0x9cd4388e", false]] as const) {
    if ((await read(p, provider, "supportsInterface", [iid], tag, host))[0] !== expected) throw Error("Instant provider interface differs");
  }
  if ((await read(p, provider, "isStreamInstantEntropyProvider", [], tag, host))[0] !== true) throw Error("Instant marker differs");
  const [mode, assumptions] = await read(p, provider, "instantEntropyProfile", [], tag, host);
  if (mode !== 1n) throw Error("Only delayed-blockhash mode is admitted");
  const [cap, floor, failureClass, revision] = await read(p, host, "gasParameterInfo", [policy.ENTROPY_INSTANT_READ_GAS], tag);
  if (!cap || cap < floor || floor !== 100000n || failureClass !== 2n || !revision) throw Error("Instant read gas profile differs");
  return freeze({ address: provider, codeHash,
    configHash: hash((await read(p, provider, "streamEntropyProviderConfigHash", [], tag, host))[0]),
    family: hash((await read(p, provider, "streamEntropyProviderFamily", [], tag, host))[0]),
    version: hash((await read(p, provider, "streamEntropyProviderVersion", [], tag, host))[0]),
    mode: 1n, assumptionsHash: hash(assumptions), noNestedGasEquivalence: true });
}
export interface EntropyInstantRequestDeployment {
  readonly chainId: bigint;
  readonly core: EntropyInstantPolicyCodePin;
  readonly coordinator: EntropyInstantPolicyCodePin;
  /** Bundled profile additionally checks its exact identity and blockhash preimages. */
  readonly providerProfile?: "source-delayed" | "bundled-blockhash";
}
export interface EntropyInstantFactsCapture {
  readonly deployment: EntropyInstantRequestDeployment; readonly tokenId: bigint;
  readonly facts: policy.EntropyInstantTerminalFacts;
  readonly identity: { readonly collectionId: bigint; readonly collectionSerial: bigint; readonly burned: boolean };
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
}
function requestDeployment(input: EntropyInstantRequestDeployment): EntropyInstantRequestDeployment {
  keys(input, ["chainId", "core", "coordinator"], ["providerProfile"]);
  const pin = (v: EntropyInstantPolicyCodePin) => {
    keys(v, ["address", "codeHash"]);
    return { address: address(v.address), codeHash: hash(v.codeHash) };
  };
  const profile = input.providerProfile ?? "source-delayed";
  if (profile !== "source-delayed" && profile !== "bundled-blockhash") throw Error("Unsupported provider profile");
  const chainId = uint(input.chainId);
  if (!chainId) throw Error("Zero chain");
  return freeze({ chainId, core: pin(input.core), coordinator: pin(input.coordinator), providerProfile: profile });
}
async function requestContext(p: Reader, d: EntropyInstantRequestDeployment, tag: number) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([runtime(p, d.core, tag), runtime(p, d.coordinator, tag)]);
  if (!same((await read(p, d.coordinator.address, "core", [], tag))[0], d.core.address)) throw Error("Original Core binding differs");
  return h;
}
const factsAbi = new Interface([`function staticTerminalEntropyFacts(uint256) view returns(uint256 collectionId,${base.ENTROPY_COLLECTION_POLICY_RECORD_TUPLE} policy,uint8 status,bytes32 seed,bytes32 requestKey)`]);
async function factsAt(p: Reader, d: EntropyInstantRequestDeployment, tokenId: bigint, tag: number): Promise<EntropyInstantFactsCapture> {
  const h = await requestContext(p, d, tag);
  const raw = bytes(await p.call({ to: d.coordinator.address, data: factsAbi.encodeFunctionData("staticTerminalEntropyFacts", [tokenId]), blockTag: tag }), 512);
  const facts = policy.decodeEntropyInstantTerminalFacts(raw);
  if (!facts.collectionId || !facts.policy.configured || !facts.policy.explicitPolicy || !facts.policy.revision
    || facts.status < 1n || facts.status > 7n) throw Error("Explicit registered subject required");
  hash(facts.policy.policyHash);
  if (!same(facts.policy.contentStateHash, base.entropyCollectionPolicyContentStateHash(facts.policy.policyHash, facts.policy.frozen))) throw Error("Direct policy content hash differs");
  const [exists, collectionId, collectionSerial, burned] = await read(p, d.core.address, "tokenCollectionIdentity", [tokenId], tag);
  if (!exists || !collectionSerial || collectionId !== facts.collectionId
    || !same((await read(p, d.core.address, "coordinatorAtMint", [tokenId], tag))[0], d.coordinator.address)) throw Error("Original token/Coordinator identity differs");
  await unchanged(p, h);
  return freeze({ deployment: d, tokenId, facts, identity: { collectionId, collectionSerial, burned }, ...h });
}
/** Direct sixteen-word original getter. REGISTERED is reported as REGISTERED; no finality is inferred. */
export async function readEntropyInstantTerminalFacts(p: Reader, supplied: EntropyInstantRequestDeployment,
  tokenId: bigint, options: { readonly blockTag: number }): Promise<EntropyInstantFactsCapture> {
  keys(options, ["blockTag"]);
  const d = requestDeployment(supplied), token = uint(tokenId), tag = number(options.blockTag);
  if (!token) throw Error("Zero token");
  return factsAt(p, d, token, tag);
}
export interface EntropyInstantRequestCapture {
  readonly deployment: EntropyInstantRequestDeployment; readonly plan: policy.EntropyInstantRequestPlan;
  readonly provider: EntropyInstantProviderObservation;
  readonly authorization: "authority" | "requester" | "public" | "admin-role-simulation-required";
  readonly callerCreditBefore: bigint; readonly totalCreditsBefore: bigint;
  readonly pendingBefore: bigint; readonly nonterminalBefore: bigint;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly captureHash: Hex;
}
function requestSaved(input: EntropyInstantRequestCapture): EntropyInstantRequestCapture {
  keys(input, ["deployment", "plan", "provider", "authorization", "callerCreditBefore", "totalCreditsBefore",
    "pendingBefore", "nonterminalBefore", "blockNumber", "blockHash", "timestamp", "captureHash"]);
  const copied = structuredClone(input), d = requestDeployment(copied.deployment);
  const plan = policy.normalizeEntropyInstantRequestPlan(copied.plan);
  equal(plan, copied.plan); equal(d, copied.deployment);
  if (plan.snapshot.chainId !== d.chainId || !same(plan.snapshot.core, d.core.address)
    || !same(plan.snapshot.coordinator, d.coordinator.address) || plan.snapshot.blockNumber !== BigInt(number(copied.blockNumber))) throw Error("Request capture coordinates differ");
  hash(copied.blockHash); uint(copied.timestamp, 64);
  const { captureHash, ...body } = copied;
  if (!same(digest(body), captureHash)) throw Error("Request capture reconstruction differs");
  return freeze(copied);
}
async function bundled(p: Reader, d: EntropyInstantRequestDeployment, v: EntropyInstantProviderObservation, tag: number) {
  if (d.providerProfile !== "bundled-blockhash") return;
  if (!same(v.family, policy.ENTROPY_INSTANT_PROVIDER_FAMILY) || !same(v.version, policy.ENTROPY_INSTANT_PROVIDER_VERSION)
    || !same(v.assumptionsHash, policy.ENTROPY_INSTANT_ASSUMPTIONS_HASH)
    || !same(v.configHash, policy.entropyInstantProviderConfigHash(d.coordinator.address))
    || !same((await read(p, v.address, "coordinator", [], tag, d.coordinator.address))[0], d.coordinator.address)) throw Error("Bundled provider profile differs");
}
/** Fresh original request, separate from selected-current policy mutation and governance readiness. */
export async function captureEntropyInstantRequest(p: Reader, supplied: EntropyInstantRequestDeployment, tokenId: bigint,
  caller: Address, value: bigint, options: { readonly blockTag: number }): Promise<EntropyInstantRequestCapture> {
  keys(options, ["blockTag"]);
  const d = requestDeployment(supplied), token = uint(tokenId), actor = address(caller), amount = uint(value), tag = number(options.blockTag);
  if (!token) throw Error("Zero token");
  const observed = await factsAt(p, d, token, tag), cid = observed.facts.collectionId;
  const configValues = await read(p, d.coordinator.address, "collectionEntropyConfig", [cid], tag);
  const config = base.normalizeEntropyCollectionPolicyConfig(Object.fromEntries(["provider", "publicRequests", "locked", "timeoutBlocks", "providerConfigHash", "providerCodeHash", "collectionSalt"].map((k, i) => [k, configValues[i]])) as unknown as base.EntropyCollectionPolicyConfig);
  const [subject] = await read(p, d.coordinator.address, "scopeEntropy", [policy.entropyInstantSubjectKey(token)], tag);
  equal({ collectionId: subject.collectionId, status: subject.status, seed: subject.seed, requestKey: subject.requestKey },
    { collectionId: cid, status: observed.facts.status, seed: observed.facts.seed, requestKey: observed.facts.requestKey }, "Subject/direct facts differ");
  const snapshot = policy.normalizeEntropyInstantRequestSnapshot({ chainId: d.chainId, core: d.core.address,
    coordinator: d.coordinator.address, collectionId: cid, tokenId: token, config, policy: observed.facts.policy, subject,
    registeredAtBlock: (await read(p, d.coordinator.address, "registeredAtBlock", [token], tag))[0], blockNumber: BigInt(tag),
    tokenLifecycle: (await read(p, d.core.address, "tokenLifecycle", [token], tag))[0], coordinatorAtMint: d.coordinator.address });
  const plan = policy.prepareEntropyInstantRequest(snapshot, actor, amount);
  equal(await read(p, d.coordinator.address, "tokenEntropy", [token], tag), [3n, ZeroHash, config.provider,
    snapshot.policy.providerEpoch, config.providerConfigHash, ZeroHash, 0n, 0n], "Original token view differs");
  const provider = await instantProfile(p, d.coordinator.address, config.provider, tag, true);
  if (!same(provider.codeHash, config.providerCodeHash) || !same(provider.configHash, config.providerConfigHash)) throw Error("Request provider/configuration drift");
  await bundled(p, d, provider, tag);
  if (!same((await read(p, d.coordinator.address, "providerRequestKeys", [config.provider, plan.providerRequestId], tag))[0], ZeroHash)) throw Error("Provider ID already bound");
  const priorRequest = await read(p, d.coordinator.address, "requests", [plan.requestKey], tag);
  equal(priorRequest, [ZeroHash, 0n, ZeroHash, ZeroAddress, 0n, 0n, ZeroHash], "Request key already stored");
  const authority = address((await read(p, d.coordinator.address, "authority", [], tag))[0]);
  let authorization: EntropyInstantRequestCapture["authorization"] = "admin-role-simulation-required";
  if (same(actor, authority)) authorization = "authority";
  else if ((await read(p, d.coordinator.address, "requesters", [actor], tag))[0]) authorization = "requester";
  else if (config.publicRequests) authorization = "public";
  const callerCreditBefore = uint((await read(p, d.coordinator.address, "entropyFeeCredit", [actor], tag))[0]);
  const totalCreditsBefore = uint((await read(p, d.coordinator.address, "totalFeeCredits", [], tag))[0]);
  const pendingBefore = uint((await read(p, d.coordinator.address, "pendingRequestCount", [], tag))[0]);
  const nonterminalBefore = uint((await read(p, d.coordinator.address, "nonterminalTokenCount", [cid], tag))[0]);
  if (!nonterminalBefore || totalCreditsBefore < callerCreditBefore || callerCreditBefore + amount >= 1n << 256n
    || totalCreditsBefore + amount >= 1n << 256n || pendingBefore === (1n << 256n) - 1n) throw Error("Accounting prestate contradicts request");
  await unchanged(p, observed);
  const body = { deployment: d, plan, provider, authorization, callerCreditBefore, totalCreditsBefore,
    pendingBefore, nonterminalBefore, blockNumber: tag, blockHash: observed.blockHash, timestamp: observed.timestamp };
  return freeze({ ...body, captureHash: digest(body) });
}
async function originalRequest(p: Reader, c: EntropyInstantRequestCapture): Promise<void> {
  equal(await captureEntropyInstantRequest(p, c.deployment, c.plan.snapshot.tokenId, c.plan.caller, c.plan.value,
    { blockTag: c.blockNumber }), c, "Historical request capture differs");
}
export interface EntropyInstantRequestSimulation {
  readonly capture: EntropyInstantRequestCapture; readonly observed: EntropyInstantRequestCapture;
  readonly returnData: Hex;
  readonly providerResult: { readonly rawRandomness: Hex; readonly provenanceHash: Hex; readonly seed: Hex; readonly sourceBlock: number; readonly sourceBlockHash: Hex } | null;
  readonly observation: "pinned-block simulation; future mined randomness and role admission require execution";
}
export async function simulateEntropyInstantRequest(p: Reader, input: EntropyInstantRequestCapture,
  options: { readonly blockTag: number }): Promise<EntropyInstantRequestSimulation> {
  const c = requestSaved(input); keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await originalRequest(p, c);
  const observed = await captureEntropyInstantRequest(p, c.deployment, c.plan.snapshot.tokenId, c.plan.caller, c.plan.value, { blockTag: tag });
  // Block and accounting balances can move; original request inputs and provider identity cannot silently change.
  equal({ ...observed.plan.snapshot, blockNumber: c.plan.snapshot.blockNumber }, c.plan.snapshot, "Request changed; recapture");
  equal(observed.provider, c.provider, "Provider changed; recapture");
  const returnData = bytes(await p.call({ ...c.plan.call, from: c.plan.caller, blockTag: tag }), 64);
  equal(decode(["bytes32", "uint256"], returnData), [c.plan.requestKey, c.plan.providerRequestId], "Original request return differs");
  // A generic provider may inspect the transient REQUESTED state installed by the original call.
  // Its standalone post-rollback read cannot reveal that call's raw result. Only the explicitly
  // reviewed, call-free bundled adapter has an independently computable blockhash result.
  let providerResult: EntropyInstantRequestSimulation["providerResult"] = null;
  if (c.deployment.providerProfile === "bundled-blockhash") {
    const source = await header(p, tag - 1);
    const result = policy.entropyInstantRawResult(c.plan.requestKey, c.plan.context, BigInt(source.blockNumber),
      source.blockHash, c.provider.configHash, c.provider.assumptionsHash);
    providerResult = { ...result, seed: policy.entropyInstantSeed(c.plan, result.rawRandomness),
      sourceBlock: source.blockNumber, sourceBlockHash: source.blockHash };
    await unchanged(p, source);
  }
  await unchanged(p, observed);
  return freeze({ capture: c, observed, returnData, providerResult,
    observation: "pinned-block simulation; future mined randomness and role admission require execution" });
}
export interface EntropyInstantRequestReceipt {
  readonly capture: EntropyInstantRequestCapture; readonly transactionHash: Hex;
  readonly blockNumber: number; readonly blockHash: Hex; readonly events: readonly EntropyInstantPolicyEventReference[];
  readonly facts: policy.EntropyInstantTerminalFacts; readonly rawRandomness: Hex; readonly provenanceHash: Hex;
  readonly credited: bigint; readonly metadataNotificationFailed: boolean; readonly metadataNotificationPending: boolean;
  readonly accounting: { readonly callerCredit: bigint; readonly totalCredits: bigint; readonly pendingRequests: bigint; readonly nonterminalTokens: bigint };
  readonly attribution: "events identify this request; balances and notification flag are end-of-block observations";
}
export async function inspectEntropyInstantRequestReceipt(p: ReceiptReader, input: EntropyInstantRequestCapture,
  supplied: ReceiptOptions): Promise<EntropyInstantRequestReceipt> {
  const c = requestSaved(input), options = receiptOptions(supplied), d = c.deployment, plan = c.plan;
  await originalRequest(p, c);
  const m = await mined(p, d, plan.caller, plan.call, c.blockNumber, options), tag = m.tag;
  if (BigInt(tag) <= plan.snapshot.registeredAtBlock) throw Error("Request must follow delivery block");
  const observed = await factsAt(p, d, plan.snapshot.tokenId, tag);
  equal(observed.facts.policy, plan.snapshot.policy, "Receipt-block explicit policy differs");
  const produced = m.found(d.coordinator.address, "InstantEntropyProduced");
  if (produced.length !== 1) throw Error("Expected one InstantEntropyProduced");
  const rawRandomness = hash(produced[0]!.args[3], true), provenanceHash = hash(produced[0]!.args[4], true);
  const seed = policy.entropyInstantSeed(plan, rawRandomness);
  equal(observed.facts, { collectionId: plan.snapshot.collectionId, policy: plan.snapshot.policy, status: 5n, seed, requestKey: plan.requestKey }, "Finalized direct facts differ");
  const requested = m.one(d.coordinator.address, "EntropyRequested", [plan.requestKey, plan.snapshot.tokenId, ZeroHash, c.provider.address, plan.providerRequestId]);
  const instant = m.one(d.coordinator.address, "InstantEntropyProduced", [1n, plan.requestKey, plan.providerRequestId, rawRandomness, provenanceHash, 1n, c.provider.assumptionsHash]);
  const finalized = m.one(d.coordinator.address, "EntropyFinalized", [plan.requestKey, plan.snapshot.tokenId, ZeroHash, seed, rawRandomness]);
  if (!(requested < instant && instant < finalized)) throw Error("Instant lifecycle event order differs");
  const credits = m.found(d.coordinator.address, "EntropyFeeCredited");
  if (plan.value > 0n) {
    const credited = m.one(d.coordinator.address, "EntropyFeeCredited", [plan.caller, plan.value]);
    if (credited >= requested) throw Error("Credit must precede request");
  } else if (credits.length) throw Error("Zero payment must not emit credit");
  equal(await read(p, d.coordinator.address, "requests", [plan.requestKey], tag), [plan.subjectKey, plan.snapshot.tokenId, ZeroHash,
    c.provider.address, BigInt(tag), plan.providerRequestId, rawRandomness], "Stored request differs");
  equal((await read(p, d.coordinator.address, "requestPolicySnapshot", [plan.requestKey], tag))[0], plan.requestPolicy, "Stored request policy differs");
  if (!same((await read(p, d.coordinator.address, "providerRequestKeys", [c.provider.address, plan.providerRequestId], tag))[0], plan.requestKey)) throw Error("Reverse provider binding differs");
  equal((await read(p, d.coordinator.address, "scopeEntropy", [plan.subjectKey], tag))[0],
    { ...plan.snapshot.subject, status: 5n, requestKey: plan.requestKey, seed }, "Stored subject differs");
  equal(await read(p, d.coordinator.address, "tokenEntropy", [plan.snapshot.tokenId], tag), [5n, seed, c.provider.address,
    plan.requestPolicy.providerEpoch, plan.requestPolicy.providerConfigHash, plan.requestKey, plan.providerRequestId, 1n], "Final token view differs");
  // Historical request proof survives provider lifecycle and selected Coordinator changes.
  await runtime(p, { address: c.provider.address, codeHash: c.provider.codeHash }, tag);
  if (d.providerProfile === "bundled-blockhash") {
    const source = await header(p, tag - 1);
    equal({ rawRandomness, provenanceHash }, policy.entropyInstantRawResult(plan.requestKey, plan.context,
      BigInt(source.blockNumber), source.blockHash, c.provider.configHash, c.provider.assumptionsHash), "Mined blockhash output differs");
    await unchanged(p, source);
  }
  const failed = m.found(d.coordinator.address, "MetadataNotificationFailed");
  if (failed.length > 1) throw Error("Duplicate notification failure");
  if (failed.length && m.one(d.coordinator.address, "MetadataNotificationFailed", [plan.snapshot.tokenId, plan.requestKey]) <= finalized) throw Error("Notification failure must follow finalization");
  const metadataNotificationPending = (await read(p, d.coordinator.address, "metadataNotificationPending", [plan.snapshot.tokenId], tag))[0] as boolean;
  const accounting = {
    callerCredit: uint((await read(p, d.coordinator.address, "entropyFeeCredit", [plan.caller], tag))[0]),
    totalCredits: uint((await read(p, d.coordinator.address, "totalFeeCredits", [], tag))[0]),
    pendingRequests: uint((await read(p, d.coordinator.address, "pendingRequestCount", [], tag))[0]),
    nonterminalTokens: uint((await read(p, d.coordinator.address, "nonterminalTokenCount", [plan.snapshot.collectionId], tag))[0])
  };
  if (accounting.totalCredits < accounting.callerCredit) throw Error("Credit totals contradict caller balance");
  const events = await m.finish();
  return freeze({ capture: c, transactionHash: m.transactionHash, blockNumber: tag, blockHash: m.h.blockHash, events,
    facts: observed.facts, rawRandomness, provenanceHash, credited: plan.value, metadataNotificationFailed: failed.length === 1,
    metadataNotificationPending, accounting,
    attribution: "events identify this request; balances and notification flag are end-of-block observations" });
}
