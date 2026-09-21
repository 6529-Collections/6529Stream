/** Pure offline decoding of eight source-authored Foundry export files.
 * A self-consistent completion marker can survive an outer revert. This module performs no RPC,
 * signing, dump parsing/parity, baseline admission, native trace verification, state generation,
 * import or deployment admission. All returned source/runtime claims remain explicitly qualified.
 */
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, ParamType, ZeroHash, getAddress, id, keccak256 } from "ethers";

const witnessBytes = readFileSync(new URL("../test/fixtures/current-preservation-bootstrap-packet-source.json", import.meta.url));
const sha256 = bytes => createHash("sha256").update(bytes).digest("hex");
export const PRESERVATION_BOOTSTRAP_SCHEMA_SHA256 = "9cae8d6e1c32e1bb756f17a823c366fd2540473b8a791764e3394b04714a8410";
if (sha256(witnessBytes) !== PRESERVATION_BOOTSTRAP_SCHEMA_SHA256) throw Error("Bootstrap fixed schema witness differs");
const witness = JSON.parse(witnessBytes.toString("utf8"));
export const PRESERVATION_BOOTSTRAP_SOURCE_COMMIT = "06a361af3f2aee053652b7d1d331480b439f1966";
export const PRESERVATION_BOOTSTRAP_PROFILE = id("6529STREAM_CALLER_BOOTSTRAP_FOUNDRY_171_V1");
export const PRESERVATION_BOOTSTRAP_SCENARIO_ARTIFACT = "test/helpers/StreamCurrentAuthorityPreservationCallerScenario.sol:StreamCurrentAuthorityPreservationCallerScenario";
export const PRESERVATION_BOOTSTRAP_VM_ADDRESS = getAddress(`0x${id("hevm cheat code").slice(-40)}`);
/** Explicit decoder allocation limits, not claims about protocol or Foundry limits. */
export const PRESERVATION_BOOTSTRAP_LIMITS = Object.freeze({
  dumpBytes: 67108864, abiBytes: 33554432, totalFileBytes: 134217728,
  arrayEntries: 65536, totalNodes: 1048576, materializedBytes: 134217728, depth: 32,
});
export const PRESERVATION_BOOTSTRAP_FILES = Object.freeze([
  "initial-dump.json", "final-dump.json", "prestate.abi", "snapshot.abi",
  "preparation.abi", "writer.abi", "cut.abi", "complete.abi",
]);
const coder = AbiCoder.defaultAbiCoder();
const schema = Object.fromEntries(Object.entries(witness.schema).map(([name, values]) => [name, values.map(value => ParamType.from(value))]));
const typedArrayByteLength = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(Uint8Array.prototype), "byteLength").get;
const fail = message => { throw Error(`Preservation bootstrap packet: ${message}`); };
function freeze(value) {
  if (value && typeof value === "object") {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}
function unique(values, label) {
  if (new Set(values).size !== values.length) fail(`duplicate ${label}`);
}
function sameScope(a, b) {
  return a.scopeType === b.scopeType && a.collectionId === b.collectionId && a.tokenId === b.tokenId && a.scopeId === b.scopeId;
}

// Scan actual wire words before ethers allocates dynamic arrays/bytes. The cumulative budget also
// covers aliased offsets; canonical re-encoding below rejects padding, gaps, aliasing and trailing data.
function preflight(types, bytes, budget) {
  const length = bytes.length;
  const bounded = (at, size) => {
    if (!Number.isSafeInteger(at) || !Number.isSafeInteger(size) || at < 0 || size < 0 || at > length || size > length - at) fail("ABI offset/length out of bounds");
  };
  const word = at => {
    bounded(at, 32);
    const value = BigInt(`0x${bytes.toString("hex", at, at + 32)}`);
    if (value > BigInt(PRESERVATION_BOOTSTRAP_LIMITS.abiBytes)) fail("ABI offset/count exceeds client allocation limit");
    return Number(value);
  };
  const dynamic = p => p.type === "bytes" || p.type === "string" || (p.baseType === "array" && (p.arrayLength === -1 || dynamic(p.arrayChildren))) || (p.baseType === "tuple" && p.components.some(dynamic));
  const width = p => dynamic(p) ? 32 : p.baseType === "tuple" ? p.components.reduce((n, c) => n + width(c), 0) : p.baseType === "array" ? p.arrayLength * width(p.arrayChildren) : 32;
  const charge = n => {
    budget.nodes++;
    budget.bytes += n;
    if (budget.nodes > PRESERVATION_BOOTSTRAP_LIMITS.totalNodes || budget.bytes > PRESERVATION_BOOTSTRAP_LIMITS.materializedBytes) fail("cumulative ABI materialization limit");
  };
  const sequence = (parts, base, depth) => {
    bounded(base, parts.reduce((n, p) => n + width(p), 0));
    let at = base;
    for (const p of parts) { visit(p, dynamic(p) ? base + word(at) : at, depth + 1); at += width(p); }
  };
  const visit = (p, at, depth) => {
    if (depth > PRESERVATION_BOOTSTRAP_LIMITS.depth) fail("ABI nesting limit");
    charge(32);
    if (p.baseType === "tuple") { sequence(p.components, at, depth); return; }
    if (p.baseType === "array") {
      const count = p.arrayLength === -1 ? word(at) : p.arrayLength;
      if (count > PRESERVATION_BOOTSTRAP_LIMITS.arrayEntries) fail("ABI array entry limit");
      const start = at + (p.arrayLength === -1 ? 32 : 0), child = p.arrayChildren;
      bounded(start, count * width(child));
      for (let i = 0; i < count; i++) visit(child, dynamic(child) ? start + word(start + i * 32) : start + i * width(child), depth + 1);
      return;
    }
    if (p.type === "bytes" || p.type === "string") {
      const size = word(at);
      bounded(at + 32, Math.ceil(size / 32) * 32);
      charge(size * 2); // Hex representation retained by ethers and returned as an immutable string.
    } else bounded(at, 32);
  };
  sequence(types, 0, 0);
}
function detach(p, evidence, value) {
  if (p.baseType === "array") {
    const child = { ...evidence, type: evidence.type.replace(/\[[^\]]*\]$/, "") };
    return value.map(v => detach(p.arrayChildren, child, v));
  }
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map((c, i) => [c.name, detach(c, evidence.components[i], value[i])]));
  if (evidence.internalType === "enum StreamFinalityScopeType" && value > 4n) fail("invalid original scope enum");
  return typeof value === "string" && p.type.startsWith("bytes") ? value.toLowerCase() : value;
}
function decode(name, bytes, budget) {
  const types = schema[name];
  preflight(types, bytes, budget);
  const decoded = coder.decode(types, bytes);
  if (!Buffer.from(coder.encode(types, decoded).slice(2), "hex").equals(bytes)) fail(`noncanonical ${name} ABI`);
  return decoded.map((v, i) => detach(types[i], witness.schema[name][i], v));
}
function accountsOf(accounts, label) {
  unique(accounts.map(a => a.account), `${label} account`);
  for (const a of accounts) unique(a.slots.map(s => s.slot), `${label} slot`);
  return new Map(accounts.map(a => [a.account, a]));
}
function requireAccount(accounts, account, label) {
  const row = accounts.get(account);
  if (!row) fail(`${label} account missing from snapshot`);
  return row;
}
function validatePreparation(preparation, writer, accounts) {
  const collection = preparation.collection;
  if (collection.writer !== writer.writer) fail("preparation writer differs");
  // Captured before later scoped preparation. This is a Safe transaction nonce, not Account.nonce.
  if (collection.writerNonceAfterSetup > writer.nonce) fail("earlier setup writer nonce exceeds final writer nonce");
  if (collection.scope.scopeType !== 0n || collection.scope.collectionId !== 1n || collection.scope.tokenId !== 0n || collection.scope.scopeId !== ZeroHash) fail("collection preparation scope differs");
  const coordinator = collection.coordinatorInventory;
  if (!coordinator.complete || coordinator.tokenCount !== 4n || coordinator.processedTokens !== 4n || coordinator.coordinatorCount !== 1n || coordinator.commitment === ZeroHash) fail("collection coordinator preparation differs");
  const rows = [collection, ...preparation.scoped];
  rows.forEach((row, i) => {
    const count = i === 1 ? 1n : 4n;
    if (row.scope.scopeType !== BigInt(i) || row.scope.collectionId !== 1n || row.scope.tokenId !== (i === 1 ? 1n : 0n)) fail("ordered preparation scopes differ");
    if (row.membership.tokenCount !== count || row.membership.membershipHash === ZeroHash) fail("preparation membership differs");
    if (!sameScope(row.scope, row.graph.scope) || !sameScope(row.scope, row.selection.scope)) fail("preparation full scope differs");
    if (row.graph.graphId === ZeroHash || row.graph.preparedChildren !== 7n) fail("preparation graph is incomplete");
    if (row.selectionId === ZeroHash || row.selection.nextIndex !== count || row.selection.tokenCount !== count || row.selection.selectionRoot === ZeroHash || row.selection.membershipHash !== row.membership.membershipHash) fail("preparation STATIC selection differs");
    // These compare retained observed codeHash facts. They do not recompute codeHash from code or
    // independently authenticate linked libraries, immutables, native execution or graph admission.
    const sourceSet = requireAccount(accounts, row.graph.sourceSet, "source set");
    if (sourceSet.codeHash !== row.graph.sourceSetCodeHash) fail("source-set observed codeHash differs");
    row.graph.children.forEach((child, index) => {
      const account = requireAccount(accounts, child, "factory child"), length = (account.code.length - 2) / 2;
      if (length === 0 || length > 24576 || account.codeHash !== row.graph.codeHashes[index]) fail("factory child observed runtime facts differ");
    });
    if (i > 0 && [row.checkpointId, row.outputPlan, row.outputRecord, row.rootHash].some(h => h !== ZeroHash)) fail("preparation contains completed client publication identifiers");
  });
}

/**
 * @param {Record<'initial-dump.json'|'final-dump.json'|'prestate.abi'|'snapshot.abi'|'preparation.abi'|'writer.abi'|'cut.abi'|'complete.abi', Uint8Array>} files
 * Exact raw binary contents. Textual 0x ABI or already-parsed objects are not accepted.
 * Inputs are detached before decoding; returned values contain no typed-array references.
 */
export function decodePreservationBootstrapPacket(files) {
  if (!files || typeof files !== "object" || Array.isArray(files)) fail("expected exactly eight raw file buffers");
  const keys = Reflect.ownKeys(files);
  if (keys.length !== 8 || keys.some(k => !PRESERVATION_BOOTSTRAP_FILES.includes(k))) fail("expected exactly eight raw file buffers");
  let total = 0;
  const inputs = new Map();
  for (const name of PRESERVATION_BOOTSTRAP_FILES) {
    const field = Object.getOwnPropertyDescriptor(files, name);
    if (!field || !Object.hasOwn(field, "value") || !(field.value instanceof Uint8Array)) fail(`expected raw bytes for ${name}`);
    const limit = name.endsWith(".json") ? PRESERVATION_BOOTSTRAP_LIMITS.dumpBytes : PRESERVATION_BOOTSTRAP_LIMITS.abiBytes;
    const length = typedArrayByteLength.call(field.value);
    if (length > limit) fail(`${name} exceeds client file bound`);
    total += length;
    inputs.set(name, { value: field.value, length });
  }
  if (total > PRESERVATION_BOOTSTRAP_LIMITS.totalFileBytes) fail("aggregate file byte bound");
  const raw = Object.fromEntries(PRESERVATION_BOOTSTRAP_FILES.map(name => {
    const { value, length } = inputs.get(name), copy = Buffer.allocUnsafe(length);
    Uint8Array.prototype.set.call(copy, value);
    return [name, copy];
  }));
  const hashes = Object.fromEntries(PRESERVATION_BOOTSTRAP_FILES.map(name => [name, {
    byteLength: raw[name].length, sha256: sha256(raw[name]), keccak256: keccak256(raw[name]),
  }]));
  const budget = { nodes: 0, bytes: 0 };
  const [cut] = decode("cut", raw["cut.abi"], budget);
  const [profile, cutHash] = decode("complete", raw["complete.abi"], budget);
  if (profile !== PRESERVATION_BOOTSTRAP_PROFILE || cut.profile !== profile || cutHash !== hashes["cut.abi"].keccak256) fail("completion marker/profile/Cut mismatch");
  for (const [field, name] of [
    ["admittedPrestateHash", "prestate.abi"], ["initialDumpHash", "initial-dump.json"],
    ["finalDumpHash", "final-dump.json"], ["snapshotHash", "snapshot.abi"],
    ["preparationHash", "preparation.abi"], ["writerHash", "writer.abi"],
  ]) if (cut[field] !== hashes[name].keccak256) fail(`Cut ${field} differs from raw file bytes`);
  if (cut.scenarioArtifact !== id(PRESERVATION_BOOTSTRAP_SCENARIO_ARTIFACT)) fail("scenario artifact identity differs");
  const [prestate] = decode("prestate", raw["prestate.abi"], budget);
  const [snapshot] = decode("snapshot", raw["snapshot.abi"], budget);
  const [preparation] = decode("preparation", raw["preparation.abi"], budget);
  const [writer] = decode("writer", raw["writer.abi"], budget);
  const before = accountsOf(prestate, "prestate"), accounts = accountsOf(snapshot.accounts, "snapshot");
  unique(snapshot.createdAccounts, "created account");
  if (BigInt(snapshot.createdAccounts.length) > snapshot.accessCount) fail("created accounts exceed recorded access count");
  for (const a of snapshot.createdAccounts) requireAccount(accounts, a, "created");
  for (const a of prestate) {
    const final = requireAccount(accounts, a.account, "prestate seed"), keys = new Set(final.slots.map(s => s.slot));
    for (const slot of a.slots) if (!keys.has(slot.slot)) fail("prestate seeded slot missing from snapshot");
  }
  for (const a of [cut.recorder, cut.caller, cut.origin, PRESERVATION_BOOTSTRAP_VM_ADDRESS, cut.scenario]) requireAccount(accounts, a, "source seed");
  if (!snapshot.createdAccounts.includes(cut.scenario)) fail("scenario missing from created accounts");
  const scenario = requireAccount(accounts, cut.scenario, "scenario");
  if (scenario.codeHash !== cut.scenarioRuntimeHash || scenario.code === "0x" || scenario.nonce === 0n) fail("scenario observed runtime facts differ");
  const writerAccount = requireAccount(accounts, writer.writer, "writer");
  if (writerAccount.code === "0x" || writer.threshold === 0n || writer.threshold > BigInt(writer.owners.length)) fail("writer observed facts differ");
  unique(cut.dumpOmissions, "dump omission");
  const allowed = [cut.recorder, cut.origin, PRESERVATION_BOOTSTRAP_VM_ADDRESS];
  for (const a of cut.dumpOmissions) {
    if (!allowed.includes(a) || snapshot.createdAccounts.includes(a) || !accounts.has(a)) fail("invalid supplied dump omission");
  }
  const infrastructure = new Set([cut.recorder, cut.caller, cut.origin, PRESERVATION_BOOTSTRAP_VM_ADDRESS]);
  const created = new Set(snapshot.createdAccounts);
  for (const a of snapshot.accounts) {
    const nonempty = a.code !== "0x" || a.balance !== 0n || a.nonce !== 0n || a.slots.some(s => s.value !== ZeroHash);
    if (nonempty && !before.has(a.account) && !created.has(a.account) && !infrastructure.has(a.account)) fail("unexplained nonempty snapshot account");
  }
  validatePreparation(preparation, writer, accounts);
  return freeze({
    sourceCommit: PRESERVATION_BOOTSTRAP_SOURCE_COMMIT, schemaWitnessSha256: PRESERVATION_BOOTSTRAP_SCHEMA_SHA256,
    files: hashes, prestate, snapshot, preparation, writer, cut, complete: { profile, cutHash },
    qualification: {
      canonicalAbiAndFileHashJoinsVerified: true, suppliedSourceRelationshipsVerified: true,
      completionMarkerVerified: true, outerExecutionVerified: false, baselineAdmissionVerified: false,
      dumpGrammarVerified: false, dumpParityVerified: false, nativeClosureVerified: false,
      nativeLibraryTraceVerified: false, runtimeCodeHashVerified: false, protocolPreparationIndependentlyVerified: false,
      importVerified: false, deploymentAdmissionVerified: false,
    },
  });
}
