# Initial collection-template economics facts

The primary resolver exposes typed facts for a narrow initial collection-artist
template. These facts let the artist consent layer identify the actual immutable
terms without materializing a wallet or trusting caller-supplied entries.

`primaryTemplateEconomicsFacts(templateId)` returns the stored entries hash,
metadata hash and aggregate artist share. It rejects anything outside this first
profile:

- Dynamic entries use COLLECTION_ARTIST and the artist label.
- Other entries have static accounts and nonartist labels.
- Artist shares total at least 500,000 ppm.

SALE_POSTER, collaborator sources and static artist entries remain valid only
where their separate cache/profile rules support them; they are not accepted by
this initial artist-template consent profile. The below-floor artist co-sign
exception is also not implemented here.

`previewArtistPrimaryTemplateAssignment(collectionId, templateId, policyHash,
frozen)` returns the existing `AssignmentFact` tuple with the exact resolver,
PRIMARY_SALE class, collection scope and canonical assignment hash. Policy must
be zero. The hash binds the template identity and immutable terms, not a later
materialized profile or payout address. Both reads require the pinned current
Core/artist facade. Neither calls economics consent, payout resolution or mint
consent, so a consent check can consume them without a recursive call chain.

An initial supported template may be configured before artist nomination. After
nomination, `resolvePrimaryAssignment` can return that exact explicit collection
TEMPLATE assignment. Default/token inheritance and another revenue class cannot
substitute a template for it. This is a current-state read, not proof of recorded
artist consent. Setting, clearing, replacing or freezing a bound template remains
closed, including same-value writes. The preview does not grant authority to
perform those operations. Existing prospective fixed-PROFILE behavior is unchanged.

The artist-layer integration must record the operative payout designation hash
as economics-consent evidence and check the current accepted identity. Later
signed payout designations may change future concrete materialization without
changing the immutable template or requiring new consent. Previously materialized
fixed wallets keep their original payees. An accepted collaborator with a nonzero
share label that this first template does not represent must block artist consent;
unpaid zero-label collaborator rows retain their separate declared boundary.
These artist-layer checks are owned by the artist integration and are not
implemented by this provider's template-shape predicate.

Fixed-price and English-auction adapters still require their explicit supported
fixed-PROFILE authority. This provider increment does not migrate those adapters,
implement prospective TEMPLATE candidates, or turn templateId into
FixedEconomicsCandidate.profileHash. A cached profile remains immutable; it must
not be described as dynamically following later artist payouts.

The focused domain suite covers actual canonical facts, preview/current hash
parity, unsupported terms, inherited-scope rejection, closed mutation, payout
revision continuity, real Safe reads and rejection of a Safe owner's attempted
freeze, plus share fuzzing. It runs alongside the complete materialization suite.
Core/artist/governance are explicit boundary fixtures; the full artist consent
and current-Core mint flow require separate integration evidence. See the
[materialization guide](artist-template-materialization.md) for the governed read
budget, wallet registration/deployment distinction and payout witness events.
