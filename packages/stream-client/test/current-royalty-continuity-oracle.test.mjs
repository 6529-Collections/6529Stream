import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes } from "ethers";
import * as continuity from "../dist/current-royalty-continuity.js";

// Literal production preimages from 49364823. Artificial rows exercise encoding;
// they are not captures of admitted routes or completed contract imports.
const coder = AbiCoder.defaultAbiCoder(), chainId = 31337n;
const address = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const core = address(1), factory = address(2), source = address(3), target = address(4), origin = address(5);
const collection = 9007199254740993n, token = collection + 10n;
const configType = "tuple(address wallet,uint16 royaltyBps,bool configured,bool frozen,uint64 revision,bytes32 profileId)";
const snapshotType = "tuple(bool exists,uint256 collectionId,uint256 tokenId,address manager,bytes32 operationRoot,bytes32 operationId,bytes32 preparedProofHash,bytes32 electionHash,bytes32 sourceAssignmentHash,bytes32 modeAssignmentHash,bytes32 sourceRoyaltyPolicyHash,bytes32 tokenAssignmentHash,bytes32 tokenRoyaltyPolicyHash,bytes32 tokenConfigHash)";
const headerType = "tuple(uint16 schemaVersion,address core,address factory,uint16 maxRoyaltyBps,uint256 protectedCount,bytes32 protectedRoot,uint256 electionCount,bytes32 electionRoot,bytes32 frozenStateHash)";
const electionType = "tuple(uint256 collectionId,uint8 mode,bytes32 electionHash,address hashOrigin)";
const zeroSnapshot = { exists: false, collectionId: 0n, tokenId: 0n, manager: ZeroAddress,
  operationRoot: ZeroHash, operationId: ZeroHash, preparedProofHash: ZeroHash, electionHash: ZeroHash,
  sourceAssignmentHash: ZeroHash, modeAssignmentHash: ZeroHash, sourceRoyaltyPolicyHash: ZeroHash,
  tokenAssignmentHash: ZeroHash, tokenRoyaltyPolicyHash: ZeroHash, tokenConfigHash: ZeroHash };
const config = { wallet: ZeroAddress, royaltyBps: 0n, configured: true, frozen: true,
  revision: (1n << 64n) - 1n, profileId: ZeroHash };
const collectionRoute = { scope: 1n, scopeId: collection, collectionId: collection, hashOrigin: origin,
  config, assignmentHash: id("configured zero assignment"), policyHash: id("configured zero policy"), snapshot: zeroSnapshot };
const election = { collectionId: collection, mode: 2n, electionHash: ZeroHash, hashOrigin: origin };
election.electionHash = keccak256(coder.encode(
  ["bytes32", "uint256", "address", "address", "uint256", "uint8"],
  [id("6529STREAM_ROYALTY_MODE_ELECTION_V1"), chainId, origin, core, collection, 2n],
));
const tokenRoute = { ...collectionRoute, scope: 2n, scopeId: token,
  assignmentHash: id("snapshot token assignment"), policyHash: id("snapshot token policy"),
  snapshot: { exists: true, collectionId: collection, tokenId: token, manager: address(6),
    operationRoot: id("operation root"), operationId: id("operation ID"), preparedProofHash: id("prepared proof"),
    electionHash: election.electionHash, sourceAssignmentHash: collectionRoute.assignmentHash,
    modeAssignmentHash: id("mode assignment"), sourceRoyaltyPolicyHash: collectionRoute.policyHash,
    tokenAssignmentHash: id("snapshot token assignment"), tokenRoyaltyPolicyHash: id("snapshot token policy"),
    tokenConfigHash: keccak256(coder.encode([configType], [config])) } };
function routeKey(route) {
  return keccak256(coder.encode(["bytes32", "uint8", "uint256"], [id("ROYALTY_ERC2981"), route.scope, route.scopeId]));
}
function routeHash(route, chain = chainId, boundCore = core) {
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "uint8", "uint256", "uint256", "address", configType, "bytes32", "bytes32", "uint8", snapshotType],
    [id("6529STREAM_PROTECTED_ROYALTY_ROUTE_V1"), chain, boundCore, id("ROYALTY_ERC2981"), route.scope,
      route.scopeId, route.collectionId, route.hashOrigin, route.config, route.assignmentHash, route.policyHash, 1n, route.snapshot],
  ));
}
function roots(routes, elections) {
  let protectedRoot = ZeroHash, electionRoot = ZeroHash;
  routes.forEach((route, index) => { protectedRoot = keccak256(coder.encode(
    ["bytes32", "uint256", "bytes32", "bytes32"], [protectedRoot, BigInt(index), routeKey(route), routeHash(route)],
  )); });
  elections.forEach((row, index) => { electionRoot = keccak256(coder.encode(
    ["bytes32", "uint256", electionType], [electionRoot, BigInt(index), row],
  )); });
  return { protectedRoot, electionRoot };
}
const header = { schemaVersion: 1n, core, factory, maxRoyaltyBps: 10000n,
  protectedCount: 2n, ...roots([collectionRoute, tokenRoute], [election]), electionCount: 1n, frozenStateHash: ZeroHash };
header.frozenStateHash = keccak256(coder.encode(
  ["bytes32", "uint256", "address", "address", "uint16", "uint256", "bytes32", "uint256", "bytes32"],
  [id("6529STREAM_FROZEN_ROYALTY_STATE_V1"), chainId, core, factory, header.maxRoyaltyBps,
    header.protectedCount, header.protectedRoot, header.electionCount, header.electionRoot],
));

test("royalty route and election preimages preserve first origin across replacement hops", () => {
  for (const row of [collectionRoute, tokenRoute]) {
    assert.equal(continuity.royaltyContinuityRouteKey({ scope: row.scope, scopeId: row.scopeId }), routeKey(row));
    assert.equal(continuity.royaltyContinuityRouteHash(chainId, core, row), routeHash(row));
    assert.notEqual(continuity.royaltyContinuityRouteHash(chainId, core, { ...row, hashOrigin: source }), routeHash(row));
    assert.notEqual(continuity.royaltyContinuityRouteHash(chainId, core, { ...row, hashOrigin: target }), routeHash(row));
    assert.notEqual(continuity.royaltyContinuityRouteHash(chainId + 1n, core, row), routeHash(row));
    assert.notEqual(continuity.royaltyContinuityRouteHash(chainId, address(9), row), routeHash(row));
  }
  assert.equal(continuity.royaltyContinuityElectionHash(chainId, core, election), election.electionHash);
  assert.notEqual(continuity.royaltyContinuityElectionHash(chainId, core, { ...election, hashOrigin: source }), election.electionHash);
  assert.notEqual(continuity.royaltyContinuityRouteHash(chainId, core, {
    ...tokenRoute, snapshot: { ...tokenRoute.snapshot, sourceAssignmentHash: id("substitute source") },
  }), routeHash(tokenRoute));
});

test("rolling roots preserve ordered rows, full-width identities and complete snapshots", () => {
  const actual = continuity.royaltyContinuityRoots(chainId, core, [collectionRoute, tokenRoute], [election]);
  assert.deepEqual(actual, roots([collectionRoute, tokenRoute], [election]));
  assert.notEqual(continuity.royaltyContinuityRoots(chainId, core, [tokenRoute, collectionRoute], [election]).protectedRoot, actual.protectedRoot);
  assert.notEqual(continuity.royaltyContinuityRoots(chainId, core, [collectionRoute], [election]).protectedRoot, actual.protectedRoot);
  assert.notEqual(continuity.royaltyContinuityRoots(chainId, core, [collectionRoute, tokenRoute], [{ ...election, mode: 1n }]).electionRoot, actual.electionRoot);
  assert.deepEqual(continuity.royaltyContinuityRoots(chainId, core, [], []), { protectedRoot: ZeroHash, electionRoot: ZeroHash });
});

test("header ABI commitment and frozen-state commitment use different exact preimages", () => {
  assert.equal(continuity.royaltyContinuityHeaderHash(header), keccak256(coder.encode([headerType], [header])));
  assert.equal(continuity.royaltyContinuityFrozenStateHash(chainId, header), header.frozenStateHash);
  assert.notEqual(continuity.royaltyContinuityHeaderHash(header), header.frozenStateHash);
  const empty = { ...header, protectedCount: 0n, protectedRoot: ZeroHash, electionCount: 0n, electionRoot: ZeroHash, frozenStateHash: ZeroHash };
  assert.equal(continuity.royaltyContinuityFrozenStateHash(chainId, empty), ZeroHash);
  assert.notEqual(continuity.royaltyContinuityFrozenStateHash(chainId, { ...header, factory: address(9) }), header.frozenStateHash);
});

test("canonical manifest bytes bind source runtime, destination, UTF-8 URI and original complete header", () => {
  const uri = "ipfs://reviewed-manifest/royalties-\u03bb";
  const reference = { uri, uriHash: keccak256(toUtf8Bytes(uri)),
    schemaId: id("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"), canonicalizationId: id("STREAM_ROYALTY_CONTINUITY_ABI_V1") };
  const codeHash = id("source runtime");
  const encoded = coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "address", "address", "address", headerType, "string", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"), chainId, source, codeHash, target, core, factory,
      header, uri, reference.uriHash, reference.schemaId, reference.canonicalizationId],
  );
  assert.equal(continuity.royaltyContinuityManifestBytes(chainId, source, codeHash, target, header, reference), encoded);
  assert.equal(continuity.royaltyContinuityManifestHash(chainId, source, codeHash, target, header, reference), keccak256(encoded));
  assert.notEqual(continuity.royaltyContinuityManifestHash(chainId, source, codeHash, address(8), header, reference), keccak256(encoded));
  assert.notEqual(continuity.royaltyContinuityManifestHash(chainId, source, id("changed runtime"), target, header, reference), keccak256(encoded));
});

test("public royalty preimage boundaries reject lossy uints, boolean coercion and unknown tuple data", () => {
  assert.throws(() => continuity.royaltyContinuityHeaderHash({ ...header, protectedCount: 2 }));
  assert.throws(() => continuity.royaltyContinuityRouteHash(chainId, core, {
    ...collectionRoute, config: { ...config, frozen: "false" },
  }));
  assert.throws(() => continuity.royaltyContinuityRouteHash(chainId, core, { ...collectionRoute, scopeId: Number(collection) }));
  assert.throws(() => continuity.royaltyContinuityHeaderHash({ ...header, unreviewed: 1n }));
  assert.throws(() => continuity.royaltyContinuityRouteHash(chainId, core, {
    ...collectionRoute, config: { ...config, revision: 1n << 64n },
  }));
});
