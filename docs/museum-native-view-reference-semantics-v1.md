# Native VIEW reference and file semantics

The native VIEW reference crosswalk describes the files and relationships in an
existing, verified VIEW retrieval envelope. It adds the native source family
missing from the [owner-family semantic export](../tools/museum/CANONICAL-SEMANTIC-EXPORT-V2.md).
It implements a bounded part of [MSM-RELATIONS](museum-semantic-mapping.md):
software environments, separately described files, token outputs and reference
captures. It does not complete MUSEUM-24 or change the nineteen packet groups,
forty-nine dossier assessments, registered definitions or prior export profiles.

## Input and source authority

The input is the exact canonical JSON envelope accepted by
[`view_preservation_retrieval_v1`](../tools/museum/view_preservation_retrieval_v1.py),
with an externally supplied Keccak-256 hash. The new source adapter runs that
concrete verifier before constructing the semantic inventory. It does not accept
a caller's `verified` flag or a substitute source report.

The same envelope can already be retained in canonical object dossier V3 at
`acquisition/inputs/preservation/input.json`, under
`/evidence/retrievalEnvelope`. A dossier consumer must verify that original V3
package before selecting the subdocument and computing its canonical byte hash.
This family package accepts the envelope itself; it does not authenticate a
claimed enclosing dossier, replace its manifest, or reassess its requirements.

The source contains the original reference publication history, native scope,
receipts, selected reference, declared environments and captures, complete member
outputs, original preservation proofs, retrieval witnesses and received media.
Recorded observations keep their original provenance. Internal correspondence
does not independently prove RPC origin, historical signature authorization,
consensus, named institutional authority or current live availability.

## Files and relationships

The inventory precedes graph construction. Separate occurrences retain source
order, duplicate values, historical alternatives and the distinction between a
selected reference and the native head at the captured block.

| Native source | Semantic treatment |
| --- | --- |
| Runnable engine/toolchain ZIP | Separate digital resource with its exact declared environment and original object identity |
| Package file inventory | Separate file occurrences and qualified package-membership declarations |
| Platform prerequisite inventory | Separate prerequisite occurrences and environment dependencies |
| Reference capture and sample | Separate capture, exact token/output correspondence and declared environment relation |
| Adopted VIEW script | Separate script occurrence with its exact adopted source |
| Complete token data, JSON and HTML | Separate output occurrences with the original token, position and byte correspondence |

The graph uses the existing pinned Linked Art model and context. Typed Stream
relations retain meanings that have no faithful property in that model. A local
DigitalObject does not become a new artwork or a physical carrier. Shared hashes
do not imply derivation, and source account addresses do not become people.

Original tuple values, selectors and JSON pointers remain available beside the
graph. The source envelope is retained literally as `source/envelope.json`.
Inventory and provenance paths resolve against that file; no external URL is
rewritten into an invented local asset.

## Evidence states

`described_only` means the native source describes the resource. `received`
requires exact correspondence to bytes retained in this envelope. Each resource
keeps the evidence and its source scope. A ZIP commitment does not establish
possession of each declared package file or operating-system prerequisite.

Original Archive correspondence is retained separately. Neither received bytes
nor a successful package verification establishes archival delivery, ongoing
availability, a `verified_archival` state, format detection, safety scanning or
permission to publish. The exporter does not execute HTML or scripts, inspect
ZIP contents, run a browser, fetch URIs or create a publication route. Reference
receipts do not prove browser performance or a completed preservation drill.

Printing instructions, file roles and token ownership do not create physical
production, custody-transfer, title-transfer or accession events. Rights and
institutional acceptance remain separate evidence.

## Offline package

The additive package retains:

- The exact original envelope and reconstructed native retrieval report.
- The ordered source inventory and complete field correspondence.
- Source, graph and package profiles and the explicit crosswalk.
- DigitalObject resources, offline JSON-LD expansion, typed relations,
  provenance, coverage and qualifications.
- The exact pinned model and vocabulary dependency closure.

Verification replays the source and rebuilds every output with the retained
model. Rehashing a changed report, inventory, resource or claim cannot bypass
reconstruction. Missing model files are errors; verification does not fall back
to the repository model or the network. The inherited package limit is 96 MiB
and 8,192 files, which can be tighter than an upstream source reader's limit.

Use the existing [Museum Python environment](../tools/museum/README.md):

```text
python -m tools.museum.view_reference_semantic_package_v1 profiles
python -m tools.museum.view_reference_semantic_package_v1 build envelope.json export --source-hash <external-envelope-hash> --disclosure public
python -m tools.museum.view_reference_semantic_package_v1 verify export --manifest-hash <external-package-hash>
python -m unittest tools.museum.test_view_reference_semantic_sources_v1 tools.museum.test_view_reference_semantic_graph_v1 tools.museum.test_view_reference_semantic_package_v1 -v
python -m unittest tools.museum.test_view_reference_semantic_receipts_v1 -v
```

Use a new output directory. The tools require explicit public disclosure and
leave the input untouched. The profiles are prospective local export profiles;
this workflow performs no registration or live capture.

The regression fixtures are synthetic retained native evidence. They exercise
the concrete source verifier and model without claiming a new deployment,
live witness, physical event or institutional ingest.
