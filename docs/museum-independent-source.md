# Independent record source capture

`STREAM_MUSEUM_INDEPENDENT_SOURCE_V1` captures the complete history of an explicit
ordered list of `(scopeKey, recordType)` lanes from the dedicated
`StreamCollectionAttestations` host. It retains original generic records,
receipts, subjects, payloads, signature bundles and interpretation documents.
This is an additive source boundary. Existing synthetic Linked Art, PREMIS,
IIIF, LIDO and package commands keep their accepted inputs and output bytes.
They do not yet consume this capture as an authenticated semantic projection.

The operator supplies a trusted anchor before capture: exact chain ID, block
hash/number/timestamp/state root, deployment evidence hash, host/Core/schema/store
addresses and runtime hashes, supporting library runtime pins, and ordered lanes.
The deployment evidence must establish that these exact deployed runtimes and
links implement the reviewed profile. The adapter checks the supplied code pins
and actual dependency joins; it does not turn an arbitrary caller-supplied code
hash or ERC-165 assertion into an independently reviewed deployment. The
`deploymentEvidenceHash` binds that external evidence; this first adapter does
not interpret every deployment-manifest format.

Every contract/code read uses the same block hash with `requireCanonical=true`
under [EIP-1898](https://eips.ethereum.org/EIPS/eip-1898). An unsupported endpoint,
revert, unavailable block or malformed return fails; there is no fallback to
`latest`, a block number or another provider. The endpoint is trusted to return
truthful execution/state. The supplied state root is compared to its anchored
header, but this implementation does **not** verify Merkle Patricia proofs,
header consensus, finality or RPC honesty. Offline replay additionally requires
an externally trusted transcript hash and consumes the exact ordered call list.
A forged transcript cannot authenticate itself by including its own hash.

`recorded_state` means this explicit trusted-RPC route, with a separate
`environment` of `local_evm_fixture` or `public_chain`. A synthetic transport
always produces `synthetic_fixture`. Neither a mode flag nor a local EVM run
establishes accepted public deployment, Museum registration or institutional
acceptance.

## Verified joins and retained authority

For each declared lane the adapter reads its count and terminal chain hash,
every `recordHashAt` entry, and every complete record/receipt. It rejects missing
or duplicate records, wrong lanes, noncanonical numeric widths, changed indices,
and rolling-chain mismatch. It checks each recorder's latest subject entry
against the last corresponding history record. Two attestors using the same
subject or nonce remain separate. The ordered lane list itself is committed by
the external anchor. This proves completeness only within those lanes; a caller
cannot prove the absence of other lanes by omitting them from the list.

The generic record is checked against its fourteen ABI words, including chain,
host, Core, original recorder, scope, both tagged hash references, exact UTF-8
URI bytes and effective time. The signature bundle is checked against its
original domain and all fourteen permanent typed words, signature bytes, generic
signature commitment and saved authorization digest. Direct, EIP-712 and ERC-1271
scheme shapes remain distinct. The admitted host's historical receipt provides
the fact of signature/authority acceptance. The adapter does not ask the current
wallet to re-approve an old proof or mistake an independent attestor for an
artist, curator, collection operator or institution.

Class 5 and original attestor attribution are retained. A nonce revoked without
a successful record does not create a record or erase earlier evidence. No
current grant, signer, artist status, governance action or module liveness is
used to reinterpret historical acceptance. Exact dependency code pins are still
required at the selected capture block. A later provider outage does not change
an earlier anchored capture.

Collection subjects include deployment scope zero. Token subjects retain the
actual token ID and collection joined by the host when it accepted the write;
burned tokens remain supported. Media object IDs remain **declared references**:
there is no typed media-membership registry proof in this profile. Current
ownership, collector delivery, media retrieval and preservation truth are not
inferred.

Payload and signature pointers must equal the actual store's content-hash
pointer. Their deployed code must be one STOP byte followed by exactly the
retained bytes, within the host's 8,192-byte bound. Schema and canonicalization
definitions must match their original receipt hashes. Documents are reconstructed
locally from ordered 8,192-byte chunks, with the last chunk bounded by its exact
remaining length. The name-derived ID, complete declaration, content hash,
kind/status, total length and canonicalization/predecessor references are checked.
ACTIVE, DEPRECATED and ARCHIVED documents all remain usable historical evidence.
Only the exact RAW_BYTES bootstrap may refer to itself.

This closure covers the registry's typed canonicalization and predecessor edges.
Arbitrary `$ref`, JSON-LD context, ontology or other references inside original
document bytes still require the separately pinned semantic evaluation profile.
Original document/payload bytes are not parsed, normalized, coerced into JCS or
promoted into a schema validation result here.

## Commands and bounds

Use the existing Museum Python environment; no new Python dependency is needed.
Offline regression and retained actual local-EVM replay:

```text
python -m unittest tools.museum.test_independent_source -v
python -m tools.museum.independent_source --anchor schemas/museum/independent-source/local-fixture/anchor.json --transcript schemas/museum/independent-source/local-fixture/transcript.json --transcript-hash 0xf489f9781d309ed1089be18358b7537044a3ff5e2a82a686bb02133050f2847e --output <new-output-directory>
```

For a read-only online capture, set an environment variable containing the
explicitly trusted endpoint and use `--rpc-env VARIABLE_NAME` instead of the
transcript arguments. The endpoint and credentials are excluded from retained
files and error messages. Only four RPC methods are available: chain ID,
block-by-hash, block-anchored code, and block-anchored calls. HTTPS is required
except for loopback endpoints. No public-chain write command is provided.

The explicit implementation bounds are 1,024 declared lanes, 4,096 records,
512 interpretation documents with 16 MiB aggregate original document bytes,
64 chunks/524,288 bytes per registered document, 100,000 read calls, 1 MiB per
RPC response, and 64 MiB per transcript. Record and signature-bundle limits stay
8,192 bytes, signatures 4,096 bytes, URI 2,048 UTF-8 bytes, and runtime code
24,576 bytes. Exceeding a bound fails deterministically. These are this first
capture profile's limits, not a reduction of full Museum delivery scope.

## Local execution evidence

The retained fixture is an actual isolated Anvil execution of reviewed host,
schema registry, document store and linked library artifacts from the accepted
independent interface22 cohort. It uses existing explicit
`IndependentCoreBoundary`, `IndependentExecutorBoundary` and
`IndependentSignatureBoundary` contracts. These do not prove current full-Core,
governance scheduling or a real Safe deployment. The host's governance authority
is zero. The schema registration executor remains the explicit test boundary.

Six actual writes cover deployment, collection, burned-token and declared-media
subjects; direct and relayed EIP-712/ERC-1271 proofs; two attestors sharing nonce
zero; a full uint256 nonce; and a write after schema archival. The contract
wallet refuses later proofs before capture, while historical export succeeds.
The snapshot uses 85 exact block-anchored/read-anchor requests and replays to
identical bytes. The fixture includes the raw transactions, receipts, artifact
hashes, constructor arguments, link addresses and final runtime pins. These are
public local fixture values, not public-network broadcasts or wallet credentials.

To make another isolated rehearsal from already reviewed Foundry artifacts:

```text
python -m tools.museum.local_independent_fixture --artifacts <reviewed-project/out> --output <new-output-directory>
```

This separate rehearsal command starts and terminates its own loopback Anvil,
uses public unlocked fixture accounts, and writes only to that fresh local
chain. It does not compile, edit the supplied artifacts, accept a public RPC URL,
or promise identical new block hashes across runs. The committed capture is
verified by offline replay, not replaced by a later rehearsal.

Remaining work includes other record authority lanes, actual Museum schema/profile
registrations, semantic source-state composition, complete disclosed inventory,
public-chain deployment acceptance, the wider preservation formats, and the
required institutional reviews. This increment does not establish full Museum
or CMC conformance.
