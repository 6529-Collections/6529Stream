import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import {
  CURRENT_ARTIST_GUARDIAN_ROTATION_ABI, ARTIST_GUARDIAN_SET_TUPLE, ARTIST_ROTATION_TERMS_TUPLE,
  ARTIST_ROTATION_AUTHORIZATION_TUPLE, ARTIST_GUARDIAN_RECORD_TUPLE, ARTIST_ROTATION_RECORD_TUPLE,
  normalizeGuardianRotationCall, normalizeArtistGuardianSet, guardianRotationDigest,
  artistGuardianRecordHash, artistRotationRecordHash,
  type PreparedGuardianRotation, type ArtistGuardianRecord, type ArtistRotationRecord,
  type ArtistRotationTransition, type ArtistRotationAuthorization, type GuardianRotationReads,
} from "./current-artist-guardian-rotation.js";
import type { CurrentArtistDeployment, CurrentArtistCodePin, CurrentArtistAuthority, CurrentArtistReplay } from "./current-artist-workflow.js";
import { createSafeCallPlan, type SafeCallPlan } from "./safe-plan.js";

const REPLAY = "(bool digestObserved,bool digestRevoked,bool nonceConsumed,bool nonceRevoked,uint256 nextUnusedNonce)";
const SNAPSHOT = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const PROOF = "(address signer,bytes32 digest,bool direct)";
const CAUSE = "(bytes32 causeHash,(bytes32 artistId,uint8 kind,bytes32 referenceHash,address actor,bytes32 reasonHash,bytes32 evidenceHash,uint64 enteredAt,address incumbent,uint8 authorityClass,uint8 priorStatus,bytes32 pendingTransitionHash,bytes32 executedTransitionHash,bytes32 previousCauseHash,bytes32 previousResolutionHash,bytes32 actorRetirementHash) facts)";
/** Every original read/event used below is exposed for independent frozen-fixture correspondence. */
export const CURRENT_ARTIST_GUARDIAN_ROTATION_WORKFLOW_ABI = Object.freeze([
  ...CURRENT_ARTIST_GUARDIAN_ROTATION_ABI,
  "function suiteConfiguration() view returns((address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator))",
  "function reads() view returns(address)", "function configurationHash() view returns(bytes32)",
  "function deploymentChainId() view returns(uint256)", "function core() view returns(address)",
  "function mintManager() view returns(address)", "function operationCoordinator() view returns(address)",
  "function artistRegistry() view returns(address)", "function archiveV2() view returns(address)", "function domainId() view returns(bytes32)",
  "function getSatellitePointer(bytes32) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  "function authorityState(bytes32) view returns(address,uint8,uint8,bytes32)",
  "function currentAuthorityCapabilities(bytes32) view returns((address authorityAddress,uint8 authorityClass,uint8 status,uint32 effectiveCapabilities,bytes32 activationRecordHash))",
  "function activeIdentity(address) view returns(bytes32)",
  `function artistAuthorizationState(bytes32,bytes32,uint256) view returns(${REPLAY})`,
  "function artistWindowInfo(bytes32) view returns(uint64 value,uint64 floor,uint64 revision)",
  "function successorDesignation(bytes32) view returns(address successor,uint8 kind,uint32 capabilities,bytes32 conditionsHash,bytes32 directiveHash,uint256 nonce)",
  "function priorAddressStandingRevoked(bytes32,address) view returns(bool revoked,bytes32 recordHash)",
  "function recoveryStandingScopeV3(bytes32,address) view returns(bytes32 retirementHash,bytes32 revocationRecordHash,bytes32 independentJudgmentHash,bytes32 continuationHash)",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes evidence)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)",
]);
const abi = new Interface(CURRENT_ARTIST_GUARDIAN_ROTATION_WORKFLOW_ABI), coder = AbiCoder.defaultAbiCoder();
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
interface Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
export interface GuardianRotationCapabilities {
  readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint;
  readonly effectiveCapabilities: bigint; readonly activationRecordHash: Hex;
}
export interface GuardianRotationSigningObservation {
  readonly side: "principal" | "acceptance"; readonly signer: Address; readonly direct: boolean;
  readonly nonce: bigint; readonly submittedTime: bigint; readonly effectiveTime: bigint;
  readonly rawDigest: Hex; readonly effectiveDigest: Hex; readonly replay: CurrentArtistReplay;
  /** Principal nonce flags in replay are deliberately ignored for this distinct kind4 lane. */
  readonly acceptance: { readonly used: boolean; readonly nextNonce: bigint } | null;
  readonly signatureVerified: false;
}
export interface GuardianRotationStanding {
  readonly successor: Address; readonly retirementHash: Hex; readonly revoked: boolean;
  readonly revocationRecordHash: Hex; readonly independentJudgmentHash: Hex; readonly continuationHash: Hex;
  /** Candidate routes only. Original composed standing admission is checked by exact simulation. */
  readonly routes: readonly ("principal" | "successor" | "currentGuardian" | "capturedGuardian" | "priorAddress")[];
}
export interface GuardianRotationCapture extends Block {
  readonly deployment: CurrentArtistDeployment; readonly prepared: PreparedGuardianRotation;
  readonly configurationHash: Hex; readonly artistId: Hex; readonly authority: CurrentArtistAuthority;
  readonly capabilities: GuardianRotationCapabilities;
  readonly guardianSet: GuardianRotationReads["guardianSet"]["result"];
  readonly guardianRecord: ArtistGuardianRecord | null;
  readonly pendingRotation: GuardianRotationReads["pendingRotation"]["result"];
  readonly rotationRecord: ArtistRotationRecord | null; readonly capturedGuardianRecord: ArtistGuardianRecord | null;
  readonly latestTransition: Hex;
  readonly activeWindow: GuardianRotationReads["activeAuthorityWindow"]["result"];
  readonly activeTransition: ArtistRotationTransition | null;
  readonly windows: {
    readonly rotation: { readonly value: bigint; readonly floor: bigint; readonly revision: bigint };
    readonly standingTail: { readonly value: bigint; readonly floor: bigint; readonly revision: bigint };
  };
  readonly activeAddresses: { readonly oldIdentity: Hex; readonly newIdentity: Hex } | null;
  readonly signing: readonly GuardianRotationSigningObservation[]; readonly standing: GuardianRotationStanding | null;
  /** Signatures, duplicate approvals, lifetime guardian retention and composed admission require simulation. */
  readonly simulationRequired: true; readonly captureHash: Hex;
}
export interface GuardianRotationSimulation {
  readonly capture: GuardianRotationCapture; readonly observation: GuardianRotationCapture;
  readonly returnData: Hex; readonly recordHash: Hex;
  /** Target eth_call from the actual actor, not a Safe ceremony or future admission guarantee. */
  readonly targetCallOnly: true;
}

function keys(v: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).some(k => typeof k !== "string" || ![...required, ...optional].includes(k))
    || required.some(k => !Object.hasOwn(v, k))) throw Error("Missing/unknown fields");
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function address(v: unknown, zero = false): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (!zero && a === ZeroAddress) throw Error("Zero address");
  return a;
}
function bytes(v: unknown, maximum = 32768): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > maximum) throw Error("Malformed/oversized bytes");
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
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function stable(v: unknown): string {
  function tagged(x: unknown): unknown {
    if (x === null) return ["null"];
    if (typeof x === "string" || typeof x === "boolean") return [typeof x, x];
    if (typeof x === "bigint") return ["bigint", x.toString()];
    if (typeof x === "number" && Number.isFinite(x)) return ["number", x];
    if (Array.isArray(x)) return ["array", x.map(tagged)];
    if (x && typeof x === "object") return ["object", Object.keys(x).sort().map(k => [k, tagged((x as Record<string, unknown>)[k])])];
    throw Error("Unsupported capture value");
  }
  return JSON.stringify(tagged(v));
}
function equal(a: unknown, b: unknown, message: string): void { if (stable(a) !== stable(b)) throw Error(message); }
function freeze<T>(v: T): T { if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); } return v; }
function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function pin(v: CurrentArtistCodePin): CurrentArtistCodePin { keys(v, ["address", "codeHash"]); return { address: address(v.address), codeHash: hash(v.codeHash) }; }
function deployment(v: CurrentArtistDeployment): CurrentArtistDeployment {
  keys(v, ["chainId", "registry", "coordinator", "components", "reads"]);
  if (!Array.isArray(v.components) || v.components.length !== 16 || Reflect.ownKeys(v.components).length !== 17 || !v.reads) throw Error("Exactly16 suite pins and Reads pin required");
  const d = { chainId: uint(v.chainId), registry: pin(v.registry), coordinator: pin(v.coordinator), components: v.components.map(pin), reads: pin(v.reads) };
  if (d.chainId === 0n || !same(d.registry.address, d.components[7]!.address) || !same(d.registry.codeHash, d.components[7]!.codeHash)
    || new Set([d.coordinator.address, d.reads.address, ...d.components.map(x => x.address)]).size !== 18) throw Error("Distinct exact Artist deployment pins required");
  return freeze(d);
}
function plain(t: ParamType, value: any): any {
  if (t.baseType === "array") return Array.from(value, v => plain(t.arrayChildren!, v));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((c, i) => [c.name, plain(c, value[i])]));
  return value;
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, maximum = 32768): Promise<any[]> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, gasLimit: 5_000_000n }), maximum);
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error(`Noncanonical ${name} return`);
  return abi.getFunction(name)!.outputs.map((t, i) => plain(t, decoded[i]));
}
async function header(p: Reader, tag: number): Promise<Block> {
  const h = await p.getBlock(tag);
  if (!h || h.number !== tag) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(h.hash), timestamp: uint(BigInt(number(h.timestamp)), 64) };
}
async function unchanged(p: Reader, h: Block): Promise<void> { equal(await header(p, h.blockNumber), { blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp }, "Pinned block changed"); }
async function context(p: Reader, d: CurrentArtistDeployment, tag: number, current: boolean) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain mismatch");
  const h = await header(p, tag);
  await Promise.all([d.coordinator, d.reads!, ...d.components].map(async x => {
    const code = bytes(await p.getCode(x.address, tag), 65536);
    if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), x.codeHash)) throw Error("Pinned Artist runtime differs");
  }));
  const [suite] = await read(p, d.coordinator.address, "suiteConfiguration", [], tag);
  const ordered = [...suite.owners, suite.registry, suite.archive, suite.core, suite.mintManager, suite.roleRegistry, suite.metadata, suite.primaryResolver, suite.royaltyResolver, suite.validator];
  equal(ordered.map(x => address(x)), d.components.map(x => x.address), "Suite component pins differ");
  if (!same((await read(p, d.coordinator.address, "reads", [], tag))[0], d.reads!.address)
    || (await read(p, d.coordinator.address, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Coordinator binding differs");
  const core = d.components[9]!.address, manager = d.components[10]!.address;
  for (const [name, expected] of [["core", core], ["mintManager", manager], ["operationCoordinator", d.coordinator.address]] as const) {
    if (!same((await read(p, d.registry.address, name, [], tag))[0], expected)) throw Error("Registry binding differs");
  }
  for (let i = 0; i < 7; i++) {
    const owner = d.components[i]!.address;
    for (const [name, expected] of [["core", core], ["mintManager", manager], ["artistRegistry", d.registry.address], ["operationCoordinator", d.coordinator.address], ["archiveV2", d.components[8]!.address], ["domainId", domains[i]!]] as const) {
      if (!same((await read(p, owner, name, [], tag))[0], expected)) throw Error("Owner binding differs");
    }
    if ((await read(p, owner, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Owner chain differs");
  }
  if (current) {
    const pointer = await read(p, core, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
    if (!same(pointer[0], d.registry.address) || !same(pointer[1], d.registry.codeHash)
      || (await read(p, d.registry.address, "artistRegistryCutover", [], tag))[0] !== false) throw Error("Registry is not current");
  }
  return { ...h, configurationHash: hash((await read(p, d.coordinator.address, "configurationHash", [], tag))[0]) };
}
function ordinary(a: CurrentArtistAuthority): boolean {
  return a.authorityClass === 1n && (a.status === 1n || a.status === 2n) || (a.authorityClass === 3n || a.authorityClass === 4n) && a.status === 3n;
}
function guardianRecord(d: CurrentArtistDeployment, artistId: Hex, expected: Hex, r: ArtistGuardianRecord): ArtistGuardianRecord {
  normalizeArtistGuardianSet(r.terms);
  if (!same(r.recordHash, expected) || !same(r.terms.artistId, artistId) || r.signer === ZeroAddress || ![1n, 3n, 4n].includes(r.authorityClass)
    || !same(artistGuardianRecordHash(d.chainId, d.registry.address, r.terms, r.nonce, r.signedAt), expected)) throw Error("Guardian record correspondence differs");
  return r;
}
function rotationRecord(d: CurrentArtistDeployment, artistId: Hex, expected: Hex, r: ArtistRotationRecord): ArtistRotationRecord {
  const t = r.transition;
  if (!same(r.recordHash, expected) || !same(r.terms.artistId, artistId) || !same(t.artistId, artistId) || !same(t.recordHash, expected)
    || !same(artistRotationRecordHash(d.chainId, d.registry.address, r.terms, r.oldNonce, t.stagedAt, t.contestEndsAt), expected)
    || r.effectiveWindow < 259200n || t.contestEndsAt !== t.stagedAt + r.effectiveWindow || r.standingTail < 2592000n || r.timingRevision === 0n
    || t.phase < 1n || t.phase > 3n) throw Error("Rotation record correspondence differs");
  return r;
}
function member(r: ArtistGuardianRecord | null, actor: Address): boolean { return r !== null && r.terms.guardians.some(a => same(a, actor)); }
async function guardian(p: Reader, d: CurrentArtistDeployment, artistId: Hex, record: Hex, tag: number): Promise<ArtistGuardianRecord | null> {
  return same(record, ZeroHash) ? null : guardianRecord(d, artistId, record, (await read(p, d.registry.address, "guardianSetRecord", [record], tag))[0]);
}
function saved(v: GuardianRotationCapture): GuardianRotationCapture {
  keys(v, ["deployment", "prepared", "blockNumber", "blockHash", "timestamp", "configurationHash", "artistId", "authority", "capabilities", "guardianSet", "guardianRecord", "pendingRotation", "rotationRecord", "capturedGuardianRecord", "latestTransition", "activeWindow", "activeTransition", "windows", "activeAddresses", "signing", "standing", "simulationRequired", "captureHash"]);
  const { captureHash, ...body } = v;
  if (!same(hash(captureHash), digest(body)) || v.simulationRequired !== true) throw Error("Changed guardian/rotation capture");
  const d = deployment(v.deployment), a = normalizeGuardianRotationCall(v.prepared), q = a.request;
  equal(d, v.deployment, "Noncanonical captured deployment"); equal(a, v.prepared, "Noncanonical captured call");
  if (q.chainId !== d.chainId || !same(q.registry, d.registry.address) || !same(v.artistId, "terms" in q ? q.terms.artistId : q.artistId)) throw Error("Captured operation coordinates differ");
  number(v.blockNumber); uint(v.timestamp, 64); hash(v.blockHash); hash(v.configurationHash);
  return freeze(structuredClone(v));
}

/** Pinned source-correspondent facts; exact signatures and composed owner admission remain unverified. */
export async function captureGuardianRotation(p: Reader, input: CurrentArtistDeployment, prepared: PreparedGuardianRotation, options: { readonly blockTag: number }): Promise<GuardianRotationCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), action = normalizeGuardianRotationCall(prepared), q = action.request, tag = number(options.blockTag);
  if (q.chainId !== d.chainId || !same(q.registry, d.registry.address)) throw Error("Prepared deployment differs");
  const artistId = "terms" in q ? q.terms.artistId : q.artistId, registry = d.registry.address, owner = d.components[2]!.address;
  const h = await context(p, d, tag, true);
  const [a, capabilities, g, pending, latest, active, rotationWindow, standingWindow] = await Promise.all([
    read(p, owner, "authorityState", [artistId], tag), read(p, registry, "currentAuthorityCapabilities", [artistId], tag),
    read(p, registry, "guardianSet", [artistId], tag), read(p, registry, "pendingRotation", [artistId], tag),
    read(p, registry, "lastArtistTransition", [artistId], tag), read(p, registry, "activeAuthorityWindow", [artistId], tag),
    read(p, registry, "artistWindowInfo", [id("ARTIST_ROTATION_CONTEST_SECONDS")], tag),
    read(p, registry, "artistWindowInfo", [id("ARTIST_PRIOR_ADDRESS_STANDING_TAIL_SECONDS")], tag),
  ]);
  const authority: CurrentArtistAuthority = { address: address(a[0]), authorityClass: a[1], status: a[2], identityRecordHash: hash(a[3]) };
  if (!ordinary(authority)) throw Error("Ordinary current authority required");
  const rights = capabilities[0] as GuardianRotationCapabilities;
  if (!same(rights.authorityAddress, authority.address) || rights.authorityClass !== authority.authorityClass || rights.status !== authority.status) throw Error("Authority/capabilities differ");
  if ((q.kind === "setGuardians" || q.kind === "stageRotation") && authority.authorityClass !== 1n
    && (same(rights.activationRecordHash, ZeroHash) || q.kind === "setGuardians" && (rights.effectiveCapabilities & 256n) !== 256n)) throw Error("Estate authority capability unavailable");
  const guardianSet = { guardians: g[0] as readonly Address[], approvalThreshold: g[1] as bigint, minContestSeconds: g[2] as bigint, recordHash: hash(g[3], true) };
  const currentGuardian = await guardian(p, d, artistId, guardianSet.recordHash, tag);
  if (currentGuardian) equal(guardianSet, { guardians: currentGuardian.terms.guardians, approvalThreshold: currentGuardian.terms.approvalThreshold, minContestSeconds: currentGuardian.terms.minContestSeconds, recordHash: currentGuardian.recordHash }, "Operative guardian head differs");
  else if (guardianSet.guardians.length || guardianSet.approvalThreshold !== 0n || guardianSet.minContestSeconds !== 0n) throw Error("Absent guardian head has nonzero facts");
  const pendingRotation = { oldAddress: address(pending[0], true), newAddress: address(pending[1], true), contestEndsAt: pending[2] as bigint, guardianApprovals: pending[3] as bigint, recordHash: hash(pending[4], true) };
  const latestTransition = hash(latest[0], true);
  const activeWindow = { transitionRecordHash: hash(active[0], true), windowEndsAt: active[1] as bigint, contested: active[2] as boolean };
  const activeTransition: ArtistRotationTransition | null = activeWindow.transitionRecordHash === ZeroHash ? null : (await read(p, registry, "artistTransitionState", [activeWindow.transitionRecordHash], tag))[0];
  if (activeTransition && (!same(activeTransition.artistId, artistId) || !same(activeTransition.recordHash, activeWindow.transitionRecordHash) || activeTransition.phase === 0n)) throw Error("Active transition correspondence differs");
  if (activeTransition && (activeWindow.windowEndsAt !== (activeTransition.phase === 1n ? activeTransition.contestEndsAt : activeTransition.postWindowEndsAt)
    || activeWindow.contested !== (activeTransition.contestedAt !== 0n))) throw Error("Active window fields differ from original transition");
  if (!activeTransition && (activeWindow.windowEndsAt !== 0n || activeWindow.contested)) throw Error("Absent active window has nonzero facts");
  const windows = {
    rotation: { value: rotationWindow[0] as bigint, floor: rotationWindow[1] as bigint, revision: rotationWindow[2] as bigint },
    standingTail: { value: standingWindow[0] as bigint, floor: standingWindow[1] as bigint, revision: standingWindow[2] as bigint },
  };
  if (windows.rotation.floor !== 259200n || windows.standingTail.floor !== 2592000n || windows.rotation.value < windows.rotation.floor
    || windows.standingTail.value < windows.standingTail.floor || windows.rotation.revision === 0n || windows.rotation.revision !== windows.standingTail.revision) throw Error("Original window facts differ");
  let rotation: ArtistRotationRecord | null = null, capturedGuardian: ArtistGuardianRecord | null = null;
  if (pendingRotation.recordHash !== ZeroHash) {
    rotation = rotationRecord(d, artistId, pendingRotation.recordHash, (await read(p, registry, "rotationRecord", [pendingRotation.recordHash], tag))[0]);
    capturedGuardian = await guardian(p, d, artistId, rotation.guardianSetRecordHash, tag);
    equal(pendingRotation, { oldAddress: rotation.terms.oldAddress, newAddress: rotation.terms.newAddress, contestEndsAt: rotation.transition.contestEndsAt, guardianApprovals: rotation.guardianApprovals, recordHash: rotation.recordHash }, "Pending rotation tuple differs");
    equal((await read(p, registry, "artistTransitionState", [rotation.recordHash], tag))[0], rotation.transition, "Rotation transition differs");
    if (!same(latestTransition, rotation.recordHash) || !same(activeWindow.transitionRecordHash, rotation.recordHash)) throw Error("Pending rotation heads differ");
    if (rotation.transition.phase !== 1n || rotation.transition.contestedAt !== 0n || rotation.transition.executedAt !== 0n || rotation.transition.postWindowEndsAt !== 0n
      || rotation.approvalThreshold !== (capturedGuardian?.terms.approvalThreshold ?? 0n) || rotation.guardianApprovals > BigInt(capturedGuardian?.terms.guardians.length ?? 0)) throw Error("Invalid pending rotation facts");
  } else if (pendingRotation.oldAddress !== ZeroAddress || pendingRotation.newAddress !== ZeroAddress || pendingRotation.contestEndsAt !== 0n || pendingRotation.guardianApprovals !== 0n) throw Error("Absent pending rotation has nonzero facts");
  let activeAddresses: GuardianRotationCapture["activeAddresses"] = null;
  if (q.kind === "stageRotation" || q.kind === "executeRotation") {
    const terms = q.kind === "stageRotation" ? q.terms : rotation?.terms;
    if (!terms || !same(terms.oldAddress, authority.address)) throw Error("Rotation old address is not current authority");
    const [oldIdentity, newIdentity] = await Promise.all([read(p, owner, "activeIdentity", [terms.oldAddress], tag), read(p, owner, "activeIdentity", [terms.newAddress], tag)]);
    activeAddresses = { oldIdentity: hash(oldIdentity[0], true), newIdentity: hash(newIdentity[0], true) };
    if (activeAddresses.newIdentity !== ZeroHash || q.kind === "executeRotation" && !same(activeAddresses.oldIdentity, artistId)) throw Error("Rotation address occupancy differs");
  }
  if (q.kind === "stageRotation") {
    if (!same(q.terms.expectedPreviousTransitionRecordHash, latestTransition)) throw Error("Previous transition guard differs");
    // Authenticated noteLiving can cancel a generic pending estate/dormancy before original stage.
    if (rotation || activeTransition && activeTransition.phase !== 1n) throw Error("Active authority window blocks rotation");
    const effective = windows.rotation.value > guardianSet.minContestSeconds ? windows.rotation.value : guardianSet.minContestSeconds;
    if (h.timestamp + effective >= 1n << 64n) throw Error("Rotation window overflows uint64");
  } else if (q.kind !== "setGuardians") {
    if (!rotation || !same(q.expectedRotationRecordHash, rotation.recordHash)) throw Error("Expected pending rotation differs");
    if (q.kind === "approveRotation" && !member(capturedGuardian, q.caller)) throw Error("Caller is not a captured guardian");
    if (q.kind === "executeRotation" && h.timestamp < rotation.transition.contestEndsAt
      && (rotation.approvalThreshold === 0n || rotation.guardianApprovals < rotation.approvalThreshold)) throw Error("Rotation is not executable");
    if (q.kind === "executeRotation" && h.timestamp + rotation.effectiveWindow >= 1n << 64n) throw Error("Post-window overflows uint64");
  }
  const signing: GuardianRotationSigningObservation[] = [];
  for (const part of action.signing) {
    const signer = part.side === "acceptance" && q.kind === "stageRotation" ? q.terms.newAddress : authority.address;
    const authorization: ArtistRotationAuthorization = q.kind === "setGuardians" ? q.authorization : q.kind === "stageRotation" ? part.side === "acceptance" ? q.newAuthorization : q.oldAuthorization : (() => { throw Error("Unexpected signing side"); })();
    const direct = same(q.caller, signer) && authorization.signature === "0x";
    if (!direct && authorization.signature === "0x" && bytes(await p.getCode(signer, tag), 65536) === "0x") throw Error("Empty relayed EOA proof");
    const effectiveTime = q.kind === "setGuardians" && direct && authorization.time === 0n ? h.timestamp : authorization.time;
    if (q.kind === "setGuardians" ? effectiveTime === 0n || effectiveTime > h.timestamp || direct && effectiveTime !== h.timestamp : authorization.time < h.timestamp) throw Error("Authorization time is not admissible at captured block");
    const kind = q.kind === "setGuardians" ? "guardianSet" : part.side === "acceptance" ? "rotationAcceptance" : "rotation";
    const getter = kind === "guardianSet" ? "guardianSetDigest" : kind === "rotation" ? "rotationDigest" : "rotationAcceptanceDigest";
    if (!("terms" in q)) throw Error("Missing signed terms");
    const rawDigest = hash((await read(p, registry, getter, [q.terms, { ...authorization, signature: "0x" }], tag))[0]);
    if (!same(rawDigest, part.digest)) throw Error("Original raw digest differs");
    const effectiveDigest = guardianRotationDigest(kind, d.chainId, registry, q.terms, { ...authorization, time: effectiveTime });
    if (effectiveTime !== authorization.time && !same((await read(p, registry, getter, [q.terms, { ...authorization, time: effectiveTime, signature: "0x" }], tag))[0], effectiveDigest)) throw Error("Original effective digest differs");
    const replay = (await read(p, registry, "artistAuthorizationState", [artistId, effectiveDigest, authorization.nonce], tag))[0] as CurrentArtistReplay;
    let acceptance: GuardianRotationSigningObservation["acceptance"] = null;
    if (part.side === "acceptance") {
      const result = await read(p, registry, "rotationAcceptanceNonceState", [artistId, signer, authorization.nonce], tag);
      acceptance = { used: result[0], nextNonce: result[1] };
      if (acceptance.used || direct && authorization.nonce !== acceptance.nextNonce) throw Error("Acceptance nonce is unavailable");
    } else if (replay.nonceConsumed || replay.nonceRevoked || direct && authorization.nonce !== replay.nextUnusedNonce) throw Error("Principal nonce is unavailable");
    if (replay.digestRevoked) throw Error("Authorization digest is revoked");
    signing.push({ side: part.side, signer, direct, nonce: authorization.nonce, submittedTime: authorization.time, effectiveTime, rawDigest, effectiveDigest, replay, acceptance, signatureVerified: false });
  }
  let standing: GuardianRotationStanding | null = null;
  if (q.kind === "vetoRotation") {
    const [s, r, scope] = await Promise.all([
      read(p, registry, "successorDesignation", [artistId], tag),
      read(p, registry, "priorAddressStandingRevoked", [artistId, q.caller], tag),
      read(p, owner, "recoveryStandingScopeV3", [artistId, q.caller], tag),
    ]);
    const routes: GuardianRotationStanding["routes"][number][] = [];
    if (same(q.caller, authority.address)) routes.push("principal");
    if (same(q.caller, s[0])) routes.push("successor");
    if (member(currentGuardian, q.caller)) routes.push("currentGuardian");
    if (member(capturedGuardian, q.caller)) routes.push("capturedGuardian");
    // scope[2] hashes the entire retained judgment, including empty or older-retirement judgments.
    // It is not a live zero/nonzero disqualification flag; original owner simulation resolves it.
    if (!same(scope[0], ZeroHash) && !r[0]) routes.push("priorAddress");
    if (!routes.length) throw Error("No observed rotation veto standing");
    standing = { successor: address(s[0], true), retirementHash: hash(scope[0], true), revoked: r[0], revocationRecordHash: hash(r[1], true), independentJudgmentHash: hash(scope[2], true), continuationHash: hash(scope[3], true), routes };
  }
  const result = { deployment: d, prepared: action, ...h, artistId, authority, capabilities: rights, guardianSet, guardianRecord: currentGuardian,
    pendingRotation, rotationRecord: rotation, capturedGuardianRecord: capturedGuardian, latestTransition, activeWindow, activeTransition,
    windows, activeAddresses, signing, standing, simulationRequired: true as const };
  await unchanged(p, h);
  return freeze({ ...result, captureHash: digest(result) });
}

/** Historical capture is reconstructed before any exact target-level simulation; all calls are read-only. */
export async function simulateGuardianRotation(p: Reader, input: GuardianRotationCapture, options: { readonly gasLimit: bigint; readonly blockTag?: number }): Promise<GuardianRotationSimulation> {
  keys(options, ["gasLimit"], ["blockTag"]);
  const c = saved(input), gasLimit = uint(options.gasLimit), tag = options.blockTag === undefined ? c.blockNumber : number(options.blockTag);
  if (gasLimit === 0n || gasLimit > 100_000_000n || tag < c.blockNumber) throw Error("Invalid bounded simulation options");
  equal(await captureGuardianRotation(p, c.deployment, c.prepared, { blockTag: c.blockNumber }), c, "Historical capture differs");
  const fresh = tag === c.blockNumber ? c : await captureGuardianRotation(p, c.deployment, c.prepared, { blockTag: tag });
  for (const field of ["authority", "capabilities", "guardianSet", "guardianRecord", "pendingRotation", "rotationRecord", "capturedGuardianRecord", "latestTransition", "windows", "activeAddresses", "standing", "configurationHash"] as const) equal(fresh[field], c[field], `${field} changed; capture again`);
  // Effective zero-time digest and temporal active-window expiry may legitimately change with the block.
  const q = c.prepared.request;
  const raw = bytes(await p.call({ ...c.prepared.call, from: q.caller, blockTag: tag, gasLimit }), 32);
  let record: Hex;
  if (q.kind === "setGuardians") {
    record = artistGuardianRecordHash(q.chainId, q.registry, q.terms, q.authorization.nonce, fresh.signing[0]!.effectiveTime);
    if (!same(raw, record)) throw Error("Simulated guardian record differs");
  } else if (q.kind === "stageRotation") {
    const window = fresh.windows.rotation.value > fresh.guardianSet.minContestSeconds ? fresh.windows.rotation.value : fresh.guardianSet.minContestSeconds;
    record = artistRotationRecordHash(q.chainId, q.registry, q.terms, q.oldAuthorization.nonce, fresh.timestamp, fresh.timestamp + window);
    if (!same(raw, record)) throw Error("Simulated rotation record differs");
  } else {
    record = q.expectedRotationRecordHash;
    if (raw !== "0x") throw Error("Void original operation returned data");
  }
  await unchanged(p, fresh);
  return freeze({ capture: c, observation: fresh, returnData: raw, recordHash: record, targetCallOnly: true as const });
}

/** One ordinary zero-value CALL. Mine/read back before planning a dependent rotation step. */
export function createGuardianRotationSafePlan(input: GuardianRotationCapture, options: { readonly safe: Address; readonly title: string }): SafeCallPlan {
  keys(options, ["safe", "title"]);
  const c = saved(input);
  if (!same(address(options.safe), c.prepared.request.caller)) throw Error("Safe differs from actual prepared actor");
  return createSafeCallPlan(c.deployment.chainId, options.title, [{ safe: address(options.safe),
    intent: `Artist operation ${c.prepared.operation}: ${c.prepared.request.kind}; exact admission simulation required`,
    call: c.prepared.call, abi: CURRENT_ARTIST_GUARDIAN_ROTATION_ABI }]);
}

export interface GuardianRotationReceipt extends Block {
  readonly capture: GuardianRotationCapture; readonly transactionHash: Hex; readonly recordHash: Hex;
  readonly evidenceId: Hex; readonly evidenceContentHash: Hex; readonly archiveEvidence: Hex;
  readonly guardianRecord: ArtistGuardianRecord | null; readonly rotationRecord: ArtistRotationRecord | null;
  readonly causeHash: Hex | null;
  readonly events: readonly { readonly address: Address; readonly name: string; readonly logIndex: number }[];
  /** Historical original event/archive evidence; not a current-state or Safe-owner certification. */
  readonly historicalEvidenceOnly: true;
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeEvents = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexedEvents = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
function decode(types: readonly string[], raw: Hex): any[] {
  const result = coder.decode(types, raw);
  if (!same(coder.encode(types, result), raw)) throw Error("Noncanonical archive tuple");
  return types.map((t, i) => plain(ParamType.from(t), result[i]));
}
function encodedEqual(types: readonly string[], actual: readonly unknown[], expected: readonly unknown[], reason: string): void {
  if (!same(coder.encode(types, actual), coder.encode(types, expected))) throw Error(reason);
}
/**
 * Decode the exact original historical receipt and complete retained operation archive.
 * Safe support is one canonical execTransaction CALL and its success log, not owner/threshold verification.
 */
export async function inspectGuardianRotationReceipt(p: ReceiptReader, input: GuardianRotationCapture, options: {
  readonly transactionHash: Hex; readonly execution: "direct" | "safe";
}): Promise<GuardianRotationReceipt> {
  keys(options, ["transactionHash", "execution"]);
  const c = saved(input), d = c.deployment, q = c.prepared.request, transactionHash = hash(options.transactionHash);
  if (options.execution !== "direct" && options.execution !== "safe") throw Error("Unknown receipt execution mode");
  equal(await captureGuardianRotation(p, d, c.prepared, { blockTag: c.blockNumber }), c, "Historical capture differs");
  const [tx, receipt] = await Promise.all([p.getTransaction(transactionHash), p.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash) || receipt.status !== 1
    || tx.chainId !== d.chainId || tx.value !== 0n || tx.blockNumber === null || receipt.blockNumber !== tx.blockNumber
    || receipt.blockNumber <= c.blockNumber || !same(tx.blockHash, receipt.blockHash) || !same(tx.from, receipt.from) || !same(tx.to, receipt.to)) throw Error("Successful matching receipt must follow capture");
  const txData = bytes(tx.data, 65536);
  if (options.execution === "direct") {
    if (!same(tx.from, q.caller) || !same(tx.to, c.prepared.call.to) || !same(txData, c.prepared.call.data)) throw Error("Direct original call differs");
  } else {
    if (!same(tx.to, q.caller)) throw Error("Safe caller differs");
    const values = safeAbi.decodeFunctionData("execTransaction", txData);
    if (!same(safeAbi.encodeFunctionData("execTransaction", values), txData) || !same(values.to, c.prepared.call.to)
      || values.value !== 0n || values.operation !== 0n || !same(values.data, c.prepared.call.data)) throw Error("Safe original CALL differs");
  }
  const h = await context(p, d, number(receipt.blockNumber), false);
  if (!same(h.blockHash, receipt.blockHash) || !same(h.configurationHash, c.configurationHash)) throw Error("Receipt block/configuration differs");
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 512) throw Error("Receipt log bound exceeded");
  let previousIndex = -1;
  const logs = receipt.logs.map(l => {
    if (l.removed || l.blockNumber !== h.blockNumber || !same(l.blockHash, h.blockHash) || !same(l.transactionHash, transactionHash)
      || number(l.index) <= previousIndex || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log");
    previousIndex = l.index;
    return { address: address(l.address), index: l.index, data: bytes(l.data, 65536), topics: l.topics.map((t: string) => hash(t, true)) };
  });
  const events: { address: Address; name: string; logIndex: number }[] = [];
  function event(target: Address, name: string, expected?: readonly unknown[], iface = abi) {
    const fragment = iface.getEvent(name)!;
    const found = logs.filter(l => same(l.address, target) && same(l.topics[0], fragment.topicHash));
    if (found.length !== 1) throw Error(`Expected one original ${name}`);
    const log = found[0]!, values = iface.decodeEventLog(fragment, log.data, log.topics), encoded = iface.encodeEventLog(fragment, values);
    if (!same(encoded.data, log.data) || stable(encoded.topics.map(t => t.toLowerCase())) !== stable(log.topics)) throw Error("Noncanonical original event");
    if (expected) {
      const wanted = iface.encodeEventLog(fragment, expected);
      if (!same(wanted.data, log.data) || stable(wanted.topics.map(t => t.toLowerCase())) !== stable(log.topics)) throw Error(`${name} correspondence differs`);
    }
    events.push({ address: target, name, logIndex: log.index });
    return values;
  }
  const owner = d.components[2]!.address, archive = d.components[8]!.address, A = ARTIST_ROTATION_AUTHORIZATION_TUPLE;
  const window = c.windows.rotation.value > c.guardianSet.minContestSeconds ? c.windows.rotation.value : c.guardianSet.minContestSeconds;
  const effectiveTime = q.kind === "setGuardians" ? c.signing[0]!.direct && q.authorization.time === 0n ? h.timestamp : q.authorization.time : 0n;
  if (q.kind === "setGuardians" && (effectiveTime === 0n || effectiveTime > h.timestamp || c.signing[0]!.direct && effectiveTime !== h.timestamp)) throw Error("Mined guardian time is inadmissible");
  if (q.kind === "stageRotation" && (q.oldAuthorization.time < h.timestamp || q.newAuthorization.time < h.timestamp)) throw Error("Mined rotation deadline expired");
  const record = q.kind === "setGuardians" ? artistGuardianRecordHash(d.chainId, d.registry.address, q.terms, q.authorization.nonce, effectiveTime)
    : q.kind === "stageRotation" ? artistRotationRecordHash(d.chainId, d.registry.address, q.terms, q.oldAuthorization.nonce, h.timestamp, h.timestamp + window) : q.expectedRotationRecordHash;
  const evidenceId = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), d.chainId, d.registry.address, d.coordinator.address, c.prepared.operation, q.caller, record])) as Hex;
  const metadata = await read(p, archive, "artistEvidenceMetadataV2", [evidenceId, 1n], h.blockNumber);
  const evidence = bytes((await read(p, archive, "artistEvidenceBytesV2", [evidenceId, 1n], h.blockNumber, 24640))[0], 24575);
  if (!same(keccak256(evidence), metadata[0]) || BigInt((evidence.length - 2) / 2) !== metadata[2] || metadata[3] !== BigInt(h.blockNumber)) throw Error("Original Archive content metadata differs");
  const pointerCode = bytes(await p.getCode(address(metadata[1]), h.blockNumber), 24576);
  if (pointerCode !== `0x00${evidence.slice(2)}`) throw Error("Archive retained STOP bytes differ");
  const envelope = decode(["uint16", "bytes32", "uint16", "address", "bytes32", `${SNAPSHOT}[7]`, `${SNAPSHOT}[7]`, "bytes"], evidence);
  encodedEqual(["uint16", "bytes32", "uint16", "address", "bytes32"], envelope.slice(0, 5), [1n, c.configurationHash, BigInt(c.prepared.operation), q.caller, record], "Archive operation identity differs");
  for (let i = 0; i < 7; i++) {
    const before = envelope[5][i], after = envelope[6][i];
    if (i === 2) {
      if (!same(before.domainId, domains[2]) || !same(after.domainId, domains[2]) || after.revision !== before.revision + 1n
        || same(before.stateRoot, after.stateRoot)
        || ((c.prepared.operation === 28 || c.prepared.operation === 29)
          ? same(before.recordChainTip, after.recordChainTip) : !same(before.recordChainTip, after.recordChainTip))) throw Error("Archive Identity snapshot transition differs");
    } else {
      const empty = { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash };
      equal(before, empty, "Unexpected non-Identity before snapshot"); equal(after, empty, "Unexpected non-Identity after snapshot");
    }
  }
  const payload = bytes(envelope[7], 24575);
  let savedGuardian: ArtistGuardianRecord | null = null, savedRotation: ArtistRotationRecord | null = null, causeHash: Hex | null = null;
  function proof(signer: Address, authorization: ArtistRotationAuthorization, kind: "guardianSet" | "rotation" | "rotationAcceptance", terms: any) {
    return { signer, digest: guardianRotationDigest(kind, d.chainId, d.registry.address, terms, authorization), direct: same(q.caller, signer) && authorization.signature === "0x" };
  }
  if (q.kind === "setGuardians") {
    const types = [ARTIST_GUARDIAN_SET_TUPLE, A, PROOF, A, ARTIST_GUARDIAN_RECORD_TUPLE], v = decode(types, payload);
    const effective = { ...q.authorization, time: effectiveTime }, expectedProof = proof(c.authority.address, effective, "guardianSet", q.terms);
    savedGuardian = guardianRecord(d, c.artistId, record, v[4]);
    encodedEqual(types, v, [q.terms, q.authorization, expectedProof, effective, savedGuardian], "Archived guardian request/proof differs");
    if (!same(savedGuardian.signer, c.authority.address) || savedGuardian.authorityClass !== c.authority.authorityClass
      || savedGuardian.nonce !== q.authorization.nonce || savedGuardian.signedAt !== effectiveTime) throw Error("Archived guardian admission differs");
    event(owner, "ArtistGuardianSetUpdated", [1n, c.artistId, q.terms.guardians, q.terms.approvalThreshold, q.terms.minContestSeconds, savedGuardian.authorityClass, q.authorization.nonce, effectiveTime, record]);
  } else if (q.kind === "stageRotation") {
    const types = [ARTIST_ROTATION_TERMS_TUPLE, A, A, PROOF, PROOF, ARTIST_ROTATION_RECORD_TUPLE], v = decode(types, payload);
    savedRotation = rotationRecord(d, c.artistId, record, v[5]);
    encodedEqual([ARTIST_ROTATION_TERMS_TUPLE], [savedRotation.terms], [q.terms], "Archived rotation terms/unsigned guard differ");
    encodedEqual(types, v, [q.terms, q.oldAuthorization, q.newAuthorization, proof(q.terms.oldAddress, q.oldAuthorization, "rotation", q.terms), proof(q.terms.newAddress, q.newAuthorization, "rotationAcceptance", q.terms), savedRotation], "Archived rotation request/proofs differ");
    if (savedRotation.oldNonce !== q.oldAuthorization.nonce || savedRotation.newNonce !== q.newAuthorization.nonce
      || !same(savedRotation.guardianSetRecordHash, c.guardianSet.recordHash) || savedRotation.approvalThreshold !== c.guardianSet.approvalThreshold
      || savedRotation.guardianApprovals !== 0n || savedRotation.effectiveWindow !== window || savedRotation.standingTail !== c.windows.standingTail.value
      || savedRotation.timingRevision !== c.windows.rotation.revision || savedRotation.transition.stagedAt !== h.timestamp || savedRotation.transition.phase !== 1n
      || savedRotation.transition.executedAt !== 0n || savedRotation.transition.postWindowEndsAt !== 0n || savedRotation.transition.contestedAt !== 0n) throw Error("Archived staged rotation facts differ");
    event(owner, "ArtistRotationStaged", [1n, c.artistId, q.terms.oldAddress, q.terms.newAddress, h.timestamp, h.timestamp + window, q.oldAuthorization.nonce, q.terms.reasonHash, record]);
  } else {
    if (!c.rotationRecord) throw Error("Missing captured rotation");
    const veto = q.kind === "vetoRotation";
    const types = veto ? ["bytes32", "bytes32", "bytes32", ARTIST_ROTATION_RECORD_TUPLE, CAUSE] : ["bytes32", "bytes32", ARTIST_ROTATION_RECORD_TUPLE];
    const v = decode(types, payload);
    savedRotation = rotationRecord(d, c.artistId, record, v[veto ? 3 : 2]);
    encodedEqual(types.slice(0, veto ? 3 : 2), v.slice(0, veto ? 3 : 2), veto ? [c.artistId, record, q.reasonHash] : [c.artistId, record], "Archived rotation action differs");
    const expectedImmutable = { ...c.rotationRecord, guardianApprovals: savedRotation.guardianApprovals, transition: savedRotation.transition };
    encodedEqual([ARTIST_ROTATION_RECORD_TUPLE], [savedRotation], [expectedImmutable], "Archived immutable rotation differs");
    const t = savedRotation.transition, previous = c.rotationRecord.transition;
    if (t.stagedAt !== previous.stagedAt || t.contestEndsAt !== previous.contestEndsAt || savedRotation.guardianApprovals < c.rotationRecord.guardianApprovals
      || savedRotation.guardianApprovals > BigInt(c.capturedGuardianRecord?.terms.guardians.length ?? 0)) throw Error("Archived rotation history differs");
    if (q.kind === "approveRotation") {
      if (t.phase !== 1n || t.executedAt !== 0n || t.postWindowEndsAt !== 0n || t.contestedAt !== 0n
        || savedRotation.guardianApprovals <= c.rotationRecord.guardianApprovals) throw Error("Archived approval is not a distinct staged approval");
      event(owner, "ArtistRotationGuardianApproved", [1n, c.artistId, q.caller, record, savedRotation.guardianApprovals]);
    } else if (q.kind === "executeRotation") {
      if (t.phase !== 2n || t.executedAt !== h.timestamp || t.postWindowEndsAt !== h.timestamp + savedRotation.effectiveWindow || t.contestedAt !== 0n
        || h.timestamp < t.contestEndsAt && (savedRotation.approvalThreshold === 0n || savedRotation.guardianApprovals < savedRotation.approvalThreshold)) throw Error("Archived execution window differs");
      event(owner, "ArtistAddressRotated", [1n, c.artistId, savedRotation.terms.oldAddress, savedRotation.terms.newAddress, c.authority.authorityClass, savedRotation.terms.reasonHash, record]);
    } else {
      if (q.kind !== "vetoRotation") throw Error("Unexpected receipt operation");
      if (t.phase !== 3n || t.contestedAt !== h.timestamp || t.executedAt !== 0n || t.postWindowEndsAt !== 0n) throw Error("Archived veto transition differs");
      const cause = v[4], f = cause.facts, causeType = ParamType.from(CAUSE).components![1]!;
      causeHash = hash(cause.causeHash);
      if (!same(causeHash, keccak256(coder.encode(["bytes32", "uint256", "address", "address", causeType], [id("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"), d.chainId, d.registry.address, owner, f])))
        || !same(f.artistId, c.artistId) || f.kind !== 2n || !same(f.referenceHash, record) || !same(f.actor, q.caller)
        || !same(f.reasonHash, q.reasonHash) || !same(f.evidenceHash, ZeroHash) || f.enteredAt !== h.timestamp
        || !same(f.incumbent, c.authority.address) || f.authorityClass !== c.authority.authorityClass || f.priorStatus !== c.authority.status
        || !same(f.pendingTransitionHash, record)) throw Error("Archived original veto cause differs");
      event(owner, "ArtistRotationVetoed", [1n, c.artistId, q.caller, record, q.reasonHash]);
    }
  }
  event(archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], metadata[1], metadata[2]]);
  if (events[0]!.logIndex >= events[1]!.logIndex) throw Error("Original event/archive order differs");
  if (options.execution === "safe") {
    const successTopic = safeEvents.getEvent("ExecutionSuccess")!.topicHash;
    const hits = logs.filter(l => same(l.address, q.caller) && same(l.topics[0], successTopic));
    if (hits.length !== 1 || logs.some(l => same(l.address, q.caller) && same(l.topics[0], safeEvents.getEvent("ExecutionFailure")!.topicHash))) throw Error("Expected Safe success without failure");
    const iface = hits[0]!.topics.length === 2 ? safeIndexedEvents : safeEvents;
    const success = event(q.caller, "ExecutionSuccess", undefined, iface);
    hash(success[0]);
    if (events[2]!.logIndex <= events[1]!.logIndex) throw Error("Safe success precedes original evidence");
  }
  await unchanged(p, h);
  return freeze({ capture: c, transactionHash, blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp,
    recordHash: record, evidenceId, evidenceContentHash: hash(metadata[0]), archiveEvidence: evidence,
    guardianRecord: savedGuardian, rotationRecord: savedRotation, causeHash, events, historicalEvidenceOnly: true as const });
}
