# Versioned reference acceptance modes

`StreamReferenceModePublication` records non-byte-exact reference evidence and
feeds the existing typed finality reference, sanction review and preservation
inventory consumers. It is a distinct producer. The original
`StreamReferenceRenderPublication` BYTE_EXACT record, schema, profile, domains and
write API retain their original meaning.

This implements the native STATIC still-image profile of CMC-FINALITY-INPUTS
rule 5(d) and LTA-FINALITY requirement 12. It does not establish universal renderer,
environment or institutional acceptance.

| Mode | Producer admission | Typed consumer and preservation closure |
| --- | --- | --- |
| BYTE_EXACT | Existing producer and exact original repeated PNG requirement | Original profile and preimages remain accepted unchanged |
| PERCEPTUAL_TOLERANCE | Exact active registered Metric document; tool/version/implementation/parameters hashes; threshold and score for each original first/last sample; complete context-bound report preimage | New exact profile, current source validation and original class-2 lock; both actual PNG objects, registered metric bytes and full mode evidence enter the inventory |
| CURATED_EQUIVALENCE | Current original ARTIST_INTENT selection, complete significant-properties bytes and ordered affirmative assessment of every field for every sample; actual original EIP712/ERC1271 INDEPENDENT_CONDITION receipt | Same typed current/lock gate; original condition record, payload, signature bundle, examiner host runtime, complete properties and definitions enter the inventory |

The supported CURATED route is the independent SIGNER_VERIFIED alternative.
Institution, examiner name and credential references are mandatory recorded
evidence. The actual original attestor must equal the examiner address. Names,
professional standing, credential validity and institutional accreditation are
not inferred. DIRECT/operator assertions, waivers and estate statements cannot
satisfy this profile. The configured INSTITUTION_SIGNER alternative needs its
own future authority profile. The new
`STREAM_REFERENCE_CURATED_CONDITION_ABI_V1` schema does not change the Museum's
existing `STREAM_CONDITION_REPORT_V1`; that general adapter continues to treat
the new registered definition as unsupported until it gains a versioned adapter.

## Publication sequence

Deploy the new producer with the original fixed Core, Metadata, Schema, Store,
Router, Snapshot and external-archive dependencies and their runtime pins.
CURATED additionally requires fixed actual CollectionAttestations and
ConservationRecordSelection bindings. An all-zero mode binding supports only
PERCEPTUAL; it never enables an unverified CURATED fallback.

Register the five exact new documents under the existing governed schema
registry, and register the exact ABI Metric document under its metric ID. New
metric names are append-only admissions, not caller-selected strings. Both modes
retain the original complete source snapshot, environment and first/last capture
rules. Every second observation now has its own actual PNG object and original
archive-coverage receipt; unequal bytes are never accepted merely by removing
the legacy equality comparison.

1. Prepare the original environment file inventories and full publication terms.
2. Read `modeContextHash(terms)` from the selected, runtime-pinned mode producer.
   It commits that host, original fixed sources, snapshot, complete captures and
   environment. Expected source hash is omitted to avoid a circular preimage.
3. For PERCEPTUAL, measure the exact selected files with the registered tool,
   then populate the exact Metric, threshold, scores, evaluation time and report
   preimage. For CURATED, publish the complete signed condition payload through
   the actual independent host, using the exact current selected Artist intent
   and complete ordered property document. No new publication proxy signs on
   behalf of the examiner.
4. Call `previewModeReference(terms,evidence,recorder)`, retain its source hash and
   canonical payload, and put that hash in `terms.expectedSourcesHash`. Upload
   the returned canonical payload, `abi.encode(terms)` and `abi.encode(evidence)`
   to the existing immutable Store in chunks of at most 8,192 bytes.
5. The actual original Metadata CURATOR class-3 or global class-8 grant must
   authorize `publishModeReference`. Its revision/predecessor, unique reference
   identity, source pins and prepared bytes are checked again atomically.
6. Use the existing governed class-2 lock transition. The typed finality reader
   calls the actual current producer before accepting its receipt or lock. A
   later incompatible source/intent/coverage change prevents current acceptance;
   original historical bytes and receipts remain available.

The new ABI payload includes every schema component in the registered document.
The embedded publication receipt zeroes only its circular hashes, payload size
and later recorded timestamp. Public receipt fields retain their original facts.
All new persistent publication events carry schema version 1.

## Reproducible metric

`tools.preservation.reference_metric` supplies one bounded implementation for
the `STREAM_METRIC_SSIM_V1` entry. SSIM's luminance and contrast/structure factors
follow the [authors' original single-scale work](https://ece.uwaterloo.ca/~z70wang/research/ssim/).
This explicitly named profile uses the retained separable 11-value integer
Gaussian approximation, weighted population moments, K1=0.01, K2=0.03, range 255,
valid windows and the mean of all RGB channel/window scores. Each rational score
is floored at scale 1e9 before averaging. It has no floating-point dependency,
implicit resampling, grayscale conversion or claim to equal another tool's
unspecified "SSIM" settings. Exact parameters and local active-function source
file hashes accompany the generated Metric tuple.

Supported input is noninterlaced 8-bit RGB or opaque RGBA PNG, 11–512 pixels per
dimension. All five PNG filters are decoded. ICC, gamma/chromaticity overrides,
transparency and unsupported dimensions fail explicitly. An already registered
metric's immutable bytes cannot be replaced to adopt this implementation;
register a distinct new metric ID/version when the existing entry differs.

The JSON input contains `contextHash`, `environmentHash`, integer `threshold`,
integer `evaluatedAt`, and one or two `captures`. Each capture has exact
`firstSha256`, `secondSha256`, integer `width` and `height`. The ordered pairs are
the actual two files selected by the corresponding publication sample.

```powershell
python -m tools.preservation.reference_metric --manifest inputs.json --environment environment.json --pair first-a.png first-b.png --pair last-a.png last-b.png --output report.json
python -m unittest tools.preservation.test_reference_metric -v
python -m tools.preservation.reference_mode_profile --check
```

Output includes exact Metric-document ABI bytes, report ABI bytes/hash, scores
and MATCH / TOLERABLE_VARIANCE / DIVERGENT classification. Negative scores retain
their signed ABI representation. Divergent measurements produce a report but
cannot satisfy the onchain threshold. The publication host checks the report
against its own context; this CLI does not authenticate a caller-supplied RPC
context, publication grant or browser execution. Retain the tool, parameters,
environment and report with the preservation package. An implementation hash
alone does not prove archived executable availability or execution of the tool.
The EVM validates attributed evidence and thresholds; it does not run SSIM.

## Validation and remaining acceptance

Ten focused Python controls pass, including the existing retained public native
capture PNGs, all filters, independent constant-image SSIM formula, negative
scores, exact report offsets and schema generation. They measure actual bytes;
they do not create new source authority or institutional acceptance.

Twelve authored Solidity cases use actual Schema/Store/Archive/publication,
Metadata intent selection, independent signature receipts and official threshold
Safe fixtures at explicit inherited Core/Artist/governance observation
boundaries. They cover the typed lock consumer, exact interpretation inventory,
missing archive/metric/property evidence, unequal repeated captures, forbidden
DIRECT assertions and whole Safe rollback/retry. The curated test exercises the
actual source proof independently; a single full curated snapshot → publication
→ finality deployment remains to be run.

The joined source has ABI/storage typechecking. The original registered V1
definition bytes remain unchanged. `STREAM_REFERENCE_MODE_ABI_V2` is an additive
standalone decoder for that same payload: all enums use ABI `uint8`, with complete
Mode, StatementOrigin and InterviewStatus value tables. Its bytes also enter the
inventory. CURATED inventory includes the exact signed institution and credential
HashRefs as external obligations, without inventing their sizes or coverage. The
new case checks both references and rejects omission/substitution by the resulting
finite archive commitment.

Selected production sizing exposed oversized tuple encoders. Fixed preparation,
dependency-read and inventory transports reduce those code paths without changing
the stored receipt, original hash, authorization or write ordering. The first
passing selected capture had all 17 products below the limit; the exact final
source is frozen again before native acceptance. Native execution, final sizes,
cold budgets, complete current-graph finality, curator/human measurement truth
and archive executable reproduction remain separate acceptance work. No
transaction-capacity claim follows from the STATIC renderer's separate capacity
campaign. No held Router proposal or blocked retained-output feature is part of
this batch.

Full PERCEPTUAL executable closure is still being extended by an additive
original-record-bound metric supplement and restored offline replay. The V1
implementation hash and report alone do not establish that complete closure.
