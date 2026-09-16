import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString,
  keccak256, toBeHex, toUtf8Bytes,
} from "ethers";
import type { BlockTag, InterfaceAbi, Provider } from "ethers";
import type { UnsignedCall } from "./client.js";
import type { Address, Hex } from "./generated/contracts.js";
import { toSafeCall, type SafeCall } from "./safe.js";

export const ROYALTY_CONTINUITY_SOURCE_COMMIT = "49364823b9e537a33896346b67639e523b4f31d1";
export const ROYALTY_CONTINUITY_SCHEMA = id("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1") as Hex;
export const ROYALTY_CONTINUITY_CANONICALIZATION = id("STREAM_ROYALTY_CONTINUITY_ABI_V1") as Hex;
export const ROYALTY_CONTINUITY_CLASS = id("ROYALTY_ERC2981") as Hex;

export interface RoyaltyConfig {
  readonly wallet: Address; readonly royaltyBps: bigint; readonly configured: boolean;
  readonly frozen: boolean; readonly revision: bigint; readonly profileId: Hex;
}
export interface RoyaltySnapshot {
  readonly exists: boolean; readonly collectionId: bigint; readonly tokenId: bigint; readonly manager: Address;
  readonly operationRoot: Hex; readonly operationId: Hex; readonly preparedProofHash: Hex; readonly electionHash: Hex;
  readonly sourceAssignmentHash: Hex; readonly modeAssignmentHash: Hex; readonly sourceRoyaltyPolicyHash: Hex;
  readonly tokenAssignmentHash: Hex; readonly tokenRoyaltyPolicyHash: Hex; readonly tokenConfigHash: Hex;
}
export interface RoyaltyContinuityHeader {
  readonly schemaVersion: bigint; readonly core: Address; readonly factory: Address; readonly maxRoyaltyBps: bigint;
  readonly protectedCount: bigint; readonly protectedRoot: Hex; readonly electionCount: bigint;
  readonly electionRoot: Hex; readonly frozenStateHash: Hex;
}
export interface RoyaltyContinuityRoute {
  readonly scope: bigint; readonly scopeId: bigint; readonly collectionId: bigint; readonly hashOrigin: Address;
  readonly config: RoyaltyConfig; readonly assignmentHash: Hex; readonly policyHash: Hex; readonly snapshot: RoyaltySnapshot;
}
export interface RoyaltyContinuityElection {
  readonly collectionId: bigint; readonly mode: bigint; readonly electionHash: Hex; readonly hashOrigin: Address;
}
export interface RoyaltyContinuityManifestRef {
  readonly expectedSourceHeaderHash: Hex; readonly contentHash: Hex; readonly uri: string; readonly uriHash: Hex;
  readonly schemaId: Hex; readonly canonicalizationId: Hex;
}
export interface RoyaltyContinuityManifestBody {
  readonly uri: string; readonly uriHash: Hex; readonly schemaId: Hex; readonly canonicalizationId: Hex;
}
export interface RoyaltyContinuityImportState {
  readonly status: bigint; readonly source: Address; readonly sourceRuntimeHash: Hex; readonly manifestHash: Hex;
  readonly beginActionId: Hex; readonly importedRoutes: bigint; readonly importedElections: bigint;
  readonly expected: RoyaltyContinuityHeader; readonly manifestReference: RoyaltyContinuityManifestRef;
}
export interface RoyaltyContinuityBindings { readonly resolver: InterfaceAbi; readonly core: InterfaceAbi }
export interface RoyaltyContinuityDeployment {
  readonly source: Address; readonly target: Address; readonly core: Address; readonly factory: Address; readonly authority: Address;
}
export interface RoyaltyContinuityCaptureLimits { readonly maxRoutes: bigint; readonly maxElections: bigint }
export interface RoyaltyContinuityChunk { readonly maxRoutes: bigint; readonly maxElections: bigint }
export interface RoyaltyContinuityTransition {
  readonly actionClass: 1; readonly scope: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
}
export interface RoyaltyContinuityPlan {
  readonly chainId: bigint; readonly blockNumber: number; readonly blockHash: Hex;
  readonly source: Address; readonly target: Address; readonly core: Address; readonly factory: Address; readonly authority: Address;
  readonly sourceRuntimeHash: Hex; readonly targetRuntimeHash: Hex; readonly coreRuntimeHash: Hex;
  readonly factoryRuntimeHash: Hex; readonly authorityRuntimeHash: Hex;
  readonly header: RoyaltyContinuityHeader; readonly headerHash: Hex;
  readonly routes: readonly RoyaltyContinuityRoute[]; readonly elections: readonly RoyaltyContinuityElection[];
  readonly manifestReference: RoyaltyContinuityManifestRef; readonly canonicalManifest: Hex; readonly manifestHash: Hex;
  readonly transition: RoyaltyContinuityTransition;
}
export interface RoyaltyContinuityAction {
  readonly kind: "begin" | "import" | "complete"; readonly caller: Address; readonly call: UnsignedCall;
  readonly source: Address; readonly target: Address; readonly sourceHeaderHash: Hex; readonly manifestHash: Hex;
}
export interface RoyaltyContinuityObservation {
  readonly phase: "awaiting-begin" | "importing" | "ready-to-complete" | "completed";
  readonly blockNumber: number; readonly blockHash: Hex; readonly importedRoutes: bigint; readonly importedElections: bigint;
  readonly ready: boolean; readonly supportsPinnedContinuity: boolean; readonly coreStillUsesSource: true;
}

const coder = AbiCoder.defaultAbiCoder();
const HEADER = "tuple(uint16 schemaVersion,address core,address factory,uint16 maxRoyaltyBps,uint256 protectedCount,bytes32 protectedRoot,uint256 electionCount,bytes32 electionRoot,bytes32 frozenStateHash)";
const CONFIG = "tuple(address wallet,uint16 royaltyBps,bool configured,bool frozen,uint64 revision,bytes32 profileId)";
const SNAPSHOT = "tuple(bool exists,uint256 collectionId,uint256 tokenId,address manager,bytes32 operationRoot,bytes32 operationId,bytes32 preparedProofHash,bytes32 electionHash,bytes32 sourceAssignmentHash,bytes32 modeAssignmentHash,bytes32 sourceRoyaltyPolicyHash,bytes32 tokenAssignmentHash,bytes32 tokenRoyaltyPolicyHash,bytes32 tokenConfigHash)";
const ROUTE = `tuple(uint8 scope,uint256 scopeId,uint256 collectionId,address hashOrigin,${CONFIG} config,bytes32 assignmentHash,bytes32 policyHash,${SNAPSHOT} snapshot)`;
const ELECTION = "tuple(uint256 collectionId,uint8 mode,bytes32 electionHash,address hashOrigin)";
const MANIFEST = "tuple(bytes32 expectedSourceHeaderHash,bytes32 contentHash,string uri,bytes32 uriHash,bytes32 schemaId,bytes32 canonicalizationId)";
const MANIFEST_DOMAIN = id("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1") as Hex;
const ROUTE_DOMAIN = id("6529STREAM_PROTECTED_ROYALTY_ROUTE_V1") as Hex;
const FROZEN_DOMAIN = id("6529STREAM_FROZEN_ROYALTY_STATE_V1") as Hex;
const ELECTION_DOMAIN = id("6529STREAM_ROYALTY_MODE_ELECTION_V1") as Hex;
const BEGIN_DOMAIN = id("6529STREAM_ROYALTY_CONTINUITY_BEGIN_V1") as Hex;
const POINTER = id("ROYALTY_RESOLVER") as Hex;
const MAX_CAPTURE_ROWS = 4096n;
const authorityAbi = new Interface(["function isStreamGovernedParameterAuthority() view returns (bool)"]);

const same = (a: string, b: string) => a.toLowerCase() === b.toLowerCase();
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return value;
}
function address(value: unknown, allowZero = false): Address {
  if (typeof value !== "string") throw Error("Expected address string");
  const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}
function hash(value: unknown, allowZero = true): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!allowZero && same(value, ZeroHash))) throw Error("Expected bytes32");
  return value.toLowerCase() as Hex;
}
function exactKeys(value: unknown, names: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...names].sort().join(",")) throw Error("Unexpected or missing tuple fields");
}
function normalize(param: ParamType, value: unknown): unknown {
  if (param.baseType === "tuple") {
    const components = param.components!; exactKeys(value, components.map(x => x.name));
    return Object.fromEntries(components.map(x => [x.name, normalize(x, value[x.name])]));
  }
  if (param.baseType === "array") {
    if (!Array.isArray(value) || (param.arrayLength !== -1 && value.length !== param.arrayLength)) throw Error("Expected exact ABI array");
    return value.map(x => normalize(param.arrayChildren!, x));
  }
  if (/^uint\d+$/.test(param.type)) return uint(value, Number(param.type.slice(4)));
  if (param.type === "address") return address(value, true);
  if (param.type === "bool" && typeof value === "boolean") return value;
  if (param.type === "string" && typeof value === "string") return value;
  if (param.type.startsWith("bytes") && typeof value === "string"
    && isHexString(value, param.type === "bytes" ? true : Number(param.type.slice(5)))) return value.toLowerCase();
  throw Error(`Invalid ${param.type} ABI value`);
}
function plain(param: ParamType, value: any): any {
  if (param.baseType === "tuple") return Object.freeze(Object.fromEntries(param.components!.map((x, i) => [x.name, plain(x, value[i])])));
  if (param.baseType === "array") return Object.freeze([...value].map(x => plain(param.arrayChildren!, x)));
  return value;
}
function deepFreeze<T>(value: T): T {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    for (const item of Object.values(value as Record<string, unknown>)) deepFreeze(item);
    Object.freeze(value);
  }
  return value;
}
function encode(type: string, value: unknown): string { return coder.encode([type], [value]); }
function strict(type: string, value: unknown): unknown { return normalize(ParamType.from(type), value); }

/** Parse the evidence JSON emitted by the example without guessing numeric-looking strings. */
export function parseRoyaltyContinuityPlanJSON(text: string): unknown {
  if (typeof text !== "string" || text.length > 16_000_000) throw Error("Expected bounded royalty continuity JSON text");
  return JSON.parse(text, (key, value) => {
    if (key === "__proto__" || key === "prototype" || key === "constructor") throw Error("Unsafe JSON field");
    if (value && typeof value === "object" && !Array.isArray(value) && Object.hasOwn(value, "$bigint")) {
      exactKeys(value, ["$bigint"]); const literal = value.$bigint;
      if (typeof literal !== "string" || literal.length > 78 || !/^(0|[1-9][0-9]*)$/.test(literal)) throw Error("Invalid tagged bigint");
      return BigInt(literal);
    }
    return value;
  });
}

export function royaltyContinuityHeaderHash(header: RoyaltyContinuityHeader): Hex {
  return keccak256(encode(HEADER, strict(HEADER, header))) as Hex;
}
export function royaltyContinuityRouteKey(route: Pick<RoyaltyContinuityRoute, "scope" | "scopeId">): Hex {
  if (!route || typeof route !== "object") throw Error("Expected route key fields");
  return keccak256(coder.encode(["bytes32", "uint8", "uint256"], [ROYALTY_CONTINUITY_CLASS, uint(route.scope, 8), uint(route.scopeId)])) as Hex;
}
export function royaltyContinuityRouteHash(chainId: bigint, core: Address, route: RoyaltyContinuityRoute): Hex {
  const normalized = strict(ROUTE, route) as RoyaltyContinuityRoute;
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "uint8", "uint256", "uint256", "address", CONFIG, "bytes32", "bytes32", "uint8", SNAPSHOT],
    [ROUTE_DOMAIN, uint(chainId), address(core), ROYALTY_CONTINUITY_CLASS, normalized.scope, normalized.scopeId, normalized.collectionId,
      normalized.hashOrigin, normalized.config, normalized.assignmentHash, normalized.policyHash, 1n, normalized.snapshot],
  )) as Hex;
}
export function royaltyContinuityElectionHash(chainId: bigint, core: Address, election: RoyaltyContinuityElection): Hex {
  const normalized = strict(ELECTION, election) as RoyaltyContinuityElection;
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint8"],
    [ELECTION_DOMAIN, uint(chainId), normalized.hashOrigin, address(core), normalized.collectionId, normalized.mode])) as Hex;
}
export function royaltyContinuityRoots(chainId: bigint, core: Address, routes: readonly RoyaltyContinuityRoute[], elections: readonly RoyaltyContinuityElection[]) {
  if (!Array.isArray(routes) || !Array.isArray(elections) || routes.length > Number(MAX_CAPTURE_ROWS) || elections.length > Number(MAX_CAPTURE_ROWS)) throw Error("Invalid bounded continuity inventory");
  let protectedRoot = ZeroHash as Hex, electionRoot = ZeroHash as Hex;
  routes.forEach((route, i) => {
    strict(ROUTE, route);
    protectedRoot = keccak256(coder.encode(["bytes32", "uint256", "bytes32", "bytes32"],
      [protectedRoot, BigInt(i), royaltyContinuityRouteKey({ scope: route.scope, scopeId: route.scopeId }), royaltyContinuityRouteHash(chainId, core, route)])) as Hex;
  });
  elections.forEach((election, i) => {
    const normalized = strict(ELECTION, election);
    electionRoot = keccak256(coder.encode(["bytes32", "uint256", ELECTION], [electionRoot, BigInt(i), normalized])) as Hex;
  });
  return Object.freeze({ protectedRoot, electionRoot });
}
export function royaltyContinuityFrozenStateHash(chainId: bigint, header: RoyaltyContinuityHeader): Hex {
  const normalized = strict(HEADER, header) as RoyaltyContinuityHeader;
  if ((normalized.protectedCount === 0n) !== same(normalized.protectedRoot, ZeroHash)
    || (normalized.electionCount === 0n) !== same(normalized.electionRoot, ZeroHash)) throw Error("Header count/root mismatch");
  if (normalized.protectedCount === 0n && normalized.electionCount === 0n) {
    if (!same(normalized.frozenStateHash, ZeroHash)) throw Error("Empty header has a frozen-state hash");
    return ZeroHash as Hex;
  }
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "uint256", "bytes32", "uint256", "bytes32"],
    [FROZEN_DOMAIN, uint(chainId), normalized.core, normalized.factory, normalized.maxRoyaltyBps, normalized.protectedCount,
      normalized.protectedRoot, normalized.electionCount, normalized.electionRoot])) as Hex;
}
export function royaltyContinuityManifestBytes(chainId: bigint, source: Address, sourceRuntimeHash: Hex, target: Address,
  header: RoyaltyContinuityHeader, reference: RoyaltyContinuityManifestBody): Hex {
  const normalizedHeader = strict(HEADER, header) as RoyaltyContinuityHeader;
  exactKeys(reference, ["uri", "uriHash", "schemaId", "canonicalizationId"]);
  if (typeof reference.uri !== "string") throw Error("Expected manifest URI");
  const body = { uri: reference.uri, uriHash: hash(reference.uriHash), schemaId: hash(reference.schemaId), canonicalizationId: hash(reference.canonicalizationId) };
  return coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "address", HEADER, "string", "bytes32", "bytes32", "bytes32"],
    [MANIFEST_DOMAIN, uint(chainId), address(source), hash(sourceRuntimeHash, false), address(target), normalizedHeader.core, normalizedHeader.factory,
      normalizedHeader, body.uri, body.uriHash, body.schemaId, body.canonicalizationId]) as Hex;
}
export function royaltyContinuityManifestHash(chainId: bigint, source: Address, sourceRuntimeHash: Hex, target: Address,
  header: RoyaltyContinuityHeader, reference: RoyaltyContinuityManifestBody): Hex {
  return keccak256(royaltyContinuityManifestBytes(chainId, source, sourceRuntimeHash, target, header, reference)) as Hex;
}

type RPC = Pick<Provider, "call" | "getNetwork" | "getBlock" | "getCode">;
type ResolverName = "source" | "target";

/** Pending current-stack caller. It prepares reads and CALLs only; it never signs, sends or claims Core cutover readiness. */
export class CurrentRoyaltyContinuityClient {
  readonly chainId: bigint;
  readonly deployment: RoyaltyContinuityDeployment;
  readonly #resolver: Interface;
  readonly #core: Interface;
  readonly #plans = new WeakSet<object>();
  readonly #actions = new WeakSet<object>();
  readonly #interfaceId: string;
  constructor(chainId: bigint, deployment: RoyaltyContinuityDeployment, bindings: RoyaltyContinuityBindings) {
    this.chainId = uint(chainId); if (this.chainId === 0n) throw Error("Nonzero chain required");
    exactKeys(deployment, ["source", "target", "core", "factory", "authority"]);
    this.deployment = Object.freeze({ source: address(deployment.source), target: address(deployment.target), core: address(deployment.core),
      factory: address(deployment.factory), authority: address(deployment.authority) });
    if (same(this.deployment.source, this.deployment.target)) throw Error("Source and candidate must differ");
    this.#resolver = new Interface(bindings.resolver); this.#core = new Interface(bindings.core);
    const required = ["MAX_ROYALTY_BPS", "beginEconomicContinuity", "boundCore", "boundCoreCodeHash", "completeEconomicContinuity",
      "continuityHeader", "continuityManifestHash", "continuitySource", "economicContinuityReady", "economicContinuityState",
      "economicElectionAt", "governanceAuthority", "importEconomicContinuity", "owner", "previewEconomicContinuity",
      "protectedEconomicRouteAt", "splitFactory", "supportsEconomicContinuity", "supportsInterface"];
    for (const name of required) if (!this.#resolver.getFunction(name)) throw Error(`Selected resolver ABI lacks ${name}`);
    if (!this.#core.getFunction("getSatellitePointer")) throw Error("Selected Core ABI lacks getSatellitePointer");
    const own = ["continuityHeader", "protectedEconomicRouteAt", "economicElectionAt", "economicContinuityState", "economicContinuityReady",
      "continuitySource", "continuityManifestHash", "previewEconomicContinuity", "beginEconomicContinuity", "importEconomicContinuity", "completeEconomicContinuity"];
    let interfaceId = 0n; for (const name of own) interfaceId ^= BigInt(this.#resolver.getFunction(name)!.selector);
    this.#interfaceId = toBeHex(interfaceId, 4);
    Object.freeze(this);
  }
  #target(name: ResolverName): Address { return this.deployment[name]; }
  #call(abi: Interface, to: Address, method: string, args: readonly unknown[]): UnsignedCall {
    const fn = abi.getFunction(method); if (!fn || fn.inputs.length !== args.length) throw Error(`Selected ABI lacks ${method}`);
    return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(fn, args.map((x, i) => normalize(fn.inputs[i]!, x))) as Hex });
  }
  #resolverCall(name: ResolverName, method: string, args: readonly unknown[] = []): UnsignedCall {
    return this.#call(this.#resolver, this.#target(name), method, args);
  }
  async #read(provider: Pick<Provider, "call">, abi: Interface, call: UnsignedCall, method: string, blockTag: BlockTag): Promise<readonly unknown[]> {
    const raw = await provider.call({ ...call, blockTag });
    if (!isHexString(raw, true) || raw.length > 4_000_002) throw Error("Malformed or excessive contract return");
    const fn = abi.getFunction(method)!; const decoded = abi.decodeFunctionResult(fn, raw);
    if (!same(abi.encodeFunctionResult(fn, decoded), raw)) throw Error("Noncanonical contract return");
    return Object.freeze(fn.outputs.map((x, i) => plain(x, decoded[i])));
  }
  async #resolverRead(provider: Pick<Provider, "call">, name: ResolverName, method: string, args: readonly unknown[], tag: BlockTag) {
    return this.#read(provider, this.#resolver, this.#resolverCall(name, method, args), method, tag);
  }
  async #corePointer(provider: Pick<Provider, "call">, tag: BlockTag) {
    const call = this.#call(this.#core, this.deployment.core, "getSatellitePointer", [POINTER]);
    return this.#read(provider, this.#core, call, "getSatellitePointer", tag);
  }
  async #block(provider: Pick<Provider, "getNetwork" | "getBlock">, tag: BlockTag) {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw Error("RPC chain differs");
    const block = await provider.getBlock(tag);
    if (!block?.hash || !Number.isSafeInteger(block.number) || block.number < 0) throw Error("Observed block unavailable");
    return { number: block.number, hash: hash(block.hash, false) };
  }
  async #codes(provider: Pick<Provider, "getCode">, tag: BlockTag) {
    const d = this.deployment;
    const entries = await Promise.all((["source", "target", "core", "factory", "authority"] as const).map(async name => {
      const code = await provider.getCode(d[name], tag);
      if (code === "0x") throw Error(`Pinned ${name} has no runtime code`);
      return [name, keccak256(code) as Hex] as const;
    }));
    return Object.fromEntries(entries) as Record<typeof entries[number][0], Hex>;
  }
  async #identity(provider: Pick<Provider, "call">, name: ResolverName, tag: BlockTag, coreHash: Hex) {
    const methods = ["owner", "governanceAuthority", "boundCore", "boundCoreCodeHash", "splitFactory", "MAX_ROYALTY_BPS", "economicContinuityReady"];
    const values = await Promise.all(methods.map(method => this.#resolverRead(provider, name, method, [], tag)));
    const [owner, authority, core, boundHash, factory, maximum, ready] = values.map(x => x[0]);
    if (!same(String(owner), this.deployment.authority) || !same(String(authority), this.deployment.authority)
      || !same(String(core), this.deployment.core) || !same(String(boundHash), coreHash)
      || !same(String(factory), this.deployment.factory) || typeof maximum !== "bigint" || typeof ready !== "boolean") {
      throw Error(`Pinned ${name} constructor identity differs`);
    }
    return { maximum, ready };
  }
  async #authority(provider: Pick<Provider, "call" | "getCode">, tag: BlockTag, expectedHash: Hex): Promise<void> {
    const code = await provider.getCode(this.deployment.authority, tag);
    if (code === "0x" || !same(keccak256(code), expectedHash) || ((code.length - 2) / 2 === 23 && code.slice(2, 8).toLowerCase() === "ef0100")) {
      throw Error("Canonical continuity authority runtime is unavailable");
    }
    const call = this.#call(authorityAbi, this.deployment.authority, "isStreamGovernedParameterAuthority", []);
    const marker = await this.#read(provider, authorityAbi, call, "isStreamGovernedParameterAuthority", tag);
    if (marker[0] !== true) throw Error("Canonical continuity authority marker is absent");
  }
  #assertHeader(header: RoyaltyContinuityHeader, maximum: bigint): void {
    if (header.schemaVersion !== 1n || !same(header.core, this.deployment.core) || !same(header.factory, this.deployment.factory)
      || header.maxRoyaltyBps !== maximum || (header.protectedCount === 0n) !== same(header.protectedRoot, ZeroHash)
      || (header.electionCount === 0n) !== same(header.electionRoot, ZeroHash)) throw Error("Invalid pinned continuity header");
  }
  #assertRoute(route: RoyaltyContinuityRoute, maximum: bigint): void {
    const { config, snapshot } = route;
    if (route.scope > 2n || !config.configured || !config.frozen || same(route.hashOrigin, ZeroAddress)
      || same(route.assignmentHash, ZeroHash) || same(route.policyHash, ZeroHash) || config.royaltyBps > maximum
      || (route.scope === 0n && (route.scopeId !== 0n || route.collectionId !== 0n))
      || (route.scope !== 0n && (route.scopeId === 0n || route.collectionId === 0n))
      || (route.scope === 1n && route.scopeId !== route.collectionId)
      || (config.royaltyBps === 0n) !== (config.profileId === ZeroHash)
      || (config.royaltyBps === 0n) !== (config.wallet === ZeroAddress)) throw Error("Invalid protected royalty route");
    if (snapshot.exists) {
      if (route.scope !== 2n || snapshot.tokenId !== route.scopeId || snapshot.collectionId !== route.collectionId
        || !same(snapshot.tokenAssignmentHash, route.assignmentHash) || !same(snapshot.tokenRoyaltyPolicyHash, route.policyHash)
        || !same(snapshot.tokenConfigHash, keccak256(encode(CONFIG, config)))) throw Error("Snapshot does not preserve its route");
    } else {
      const zero = { exists: false, collectionId: 0n, tokenId: 0n, manager: ZeroAddress, operationRoot: ZeroHash, operationId: ZeroHash,
        preparedProofHash: ZeroHash, electionHash: ZeroHash, sourceAssignmentHash: ZeroHash, modeAssignmentHash: ZeroHash,
        sourceRoyaltyPolicyHash: ZeroHash, tokenAssignmentHash: ZeroHash, tokenRoyaltyPolicyHash: ZeroHash, tokenConfigHash: ZeroHash };
      if (!same(keccak256(encode(SNAPSHOT, snapshot)), keccak256(encode(SNAPSHOT, zero)))) throw Error("Absent snapshot is not empty");
    }
  }
  #reconstruct(saved: unknown): RoyaltyContinuityPlan {
    const fields = ["chainId", "blockNumber", "blockHash", "source", "target", "core", "factory", "authority",
      "sourceRuntimeHash", "targetRuntimeHash", "coreRuntimeHash", "factoryRuntimeHash", "authorityRuntimeHash",
      "header", "headerHash", "routes", "elections", "manifestReference", "canonicalManifest", "manifestHash", "transition"];
    exactKeys(saved, fields);
    const chainId = uint(saved.chainId);
    if (chainId !== this.chainId || !Number.isSafeInteger(saved.blockNumber) || (saved.blockNumber as number) < 0) throw Error("Saved plan chain or block is invalid");
    const coordinates = { source: address(saved.source), target: address(saved.target), core: address(saved.core),
      factory: address(saved.factory), authority: address(saved.authority) };
    for (const name of ["source", "target", "core", "factory", "authority"] as const) {
      if (!same(coordinates[name], this.deployment[name])) throw Error(`Saved plan ${name} differs from this deployment`);
    }
    const sourceRuntimeHash = hash(saved.sourceRuntimeHash, false), targetRuntimeHash = hash(saved.targetRuntimeHash, false);
    const coreRuntimeHash = hash(saved.coreRuntimeHash, false), factoryRuntimeHash = hash(saved.factoryRuntimeHash, false);
    const authorityRuntimeHash = hash(saved.authorityRuntimeHash, false);
    const header = strict(HEADER, saved.header) as RoyaltyContinuityHeader;
    this.#assertHeader(header, header.maxRoyaltyBps);
    if (!saved.manifestReference || typeof saved.manifestReference !== "object" || Array.isArray(saved.manifestReference)) throw Error("Saved manifest reference is absent");
    const rawUri = (saved.manifestReference as Record<string, unknown>).uri;
    if (typeof rawUri !== "string" || toUtf8Bytes(rawUri).length === 0 || toUtf8Bytes(rawUri).length > 2048) throw Error("Saved manifest URI is invalid");
    if (typeof saved.canonicalManifest !== "string" || saved.canonicalManifest.length > 16_386 || !isHexString(saved.canonicalManifest, true)) throw Error("Saved canonical manifest is invalid");
    if (!Array.isArray(saved.routes) || !Array.isArray(saved.elections)
      || saved.routes.length > Number(MAX_CAPTURE_ROWS) || saved.elections.length > Number(MAX_CAPTURE_ROWS)) throw Error("Saved inventory is not bounded");
    const routes = saved.routes.map(value => strict(ROUTE, value) as RoyaltyContinuityRoute);
    const elections = saved.elections.map(value => strict(ELECTION, value) as RoyaltyContinuityElection);
    if (BigInt(routes.length) !== header.protectedCount || BigInt(elections.length) !== header.electionCount) throw Error("Saved inventory count differs from its header");
    const routeKeys = new Set<string>(), electionIds = new Set<string>();
    for (const route of routes) {
      this.#assertRoute(route, header.maxRoyaltyBps);
      const key = royaltyContinuityRouteKey(route); if (routeKeys.has(key)) throw Error("Saved plan has a duplicate route key");
      routeKeys.add(key);
    }
    for (const election of elections) {
      const collection = uint(election.collectionId), mode = uint(election.mode, 8);
      if (collection === 0n || (mode !== 1n && mode !== 2n) || same(election.hashOrigin, ZeroAddress)
        || !same(election.electionHash, royaltyContinuityElectionHash(this.chainId, this.deployment.core, election))) throw Error("Saved plan has an invalid election");
      const key = collection.toString(); if (electionIds.has(key)) throw Error("Saved plan has a duplicate election");
      electionIds.add(key);
    }
    const roots = royaltyContinuityRoots(this.chainId, this.deployment.core, routes, elections);
    if (!same(roots.protectedRoot, header.protectedRoot) || !same(roots.electionRoot, header.electionRoot)
      || !same(royaltyContinuityFrozenStateHash(this.chainId, header), header.frozenStateHash)) throw Error("Saved plan does not reproduce its immutable header");
    const headerHash = hash(saved.headerHash, false);
    if (!same(headerHash, royaltyContinuityHeaderHash(header))) throw Error("Saved source header commitment differs");
    const manifestReference = strict(MANIFEST, saved.manifestReference) as RoyaltyContinuityManifestRef;
    if (!same(manifestReference.expectedSourceHeaderHash, headerHash) || typeof manifestReference.uri !== "string"
      || toUtf8Bytes(manifestReference.uri).length === 0 || toUtf8Bytes(manifestReference.uri).length > 2048
      || !same(manifestReference.uriHash, keccak256(toUtf8Bytes(manifestReference.uri)))
      || !same(manifestReference.schemaId, ROYALTY_CONTINUITY_SCHEMA)
      || !same(manifestReference.canonicalizationId, ROYALTY_CONTINUITY_CANONICALIZATION)) throw Error("Saved manifest reference is invalid");
    const body = { uri: manifestReference.uri, uriHash: manifestReference.uriHash,
      schemaId: manifestReference.schemaId, canonicalizationId: manifestReference.canonicalizationId };
    const canonicalManifest = royaltyContinuityManifestBytes(this.chainId, coordinates.source, sourceRuntimeHash, coordinates.target, header, body);
    if (!same(saved.canonicalManifest, canonicalManifest)) throw Error("Saved canonical manifest bytes differ");
    const manifestHash = hash(saved.manifestHash, false);
    if (!same(manifestHash, keccak256(canonicalManifest)) || !same(manifestReference.contentHash, manifestHash)) throw Error("Saved manifest hash differs");
    exactKeys(saved.transition, ["actionClass", "scope", "oldValueHash", "newValueHash"]);
    if (saved.transition.actionClass !== 1) throw Error("Saved begin action class differs");
    const scope = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address"],
      [BEGIN_DOMAIN, this.chainId, coordinates.target, coordinates.core, coordinates.source])) as Hex;
    const oldValueHash = keccak256(coder.encode(["bytes32", "uint8", "uint256"], [scope, 0n, 0n])) as Hex;
    const newValueHash = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", HEADER, "address", "bytes32"],
      [scope, manifestHash, sourceRuntimeHash, header, coordinates.authority, authorityRuntimeHash])) as Hex;
    if (!same(hash(saved.transition.scope), scope) || !same(hash(saved.transition.oldValueHash), oldValueHash)
      || !same(hash(saved.transition.newValueHash), newValueHash)) throw Error("Saved begin transition differs");
    return deepFreeze({ chainId, blockNumber: saved.blockNumber as number, blockHash: hash(saved.blockHash, false), ...coordinates,
      sourceRuntimeHash, targetRuntimeHash, coreRuntimeHash, factoryRuntimeHash, authorityRuntimeHash, header, headerHash,
      routes, elections, manifestReference, canonicalManifest, manifestHash,
      transition: { actionClass: 1 as const, scope, oldValueHash, newValueHash } });
  }
  #plan(plan: RoyaltyContinuityPlan): void {
    if (!this.#plans.has(plan) || plan.chainId !== this.chainId || !same(plan.source, this.deployment.source)
      || !same(plan.target, this.deployment.target)) throw Error("Plan belongs to another client or deployment");
  }
  async capture(provider: RPC, uri: string, limits: RoyaltyContinuityCaptureLimits, blockTag: BlockTag = "latest"): Promise<RoyaltyContinuityPlan> {
    exactKeys(limits, ["maxRoutes", "maxElections"]);
    const maxRoutes = uint(limits.maxRoutes), maxElections = uint(limits.maxElections);
    if (maxRoutes > MAX_CAPTURE_ROWS || maxElections > MAX_CAPTURE_ROWS) throw Error("Capture limit exceeds 4096 rows");
    if (typeof uri !== "string" || toUtf8Bytes(uri).length === 0 || toUtf8Bytes(uri).length > 2048) throw Error("Manifest URI must contain 1..2048 UTF-8 bytes");
    const block = await this.#block(provider, blockTag), at = block.number, codes = await this.#codes(provider, at);
    const pointer = await this.#corePointer(provider, at);
    if (!same(String(pointer[0]), this.deployment.source) || !same(String(pointer[1]), codes.source)) throw Error("Core does not select the pinned source runtime");
    const [sourceIdentity, targetIdentity, sourceCapability, targetCapability] = await Promise.all([
      this.#identity(provider, "source", at, codes.core), this.#identity(provider, "target", at, codes.core),
      this.#resolverRead(provider, "source", "supportsInterface", [this.#interfaceId], at),
      this.#resolverRead(provider, "target", "supportsInterface", [this.#interfaceId], at),
      this.#authority(provider, at, codes.authority),
    ]);
    if (!sourceIdentity.ready || !targetIdentity.ready || sourceCapability[0] !== true || targetCapability[0] !== true
      || sourceIdentity.maximum !== targetIdentity.maximum) throw Error("Resolver continuity capability is unavailable");
    const [rawHeader] = await this.#resolverRead(provider, "source", "continuityHeader", [], at);
    const header = rawHeader as RoyaltyContinuityHeader; this.#assertHeader(header, sourceIdentity.maximum);
    if (header.protectedCount > maxRoutes || header.electionCount > maxElections) throw Error("Source inventory exceeds explicit capture limit");
    const routes: RoyaltyContinuityRoute[] = [], elections: RoyaltyContinuityElection[] = [];
    const routeKeys = new Set<string>(), electionIds = new Set<string>();
    for (let i = 0n; i < header.protectedCount; ++i) {
      const [raw] = await this.#resolverRead(provider, "source", "protectedEconomicRouteAt", [i], at);
      const route = raw as RoyaltyContinuityRoute; this.#assertRoute(route, sourceIdentity.maximum);
      const key = royaltyContinuityRouteKey({ scope: route.scope, scopeId: route.scopeId }); if (routeKeys.has(key)) throw Error("Duplicate protected route key");
      routeKeys.add(key); routes.push(route);
    }
    for (let i = 0n; i < header.electionCount; ++i) {
      const [raw] = await this.#resolverRead(provider, "source", "economicElectionAt", [i], at);
      const election = raw as RoyaltyContinuityElection;
      if (election.collectionId === 0n || (election.mode !== 1n && election.mode !== 2n) || same(election.hashOrigin, ZeroAddress)
        || !same(election.electionHash, royaltyContinuityElectionHash(this.chainId, this.deployment.core, election))) throw Error("Invalid immutable royalty election");
      const key = election.collectionId.toString(); if (electionIds.has(key)) throw Error("Duplicate royalty election");
      electionIds.add(key); elections.push(election);
    }
    const roots = royaltyContinuityRoots(this.chainId, this.deployment.core, routes, elections);
    if (!same(roots.protectedRoot, header.protectedRoot) || !same(roots.electionRoot, header.electionRoot)
      || !same(royaltyContinuityFrozenStateHash(this.chainId, header), header.frozenStateHash)) throw Error("Source inventory does not reproduce its immutable header");
    const headerHash = royaltyContinuityHeaderHash(header), uriHash = keccak256(toUtf8Bytes(uri)) as Hex;
    const referenceBase = { uri, uriHash, schemaId: ROYALTY_CONTINUITY_SCHEMA, canonicalizationId: ROYALTY_CONTINUITY_CANONICALIZATION };
    const canonicalManifest = royaltyContinuityManifestBytes(this.chainId, this.deployment.source, codes.source, this.deployment.target, header, referenceBase);
    const manifestHash = keccak256(canonicalManifest) as Hex;
    const manifestReference = Object.freeze({ expectedSourceHeaderHash: headerHash, contentHash: manifestHash, ...referenceBase });
    const preview = await this.#resolverRead(provider, "target", "previewEconomicContinuity", [this.deployment.source, manifestReference], at);
    const scope = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address"],
      [BEGIN_DOMAIN, this.chainId, this.deployment.target, this.deployment.core, this.deployment.source])) as Hex;
    const oldValueHash = keccak256(coder.encode(["bytes32", "uint8", "uint256"], [scope, 0n, 0n])) as Hex;
    const newValueHash = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", HEADER, "address", "bytes32"],
      [scope, manifestHash, codes.source, header, this.deployment.authority, codes.authority])) as Hex;
    for (const [actual, expected] of [[preview[0], manifestHash], [preview[1], scope], [preview[2], oldValueHash], [preview[3], newValueHash]]) {
      if (!same(String(actual), String(expected))) throw Error("Candidate preview differs from independent continuity preimage");
    }
    const [endHeader] = await this.#resolverRead(provider, "source", "continuityHeader", [], at);
    if (!same(royaltyContinuityHeaderHash(endHeader as RoyaltyContinuityHeader), headerHash)
      || (await provider.getBlock(at))?.hash?.toLowerCase() !== block.hash) throw Error("Pinned source block changed during capture");
    const plan = deepFreeze({ chainId: this.chainId, blockNumber: at, blockHash: block.hash, ...this.deployment,
      sourceRuntimeHash: codes.source, targetRuntimeHash: codes.target, coreRuntimeHash: codes.core,
      factoryRuntimeHash: codes.factory, authorityRuntimeHash: codes.authority, header, headerHash,
      routes, elections, manifestReference, canonicalManifest, manifestHash,
      transition: { actionClass: 1 as const, scope, oldValueHash, newValueHash } }) as RoyaltyContinuityPlan;
    this.#plans.add(plan); return plan;
  }
  begin(plan: RoyaltyContinuityPlan): RoyaltyContinuityAction {
    this.#plan(plan);
    const action = Object.freeze({ kind: "begin", caller: this.deployment.authority,
      call: this.#resolverCall("target", "beginEconomicContinuity", [this.deployment.source, plan.manifestReference]),
      source: plan.source, target: plan.target, sourceHeaderHash: plan.headerHash, manifestHash: plan.manifestHash });
    this.#actions.add(action); return action;
  }
  /** Reconstruct all saved commitments, then bind them to current chain state before resuming. */
  async restore(provider: RPC, saved: unknown, blockTag: BlockTag = "latest"): Promise<{ readonly plan: RoyaltyContinuityPlan; readonly observation: RoyaltyContinuityObservation }> {
    const plan = this.#reconstruct(saved);
    const capturedBlock = await provider.getBlock(plan.blockNumber);
    if (!capturedBlock?.hash || !same(capturedBlock.hash, plan.blockHash)) throw Error("Saved capture block provenance differs");
    const capturedCodes = await this.#codes(provider, plan.blockNumber);
    for (const [name, expected] of [["source", plan.sourceRuntimeHash], ["target", plan.targetRuntimeHash], ["core", plan.coreRuntimeHash],
      ["factory", plan.factoryRuntimeHash], ["authority", plan.authorityRuntimeHash]] as const) {
      if (!same(capturedCodes[name], expected)) throw Error(`Saved capture ${name} runtime provenance differs`);
    }
    const [capturedHeader, capturedPointer, sourceIdentity, targetIdentity] = await Promise.all([
      this.#resolverRead(provider, "source", "continuityHeader", [], plan.blockNumber), this.#corePointer(provider, plan.blockNumber),
      this.#identity(provider, "source", plan.blockNumber, plan.coreRuntimeHash), this.#identity(provider, "target", plan.blockNumber, plan.coreRuntimeHash),
      this.#authority(provider, plan.blockNumber, plan.authorityRuntimeHash),
    ]);
    if (!same(royaltyContinuityHeaderHash(capturedHeader[0] as RoyaltyContinuityHeader), plan.headerHash)
      || !same(String(capturedPointer[0]), plan.source) || !same(String(capturedPointer[1]), plan.sourceRuntimeHash)
      || !sourceIdentity.ready || !targetIdentity.ready || sourceIdentity.maximum !== plan.header.maxRoyaltyBps
      || targetIdentity.maximum !== plan.header.maxRoyaltyBps) throw Error("Saved capture resolver provenance differs");
    const capturedPreview = await this.#resolverRead(provider, "target", "previewEconomicContinuity", [plan.source, plan.manifestReference], plan.blockNumber);
    for (const [actual, expected] of [[capturedPreview[0], plan.manifestHash], [capturedPreview[1], plan.transition.scope],
      [capturedPreview[2], plan.transition.oldValueHash], [capturedPreview[3], plan.transition.newValueHash]]) {
      if (!same(String(actual), String(expected))) throw Error("Saved capture preview provenance differs");
    }
    if (!same(String((await provider.getBlock(plan.blockNumber))?.hash ?? ""), plan.blockHash)) throw Error("Saved capture block changed during restore");
    this.#plans.add(plan);
    try {
      return Object.freeze({ plan, observation: await this.inspect(provider, plan, blockTag) });
    } catch (error) {
      this.#plans.delete(plan); throw error;
    }
  }
  async inspect(provider: RPC, plan: RoyaltyContinuityPlan, blockTag: BlockTag = "latest"): Promise<RoyaltyContinuityObservation> {
    this.#plan(plan); const block = await this.#block(provider, blockTag), at = block.number, codes = await this.#codes(provider, at);
    for (const [name, expected] of [["source", plan.sourceRuntimeHash], ["target", plan.targetRuntimeHash], ["core", plan.coreRuntimeHash],
      ["factory", plan.factoryRuntimeHash], ["authority", plan.authorityRuntimeHash]] as const) {
      if (!same(codes[name], expected)) throw Error(`Pinned ${name} runtime changed`);
    }
    const pointer = await this.#corePointer(provider, at);
    if (!same(String(pointer[0]), plan.source) || !same(String(pointer[1]), plan.sourceRuntimeHash)) throw Error("Pinned source is no longer the current Core resolver");
    const [sourceIdentity, targetIdentity] = await Promise.all([
      this.#identity(provider, "source", at, plan.coreRuntimeHash), this.#identity(provider, "target", at, plan.coreRuntimeHash),
      this.#authority(provider, at, plan.authorityRuntimeHash),
    ]);
    if (!sourceIdentity.ready || sourceIdentity.maximum !== plan.header.maxRoyaltyBps || targetIdentity.maximum !== plan.header.maxRoyaltyBps) {
      throw Error("Current resolver identity or source readiness changed");
    }
    const [sourceHeader, targetState, ready, storedSource, storedManifest] = await Promise.all([
      this.#resolverRead(provider, "source", "continuityHeader", [], at), this.#resolverRead(provider, "target", "economicContinuityState", [], at),
      this.#resolverRead(provider, "target", "economicContinuityReady", [], at), this.#resolverRead(provider, "target", "continuitySource", [], at),
      this.#resolverRead(provider, "target", "continuityManifestHash", [], at),
    ]);
    if (!same(royaltyContinuityHeaderHash(sourceHeader[0] as RoyaltyContinuityHeader), plan.headerHash)) throw Error("Pinned source header changed");
    const state = targetState[0] as RoyaltyContinuityImportState;
    if (state.status > 2n || state.importedRoutes > plan.header.protectedCount || state.importedElections > plan.header.electionCount) throw Error("Invalid candidate import state");
    let phase: RoyaltyContinuityObservation["phase"], supports = false;
    if (state.status === 0n) {
      if (ready[0] !== true || !same(String(storedSource[0]), ZeroAddress) || !same(String(storedManifest[0]), ZeroHash)
        || state.importedRoutes !== 0n || state.importedElections !== 0n) throw Error("Candidate is not a pristine continuation target");
      if (!targetIdentity.ready) throw Error("Pristine candidate does not report ready");
      const preview = await this.#resolverRead(provider, "target", "previewEconomicContinuity", [plan.source, plan.manifestReference], at);
      for (const [actual, expected] of [[preview[0], plan.manifestHash], [preview[1], plan.transition.scope],
        [preview[2], plan.transition.oldValueHash], [preview[3], plan.transition.newValueHash]]) {
        if (!same(String(actual), String(expected))) throw Error("Candidate is no longer pristine for the pinned preview");
      }
      phase = "awaiting-begin";
    } else {
      if (!same(state.source, plan.source) || !same(state.sourceRuntimeHash, plan.sourceRuntimeHash)
        || !same(state.manifestHash, plan.manifestHash) || !same(royaltyContinuityHeaderHash(state.expected), plan.headerHash)
        || !same(keccak256(encode(MANIFEST, state.manifestReference)), keccak256(encode(MANIFEST, plan.manifestReference)))
        || !same(String(storedSource[0]), plan.source) || !same(String(storedManifest[0]), plan.manifestHash)) throw Error("Candidate continuation belongs to changed source or manifest");
      if (state.status === 1n) {
        if (ready[0] !== false) throw Error("Importing candidate incorrectly reports ready");
        phase = state.importedRoutes === plan.header.protectedCount && state.importedElections === plan.header.electionCount
          ? "ready-to-complete" : "importing";
      } else {
        if (ready[0] !== true || state.importedRoutes !== plan.header.protectedCount || state.importedElections !== plan.header.electionCount) throw Error("Completed candidate is incomplete");
        const capability = await this.#resolverRead(provider, "target", "supportsEconomicContinuity",
          [plan.source, plan.header.frozenStateHash, plan.manifestHash], at);
        if (capability[0] !== true) throw Error("Completed candidate lacks live pinned continuity capability");
        supports = true; phase = "completed";
      }
    }
    if ((await provider.getBlock(at))?.hash?.toLowerCase() !== block.hash) throw Error("Observed block changed; repeat inspection");
    return Object.freeze({ phase, blockNumber: at, blockHash: block.hash, importedRoutes: state.importedRoutes,
      importedElections: state.importedElections, ready: ready[0] as boolean, supportsPinnedContinuity: supports, coreStillUsesSource: true });
  }
  async next(provider: RPC, plan: RoyaltyContinuityPlan, caller: Address, chunk: RoyaltyContinuityChunk = { maxRoutes: 16n, maxElections: 64n }, blockTag: BlockTag = "latest") {
    this.#plan(plan); const actor = address(caller); exactKeys(chunk, ["maxRoutes", "maxElections"]);
    const maxRoutes = uint(chunk.maxRoutes), maxElections = uint(chunk.maxElections);
    if (maxRoutes > 16n || maxElections > 64n || (maxRoutes === 0n && maxElections === 0n)) throw Error("Import chunk exceeds 16 routes / 64 elections");
    const observation = await this.inspect(provider, plan, blockTag);
    if (observation.phase === "awaiting-begin") throw Error("Governed begin has not executed");
    if (observation.phase === "completed") return Object.freeze({ kind: "completed" as const, observation });
    if (observation.phase === "importing") {
      if (observation.importedElections < plan.header.electionCount && maxElections === 0n) throw Error("Chunk cannot advance pending elections");
      if (observation.importedElections === plan.header.electionCount
        && observation.importedRoutes < plan.header.protectedCount && maxRoutes === 0n) throw Error("Chunk cannot advance pending routes");
    }
    const kind = observation.phase === "ready-to-complete" ? "complete" as const : "import" as const;
    const call = kind === "complete" ? this.#resolverCall("target", "completeEconomicContinuity")
      : this.#resolverCall("target", "importEconomicContinuity", [maxRoutes, maxElections]);
    const action = Object.freeze({ kind, caller: actor, call, source: plan.source, target: plan.target,
      sourceHeaderHash: plan.headerHash, manifestHash: plan.manifestHash }) as RoyaltyContinuityAction;
    this.#actions.add(action);
    return Object.freeze({ kind, observation, action });
  }
  safeCall(action: RoyaltyContinuityAction): SafeCall {
    if (!this.#actions.has(action) || !same(action.target, this.deployment.target) || !same(action.call.to, this.deployment.target) || action.call.value !== 0n) throw Error("Changed continuity action");
    if (action.kind === "begin") throw Error("Begin must execute inside the canonical governance authority action, not as a direct Safe CALL");
    return toSafeCall(action.call);
  }
  async simulate(provider: Pick<Provider, "call" | "getNetwork">, action: RoyaltyContinuityAction, blockTag: BlockTag = "latest"): Promise<string> {
    if (!this.#actions.has(action) || (await provider.getNetwork()).chainId !== this.chainId || !same(action.call.to, this.deployment.target) || action.call.value !== 0n) throw Error("Simulation coordinates differ");
    if (action.kind === "begin") throw Error("Begin simulation requires the canonical governance authority's executing action context");
    return provider.call({ ...action.call, from: address(action.caller), blockTag });
  }
}
