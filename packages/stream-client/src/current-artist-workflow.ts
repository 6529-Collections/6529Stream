import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { prepareCurrentArtistAction, normalizeCurrentArtistAction } from "./current-artist-operation.js";
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
const terms = {
  bindingRefusal: "(uint256 collectionId,uint64 generation,bytes32 bindingHash,bytes32 reasonHash,string reasonURI)", saleConsent: "(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)", royaltyFreeze: "(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)", contentFreeze: "(uint256 collectionId,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash)", authorizationRevocation: "(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce)"
} as const;
const methods = {
  bindingRefusal: ["refuseArtistBinding", "bindingRefusalDigest"], saleConsent: ["recordSaleConsent", "saleConsentDigest"], royaltyFreeze: ["authorizeArtistRoyaltyFreeze", "royaltyFreezeDigest"], contentFreeze: ["authorizeArtistContentFreeze", "contentFreezeDigest"], authorizationRevocation: ["revokeArtistAuthorization", "authorizationRevocationDigest"]
} as const;
const writes = Object.entries(terms).flatMap(([k, t]) => {
  const names = methods[k as keyof typeof methods];
  return [`function ${names[0]}(${t},${A}) returns(bytes32)`, `function ${names[1]}(${t},${A}) view returns(bytes32)`];
});
const abi = new Interface([...writes,
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
  keys(v, ["chainId", "registry", "coordinator", "components"]);
  if (!Array.isArray(v.components) || v.components.length !== 16) {
    throw Error("Expected exactly16 component pins");
  }
  const d = {
    chainId: uint(v.chainId), registry: pin(v.registry), coordinator: pin(v.coordinator), components: v.components.map(pin)
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
  await Promise.all([d.coordinator, ...d.components].map(async (x) => {
    const code = bytes(await p.getCode(x.address, tag), 65536);
    if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), x.codeHash)) {
      throw Error("Pinned Artist runtime differs");
    }
  }));
  const [suite] = await read(p, d.coordinator.address, "suiteConfiguration", [], tag);
  const ordered = [...suite.owners, suite.registry, suite.archive, suite.core, suite.mintManager, suite.roleRegistry, suite.metadata, suite.primaryResolver, suite.royaltyResolver, suite.validator];
  equal(ordered.map(address), d.components.map(p => p.address), "Suite component pins differ");
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
  keys(v, ["deployment", "action", "blockNumber", "blockHash", "timestamp", "configurationHash", "authority", "binding", "replay", "revocationTarget", "simulationRequired", "captureHash"]);
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
  if (q.chainId !== d.chainId || !same(q.registry, d.registry.address)) {
    throw Error("Action deployment differs");
  }
  const h = await context(p, d, tag, true);
  if (m.core !== undefined && !same(m.core, d.components[9]!.address)) {
    throw Error("Signed Core differs");
  }
  if (m.deadline < h.timestamp) {
    throw Error("Artist authorization expired");
  }
  let b: CurrentArtistBinding | null = null;
  if (q.kind !== "authorizationRevocation") {
    if ((await read(p, d.components[9]!.address, "collectionExists", [m.collectionId], tag))[0] !== true) {
      throw Error("Unknown collection");
    }
    b = binding((await read(p, d.components[0]!.address, "binding", [m.collectionId], tag))[0]);
    if (!same(b.artistId, q.artistId) || b.bindingHash === ZeroHash) {
      throw Error("Binding/replay identity differs");
    }
    const [state, generation] = await read(p, d.components[4]!.address, "attributionState", [m.collectionId], tag);
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
      if (!b.accepted || !([2n, 3n].includes(state) || q.kind !== "saleConsent" && state === 4n)) {
        throw Error("Binding is not eligible");
      }
    }
    if (q.kind === "saleConsent" || q.kind === "contentFreeze") {
      const [t] = await read(p, d.components[0]!.address, "bindingTerms", [m.collectionId, b.generation], tag);
      if (b.consentMode !== 1n || t.mode !== 0n || t.threshold !== 0n || t.count > 32n || (await read(p, d.components[1]!.address, "acceptedCount", [b.bindingHash], tag))[0] !== t.count) {
        throw Error("Collaborator/consent profile is not ready");
      }
    }
  }
  const raw = await read(p, d.components[2]!.address, "authorityState", [q.artistId], tag);
  const authority = {
    address: address(raw[0]), authorityClass: raw[1] as bigint, status: raw[2] as bigint, identityRecordHash: hash(raw[3])
  };
  if (!same(authority.address, q.signer) || !ordinary(authority, [20, 21, 54].includes(Number(action.operationId)))) {
    throw Error("Current Artist authority differs");
  }
  if (authority.authorityClass !== 1n) {
    const [caps] = await read(p, d.registry.address, "currentAuthorityCapabilities", [q.artistId], tag);
    const required = action.operationId === 16n ? 1024n : action.operationId === 20n ? 32n : action.operationId === 21n ? 128n : 0n;
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
  const state = await replayRead(p, d, q.artistId, action.payload.digest, m.nonce, tag);
  if (state.nonceConsumed || state.nonceRevoked || state.digestRevoked) {
    throw Error("Artist authorization consumed/revoked");
  }
  if (q.mode === "direct" && m.nonce !== state.nextUnusedNonce) {
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
    deployment: d, action, ...h, authority, binding: b, replay: state, revocationTarget, simulationRequired: true as const
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
/** Independent ordered ordinary CALLs; dependent state must be mined and recaptured between steps. */
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
  const lane = (c: CurrentArtistCapture) =>     c.action.request.registry.toLowerCase() + ":" + c.action.request.artistId.toLowerCase();
  for (const c of items) {
    const nonceKey = lane(c) + ":nonce:" + c.action.request.message.nonce.toString();
    if (authorizations.has(nonceKey)) {
      throw Error("Duplicate Artist authorization nonce in Safe plan");
    }
    authorizations.add(nonceKey);
    authorizationDigests.add(lane(c) + ":digest:" + c.action.payload.digest.toLowerCase());
  }
  for (const c of items) {
    const q = c.action.request;
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
function originalRecord(c: CurrentArtistCapture, time: bigint): Hex {
  const q = c.action.request;
  const m = q.message as any;
  const [t] = abi.decodeFunctionData(c.action.method, c.action.call.data);
  const chain = c.deployment.chainId;
  const host = c.deployment.registry.address;
  const core = c.deployment.components[9]!.address;
  const artist = q.artistId;
  const signer = q.signer;
  const cl = c.authority.authorityClass;
  const n = m.nonce;
  const common = [chain, host];
  let types: string[];
  let values: unknown[];
  switch (q.kind) {
    case "bindingRefusal":
      types = ["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "bytes32", "address", "uint8", "bytes32", "uint256", "uint64"];
      values = ["0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed", ...common, core, t.collectionId, t.generation, t.bindingHash, artist, signer, cl, t.reasonHash, n, time];
      break;
    case "saleConsent":
      types = ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"), ...common, t.saleAdapter, core, t.collectionId, t.saleId, t.saleConfigHash, artist, signer, cl, n, time];
      break;
    case "royaltyFreeze":
      types = ["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"), ...common, t.resolver, t.collectionId, t.revenueClass, t.expectedAssignmentHash, artist, signer, cl, n, time];
      break;
    case "contentFreeze":
      types = ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32[]", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"];
      values = [id("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"), ...common, t.metadataContract, core, t.collectionId, t.lockClasses, t.expectedStateHash, artist, signer, cl, n, time];
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
  const [t, auth] = abi.decodeFunctionData(a.method, a.call.data);
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
  if (h.timestamp > m.deadline) {
    throw Error("Receipt execution exceeded authorization deadline");
  }
  if (!same(h.blockHash, blockHash) || !same(h.configurationHash, c.configurationHash)) {
    throw Error("Receipt block/configuration differs");
  }
  const recordHash = originalRecord(c, h.timestamp);
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
  const cl = c.authority.authorityClass;
  const n = m.nonce;
  const at = h.timestamp;
  const owner = d.components[6]!.address;
  switch (q.kind) {
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
    case "saleConsent": {
      event(owner, "ArtistSaleConsentRecorded", [1, t.collectionId, t.saleConfigHash, q.signer, t.saleId, cl, n, at, recordHash]);
      const [v] = await read(p, d.registry.address, "saleConsentRecord", [recordHash], tag);
      const expected = [recordHash, t, q.artistId, q.signer, cl, n, at, c.binding!.generation, c.binding!.bindingHash];
      if (!same(coder.encode([abi.getFunction("saleConsentRecord")!.outputs![0]!], [v]), coder.encode([abi.getFunction("saleConsentRecord")!.outputs![0]!], [expected]))) {
        throw Error("Historical sale consent differs");
      }
      break;
    }
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
  const mask = q.kind === "authorizationRevocation" ? 4 : q.kind === "bindingRefusal" ? 21 : 87;
  const writeMask = q.kind === "authorizationRevocation" ? 4 : q.kind === "bindingRefusal" ? 21 : 68;
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
  const proof = [q.signer, a.payload.digest, q.mode === "direct"];
  const authority = [q.artistId, q.signer, cl, c.authority.status];
  let payloadTypes: string[];
  let payloadValues: unknown[];
  if (q.kind === "authorizationRevocation") {
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
      const facts = decode(["address", "bytes32", "bytes32", "bytes32", "bytes4", "uint256", "bytes32"], decoded[5]);
      if (facts[5] !== t.collectionId || !same(facts[6], t.saleConfigHash) || facts[4] === "0x00000000" || facts[4] === "0xffffffff") {
        throw Error("Archive sale facts differ");
      }
      address(facts[0]);
      hash(facts[1]);
      hash(facts[2]);
      hash(facts[3]);
      payloadValues.push(decoded[5]);
    }
  }
  if (!same(coder.encode(payloadTypes, payloadValues), v[7])) {
    throw Error("Archive request/authority/proof differs");
  }
  const observedReplay = await replayRead(p, d, q.artistId, a.payload.digest, m.nonce, tag);
  if (!observedReplay.digestObserved || !observedReplay.nonceConsumed || observedReplay.digestRevoked || observedReplay.nonceRevoked) {
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
    capture: c, transactionHash, blockNumber: tag, blockHash, recordHash, evidenceId, events: refs.sort((a, b) => a.logIndex - b.logIndex), observedReplay
  });
}
