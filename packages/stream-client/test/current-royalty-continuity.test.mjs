import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import {
  CurrentRoyaltyContinuityClient, ROYALTY_CONTINUITY_CANONICALIZATION, ROYALTY_CONTINUITY_CLASS,
  ROYALTY_CONTINUITY_SCHEMA, royaltyContinuityElectionHash, royaltyContinuityFrozenStateHash,
  royaltyContinuityHeaderHash, royaltyContinuityManifestHash, royaltyContinuityRoots,
  royaltyContinuityRouteHash, royaltyContinuityRouteKey, parseRoyaltyContinuityPlanJSON,
} from "../dist/current-royalty-continuity.js";
import { royaltyContinuityFixture } from "../scripts/generate-current-royalty-continuity-fixture.mjs";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-royalty-continuity-abi.json", import.meta.url), "utf8"));
const resolver = new Interface(fixture.abis.resolver), coreAbi = new Interface(fixture.abis.core),
  authorityAbi = new Interface(["function isStreamGovernedParameterAuthority() view returns (bool)"]), coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), H = id;
const chain = 31337n, source = A(1), target = A(2), core = A(3), factory = A(4), authority = A(5), hashOrigin = A(99);
const deployment = { source, target, core, factory, authority };
const code = { [source]: "0x6001", [target]: "0x6002", [core]: "0x6003", [factory]: "0x6004", [authority]: "0x6005" };
const codeHash = Object.fromEntries(Object.entries(code).map(([a, v]) => [a, keccak256(v)]));
const CONFIG = "tuple(address wallet,uint16 royaltyBps,bool configured,bool frozen,uint64 revision,bytes32 profileId)";
const SNAPSHOT = "tuple(bool exists,uint256 collectionId,uint256 tokenId,address manager,bytes32 operationRoot,bytes32 operationId,bytes32 preparedProofHash,bytes32 electionHash,bytes32 sourceAssignmentHash,bytes32 modeAssignmentHash,bytes32 sourceRoyaltyPolicyHash,bytes32 tokenAssignmentHash,bytes32 tokenRoyaltyPolicyHash,bytes32 tokenConfigHash)";
const ROUTE = `tuple(uint8 scope,uint256 scopeId,uint256 collectionId,address hashOrigin,${CONFIG} config,bytes32 assignmentHash,bytes32 policyHash,${SNAPSHOT} snapshot)`;
const ELECTION = "tuple(uint256 collectionId,uint8 mode,bytes32 electionHash,address hashOrigin)";
const HEADER = "tuple(uint16 schemaVersion,address core,address factory,uint16 maxRoyaltyBps,uint256 protectedCount,bytes32 protectedRoot,uint256 electionCount,bytes32 electionRoot,bytes32 frozenStateHash)";
const MANIFEST = "tuple(bytes32 expectedSourceHeaderHash,bytes32 contentHash,string uri,bytes32 uriHash,bytes32 schemaId,bytes32 canonicalizationId)";
const uri = "ipfs://royalty-continuity/immutable.json", maximum = 1000n;
const config = { wallet: A(10), royaltyBps: 750n, configured: true, frozen: true, revision: 9007199254740991n, profileId: H("profile") };
const assignmentHash = H("assignment"), policyHash = H("policy"), collectionId = 9007199254740993n, tokenId = 9007199254740999n;
const election = { collectionId, mode: 2n, electionHash: ZeroHash, hashOrigin };
election.electionHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint8"],
  [H("6529STREAM_ROYALTY_MODE_ELECTION_V1"), chain, hashOrigin, core, collectionId, 2n]));
const snapshot = { exists: true, collectionId, tokenId, manager: A(11), operationRoot: H("operation root"), operationId: H("operation id"),
  preparedProofHash: H("prepared proof"), electionHash: election.electionHash, sourceAssignmentHash: H("source assignment"),
  modeAssignmentHash: H("mode assignment"), sourceRoyaltyPolicyHash: H("source policy"), tokenAssignmentHash: assignmentHash,
  tokenRoyaltyPolicyHash: policyHash, tokenConfigHash: keccak256(coder.encode([CONFIG], [config])) };
const route = { scope: 2n, scopeId: tokenId, collectionId, hashOrigin, config, assignmentHash, policyHash, snapshot };

function independentData() {
  const routeKey = keccak256(coder.encode(["bytes32", "uint8", "uint256"], [H("ROYALTY_ERC2981"), route.scope, route.scopeId]));
  const routeHash = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint8", "uint256", "uint256", "address", CONFIG, "bytes32", "bytes32", "uint8", SNAPSHOT],
    [H("6529STREAM_PROTECTED_ROYALTY_ROUTE_V1"), chain, core, H("ROYALTY_ERC2981"), route.scope, route.scopeId,
      route.collectionId, route.hashOrigin, route.config, route.assignmentHash, route.policyHash, 1n, route.snapshot]));
  const protectedRoot = keccak256(coder.encode(["bytes32", "uint256", "bytes32", "bytes32"], [ZeroHash, 0n, routeKey, routeHash]));
  const electionRoot = keccak256(coder.encode(["bytes32", "uint256", ELECTION], [ZeroHash, 0n, election]));
  const frozenStateHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "uint256", "bytes32", "uint256", "bytes32"],
    [H("6529STREAM_FROZEN_ROYALTY_STATE_V1"), chain, core, factory, maximum, 1n, protectedRoot, 1n, electionRoot]));
  const header = { schemaVersion: 1n, core, factory, maxRoyaltyBps: maximum, protectedCount: 1n, protectedRoot,
    electionCount: 1n, electionRoot, frozenStateHash };
  const headerHash = keccak256(coder.encode([HEADER], [header])), uriHash = keccak256(toUtf8Bytes(uri));
  const manifestHash = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "address", HEADER, "string", "bytes32", "bytes32", "bytes32"],
    [H("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"), chain, source, codeHash[source], target, core, factory, header, uri, uriHash,
      H("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"), H("STREAM_ROYALTY_CONTINUITY_ABI_V1")]));
  const reference = { expectedSourceHeaderHash: headerHash, contentHash: manifestHash, uri, uriHash,
    schemaId: H("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"), canonicalizationId: H("STREAM_ROYALTY_CONTINUITY_ABI_V1") };
  const scope = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address"],
    [H("6529STREAM_ROYALTY_CONTINUITY_BEGIN_V1"), chain, target, core, source]));
  const oldValueHash = keccak256(coder.encode(["bytes32", "uint8", "uint256"], [scope, 0n, 0n]));
  const newValueHash = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", HEADER, "address", "bytes32"],
    [scope, manifestHash, codeHash[source], header, authority, codeHash[authority]]));
  return { routeKey, routeHash, protectedRoot, electionRoot, header, headerHash, manifestHash, reference, scope, oldValueHash, newValueHash };
}
const expected = independentData();
const emptyHeader = { schemaVersion: 0n, core: ZeroAddress, factory: ZeroAddress, maxRoyaltyBps: 0n, protectedCount: 0n,
  protectedRoot: ZeroHash, electionCount: 0n, electionRoot: ZeroHash, frozenStateHash: ZeroHash };
const emptyRef = { expectedSourceHeaderHash: ZeroHash, contentHash: ZeroHash, uri: "", uriHash: ZeroHash, schemaId: ZeroHash, canonicalizationId: ZeroHash };

class RPC {
  number = 100; status = 0n; importedRoutes = 0n; importedElections = 0n; plan = null; mutateHeader = false; changedCode = false;
  ownerDrift = false; badPreview = false; authorityMarker = true; delegatedAuthority = false; reorg = false; calls = [];
  async getNetwork() { return { chainId: chain }; }
  async getBlock(tag) {
    const number = typeof tag === "number" ? tag : this.number;
    return { number, hash: H(this.reorg && tag !== "latest" ? "changed block" : `block ${number}`), timestamp: 1000 };
  }
  async getCode(address) {
    if (this.changedCode && address === source) return "0x6011";
    if (this.delegatedAuthority && address === authority) return "0xef0100" + "11".repeat(20);
    return code[address];
  }
  state() {
    if (this.status === 0n) return { status: 0n, source: ZeroAddress, sourceRuntimeHash: ZeroHash, manifestHash: ZeroHash,
      beginActionId: ZeroHash, importedRoutes: 0n, importedElections: 0n, expected: emptyHeader, manifestReference: emptyRef };
    return { status: this.status, source, sourceRuntimeHash: codeHash[source], manifestHash: this.plan.manifestHash,
      beginActionId: H("action"), importedRoutes: this.importedRoutes, importedElections: this.importedElections,
      expected: expected.header, manifestReference: this.plan.manifestReference };
  }
  async call(tx) {
    this.calls.push(tx);
    if (tx.to === core) {
      const parsed = coreAbi.parseTransaction(tx); assert.equal(parsed.name, "getSatellitePointer");
      return coreAbi.encodeFunctionResult(parsed.name, [source, codeHash[source], false, ZeroHash, "0x00000000", ZeroAddress, 0n, ZeroHash, ZeroHash, 1n]);
    }
    if (tx.to === authority) {
      const parsed = authorityAbi.parseTransaction(tx); assert.equal(parsed.name, "isStreamGovernedParameterAuthority");
      return authorityAbi.encodeFunctionResult(parsed.name, [this.authorityMarker]);
    }
    if (tx.to !== source && tx.to !== target) throw Error(`Unexpected target ${tx.to}`);
    const parsed = resolver.parseTransaction(tx), name = parsed.name, isSource = tx.to === source; let out;
    if (name === "owner") out = [this.ownerDrift && isSource ? A(123) : authority];
    else if (name === "governanceAuthority") out = [authority];
    else if (name === "boundCore") out = [core];
    else if (name === "boundCoreCodeHash") out = [codeHash[core]];
    else if (name === "splitFactory") out = [factory];
    else if (name === "MAX_ROYALTY_BPS") out = [maximum];
    else if (name === "supportsInterface") out = [true];
    else if (name === "continuityHeader") out = [isSource ? { ...expected.header, ...(this.mutateHeader ? { protectedRoot: H("changed root") } : {}) } : emptyHeader];
    else if (name === "protectedEconomicRouteAt") { assert(isSource); assert.equal(parsed.args[0], 0n); out = [route]; }
    else if (name === "economicElectionAt") { assert(isSource); assert.equal(parsed.args[0], 0n); out = [election]; }
    else if (name === "previewEconomicContinuity") { assert(!isSource); assert.equal(parsed.args[0], source); out = [this.badPreview ? H("mutated target") : expected.manifestHash, expected.scope, expected.oldValueHash, expected.newValueHash]; }
    else if (name === "economicContinuityState") out = [this.state()];
    else if (name === "economicContinuityReady") out = [isSource || (typeof tx.blockTag === "number" && tx.blockTag < this.number) || this.status !== 1n];
    else if (name === "continuitySource") out = [this.status === 0n ? ZeroAddress : source];
    else if (name === "continuityManifestHash") out = [this.status === 0n ? ZeroHash : this.plan.manifestHash];
    else if (name === "supportsEconomicContinuity") out = [this.status === 2n && parsed.args[0] === source
      && parsed.args[1] === expected.header.frozenStateHash && parsed.args[2] === this.plan.manifestHash];
    else if (["beginEconomicContinuity", "importEconomicContinuity", "completeEconomicContinuity"].includes(name)) return "0x";
    else throw Error(`Unhandled ${name}`);
    return resolver.encodeFunctionResult(name, out);
  }
}
const make = () => new CurrentRoyaltyContinuityClient(chain, deployment, fixture.abis);
const savedJSON = plan => JSON.stringify(plan, (_key, value) => typeof value === "bigint" ? { $bigint: value.toString() } : value);

test("pure producers match independent Solidity abi.encode preimages and retain original hash origin", () => {
  assert.equal(ROYALTY_CONTINUITY_CLASS, H("ROYALTY_ERC2981"));
  assert.equal(ROYALTY_CONTINUITY_SCHEMA, expected.reference.schemaId);
  assert.equal(ROYALTY_CONTINUITY_CANONICALIZATION, expected.reference.canonicalizationId);
  assert.equal(royaltyContinuityRouteKey(route), expected.routeKey);
  assert.equal(royaltyContinuityRouteHash(chain, core, route), expected.routeHash);
  assert.equal(royaltyContinuityElectionHash(chain, core, election), election.electionHash);
  assert.deepEqual(royaltyContinuityRoots(chain, core, [route], [election]), { protectedRoot: expected.protectedRoot, electionRoot: expected.electionRoot });
  assert.equal(royaltyContinuityFrozenStateHash(chain, expected.header), expected.header.frozenStateHash);
  assert.equal(royaltyContinuityHeaderHash(expected.header), expected.headerHash);
  assert.equal(royaltyContinuityManifestHash(chain, source, codeHash[source], target, expected.header,
    { uri, uriHash: expected.reference.uriHash, schemaId: expected.reference.schemaId, canonicalizationId: expected.reference.canonicalizationId }), expected.manifestHash);
  assert.equal(route.hashOrigin, hashOrigin); assert.notEqual(route.hashOrigin, source); assert.notEqual(route.hashOrigin, target);
});

test("capture pins actual current source, full-width inventory, immutable roots and exact governed preview", async () => {
  const client = make(), rpc = new RPC(), plan = await client.capture(rpc, uri, { maxRoutes: 1n, maxElections: 1n }); rpc.plan = plan;
  assert.equal(plan.headerHash, expected.headerHash); assert.equal(plan.manifestHash, expected.manifestHash);
  assert.equal(keccak256(plan.canonicalManifest), plan.manifestHash);
  assert.equal(plan.routes[0].scopeId, tokenId); assert.equal(plan.routes[0].config.revision, 9007199254740991n);
  assert.deepEqual(plan.transition, { actionClass: 1, scope: expected.scope, oldValueHash: expected.oldValueHash, newValueHash: expected.newValueHash });
  assert(Object.isFrozen(plan.routes[0].snapshot));
  const begin = client.begin(plan); assert.equal(begin.caller, authority); assert.equal(begin.call.value, 0n);
  const decoded = resolver.parseTransaction(begin.call); assert.equal(decoded.name, "beginEconomicContinuity");
  assert.equal(decoded.args.source, source); assert.equal(decoded.args.manifestReference.contentHash, expected.manifestHash);
  assert.throws(() => client.safeCall(begin), /governance authority action/);
  assert.throws(() => client.safeCall({ ...begin }), /Changed continuity action/);
});

test("strict capture bounds and independently changed inventory or source fail closed", async () => {
  await assert.rejects(make().capture(new RPC(), uri, { maxRoutes: 0n, maxElections: 1n }), /exceeds explicit/);
  await assert.rejects(make().capture(new RPC(), uri, { maxRoutes: 4097n, maxElections: 1n }), /4096/);
  const changed = new RPC(); changed.mutateHeader = true; await assert.rejects(make().capture(changed, uri, { maxRoutes: 1n, maxElections: 1n }), /header|inventory/);
  const runtime = new RPC(); runtime.changedCode = true; await assert.rejects(make().capture(runtime, uri, { maxRoutes: 1n, maxElections: 1n }), /Core does not select/);
  const marker = new RPC(); marker.authorityMarker = false; await assert.rejects(make().capture(marker, uri, { maxRoutes: 1n, maxElections: 1n }), /marker/);
  const delegated = new RPC(); delegated.delegatedAuthority = true; await assert.rejects(make().capture(delegated, uri, { maxRoutes: 1n, maxElections: 1n }), /authority runtime/);
});

test("fresh inspection rejects stale continuation and emits only bounded permissionless import CALLs", async () => {
  const client = make(), rpc = new RPC(), plan = await client.capture(rpc, uri, { maxRoutes: 1n, maxElections: 1n }); rpc.plan = plan;
  assert.equal((await client.inspect(rpc, plan)).phase, "awaiting-begin");
  await assert.rejects(client.next(rpc, plan, A(20)), /begin has not executed/);
  rpc.status = 1n; rpc.number = 101;
  const next = await client.next(rpc, plan, A(20), { maxRoutes: 16n, maxElections: 64n });
  assert.equal(next.kind, "import"); assert.equal(next.action.caller, A(20)); assert.equal(next.action.call.value, 0n);
  const decoded = resolver.parseTransaction(next.action.call); assert.equal(decoded.name, "importEconomicContinuity");
  assert.deepEqual([...decoded.args], [16n, 64n]);
  await assert.rejects(client.next(rpc, plan, A(20), { maxRoutes: 17n, maxElections: 0n }), /exceeds/);
  await assert.rejects(client.next(rpc, plan, A(20), { maxRoutes: 16n, maxElections: 0n }), /pending elections/);
  rpc.importedElections = 1n;
  await assert.rejects(client.next(rpc, plan, A(20), { maxRoutes: 0n, maxElections: 64n }), /pending routes/);
  rpc.mutateHeader = true; await assert.rejects(client.next(rpc, plan, A(20)), /source header changed/);
});

test("freshness rechecks canonical ownership and pristine preview before any continuation", async () => {
  const client = make(), rpc = new RPC(), plan = await client.capture(rpc, uri, { maxRoutes: 1n, maxElections: 1n }); rpc.plan = plan;
  rpc.ownerDrift = true; await assert.rejects(client.inspect(rpc, plan), /constructor identity/);
  rpc.ownerDrift = false; rpc.badPreview = true; await assert.rejects(client.inspect(rpc, plan), /no longer pristine/);
});

test("complete is offered only after exact cursors; completed capability is not presented as Core cutover", async () => {
  const client = make(), rpc = new RPC(), plan = await client.capture(rpc, uri, { maxRoutes: 1n, maxElections: 1n }); rpc.plan = plan;
  rpc.status = 1n; rpc.importedRoutes = 1n; rpc.importedElections = 1n;
  const completion = await client.next(rpc, plan, A(21)); assert.equal(completion.kind, "complete");
  assert.equal(resolver.parseTransaction(completion.action.call).name, "completeEconomicContinuity");
  rpc.status = 2n;
  const observed = await client.inspect(rpc, plan); assert.equal(observed.phase, "completed");
  assert.equal(observed.supportsPinnedContinuity, true); assert.equal(observed.coreStillUsesSource, true);
  assert.deepEqual(await client.next(rpc, plan, A(21)), { kind: "completed", observation: observed });
});

test("permissionless simulation preserves the actual caller and zero-value CALL without sending", async () => {
  const client = make(), rpc = new RPC(), plan = await client.capture(rpc, uri, { maxRoutes: 1n, maxElections: 1n }); rpc.plan = plan;
  const begin = client.begin(plan); await assert.rejects(client.simulate(rpc, begin), /executing action context/);
  rpc.status = 1n; rpc.number = 101;
  const { action } = await client.next(rpc, plan, A(22)); assert.equal(await client.simulate(rpc, action, "pending"), "0x");
  const simulated = rpc.calls.at(-1); assert.equal(simulated.to, target); assert.equal(simulated.from, A(22));
  assert.equal(simulated.value, 0n); assert.equal(simulated.blockTag, "pending");
});

test("a fresh process reconstructs durable evidence before resuming importing or completed candidates", async () => {
  const first = make(), rpc = new RPC(), original = await first.capture(rpc, uri, { maxRoutes: 1n, maxElections: 1n }); rpc.plan = original;
  const text = savedJSON(original), parsed = parseRoyaltyContinuityPlanJSON(text);
  rpc.status = 1n; rpc.number = 101;
  const restored = await make().restore(rpc, parsed); assert.equal(restored.observation.phase, "importing");
  assert.notEqual(restored.plan, original); assert(Object.isFrozen(restored.plan));
  const next = await make().restore(rpc, parseRoyaltyContinuityPlanJSON(text));
  assert.equal(next.observation.importedRoutes, 0n);
  rpc.status = 2n; rpc.importedRoutes = 1n; rpc.importedElections = 1n;
  assert.equal((await make().restore(rpc, parseRoyaltyContinuityPlanJSON(text))).observation.phase, "completed");
  const badRoot = parseRoyaltyContinuityPlanJSON(text); badRoot.header.protectedRoot = H("forged root");
  await assert.rejects(make().restore(rpc, badRoot), /reproduce|header commitment/);
  const badBytes = parseRoyaltyContinuityPlanJSON(text); badBytes.canonicalManifest = "0x00" + badBytes.canonicalManifest.slice(4);
  await assert.rejects(make().restore(rpc, badBytes), /canonical manifest/);
  const badBlock = parseRoyaltyContinuityPlanJSON(text); badBlock.blockHash = H("forged capture block");
  await assert.rejects(make().restore(rpc, badBlock), /capture block provenance/);
  const changed = new RPC(); changed.plan = original; changed.status = 1n; changed.changedCode = true;
  await assert.rejects(make().restore(changed, parseRoyaltyContinuityPlanJSON(text)), /source runtime provenance|runtime changed/);
  assert.throws(() => parseRoyaltyContinuityPlanJSON('{"x":{"$bigint":"01"}}'), /tagged bigint/);
});

test("fixture records the exact canonical source and clean compiler input/output digests", () => {
  assert.equal(fixture.sourceCommit, "49364823b9e537a33896346b67639e523b4f31d1");
  assert.match(fixture.inputSha256, /^[0-9a-f]{64}$/); assert.match(fixture.outputSha256, /^[0-9a-f]{64}$/);
  assert.match(fixture.qualification, /no deployment, Core-cutover, native-runtime, audit or release claim/);
  assert.throws(() => royaltyContinuityFixture("{}", "{}"), /differs from the reviewed canonical/);
});
