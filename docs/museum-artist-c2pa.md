# Museum Artist C2PA consumption

The [offline consumer](../tools/museum/artist_c2pa.py) decodes the accepted ART38
interface at source commit `3f1a068088347176f85f3aa1a2731079e39d8227`.
Its [versioned profile](../schemas/museum/artist-c2pa/profile.json) records the
exact producer/interface source hashes and report definition hash. This is a
supplied-evidence interpreter, with no RPC, signing, publication or URI fetching.

## Input and output

The Python API consumes immutable bytes from the native getters. ABI integers
are Python integers at input; retained JSON uses exact decimal strings.
All ABI decoding requires exact canonical re-encoding, including offsets,
padding, booleans, narrow integers, array bounds and trailing bytes.
The joined consumer caps all supplied byte occurrences at 16 MiB before
decoding, including repeated occurrences. This offchain resource cap is separate
from native 8,192-byte payload limits and the 256-entry per-history limit.

| API | Input | Result |
| --- | --- | --- |
| `decode_credentials` | Exact credential schema ID and original unwrapped statement | Versioned payload and ordered credentials; unsupported nonzero kinds remain opaque |
| `consume_credentials` | Artist ID, queried collection, current head, revision-ordered `CredentialEvidence` tuple, separate personhood getter bytes | Complete supplied prefix and head agreement, original statements/attestations and independent personhood observation |
| `decode_report` | Original unwrapped typed report and exact schema definition bytes | Separate recorded validation/authorship claims and original bytes |
| `consume_reconciliation` | `Context`, exact schema, current Selection, revision-ordered historical Selection returns, Display and matching `ReportEvidence` tuple | Original Metadata record/payload joins, selection hashes, retained verifier artifacts and separate display observation |
| `consume` | The reconciliation inputs plus `ArtistEvidence` tuples and exact identity-document bytes keyed by hash | Cross-joins reports to historical credential records or identity-only enumerations and checks supplied current-head agreement |

`CredentialEvidence` contains exact `c2paCredentialRecord` and
`attestationRecord` return bytes, plus the unwrapped statement.
`ArtistEvidence` adds the artist ID, `c2paCredentialHead` return and independent
`personhoodAttestation(collectionId, artistId)` return. These reads belong to the
fixed Attribution owner, `suite.owners[4]`; the new getters are not Registry
forwards. Credential history is global per artist. Its collection, binding,
generation and original source Registry remain historical values, including
after hydration. They are not overwritten with a later report's collection.

`ReportEvidence` contains exact original Metadata `collectionRecord` return
bytes, the unwrapped payload, and the retained verifier observation and trust
anchor bytes. Each original receipt must name the supplied selected verifier,
class 4 or 6, the exact report schema and RAW_BYTES definition. Class 8 does not
qualify. Metadata record URI and report URI are independent fields.

`Context` records the supplied chain, companion, Core, Metadata, Artist, Router,
verifier, collection, subject and source block. It provides hash-preimage inputs;
it does not authenticate their provenance or runtime. The same-block provenance,
canonical schema admission and complete publication/selection event histories
must be established by a separate admitted capture process.

The consumer preserves raw bytes in its output. It never replaces existing
Museum source/profile meanings or the original Artist Metadata-backlink reader,
whose kind-7/8 publication scope remains unchanged. An absent optional read
must be reported by the capture layer as unavailable; a fabricated zero tuple
cannot substitute for a failed call.

## Historical and current facts

Credential rows are strictly ordered by the native five-word credential hash.
Validity windows are start-inclusive and end-exclusive; zero end is unbounded.
An empty latest credential list withdraws that enumeration. It never falls back
to an older list or to the identity document. Identity-document enumeration is
used only when the historical report explicitly records a zero credential head.
An older selected report remains retained after a later withdrawal.

Personhood is always a separate collection-and-artist observation. Credential
records cannot satisfy it. A native personhood record is still an attributed
statement, not proof of a human identity, professional qualification or identity
document authenticity. The seven-word attestation getter omits original nonce,
URI and authorization terms; this consumer does not claim to reconstruct its
complete op24 authorization preimage.

Selection revisions start at one. Each selection hash uses the original
chain/companion/dependency context and the complete tuple with its own
`selectionHash` field zeroed. Metadata record indices must increase; they need
not be consecutive because other subjects and recorders share the lane.

The selected report and supplied Display remain separate. A stale Display
preserves identifiers and the authorship assertion while returning both statuses
as `unevaluated`. The recorded report is not erased. A current Display must agree
with the selected report and supplied current credential head, but this local
agreement does not prove current dependency selection or authority. Provenance
remains live: changed output JSON makes an earlier full-output evidence hash
stale. This historical seam does not establish universal frozen JSON. The
additive [V2 standing-conflict reader](museum-artist-c2pa-conflicts.md) checks
supplied history and original acknowledgement guards separately from the
unchanged six-word Display. Authenticated original-operation evidence remains
a separate requirement.

## What the checks establish

The consumer checks exact native shapes, supplied history linkage, record and
selection hashes, artifact fixity, identity/key-history byte commitments and
declared credential match constraints. It retains the verifier's validation and
authorship outcomes as **recorded claims**. It does not execute a C2PA validator,
validate certificate chains or trust quality, authenticate signer identity,
interpret every public-key-history shape, retrieve media, or prove complete
onchain admission. These outputs alone do not satisfy the object dossier's
`OD-C2PA` acceptance requirement.

Run with the repository's Museum Python environment:

```text
python -m tools.museum.artist_c2pa --check
python -m unittest tools.museum.test_artist_c2pa
```

Omitting `--check` regenerates only the prospective consumer profile. Native
execution, actual graph capture and full Museum acceptance remain separate.
