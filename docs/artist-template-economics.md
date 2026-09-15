# Artist consent for collection primary templates

The additive `IStreamArtistTemplateEconomicsAuthority` capability records an
artist's approval of a prospective collection `PRIMARY_SALE` template assignment.
It uses the existing operation-15 authorization digest, nonce, replay protection,
payout designation record and binding association. It does not install an
assignment. The Resolver owner must separately call
`setPrimaryTemplateAssignment` with the exact approved terms.

A caller first obtains `primaryTemplateConsentFacts(templateId)` and
`previewArtistPrimaryTemplateConsentAssignment(collectionId, templateId, 0, false)`
from the actual Resolver's `IStreamArtistPrimaryTemplateConsentFacts` capability.
The template must exist in that Resolver. The resulting `AssignmentFact` supplies
the exact assignment hash for `EconomicsConsent`; the payload must name that
Resolver, `PRIMARY_SALE`, collection scope `1`, and the same collection ID.
The artist signs the original `economicsConsentDigest(payload, authorization)`
and submits `recordProspectiveTemplateEconomicsConsent(payload, templateId,
authorization)` through the Artist facade. A direct Artist Safe may instead
execute the call with an empty signature through the existing direct-call rule.

The supported template contains a positive `COLLECTION_ARTIST` share and static
nonartist rows. A share below 500,000 ppm requires the exact original consent for
the current accepted artist, binding generation and binding hash before current
economics can be accepted. Zero artist share, `SALE_POSTER`, static artist aliases
and paid collaborator rows are not admitted by this capability. Accepted unpaid
collaborator rows remain required. Template preview does not require prior
consent, so the artist can approve a prospective assignment without recursive
resolution or a preinstalled assignment.

The original `IStreamArtistPrimaryTemplateFacts` functions and interface ID retain
the initial 500,000 ppm floor. `IStreamArtistEconomicsAuthority` and its original
fixed-profile entry retain their interface ID and supported candidate type.
Older sale routes that use the initial-template facts remain bounded by that
profile; the new capability does not implicitly widen those sale routes.

The assignment hash retains the existing domain and commits the actual template
ID, entries hash, metadata hash, Resolver context and assignment key. The archive
stores supplemental prospective-template evidence beside the unchanged
operation-15 payload and exact association. Later payout designations change the
dynamic materialization through the typed operative payout read; they do not
rewrite the original consent, stored template or previously materialized wallets.
A changed binding requires a valid association for that new binding, preserving
historical records.

This ingress supports **set only**: policy is zero and `frozen` is false. It does
not authorize template freezing or clearing. Those bound-template mutations stay
closed; a preview with `frozen=true` does not grant authority. Delegated
prospective-template consent is not included in this additive entry.

The focused `StreamArtistTemplateConsentTest` suite uses actual Artist owners,
Coordinator, Archive, primary Resolver and official Safe. Its inherited Core and
governance contracts are typed unit boundaries. Its corrected-binding test also
labels the substituted authoritative Binding/Attribution reads; it does not
claim implementation of corrective binding ingress. These tests are not a full
current-stack, sale-route, governance activation or transaction-capacity claim.

Run the focused suite from the checkout with the standard command wrapper:

```text
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistTemplateConsent.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

Use ordinary aggregate mode for this unit fixture. Its immutable child factories
preserve the fixture's original in-call CREATE nonce sequence. The increased
harness limits permit fixture construction; production runtime sizes are checked
separately. They do not establish public transaction capacity.
