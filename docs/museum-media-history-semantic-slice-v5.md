# Synthetic photograph byte-backed supplement V5

V5 extends the [eight-case field ledger](museum-media-history-semantic-slice-v4.md)
with one **generated synthetic PNG** for the photograph's display derivative.
The original eight source files stay unchanged: master, display and two
physical prints remain `described_only` in that corpus. This supplement does
not stand in for an artist deposit, receipt or repository accession.

The 1200 × 800 RGB PNG was generated once as a synthetic fixture, pinned by
SHA-256, and retained as both `input/byte-backed-photo.png` and
`media/synthetic-display.png`. Its actual byte length and SHA-256 feed
synthetic file assertions; a canonical CIDv1 URI is derived from that digest.
The supplement declares `image/png`, `fmt/13`, finite rights and attribution
through a separately retained **synthetic** fixture, not from the original
artist or an institution. The fixture is derived from the repository's pinned
four-format example and retains its unrelated example source claims; only this
photo file is selected for PREMIS, IIIF and LIDO media output.

The existing [four-format exporter](museum-multiformat-package.md) produces
Linked Art resources, one PREMIS file, one IIIF Image painting Canvas and one
LIDO resource for that display file. The original Linked Art photo VisualItem,
master and two prints remain in the corpus projection. The outer
`formats/byte-backed/correspondence.json` binds the exact original work,
visual-content, display-file and print pointers to the supplemental export.
Its `sourceFieldMappings` resolve the display ID across all four targets and
the display dimensions into IIIF. File, work, visual content, LIDO record,
Canvas and physical print identifiers remain distinct.

```powershell
python -m tools.museum.corpus_semantic_v1 build <corpus-directory> <new-semantic-directory> --corpus-hash <corpus-hash> --version 5
python -m tools.museum.corpus_semantic_v1 verify <semantic-directory> --manifest-hash <semantic-hash>
python -m unittest tools.museum.test_corpus_photo_bytes_v1
```

The package retains the original corpus, pinned base fixture, pinned image input,
generated media copy,
both model closures and complete nested four-format package. Verification uses
the external V5 manifest pin, then rebuilds every output offline from the
retained exact inputs. Replay reads the pinned PNG bytes and does not run a
compressor. The nested package can also be checked with
`tools.museum.package_v2 verify` using its own retained manifest hash.
Rehashed changes to media, PREMIS, correspondence or source fixture do not
pass replay.

The V4 field ledger remains a ledger of the **original described-only source**;
its PREMIS and IIIF cells remain unsupported. V5's additive correspondence
records which new synthetic byte and declarations enable a supported media
projection. This demonstrates exporter behavior, not current-chain source
mapping, authenticated artist authority, original media receipt, print custody,
institutional ingest or practitioner acceptance.
