# Museum semantic profile delivery

Owner adoption: 12 September 2026. The complete
[specification](../docs/museum-semantic-mapping.md) is accepted full-v1 scope
under [ADR 0036](../docs/adr/0036-museum-semantic-profile.md).
Specification adoption is complete. The integrated implementation and scoped
evidence below do not establish complete full-v1 or institutional acceptance.

## Current delivery overview

Checkpoint: **22 September 2026**, integration `9312a0cf2`. The
[canonical feature checklist](STREAM_FEATURE_STATUS.md) owns granular build,
test and integration status. This delivery checkpoint includes the later
retained qualified-account fixture and selection evidence at `8967a96e1` and
`9312a0cf2`; the checklist's `19f0ed0b` checkpoint predates that intake.

Integrated outputs now include the [unified evidence dossier
V4](../docs/museum-unified-dossier-v4.md), [native Linked Art, PREMIS, IIIF and
LIDO exports](../docs/museum-native-multiformat.md), and [native media and
preservation exports](../docs/museum-native-media-preservation.md). Versioned
[declaration lineage](../docs/museum-declaration-lineage.md) and
[qualified-account review](../docs/museum-qualified-account-review.md) retain
original assertions, exact source/reviewer admissions and explicit selection.

The [retained qualified-review fixture](../docs/museum-qualified-review-fixture.md)
adds actual local governance registration and independent-account publication,
with offline replay and selection against the original records. It uses
explicitly pinned historical native contract products. It does not establish
full current-stack or public-testnet acceptance. General and Artist review
adapters remain separate work at this checkpoint. External repository-family
ingests and practitioner reviews remain incomplete; no institutional engagement
or acceptance is claimed.

## Delivery and ownership

The integrator owns delivery, design decisions, shared interfaces, integration
and acceptance. Museum builders own profiles, exporters, capture and retained
evidence; contract owners supply the corresponding record-host and Safe paths.
Independent review checks each proposed increment against its exact source and
evidence. These are responsibilities within the existing team; external
institutional participation is a separate, still-open requirement.

Contract engineering and museum acceptance have separate checkpoints. A
working testnet system can be exercised before institutional ingests finish.
Full-v1 acceptance keeps every museum requirement, including external reviews.
No third-party authority match or museum review becomes a mint/finality gate.

The five delivery-package IDs below retain their original planning meaning;
they are not the finer-grained row IDs in the canonical feature checklist.
Test counts belong to their stated source and cohort, can overlap, and must not
be added into a total or treated as full-v1 acceptance.

| Work package | Concrete output and completion check | Dependency | Owner | Status |
| --- | --- | --- | --- | --- |
| MUSEUM-01 Profile and fixtures | Versioned profiles, pinned dependencies, field accounting, declaration lineage and exact source/reviewer admission policies; preserve prior profile bytes and rejection coverage | Adopted specification; shared record interfaces | Museum builders; integrator owns shared interfaces | Lineage `b7cd578e5` and qualified review `1a899e474`/`19f0ed0b9` integrated; 89 combined root tests pass at `19f0ed0b9` for scoped software/replay controls. Complete mapping and conformance remain open |
| MUSEUM-02 Record integration | Registered documents and original records through actual hosts, with authority, Safe, replay and publication-order evidence | MUSEUM-01 interfaces; actual metadata hosts | Integrator and contract/capture owners | Actual local qualified-review originals `8967a96e1` and selection `9312a0cf2` integrated; 21 root fixture/selection tests pass. Capture uses pinned historical native products; full current-stack acceptance remains open |
| MUSEUM-03 Offline exporter | Deterministic canonical dossier V4 and portable packages; exact values, attribution, field coverage, provenance and explicit review/lineage selection reproduced offline | MUSEUM-01 profiles; qualified MUSEUM-02 inputs | Museum export builders | Canonical dossier and native-source export paths integrated alongside preserved fixture paths. Original evidence and missing inputs remain explicit; complete dossier acceptance and full institutional conformance remain open |
| MUSEUM-04 Cross-format and capture | Linked Art/PREMIS/IIIF/LIDO correspondence from retained native sources, including media, publication events, agents and documentary rights | MUSEUM-01; compose with MUSEUM-02/03 | Museum export/capture builders | Four-format packages integrated; native IIIF painting and PREMIS preservation increment `a35a05d34` passes 46 focused root tests. Operator context and synthetic inputs remain identified; current public-chain capture and institutional acceptance are not established |
| MUSEUM-05 Institutional evidence | Both existing named repository-family ingests and both external practitioner roles examine semantic packages and coverage; at least one review covers CRM/Linked Art and authority reconciliation | Reproducible MUSEUM-03/04 outputs | Integrator coordinates external evidence | Pending; no institution or reviewer engagement claimed |

## Historical delivery evidence

The following records preserve the earlier foundation plan and evidence at
their stated snapshots. Their forward-looking assignments, pending work and
test counts describe those sources, not the current checkpoint above.

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

### Acceptance evidence

The first [PREMIS file projection](../docs/museum-premis-file-projection.md) is
integrated as `9f6afe60`. Its reviewed 149-test snapshot preserves the original
132 tests and both preceding output versions. The pinned PREMIS 3 schema and
explicit XML/RDF datatype handling retain one file's size, format and fixity
assertions, linked to four Linked Art resources and 353 source rows. These are
assertion-preserving exports, not a new verification of the file's actual bytes.
Full PREMIS events/agents/rights, IIIF, LIDO and authenticated capture remain.
The complete 149-test cohort and six generators also pass Windows and Linux CI
at `4c7cc4b6`
([run 34708017861](https://github.com/6529-Collections/6529Stream/actions/runs/34708017861)).

The abstract/nonvisual increment is integrated as `db3c8153` with independent
review. All 132 tests and five generators pass again in the integration
checkout. The original 104 tests and v1 package bytes remain unchanged.
[Abstract works and nonvisual projection](../docs/museum-abstract-nonvisual-projection.md)
now distinguish E89 works, linguistic content, their carriers and nonlinguistic
source assertions with exact field accounting. These are public fixtures;
authenticated-chain exports and institutional acceptance remain open. The
132-test version also passes Windows/Linux CI at `d8f0eef2`
([run 34706982326](https://github.com/6529-Collections/6529Stream/actions/runs/34706982326)).
The preceding 104-test platform evidence
below remains tied to its original source.

The preceding package increment contains 104 tests, all passing again in the root
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
Further complete mappings, BagIt/OCFL packaging, real-chain authority and
institutional ingests remain in scope; the later abstract-work increment is
recorded above.

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
