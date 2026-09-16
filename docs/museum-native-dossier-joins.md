# Typed native dossier joins

The V2 partial assembler replays concrete native readers against the original
source state of a verified [V1 partial assembly](museum-object-dossier.md).
It preserves that entire assembly unchanged under `base/`, retains every new
anchor, transcript and snapshot, and reports checked facts and unresolved
coverage separately. It does not emit full `OBJECT_DOSSIER_V1` conformance.

## Source adapters

| Kind | Reader | Scope |
| --- | --- | --- |
| `owner` | `OwnerCatalogSource` | All native/admitted types and complete history for one host and token. |
| `independent` | `IndependentCatalogSource` | All eight native types for one host and exact collection, or separate deployment scope `0`. |
| `ownership` | `OwnershipSource` | Complete bounded Core Transfer history reconciled with the token's source-block identity, lifecycle and owner. |
| `metadata` | `MetadataCatalogSource` | Native `recordTypeCount/At`, policies, complete generic record lanes and payload-pointer inventory for one host and nonzero collection. |
| `hosts` | `DossierHostsSource` | Every module in Core's current registry, plus its selected Metadata pointer, retaining all lifecycle statuses. |

The classes live in `tools.museum.owner_catalog_source`,
`independent_catalog_source`, `ownership_source`, `metadata_catalog_source`
and `dossier_hosts_source`. Each exposes `snapshot()` and `transcript()`, and
provides bounded capture/replay and profile-definition commands.

MetadataV1 scope `0` is a writer-grant scope, not a generic record scope.
Its native type catalog can be empty before types are admitted. The reader
retains all original subject hashes, historical receipts and schema-definition
commitments. It neither invents unknown token-subject preimages nor rechecks
today's writer permissions. Repeated content under different families retains
each record occurrence and native `(family, content hash)` pointer identity.
Typed script/media manifests and bundles remain separate native surfaces.

## Host and scope coverage

The host reader binds Core's registry and selected Metadata pointer, reads
the registry's complete append-only enumeration, and retains deprecated and
incident-revoked rows. Supported same-Core hosts yield explicit expected scopes:
owner token; independent deployment `0` and collection; Metadata collection.
Independent and Metadata head/count observations are compared with the
corresponding complete source snapshots. The owner reader supplies its own
event-derived type catalog because that host has no native type enumerator.

Unknown successor versions and changed runtimes remain unresolved rows. The
reader does not call a successor through an assumed V1 ABI. A selected Metadata
host outside the current registry remains visible. A foreign Core binding is
reported and excluded from this token's scope reads.

The registry is the set of modules registered through that registry instance.
It does not enumerate alternate historical registries or all compatible
unregistered deployments. Owner and independent writes do not require Core
selection or registry membership. Therefore even complete current-registry
coverage leaves the global applicable-host denominator unresolved. A missing
source is not an authenticated empty lane.

## Exact source agreement

`tools.museum.object_dossier_native` accepts only the five known reader kinds.
It reconstructs each snapshot using its retained transcript and compares the
exact result. Assertions inside a supplied snapshot cannot replace replay.

Every source must agree with the verified original chain, Core, block hash,
block number, timestamp, state root, environment and deployment-evidence hash.
Token, collection and observed serial/lifecycle/burn/owner facts are joined
where the reader observes them. Core runtime and all shared address pins must
agree, including the original capture's pins and dynamically read chunk/module
code. Identical RPC requests cannot return different results across retained
original evidence and new readers. Distinct legitimate schema/store addresses
keep their own bindings; the assembler does not force them into one registry.

Records are preserved by host, scope, record type, index and record hash.
The report references every original record and whole native lane, including
other-subject records that establish its denominator. A collection head is
never relabeled as a token-filtered head. Reused payload bytes do not merge
record occurrences.

Synthetic inputs retain `synthetic_only` status. Caller-admitted RPC inputs can
establish `verified_within_source_profile` facts, with complete registered-scope
coverage separately reported. These statuses do not assert genuine native
capture acceptance, consensus, legal title or full dossier completeness.

## Input and commands

The new input directory contains `inputs.json` and exactly the files it names
under `data/`. The canonical input envelope has these fields:

- `profile`: `STREAM_MUSEUM_OBJECT_DOSSIER_NATIVE_INPUTS_V1`
- `version`: `1`
- `disclosure`: `public`, an explicit caller declaration
- `sourceState`: exactly the original V1 manifest's source state
- `sources`: rows sorted by unique `id`

Each row has `id`, `kind`, `provenance`, `anchorPath`, `anchorHash`,
`transcriptPath`, `transcriptHash`, `snapshotPath` and `snapshotHash`. Paths are
relative to `data/`; hashes are external Keccak-256 commitments to exact bytes.
`provenance` is `synthetic_fixture` or explicit `trusted_rpc` admission. The
snapshot must replay with that same provenance. Repeated logical host/scope
sources, unknown fields, unsafe paths, extra files and inconsistent pins fail.
The caller also supplies the envelope's external commitment.

```powershell
python -m tools.museum.object_dossier_native_assembly build --base work/object-dossier-partial --base-hash <external-v1-manifest-hash> --native work/native-inputs --native-hash <external-input-hash> --output work/object-dossier-v2
python -m tools.museum.object_dossier_native_assembly verify work/object-dossier-v2 --manifest-hash <returned-v2-manifest-hash>
python -m tools.museum.object_dossier_native_assembly definitions --output schemas/museum/object-dossier --check
```

Verification reconstructs the original V1 assembly and every typed source, then
compares the complete V2 directory. Retained implementation files are inert
provenance, not executed reconstruction tools or a complete runtime archive.
V1 profiles, schema files, outputs and retained fixtures remain unchanged.

## Remaining acceptance

The broad owner, independent and token COMPLETE/HEADS requirements remain
unresolved until applicable host, family and scope completeness is established.
MetadataV1 alone does not cover every token attestation host. Transfer
provenance additionally needs its covering LTA-EVENT-HISTORY archive and all
applicable accession/deaccession title-binding correspondence. A recorded title
binding does not establish legal validity or physical custody.

Capture8 does not contain these complete source transcripts. An empty new input
set can demonstrate preservation and missing-source reporting, but cannot
upgrade its original requirement coverage. Genuine native source captures,
full typed evidence integration, the acquisition packet and institutional
acceptance remain separate outstanding work.

The capture8 empty-input V2 diagnostic built and reconstructed with network
access disabled: 534 files, 30,944,232 bytes, manifest
`0x3451c2250bca5681a5fe1a650fb148691144aa3f2e1719c70be14e945100d8b1`.
It retains all original V1 files, reports zero new native checks and leaves
the native source/host/archive requirements unresolved. This result is not a
positive native-capture or complete-dossier acceptance case.
