# Museum semantic profile delivery

Owner adoption: 12 September 2026. The complete
[specification](../docs/museum-semantic-mapping.md) is accepted full-v1 scope
under [ADR 0036](../docs/adr/0036-museum-semantic-profile.md).
Specification adoption is complete; executable schema publication, contracts,
exporters and institutional conformance are not claimed complete.

## Delivery and ownership

The integrator owns delivery, design decisions, interfaces and acceptance.
The artist builder continues royalty and finality work. The Manager/Ledger
revocation handoff is integrated, and the revenue builder is implementing the
profile, fixtures and offline exporter. The integrator owns the shared record interface
and onchain metadata integration alongside operator deployment. The
independent reviewer challenges both the profile and actual export behavior.
This is an assignment plan within the existing team, not a claim that extra
agents or an external institution are already working.

Contract engineering and museum acceptance have separate checkpoints. A
working testnet system can be exercised before institutional ingests finish.
Full-v1 acceptance keeps every museum requirement, including external reviews.
No third-party authority match or museum review becomes a mint/finality gate.

| Work package | Concrete output and completion check | Dependency | Owner | Status |
| --- | --- | --- | --- | --- |
| MUSEUM-01 Profile and fixtures | Three exact schemas, five record allocations, pinned offline dependency closure, machine-readable crosswalk, explicit bounds and eight fixture scenarios; validate positive and negative vectors | Adopted specification | Revenue builder; integrator owns shared record interface | Reviewed first foundation integrated as `c7752f11`: 32 tests and both generators pass; complete mapping/conformance pending |
| MUSEUM-02 Record integration | Registered documents and payload writes/reads through existing artist, curator, institution, independent and archive authority lanes; Safe direct/relayed paths, replay and renderer isolation tested | MUSEUM-01 interfaces; actual metadata hosts | Metadata builder with integrator | Pending |
| MUSEUM-03 Offline exporter | Deterministic package, identity/provenance indexes, exact values, policy-bound conflict presentation, TGN snapshots and field coverage; regenerate with no network | MUSEUM-01 fixture/schema boundary; real-chain acceptance also needs MUSEUM-02 | Revenue builder | Reviewed synthetic fixture export/verification integrated; recorded-chain and complete format mappings pending |
| MUSEUM-04 Cross-format and capture | LIDO/PREMIS/IIIF correspondence tests; draft-preview and confirmed-record adapters preserving artist text, stable IDs and attribution | MUSEUM-01; compose with MUSEUM-03 | Export/capture builder | Pending |
| MUSEUM-05 Institutional evidence | Both existing named repository-family ingests and both external practitioner roles examine semantic packages and coverage; at least one review covers CRM/Linked Art and authority reconciliation | Reproducible MUSEUM-03/04 outputs | Integrator coordinates external evidence | Pending; no institution or reviewer engagement claimed |

Build the exporter first against immutable fixtures and a typed source-state
adapter so it can proceed before all metadata hosts are implemented. A fixture
or draft adapter must remain visibly distinct from verified chain inputs;
end-to-end acceptance uses the actual contracts. Profile publication and
contract writers share one reviewed payload interface before implementation.

The integrator's [document registry](../docs/schema-registry.md) passes 19
independently reviewed cases, including 256 fuzz inputs and actual Safe/Executor
governance. It retains up to 64 canonical 8,192-byte chunks per logical
document, so the captured 434,213-byte CRM dependency fits as 54 chunks with
one whole-file identity. The builder's publication plan remains explicitly
prospective until actual governance registration and readback. Synthetic
fixtures cannot be promoted to authenticated onchain source records.

The first [offline tooling](../tools/museum/README.md) increment retains three
candidate schemas, eight synthetic fixture scenarios and the exact Linked Art
context bytes. Source selection binds complete selectors and review revisions;
unselected hostile identity assertions remain diagnostic. The prospective
publication planner retains original whole-file hashes. The full CRM/Linked Art
mapping and dependency closure, real recorded-state adapter and institutional
evidence remain required; passing 32 foundation tests closes none of those
larger acceptance gates by itself.

Pinned [vocabulary interpretation](../docs/museum-vocabulary-interpretation.md)
is integrated as `d1aa3652`, with seven reviewed cases passing again locally.
The original CRM, Linked Art and enhancement bytes remain unchanged; a separate
explicit policy adds the six missing class declarations needed by the current
closed vocabulary. This proves the named hierarchy/domain/range rules used by
that implementation, not full RDF/OWL reasoning or Linked Art model acceptance.

## Acceptance evidence

All twelve gates in [MSM-CONFORMANCE](../docs/museum-semantic-mapping.md) and
the [conformance matrix](../docs/launch-conformance-matrix.md) remain open until
their exact evidence is retained. Every package records source revision and
state, profile/dependency hashes, test outputs, coverage and reviewer disposition.
Semantic package fidelity is assessed across sources and sidecars, not inferred
from target-schema validity or a graph containing only convenient fields.

The adversarial corpus must include unauthenticated reviewer names, self-review,
hostile disputes and IRI reuse, source omission, uint256 rounding, payload and
dependency limits, disclosure leaks, live context fetching, profile changes and
old-package verification. Keep the original eight media/history scenarios and
all existing record-family rejection and Safe compatibility requirements.

No production deployment, existing RC1 tag, historical catalog/schema document
or existing release evidence is changed by this adoption commit. Generated
catalog and release artifacts are produced from their owning implementations
when those inputs exist, with their checks; documentation allocations are not
fabricated registrations.
