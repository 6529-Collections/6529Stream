# Synthetic media/history semantic slice V2

This extends the [V1 photograph and interview package](museum-media-history-semantic-slice-v1.md)
without changing its externally pinned archive format or three-case replay.
Pass `--version 2` to include the interactive work and historical geography
cases. The archive still retains all eight original V2 source packages, the
exact V2 crosswalk bytes and the pinned Linked Art model closure. It marks
itself incomplete and makes no authenticated-chain or institutional claim.

| Case | Supported Linked Art V2 projection | Original values retained without a stronger claim |
| --- | --- | --- |
| Interactive work | Code, dependency, environment, reference output and preservation-evidence resources remain separate `DigitalObject`s; the completed execution is an `Activity` with the known synthetic artist participant | Software content is not invented as linguistic text or a visual image. Dependency and environment semantics, significant properties, resource presence and date precision stay in the source and exact field-coverage ledger |
| Historical geography | The original local place IRI and unchanged place statement become a `Place` resource | Competing artist/curator claims, proposed and rejected synthetic TGN-style snapshots, capture-location role, unknown precise site and revision history remain attributed in the original source and coverage ledger. No Getty equivalence, coordinates or event location is asserted |

Both cases use the same schema, crosswalk, validation-policy and vocabulary
hashes recorded in the V1 package. Each emitted field has an exact source
pointer and source hash. All other fields remain `retained_stream_only`, with
their exact lexical values in the coverage report and original source bytes in
the package. The verifier replays both package versions using only their
retained source and model files; V1 continues to rebuild three cases, while V2
rebuilds five.

```powershell
python -m tools.museum.corpus_semantic_v1 build <corpus-directory> <new-semantic-directory> --corpus-hash <corpus-hash> --version 2
python -m tools.museum.corpus_semantic_v1 verify <semantic-directory> --manifest-hash <semantic-hash>
python -m unittest tools.museum.test_corpus_semantic_v1
```

Conflicting documentation, independent accounts and offline revision still
need explicit semantic projection or qualified no-projection decisions.
Recorded assertion authority, current-chain mapping, four-format parity,
repository ingests and practitioner acceptance remain open.
