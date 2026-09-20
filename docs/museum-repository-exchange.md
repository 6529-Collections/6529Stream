# Export and restore an exact historical Museum bag

`tools.museum.repository_exchange` provides a complete local round trip from a
pinned BagIt bag to an immutable OCFL object and back to a selected historical
bag. The restored directory contains exactly the original payloads and tags.
The command prints its receipt separately; it adds no receipt to the bag.

This implements the local recovery path associated with
[CMC-PACKAGING rule 4](collection-metadata-contract.md#dossier-and-export-packaging-cmc-packaging)
and [MSM-EXPORT rule 11](museum-semantic-mapping.md#9-export-deterministic-verification-and-archival-delivery-msm-export).
It reuses the existing profiles and leaves the original 29 genesis definitions
unchanged. It does not establish full conformance with either specification,
current source authority or a named institution's ingest requirements.

## Inputs and verification

| Command | Required external commitments | Result |
| --- | --- | --- |
| `export` | Bag manifest hash; previous inventory hash when appending | New immutable OCFL tree and JSON inspection |
| `inspect` | OCFL inventory hash | Full-history verification and JSON inspection |
| `import` | OCFL inventory hash, explicit `vN`, selected bag manifest hash | Exact historical bag directory and JSON receipt |

Obtain the expected commitments from the separately retained handoff or other
trusted channel. A digest calculated solely from the supplied files is useful
for comparison, but does not independently authenticate their origin.

The workflow accepts three existing closed formats:

- [Complete standard BagIt bags](museum-bagit-ocfl.md), with replay of every
  declared nested semantic package. A bag declaring zero semantic packages
  reports that zero; this does not imply a complete Museum semantic export.
- [Hydrated bags](museum-bagit-hydration.md), preserving their exact original
  source tags and inert fetch instructions under the provenance directory.
  Incomplete fetch-dependent inputs must be hydrated with local bytes first.
- [Scoped evidence dossiers](museum-scoped-dossier.md), including their existing
  source, semantic export, media and dossier reconstruction checks. Their
  original scope remains explicit; they do not become full object dossiers.

Every command that consumes an object checks its entire physical and historical
inventory before replaying all declared semantics. This includes historical
versions other than the selected restore target. A self-consistent transport
wrapper around invalid semantic evidence fails. Neither an operator database
nor a network service is used. Retained tool source remains inert; only the
installed verifier runs.

Import requires an explicit canonical version such as `v1` and its independent
bag pin. It rejects `head`, `latest`, `v01`, absent versions and mismatching
pins. Restoring an older version does not select a new current record state or
claim that its historical contents meet current conformance requirements.

## Commands

Run from the repository root in the [Museum Python environment](../tools/museum/README.md).
The following PowerShell example uses the existing **synthetic** worked bag;
its fixture commitments are not actual onchain admission evidence. Create an
empty task-owned parent directory, then build, export, inspect and restore:

```powershell
New-Item -ItemType Directory -Path out/exchange-demo
$pins = Get-Content -Raw schemas/museum/bagit/worked-pins.json | ConvertFrom-Json
python -m tools.museum.bagit build schemas/museum/bagit/worked-input.json schemas/museum/bagit/worked-payload out/exchange-demo/bag --description-hash $pins.inputHash
$export = python -m tools.museum.repository_exchange export out/exchange-demo/bag out/exchange-demo/object-v1 --bag-manifest-hash $pins.bagManifestHash --created 2026-09-20T00:00:00Z --message "Synthetic recovery example" | ConvertFrom-Json
python -m tools.museum.repository_exchange inspect out/exchange-demo/object-v1 --inventory-hash $export.inventoryHash
python -m tools.museum.repository_exchange import out/exchange-demo/object-v1 out/exchange-demo/restored-v1 --inventory-hash $export.inventoryHash --version v1 --bag-manifest-hash $pins.bagManifestHash
python -m tools.museum.bagit verify out/exchange-demo/restored-v1 --manifest-hash $pins.bagManifestHash
```

Keep the returned inventory hash with the handoff. A successor uses a separately
built bag whose descriptor's `predecessor` is the exact previous bag manifest
hash, the same work identity and bundle family, and a strictly later version
timestamp. The previous object remains untouched:

```powershell
python -m tools.museum.repository_exchange export <successor-bag> <new-object-v2> --bag-manifest-hash <successor-bag-hash> --created 2026-09-21T00:00:00Z --message "Superseding export" --previous <object-v1> --previous-inventory-hash <inventory-v1-hash>
python -m tools.museum.repository_exchange import <object-v2> <restored-original-bag> --inventory-hash <inventory-v2-hash> --version v1 --bag-manifest-hash <original-bag-hash>
```

The Python API exposes `export_bag`, `inspect_object` and `import_version` with
the same required inputs. Export and inspection return an `Inspection` holding
the verified `ObjectVersion`, ordered `Version` objects and a JSON-ready report.
Each `Version` retains the complete original `Bag`. Import returns a JSON-ready
receipt identifying the supplied object head and separately selected version.

## Publication and bounds

Outputs must be new directories with existing parents, outside every input
directory. Symlinks, junctions, unsafe bag paths, extra files and undeclared
empty directories fail validation. Source directories are never modified.
After all source and semantic checks, the output is staged beside its final
destination and read back byte-for-byte. One atomic no-replace rename publishes
the completed directory. A destination created concurrently causes failure,
including an empty directory; it is not replaced. Failed staging or publication
cleans up the temporary tree without publishing partial output.

Publication supports Windows and Linux with `renameat2(RENAME_NOREPLACE)`.
Other platforms or filesystems without this primitive fail closed. Inspection
does not require publication support. Atomic visibility does not imply durable
storage after a power failure, concurrent repository-writer coordination or an
OCFL storage-root layout.

The existing bounds remain 8,192 physical files, 96 MiB per object, 2 MiB per
descriptor/inventory and 64 versions. The exchange also limits cumulative
logical bag replay to 32,768 file occurrences and 384 MiB across all versions,
including repeated content. Only one replay directory exists at a time. These
local operational bounds may reject an otherwise valid larger OCFL history;
they do not alter a registered profile or onchain limit.

Reports distinguish exact supplied bytes and successful declared semantic
replay from source authentication, current conformance, full dossier acceptance
and institutional ingest. All four latter claims remain false. Source
admission, chain-state completeness, authoritative render inventory and named
repository/practitioner evidence remain separate requirements.

## Validation

```powershell
python -m unittest tools.museum.test_repository_exchange tools.museum.test_bagit tools.museum.test_hydration tools.museum.test_dossier -v
```

The focused exchange tests cover exact two-version restoration, retained
deduplicated bytes, both external pins, historical tampering, semantic failure
behind valid transport, hydrated provenance, scoped dossier reconstruction,
logical replay bounds and failure-safe publication. The scoped source fixture
retains its existing local-chain qualification; it is not public-testnet or
institutional acceptance evidence.
