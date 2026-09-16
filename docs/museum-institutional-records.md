# Institutional owner documentation

The institutional adapter adds typed accession, title-binding, deaccession,
redemption-claim and citation documentation to the offline museum exporter.
Its source is the original `StreamOwnerRecords` receipt at an externally pinned
block. The owner who published the record remains the author after a transfer.
A named acquiring institution or instrument custodian remains a separate party.

This is a prospective schema/profile implementation. The regression controls
construct synthetic original-wire RPC replies. They do not establish a deployed
capture, legal instrument validity, named-party identity or institutional ingest.
The coordinator must retain a separate actual current-stack capture before
claiming that runtime integration.

## Interpretation and source boundaries

The exact generated documents live in
[schemas/museum/institutional](../schemas/museum/institutional). Their schema
names are `STREAM_ACCESSION_V1`, `STREAM_DEACCESSION_V1`,
`STREAM_REDEMPTION_CLAIM_V1` and `STREAM_CITATION_RECORD_V1`.
The family-to-document binding checks the full registered schema bytes, schema
hash and registered RFC 8785 definition. A matching schema name alone is
insufficient. These are candidate documents, not a registration claim.

| Family | Typed content | Evidence qualification |
| --- | --- | --- |
| ACCESSION | Accession identifier, named acquiring institution, title instrument and custodian | Owner documentation; independent institutional adoption and legal title remain unproven |
| DEACCESSION | Reason-class IRI, disposition reference, title instrument and custodian | No inferred physical disposal or legal transfer |
| REDEMPTION_CLAIM | Program/entitlement ID, entitlement text, nullable fulfillment reference | Complete selected token lane establishes first accepted claim under that host; fulfillment and consensus nullifier execution remain separate |
| CITATION | Original work citation, typed record-state qualifier, citing-work reference and context | Original chain/Core/token must match the owner receipt; referenced state is not asserted verified |

`TITLE_BINDING` is nested in accession and deaccession payloads. It preserves
the instrument URI/HashRef, custodian, original chain/Core/token, block,
transaction, log index and both Transfer parties. The log index disambiguates
multiple transfers within a transaction. A declared transfer is not a verified
receipt. These fields never generate `Acquisition`, `TransferOfCustody`, token
ownership or physical-ownership claims. The semantic resources contain the
qualified original statements and named parties; their detailed relationships
remain typed in the complete Stream dossier.

New `InstitutionalOwnerSource` anchors use
`STREAM_MUSEUM_INSTITUTIONAL_OWNER_SOURCE_V1`. The existing
`STREAM_MUSEUM_OWNER_RECORD_SOURCE_V1` and its historical loan/valuation packages
remain unchanged. Source capture verifies the original direct or relayed wire,
domain, nonce consumption, schema/payload chunks, record hash, actor and lane
accumulator. Relayed acceptance is evidence from the pinned trusted RPC host,
not a new offchain re-evaluation of historical ERC-1271 code or a trie proof.
The new source accepts only the four closed public institutional families.
Every retained row and immediate predecessor must have the exact candidate
schema; unrelated lanes and opaque predecessor payloads reject before packaging.
Loan, valuation and condition records continue through their own source profiles.

For every token with selected redemption records, capture reads the pinned lane
head/count and requires every record from index zero through that head in the
selected source. The projection validates all of those records against the exact
candidate schema, including records omitted from its display plan. The first
record for each token/program is operative. Later records and corrections are
supplemental; they cannot create a second claim. A missing prior record, changed
head, unsupported historical schema or more than 128 source records rejects
this bounded profile rather than making an incomplete primacy claim.

## Public instrument bytes

Callers must explicitly classify the package as public. Optional documents use
`keccak256(JCS(HashRef))` as their map key. Supplied documents are retained
byte-for-byte under `instruments/` and checked with the explicitly supported
RAW_BYTES Keccak-256 or SHA-256 profile. Unsupported supplied hash profiles,
unreferenced files, wrong digests and bounds violations reject. Unsupplied
references remain `referenced_not_supplied`. This is not a private-instrument
intake channel. A matching digest proves bytes, not legal effect or a signer's
identity.

The maximum is 64 projected records, 128 captured owner records, 128 instrument
files, 1 MiB per file, 16 MiB aggregate instrument bytes and 8,192 bytes per
original owner payload. Exact decimal strings preserve uint256 identities.
Every original value, null, empty collection and array order appears in the
coverage/sidecar data. Source packages, schema documents, anchor, deployment
evidence and exact replay transcript remain embedded.

## Build and verify

Use the Python environment described in the
[museum tooling guide](../tools/museum/README.md).

```text
python -m tools.museum.institutional --check
python -m unittest tools.museum.test_institutional -v
python -m tools.museum.institutional_package build SOURCE PLAN OWNER_INPUTS OWNER_PINS OUTPUT --source-manifest-hash HASH --plan-hash HASH --profile-hash HASH --disclosure public
python -m tools.museum.institutional_package verify OUTPUT --manifest-hash HASH
```

`SOURCE` is an already verified recorded account package. `OWNER_INPUTS` contains
`anchor.json`, `transcript.json` and `deployment-evidence.json`; `OWNER_PINS`
contains `anchorHash`, `transcriptHash` and `sourceHash`. Both source adapters must
use the same chain, original Core, block/hash/state root, timestamp and environment.
The new plan is canonical JSON with `version: "1"`, `ownerSourceHash` and a
`records` array of original record hashes. Its bytes and profile are externally
pinned. Optional `--documents INDEX` accepts a canonical object mapping HashRef
keys to safe relative file paths beneath that index's directory.

Verification replays every source read and rebuilds the semantic output. It
rejects modified output even if a caller recomputes the package checksum table.
The command never registers a schema, posts a record, downloads an instrument
or broadcasts a transaction. Independent institutional authority,
notarization, acquisition-packet completeness and real deployment
capture remain separate acceptance work.

## Optional original token Transfer evidence

`TitleTransferCapture` in `tools/museum/institutional_transfers.py` checks the
receipt correspondence separately from the source documentation. Pass a
concrete reconstructed institutional source, a canonical hint document, a
read-only `RpcTransport` or externally pinned `ReplayTransport`, the external
owner snapshot hash and hint hash. Hints contain `profile` equal to
`STREAM_MUSEUM_INSTITUTIONAL_TRANSFER_RECEIPTS_V1`, `ownerSourceHash` and selected
accession/deaccession `records`.

The capture requires a successful receipt with the exact original Core address,
four ERC-721 Transfer topics, empty data, token/from/to and specified log index.
It joins the receipt's block and transaction position through parent-linked
headers to the original pinned anchor. The transfer timestamp must not exceed
the recorded publication timestamp; equal timestamps do not prove ordering
within a block, because the owner publication transaction is not joined here.
This bounded profile accepts at most 64 selected records
and an ancestor span of 256 blocks. Older transfers fail explicitly and need a
separately qualified capture profile; no partial ancestry is reported verified.

Retain `capture.reader.transcript()` after `capture.capture()`, externally pin
its hash, and build the separate derivative:

```text
python -m tools.museum.institutional_transfer_package build INSTITUTIONAL_PACKAGE HINTS TRANSCRIPT OUTPUT --source-manifest-hash HASH --hints-hash HASH --transcript-hash HASH --profile-hash HASH
python -m tools.museum.institutional_transfer_package verify OUTPUT --manifest-hash HASH
python -m unittest tools.museum.test_institutional_transfers -v
```

The derivative retains the entire original institutional package and exact
receipt transcript, and independently rebuilds the correspondence report.
Its `selectedOriginalTokenTransfersChecked` claim identifies the successful
receipt join. It never upgrades legal title, physical custody, institution
identity or full transfer-history claims. Trusted RPC consistency is the
boundary; Ethereum receipt/state trie proofs are not implemented. Current tests
use synthetic original-wire/receipt replies, including failed/wrong token, wrong
Core, altered block ancestry and checksum-rehashed output controls. They do not
prove a genuine current-chain Transfer capture was executed.

The normative boundaries are
[owner records and citations](collection-metadata-contract.md#owner-records-and-the-object-dossier)
and the adopted [museum semantic mapping](museum-semantic-mapping.md).
