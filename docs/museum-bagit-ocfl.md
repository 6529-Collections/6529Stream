# BagIt transport and immutable OCFL versions

The exporter implements a deterministic public packaging profile for the
[CMC-PACKAGING](collection-metadata-contract.md#dossier-and-export-packaging-cmc-packaging)
transport requirements. It emits BagIt 1.0 files and maps complete bags into
OCFL 1.1 objects. These formats preserve bytes and version history; they do not
establish onchain admission, source authorship, an authoritative complete
render inventory, archival authority or institutional acceptance.

The prospective [profile](../schemas/museum/bagit/profile.json) and
[worked bag](../schemas/museum/bagit/worked-bag/stream-manifest.json) are explicit
new implementation documents. They have not been registered as the genesis
`STREAM_BAGIT_PROFILE_V1` document. The worked input is synthetic. Its sample
citation, schema and tool commitments are fixture values, not captured records.
The older museum package versions and their qualification bytes remain exact.

`tools.museum.bagit` accepts a canonical `stream_bagit_input` version 1 descriptor
and the exact set of embedded payload bytes. An external input hash binds the
build. The descriptor identifies the intended `OBJECT_DOSSIER_V1` or
`STATE_EXPORT` use, public disclosure classification, source mode, a canonical
work citation with typed `fin`, `snap` or `chain` qualifier, bagging date,
bundle-manifest and schema paths/hashes, schema ID, scoped record-chain heads,
packaging-tool name/version/source hash, previous bag manifest hash, payload
rows, and any nested semantic packages. This is an input contract, not an
implementation of the entire dossier or state-export record schema. Actual
record/schema/authority admission remains the caller's separate prerequisite;
a bundleKind string does not supply it.

Every payload row commits its relative path, exact length, SHA-256 and
keccak256 digests, render-critical classification, and embedded/fetch delivery.
The bundle manifest and schema must be embedded. Render-critical payloads must
be embedded. This enforces the supplied inventory; it cannot detect an omitted
render dependency or prove the operator's public classification.

The bag retains all embedded payloads without rewriting them. It contains:

- `bagit.txt`, with BagIt 1.0 and UTF-8 declarations;
- `manifest-sha256.txt` and `manifest-keccak256.txt`, each covering every declared
  payload exactly once;
- `bag-info.txt`, with External-Identifier, Bagging-Date, Payload-Oxum,
  Stream-Schema-Id, Stream-Schema-Hash and Stream-Self-Containment;
- canonical `stream-manifest.json`, retaining the input descriptor, prospective
  profile commitment and explicit qualification;
- the exact prospective profile bytes and `tagmanifest-sha256.txt`, covering all
  tag files except the tagmanifest itself.

The externally supplied hash of `stream-manifest.json` is the bag verification
anchor. The verifier reconstructs all canonical tag bytes and checks every
embedded payload. Changed tags, file inventories, sizes and either digest fail.
There is no circular hash: the input commits payloads; tags commit that input;
the tagmanifest commits the other tags and excludes itself.

A noncritical fetch row additionally identifies a content-addressed URI and two
embedded external-admission evidence files, separately labeled `onchain` and
`permanent_external`, with exact hashes. This version supports the existing
CIDv1/raw/sha2-256/base32lower IPFS profile and canonical Arweave transaction IDs;
it does not accept mutable HTTP URLs, other CID codecs, paths or gateways.
An Arweave transaction ID is never treated as the payload digest. Evidence-file
fixity is checked; receipt authority and dual-family availability remain outside
this transport verifier. No URL is fetched. Such a bag reports
`fetch_dependent` and is incomplete under BagIt until the missing payloads are
supplied; it is never reported as a complete valid bag. Complete all-embedded
inputs are supported. The separate [offline hydration derivative](museum-bagit-hydration.md)
fulfills the exact missing bytes without changing this original profile.
Absent optional STATE_EXPORT token-data bytes do not create a fetch dependency.

A declared nested museum v2 package must be wholly embedded, including its
manifest, source/capture bytes, sidecars, schemas and interpretation dependencies.
Filesystem build/verification invokes the existing package verifier against
those exact retained bytes. It preserves original source qualifications and
rejects a synthetic package labeled as recorded. The lower-level in-memory
`build_bag` and `verify_bag_files` functions establish transport fixity only;
`verify_bag` also performs this nested semantic replay. No hidden network loader
or media retriever is introduced.

## OCFL mapping

The [repository exchange workflow](museum-repository-exchange.md) adds public
`export`, `inspect` and selected-version `import` commands over this mapping.
It replays every declared semantic package across the complete object history
and atomically restores the selected bag's exact original payloads and tags.

`tools.museum.ocfl` creates a new object directory for each version operation;
it never mutates an existing object, version or storage root. A successor takes
the exact previous object and an external inventory hash. Its bag predecessor
must equal the prior bag's stream-manifest hash. The canonical work citation
without the changing record-state qualifier is the stable OCFL object ID;
each exact qualified citation remains in that version's bag-info/manifest.
The bundle family stays fixed, and supplied UTC version timestamps must increase.
Bagging and version dates remain distinct caller-supplied facts.

The object uses `0=ocfl_object_1.1`, SHA-256 content addressing, canonical
`inventory.json` plus SHA-256 sidecars at the root and every version, complete
version states and SHA-512 supplementary fixity. Exact bag files appear at
logical `bag/` paths, including original `data/` payloads and tags. Identical
content is reused by digest; prior physical content, inventory bytes and version
state remain unchanged. Record-chain heads remain in the retained stream
manifest, whose bytes are covered by standard OCFL fixity. Semantic chain heads
are not mislabeled as file digests or invented OCFL digest algorithms.

The verifier checks every historical inventory/sidecar, complete physical and
logical inventories, content digests, exact retained bags, citation/family,
predecessor and chronology. It rejects rewritten old state, missing/orphan files,
future-version references and corrupted content. OCFL ingestion currently
requires complete bags: original all-embedded bags or the explicit verified
hydration derivative. Incomplete fetch-dependent bags return an explicit error.
The object verifier establishes byte/version correctness, while
the BagIt CLI's build/verification path also runs any nested semantic replay.
No OCFL storage-root layout, repository API, concurrent writer coordination or
named-repository ingest is implied.

Both profiles enforce 8,192 files, 96 MiB aggregate bytes, 2 MiB descriptors and
inventories, 1,024 UTF-8 path bytes and 64 OCFL versions. Paths must be portable,
relative, free of controls/percent escapes and file-directory/case collisions.
Symlinks and Windows junctions are rejected. Writes require a new destination.
These implementation bounds are explicit; they do not redefine onchain limits.

## Offline commands and checks

Use the existing museum Python environment. For the synthetic worked input:

```powershell
python -m tools.museum.bagit build schemas/museum/bagit/worked-input.json schemas/museum/bagit/worked-payload D:/temp/example-bag --description-hash <worked-pins.inputHash>
python -m tools.museum.bagit verify D:/temp/example-bag --manifest-hash <worked-pins.bagManifestHash>
python -m tools.museum.ocfl version D:/temp/example-bag D:/temp/example-object-v1 --bag-manifest-hash <worked-pins.bagManifestHash> --created 2026-09-15T00:00:00Z --message "Synthetic example"
python -m tools.museum.ocfl verify D:/temp/example-object-v1 --inventory-hash <returned-inventory-hash>
python -m unittest tools.museum.test_bagit -v
```

A successor uses a new bag with its `predecessor` field set to the exact previous
bag hash, and supplies `--previous` plus `--previous-inventory-hash`. Always use
a new output directory. The worked pins are in
[worked-pins.json](../schemas/museum/bagit/worked-pins.json).

The focused tests cover exact manifests, tag/payload tampering, missing/extra
files, disclosure and citation rejection, fetch identity/evidence constraints,
critical embedding, optional STATE_EXPORT bytes, CLI/no-overwrite behavior,
literal nested-package semantic replay and synthetic-to-recorded rejection,
two-version deduplication, chronology/identity/predecessor rejection, and rehashed
historical-state corruption. Full dossier schemas, actual record admission,
archival availability, genesis registration and named institutional
repository ingest remain separate work.

The byte layout follows [RFC 8493](https://www.rfc-editor.org/rfc/rfc8493.html)
and the [OCFL 1.1 specification](https://ocfl.io/1.1/spec/). These references define
transport/storage formats; their use is not evidence of institutional acceptance.
