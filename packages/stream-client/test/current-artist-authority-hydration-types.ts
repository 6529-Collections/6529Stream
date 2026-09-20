import type { Address, Hex } from "../src/generated/contracts.js";
import {
  ARTIST_HYDRATION_PROFILES, normalizeArtistHydrationSnapshot, normalizeArtistHydrationCheckpoint, normalizeArtistHydrationSuite,
  normalizeArtistHydrationNativeReceipt, normalizeArtistHydrationNonceWord, normalizeArtistHydrationQuery, normalizeArtistHydrationOwnerData,
  normalizeArtistAuthorityHydrationRequest, prepareArtistAuthorityHydrationCall, normalizeArtistAuthorityHydrationCall,
  encodeArtistHydrationIdentity, decodeArtistHydrationIdentity, encodeArtistHydrationOwnerState, decodeArtistHydrationOwnerState,
  encodeArtistHydrationMultipleBundle, decodeArtistHydrationMultipleBundle, artistAuthorityHydrationBaseRequest,
  artistAuthorityHydrationCommitment, artistAuthorityHydrationReplayKey, artistAuthorityHydrationReplayDelta,
  artistAuthorityHydrationOwnerAfter, artistAuthorityHydrationEvidenceId, encodeArtistAuthorityHydrationProfileEvidence,
  decodeArtistAuthorityHydrationProfileEvidence, encodeArtistAuthorityHydrationEvidence, decodeArtistAuthorityHydrationEvidence,
  type ArtistHydrationSnapshot, type ArtistHydrationCheckpoint, type ArtistHydrationSuite, type ArtistHydrationQuery,
  type ArtistHydrationOwnerData, type ArtistHydrationNonceWord, type ArtistSingleHydrationRequest, type ArtistMultipleHydrationRequest,
  type ArtistHydrationIdentity, type ArtistHydrationBinding, type ArtistHydrationDelegationIdentity, type ArtistHydrationDelegationConsent,
  type ArtistHydrationMultipleBundle, type ArtistAuthorityHydrationCoordinates, type ArtistHydrationOwnerEnvironment,
  type ArtistAuthorityHydrationRequest, type ArtistAuthorityHydrationCall, type ArtistHydrationSeven,
  type ArtistAuthorityHydrationEvidence, type ArtistAuthorityHydrationProfileEvidence
} from "../src/current-artist-authority-hydration.js";

declare const actor: Address, bytes: Hex;
declare const coordinates: ArtistAuthorityHydrationCoordinates, env: ArtistHydrationOwnerEnvironment;
declare const single: ArtistSingleHydrationRequest, multiple: ArtistMultipleHydrationRequest;
declare const state: ArtistHydrationIdentity, binding: ArtistHydrationBinding;
declare const delegation: ArtistHydrationDelegationIdentity, consents: ArtistHydrationDelegationConsent;
declare const rows: ArtistHydrationMultipleBundle;
declare const query: ArtistHydrationQuery, data: ArtistHydrationOwnerData;
declare const ownerData: ArtistHydrationSeven<ArtistHydrationOwnerData>, before: ArtistHydrationSeven<ArtistHydrationSnapshot>;
declare const checkpoint: ArtistHydrationCheckpoint, suite: ArtistHydrationSuite, word: ArtistHydrationNonceWord;
normalizeArtistHydrationSnapshot(before[0]); normalizeArtistHydrationCheckpoint(checkpoint); normalizeArtistHydrationSuite(suite);
normalizeArtistHydrationNativeReceipt({ operation: 60n, artistId: bytes, collectionId: (1n << 230n) + 1n, recordHash: bytes });
normalizeArtistHydrationNonceWord(word); normalizeArtistHydrationQuery(query); normalizeArtistHydrationOwnerData(data);
const requests: readonly ArtistAuthorityHydrationRequest[] = [
  { kind: "baseline", request: single }, { kind: "delegation", request: single }, { kind: "multiple", request: multiple }
];
for (const input of requests) {
  const normalized: ArtistAuthorityHydrationRequest = normalizeArtistAuthorityHydrationRequest(input);
  const call: ArtistAuthorityHydrationCall = prepareArtistAuthorityHydrationCall(coordinates.registry, actor, normalized);
  const rebuilt: ArtistAuthorityHydrationCall = normalizeArtistAuthorityHydrationCall(call);
  const suppliedFacts: false = rebuilt.factsVerified;
  const selectedProfile: Hex = rebuilt.profile, selector: Hex = rebuilt.capabilityId;
  const actualCaller: Address = rebuilt.caller;
  const base: ArtistSingleHydrationRequest = artistAuthorityHydrationBaseRequest(input);
  const commitment: Hex = artistAuthorityHydrationCommitment(coordinates, input, query, ownerData);
  const evidenceId: Hex = artistAuthorityHydrationEvidenceId(coordinates, actor, commitment);
  // @ts-expect-error The prepared call has no fresh Artist signature or signing domain.
  rebuilt.signingPayload;
  // @ts-expect-error Caller is an immutable part of the operation plan.
  rebuilt.caller = coordinates.registry;
  // @ts-expect-error Source-readiness verification cannot be asserted by a pure plan.
  const live: true = rebuilt.factsVerified;
  if (normalized.kind === "multiple") {
    const allArtists: readonly Hex[] = normalized.request.artistIds;
    // @ts-expect-error Multiple request is not a caller-picked single Artist anchor.
    normalized.request.artistId;
    void allArtists;
  } else {
    const artist: Hex = normalized.request.artistId;
    void artist;
  }
  void [suppliedFacts, selectedProfile, selector, actualCaller, base, evidenceId, live];
}
const identityRaw: Hex = encodeArtistHydrationIdentity(state);
const identityBack: ArtistHydrationIdentity = decodeArtistHydrationIdentity(identityRaw);
const baselineRaw: Hex = encodeArtistHydrationOwnerState("baseline", 2, state);
const bindingBack: ArtistHydrationBinding = decodeArtistHydrationOwnerState("delegation", 0, encodeArtistHydrationOwnerState("delegation", 0, binding));
const delegationBack: ArtistHydrationDelegationIdentity = decodeArtistHydrationOwnerState("delegation", 2, encodeArtistHydrationOwnerState("delegation", 2, delegation));
const consentBack: ArtistHydrationDelegationConsent = decodeArtistHydrationOwnerState("delegation", 6, encodeArtistHydrationOwnerState("delegation", 6, consents));
const emptyOwner: null = decodeArtistHydrationOwnerState("baseline", 1, "0x");
const bundleBack: ArtistHydrationMultipleBundle = decodeArtistHydrationMultipleBundle(2, encodeArtistHydrationMultipleBundle(2, rows));
const key: Hex = artistAuthorityHydrationReplayKey(env, { surface: bytes, scope: bytes });
const delta: Hex = artistAuthorityHydrationReplayDelta(env, data);
const after: ArtistHydrationSnapshot = artistAuthorityHydrationOwnerAfter(env, before[0], actor, query, data, bytes);
const profileEvidence: ArtistAuthorityHydrationProfileEvidence = { profile: ARTIST_HYDRATION_PROFILES.baseline,
  predecessorRegistry: coordinates.predecessorRegistry, sourceCoordinator: coordinates.sourceCoordinator,
  expectedSource: single.expectedSource, query, ownerData };
const profileData: Hex = encodeArtistAuthorityHydrationProfileEvidence(profileEvidence);
const profileBack: ArtistAuthorityHydrationProfileEvidence = decodeArtistAuthorityHydrationProfileEvidence(profileData);
const archiveEvidence: ArtistAuthorityHydrationEvidence = { schemaVersion: 1n, configurationHash: bytes, operationId: 60n, actor,
  commitment: bytes, before, after: before, profileData };
const archiveBytes: Hex = encodeArtistAuthorityHydrationEvidence(archiveEvidence, 24_575n);
const archiveBack: ArtistAuthorityHydrationEvidence = decodeArtistAuthorityHydrationEvidence(archiveBytes);

// @ts-expect-error Combined multiple+delegation is deliberately excluded.
normalizeArtistAuthorityHydrationRequest({ kind: "multiple-delegation", request: multiple });
// @ts-expect-error Advanced single profiles are outside this closed family.
normalizeArtistAuthorityHydrationRequest({ kind: "readiness", request: single });
// @ts-expect-error The multiple profile requires its original five-field request.
normalizeArtistAuthorityHydrationRequest({ kind: "multiple", request: single });
// @ts-expect-error The original single profile has no caller-supplied signatures.
normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: { ...single, signatures: [bytes] } });
// @ts-expect-error Original bindingIndex preserves uint256 bigint.
normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: { ...single, bindingIndex: 0 } });
// @ts-expect-error All seven source checkpoints are required statically.
normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: { ...single, expectedSource: [checkpoint] } });
// @ts-expect-error Owner codecs select exact state by owner/profile.
encodeArtistHydrationOwnerState("baseline", 2, delegation);
// @ts-expect-error Delegation Identity requires its tagged wrapper.
encodeArtistHydrationOwnerState("delegation", 2, state);
// @ts-expect-error Empty collaborator owner takes null, not invented typed state.
encodeArtistHydrationOwnerState("baseline", 1, {});
// @ts-expect-error Original multiple collaborator owner stays empty, without a bundle.
encodeArtistHydrationMultipleBundle(1, rows);
// @ts-expect-error Fixed original seven owners have indices0..6.
decodeArtistHydrationOwnerState("baseline", 7, bytes);
// @ts-expect-error Decoded historical grant arrays are immutable.
delegationBack.grants.push(delegationBack.grants[0]!);
// @ts-expect-error Original archive snapshots preserve uint64 bigint.
normalizeArtistHydrationSnapshot({ ...before[0], revision: 1 });
// @ts-expect-error Receipt operations preserve original uint16 bigint.
normalizeArtistHydrationNativeReceipt({ operation: 60, artistId: bytes, collectionId: 1n, recordHash: bytes });
// @ts-expect-error Plain nonce words cannot be JS numbers.
normalizeArtistHydrationNonceWord({ ...word, words: [1, 2] });
// @ts-expect-error Pure original commitment needs complete typed owner data, not an asserted digest.
artistAuthorityHydrationCommitment(coordinates, requests[0]!, query, bytes);
// @ts-expect-error Full carrier byte bound is a bigint.
encodeArtistAuthorityHydrationEvidence(archiveEvidence, 24575);
// @ts-expect-error Decoded Archive evidence is deeply immutable.
archiveBack.before[0].revision = 0n;
// @ts-expect-error The source-derived identity is not an EIP712 payload.
identityBack.digest;
void [baselineRaw, bindingBack, consentBack, emptyOwner, bundleBack, key, delta, after, profileBack];
