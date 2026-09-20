import type { Address, Hex, UnsignedCall } from "../src/index.js";
import * as bundle from "../src/current-scoped-policy-bundle-v2.js";

declare const coordinates: bundle.ScopedPolicyBundleV2Coordinates;
declare const caller: Address;
declare const id: Hex;
declare const scope: bundle.ScopedPolicyBundleV2Scope;
declare const dependencies: bundle.ScopedPolicyBundleV2Dependencies;
declare const item: bundle.ScopedPolicyBundleV2Item;
declare const proof: bundle.ScopedPolicyBundleV2Proof;
declare const admission: bundle.ScopedPolicyBundleV2Admission;
declare const progress: bundle.ScopedPolicyBundleV2Progress;
declare const segment: bundle.ScopedPolicyBundleV2Segment;
declare const inventory: bundle.ScopedPolicyBundleV2InventoryEvidence;
declare const evidence: bundle.ScopedPolicyBundleV2Evidence;
declare const artifact: bundle.ScopedPolicyBundleV2Artifact;
declare const object: bundle.ScopedPolicyBundleV2ObjectIdentity;
declare const pair: bundle.ScopedPolicyBundleV2CurrentPair;

const requests: readonly bundle.ScopedPolicyBundleV2Request[] = [
  { kind: "beginCoverage", id },
  { kind: "coverNext", id, item, nextLink: id, proof },
  { kind: "coverEmptySegment", id },
  { kind: "beginRefresh", id },
  { kind: "refreshNext", id, expectedIndex: 0n },
];
for (const request of requests) {
  const prepared = bundle.prepareScopedPolicyBundleV2Call(coordinates, caller, request);
  const call: UnsignedCall = prepared.call;
  const unverified: false = prepared.factsVerified;
  bundle.normalizeScopedPolicyBundleV2Call(prepared);
  if (prepared.request.kind === "coverNext") {
    const occurrence: bundle.ScopedPolicyBundleV2Item = prepared.request.item;
    const backend: bigint = prepared.request.proof.backend;
    bundle.validateScopedPolicyBundleV2Proof(occurrence, prepared.request.proof);
    bundle.validateScopedPolicyBundleV2NextItem(progress, segment, occurrence, prepared.request.nextLink);
    // @ts-expect-error the current proof does not rewrite the retained occurrence
    prepared.request.item.originalCoverageHash = id;
    // @ts-expect-error original archive backend is immutable
    prepared.request.proof.backend = 2n;
    void backend;
  }
  if (prepared.request.kind === "refreshNext") {
    const index: bigint = prepared.request.expectedIndex;
    void index;
  }
  // @ts-expect-error the literal caller is retained immutably
  prepared.caller = caller;
  // @ts-expect-error the transport is a fixed zero-value CALL
  prepared.call.value = 1n;
  void call; void unverified;
}

const dependencyHash: Hex = bundle.scopedPolicyBundleV2DependencyHash(dependencies);
const environment: Hex = bundle.scopedPolicyBundleV2EnvironmentHash(dependencies, id, 1n, id, 0n);
const refreshId: Hex = bundle.scopedPolicyBundleV2RefreshId(coordinates, dependencyHash, id, environment);
const coverageHash: Hex = bundle.scopedPolicyBundleV2CoverageHash(coordinates, dependencyHash, inventory, evidence);
bundle.validateScopedPolicyBundleV2Evidence(coordinates, dependencyHash, inventory, evidence);
bundle.validateScopedPolicyBundleV2Admission(id, item, admission);
bundle.validateScopedPolicyBundleV2EmptySegment(progress, segment);
bundle.scopedPolicyBundleV2IntrinsicAdmission(item, proof);
bundle.scopedPolicyBundleV2ItemChain(id, id, 0n, id, admission);
bundle.scopedPolicyBundleV2ObservationChain(id, 0n, id, id);
bundle.scopedPolicyBundleV2CurrentPairHash(admission.externalOriginal, pair);
bundle.scopedPolicyBundleV2ExternalOriginalHash(dependencies, admission.externalOriginal, [id, id, id, id, id]);
bundle.scopedPolicyBundleV2OnchainOriginalHash(dependencies, admission.onchainOriginal, artifact, id, id);
bundle.decodeScopedPolicyBundleV2Admission(bundle.encodeScopedPolicyBundleV2Admission(admission));
bundle.decodeScopedPolicyBundleV2ObjectIdentity(bundle.encodeScopedPolicyBundleV2ObjectIdentity(object));
bundle.decodeScopedPolicyBundleV2Artifact(bundle.encodeScopedPolicyBundleV2Artifact(artifact));
bundle.decodeScopedPolicyBundleV2CurrentPair(bundle.encodeScopedPolicyBundleV2CurrentPair(pair));

const read = bundle.prepareScopedPolicyBundleV2Read(coordinates, caller, { kind: "admittedItem", id, index: 0n });
bundle.normalizeScopedPolicyBundleV2Read(read);
bundle.prepareScopedPolicyBundleV2Read(coordinates, caller, { kind: "requireCoverage", scope, id, expectedHash: id });
bundle.prepareScopedPolicyBundleV2Read(coordinates, caller, { kind: "requireFullCurrentCoverage", id });
bundle.prepareScopedPolicyBundleV2Read(coordinates, caller, { kind: "refresh", key: refreshId });

// @ts-expect-error refresh cursor is exact uint64 represented as bigint
bundle.prepareScopedPolicyBundleV2Call(coordinates, caller, { kind: "refreshNext", id, expectedIndex: 0 });
// @ts-expect-error coverage requires the next occurrence's original Proof
bundle.prepareScopedPolicyBundleV2Call(coordinates, caller, { kind: "coverNext", id, item, nextLink: id });
// @ts-expect-error a supplied Admission is not a replacement for actual archive proof admission
bundle.prepareScopedPolicyBundleV2Call(coordinates, caller, { kind: "coverNext", id, item, nextLink: id, proof, admission });
// @ts-expect-error no gas/governance authority shortcut
bundle.prepareScopedPolicyBundleV2Call(coordinates, caller, { kind: "raiseGasParameter", value: 1n });
// @ts-expect-error original native value is not configurable
bundle.prepareScopedPolicyBundleV2Call(coordinates, caller, { kind: "beginCoverage", id, value: 1n });
// @ts-expect-error public observation cursor is bigint
bundle.prepareScopedPolicyBundleV2Read(coordinates, caller, { kind: "admittedItem", id, index: 1 });
// @ts-expect-error bundle host does not expose the inventory's segment getter
bundle.prepareScopedPolicyBundleV2Read(coordinates, caller, { kind: "inventorySegment", id, index: 0n });
// @ts-expect-error dependency pins are a fixed six-entry tuple
const invalidDependencies: bundle.ScopedPolicyBundleV2Dependencies = { ...dependencies, codeHashes: [id] };
// @ts-expect-error fixed runtime pins are readonly
dependencies.codeHashes[0] = id;
// @ts-expect-error source progress completion is a boolean, not an integer
const invalidProgress: bundle.ScopedPolicyBundleV2Progress = { ...progress, complete: 1n };
// @ts-expect-error artifact chunk order cannot be rewritten
artifact.chunkHashes.reverse();
// @ts-expect-error refreshed fixity observations do not mutate retained receipt identities
admission.externalOriginal.firstReceiptHash = id;
// @ts-expect-error structural helpers never assert live authority or complete archival coverage
const invalidVerification: true = read.factsVerified;
// @ts-expect-error exact coordinates have no arbitrary archive target override
bundle.normalizeScopedPolicyBundleV2Coordinates({ ...coordinates, archive: caller });

void coverageHash; void invalidDependencies; void invalidProgress; void invalidVerification;
