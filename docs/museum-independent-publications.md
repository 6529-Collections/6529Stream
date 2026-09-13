# Independent publication positions

`STREAM_MUSEUM_INDEPENDENT_PUBLICATION_V1` binds exact publication positions to
records from the [independent history capture](museum-independent-source.md).
This is an additive read-only profile. It does not admit a semantic assertion,
reviewer or Person/Group identity, and does not change existing fixture
projections or package bytes.

An original assertion must precede a qualifying review. A record index only
orders its own `(scope, type)` lane, and two different publications can share a
timestamp. This profile orders events by the numeric tuple
`(blockNumber, transactionIndex, logIndex)`, retaining every value as a lossless
unsigned decimal string. The original record's index and timestamp remain
separate source facts.

## Evidence and exact checks

The adapter first reproduces the entire source capture against its externally
trusted transcript commitment and original block/deployment anchor. A complete
hint map names the transaction containing each captured record. Hints locate
receipts; they do not establish inclusion or authority. Duplicate, foreign or
missing record hints reject. Several records may name one transaction.

Every selected transaction must have a successful receipt. The matching event
must come from the exact host, with the exact signature and four topics. The
indexed scope, type and subject, complete generic record tuple, record and chain
hashes, original attestor, class 5 and event version 1 must all agree with the
validated source capture. ABI decoding rejects noncanonical offsets, padding,
widths and trailing data. Every captured record needs exactly one matching
publication. Unknown events in a declared complete lane reject; events in other
lanes remain receipt evidence outside the selected inventory.

Receipt and log block hashes, transaction hashes and indices must agree. Removed
logs, duplicate or unordered log indices and contradictory transaction/log order
reject. The exact receipt-array offset is retained separately from the block-wide
log index. Other events in each receipt are preserved without treating them as
selected semantic assertions.

The adapter walks backward through parent hashes from the source anchor. Each
header must return the requested hash and a height exactly one below its child.
Timestamps cannot decrease toward the child, and each selected header timestamp
must equal its record's saved `recordedAt`. Equal timestamps are allowed by this
capture check, including the explicit local Anvil fixture; this is not a
consensus-rule validator. The header's transaction list must contain the exact
transaction at its reported index. The anchor's hash, height, time and state root
are checked again at completion, followed by an EIP-1898 canonical-block code
read of the pinned host. There is no latest/block-number fallback.

These remain **trusted-RPC observations**. Hash-linked reported headers and
receipts are not independently verified receipt-trie proofs, consensus or
finality. An offline replay needs an external transcript commitment; a file's
self-declared hash cannot authenticate it. `local_evm_fixture` denotes the
actual isolated execution with named boundaries, not a public-chain deployment.

## Commands and limits

Use the existing Museum Python environment. No new dependency is needed.

```text
python -m unittest tools.museum.test_independent_publication tools.museum.test_independent_source -v
python -m tools.museum.independent_publication --anchor schemas/museum/independent-publication/local-fixture/anchor.json --source-transcript schemas/museum/independent-publication/local-fixture/transcript.json --source-transcript-hash 0xe37251d457433b030259d0f078d9c7f301c1845874ec472baae57a6d57ffce52 --hints schemas/museum/independent-publication/local-fixture/publication-hints.json --publication-transcript schemas/museum/independent-publication/local-fixture/publication-transcript.json --publication-transcript-hash 0x6163b3162d9783396cb2dbec389da9e254f15f2b324d5845f0af45e17b7e922c --output <new-output-directory>
```

For online publication reads, replace the publication transcript arguments with
`--rpc-env VARIABLE_NAME`, referring to an explicitly trusted endpoint. The
existing source transcript and its external anchor are still required. The only
additional RPC method is read-only `eth_getTransactionReceipt`; headers are read
by hash, and code uses the original canonical block hash. Endpoint credentials
are excluded from output and error messages.

The hint document is bounded by 1 MiB and the source profile's 4,096 records.
The parent walk retains at most 4,096 headers, including the anchor. A receipt
has at most 8,192 logs; each log has at most four topics and 262,144 data bytes,
while each matched record event has a tighter 16,384-byte ABI limit. Header
transaction lists are limited to 65,536 hashes. The shared 1 MiB response,
100,000-request and 64 MiB transcript limits still apply, and the complete
publication output has a separate 64 MiB bound. Reaching a bound fails explicitly.
Older or larger histories need a separately supported strategy; these limits
do not narrow full Museum delivery requirements.

The output embeds all selected receipts and traversed headers. Each publication
binds its event and receipt hashes, source record, block and transaction, log
offset and numeric position. It also binds the source anchor, capture, source
transcript, hint map and publication transcript. Source payloads, schema bytes,
signature bundles and their history remain in the separately retained source
capture rather than being reinterpreted here.

## Rehearsal and remaining authority work

An isolated rehearsal can additionally retain publication evidence:

```text
python -m tools.museum.local_independent_fixture --artifacts <reviewed-project/out> --output <new-output-directory> --publications
```

The included fixture executed the actual reviewed independent host, schema/store
and linked libraries with explicit `IndependentCoreBoundary`,
`IndependentExecutorBoundary` and `IndependentSignatureBoundary` doubles. Its six
records occupy six transactions, ten retained ancestor headers and nineteen
additional publication RPC requests. Three publications in two lanes share one
timestamp. The same-transaction and same-block multiple-publication regression
arrangements are separately labeled synthetic; they are not additional actual
batch execution claims. Original independent capture fixtures remain unchanged.

Publication order is only one prerequisite for recorded semantic reviews. The
historical signature author/account is distinct from an asserted Person, Group
or arbitrary `assertingAgent` IRI. No payload name creates that relationship,
and no Boolean creates self-review authority. Exact registered semantic
schemas/profiles, admitted agent evidence, selection and review policy, the
other authority lanes, full dossier packaging, public deployment and
institutional acceptance remain separate work.
