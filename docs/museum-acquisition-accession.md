# Acquisition ACCESSION and native title history

The acquisition exporter identifies the exact instrument recorded in a selected
original `ACCESSION`, checks its declared token transfer against Core history,
and retains public instrument bytes when supplied. The selected record is an
explicit choice for this acquisition. It is not a new native “current accession”
rule, a legal-title determination or an institutional acceptance report.

The additive [canonical packet V2 adapter](museum-acquisition-packet-v2.md)
consumes this unchanged package and represents its native owner authority in an
item-9 fragment. This original acquisition profile retains its V1 compatibility
boundary below; only the explicitly selected V2 assembly closes that schema gap.

The [19-item examination](museum-dossier-gather.md) still needs evidence for
its other requirements. Item 9 now has a source-backed documentary join. Item 10
remains partial because a full protocol event archive and the universe of prior
or unregistered OwnerRecords hosts are not supplied.

## Original sources and interpretation

The new `STREAM_MUSEUM_PUBLIC_OWNER_CATALOG_SOURCE_V1` profile uses the existing
native OwnerRecords interfaces and two fixed log filters: every type admission
at the admitted host, and every original publication for the exact token. It
reads native lane counts, every indexed record, chain heads, per-author latest
records, original receipts, retained signature bundles and consumed nonces.
The fixed native types plus observed admissions define this host's denominator.
An omitted empty admitted type cannot be independently discovered from state.

The second source is the unchanged
`STREAM_MUSEUM_PUBLIC_CORE_OWNERSHIP_HISTORY_V1`. Both sources must share chain,
Core, token, block hash/number, timestamp, state root, environment, deployment
evidence and Core runtime. Shared RPC responses, full receipts, touched canonical
headers, block log positions and matching filter results must agree across the
two captures. A matching log disclosed by either source's receipt cannot be
silently omitted by the other source's query results.

The exporter checks the receipt owner for **every** original owner record
against the last token Transfer preceding its publication. It interprets all
ACCESSION/DEACCESSION occurrences only when original receipt schema and JCS
commitments equal the exact retained definitions. Other historical schemas and
invalid payload meanings remain visible without reinterpretation. The selected
ACCESSION must have supported original bytes and a matching native transfer.

Each `TITLE_BINDING` joins chain, Core, token, block, transaction hash, log index,
sender and recipient. Block/transaction/log order must put the transfer before
publication, including within the same transaction. A matching timestamp alone
does not establish order. Later transfers do not rewrite an earlier receipt's
owner or the recorded institution/custodian. Nonselected unmatched title
statements remain explicit in the report.

Original payloads and signature bundles are retained beside both complete source
triplets. Public referenced documents are keyed by `Keccak256(JCS(HashRef))`.
Supplied `RAW_BYTES` Keccak-256 or SHA-256 objects must match their original
commitment. Missing references stay `referenced_not_supplied`; the exporter does
not fetch URLs. It rejects unreferenced documents and unsupported supplied hash
profiles. Instrument integrity does not establish legal validity.

## Capture and offline use

The CLI prints its current exact profile hashes:

```powershell
python -m tools.museum.acquisition_accession_cli profiles
```

Prepare separately admitted, closed owner/ownership anchors and this canonical
selection JSON. Replace the illustrative addresses and hash with the actual
original host and ACCESSION hash:

```json
{"accessionRecordHash":"0x<64 lowercase hex digits>","host":"0x<40 lowercase hex digits>","profile":"STREAM_MUSEUM_ACQUISITION_ACCESSION_HISTORY_V1","tokenId":"71"}
```

Hash the exact canonical selection and anchors externally. The live command
uses an explicitly named process environment variable for its RPC endpoint:

```powershell
python -m tools.museum.acquisition_accession_cli capture --owner-anchor owner-anchor.json --owner-anchor-hash 0xOWNER --owner-source-profile-hash 0xOWNERPROFILE --ownership-anchor ownership-anchor.json --ownership-anchor-hash 0xOWNERSHIP --ownership-source-profile-hash 0xOWNERSHIPPROFILE --selection selection.json --selection-hash 0xSELECTION --rpc-env STREAM_CAPTURE_RPC --disclosure public --output out/acquisition-accession
```

`--documents public-documents` optionally supplies a flat directory containing
lowercase 64-hex HashRef-key filenames with `.bin` suffixes. No symlinks or nested
directories are admitted. Limits are 128 documents, 1 MiB each and 16 MiB total.
The source profiles enforce their own log, receipt, record and byte bounds.

Existing source triplets can instead be joined with `compose --owner-source DIR
--owner-pins FILE --ownership-source DIR --ownership-pins FILE`, the same
selection/hash/disclosure/output options, and optional documents. Each source
directory contains exactly `anchor.json`, `transcript.json`, `snapshot.json`.
Each separately supplied pins file contains exactly `profileHash`, `anchorHash`,
`transcriptHash`, `snapshotHash`, `provenance`. Provenance is an external admission;
transcript bytes cannot authenticate their own origin.

Every original source is replayed. Capture and composition verify the complete
derived package before publishing to a new output directory. Verification is
offline and requires an externally supplied manifest commitment:

```powershell
python -m tools.museum.acquisition_accession_cli verify out/acquisition-accession --manifest-hash 0xMANIFEST
```

The common museum package verifier recognizes the new distinct mode, allowing
the existing BagIt/repository transport workflow to retain the verified package.
Old profiles and historical packages keep their original meaning.

## Explicit remaining boundaries

- Native OwnerRecords receipts contain owner, relay and signature facts, but no
  numeric `authorityClass`. The original canonical packet's generic record
  requires that field. This exporter retains an explicit historical-owner
  authority object and reports the schema gap; it does not fabricate a class or
  silently change the old schema. Its output is an acquisition evidence package,
  not a canonical packet fragment.
- Filtered provider history completeness and canonical block mapping remain
  trusted. This is not a genesis block walk, receipt-trie proof or consensus
  verification. The [public-history boundary](museum-public-history-capture.md)
  applies to both sources.
- Complete lanes in one admitted host do not prove global record absence or a
  canonical host selection. Unsupported statements and all missing bytes are
  listed explicitly.
- Synthetic tests validate the join and replay, not an actual deployed capture.
  The [RC1 RPC limitation](museum-rc1-public-capture.md) remains unresolved.
