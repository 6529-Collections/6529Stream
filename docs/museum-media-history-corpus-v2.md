# Synthetic media and history corpus V2

This corpus exercises the eight fixture scenarios named in
[MSM-CONFORMANCE](museum-semantic-mapping.md). It is source evidence for the
offline fixture exporter, not a recorded Stream dossier or an accepted Linked
Art, PREMIS, IIIF or LIDO projection. The original
[`museum-source-v1`](../schemas/museum/fixtures/source.schema.json) schema and
its eight source files remain unchanged. V2 has the separate schema ID
`urn:6529stream:fixture:museum-source-v2` and the exact schema Keccak256
`0x052724ed357f286d28d15113a37d2d8f007487205b2f815817f7ef1d11ae35fe`.

| Scenario | Exact source Keccak256 | Added source distinction |
| --- | --- | --- |
| Photograph and two prints | `0xd5faf734d7a11f364b589d6fa1d23f3374b68f63863de2ba135e8808a44de4e5` | One visual content ID, four distinct objects, pixel/image/sheet measurements, separate capture/completion/printing events |
| Written interview | `0x90e4d21d2c14abb20167ee276d5c44e93780b2b9fdcd700cb4d1e34c78ec77da` | Instrument and transcript; artist/interviewer roles and language; no recording or duration |
| AV interview | `0x32f44dd45fcbee1a9736aa1c38d9e831551bfc2f36defd3f310dce980b7fc5ec` | Distinct recording, transcript and captions; segment time, duration and speaker |
| Interactive work | `0xc5a302d335ee0a07a852fb682c2ace5faeec29afba5208b8d424ceb7ca91be28` | Code, dependency, environment, reference output, preservation evidence, execution and significant properties |
| Historical geography | `0x647d07342e1e3b99bd5c96937ce4aa5a2bf26ea01b0baa5ce8debd937b671970` | Original statement, local place ID, two synthetic TGN-style snapshot rows and linked later revision; no asserted Getty match |
| Conflicting documentation | `0xf510f590abe76ffd8f92d4594548ba6050e74b56e60458833d6599c2195585c3` | Master described but unreceived; separately authored, disputed custody statements about a distinct print |
| Independent accounts | `0xdd83212352b66ed67adf7ebd38be2978634413f911d92ea4bea67986b33dc1d7` | Artist and curator statements about a distinct print remain separately attributed, without an authenticated identity or universal selection |
| Offline revision | `0xa3c4e4c37d56367218582801034ac48ce8321011f7b69e97c3ec89262286c90d` | Later authored wording cites, rather than replaces, the original revision |

Every media resource is `described_only`: a filename in a fixture is not receipt,
fixity or archival preservation evidence. The place alignment and independent
accounts are synthetic examples, not Getty data or verified people. The
fixture exporter retains each original field and its exact value in its
coverage report; it marks them `retained_stream_only`, since target mappings
have not been evaluated by this path.

Generate or check the tracked V2 inputs and build a detached archive with:

```powershell
python -m tools.museum.fixtures_v2 --check
python -m tools.museum.corpus_v2 build <new-output-directory>
python -m tools.museum.corpus_v2 verify <output-directory> --manifest-hash <printed-hash>
python -m unittest tools.museum.test_fixtures_v2
```

The corpus manifest externally pins all eight individual package manifests,
schema bytes and source bytes. Verification regenerates each package from its
retained originals and performs no live authority, context or repository read.
The offline-revision test verifies an old archive while a changed V3 schema
exists, without replacing the old schema bytes. These tests close the named
synthetic source-retention examples only. Current-stack whole-corpus mappings,
actual-chain source records, two repository-family ingests and external
practitioner acceptance remain open.
