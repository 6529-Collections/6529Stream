# Assemble a unified Museum evidence dossier

Object dossier V4 assembles the existing canonical semantic export, recorded
physical-production statements, and General institutional or physical-transfer
statements into one independently pinned package. Verification replays the
original sources and reconstructs every derived byte offline.

The required base is the [complete owner-family semantic export
V2](../tools/museum/CANONICAL-SEMANTIC-EXPORT-V2.md). It already retains object
dossier V3, acquisition packet V10, native OwnerRecords/accession evidence and
the original semantic selection. V4 reuses that work. The original nineteen
packet groups and forty-nine requirement assessments remain unchanged.

This is a usable evidence assembly, with explicit gaps. It does not claim a
complete accepted dossier, physical performance, legal title, current custody,
institutional acceptance, profile registration or production readiness.

## Inputs

| Input | Required | Meaning |
| --- | --- | --- |
| Canonical semantic export V2 | Yes | Existing native dossier, owner families, selection and model closure |
| [Recorded physical production V1](museum-recorded-physical-production-v1.md) | No | Original Artist statements and their qualified production graph |
| [General semantic dossier V1](museum-general-semantic-v1.md) | No | Original institutional, estate or curatorial assertions |
| [Recorded physical transfer V1](museum-recorded-physical-transfer-v1.md) | No | Qualified Acquisition or TransferOfCustody statements and the complete original General dossier |

Supply each directory with its separately retained manifest commitment. A hash
calculated only from received files detects subsequent changes but does not
authenticate their origin. Each optional directory and its pin must be supplied
together. Restricted disclosure is unsupported and fails before source reads.

The transfer package already contains its full General dossier. V4 references
that exact child; it does not require a duplicate standalone General package.
If both are supplied, they must identify the same complete original package.
Original selections, withheld assertions, unsupported records, authority,
historical qualifications and model dependencies survive assembly.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md). Existing source
builders prepare and verify the packages above. After reviewing their original
selections, assemble them with explicit pins:

```powershell
python -m tools.museum.canonical_object_dossier_v4 assemble --canonical <semantic-v2-directory> --canonical-hash <semantic-v2-manifest-hash> --production <production-directory> --production-hash <production-manifest-hash> --transfer <transfer-directory> --transfer-hash <transfer-manifest-hash> --disclosure public --output <new-dossier-directory>
python -m tools.museum.canonical_object_dossier_v4 verify <dossier-directory> --manifest-hash <dossier-manifest-hash>
python -m tools.museum.package_v2 verify <dossier-directory> --manifest-hash <dossier-manifest-hash>
```

Omit an optional family when evidence is unavailable. The assembly records its
absence. To include General assertions without a physical-transfer package, use
`--general <directory> --general-hash <manifest-hash>`.

The Python entrypoint is `canonical_object_dossier_v4.compose`. It accepts the
canonical file map and manifest hash, optional `production_files` /
`production_hash`, `general_files` / `general_hash`, and `transfer_files` /
`transfer_hash`, with `disclosure="public"`. `verify` accepts the complete output
file map and its external manifest hash.

Output directories must be new, have existing parents and remain outside input
directories. The existing atomic publication helper reads staged bytes back
before publishing. Failed verification does not publish a partial package.

## Read the joins and gaps

The supplemental ledger keeps family evidence separate from the unchanged
acceptance assessment. No requirement is promoted by adding a family. Source
replay, a selected statement and institutional acceptance are different facts.

The version-local observation join compares original source observations:

- Same-anchor runtime bytes, successful getter answers, overlapping header
  fields, receipts and event coordinates must agree. A contradiction fails.
  Different tip blocks cannot hide contradictions about the same retained
  historical block hash.
- Observed matching logs cannot disappear from a retained covering query or
  receipt. Duplicate occurrences remain in the original source packages.
- Missing header or transaction-placement detail stays explicitly missing.
  An observed reverted receipt may retain an empty log list; it is not rewritten
  into a successful receipt.
- Different source timing or configuration remains a distinct original source
  and is classified as unjoined. It does not silently become evidence for the
  canonical packet's selected state.
- Host-specific deployment-evidence commitments remain separate. Matching
  declared state does not require unrelated hosts to share one evidence hash.

Statement applicability uses original subject declarations. A matching
collection does not prove that a physical object belongs to the dossier's
token. Token applicability requires the exact original token subject; media
scope remains media scope unless original evidence establishes the relation.
Unselected or withheld statements cannot acquire authority through packaging.

Graphs remain in separate package namespaces. Equal entity IRIs in Artist and
General declarations are not enough to merge physical objects, events or
people. Names, wallet addresses, production status and token transfers do not
establish physical identity, event performance, title, custody or accession.

The `complete` command verifies the package and then refuses completion while
the adopted requirements remain unresolved. Read the retained assessment and
supplemental missing-evidence information when planning additional evidence.

## Existing BagIt and OCFL delivery

V4 is supported by the existing nested-package verifier. It can therefore be
embedded unchanged in a standard [BagIt state export](museum-bagit-ocfl.md) and
round-tripped through [repository exchange](museum-repository-exchange.md).
This uses existing transport and OCFL profiles; it creates no new evidence
framework or registration claim.

In an existing BagIt input descriptor:

1. Use `bundleKind: "STATE_EXPORT"`, explicit public disclosure and the retained
   canonical token citation's `qualified` string (the original dossier stores
   `citation` as an object). Keep the source's actual provenance qualification.
2. Embed the entire V4 package under one prefix, such as `dossier/`, and list
   every exact payload with its existing size and hash commitments.
3. Declare `semanticPackages: [{"prefix": "dossier", "manifestHash": "<external V4 pin>"}]`.
   This causes semantic replay during bag verification and repository exchange.
4. Supply the existing required bundle/schema/tool commitments and bagging
   metadata from the actual retained inputs. Transport tags do not authenticate
   a tool archive or register a schema. Keep those evidence gaps explicit.

Then use the existing `tools.museum.bagit` build/verify commands and
`tools.museum.repository_exchange` export/inspect/import commands. Retain both
the bag manifest hash and OCFL inventory hash separately. Restoring an explicit
historical version preserves all original package bytes and qualifications.

Bag transport success is not a promotion of any of the forty-nine assessments.
Full render inventory, source authentication, native execution, preserved
runtime/tool evidence and named institutional acceptance remain separate.

## Validation

```powershell
python -m unittest tools.museum.test_canonical_dossier_observations_v4 tools.museum.test_canonical_object_dossier_v4 -v
```

Concrete offline fixtures exercise original package reconstruction. They are
synthetic RPC evidence, not a deployed-chain capture or an institutional review.
