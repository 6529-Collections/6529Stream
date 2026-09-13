# WORK_DESCRIPTION JSON interpretation

This is a complete bounded pure interpretation of `WORK_DESCRIPTION` with semantic
schema `STREAM_WORK_DESCRIPTION_V1` and supported profile
`STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1`. The files are proposed registration
inputs. Serialization does not prove publication authority, current selection,
actual creator association, catalog registration, or truth of an assertion.
Root's authenticated record consumer owns those joins. Existing museum assertion
schemas and their LIDO outputs remain distinct.

`StreamWorkRecordJson.serialize` reconstructs the entire payload from typed data.
`requireExact` compares its length, keccak256 and every byte with the supplied
recorded payload. Common fields are nonzero subject/profile hashes, an explicit
null or nonzero predecessor, and version1. The actual envelope, expected profile
and lineage are separately authenticated inputs. An ABI witness hash is never
the record's JSON hash.

The full form includes authored title, creator, creation date/range, medium,
format, measurements, edition and credit. The artist branch retains exact
artistId, bindingGeneration64 and bindingHash; the named branch cannot silently
replace a known registry artist. Determining which branch is appropriate needs
the real collection association. The absence form has its own explicit reason
and date. All full-form witness fields must be zero/empty in that form, including
nested arrays and inactive discriminants. Rejection never creates absence.

Dates are exact Gregorian years0001..9999. Ranges include both endpoints and
require end>=start. Partial/uncertain/BCE/open dates are unsupported. Measurements
permit every combination of pixels, aspect ratio and duration in seconds.
Positive uint256 decimal strings and numerator/denominator pairs retain their
full values without reduction or floating point. `dimensionless_generative` is
an explicit separate branch. Unique, positive serial N<=M, and authored open
series remain separate edition forms.

Only inscription can be omitted from the JSON full form; when present it is
nonempty exact text, without a cryptographic-signature claim. Alternate titles,
language variants and authority references are explicit ordered arrays, including
empty arrays. Duplicates are retained. Language variants name an existing target;
alternate-title indices are zero-based decimal strings. No language is inferred
or normalized. The supported tag grammar is two or three ASCII letters, optional
four-letter script, optional two-letter or three-digit region. Other BCP47 forms
are rejected by this profile. Authority IDs use the explicitly documented lexical
subsets in the profile; they do not establish external identity matches.

Direct digital format references use `fmt/N` or `x-fmt/N` and the exact
keccak256 of UTF8 `PRONOM:` followed by that PUID. This is not format detection.
The catalog branch uses the complete bounded
`STREAM_WORK_FORMAT_CATALOG_V1` document: one to eight ordered entries with unique
nonzero IDs, each mapped to a PUID or full-specification URI and tagged RAW_BYTES
keccak256 digest. The selected ID must occur exactly once. Every entry is
validated and hashed, including unselected entries. `catalogDocument` returns
those exact bytes for comparison with the actual registry/store document.
Catalog name and selected ID are external to the document's content commitment.
This named catalog interpretation is a supported subset, not a claim that any
other existing catalog schema has these bytes. A URI/hash alone does not prove
the specification was fetched or is available.

All JSON keys are fixed ASCII in canonical order; valid UTF8 values preserve
control escapes, astral characters, language case and normalization form. All
quantities are schema-defined decimal strings; only version/algorithm1 are JSON
numbers. The encoded payload limit is8192 bytes including punctuation/escaping.
Decoded text limits are bytes: title/creator/open-series512; medium/inscription/
absence reason/language value1024; credit2048; alternate title256; language16;
catalog name128; PUID32; specification URI2048. Arrays allow8 alternate titles,
8 language variants and16 authority references. Exceeding any bound rejects,
never truncates. The Python validator executes all semantic constraints in
addition to the closed schema; ordinary JSON Schema validation alone is insufficient.

Run with the pinned museum Python environment, which already provides
`jsonschema`, `rfc8785` and `pycryptodome`:

```powershell
python -m tools.metadata.work_profile --check
python -m unittest tools.metadata.test_work_profile -v
```

The generator owns only its eight new work definition/fixture files. Shared
`StreamRecordJson` and Renderer dependencies are immutable borrowed sources from
root e82c6cfb. Their URI predicate is exactly the supported content scheme and
whitespace/host check; it is not a general URI parser, network request, or format
availability check. The tests are pure meaning proofs. Actual registered
definitions, authorized publication, retained receipts, current selection,
LIDO WORK-description crosswalk and institutional ingest remain separate gates.
