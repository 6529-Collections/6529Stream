# Dynamic primary templates in prepared auctions

Prepared native rights mode `3` supports a positive `COLLECTION_ARTIST` share,
the sale's `SALE_POSTER`, paid collaborators and static nonartist recipients.
Modes `1` and `2` retain their original artist-only template rules. The original
PROFILE route, royalty snapshots and default/disabled royalty selection remain
separate supported paths.

`SALE_POSTER` means the poster in the signed auction configuration. Artist
economics consent approves its symbolic allocation before an auction exists;
the signed sale configuration supplies the actual recipient. An accepted artist
acting as poster uses `COLLECTION_ARTIST`. The signing authority is never a
fallback payout destination.

## Register and approve the terms

The Resolver owner calls `createDynamicPrimaryTemplate` with the original
template entries and a list of `CollaboratorReference` values. A reference holds
the original accepted binding row's `account`, `role` and nonzero
`shareLabelId`. Role is an opaque value and may be zero. Its account source is:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
    reference.account,
    reference.role,
    reference.shareLabelId
))
```

The corresponding entry uses a zero static account, this source, the same
share label and a positive share. References and declared collaborator sources
must match exactly. The original deterministic template hash and canonical
entry order remain unchanged. Templates retain the original limits of 64
entries and eight distinct dynamic sources; including artist and poster leaves
six distinct collaborator sources. Binding enumeration remains bounded to 32
rows. Every paid row must fit and have its own source entry, including rows that
ultimately share a payout address or label.

Read `previewArtistDynamicPrimaryTemplateAssignment` to reconstruct the original
collection assignment hash. Record consent through the original
`recordProspectiveTemplateEconomicsConsent` operation 15, then have the Resolver
owner set that exact template assignment. Consent retains the original
signature, replay, accepted-binding association and archival record. Dynamic
current reads require the current binding's exact consent at every positive
artist share. Prospective facts validate the current binding and payout
designations before consent is recorded.

The additive `IStreamArtistDynamicPrimaryTemplateFacts` capability is explicit.
Its advertised read failures are terminal. Existing static and artist-only
templates keep their original evidence and validation paths.

## Open and settle a sale

Open a rights auction with `OriginalPolicy.mode = 3`, the original assignment
and template IDs, and the policy preview for the configured poster. These values
are inside the original signed rights configuration and intent. The Manager
still prepares the actual token and validates the original callback, royalty
phase policy and official recorder result.

At settlement, the Resolver independently reads the accepted generation and
each collaborator's original identity/acceptance row. It resolves money through
`collaboratorPayoutAccount(collaboratorArtistId, originalAccount)`. Every paid
row needs an operative nonzero payout and designation record. Unaccepted,
missing, mismatched or malformed rows fail closed. Static or poster entries
cannot replace artist or paid-collaborator labels.

Each materialization resolves each matched row once. Identical concrete
`(account, label)` pairs aggregate under the original profile rules; different
labels retain separate entries. Profile and wallet identity depend on the
concrete recipients and immutable template, so repeated sales reuse the same
wallet. An artist-signed payout rotation changes future materializations while
retaining the original source identities and consent.

The recorder compares the full actual-token candidate and beneficiary witness
around funding. Payout, designation, binding or assignment changes during that
operation revert the entire mint and payment. Undeployed wallets receive the
original escrow credit, which can later deploy and fund the canonical wallet.
Recipients use the original split-wallet pull release. The original settlement
receipt remains; additive schema-1 facts bind the exact beneficiary witness and
actual poster.

## Evidence boundaries and remaining profiles

The focused tests combine actual Core/Manager/Resolver/house/recorder/Safe
commerce with a typed Artist, governance and entropy boundary, and separate
actual Artist/Safe/collaborator/Resolver/Archive tests with a typed Core. These
are complementary proofs; a joined current Artist commerce run remains its own
integration gate. Test results and deployment sizes are recorded only after the
frozen native run passes.

This slice does not add artist-less `PLATFORM_WORKS` templates, arbitrary source
plugins, wider assignment scopes, or template freeze/clear mutation authority.
Other sale families need explicit dynamic-context adoption. Complete current
stack composition, transaction capacity and release-candidate validation remain
required. Royalty templates remain fixed-recipient assignments because ERC-2981
does not supply sale context.
