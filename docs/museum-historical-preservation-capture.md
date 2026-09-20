# Historical media masters and prospective references

The native media-master and prospective-reference readers retain original
records at a pinned collection and block. Their reviewed source is
`905bbe2a3f33f5e7fca436a987d8cba532149e8e`. They use existing producer APIs;
the [producer map](museum-packet-v5-producer-map.md) records that boundary.

## Media masters

`tools.museum.public_media_master_capture` captures the three native shared
media slots: image, animation and content. It retains their complete selected
revision histories, original MASTER or WAIVER payloads, publication receipts,
recorded manifests and immutable external object/coverage records. Historical
hash candidates use the original association, manifest, selected records and
archive commitments. Current slots remain a separate observation.

PRESENT is a recorded selection status. It does not establish current archive
availability. WAIVED retains the original native Artist publication and waiver
scope. ABSENT means no selected head within the captured native slot history.
A media URI does not establish archival delivery.

The supported stored-media writer uses IPFS, Arweave or HTTPS source kinds with
their corresponding URI schemes. Broader typed or opaque historical manifests
remain explicit raw observations; they do not become supported master evidence
merely because an ABI tuple or inventory hash can be reconstructed.

The reader uses immutable `objectIdentity` and `coverage` getters to reconstruct
the original archive hash. It does not call current `requireCoverage` as a
condition for retaining old evidence. Later fixity or archive-family changes
therefore cannot substitute new bytes for the original commitment.

An empty inventory has a nonzero native inventory hash. Its master evidence
hash still includes an Artist association, but no slot selection retains that
association. A source-block empty-inventory candidate does not establish the
association at an earlier release. The assembly reports that gap explicitly.

## Prospective references

`tools.museum.public_prospective_reference_capture` captures the original
pre-sale publication host. It reconciles the complete collection
`prospectiveCount/At` history with publication events, immutable Publication and
Receipt structs, canonical payloads, retained execution declarations, definitions
and archive commitments.

The original payload retains the full Source preimage. Its source hash also
includes dependency gas values. The reader reconstructs those values from the
three original gas registrations and subsequent update histories. Current gas
and current source are reported separately.

The supported native profile describes one or two named simulation vectors,
declared STATIC still captures and a Windows/AMD64 environment inventory.
Reconstructing these bytes does not execute the browser, verify ZIP membership,
retrieve archives or establish executable dependency completeness. These
pre-sale simulations do not supply actual token renders, finalized entropy or
finality evidence.

If captured current pointers or source dependencies fail the deterministic
current-source preflight, currentSource is `not_evaluated` with explicit reasons.
Original publication payloads remain available for historical examination. An
unexpected RPC failure remains a capture failure; it is not absence evidence.

## Join to an unchanged V5 packet

`tools.museum.acquisition_preservation_v5` accepts an externally pinned
[attribution-enriched V5 assembly](museum-attribution-sanction-capture.md), a
master capture and a prospective-reference capture. It reconstructs all inputs
and reconciles their nine source transcripts, including common anchors, runtime
pins, overlapping log queries, headers and complete shared receipts.

The original provider configuration binds master target 6 and prospective
target 9 to the added captures. Supported shared dependencies must agree. The
assembly examines releases belonging to that original provider; a later
provider's release remains unresolved until its own configuration is captured.
This profile requires both configured producer hosts. It does not reinterpret
a zero prospective-host address as a captured empty history.

For each original ReleaseFloorReceipt, the assembly compares:

- Saved media evidence against exact native master preimages and inventory.
- Selected master and router-manifest heads strictly before the release.
- Saved reference evidence against its original Receipt and complete Source.
- The original source admission, source-set head and full release context.
- The prospective head and committed gas values at the release publication.

A matching record first published after the release, or replaced before it,
cannot establish the saved join. A replacement after the release preserves the
historical match. The comparison uses the original release publication, even
when a later paid sale reused that receipt. Manifest storage and manifest
selection events remain distinct; selecting a previously stored manifest does
not require a new storage event.

Missing original inputs remain unresolved. The join does not replace them with
current inputs or claim that historical authority, runtime or liveness checks
were executed. Provider log completeness and canonical chain mapping remain
trust assumptions, including in offline replay.

All original packet paths and payload bytes remain unchanged. The previous
manifest is retained at `inputs/attribution-v5-manifest.json`. The two added
capture trees are under `captures/media-masters/` and
`captures/prospective-reference/`. The report is
`preservation/assembly.json`; native correspondence is in
`preservation/native-join.json`.

All nineteen supplied requirements remain visible. Items 8 and 13 contain
partial native evidence. Native media slots do not supply a general mediaClass
mapping, and native prospective receipts do not authenticate V5's generic
capture/environment record labels. These generic fields remain supplied.
Institutional acceptance and complete source coverage remain separate.

## Offline commands

Use each module's `--help` and `profiles` commands to obtain its exact CLI and
definition pins. Capture requires public disclosure and explicit external
anchor/profile pins. Endpoints are read from process environment variables;
they are not retained in the output.

```powershell
python -m tools.museum.acquisition_preservation_v5 assemble --packet attribution-v5 --packet-hash <hash> --masters masters --masters-hash <hash> --references prospective --references-hash <hash> --disclosure public --output preservation-v5
python -m tools.museum.acquisition_preservation_v5 verify preservation-v5 --manifest-hash <hash>
python -m tools.museum.acquisition_preservation_v5 export-supplied-packet preservation-v5 --manifest-hash <hash>
```

Outputs require a new directory. Verification and supplied-packet export work
offline. `complete-packet` refuses a complete source-covered packet claim.
Reader size/history limits and unsupported current producer states cause
capture failure; they do not prove that records are absent. Synthetic fixture
replay verifies consumer consistency, not native EVM or actual-chain acceptance.
