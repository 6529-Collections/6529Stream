# Object-dossier inventory and partial assembly

The adopted [object dossier](collection-metadata-contract.md#object-dossier-export-cmc-object-dossier)
contains the token's complete applicable evidence, including collection
conservation records, ownership history, finality and content proofs, entropy,
attribution, render inputs and the expanded semantic package. The
[selected-media dossier](museum-scoped-dossier.md) establishes a narrower
selection. Its successful verification does not fill the remaining requirements.

This implementation adds a fixed requirements inventory, a bounded supplied
component format, a replayable partial assembly from the
[actual token capture](museum-token-capture.md), and a native render-inventory
reader. It does not expose a full `OBJECT_DOSSIER_V1` conformance result.

## Requirement accounting

`tools.museum.object_dossier_inventory` generates
[requirements.json](../schemas/museum/object-dossier/requirements.json).
The denominator comes from CMC-OBJECT-DOSSIER, CMC-PACKAGING and MSM-EXPORT,
including separate packaging, preserved-tool and institutional gates. It is
never derived from the components a caller happened to supply.

Every requirement remains in the report with one of these states:

| State | Meaning |
| --- | --- |
| `verified` | A concrete internal adapter checked the evidence for this requirement. |
| `supplied_unverified` | Exact supplied bytes and their commitments agree; their canonical meaning remains unverified. |
| `missing` | Required evidence has not been provided or verified. |
| `not_applicable` | A supported verified work classification excludes a conditional requirement. |

Unknown work classification leaves script applicability unresolved. Authenticated
absence, an explicit waiver and a missing input are different facts. An empty
directory or a caller's `complete` flag proves none of them. Requirement coverage
alone is not protocol conformance or institutional acceptance.

## Capture8 partial assembly

`tools.museum.object_dossier` replays the committed token fixture before it
assembles anything. It checks the paid-mint transaction, six exact source-block
Core views, token subject, registered semantic selection and unchanged V3,
BagIt and OCFL commitments through the existing token verifier.

The assembly retains both original compressed fixture files and the complete
unchanged scoped bag. Its canonical manifest commits to every file, the exact
source identity and block, the fixed requirement report and inert implementation
source snapshots. Source code retained as provenance is never executed.
Verification repeats the source replay and reconstructs the exact assembly.
Implementation snapshots use UTF-8 with LF line endings; original capture files
remain byte-exact. Later source changes cannot replace the captured inert snapshot.

Only canonical token identity is currently a complete dossier requirement
proved by this adapter. The verified narrower evidence is reported separately:

- The semantic export contains one exact token subject and one selected lane.
  It does not enumerate every applicable record family.
- The PNG matches token data and actual metadata. It does not define the
  authoritative render inventory.
- The actual paid-mint receipt contains one Core ownership hop. It does not
  establish complete mint-to-anchor history or its covering event-history snapshot.

The assembly is a diagnostic directory, not an adopted object-dossier bag. Its
claims are closed and explicitly partial. The existing scoped bag, profiles
and retained fixture bytes remain unchanged.

```powershell
python -m tools.museum.object_dossier inspect schemas/museum/dossier/token-local-fixture --fixture-hash 0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425
python -m tools.museum.object_dossier build schemas/museum/dossier/token-local-fixture work/object-dossier-partial --fixture-hash 0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425
python -m tools.museum.object_dossier verify work/object-dossier-partial --manifest-hash <returned-manifest-hash>
```

The capture8 diagnostic build and independent rebuild completed with manifest
`0x909ba0da133b1d96ca3edb6bd5a0ae29ca6111226195f1c01391945b2887b443`:
521 files and 30,600,101 bytes. Its report retains all 49 requirements, verifies
identity, and leaves the other 48 unfulfilled, including two with unresolved
script applicability. These counts describe this adapter's admitted evidence,
not the total implementation status of the protocol.

## Supplied components

An optional supplied directory contains `components.json` and `data/` files.
The caller supplies the envelope's external Keccak-256 commitment. The closed
[component schema](../schemas/museum/object-dossier/components-schema.json)
requires exact chain, Core, collection, token, serial, subject, block and
qualified citation agreement with the verified source. Each row identifies its
requirement, versioned profile, occurrence ID, path, size and two byte hashes.
The envelope must explicitly declare `disclosure: public`; this declaration
does not itself prove permission to disclose the supplied contents.

The reader rejects unknown requirements, status/completeness/absence fields,
extra or missing files, path aliases and traversal, changed hashes, mixed
blocks and foreign subjects. It preserves separate occurrences of identical
bytes, including their distinct requirement labels. It does not execute a
component or fetch a URI. A versioned profile name is a claim to be checked by
a future supported canonical adapter; supplying it does not confer authority.

Add `--components <directory> --components-hash <external-hash>` to `inspect`
or `build`. A supplied copy cannot replace the identity already checked against
Core. The component reader and assembly enforce explicit byte and file bounds.

## Native render inventory

The native inventory reader has a separate finite scope: the existing
`IStreamRenderCriticalInventory` producer. It uses the current onchain evidence
as its denominator and reconstructs every original segment and item occurrence.
Its result must remain separate from archival coverage, byte availability,
content-root membership, finality acceptance and complete object-dossier status.

`tools.museum.object_inventory_source.NativeInventorySource` checks:

- EIP-1898 source-block calls and exact producer/dependency runtime pins.
- `requireCurrent`, the completed plan, full original context, the eight original
  inputs, and the exact plan/evidence commitments.
- Every stored segment and its complete item array from original receipt-bound
  events, including item links, segment keys/counts and the cumulative chain.
- Parent-linked block ancestry, transaction membership, event coordinates and
  ordered segment publication. Receipt hints cannot omit a segment or add an
  unused transaction.
- Original token-role occurrences, preserving repeated bytes in separate roles,
  and explicit empty segments with their source witnesses.

The finite producer defines seven initial stages, 31 definition stages and one
stage for every retained token. It owns current source eligibility; this reader
does not independently repeat all source-publication authority and registry
checks. A collection inventory index is not an independently read Core serial.
The complete source context and item provenance remain in the output.

The initial complete adapter vector is explicitly synthetic test evidence.
No genuine pinned RPC snapshot of a completed native inventory is included in
this batch. It cannot be joined to capture8 by matching collection or token
numbers. A future admitted source must match the exact chain, producer/runtime,
dependency, block and original scope commitments.

Offline replay requires separate external anchor and transcript pins:

```powershell
python -m tools.museum.object_inventory_source replay --anchor work/inventory/anchor.json --anchor-hash <external-anchor-hash> --transcript work/inventory/transcript.json --transcript-hash <external-transcript-hash> --output work/inventory-replay
```

The default provenance is `synthetic_fixture`. Explicit `--provenance trusted_rpc`
means caller admission of RPC evidence; the transcript does not authenticate its
own origin, and the report still claims neither actual-chain acceptance nor
consensus proof. Supplying this report to the partial assembler does not silently
join it to capture8 or upgrade its requirement status.

The complete synthetic vector reconstructs 39 segments and 42 item occurrences
for test token `71`, with snapshot commitment
`0x6a1ff2fc9edf69ea6943713ca4278ee837873f76ac874f4cccdee499aeb3967a`.
It is independent test data, not capture8 token `1` or an EVM-executed capture.

## Native record catalogs and ownership history

Three additional source readers reconstruct protocol-defined inventories at
one externally pinned block. Their anchors bind the chain, source block,
runtime and deployment evidence; callers cannot supply a shortened lane list.
All expose `snapshot()` and `transcript()` and support pinned offline replay.

| Reader | Completeness denominator | Verified absence |
| --- | --- | --- |
| `tools.museum.owner_catalog_source.OwnerCatalogSource` | Ten built-in owner types plus every successful `OwnerRecordTypeAdmitted` event from genesis through the anchor; every record index for the exact token and every observed author's latest pointer. | Zero count and zero head, with no corresponding publication in the complete receipt history. |
| `tools.museum.independent_catalog_source.IndependentCatalogSource` | All eight native independent types for one exact collection scope, all record indexes and scoped latest pointers, plus the complete deduplicated payload/signature pointer inventory. | Zero count and zero head for each explicitly retained empty lane. |
| `tools.museum.ownership_source.OwnershipSource` | Every block transaction receipt from genesis through the anchor; Core's complete ERC-721 `Transfer` stream for the exact token. | Missing mint evidence is an error; it is never represented as an absent ownership history. |

Owner and independent hosts do not expose `recordTypeCount/At`. Those getters
belong to the separate MetadataV1 host. Independent types form a fixed closed
catalog; additional owner types require complete admission-event discovery.
Independent scope `0` is supported as its own deployment-wide scope. Capturing
one scope does not establish every scope applicable to a token.

The owner reader checks each original record hash, receipt, signature bundle,
publication event, chain link and recorded timestamp. It retains valid empty
payloads and every native hash algorithm. Embedded Keccak-256 and SHA-256
content is checked; URI-only and opaque algorithm commitments remain explicitly
unverified as content. Historical schema commitments are preserved without
claiming schema interpretation or legal title. Native receipt acceptance is
not replaced by today's ownership or signature policy.

The independent reader retains all subjects in a scope's lanes, including
records for other tokens and media, so filtering cannot conceal chain members.
It checks original schema/document/chunk closure and historical attestor
receipts. Pointer counts are not record counts: native storage deduplicates
each `(family, content hash)` pair. Repeated record occurrences remain distinct.

The shared receipt walk follows parent-linked headers to block zero, fetches
every transaction receipt, and checks receipt coordinates and contiguous
block-wide log indexes. It refuses sources above 4,096 blocks including genesis,
or beyond its 64 MiB transcript limit, rather than truncating the history.
The ownership reader requires one mint, uninterrupted owner transitions,
optional terminal burn and agreement with permanent collection identity and
lifecycle. It checks `ownerOf` for a live token; burned tokens retain identity
and are reconciled without calling the reverting ownership getter. Self-transfers
are valid. Original Transfer logs are also retained as canonical JSONL.

Each module provides `capture`, `replay` and `definitions --check` commands.
Capture uses an environment-variable name for the RPC endpoint. Replay requires
separate external anchor and transcript commitments; its default provenance is
`synthetic_fixture`. Example:

```powershell
python -m tools.museum.ownership_source replay --anchor work/ownership/anchor.json --anchor-hash <external-anchor-hash> --transcript work/ownership/transcript.json --transcript-hash <external-transcript-hash> --output work/ownership-replay
python -m tools.museum.independent_catalog_source definitions --output schemas/museum/object-dossier --check
```

These readers supply consistency evidence under caller-admitted RPC and native
runtime pins. They do not verify Ethereum receipt tries, consensus or the
complete registered address set required by LTA-EVENT-HISTORY. Token Transfer
JSONL is not relabeled as that full protocol archive snapshot. Their synthetic
controls are not genuine native capture acceptance. Capture8 contains selected
records and a mint receipt; it does not contain the new complete source
transcripts. The diagnostic assembler therefore keeps its previous requirement
results until concrete adapters join new evidence to the exact source identity
and block. No existing retained fixture is rewritten.

## Remaining required work

[Typed native joins](museum-native-dossier-joins.md) add a separate V2 partial
assembler, native MetadataV1 catalog and current-registry host roster. It replays
concrete sources against the original block and retains all record occurrences,
while reporting missing and non-exhaustive host/scope coverage explicitly.

Full assembly needs concrete canonical adapters and a complete positive for
the remaining sources. These include actual complete record-catalog and
ownership captures, all remaining applicable native record hosts and scopes,
title-binding history and its covering event archive, finality/content and
entropy evidence, conservation/rights/attribution state, and every authoritative
render byte. A current inventory roster does not prove all those bytes are held.

The full 19-field acquisition packet remains required. Registered schemas and
packaging profiles, preserved reconstruction tooling, zero-operator regeneration,
both named repository-family ingests and both external practitioner roles remain
separate adopted obligations. No partial diagnostic or synthetic vector fulfills
those gates.

```powershell
python -m tools.museum.object_dossier_inventory --check
python -m tools.museum.object_dossier_components definitions --check
python -m tools.museum.object_dossier definitions --check
python -m tools.museum.object_inventory_source definitions --output schemas/museum/object-dossier --check
python -m unittest tools.museum.test_object_dossier_inventory tools.museum.test_object_dossier_components tools.museum.test_object_dossier_admission tools.museum.test_object_dossier tools.museum.test_object_inventory_source -v
```
