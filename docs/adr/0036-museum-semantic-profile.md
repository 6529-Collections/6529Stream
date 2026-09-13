# ADR 0036: Adopt the museum semantic profile

Status: Accepted by owner instruction on 12 September 2026.

Issue: [#743](https://github.com/6529-Collections/6529Stream/issues/743).

## Decision

M1. Adopt the complete [museum semantic mapping specification](../museum-semantic-mapping.md)
into full-v1 delivery: CIDOC CRM/Linked Art mappings, Getty TGN and other
authority reconciliation, attributed assertions, deterministic offline exports,
cross-format validation, authoring compatibility and institutional evidence.
The document remains Draft under the specification lifecycle until its normal
review conditions are met. Accepted scope is distinct from implemented or
registered artifacts and from deployed governance actions.

M2. Build the museum profile alongside contract delivery. Testnet engineering
does not wait for museum institutional acceptance; a conforming full-v1 release
still requires the complete museum gate set. No mint, payment, finality or Safe
call acquires a new semantic-review prerequisite. The [delivery plan](../../ops/MUSEUM_DELIVERY.md)
owns the implementation sequence and evidence status, and the
[conformance matrix](../launch-conformance-matrix.md) registers the gates.

M3. Authenticate reviews separately from a recorder's claimed review status.
Bind deterministic export selection to exact source/reviewer authority and
source state. Preserve competing claims, but do not let an unsolicited dispute
suppress an artist-authorized default dossier assertion. Supplemental identity
declarations retain their source authority; IRI reuse cannot overwrite or merge
another entity. These rules are owned by [MSM-ASSERTIONS] and [MSM-IDENTITY].

M4. Retain the full interpretation closure through existing bounded registry
and payload mechanisms. Pin operational resource limits, exact numeric/byte
representations, and schema-derived field coverage. Full fidelity refers to
the complete package within its declared disclosure scope, not to a lossless
Linked Art projection. These rules are owned by [MSM-PROFILE], [MSM-EXPORT]
and [MSM-INTEROP].

M5. Preserve the original proposal, historical RC1 evidence and original
registered schema meanings. New profile/schema versions and record-type
catalog entries must use the existing extension mechanisms. This adoption
does not rewrite historical exports or claim registration, executable mapping
tables, successful institutional ingests, or production readiness.

## Affected homes and permanence classes

| Home | Amendment | Class |
| --- | --- | --- |
| [Museum semantic mapping](../museum-semantic-mapping.md) | New profile, record payloads, mapping/selection rules and acceptance | Replaceable catalog/profile state; Operational export/capture/verification |
| [Collection metadata](../collection-metadata-contract.md) | Three schema allocations, five record types, inherited authority and museum-format/dossier links | Replaceable catalog entries; Operational dossier requirements |
| [Protocol v1](../launch-v1-target-architecture.md), [specification policy](../spec-policy.md) | Additive scope and inventory links | Classification and scope; no new Permanent mechanism |
| [Conformance matrix](../launch-conformance-matrix.md) | MSM-01 through MSM-12, extending the existing institutional gate | Operational evidence requirements |

All cited Permanent record, subject, hashing, signing, authorization, registry,
payload, finality and Core semantics are inherited unchanged. The original
proposal's SHA-256 is recorded in the addendum's source appendix. The changes
above refine its review/selection, identity, bounds and fidelity rules without
removing any proposed media class, format, record family or acceptance fixture.
