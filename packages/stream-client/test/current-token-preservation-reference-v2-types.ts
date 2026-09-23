import type { Address, Hex } from "../src/generated/contracts.js";
import * as reference from "../src/current-token-preservation-reference-v2.js";
import type { TokenPreservationSnapshotV2Dependencies } from "../src/current-token-preservation-snapshot-v2.js";
import { toSafeCall } from "../src/safe.js";

declare const actor: Address;
declare const hash: Hex;
declare const coordinates: reference.TokenPreservationReferenceV2Coordinates;
declare const dependencies: reference.TokenPreservationReferenceV2Dependencies;
declare const publication: reference.TokenPreservationReferenceV2Publication;
declare const receipt: reference.TokenPreservationReferenceV2Receipt;
declare const environment: reference.TokenPreservationReferenceV2Environment;
declare const rows: readonly reference.TokenPreservationReferenceV2PackageFile[];
declare const collection: reference.TokenPreservationReferenceV2CollectionSource;
declare const scoped: reference.TokenPreservationReferenceV2ScopedSource;
declare const snapshotDependencies: TokenPreservationSnapshotV2Dependencies;

const scopes: readonly reference.TokenPreservationReferenceV2ScopeKind[] = ["collection", "scoped"];
const requests: readonly reference.TokenPreservationReferenceV2Request[] = [
  { kind: "prepareEnvironment", environment },
  { kind: "prepareFileInventory", rows, relative: true },
  { kind: "prepareFileInventoryPart", rows, relative: false },
  { kind: "prepareFileInventoryFromParts", rows, relative: true },
  { kind: "publishReference", publication },
];
for (const request of requests) {
  const plan: reference.TokenPreservationReferenceV2Call = reference.prepareTokenPreservationReferenceV2Call(coordinates, actor, request);
  const rebuilt: reference.TokenPreservationReferenceV2Call = reference.normalizeTokenPreservationReferenceV2Call(plan);
  const safe = toSafeCall(rebuilt.call);
  const actual: false = plan.factsVerified;
  void [safe, actual];
}
for (const scopeKind of scopes) {
  const source: reference.TokenPreservationReferenceV2Source = scopeKind === "collection" ? collection : scoped;
  const raw: Hex = reference.encodeTokenPreservationReferenceV2Source(scopeKind, source);
  const decoded: reference.TokenPreservationReferenceV2SourceFacts = reference.decodeTokenPreservationReferenceV2Source(scopeKind, raw);
  reference.validateTokenPreservationReferenceV2Source({ ...coordinates, scopeKind }, dependencies, publication, decoded, snapshotDependencies);
  const definition: readonly reference.TokenPreservationReferenceV2Definition[] = reference.tokenPreservationReferenceV2Definitions(scopeKind);
  const payload: reference.TokenPreservationReferenceV2Payload = reference.decodeTokenPreservationReferenceV2ReferenceBytes(scopeKind, raw);
  void [definition, payload];
}
const authority: reference.TokenPreservationReferenceV2Authority = { authorizationClass: 3n, grantRevision: 7n };
const preview: reference.TokenPreservationReferenceV2Receipt = reference.tokenPreservationReferenceV2PreviewReceipt(coordinates, publication, actor, authority, hash);
const bytes: Hex = reference.tokenPreservationReferenceV2ReferenceBytes(coordinates, dependencies, publication, preview, collection, hash);
const record: Hex = reference.tokenPreservationReferenceV2RecordHash(coordinates, publication, receipt);
const chain: Hex = reference.tokenPreservationReferenceV2ChainHash(coordinates, publication.scope, hash, 3n, record);
reference.authenticateTokenPreservationReferenceV2History(coordinates, dependencies, publication, receipt, bytes, chain);
reference.tokenPreservationReferenceV2Chunks(bytes);
reference.validateTokenPreservationReferenceV2Candidate("collection", publication, {
  timestamp: 10n, head: hash, count: 4n, referenceIdUsed: false,
  lock: { recordHash: hash, revision: 1n, actionId: hash, lockedAt: 1n },
}, "preview");
const binding: reference.TokenPreservationReferenceV2ScopedRootBinding = reference.tokenPreservationReferenceV2ScopedRootBindingFromSnapshot(snapshotDependencies, scoped.snapshotSource, scoped.snapshot);
reference.tokenPreservationReferenceV2ScopedRootStateHash(coordinates.chainId, actor, coordinates.core, scoped.contentRoot, binding);

const reads: readonly reference.TokenPreservationReferenceV2ReadRequest[] = [
  { kind: "dependencies" }, { kind: "core" }, { kind: "metadataHost" }, { kind: "metadataRouter" },
  { kind: "snapshots" }, { kind: "archiveCoverage" }, { kind: "deploymentChainId" },
  { kind: "preservationPolicyReferenceProfile" }, { kind: "scopedPreservationPolicyReferenceProfile" },
  { kind: "supportsInterface", interfaceId: hash },
  { kind: "preparedFileInventory", id: hash },
  { kind: "referenceRecord", hash }, { kind: "referencePayload", hash }, { kind: "referenceSource", hash },
  { kind: "currentReference", scope: publication.scope }, { kind: "referenceCount", scope: publication.scope },
  { kind: "referenceLock", scope: publication.scope }, { kind: "referenceAt", scope: publication.scope, index: 0n },
  { kind: "requireCurrent", scope: publication.scope, hash, revision: 1n },
  { kind: "referenceChunkCount", hash }, { kind: "referenceChunkAt", hash, index: 0n },
  { kind: "previewReference", publication, recorder: actor },
];
for (const request of reads) reference.normalizeTokenPreservationReferenceV2Read(reference.prepareTokenPreservationReferenceV2Read(coordinates, actor, request));

// @ts-expect-error Governance lock is outside this five-write caller family.
const forbidden: reference.TokenPreservationReferenceV2Request = { kind: "lockReference", scope: publication.scope };
// @ts-expect-error VIEW is not a selectable host family.
const view: reference.TokenPreservationReferenceV2ScopeKind = "view";
// @ts-expect-error Reference uses CURATOR 3/8, not SNAPSHOT 7.
const wrongGrant: reference.TokenPreservationReferenceV2Authority = { authorizationClass: 7n, grantRevision: 1n };
// @ts-expect-error Original widths are bigint inputs.
const wrongWidth: reference.TokenPreservationReferenceV2PackageFile = { path: "file", byteSize: 1, sha256Digest: hash };
// @ts-expect-error Every seven-host pin slot is required.
const wrongRoster: reference.TokenPreservationReferenceV2Dependencies = { ...dependencies, targets: [actor] };
// @ts-expect-error Nested inputs are readonly.
publication.observation.captures[0]!.capturedAt = 0n;
// @ts-expect-error Root companion has the immutable preservation family field.
binding.preservationOutputProfile = hash;
// @ts-expect-error Source facts are detached readonly arrays.
scoped.samples.push(scoped.samples[0]!);
// @ts-expect-error Generic gas mutation cannot enter finite reads.
const wrongRead: reference.TokenPreservationReferenceV2ReadRequest = { kind: "raiseGasParameter", field: 1n, value: 2n };
void [forbidden, view, wrongGrant, wrongWidth, wrongRoster, wrongRead];
