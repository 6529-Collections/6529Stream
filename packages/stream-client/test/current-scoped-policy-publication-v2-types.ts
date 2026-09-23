import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as p from "../src/current-scoped-policy-publication-v2.js";

declare const coordinates: p.ScopedPolicyPublicationV2Coordinates;
declare const caller: Address;
declare const commitment: Hex;
declare const scope: p.ScopedPolicyPublicationV2Scope;
declare const identity: p.ScopedPolicyPublicationV2CheckpointIdentity;
declare const content: p.ScopedPolicyPublicationV2ContentPlan;
declare const publication: p.ScopedPolicyPublicationV2Publication;
declare const source: p.ScopedPolicyPublicationV2Source;
declare const dependencies: p.ScopedPolicyPublicationV2Dependencies;
declare const receipt: p.ScopedPolicyPublicationV2Receipt;
declare const output: p.ScopedPolicyPublicationV2Output;
declare const coverage: p.ScopedPolicyPublicationV2Coverage;

const prepared = p.prepareScopedPolicyPublicationV2Call(coordinates, caller, {
  kind: "append", id: commitment, payloads: [{ tokenId: 1n, image: "0x", animation: "0x01" }],
});
const call: UnsignedCall = prepared.call;
const unchecked: false = prepared.factsVerified;
const rebuilt: p.ScopedPolicyPublicationV2Call = p.normalizeScopedPolicyPublicationV2Call(prepared);
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "begin", selectionId: commitment, salt: commitment });
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "beginManifest", checkpointHash: commitment,
  artifactHash: commitment, coverageHash: commitment, artistId: commitment });
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "verifyNextOutputs", planHash: commitment, count: 16n });
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "publishSnapshot", publication });
if (rebuilt.request.kind === "append") {
  const token: bigint = rebuilt.request.payloads[0]!.tokenId;
  const bytes: Hex = rebuilt.request.payloads[0]!.animation;
  void token; void bytes;
  // @ts-expect-error nested call snapshots are readonly
  rebuilt.request.payloads.push({ tokenId: 2n, image: "0x", animation: "0x01" });
  // @ts-expect-error nested original fields are readonly
  rebuilt.request.payloads[0]!.tokenId = 2n;
}
const sourceHash: Hex = p.scopedPolicyPublicationV2SourceHash(coordinates, dependencies, source);
const checked: p.ScopedPolicyPublicationV2Source = p.validateScopedPolicyPublicationV2Source(coordinates, dependencies, publication, source);
const checkpoint: Hex = p.scopedPolicyPublicationV2CheckpointId(coordinates, identity);
const initial: p.ScopedPolicyPublicationV2ContentPlan = p.scopedPolicyPublicationV2InitialContentPlan(identity);
const leaf: Hex = p.scopedPolicyPublicationV2LeafHash(coordinates.chainId, coordinates.core, output.leaf);
p.scopedPolicyPublicationV2ContentRoot(coordinates.chainId, coordinates.core, [output.leaf]);
p.scopedPolicyPublicationV2LeafChain(commitment, 0n, leaf);
p.scopedPolicyPublicationV2OutputChain(commitment, 0n, output);
const manifest: p.ScopedPolicyPublicationV2Manifest = p.scopedPolicyPublicationV2Manifest(coordinates, checkpoint, content, caller, coverage);
const plan: Hex = p.scopedPolicyPublicationV2ManifestPlanHash(coordinates, caller, manifest);
p.scopedPolicyPublicationV2ManifestRecordHash(plan);
const archive: Hex = p.scopedPolicyPublicationV2OutputManifestBytes(coordinates, checkpoint, content, caller, [output]);
const decodedArchive: p.ScopedPolicyPublicationV2OutputManifestBytes = p.decodeScopedPolicyPublicationV2OutputManifestBytes(archive);
const canonical: Hex = p.scopedPolicyPublicationV2SnapshotBytes(coordinates, dependencies, publication, receipt, source);
const decoded: p.ScopedPolicyPublicationV2SnapshotPayload = p.decodeScopedPolicyPublicationV2SnapshotBytes(canonical);
const count: bigint = decoded.source.entropy.policyCount;
p.scopedPolicyPublicationV2SnapshotRecordHash(coordinates, publication, receipt);
p.scopedPolicyPublicationV2SnapshotChainHash(coordinates, scope, commitment, 1n, commitment);
const preview = p.scopedPolicyPublicationV2PreviewReceipt(coordinates, publication, caller, {
  authorizationClass: 7n, grantRevision: 2n, displayAuthorizationClass: 8n, displayGrantRevision: 3n,
}, sourceHash);
const chunks: readonly p.ScopedPolicyPublicationV2Chunk[] = p.scopedPolicyPublicationV2Chunks(canonical);

const read = p.prepareScopedPolicyPublicationV2Read(coordinates, caller, {
  host: "snapshot", kind: "previewSnapshot", publication, publisher: caller,
});
p.normalizeScopedPolicyPublicationV2Read(read);
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "checkpoint", kind: "outputAt", id: commitment, index: 1n });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "checkpoint", kind: "requireCurrentCheckpoint", id: commitment });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "output", kind: "manifestPlan", planHash: commitment });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "output", kind: "requireCurrentManifest", recordHash: commitment, artistId: commitment });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "dependencies" });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "snapshotAt", scope, index: 3n });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "snapshotRecord", hash: commitment });
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "requireCurrent", scope, hash: commitment, revision: 1n });

// @ts-expect-error no governance lock write in this profile
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "lockSnapshot", scope });
// @ts-expect-error no arbitrary gas mutation
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "raiseGasParameter", parameterId: commitment, value: 1n });
// @ts-expect-error numbers are not exact uint256 counters
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "verifyNextOutputs", planHash: commitment, count: 1 });
// @ts-expect-error per-token uint256 must be bigint
p.prepareScopedPolicyPublicationV2Call(coordinates, caller, { kind: "append", id: commitment, payloads: [{ tokenId: 1, image: "0x", animation: "0x01" }] });
// @ts-expect-error host and method cannot be interchanged
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "manifestRecord", recordHash: commitment });
// @ts-expect-error a publication mutation is not a read
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "publishSnapshot", publication });
// @ts-expect-error exact scope revision width represented by bigint
p.prepareScopedPolicyPublicationV2Read(coordinates, caller, { host: "snapshot", kind: "requireCurrent", scope, hash: commitment, revision: 1 });
// @ts-expect-error wrong authority family class
p.scopedPolicyPublicationV2PreviewReceipt(coordinates, publication, caller, { authorizationClass: 1n, grantRevision: 1n, displayAuthorizationClass: 8n, displayGrantRevision: 1n }, sourceHash);
// @ts-expect-error no caller-supplied provenance flag
prepared.factsVerified = true;
// @ts-expect-error immutable source policy inventory
decoded.source.entropy.policies.push(source.entropy.policies[0]!);
// @ts-expect-error fixed complete eleven-target dependencies
const incomplete: p.ScopedPolicyPublicationV2Dependencies = { ...dependencies, targets: [caller] };
// @ts-expect-error output arrays are immutable
decodedArchive.rows[0] = output;
// @ts-expect-error prepared caller cannot be changed in place
prepared.caller = caller;
// @ts-expect-error immutable Store chunk facts
chunks[0]!.runtime = "0x";

void call; void unchecked; void checked; void initial; void count; void preview; void incomplete;
