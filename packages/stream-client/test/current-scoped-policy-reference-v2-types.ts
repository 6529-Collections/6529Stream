import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import type { ScopedPolicyGraphV2SnapshotDependencies } from "../src/current-scoped-policy-graph-v2.js";
import * as ref from "../src/current-scoped-policy-reference-v2.js";

declare const coordinates: ref.ScopedPolicyReferenceV2Coordinates;
declare const actor: Address;
declare const commitment: Hex;
declare const publication: ref.ScopedPolicyReferenceV2Publication;
declare const receipt: ref.ScopedPolicyReferenceV2Receipt;
declare const source: ref.ScopedPolicyReferenceV2SourceFacts;
declare const dependencies: ref.ScopedPolicyReferenceV2Dependencies;
declare const snapshotDependencies: ScopedPolicyGraphV2SnapshotDependencies;
declare const environment: ref.ScopedPolicyReferenceV2Environment;
declare const rows: readonly ref.ScopedPolicyReferenceV2PackageFile[];
declare const bytes: Hex;

const kinds = ["prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts"] as const;
for (const kind of kinds) {
  const plan = ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind, rows, relative: true });
  const call: UnsignedCall = plan.call;
  const unverified: false = plan.factsVerified;
  ref.normalizeScopedPolicyReferenceV2Call(plan);
  if (plan.preparation) {
    const id: Hex = plan.preparation.id;
    const length: bigint = plan.preparation.byteLength;
    // @ts-expect-error preparation is detached readonly data
    plan.preparation.contentHash = commitment;
    void id; void length;
  }
  if (plan.request.kind === "prepareFileInventory") {
    const relative: boolean = plan.request.relative;
    // @ts-expect-error rows cannot be appended after planning
    plan.request.rows.push(rows[0]!);
    void relative;
  }
  void call; void unverified;
}

ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind: "prepareEnvironment", environment });
const publish = ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind: "publishReference", publication });
if (publish.request.kind === "publishReference") {
  const time: bigint = publish.request.publication.observation.effectiveAt;
  const capture: ref.ScopedPolicyReferenceV2Capture = publish.request.publication.observation.captures[0]!;
  // @ts-expect-error captured screenshot fields cannot be rewritten
  capture.repeatCaptureSha256[0] = commitment;
  // @ts-expect-error full environment inventories are immutable
  publish.request.publication.observation.environment.packageFiles[0]!.byteSize = 1n;
  void time;
}

const validated = ref.validateScopedPolicyReferenceV2Source(coordinates, dependencies, publication, source, snapshotDependencies);
const hash: Hex = ref.scopedPolicyReferenceV2SourceHash(coordinates, dependencies, validated);
const preview: ref.ScopedPolicyReferenceV2Receipt = ref.scopedPolicyReferenceV2PreviewReceipt(
  coordinates, publication, actor, { authorizationClass: 3n, grantRevision: 1n }, hash,
);
ref.scopedPolicyReferenceV2PreviewReceipt(coordinates, publication, actor, { authorizationClass: 8n, grantRevision: 1n }, hash);
const payloadBytes: Hex = ref.scopedPolicyReferenceV2PayloadBytes(coordinates, publication, preview, source, bytes);
const decoded: ref.ScopedPolicyReferenceV2Payload = ref.decodeScopedPolicyReferenceV2Payload(payloadBytes);
const original: ref.ScopedPolicyReferenceV2Publication = decoded.publication;
ref.scopedPolicyReferenceV2RecordHash(coordinates, original, receipt);
ref.scopedPolicyReferenceV2ChainHash(coordinates, publication.scope, commitment, 2n, commitment);
ref.authenticateScopedPolicyReferenceV2History(coordinates, dependencies, publication, receipt, payloadBytes, commitment);
ref.decodeScopedPolicyReferenceV2Dependencies(ref.encodeScopedPolicyReferenceV2Dependencies(dependencies));
ref.decodeScopedPolicyReferenceV2SourceFacts(ref.encodeScopedPolicyReferenceV2SourceFacts(source));
ref.decodeScopedPolicyReferenceV2Publication(ref.encodeScopedPolicyReferenceV2Publication(publication));
ref.decodeScopedPolicyReferenceV2Receipt(ref.encodeScopedPolicyReferenceV2Receipt(receipt));

const read = ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, {
  kind: "previewReference", publication, recorder: actor,
});
ref.normalizeScopedPolicyReferenceV2Read(read);
ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, { kind: "currentReference", scope: publication.scope });
ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, { kind: "referenceSource", hash: commitment });
ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, { kind: "referenceAt", scope: publication.scope, index: 1n });
ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, { kind: "requireCurrent", scope: publication.scope, hash: commitment, revision: 1n });
const document: ref.ScopedPolicyReferenceV2Document = ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS[0]!;
const documentLength: bigint = document.byteLength;
const chunkRuntime: Hex = ref.scopedPolicyReferenceV2Chunks(payloadBytes)[0]!.runtime;

// @ts-expect-error no governed lock mutation in this permissionless preparation/publication profile
ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind: "lockReference", scope: publication.scope });
// @ts-expect-error no gas-raise authority shortcut
ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind: "raiseGasParameter", value: 1n });
// @ts-expect-error native value is not a user-selectable input for these nonpayable calls
ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind: "publishReference", publication, value: 1n });
// @ts-expect-error collection SNAPSHOT class7 does not grant reference CURATOR authority
ref.scopedPolicyReferenceV2PreviewReceipt(coordinates, publication, actor, { authorizationClass: 7n, grantRevision: 1n }, commitment);
// @ts-expect-error revisions are exact bigints
ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, { kind: "requireCurrent", scope: publication.scope, hash: commitment, revision: 1 });
// @ts-expect-error no fabricated current-pair endpoint on the reference host
ref.prepareScopedPolicyReferenceV2Read(coordinates, actor, { kind: "currentReceiptPair", hash: commitment });
// @ts-expect-error array assembly takes full original rows, never arbitrary part IDs
ref.prepareScopedPolicyReferenceV2Call(coordinates, actor, { kind: "prepareFileInventoryFromParts", partIds: [commitment], relative: true });
// @ts-expect-error dependency arrays are fixed width
const invalidDependencies: ref.ScopedPolicyReferenceV2Dependencies = { ...dependencies, targets: [actor] };
// @ts-expect-error source capture order is immutable
source.samples.reverse();
// @ts-expect-error raw source widths are retained bigint values
const invalidCapture: ref.ScopedPolicyReferenceV2Capture = { ...publication.observation.captures[0]!, htmlBytes: 12 };
// @ts-expect-error no extra provider or writer in the exact call coordinates
ref.normalizeScopedPolicyReferenceV2Coordinates({ ...coordinates, provider: actor });
// @ts-expect-error document constants are immutable
document.byteLength = 0n;

void documentLength; void chunkRuntime; void invalidDependencies; void invalidCapture;
