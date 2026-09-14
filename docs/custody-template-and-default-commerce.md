# Scoped custody and default primary rights

This implementation batch adds explicit primary-rights choices to the native
English auction house. Its focused tests are type-checked; native execution,
compiled size, and joined full-current acceptance remain pending. The separate
token-PROFILE implementation and its frozen native162 cohort retain their own
source and evidence boundary. Native162 compiled that predecessor successfully,
but its house measured 24,962 bytes and stopped the size gate before any tests.
The fixed house read worker has since been extracted without changing its public
getters. This later batch has not been measured.

## Existing-token custody templates

Acquire the token through an existing unpaid custody entry. After actual Core
allocation, approve and install an exact token TEMPLATE assignment. The Artist
uses the existing `recordProspectiveTemplateEconomicsConsent` operation 15 with
`scope = 2`, `scopeId = tokenId`, the actual collection, and the original canonical
assignment hash. `previewArtistScopedPrimaryTemplateAssignment` provides the
additive raw preview; it validates real Core token/collection identity. It does
not consume the consent being proposed. Collection approvals and another token's
approvals cannot substitute for that exact payload.

The original Artist signature domain, authorization nonce, binding association,
and Archive envelope remain unchanged. New scoped supplemental evidence records
the template facts and exact assignment fact. Current use requires the original
binding-specific consent at every positive artist share. Static templates retain
an operative Artist payout and exclude paid collaborator labels. Dynamic templates
resolve every accepted paid collaborator row through its typed current payout;
original account/role/label identity remains separate from rotated payout money.
The prospective signature approves symbolic SALE_POSTER allocation. It cannot
approve a concrete auction poster absent from the operation-15 payload.

Before any bid, the poster calls `activateCustodyRights` with both original
platform and current accepted-Artist signatures. The new authorization is always
ALLOW_CURRENT. Its domain is `6529StreamCustodyRightsAllowCurrent`, version `1`,
with the actual chain and house. The exact type is:

```text
CustodyRightsActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)
```

The signed `rightsMode` selects one family:

| Mode | Required actual resolution |
| --- | --- |
| 1 | Default PROFILE, scope 0 / id 0 |
| 2 | Token TEMPLATE, scope 2 / actual token; original 500,000 ppm Artist floor |
| 3 | Token TEMPLATE, scope 2 / actual token; consent-qualified positive Artist share |
| 4 | Token dynamic TEMPLATE with SALE_POSTER and accepted paid collaborators |
| 5 | Default TEMPLATE, scope 0 / id 0; original 500,000 ppm Artist floor |
| 6 | Default TEMPLATE, scope 0 / id 0; consent-qualified positive Artist share |
| 7 | Default dynamic TEMPLATE with SALE_POSTER and accepted paid collaborators |

`primaryPolicyMode` must be 1. The activation commits the original auction/config,
complete eligible origin, real token, initial assignment and actual-token
PRIMARY_POLICY_V1 hash. It appends a new effective bid/settlement configuration;
it never overwrites the original acquisition, auction config, sale id, or nonce.
The concrete poster remains the original signed configuration's poster.
Activation rejects already-bid, terminal, paused, expired, previously activated,
wrong-owner/custody, and mutually activated token-PROFILE sales.

Use `bidCustodyRights` or `bidSignedCustodyRights`, then `settleCustodyRights`.
Signed bids use the unchanged BidAuthorization type and digest, with the new
effective configuration hash. Old bid/paid-settlement entries reject activated
sales, including old signed bids. The new entry family rejects absent activation.
Bid replay, original sale consumption, refund balances, and official recorder
results remain shared with the existing house. No second mint, counter use, or
royalty snapshot occurs during paid custody transfer.

ALLOW_CURRENT admits an independently approved later assignment and current
Artist/collaborator payout rotation before execution. The selected family cannot
change. Actual-token selection, materialized profile/wallet/entries, and dynamic
beneficiary witness must remain identical across the single funding operation.
Templates use the original forced escrow behavior. The versioned
`CustodyRightsRevenueRecorded` event retains full original custody facts,
activation, dynamic witness, and original result; its canonical result and sale
consumption coordinates remain unchanged. No-bid/cancel, signed deadline escape,
poster custody return, and own refund claims retain their original exemptions.

## Explicit default PROFILE commerce

Resolver precedence remains token, collection, then default, selected by actual
configured state. A configured token or collection assignment cannot be skipped,
even when it happens to resolve to the same PROFILE. The default consumer requires
an actual scope-0 PROFILE, nonzero original assignment hash, deployed verified
split wallet, and exact collection-specific current Artist consent. It does not
turn global default installation into Artist approval for every collection.

Custody mode 1 selects this source after ordinary acquisition. For deferred mint
commerce, use the existing `registerRightsAuction` selector and OriginalPolicy
with `mode = 4`, `templateId = 0`, and the exact default assignment hash. The
existing rights configuration/signatures bind that new explicit mode. Its opening
policy uses token 0; actual prepared settlement derives PRIMARY_POLICY_V1 with the
real prepared token id. The original prepared rights event carries both policy
coordinates and the actual root. Manager selectors, host storage, phase hashes,
replay, all royalty snapshot hooks, and Core remain unchanged.

## Explicit default TEMPLATE commerce

Modes 5, 6, and 7 have the same meanings in custody `rightsMode` and prepared
`OriginalPolicy.mode`. They use the existing activation or auction registration
entry points and signing fields. A prepared opening commits the exact default
assignment/template and token-0 policy; settlement commits the actual prepared
token's PRIMARY_POLICY_V1. Custody activation commits its already allocated token.
Both routes require the actual Resolver to select scope 0 / id 0. An existing
token or collection override takes precedence and blocks the default family;
removing the override restores eligibility only with current valid source consent.

The original global owner installs or freezes default terms. That action does not
grant Artist authority over every collection. The Artist approves use for its
specific collection through original operation 15, with the actual collection,
`scope = 0`, `scopeId = 0`, and the original raw default assignment hash.
`previewArtistDefaultPrimaryTemplateAssignment` reconstructs those raw terms
without consuming the consent being proposed. The assignment hash retains its
canonical scope-0 preimage; collection identity is independently signed in the
original economics payload and retained binding association.

A prospective approval uses the existing
`recordProspectiveTemplateEconomicsConsent`. An already installed default,
including a frozen one, can receive its first approval through original
`recordEconomicsConsent`: its exact raw facts and current payout designations are
validated before creating the record. Ordinary current consumption always requires
the exact accepted binding's consent. Freezing changes the default assignment hash
and requires approval of that new hash. There is no new global Artist setter,
collection/token TEMPLATE clear/freeze authority, or consent bypass for a majority
Artist share.

Mode 5 keeps the strict template grammar and Artist floor. Mode 6 admits only a
positive COLLECTION_ARTIST share with explicit consent. Mode 7 uses the original
dynamic source identities and accepted collaborator rows. The operation-15
signature approves symbolic SALE_POSTER terms; the actual poster remains bound by
the auction's signed configuration. Current payout rotation may change the derived
profile without changing the template's raw source hash. Selection, beneficiaries,
profile, wallet, and entries must stay stable through materialization and funding.
All three template families preserve forced escrow and original receipt/result
linkage. A failed late consent check rolls back payment and mint or custody transfer,
so the same complete signed Safe transaction can be retried after repair.

## Boundaries and pending validation

The old PROFILE path, collection-template modes 1–3, token-PROFILE activation,
royalty live/snapshot/default/disabled choices and their hashes remain distinct.
TEMPLATE clear/freeze mutation authority is not added. This is not a primary
allocation-time snapshot hook or a prepared future-token override reservation.
Zero-Artist/platform-only primary profiles remain separate work. Dynamic
templates retain their original maximum 64 entries and eight unique dynamic
sources (at most six collaborator sources when Artist and poster sources are both
present) and positive COLLECTION_ARTIST requirement. Wider auction/product variants and cold collector
gas conformance remain outside this batch.

The default-template extension adds five commerce cases and three Artist authority
cases. New tests cover actual Core/Manager/Resolver/house/recorder/Safe payment with a
typed Artist/governance/entropy boundary, and complementary actual Artist/Safe/
Resolver authority with the existing typed unit Core/governance boundary. They do
not substitute for a joined actual-Artist/current-Core runtime. The final native
build must measure every linked worker and host size and execute the new cases;
ABI-only success establishes type consistency, not those outcomes.
