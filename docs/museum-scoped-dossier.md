# Scoped semantic-evidence dossiers

`tools.museum.dossier` packages an authenticated
[V3 semantic export](museum-archival-semantic-export.md) and its selected media
into a complete BagIt directory, then immutable OCFL versions. Inspection,
building and verification are offline. The tool never fetches a URI or writes
a chain record.

This is a distinct, prospective, unregistered profile:
`MUSEUM_SEMANTIC_EVIDENCE_DOSSIER_V1`. It does not claim the adopted
`OBJECT_DOSSIER_V1` or `STATE_EXPORT` contract. The existing BagIt profile,
hydration profile, semantic schemas V1/V2/V3 and retained capture stay unchanged.

## What is authenticated and what is supplied

The external export-manifest hash anchors full replay of its original source
records, historical account authorities, selection policies, typed assertions,
resources, dependency closure and authority snapshots. Every original package
file is embedded unchanged below `data/semantic/`, including its original
outer manifest. No source facts are supplied through a dossier metadata form.

The selected, admitted `presentation-of` assertions determine media bindings.
Each requires unambiguous typed SHA-256, byte length, MIME type and canonical
content URI claims. The media index retains the exact admitted claims. This
profile classifies every selected presentation body as render-critical; it
does not infer `SOURCE_MASTER`, `DISPLAY_DERIVATIVE` or other preservation roles.

The operator supplies exact local bytes in files named `<sha256>.bin`, with
lowercase SHA-256 and no `0x` prefix. Each size and SHA-256 must match the
authenticated assertions. IPFS URIs must be canonical CIDv1/raw/sha2-256 with
the same digest. An Arweave transaction identifier does not establish digest
agreement or availability. Repeated media bytes may be deduplicated, while
each entity binding remains in the index. Ambiguous assertions, extra supply,
missing bytes and mismatches fail closed. Missing render-critical bytes cannot
be replaced with a fetch instruction or a hydration promise.

Local size/hash verification does not identify the file format, prove a prior
fixity check, authenticate an authority publisher, establish a qualified human,
or confer institutional or archival acceptance. It also does not establish
that the bounded selection contains the complete token render inventory.

## Build and inspect

Use the existing museum Python environment and a verified V3 export directory.
The following commands use illustrative local paths; obtain the external hash
from the trusted producer or retained capture, independently of the directory
being verified. Each output directory must be new.

```powershell
python -m tools.museum.dossier inspect work/semantic-export --manifest-hash <export-manifest-hash>
```

Inspection prints the exact source scope, entity/media bindings and
`missingMedia` filenames. Put the corresponding local originals under
`work/media-supply`, then inspect again. Inspection reports
`readyToPackage: true` only when this selected media inventory is supplied.

```powershell
python -m tools.museum.dossier inspect work/semantic-export --manifest-hash <export-manifest-hash> --media-directory work/media-supply
python -m tools.museum.dossier build work/semantic-export work/dossier-bag --manifest-hash <export-manifest-hash> --media-directory work/media-supply --bagging-date 2026-09-16
python -m tools.museum.dossier verify work/dossier-bag --manifest-hash <returned-bag-manifest-hash>
```

An optional `--archive-evidence <local-file>` must be paired with its separately
trusted `--archive-evidence-hash <hash>`. It is checked against this exact
semantic manifest and original source anchor and retained under
`data/publication/`. It authenticates the later semantic-manifest publication;
it is not a media archival receipt, a source assertion or a consensus proof.

The inspectable directory includes `data/dossier/manifest.json`,
`media-index.json`, the closed schema/profile, exact original export files,
media bytes, and optional publication evidence/report. A small source index
commits to normalized UTF-8/LF text of the three dossier modules. Those files
are inert reported source bytes: verification checks their closed index and
commitments, never executes them and does not prove which code a producer ran.
They are not a complete runtime archive. Historical snapshots remain unchanged
when a compatible verifier reconstructs a later OCFL version.

## OCFL and independent verification

```powershell
python -m tools.museum.dossier ocfl work/dossier-bag work/dossier-ocfl --manifest-hash <bag-manifest-hash> --created 2026-09-16T00:00:00Z --message "Initial scoped evidence dossier"
python -m tools.museum.dossier verify-ocfl work/dossier-ocfl --inventory-hash <returned-inventory-hash>
```

These commands reuse the existing OCFL byte/version machinery. The dossier
verifier also reconstructs every distinct historical bag and replays its
source and media joins. The generic `tools.museum.ocfl verify` command checks
transport and version fixity only; it is not a substitute for `verify-ocfl`.
The generic BagIt directory verifier dispatches this profile to the full
dossier verifier. In-memory `verify_bag_files` remains transport-only.

For a successor, build a new bag with `--predecessor <previous-bag-hash>`, then
use `ocfl --previous <previous-object-directory> --previous-inventory-hash
<trusted-previous-inventory-hash>`. The timestamp must increase. The new output
preserves previous content; the prior directory is never overwritten. A new
packaging date or OCFL version does not establish a later source block,
finality, or archival availability.

Collection identity is the exact canonical collection subject:
`urn:6529stream:subject:<subjectId>@block:<blockHash>`. OCFL retains that identity
without the block qualifier. It is explicitly not a token work citation. A
token-scoped export retains its original token citation and chain-head
qualifier. The tool never manufactures a token ID from a collection ID.

## Retained collection and token positives

The existing [archive fixture](../schemas/museum/archival-export/local-fixture/manifest.json)
rebuilds the actual collection export at block 851. Its admitted media claims
identify a 70-byte PNG with SHA-256
`9cc2b380a9efb1077cefd7c25a09520a9dc477109d5d7bc4a035c5b55e7c7c84`.
The dossier regression supplies matching bytes explicitly and verifies source
replay, unchanged dependency bytes, media fixity, separate publication
evidence, missing-media rejection and OCFL preservation offline.

The separate [actual token capture](museum-token-capture.md) joins a paid mint,
15 fresh token-subject Safe records, registered semantic profiles and these
exact PNG bytes at source block 1311. Core token data and actual `tokenURI`
identify the same token and media. Its V3 export, scoped BagIt dossier and OCFL
object verify offline. This is a new explicitly pinned native composition;
it preserves the collection capture and older generic token fixture unchanged.
Required preservation roles and performed historical fixity still need their
own evidence. The token positive covers this selected presentation-media
inventory, not the full render inventory.

The full adopted object-dossier acceptance remains a separate required target.
It includes the authoritative render inventory and applicable archival,
snapshot, dependency and qualification evidence. The token capture reused
pinned binaries; no native contracts were rebuilt for it.

```powershell
python -m tools.museum.dossier definitions --check
python -m unittest tools.museum.test_dossier_media tools.museum.test_dossier tools.museum.test_bagit tools.museum.test_hydration -q
```
