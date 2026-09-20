# Recovered pending generations with complete grants and delegated consents

This operation60 composition retains one original class1/class3 recovered Artist and one
PRIMARY_ONLY collection with 2â€“128 original pending binding generations. Earlier generations
must be refused or withdrawn; only the final generation is accepted. Original mode1 and mode2
rows may coexist. Complete Identity grants, replacements, revocations, both nonce kinds and
original direct/delegated policy, economics, sale, royalty-freeze and attestation records are
retained alongside the existing direct content/freeze histories.

No new writer, signature, nonce, facade selector or capability bit is introduced. Preparation
selects the profile from authenticated complete source histories, never a supplied subset.
The original seven-owner operation60 guards, source reread, commit and atomic Archive remain.

## Exact selection and encodings

Owner0 keeps the original `BindingGenerations.Bundle`. If every retained binding is mode1,
its old encoder returns the original bytes. If any retained row is mode2, its canonical bytes are:

```solidity
abi.encode(
    keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_GENERATION_MODES_V1"),
    uint16(1),
    originalGenerationBundle
)
```

A mode tag without an actual mode2 row is refused. Every original proposal hash includes its
own mode, and every row, refusal/withdrawal, revision, receipt and replay key is still required.
The final generation is joined to current Attribution and the complete Identity history.

When the complete Identity inventory has any grant, including an unused, expired, exhausted,
replaced or revoked grant, or the final binding is mode2, owner6 uses:

```solidity
abi.encode(
    keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1"),
    uint16(1),
    uint64(finalGeneration),
    uint8(finalConsentMode),
    originalContentBundle
)
```

The original nominal ContentConsentHydration.Bundle is unchanged. Its base arrays contain
every original14/15/16 occurrence; its other arrays contain every17/20/21 occurrence. A mode2
binding with no grants or consent records still has this explicit empty consent envelope.
All seven headers require BINDING_GENERATIONS512 and DELEGATED_CONSENT64. CONTENT_CONSENTS256,
DIRECT_ECONOMICS32 and ATTESTATIONS128 reflect actual corresponding records only.

A current mode1 binding still forbids delegated14/16, even when earlier pending mode2 rows or
a current grant exist. Its other original capabilities remain unchanged. Original generation1,
all-mode1/no-grant generation-only14/24, direct base-consent and content-consent profile bytes
and their original import branches remain supported.

## Historical authorization and complete imports

The original Identity collector authenticates the full grant and revision history, original
signatures, authorization revocations, nonce indexes and replay tree in every retained era.
Each recorded grant association is checked against that exact historical grant and original
receipt chronology. Grant use counts must equal the complete sum across14/15/16/20/24.
A current grant head never substitutes for a recorded grant. Expiry, later revocation or
replacement does not erase a consent, and importing a historical consent does not authorize
a fresh action or restore a consumed nonce.

Original15 and24 preimages use the existing exhaustive collection witness; original20 uses the
existing exhaustive royalty-freeze witness array and the existing WithConsents entrypoint.
All original signing domains and source environments remain. Missing, duplicate, foreign or
unsupported journal rows and mismatched tags, generations, modes or capability headers fail
before owner writes. The content import validates the new envelope then uses its original
maps and write order with the authenticated generation; no Owner or Identity write path changes.
A late Archive failure rolls back every owner and the Safe nonce, permitting an identical retry.

The selected Router remains the same during this Artist migration. No Router tag import is
inferred. The separate ENTROPY_CONFIGURATION op17 family is still explicitly unsupported until
its dependency joins are implemented; original supported metadata/recovery content is retained.

## Focused evidence and remaining scope

The authored suite covers empty mode2, shared grants across14/16/20/24, sparse delegated nonce
words, replacement/revocation/expiry/exhaustion, prior mode2 with final mode1, Aâ†’Bâ†’C imports and
fresh successor grants, missing complete replay inventory, wrong tags/modes/generations,
foreign grant/use counts and counted late Archive failure with identical Safe retry. Two prior
unused-grant refusal cases now exercise the explicitly supported complete base/content profile.
Literal tag and original record hash oracles are independent of the new encoders.

These recipes use actual Artist owners, Registry, Coordinator, Archive, resolvers and threshold
Safe, with Core, governance, Metadata and sale facts as explicit typed boundaries. Authored/type
and selected product size evidence do not establish runtime, full-current, maximum carrier or
transaction-cap acceptance. The original 24,575-byte carrier limit is unchanged.

Accepted-binding corrections, generation changes after an accepted binding, class4, collaborator
policies, multiple identities/collections and further authority compositions remain separate.
This batch does not apply any held collaborator, global-freeze or replay-mutation proposal.

The frozen ABI5 capture covers 1,175 sources with no compiler errors. Saved-output comparison
retains all 10,756 prior ABI entries and 7,134 selectors across 1,303 common production/interface
products, with unchanged recursive storage. The paired selected captures cover twelve products;
all fit after the new generation stage's initial 24,592-byte overrun was repaired to 24,541 by
moving only its new pure contextual check into the new 14,478-byte codec. Other selected sizes
include Preparation 24,366, Binding 23,011 and Consent 21,951. Consent creation is 48,318 bytes
plus its original 160-byte constructor arguments, totaling 48,478. These are compiler size and
source-preservation facts, not executed transaction or maximum-workload acceptance.
