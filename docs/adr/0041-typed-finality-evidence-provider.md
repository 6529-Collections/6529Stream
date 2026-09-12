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

## Delivery boundaries

This design neither changes permanent artist signing preimages nor grants
generic record writers permission to bypass typed evidence checks. The root,
snapshot, reference render, intent or waiver, interview, rights, work description,
render-critical inventory and archival coverage remain separately validated
inputs. Every full-v1 scope and museum requirement remains in the
[delivery ledger](../../ops/V1_DELIVERY.md). A reviewed enumeration primitive
does not close those requirements.
