# Synthetic media/history four-format correspondence V4

This extends the [eight-case semantic package](museum-media-history-semantic-slice-v3.md)
with one source-field ledger across Linked Art, PREMIS, IIIF and LIDO. V1–V3
packages and their pinned bytes remain unchanged. V4 still replays the complete
eight-case synthetic corpus and its exact model dependencies offline.

The ledger at `formats/field-correspondence.json` uses each V3 case's complete
source-field denominator. A `mapped` cell points to an actual format-local
resource and JSON Pointer or XML XPath. Every other present field is retained
with `retained_stream_only`. It compares values only when at least two formats
map the same original field; matching labels do not merge entity roles or
authenticate the source.

| Case | Linked Art | LIDO | PREMIS / IIIF |
| --- | --- | --- | --- |
| Photograph | Distinct VisualItem, master, display derivative and two prints | XSD-validated synthetic work ID, title, work type and quoted statement | Unsupported: resources are described only; no received file, digest, size, format, rights or painting URI |
| Interactive software | Five distinct digital descriptions, execution Activity and named synthetic participant | XSD-validated synthetic work ID, title, work type and quoted statement | Unsupported: no preserved file facts or playable painting body |
| Other six cases | Existing V3 supported entities/extensions | No bounded LIDO work description in this version | Same explicit unsupported source requirements |

The LIDO record ID is derived from the exact source hash and remains distinct
from the source work, visual content, carriers, execution event and people.
Its required `recordSource` names the synthetic fixture generator and is not
an institutional publisher. The original LIDO 1.1 XSD and existing XML
emitter are reused. No invented media link, fixity result or license appears.

```powershell
python -m tools.museum.corpus_semantic_v1 build <corpus-directory> <new-semantic-directory> --corpus-hash <corpus-hash> --version 4
python -m tools.museum.corpus_semantic_v1 verify <semantic-directory> --manifest-hash <semantic-hash>
python -m unittest tools.museum.test_corpus_formats_v1 tools.museum.test_corpus_semantic_v1
```

Verification requires the external manifest pin, checks the complete file
inventory and replays the corpus, Linked Art and LIDO outputs and ledger from
retained inputs. Rehashing an altered LIDO document, identity link or ledger
does not pass reconstruction.

This is a bounded synthetic correspondence example, not the
[canonical field correspondence route](museum-field-correspondence.md) for
authenticated native records or the account format exporter. Current-chain
source mappings, received media, authenticated authors/reviewers, actual
four-format parity, repository ingests and practitioner acceptance remain open.
