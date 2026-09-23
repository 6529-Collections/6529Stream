# Museum genesis schema catalog

The [generated catalog](../schemas/museum/genesis/catalog.json) inventories the
29 exact names in [CMC-GENESIS-SCHEMAS](collection-metadata-contract.md).
The [admission plan](../schemas/museum/genesis/admission-plan.json) contains
prospective registry inputs. Neither file is evidence of registration, deployment
admission, full family implementation, institutional acceptance or readiness.

## What the catalog checks

Each canonical name has a JSON Schema document, its exact keccak256 and SHA-256,
its definition/interpretation source, at least one worked example, and an explicit validation
scope. The [example index](../schemas/museum/genesis/example-index.json) records
the exact example bytes and their synthetic or supplied-data provenance.
The generator compares the closed name list and order to the normative CMC
table. It rejects missing definitions, invalid examples, remote schema references
and conflicting same-name account-profile schema bytes.
The Rights generator has no Python semantic validator; its entry identifies the
native Solidity interpreters separately and does not claim to execute them.

The original 19 canonical schema files retain their bytes. The new definitions
cover `MASTER_WAIVER`, `OBJECT_DOSSIER`, `ACQUISITION_PACKET`, `PREMIS_V3_PROFILE`,
`REFERENCE_RENDER`, `METRIC_SSIM`, `IIIF_P3_MIN`, `LIDO_PROFILE`, `BAGIT_PROFILE`
and `COLLECTION_IDENTITY` under their exact CMC names. Related narrower profiles
are listed as references and never counted as substitutes. In particular, the
existing BagIt implementation-profile object is preserved; it is not itself the
new canonical JSON Schema document and is not registered a second time under
the same identifier with a different kind.

The PREMIS, LIDO and BagIt schema bytes commit their complete crosswalk or
element rules. Their worked profile values demonstrate the definition; separate
validators check the retained LIDO XML and BagIt/OCFL examples. A valid profile
definition does not establish that every described conversion is implemented.

## Generate and verify

Use the repository's pinned Python dependencies. These commands run offline:

```text
python -m tools.metadata.collection_identity_profile --check
python -m tools.metadata.genesis_preservation_profile --check
python -m tools.metadata.genesis_dossier_profile --check
python -m tools.metadata.genesis_premis_profile --check
python -m tools.metadata.genesis_iiif_profile --check
python -m tools.metadata.genesis_packaging_profile --check
python -m tools.museum.genesis_catalog --require-complete
python -m tools.museum.genesis_catalog --check --require-complete
python -m unittest tools.museum.test_genesis_catalog
```

Omitting `--check` regenerates only that generator's outputs. A catalog generated
without `--require-complete` can describe partial source coverage; its
`sourceSetComplete` and `missing` fields remain explicit. The complete-source
flag means all 29 schema documents and worked examples passed local checks.
It is not a conformance or deployment gate.

## Registry admission recipe

The plan starts with the exact `RAW_BYTES` bootstrap and `RFC8785_JCS`
definition, then the canonical schemas and required existing companion
declarations. Every entry includes its source path, kind, schema/document ID,
whole-document hash, total length, canonicalization declaration, zero predecessor,
and ordered chunk offsets, lengths and hashes. A chunk is at most 8,192 bytes;
every nonfinal chunk is exactly 8,192 bytes. The plan enforces the existing
64-chunk, 524,288-byte document limit.

All definition bytes are canonical JSON. Their *registry declarations* still
differ: native typed Work, Rights, Conservation, Owner Notice and Notarization
readers require their schema/profile documents to declare `RAW_BYTES`; the
existing Loan, Valuation, Condition and institutional/semantic readers require
their schemas to declare `RFC8785_JCS`. The plan preserves these requirements.
It does not convert bytes or uniformly rewrite declarations.

For an exact frozen plan, the integration recipe must:

1. Read any existing document with the proposed ID. Reuse it only if its kind,
   original bytes, hash, length, canonicalization, predecessor and ordered chunks
   match. A different existing definition blocks that ID; preserve its meaning
   and allocate an explicitly new version through the appropriate design process.
2. Publish every exact chunk to the selected ContentAddressedStore and retain
   its index. Repeated chunks may share storage, but every ordered occurrence
   stays in the document's chunk list.
3. Use the original SchemaRegistry registration transition and the authorized
   class-1 Safe/Executor path. The generator neither signs nor submits anything.
4. Read back the document, complete bytes, length and each stored chunk at the
   receipt block. Retain chain, registry, Store, transaction and block identities
   in a new evidence packet before claiming admission.

This replaces a single-chunk assumption in prospective recipe inputs. It does
not increase any record payload bound: typed Artist/Notarization payloads retain
their own 8,192-byte limits, while generic General payloads have the separately
implemented 24,576-byte carrier. Large dossier manifests are external hash-bound
artifacts, not automatically on-chain payloads.

## Remaining implementation and acceptance boundaries

- Collection identity validation joins five normative strings to supplied Core
  identity and artist-display context. The renderer inspected at integration
  commit `6292287bdabe1d2452f11b1254ced325e259b731` does not yet emit that
  component. Supplied examples do not prove renderer output or chain state.
- PREMIS definition coverage does not complete a broad PREMIS emitter. The
  retained PREMIS XSD is byte-pinned; LoC authority URIs and CMC labels are
  declared without claiming a retained, authenticated LoC vocabulary snapshot.
  Only the primary-source-confirmed `ing`, `mig` and `val` term identifiers are
  resolved. Other authority term URIs and the local conservation term's
  `closeMatch` remain explicit gaps before full vocabulary admission.
- Archival IIIF validation checks the mandatory Presentation 3 core, painting
  content-addressed locators and supplied media commitments. It permits additional
  Presentation fields and operational services. It does not fetch bytes, validate
  every extension, prove availability or establish viewer interoperability.
- The existing OCFL mapper preserves record heads in the bag's exact
  `stream-manifest.json` content. A direct record-head inventory fixity supplement
  from the CMC packaging table remains an explicit implementation gap.
- Broad dossier and acquisition validators check supplied-data consistency.
  Inventories retain native scope/family lanes, including other subjects in the
  same lane, and preserve opaque `bytes32` record-family IDs. Chain-step checks
  dispatch to General's distinct preimage or the shared Metadata/Owner/Independent
  preimage. Selected packet references have separate target-subject checks.
  Complete chain regeneration, event-history completeness, signature/authority
  evidence, all underlying artifacts, named repository ingests, practitioner
  review and wider release acceptance remain separate.
- The original semantic-export V1 worked shape is explicitly `incomplete` and
  `not_evaluated`. Later exporter versions retain their own identities; none is
  silently substituted for the V1 genesis definition.

The catalog's admission observations are empty. Synthetic test registration
and source-file presence cannot fill them. Current maturity remains governed by
[status](status.md), [known blockers](known-blockers.md) and
[release readiness](release-readiness.md).
