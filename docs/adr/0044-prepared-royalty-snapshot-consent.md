# ADR 0044: Artist consent for prepared royalty snapshots

## Status

Accepted implementation decision on 14 September 2026 under the owner's
explicit authority to complete the undeployed full-v1 system. This is an
additive current-stack capability; the published RC1 remains unchanged.
Implementation acceptance and complete current-system acceptance are separate.

## Decision

An artist may authorize future mint-time royalty snapshots by approving the
exact collection royalty terms together with an irreversible snapshot-mode
election. The existing Artist operation 15 records that approval. Each actual
prepared mint derives and permanently freezes its token assignment from those
approved terms and retains the approved source terms and original mint provenance.

This explicitly amends the separate future-token consent rule for the new
prepared mode. The historical [ADR 0021 interface packet](0021-revenue-resolver-validation-adapter-interface-packet.md)
requires the snapshot consumer to obtain consent for the derived scope-2 token
assignment. The current additive capability instead consumes the approved
collection-specific mode-bound source and an authenticated in-flight prepared
token proof.
It does not claim to implement the old physical adapter transcript or silently
reinterpret its existing selectors. Other token economics mutations retain
their own authority requirements.

## Election and consent

The original Resolver owner may elect mode `1` (live) or `2` (snapshot) once,
before the collection's first token allocation. An unelected collection keeps
live behavior. The election hash commits the chain, Resolver, Core, collection
and selected mode. An elected collection cannot return to an unelected state.

Mode 2 selects an explicit, unfrozen collection source when configured: either a positive
profile with its actual split wallet and a royalty rate no greater than 1,000
basis points, or the canonical configured-disabled zero tuple from
[ADR 0038](0038-token-royalties-and-disabled-assignment-representation.md). The disabled source
retains nonzero assignment and policy hashes, skips profile-specific zero-ID
reads, and keeps the original payout and collaborator prerequisites. The
Artist previews and independently reconstructs the original source assignment,
then signs its election-bound assignment under the existing operation-15
domain and nonce rules. Recording consent and installing collection terms are
separate calls. Consuming either source or mint authorization requires the
current Artist binding and payout association.

When the collection key is missing, mode 2 selects the configured default.
A configured collection key, including disabled zero, always takes precedence.
The default retains its canonical scope-0/id-0 source assignment and policy
hashes, including its frozen bit. Its mode approval remains collection-specific
under operation 15 and cannot authorize another collection or global mutation.
An already selected default uses current-consent recording; prospective fixed
SET still authorizes a collection override. Default changes or freezing require
new current mode approval and phase commitments for subsequent mints. Existing
token snapshots remain fixed. Missing collection and default keys reject.

`6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1` commits the election and original
source assignment. The canonical `ROYALTY_POLICY_V1` hash remains unchanged;
callers must not substitute the election-bound consent hash for that source
policy hash. The [Artist guide](../artist-snapshot-royalty-consent.md) describes
the exact preview, payload and signing sequence.

## Declared platform collections

For a current `PLATFORM_WORKS` collection, RSR-ARTIST-ECONOMICS.1 and
AA-CONSENT.5 require no synthetic Artist operation-15 approval. The original
Resolver owner remains the source mutation authority. The additive
[platform snapshot consumer](../platform-royalty-snapshots.md) authenticates the
actual selected Artist registry, declaration and current uncontested state.
It retains every original source/mode/token hash and prepared proof. Open or
sustained contests and incomplete corrective generations block this path;
accepted correction returns to the original exact Artist economics approval.
A historical declaration finality record is never current mint authority.

## Prepared mint boundary

A fresh phase registers its exact Resolver address and runtime hash, election,
mode-bound consent, canonical source royalty policy and existing application
configuration. The resulting wrapper participates in the existing phase and
mint-authorization hashes. An already configured snapshot phase cannot be
downgraded by replacing its selected Resolver with a live-only implementation.

After Core prepares the actual token, the original Manager calls the snapshot
hook before payment and mint completion. The Resolver independently verifies
Core's selected Manager, Registry admission, consumed operation root, operation
ID and current pending token. It rechecks both this proof and the complete
source after external reads. The token config is an independent copy; freezing
it must not mutate the source being checked.

The Resolver stores the frozen token configuration and the source/election,
Manager, operation and proof identities on its own original contract. A repeated
identical hook is a no-op only within that same authenticated prepared context;
historical or unrelated calls cannot create or replace a snapshot. Any later
failure rolls back the snapshot with mint, funding and replay state. Subsequent
approved collection changes apply to later authorized mints, while existing
token assignments remain fixed.

The four current prepared execution sites apply the same checks. Single-step
mint paths reject snapshot mode. Refund-window purchases reject incompatible
phases before accepting a deposit, while existing refund and deadline exits
remain callable.

## Interfaces and delivery evidence

- [IStreamRoyaltySnapshot](../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltySnapshot.sol) owns election, source, hook and stored provenance reads.
- [IStreamArtistSnapshotRoyaltyFacts](../../smart-contracts/interfaces/stream/artist/IStreamArtistSnapshotRoyaltyFacts.sol) provides independently reconstructible Artist facts.
- [IStreamMintRoyaltyPolicy](../../smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol) binds the phase configuration to the elected source.

The independently reviewed commerce cohort passes 23 tests against actual Core,
Manager, Resolver, recorder and Safe, with typed Artist, governance and entropy
boundaries. A separate 12-test cohort executes actual Artist operation 15,
Archive, Resolver and Safe with a typed Core boundary. Those results do not
establish one joined full-current flow; that integration is underway.

Canonical configured-disabled snapshots additionally pass 28 independently
reviewed cases across complementary actual Artist and actual Core cohorts.
Existing zero token assignments suppress later positive fallback; original
Artist payout and collaborator authority remain mandatory.

Default-source snapshots additionally have 37 independently reviewed cases
across complementary Artist and Core cohorts. This is separate from the joined
current-system result.

Dynamic templates, wider royalty mutation profiles, complete Safe call coverage,
normative gas ceilings and the new release
candidate remain requirements in the [delivery ledger](../../ops/V1_DELIVERY.md).
This increment does not remove them from full v1.
