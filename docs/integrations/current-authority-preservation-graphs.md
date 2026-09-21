# Current-authority preservation graphs

This additive profile connects preservation output evidence to the original
Finality graph across Artist succession. It is source-reviewed implementation
with ABI-only validation. Native execution, linked contract sizes, transaction
gas, fresh browser observations and complete Finality acceptance remain pending.
See [protocol status](../status.md) for the repository's maturity boundary.

The existing [preservation consumers](preservation-policy-consumers-v1.md) keep
their content, checkpoint, snapshot and reference types. The new inventory,
coverage and factory profiles bind the original archive worker and the current
authority resolver explicitly. Original full-output profiles and their
currentness rules are unchanged.

## Construction and graph identity

`StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1` serves COLLECTION.
`StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1` serves
TOKEN, RELEASE and SEASON. Each constructor accepts the corresponding genuine
preservation `Recipe`, `StreamArtistArchiveOriginTypes.Dependencies` and
`StreamCurrentAuthorityInventoryTypes.Dependencies`.

The factory recipe hash includes its distinct factory profile, chain, complete
recipe, original archive dependencies and resolver dependencies. A factory may
precede the predicted resolver in the original deployment cycle; every operative
graph read requires its actual runtime, capabilities and original anchors.
Construction does not require a minted scope or a publication.

Child zero is the existing preservation readiness deployment. Children one
through four are fixed V2 checkpoint, output, snapshot and reference deployments.
Children five and six are the new
current-authority inventory and coverage hosts. Creation is bounded and
append-only. Every current graph read rechecks the exact child runtimes,
constructor hashes and entropy source plan. The Router's COLLECTION publication
reader accepts the two explicitly named standard and current-authority factory
profiles. It first requires the base COLLECTION factory capability; the new
profile additionally requires the authority-factory capability and canonical
original-archive and resolver dependency tuples. Their values enter the recipe
hash and distinct graph domain. A SCOPED factory or an unknown profile cannot
enter this route even if it advertises the same supplemental selectors.

The reader retains every source-plan, seven-child runtime and current-graph
check before returning the output child. The original standard branch keeps
its original hash and performs no new authority-dependency reads. Eight added
regressions cover dispatch, missing capabilities, dependency corruption and
noncanonical replies; they are ABI-checked, with native execution pending.

The new, undeployed current-authority factories select
`6529STREAM_TOKEN_PRESERVATION_FAMILY_V2`. Their existing nominal V1 tuple types
and factory domains remain fixed; original standard V1 factories still deploy
only their original V1 children. Shared workers dispatch from authenticated
Plans, manifests and root bindings. A caller-supplied family word does not
authorize a producer.

Each V2 row retains its actual admitted producer marker: either
`6529STREAM_PRESERVATION_RENDER_V1` or
`6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1`. The family marker never
replaces that row marker. VIEW and unknown producers reject. Currentness still
rejoins the complete original Registry admission, producer binding and saved
output. Actual current-Artist producer admission and the complete succession
ceremony require separate composed runtime validation.

The separate [scoped ceremony recipe](current-authority-scoped-preservation-ceremony.md)
constructs actual current-Artist admission, V2 publication, fresh source export
and exact local resume entrypoints. Its three succession cases are authored;
runtime and complete capture/coverage acceptance remain pending.

## V2 interpretation and compatibility

Collection and scoped checkpoint capabilities are respectively
`6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2` and
`6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2`. Both use the common
`6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2` output capability. Snapshot,
reference and root interpretations have new governed V2 definitions and hash
domains. Original V1 documents, default worker branches and historical hashes
retain their meanings.

Plan and output-row widths remain 448 and 1,152 bytes. The output manifest remains
640 plus 1,152 bytes per row; collection and scoped root bindings remain 608 and
800 bytes. Both families reuse the exact original six-field token-content leaf
definition. Original content consent, one-use books, root histories and scoped
aggregates remain shared. Stored-root readers recognize an exact V2 root-profile
and family pair and preserve the original V1 branch.
The COLLECTION factory reader also checks both fixed children: canonical
checkpoint/output capabilities, exact V2 profiles, Core and Router identity,
and the output-to-checkpoint link. A consistent V1 pair cannot replace them.
The standard factory keeps its original dispatch.

The finality input envelope is producer-neutral and retains its original schema
and Registry input domain. Its existing snapshot and reference profile-hash
fields must both match the selected family. Mixed V1/V2 profile hashes reject.
Reference V2 hosts add an eighth immutable family pin; snapshot V2 hosts retain
the original three immutables and select their family in constructor-only
storage. Runtime prediction must use the corresponding compiler artifacts.

## Inventory and archive evidence

Each inventory plan captures the complete resolved authority and preservation
source context. Every append and seal checks that capture. A cutover or any
meaningful source drift invalidates operative use of the old plan; saved
historical evidence remains readable. A new plan retains the original host
anchors and can admit original records from different authenticated eras.

The new writer interfaces require receipt witnesses for WORK, Intent, Intent
Waiver, Interview and the original content-root authorization. Separate fixed
root companions authenticate the original op17 occurrence and then validate the
actual preservation binding, envelope, digest and STOP bytes. Their item roles
are fixed preservation roles; callers cannot supply a role or an arbitrary
archive origin.

The token sequence is output, script, library, renderer, current citation and
preservation. `appendTokenPreservation` is mandatory before the token cursor
advances. Its rows include the complete producer binding, admission,
registration, read/target sets, producer and attribution runtimes, schema,
analysis, golden evidence and every registered target runtime. The narrower
producer getter alone does not represent the complete binding preimage.

The two new coverage hosts accept only the corresponding witness-aware
inventory, exact authority profile and complete constructor configuration.
Archive admission and refresh bind the same full capture and origin set. STATE
rows follow the captured authority; original archival bytes retain their
authenticated original locations. Complete STOP checks and the full current
diagnostic remain available.

## Provider and discovery

`StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1` and
`StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1` are distinct siblings.
They preserve the original Registry, provider and adapter reciprocity while
selecting exact preservation factory children. The discovery catalogue and
source-configuration hashes have separate authority domains.

The original Artist remains the durable Finality anchor. Current sanction
components resolve through the original Registry's authenticated authority
route. Preservation statements retain their own typed manifests and complete
current inventory checks. Original static branches remain separate. The new
provider also composes the shared, one-time governed VIEW source binding. Its
four constructor arguments and original source-configuration hash remain
unchanged. The binding validates the original declaration, source-factory
dependencies and preservation snapshot reciprocities; the route-read budget
comes from that bound declaration. VIEW keeps its separate producer profile and
does not enter the token-preservation V2 family.

The provider also forwards the shared complete VIEW binding interface. Its
complete proposal admits the reference, inventory and bundle source selection
in the same original one-time class2 action. Basic and complete entrypoints
consume the same guard; completing a basic-only binding later is not supported.
The complete proposal, rather than its inner basic proposal, must be authorized.
`viewFinalitySourcesReceipt()` retains historical admission after dependency
drift; `viewFinalitySources()` revalidates the operative source bindings. Neither
getter substitutes for current reference, inventory, archive or Finality
evidence. This thin forwarding layer retains the four constructor arguments and
source-configuration hash formula.

VIEW Finality dispatch uses the separately reviewed shared Configuration,
Components, Metadata and Operations workers with the original constructor-owned
configuration. The provider selects VIEW before probing token-preservation
graphs in all ten source, component, manifest, input, review, prepared and
metadata surfaces. Both prepared entrypoints first authenticate the original
Registry caller and runtime. Pending or invalid VIEW sources fail on that route;
they cannot fall back to a token or collection profile. Other scopes keep their
existing dispatch and fixed token-family checks. Native execution and complete
VIEW ceremony acceptance remain pending.

The [actual current-authority VIEW binding tests](../../test/current/StreamCurrentAuthorityViewCompleteBinding.t.sol)
use a distinct [constructor fixture](../../test/helpers/StreamCurrentAuthorityViewCompleteBindingFixture.sol)
over the real current-authority graph. They check the original inventory's full
profile, source, origin and authority commitment through complete binding and
catalogue dispatch. That commitment differs from a hash of the ordinary source
tuple alone. The shared original-anchor reader must authenticate the complete
original configuration without replacing it with projected current sources.

The positive construction and Safe binding use real contracts. Runtime drift
and explicitly injected getter faults exercise refusal, retained historical
receipts and restored retries. These are source-identity and admission cases;
they do not mint artwork, publish observations or prove a complete VIEW Finality
ceremony. The VIEW renderer uses its required original attribution profile; the
current-Artist token producer remains a separate interface and family. The
typed dispatch cases separately isolate all ten host routes and prepared-call
guards, and do not replace this genuine configuration coverage.

Preservation excludes only sanction-derived display. It does not freeze or
ignore C2PA, claims, corrections or other provenance changes. Such changes can
still make preservation observations stale. Sharing a retained reference or
root never proves parity of changed full live JSON.

## Validation boundary

Focused authored cases exercise both V1 and V2 root publication codecs, exact
definitions and domains, consent rollback/retry, mixed-family refusal,
checkpoint/output/snapshot/reference dispatch, input envelopes, actual Archive/STOP loading,
capture identity and staleness, phase ordering, retry rollback and coverage
profiles. Some tests deliberately mock the already-authenticated source or
receipt-admission readers so they can isolate those kernels. They do not prove
a complete current-stack ceremony. ABI-only compilation checks types and
interfaces; it does not execute those tests or measure deployment sizes and gas.

The shared test environment's original Finality budget and VIEW maximum remain
a separate integration constraint. Do not infer that either budget fits this
new graph, or substitute old captures, inventories or finalization evidence.
