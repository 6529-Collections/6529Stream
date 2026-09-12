# ADR 0038: Token royalties and disabled assignment representation

Status: accepted implementation direction; typed source, runtime, and integration
acceptance remain separate.

## Context

The current royalty resolver stores default and collection terms. The next
increment adds actual retained token identity, token overrides, and artist
admission for token/default royalty economics. It uses the binding association
and immutable continuation rules in [ADR 0034](0034-economics-consent-binding-associations.md).

A configured zero-rate royalty already has a distinct representation in the
current resolver: `profileId == 0`, `wallet == 0`, `royaltyBps == 0`, and
`configured == true`. Clearing a key removes it and allows ancestor fallback.
Conflating these states would change economics without the artist's exact
consent.

The frozen [ADR 0021 interface packet](0021-revenue-resolver-validation-adapter-interface-packet.md)
uses a seven-call `P(profileId)` observation bundle for profile-bearing routes.
That bundle authenticates an actual nonzero profile. A disabled assignment has
no such profile. It cannot honestly be represented as seven successful profile
observations or as a missing assignment.

## Decision

StreamRoyaltyResolver remains the only royalty state owner. Its existing
default/collection storage, ABI, constructor pins, per-key hash, and resolved
royalty-policy hash preimages remain unchanged. A token map is appended. Token
mutation and preparation reads require Core's actual retained token-to-collection
mapping. Prepared and burned mappings are assignment facts; they do not grant
minting or financial lifecycle authority.

The permanent `royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)`
entry remains O(1) and storage-only. It selects token, collection, then default
from the authoritative mapping fields supplied by Core. Unmapped tokens select
only default. It performs no external call, including artist consent calls.
Its result is royalty disclosure, not authority to change an assignment or
perform a sale.

Additive typed preparation reads expose exact-key facts, prospective profile
terms, clear previews, and selected royalty terms. Exact-key reads never hide a
missing key behind an ancestor. Clear previews return per-key result hash zero
and the actual nonzero prior hash. They require an existing mutable collection
or token key. A clear stores zero economics with `configured == false` and
`frozen == false`, while advancing the existing per-key revision. Reconfiguring
advances that revision again; it does not reset the counter or change the
economics-only assignment preimage. Setting, replacing, and clearing those keys requires current
artist-association consent through the existing caller-bound validating accessor.
Default signatures retain an independently checked, unsigned collection admission
context; they are not automatically reusable for another collection.

The current-profile freeze remains exact-key only. Unilateral artist freeze
remains collection-only under AA-ECON5. Governance may materialize actual ancestor
terms into a frozen token key, with artist consent over the resulting frozen
token hash. This does not implement inherited/global freezes or mint snapshots.

## Explicit disabled-royalty branch

A disabled royalty is valid only when all of the following hold:

- Revenue class is `ROYALTY_ERC2981`, assignment type is PROFILE, and
  profile ID, wallet, and royalty basis points are all zero.
- The key is configured. Its per-key assignment hash is nonzero and uses the
  existing PROFILE context with zero wallet, entries hash, and metadata hash,
  followed by the existing royalty pointer context with zero profile and bps.
- No split profile or wallet is claimed to exist. No factory profile observation
  is made or fabricated for this branch.
- Artist admission still requires the actual primary payout designation and
  every required paid-collaborator designation, the exact current binding
  association, and a fresh authorized economics record when needed.

AA-ECON1's beneficiary-label validation applies when a split profile exists.
A disabled royalty pays nobody and contains no fictitious entries. It is an
explicit artist-authorized zero-rate election. It suppresses fallback and is
never accepted as the all-zero resulting hash of a clear operation. Invalid
mixed representations, such as nonzero profile with zero bps, are rejected.

This is an explicit representation amendment for the bounded resolver/artist
branch. It does not silently widen the historical ADR 0021 packet. A future
validation-adapter integration must publish its effective versioned disabled
branch and corresponding call/transcript vectors: no `P(0)` bundle, no synthetic
successful observation, and no reuse of a nonzero-profile transcript. Core and
artist identity/consent observations remain mandatory in their respective scopes.
The historical packet bytes and their evidence remain unchanged. Current tests
may claim the disabled resolver/artist branch; they may not claim conformance
to the unamended profile-observation packet.

## Evidence and remaining work

Required evidence covers real token/collection/default precedence; bps-only
changes; disabled versus missing versus clear-zero; unknown, foreign, and retained
burned mappings; exact freeze; default admission; payout/collaborator checks;
current-association replay and continuation; events and atomic rollback; actual
Safe reads/writes; and callback-free Core royalty disclosure. Runtime and
argument-inclusive creation sizes, links, previous ABIs, and storage prefixes
must be bound to the final source.

Inherited/global/permanent freeze modes, loosening, descendant counters,
PREPARED_MINT royalty snapshots and royalty-mode election, complete ADR 0021
adapter/governance conformance, and actual-current deployment/catalog integration
remain explicit obligations. They are not supplied by a token override alone.
