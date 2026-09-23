# Synthetic media/history semantic slice V1

This fixture adapter projects the [pinned eight-case corpus](museum-media-history-corpus-v2.md)
through the existing Linked Art V2 validator and offline dependency closure.
It covers three cases: photograph with two prints, written interview and AV
interview. The V2 crosswalk hash is
`0x7be0d4e34e2b13c1fabf3da03dde55de088d6abb9647b9a57a409134f564edc1`;
the Linked Art validation-policy hash is
`0xc5dfe8227e65a2012b707b3d669ec9c4712e1a4e8b3441556b9f8c67da38e19d`.
The source V2 schema hash is
`0x052724ed357f286d28d15113a37d2d8f007487205b2f815817f7ef1d11ae35fe`
and the vocabulary-policy hash is
`0xd56f4d9fdb72ea1eddcb6542c2fe0a52761d6837914f11b3bf0876ec2bd64faf`.
The package retains the exact crosswalk and policy bytes, their complete
dependencies and all eight original source packages. It binds the corpus manifest hash supplied by
the caller. The original fixture V1 and V2 source files are unchanged.

| Case | Supported projection | Original meaning retained in source/coverage |
| --- | --- | --- |
| Photograph | One `VisualItem`; master and display `DigitalObject` resources with `digitally_shows`; two distinct `HumanMadeObject` prints with `shows` | Work/token binding, master-to-display derivation, pixel and physical image/sheet measurements, capture/completion/printing event detail and resource presence |
| Written interview | Instrument and transcript as distinct `DigitalObject` resources; completed interview `Activity`; participant identity references | Interviewee/interviewer roles, lexical date and precision, language and unreceived-file state; no recording or duration is invented |
| AV interview | Instrument, recording, transcript and captions as distinct `DigitalObject` resources; completed interview `Activity`; participant identity references | Duration, time-aligned caption segment, speaker, roles, lexical date and unreceived-file state; no transcript text or audiovisual content entity is invented |

Each emitted resource is checked against the pinned Linked Art schema and
expanded with its retained context. The provenance ledger links emitted paths
to exact JSON Pointers and source hashes. The coverage ledger starts from the
complete source-schema inventory, marking supported paths `mapped` and every
other path `retained_stream_only`. It keeps the original byte value, including
null, order and lexical precision. A role or file name never establishes a
received file, authenticated person, completed accession, or accepted authority
match. `completeness` remains `incomplete` and all release/acceptance claims
remain false.

Build the original corpus first, then the semantic package, using the printed
hash from each step:

```powershell
python -m tools.museum.corpus_v2 build <new-corpus-directory>
python -m tools.museum.corpus_semantic_v1 build <corpus-directory> <new-semantic-directory> --corpus-hash <corpus-hash>
python -m tools.museum.corpus_semantic_v1 verify <semantic-directory> --manifest-hash <semantic-hash>
python -m unittest tools.museum.test_corpus_semantic_v1
```

Verification reads the original corpus and pinned model closure solely from
the package, including the crosswalk definition, and regenerates every semantic
output. It rejects a changed crosswalk, model policy or resource even when its
enclosing manifest is rehashed;
the trusted external manifest hash remains the package integrity anchor.
The remaining five cases—interactive work, historical geography, conflicting
documentation, independent accounts and offline revision—still need their
own semantic mappings. Current-chain integration, recorded assertion authority,
cross-format parity, repository ingests and practitioner acceptance remain open.
