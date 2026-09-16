# Offline BagIt hydration

The explicit `STREAM_BAGIT_HYDRATION_PROFILE_V1` derivative completes a verified
fetch-dependent [Stream bag](museum-bagit-ocfl.md) from locally supplied bytes.
It performs no network retrieval. It neither alters the original bag nor changes
its profile, input descriptor, source classification or evidence. The
[hydration profile](../schemas/museum/bagit/hydration-profile.json) is a
prospective, unregistered implementation document.

The caller supplies the original bag directory, its externally obtained
`stream-manifest.json` keccak256 hash, and a separate directory containing the
complete missing payload set at the original relative paths. The source must
be an original version 1 fetch-dependent bag. Already complete bags, partial
fulfillment, extra files, altered lengths and either incorrect digest reject.
Every supplied file must match its original exact length, SHA-256 and keccak256.
No retrieval URL, replacement commitment or new source assertion is accepted.

The derivative retains each embedded payload literally and adds the verified
missing bytes under `data/`. Every original tag file is copied byte for byte
under `provenance/source-bag/` with a `.original` suffix. In particular,
`fetch.txt.original` records the original retrieval declaration;
`tagmanifest-sha256.txt.original` retains its exact old tag commitments.
These are inert provenance files, not active fetch instructions or tag manifests.
They are included in the new root tagmanifest. There is no root `fetch.txt`.

The new canonical stream manifest uses mode `stream_bagit_hydrated_package`,
version `1`, the hydration profile hash and `sourceBagManifestHash`. It retains
the original input and qualification objects exactly, and records the fulfilled
paths, local byte supply, no network retrieval and no established archival
availability. Payload manifests retain the original declared commitments.
Bag-info retains all original values except `Stream-Self-Containment`, which
becomes `self_contained`. Original bagging date and packaging-tool references
remain original provenance; no new timestamp or tool authorship is invented.
The original bag bytes and original manifest hash remain independently
reconstructible from the derivative.

Verification first authenticates and reconstructs the retained original bag,
then repeats every fulfillment check and rebuilds the derivative. It compares
the complete expected file set and every canonical byte. Modified provenance,
reintroduced active fetch instructions, an incorrect original manifest anchor
or a second hydration layer reject. Filesystem verification also invokes the
existing verifier for every declared nested museum package; source/capture
bytes, format support and qualifications remain unchanged. As with the original
BagIt API, the lower-level in-memory functions establish byte fixity only.

A verified derivative can enter the existing immutable OCFL version workflow.
Its original work identity, bundle family and predecessor commitment remain
unchanged. A later OCFL version must name the previous *hydrated* bag manifest
hash in its new input predecessor, just as any other complete prior bag. A
fetch-dependent original cannot itself enter OCFL. Hydration does not rewrite
an existing OCFL version or create a storage-root repository service.

All file, aggregate-byte and path bounds remain those of the BagIt profile,
including the additional provenance bytes. Shared directory components must
use one exact spelling: `A/x` and `a/y` reject before writing on every platform,
while `A/x` and `A/y` remain valid. File/directory collisions, symlinks, junctions
and existing output directories also reject.

## Commands

Use the existing museum Python environment. Supply only the exact missing
relative payload paths in `provided`; obtain the source hash independently of
the bag being checked.

```powershell
python -m tools.museum.hydration D:/temp/source-bag D:/temp/provided D:/temp/hydrated-bag --source-manifest-hash <original-bag-hash>
python -m tools.museum.bagit verify D:/temp/hydrated-bag --manifest-hash <returned-hydrated-manifest-hash>
python -m tools.museum.ocfl version D:/temp/hydrated-bag D:/temp/object-v1 --bag-manifest-hash <returned-hydrated-manifest-hash> --created 2026-09-15T00:00:00Z --message "Locally fulfilled payloads"
python -m unittest tools.museum.test_bagit tools.museum.test_hydration -v
```

The CLI verifies the original nested semantics before creating a new output,
then checks written bytes. It reports complete local payload presence, not
retrieval success, public-chain acceptance, an authoritative render inventory,
archival availability, genesis registration or institutional ingest. An
externally admitted input remains externally admitted; synthetic data never
becomes recorded through hydration.

Focused offline tests cover exact source preservation, both independent
digests, missing/extra/wrong bytes, tag and provenance tampering, external
manifest anchors, nonrecursive dispatch, complete OCFL entry, no-overwrite CLI
behavior, shared-directory casing, the unchanged original worked profile and
literal retained recorded-account package replay. The latter uses a synthetic
transport fixture containing an authentic local-EVM recorded package; it does
not claim a newly captured dossier or a recorded preservation master.
