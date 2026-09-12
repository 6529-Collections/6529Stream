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
| MUSEUM-02 Record integration | Registered documents and payload writes/reads through existing artist, curator, institution, independent and archive authority lanes; Safe direct/relayed paths, replay and renderer isolation tested | MUSEUM-01 interfaces; actual metadata hosts | Integrator and both builders | Byte host `72c4b099`, actual artist composition `85f44fbd` and independent host `4673f248` pass focused review; full current-stack and museum-schema composition pending |
| MUSEUM-03 Offline exporter | Deterministic package, identity/provenance indexes, exact values, policy-bound conflict presentation, TGN snapshots and field coverage; regenerate with no network | MUSEUM-01 fixture/schema boundary; real-chain acceptance also needs MUSEUM-02 | Revenue builder | Reviewed selection, projection and reproducible public package integrated; 104 combined tests pass; recorded-chain and complete format mappings pending |
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

The latest integrated suite contains 104 tests, all passing again in the root
environment with 15 pinned packages. Reviewed semantic-review selection
(`f5a23d72`) binds authenticated reviewer evidence to exact original assertion
selectors and avoids circular commitments. Resource projection (`ff1a899d`)
retains source inventory, exact values, attribution and diagnostic sidecars.
Offline package construction and verification (`66aebd4a`) reproduce the
projection from archived inputs and reject missing, altered or extra files.
The current package is an explicitly public fixture product; it rejects claims
of authenticated recorded-state input or restricted-record support.

These increments add [review literals](../docs/museum-review-literal.md),
[resource projection](../docs/museum-resource-projection.md) and
[offline package reproduction](../docs/museum-offline-resource-package.md).
The earlier 65-test source at `49b3e072` passed CI on Windows and Linux. The new
104-test source and all four generators also pass both platforms at `dac4d4ed`
([run 34697427952](https://github.com/6529-Collections/6529Stream/actions/runs/34697427952)).
Complete mappings, including a faithful abstract-work representation, BagIt/
OCFL packaging, real-chain authority and institutional ingests remain in scope.

The [metadata host](../docs/integrations/metadata-records.md) now has focused
record-byte, history, authority and Safe tests. Four actual artist-publication
composition cases and the dedicated independent-attestor host's 22-case cohort
pass independent review and are integrated as `85f44fbd` and `4673f248`.
Their Core/Executor boundaries differ and remain explicitly documented; they
do not establish full current-stack or museum-schema acceptance.
The exporter will consume verified records through its typed adapter;
it must never relabel a synthetic fixture as an onchain source.

The [schema inventory engine](../docs/museum-schema-inventory.md) is integrated
as `ef3b1631`. Thirteen new cases extend the reviewed museum suite to 65 tests,
covering the actual candidate schema shapes, applicable branches, exact large
integers/decimals and complete field accounting within explicit work budgets.
This supplies the source-field inventory for subsequent projections; it does
not make the current synthetic exporter an authenticated recorded-state export.

The [Linked Art validator](../docs/museum-linked-art-validation.md) is integrated
as `ef107a22`. Its 52-test combined suite passes independent review and a fresh
root environment with 15 pinned packages. All 667 retained schema references
resolve locally after three narrowly declared interpretation repairs; the
original standards remain unchanged. URI/date-time validation consumes the
whole value, and the chosen time profile explicitly excludes leap seconds.
The independent Windows/Linux workflow runs these tools without Solidity
compilation. Full source mappings, recorded-state export and institutional
acceptance remain open.

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
