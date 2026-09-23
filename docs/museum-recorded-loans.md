# Recorded owner loan dossiers

This adapter implements a bounded documentation/export profile for
[CMC-EXHIBITION-LOAN](collection-metadata-contract.md#exhibition-and-loan-records-cmc-exhibition-loan)
and [MSM-RELATIONS](museum-semantic-mapping.md#8-relationships-evidence-and-authority-boundaries-msm-relations).
The source is the existing token-scoped `StreamOwnerRecords` `LOAN` lane.
There is no `INDEPENDENT_LOAN` family; independent exhibition or condition
records are not relabeled as owner loan statements.

## Source and authority

`owner_record_source.py` reads selected original `OwnerRecord` and `Receipt`
tuples at one externally pinned block. It checks the original owner token
subject, record preimage, lane index/chain, registered schema/canonicalization
bytes, SSTORE2 bytes, and exact direct or relayed signature bundle. The original
14-word owner EIP-712 payload/domain and consumed unordered nonce remain exact.
A historical ERC-1271 receipt is not reauthorized against today's wallet.
Likewise, today's `ownerOf` is never substituted for the owner admitted when
the original statement was published. Transfers and burns do not erase it.

The externally selected host, Core, schema store and chunk store must match
their runtime pins and immutable bindings. This is selected-host evidence,
not proof that Core has selected a universal authoritative loan satellite.
The deployment evidence remains externally supplied and hash-pinned. Ordinary
RPC transcript replay does not prove consensus, state-trie membership,
institution identity, legal title or physical custody.

The finite source profile supports at most 128 selected original `LOAN`,
`VALUATION`, and `CONDITION_REPORT` records. It requires actual embedded payload
bytes, Keccak-256 commitments, and original registered definitions. URI-only
and other hash profiles get an explicit unsupported-source error. It checks
each selected lane position and immediate predecessor; it does not claim a
complete host/token history inventory. All original receipt, payload,
signature and registered-document bytes remain in the captured source.

## Semantic profile

`schemas/museum/loan/STREAM_LOAN_V1.json` is a closed prospective serialization
of the required loan fields, not a genesis-registration claim. The export
requires this exact schema to be registered under its original ID with the
actual JCS definition. It retains token subject, lender/borrower identities,
status, names, loan window, insurance VALUATION reference, outgoing/return
CONDITION_REPORT references, other condition references and return conditions.

Only explicitly completed source statements with a recorded title and named
parties produce a generic Activity. Person/Group classes are explicitly named
in the original declaration. Participant roles remain distinct in a separate
correspondence file; no organizer, owner or custodian class is guessed.
Identical same-kind party declarations may share one resource with all their
source provenance. Event IDs remain unique, and conflicting or cross-kind
declarations reject. Already selected original graph identities cannot be
redeclared by this distinct profile. Name or wallet equality does not merge IDs.

Planned, cancelled and unknown statements remain nonperformed dossiers;
missing names are explicit unsupported graph dispositions. Gregorian UTC
bounds use only original values, with original expressions/precision/calendar
and timezone retained. Publication timestamps are never loan dates.

Each linked valuation/condition record must be selected explicitly and match
its original family, schema ID, token subject and exact content HashRef.
Missing references or missing selected records remain precise incomplete
dossier facts. Their registered original bytes are preserved opaquely; this
profile does not invent appraisal amounts, condition assessments or sealed
instrument contents. `recordedBeforeLoan` compares the original timestamps
only; equality does not establish same-block transaction order. Neither a
reference nor this timestamp comparison proves that a valuation was operative
at loan publication. Countersignatures also require their own future typed
evidence join and are not inferred from party names or references.

Every original scalar, null and empty collection has a source-pointer coverage
row. Every graph value identifies its original receipt and field paths. The
loan dossier documents reported context; it emits no Acquisition,
TransferOfCustody, ERC-721 transfer, rights grant or enforceable return promise.

## Offline build and replay

```text
python -m tools.museum.loans --check
python -m unittest tools.museum.test_loans -v
python -m tools.museum.loan_package build RECORDED_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public --owner-inputs OWNER_INPUTS --owner-pins OWNER_PINS.json
python -m tools.museum.loan_package verify OUTPUT --manifest-hash HASH
```

The canonical plan has exactly `version: "1"`, `ownerSourceHash`, and `records`
(up to 64 original loan record hashes). Owner inputs contain `anchor.json`,
`transcript.json`, and `deployment-evidence.json`; owner pins contain
`anchorHash`, `transcriptHash`, and `sourceHash`. The plan/profile and all source
pins are external inputs. The owner and original recorded source must have the
same chain, Core, block, state root, timestamp and environment qualification.
Explicit public classification is required. Omit both owner options and use a
null source hash/empty selection to obtain `owner_receipt_source_missing`.

The package literally retains and replays the original recorded package plus
the separate owner source closure, then reconstructs all dossier, graph,
coverage and reference files. The generic verifier recognizes a distinct mode;
prior profiles remain unchanged. Tampering remains invalid even when the outer
file inventory is recomputed. Verification is network-free and output keeps
the existing no-overwrite discipline.

Focused positive cases use labelled synthetic original-wire responses, including
DIRECT and ERC-1271/EOA receipt encodings; synthetic transcript replay remains
explicitly identified by retained deployment evidence. The actual recorded
fixture has no owner loan capture, and exercises the missing-source result.
Neither test is a positive onchain owner-loan acceptance claim. A later actual
local example should publish through a genuine OwnerRecords host/current owner,
retain the returned receipts/schema/chunks at the same source block and replay
these inputs. No deployment or broadcast is part of this feature batch.
