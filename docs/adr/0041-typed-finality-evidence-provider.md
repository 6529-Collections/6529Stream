# ADR 0041: Typed finality evidence beside generic records

Status: Accepted implementation design, 12 September 2026. Complete producer
and current-stack finality acceptance remain in development under
[ADR 0039](0039-canonical-finality-governance-and-evidence.md).

## Fixed bindings and responsibilities

Keep `StreamCollectionMetadataV1` responsible for exact attributed record bytes,
interpretation identities and history. A separate immutable evidence provider
interprets the applicable records, actual Core membership and actual rendering
sources. Generic bytes alone cannot establish finality readiness.

The provider binds one Core and one generic metadata host. Discovery identifies
that fixed provider through `scopeEvidenceProvider()`. The finality registry
pins the provider and validates reciprocal Core/metadata/discovery bindings and
the required interfaces. New candidate and mutation checks also validate the
actual Core-selected metadata host and its recorded runtime hash. A mutable
provider lookup or a zero-code success path is not part of this design.

The provider implements the existing five metadata-finality reads and the
typed ten-reference scope-evidence read. Its own `metadataHost()` identifies
the generic host. Each inherited ERC-165 interface is advertised and checked
separately; the provider's own interface identifier does not include inherited
selectors. The Core adapter takes `(core, metadataHost, evidenceProvider)`:
`collectionMetadata()` continues to mean the generic host, and a separate
getter identifies the evidence provider.

The permanent scope-input commitment's `metadataHost` field remains the actual
generic metadata host. It is never replaced with the satellite's address. New
execution eligibility and retained historical evidence have separate checks;
changing a selected pointer must not erase the ability to examine old records.

## Complete membership and actual sources

The [collection token inventory](../integrations/collection-token-inventory.md)
supplies a serial-checked enumeration of every completed Core mint, including
burned tokens. The producer checks current completeness when forming a new
collection commitment. A caller-supplied root, token count or readiness flag
does not substitute for validating the complete applicable membership.

The first renderer profile obtains its mode from actual stored source: a
nonempty current script is ONCHAIN, otherwise OFFCHAIN. This does not establish
the full HYBRID profile. Source descriptors identify the fixed linked renderer,
original script/media bytes and explicit locks. Core's collection freeze is
reported separately and is not a substitute for metadata locks.

Token evidence uses the coordinator recorded at that token's mint, rather than
assuming today's entropy pointer produced every historical token. Prepared
identities and unresolved entropy cannot silently become complete evidence.
Retained burned identity must be available to historical content reconstruction;
normal ERC-721 `tokenURI` behavior for burned tokens remains unchanged.

## Stable presentation and live artist authority

An artist identity presentation lock captures the accepted binding, generation,
nominated artist and exact identity/acceptance evidence. Live signing authority
can rotate without rewriting that presentation. This lock does not freeze the
artist registry's authority or lifecycle records. A separate one-way display
lock seals configured name and description; script, media, base URI and
dependencies retain their own explicit lock semantics.

The serving profile must identify exactly what the content commitment binds.
Current deterministic Stream JSON is not automatically RFC 8785/JCS: it has its
own field order and may contain integer literals beyond JavaScript's exact
number range. Any registered canonicalization profile must preserve all values
and explain its exact byte rules. A producer must not label arbitrary JSON as
JCS, round large identifiers, filter out artwork fields, or silently hash a
different presentation from the one publicly served.

Current artist status and authority remain separately readable. The complete
artist-display requirements, including truthful dispute and revocation
diagnostics, remain required. Separating stable presentation from live status
does not by itself complete that renderer conformance or permit hiding later
disputes. The corresponding schema and public presentation behavior must be
explicit before accepting the complete profile.

## Authoritative collection-root publication

The fixed Router owns the authoritative root that changes its `CONTENT_ROOT`
artist-content family. The generic metadata host retains interpretation and
publisher-grant ownership. An immutable provider exposes its metadata host,
schema registry and complete-leaf verifier with their original runtime hashes;
the Finality registry exposes its original provider hash. Root preparation
checks the selected Core pointers and all reciprocal bindings, including the
artist facade's fixed Finality registry. The approved route commits ten actual
component addresses and runtime hashes, including Core and artist facade.

Collection metadata administration maps to the existing `SNAPSHOT` family
class-7 grant at that collection; global administration maps to its class-8
grant at scope zero. Class 7 takes precedence when both grants apply. The chosen
publisher, class and nonzero revision enter the exact artist-approved state.
This mapping adds no numbered genesis role and does not allow a generic record
to claim typed root authority. Both root and leaf definition pairs must be
active and contain the exact fixed document bytes registered under `RAW_BYTES`.

Publication always needs exact operation-17 artist consent, including when
ordinary pre-mint content configuration would be allowed without consent.
The append-only record binds its predecessor and original manifest verification.
Current manifest validity is checked again after consent handling, before any
new root becomes authoritative. Consent, lineage and ratification evolution
roll back together on failure. Historical reads do not require new-publication
eligibility. The serving-source commitment excludes the root aggregate to avoid
a self-invalidating checkpoint. See the
[caller guide](../integrations/content-root-publication.md) for profile and gas
boundaries. The complete normative publication facade, scope profiles and actual
artist/provider/Finality composition remain required.

## Provider construction and delayed record consumers

The concrete [Router serving base](../integrations/finality-router-evidence.md)
is constructed from already-live Core, generic metadata, Router and membership
hosts. Serving adapters follow the provider, and fixed discovery follows those
adapters. The complete typed provider must implement all required reads before
it can serve the original Registry. The six-family base alone does not satisfy
that constructor or provide complete finality evidence.

The original Registry precedes the Coordinator, as specified in ADR 0039.
Current WORK and RIGHTS selectors require the live Coordinator and selected
generic metadata at their construction; WORK also requires the selected artist.
Requiring already-live selectors in the provider constructor would create a
cycle. The complete provider therefore binds their predicted, fixed deployment
addresses and exact expected runtime hashes, and rejects every operative record
read until their actual code and reciprocal source/artist bindings match. There
is no mutable binding phase, missing-code readiness or substitute Coordinator.

The accepted selector compiler artifacts embed nine environment immutables:
Core, metadata, schema and store addresses; those four runtime hashes; and chain
ID. Coordinator and artist-owner pins are storage, not runtime immutables. Their
expected runtime hashes can therefore be derived after fixing the exact compiler
product, library links and those nine earlier deployment values. Deployment
tooling must perform that calculation and verify the later actual creations;
an assumed hash or bytecode-size comparison is insufficient.

Use a controlled CREATE sequence or fixed child factory for the predicted
Coordinator, original Registry and later selectors. Include every relevant
creation and transaction when calculating nonces. Mutually dependent CREATE2
initcodes are not solved by sequential address hashing. After Coordinator
construction, governed selection of the metadata and artist hosts precedes
actual selector deployment. Candidate validation then enforces the saved
Router original-Finality anchor and live selected graph. None of these
operative checks is moved into a constructor that precedes its dependencies.

## Complete original entropy as one serving route

Accepted implementation interpretation, 13 September 2026: represent the complete
original entropy source set with one explicit composite adapter per actual scope
inventory. LTA-FINALITY requires every participating source's frozen state and
permits adapters; this profile validates and exposes every native identity/policy
inside the single component commitment. It does not describe a composite as a
native coordinator or omit historical sources.

Individual same-family expectations are unsuitable for the existing serving
contract: the original Registry's frozen-route getter returns the first match,
while the recovery companion rejects an ambiguous family. The composite keeps
one complete route and the existing hash-bound family/scope recovery semantics.
Its explicit token resolver proves retained scope membership, then derives the
actual Core coordinatorAtMint and validates that original source's runtime/policy.
Collection membership uses the saved inventory prefix/count and exact serial;
published subsets retain their sealed membership independently of later mints.

A fixed, constructor-bound factory precedes the original Registry. Permissionless
later preparation derives the actual current plan and admits the complete locked
source list into a constructor-only child. The factory's append-only plan/child
and runtime mapping is not a mutable source allowlist. Complete current discovery
must call its current-component or additive current-route projection; both retain
complete current selection. The route projection omits only the redundant child
finality-state read, which the Registry performs independently. The Registry does not automatically
perform an adapter's current-selection check. Historical child reads use retained
scope/source evidence, while current admission separately rejects stale membership.

The [source-set guide](../integrations/original-entropy-source-sets.md) documents
its exact commitments, serving budgets and current test/composition boundaries.

## Delivery boundaries

The [original-coordinator inventory](../integrations/original-coordinator-inventory.md)
now derives an ordered complete source set from actual token membership and
Core's retained coordinator address for each completed or burned token.
Permissionless bounded indexing binds every association and first-occurrence
runtime identity. These code pins are observed at indexing; original module
identity and actual entropy-policy validation still belong to complete discovery.
Current membership completeness and per-entry live code validation are explicit
separate reads.

The [description consumer](../integrations/finality-description-evidence.md)
now joins the actual WORK and RIGHTS selectors through their exact current
head, validating readback and original receipt. It keeps late selector bindings
fixed and does not infer scope membership from a canonical subject. The existing
collection-root consumer remains separate; collection roots are not silently
reused for TOKEN, RELEASE, SEASON or VIEW subjects.

This design neither changes permanent artist signing preimages nor grants
generic record writers permission to bypass typed evidence checks. The root,
snapshot, reference render, intent or waiver, interview, rights, work description,
render-critical inventory and archival coverage remain separately validated
inputs. Every full-v1 scope and museum requirement remains in the
[delivery ledger](../../ops/V1_DELIVERY.md). A reviewed enumeration primitive
does not close those requirements.

## Registered native multi-capture artist review

Accepted implementation interpretation, 13 September 2026: extend the native
artist-bound COLLECTION review to an ordered two-to-sixteen-capture profile
through an additional exact registered CATALOG. Preserve the four existing
ceremony/archive definitions, their identities and all permanent sanction
preimages. A single capture continues to select the original profile.

The [native provider](../integrations/native-finality-provider.md) performs full
current manifest admission before deriving each original PNG content hash. Its
multi-capture path requires exact ACTIVE profile facts and complete identical
bytes from the original SchemaRegistry and Store. Caller-supplied lists and
record or coverage commitments cannot substitute for original image content.

The profile is a composite interpretation that overrides only the original
single-capture producer applicability restriction. It does not supersede the
base schema or alter the permanent ceremony encoding. New admission requires
current eligibility; historical interpretation retains the fifth document and
resolves its identity through the original Registry's immutable provider binding.
Retiring the profile cannot rewrite an original signature or erase document bytes.
The existing Archive verifier continues to rely on original Artist admission;
independent parsing of the fifth definition is not claimed for that verifier.

## One current statement for candidate inputs and review

Accepted implementation interpretation, 13 September 2026: the original Registry
may return artist preparation and review facts together. It retains all original
scope, component, discovery, Core and manifest gates. After those checks, a fixed
provider may derive one current statement for both the input commitment and the
ordered original image facts. Only the exact original Registry/runtime can use
that prepared provider entrypoint; public methods retain complete validation.

Capability selection is explicit at each boundary. An older Registry preserves
the original Artist candidate calls; an older provider preserves the original
input/public-review reads inside the Registry. Failure after a capability was
advertised is terminal. No readiness cache, different permanent preimage or
weaker finalization check is introduced. The
[native provider guide](../integrations/native-finality-provider.md) documents
these interfaces and the separate complete-ceremony/gas acceptance boundary.
