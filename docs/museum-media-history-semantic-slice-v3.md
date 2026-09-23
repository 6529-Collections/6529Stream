# Synthetic media/history semantic slice V3

This extends the [V2 five-case package](museum-media-history-semantic-slice-v2.md)
to all eight source scenarios while retaining V1 and V2 replay. Build with
`--version 3`; verification dispatches from the externally pinned package
version and reproduces its original bytes. The software execution Activity
uses `fixture-v2:completed-execution` in V2/V3 exports. The earlier draft with
the interview rule on an execution event was never integrated or published;
verification rejects it even when its manifest is rehashed.

| Case | V3 projection | Boundary preserved |
| --- | --- | --- |
| Incomplete documentation | Separate described master `DigitalObject` and print `HumanMadeObject`; typed unresolved-claim ledger retains both custody statements and authors | No master receipt, archival fixity, physical accession or selected custody location |
| Independent accounts | One distinct print `HumanMadeObject`; typed unresolved-claim ledger retains artist and curator statements without replacing either | Synthetic author IRIs do not authenticate people, prove independence or confer a universal verdict |
| Offline revision | Typed revision-lineage ledger retains both exact statements and the later revision's pointer to the first | No invented Linked Art content type, current-record authority or replacement of the original wording |

The ledger entries bind exact source hashes and JSON Pointers. Their mapped
field coverage points to the corresponding typed extension path; all other
source fields remain accounted for in the coverage ledger and original source
packages. Detached verification replays the full eight-case corpus, pinned
crosswalk and model dependency closure. Rehashed attempts to choose a winning
claim or change revision lineage fail reconstruction.

```powershell
python -m tools.museum.corpus_semantic_v1 build <corpus-directory> <new-semantic-directory> --corpus-hash <corpus-hash> --version 3
python -m tools.museum.corpus_semantic_v1 verify <semantic-directory> --manifest-hash <semantic-hash>
python -m unittest tools.museum.test_corpus_semantic_v1
```

This closes the named **synthetic fixture projection/replay** examples only.
The package reports `incomplete`: full current-chain source mappings,
authenticated source and reviewer authority, four-format parity, named
repository-family ingests and practitioner acceptance remain open under
MUSEUM-38 and the adopted museum conformance gates.
