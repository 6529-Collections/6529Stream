# Acquisition packet V5: native evidence and source coverage

`STREAM_ACQUISITION_PACKET_V5` represents all 19 acquisition requirements in
one supplied-data packet. It adds the native personhood, DIRECT floor and
conservation context structures that V4 cannot represent. V1–V4 retain their
original definitions and behavior.

## Native fields

The packet keeps the existing required field groups, including ownership,
RIGHTS, preservation, condition, recovery and sustainability. Two field groups
now carry the complete native fragments:

- `attribution.personhood` embeds
  `STREAM_ACQUISITION_PERSONHOOD_V1`, including the original General authority,
  notarization scope and current versus original identity observations.
- `conservation` has kind `native_direct_conservation`, with `context` holding
  `STREAM_ACQUISITION_CONSERVATION_CONTEXT_V1` and `floor` holding
  `STREAM_ACQUISITION_DIRECT_FLOOR_V1`.

Each fragment uses its existing validator. Cross-field checks retain the
packet's source identity, native head relationships and completed mint
chronology. A General notarization may have been published under a different
collection from the artwork. Its original scope is retained and checked;
rewriting it to the artwork's collection is not an adaptation.

Personhood keeps the native `NONE`, `WAIVER`, `RESOLVED`, `STALE` and
`UNRESOLVED` states. Stale or unresolved evidence is retained with its original
records; it is not reported as absent. `NONE` is scoped to the captured native
head and does not prove that no documentary evidence exists elsewhere.

All 19 field groups are mandatory. Existing explicit absence, waiver and
non-applicability branches keep their meanings. A caller must supply their
required evidence references; leaving out a field does not establish absence.

## Source-preserving assembly

`tools.museum.acquisition_packet_v5` accepts an externally pinned
[DIRECT conservation assembly](museum-direct-conservation-composition.md)
and externally pinned canonical V5 packet bytes. It replays the original
six-source assembly and preserves that package and the supplied packet
unchanged.

The packet's three native fragments must match the replayed fragments byte
for byte. The current RIGHTS field must match the captured RIGHTS fragment.
Only its snapshot reference URI is relocated to the original snapshot's path
inside the new package; its hash and authority fields stay unchanged.

The current attribution join compares the captured native attribution state,
generation and binding Artist ID where those observations support the field.
Native states 1–5 mean claimed, accepted, sanctioned, disputed and revoked.
State 0 means NONE. It does not establish `platform_works`; that requires
separate declaration evidence. This join does not reconstruct the binding's
authority, a sanction's authority or the full attestation history.

The [producer map](museum-packet-v5-producer-map.md) identifies the exact
remaining attribution, sanction, master, archive and reference APIs. Their
availability does not mean their evidence has been captured by this workflow.

The additive [attribution/sanction join](museum-attribution-sanction-capture.md)
adds its own native capture to this unchanged assembly. It compares the
supported fields while retaining the original confirmed sanction separately
from the latest association sanction and later dispute restoration.

## Complete supplied data and incomplete source coverage

Schema validation checks all supplied field groups and their relationships.
The assembly reports source coverage separately for every requirement:

| Coverage | Meaning |
| --- | --- |
| `derived_within_source_profile` | Items 2, 7 and 19 are bound to replayed token identity and RIGHTS evidence. |
| `partial` | Items 5, 6, 10 and 13 combine source-derived native evidence with remaining supplied claims or incomplete source history. |
| `supplied_only` | The other required fields pass supplied-data checks but lack a complete source join in this assembly. |

`export-supplied-packet` returns the exact validated packet bytes. This is a
usable full packet representation, not a claim that all its statements were
authenticated. `complete-packet` verifies the package and then refuses a
source-complete claim, listing the unresolved requirements.

The original historical qualifications remain visible in the retained
DIRECT assembly. Changed current personhood or selections do not rewrite
first-sale facts. Synthetic examples do not establish native execution,
chain consensus, legal personhood, institutional acceptance or complete
acquisition conformance.

## Commands

The additive [native accession and title assembly](museum-acquisition-title-v5.md)
replays the preservation packet and existing accession history, reconciles
eleven sources, and exports a new V5 packet with native legal-instrument,
transfer, title-binding and owner-head fields. It retains the original packet
and every earlier report. Explicit original selection, legal title and
institutional identity remain distinct from the native evidence.

The additive [historical preservation assembly](museum-historical-preservation-capture.md)
accepts the attribution-enriched packet and adds native master and pre-sale
reference evidence. It preserves the original packet bytes and compares saved
release commitments with historical source inputs. Generic preservation labels,
archive delivery, post-mint finality and complete source coverage remain qualified.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.metadata.acquisition_packet_v5 --check

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_packet_v5 assemble `
  --direct direct-conservation-assembly --direct-hash $directHash `
  --packet supplied-v5.json --packet-hash $packetHash `
  --disclosure public --output packet-v5-assembly

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_packet_v5 verify `
  packet-v5-assembly --manifest-hash $manifestHash

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_packet_v5 export-supplied-packet `
  packet-v5-assembly --manifest-hash $manifestHash

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_packet_v5 complete-packet `
  packet-v5-assembly --manifest-hash $manifestHash
```

The output directory must be new. Verification and export reconstruct the
package offline. The exported JSON is canonical and has no appended newline.
