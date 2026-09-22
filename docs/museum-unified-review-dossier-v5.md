# Unified Museum review evidence dossier V5

V5 retains a verified [unified V4 dossier](museum-unified-dossier-v4.md)
byte-for-byte and adds optional [native Artist review](museum-native-artist-review-dossier.md)
and General review packets. V4 remains the sole source of its nineteen packet
groups and forty-nine requirement assessments. Reviews are separate supplemental
evidence; they do not change V4 selections, graphs or acceptance decisions.

Each child is replayed before assembly. The Artist child has its own externally
pinned manifest. The General review packet has an external hash of the canonical,
sorted file-reference list, plus a separately pinned selection policy hash and
caller-declared provenance. General replay verifies its concrete attestation,
publication and semantic transcripts. The wrapper retains every child file under
`v4/`, `artist-review/` or `general-review/` and rebuilds every output byte from
those original inputs during verification.

## Reading the joins

`dossier/review-joins.json` lists every selected and withheld review assertion by
its complete original selector, assertion revision, interpretation profile,
original anchor subject and source state. The wrapper checks these values
against the replayed child snapshots. It also compares positive RPC observations
at the same chain and block; contradictory runtime, getter, header, receipt or
event evidence rejects assembly.

The join classifies each assertion as an exact V4 occurrence, the same original
subject in the same state, the same documentary subject in a different state, or
unjoined. It uses the original chain, Core, collection, subject and record
selectors. Matching a collection-level subject does not establish that a work or
physical object belongs to the canonical token. The original V4 fixture's
canonical token is in collection 1; its existing supplemental statements and
these review fixtures are in collection 7, so their token applicability remains
unjoined. Original invalid, withheld and unselected records stay in their child
sidecars.

Artist and General reviewer policies remain independent. The wrapper never
substitutes one family's reviewer for the other, merges equal IRIs into one
person or object, grants title or custody, or claims human independence or
institutional acceptance.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md). Supply V4 and
each optional child with its external pins. For a General review packet, compute
its packet hash as Keccak-256 of canonical JSON containing the sorted array of
standard `{path, bytes, sha256, keccak256}` references for every file. Its policy
hash is Keccak-256 of the original `selection.json` bytes.

```powershell
python -m tools.museum.canonical_object_dossier_v5 assemble --v4 <v4-directory> --v4-hash <v4-manifest-hash> --artist <artist-directory> --artist-hash <artist-manifest-hash> --general-review <general-review-directory> --general-review-hash <general-packet-hash> --general-review-policy-hash <general-policy-hash> --general-review-provenance synthetic_fixture --disclosure public --output <new-directory>
python -m tools.museum.canonical_object_dossier_v5 verify <new-directory> --manifest-hash <v5-manifest-hash>
```

Omit either review family when unavailable. A package path and its pin must be
supplied together. Verification requires an external V5 manifest hash. The
`complete` command verifies the package but refuses completion while V4's
original requirements remain unresolved. V5 does not alter the existing V4
profile, V4 files or earlier review profiles.

The focused tests use synthetic RPC histories and offline model dependencies.
They do not prove the origin of an RPC capture, consensus, current authority,
actual physical acts, full dossier conformance or institutional acceptance.
