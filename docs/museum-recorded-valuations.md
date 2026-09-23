# Recorded valuation dossiers and loan insurance references

This exporter implements a prospective, versioned `STREAM_VALUATION_V1` profile
over selected original `StreamOwnerRecords` receipts. Its normative inputs are
[CMC owner-record rule 10 and the loan rules](collection-metadata-contract.md),
[ADR 0014 V8](adr/0014-world-class-pass-round-5.md), and the source-authority and
reconstruction requirements in the [museum semantic mapping](museum-semantic-mapping.md).
The original [loan profile](museum-recorded-loans.md) and all earlier package
meanings remain unchanged. No schema registration, publication or deployment is
performed by these tools.

The receipt proves which token-owner account published the statement under the
retained RPC evidence boundary. It does not establish legal ownership, an
institution's identity, the accuracy of a figure, professional appraisal,
insurance coverage, or assent by anyone named in the payload. Actual-record
mapping uses the original owner-record family, record hash, schema definition,
JCS binding, embedded payload, signer bundle, token subject and lane index.
Another registered valuation schema receives an explicit unsupported result;
its bytes are retained through the original source package.

## Typed facts and semantic output

The closed schema retains a valuation-document IRI, token, object/loan scope,
asserted/withdrawn status, title, basis, effective date, amount and currency,
confidentiality flag, instrument commitment, named issuer and appraiser,
supersession references, other references, and cited countersignatures.

- `appraisal`, `book_value`, `insurance`, and `other` remain distinct bases.
  Amounts are exact decimal strings, including original sign and scale. Currency
  identifiers remain source strings; a three-letter shape check is not an ISO
  catalog check. There is no rounding, conversion or current-price comparison.
- The original effective-date expression, precision, calendar and timezone are
  retained alongside the native record's separately declared `effectiveAt`.
  Publication time is never substituted for either effective date.
- A confidential valuation must have a null amount. Its instrument is a public
  URI/HashRef commitment; sealed instrument bytes are neither accepted nor fetched.
  This validates the typed amount field, not arbitrary prose for accidental
  disclosure. The caller must explicitly classify the complete export as public.
- The receipt's historical owner is distinct from the named issuer/appraiser.
  A countersignature entry preserves the stated role, attestor identity, record
  hash and reference. It is reported as `unverified_reference`; this version has
  no selected general-attestation adapter and never treats a matching address,
  name or timestamp as a signature or professional authority.
- An explicitly named valuation document becomes a `LinguisticObject`, and
  explicit named parties become `Person` or `Group` resources with source roles
  in a sidecar. Monetary facts remain typed Stream extensions: the pinned
  Linked Art validation subset does not admit a fabricated appraisal Activity
  or `MonetaryAmount`. Every source value remains in the dossier and coverage
  output. Repeated party IRIs require the entire identical declaration.

## Bounded publication-order witness

The optional `STREAM_MUSEUM_OWNER_VALUATION_HISTORY_V1` evidence joins the
existing owner-record source to actual receipt logs and complete valuation
lanes for the selected loans' tokens. It reads the actual `recordChainHash`
count/head and every `recordHashAt` entry. Every original valuation must also
be present in the verified owner-source snapshot; a supplied subset never
certifies completeness.

Hints name exact transaction hashes. The reader verifies successful receipts,
the full original `OwnerRecordRecorded` ABI bytes and indexed fields, original
recorded-at timestamp, and block/transaction/log coordinates. It reads block
headers from the externally pinned capture block backwards through exact
parent hashes, checks each transaction hash at its header index, and requires
event order to agree with the original per-family record order. Same-block
ordering uses transaction index, then log index; same-transaction ordering uses
log index. A timestamp comparison alone supplies no cross-family order proof.

Bounds are 128 selected original records/receipts, 64 semantic valuation rows,
64 loans, and 256 ancestor blocks. A missing record, mismatched head, incomplete
receipt set, malformed event or exceeded bound fails without a partial
completeness result. The source transcript remains an RPC trust boundary:
neither Ethereum receipt/state trie proofs nor independent consensus are
verified. Long-lived dossiers outside the ancestry bound need a separately
supported historical proof profile; this implementation does not pretend that
they fit.

The insurance join checks the exact loan-selected valuation reference and its
same-token content commitment. With the optional witness, it reports whether
that record preceded the loan and whether any interpretable valuation in the
complete prior lane explicitly named it as superseded. A prior opaque schema
prevents an unsuperseded conclusion. Later records cannot retroactively change
the earlier result. An appraisal or book value does not displace an insurance
record merely because it was published later.

`ordered_selected_unsuperseded_reference` means this precisely documented
selection. It does **not** prove that the appraisal or policy was legally
operative, professionally accepted, effective under the instrument's terms,
current at export, or the universal latest value. A separate field reports
whether the native declared effective time was no later than the loan's
publication. The original dates, basis, scope and all evidence positions are
retained for a consumer's explicit decision. No ownership, custody, royalty or
default token-rendering state is changed.

## Offline package and replay

The valuation derivative starts from a verified loan package and retains that
package literally, including its original recorded package and owner evidence.
The plan has exactly `version: "1"`, `ownerSourceHash`, `records`, and `loans`.
Loan selections must be retained by the source loan package. To use a complete
lane witness, the valuation selection must include every valuation in those
lanes, including unsupported records. Standalone valuations can use an empty
loan selection without a history witness.

Optional history inputs are `hints.json` and `transcript.json`; pins are
`hintsHash`, `transcriptHash`, and `snapshotHash`. Hints contain the exact
history profile, `ownerSourceHash`, selected `loans`, and `transactions`.
The `ValuationHistory` Python reader can capture through the existing read-only
RPC transport; verification always uses its retained exact transcript. All
source/profile/plan/history hashes are external inputs. No endpoint credentials
are retained. Each package rebuild replays its original source and reconstructs
every output, rather than trusting an edited report or reordered source list.

```text
python -m tools.museum.valuations --check
python -m unittest tools.museum.test_valuations -v
python -m tools.museum.valuation_package build LOAN_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public
python -m tools.museum.valuation_package build LOAN_PACKAGE PLAN.json OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public --history-inputs HISTORY_INPUTS --history-pins HISTORY_PINS.json
python -m tools.museum.valuation_package verify OUTPUT --manifest-hash HASH
```

The generic package verifier dispatches this distinct mode. Verification is
network-free and the existing no-overwrite output discipline remains. Shared
parties between loan and valuation resources require identical whole source
declarations; name matching and account matching do not merge identities.

Positive source-wire, same-block receipt and package cases are explicitly
synthetic controls, with that fixture qualification retained in their source
evidence. The existing actual recorded capture supplies the missing-owner-source
case. Neither establishes actual captured valuation/insurance acceptance or
full institutional conformance. A later local example must publish the exact
registered valuation and loan payloads through a genuine OwnerRecords host,
retain all selected receipts and the full valuation lane at the same block,
and replay those returned facts. No broadcast or native compilation is part
of this feature batch.
