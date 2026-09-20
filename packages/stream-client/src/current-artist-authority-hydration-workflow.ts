import { AbiCoder, Interface, ParamType, ZeroHash, ZeroAddress, getAddress, id, isHexString, keccak256, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import {
  normalizeArtistAuthorityHydrationCall, artistAuthorityHydrationCommitment,
  artistAuthorityHydrationEvidenceId, artistAuthorityHydrationOwnerAfter,
  artistAuthorityHydrationReplayKey, decodeArtistAuthorityHydrationEvidence,
  decodeArtistAuthorityHydrationProfileEvidence, decodeArtistHydrationOwnerState,
  encodeArtistAuthorityHydrationEvidence, encodeArtistAuthorityHydrationProfileEvidence,
  encodeArtistHydrationMultipleBundle,
  ARTIST_HYDRATION_SNAPSHOT_TUPLE, ARTIST_HYDRATION_CHECKPOINT_TUPLE,
  ARTIST_HYDRATION_REPLAY_CELL_TUPLE, ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE,
  ARTIST_HYDRATION_SUITE_TUPLE, ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_IDENTITY_TUPLE,
  type ArtistHydrationSnapshot, type ArtistHydrationCheckpoint,
  type ArtistHydrationNativeReceipt, type ArtistHydrationSuite,
  type ArtistHydrationQuery, type ArtistHydrationOwnerData,
  type ArtistHydrationNonceWord,
} from "./current-artist-authority-hydration.js";

export interface ArtistHydrationCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}
/** Original Coordinator order: owners[7], Registry, Archive, Core, Manager, roles, metadata, primary, royalty, validator. */
export interface ArtistHydrationSuitePins {
  readonly registry: ArtistHydrationCodePin;
  readonly coordinator: ArtistHydrationCodePin;
  readonly components: readonly ArtistHydrationCodePin[];
}
export interface ArtistAuthorityHydrationDeployment {
  readonly chainId: bigint;
  readonly source: ArtistHydrationSuitePins;
  readonly destination: ArtistHydrationSuitePins;
}
type Call = ReturnType<typeof normalizeArtistAuthorityHydrationCall>;
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
export interface ArtistHydrationNonceInventory {
  readonly kind: bigint;
  readonly key: Hex;
  readonly words: readonly ArtistHydrationNonceWord[];
}
export interface ArtistHydrationLane {
  readonly kind: bigint;
  readonly key: Hex;
  readonly tip: Hex;
  readonly count: bigint;
}
export interface ArtistHydrationPayloadCatalog {
  readonly host: Address;
  readonly rows: readonly { readonly pointer: Address; readonly payloadType: Hex; readonly payloadHash: Hex }[];
}
export interface ArtistAuthorityHydrationCapture {
  readonly deployment: ArtistAuthorityHydrationDeployment;
  readonly prepared: Call;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly configurationHash: Hex;
  readonly sourceSuite: ArtistHydrationSuite;
  readonly destinationSuite: ArtistHydrationSuite;
  readonly checkpoints: readonly ArtistHydrationCheckpoint[];
  readonly journals: readonly (readonly ArtistHydrationNativeReceipt[])[];
  readonly nonceIndexes: readonly ArtistHydrationNonceInventory[];
  readonly lanes: readonly ArtistHydrationLane[];
  readonly payloadCatalogs: readonly ArtistHydrationPayloadCatalog[];
  readonly query: ArtistHydrationQuery;
  readonly ownerData: readonly ArtistHydrationOwnerData[];
  readonly before: readonly ArtistHydrationSnapshot[];
  readonly after: readonly ArtistHydrationSnapshot[];
  readonly commitment: Hex;
  readonly evidenceId: Hex;
  /** The original actual-caller call succeeded at this concrete block. It does not authorize a later call. */
  readonly simulated: true;
  readonly captureHash: Hex;
}
export interface ArtistAuthorityHydrationReceipt {
  readonly capture: ArtistAuthorityHydrationCapture;
  readonly transactionHash: Hex;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly commitment: Hex;
  readonly evidenceId: Hex;
  readonly events: readonly { readonly address: Address; readonly event: string; readonly logIndex: number }[];
  /** End-of-block observations can include later native writes; the archived snapshots prove the atomic operation. */
  readonly observedOwners: readonly ArtistHydrationSnapshot[];
}
const coder = AbiCoder.defaultAbiCoder();
const MAX_EVIDENCE = 24_575;
const MAX_RPC = 1_048_576;
const MAX_CALL = 2_097_152;
const DOMAINS = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
const abi = new Interface([
  "function core() view returns(address)", "function mintManager() view returns(address)",
  "function operationCoordinator() view returns(address)", "function artistRegistry() view returns(address)",
  "function archiveV2() view returns(address)", "function deploymentChainId() view returns(uint256)",
  "function domainId() view returns(bytes32)", "function configurationHash() view returns(bytes32)",
  `function authorityHydrationSuite() view returns(${ARTIST_HYDRATION_SUITE_TUPLE})`,
  "function supportsInterface(bytes4) view returns(bool)",
  "function gasParameterInfo(bytes32) view returns(uint256,uint256,uint8,uint64)",
  "function getSatellitePointer(bytes32) view returns(address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64)",
  "function importedHistoryBindingCount() view returns(uint256)",
  "function importedHistoryBinding(uint256) view returns(address,uint64,bytes32,bytes32)",
  "function artistHistoryPredecessorBinding(address) view returns(bool,bytes32,uint256)",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  "function importedLaneVerified(uint8,bytes32) view returns(bool,bytes32,uint64)",
  "function artistHistoryLane(uint8,bytes32) view returns(bytes32,uint64)",
  `function ownerStateSnapshotV2() view returns(${ARTIST_HYDRATION_SNAPSHOT_TUPLE})`,
  `function authorityCheckpoint() view returns(${ARTIST_HYDRATION_CHECKPOINT_TUPLE})`,
  `function authorityReplayAt(uint256) view returns(bytes32,${ARTIST_HYDRATION_REPLAY_CELL_TUPLE})`,
  `function replayCell(bytes32) view returns(${ARTIST_HYDRATION_REPLAY_CELL_TUPLE})`,
  `function importedAuthorityReplayCell(bytes32) view returns(${ARTIST_HYDRATION_REPLAY_CELL_TUPLE})`,
  "function authorityNonceIndexAt(uint256) view returns((uint8 kind,bytes32 key,uint256 prefixCount))",
  "function authorityNonceWordAt(uint8,bytes32,uint256) view returns(uint256,uint256[32],bool)",
  "function authorityHydrationCommitment() view returns(bytes32)",
  `function authorityHydrationState(${ARTIST_HYDRATION_QUERY_TUPLE}) view returns(bytes)`,
  `function authorityLivingIdentityHydrationState(${ARTIST_HYDRATION_QUERY_TUPLE}) view returns(bytes)`,
  `function authorityDelegationHydrationState(${ARTIST_HYDRATION_QUERY_TUPLE}) view returns(bytes)`,
  "function artistNativeReceiptCount() view returns(uint256)",
  `function artistNativeReceiptAt(uint256) view returns(${ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE})`,
  "function artistHistorySourceCursor(address) view returns(uint256)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns(uint256)",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32,address,uint32,uint64)",
  "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes)",
  "function storedPayloadCount() view returns(uint256)",
  "function storedPayloadAt(uint256) view returns(address,bytes32,bytes32)",
  "event ArtistAuthorityHydrated(uint16 schemaVersion,bytes32 indexed artistId,uint256 indexed collectionId,address indexed predecessorRegistry,bytes32 profile,bytes32 commitment)",
  "event MultipleArtistAuthorityHydrated(address indexed predecessor,bytes32 indexed commitment,bytes32[] artistIds,uint256[] collectionIds)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)",
  "event ArtistStoredPayload(uint16 schemaVersion,uint256 indexed index,bytes32 indexed payloadType,bytes32 indexed payloadHash,address pointer)",
]);
const safeAbi = new Interface([
  "function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const same = (a: unknown, b: unknown) => typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
function stable(v: unknown): string {
  if (v === null) return "null";
  if (typeof v === "bigint") return JSON.stringify(["bigint", v.toString()]);
  if (typeof v === "string" || typeof v === "boolean" || typeof v === "number") return JSON.stringify([typeof v, v]);
  if (Array.isArray(v)) return JSON.stringify(["array", v.map(stable)]);
  if (v && typeof v === "object") return JSON.stringify(["object", Object.keys(v).sort().map(k => [k, stable((v as Record<string, unknown>)[k])])]);
  throw Error("Unsupported captured value");
}
function equal(a: unknown, b: unknown): boolean { return stable(a) === stable(b); }
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { for (const child of Object.values(v)) freeze(child); Object.freeze(v); }
  return v;
}
function keys(v: unknown, expected: readonly string[]): asserts v is Record<string, unknown> {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...expected].sort().join()) throw Error("Unexpected object fields");
}
function addr(v: unknown): Address {
  if (typeof v !== "string") throw Error("Address required");
  const a = getAddress(v); if (a === ZeroAddress) throw Error("Nonzero address required"); return a as Address;
}
function hex(v: unknown, max: number): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or excessive bytes");
  return v.toLowerCase() as Hex;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && same(v, ZeroHash))) throw Error("Invalid bytes32");
  return v.toLowerCase() as Hex;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) throw Error("Concrete block number required"); return v;
}
function pin(v: unknown): ArtistHydrationCodePin {
  keys(v, ["address", "codeHash"]); return { address: addr(v.address), codeHash: hash(v.codeHash) };
}
function suitePins(v: unknown): ArtistHydrationSuitePins {
  keys(v, ["registry", "coordinator", "components"]);
  if (!Array.isArray(v.components) || v.components.length !== 16) throw Error("Sixteen fixed component pins required");
  if (Object.keys(v.components).join() !== Array.from({ length: 16 }, (_, i) => String(i)).join()) throw Error("Dense component pins required");
  const result = { registry: pin(v.registry), coordinator: pin(v.coordinator), components: v.components.map(pin) };
  if (!same(result.registry.address, result.components[7]!.address) || !same(result.registry.codeHash, result.components[7]!.codeHash)
    || new Set([...result.components.map(p => p.address), result.coordinator.address]).size !== 17) throw Error("Duplicate or inconsistent suite pins");
  return result;
}
function deployment(v: ArtistAuthorityHydrationDeployment): ArtistAuthorityHydrationDeployment {
  keys(v, ["chainId", "source", "destination"]);
  if (typeof v.chainId !== "bigint" || v.chainId <= 0n || v.chainId >= 1n << 256n) throw Error("Invalid chain ID");
  const d = { chainId: v.chainId, source: suitePins(v.source), destination: suitePins(v.destination) };
  if (same(d.source.registry.address, d.destination.registry.address) || same(d.source.coordinator.address, d.destination.coordinator.address)) throw Error("Distinct source and destination required");
  for (let i = 9; i < 16; ++i) if (!equal(d.source.components[i], d.destination.components[i])) throw Error("Non-Artist dependencies differ");
  return freeze(d);
}
function plain(p: ParamType, v: any): any {
  if (p.baseType === "array") return [...v].map(x => plain(p.arrayChildren!, x));
  if (p.baseType === "tuple") return Object.fromEntries(p.components!.map((c, i) => [c.name, plain(c, v[i])]));
  return v;
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number): Promise<any[]> {
  const f = abi.getFunction(name)!;
  const raw = hex(await p.call({ to, data: abi.encodeFunctionData(f, args), blockTag: tag }), MAX_RPC);
  const value = abi.decodeFunctionResult(f, raw);
  if (!same(abi.encodeFunctionResult(f, value), raw)) throw Error(`Noncanonical ${name} result`);
  return f.outputs.map((t, i) => plain(t, value[i]));
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Block unavailable");
  return { blockNumber: tag, blockHash: hash(b.hash) };
}
async function unchanged(p: Reader, b: { blockNumber: number; blockHash: Hex }) {
  if (!same((await header(p, b.blockNumber)).blockHash, b.blockHash)) throw Error("Observed block changed");
}
async function runtime(p: Reader, pin: ArtistHydrationCodePin, tag: number) {
  const code = hex(await p.getCode(pin.address, tag), 131_072);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), pin.codeHash)) throw Error("Pinned runtime differs");
}
async function suite(p: Reader, d: ArtistAuthorityHydrationDeployment, pins: ArtistHydrationSuitePins, tag: number): Promise<ArtistHydrationSuite> {
  for (const item of [pins.coordinator, ...pins.components]) await runtime(p, item, tag);
  const s = (await read(p, pins.coordinator.address, "authorityHydrationSuite", [], tag))[0] as ArtistHydrationSuite;
  const targets = [...s.owners, s.registry, s.archive, s.core, s.mintManager, s.roleRegistry, s.metadata, s.primaryResolver, s.royaltyResolver, s.validator];
  if (targets.length !== 16 || targets.some((a, i) => !same(a, pins.components[i]!.address))) throw Error("Suite differs from supplied pins");
  if ((await read(p, pins.coordinator.address, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Coordinator chain differs");
  for (const [fn, expected] of [["core", s.core], ["mintManager", s.mintManager], ["operationCoordinator", pins.coordinator.address]]) {
    if (!same((await read(p, s.registry, fn!, [], tag))[0], expected)) throw Error("Registry binding differs");
  }
  for (const [fn, expected] of [["artistRegistry", s.registry], ["operationCoordinator", pins.coordinator.address]]) {
    if (!same((await read(p, s.archive, fn!, [], tag))[0], expected)) throw Error("Archive binding differs");
  }
  if ((await read(p, s.archive, "artistArchiveMaxEvidenceBytesV2", [], tag))[0] !== BigInt(MAX_EVIDENCE)) throw Error("Unsupported Archive bound");
  for (let i = 0; i < 7; ++i) {
    const owner = s.owners[i]!;
    for (const [fn, expected] of [["core", s.core], ["mintManager", s.mintManager], ["artistRegistry", s.registry], ["operationCoordinator", pins.coordinator.address], ["archiveV2", s.archive], ["domainId", DOMAINS[i]]]) {
      if (!same((await read(p, owner, fn!, [], tag))[0], expected)) throw Error("Owner reciprocal binding differs");
    }
    if ((await read(p, owner, "deploymentChainId", [], tag))[0] !== d.chainId) throw Error("Owner chain differs");
  }
  return s;
}
async function context(p: Reader, d: ArtistAuthorityHydrationDeployment, tag: number, admission: boolean) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("Wrong chain");
  const source = await suite(p, d, d.source, tag);
  const destination = await suite(p, d, d.destination, tag);
  if (!same(source.primaryRevenueClass, destination.primaryRevenueClass)) throw Error("Revenue class differs");
  const configurationHash = hash((await read(p, d.destination.coordinator.address, "configurationHash", [], tag))[0]);
  if (admission) {
    const gas = await read(p, destination.registry, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS")], tag);
    if (gas[0] === 0n || gas[0] === (1n << 256n) - 1n || gas[2] !== 2n || gas[3] === 0n) throw Error("Invalid original History read gas profile");
    const pointer = await read(p, destination.core, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
    if (!same(pointer[0], destination.registry) || !same(pointer[1], d.destination.registry.codeHash) || pointer[9] === 0n) throw Error("Successor is not currently selected");
    if ((await read(p, destination.owners[2]!, "artistRegistryCutover", [], tag))[0]) throw Error("Successor already cut over");
  }
  return { source, destination, configurationHash };
}
function coordinates(d: ArtistAuthorityHydrationDeployment) {
  return { chainId: d.chainId, registry: d.destination.registry.address, coordinator: d.destination.coordinator.address,
    predecessorRegistry: d.source.registry.address, sourceCoordinator: d.source.coordinator.address };
}
function ownerEnvironment(d: ArtistAuthorityHydrationDeployment, s: ArtistHydrationSuite, i: number) {
  return { chainId: d.chainId, registry: s.registry, coordinator: d.destination.coordinator.address, archive: s.archive, owner: s.owners[i]!, domain: DOMAINS[i]! as Hex };
}
function boundedCount(value: bigint, max: number, name: string): number {
  if (value < 0n || value > BigInt(max)) throw Error(`Excessive ${name}`); return Number(value);
}
async function history(p: Reader, d: ArtistAuthorityHydrationDeployment, source: ArtistHydrationSuite, destination: ArtistHydrationSuite, tag: number) {
  const h = destination.owners[2]!;
  if ((await read(p, h, "importedHistoryBindingCount", [], tag))[0] !== 1n) throw Error("Exactly one predecessor binding required");
  const binding = await read(p, h, "importedHistoryBinding", [0n], tag);
  const predecessor = await read(p, h, "artistHistoryPredecessorBinding", [source.registry], tag);
  if (!same(binding[0], source.registry) || binding[1] > BigInt(tag) || same(binding[2], ZeroHash) || same(binding[3], ZeroHash)
    || predecessor[0] !== true || !same(predecessor[1], d.source.registry.codeHash) || predecessor[2] !== 1n) throw Error("Predecessor binding differs");
  const cutover = await read(p, source.registry, "artistRegistryCutover", [], tag);
  if (cutover[0] !== true || !same(cutover[1], destination.registry) || cutover[2] === 0n || cutover[2] > BigInt(tag)
    || (await read(p, source.registry, "importedHistoryBindingCount", [], tag))[0] !== 0n) throw Error("Unsupported predecessor cutover/history");
}
async function lane(p: Reader, source: ArtistHydrationSuite, destination: ArtistHydrationSuite, kind: bigint, key: Hex, count: bigint, tag: number): Promise<ArtistHydrationLane> {
  const [tip, n] = await read(p, source.registry, "artistHistoryLane", [kind, key], tag);
  const [verified, importedTip, importedCount] = await read(p, destination.owners[2]!, "importedLaneVerified", [kind, key], tag);
  if (verified !== true || n === 0n || n !== count || importedCount !== n || !same(tip, importedTip)) throw Error("Complete permanent lane proof differs");
  return { kind, key, tip: hash(tip), count: n };
}
async function inventory(p: Reader, source: ArtistHydrationSuite, destination: ArtistHydrationSuite, input: any, tag: number) {
  const request = input.request;
  const multiple = input.kind === "multiple";
  const delegation = input.kind === "delegation";
  const checkpoints: ArtistHydrationCheckpoint[] = [];
  const before: ArtistHydrationSnapshot[] = [];
  const journals: ArtistHydrationNativeReceipt[][] = [];
  for (let i = 0; i < 7; ++i) {
    const cp = (await read(p, source.owners[i]!, "authorityCheckpoint", [], tag))[0] as ArtistHydrationCheckpoint;
    if (!equal(cp, request.expectedSource[i]) || !same(cp.schema, id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"))
      || !same(cp.ownerState.domainId, DOMAINS[i]) || cp.replayCount > 512n || cp.nonceIndexCount > (multiple || delegation ? 128n : 1n)) throw Error("Source checkpoint differs or exceeds profile");
    const state = (await read(p, destination.owners[i]!, "ownerStateSnapshotV2", [], tag))[0] as ArtistHydrationSnapshot;
    const revision = i === 2 ? (multiple ? 1n + BigInt(request.artistIds.length + request.collections.length) : 3n) : 0n;
    if (state.revision !== revision || !same(state.domainId, DOMAINS[i])
      || (await read(p, destination.owners[i]!, "artistNativeReceiptCount", [], tag))[0] !== 0n
      || !same((await read(p, destination.owners[i]!, "authorityHydrationCommitment", [], tag))[0], ZeroHash)) throw Error("Destination is not empty for this hydration profile");
    const count = boundedCount((await read(p, source.owners[i]!, "artistNativeReceiptCount", [], tag))[0], 128, "source receipts");
    const rows: ArtistHydrationNativeReceipt[] = [];
    for (let j = 0; j < count; ++j) rows.push((await read(p, source.owners[i]!, "artistNativeReceiptAt", [BigInt(j)], tag))[0]);
    checkpoints.push(cp); before.push(state); journals.push(rows);
  }
  return { checkpoints, before, journals };
}
function queryFor(artistId: Hex, collectionId = 0n, policies: any[] = []): ArtistHydrationQuery {
  return { artistId, collectionId, bindingHash: ZeroHash as Hex, policies, records: [] };
}
function queries(input: any, journals: readonly (readonly ArtistHydrationNativeReceipt[])[], cp: readonly ArtistHydrationCheckpoint[]) {
  const r = input.request, multiple = input.kind === "multiple", delegation = input.kind === "delegation";
  const artistIds: Hex[] = multiple ? [...r.artistIds] : [r.artistId];
  const collections: any[] = multiple ? r.collections : [{ artistId: r.artistId, collectionId: r.collectionId, policies: r.policies }];
  const artists: any[] = artistIds.map(a => queryFor(a));
  const rows: any[] = collections.map(c => queryFor(c.artistId, c.collectionId, c.policies));
  const registrations = new Set<string>(), accepted = new Set<string>();
  const policyCounts = new Map<string, number>();
  let revocations = 0;
  const totalPolicies = collections.reduce((n, c) => n + c.policies.length, 0);
  if (totalPolicies > 128) throw Error("Excessive total policy selectors");
  for (let i = 0; i < 7; ++i) {
    const receipts = journals[i]!;
    if ((i === 0 || i === 3) && receipts.length !== collections.length) throw Error("Incomplete collection receipts");
    if ((i === 1 || i === 4 || i === 5) && receipts.length !== 0) throw Error("Unsupported source history");
    for (let j = 0; j < receipts.length; ++j) {
      const receipt = receipts[j]!;
      const artist = artists.find(a => same(a.artistId, receipt.artistId));
      if (!artist || same(receipt.recordHash, ZeroHash)) throw Error("Receipt Artist not selected");
      artist.records.push(receipt.recordHash);
      if (i === 2) {
        if (receipt.collectionId !== 0n) throw Error("Identity receipt scope differs");
        if (receipt.operation === 1n) {
          if (registrations.has(receipt.artistId) || !same(receipt.recordHash, receipt.artistId) || (!multiple && j !== 0)) throw Error("Invalid registration receipt");
          registrations.add(receipt.artistId);
        } else if (receipt.operation === 54n) ++revocations;
        else if (!delegation || ![25n, 26n, 27n].includes(receipt.operation)) throw Error("Unsupported Identity history");
      } else {
        const collection = rows.find(c => c.collectionId === receipt.collectionId && same(c.artistId, receipt.artistId));
        if (!collection) throw Error("Receipt collection not selected");
        const k = collection.collectionId.toString();
        if (i === 0 && receipt.operation === 1n && same(collection.bindingHash, ZeroHash)) collection.bindingHash = receipt.recordHash;
        else if (i === 3 && receipt.operation === 2n && !accepted.has(k)) accepted.add(k);
        else if (i === 6 && receipt.operation === 14n) policyCounts.set(k, (policyCounts.get(k) ?? 0) + 1);
        else if (!(delegation && i === 6 && receipt.operation === 16n)) throw Error("Unsupported collection history");
      }
    }
  }
  if (registrations.size !== artists.length) throw Error("Incomplete registration inventory");
  for (const row of rows) if (same(row.bindingHash, ZeroHash) || !accepted.has(row.collectionId.toString())
    || (policyCounts.get(row.collectionId.toString()) ?? 0) !== row.policies.length) throw Error("Incomplete binding/acceptance/policy inventory");
  for (let i = 0; i < 7; ++i) {
    const expected = i === 0 || i === 4 ? BigInt(2 * rows.length)
      : i === 2 ? (delegation ? BigInt(2 + journals[2]!.length + journals[6]!.length) : BigInt(artists.length + rows.length + totalPolicies + revocations + 1))
      : i === 3 ? BigInt(rows.length) : i === 6 ? BigInt(journals[6]!.length) : 0n;
    if (cp[i]!.ownerState.revision !== expected) throw Error("Unsupported source revision history");
  }
  const query = multiple ? rows[0] : { ...rows[0], records: journals.flat().map(r => r.recordHash) };
  return { artists, collections: rows, query };
}
async function guards(p: Reader, d: ArtistAuthorityHydrationDeployment, source: ArtistHydrationSuite, input: any, cp: readonly ArtistHydrationCheckpoint[], tag: number) {
  const data: any[] = [];
  for (let i = 0; i < 7; ++i) {
    const origins = input.request.replayOrigins[i];
    if (BigInt(origins.length) !== cp[i]!.replayCount) throw Error("Incomplete replay origin inventory");
    const row: any = { typedState: "0x", origins, sourceKeys: [], cells: [], nonces: [] };
    const seen = new Set<string>();
    for (let j = 0; j < origins.length; ++j) {
      const [key, cell] = await read(p, source.owners[i]!, "authorityReplayAt", [BigInt(j)], tag);
      const expected = artistAuthorityHydrationReplayKey({ chainId: d.chainId, registry: source.registry,
        coordinator: d.source.coordinator.address, archive: source.archive, owner: source.owners[i]!, domain: DOMAINS[i]! as Hex }, origins[j]);
      if (!same(key, expected) || cell.status === 0n || seen.has(key)
        || !equal(cell, (await read(p, source.owners[i]!, "replayCell", [key], tag))[0])) throw Error("Source replay inventory differs");
      seen.add(key); row.sourceKeys.push(key); row.cells.push(cell);
    }
    if (i !== 2 && cp[i]!.nonceIndexCount !== 0n) throw Error("Unsupported owner nonce history");
    data.push(row);
  }
  const nonceIndexes: ArtistHydrationNonceInventory[] = [];
  let prefixes = 0;
  const seen = new Set<string>();
  for (let i = 0; i < boundedCount(cp[2]!.nonceIndexCount, input.kind === "baseline" ? 1 : 128, "nonce indexes"); ++i) {
    const n = (await read(p, source.owners[2]!, "authorityNonceIndexAt", [BigInt(i)], tag))[0];
    const key = `${n.kind}:${n.key}`;
    if (seen.has(key) || n.prefixCount === 0n || (n.kind !== 1n && !(input.kind === "delegation" && n.kind === 2n))) throw Error("Unsupported or duplicate nonce index");
    seen.add(key);
    const count = boundedCount(n.prefixCount, 256, "nonce prefixes"); prefixes += count;
    if (prefixes > 256) throw Error("Excessive total nonce prefixes");
    const words: ArtistHydrationNonceWord[] = [];
    const wordKeys = new Set<string>();
    for (let j = 0; j < count; ++j) {
      const [prefix, levels, exhausted] = await read(p, source.owners[2]!, "authorityNonceWordAt", [n.kind, n.key, BigInt(j)], tag);
      if (wordKeys.has(prefix.toString())) throw Error("Duplicate nonce prefix");
      wordKeys.add(prefix.toString()); words.push({ prefix, words: levels, exhausted });
    }
    nonceIndexes.push({ kind: n.kind, key: n.key, words });
  }
  return { data, nonceIndexes };
}
async function typedState(p: Reader, owner: Address, method: string, query: ArtistHydrationQuery, profile: "baseline" | "delegation", index: number, tag: number) {
  const raw = hex((await read(p, owner, method, [query], tag))[0], MAX_EVIDENCE);
  const decoded = decodeArtistHydrationOwnerState(profile, index as 0, raw);
  return { raw, decoded: decoded as any };
}
function policyRecords(raw: any, profile: string): Hex[] {
  return profile === "delegation" ? raw.policies.map((p: any) => p.recordHash) : raw;
}
function multipleIdentity(raw: Hex): any {
  const t = ParamType.from(ARTIST_HYDRATION_IDENTITY_TUPLE);
  const decoded = coder.decode([t], raw);
  if (!same(coder.encode([t], decoded), raw)) throw Error("Noncanonical living identity");
  return plain(t, decoded[0]);
}
async function states(p: Reader, source: ArtistHydrationSuite, input: any, journal: readonly (readonly ArtistHydrationNativeReceipt[])[], q: ReturnType<typeof queries>, data: any[], indexes: readonly ArtistHydrationNonceInventory[], tag: number) {
  if (input.kind !== "multiple") {
    const principal = indexes.filter(n => n.kind === 1n && same(n.key, q.query.artistId));
    if (principal.length !== 1 || (input.kind === "baseline" && indexes.length !== 1)) throw Error("Incomplete principal nonce lane");
    data[2].nonces = principal[0]!.words;
    const decoded: any[] = [];
    for (let i = 0; i < 7; ++i) {
      const method = input.kind === "delegation" && [0, 2, 6].includes(i) ? "authorityDelegationHydrationState" : "authorityHydrationState";
      const value = await typedState(p, source.owners[i]!, method, q.query, input.kind, i, tag);
      data[i].typedState = value.raw; decoded.push(value.decoded);
    }
    // The original typed producers enforce their profile. These joins bind their output to the complete journals.
    const identity: any = input.kind === "delegation" ? decodeArtistHydrationOwnerState("baseline", 2, decoded[2].baseline) : decoded[2];
    const binding = decoded[0];
    if (!same(binding.item.artistId, q.query.artistId) || !same(binding.item.bindingHash, q.query.bindingHash)
      || !same(binding.item.artistAddress, identity.item.authorityAddress) || !same(binding.item.identityRecordHash, identity.item.identityRecordHash)
      || identity.nextRegistrationNonce !== 1n || identity.signatures.length !== q.query.records.length
      || !same(decoded[3].record, journal[3]![0]!.recordHash)) throw Error("Typed source records differ from journals");
    const policies = journal[6]!.filter(r => r.operation === 14n).map(r => r.recordHash);
    if (!equal(policyRecords(decoded[6], input.kind), policies)) throw Error("Policy order differs from native journal");
    if (input.kind === "delegation") {
      if (decoded[2].epoch !== 0n || indexes.length !== decoded[2].delegateNonces.length + 1) throw Error("Unsupported delegation epoch or nonce inventory");
      for (const n of decoded[2].delegateNonces) {
        const indexed = indexes.find(x => x.kind === 2n && same(x.key, n.key));
        if (!indexed || !equal(indexed.words, n.words)) throw Error("Delegate nonce words differ from checkpoint inventory");
      }
      if (!equal(decoded[2].revisions.map((r: any) => r.item.recordHash), journal[2]!.filter(r => r.operation === 25n).map(r => r.recordHash))
        || !equal(decoded[2].grants.map((r: any) => r.recordHash), journal[2]!.filter(r => r.operation === 26n).map(r => r.recordHash))
        || !equal(decoded[6].sales.map((r: any) => r.item.recordHash), journal[6]!.filter(r => r.operation === 16n).map(r => r.recordHash))) throw Error("Delegation history differs from complete journals");
    }
    return;
  }
  if (indexes.length !== q.artists.length || indexes.some(n => n.kind !== 1n || !q.artists.some(a => same(a.artistId, n.key)))) throw Error("Incomplete multiple identity nonce inventory");
  const identities: any[] = [];
  for (const query of q.artists) {
    const raw = hex((await read(p, source.owners[2]!, "authorityLivingIdentityHydrationState", [query], tag))[0], MAX_EVIDENCE);
    const decoded = multipleIdentity(raw);
    if (decoded.nextRegistrationNonce !== BigInt(q.artists.length) || decoded.signatures.length !== query.records.length) throw Error("Multiple identity allocator/signatures differ");
    identities.push({ query, state: raw, nonces: indexes.find(n => same(n.key, query.artistId))!.words });
  }
  const ids = q.collections.map(c => c.collectionId);
  for (let i = 0; i < 7; ++i) {
    if (i === 1 || i === 5) continue;
    if (i === 2) {
      data[i].typedState = encodeArtistHydrationMultipleBundle(2, { rows: identities, artistIds: q.artists.map(a => a.artistId), collectionIds: ids, registrationCount: BigInt(identities.length) });
      continue;
    }
    const rows: any[] = [];
    for (const query of q.collections) {
      const value = await typedState(p, source.owners[i]!, "authorityHydrationState", query, "baseline", i, tag);
      if (i === 0) {
        const identity = multipleIdentity(identities.find(r => same(r.query.artistId, query.artistId)).state);
        if (!same(value.decoded.item.artistId, query.artistId) || !same(value.decoded.item.bindingHash, query.bindingHash)
          || !same(value.decoded.item.artistAddress, identity.item.authorityAddress) || !same(value.decoded.item.identityRecordHash, identity.item.identityRecordHash)) throw Error("Multiple binding/identity differs");
      }
      if (i === 3 && !same(value.decoded.record, journal[3]!.find(r => r.collectionId === query.collectionId)!.recordHash)) throw Error("Multiple acceptance differs");
      if (i === 6 && !equal(value.decoded, journal[6]!.filter(r => r.collectionId === query.collectionId).map(r => r.recordHash))) throw Error("Multiple policy order differs");
      rows.push({ query: { ...query, policies: i === 6 ? query.policies : [], records: [] }, state: value.raw, nonces: [] });
    }
    data[i].typedState = encodeArtistHydrationMultipleBundle(i as 0, { rows, artistIds: [], collectionIds: [], registrationCount: 0n });
  }
}
function captureDigest(value: Omit<ArtistAuthorityHydrationCapture, "captureHash">): Hex {
  return keccak256(new TextEncoder().encode(stable(value))) as Hex;
}
function saved(value: ArtistAuthorityHydrationCapture): ArtistAuthorityHydrationCapture {
  keys(value, ["deployment", "prepared", "blockNumber", "blockHash", "configurationHash", "sourceSuite", "destinationSuite", "checkpoints", "journals", "nonceIndexes", "lanes", "payloadCatalogs", "query", "ownerData", "before", "after", "commitment", "evidenceId", "simulated", "captureHash"]);
  // JSON-free cloning keeps bigint and string distinct. Historical recapture below authenticates observations.
  function clone(v: any): any { return Array.isArray(v) ? v.map(clone) : v && typeof v === "object" ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, clone(x)])) : v; }
  const copied = clone(value) as ArtistAuthorityHydrationCapture;
  const { captureHash, ...body } = copied;
  if (!same(captureDigest(body), hash(captureHash)) || copied.simulated !== true) throw Error("Hydration capture was changed");
  deployment(copied.deployment); normalizeArtistAuthorityHydrationCall(copied.prepared); number(copied.blockNumber); hash(copied.blockHash);
  return freeze(copied);
}
async function catalogs(p: Reader, suite: ArtistHydrationSuite, tag: number): Promise<ArtistHydrationPayloadCatalog[]> {
  const result: ArtistHydrationPayloadCatalog[] = [];
  for (const host of [suite.owners[2]!, suite.owners[4]!, suite.owners[6]!, suite.archive]) {
    const count = boundedCount((await read(p, host, "storedPayloadCount", [], tag))[0], 1024, "prestate payload catalog");
    const rows = [];
    const keys = new Set<string>();
    for (let i = 0; i < count; ++i) {
      const [pointer, payloadType, payloadHash] = await read(p, host, "storedPayloadAt", [BigInt(i)], tag);
      const key = `${payloadType}:${payloadHash}`;
      if (keys.has(key)) throw Error("Duplicate payload catalog key"); keys.add(key);
      const code = hex(await p.getCode(addr(pointer), tag), MAX_EVIDENCE + 1);
      if (!code.startsWith("0x00") || !same(keccak256(`0x${code.slice(4)}`), payloadHash)) throw Error("Prestate payload carrier differs");
      rows.push({ pointer: addr(pointer), payloadType: hash(payloadType), payloadHash: hash(payloadHash) });
    }
    result.push({ host, rows });
  }
  const archiveKeys = new Set(result[3]!.rows.map(r => `${r.payloadType}:${r.payloadHash}`));
  for (const catalog of result.slice(0, 3)) if (catalog.rows.some(r => !archiveKeys.has(`${r.payloadType}:${r.payloadHash}`))) throw Error("Prestate payload catalog synchronization incomplete");
  return result;
}
/** Complete, bounded source capture plus the original permissionless call at one concrete block. */
export async function captureArtistAuthorityHydration(p: Reader, rawDeployment: ArtistAuthorityHydrationDeployment, rawCall: Call, options: { readonly blockTag: number }): Promise<ArtistAuthorityHydrationCapture> {
  const d = deployment(rawDeployment), prepared = normalizeArtistAuthorityHydrationCall(rawCall);
  keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (!same(prepared.call.to, d.destination.registry.address)) throw Error("Hydration call targets another Registry");
  const input = (prepared as any).input;
  const b = await header(p, tag);
  const c = await context(p, d, tag, true);
  await history(p, d, c.source, c.destination, tag);
  const inv = await inventory(p, c.source, c.destination, input, tag);
  const q = queries(input, inv.journals, inv.checkpoints);
  const g = await guards(p, d, c.source, input, inv.checkpoints, tag);
  const lanes: ArtistHydrationLane[] = [];
  for (const a of q.artists) lanes.push(await lane(p, c.source, c.destination, 1n, a.artistId, BigInt(a.records.length), tag));
  for (const a of q.collections) lanes.push(await lane(p, c.source, c.destination, 2n, coder.encode(["uint256"], [a.collectionId]) as Hex,
    BigInt(inv.journals.flat().filter(r => r.collectionId === a.collectionId).length), tag));
  await states(p, c.source, input, inv.journals, q, g.data, g.nonceIndexes, tag);
  const payloadCatalogs = await catalogs(p, c.destination, tag);
  const commitment = artistAuthorityHydrationCommitment(coordinates(d), input, q.query, g.data);
  const after = inv.before.map((s, i) => artistAuthorityHydrationOwnerAfter(ownerEnvironment(d, c.destination, i), s, prepared.caller, q.query, g.data[i]!, commitment));
  const evidenceId = artistAuthorityHydrationEvidenceId(coordinates(d), prepared.caller, commitment);
  // The actual complete carrier, including seven before/after snapshots, must fit before simulation.
  const profileData = encodeArtistAuthorityHydrationProfileEvidence({ profile: prepared.profile, predecessorRegistry: c.source.registry,
    sourceCoordinator: d.source.coordinator.address, expectedSource: inv.checkpoints as any, query: q.query, ownerData: g.data as any });
  encodeArtistAuthorityHydrationEvidence({ schemaVersion: 1n, configurationHash: c.configurationHash, operationId: 60n,
    actor: prepared.caller, commitment, before: inv.before as any, after: after as any, profileData });
  const result = hash(await p.call({ ...prepared.call, from: prepared.caller, blockTag: tag }));
  if (!same(result, commitment)) throw Error("Original hydration call returned a different reconstructed commitment");
  // Recheck the original source headers after the simulated import, just as the contract does around writes.
  for (let i = 0; i < 7; ++i) if (!equal(inv.checkpoints[i], (await read(p, c.source.owners[i]!, "authorityCheckpoint", [], tag))[0])) throw Error("Source checkpoint changed");
  if (!equal(c.source, (await read(p, d.source.coordinator.address, "authorityHydrationSuite", [], tag))[0])) throw Error("Source suite changed");
  await unchanged(p, b);
  const body = { deployment: d, prepared, ...b, configurationHash: c.configurationHash, sourceSuite: c.source, destinationSuite: c.destination,
    ...inv, nonceIndexes: g.nonceIndexes, lanes, payloadCatalogs, query: q.query, ownerData: g.data, after, commitment, evidenceId, simulated: true as const };
  return freeze({ ...body, captureHash: captureDigest(body) });
}
/** Revalidates the retained prestate; never rewrites a stale request or refreshes its source headers. */
export async function simulateArtistAuthorityHydration(p: Reader, raw: ArtistAuthorityHydrationCapture, options: { readonly blockTag: number }): Promise<ArtistAuthorityHydrationCapture> {
  const c = saved(raw); keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  const historical = await captureArtistAuthorityHydration(p, c.deployment, c.prepared, { blockTag: c.blockNumber });
  if (!equal(historical, c)) throw Error("Saved historical capture differs");
  const fresh = tag === c.blockNumber ? historical : await captureArtistAuthorityHydration(p, c.deployment, c.prepared, { blockTag: tag });
  const { blockNumber: _n, blockHash: _h, captureHash: _c, ...facts } = c;
  const { blockNumber: _n2, blockHash: _h2, captureHash: _c2, ...next } = fresh;
  if (!equal(facts, next)) throw Error("Hydration facts changed; prepare a new capture");
  return fresh;
}
interface Log {
  address: Address;
  topics: Hex[];
  data: Hex;
  index: number;
}
function event(log: Log, name: string): any[] | null {
  const fragment = abi.getEvent(name)!;
  if (!same(log.topics[0], fragment.topicHash)) return null;
  const value = abi.decodeEventLog(fragment, log.data, log.topics);
  const encoded = abi.encodeEventLog(fragment, value);
  if (!same(encoded.data, log.data) || !equal(encoded.topics.map(t => t.toLowerCase()), log.topics)) throw Error("Noncanonical hydration event");
  return fragment.inputs.map((p, i) => plain(p, value[i]));
}
function safeOutcome(log: Log, name: "ExecutionSuccess" | "ExecutionFailure"): boolean {
  const topic = safeAbi.getEvent(name)!.topicHash;
  if (!same(log.topics[0], topic)) return false;
  // Both original Safe event layouts occur: txHash either unindexed or indexed.
  if (log.topics.length === 1 && log.data.length === 130) {
    const value = safeAbi.decodeEventLog(name, log.data, log.topics);
    if (!same(safeAbi.encodeEventLog(name, value).data, log.data)) throw Error("Noncanonical Safe outcome");
    return true;
  }
  if (log.topics.length === 2 && log.data.length === 66) {
    coder.decode(["uint256"], log.data); return true;
  }
  throw Error("Malformed Safe outcome");
}
async function payloads(p: Reader, c: ArtistAuthorityHydrationCapture, logs: readonly Log[], tag: number, archiveIndex: number, hydratedIndex: number,
  references: { address: Address; event: string; logIndex: number }[]) {
  const imported: { payloadType: Hex; payloadHash: Hex; bytes: Hex }[] = [];
  const append = (kind: string, bytes: Hex) => imported.push({ payloadType: id(kind) as Hex, payloadHash: keccak256(bytes) as Hex, bytes });
  function identity(raw: Hex) {
    const decoded = multipleIdentity(raw);
    append("ARTIST_IDENTITY_DOCUMENT", decoded.document);
    for (const signature of decoded.signatures) append("ARTIST_SIGNATURE_BUNDLE", signature);
  }
  if (c.prepared.input.kind === "multiple") {
    const state = decodeArtistHydrationOwnerState("multiple", 2, c.ownerData[2]!.typedState);
    for (const row of state.rows) identity(row.state);
  } else if (c.prepared.input.kind === "delegation") {
    const state = decodeArtistHydrationOwnerState("delegation", 2, c.ownerData[2]!.typedState);
    identity(state.baseline);
    for (const revision of state.revisions) append("ARTIST_IDENTITY_DOCUMENT", revision.document);
  } else identity(c.ownerData[2]!.typedState);
  const expected = c.payloadCatalogs.map(catalog => ({ host: catalog.host, rows: [...catalog.rows] }));
  const owner = expected[0]!;
  const archive = expected[3]!;
  const key = (v: { payloadType: Hex; payloadHash: Hex }) => `${v.payloadType}:${v.payloadHash}`;
  const ownerKeys = new Set(owner.rows.map(key));
  const archiveKeys = new Set(archive.rows.map(key));
  const additions: { host: Address; index: bigint; payloadType: Hex; payloadHash: Hex; pointer?: Address; bytes: Hex }[] = [];
  for (const row of imported) {
    if (ownerKeys.has(key(row))) continue;
    ownerKeys.add(key(row));
    additions.push({ host: owner.host, index: BigInt(owner.rows.length), ...row });
    owner.rows.push({ pointer: ZeroAddress as Address, payloadType: row.payloadType, payloadHash: row.payloadHash });
  }
  const relevant = logs.filter(l => c.payloadCatalogs.some(catalog => same(catalog.host, l.address)))
    .map(log => ({ log, values: event(log, "ArtistStoredPayload") })).filter(v => v.values !== null);
  // Resolve each expected newly stored Identity row, including the deduplicated empty signature bundle.
  let priorOwnerEvent = -1;
  for (const row of additions) {
    const matched = relevant.filter(v => same(v.log.address, row.host) && v.values![1] === row.index);
    if (matched.length !== 1) throw Error("Missing expected owner payload event");
    const v = matched[0]!;
    if (v.values![0] !== 1n || !same(v.values![2], row.payloadType) || !same(v.values![3], row.payloadHash) || v.log.index >= archiveIndex || v.log.index <= priorOwnerEvent) throw Error("Owner payload identity/order differs");
    priorOwnerEvent = v.log.index;
    row.pointer = addr(v.values![4]); owner.rows[Number(row.index)] = { pointer: row.pointer, payloadType: row.payloadType, payloadHash: row.payloadHash };
    if (!archiveKeys.has(key(row))) {
      archiveKeys.add(key(row));
      archive.rows.push({ pointer: row.pointer, payloadType: row.payloadType, payloadHash: row.payloadHash });
    }
  }
  let expectedEventCount = additions.length;
  let priorArchiveEvent = hydratedIndex;
  for (let i = c.payloadCatalogs[3]!.rows.length; i < archive.rows.length; ++i) {
    const row = archive.rows[i]!;
    const matched = relevant.filter(v => same(v.log.address, archive.host) && v.values![1] === BigInt(i));
    if (matched.length !== 1 || matched[0]!.values![0] !== 1n || !same(matched[0]!.values![2], row.payloadType)
      || !same(matched[0]!.values![3], row.payloadHash) || !same(matched[0]!.values![4], row.pointer) || matched[0]!.log.index <= priorArchiveEvent) throw Error("Missing or inconsistent atomic Archive payload entry");
    priorArchiveEvent = matched[0]!.log.index;
    ++expectedEventCount;
  }
  if (relevant.length !== expectedEventCount) throw Error("Unexpected hydration payload event");
  for (const catalog of expected) {
    const count = (await read(p, catalog.host, "storedPayloadCount", [], tag))[0];
    if (count < BigInt(catalog.rows.length)) throw Error("Incomplete payload catalog readback");
    for (let i = 0; i < catalog.rows.length; ++i) {
      const row = catalog.rows[i]!;
      const actual = await read(p, catalog.host, "storedPayloadAt", [BigInt(i)], tag);
      if (!same(actual[0], row.pointer) || !same(actual[1], row.payloadType) || !same(actual[2], row.payloadHash)) throw Error("Payload catalog prefix changed");
      const code = hex(await p.getCode(row.pointer, tag), MAX_EVIDENCE + 1);
      if (!code.startsWith("0x00") || !same(keccak256(`0x${code.slice(4)}`), row.payloadHash)) throw Error("Stored payload bytes differ");
    }
  }
  for (const v of relevant) references.push({ address: v.log.address, event: "ArtistStoredPayload", logIndex: v.log.index });
}
/** Verifies the exact successful call and atomic Archive evidence. A completed operation is never a successful retry. */
export async function inspectArtistAuthorityHydrationReceipt(p: ReceiptReader, raw: ArtistAuthorityHydrationCapture, transactionHash: Hex,
  options: { readonly execution: "direct" | "safe" }): Promise<ArtistAuthorityHydrationReceipt> {
  const c = saved(raw), txHash = hash(transactionHash);
  keys(options, ["execution"]); const execution = options.execution;
  if (execution !== "direct" && execution !== "safe") throw Error("Unsupported receipt transport");
  const historical = await captureArtistAuthorityHydration(p, c.deployment, c.prepared, { blockTag: c.blockNumber });
  if (!equal(historical, c)) throw Error("Historical capture differs");
  const tx = await p.getTransaction(txHash), receipt = await p.getTransactionReceipt(txHash);
  if (!tx || !receipt || receipt.status !== 1 || !same(receipt.hash, txHash) || !same(tx.hash, txHash)
    || tx.blockNumber !== receipt.blockNumber || !same(tx.blockHash, receipt.blockHash) || receipt.blockNumber <= c.blockNumber) throw Error("Successful receipt must follow capture block");
  const tag = number(receipt.blockNumber), b = await header(p, tag);
  if (!same(b.blockHash, receipt.blockHash)) throw Error("Receipt block changed");
  const target = c.prepared.call, data = hex(tx.data, MAX_CALL);
  if (tx.value !== 0n || !same(tx.to, receipt.to) || !same(tx.from, receipt.from)) throw Error("Receipt transaction envelope differs");
  if (execution === "direct") {
    if (!same(tx.from, c.prepared.caller) || !same(tx.to, target.to) || !same(data, target.data)) throw Error("Direct call differs");
  } else {
    if (!same(tx.to, c.prepared.caller)) throw Error("Safe is not actual hydration caller");
    const call = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", call), data) || !same(call[0], target.to) || call[1] !== 0n || !same(call[2], target.data) || call[3] !== 0n) throw Error("Safe must execute the exact ordinary zero-value CALL");
  }
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 2048) throw Error("Excessive receipt logs");
  const seen = new Set<number>();
  const logs: Log[] = receipt.logs.map(l => {
    const index = number(l.index);
    if (seen.has(index) || l.removed || l.blockNumber !== tag || !same(l.blockHash, b.blockHash) || !same(l.transactionHash, txHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log");
    seen.add(index);
    return { index, address: addr(l.address), topics: l.topics.map((t: string) => hash(t, true)), data: hex(l.data, 65_536) };
  });
  logs.sort((a, b) => a.index - b.index);
  const live = await context(p, c.deployment, tag, false);
  if (!equal(live.source, c.sourceSuite) || !equal(live.destination, c.destinationSuite) || !same(live.configurationHash, c.configurationHash)) throw Error("Receipt deployment differs");
  const references: { address: Address; event: string; logIndex: number }[] = [];
  function only(address: Address, name: string) {
    const matches = logs.filter(l => same(l.address, address)).map(log => ({ log, values: event(log, name) })).filter(e => e.values !== null);
    if (matches.length !== 1) throw Error(`Expected exactly one ${name}`);
    const found = matches[0]!; references.push({ address, event: name, logIndex: found.log.index });
    return { log: found.log, values: found.values! };
  }
  const a = only(c.destinationSuite.archive, "ArtistArchiveEvidenceAppendedV2");
  const h = only(c.deployment.destination.coordinator.address, "ArtistAuthorityHydrated");
  if (a.log.index >= h.log.index || !same(a.values[0], c.evidenceId) || a.values[1] !== 1n
    || h.values[0] !== 1n || !same(h.values[1], c.query.artistId) || h.values[2] !== c.query.collectionId
    || !same(h.values[3], c.sourceSuite.registry) || !same(h.values[4], c.prepared.profile) || !same(h.values[5], c.commitment)) throw Error("Hydration event identity/order differs");
  const metadata = await read(p, c.destinationSuite.archive, "artistEvidenceMetadataV2", [c.evidenceId, 1n], tag);
  const rawEvidence = hex((await read(p, c.destinationSuite.archive, "artistEvidenceBytesV2", [c.evidenceId, 1n], tag))[0], MAX_EVIDENCE);
  if (!same(metadata[0], a.values[2]) || !same(metadata[1], a.values[3]) || metadata[2] !== a.values[4] || metadata[3] !== BigInt(tag)
    || metadata[2] !== BigInt((rawEvidence.length - 2) / 2) || !same(keccak256(rawEvidence), metadata[0])) throw Error("Archive immutable receipt differs");
  const pointerCode = hex(await p.getCode(addr(metadata[1]), tag), MAX_EVIDENCE + 1);
  if (!same(pointerCode, `0x00${rawEvidence.slice(2)}`)) throw Error("Archive pointer bytes differ");
  const evidence = decodeArtistAuthorityHydrationEvidence(rawEvidence);
  const profile = decodeArtistAuthorityHydrationProfileEvidence(evidence.profileData);
  if (!same(evidence.configurationHash, c.configurationHash) || !same(evidence.actor, c.prepared.caller) || !same(evidence.commitment, c.commitment)
    || !equal(evidence.before, c.before) || !equal(evidence.after, c.after)
    || !same(profile.profile, c.prepared.profile) || !same(profile.predecessorRegistry, c.sourceSuite.registry)
    || !same(profile.sourceCoordinator, c.deployment.source.coordinator.address) || !equal(profile.expectedSource, c.checkpoints)
    || !equal(profile.query, c.query) || !equal(profile.ownerData, c.ownerData)) throw Error("Atomic operation/profile evidence differs");
  let lastHydration = h.log.index;
  if (c.prepared.input.kind === "multiple") {
    const m = only(c.deployment.destination.coordinator.address, "MultipleArtistAuthorityHydrated");
    if (m.log.index <= h.log.index || !same(m.values[0], c.sourceSuite.registry) || !same(m.values[1], c.commitment)
      || !equal(m.values[2], c.prepared.input.request.artistIds) || !equal(m.values[3], c.prepared.input.request.collections.map(r => r.collectionId))) throw Error("Multiple profile event differs");
    lastHydration = m.log.index;
  } else if (logs.some(l => same(l.address, c.deployment.destination.coordinator.address) && event(l, "MultipleArtistAuthorityHydrated"))) throw Error("Unexpected multiple profile event");
  const observedOwners: ArtistHydrationSnapshot[] = [];
  for (let i = 0; i < 7; ++i) {
    const owner = c.destinationSuite.owners[i]!;
    if (!same((await read(p, owner, "authorityHydrationCommitment", [], tag))[0], c.commitment)) throw Error("Incomplete seven-owner hydration");
    const observed = (await read(p, owner, "ownerStateSnapshotV2", [], tag))[0] as ArtistHydrationSnapshot;
    if (!same(observed.domainId, c.after[i]!.domainId) || observed.revision < c.after[i]!.revision
      || (observed.revision === c.after[i]!.revision && !equal(observed, c.after[i]))) throw Error("Owner readback contradicts archived state");
    observedOwners.push(observed);
    for (let j = 0; j < c.ownerData[i]!.sourceKeys.length; ++j) {
      const cell = (await read(p, owner, "importedAuthorityReplayCell", [c.ownerData[i]!.sourceKeys[j]], tag))[0];
      if (!equal(cell, c.ownerData[i]!.cells[j])) throw Error("Historical replay cell differs");
    }
    const count = (await read(p, owner, "artistNativeReceiptCount", [], tag))[0];
    if ((await read(p, c.destinationSuite.owners[2]!, "artistHistorySourceCursor", [owner], tag))[0] !== count) throw Error("Native history synchronization incomplete");
  }
  await payloads(p, c, logs, tag, a.log.index, lastHydration, references);
  if (execution === "safe") {
    const safeLogs = logs.filter(l => same(l.address, c.prepared.caller));
    if (safeLogs.some(l => safeOutcome(l, "ExecutionFailure"))) throw Error("Safe execution failed");
    const success = safeLogs.filter(l => safeOutcome(l, "ExecutionSuccess"));
    if (success.length !== 1 || success[0]!.index <= Math.max(...references.map(r => r.logIndex))) throw Error("Missing or misordered Safe success");
    references.push({ address: c.prepared.caller, event: "ExecutionSuccess", logIndex: success[0]!.index });
  }
  await unchanged(p, b); await unchanged(p, c);
  return freeze({ capture: c, transactionHash: txHash, ...b, commitment: c.commitment, evidenceId: c.evidenceId,
    events: references.sort((a, b) => a.logIndex - b.logIndex), observedOwners });
}
