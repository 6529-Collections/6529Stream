/** Synthetic ABI packets only. No actual exported packet or native execution is available. */
import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, ParamType, ZeroHash, getAddress, id, keccak256 } from "ethers";
import {
  decodePreservationBootstrapPacket, PRESERVATION_BOOTSTRAP_FILES, PRESERVATION_BOOTSTRAP_PROFILE,
  PRESERVATION_BOOTSTRAP_SCENARIO_ARTIFACT, PRESERVATION_BOOTSTRAP_VM_ADDRESS,
  PRESERVATION_BOOTSTRAP_SCHEMA_SHA256, PRESERVATION_BOOTSTRAP_SOURCE_COMMIT,
} from "../scripts/current-preservation-bootstrap-packet.mjs";

const rawWitness = readFileSync(new URL("./fixtures/current-preservation-bootstrap-packet-source.json", import.meta.url));
const witness = JSON.parse(rawWitness.toString("utf8"));
const coder = AbiCoder.defaultAbiCoder();
const schema = Object.fromEntries(Object.entries(witness.schema).map(([k, v]) => [k, v.map(x => ParamType.from(x))]));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const binary = hex => Buffer.from(hex.slice(2), "hex");
const encode = (name, ...values) => binary(coder.encode(schema[name], values));
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
function zero(p) {
  if (p.baseType === "array") return p.arrayLength === -1 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(x => [x.name, zero(x)]));
  if (p.type === "address") return address(0);
  if (p.type === "bool") return false;
  if (p.type === "string") return "";
  if (p.type.startsWith("bytes")) return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`;
  return 0n;
}
function account(a, extra = {}) {
  return { account: a, code: "0x", codeHash: ZeroHash, balance: 0n, nonce: 0n, slots: [], ...extra };
}
function synthetic() {
  const cut = zero(schema.cut[0]), preparation = zero(schema.preparation[0]);
  Object.assign(cut, { profile: PRESERVATION_BOOTSTRAP_PROFILE, recorder: address(2), caller: address(3), origin: address(4), scenario: address(5), chainId: 31337n, blockNumber: 123n, timestamp: 900n, baseFee: 1n, gasLimit: 30000000n, coinbase: address(0), prevrandao: 77n, scenarioArtifact: id(PRESERVATION_BOOTSTRAP_SCENARIO_ARTIFACT), scenarioCreationHash: id("synthetic creation bytes"), scenarioRuntimeHash: id("synthetic observed scenario hash"), dumpOmissions: [address(2), PRESERVATION_BOOTSTRAP_VM_ADDRESS] });
  const writer = { writer: address(6), owners: [address(7), address(8)], threshold: 2n, nonce: 10n };
  const prestate = [account(address(9)), account(address(12), { code: "0xab", codeHash: id("retained original prestate observation"), nonce: 1n })];
  const snapshot = { accounts: [...prestate.map(x => ({ ...x })), account(cut.recorder), account(cut.caller), account(cut.origin),
    account(PRESERVATION_BOOTSTRAP_VM_ADDRESS, { codeHash: id("observed Foundry VM magic code hash") }),
    account(cut.scenario, { code: "0x6000", codeHash: cut.scenarioRuntimeHash, nonce: 1n }),
    account(writer.writer, { code: "0x6001", codeHash: id("observed writer hash"), nonce: 2n })],
    accessHash: id("opaque source-recorded access hash"), accessCount: 100n, createdAccounts: [cut.scenario, writer.writer] };
  const rows = [preparation.collection, ...preparation.scoped];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i], count = i === 1 ? 1n : 4n;
    row.scope = { scopeType: BigInt(i), collectionId: 1n, tokenId: i === 1 ? 1n : 0n, scopeId: i > 1 ? id(`scope${i}`) : ZeroHash };
    row.membership.tokenCount = count;
    row.membership.membershipHash = id(`membership${i}`);
    row.graph.scope = { ...row.scope };
    row.graph.graphId = id(`graph${i}`);
    row.graph.preparedChildren = 7n;
    row.graph.sourceSet = address(20 + i);
    row.graph.sourceSetCodeHash = id(`sourceSet${i}`);
    snapshot.accounts.push(account(row.graph.sourceSet, { code: "0x6010", codeHash: row.graph.sourceSetCodeHash, nonce: 1n }));
    snapshot.createdAccounts.push(row.graph.sourceSet);
    for (let j = 0; j < 7; j++) {
      row.graph.children[j] = address(100 + i * 7 + j);
      row.graph.codeHashes[j] = id(`child${i}-${j}`);
      snapshot.accounts.push(account(row.graph.children[j], { code: "0x6020", codeHash: row.graph.codeHashes[j], nonce: 1n }));
      snapshot.createdAccounts.push(row.graph.children[j]);
    }
    row.selectionId = id(`selection${i}`);
    Object.assign(row.selection, { scope: { ...row.scope }, membershipHash: row.membership.membershipHash, tokenCount: count, nextIndex: count, selectionRoot: id(`root${i}`) });
  }
  Object.assign(preparation.collection, { writer: writer.writer, writerNonceAfterSetup: 4n });
  Object.assign(preparation.collection.coordinatorInventory, { exists: true, complete: true, processedTokens: 4n, tokenCount: 4n, coordinatorCount: 1n, commitment: id("coordinators") });
  const dumps = { "initial-dump.json": Buffer.from('{"synthetic": "initial, not parsed or admitted"}\n'), "final-dump.json": Buffer.from('{"synthetic": "final, not parsed or admitted"}\n') };
  return { cut, writer, preparation, prestate, snapshot, dumps };
}
function packet(data = synthetic(), substitutions = {}) {
  const files = { ...data.dumps, "prestate.abi": encode("prestate", data.prestate), "snapshot.abi": encode("snapshot", data.snapshot), "preparation.abi": encode("preparation", data.preparation), "writer.abi": encode("writer", data.writer), ...substitutions };
  const cut = { ...data.cut };
  for (const [field, name] of [["admittedPrestateHash", "prestate.abi"], ["initialDumpHash", "initial-dump.json"], ["finalDumpHash", "final-dump.json"], ["snapshotHash", "snapshot.abi"], ["preparationHash", "preparation.abi"], ["writerHash", "writer.abi"]]) cut[field] = keccak256(files[name]);
  files["cut.abi"] = encode("cut", cut);
  files["complete.abi"] = encode("complete", cut.profile, keccak256(files["cut.abi"]));
  return files;
}
const rejects = (edit, pattern) => { const input = synthetic(); edit(input); assert.throws(() => decodePreservationBootstrapPacket(packet(input)), pattern); };

test("fixed source and compiler schema identities stay separately qualified", () => {
  assert.equal(sha(rawWitness), PRESERVATION_BOOTSTRAP_SCHEMA_SHA256);
  assert.equal(witness.sourceCommit, PRESERVATION_BOOTSTRAP_SOURCE_COMMIT);
  assert.equal(witness.sourceTree, "45eadcea1043f24d389b781dfa260285bd5da754");
  assert.equal(witness.compiler.result.baseCommit, "4c00d1f2e808b97cdcb8926dfbc4e273a667094e");
  assert.equal(witness.compiler.result.evmStarted, false);
  assert.equal(witness.compiler.result.bytecodeRequested, false);
  assert.equal(witness.historicalTupleWitness.sourceCommit, "61d0efc5c88db67126a1af2e3ccaa6d1ddecb41d");
  const bootstrap = witness.sources["test/helpers/StreamCurrentAuthorityPreservationCallerBootstrap.sol"];
  assert.equal(bootstrap.sha256, "d28f5bcdb688042bb712c30bd454c6655fcb6996b406a5d7b254b95f939258d8");
  assert.equal(bootstrap.compilerInputSha256, "67e5b51ff4db0b97a1934c8f43e126357beff6abf27a979acfb7edc00f4fba19");
  assert.match(bootstrap.text, /function exportPreparationFile/);
  assert.match(bootstrap.text, /successful outer\n\s*\/\/\/ execution result/);
  for (const source of Object.values(witness.sources)) assert.equal(sha(Buffer.from(source.text)), source.sha256);
});

test("synthetic eight-file packet decodes exact outer tuples and keeps all execution claims false", () => {
  const input = synthetic(), files = packet(input), result = decodePreservationBootstrapPacket(files);
  assert.deepEqual(result.preparation, input.preparation);
  assert.deepEqual(result.writer, input.writer);
  assert.deepEqual(result.snapshot, input.snapshot);
  assert.deepEqual(result.prestate, input.prestate);
  for (const name of PRESERVATION_BOOTSTRAP_FILES) {
    assert.equal(result.files[name].sha256, sha(files[name]));
    assert.equal(result.files[name].keccak256, keccak256(files[name]));
    assert.equal(result.files[name].byteLength, files[name].length);
  }
  assert.equal(result.qualification.completionMarkerVerified, true);
  for (const name of ["outerExecutionVerified", "baselineAdmissionVerified", "dumpGrammarVerified", "dumpParityVerified", "nativeClosureVerified", "nativeLibraryTraceVerified", "runtimeCodeHashVerified", "protocolPreparationIndependentlyVerified", "importVerified", "deploymentAdmissionVerified"]) assert.equal(result.qualification[name], false);
  assert.ok(Object.isFrozen(result.snapshot.accounts[0]));
  assert.equal(ArrayBuffer.isView(result.preparation), false);
});

test("all six Cut file hashes bind exact raw bytes and marker is independently bound to Cut", () => {
  for (const name of PRESERVATION_BOOTSTRAP_FILES) {
    const files = packet(); files[name] = Buffer.concat([files[name], Buffer.from([0])]);
    assert.throws(() => decodePreservationBootstrapPacket(files), /raw file|canonical|offset|marker/);
  }
  rejects(x => { x.cut.profile = id("other profile"); }, /profile/);
  rejects(x => { x.cut.scenarioArtifact = id("other artifact"); }, /artifact/);
  const files = packet(); files["complete.abi"] = encode("complete", PRESERVATION_BOOTSTRAP_PROFILE, ZeroHash);
  assert.throws(() => decodePreservationBootstrapPacket(files), /marker/);
});

test("writer struct wrapper differs from flat writerState returns even with rehashed Cut", () => {
  const input = synthetic(), flat = binary(coder.encode(witness.abis.StreamCurrentAuthorityPreservationCallerScenario.find(x => x.name === "writerState").outputs, [input.writer.writer, input.writer.owners, input.writer.threshold, input.writer.nonce]));
  assert.notDeepEqual(flat, encode("writer", input.writer));
  assert.throws(() => decodePreservationBootstrapPacket(packet(input, { "writer.abi": flat })), /offset|count|canonical|bounds/);
  const cutFlat = binary(coder.encode(schema.cut[0].components, Object.values(input.cut)));
  const files = packet(input); files["cut.abi"] = cutFlat; files["complete.abi"] = encode("complete", input.cut.profile, keccak256(cutFlat));
  assert.throws(() => decodePreservationBootstrapPacket(files));
});

test("canonical ABI rejects rehashed trailing bytes, dirty bool/enum and oversized wire counts", () => {
  const input = synthetic();
  for (const name of ["prestate", "snapshot", "preparation", "writer"]) {
    const key = `${name}.abi`, files = packet(input), changed = Buffer.concat([files[key], Buffer.alloc(32)]);
    assert.throws(() => decodePreservationBootstrapPacket(packet(input, { [key]: changed })), /canonical/);
  }
  rejects(x => { x.preparation.scoped[0].scope.scopeType = 5n; }, /enum/);
  const dirty = encode("preparation", input.preparation);
  const dynamic = p => p.type === "bytes" || p.type === "string" || (p.baseType === "array" && (p.arrayLength === -1 || dynamic(p.arrayChildren))) || (p.baseType === "tuple" && p.components.some(dynamic));
  const width = p => dynamic(p) ? 32 : p.baseType === "tuple" ? p.components.reduce((n, c) => n + width(c), 0) : p.baseType === "array" ? p.arrayLength * width(p.arrayChildren) : 32;
  const member = (p, base, name) => {
    let offset = base;
    for (const c of p.components) {
      if (c.name === name) return { type: c, offset: dynamic(c) ? base + Number(BigInt(`0x${dirty.toString("hex", offset, offset + 32)}`)) : offset };
      offset += width(c);
    }
    throw Error("Missing original tuple member");
  };
  const preparationOffset = Number(BigInt(`0x${dirty.toString("hex", 0, 32)}`));
  const collection = member(schema.preparation[0], preparationOffset, "collection");
  const coordinator = member(collection.type, collection.offset, "coordinatorInventory");
  const complete = member(coordinator.type, coordinator.offset, "complete");
  dirty.fill(0, complete.offset, complete.offset + 32); dirty[complete.offset + 31] = 2;
  assert.throws(() => decodePreservationBootstrapPacket(packet(input, { "preparation.abi": dirty })), /canonical/);
  const fake = Buffer.concat([Buffer.from("20".padStart(64, "0"), "hex"), Buffer.from("1".padEnd(64, "0"), "hex")]);
  assert.throws(() => decodePreservationBootstrapPacket(packet(input, { "prestate.abi": fake })), /allocation|count/);
});

test("duplicate prestate/snapshot accounts and slots reject despite fully rehashed commitments", () => {
  rejects(x => { x.prestate.push({ ...x.prestate[0] }); }, /duplicate prestate account/);
  rejects(x => { x.snapshot.accounts.push({ ...x.snapshot.accounts[0] }); }, /duplicate snapshot account/);
  for (const set of ["prestate", "snapshot"]) rejects(x => {
    const rows = set === "prestate" ? x.prestate : x.snapshot.accounts;
    rows[0].slots = [{ slot: id("slot"), value: ZeroHash }, { slot: id("slot"), value: id("value") }];
  }, /duplicate .* slot/);
});

test("source created-account and seed closure consistency is checked without native trace claims", () => {
  rejects(x => { x.snapshot.createdAccounts.push(x.snapshot.createdAccounts[0]); }, /duplicate created/);
  rejects(x => { x.snapshot.createdAccounts.push(address(10000)); }, /created account missing/);
  rejects(x => { x.snapshot.createdAccounts = x.snapshot.createdAccounts.filter(a => a !== x.cut.scenario); }, /scenario missing/);
  rejects(x => { x.snapshot.accessCount = 0n; }, /access count/);
  rejects(x => { x.snapshot.accounts = x.snapshot.accounts.filter(a => a.account !== x.cut.caller); }, /source seed/);
  rejects(x => { x.snapshot.accounts.push(account(address(10000), { balance: 1n })); }, /unexplained/);
  const input = synthetic(); input.snapshot.accounts.push(account(address(10000)));
  assert.equal(decodePreservationBootstrapPacket(packet(input)).qualification.nativeClosureVerified, false);
});

test("all prestate seed slot keys must survive in final snapshot, with independently changed values allowed", () => {
  const input = synthetic(), key = id("seeded slot");
  input.prestate[1].slots = [{ slot: key, value: id("before value") }];
  assert.throws(() => decodePreservationBootstrapPacket(packet(input)), /seeded slot/);
  input.snapshot.accounts.find(a => a.account === input.prestate[1].account).slots = [{ slot: key, value: id("after value") }];
  assert.equal(decodePreservationBootstrapPacket(packet(input)).snapshot.accounts.find(a => a.account === input.prestate[1].account).slots[0].value, id("after value"));
});

test("zero-codeHash absent and observed VM magic hash remain facts without invented runtime hashing", () => {
  const result = decodePreservationBootstrapPacket(packet());
  const absent = result.snapshot.accounts.find(a => a.account === address(9));
  assert.equal(absent.codeHash, ZeroHash); assert.equal(absent.code, "0x");
  const vm = result.snapshot.accounts.find(a => a.account === PRESERVATION_BOOTSTRAP_VM_ADDRESS);
  assert.equal(vm.code, "0x"); assert.equal(vm.codeHash, id("observed Foundry VM magic code hash"));
  const scenario = result.snapshot.accounts.find(a => a.account === result.cut.scenario);
  assert.notEqual(scenario.codeHash, keccak256(scenario.code));
  assert.equal(result.qualification.runtimeCodeHashVerified, false);
});

test("dump bytes are hash-bound opaque inputs; grammar/parity and omission discovery stay separate", () => {
  const input = synthetic();
  input.dumps["initial-dump.json"] = Buffer.from([0xff, 0, 1]);
  input.dumps["final-dump.json"] = Buffer.from("not JSON and not a parity witness");
  const result = decodePreservationBootstrapPacket(packet(input));
  assert.equal(result.qualification.dumpGrammarVerified, false);
  assert.equal(result.qualification.dumpParityVerified, false);
  rejects(x => { x.cut.dumpOmissions = [x.cut.caller]; }, /omission/);
  rejects(x => { x.cut.dumpOmissions = [x.cut.recorder, x.cut.recorder]; }, /duplicate dump/);
  rejects(x => { x.snapshot.createdAccounts.push(x.cut.recorder); }, /omission/);
});

test("writer relationship permits an earlier Safe nonce and never equates the EVM account nonce", () => {
  const input = synthetic();
  input.writer.nonce = 1n << 200n;
  input.preparation.collection.writerNonceAfterSetup = input.writer.nonce - 10n;
  const result = decodePreservationBootstrapPacket(packet(input));
  assert.equal(result.writer.nonce, 1n << 200n);
  assert.equal(result.snapshot.accounts.find(a => a.account === result.writer.writer).nonce, 2n);
  rejects(x => { x.preparation.collection.writerNonceAfterSetup = x.writer.nonce + 1n; }, /earlier setup/);
  rejects(x => { x.preparation.collection.writer = address(11); }, /writer differs/);
  rejects(x => { x.writer.threshold = 0n; }, /writer observed/);
  rejects(x => { x.writer.threshold = 3n; }, /writer observed/);
});

test("source Scenario preparation counts, full scopes and untouched client identifiers are enforced", () => {
  rejects(x => { x.preparation.collection.membership.tokenCount = 3n; }, /membership/);
  rejects(x => { x.preparation.scoped[0].membership.tokenCount = 4n; }, /membership/);
  rejects(x => { x.preparation.scoped.reverse(); }, /scopes/);
  rejects(x => { x.preparation.scoped[1].selection.scope.scopeId = id("other"); }, /full scope/);
  rejects(x => { x.preparation.collection.graph.preparedChildren = 6n; }, /graph/);
  rejects(x => { x.preparation.collection.selection.nextIndex = 3n; }, /STATIC/);
  rejects(x => { x.preparation.collection.coordinatorInventory.complete = false; }, /coordinator/);
  for (const field of ["checkpointId", "outputPlan", "outputRecord", "rootHash"]) rejects(x => { x.preparation.scoped[1][field] = id("completed"); }, /publication identifiers/);
});

test("optional tuple fields retain arbitrary structural values without invented nonzero/order constraints", () => {
  const input = synthetic();
  input.cut.chainId = (1n << 256n) - 1n;
  input.cut.blockNumber = 0n; input.cut.timestamp = 0n; input.cut.baseFee = 0n;
  input.preparation.scoped[0].observedAt = (1n << 64n) - 1n;
  input.preparation.scoped[0].consentNonce = (1n << 256n) - 1n;
  input.preparation.scoped[0].snapshotPayload = "0x1234";
  input.preparation.scoped[0].metadataJSON = ["0xff", "0x", "0x00"];
  input.snapshot.accounts.reverse(); input.snapshot.createdAccounts.reverse(); input.prestate.reverse();
  const result = decodePreservationBootstrapPacket(packet(input));
  assert.equal(result.preparation.scoped[0].observedAt, (1n << 64n) - 1n);
  assert.deepEqual(result.preparation.scoped[0].metadataJSON, ["0xff", "0x", "0x00"]);
  assert.equal(result.cut.chainId, (1n << 256n) - 1n);
});

test("exact eight buffers only, detached immutable return and bounded files", () => {
  const files = packet();
  assert.throws(() => decodePreservationBootstrapPacket({ ...files, extra: Buffer.alloc(0) }), /eight/);
  assert.throws(() => decodePreservationBootstrapPacket({ ...files, "prestate.abi": `0x${files["prestate.abi"].toString("hex")}` }), /raw bytes/);
  const accessor = { ...files }; Object.defineProperty(accessor, "snapshot.abi", { get: () => files["snapshot.abi"] });
  assert.throws(() => decodePreservationBootstrapPacket(accessor), /raw bytes/);
  const result = decodePreservationBootstrapPacket(files), saved = result.files["snapshot.abi"].sha256;
  files["snapshot.abi"].fill(0);
  assert.equal(result.files["snapshot.abi"].sha256, saved);
  assert.equal(result.snapshot.accounts[0].account, address(9));
  assert.throws(() => { result.writer.owners.push(address(55)); }, TypeError);
});
