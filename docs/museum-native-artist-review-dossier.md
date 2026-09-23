# Portable native Artist review dossier

The `STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_DOSSIER_V1` package captures one public,
explicitly selected Artist review interpretation. It retains the complete
Metadata and Artist source snapshots and their RPC transcripts, the interpretation
snapshot and transcript, registered document bytes, exact selection policy,
selected result, an attributed Linked Art statement for each selected assertion,
and the offline model dependencies. An external manifest hash pins every file.

The source reader authenticates each original native Artist publication and its
historical op24, Archive, signature, grant, identity, binding and receipt joins.
The selection remains bound to complete original assertion selectors, authority,
revision, profile, scope and publication order. Unselected or invalid assertions
remain in the retained snapshot and sidecar. The graph quotes selected assertions
as recorded statements; it does not infer Artist personhood, institutional
standing, legal title or the truth of an asserted relationship.

## Build and verify

`build` accepts a concrete `NativeArtistReviewSource`, externally pinned
selection bytes and a public disclosure decision:

```python
from tools.museum.native_artist_review_dossier_v1 import build, verify

package = build(source, selection_bytes, selection_hash, disclosure="public")
verified = verify(dict(package.files), package.manifest_hash)
```

For an offline capture, write the Metadata anchor, Metadata transcript, Artist
transcript, interpretation transcript and selection bytes to local files. Pin
each file by Keccak-256 in a canonical JSON replay plan with these exact keys:
`profile`, `provenance`, `metadataAnchor`, `metadataTranscript`,
`artistTranscript`, `semanticTranscript`, `selection`. `profile` is
`STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_DOSSIER_V1`; `provenance` is the admitted
source mode. Each input has `{"path": "relative-file.json", "hash": "0x…"}`.
The plan itself also needs an externally recorded Keccak-256 hash. Replay reads
only those pinned local paths and refuses path escapes or an existing output:

```powershell
.\.venv-tools\museum\Scripts\python.exe -m tools.museum.native_artist_review_dossier_v1 replay capture\plan.json dossier --plan-hash 0x... --disclosure public
.\.venv-tools\museum\Scripts\python.exe -m tools.museum.native_artist_review_dossier_v1 verify dossier --manifest-hash 0x...
```

Verification replays the three concrete readers, their registered interpretation
checks, selection and Linked Art expansion, then compares **every regenerated
file byte** with the externally pinned package. Graph and report edits fail even
when an attacker recomputes the package manifest. The complete original payloads
and interpretation diagnostics remain available for inspection.

The focused tests use synthetic RPC histories. This package does not prove the
origin of the supplied RPC capture, consensus, actual chain execution, reviewer
human independence, institutional acceptance or full object-dossier conformance.
The Artist and General semantic packages have separate source authority; neither
package promotes one family's records into the other's review policy.
