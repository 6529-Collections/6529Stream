import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import { toSafeCall } from "../src/safe.js";
import {
  type TokenPreservationSnapshotV2Coordinates,
  type TokenPreservationSnapshotV2Dependencies,
  type TokenPreservationSnapshotV2Scope,
  type TokenPreservationSnapshotV2CollectionPublication,
  type TokenPreservationSnapshotV2ScopedPublication,
  type TokenPreservationSnapshotV2CollectionSource,
  type TokenPreservationSnapshotV2ScopedSource,
  type TokenPreservationSnapshotV2Receipt,
  type TokenPreservationSnapshotV2Lock,
  type TokenPreservationSnapshotV2Authority,
  type TokenPreservationSnapshotV2Request,
  type TokenPreservationSnapshotV2ReadRequest,
  normalizeTokenPreservationSnapshotV2Coordinates,
  normalizeTokenPreservationSnapshotV2Dependencies,
  normalizeTokenPreservationSnapshotV2CollectionPublication,
  normalizeTokenPreservationSnapshotV2ScopedPublication,
  normalizeTokenPreservationSnapshotV2CollectionSource,
  normalizeTokenPreservationSnapshotV2ScopedSource,
  encodeTokenPreservationSnapshotV2CollectionSource,
  decodeTokenPreservationSnapshotV2CollectionSource,
  encodeTokenPreservationSnapshotV2ScopedSource,
  decodeTokenPreservationSnapshotV2ScopedSource,
  normalizeTokenPreservationSnapshotV2Receipt,
  validateTokenPreservationSnapshotV2Scope,
  validateTokenPreservationSnapshotV2Dependencies,
  validateTokenPreservationSnapshotV2Publication,
  validateTokenPreservationSnapshotV2Candidate,
  validateTokenPreservationSnapshotV2Source,
  tokenPreservationSnapshotV2ScopeSubject,
  tokenPreservationSnapshotV2SourceHash,
  tokenPreservationSnapshotV2RootRecordHash,
  tokenPreservationSnapshotV2PreviewReceipt,
  tokenPreservationSnapshotV2SnapshotBytes,
  decodeTokenPreservationSnapshotV2SnapshotBytes,
  tokenPreservationSnapshotV2RecordHash,
  tokenPreservationSnapshotV2ChainHash,
  tokenPreservationSnapshotV2Chunks,
  tokenPreservationSnapshotV2Definitions,
  tokenPreservationSnapshotV2RootDefinitions,
  authenticateTokenPreservationSnapshotV2History,
  prepareTokenPreservationSnapshotV2Call,
  normalizeTokenPreservationSnapshotV2Call,
  prepareTokenPreservationSnapshotV2Read,
  normalizeTokenPreservationSnapshotV2Read,
} from "../src/current-token-preservation-snapshot-v2.js";

declare const c: TokenPreservationSnapshotV2Coordinates;
declare const d: TokenPreservationSnapshotV2Dependencies;
declare const scope: TokenPreservationSnapshotV2Scope;
declare const collection: TokenPreservationSnapshotV2CollectionPublication;
declare const scoped: TokenPreservationSnapshotV2ScopedPublication;
declare const collectionSource: TokenPreservationSnapshotV2CollectionSource;
declare const scopedSource: TokenPreservationSnapshotV2ScopedSource;
declare const receipt: TokenPreservationSnapshotV2Receipt;
declare const lock: TokenPreservationSnapshotV2Lock;
declare const a: Address;
declare const h: Hex;

normalizeTokenPreservationSnapshotV2Coordinates(c);
normalizeTokenPreservationSnapshotV2Dependencies(d);
normalizeTokenPreservationSnapshotV2CollectionPublication(collection);
normalizeTokenPreservationSnapshotV2ScopedPublication(scoped);
const sourceA = decodeTokenPreservationSnapshotV2CollectionSource(encodeTokenPreservationSnapshotV2CollectionSource(collectionSource));
const sourceB = decodeTokenPreservationSnapshotV2ScopedSource(encodeTokenPreservationSnapshotV2ScopedSource(scopedSource));
normalizeTokenPreservationSnapshotV2CollectionSource(sourceA);
normalizeTokenPreservationSnapshotV2ScopedSource(sourceB);
const family: Hex = sourceA.rootBinding.preservationOutputProfile;
const factory: Address = sourceB.sourceFactory;
const retainedRevision: bigint = normalizeTokenPreservationSnapshotV2Receipt(receipt).grantRevision;
validateTokenPreservationSnapshotV2Scope("collection", scope);
validateTokenPreservationSnapshotV2Dependencies(c, d);
validateTokenPreservationSnapshotV2Publication("scoped", scoped, false);
validateTokenPreservationSnapshotV2Candidate("collection", collection, { timestamp: 10n, head: h, count: 1n, snapshotIdUsed: false, lock });
validateTokenPreservationSnapshotV2Source(c, d, collection, collectionSource);
const subject: Hex = tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, scope);
const sourceHash: Hex = tokenPreservationSnapshotV2SourceHash(c, d, scopedSource);
const rootHash: Hex = tokenPreservationSnapshotV2RootRecordHash(c.chainId, a, sourceA.root, sourceA.rootBinding);
const authority: TokenPreservationSnapshotV2Authority = { authorizationClass: 7n, grantRevision: 1n, displayAuthorizationClass: 8n, displayGrantRevision: 2n };
const preview = tokenPreservationSnapshotV2PreviewReceipt(c, scoped, a, authority, h);
const canonical: Hex = tokenPreservationSnapshotV2SnapshotBytes(c, d, scoped, preview, scopedSource);
const payload = decodeTokenPreservationSnapshotV2SnapshotBytes("scoped", canonical);
const recordHash: Hex = tokenPreservationSnapshotV2RecordHash(c, scoped, receipt);
const chainHash: Hex = tokenPreservationSnapshotV2ChainHash(c, scope, h, 1n, h);
const chunks = tokenPreservationSnapshotV2Chunks(canonical);
const chunkHash: Hex = chunks[0]!.hash;
const definitions = [...tokenPreservationSnapshotV2Definitions("collection"), ...tokenPreservationSnapshotV2RootDefinitions()];
const definitionKind: 0n | 1n | 2n = definitions[0]!.kind;
const history = authenticateTokenPreservationSnapshotV2History(c, d, collection, receipt, canonical, h);
const historicOnly: false = history.currentnessChecked;
const noAuthority: false = history.authorityChecked;

const request: TokenPreservationSnapshotV2Request = { kind: "publishSnapshot", publication: scoped };
const planned = normalizeTokenPreservationSnapshotV2Call(prepareTokenPreservationSnapshotV2Call(c, a, request));
const call: UnsignedCall = planned.call;
const verified: false = planned.factsVerified;
const safe = toSafeCall(call);
const operation: 0 = safe.operation;
const reads: readonly TokenPreservationSnapshotV2ReadRequest[] = [
  { kind: "previewSnapshot", publication: collection, publisher: a },
  { kind: "currentSnapshot", scope }, { kind: "snapshotCount", scope }, { kind: "snapshotLock", scope },
  { kind: "snapshotAt", scope, index: 0n }, { kind: "requireCurrent", scope, recordHash: h, revision: 1n },
  { kind: "snapshotRecord", recordHash: h }, { kind: "snapshotPayload", recordHash: h },
  { kind: "snapshotChunkCount", recordHash: h }, { kind: "snapshotChunkAt", recordHash: h, index: 0n },
  { kind: "dependencies" }, { kind: "core" }, { kind: "metadataHost" }, { kind: "authorityCodeHash" },
  { kind: "governanceAuthority" }, { kind: "preservationPolicySnapshotProfile" }, { kind: "scopedPreservationPolicySnapshotProfile" },
  { kind: "supportsInterface", interfaceId: "0x01ffc9a7" },
];
for (const request of reads) {
  const plan = normalizeTokenPreservationSnapshotV2Read(prepareTokenPreservationSnapshotV2Read(c, a, request));
  const output: UnsignedCall = plan.call;
  void output;
}

// @ts-expect-error immutable dependency array
d.targets[0] = a;
// @ts-expect-error immutable complete nested policy evidence
sourceB.entropy.policies[0]!.collectionPolicy.frozen = true;
// @ts-expect-error scoped source has no root
sourceB.root;
// @ts-expect-error collection source has no factory
sourceA.sourceFactory;
// @ts-expect-error collection publication requires actual prior root
const missingRoot: TokenPreservationSnapshotV2CollectionPublication = scoped;
// @ts-expect-error scope enum is closed
const badScope: TokenPreservationSnapshotV2Scope = { scopeType: 5n, collectionId: 1n, tokenId: 0n, scopeId: h };
// @ts-expect-error writer classes are original 7/8
const badAuthority: TokenPreservationSnapshotV2Authority = { ...authority, authorizationClass: 3n };
// @ts-expect-error locking is not an exposed mutation
const badRequest: TokenPreservationSnapshotV2Request = { kind: "lockSnapshot", publication: scoped };
// @ts-expect-error gas mutation is not an exposed read
const badRead: TokenPreservationSnapshotV2ReadRequest = { kind: "raiseGasParameter" };
// @ts-expect-error exact uint values use bigint
normalizeTokenPreservationSnapshotV2Coordinates({ ...c, chainId: 1 });
// @ts-expect-error immutable decoded payload
payload.publication.expectedSourceHash = h;
// @ts-expect-error immutable chunks
chunks.push(chunks[0]!);

void [family, factory, retainedRevision, subject, sourceHash, rootHash, recordHash, chainHash, chunkHash,
  definitionKind, historicOnly, noAuthority, verified, operation, missingRoot, badScope, badAuthority, badRequest, badRead];
