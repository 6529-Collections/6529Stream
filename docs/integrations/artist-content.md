# Artist control of artwork content

The current metadata host can apply exact content consents and defensive freezes.
The corresponding modular artist operations 17/21 and the actual executed-finality
provider are still being integrated. The host tests use an explicit artist read
boundary; they do not establish full-v1 content-authority completion. These APIs
are not in the retained RC1 client ABI export.

## Read the artwork being approved

Use the capability interfaces
[IStreamArtistContentFacts](../../smart-contracts/interfaces/stream/artist/IStreamArtistContentFacts.sol)
and [IStreamArtistContentMutationFacts](../../smart-contracts/interfaces/stream/artist/IStreamArtistContentMutationFacts.sol).
The router distinguishes these actual stored content families:

| Family ID | Fields committed | Candidate preview |
| --- | --- | --- |
| `keccak256("SCRIPT")` | Raw `animationScript` bytes | `previewArtistScriptState` |
| `keccak256("MEDIA_MANIFEST")` | Both `image` and `animationBaseURI` | `previewArtistMediaState` |

`artistContentFamilyState` returns the current family hash. Unknown families
return `supported = false` and a zero hash. Collection title and description are
display fields; changing only those fields does not change the artwork commitment
or consume content consent.

Every commitment includes a host context binding chain ID, Core, collection ID,
router address and code hash, and linked renderer address and code hash. The full
collection commitment retains the `6529STREAM_ROUTER_ONCHAIN_CONTENT_V1` preimage
over that context and the hashes of image, base URI and raw script, in that order.
Family hashes use `6529STREAM_ROUTER_CONTENT_FAMILY_V1`, the same context, the
family ID and its field hashes in the table's order. All structured encoding is
`abi.encode`; string fields contribute `keccak256(bytes(value))`.

`currentArtistContentState` requires configured metadata and a nonempty script
for this onchain rendering profile. `artistContentFreezeState` computes the same
commitment without that readiness requirement. An artist can therefore freeze
incomplete or empty content defensively before approving a first release.

## Apply an approved change

The [content-authority interface](../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol)
separates recording artist permission from the metadata administrator's mutation.
An approval binds Core, metadata host, collection, family, exact resulting state,
nonce and deadline. Use the actual artist signing integration for the deployed
registry, including Safe message handling where applicable.

Once ratification or the first mint opens the consent window, the router obtains
the exact validated record through `contentConsentEvidence`. It permanently marks
that record consumed before changing content. Failed writes roll that mark back.
A no-op consumes nothing. Returning from state B to A does not make the old
approval for B reusable; that change needs a fresh record.

Successful changes emit `ArtistContentConsentApplied` with collection, family,
consent record, resulting full content hash and event schema version. The router
also stores an evolution witness tied to the current operative ratification.
Each change must extend the ratified state or the last verified evolution of it.
A later ratification changes that baseline. A witness never makes an empty script
eligible for the onchain minting profile.

## Apply a defensive freeze

Anyone can call `applyArtistContentFreeze(collectionId, freezeRecordHash)`,
including a separate Safe or relayer. The call verifies the currently applicable
artist authorization for every requested lock and requires the actual content
hash to match its expected state. It changes no artwork and grants no editing
permission. It does not require the metadata administrator or mint-ready content.

| Lock | Effect in this router |
| --- | --- |
| `SCRIPT` | Prevents changes to raw script bytes |
| `MEDIA_MANIFEST` | Prevents changes to image or animation base URI |
| `BASE_URI` | Prevents base URI changes, including through the combined metadata setter |
| `DEPENDENCIES` | Already fixed by the immutable linked renderer; no dependency mutation exists in this profile |

Locks are one-way. Unknown locks are rejected. Artist freezes do not lock title,
description, registry identity operations or unrelated metadata families.
`CollectionMetadataLocked` records the applying caller, verified artist authority
class, authorization hash and schema version. Applications should verify those
events and read the resulting locks before displaying completion.

The host suite includes real two-of-two Safe administration, a separate Safe
freeze relayer, exact event checks, replay prevention, stale-state rejection and
the combined-setter base URI regression. Full current artist composition and
executed-finality enforcement remain separate acceptance work.
