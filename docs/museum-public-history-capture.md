# Public-chain RIGHTS and ownership capture

The public-history readers capture native RIGHTS selections and Core token
ownership at an explicitly pinned block, including ordinary public-chain block
heights. They query fixed address/topic filters over the entire numeric range
from block zero through that anchor, then read the matching receipts and block
headers. They avoid reading millions of unrelated headers and receipts.

This is a separate source profile with explicit trust in the RPC provider's log
completeness and canonical block mapping. Existing strict genesis-walk readers,
their 4,096-block bound, transcript format and profile bytes remain unchanged.
The new readers do not silently broaden those original profiles.

## Source products

| Kind | Native checks and derived output |
| --- | --- |
| `rights` | Both canonical collection/token selections, every revision through each native head, original Metadata publications, receipt authority, exact payload/definition bytes and six effective grant statuses; emits the original item-7 schema fragment. |
| `ownership` | Original mint, connected transfers, optional terminal burn, permanent collection identity and current Core owner/lifecycle; emits original ordered Transfer logs as canonical JSONL. |

RIGHTS preserves the [current RIGHTS semantics](museum-current-rights-evidence.md):
the installed Core pointers and original finality provider bind the selector;
token grants, including `unspecified`, take precedence. A zero native head means
no selected record, while unselected historical publications may still exist.
Publication and selection events must agree with every native selected revision.

Ownership continuity and the final owner catch missing or disconnected hops.
They cannot detect every silent provider omission: an omitted self-transfer or
transfer cycle returning to the same owner can leave the same final state.
The output explicitly retains this limitation. Ownership alone does not complete
acquisition item 10, prove legal title, or supply a full protocol event archive.

The standalone capture retains the source, frozen definitions and derived output.
It does not extend an existing examination or imply completion of the full
acquisition packet. Existing strict-profile dossier composers continue to require
their original input profiles. Public mint/entropy capture is a separate follow-on.

## Range coverage and checks

Each consumer derives its filters from the pinned native identity:

- RIGHTS queries the Metadata host's RIGHTS publications for the exact
  collection and collection/token subjects, plus the bound selector's events
  for those same subjects.
- Ownership queries the Core's `Transfer` event with the exact indexed token.

There is no caller-selected starting block, address list, topic list or transaction
hint. Each filter begins with inclusive 50,000-block windows. An explicit provider
range/size limit, oversized response, or response with at least 1,000 logs causes
deterministic binary subdivision, lower half first. Children exactly partition
their parent. Every completed leaf is retained; disclosed parent hits must survive
in the completed children. A limited or saturated single block fails capture.

Every returned log must match its requested filter and range, occur identically
in its successful full receipt, and agree with that receipt's transaction slot in
the canonical block header. All matching logs in retained receipts must equal the
query union. Duplicate contradictions, invalid receipt log order, conflicting
headers, backward touched-header timestamps and inconsistent adjacent parent links
fail. Global log-index gaps between unqueried transactions are valid.

The source header is checked by hash and number before and after the history
scan and again after native state reads. State and runtime calls use the exact
EIP-1898 block hash with `requireCanonical: true`. Repeated identical requests
must return identical results. These are consistency checks on provider answers;
the sparse headers do not prove ancestry, receipt tries or consensus.

`eth_getLogs` supplies no independently authenticated total. A successful response
below the threshold can still silently omit logs. The coverage report therefore
sets `providerLogCompletenessTrusted` and `canonicalMappingTrusted` to true,
and `genesisWalk`, `allBlockReceipts`, `ancestryProven` and `receiptTrieProven`
to false. Native state joins remain mandatory; an empty RPC page alone never
establishes a complete native item. See the [Ethereum JSON-RPC reference](https://ethereum.org/developers/docs/apis/json-rpc/)
for the RPC methods.

| Bound | Limit |
| --- | --- |
| Log queries, including split parents | 16,384 |
| Filters | 32 maximum; RIGHTS uses two and ownership one |
| Unique disclosed matching logs | 8,192 |
| Matching transaction receipts / touched blocks | 4,096 each |
| Transactions per touched block / logs per retained receipt | 8,192 / 4,096 |
| RPC response / transcript | 1 MiB / 64 MiB |
| Total RPC calls | 100,000 |
| RIGHTS revisions per subject / snapshot | 64 / 8 MiB |
| Capture package | 8,192 files / 96 MiB |

Exceeding a bound fails the capture. It never publishes a partial success.
Provider-specific errors beyond the recognized range/size outcomes also fail;
failed calls are never converted into empty pages.

## Capture a pinned source

Use the isolated Python environment from the [tooling README](../tools/museum/README.md).
The commands below are read-only. Supply a provider that supports historical
state/code calls by EIP-1898 hash, full transaction receipts, hash/number headers
and filtered logs over the required history.

First obtain an admitted deployment record and a specific source block. Construct
the canonical UTF-8 JSON anchor with these shared fields:
`profile`, `chainId`, `blockHash`, `blockNumber`, `timestamp`, `stateRoot`,
`environment`, `deploymentEvidenceHash`, `core`, `tokenId` and `collectionId`.
Use decimal strings for integers, lowercase `0x` hex for addresses/hashes and
`public_chain` for the environment. Anchors are limited to 65,536 bytes; extra
fields fail. `deploymentEvidenceHash` is an external admission commitment,
not an independently verified deployment proof in this capture.

- Ownership adds `coreRuntimeHash` and uses
  `STREAM_MUSEUM_PUBLIC_CORE_OWNERSHIP_HISTORY_V1` as `profile`.
- RIGHTS adds `host`, `router`, `originalFinality`, `provider`, `rightsSelector`,
  `schemas`, `store` and `codePins`, and uses
  `STREAM_MUSEUM_PUBLIC_RIGHTS_SOURCE_V1`. Each pin contains exactly `address`
  and `runtimeHash`; the list must cover the eight native hosts and any additional
  native contracts the selected evidence needs, up to 64 distinct pins.

Review the actual chain, block, deployment and runtime commitments before
admitting the anchor. Canonicalize with `tools.museum.canonical.dumps`; retain its
Keccak-256 hash independently. A hash computed from untrusted input establishes
byte agreement, not trust in that input. List the implemented source profiles:

```text
python -m tools.museum.public_history_capture profiles
```

Load the endpoint through your approved local credential workflow into a named
process environment variable, here `STREAM_PUBLIC_RPC`. The CLI accepts the
variable name, never a URL argument. Endpoints and remote error messages are not
included in capture evidence. HTTPS is required except for loopback HTTP;
redirects are refused and each request has a 30-second timeout.

```text
python -m tools.museum.public_history_capture capture --kind rights --anchor out/public-rights-anchor.json --anchor-hash 0x<external-anchor-hash> --source-profile-hash 0x<public-rights-profile-hash> --rpc-env STREAM_PUBLIC_RPC --disclosure public --output out/public-rights-capture

python -m tools.museum.public_history_capture capture --kind ownership --anchor out/public-ownership-anchor.json --anchor-hash 0x<external-anchor-hash> --source-profile-hash 0x<public-ownership-profile-hash> --rpc-env STREAM_PUBLIC_RPC --disclosure public --output out/public-ownership-capture
```

The output must be a new directory with an existing parent. Disclosure, input
shape, external pins and output constraints are checked before endpoint use.
The tool reconstructs the full capture offline before publishing through an
atomic no-overwrite directory operation. Record the printed manifest hash
outside the capture directory.

## Offline verification and retained evidence

```text
python -m tools.museum.public_history_capture verify out/public-rights-capture --manifest-hash 0x<external-result-manifest-hash>
```

Verification requires no endpoint or network connection. It consumes every
ordered transcript call, including sanitized split-limit outcomes, recomputes
the query schedule and native joins, then compares every file byte for byte.
The common `tools.museum.package_v2.verify_package` dispatcher also recognizes
this distinct capture mode.

Each capture contains `source/anchor.json`, `source/transcript.json`,
`source/snapshot.json`, the source/history/RPC/capture definitions,
`capture/report.json`, the derived RIGHTS files or ownership JSONL, and
`manifest.json`. The report retains the exact query ranges and explicit claims.
Rehashing an edited snapshot, profile, fragment or manifest cannot replace
reconstruction from the concrete source reader.

RPC provenance is caller-admitted; neither a transcript nor its local manifest
authenticates the provider. Synthetic controls exercise the same native wire
readers at public-size block heights. They do not establish actual Sepolia or
mainnet execution. This batch includes no live RPC capture, native rebuild,
registered source profile or deployment acceptance.
