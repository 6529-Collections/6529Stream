# Artist consent for elected collection royalty snapshots

[ADR 0044](adr/0044-prepared-royalty-snapshot-consent.md) defines this additive
prepared-mode consent rule and its explicit relationship to the historical
separate token-consent packet.

The Artist reads distinguish live royalties from an explicitly elected collection
snapshot mode. They use the selected immutable Royalty Resolver's additive
`IStreamArtistSnapshotRoyaltyFacts` capability. An older Resolver that does not
advertise it keeps the original live path. A Resolver that advertises it must
return valid mode and election facts; failed or malformed reads are terminal.
An unelected collection reports live mode `1` with a zero election hash. An
explicit mode-1 election has a nonzero authenticated election hash and retains
the same live assignment and evidence bytes.

The first snapshot mode is `2`. It supports a configured, unfrozen collection
profile with a positive royalty rate of at most 1,000 basis points and the
actual split wallet for that profile, or an explicitly configured disabled
assignment with profile ID, wallet and rate all zero. The Resolver owner elects the mode before
the first mint. The Artist validates the election hash against the actual chain,
Resolver, Core, collection and mode. A prospective snapshot approval uses
collection scope `1`, its exact collection ID and `frozen=false`.

Obtain `previewArtistSnapshotRoyaltyAssignment(collectionId, profileId,
royaltyBps, false)` from the actual Resolver and put its assignment hash into the
original `EconomicsConsent` payload. Sign the existing
`economicsConsentDigest(payload, authorization)` and submit
`recordProspectiveEconomicsConsent(payload, fixedCandidate, authorization)`.
The existing direct Artist Safe rule is also available. No new signature domain,
operation number, nonce surface or consent store is introduced. The Resolver
owner separately installs the exact approved collection terms.

The snapshot assignment hash commits the election and original collection
assignment hash under `6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1`. The original
raw collection fact and `ROYALTY_POLICY_V1` source hash remain unchanged. Artist
reads independently reconstruct the raw fact through the original scope-1
preview before accepting the mode-bound fact. The existing operation-15 archive
retains the fixed candidate, exact signed fact and original binding association.
Current snapshot evidence separately records the election, raw fact, mode fact
and full current configuration. Original live evidence bytes remain unchanged.

Prospective and current snapshot facts do not require prior consent, allowing
original operation 15 to approve them without recursive authorization. Actual
source admission and configuration require the existing consent for the current
artist, binding generation and binding hash. The Artist mint-consent read uses
the mode-bound collection fact alongside all original policy, payout, primary
economics, ratification and attestation prerequisites. A live-mode approval
cannot authorize the elected snapshot assignment. A changed accepted binding
requires its own association while preserving the historical record.

Current and prospective profile checks retain the actual operative payout and
accepted collaborator designations. They do not turn fixed royalty profiles
into dynamic payout templates. A payout change that no longer matches a profile
blocks a new approval until the proposed profile or payout is corrected.
Configured-disabled royalties still require the operative Artist payout and all
required collaborator designations, although they contain no paid profile
entries. They retain a nonzero original assignment hash, source policy hash and
signed mode hash. No profile-specific observation is made for profile zero;
the original factory identity reads remain part of the canonical hash context.

This first mode does not admit default fallback, generic token economics
consent, collection freezing or clearing. Snapshot
freeze proposals are rejected; the existing boolean freeze-eligibility query
returns false for an authenticated mode-2 collection. Malformed mode reads still
revert. Derived token snapshot authority belongs to the separate prepared
operation and original collection consent; the Artist does not invent a new
scope-2 approval for a future token. A disabled snapshot creates a configured,
frozen token key with zero economics and nonzero provenance hashes. It suppresses
later positive collection/default royalties. Missing keys and clear-result hash
zero remain distinct and cannot authorize the snapshot. This follows the
explicit representation in [ADR 0038](adr/0038-token-royalties-and-disabled-assignment-representation.md).

`StreamArtistSnapshotRoyaltyConsentTest` uses actual Artist owners, Coordinator,
Archive, Royalty Resolver, split profiles and official Safe. Core and governance
are typed unit boundaries. Its election helper explicitly supplies the Core
pre-first-mint read, and its binding continuation test labels the authoritative
replacement reads. This suite does not establish actual Core snapshot creation,
prepared hook execution, joined commerce, governance activation or public
transaction capacity. The separate `StreamCurrentDisabledRoyaltySnapshotTest`
uses actual Core, Manager, Ledger, Resolver, recorder, auction and Safe to check
prepared zero-rate snapshots, full receipts, idempotence and atomic payment
failure/retry. Its Artist, governance and entropy boundaries are typed fixtures;
combining the two suites does not establish a joined actual Artist commerce flow.

Run the focused suite from the checkout:

```text
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistSnapshotRoyaltyConsent.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

Use aggregate mode for the inherited unit fixture's original CREATE sequence.
The harness allowances permit construction of the fixture; deployed production
runtime sizes require separate checks.
