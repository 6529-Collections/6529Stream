import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { CurrentArtistDeployment } from "./current-artist-workflow.js";
import type { ArtistHydrationSnapshot } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_SNAPSHOT_TUPLE } from "./current-artist-authority-hydration.js";
import * as recovery from "./current-artist-recovery-adjudication.js";

// Retained 3ac39b55 compiler ABI. No V1 or rewind selectors are dispatched here.
const abi = new Interface([
  "event ArtistIdentityRecoveryPrepared(uint16 schemaVersion,bytes32 indexed artistId,bytes32 indexed governanceActionId,bytes32 associationHash,bytes32 guardianRecordHash,address preparedBy,uint64 preparedAt)",
  "function reads() view returns(address)",
  "event ArtistDormancyCancelled(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed noticeHash, address canceller, uint8 authorityClass, bytes32 cancellationHash)",
  "event ArtistIdentityRecovered(uint16 schemaVersion, bytes32 indexed artistId, address indexed oldAddress, address indexed newAddress, uint8 vestedAuthorityClass, bytes32 evidenceHash, bytes32 reasonHash, bytes32 supersededRecordsHash, uint64 recoveredAt, bytes32 recoveryRecordHash, bytes32 governanceActionId, bytes32[] supersededRecordHashes)",
  "event ArtistStoredPayload(uint16 schemaVersion, uint256 indexed index, bytes32 indexed payloadType, bytes32 indexed payloadHash, address pointer)",
  "function artistRegistryCutover() view returns (bool, address, uint64)",
  "function core() view returns (address)",
  "function dormancyRecord(bytes32 hash) view returns ((bytes32 recordHash, (bytes32 artistId, bytes32 evidenceHash, string reasonURI) terms, address incumbent, uint64 initiatedAt, uint64 noticeEndsAt, uint64 inactivitySeconds, uint64 noticeSeconds, uint64 timingRevision, uint64 priorLivenessAt, uint256 priorActivity, bytes32 actionId, bytes32 witnessHash), uint8, (bytes32 recordHash, bytes32 noticeHash, address actor, uint8 authorityClass, uint64 observedAt, uint64 appointmentBlock, (address authority, uint8 authorityClass, uint32 capabilities, bytes32 designation, bytes32 directive, bytes32 guardian, bytes32 stewardGrantRecordHash, uint64 postSeconds, uint64 standingTail) plan, bytes32 evidenceHash, bytes32 actionId, bytes32 witnessHash, uint64 delegationEpoch))",
  "function estateDirectiveRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, uint32 grantedCapabilities, uint32 forbiddenCapabilities, bytes32 directivePayloadHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function governanceAuthority() view returns (address)",
  "function guardianSetRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, address[] guardians, uint32 approvalThreshold, uint64 minContestSeconds) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 previousOperativeRecordHash, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function identityContestCause(bytes32 causeHash) view returns ((bytes32 causeHash, (bytes32 artistId, uint8 kind, bytes32 referenceHash, address actor, bytes32 reasonHash, bytes32 evidenceHash, uint64 enteredAt, address incumbent, uint8 authorityClass, uint8 priorStatus, bytes32 pendingTransitionHash, bytes32 executedTransitionHash, bytes32 previousCauseHash, bytes32 previousResolutionHash, bytes32 actorRetirementHash) facts))",
  "function identityRecoveryActionState(bytes32 artistId, bytes32 actionId) view returns ((bytes32 associationHash, bytes32 artistId, bytes32 requestHash, bytes32 acceptanceHash, bytes32 contextHash, (bytes32 actionId, bytes32 callsHash, uint256 callIndex, bytes32 callDataHash, address executor, bytes32 executorCodeHash, address proposer, bytes32 roleMutationHash, uint64 roleRevision, uint64 notBefore, uint64 expiresAfter, uint64 minimumDelay, bytes32 manifestHash) action, (bytes32 recordHash, (bytes32 artistId, address[] guardians, uint32 approvalThreshold, uint64 minContestSeconds) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 previousOperativeRecordHash, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional) guardian, address preparedBy, uint64 preparedAt, uint64 ownerRevision), (address vetoer, bytes32 reasonHash, uint64 vetoedAt), bytes32, uint64)",
  "function identityRecoveryContextV2((bytes32 artistId, address newAddress, uint8 vestedAuthorityClass, bytes32 expectedCauseHash, bytes32 expectedResolutionHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32[] supersededRecordHashes) p, (uint256 nonce, uint64 time, bytes signature) a, bytes32 manifestHash) view returns ((bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, bytes32 causeHash, address incumbent, uint64 postContestSeconds, uint64 standingTailSeconds, uint64 timingRevision, uint64 delegationEpoch, (bytes32 artistId, bytes32 recordHash, uint64 stagedAt, uint64 contestEndsAt, uint64 executedAt, uint64 postWindowEndsAt, uint64 contestedAt, uint8 phase) abandonedTransition))",
  "function identityRecoveryEvidenceState(bytes32 artistId, bytes32 actionId) view returns ((bytes32 manifestHash, bytes32 basisCommitment, bytes32 selectionCommitment, bytes32 requiredRole, uint64 preparedFromOwnerRevision, bytes32 associationHash))",
  "function identityRecoveryRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, address oldAddress, address newAddress, uint8 vestedAuthorityClass, bytes32 evidenceHash, bytes32 reasonHash, bytes32 supersededRecordsHash, bytes32 governanceActionId, uint64 recoveredAt) fields, (bytes32 artistId, address newAddress, uint8 vestedAuthorityClass, bytes32 expectedCauseHash, bytes32 expectedResolutionHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32[] supersededRecordHashes) terms, address executor, address proposer, bytes32 governanceWitnessHash, bytes32 contextHash, bytes32 acceptanceDigest, uint256 acceptanceNonce, uint64 acceptanceDeadline, uint64 postContestSeconds, uint64 standingTailSeconds, uint64 timingRevision, uint64 delegationEpoch, (bytes32 artistId, bytes32 recordHash, uint64 stagedAt, uint64 contestEndsAt, uint64 executedAt, uint64 postWindowEndsAt, uint64 contestedAt, uint8 phase) abandonedTransition))",
  "function mintManager() view returns (address)",
  "function operationCoordinator() view returns (address)",
  "function operativeEstateDirective(bytes32 artistId) view returns (bytes32)",
  "function rotationAcceptanceNonceState(bytes32 artistId, address account, uint256 nonce) view returns (bool, uint256)",
  "function storedPayloadAt(uint256 index) view returns (address, bytes32, bytes32)",
  "function storedPayloadCount() view returns (uint256)",
  "function configurationHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function suiteConfiguration() view returns ((address registry, address archive, address[7] owners, address core, address mintManager, address roleRegistry, address metadata, address primaryResolver, address royaltyResolver, bytes32 primaryRevenueClass, address validator))",
  "function archiveV2() view returns (address)",
  "function artistNativeReceiptAt(uint256 index) view returns ((uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash))",
  "function artistNativeReceiptCount() view returns (uint256)",
  "function artistRegistry() view returns (address)",
  "function artistWindowAuthority() view returns (address)",
  "function domainId() view returns (bytes32)",
  "function dormancyResolutionState(bytes32 id, bytes32 cause) view returns (bytes32, uint8, bytes32)",
  "function guardianHistoryState(bytes32 artistId, uint64 index, address actor, bytes32 actionId) view returns ((uint64 count, uint64 ownerRevision, bytes32 commitment), (bytes32 artistId, uint64 index, uint64 ownerRevision, bytes32 recordHash, bytes32 recordDataHash, bytes32 previousCommitment, bytes32 commitment), (bytes32 artistId, uint64 count, bytes32 historyCommitment, bytes32 associationHash), uint64)",
  "function guardianRecoveryAuthorityRoleV2((bytes32 artistId, address newAddress, uint8 vestedAuthorityClass, bytes32 expectedCauseHash, bytes32 expectedResolutionHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32[] supersededRecordHashes) p, (uint256 nonce, uint64 time, bytes signature) a, bytes32 manifestHash) view returns (bytes32)",
  "function guardianRecoverySelection(bytes32 actionId) view returns ((bytes32 sourceKey, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bytes32 commitment), (bytes32 recordHash, (bytes32 artistId, address[] guardians, uint32 approvalThreshold, uint64 minContestSeconds) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 previousOperativeRecordHash, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function guardianVestingSnapshot(bytes32 artistId, bytes32 recordHash) view returns ((bytes32 artistId, bytes32 transitionRecordHash, uint16 operationId, uint64 ownerRevision, uint64 executedAt, address oldAddress, address newAddress, uint8 authorityClass, (uint64 count, uint64 ownerRevision, bytes32 commitment) guardians, bytes32 previousTransitionRecordHash, bytes32 previousCommitment, bytes32 commitment))",
  "function identityRecoveryReceipts(bytes32 record) view returns (bytes32, bytes32, bytes32)",
  "function ownerStateSnapshotV2() view returns ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip))",
  "function recoveryEvidenceBinding() view returns (address, bytes32)",
  "function recoveryExecutorBinding() view returns (address, bytes32)",
  "function recoverySelectionBasisV2(bytes32 manifestHash) view returns ((bytes32 manifestHash, bytes32 artistId, bytes32 ownerCodeHash, (uint64 count, uint64 ownerRevision, bytes32 commitment) history, bytes32 sourceCommitment))",
  "function recoverySelectionPreparationBinding() view returns (address, bytes32)",
  "function replayCell(bytes32 key) view returns ((bytes32 commitment, uint64 touchedRevision, uint8 kind, uint8 status))",
  "error InvalidRecoveryAppealEvidence(bytes32 documentHash)",
  "error InvalidRecoveryManifest(bytes32 manifestHash)",
  "event RecoveryAppealEvidencePublished(uint16 schemaVersion, bytes32 indexed documentHash, bytes32 indexed resolutionManifestHash, bytes32 ownerCodeHash)",
  "event RecoveryResolutionManifestPublished(uint16 schemaVersion, bytes32 indexed manifestHash, bytes32 indexed artistId, bytes32 indexed causeHash, uint64 ownerRevision, bytes32 ownerCodeHash)",
  "function appealEvidenceV2(bytes32 hash) view returns ((bytes32 resolutionManifestHash, bytes32 hostileFindingsHash, (bytes32 guardianRecordHash, address[] parties)[] findings), bytes32)",
  "function archive() view returns (address)",
  "function coordinator() view returns (address)",
  "function owner() view returns (address)",
  "function resolutionManifest(bytes32 hash) view returns ((bytes32 artistId, uint64 ownerRevision, bytes32 causeHash, bytes32 resolutionHash, bytes32 executedHead, uint8 basis, bytes32 requestCommitment, bytes32 resolutionEvidenceHash, (bytes32 transitionRecordHash, bytes32 vestingCommitment)[] contestedVestings, bytes32[] supersededRecordHashes), bytes32)",
  "event RecoverySelectionPrepared(bytes32 indexed key, bytes32 indexed manifestHash, uint64 count)",
  "event RecoverySelectionProgress(bytes32 indexed key, uint64 processed, bool complete)",
  "function requireSelectionV2(bytes32 manifestHash) view returns ((bytes32 sourceKey, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bytes32 commitment) result)",
  "function retainedMemberV2(bytes32 key, address actor) view returns (bool)",
  "function selectionV2(bytes32 key) view returns ((bytes32 manifestHash, bytes32 artistId, bytes32 ownerCodeHash, (uint64 count, uint64 ownerRevision, bytes32 commitment) history, bytes32 sourceCommitment), (uint64 processed, uint64 lastOwnerRevision, bytes32 historyTip, uint64 excludedSeen, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bool complete))",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId, uint64 indexed evidenceVersion, bytes32 indexed contentHash, address pointer, uint256 payloadSize)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns (uint256)",
  "function artistEvidenceBytesV2(bytes32 evidenceId, uint64 evidenceVersion) view returns (bytes evidence)",
  "function artistEvidenceMetadataV2(bytes32 evidenceId, uint64 evidenceVersion) view returns (bytes32 contentHash, address pointer, uint32 payloadSize, uint64 appendedAtBlock)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
  "function currentAction() view returns (bool executing, bytes32 actionId, uint8 actionClass, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionFacts(bytes32 id) view returns ((uint8 status, uint8 actionClass, bytes32 callHash, uint64 notBefore, uint64 expiresAfter) facts)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function governanceRootState() view returns (address governanceRoot_, bytes32 codeHash, uint64 revision)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function roleRegistry() view returns (address)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "function roleMutationState(bytes32 role) view returns (bytes32 chainHash, uint64 revision)",
  "event ArtistDormancyCancellationContext(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed recordHash, (uint256 chainId, address registry, address identityOwner, address recorder, uint8 recorderAuthorityClass) context, (bytes32 recordHash, bytes32 noticeHash, address actor, uint8 authorityClass, uint64 observedAt, uint64 appointmentBlock, (address authority, uint8 authorityClass, uint32 capabilities, bytes32 designation, bytes32 directive, bytes32 guardian, bytes32 stewardGrantRecordHash, uint64 postSeconds, uint64 standingTail) plan, bytes32 evidenceHash, bytes32 actionId, bytes32 witnessHash, uint64 delegationEpoch) terminal, uint256 activityCount)"
]);
const coder = AbiCoder.defaultAbiCoder();
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
async function runtime(p: Reader, v: ArtistRecoveryCodePin, tag: number): Promise<void> {
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
function pin(v: ArtistRecoveryCodePin): ArtistRecoveryCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}

export interface ArtistRecoveryCodePin { readonly address: Address; readonly codeHash: Hex }
export interface ArtistRecoveryAdjudicationDeployment {
  readonly artist: CurrentArtistDeployment;
  readonly evidence: ArtistRecoveryCodePin;
  readonly selection: ArtistRecoveryCodePin;
  readonly governance: ArtistRecoveryCodePin;
}
type Reader = Pick<import("ethers").Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<import("ethers").Provider, "getTransaction" | "getTransactionReceipt">;
interface Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
function deployment(v: ArtistRecoveryAdjudicationDeployment): ArtistRecoveryAdjudicationDeployment {
  keys(v, ["artist", "evidence", "selection", "governance"]);
  const a = v.artist;
  keys(a, ["chainId", "registry", "coordinator", "components"], ["reads"]);
  if (!Array.isArray(a.components) || a.components.length !== 16 || Reflect.ownKeys(a.components).length !== 17) throw Error("Expected exactly16 component pins");
  const components = a.components.map(pin), registry = pin(a.registry);
  if (!same(components[7]!.address, registry.address) || !same(components[7]!.codeHash, registry.codeHash)
    || new Set(components.map(x => x.address)).size !== 16) throw Error("Distinct suite pins required");
  return freeze({ artist: { chainId: uint(a.chainId), registry, coordinator: pin(a.coordinator), components,
    ...(a.reads ? { reads: pin(a.reads) } : {}) }, evidence: pin(v.evidence), selection: pin(v.selection), governance: pin(v.governance) });
}
function coordinates(d: ArtistRecoveryAdjudicationDeployment): recovery.ArtistRecoveryAdjudicationCoordinates {
  return { chainId: d.artist.chainId, registry: d.artist.registry.address, coordinator: d.artist.coordinator.address,
    owner: d.artist.components[2]!.address, ownerCodeHash: d.artist.components[2]!.codeHash,
    archive: d.artist.components[8]!.address, core: d.artist.components[9]!.address,
    mintManager: d.artist.components[10]!.address, evidencePublisher: d.evidence.address, selectionPreparation: d.selection.address };
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


async function context(p: Reader, d: ArtistRecoveryAdjudicationDeployment, tag: number, current: boolean) {
  const h = await artistContext(p, d.artist, tag, current), c = coordinates(d);
  await Promise.all([d.evidence, d.selection, d.governance].map(v => runtime(p, v, tag)));
  for (const [method, expected] of [["recoveryEvidenceBinding", d.evidence], ["recoverySelectionPreparationBinding", d.selection], ["recoveryExecutorBinding", d.governance]] as const) {
    equal(await read(p, c.owner, method, [], tag), [expected.address, expected.codeHash], "Identity helper binding differs");
  }
  for (const helper of [c.evidencePublisher, c.selectionPreparation]) {
    for (const [name, value] of [["owner", c.owner], ["artistRegistry", c.registry], ["deploymentChainId", c.chainId]] as const) {
      equal((await read(p, helper, name, [], tag))[0], value, "Helper reciprocal binding differs");
    }
  }
  for (const [name, value] of [["coordinator", c.coordinator], ["archive", c.archive], ["core", c.core], ["mintManager", c.mintManager]] as const) {
    equal((await read(p, c.evidencePublisher, name, [], tag))[0], value, "Evidence publisher binding differs");
  }
  equal((await read(p, c.owner, "artistWindowAuthority", [], tag))[0], d.governance.address);
  equal((await read(p, d.governance.address, "roleRegistry", [], tag))[0], d.artist.components[11]!.address);
  return h;
}
function encoded(types: readonly string[], values: readonly unknown[]): Hex { return coder.encode(types, values) as Hex; }
function hashEncoded(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(encoded(types, values)) as Hex; }
function zeros(type: string): any {
  const walk = (p: ParamType): any => p.baseType === "tuple" ? Object.fromEntries(p.components!.map(x => [x.name, walk(x)]))
    : p.baseType === "array" ? Array.from({ length: Math.max(p.arrayLength!, 0) }, () => walk(p.arrayChildren!))
    : p.type === "address" ? ZeroAddress : p.type === "bool" ? false : p.type === "bytes" ? "0x" : p.type === "string" ? "" : p.type.startsWith("bytes") ? "0x" + "00".repeat(Number(p.type.slice(5))) : 0n;
  return walk(ParamType.from(type));
}
function bounded(value: bigint, max: number, label: string): number {
  uint(value); if (value > BigInt(max)) throw Error(label + " exceeds client bound"); return Number(value);
}
export interface ArtistRecoverySelectionObservation {
  readonly key: Hex;
  readonly basis: recovery.ArtistRecoverySelectionBasis;
  readonly progress: recovery.ArtistRecoverySelectionProgress;
  readonly result: recovery.ArtistRecoverySelectionResult | null;
}
export interface ArtistRecoveryPayloadRow { readonly pointer: Address; readonly payloadType: Hex; readonly payloadHash: Hex }
export interface ArtistRecoveryPayloadCatalog { readonly host: Address; readonly rows: readonly ArtistRecoveryPayloadRow[] }
export interface ArtistRecoveryAdjudicationFacts {
  readonly manifest: recovery.ArtistRecoveryResolutionManifest;
  readonly selection: ArtistRecoverySelectionObservation;
  readonly context: recovery.ArtistRecoveryContext;
  readonly role: Hex;
  readonly evidence: recovery.ArtistRecoveryEvidence;
  readonly notice: recovery.ArtistRecoveryNoticeEvidence | null;
  readonly association: recovery.ArtistRecoveryActionAssociation;
  readonly veto: { readonly vetoer: Address; readonly reasonHash: Hex; readonly vetoedAt: bigint };
  readonly executed: Hex;
  readonly state: recovery.ArtistRecoveryEvidenceState;
  readonly acceptanceDigest: Hex;
  readonly acceptanceConsumed: boolean;
  readonly acceptanceHint: bigint;
  readonly digestDenied: boolean;
  readonly nativeCount: bigint;
  readonly payloads: readonly ArtistRecoveryPayloadCatalog[];
}
export interface ArtistRecoveryAdjudicationCapture extends Block {
  readonly deployment: ArtistRecoveryAdjudicationDeployment;
  readonly prepared: recovery.ArtistRecoveryAdjudicationCall;
  readonly configurationHash: Hex;
  readonly ownerSnapshot: ArtistHydrationSnapshot;
  readonly retained: readonly unknown[] | null;
  readonly selection: ArtistRecoverySelectionObservation | null;
  readonly recovery: ArtistRecoveryAdjudicationFacts | null;
  readonly result: readonly unknown[];
  readonly captureHash: Hex;
  readonly simulationRequired: true;
}
const callAbi = new Interface([
  ...recovery.CURRENT_ARTIST_RECOVERY_EVIDENCE_ABI,
  ...recovery.CURRENT_ARTIST_RECOVERY_SELECTION_ABI,
  ...recovery.CURRENT_ARTIST_RECOVERY_ADJUDICATION_ABI,
]);
async function originalCall(p: Reader, call: UnsignedCall, caller: Address, tag: number, intf = callAbi): Promise<readonly unknown[]> {
  const raw = bytes(await p.call({ ...call, from: caller, blockTag: tag }), 524288);
  const f = intf.getFunction(call.data.slice(0, 10))!;
  const decoded = intf.decodeFunctionResult(f, raw);
  equal(intf.encodeFunctionResult(f, decoded).toLowerCase(), raw, "Noncanonical original call result");
  return f.outputs.map((v, i) => plain(v, decoded[i]));
}
async function retained(p: Reader, d: ArtistRecoveryAdjudicationDeployment, kind: "resolutionManifest" | "appealEvidenceV2", identity: Hex, tag: number, optional = false): Promise<any[] | null> {
  let result;
  try { result = await read(p, d.evidence.address, kind, [identity], tag, undefined, 65536); }
  catch (error) {
    const e = error as { code?: string; data?: string };
    const name = kind === "resolutionManifest" ? "InvalidRecoveryManifest" : "InvalidRecoveryAppealEvidence";
    if (optional && e.code === "CALL_EXCEPTION" && typeof e.data === "string"
      && same(e.data, abi.encodeErrorResult(name, [identity]))) return null;
    throw error;
  }
  const c = coordinates(d);
  equal(result[1], c.ownerCodeHash, "Retained evidence owner pin differs");
  const computed = kind === "resolutionManifest" ? recovery.artistRecoveryResolutionManifestHash(c, result[0]) : recovery.artistRecoveryAppealHash(c, result[0]);
  equal(computed, identity, "Retained evidence hash differs");
  return result;
}
async function selected(p: Reader, d: ArtistRecoveryAdjudicationDeployment, tag: number, manifestHash?: Hex, key?: Hex, live = true): Promise<ArtistRecoverySelectionObservation> {
  const c = coordinates(d);
  let basis: recovery.ArtistRecoverySelectionBasis;
  if (manifestHash && live) {
    basis = recovery.normalizeArtistRecoverySelectionBasis((await read(p, c.owner, "recoverySelectionBasisV2", [manifestHash], tag))[0]);
    key = recovery.artistRecoverySelectionKey(c, basis);
    const [head] = await read(p, c.owner, "guardianHistoryState", [basis.artistId, 0n, ZeroAddress, ZeroHash], tag);
    equal(head, basis.history, "Complete guardian history head differs");
  }
  const [savedBasis, progress] = await read(p, c.selectionPreparation, "selectionV2", [key!], tag);
  if (manifestHash && live && savedBasis.manifestHash !== ZeroHash) equal(savedBasis, basis!, "Selection basis changed");
  if (!manifestHash || !live) basis = recovery.normalizeArtistRecoverySelectionBasis(savedBasis);
  const b = basis!;
  if (b.manifestHash !== ZeroHash) {
    equal(recovery.artistRecoverySelectionKey(c, b), key);
    if (!same(b.ownerCodeHash, c.ownerCodeHash) || progress.processed > b.history.count) throw Error("Selection pin/progress differs");
  }
  let result = null;
  if (progress.complete) {
    result = recovery.artistRecoverySelectionResult(c, b, progress);
    if (live) equal((await read(p, c.selectionPreparation, "requireSelectionV2", [b.manifestHash], tag))[0], result);
  }
  return freeze({ key: hash(key, true), basis: b, progress: recovery.normalizeArtistRecoverySelectionProgress(progress), result });
}
async function notice(p: Reader, c: recovery.ArtistRecoveryAdjudicationCoordinates, causeHash: Hex, tag: number): Promise<recovery.ArtistRecoveryNoticeEvidence | null> {
  const [cause] = await read(p, c.owner, "identityContestCause", [causeHash], tag);
  equal(cause.causeHash, causeHash);
  if (cause.facts.priorStatus !== 2n) return null;
  const [noticeHash, phase, terminalHash] = await read(p, c.owner, "dormancyResolutionState", [cause.facts.artistId, causeHash], tag);
  const [n, observedPhase, terminal] = await read(p, c.owner, "dormancyRecord", [noticeHash], tag);
  if (!same(n.recordHash, hash(noticeHash)) || !same(n.terms.artistId, cause.facts.artistId)
    || phase !== observedPhase || ![1n, 2n].includes(phase) || !same(terminal.recordHash, terminalHash)) throw Error("Current notice provenance differs");
  if (phase === 1n) equal(terminal, zeros(recovery.ARTIST_RECOVERY_TERMINAL_TUPLE));
  return recovery.normalizeArtistRecoveryNoticeEvidence({ cause, notice: n, phase, terminal });
}
function replayKey(c: recovery.ArtistRecoveryAdjudicationCoordinates, surface: string, scope: Hex): Hex {
  return hashEncoded(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), c.chainId, c.registry, c.coordinator, c.archive, c.owner, domains[2], id(surface), scope]);
}
async function appealAuthority(p: Reader, d: ArtistRecoveryAdjudicationDeployment, tag: number): Promise<recovery.ArtistRecoveryAppealAuthority> {
  const executor = d.governance.address, roles = d.artist.components[11]!.address;
  equal((await read(p, roles, "owner", [], tag))[0], executor);
  const [root, rootCodeHash, rootRevision] = await read(p, executor, "governanceRootState", [], tag);
  await runtime(p, { address: address(root), codeHash: hash(rootCodeHash) }, tag);
  equal((await read(p, executor, "owner", [], tag))[0], root);
  if (!rootRevision || (await read(p, roles, "hasRole", [recovery.ARTIST_RECOVERY_APPEAL_ROLE, root], tag))[0] !== true) throw Error("Canonical APPEAL root unavailable");
  const [roleMutationHash, roleRevision] = await read(p, roles, "roleMutationState", [recovery.ARTIST_RECOVERY_APPEAL_ROLE], tag);
  hash(roleMutationHash); if (!roleRevision) throw Error("APPEAL role has no revision");
  return { executor, roles, root, rootCodeHash, rootRevision, roleMutationHash, roleRevision };
}
async function catalogs(p: Reader, c: recovery.ArtistRecoveryAdjudicationCoordinates, tag: number): Promise<ArtistRecoveryPayloadCatalog[]> {
  const result = [];
  for (const host of [c.owner, c.archive]) {
    const count = bounded((await read(p, host, "storedPayloadCount", [], tag))[0], 1024, "Payload catalog"), rows = [];
    const seen = new Set<string>();
    for (let i = 0; i < count; i++) {
      const [pointer, payloadType, payloadHash] = await read(p, host, "storedPayloadAt", [BigInt(i)], tag);
      const code = bytes(await p.getCode(address(pointer), tag), 24576);
      if (!code.startsWith("0x00") || !same(keccak256(`0x${code.slice(4)}`), payloadHash)) throw Error("Payload carrier differs");
      const key = `${payloadType}:${payloadHash}`;
      if (seen.has(key)) throw Error("Duplicate payload catalog key"); seen.add(key);
      rows.push({ pointer: address(pointer), payloadType: hash(payloadType), payloadHash: hash(payloadHash) });
    }
    result.push({ host, rows });
  }
  const archive = new Set(result[1]!.rows.map(r => `${r.payloadType}:${r.payloadHash}`));
  if (result[0]!.rows.some(r => !archive.has(`${r.payloadType}:${r.payloadHash}`))) throw Error("Payload sync incomplete");
  return result;
}
async function recoveryFacts(p: Reader, d: ArtistRecoveryAdjudicationDeployment, input: Extract<recovery.ArtistRecoveryAdjudicationInput, { request: recovery.ArtistRecoveryRequest }>, tag: number): Promise<ArtistRecoveryAdjudicationFacts> {
  const c = coordinates(d), request = input.request, acceptance = input.acceptance;
  const manifest = (await retained(p, d, "resolutionManifest", input.manifestHash, tag))![0];
  equal(manifest.requestCommitment, recovery.artistRecoveryRequestCommitment(request));
  equal(manifest.artistId, request.artistId);
  const selection = await selected(p, d, tag, input.manifestHash);
  if (!selection.result) throw Error("Complete original selection is required");
  const ctx = recovery.normalizeArtistRecoveryContext((await read(p, c.registry, "identityRecoveryContextV2", [request, acceptance, input.manifestHash], tag))[0]);
  equal(ctx.scopeHash, recovery.artistRecoveryScopeHash(c, request.artistId));
  equal(ctx.newValueHash, recovery.artistRecoveryIntentHash(ctx, request, acceptance));
  const [role] = await read(p, c.owner, "guardianRecoveryAuthorityRoleV2", [request, acceptance, input.manifestHash], tag);
  if (![recovery.ARTIST_RECOVERY_ARBITER_ROLE, recovery.ARTIST_RECOVERY_APPEAL_ROLE].includes(role)) throw Error("Unknown original recovery role");
  let appeal = zeros(recovery.ARTIST_RECOVERY_APPEAL_DOCUMENT_TUPLE), authority = zeros(recovery.ARTIST_RECOVERY_APPEAL_AUTHORITY_TUPLE);
  if (role === recovery.ARTIST_RECOVERY_APPEAL_ROLE) {
    appeal = (await retained(p, d, "appealEvidenceV2", request.evidenceHash, tag))![0];
    equal(appeal.resolutionManifestHash, input.manifestHash);
    authority = await appealAuthority(p, d, tag);
  }
  let directive = zeros(recovery.ARTIST_RECOVERY_DIRECTIVE_RECORD_TUPLE);
  const [directiveHash] = await read(p, c.owner, "operativeEstateDirective", [request.artistId], tag);
  if (directiveHash !== ZeroHash) {
    [directive] = await read(p, c.owner, "estateDirectiveRecord", [directiveHash], tag);
    equal(directive.recordHash, directiveHash); equal(directive.terms.artistId, request.artistId);
  }
  const [association, veto, executed] = await read(p, c.owner, "identityRecoveryActionState", [request.artistId, "actionId" in input ? input.actionId : ZeroHash], tag);
  const [state] = await read(p, c.owner, "identityRecoveryEvidenceState", [request.artistId, association.action.actionId], tag);
  const [consumed, hint] = await read(p, c.owner, "rotationAcceptanceNonceState", [request.artistId, request.newAddress, acceptance.nonce], tag);
  const acceptanceDigest = recovery.artistRecoveryAcceptancePayload(c.chainId, c.registry, request, ctx.incumbent, acceptance).digest;
  const [denied] = await read(p, c.owner, "replayCell", [replayKey(c, "identity_authority.replay.digest_revocation", hashEncoded(["bytes32", "bytes32"], [request.artistId, acceptanceDigest]))], tag);
  return freeze({ manifest, selection, context: ctx, role, evidence: { manifestHash: input.manifestHash, manifest, appeal, appealAuthority: authority, directive },
    notice: await notice(p, c, request.expectedCauseHash, tag), association, veto, executed, state,
    acceptanceDigest, acceptanceConsumed: consumed, acceptanceHint: hint, digestDenied: denied.status !== 0n,
    nativeCount: uint((await read(p, c.owner, "artistNativeReceiptCount", [], tag))[0]), payloads: await catalogs(p, c, tag) });
}
/** Pinned original reads and exact caller simulation. Private ancestry admission remains the original contracts' responsibility. */
export async function captureArtistRecoveryAdjudication(p: Reader, rawDeployment: ArtistRecoveryAdjudicationDeployment, rawCall: recovery.ArtistRecoveryAdjudicationCall, options: { readonly blockTag: number }): Promise<ArtistRecoveryAdjudicationCapture> {
  const d = deployment(rawDeployment), prepared = recovery.normalizeArtistRecoveryAdjudicationCall(rawCall);
  equal(prepared.coordinates, coordinates(d)); keys(options, ["blockTag"]); const tag = number(options.blockTag), input = prepared.input;
  if (input.kind === "recoverArtistIdentityV2") throw Error("Recovery executes through the prepared Governance operation");
  if (input.kind === "continueSelectionV2" && input.maximumRecords > 64n) throw Error("Selection chunk exceeds64 records");
  const h = await context(p, d, tag, input.kind === "registerIdentityRecoveryActionV2");
  const [ownerSnapshot] = await read(p, prepared.coordinates.owner, "ownerStateSnapshotV2", [], tag);
  let saved = null, selection = null, facts = null;
  if (input.kind === "publishResolutionManifest" || input.kind === "publishAppealV2") {
    saved = await retained(p, d, input.kind === "publishResolutionManifest" ? "resolutionManifest" : "appealEvidenceV2", prepared.expectedReturnHash!, tag, true);
  } else if (["beginSelectionV2", "requireSelectionV2"].includes(input.kind)) {
    const manifestHash = (input as { manifestHash: Hex }).manifestHash;
    saved = await retained(p, d, "resolutionManifest", manifestHash, tag);
    selection = await selected(p, d, tag, manifestHash);
  } else if (input.kind === "continueSelectionV2" || input.kind === "selectionV2" || input.kind === "retainedMemberV2") {
    selection = await selected(p, d, tag, undefined, input.key, false);
    if (input.kind === "continueSelectionV2") {
      saved = await retained(p, d, "resolutionManifest", selection.basis.manifestHash, tag);
      selection = await selected(p, d, tag, selection.basis.manifestHash);
    }
  } else if (input.kind === "identityRecoveryContextV2" || input.kind === "registerIdentityRecoveryActionV2") {
    facts = await recoveryFacts(p, d, input, tag);
  }
  const result = await originalCall(p, prepared.call, prepared.caller, tag);
  if (prepared.expectedReturnHash) equal(result[0], prepared.expectedReturnHash);
  if (input.kind === "beginSelectionV2") equal(result[0], selection!.key);
  if (input.kind === "identityRecoveryContextV2") equal(result[0], facts!.context);
  if (input.kind === "continueSelectionV2") {
    const before = selection!, after = recovery.normalizeArtistRecoverySelectionProgress(result[0] as recovery.ArtistRecoverySelectionProgress);
    const expected = before.progress.complete ? before.progress.processed : [before.progress.processed + input.maximumRecords, before.basis.history.count].reduce((a,b) => a < b ? a : b);
    if (after.processed !== expected || after.complete !== (expected === before.basis.history.count)) throw Error("Selection progress return differs");
    if (before.progress.complete) equal(after, before.progress);
  }
  await unchanged(p, h);
  const body = { ...h, deployment: d, prepared, ownerSnapshot, retained: saved, selection, recovery: facts, result, simulationRequired: true as const };
  return freeze({ ...body, captureHash: digest(body) });
}
function savedCapture(raw: ArtistRecoveryAdjudicationCapture): ArtistRecoveryAdjudicationCapture {
  const copy = structuredClone(raw), { captureHash, ...body } = copy;
  keys(copy, ["blockNumber", "blockHash", "timestamp", "configurationHash", "deployment", "prepared", "ownerSnapshot", "retained", "selection", "recovery", "result", "simulationRequired", "captureHash"]);
  if (copy.simulationRequired !== true || !same(hash(captureHash), digest(body))) throw Error("Capture changed");
  deployment(copy.deployment); recovery.normalizeArtistRecoveryAdjudicationCall(copy.prepared);
  number(copy.blockNumber); hash(copy.blockHash); uint(copy.timestamp, 64);
  return freeze(copy);
}
async function historical(p: Reader, c: ArtistRecoveryAdjudicationCapture): Promise<void> {
  equal(await captureArtistRecoveryAdjudication(p, c.deployment, c.prepared, { blockTag: c.blockNumber }), c, "Historical capture changed");
}
export async function simulateArtistRecoveryAdjudication(p: Reader, raw: ArtistRecoveryAdjudicationCapture, options: { readonly blockTag: number }): Promise<ArtistRecoveryAdjudicationCapture> {
  const c = savedCapture(raw); keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await historical(p, c);
  return captureArtistRecoveryAdjudication(p, c.deployment, c.prepared, { blockTag: tag });
}
export interface ArtistRecoveryAdjudicationGovernance {
  readonly capture: ArtistRecoveryAdjudicationCapture;
  readonly proposer: Address;
  readonly batch: recovery.ArtistRecoveryGovernanceBatch;
}
export interface ArtistRecoveryAdjudicationOperation {
  readonly prepared: ArtistRecoveryAdjudicationGovernance;
  readonly stage: "publish" | "schedule" | "register" | "execute";
  readonly caller: Address;
  readonly call: UnsignedCall;
}
export function prepareArtistRecoveryAdjudicationGovernance(raw: ArtistRecoveryAdjudicationCapture, proposer: Address, nonce: bigint, window: recovery.ArtistRecoveryGovernanceWindow): ArtistRecoveryAdjudicationGovernance {
  const c = savedCapture(raw), input = c.prepared.input;
  if (input.kind !== "identityRecoveryContextV2" || !c.recovery) throw Error("Governance requires the complete context capture");
  const batch = recovery.artistRecoveryGovernanceBatch(coordinates(c.deployment), input.request, input.acceptance, input.manifestHash,
    c.recovery.context, c.deployment.governance.address, nonce, window);
  return freeze({ capture: c, proposer: address(proposer), batch });
}
export function prepareArtistRecoveryAdjudicationOperation(raw: ArtistRecoveryAdjudicationGovernance, stage: ArtistRecoveryAdjudicationOperation["stage"], caller: Address): ArtistRecoveryAdjudicationOperation {
  keys(raw, ["capture", "proposer", "batch"]);
  const prepared = prepareArtistRecoveryAdjudicationGovernance(raw.capture, raw.proposer, raw.batch.nonce, raw.batch.window);
  equal(prepared, raw); const actor = address(caller), b = prepared.batch;
  if (!["publish", "schedule", "register", "execute"].includes(stage)) throw Error("Unknown governance stage");
  if (stage === "schedule" && actor !== prepared.proposer) throw Error("Schedule caller differs from proposer");
  const call = stage === "publish" ? b.publicationCall : stage === "schedule" ? b.scheduleCall : stage === "execute" ? b.executionCall
    : recovery.prepareArtistRecoveryAdjudicationCall(b.coordinates, actor, { kind: "registerIdentityRecoveryActionV2", actionId: b.actionId,
      calls: [b.governanceCall], request: b.request, acceptance: b.acceptance, manifestHash: b.manifestHash }).call;
  return freeze({ prepared, stage, caller: actor, call });
}
function operation(raw: ArtistRecoveryAdjudicationOperation): ArtistRecoveryAdjudicationOperation {
  keys(raw, ["prepared", "stage", "caller", "call"]);
  const value = prepareArtistRecoveryAdjudicationOperation(raw.prepared, raw.stage, raw.caller); equal(value, raw); return value;
}
async function governance(p: Reader, o: ArtistRecoveryAdjudicationOperation, tag: number) {
  const d = o.prepared.capture.deployment, g = d.governance.address;
  const state = await read(p, g, "systemManifestBootstrapState", [], tag);
  if (state[0] !== true || state[1] !== true) throw Error("Only sealed ordinary governance is supported");
  const policy = await read(p, g, "governanceActionPolicyState", [], tag);
  hash(policy[0]); hash(policy[1]); if (!policy[2]) throw Error("Governance catalog missing");
  const [delay] = await read(p, g, "minimumDelay", [2n], tag);
  if (delay < 259200n) throw Error("Original recovery delay below72 hours");
  return { candidateProfileHash: policy[0] as Hex, catalogHash: policy[1] as Hex, minimumDelay: delay as bigint };
}
async function publication(p: Reader, b: recovery.ArtistRecoveryGovernanceBatch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.executor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = encoded(["bytes[]"], [[b.targetCall.data]]);
  equal(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`);
  return pointer;
}
async function action(p: Reader, o: ArtistRecoveryAdjudicationOperation, tag: number) {
  const b = o.prepared.batch, [a] = await read(p, b.executor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: 2n, target: b.targetCall.to, value: 0n, selector: b.governanceCall.selector, callHash: b.callsHash,
    scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash, notBefore: b.window.notBefore,
    expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer, reasonHash: b.window.reasonHash,
    reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) equal(a[key], value, `Scheduled ${key} differs`);
  equal((await read(p, b.executor, "scheduledCallData", [b.actionId], tag))[0], [b.targetCall.data]);
  const pointer = await publication(p, b, tag);
  if (!pointer) throw Error("Scheduled call publication missing");
  equal((await read(p, b.executor, "scheduledCallDataPointer", [b.actionId], tag))[0], pointer);
  return a;
}
async function proposerRole(p: Reader, o: ArtistRecoveryAdjudicationOperation, tag: number): Promise<void> {
  const d = o.prepared.capture.deployment, f = o.prepared.capture.recovery!;
  if (f.role === recovery.ARTIST_RECOVERY_APPEAL_ROLE) {
    equal((await appealAuthority(p, d, tag)).root, o.prepared.proposer, "APPEAL requires actual root proposer");
  } else if ((await read(p, d.artist.components[11]!.address, "hasRole", [f.role, o.prepared.proposer], tag))[0] !== true) {
    throw Error("Proposer lacks original recovery role");
  }
  const [commitment, revision] = await read(p, d.artist.components[11]!.address, "roleMutationState", [f.role], tag);
  hash(commitment); if (!revision) throw Error("Role mutation revision missing");
}
export interface ArtistRecoveryAdjudicationSimulation extends Block {
  readonly operation: ArtistRecoveryAdjudicationOperation;
  readonly facts: ArtistRecoveryAdjudicationFacts | null;
  readonly result: readonly unknown[];
  readonly catalog: { readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly minimumDelay: bigint };
}
/** The original governance call establishes selected-row, guardian, signature and private ancestry admission. */
export async function simulateArtistRecoveryAdjudicationOperation(p: Reader, raw: ArtistRecoveryAdjudicationOperation, options: { readonly blockTag: number }): Promise<ArtistRecoveryAdjudicationSimulation> {
  const o = operation(raw), c = o.prepared.capture, b = o.prepared.batch;
  keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await historical(p, c);
  const h = await context(p, c.deployment, tag, o.stage === "register" || o.stage === "execute");
  const catalog = await governance(p, o, tag);
  let facts: ArtistRecoveryAdjudicationFacts | null = null;
  if (o.stage !== "publish") {
    facts = await recoveryFacts(p, c.deployment, { kind: "identityRecoveryContextV2", request: b.request, acceptance: b.acceptance, manifestHash: b.manifestHash }, tag);
    equal(facts.context, b.context, "Scheduled recovery context changed; prepare a new action");
    equal(facts.evidence, c.recovery!.evidence, "Scheduled evidence changed");
    await proposerRole(p, o, tag);
  }
  if (o.stage === "schedule") {
    if ((await read(p, b.executor, "isProposer", [o.caller], tag))[0] !== true) throw Error("Caller is not an ordinary proposer");
    equal((await read(p, b.executor, "governanceNonce", [], tag))[0], b.nonce);
    if (!await publication(p, b, tag)) throw Error("Publish original call bytes before scheduling");
    if (h.timestamp > (1n << 64n) - 1n - 31536000n || b.window.notBefore < h.timestamp + catalog.minimumDelay
      || b.window.expiresAfter > h.timestamp + 31536000n) throw Error("Original scheduling window differs");
  }
  if (o.stage === "register" || o.stage === "execute") {
    const a = await action(p, o, tag);
    if (a.status !== 1n) throw Error("Action is not scheduled");
    if (o.stage === "register") {
      recovery.assertArtistRecoveryRegistrationWindow(b.acceptance, b.window, h.timestamp, catalog.minimumDelay);
    } else {
      if (h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter || h.timestamp > b.acceptance.time) throw Error("Execution outside original deadline/window");
      const f = facts!;
      if (f.association.associationHash === ZeroHash || f.veto.vetoer !== ZeroAddress || f.executed !== ZeroHash
        || f.state.manifestHash !== b.manifestHash || f.state.associationHash !== f.association.associationHash
        || f.association.action.actionId !== b.actionId || f.state.preparedFromOwnerRevision !== f.manifest.ownerRevision
        || f.association.ownerRevision !== f.manifest.ownerRevision + 1n) throw Error("Recovery registration is missing/stale/terminal");
      const [snapshot] = await read(p, b.coordinates.owner, "ownerStateSnapshotV2", [], tag);
      if (snapshot.revision !== f.association.ownerRevision) throw Error("Owner changed after registration");
      if (f.acceptanceConsumed || f.digestDenied || (b.executor === b.request.newAddress && b.acceptance.signature === "0x" && b.acceptance.nonce !== f.acceptanceHint)) throw Error("New-side acceptance replay/nonce differs");
    }
  }
  const intf = o.stage === "register" ? callAbi : new Interface(recovery.CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI);
  const result = await originalCall(p, o.call, o.caller, tag, intf);
  if (o.stage === "schedule") equal(result[0], b.actionId);
  if (o.stage === "publish") {
    const pointer = await publication(p, b, tag);
    if (pointer) equal(result[0], pointer);
    else address(result[0]);
  }
  if (o.stage === "register") hash(result[0]);
  await unchanged(p, h);
  return freeze({ ...h, operation: o, facts, result, catalog });
}

export interface ArtistRecoveryEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
interface ReceiptOptions { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }
async function mined(p: ReceiptReader, d: ArtistRecoveryAdjudicationDeployment, caller: Address, call: UnsignedCall, before: number,
  options: ReceiptOptions) {
  const transactionHash = options.transactionHash, execution = options.execution;
  const [r, tx] = await Promise.all([p.getTransactionReceipt(transactionHash), p.getTransaction(transactionHash)]);
  if (!r || !tx || r.status !== 1 || !same(r.hash, transactionHash) || !same(tx.hash, transactionHash)
    || tx.chainId !== d.artist.chainId || tx.value !== (execution === "direct" ? call.value : 0n) || r.blockNumber <= before || tx.blockNumber !== r.blockNumber
    || !same(tx.blockHash, r.blockHash) || !same(tx.to, r.to) || !same(tx.from, r.from)) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 524288);
  if (execution === "direct") {
    if (!same(tx.from, caller) || !same(tx.to, call.to) || !same(data, call.data)) throw Error("Direct call differs");
  } else {
    const decoded = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(tx.to, caller) || !same(safeAbi.encodeFunctionData("execTransaction", decoded), data)
      || !same(decoded[0], call.to) || decoded[1] !== call.value || !same(decoded[2], call.data) || decoded[3] !== 0n) throw Error("Safe requires exact ordinary CALL");
  }
  const tag = number(r.blockNumber), h = await context(p, d, tag, false);
  if (!same(h.blockHash, r.blockHash)) throw Error("Receipt block differs");
  if (!Array.isArray(r.logs) || r.logs.length > 256) throw Error("Receipt exceeds256 logs");
  const logs: Log[] = r.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== tag || !same(l.blockHash, h.blockHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log identity");
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 65536), index: number(l.index) };
  });
  if (logs.some((l, n) => n > 0 && l.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const refs: ArtistRecoveryEventReference[] = [];
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

export interface ArtistRecoveryAdjudicationReceipt extends Block {
  readonly capture: ArtistRecoveryAdjudicationCapture;
  readonly transactionHash: Hex;
  readonly events: readonly ArtistRecoveryEventReference[];
  readonly retained: readonly unknown[] | null;
  readonly selection: ArtistRecoverySelectionObservation | null;
  readonly attribution: "exact original event or prior-block reuse proof";
}
/** Publisher and selection writes only. Selection progress reconciliation requires the observed exact step. */
export async function inspectArtistRecoveryAdjudicationReceipt(p: ReceiptReader, raw: ArtistRecoveryAdjudicationCapture, supplied: ReceiptOptions): Promise<ArtistRecoveryAdjudicationReceipt> {
  const c = savedCapture(raw), options = receiptOptions(supplied), input = c.prepared.input, d = c.deployment;
  if (!["publishResolutionManifest", "publishAppealV2", "beginSelectionV2", "continueSelectionV2"].includes(input.kind)) throw Error("This receipt helper covers evidence and selection writes");
  await historical(p, c);
  const m = await mined(p, d, c.prepared.caller, c.prepared.call, c.blockNumber, options), { tag, h } = m;
  let saved = null, selection = null;
  const prior = await context(p, d, tag - 1, false);
  if (input.kind === "publishResolutionManifest" || input.kind === "publishAppealV2") {
    const getter = input.kind === "publishResolutionManifest" ? "resolutionManifest" : "appealEvidenceV2";
    const identity = c.prepared.expectedReturnHash!;
    saved = await retained(p, d, getter, identity, tag);
    equal(saved![0], input.kind === "publishResolutionManifest" ? input.manifest : input.document);
    const before = await retained(p, d, getter, identity, tag - 1, true);
    const event = input.kind === "publishResolutionManifest" ? "RecoveryResolutionManifestPublished" : "RecoveryAppealEvidencePublished";
    const logs = m.found(d.evidence.address, event);
    if (before) {
      if (logs.length) throw Error("Retained evidence retry emitted a new publication");
      equal(before, saved);
    } else if (input.kind === "publishResolutionManifest") {
      m.one(d.evidence.address, event, [1n, identity, input.manifest.artistId, input.manifest.causeHash, input.manifest.ownerRevision, coordinates(d).ownerCodeHash]);
    } else {
      m.one(d.evidence.address, event, [2n, identity, input.document.resolutionManifestHash, coordinates(d).ownerCodeHash]);
    }
  } else if (input.kind === "beginSelectionV2") {
    const old = await selected(p, d, tag - 1, input.manifestHash);
    selection = await selected(p, d, tag, input.manifestHash);
    equal(selection.key, old.key); equal(selection.basis, old.basis);
    const [priorSaved] = await read(p, d.selection.address, "selectionV2", [old.key], tag - 1);
    const logs = m.found(d.selection.address, "RecoverySelectionPrepared");
    if (priorSaved.manifestHash !== ZeroHash) {
      if (logs.length) throw Error("Selection retry unexpectedly emitted begin");
      equal(selection.progress, old.progress);
    } else {
      m.one(d.selection.address, "RecoverySelectionPrepared", [old.key, input.manifestHash, old.basis.history.count]);
      equal(selection.progress, zeros(recovery.ARTIST_RECOVERY_SELECTION_PROGRESS_TUPLE), "Later same-block selection progress is outside this receipt profile");
    }
  } else if (input.kind === "continueSelectionV2") {
    const old = await selected(p, d, tag - 1, undefined, input.key, false);
    // Complete retries still call the original live basis/requireStored checks.
    const prediction = await originalCall(p, c.prepared.call, c.prepared.caller, tag - 1);
    selection = await selected(p, d, tag, undefined, input.key, false);
    equal(selection.basis, old.basis); equal(selection.progress, prediction[0], "Observed progress differs from the exact prior-block step");
    if (old.progress.complete) {
      if (m.found(d.selection.address, "RecoverySelectionProgress").length) throw Error("Complete retry unexpectedly emitted progress");
    } else {
      m.one(d.selection.address, "RecoverySelectionProgress", [input.key, selection.progress.processed, selection.progress.complete]);
    }
  }
  await unchanged(p, prior);
  return freeze({ ...h, capture: c, transactionHash: m.transactionHash, events: await m.finish(), retained: saved, selection,
    attribution: "exact original event or prior-block reuse proof" });
}
export interface ArtistRecoveryAdjudicationGovernanceReceipt extends Block {
  readonly operation: ArtistRecoveryAdjudicationOperation;
  readonly transactionHash: Hex;
  readonly events: readonly ArtistRecoveryEventReference[];
  readonly association: recovery.ArtistRecoveryActionAssociation | null;
  readonly record: recovery.ArtistRecoveryRecord | null;
  readonly evidenceId: Hex | null;
  readonly archiveBytes: Hex | null;
  readonly nativeRecords: readonly { readonly operation: bigint; readonly artistId: Hex; readonly collectionId: bigint; readonly recordHash: Hex }[];
  readonly attribution: "immutable operation evidence; block-end observations may include later operations";
}
type Mined = Awaited<ReturnType<typeof mined>>;
async function archiveEvidence(p: Reader, m: Mined, o: ArtistRecoveryAdjudicationOperation, op: 35n | 65534n, actor: Address, commitment: Hex, before: ArtistHydrationSnapshot) {
  const c = coordinates(o.prepared.capture.deployment), evidenceId = recovery.artistRecoveryOperationEvidenceId(c, op, actor, commitment);
  const metadata = await read(p, c.archive, "artistEvidenceMetadataV2", [evidenceId, 1n], m.tag);
  const [raw] = await read(p, c.archive, "artistEvidenceBytesV2", [evidenceId, 1n], m.tag, undefined, 32768);
  const archiveBytes = bytes(raw, 24575);
  if (metadata[3] !== BigInt(m.tag) || metadata[2] !== BigInt((archiveBytes.length - 2) / 2) || metadata[0] !== keccak256(archiveBytes)) throw Error("Archive metadata differs");
  const pointer = address(metadata[1]);
  equal(bytes(await p.getCode(pointer, m.tag), 24576), `0x00${archiveBytes.slice(2)}`);
  const index = m.one(c.archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], pointer, metadata[2]]);
  const e = recovery.decodeArtistRecoveryOperationEvidence(archiveBytes);
  equal([e.schemaVersion, e.configurationHash, e.operation, e.actor, e.primaryRecordHash],
    [1n, o.prepared.capture.configurationHash, op, actor, op === 35n ? commitment : ZeroHash]);
  for (let i = 0; i < 7; i++) {
    if (i !== 2) { equal(e.before[i], zeros(ARTIST_HYDRATION_SNAPSHOT_TUPLE)); equal(e.after[i], zeros(ARTIST_HYDRATION_SNAPSHOT_TUPLE)); }
  }
  equal(e.before[2], before, "Archive pre-operation owner state differs from prior-block evidence");
  const after = e.after[2]!;
  if (after.domainId !== domains[2] || after.revision !== before.revision + 1n) throw Error("Archive Identity revision differs");
  hash(after.stateRoot); hash(after.recordChainTip);
  if (op === 65534n) equal(after.recordChainTip, before.recordChainTip, "Preparation cannot append semantic receipts");
  const [observed] = await read(p, c.owner, "ownerStateSnapshotV2", [], m.tag);
  if (observed.revision < after.revision) throw Error("Receipt owner revision regressed");
  if (observed.revision === after.revision) equal(observed, after);
  return { evidenceId, archiveBytes, e, index, after };
}
async function consumed(p: Reader, c: recovery.ArtistRecoveryAdjudicationCoordinates, surface: string, scope: Hex, commitment: Hex, revision: bigint, tag: number, exactRevision = true) {
  const [cell] = await read(p, c.owner, "replayCell", [replayKey(c, surface, scope)], tag);
  if (cell.status !== 2n || cell.kind !== 1n || cell.commitment !== commitment || !cell.touchedRevision
    || (exactRevision ? cell.touchedRevision !== revision : cell.touchedRevision > revision)) throw Error("Original replay evidence differs");
}
async function payloadEvidence(p: Reader, m: Mined, c: recovery.ArtistRecoveryAdjudicationCoordinates, before: readonly ArtistRecoveryPayloadCatalog[], payloads: readonly { kind: Hex; bytes: Hex }[], archived: number) {
  let lastRequired = archived;
  for (const catalog of before) {
    const keys = new Set(catalog.rows.map(r => `${r.payloadType}:${r.payloadHash}`));
    const expected: { kind: Hex; bytes: Hex; hash: Hex }[] = [];
    for (const payload of payloads) {
      const hash = keccak256(payload.bytes) as Hex, key = `${payload.kind}:${hash}`;
      if (!keys.has(key)) { expected.push({ ...payload, hash }); keys.add(key); }
    }
    const count = (await read(p, catalog.host, "storedPayloadCount", [], m.tag))[0];
    if (count < BigInt(catalog.rows.length + expected.length)) throw Error("Stored payload inventory incomplete");
    const events = m.found(catalog.host, "ArtistStoredPayload");
    if (events.length !== expected.length) throw Error("Exact payload additions missing");
    let last = -1;
    for (let i = 0; i < catalog.rows.length; i++) {
      const r = catalog.rows[i]!;
      equal(await read(p, catalog.host, "storedPayloadAt", [BigInt(i)], m.tag), [r.pointer, r.payloadType, r.payloadHash]);
    }
    for (let i = 0; i < expected.length; i++) {
      const item = expected[i]!, rowIndex = BigInt(catalog.rows.length + i);
      const [pointer, kind, hash] = await read(p, catalog.host, "storedPayloadAt", [rowIndex], m.tag);
      equal([kind, hash], [item.kind, item.hash]);
      equal(bytes(await p.getCode(address(pointer), m.tag), 24576), `0x00${item.bytes.slice(2)}`);
      const event = events[i]!;
      equal(Array.from(event.args), [1n, rowIndex, kind, hash, pointer]);
      if (event.log.index <= last || (catalog.host === c.owner ? event.log.index >= archived : event.log.index <= archived)) throw Error("Payload store/sync order differs");
      last = event.log.index; lastRequired = Math.max(lastRequired, last); m.reference(event.log, "ArtistStoredPayload");
    }
  }
  return lastRequired;
}
function compareAssociation(a: recovery.ArtistRecoveryActionAssociation, o: ArtistRecoveryAdjudicationOperation, role: { hash: Hex; revision: bigint }, timestamp: bigint, revision: bigint): void {
  const b = o.prepared.batch, d = o.prepared.capture.deployment;
  equal({ artistId: a.artistId, requestHash: a.requestHash, acceptanceHash: a.acceptanceHash, contextHash: a.contextHash,
    preparedBy: a.preparedBy, preparedAt: a.preparedAt, ownerRevision: a.ownerRevision },
  { artistId: b.request.artistId, requestHash: keccak256(recovery.encodeArtistRecoveryRequest(b.request)),
    acceptanceHash: keccak256(recovery.encodeArtistRecoveryAuthorization(b.acceptance)), contextHash: keccak256(recovery.encodeArtistRecoveryContext(b.context)),
    preparedBy: o.caller, preparedAt: timestamp, ownerRevision: revision });
  equal(a.action, { actionId: b.actionId, callsHash: b.callsHash, callIndex: 0n, callDataHash: b.governanceCall.callDataHash,
    executor: b.executor, executorCodeHash: d.governance.codeHash, proposer: o.prepared.proposer, roleMutationHash: role.hash,
    roleRevision: role.revision, notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter,
    minimumDelay: a.action.minimumDelay, manifestHash: b.window.manifestHash });
  if (a.action.minimumDelay < 259200n) throw Error("Preparation has invalid minimum delay");
}
async function registrationReceipt(p: ReceiptReader, m: Mined, o: ArtistRecoveryAdjudicationOperation, before: ArtistHydrationSnapshot, f: ArtistRecoveryAdjudicationFacts) {
  const b = o.prepared.batch, c = b.coordinates;
  const [a, veto, executed] = await read(p, c.owner, "identityRecoveryActionState", [b.request.artistId, b.actionId], m.tag);
  const [state] = await read(p, c.owner, "identityRecoveryEvidenceState", [b.request.artistId, b.actionId], m.tag);
  const roleState = await read(p, o.prepared.capture.deployment.artist.components[11]!.address, "roleMutationState", [f.role], m.tag - 1);
  compareAssociation(a, o, { hash: roleState[0], revision: roleState[1] }, m.h.timestamp, before.revision + 1n);
  recovery.assertArtistRecoveryRegistrationWindow(b.acceptance, b.window, m.h.timestamp, a.action.minimumDelay);
  if (f.manifest.ownerRevision !== before.revision || state.preparedFromOwnerRevision !== before.revision || state.manifestHash !== b.manifestHash
    || state.requiredRole !== f.role || state.associationHash !== a.associationHash || state.selectionCommitment !== f.selection.result!.commitment) throw Error("Registered manifest/selection state differs");
  hash(state.basisCommitment);
  equal(a.associationHash, recovery.artistRecoveryPreparationHash(c, f.association.action.actionId, b.manifestHash, state.basisCommitment, f.selection.result!, a));
  const [selection, restored] = await read(p, c.owner, "guardianRecoverySelection", [b.actionId], m.tag);
  equal(selection, f.selection.result); equal(restored, a.guardian);
  const [, , history] = await read(p, c.owner, "guardianHistoryState", [b.request.artistId, 0n, ZeroAddress, b.actionId], m.tag);
  equal(history, { artistId: b.request.artistId, count: f.selection.basis.history.count, historyCommitment: f.selection.basis.history.commitment, associationHash: a.associationHash });
  const prepared = m.one(c.owner, "ArtistIdentityRecoveryPrepared", [1n, b.request.artistId, b.actionId, a.associationHash, a.guardian.recordHash, o.caller, m.h.timestamp]);
  const archive = await archiveEvidence(p, m, o, 65534n, o.caller, a.associationHash, before);
  if (archive.index <= prepared) throw Error("Preparation Archive precedes owner event");
  await consumed(p, c, "identity_authority.replay.recovery_preparation", b.actionId, a.associationHash, archive.after.revision, m.tag);
  const evidence = recovery.decodeArtistRecoveryPreparationEvidence(archive.e.payload);
  equal(evidence, { payload: { request: b.request, acceptance: b.acceptance, context: b.context, association: a,
    count: f.selection.basis.history.count, history, selection, restored, state, evidence: f.evidence }, notice: f.notice });
  if (m.found(c.owner, "ArtistStoredPayload").length || m.found(c.archive, "ArtistStoredPayload").length) throw Error("Preparation cannot add payloads");
  // A later same-block veto/execution is represented by the retained immutable preparation above.
  void veto; void executed;
  return { association: a as recovery.ArtistRecoveryActionAssociation, record: null, evidenceId: archive.evidenceId, archiveBytes: archive.archiveBytes, nativeRecords: [], last: archive.index };
}
async function executionReceipt(p: ReceiptReader, m: Mined, o: ArtistRecoveryAdjudicationOperation, before: ArtistHydrationSnapshot, f: ArtistRecoveryAdjudicationFacts) {
  const b = o.prepared.batch, c = b.coordinates, q = b.request, a = b.acceptance;
  if (m.h.timestamp < b.window.notBefore || m.h.timestamp > b.window.expiresAfter || m.h.timestamp > a.time) throw Error("Recovery executed outside signed/governance window");
  if (before.revision !== f.manifest.ownerRevision + 1n || f.association.ownerRevision !== before.revision || f.association.action.actionId !== b.actionId
    || f.state.manifestHash !== b.manifestHash || f.state.associationHash !== f.association.associationHash || f.veto.vetoer !== ZeroAddress || f.executed !== ZeroHash) throw Error("Prepared recovery was not live in the previous block");
  const fields: recovery.ArtistRecoveryRecordFields = { artistId: q.artistId, oldAddress: b.context.incumbent, newAddress: q.newAddress,
    vestedAuthorityClass: q.vestedAuthorityClass, evidenceHash: q.evidenceHash, reasonHash: q.reasonHash,
    supersededRecordsHash: recovery.artistRecoverySupersededRecordsHash(q.supersededRecordHashes), governanceActionId: b.actionId, recoveredAt: m.h.timestamp };
  const recordHash = recovery.artistRecoveryRecordHash(c.chainId, c.registry, fields);
  const [record] = await read(p, c.owner, "identityRecoveryRecord", [recordHash], m.tag);
  const [association, , executed] = await read(p, c.owner, "identityRecoveryActionState", [q.artistId, b.actionId], m.tag);
  equal(association, f.association); equal(executed, recordHash);
  const [state] = await read(p, c.owner, "identityRecoveryEvidenceState", [q.artistId, b.actionId], m.tag); equal(state, f.state);
  const event = m.one(c.owner, "ArtistIdentityRecovered", [2n, q.artistId, b.context.incumbent, q.newAddress, q.vestedAuthorityClass,
    q.evidenceHash, q.reasonHash, fields.supersededRecordsHash, m.h.timestamp, recordHash, b.actionId, q.supersededRecordHashes]);
  const archive = await archiveEvidence(p, m, o, 35n, b.executor, recordHash, before);
  if (archive.index <= event) throw Error("Recovery Archive precedes owner event");
  const targetStart = Math.min(event, ...["ArtistStoredPayload", "ArtistDormancyCancelled", "ArtistDormancyCancellationContext"]
    .flatMap(name => m.found(c.owner, name).map(v => v.log.index)));
  const memberships = m.found(b.executor, "TerminalFreezeActionMembershipUpdated").filter(v => v.args[2] === b.actionId);
  if (memberships.length > 1) throw Error("Duplicate terminal membership cleanup");
  for (const entry of memberships) {
    const a = entry.args;
    if (a[0] !== 1n || a[1] !== b.context.scopeHash || a[3] !== o.prepared.proposer || a[4] !== false || a[5] !== 3n
      || a[7] !== b.window.notBefore || a[8] > a[9] || a[9] >= 64n || entry.log.index >= targetStart) throw Error("Terminal cleanup fields/order differ");
    m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
  }
  const decoded = recovery.decodeArtistRecoveryExecutionEvidence(archive.e.payload), e = decoded.payload;
  equal(e.request, q); equal(e.acceptance, a); equal(e.context, b.context); equal(e.state, f.state); equal(e.evidence, f.evidence);
  const direct = b.executor === q.newAddress && a.signature === "0x";
  equal(e.proof, { signer: q.newAddress, digest: f.acceptanceDigest, direct });
  equal(e.governance, { actionId: b.actionId, proposer: o.prepared.proposer, actionClass: 2n,
    roleMutationHash: f.association.action.roleMutationHash, roleRevision: f.association.action.roleRevision,
    scopeHash: b.context.scopeHash, oldValueHash: b.context.oldValueHash, newValueHash: b.context.newValueHash });
  const expected: recovery.ArtistRecoveryRecord = { recordHash, fields, terms: q, executor: b.executor, proposer: o.prepared.proposer,
    governanceWitnessHash: keccak256(recovery.encodeArtistRecoveryGovernanceWitness(e.governance)) as Hex,
    contextHash: keccak256(recovery.encodeArtistRecoveryContext(b.context)) as Hex, acceptanceDigest: f.acceptanceDigest,
    acceptanceNonce: a.nonce, acceptanceDeadline: a.time, postContestSeconds: b.context.postContestSeconds,
    standingTailSeconds: b.context.standingTailSeconds, timingRevision: b.context.timingRevision,
    delegationEpoch: b.context.delegationEpoch + 1n, abandonedTransition: b.context.abandonedTransition };
  equal(record, expected); equal(e.record, expected);
  const afterRevision = archive.after.revision;
  await consumed(p, c, "identity_authority.replay.recovery_action", hashEncoded(["bytes32", "bytes32", "bytes32", "bytes32"], [b.actionId, b.context.scopeHash, b.context.oldValueHash, b.context.newValueHash]), recordHash, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.standing_retirement", hashEncoded(["bytes32", "address", "bytes32"], [q.artistId, b.context.incumbent, recordHash]), recordHash, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.contest_resolution", hashEncoded(["bytes32", "bytes32"], [q.artistId, q.expectedCauseHash]), recordHash, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.nonce_allocator", hashEncoded(["bytes32", "bytes32", "address", "uint256"], [id("rotation_acceptance"), q.artistId, q.newAddress, a.nonce]), f.acceptanceDigest, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.authorization_consumed_digest", hashEncoded(["bytes32", "bytes32"], [q.artistId, f.acceptanceDigest]), f.acceptanceDigest, afterRevision, m.tag, false);
  const [denied] = await read(p, c.owner, "replayCell", [replayKey(c, "identity_authority.replay.digest_revocation", hashEncoded(["bytes32", "bytes32"], [q.artistId, f.acceptanceDigest]))], m.tag);
  if (denied.status !== 0n) throw Error("Accepted digest was revoked");
  const [vesting] = await read(p, c.owner, "guardianVestingSnapshot", [q.artistId, recordHash], m.tag);
  equal([vesting.artistId, vesting.transitionRecordHash, vesting.operationId, vesting.ownerRevision, vesting.executedAt,
    vesting.oldAddress, vesting.newAddress, vesting.authorityClass, vesting.guardians, vesting.previousTransitionRecordHash],
  [q.artistId, recordHash, 35n, afterRevision, m.h.timestamp, b.context.incumbent, q.newAddress, q.vestedAuthorityClass,
    f.selection.basis.history, f.manifest.executedHead]);
  equal(vesting.commitment, recovery.artistRecoveryVestingCommitment(c, vesting));
  if (f.manifest.executedHead === ZeroHash) equal(vesting.previousCommitment, ZeroHash);
  else equal(vesting.previousCommitment, (await read(p, c.owner, "guardianVestingSnapshot", [q.artistId, f.manifest.executedHead], m.tag))[0].commitment);
  const pair = await read(p, c.owner, "identityRecoveryReceipts", [recordHash], m.tag);
  hash(pair[0]); hash(pair[2]);
  equal(pair[1], hashEncoded(["bytes32", "uint16", "bytes32", "bytes32", "bytes32"], ["0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09", 2n, recordHash,
    "0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae", fields.supersededRecordsHash]));
  equal(decoded.noticeBefore, f.notice);
  const nativeRecords = [];
  let offset = 0n;
  if (f.notice) {
    const n = decoded.noticeAfter;
    if (!n) throw Error("Current notice post-evidence missing");
    equal(n.cause, f.notice.cause); equal(n.notice, f.notice.notice);
    if (f.notice.phase === 1n) {
      const terminal = { ...zeros(recovery.ARTIST_RECOVERY_TERMINAL_TUPLE), noticeHash: n.notice.recordHash, actor: q.newAddress, authorityClass: 1n, observedAt: m.h.timestamp };
      terminal.recordHash = recovery.artistRecoveryCancellationHash(c, terminal, n.notice.priorActivity + 1n);
      equal(n.phase, 2n); equal(n.terminal, terminal);
      const cancelled = m.one(c.owner, "ArtistDormancyCancelled", [1n, q.artistId, n.notice.recordHash, q.newAddress, 1n, terminal.recordHash]);
      const contextual = m.one(c.owner, "ArtistDormancyCancellationContext", [1n, q.artistId, terminal.recordHash,
        { chainId: c.chainId, registry: c.registry, identityOwner: c.owner, recorder: q.newAddress, recorderAuthorityClass: 1n }, terminal, n.notice.priorActivity + 1n]);
      if (cancelled >= contextual || contextual >= event) throw Error("Genuine42 cancellation must precede recovery35");
      await consumed(p, c, "identity_authority.replay.dormancy_cancellation_key", n.notice.recordHash, terminal.recordHash, afterRevision, m.tag);
      nativeRecords.push({ operation: 42n, artistId: q.artistId, collectionId: 0n, recordHash: terminal.recordHash }); offset = 1n;
    } else {
      equal(n, f.notice);
      if (m.found(c.owner, "ArtistDormancyCancelled").length || m.found(c.owner, "ArtistDormancyCancellationContext").length) throw Error("Phase2 notice cannot be cancelled again");
    }
    const retainedNotice = await notice(p, c, q.expectedCauseHash, m.tag); equal(retainedNotice, n);
  } else if (decoded.noticeAfter) throw Error("Unexpected notice wrapper");
  nativeRecords.push({ operation: 35n, artistId: q.artistId, collectionId: 0n, recordHash },
    { operation: 35n, artistId: q.artistId, collectionId: 0n, recordHash: fields.supersededRecordsHash });
  const count = (await read(p, c.owner, "artistNativeReceiptCount", [], m.tag))[0];
  if (count < f.nativeCount + 2n + offset) throw Error("Native recovery journal incomplete");
  for (let i = 0; i < nativeRecords.length; i++) equal((await read(p, c.owner, "artistNativeReceiptAt", [f.nativeCount + BigInt(i)], m.tag))[0], nativeRecords[i]);
  const preimage = encoded(["bytes32", "uint256", "address", recovery.ARTIST_RECOVERY_RECORD_FIELDS_TUPLE],
    ["0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff", c.chainId, c.registry, fields]);
  const last = await payloadEvidence(p, m, c, f.payloads, [{ kind: id("ARTIST_SIGNATURE_BUNDLE") as Hex, bytes: a.signature },
    { kind: id("ARTIST_RECORD_PREIMAGE") as Hex, bytes: preimage }], archive.index);
  return { association: f.association, record: expected, evidenceId: archive.evidenceId, archiveBytes: archive.archiveBytes, nativeRecords, last };
}
/** Exact singleton original governance transport, plus immutable auxiliary/operation35 evidence. */
export async function inspectArtistRecoveryAdjudicationOperationReceipt(p: ReceiptReader, raw: ArtistRecoveryAdjudicationOperation, supplied: ReceiptOptions): Promise<ArtistRecoveryAdjudicationGovernanceReceipt> {
  const o = operation(raw), c = o.prepared.capture, b = o.prepared.batch, d = c.deployment, options = receiptOptions(supplied);
  await historical(p, c);
  const m = await mined(p, d, o.caller, o.call, c.blockNumber, options), { h, tag } = m;
  let detail: { association: recovery.ArtistRecoveryActionAssociation | null; record: recovery.ArtistRecoveryRecord | null; evidenceId: Hex | null; archiveBytes: Hex | null; nativeRecords: { operation: bigint; artistId: Hex; collectionId: bigint; recordHash: Hex }[]; last: number }
    = { association: null, record: null, evidenceId: null, archiveBytes: null, nativeRecords: [], last: -1 };
  const prior = await context(p, d, tag - 1, false);
  if (o.stage === "publish") {
    const now = await publication(p, b, tag), old = await publication(p, b, tag - 1);
    if (!now) throw Error("Publication not retained");
    if (old) {
      equal(now, old); if (m.found(b.executor, "GovernanceCallDataPublished").length) throw Error("Publication retry emitted first event");
    } else m.one(b.executor, "GovernanceCallDataPublished", [1n, b.publicationKey, now, o.caller]);
  } else {
    const catalog = await governance(p, o, tag);
    const a = await action(p, o, tag);
    if (o.stage === "schedule") {
      if (![1n, 2n, 5n].includes(a.status) || b.window.notBefore < h.timestamp + catalog.minimumDelay
        || h.timestamp > (1n << 64n) - 1n - 31536000n || b.window.expiresAfter > h.timestamp + 31536000n) throw Error("Schedule state/window contradiction");
      if ((await read(p, b.executor, "governanceNonce", [], tag))[0] < b.nonce + 1n) throw Error("Governance nonce did not advance");
      const membership = m.one(b.executor, "TerminalFreezeGuardianConfigCommitted", [1n, b.actionId,
        hash((await read(p, b.executor, "terminalFreezeGuardianConfigCommitment", [b.actionId], tag))[0])]);
      const entries = m.found(b.executor, "TerminalFreezeActionMembershipUpdated").filter(v => v.args[2] === b.actionId);
      if (entries.length !== 1) throw Error("Original terminal membership append missing");
      const entry = entries[0]!, args = entry.args;
      if (args[0] !== 1n || args[1] !== b.context.scopeHash || args[3] !== o.caller || args[4] !== true || args[5] !== 1n
        || args[7] !== b.window.notBefore || args[9] !== args[8] + 1n || args[9] > 64n || entry.log.index >= membership) throw Error("Terminal membership fields/order differ");
      m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
      const scheduled = m.one(b.executor, "GovernanceActionScheduled", [1n, b.actionId, 2n, b.targetCall.to, 0n, b.governanceCall.selector,
        b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, b.window.notBefore, b.window.expiresAfter, b.nonce,
        o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      const validated = m.one(b.executor, "GovernanceActionPolicyValidated", [1n, b.actionId, 1n, catalog.candidateProfileHash, catalog.catalogHash]);
      if (membership >= scheduled || scheduled >= validated) throw Error("Schedule source event order differs");
    } else {
      const input = { kind: "identityRecoveryContextV2" as const, request: b.request, acceptance: b.acceptance, manifestHash: b.manifestHash };
      const f = await recoveryFacts(p, d, input, tag - 1);
      equal(f.context, b.context); equal(f.evidence, c.recovery!.evidence);
      const [before] = await read(p, b.coordinates.owner, "ownerStateSnapshotV2", [], tag - 1);
      detail = o.stage === "register" ? await registrationReceipt(p, m, o, before, f) : await executionReceipt(p, m, o, before, f);
      if (o.stage === "execute") {
        if (a.status !== 3n || !same(a.executor, o.caller)) throw Error("Governance execution state differs");
        const executed = m.one(b.executor, "GovernanceActionExecuted", [1n, b.actionId, 2n, b.targetCall.to, 0n, b.governanceCall.selector,
          b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, o.caller, b.window.manifestHash]);
        const validated = m.one(b.executor, "GovernanceActionPolicyValidated", [1n, b.actionId, 2n, catalog.candidateProfileHash, catalog.catalogHash]);
        if (detail.last >= executed || executed >= validated) throw Error("Execution source event order differs");
      }
    }
  }
  await unchanged(p, prior);
  const { last: _, ...result } = detail;
  return freeze({ ...h, operation: o, transactionHash: m.transactionHash, events: await m.finish(), ...result,
    attribution: "immutable operation evidence; block-end observations may include later operations" });
}
