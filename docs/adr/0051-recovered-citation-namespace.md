# ADR 0051: Executed recovery citation namespace

## Status

Accepted on 20 September 2026 by the autonomous-run integrator for MUSEUM-17.
This is an additive pre-genesis citation-profile clarification. Candidate
profile registration and native renderer acceptance remain separate work.

## Problem and current behavior

CMC-CITATION V1 defines three closed qualifier namespaces: finality record
(`fin`), snapshot manifest (`snap`) and record-chain head (`chain`). Its
recovery rule also requires a recovery manifest hash without assigning that
hash a namespace. Those four commitments are distinct. Interpreting a recovery
manifest as a finality record or snapshot silently changes existing meanings.

## Decision

The new `STREAM_CANONICAL_CITATION_PROFILE_V2` and
`STREAM_CANONICAL_CITATION_V2` schema add exactly one qualifier:

```text
eip155:<originalChainId>/erc721:<originalLowercaseCore>/<originalTokenId>@rec:<hash>
```

`hash` is a nonzero lowercase `0x`-prefixed bytes32 **content hash of an
executed recovery's canonical manifest**. It is neither the recovery ID,
recovery route hash, original finality record hash nor a snapshot manifest
hash. Only an original executed native recovery record and its exact retained
manifest bytes can establish the `rec` source correspondence. Scheduling,
preparation, veto, cancellation and an unexecuted manifest cannot do so.

The chain/Core/global-token triple remains the work's permanent identity,
including burned works, recovered serving routes and successor deployments.
Keep original finality, recovery ID, predecessor, scope and route hash as
separate typed relationships. A historical executed recovery does not become
unexecuted because its route later changes. A currently serving route must be
identified through its actual route-family selection; the latest recovery
head alone is insufficient.

V2 retains the exact V1 meanings of `fin`, `snap` and `chain`. The original V1
parser, three-prefix schemas, original 29 genesis definitions, stored receipt
bytes and historical citations remain unchanged. A V1 consumer rejects `rec`;
it must not strip the qualifier, relabel it, or claim V2 conformance. Broader
packet schemas require their own additive adaptation before carrying `rec`.

## Alternatives and security impact

Reusing `fin` or `snap` would make existing hash namespaces ambiguous. An
untyped hash would require guessing which record family to query. A fourth
explicit namespace preserves the original distinctions.

Syntax validation proves no source authority or execution. Native readers
must retain the admitted block, runtime identities, original record and
manifest bytes, and reject contradictory shared-source reads. No new write,
recovery, ownership or signing permission is introduced by a citation.

## Release, validation and rollout

Publish the additive profile/schema with offline tooling and a separate exact
candidate catalog registration. Do not retroactively mark them registered.
Validate unchanged V1 behavior; V2 canonical ranges and nonzero commitments;
executed `rec` positives; prepared/unexecuted, wrong manifest, wrong scope and
rehashed contradiction negatives; and deterministic source-package replay.
Renderer integration and complete acquisition/dossier acceptance are separate
source and runtime checks owned by their delivery leads.

## Non-goals and accepted limits

This decision defines no automatic winner between original finality and later
recovery states, no DOI/ARK registration, no successor identity replacement,
and no consensus or institutional acceptance. Per-source bounded recovery
history is not a claim to cover every scheduled action or every applicable
scope in the complete acquisition packet.
