# Native preservation objects and retained-file PREMIS

The [retained-file adapter](../tools/museum/premis_retained.py) reads selected
typed preservation objects directly from a complete native
`IndependentCatalogSource`. It compares their original content commitments with
local retained bytes and emits PREMIS 3 XML using the existing pinned XSD.
This extends MUSEUM-27/31 beyond selected semantic file assertions.

The separate [export profile](../schemas/museum/premis-retained/profile.json)
preserves the meanings of the existing account, preservation-object, fixity and
PREMIS profiles. It uses the unchanged
`STREAM_MUSEUM_PRESERVATION_OBJECT_V1` schema. It does not redefine
`STREAM_PREMIS_V3_PROFILE` or claim its complete implementation.

## Original records and measured bytes

The source must be the concrete native Independent catalogue adapter or an
offline replay of its externally pinned anchor and transcript. The adapter
checks the complete scoped native catalogue before selecting object records.
The selected records must have their exact original schema and RFC 8785 JCS
definition bytes, independent semantic-assertion family, class-5 receipt,
collection scope and canonical media-subject preimage.

All original payloads, receipt fields, signature bundles, pointers and document
definitions remain in the source snapshot and transcript. The new typed view
does not pretend to be `RecordedSemanticSource`, use its account interpretation
profile, or infer original publication event positions. Native media membership
remains a declared reference. A trusted-RPC source is caller-admitted observation
evidence, not a cryptographic state or consensus proof. Synthetic replay remains
explicitly synthetic.

The plan explicitly binds each selected record hash to a relative retained-file
path. It must list record hashes in sorted, unique order. Separate original
objects and roles can select the same file; each occurrence keeps its own
correspondence and source authority. The exporter does not infer a preservation
role from a filename, MIME value or digest.

For every supplied selected file the exporter computes SHA-256, Keccak-256 and
byte length. It compares the original object's declared hash algorithm, digest
and size without modifying those original values. The comparison report
distinguishes `matches`, `mismatch` and `missing`, with exact expected and
observed values and an explicit number of performed comparisons.

These are current offline measurements. The adapter creates no historical
fixity event, check time, agent or tool-execution claim. It does not fetch an
object URI, establish prior availability, detect format, authenticate a person,
or establish institutional acceptance. Recorded PRONOM/MIME, roles, properties
and relationships remain attributed declarations even after the bytes match.

## XML and missing evidence

The XML uses the existing canonical object mapping: derived Stream media subject
as the PREMIS object identifier, original fixity/size, role and significant
properties, declared PRONOM/MIME format, URI and explicitly recorded
relationships. Relationships must target selected original objects.

Missing or mismatching files produce an unsupported report and **no XML**.
Unsupported roles or format mappings and absent relationship targets also
remain explicit. The exporter does not omit an inconvenient object to make a
smaller successful document. Malformed present records, changed definitions,
broken source joins and unselected extra files reject instead of becoming
missing-evidence diagnostics. Even an all-missing file set must first pass the
native source and selected typed-record checks.

At most 128 objects, 32 MiB per file and 64 MiB of distinct retained bytes are
supported. Plans are at most 512 KiB. The complete package has the inherited
96 MiB and 8,192-file bounds. Paths must be portable and unique under case-folding;
links and existing output directories are not accepted by the file-tree tools.

## Build and replay offline

Use the repository's Museum Python environment. The exact plan is canonical JCS:

```json
{"mode":"native_catalogue_retained_premis","objects":[],"profileHash":"0x...","sourceSnapshotHash":"0x...","version":"1"}
```

Each object entry contains exactly `recordHash` and `path`. An empty selection
produces unsupported diagnostics; it does not discover or invent objects.

```text
python -m tools.museum.premis_retained definitions --check
python -m tools.museum.premis_retained build --anchor anchor.json --anchor-hash HASH --transcript transcript.json --transcript-hash HASH --source-hash HASH --plan plan.json --plan-hash HASH --profile-hash HASH --files retained-files --output new-premis-package --provenance synthetic_fixture --disclosure public
python -m tools.museum.premis_retained verify new-premis-package --manifest-hash PRINTED_HASH
python -m unittest tools.museum.test_premis_retained
```

Use `trusted_rpc` only for separately admitted source observations and retain
the source pin corresponding to that exact provenance. Changing provenance
changes the native source snapshot. A public disclosure declaration covers both
the whole retained source catalogue and supplied files; it is a caller decision,
not a disclosure-rights check by the tool. Restricted export refuses before
output.

The package retains the original anchor/transcript/snapshot, exact plan, typed
object and JCS definitions, PREMIS dependency closure, local files, comparison
report, correspondence and provenance. Verification checks the external manifest
commitment, replays the source and regenerates every output. Rehashing a changed
report or XML does not bypass that reconstruction.

## Worked synthetic example

The [example index](../schemas/museum/premis-retained/example/index.json) retains
an exact anchor, native transcript, selection plan, shared local file and expected
XML/comparison/report bytes. Its
[pins](../schemas/museum/premis-retained/example/pins.json) include the source,
profile and fully reconstructed package manifest commitments. The complete
package and existing XSD chunks are reconstructed during verification rather
than duplicated in this compact example.

Two original objects declare `SOURCE_MASTER` and `DISPLAY_DERIVATIVE` roles for
the same supplied bytes, using SHA-256 and Keccak-256 respectively. The file is
synthetic; its declared MIME and PRONOM values do not establish its format.

```text
python -m tools.museum.test_premis_retained --check-example
```

To regenerate this example deliberately, use the same command with
`--generate-example`. The ordinary focused test also checks every retained byte,
rebuilds the package through the public API and verifies its external manifest
pin. Negative controls cover missing bytes, independent size/digest mismatches,
changed native definitions and rehashed report substitution.

The fixture uses a declared synthetic native source and actual local byte
measurements. Metadata-host object sources, historical fixity events, broader
format resolution, actual-chain captures and full PREMIS acceptance remain
separate work.
