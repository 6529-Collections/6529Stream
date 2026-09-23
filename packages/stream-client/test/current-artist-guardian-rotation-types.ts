import * as p from "../src/current-artist-guardian-rotation.js";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";

declare const registry: Address, caller: Address, hash: Hex;
declare const terms: p.ArtistRotationTerms, guardians: p.ArtistGuardianSet, authorization: p.ArtistRotationAuthorization;
declare const transition: p.ArtistRotationTransition, record: p.ArtistRotationRecord, guardianRecord: p.ArtistGuardianRecord;
const base = { chainId: 1n, registry, caller };
const requests: readonly p.GuardianRotationRequest[] = [
  { ...base, kind: "setGuardians", terms: guardians, authorization },
  { ...base, kind: "stageRotation", terms, oldAuthorization: authorization, newAuthorization: authorization },
  { ...base, kind: "approveRotation", artistId: hash, expectedRotationRecordHash: hash },
  { ...base, kind: "vetoRotation", artistId: hash, expectedRotationRecordHash: hash, reasonHash: hash },
  { ...base, kind: "executeRotation", artistId: hash, expectedRotationRecordHash: hash },
];
for (const request of requests) {
  const prepared: p.PreparedGuardianRotation = p.prepareGuardianRotationCall(request);
  const operation: 28 | 29 | 30 | 31 | 32 = prepared.operation, unverified: false = prepared.factsVerified;
  const call: UnsignedCall = prepared.call;
  p.normalizeGuardianRotationCall(prepared);
  for (const signing of prepared.signing) {
    const kind: 1 | 4 = signing.nonceLane.kind, side: "principal" | "acceptance" = signing.side;
    const signer: Address | undefined = signing.signer, digestCall: UnsignedCall = signing.digestCall;
    void kind; void side; void signer; void digestCall;
  }
  void operation; void unverified; void call;
}
const gm: p.ArtistGuardianSetMessage = p.guardianRotationTypedData("guardianSet", 1n, registry, guardians, authorization).message;
const rm: p.ArtistRotationMessage = p.guardianRotationTypedData("rotation", 1n, registry, terms, authorization).message;
const am: p.ArtistRotationAcceptanceMessage = p.guardianRotationTypedData("rotationAcceptance", 1n, registry, terms, authorization).message;
const digest: Hex = p.guardianRotationDigest("rotation", 1n, registry, terms, authorization);
p.artistGuardianRecordHash(1n, registry, guardians, authorization.nonce, 1n);
p.artistRotationRecordHash(1n, registry, terms, authorization.nonce, 1n, 2n);
p.rotationAcceptanceLane(hash, caller);
p.normalizeArtistGuardianSet(guardians); p.normalizeArtistRotationTerms(terms); p.normalizeArtistRotationAuthorization(authorization);
const guardian: p.GuardianRotationReads["guardianSet"]["result"] = p.decodeGuardianRotationRead("guardianSet", hash);
const pending: p.GuardianRotationReads["pendingRotation"]["result"] = p.decodeGuardianRotationRead("pendingRotation", hash);
const gr: p.ArtistGuardianRecord = p.decodeGuardianRotationRead("guardianSetRecord", hash);
const rr: p.ArtistRotationRecord = p.decodeGuardianRotationRead("rotationRecord", hash);
const tr: p.ArtistRotationTransition = p.decodeGuardianRotationRead("artistTransitionState", hash);
const last: Hex = p.decodeGuardianRotationRead("lastArtistTransition", hash);
const window: p.GuardianRotationReads["activeAuthorityWindow"]["result"] = p.decodeGuardianRotationRead("activeAuthorityWindow", hash);
const nonce: p.GuardianRotationReads["rotationAcceptanceNonceState"]["result"] = p.decodeGuardianRotationRead("rotationAcceptanceNonceState", hash);
p.prepareGuardianRotationRead(registry, "guardianSet", [hash]);
p.prepareGuardianRotationRead(registry, "rotationAcceptanceNonceState", [hash, caller, 1n]);
void gm; void rm; void am; void digest; void guardian; void pending; void gr; void rr; void tr; void last; void window; void nonce;

// @ts-expect-error original nonce remains uint256 bigint
p.normalizeArtistRotationAuthorization({ ...authorization, nonce: 1 });
// @ts-expect-error authorization has time, not a deadline alias
p.normalizeArtistRotationAuthorization({ nonce: 1n, deadline: 1n, signature: hash });
// @ts-expect-error guardian threshold remains bigint
p.normalizeArtistGuardianSet({ ...guardians, approvalThreshold: 1 });
// @ts-expect-error concurrency guard is required calldata even though excluded from signatures
p.normalizeArtistRotationTerms({ artistId: hash, oldAddress: caller, newAddress: registry, reasonHash: hash });
// @ts-expect-error two independent authorizations are required
p.prepareGuardianRotationCall({ ...base, kind: "stageRotation", terms, authorization });
// @ts-expect-error veto requires reasonHash
p.prepareGuardianRotationCall({ ...base, kind: "vetoRotation", artistId: hash, expectedRotationRecordHash: hash });
// @ts-expect-error approval is not a signing operation
p.prepareGuardianRotationCall({ ...base, kind: "approveRotation", artistId: hash, expectedRotationRecordHash: hash, authorization });
// @ts-expect-error recovery is a distinct capability
p.prepareGuardianRotationCall({ ...base, kind: "recoverArtistIdentity", terms, authorization });
// @ts-expect-error guardian typed data does not accept rotation terms
p.guardianRotationTypedData("guardianSet", 1n, registry, terms, authorization);
// @ts-expect-error rotation typed data does not accept guardian terms
p.guardianRotationTypedData("rotation", 1n, registry, guardians, authorization);
// @ts-expect-error approval has no third signing schema
p.guardianRotationTypedData("approveRotation", 1n, registry, terms, authorization);
// @ts-expect-error no reason in new-address acceptance message
const reason: Hex = am.reasonHash;
// @ts-expect-error no concurrency guard in principal signed message
const guard: Hex = rm.expectedPreviousTransitionRecordHash;
// @ts-expect-error digest getters are separate prepared signing reads
p.prepareGuardianRotationRead(registry, "rotationDigest", [terms, authorization]);
// @ts-expect-error acceptance lane read needs new address and nonce
p.prepareGuardianRotationRead(registry, "rotationAcceptanceNonceState", [hash]);
// @ts-expect-error uint256 read nonce remains bigint
p.prepareGuardianRotationRead(registry, "rotationAcceptanceNonceState", [hash, caller, 1]);
// @ts-expect-error scalar read accepts exactly one argument
p.prepareGuardianRotationRead(registry, "guardianSet", [hash, hash]);
// @ts-expect-error guardian set cannot be mutated
guardians.guardians.push(caller);
// @ts-expect-error immutable full original transition
transition.phase = 3n;
// @ts-expect-error immutable nested original record
record.terms.reasonHash = hash;
// @ts-expect-error immutable original guardian association
guardianRecord.provisional.windowEndsAt = 1n;
// @ts-expect-error preparation never certifies supplied authority facts
const verified: true = p.prepareGuardianRotationCall(requests[0]!).factsVerified;
void reason; void guard; void verified;
