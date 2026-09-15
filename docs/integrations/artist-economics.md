# Artist approval of revenue changes

This guide describes the modular artist implementation on the v1 development
line. The published RC1 has an earlier artist ABI. Use the source and addresses
for the deployment you are integrating; client and deployment-script migration
for this new line remains in progress.

The supported change is an explicit collection-level fixed split profile:
`PRIMARY_SALE` for primary revenue or `ROYALTY_ERC2981` for royalties. The
assignment policy is zero. Collaborator templates, token overrides, clearing an
artist-bound assignment and prospective zero-profile royalty disablement are
separate unfinished features.

## Approve and apply changed economics

1. Create and deploy the immutable split profile through the resolver's own
   `splitFactory()`. The primary and royalty resolver may have different factories.
   Registration alone is insufficient for this assignment path. The artist-labeled
   entries must match the current artist payout designation and required share.
2. Call `previewArtistPrimaryAssignment(collectionId, profileHash, 0, frozen)` or
   `previewArtistRoyaltyAssignment(collectionId, profileHash, royaltyBps, frozen)`.
   The resolver derives the commitment from its actual profile and deployment
   context. Preview does not change state or approve a governance transaction.
3. Fill `EconomicsConsent` from that returned `AssignmentFact`, and submit
   `recordProspectiveEconomicsConsent(payload, candidate, authorization)` to the
   artist facade. The candidate contains the same profile, zero policy, intended
   frozen bit, and royalty rate (zero for primary revenue). Use the facade's
   economics digest and the exact nonce/deadline for a relayed authorization.
4. Execute the corresponding resolver configuration through governance. The
   resolver requires consent to the exact resulting hash before changing storage.
   A signature for a different rate, profile, resolver, scope or frozen bit fails.
   Governance ownership and delays still apply after artist consent.
5. Read the active assignment and compare its hash with the approved candidate.
   Index the resolver event and artist record as separate transitions. Neither
   event alone proves the other transition happened.

Fixed-profile consent remains valid if the artist later changes their payout
designation. The existing wallet still pays its immutable accounts; it does not
redirect money. Consent to a new profile checks the current designation.

## Apply an artist's defensive royalty freeze

Read `currentArtistRoyaltyAssignment(collectionId)` and authorize that exact hash
with `authorizeArtistRoyaltyFreeze`. This requires the active artist and current
binding, but does not require unrelated mint, payout or content floor records.
Anyone can then call the resolver's
`applyArtistRoyaltyFreeze(collectionId, expectedAssignmentHash)`.

Application checks the current explicit assignment and authorization again. It
permanently freezes that assignment while preserving the profile, wallet and
royalty rate. An authorization for an old assignment cannot freeze its replacement.
The operation has no primary-resolver dependency and cannot unfreeze royalties.

Freezing changes the assignment hash. To keep new minting eligible, first record
prospective economics consent to the same royalty profile/rate with `frozen=true`.
Without that consent, the defensive freeze can deliberately stop new minting;
existing earned balances and royalty routing remain intact. An ordinary governed
freeze also requires consent to the resulting frozen hash.

For a Safe, use real Safe execution for direct artist/owner calls or the handler's
SafeMessage wrapping for a relayed Stream digest. An owner's EOA is not the Safe's
authority. The [artist domain guide](../../smart-contracts/domains/artist/README.md)
describes authorization fields and supported signature paths.

| Caller capability | Interface |
| --- | --- |
| Artist consent and freeze authorization | [IStreamArtistEconomicsAuthority](../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol) |
| Primary candidate facts | [IStreamArtistPrimaryFacts](../../smart-contracts/interfaces/stream/artist/IStreamArtistPrimaryFacts.sol) |
| Royalty candidate facts | [IStreamArtistRoyaltyPreview](../../smart-contracts/interfaces/stream/artist/IStreamArtistRoyaltyPreview.sol) |
| Apply the exact artist freeze | [IStreamRoyaltyFreeze](../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyFreeze.sol) |

These are separate capabilities at the owning contract addresses. They preserve
the existing live royalty-facts and royalty-disclosure interface identifiers.
