import {
  AbiCoder, Interface, ParamType, ZeroAddress as ETH_ZERO_ADDRESS, ZeroHash as ETH_ZERO_HASH,
  getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider, type EventFragment
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { requireSafeExecution } from "./safe.js";
import * as pub from "./current-scoped-policy-publication-v2.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import {
  inspectScopedPolicyGraphV2Current,
  type ScopedPolicyGraphV2Deployment,
  type ScopedPolicyGraphV2Capture
} from "./current-scoped-policy-graph-v2-workflow.js";

type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
export interface ScopedPolicyPublicationV2CodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}
export interface ScopedPolicyPublicationV2Block {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}
/** Pins must come from reviewed release/link metadata; supplied hashes do not prove source. */
export interface ScopedPolicyPublicationV2Deployment {
  readonly graph: ScopedPolicyGraphV2Deployment;
  readonly linkedDependencies: readonly ScopedPolicyPublicationV2CodePin[];
}
/** Immutable local history remains available without current graph/source admission. */
export interface ScopedPolicyPublicationV2HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly checkpoint: ScopedPolicyPublicationV2CodePin;
  readonly output: ScopedPolicyPublicationV2CodePin;
  readonly snapshot: ScopedPolicyPublicationV2CodePin;
  readonly linkedDependencies: readonly ScopedPolicyPublicationV2CodePin[];
}
const ZERO = ETH_ZERO_HASH as Hex;
const ZERO_ADDRESS = ETH_ZERO_ADDRESS as Address;
const coder = AbiCoder.defaultAbiCoder();
const MAX_RPC = 2_097_152;
const MAX_RUNTIME = 131_072;
const MAX_LOGS = 4096;
const MAX_CALL = 2_097_152;
const MAX_TOKENS = 256;

function keys(value: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || required.some(key => !Object.hasOwn(value, key))
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || ![...required, ...optional].includes(key))) {
    throw Error("Missing or unknown properties");
  }
}

function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!zero && result === ZERO_ADDRESS) throw Error("Zero address");
  return result;
}

function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!zero && value.toLowerCase() === ZERO)) throw Error("Expected bytes32");
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, maximum = MAX_RPC): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw Error("Expected bounded unsigned bigint");
  }
  return value;
}

function number(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw Error("Expected concrete block/index");
  }
  return value;
}

function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}

function stable(value: unknown): string {
  function convert(v: unknown): unknown {
    if (v === null) return ["null"];
    if (typeof v === "string" || typeof v === "boolean") return [typeof v, v];
    if (typeof v === "bigint") return ["bigint", v.toString()];
    if (typeof v === "number" && Number.isFinite(v)) return ["number", v];
    if (Array.isArray(v)) return ["array", v.map(convert)];
    if (v && typeof v === "object") {
      return ["object", Object.keys(v).sort().map(key => [key, convert((v as Record<string, unknown>)[key])])];
    }
    throw Error("Unsupported canonical value");
  }
  return JSON.stringify(convert(value));
}

function equal(a: unknown, b: unknown, reason = "Observed facts changed; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}

function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}

function fingerprint(value: unknown): Hex {
  return keccak256(toUtf8Bytes(stable(value))) as Hex;
}

function codePin(value: ScopedPolicyPublicationV2CodePin): ScopedPolicyPublicationV2CodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function pinList(value: readonly ScopedPolicyPublicationV2CodePin[]): readonly ScopedPolicyPublicationV2CodePin[] {
  if (!Array.isArray(value) || value.length > 256) throw Error("Linked dependency limit exceeded");
  const pins = value.map(codePin);
  if (new Set(pins.map(pin => pin.address)).size !== pins.length) throw Error("Duplicate linked dependency");
  return pins;
}

async function header(provider: Reader, tag: number): Promise<ScopedPolicyPublicationV2Block> {
  const value = await provider.getBlock(number(tag));
  if (!value || value.number !== tag) throw Error("Missing or mismatched block");
  return { blockNumber: tag, blockHash: hash(value.hash), timestamp: BigInt(number(value.timestamp)) };
}

async function unchanged(provider: Reader, block: ScopedPolicyPublicationV2Block): Promise<void> {
  equal(await header(provider, block.blockNumber), block, "Pinned block changed");
}

async function runtime(provider: Reader, pin: ScopedPolicyPublicationV2CodePin, tag: number): Promise<void> {
  const raw = bytes(await provider.getCode(pin.address, tag), MAX_RUNTIME);
  if (raw === "0x" || (raw.length === 48 && raw.startsWith("0xef0100"))
    || !same(keccak256(raw), pin.codeHash)) throw Error("Pinned runtime differs");
}

function plain(param: ParamType, value: unknown): unknown {
  if (param.baseType === "array") return (value as readonly unknown[]).map(item => plain(param.arrayChildren!, item));
  if (param.baseType === "tuple") {
    const fields = param.components!;
    if (fields.every(field => field.name !== "")) {
      return Object.fromEntries(fields.map((field, index) => [field.name, plain(field, (value as readonly unknown[])[index])]));
    }
    return fields.map((field, index) => plain(field, (value as readonly unknown[])[index]));
  }
  return value;
}

async function rpc(provider: Reader, target: Address, iface: Interface, method: string,
  args: readonly unknown[], tag: number, from?: Address, gasLimit?: bigint): Promise<readonly unknown[]> {
  const data = iface.encodeFunctionData(method, args);
  const result = bytes(await provider.call({ to: target, data, blockTag: tag, ...(from ? { from } : {}),
    ...(gasLimit ? { gasLimit } : {}) }));
  const decoded = iface.decodeFunctionResult(method, result);
  if (!same(iface.encodeFunctionResult(method, decoded), result)) throw Error("Noncanonical RPC result");
  return iface.getFunction(method)!.outputs.map((param, index) => plain(param, decoded[index]));
}

const selectionAbi = new Interface([
  "function checkpoint(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot))",
  "function requireCurrentCheckpoint(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot))",
  "function selectionAt(bytes32 id, uint256 index) view returns ((uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes))"
]);

const artifactCoverageAbi = new Interface([
  "function requireArtifactCoverage(bytes32 hash, bytes32 artistId, bytes32 artifactHash) view returns ((bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) result)",
  "function artifactChunk(bytes32 hash, uint32 index) view returns (address, bytes32)"
]);

const servingFactsAbi = new Interface([
  "function artistPresentation(uint256 collectionId) view returns ((bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash))"
]);

const staticRouterAbi = new Interface([
  "function resolvedMetadataConfig(uint256 tokenId) view returns ((bytes32 recordHash, bytes32 previous, uint256 collectionId, uint256 tokenId, uint64 revision, uint64 defaultRevision, uint8 level, bytes32 sourceSnapshotHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, (uint8 mode, address renderer, string baseURI, string pendingURI, uint8 offchainURIIdMode, bool frozen) config))",
  "function staticRenderSourceForConfig(uint256 collectionId, bytes32 recordHash) view returns ((uint256 chainId, bool configured, string name, string description, string imageURI, string animationBaseURI, string script, (address host, bytes32 codeHash, bytes32 manifestHash) scriptManifest, (address host, bytes32 codeHash, bytes32 manifestHash) mediaManifest), (uint8 mode, address renderer, string baseURI, string pendingURI, uint8 offchainURIIdMode, bool frozen))"
]);

const fullViewsAbi = new Interface([
  "function tokenJSON(uint256 tokenId) view returns (string)",
  "function tokenHTML(uint256 tokenId) view returns (string)"
]);

const coreIdentityAbi = new Interface([
  "function coordinatorAtMint(uint256 tokenId) view returns (address)"
]);

const coreAbi = new Interface([
  "function tokenData(uint256 tokenId) view returns (bytes)"
]);

const sourceSetAbi = new Interface([
  "function tokenEntropyReadiness(uint256 tokenId) view returns ((address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) t)"
]);

const readinessAbi = new Interface([
  "function requireTerminalRenderReady(uint256 tokenId) view returns (((address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 configRecordHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, address registry, bytes32 registryCodeHash, bytes32 admissionHash, bytes32 policyChainHash, bytes32 evidenceHash) e)"
]);

const staticEntropyAbi = new Interface([
  "function staticTokenRenderFacts(uint256 tokenId) view returns (uint8 status, bytes32 seed, address provider)"
]);

const metadataAbi = new Interface([
  "function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account) view returns (bool, uint64)"
]);

const storeAbi = new Interface([
  "function chunk(bytes32) view returns (address pointer, uint32 length)"
]);

function deployment(value: ScopedPolicyPublicationV2Deployment): ScopedPolicyPublicationV2Deployment {
  keys(value, ["graph", "linkedDependencies"]);
  // The graph reader performs exact structural normalization of its own deployment.
  return freeze({ graph: structuredClone(value.graph), linkedDependencies: pinList(value.linkedDependencies) });
}

function coordinates(c: ScopedPolicyGraphV2Capture): pub.ScopedPolicyPublicationV2Coordinates {
  return {
    chainId: c.deployment.chainId,
    core: c.recipe.inventory.targets[0],
    metadata: c.recipe.inventory.targets[1],
    checkpoint: c.graph.children[1],
    output: c.graph.children[2],
    snapshot: c.graph.children[3]
  };
}

async function context(provider: Reader, d: ScopedPolicyPublicationV2Deployment,
  scope: graph.ScopedPolicyGraphV2Scope, tag: number): Promise<ScopedPolicyGraphV2Capture> {
  const result = await inspectScopedPolicyGraphV2Current(provider, d.graph, scope, { blockTag: tag });
  for (const pin of d.linkedDependencies) await runtime(provider, pin, tag);
  return result.capture;
}

async function read<T>(provider: Reader, target: Address, iface: Interface, method: string,
  args: readonly unknown[], tag: number): Promise<T> {
  const result = await rpc(provider, target, iface, method, args, tag);
  return (result.length === 1 ? result[0] : result) as T;
}

function encoded(iface: Interface, method: string, value: unknown): Hex {
  return coder.encode([iface.getFunction(method)!.outputs[0]!], [value]) as Hex;
}

function boundedCount(value: bigint): number {
  if (value < 0n || value > BigInt(MAX_TOKENS)) throw Error("Client token inventory exceeds 256 rows");
  return Number(value);
}

function gas(value: unknown): bigint {
  const result = uint(value);
  if (result === 0n || result > 100_000_000n) throw Error("Simulation gas must be 1..100000000");
  return result;
}

function host(kind: pub.ScopedPolicyPublicationV2Request["kind"]): "checkpoint" | "output" | "snapshot" {
  return kind === "begin" || kind === "append" ? "checkpoint"
    : kind === "beginManifest" || kind === "verifyNextOutputs" ? "output" : "snapshot";
}

async function selected(provider: Reader, c: ScopedPolicyGraphV2Capture, selectionId: Hex, tag: number) {
  const selectionHost = c.recipe.targets[1];
  const value = pub.normalizeScopedPolicyPublicationV2SelectionPlan(
    await read(provider, selectionHost, selectionAbi, "requireCurrentCheckpoint", [selectionId], tag)
  );
  equal(value.scope, c.graph.scope, "Selection full scope differs");
  equal([value.membershipHash, value.tokenCount],
    [c.inventory.membership.membershipHash, c.inventory.membership.tokenCount], "Selection membership differs");
  if (value.tokenCount === 0n || value.nextIndex !== value.tokenCount || value.selectionRoot === ZERO) {
    throw Error("Selection must be genuinely complete");
  }
  const rows: pub.ScopedPolicyPublicationV2TokenSelection[] = [];
  for (let i = 0; i < boundedCount(value.tokenCount); i++) {
    const row = pub.normalizeScopedPolicyPublicationV2TokenSelection(
      await read(provider, selectionHost, selectionAbi, "selectionAt", [selectionId, BigInt(i)], tag)
    );
    if (row.tokenId === 0n || (i > 0 && row.tokenId <= rows[i - 1]!.tokenId)
      || (value.scope.scopeType === 1n && row.tokenId !== value.scope.tokenId)) throw Error("Selection token order differs");
    rows.push(row);
  }
  return freeze({ plan: value, rows });
}

async function content(provider: Reader, c: ScopedPolicyGraphV2Capture, key: Hex, tag: number, current: boolean) {
  const iface = pub.scopedPolicyPublicationV2Interface("checkpoint");
  const plan = pub.normalizeScopedPolicyPublicationV2ContentPlan(
    await read(provider, c.graph.children[1], iface, current ? "requireCurrentCheckpoint" : "checkpoint", [key], tag)
  );
  if (plan.tokenCount === 0n || plan.nextIndex > plan.tokenCount) throw Error("Unknown or inconsistent content checkpoint");
  boundedCount(plan.tokenCount);
  equal(plan.scope, c.graph.scope, "Content full scope differs");
  equal([plan.inventoryHash, plan.policyChainHash],
    [c.inventory.progress.commitment, c.inventory.policyChainHash], "Content source inventory differs");
  const selection = await selected(provider, c, plan.selectionId, tag);
  equal(plan.selectionHash, keccak256(encoded(selectionAbi, "checkpoint", selection.plan)), "Selection state hash differs");
  const outputs: pub.ScopedPolicyPublicationV2Output[] = [];
  for (let i = 0; i < boundedCount(plan.nextIndex); i++) {
    outputs.push(pub.normalizeScopedPolicyPublicationV2Output(
      await read(provider, c.graph.children[1], iface, "outputAt", [key, BigInt(i)], tag)
    ));
  }
  return freeze({ key, plan, selection, outputs });
}

interface Coverage {
  readonly completionHash: Hex;
  readonly artifactHash: Hex;
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly chunkCount: bigint;
  readonly firstFamilyRecordHash: Hex;
  readonly secondFamilyRecordHash: Hex;
  readonly validationEpoch: bigint;
  readonly evidenceChainHash: Hex;
}

async function covered(provider: Reader, c: ScopedPolicyGraphV2Capture,
  coverageHash: Hex, artistId: Hex, artifactHash: Hex, tag: number) {
  const target = c.recipe.inventory.targets[10];
  const coverage = await read(provider, target, artifactCoverageAbi, "requireArtifactCoverage",
    [coverageHash, artistId, artifactHash], tag) as Coverage;
  equal([coverage.completionHash, coverage.artistId, coverage.artifactHash], [coverageHash, artistId, artifactHash],
    "Coverage identity differs");
  if (coverage.firstFamilyRecordHash === ZERO || coverage.secondFamilyRecordHash === ZERO
    || coverage.firstFamilyRecordHash === coverage.secondFamilyRecordHash
    || coverage.byteLength === 0n || coverage.byteLength > 524_288n
    || coverage.chunkCount !== (coverage.byteLength + 8191n) / 8192n) throw Error("Invalid complete artifact coverage");
  let joined = "0x";
  const chunks: { pointer: Address; codeHash: Hex; bytes: Hex }[] = [];
  for (let i = 0n; i < coverage.chunkCount; i++) {
    const [pointer_, codeHash_] = await rpc(provider, target, artifactCoverageAbi, "artifactChunk", [artifactHash, i], tag);
    const pointer = address(pointer_);
    const codeHash = hash(codeHash_);
    const raw = bytes(await provider.getCode(pointer, tag), 8193);
    const length = coverage.byteLength - i * 8192n;
    if (!raw.startsWith("0x00") || BigInt((raw.length - 4) / 2) !== (length > 8192n ? 8192n : length)
      || !same(keccak256(raw), codeHash)) throw Error("Artifact STOP carrier differs");
    const payload = `0x${raw.slice(4)}` as Hex;
    chunks.push({ pointer, codeHash, bytes: payload });
    joined += raw.slice(4);
  }
  if (!same(keccak256(joined), coverage.contentHash)) throw Error("Covered artifact content hash differs");
  return freeze({ coverage, canonical: joined as Hex, chunks });
}

async function observeOutput(provider: Reader, c: ScopedPolicyGraphV2Capture,
  plan: pub.ScopedPolicyPublicationV2ContentPlan, row: pub.ScopedPolicyPublicationV2TokenSelection,
  imageHash: Hex, animation: Hex | null, tag: number): Promise<pub.ScopedPolicyPublicationV2Output> {
  const coord = coordinates(c);
  const router = c.recipe.inventory.targets[4];
  const config = await read(provider, router, staticRouterAbi, "resolvedMetadataConfig", [row.tokenId], tag) as {
    recordHash: Hex; config: { mode: bigint; frozen: boolean }; selection: unknown;
  };
  if (!same(keccak256(encoded(staticRouterAbi, "resolvedMetadataConfig", config)), row.configHash)
    || config.recordHash !== row.configRecordHash || config.config.mode !== 1n || !config.config.frozen) {
    throw Error("Current STATIC configuration differs");
  }
  equal(config.selection, row.selection, "Current renderer selection differs");
  if (!same(row.selection.rendererId, id("6529STREAM_RENDERER_V1"))
    || !same(row.selection.rendererVersion, id("6529STREAM_STATIC_RENDERER_V1"))) throw Error("Not the original STATIC renderer");
  const source = await rpc(provider, router, staticRouterAbi, "staticRenderSourceForConfig",
    [plan.scope.collectionId, row.configRecordHash], tag);
  const outputs = staticRouterAbi.getFunction("staticRenderSourceForConfig")!.outputs;
  if (!same(keccak256(coder.encode([outputs[0]!], [source[0]])), row.rawSourceHash)) throw Error("STATIC source hash differs");
  equal(source[1], config.config, "STATIC selected config differs");
  for (let i = 0; i < row.sources.length; i++) {
    if (row.sources[i] !== ZERO_ADDRESS) await runtime(provider, { address: row.sources[i]!, codeHash: row.sourceCodeHashes[i]! }, tag);
  }
  const coordinator = address(await read(provider, coord.core, coreIdentityAbi, "coordinatorAtMint", [row.tokenId], tag));
  if (coordinator !== row.sources[3]) throw Error("Original at-mint Coordinator differs");
  const entropy = pub.normalizeScopedPolicyPublicationV2TokenReadiness(
    await read(provider, c.graph.sourceSet, sourceSetAbi, "tokenEntropyReadiness", [row.tokenId], tag)
  );
  equal([entropy.coordinator, entropy.coordinatorCodeHash], [coordinator, row.sourceCodeHashes[3]], "Token policy Coordinator differs");
  if (entropy.policyHash === ZERO) throw Error("Missing token policy");
  let terminalAdmissionHash = ZERO;
  if (entropy.terminal) {
    if (entropy.finalized || entropy.seed !== ZERO || entropy.renderRequirement !== 1n
      || !((entropy.status === 1n && entropy.mode === 0n) || (entropy.status === 2n && entropy.mode === 2n))) {
      throw Error("Invalid terminal policy readiness");
    }
    const terminal = pub.normalizeScopedPolicyPublicationV2TerminalEvidence(
      await read(provider, c.graph.children[0], readinessAbi, "requireTerminalRenderReady", [row.tokenId], tag)
    );
    equal(terminal.entropy, entropy, "Terminal entropy differs");
    for (const name of ["versionKey", "renderer", "rendererCodeHash", "registry", "registryCodeHash"] as const) {
      equal(terminal[name], row.selection[name], "Terminal renderer binding differs");
    }
    if (terminal.configRecordHash !== row.configRecordHash || terminal.policyChainHash !== plan.policyChainHash
      || terminal.admissionHash === ZERO || terminal.evidenceHash === ZERO) throw Error("Terminal admission differs");
    terminalAdmissionHash = keccak256(encoded(readinessAbi, "requireTerminalRenderReady", terminal)) as Hex;
  } else {
    if (!entropy.finalized || entropy.status !== 5n || entropy.mode !== 2n || entropy.renderRequirement !== 0n) {
      throw Error("Nonterminal token is not finalized ASYNC_REQUIRED");
    }
    const [status, seed] = await rpc(provider, coordinator, staticEntropyAbi, "staticTokenRenderFacts", [row.tokenId], tag);
    if (status !== 5n || seed !== entropy.seed) throw Error("Native finalized entropy differs");
  }
  const data = bytes(await read(provider, coord.core, coreAbi, "tokenData", [row.tokenId], tag), 16384);
  const json = toUtf8Bytes(await read(provider, router, fullViewsAbi, "tokenJSON", [row.tokenId], tag) as string);
  const html = toUtf8Bytes(await read(provider, router, fullViewsAbi, "tokenHTML", [row.tokenId], tag) as string);
  if (json.length === 0 || html.length === 0 || json.length > MAX_RPC || html.length > MAX_RPC) throw Error("Rendered byte bound exceeded");
  if (animation !== null && !same(keccak256(animation), keccak256(html))) throw Error("Supplied animation differs from actual HTML");
  const profile = id("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2");
  const value: pub.ScopedPolicyPublicationV2Output = {
    leaf: { tokenId: row.tokenId, metadataHash: keccak256(json) as Hex, imageHash,
      animationHash: keccak256(html) as Hex, contentHash: ZERO, tokenDataHash: keccak256(data) as Hex },
    selectionRowHash: keccak256(coder.encode(
      ["bytes32", "uint256", "address", "address", selectionAbi.getFunction("selectionAt")!.outputs[0]!],
      [id("6529STREAM_STATIC_SELECTION_ROW_V1"), coord.chainId, coord.core, router, row]
    )) as Hex,
    sourceFactsHash: keccak256(coder.encode(
      ["bytes32", "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
      [profile, row.configHash, row.rawSourceHash, coordinator, encoded(sourceSetAbi, "tokenEntropyReadiness", entropy),
        c.graph.sourceSet, c.graph.sourceSetCodeHash, plan.inventoryHash, plan.policyChainHash,
        c.graph.children[0], c.graph.codeHashes[0], terminalAdmissionHash]
    )) as Hex,
    htmlHash: keccak256(html) as Hex,
    entropy,
    terminalAdmissionHash
  };
  return pub.normalizeScopedPolicyPublicationV2Output(value);
}

function progressed(c: ScopedPolicyGraphV2Capture, before: pub.ScopedPolicyPublicationV2ContentPlan,
  outputs: readonly pub.ScopedPolicyPublicationV2Output[]): pub.ScopedPolicyPublicationV2ContentPlan {
  let leafChainHash = ZERO;
  let outputRoot = ZERO;
  const coord = coordinates(c);
  for (let i = 0; i < outputs.length; i++) {
    const leafHash = pub.scopedPolicyPublicationV2LeafHash(coord.chainId, coord.core, outputs[i]!.leaf);
    leafChainHash = pub.scopedPolicyPublicationV2LeafChain(leafChainHash, BigInt(i), leafHash);
    outputRoot = pub.scopedPolicyPublicationV2OutputChain(outputRoot, BigInt(i), outputs[i]!);
  }
  return freeze({ ...before, nextIndex: BigInt(outputs.length), leafChainHash, outputRoot,
    contentRoot: BigInt(outputs.length) === before.tokenCount
      ? pub.scopedPolicyPublicationV2ContentRoot(coord.chainId, coord.core, outputs.map(row => row.leaf)) : ZERO });
}

async function checkpointStage(provider: Reader, c: ScopedPolicyGraphV2Capture,
  request: Extract<pub.ScopedPolicyPublicationV2Request, { kind: "begin" | "append" }>, tag: number) {
  const iface = pub.scopedPolicyPublicationV2Interface("checkpoint");
  if (request.kind === "begin") {
    const selection = await selected(provider, c, request.selectionId, tag);
    const identity: pub.ScopedPolicyPublicationV2CheckpointIdentity = {
      selectionCheckpoint: c.recipe.targets[1], selectionId: request.selectionId, selection: selection.plan,
      entropySourceSet: c.graph.sourceSet, entropySourceSetCodeHash: c.graph.sourceSetCodeHash,
      terminalReadiness: c.graph.children[0], terminalReadinessCodeHash: c.graph.codeHashes[0],
      inventoryHash: c.inventory.progress.commitment, policyChainHash: c.inventory.policyChainHash, salt: request.salt
    };
    const key = pub.scopedPolicyPublicationV2CheckpointId(coordinates(c), identity);
    const before = pub.normalizeScopedPolicyPublicationV2ContentPlan(
      await read(provider, c.graph.children[1], iface, "checkpoint", [key], tag)
    );
    if (before.tokenCount === 0n && !/^0x0+$/.test(pub.encodeScopedPolicyPublicationV2ContentPlan(before))) {
      throw Error("Noncanonical absent content checkpoint");
    }
    const initial = pub.scopedPolicyPublicationV2InitialContentPlan(identity);
    if (before.tokenCount !== 0n) {
      equal({ ...before, nextIndex: 0n, leafChainHash: ZERO, contentRoot: ZERO, outputRoot: ZERO }, initial,
        "Retained checkpoint identity differs");
    }
    return freeze({ kind: "checkpoint" as const, key, before, expected: before.tokenCount === 0n ? initial : before,
      selection, outputs: [] as readonly pub.ScopedPolicyPublicationV2Output[], appended: [] as readonly pub.ScopedPolicyPublicationV2Output[] });
  }
  const saved = await content(provider, c, request.id, tag, false);
  if (BigInt(request.payloads.length) > saved.plan.tokenCount - saved.plan.nextIndex) throw Error("Append exceeds remaining rows");
  // Current checkpoint's view is complete-only. For a partial checkpoint independently re-observe its saved prefix.
  for (let i = 0; i < saved.outputs.length; i++) {
    equal(await observeOutput(provider, c, saved.plan, saved.selection.rows[i]!, saved.outputs[i]!.leaf.imageHash, null, tag),
      saved.outputs[i], "Previously appended output is stale");
  }
  equal(progressed(c, saved.plan, saved.outputs), saved.plan, "Saved checkpoint roots differ");
  const appended: pub.ScopedPolicyPublicationV2Output[] = [];
  for (let i = 0; i < request.payloads.length; i++) {
    const payload = request.payloads[i]!;
    const row = saved.selection.rows[saved.outputs.length + i]!;
    if (payload.tokenId !== row.tokenId) throw Error("Append token differs from complete Selection order");
    appended.push(await observeOutput(provider, c, saved.plan, row,
      payload.image === "0x" ? ZERO : keccak256(payload.image) as Hex, payload.animation, tag));
  }
  return freeze({ kind: "checkpoint" as const, key: request.id, before: saved.plan,
    expected: progressed(c, saved.plan, [...saved.outputs, ...appended]), selection: saved.selection,
    outputs: saved.outputs, appended });
}

async function manifestFacts(provider: Reader, c: ScopedPolicyGraphV2Capture,
  checkpointHash: Hex, artifactHash: Hex, coverageHash: Hex, artistId: Hex, tag: number) {
  await definitions(provider, c.recipe.inventory.targets[2], "output", tag);
  const saved = await content(provider, c, checkpointHash, tag, true);
  const archive = await covered(provider, c, coverageHash, artistId, artifactHash, tag);
  const canonical = pub.scopedPolicyPublicationV2OutputManifestBytes(coordinates(c), checkpointHash,
    saved.plan, c.graph.sourceSet, saved.outputs);
  equal(archive.canonical, canonical, "Preserved manifest header/ordered full outputs differ");
  equal([archive.coverage.schemaId, archive.coverage.canonicalizationId],
    [pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA, pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION],
    "Preserved manifest definitions differ");
  const manifest: pub.ScopedPolicyPublicationV2Manifest = {
    checkpointHash, checkpointStateHash: keccak256(pub.encodeScopedPolicyPublicationV2ContentPlan(saved.plan)) as Hex,
    entropySourceSet: c.graph.sourceSet, inventoryHash: saved.plan.inventoryHash, policyChainHash: saved.plan.policyChainHash,
    artifactHash, coverageHash, artistId, contentRoot: saved.plan.contentRoot, outputRoot: saved.plan.outputRoot,
    manifestHash: keccak256(canonical) as Hex, scope: saved.plan.scope, tokenCount: saved.plan.tokenCount,
    byteLength: BigInt((canonical.length - 2) / 2)
  };
  return freeze({ content: saved, archive, manifest });
}

async function outputStage(provider: Reader, c: ScopedPolicyGraphV2Capture,
  request: Extract<pub.ScopedPolicyPublicationV2Request, { kind: "beginManifest" | "verifyNextOutputs" }>, tag: number) {
  const iface = pub.scopedPolicyPublicationV2Interface("output");
  if (request.kind === "beginManifest") {
    const facts = await manifestFacts(provider, c, request.checkpointHash, request.artifactHash, request.coverageHash, request.artistId, tag);
    const key = pub.scopedPolicyPublicationV2ManifestPlanHash(coordinates(c), c.recipe.inventory.targets[10], facts.manifest);
    const before = pub.normalizeScopedPolicyPublicationV2OutputPlan(
      await read(provider, c.graph.children[2], iface, "manifestPlan", [key], tag)
    );
    if (before.manifest.tokenCount === 0n) {
      if (!/^0x0+$/.test(pub.encodeScopedPolicyPublicationV2OutputPlan(before))) throw Error("Noncanonical absent manifest plan");
    } else equal(before.manifest, facts.manifest, "Retained manifest identity differs");
    return freeze({ kind: "output" as const, key, before, facts,
      expected: before.manifest.tokenCount === 0n ? { manifest: facts.manifest, nextIndex: 0n, recordHash: ZERO } : before });
  }
  const before = pub.normalizeScopedPolicyPublicationV2OutputPlan(
    await read(provider, c.graph.children[2], iface, "manifestPlan", [request.planHash], tag)
  );
  const m = before.manifest;
  if (m.tokenCount === 0n || before.nextIndex > m.tokenCount || request.count > m.tokenCount - before.nextIndex) {
    throw Error("Verify exceeds remaining manifest rows");
  }
  equal(pub.scopedPolicyPublicationV2ManifestPlanHash(coordinates(c), c.recipe.inventory.targets[10], m), request.planHash,
    "Manifest plan identity differs");
  // Deliberately stronger client admission: even nonfinal verification requires the current full graph and coverage.
  const facts = await manifestFacts(provider, c, m.checkpointHash, m.artifactHash, m.coverageHash, m.artistId, tag);
  equal(facts.manifest, m, "Current manifest facts differ");
  const nextIndex = before.nextIndex + request.count;
  const recordHash = nextIndex === m.tokenCount ? pub.scopedPolicyPublicationV2ManifestRecordHash(request.planHash) : ZERO;
  return freeze({ kind: "output" as const, key: request.planHash, before, facts, expected: { manifest: m, nextIndex, recordHash } });
}

async function authority(provider: Reader, metadata: Address, collectionId: bigint,
  family: Hex, caller: Address, tag: number) {
  for (const authorizationClass of [7n, 8n]) {
    const [enabled, revision] = await rpc(provider, metadata, metadataAbi, "familyWriter",
      [authorizationClass === 7n ? collectionId : 0n, family, authorizationClass, caller], tag);
    if (enabled === true && typeof revision === "bigint" && revision !== 0n) {
      return { authorizationClass, grantRevision: revision };
    }
  }
  throw Error("Publisher lacks an original independent family grant");
}

const payloadTypes = ["bytes32", "uint256", "address", "address[11]", "bytes32[11]",
  pub.SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE,
  pub.SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE,
  pub.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE];

function snapshotCanonical(coord: pub.ScopedPolicyPublicationV2Coordinates,
  deps: graph.ScopedPolicyGraphV2SnapshotDependencies, publication: pub.ScopedPolicyPublicationV2Publication,
  receipt: pub.ScopedPolicyPublicationV2Receipt, source: pub.ScopedPolicyPublicationV2Source): Hex {
  return bytes(coder.encode(payloadTypes, [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2"), coord.chainId,
    coord.snapshot, deps.targets, deps.codeHashes, { ...publication, expectedSourceHash: ZERO }, receipt, source]), 524288);
}

async function storeChunks(provider: Reader, store: Address, canonical: Hex, tag: number) {
  const chunks: { readonly hash: Hex; readonly pointer: Address; readonly length: bigint }[] = [];
  for (let offset = 2; offset < canonical.length; offset += 16384) {
    const payload = `0x${canonical.slice(offset, offset + 16384)}` as Hex;
    const chunkHash = keccak256(payload) as Hex;
    const [pointer_, length] = await rpc(provider, store, storeAbi, "chunk", [chunkHash], tag);
    const pointer = address(pointer_);
    if (length !== BigInt((payload.length - 2) / 2)) throw Error("Snapshot Store chunk is not preuploaded");
    const code = bytes(await provider.getCode(pointer, tag), 8193);
    if (code !== `0x00${payload.slice(2)}`) throw Error("Snapshot Store STOP carrier differs");
    chunks.push({ hash: chunkHash, pointer, length: length as bigint });
  }
  return freeze(chunks);
}

async function snapshotStage(provider: Reader, c: ScopedPolicyGraphV2Capture,
  publication: pub.ScopedPolicyPublicationV2Publication, caller: Address, tag: number, requireStored: boolean) {
  const iface = pub.scopedPolicyPublicationV2Interface("snapshot");
  const coord = coordinates(c);
  equal(publication.scope, c.graph.scope, "Snapshot full scope differs");
  const deps = c.childDependencies.snapshot!;
  await definitions(provider, deps.targets[2], "snapshot", tag);
  const current = pub.normalizeScopedPolicyPublicationV2Receipt(
    await read(provider, coord.snapshot, iface, "currentSnapshot", [publication.scope], tag)
  );
  const count = uint(await read(provider, coord.snapshot, iface, "snapshotCount", [publication.scope], tag));
  const lock = pub.normalizeScopedPolicyPublicationV2Lock(
    await read(provider, coord.snapshot, iface, "snapshotLock", [publication.scope], tag)
  );
  if (lock.actionId !== ZERO) throw Error("Snapshot is governed-locked");
  if (count !== publication.expectedRevision || current.recordHash !== publication.expectedHead
    || current.revision !== count || publication.effectiveAt > c.observed.timestamp) throw Error("Snapshot lineage/time differs");
  if (current.recordHash === ZERO) {
    if (!/^0x0+$/.test(pub.encodeScopedPolicyPublicationV2Receipt(current))) throw Error("Noncanonical missing snapshot");
  } else {
    const [savedPublication] = await rpc(provider, coord.snapshot, iface, "snapshotRecord", [current.recordHash], tag);
    equal((savedPublication as pub.ScopedPolicyPublicationV2Publication).scope, publication.scope, "Previous full scope differs");
  }
  const artist = pub.normalizeScopedPolicyPublicationV2ArtistPresentation(
    await read(provider, deps.targets[4], servingFactsAbi, "artistPresentation", [publication.scope.collectionId], tag)
  );
  if (!artist.locked || artist.artistId === ZERO || artist.snapshotHash === ZERO || artist.registry === ZERO_ADDRESS
    || artist.registryCodeHash === ZERO || artist.bindingGeneration === 0n || artist.bindingHash === ZERO
    || artist.identityRecordHash === ZERO || artist.acceptanceRecordHash === ZERO || artist.nominatedArtist === ZERO_ADDRESS
    || artist.acceptedAt === 0n || artist.lockedAt === 0n) throw Error("Artist presentation must be locked and complete");
  const outputIface = pub.scopedPolicyPublicationV2Interface("output");
  const manifest = pub.normalizeScopedPolicyPublicationV2Manifest(
    await read(provider, coord.output, outputIface, "requireCurrentManifest", [publication.outputManifestRecord, artist.artistId], tag)
  );
  const facts = await manifestFacts(provider, c, manifest.checkpointHash, manifest.artifactHash,
    manifest.coverageHash, artist.artistId, tag);
  equal(manifest, facts.manifest, "Snapshot's covered output differs");
  if (publication.coordinatorInventoryPlan !== c.inventory.plan) throw Error("Snapshot inventory plan differs");
  const source: pub.ScopedPolicyPublicationV2Source = {
    scope: publication.scope, membership: c.inventory.membership, artist,
    selection: facts.content.selection.plan, content: facts.content.plan, outputs: manifest,
    sourceFactory: c.deployment.sourceFactory.address, sourceFactoryCodeHash: c.deployment.sourceFactory.codeHash,
    factoryDependenciesHash: c.deployment.sourceFactoryDependenciesHash,
    entropy: { planId: c.inventory.plan, inventoryHash: c.inventory.progress.commitment,
      policyChainHash: c.inventory.policyChainHash, policyCount: BigInt(c.inventory.policies.length),
      allFrozen: true, policies: c.inventory.policies }
  };
  const sourceHash = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address[11]", "bytes32[11]", pub.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), coord.chainId, coord.snapshot, deps.targets, deps.codeHashes, source]
  )) as Hex;
  const grant = await authority(provider, coord.metadata, publication.scope.collectionId,
    id("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1") as Hex, caller, tag);
  const display = await authority(provider, coord.metadata, publication.scope.collectionId,
    id("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1") as Hex, caller, tag);
  const receipt: pub.ScopedPolicyPublicationV2Receipt = {
    recordHash: ZERO, scopeSubject: c.inventory.membership.scopeSubject, predecessor: publication.expectedHead,
    revision: publication.expectedRevision + 1n, chainHash: ZERO, manifestHash: ZERO, manifestBytes: 0n,
    sourceHash, publisher: caller, ...grant, displayAuthorizationClass: display.authorizationClass,
    displayGrantRevision: display.grantRevision, recordedAt: 0n,
    schemaHash: pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_HASH,
    profileHash: pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH,
    canonicalizationHash: pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_HASH
  };
  const canonical = snapshotCanonical(coord, deps, publication, receipt, source);
  const [actualHash, actualCanonical] = await rpc(provider, coord.snapshot, iface, "previewSnapshot", [publication, caller], tag);
  equal([actualHash, actualCanonical], [sourceHash, canonical], "Original snapshot preview/source/canonical bytes differ");
  if (publication.expectedSourceHash !== ZERO && publication.expectedSourceHash !== sourceHash) throw Error("Expected snapshot source changed");
  const chunks = requireStored ? await storeChunks(provider, deps.targets[3], canonical, tag) : null;
  return freeze({ kind: "snapshot" as const, current, count, lock, source, receipt, sourceHash, canonical, chunks, facts });
}

export async function previewScopedPolicyPublicationV2Snapshot(provider: Reader,
  inputDeployment: ScopedPolicyPublicationV2Deployment, inputPublication: pub.ScopedPolicyPublicationV2Publication,
  inputPublisher: Address, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment);
  const publication = pub.normalizeScopedPolicyPublicationV2Publication(inputPublication);
  const publisher = address(inputPublisher);
  keys(options, ["blockTag"]);
  const c = await context(provider, d, publication.scope, number(options.blockTag));
  const result = await snapshotStage(provider, c, publication, publisher, c.observed.blockNumber, false);
  await unchanged(provider, c.observed);
  return freeze({ deployment: d, observed: c.observed, publication, publisher, ...result,
    readyPublication: { ...publication, expectedSourceHash: result.sourceHash }, storeAvailabilityChecked: false as const });
}

type Immutable<T> = T extends readonly (infer Item)[] ? readonly Immutable<Item>[]
  : T extends object ? { readonly [Key in keyof T]: Immutable<T[Key]> } : T;
type Stage = Immutable<Awaited<ReturnType<typeof checkpointStage>> | Awaited<ReturnType<typeof outputStage>>
  | Awaited<ReturnType<typeof snapshotStage>>>;

export interface ScopedPolicyPublicationV2Capture {
  readonly deployment: ScopedPolicyPublicationV2Deployment;
  readonly scope: graph.ScopedPolicyGraphV2Scope;
  readonly prepared: pub.ScopedPolicyPublicationV2Call;
  readonly observed: ScopedPolicyPublicationV2Block;
  readonly graph: ScopedPolicyGraphV2Capture;
  readonly stage: Stage;
  readonly captureHash: Hex;
}

/** All stages use the client's stricter current-graph/current-coverage profile. */
export async function captureScopedPolicyPublicationV2(provider: Reader, inputDeployment: ScopedPolicyPublicationV2Deployment,
  inputScope: graph.ScopedPolicyGraphV2Scope, inputCaller: Address, inputRequest: pub.ScopedPolicyPublicationV2Request,
  options: { readonly blockTag: number }): Promise<ScopedPolicyPublicationV2Capture> {
  const d = deployment(inputDeployment);
  const scope = graph.validateScopedPolicyGraphV2Scope(inputScope);
  const caller = address(inputCaller);
  const request = structuredClone(inputRequest);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  const c = await context(provider, d, scope, tag);
  const prepared = pub.prepareScopedPolicyPublicationV2Call(coordinates(c), caller, request);
  bytes(prepared.call.data, MAX_CALL);
  const normalized = prepared.request;
  const stage = normalized.kind === "begin" || normalized.kind === "append"
    ? await checkpointStage(provider, c, normalized, tag)
    : normalized.kind === "beginManifest" || normalized.kind === "verifyNextOutputs"
      ? await outputStage(provider, c, normalized, tag)
      : await snapshotStage(provider, c, normalized.publication, caller, tag, true);
  await unchanged(provider, c.observed);
  const fields = { deployment: d, scope, prepared, observed: c.observed, graph: c, stage };
  return freeze({ ...fields, captureHash: fingerprint(fields) });
}

function savedCapture(value: ScopedPolicyPublicationV2Capture): ScopedPolicyPublicationV2Capture {
  keys(value, ["deployment", "scope", "prepared", "observed", "graph", "stage", "captureHash"]);
  const snapshot = structuredClone(value);
  const { captureHash, ...fields } = snapshot;
  if (fingerprint(fields) !== hash(captureHash)) throw Error("Capture fingerprint differs");
  equal(pub.normalizeScopedPolicyPublicationV2Call(snapshot.prepared), snapshot.prepared, "Prepared call changed");
  equal(snapshot.prepared.coordinates, coordinates(snapshot.graph), "Prepared graph coordinates differ");
  equal(snapshot.scope, snapshot.graph.graph.scope, "Captured full scope differs");
  return freeze(snapshot);
}

function comparable(value: ScopedPolicyPublicationV2Capture) {
  const { observed: _observed, captureHash: _hash, graph: nested, ...rest } = value;
  const { observed: _nestedObserved, captureHash: _nestedHash, ...graphFacts } = nested;
  return { ...rest, graph: graphFacts };
}

async function revalidate(provider: Reader, saved: ScopedPolicyPublicationV2Capture, tag: number) {
  if (tag < saved.observed.blockNumber) throw Error("Cannot simulate before captured block");
  await unchanged(provider, saved.observed);
  const original = await captureScopedPolicyPublicationV2(provider, saved.deployment, saved.scope,
    saved.prepared.caller, saved.prepared.request, { blockTag: saved.observed.blockNumber });
  equal(original, saved, "Original capture reconstruction differs");
  const current = tag === saved.observed.blockNumber ? original : await captureScopedPolicyPublicationV2(provider,
    saved.deployment, saved.scope, saved.prepared.caller, saved.prepared.request, { blockTag: tag });
  equal(comparable(current), comparable(saved), "Reviewed publication context changed; recapture");
  return current;
}

export async function simulateScopedPolicyPublicationV2(provider: Reader, input: ScopedPolicyPublicationV2Capture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const gasLimit = gas(options.gasLimit);
  const current = await revalidate(provider, saved, number(options.blockTag));
  const iface = pub.scopedPolicyPublicationV2Interface(host(current.prepared.request.kind));
  const returnData = bytes(await provider.call({ ...current.prepared.call, from: current.prepared.caller,
    gasLimit, blockTag: current.observed.blockNumber }));
  const decoded = iface.decodeFunctionResult(current.prepared.request.kind, returnData);
  if (iface.encodeFunctionResult(current.prepared.request.kind, decoded) !== returnData) throw Error("Noncanonical simulation result");
  const values = iface.getFunction(current.prepared.request.kind)!.outputs.map((parameter, i) => plain(parameter, decoded[i]));
  if (current.stage.kind === "checkpoint" && current.prepared.request.kind === "begin") equal(values, [current.stage.key]);
  if (current.stage.kind === "output") equal(values,
    [current.prepared.request.kind === "beginManifest" ? current.stage.key : current.stage.expected.recordHash]);
  if (current.stage.kind === "snapshot") equal(values, [atTime(current, current.observed.timestamp).recordHash], "Simulated snapshot hash differs");
  await unchanged(provider, current.observed);
  return freeze({ capture: current, gasLimit, returnValues: values, returnData, simulated: true as const, persisted: false as const });
}

const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);

export type ScopedPolicyPublicationV2ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex }
>;

interface CopiedLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

async function transport(provider: ReceiptReader, saved: ScopedPolicyPublicationV2Capture,
  transactionHash: Hex, options: ScopedPolicyPublicationV2ReceiptOptions) {
  const raw = await provider.getTransactionReceipt(transactionHash);
  if (!raw || raw.status !== 1 || !same(raw.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = number(raw.blockNumber);
  const blockHash = hash(raw.blockHash);
  const from = address(raw.from);
  const to = address(raw.to);
  if (blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow captured block");
  if (!Array.isArray(raw.logs) || raw.logs.length > MAX_LOGS) throw Error("Receipt log limit exceeded");
  let priorIndex = -1;
  let total = 0;
  const logs: CopiedLog[] = raw.logs.map(log => {
    const index = number(log.index);
    if (index <= priorIndex || log.removed !== false || !same(log.transactionHash, transactionHash)
      || log.blockNumber !== blockNumber || !same(log.blockHash, blockHash)) throw Error("Receipt log identity/order differs");
    priorIndex = index;
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error("Malformed log topics");
    const data = bytes(log.data, 65536);
    total += (data.length - 2) / 2;
    if (total > 1_048_576) throw Error("Receipt aggregate log bound exceeded");
    return { address: address(log.address), topics: log.topics.map((topic: string) => hash(topic, true)), data, index };
  });
  const tx = await provider.getTransaction(transactionHash);
  if (!tx || !same(tx.hash, transactionHash) || !same(tx.from, from) || !same(tx.to, to)
    || tx.blockNumber !== blockNumber || !same(tx.blockHash, blockHash)
    || tx.chainId !== saved.deployment.graph.chainId) throw Error("Transaction envelope differs");
  const data = bytes(tx.data, MAX_CALL + 16384);
  const call = saved.prepared.call;
  const caller = saved.prepared.caller;
  if (tx.value !== 0n) throw Error("Outer value must be zero");
  let safeIndex = -1;
  if (options.execution === "direct") {
    if (!same(from, caller) || !same(to, call.to) || !same(data, call.data)) throw Error("Direct caller/target/data differs");
  } else {
    if (!same(to, caller)) throw Error("Safe is not the actual publication caller");
    const decoded = safe.decodeFunctionData("execTransaction", data);
    if (!same(safe.encodeFunctionData("execTransaction", decoded), data) || !same(decoded.to, call.to)
      || decoded.value !== 0n || !same(decoded.data, call.data) || decoded.operation !== 0n) throw Error("Safe inner CALL differs");
    const executionTopics = [safe.getEvent("ExecutionSuccess")!.topicHash, safe.getEvent("ExecutionFailure")!.topicHash];
    const matches = logs.filter(log => same(log.address, caller) && executionTopics.some(topic => same(topic, log.topics[0])));
    if (matches.length !== 1) throw Error("Expected exactly one Safe execution event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) },
      caller, options.expectedSafeTxHash);
    safeIndex = matches[0]!.index;
  }
  const observed = await header(provider, blockNumber);
  if (!same(observed.blockHash, blockHash)) throw Error("Receipt block changed");
  return { observed, logs, safeIndex };
}

function events(logs: readonly CopiedLog[], target: Address, iface: Interface, name: string) {
  const fragment = iface.getEvent(name)!;
  return logs.filter(log => same(log.address, target) && same(log.topics[0], fragment.topicHash)).map(row => {
    const decoded = iface.decodeEventLog(fragment, row.data, [...row.topics]);
    const encoded = iface.encodeEventLog(fragment, decoded);
    equal(encoded.topics.map(topic => topic.toLowerCase()), row.topics, `${name} topics differ`);
    if (!same(encoded.data, row.data)) throw Error(`Noncanonical ${name}`);
    return { index: row.index, fields: Object.fromEntries(fragment.inputs.map((param, index) => [param.name, plain(param, decoded[index])])) };
  });
}

function atTime(saved: ScopedPolicyPublicationV2Capture, timestamp: bigint): pub.ScopedPolicyPublicationV2Receipt {
  if (saved.stage.kind !== "snapshot" || saved.prepared.request.kind !== "publishSnapshot") throw Error("Not a snapshot capture");
  if (timestamp === 0n || timestamp >= (1n << 64n)) throw Error("Snapshot timestamp outside uint64");
  const coord = saved.prepared.coordinates;
  const p = saved.prepared.request.publication;
  const fields = { ...saved.stage.receipt, manifestHash: keccak256(saved.stage.canonical) as Hex,
    manifestBytes: BigInt((saved.stage.canonical.length - 2) / 2), recordedAt: timestamp };
  const recordHash = pub.scopedPolicyPublicationV2SnapshotRecordHash(coord, p, fields);
  return freeze({ ...fields, recordHash, chainHash: pub.scopedPolicyPublicationV2SnapshotChainHash(coord,
    p.scope, saved.stage.current.chainHash, fields.revision, recordHash) });
}

function historyDeployment(value: ScopedPolicyPublicationV2HistoryDeployment): ScopedPolicyPublicationV2HistoryDeployment {
  keys(value, ["chainId", "core", "metadata", "checkpoint", "output", "snapshot", "linkedDependencies"]);
  const chainId = uint(value.chainId);
  if (chainId === 0n) throw Error("Zero chain ID");
  return freeze({ chainId, core: address(value.core), metadata: address(value.metadata),
    checkpoint: codePin(value.checkpoint), output: codePin(value.output), snapshot: codePin(value.snapshot),
    linkedDependencies: pinList(value.linkedDependencies) });
}

function historyCoordinates(d: ScopedPolicyPublicationV2HistoryDeployment): pub.ScopedPolicyPublicationV2Coordinates {
  return { chainId: d.chainId, core: d.core, metadata: d.metadata,
    checkpoint: d.checkpoint.address, output: d.output.address, snapshot: d.snapshot.address };
}

export type ScopedPolicyPublicationV2HistoryRequest = Readonly<
  { kind: "checkpoint"; id: Hex } | { kind: "manifestPlan"; planHash: Hex }
  | { kind: "manifestRecord"; recordHash: Hex } | { kind: "snapshotRecord"; recordHash: Hex }
>;

export type ScopedPolicyPublicationV2HistoryResult = Readonly<
  { kind: "checkpoint"; key: Hex; plan: pub.ScopedPolicyPublicationV2ContentPlan;
    outputs: readonly pub.ScopedPolicyPublicationV2Output[] }
  | { kind: "manifestPlan" | "manifestRecord"; key: Hex; plan: pub.ScopedPolicyPublicationV2OutputPlan | null;
    manifest: pub.ScopedPolicyPublicationV2Manifest }
  | { kind: "snapshotRecord"; key: Hex; publication: pub.ScopedPolicyPublicationV2Publication;
    receipt: pub.ScopedPolicyPublicationV2Receipt; canonical: Hex; source: pub.ScopedPolicyPublicationV2Source }
>;

/** Local retained facts do not establish current eligibility, archival liveness or finality. */
export async function inspectScopedPolicyPublicationV2History(provider: Reader,
  inputDeployment: ScopedPolicyPublicationV2HistoryDeployment, inputRequest: ScopedPolicyPublicationV2HistoryRequest,
  options: { readonly blockTag: number }) {
  const d = historyDeployment(inputDeployment);
  const request = structuredClone(inputRequest);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  const observed = await header(provider, tag);
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("History chain differs");
  const route = request.kind === "checkpoint" ? "checkpoint" : request.kind === "snapshotRecord" ? "snapshot" : "output";
  if (!["checkpoint", "manifestPlan", "manifestRecord", "snapshotRecord"].includes(request.kind)) throw Error("Unknown history request");
  keys(request, ["kind", request.kind === "checkpoint" ? "id" : request.kind === "manifestPlan" ? "planHash" : "recordHash"]);
  for (const pin of [d[route], ...d.linkedDependencies]) await runtime(provider, pin, tag);
  const iface = pub.scopedPolicyPublicationV2Interface(route);
  const coord = historyCoordinates(d);
  equal(await read(provider, d[route].address, iface, "core", [], tag), d.core, "Retained host Core binding differs");
  let result: ScopedPolicyPublicationV2HistoryResult;
  if (request.kind === "checkpoint") {
    const key = hash(request.id, true);
    const plan = pub.normalizeScopedPolicyPublicationV2ContentPlan(await read(provider, d.checkpoint.address, iface, "checkpoint", [key], tag));
    if (plan.tokenCount === 0n) {
      if (!/^0x0+$/.test(pub.encodeScopedPolicyPublicationV2ContentPlan(plan))) throw Error("Noncanonical empty checkpoint");
      result = { kind: request.kind, key, plan, outputs: [] };
    } else {
      graph.validateScopedPolicyGraphV2Scope(plan.scope);
      if (plan.nextIndex > plan.tokenCount) throw Error("Invalid checkpoint progress");
      boundedCount(plan.tokenCount);
      const outputs: pub.ScopedPolicyPublicationV2Output[] = [];
      for (let i = 0; i < boundedCount(plan.nextIndex); i++) {
        outputs.push(pub.validateScopedPolicyPublicationV2Output(await read(provider, d.checkpoint.address, iface, "outputAt", [key, BigInt(i)], tag)));
      }
      let leafChainHash = ZERO;
      let outputRoot = ZERO;
      outputs.forEach((row, i) => {
        leafChainHash = pub.scopedPolicyPublicationV2LeafChain(leafChainHash, BigInt(i), pub.scopedPolicyPublicationV2LeafHash(d.chainId, d.core, row.leaf));
        outputRoot = pub.scopedPolicyPublicationV2OutputChain(outputRoot, BigInt(i), row);
      });
      equal([plan.leafChainHash, plan.outputRoot, plan.contentRoot], [leafChainHash, outputRoot,
        plan.nextIndex === plan.tokenCount ? pub.scopedPolicyPublicationV2ContentRoot(d.chainId, d.core, outputs.map(row => row.leaf)) : ZERO],
      "Retained checkpoint roots differ");
      result = { kind: request.kind, key, plan, outputs };
    }
  } else if (request.kind === "manifestPlan" || request.kind === "manifestRecord") {
    const isPlan = request.kind === "manifestPlan";
    const key = hash(isPlan ? request.planHash : request.recordHash, isPlan);
    const raw = await read(provider, d.output.address, iface, request.kind, [key], tag);
    const plan = isPlan ? pub.normalizeScopedPolicyPublicationV2OutputPlan(raw as pub.ScopedPolicyPublicationV2OutputPlan) : null;
    const manifest = plan?.manifest ?? pub.normalizeScopedPolicyPublicationV2Manifest(raw as pub.ScopedPolicyPublicationV2Manifest);
    if (manifest.tokenCount === 0n) {
      if (!plan || !/^0x0+$/.test(pub.encodeScopedPolicyPublicationV2OutputPlan(plan))) throw Error("Noncanonical empty manifest plan");
    } else {
      graph.validateScopedPolicyGraphV2Scope(manifest.scope);
      boundedCount(manifest.tokenCount);
      const coverage = address(await read(provider, d.output.address, iface, "artifactCoverage", [], tag));
      equal(await read(provider, d.output.address, iface, "contentCheckpoint", [], tag), d.checkpoint.address, "Output checkpoint binding differs");
      const planHash = pub.scopedPolicyPublicationV2ManifestPlanHash(coord, coverage, manifest);
      const recordHash = pub.scopedPolicyPublicationV2ManifestRecordHash(planHash);
      if (isPlan) {
        equal(planHash, key, "Retained manifest plan hash differs");
        if (plan!.nextIndex > manifest.tokenCount
          || plan!.recordHash !== (plan!.nextIndex === manifest.tokenCount ? recordHash : ZERO)) throw Error("Retained output progress differs");
      } else equal(recordHash, key, "Retained manifest record hash differs");
    }
    result = { kind: request.kind, key, plan, manifest };
  } else {
    const key = hash(request.recordHash);
    equal(await read(provider, d.snapshot.address, iface, "metadataHost", [], tag), d.metadata, "Snapshot Metadata binding differs");
    const [publication_, receipt_] = await rpc(provider, d.snapshot.address, iface, "snapshotRecord", [key], tag);
    const publication = pub.normalizeScopedPolicyPublicationV2Publication(publication_ as pub.ScopedPolicyPublicationV2Publication);
    const receipt = pub.normalizeScopedPolicyPublicationV2Receipt(receipt_ as pub.ScopedPolicyPublicationV2Receipt);
    pub.validateScopedPolicyPublicationV2Publication(publication);
    if (receipt.predecessor !== publication.expectedHead || receipt.revision !== publication.expectedRevision + 1n
      || receipt.scopeSubject !== graph.scopedPolicyGraphV2ScopeSubject(d.chainId, d.core, publication.scope)) {
      throw Error("Retained snapshot publication/receipt lineage differs");
    }
    equal([receipt.recordHash, pub.scopedPolicyPublicationV2SnapshotRecordHash(coord, publication, receipt)], [key, key],
      "Retained snapshot record hash differs");
    const canonical = bytes(await read(provider, d.snapshot.address, iface, "snapshotPayload", [key], tag), 524288);
    if (keccak256(canonical) !== receipt.manifestHash || BigInt((canonical.length - 2) / 2) !== receipt.manifestBytes) {
      throw Error("Retained snapshot bytes differ");
    }
    const decoded = coder.decode(payloadTypes, canonical);
    if (coder.encode(payloadTypes, decoded) !== canonical) throw Error("Noncanonical snapshot payload");
    const payloadPublication = pub.decodeScopedPolicyPublicationV2Publication(coder.encode([payloadTypes[5]!], [decoded[5]]) as Hex);
    const payloadReceipt = pub.decodeScopedPolicyPublicationV2Receipt(coder.encode([payloadTypes[6]!], [decoded[6]]) as Hex);
    equal([decoded[0], decoded[1], decoded[2]], [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2"), d.chainId, d.snapshot.address]);
    equal(payloadPublication, { ...publication, expectedSourceHash: ZERO }, "Retained payload publication differs");
    equal(payloadReceipt, { ...receipt, recordHash: ZERO, chainHash: ZERO, manifestHash: ZERO, manifestBytes: 0n, recordedAt: 0n },
      "Retained payload receipt differs");
    const source = pub.decodeScopedPolicyPublicationV2Source(coder.encode([payloadTypes[7]!], [decoded[7]]) as Hex);
    const payload = pub.decodeScopedPolicyPublicationV2SnapshotBytes(canonical);
    // Gas settings are absent from the immutable payload and irrelevant to these pure structural joins.
    pub.validateScopedPolicyPublicationV2Source(coord, {
      targets: payload.targets, codeHashes: payload.codeHashes, chainId: d.chainId,
      readGas: 0n, sourceGas: 0n, inventoryGas: 0n
    }, publication, source);
    equal(source.scope, publication.scope, "Retained source full scope differs");
    const sourceHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", payloadTypes[7]!],
      [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), d.chainId, d.snapshot.address, decoded[3], decoded[4], source]));
    equal([sourceHash, receipt.sourceHash], [publication.expectedSourceHash, publication.expectedSourceHash]);
    let previousChain = ZERO;
    if (receipt.predecessor !== ZERO) {
      const [previousPublication, previousReceipt] = await rpc(provider, d.snapshot.address, iface, "snapshotRecord", [receipt.predecessor], tag);
      equal((previousPublication as pub.ScopedPolicyPublicationV2Publication).scope, publication.scope, "Previous snapshot full scope differs");
      const previous = pub.normalizeScopedPolicyPublicationV2Receipt(previousReceipt as pub.ScopedPolicyPublicationV2Receipt);
      if (previous.recordHash !== receipt.predecessor || previous.revision + 1n !== receipt.revision) throw Error("Previous snapshot revision differs");
      previousChain = previous.chainHash;
    } else if (receipt.revision !== 1n) throw Error("First snapshot revision differs");
    equal(receipt.chainHash, pub.scopedPolicyPublicationV2SnapshotChainHash(coord, publication.scope, previousChain,
      receipt.revision, key), "Retained snapshot chain differs");
    result = { kind: request.kind, key, publication, receipt, canonical, source };
  }
  await unchanged(provider, observed);
  return freeze({ deployment: d, observed, result, currentnessChecked: false as const, finalityEstablished: false as const });
}

export type ScopedPolicyPublicationV2CurrentRequest = Readonly<
  { kind: "checkpoint"; id: Hex }
  | { kind: "manifest"; recordHash: Hex; artistId: Hex }
  | { kind: "snapshot"; recordHash: Hex; revision: bigint }
>;

/** Currentness is original producer admission; it remains separate from complete finality. */
export async function inspectScopedPolicyPublicationV2Current(provider: Reader,
  inputDeployment: ScopedPolicyPublicationV2Deployment, inputScope: graph.ScopedPolicyGraphV2Scope,
  inputRequest: ScopedPolicyPublicationV2CurrentRequest, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment);
  const scope = graph.validateScopedPolicyGraphV2Scope(inputScope);
  const request = structuredClone(inputRequest);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag);
  const c = await context(provider, d, scope, tag);
  let result: pub.ScopedPolicyPublicationV2ContentPlan | pub.ScopedPolicyPublicationV2Manifest | pub.ScopedPolicyPublicationV2Receipt;
  if (request.kind === "checkpoint") {
    keys(request, ["kind", "id"]);
    result = (await content(provider, c, hash(request.id), tag, true)).plan;
  } else if (request.kind === "manifest") {
    keys(request, ["kind", "recordHash", "artistId"]);
    const manifest = pub.normalizeScopedPolicyPublicationV2Manifest(await read(provider, c.graph.children[2],
      pub.scopedPolicyPublicationV2Interface("output"), "requireCurrentManifest", [hash(request.recordHash), hash(request.artistId)], tag));
    equal(manifest.scope, scope, "Current manifest full scope differs");
    equal((await manifestFacts(provider, c, manifest.checkpointHash, manifest.artifactHash, manifest.coverageHash, manifest.artistId, tag)).manifest,
      manifest, "Current manifest facts differ");
    result = manifest;
  } else if (request.kind === "snapshot") {
    keys(request, ["kind", "recordHash", "revision"]);
    result = pub.normalizeScopedPolicyPublicationV2Receipt(await read(provider, c.graph.children[3],
      pub.scopedPolicyPublicationV2Interface("snapshot"), "requireCurrent", [scope, hash(request.recordHash), uint(request.revision, 64)], tag));
    equal([result.recordHash, result.revision, result.scopeSubject],
      [request.recordHash, request.revision, c.inventory.membership.scopeSubject], "Current snapshot identity differs");
  } else throw Error("Unknown current request");
  await unchanged(provider, c.observed);
  return freeze({ deployment: d, observed: c.observed, scope, result, currentnessChecked: true as const, finalityEstablished: false as const });
}

/** Receipt attribution uses an unchanged reviewed prestate and exact end-block progress. */
export async function reconcileScopedPolicyPublicationV2Receipt(provider: ReceiptReader,
  input: ScopedPolicyPublicationV2Capture, inputTransactionHash: Hex, inputOptions: ScopedPolicyPublicationV2ReceiptOptions) {
  const saved = savedCapture(input);
  const transactionHash = hash(inputTransactionHash);
  if (inputOptions.execution !== "direct" && inputOptions.execution !== "safe") throw Error("Unknown receipt transport");
  keys(inputOptions, inputOptions.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const options: ScopedPolicyPublicationV2ReceiptOptions = inputOptions.execution === "safe"
    ? { execution: "safe", expectedSafeTxHash: hash(inputOptions.expectedSafeTxHash) } : { execution: "direct" };
  const t = await transport(provider, saved, transactionHash, options);
  const prior = await revalidate(provider, saved, t.observed.blockNumber - 1);
  const afterGraph = await context(provider, prior.deployment, prior.scope, t.observed.blockNumber);
  const { observed: _priorObserved, captureHash: _priorHash, ...priorGraphFacts } = prior.graph;
  const { observed: _afterObserved, captureHash: _afterHash, ...afterGraphFacts } = afterGraph;
  equal(afterGraphFacts, priorGraphFacts, "Graph/source changed in receipt block");
  const coord = prior.prepared.coordinates;
  const request = prior.prepared.request;
  const stage = prior.stage;
  const iface = pub.scopedPolicyPublicationV2Interface(host(request.kind));
  const target = prior.prepared.call.to;
  const allEvents = iface.fragments.filter((fragment): fragment is EventFragment => fragment.type === "event")
    .flatMap(fragment => events(t.logs, target, iface, fragment.name)
      .map(event => ({ ...event, name: fragment.name })));
  const required: { name: string; fields: unknown }[] = [];
  let result: pub.ScopedPolicyPublicationV2ContentPlan | pub.ScopedPolicyPublicationV2OutputPlan | pub.ScopedPolicyPublicationV2Receipt;
  if (stage.kind === "checkpoint") {
    const actual = pub.normalizeScopedPolicyPublicationV2ContentPlan(
      await read(provider, coord.checkpoint, iface, "checkpoint", [stage.key], t.observed.blockNumber)
    );
    equal(actual, stage.expected, "Mined checkpoint progress differs");
    if (request.kind === "begin") {
      if (stage.before.tokenCount === 0n) required.push({ name: "StaticContentStarted",
        fields: { schemaVersion: 2n, id: stage.key, salt: request.salt, plan: stage.expected } });
    } else if (request.kind === "append") {
      for (let i = 0; i < stage.outputs.length + stage.appended.length; i++) {
        const row = i < stage.outputs.length ? stage.outputs[i]! : stage.appended[i - stage.outputs.length]!;
        equal(await read(provider, coord.checkpoint, iface, "outputAt", [stage.key, BigInt(i)], t.observed.blockNumber), row,
          "Mined output row differs");
      }
      stage.appended.forEach((output, i) => required.push({ name: "StaticContentAppended", fields: {
        schemaVersion: 2n, id: stage.key, index: stage.before.nextIndex + BigInt(i), output,
        leafHash: pub.scopedPolicyPublicationV2LeafHash(coord.chainId, coord.core, output.leaf)
      } }));
      if (stage.expected.nextIndex === stage.expected.tokenCount) required.push({ name: "StaticContentCompleted", fields: {
        schemaVersion: 2n, id: stage.key, contentRoot: stage.expected.contentRoot,
        outputRoot: stage.expected.outputRoot, count: stage.expected.tokenCount
      } });
    } else throw Error("Captured checkpoint request differs");
    result = actual;
  } else if (stage.kind === "output") {
    const actual = pub.normalizeScopedPolicyPublicationV2OutputPlan(
      await read(provider, coord.output, iface, "manifestPlan", [stage.key], t.observed.blockNumber)
    );
    equal(actual, stage.expected, "Mined manifest progress differs");
    if (request.kind === "beginManifest") {
      if (stage.before.manifest.tokenCount === 0n) required.push({ name: "OutputManifestStarted", fields: {
        schemaVersion: 2n, planHash: stage.key, manifest: stage.expected.manifest
      } });
    } else if (request.kind === "verifyNextOutputs") {
      required.push({ name: "OutputManifestAdvanced", fields: { schemaVersion: 2n, planHash: stage.key,
        firstIndex: stage.before.nextIndex, nextIndex: stage.expected.nextIndex } });
      if (stage.expected.recordHash !== ZERO) {
        equal(await read(provider, coord.output, iface, "manifestRecord", [stage.expected.recordHash], t.observed.blockNumber),
          stage.expected.manifest, "Mined manifest record differs");
        required.push({ name: "OutputManifestVerified", fields: { schemaVersion: 2n, recordHash: stage.expected.recordHash,
          planHash: stage.key, manifest: stage.expected.manifest } });
      }
    } else throw Error("Captured output request differs");
    result = actual;
  } else {
    if (request.kind !== "publishSnapshot") throw Error("Captured snapshot request differs");
    const expected = atTime(prior, t.observed.timestamp);
    const [publication, receipt] = await rpc(provider, coord.snapshot, iface, "snapshotRecord", [expected.recordHash], t.observed.blockNumber);
    equal([publication, receipt], [request.publication, expected], "Mined snapshot record differs");
    equal(await read(provider, coord.snapshot, iface, "snapshotPayload", [expected.recordHash], t.observed.blockNumber),
      stage.canonical, "Mined snapshot canonical payload differs");
    equal(await read(provider, coord.snapshot, iface, "currentSnapshot", [prior.scope], t.observed.blockNumber), expected,
      "End-block snapshot head differs");
    equal(await read(provider, coord.snapshot, iface, "snapshotCount", [prior.scope], t.observed.blockNumber), expected.revision);
    equal(await read(provider, coord.snapshot, iface, "snapshotAt", [prior.scope, expected.revision - 1n], t.observed.blockNumber), expected.recordHash);
    const chunks = await storeChunks(provider, afterGraph.recipe.inventory.targets[3], stage.canonical, t.observed.blockNumber);
    equal(chunks, stage.chunks, "Snapshot retained carrier changed");
    required.push({ name: "ScopedPolicySnapshotPublished", fields: { schemaVersion: 2n, scopeSubject: expected.scopeSubject,
      snapshotId: request.publication.snapshotId, recordHash: expected.recordHash, publication: request.publication, receipt: expected } });
    result = expected;
  }
  allEvents.sort((a, b) => a.index - b.index);
  if (allEvents.length !== required.length) throw Error("Publication event count differs");
  for (let i = 0; i < required.length; i++) {
    equal({ name: allEvents[i]!.name, fields: allEvents[i]!.fields }, required[i], "Publication event/order differs");
  }
  const last = allEvents.length === 0 ? -1 : allEvents[allEvents.length - 1]!.index;
  if (t.safeIndex >= 0 && t.safeIndex <= last) throw Error("Safe success precedes publication evidence");
  await unchanged(provider, t.observed);
  return freeze({ transactionHash, observed: t.observed, prior, result, eventlessRetry: required.length === 0,
    execution: options.execution, evidence: "prior-and-end-block-reconciliation" as const, finalityEstablished: false as const });
}

async function localState(provider: Reader, saved: ScopedPolicyPublicationV2Capture, tag: number) {
  const target = saved.prepared.call.to;
  const iface = pub.scopedPolicyPublicationV2Interface(host(saved.prepared.request.kind));
  if (saved.stage.kind === "checkpoint") return read(provider, target, iface, "checkpoint", [saved.stage.key], tag);
  if (saved.stage.kind === "output") return read(provider, target, iface, "manifestPlan", [saved.stage.key], tag);
  return read(provider, target, iface, "currentSnapshot", [saved.scope], tag);
}

/** Unchanged getter observations do not independently prove transaction rollback. */
export async function observeScopedPolicyPublicationV2Refusal(provider: Reader, input: ScopedPolicyPublicationV2Capture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const tag = number(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber || (await provider.getNetwork()).chainId !== saved.deployment.graph.chainId) {
    throw Error("Refusal block/chain differs");
  }
  await revalidate(provider, saved, saved.observed.blockNumber);
  const observed = await header(provider, tag);
  const index = saved.stage.kind === "checkpoint" ? 1 : saved.stage.kind === "output" ? 2 : 3;
  for (const pin of [{ address: saved.graph.graph.children[index]!, codeHash: saved.graph.graph.codeHashes[index]! },
    ...saved.deployment.linkedDependencies]) await runtime(provider, pin, tag);
  const before = await localState(provider, saved, tag);
  let error: unknown;
  let succeeded = false;
  try {
    await provider.call({ ...saved.prepared.call, from: saved.prepared.caller, gasLimit, blockTag: tag });
    succeeded = true;
  } catch (cause) { error = cause; }
  const after = await localState(provider, saved, tag);
  await unchanged(provider, observed);
  if (succeeded) throw Error("Original publication call did not refuse");
  const code = error && typeof error === "object" && "code" in error ? error.code : undefined;
  return freeze({ observed, error, outcome: code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: stable(before) === stable(after), rollbackProven: false as const });
}

const schemaAbi = new Interface([
  "function document(bytes32 id) view returns ((bool exists, uint8 status, bytes32 declarationHash, (string name, uint8 kind, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, string uri, uint32 totalBytes) specification, bytes32[] chunkHashes))",
  "function documentBytes(bytes32 id) view returns (bytes payload)"
]);

async function definitions(provider: Reader, target: Address, kind: "output" | "snapshot", tag: number) {
  const rows = kind === "output" ? [
    [pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA, 0n, pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA_HASH,
      pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA_BYTES],
    [pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION, 1n, pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION_HASH,
      pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION_BYTES]
  ] as const : [
    [pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA, 0n, pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_HASH,
      pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_BYTES],
    [pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_DOCUMENT, 2n, pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH,
      pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_BYTES],
    [pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION, 1n, pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_HASH,
      pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_BYTES]
  ] as const;
  for (const [key, documentKind, contentHash, byteLength] of rows) {
    const doc = await read(provider, target, schemaAbi, "document", [key], tag) as {
      exists: boolean; status: bigint;
      specification: { name: string; kind: bigint; contentHash: Hex; canonicalizationId: Hex; totalBytes: bigint };
    };
    const spec = doc.specification;
    if (!doc.exists || doc.status !== 0n || id(spec.name) !== key || spec.kind !== documentKind
      || spec.contentHash !== contentHash || spec.totalBytes !== byteLength || spec.canonicalizationId !== id("RAW_BYTES")) {
      throw Error("Original active interpretation document differs");
    }
    const raw = bytes(await read(provider, target, schemaAbi, "documentBytes", [key], tag), 8192);
    if (BigInt((raw.length - 2) / 2) !== byteLength || keccak256(raw) !== contentHash) throw Error("Original definition bytes differ");
  }
}
