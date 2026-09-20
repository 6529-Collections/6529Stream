import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as root from "../src/current-scoped-policy-root-v2.js";

declare const coordinates: root.ScopedPolicyRootV2Coordinates;
declare const actor: Address;
declare const commitment: Hex;
declare const publication: root.ScopedPolicyRootV2Publication;
declare const record: root.ScopedPolicyRootV2Record;
declare const binding: root.ScopedPolicyRootV2Binding;
declare const aggregate: root.ScopedPolicyRootV2Aggregate;
declare const facts: root.ScopedPolicyRootV2PreparedRecordFacts;
declare const payload: root.ScopedPolicyRootV2ConsentPayload;

const write = root.prepareScopedPolicyRootV2Call(coordinates, actor, {
  kind: "publishScopedPolicyContentRootPublication", publication,
});
const consent = root.prepareScopedPolicyRootV2Call(coordinates, actor, {
  kind: "recordContentConsent", collectionId: 1n, newFamilyStateHash: commitment,
  signer: actor, authorityClass: 3n, authorization: { nonce: 0n, deadline: 1n, signature: "0x" },
});
const call: UnsignedCall = consent.call;
const unchecked: false = consent.factsVerified;
root.normalizeScopedPolicyRootV2Call(consent);
if (consent.request.kind === "recordContentConsent") {
  const nonce: bigint = consent.request.authorization.nonce;
  const class_: 1n | 3n = consent.request.authorityClass;
  // @ts-expect-error nested authorization is immutable
  consent.request.authorization.signature = "0x01";
  void nonce; void class_;
}
if (consent.consent) {
  const digest: Hex = consent.consent.payload.digest;
  const direct: boolean = consent.consent.direct;
  const domainTarget: string | null | undefined = consent.consent.payload.domain.verifyingContract;
  // @ts-expect-error signer observation is immutable
  consent.consent.signer = actor;
  void digest; void direct; void domainTarget;
}

const prepared = root.scopedPolicyRootV2PreparedRecord(coordinates, facts);
const immutable: false = prepared.factsVerified;
const projected: root.ScopedPolicyRootV2Binding = root.scopedPolicyRootV2BindingFromSnapshot(facts.dependencies, facts.source, facts.receipt);
const routeHash: Hex = root.scopedPolicyRootV2RouteHash(coordinates, facts.route);
const state: Hex = root.scopedPolicyRootV2StateHash(coordinates, record, binding);
const legacyState: Hex = root.scopedPolicyRootV2LegacyStateHash(coordinates, record);
const next = root.scopedPolicyRootV2NextAggregate(coordinates, aggregate, commitment, record);
const legacy = root.scopedPolicyRootV2EmptyLegacyFamily(coordinates, 1n);
const family: Hex = root.scopedPolicyRootV2FamilyHash(coordinates, 1n, legacy, next);
root.scopedPolicyRootV2RecordHash(coordinates, record, binding, aggregate);
root.scopedPolicyRootV2LegacyRecordHash(coordinates, record, aggregate);
const version: "v1" | "v2" = root.authenticateScopedPolicyRootV2History(coordinates, commitment, record, binding, aggregate);
const decoded: root.ScopedPolicyRootV2ConsentPayload = root.decodeScopedPolicyRootV2ConsentPayload(root.encodeScopedPolicyRootV2ConsentPayload(payload));
root.scopedPolicyRootV2ConsentRecordHash(coordinates, {
  terms: payload.terms, artistId: commitment, signer: actor, authorityClass: 1n, nonce: 0n, observedAt: 1n,
});
root.scopedPolicyRootV2ConsentEvidenceId(coordinates, actor, actor, commitment);

const read = root.prepareScopedPolicyRootV2Read(coordinates, actor, {
  kind: "previewScopedPolicyContentRootPublication", publication, publisher: actor,
});
root.normalizeScopedPolicyRootV2Read(read);
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "scopedContentRootHead", scope: publication.scope });
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "scopedPolicyContentRootBinding", recordHash: commitment });
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "scopedContentRootAggregate", collectionId: 1n });
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "contentConsentEvidenceForHost", collectionId: 1n, newFamilyStateHash: family });
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "firstReleaseRatification", collectionId: 1n });

// @ts-expect-error class4 authoring exists elsewhere but is not consumed by this closed root profile
root.prepareScopedPolicyRootV2Call(coordinates, actor, { kind: "recordContentConsent", collectionId: 1n, newFamilyStateHash: commitment, signer: actor, authorityClass: 4n, authorization: { nonce: 0n, deadline: 1n, signature: "0x" } });
// @ts-expect-error operation17 has no delegated grant variant here
root.prepareScopedPolicyRootV2Call(coordinates, actor, { kind: "recordDelegatedContentConsent", publication });
// @ts-expect-error no snapshot lock authority in this batch
root.prepareScopedPolicyRootV2Call(coordinates, actor, { kind: "lockSnapshot", scope: publication.scope });
// @ts-expect-error full width quantities use bigint
root.prepareScopedPolicyRootV2Call(coordinates, actor, { kind: "recordContentConsent", collectionId: 1, newFamilyStateHash: commitment, signer: actor, authorityClass: 1n, authorization: { nonce: 0n, deadline: 1n, signature: "0x" } });
// @ts-expect-error exact deadline is not a JavaScript number
root.normalizeScopedPolicyRootV2Authorization({ nonce: 0n, deadline: 1, signature: "0x" });
// @ts-expect-error no arbitrary library/current-source reader
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "requireCurrent", recordHash: commitment });
// @ts-expect-error writes are not read calls
root.prepareScopedPolicyRootV2Read(coordinates, actor, { kind: "publishScopedPolicyContentRootPublication", publication });
// @ts-expect-error immutable derived state
prepared.record.stateHash = commitment;
// @ts-expect-error no caller-supplied provenance assertion
prepared.factsVerified = true;
// @ts-expect-error caller is immutable
write.caller = actor;
// @ts-expect-error all six route pins are required
const incomplete: root.ScopedPolicyRootV2RouteFacts = { ...facts.route, codeHashes: [commitment] };
// @ts-expect-error decoded Archive constituent is immutable
decoded.proof.direct = true;
// @ts-expect-error publisher class is SNAPSHOT7/8, independent from Artist class1/3
root.scopedPolicyRootV2PreparedRecord(coordinates, { ...facts, authorizationClass: 1n });

void call; void unchecked; void immutable; void projected; void routeHash;
void state; void legacyState; void version; void incomplete;
