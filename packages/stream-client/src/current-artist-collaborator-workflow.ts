import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import {
  CURRENT_ARTIST_COLLABORATOR_ABI, COLLABORATOR_PROPOSAL_TUPLE, COLLABORATOR_PROPOSAL_STATE_TUPLE,
  COLLABORATOR_AUTHORIZATION_TUPLE, COLLABORATOR_ACCEPTANCE_TUPLE, COLLABORATOR_BINDING_TUPLE,
  COLLABORATOR_BINDING_TERMS_TUPLE, normalizeCollaboratorCall, normalizeCollaboratorProposal,
  collaboratorProposalHash, collaboratorIdentityId, collaboratorAcceptanceRecordHash, collaboratorSetHash,
  primaryOnlyCollaboratorBindingHash, type PreparedCollaborator, type CollaboratorIdentityProposalState,
  type CollaboratorBinding, type CollaboratorBindingTerms, type CollaboratorRow,
} from "./current-artist-collaborator.js";
import type { CurrentArtistDeployment, CurrentArtistCodePin, CurrentArtistAuthority, CurrentArtistReplay } from "./current-artist-workflow.js";
import { createSafeCallPlan, type SafeCallPlan } from "./safe-plan.js";

const REPLAY = "(bool digestObserved,bool digestRevoked,bool nonceConsumed,bool nonceRevoked,uint256 nextUnusedNonce)";
const SNAPSHOT = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const CELL = "(bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status)";
const PROOF = "(address signer,bytes32 digest,bool direct)";
const NATIVE = "(uint16 operation,bytes32 artistId,uint256 collectionId,bytes32 recordHash)";
/** Exact original reads and events, exposed for independent frozen compiler-fixture correspondence. */
export const CURRENT_ARTIST_COLLABORATOR_WORKFLOW_ABI = Object.freeze([
  ...CURRENT_ARTIST_COLLABORATOR_ABI,
  "function suiteConfiguration() view returns((address registry,address archive,address[7] owners,address core,address mintManager,address roleRegistry,address metadata,address primaryResolver,address royaltyResolver,bytes32 primaryRevenueClass,address validator))",
  "function reads() view returns(address)", "function configurationHash() view returns(bytes32)",
  "function deploymentChainId() view returns(uint256)", "function core() view returns(address)",
  "function mintManager() view returns(address)", "function operationCoordinator() view returns(address)",
  "function artistRegistry() view returns(address)", "function archiveV2() view returns(address)", "function domainId() view returns(bytes32)",
  "function getSatellitePointer(bytes32) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  "function authorityState(bytes32) view returns(address,uint8,uint8,bytes32)",
  "function currentAuthorityCapabilities(bytes32) view returns((address authorityAddress,uint8 authorityClass,uint8 status,uint32 effectiveCapabilities,bytes32 activationRecordHash))",
  "function activeIdentity(address) view returns(bytes32)", "function nextRegistrationNonce() view returns(uint256)",
  "function hasRole(bytes32,address) view returns(bool)", "function roleMutationState(bytes32) view returns(bytes32,uint64)",
  "function collectionExists(uint256) view returns(bool)",
  "function attributionState(uint256) view returns(uint8,uint64)",
  `function binding(uint256) view returns(${COLLABORATOR_BINDING_TUPLE})`,
  `function bindingTerms(uint256,uint64) view returns(${COLLABORATOR_BINDING_TERMS_TUPLE})`,
  "function acceptedCount(bytes32) view returns(uint32)", "function acceptanceRecord(bytes32) view returns(bytes32)",
  `function artistAuthorizationState(bytes32,bytes32,uint256) view returns(${REPLAY})`,
  `function ownerStateSnapshotV2() view returns(${SNAPSHOT})`,
  `function replayCell(bytes32) view returns(${CELL})`,
  "function artistNativeReceiptCount() view returns(uint256)",
  `function artistNativeReceiptAt(uint256) view returns(${NATIVE})`,
  "function artistNativeReceiptRevisionAt(uint256) view returns(uint64)",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32 contentHash,address pointer,uint32 payloadSize,uint64 appendedAtBlock)",
  "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes evidence)",
  "event ArtistIdentityRegistered(uint16 schemaVersion,bytes32 indexed artistId,address indexed authorityAddress,bytes32 identityRecordHash,string identityRecordURI,uint256 registrationNonce)",
  "event ArtistIdentityDisplayNameStored(bytes32 indexed artistId,bytes32 indexed identityRecordHash,string displayName)",
  "event CollaboratorAccepted(uint16 schemaVersion,uint256 indexed collectionId,address indexed collaborator,bytes32 indexed collaboratorArtistId,uint64 bindingGeneration,bytes32 role,bytes32 shareLabelId,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 acceptanceRecordHash,bytes32 bindingHash)",
  "event ArtistAttributionStateChanged(uint16 schemaVersion,uint256 indexed collectionId,uint8 indexed newState,uint64 bindingGeneration,uint8 oldState,address actor,uint8 authorityClass,bytes32 recordHash,bytes32 reasonHash,string reasonURI)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)",
]);
const abi = new Interface(CURRENT_ARTIST_COLLABORATOR_WORKFLOW_ABI), coder = AbiCoder.defaultAbiCoder();
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
interface Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
export interface CollaboratorSnapshot { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex }
export interface CollaboratorReplayCell { readonly commitment: Hex; readonly touchedRevision: bigint; readonly kind: bigint; readonly status: bigint }
export interface CollaboratorCapabilities {
  readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint;
  readonly effectiveCapabilities: bigint; readonly activationRecordHash: Hex;
}
export interface CollaboratorSigningObservation {
  readonly signer: Address; readonly direct: boolean; readonly digest: Hex; readonly replay: CurrentArtistReplay;
  readonly signatureVerified: false;
}
export interface CollaboratorCapture extends Block {
  readonly deployment: CurrentArtistDeployment; readonly prepared: PreparedCollaborator; readonly configurationHash: Hex;
  readonly proposal: CollaboratorIdentityProposalState | null;
  readonly role: { readonly role: Hex; readonly mutationHash: Hex; readonly revision: bigint } | null;
  readonly registration: {
    readonly allocationNonce: bigint; readonly predictedArtistId: Hex;
    readonly nonce: { readonly used: boolean; readonly firstUnused: bigint };
    readonly nonceCell: CollaboratorReplayCell; readonly digestCell: CollaboratorReplayCell;
  } | null;
  readonly row: {
    readonly binding: CollaboratorBinding; readonly terms: CollaboratorBindingTerms; readonly rows: readonly CollaboratorRow[];
    readonly attribution: { readonly state: bigint; readonly generation: bigint };
    readonly artistId: Hex; readonly authority: CurrentArtistAuthority; readonly capabilities: CollaboratorCapabilities;
    readonly acceptedCount: bigint; readonly primaryRecord: Hex; readonly completesIfExecuted: boolean;
  } | null;
  readonly signing: CollaboratorSigningObservation | null;
  /** Only owner slots visited by the original recipe are populated; remaining slots are zero. */
  readonly snapshots: readonly CollaboratorSnapshot[];
  /** Original Identity(op6) or Acceptance(op7) journal cursor; op5 has no native record. */
  readonly nativeCount: bigint | null;
  readonly simulationRequired: true; readonly captureHash: Hex;
}
export interface CollaboratorSimulation {
  readonly capture: CollaboratorCapture; readonly observation: CollaboratorCapture;
  readonly returnData: Hex; readonly recordHash: Hex; readonly targetCallOnly: true;
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
function replayKey(d: CurrentArtistDeployment, ownerIndex: number, surface: string, scope: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), d.chainId, d.registry.address, d.coordinator.address, d.components[8]!.address,
      d.components[ownerIndex]!.address, domains[ownerIndex], id(surface), scope])) as Hex;
}
function saved(v: CollaboratorCapture): CollaboratorCapture {
  keys(v, ["deployment", "prepared", "blockNumber", "blockHash", "timestamp", "configurationHash", "proposal", "role", "registration", "row", "signing", "snapshots", "nativeCount", "simulationRequired", "captureHash"]);
  const { captureHash, ...body } = v;
  if (!same(hash(captureHash), digest(body)) || v.simulationRequired !== true) throw Error("Changed collaborator capture");
  equal(deployment(v.deployment), v.deployment, "Noncanonical deployment");
  const a = normalizeCollaboratorCall(v.prepared), q = a.request;
  equal(a, v.prepared, "Noncanonical prepared operation");
  if (q.chainId !== v.deployment.chainId || !same(q.registry, v.deployment.registry.address)) throw Error("Captured deployment differs");
  number(v.blockNumber); hash(v.blockHash); uint(v.timestamp, 64); hash(v.configurationHash);
  return freeze(structuredClone(v));
}
function proposalState(d: CurrentArtistDeployment, value: CollaboratorIdentityProposalState): void {
  normalizeCollaboratorProposal(value.proposal);
  if (!same(collaboratorProposalHash(d.chainId, d.registry.address, value.proposal, value.proposer), value.proposalHash)) throw Error("Proposal hash correspondence differs");
}
function nonrevoked(r: CurrentArtistReplay): void {
  // Observation is an append-only fact, not revocation or nonce consumption.
  if (r.digestRevoked || r.nonceConsumed || r.nonceRevoked) throw Error("Authorization is revoked or consumed");
}
/** Source-correspondent observations. Exact signatures, liveness composition and write admission require simulation. */
export async function captureCollaborator(p: Reader, input: CurrentArtistDeployment, prepared: PreparedCollaborator, options: { readonly blockTag: number }): Promise<CollaboratorCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), action = normalizeCollaboratorCall(prepared), q = action.request, tag = number(options.blockTag);
  if (q.chainId !== d.chainId || !same(q.registry, d.registry.address)) throw Error("Prepared deployment differs");
  const h = await context(p, d, tag, true), registry = d.registry.address, identity = d.components[2]!.address;
  let proposal: CollaboratorCapture["proposal"] = null, role: CollaboratorCapture["role"] = null;
  let registration: CollaboratorCapture["registration"] = null, row: CollaboratorCapture["row"] = null;
  let signing: CollaboratorCapture["signing"] = null, nativeCount: bigint | null = null;
  const empty: CollaboratorSnapshot = { domainId: ZeroHash as Hex, revision: 0n, stateRoot: ZeroHash as Hex, recordChainTip: ZeroHash as Hex };
  const snapshots: CollaboratorSnapshot[] = [];
  for (let i = 0; i < 7; i++) {
    const selected = action.operation === 7 ? i < 5 : i === 1 || i === 2;
    const s: CollaboratorSnapshot = selected ? (await read(p, d.components[i]!.address, "ownerStateSnapshotV2", [], tag))[0] : empty;
    if (selected && !same(s.domainId, domains[i])) throw Error("Owner snapshot domain differs");
    snapshots.push(s);
  }
  if (q.kind !== "acceptRow") {
    const account = q.kind === "proposeIdentity" ? q.proposal.account : q.account;
    const documentHash = q.kind === "proposeIdentity" ? q.proposal.identityRecordHash : q.identityRecordHash;
    if (!same((await read(p, identity, "activeIdentity", [account], tag))[0], ZeroHash)) throw Error("Account already registered");
    proposal = (await read(p, registry, "collaboratorIdentityProposal", [account, documentHash], tag))[0] as CollaboratorIdentityProposalState;
    if (q.kind === "proposeIdentity") {
      if (!same(proposal.proposalHash, ZeroHash)) throw Error("Proposal pair already exists");
      const roleId = id("ROLE_ARTIST_REGISTRY_ADMIN") as Hex, target = d.components[11]!.address;
      if ((await read(p, target, "hasRole", [roleId, q.caller], tag))[0] !== true) throw Error("Proposal requires Registry admin");
      const mutation = await read(p, target, "roleMutationState", [roleId], tag);
      role = { role: roleId, mutationHash: hash(mutation[0], true), revision: mutation[1] };
    } else {
      proposalState(d, proposal);
      if (!same(proposal.proposal.account, q.account) || !same(proposal.proposal.identityRecordHash, q.identityRecordHash)
        || !same(proposal.acceptedArtistId, ZeroHash)) throw Error("Proposal is not pending for this account/document");
      const allocationNonce = (await read(p, identity, "nextRegistrationNonce", [], tag))[0] as bigint;
      const predictedArtistId = collaboratorIdentityId(d.chainId, registry, q.account, q.identityRecordHash, allocationNonce);
      const nonce = await read(p, registry, "collaboratorRegistrationNonceState", [q.account, q.authorization.nonce], tag);
      const signedDigest = action.signing!.payload.digest;
      const nonceScope = keccak256(coder.encode(["address", "uint256"], [q.account, q.authorization.nonce])) as Hex;
      const digestScope = keccak256(coder.encode(["address", "bytes32"], [q.account, signedDigest])) as Hex;
      const nonceCell: CollaboratorReplayCell = (await read(p, identity, "replayCell", [replayKey(d, 2, "identity_authority.replay.collaborator_account_nonce", nonceScope)], tag))[0];
      const digestCell: CollaboratorReplayCell = (await read(p, identity, "replayCell", [replayKey(d, 2, "identity_authority.replay.collaborator_account_digest", digestScope)], tag))[0];
      if (nonce[0] || nonceCell.status !== 0n || digestCell.status !== 0n) throw Error("Account registration authorization already consumed");
      registration = { allocationNonce, predictedArtistId, nonce: { used: nonce[0], firstUnused: nonce[1] }, nonceCell, digestCell };
      nativeCount = (await read(p, identity, "artistNativeReceiptCount", [], tag))[0];
    }
  } else {
    if (!same(q.core, d.components[9]!.address)) throw Error("Acceptance Core differs");
    const terms = q.terms, binding: CollaboratorBinding = (await read(p, d.components[0]!.address, "binding", [terms.collectionId], tag))[0];
    const attr = await read(p, d.components[4]!.address, "attributionState", [terms.collectionId], tag);
    if ((await read(p, q.core, "collectionExists", [terms.collectionId], tag))[0] !== true || binding.accepted || attr[0] !== 1n
      || attr[1] !== binding.generation || terms.generation !== binding.generation || !same(terms.bindingHash, binding.bindingHash)
      || same(binding.bindingHash, ZeroHash)) throw Error("Acceptance requires current claimed binding");
    const immutable: CollaboratorBindingTerms = (await read(p, d.components[0]!.address, "bindingTerms", [terms.collectionId, terms.generation], tag))[0];
    const count = (await read(p, registry, "collaboratorCount", [terms.collectionId, terms.generation], tag))[0];
    const emptyCapabilities = keccak256(coder.encode(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []]));
    if (immutable.mode !== 0n || immutable.threshold !== 0n || immutable.count === 0n || immutable.count > 32n || count !== immutable.count
      || !same(immutable.capabilityPolicySetHash, emptyCapabilities)) throw Error("Only original PRIMARY_ONLY collaborator terms supported");
    const rows: CollaboratorRow[] = [];
    for (let i = 0n; i < count; i++) {
      const r: CollaboratorRow = (await read(p, registry, "collaboratorAt", [terms.collectionId, terms.generation, i], tag))[0];
      if (r.accepted !== !same(r.collaboratorArtistId, ZeroHash) || r.accepted !== !same(r.acceptanceRecordHash, ZeroHash)) throw Error("Collaborator row join differs");
      rows.push(r);
    }
    const originalTerms = rows.map(({ account, role, shareLabelId }) => ({ account, role, shareLabelId }));
    if (!same(collaboratorSetHash(originalTerms), immutable.collaboratorSetHash)
      || !same(primaryOnlyCollaboratorBindingHash(d.chainId, registry, q.core, terms.collectionId, binding, originalTerms), binding.bindingHash)
      || ![1n, 2n].includes(binding.consentMode) || binding.saleConsentScope > 1n || binding.registryImmutabilityElection > 1n) throw Error("Immutable binding/row hash differs");
    const selected = rows.find(r => same(r.account, terms.account) && same(r.role, terms.role) && same(r.shareLabelId, terms.shareLabelId));
    if (!selected || selected.accepted) throw Error("Exact unaccepted collaborator row missing");
    const acceptedCount = (await read(p, d.components[1]!.address, "acceptedCount", [binding.bindingHash], tag))[0] as bigint;
    if (acceptedCount !== BigInt(rows.filter(r => r.accepted).length)) throw Error("Collaborator accepted count differs");
    const primaryRecord = hash((await read(p, d.components[3]!.address, "acceptanceRecord", [binding.bindingHash], tag))[0], true);
    const artistId = hash((await read(p, identity, "activeIdentity", [terms.account], tag))[0]);
    const a = await read(p, identity, "authorityState", [artistId], tag);
    const authority: CurrentArtistAuthority = { address: address(a[0]), authorityClass: a[1], status: a[2], identityRecordHash: hash(a[3]) };
    const capabilities: CollaboratorCapabilities = (await read(p, identity, "currentAuthorityCapabilities", [artistId], tag))[0];
    if (!same(authority.address, terms.account) || !ordinary(authority)
      || !same(capabilities.authorityAddress, authority.address) || capabilities.authorityClass !== authority.authorityClass || capabilities.status !== authority.status
      || authority.authorityClass !== 1n && same(capabilities.activationRecordHash, ZeroHash)) throw Error("Collaborator requires its own current ordinary principal");
    row = { binding, terms: immutable, rows, attribution: { state: attr[0], generation: attr[1] }, artistId, authority, capabilities,
      acceptedCount, primaryRecord, completesIfExecuted: acceptedCount + 1n === count && !same(primaryRecord, ZeroHash) };
    nativeCount = (await read(p, d.components[3]!.address, "artistNativeReceiptCount", [], tag))[0];
  }
  if (q.kind !== "proposeIdentity") {
    const signer = q.kind === "acceptIdentity" ? q.account : q.terms.account, direct = same(q.caller, signer) && q.authorization.signature === "0x";
    if (q.authorization.time < h.timestamp) throw Error("Collaborator deadline expired");
    if (!direct && q.authorization.signature === "0x" && bytes(await p.getCode(signer, tag), 65536) === "0x") throw Error("Empty relayed EOA proof");
    const signed = action.signing!, raw = bytes(await p.call({ ...signed.digestCall, blockTag: tag, gasLimit: 5_000_000n }), 32);
    if (!same(raw, signed.payload.digest)) throw Error("Original signing digest getter differs");
    const artistId = registration?.predictedArtistId ?? row!.artistId;
    const replay: CurrentArtistReplay = (await read(p, registry, "artistAuthorizationState", [artistId, signed.payload.digest, q.authorization.nonce], tag))[0];
    nonrevoked(replay);
    if (direct && q.authorization.nonce !== (registration ? registration.nonce.firstUnused : replay.nextUnusedNonce)) throw Error("Direct authorization requires first unused nonce");
    signing = { signer, direct, digest: signed.payload.digest, replay, signatureVerified: false };
  }
  await unchanged(p, h);
  const body = { deployment: d, prepared: action, ...h, proposal, role, registration, row, signing, snapshots, nativeCount, simulationRequired: true as const };
  return freeze({ ...body, captureHash: digest(body) });
}
/** Historical capture is independently re-read; changed admission facts require a new capture. */
export async function simulateCollaborator(p: Reader, input: CollaboratorCapture, options: { readonly gasLimit: bigint; readonly blockTag?: number }): Promise<CollaboratorSimulation> {
  keys(options, ["gasLimit"], ["blockTag"]);
  const c = saved(input), gasLimit = uint(options.gasLimit), tag = options.blockTag === undefined ? c.blockNumber : number(options.blockTag);
  if (gasLimit === 0n || gasLimit > 100_000_000n || tag < c.blockNumber) throw Error("Invalid bounded simulation options");
  equal(await captureCollaborator(p, c.deployment, c.prepared, { blockTag: c.blockNumber }), c, "Historical capture differs");
  const fresh = tag === c.blockNumber ? c : await captureCollaborator(p, c.deployment, c.prepared, { blockTag: tag });
  for (const field of ["configurationHash", "proposal", "role", "registration", "row", "signing"] as const) equal(fresh[field], c[field], field + " changed; capture again");
  const q = c.prepared.request;
  const expected = q.kind === "proposeIdentity" ? collaboratorProposalHash(q.chainId, q.registry, q.proposal, q.caller)
    : q.kind === "acceptIdentity" ? fresh.registration!.predictedArtistId
    : collaboratorAcceptanceRecordHash(q.chainId, q.registry, q.core, q.terms, fresh.row!.authority.authorityClass, q.authorization.nonce, fresh.timestamp);
  const raw = bytes(await p.call({ ...c.prepared.call, from: q.caller, blockTag: tag, gasLimit }), 32);
  if (!same(raw, expected)) throw Error("Simulated original return differs");
  await unchanged(p, fresh);
  return freeze({ capture: c, observation: fresh, returnData: raw, recordHash: expected, targetCallOnly: true as const });
}
/** One ordinary zero-value CALL. Capture again after each dependent proposal/identity/row step. */
export function createCollaboratorSafePlan(input: CollaboratorCapture, options: { readonly safe: Address; readonly title: string }): SafeCallPlan {
  keys(options, ["safe", "title"]);
  const c = saved(input);
  if (!same(address(options.safe), c.prepared.request.caller)) throw Error("Safe differs from prepared actual actor");
  return createSafeCallPlan(c.deployment.chainId, options.title, [{ safe: address(options.safe),
    intent: "Artist operation " + c.prepared.operation + ": " + c.prepared.request.kind + "; exact admission simulation required",
    call: c.prepared.call, abi: CURRENT_ARTIST_COLLABORATOR_ABI }]);
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
export async function inspectCollaboratorReceipt(p: ReceiptReader, input: CollaboratorCapture, options: {
  readonly transactionHash: Hex; readonly execution: "direct" | "safe";
}): Promise<CollaboratorReceipt> {
  keys(options, ["transactionHash", "execution"]);
  const c = saved(input), d = c.deployment, q = c.prepared.request, transactionHash = hash(options.transactionHash);
  if (options.execution !== "direct" && options.execution !== "safe") throw Error("Unknown receipt execution mode");
  equal(await captureCollaborator(p, d, c.prepared, { blockTag: c.blockNumber }), c, "Historical capture differs");
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
  const identity = d.components[2]!.address, acceptance = d.components[3]!.address, archive = d.components[8]!.address;
  let record: Hex, artistId: Hex | null = null, allocationNonce: bigint | null = null;
  const signatureProof = c.signing ? { signer: c.signing.signer, digest: c.signing.digest, direct: c.signing.direct } : null;
  if (q.kind !== "proposeIdentity" && q.authorization.time < h.timestamp) throw Error("Mined collaborator deadline expired");
  if (q.kind === "proposeIdentity") {
    record = collaboratorProposalHash(d.chainId, d.registry.address, q.proposal, q.caller);
    const t = q.proposal;
    event(d.components[1]!.address, "CollaboratorIdentityProposed", [1n, t.account, t.identityRecordHash, t.identityRecordURI, q.caller, t.reasonHash, t.reasonURI]);
  } else if (q.kind === "acceptIdentity") {
    const registered = event(identity, "ArtistIdentityRegistered");
    allocationNonce = registered.registrationNonce as bigint;
    record = collaboratorIdentityId(d.chainId, d.registry.address, q.account, q.identityRecordHash, allocationNonce);
    artistId = record;
    if (!c.proposal || !c.registration || allocationNonce < c.registration.allocationNonce) throw Error("Registration allocation precedes capture");
    encodedEqual(["uint16", "bytes32", "address", "bytes32", "string", "uint256"], Array.from(registered),
      [1n, record, q.account, q.identityRecordHash, c.proposal.proposal.identityRecordURI, allocationNonce], "Identity registration event differs");
    event(identity, "ArtistIdentityDisplayNameStored", [record, q.identityRecordHash, q.displayName]);
  } else {
    if (!c.row) throw Error("Missing captured collaborator row");
    artistId = c.row.artistId;
    record = collaboratorAcceptanceRecordHash(d.chainId, d.registry.address, q.core, q.terms, c.row.authority.authorityClass, q.authorization.nonce, h.timestamp);
    event(acceptance, "CollaboratorAccepted", [1n, q.terms.collectionId, q.terms.account, artistId, q.terms.generation,
      q.terms.role, q.terms.shareLabelId, c.row.authority.authorityClass, q.authorization.nonce, h.timestamp, record, q.terms.bindingHash]);
  }
  const evidenceId = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), d.chainId, d.registry.address, d.coordinator.address, c.prepared.operation, q.caller, record])) as Hex;
  const metadata = await read(p, archive, "artistEvidenceMetadataV2", [evidenceId, 1n], h.blockNumber);
  const evidence = bytes((await read(p, archive, "artistEvidenceBytesV2", [evidenceId, 1n], h.blockNumber, 24640))[0], 24575);
  if (!same(keccak256(evidence), metadata[0]) || BigInt((evidence.length - 2) / 2) !== metadata[2] || metadata[3] !== BigInt(h.blockNumber)) throw Error("Original Archive content metadata differs");
  const pointerCode = bytes(await p.getCode(address(metadata[1]), h.blockNumber), 24576);
  if (pointerCode !== "0x00" + evidence.slice(2)) throw Error("Archive retained STOP bytes differ");
  const envelope = decode(["uint16", "bytes32", "uint16", "address", "bytes32", SNAPSHOT + "[7]", SNAPSHOT + "[7]", "bytes"], evidence);
  encodedEqual(["uint16", "bytes32", "uint16", "address", "bytes32"], envelope.slice(0, 5),
    [1n, c.configurationHash, BigInt(c.prepared.operation), q.caller, record], "Archive operation identity differs");
  const payload = bytes(envelope[7], 24575);
  let completion: CollaboratorReceipt["completion"] = null, observedRole: CollaboratorCapture["role"] = null;
  if (q.kind === "proposeIdentity") {
    const types = [COLLABORATOR_PROPOSAL_TUPLE, "bytes32", "uint64"], v = decode(types, payload);
    encodedEqual([COLLABORATOR_PROPOSAL_TUPLE], [v[0]], [q.proposal], "Archived identity proposal differs");
    if (!c.role || v[2] < c.role.revision || v[2] === c.role.revision && !same(v[1], c.role.mutationHash)) throw Error("Archived admin role mutation differs");
    observedRole = { role: c.role.role, mutationHash: hash(v[1], true), revision: v[2] };
  } else if (q.kind === "acceptIdentity") {
    const types = [COLLABORATOR_PROPOSAL_STATE_TUPLE, COLLABORATOR_AUTHORIZATION_TUPLE, PROOF, "bytes", "string", "uint256"], v = decode(types, payload);
    encodedEqual(types, v, [c.proposal, q.authorization, signatureProof, q.document, q.displayName, allocationNonce], "Archived registration proposal/proof/document/allocation differs");
  } else {
    const types = [COLLABORATOR_BINDING_TUPLE, COLLABORATOR_ACCEPTANCE_TUPLE, "bytes32", COLLABORATOR_AUTHORIZATION_TUPLE,
      PROOF, COLLABORATOR_BINDING_TERMS_TUPLE, "uint32", "uint32", "bytes32", "bool"];
    const v = decode(types, payload), r = c.row!;
    encodedEqual(types.slice(0, 6), v.slice(0, 6), [r.binding, q.terms, r.artistId, q.authorization, signatureProof, r.terms], "Archived collaborator terms/role/label/principal/proof differ");
    const priorCount: bigint = v[6], count: bigint = v[7], primaryRecord = hash(v[8], true), complete: boolean = v[9];
    if (priorCount < r.acceptedCount || count !== priorCount + 1n || count > r.terms.count
      || !same(r.primaryRecord, ZeroHash) && !same(primaryRecord, r.primaryRecord)
      || complete !== (count === r.terms.count && !same(primaryRecord, ZeroHash))) throw Error("Archived row completion differs");
    completion = { priorCount, count, primaryRecord, complete };
    if (complete) {
      event(d.components[4]!.address, "ArtistAttributionStateChanged", [1n, q.terms.collectionId, 2n, q.terms.generation, 1n,
        q.terms.account, r.authority.authorityClass, record, ZeroHash, ""]);
    } else if (logs.some(l => same(l.address, d.components[4]!.address) && same(l.topics[0], abi.getEvent("ArtistAttributionStateChanged")!.topicHash))) {
      throw Error("Partial row unexpectedly changed attribution");
    }
  }
  for (let i = 0; i < 7; i++) {
    const before: CollaboratorSnapshot = envelope[5][i], after: CollaboratorSnapshot = envelope[6][i], captured = c.snapshots[i]!;
    const selected = q.kind === "acceptRow" ? i < 5 : i === 1 || i === 2;
    if (!selected) {
      const empty = { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash };
      equal(before, empty, "Unexpected owner before snapshot"); equal(after, empty, "Unexpected owner after snapshot");
      continue;
    }
    if (!same(before.domainId, domains[i]) || !same(after.domainId, domains[i]) || before.revision < captured.revision) throw Error("Archive owner snapshot domain/clock differs");
    if (before.revision === captured.revision) equal(before, captured, "Archive captured owner snapshot differs");
    const changed = q.kind === "proposeIdentity" ? i === 1 : q.kind === "acceptIdentity" ? i === 1 || i === 2
      : i === 1 || i === 2 || i === 3 || completion!.complete && (i === 0 || i === 4);
    if (!changed) {
      equal(after, before, "Unchanged recipe owner mutated");
    } else {
      const changesTip = q.kind === "acceptIdentity" ? i === 2 : q.kind === "acceptRow" && i === 3;
      if (after.revision !== before.revision + 1n || same(before.stateRoot, after.stateRoot)
        || (changesTip ? same(before.recordChainTip, after.recordChainTip) : !same(before.recordChainTip, after.recordChainTip))) throw Error("Original owner transition differs");
    }
  }
  let native: CollaboratorReceipt["native"] = null, observedReplay: CurrentArtistReplay | null = null;
  let observedAccountNonce: CollaboratorReceipt["observedAccountNonce"] = null;
  if (q.kind !== "proposeIdentity") {
    const ownerIndex = q.kind === "acceptIdentity" ? 2 : 3, owner = d.components[ownerIndex]!.address;
    const first = c.nativeCount!, count = (await read(p, owner, "artistNativeReceiptCount", [], h.blockNumber))[0] as bigint;
    if (count <= first || count - first > 128n) throw Error("Native receipt search exceeds bounded captured cursor");
    for (let i = first; i < count; i++) {
      const r = (await read(p, owner, "artistNativeReceiptAt", [i], h.blockNumber))[0];
      if (!same(r.recordHash, record)) continue;
      if (native || r.operation !== BigInt(c.prepared.operation) || !same(r.artistId, artistId)
        || r.collectionId !== (q.kind === "acceptRow" ? q.terms.collectionId : 0n)) throw Error("Original native receipt correspondence differs");
      const revision = (await read(p, owner, "artistNativeReceiptRevisionAt", [i], h.blockNumber))[0] as bigint;
      if (revision !== envelope[6][ownerIndex].revision) throw Error("Native receipt admission revision differs");
      native = { owner, index: i, revision, operation: r.operation, artistId: hash(r.artistId), collectionId: r.collectionId, recordHash: hash(r.recordHash) };
    }
    if (!native) throw Error("Original native receipt missing");
    observedReplay = (await read(p, d.registry.address, "artistAuthorizationState", [artistId, c.signing!.digest, q.authorization.nonce], h.blockNumber))[0] as CurrentArtistReplay;
    if (!observedReplay.digestObserved || !observedReplay.nonceConsumed) throw Error("Mined principal replay consumption missing");
    if (q.kind === "acceptIdentity") {
      const n = await read(p, d.registry.address, "collaboratorRegistrationNonceState", [q.account, q.authorization.nonce], h.blockNumber);
      if (n[0] !== true) throw Error("Mined account registration nonce missing");
      const scope = keccak256(coder.encode(["address", "bytes32"], [q.account, c.signing!.digest])) as Hex;
      const cell: CollaboratorReplayCell = (await read(p, identity, "replayCell", [replayKey(d, 2, "identity_authority.replay.collaborator_account_digest", scope)], h.blockNumber))[0];
      if (cell.status !== 2n || cell.kind !== 1n || !same(cell.commitment, c.signing!.digest) || cell.touchedRevision !== envelope[6][2].revision) throw Error("Mined account digest receipt differs");
      observedAccountNonce = { used: true, firstUnused: n[1] };
    }
  }
  event(archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], metadata[1], metadata[2]]);
  for (let i = 1; i < events.length; i++) if (events[i - 1]!.logIndex >= events[i]!.logIndex) throw Error("Original event/archive order differs");
  const archiveIndex = events[events.length - 1]!.logIndex;
  if (options.execution === "safe") {
    const successTopic = safeEvents.getEvent("ExecutionSuccess")!.topicHash;
    const hits = logs.filter(l => same(l.address, q.caller) && same(l.topics[0], successTopic));
    if (hits.length !== 1 || logs.some(l => same(l.address, q.caller) && same(l.topics[0], safeEvents.getEvent("ExecutionFailure")!.topicHash))) throw Error("Expected Safe success without failure");
    const iface = hits[0]!.topics.length === 2 ? safeIndexedEvents : safeEvents;
    const success = event(q.caller, "ExecutionSuccess", undefined, iface);
    hash(success[0]);
    if (events[events.length - 1]!.logIndex <= archiveIndex) throw Error("Safe success precedes original evidence");
  }
  await unchanged(p, h);
  return freeze({ capture: c, transactionHash, blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp,
    recordHash: record, artistId, allocationNonce, evidenceId, evidenceContentHash: hash(metadata[0]), archiveEvidence: evidence,
    observedRole, completion, native, observedReplay, observedAccountNonce, events, historicalEvidenceOnly: true as const });
}

export interface CollaboratorReceipt extends Block {
  readonly capture: CollaboratorCapture; readonly transactionHash: Hex; readonly recordHash: Hex;
  readonly artistId: Hex | null; readonly allocationNonce: bigint | null;
  readonly evidenceId: Hex; readonly evidenceContentHash: Hex; readonly archiveEvidence: Hex;
  readonly observedRole: CollaboratorCapture["role"];
  readonly completion: { readonly priorCount: bigint; readonly count: bigint; readonly primaryRecord: Hex; readonly complete: boolean } | null;
  readonly native: { readonly owner: Address; readonly index: bigint; readonly revision: bigint; readonly operation: bigint;
    readonly artistId: Hex; readonly collectionId: bigint; readonly recordHash: Hex } | null;
  readonly observedReplay: CurrentArtistReplay | null;
  readonly observedAccountNonce: { readonly used: boolean; readonly firstUnused: bigint } | null;
  readonly events: readonly { readonly address: Address; readonly name: string; readonly logIndex: number }[];
  /** Complete original historical evidence; no current entitlement, Safe-owner or broader identity-schema certification. */
  readonly historicalEvidenceOnly: true;
}
