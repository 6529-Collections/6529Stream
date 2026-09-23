# Read-only current-stack monitor

The CLI in [`tools/operations`](../tools/operations/README.md) observes one
explicitly pinned block. It checks deployment identity and runtime hashes,
reads a small set of supported state views, and retains selected event
identities. Every RPC result or classified failure is replayable offline.
It has no signer, broadcast method, alert delivery, scheduler or hosted service.

This is a pre-audit contributor tool. Offline transport regressions are covered;
an actual current-stack or testnet rehearsal is still required. The
[older monitoring baseline](monitoring.md) remains a separate scope. This tool
does not establish release readiness, policy correctness or consensus finality.

## Existing inputs and their authority

Supply independently retained pins. Computing a new pin for an unreviewed or
changed input only records those bytes; it does not authenticate their origin.

| Input | Commitment and purpose |
| --- | --- |
| Existing `anchor.json` | External SHA-256; chain ID, Core, block hash/number, timestamp, state root, environment and code pins |
| Existing `deployment-evidence.json` | Exact-byte Keccak-256 from the anchor; actual deployed artifact addresses, runtime hashes and byte lengths |
| Existing native products manifest | SHA-256 from deployment evidence; `current_museum_native_products_v1` compiler input inventory |
| Native compiler artifacts | SHA-256 and exact source/contract identity from both the native manifest and deployment evidence; ABI and `methodIdentifiers` |
| [Genesis profile v2](../release-artifacts/genesis-deployment-profile.json) | External SHA-256; ordered 37 role IDs/keys and multiplicity |
| Optional canonical deployment candidate v2 | External SHA-256; explicit role/address/artifact/runtime bindings for the same chain and genesis profile |

The capture adapter consumes the formats produced by
[`current_museum_capture.py`](../tools/museum/current_museum_capture.py) and
[`current_native_fixture.py`](../tools/museum/current_native_fixture.py).
A native inventory without actual deployment rows is refused. Additional
anchor code pins, such as Safe components, get runtime checks even when no
native ABI is present for them.

The optional candidate uses the existing
[candidate schema](../deployments/schema/canonical-deployment-candidate.v2.schema.json).
This monitor checks only its monitoring bindings; run the existing canonical
candidate validator separately for release acceptance. Role addresses must be
distinct in this adapter. Exact implementation names must match the profile;
equivalent implementation acceptance remains the canonical validator's job.
Roles are never inferred from artifact names. Without a candidate, all 37 role
bindings are unavailable even if the selected captured products match.

The checked-in mainnet planning candidate has no deployment instances and is
not a local-chain deployment. Do not relabel it or a native products inventory
as actual 37-role evidence. The genesis profile's mainnet chain is normative;
the capture anchor identifies the observed chain, and a supplied candidate must
agree with that anchor.

Artifact paths must resolve as recorded in the pinned native input. Inputs
use canonical lowercase hexadecimal addresses/hashes. No alternate deployment
manifest, address guessing, compiler invocation or automatic path rewriting is
part of this command.

## Run a pinned observation

Use the [existing Museum Python environment](../tools/museum/README.md); the
monitor adds no Python dependency. Configure the RPC URL through the named
environment variable using the operator's normal credential mechanism. The
command takes the variable's name, never the URL as an argument.

The following shell example uses operator-supplied file paths and exact pins:

```sh
python -m tools.operations.current_health \
  --anchor "$ANCHOR" --anchor-sha256 "$ANCHOR_SHA256" \
  --deployment-evidence "$DEPLOYMENT_EVIDENCE" \
  --native-manifest "$NATIVE_MANIFEST" \
  --genesis-profile release-artifacts/genesis-deployment-profile.json \
  --genesis-profile-sha256 "$GENESIS_PROFILE_SHA256" \
  --candidate "$CANDIDATE" --candidate-sha256 "$CANDIDATE_SHA256" \
  --endpoint-env STREAM_MONITOR_RPC_URL --output artifacts/monitor-run-001
```

Omit both candidate flags when no authenticated role binding is available.
Use a new output directory for each run. A successful collection writes
`report.json`, `transcript.json` and `pins.json`; existing directories are
refused. The report includes exact input and reader-source hashes. It contains
no endpoint URL or RPC error message. Runtime and contract event data are
public observations, so review retained files under the deployment's normal
evidence policy before publishing them.

The endpoint must support EIP-1898 block-hash `eth_call`/`eth_getCode`, plus
block-hash `eth_getLogs`. The monitor never falls back to `latest` or silently
switches to number-only state reads. An unsupported method becomes unavailable.
HTTP is allowed only for loopback hosts; other endpoints require HTTPS.
Redirects are refused. Requests use a ten-second socket timeout and stop
starting requests after a sixty-second collection budget. These are transport
bounds, not a guarantee against a slowly streaming peer.

The requested anchor can be historical. No wall-clock freshness or number of
confirmations is inferred. Select a new authenticated anchor when the intended
observation block changes.

## Replay and interpret the report

Retain the exact source bytes, input files and an independent copy of the
transcript's SHA-256. Repeat the command with the same inputs, replacing
`--endpoint-env` with:

```sh
--replay artifacts/monitor-run-001/transcript.json \
--replay-sha256 "$TRANSCRIPT_SHA256" --output artifacts/monitor-replay-001
```

Replay requires exact call order, block parameters and complete transcript
consumption. Online collection automatically performs this offline comparison
before writing results. Changing source bytes, including line endings, changes
the source identity recorded in the report.

| Outcome | Meaning | Exit code |
| --- | --- | --- |
| `observed` | All configured checks and supplied role bindings were observed without a reported issue | 0 |
| `incomplete` | Required coverage or a read is unavailable | 2 |
| `attention` | A pause, uninitialized genesis or pending recovery count requires operator review | 2 |
| `failure` | Chain/block identity, runtime expectation or event consistency failed | 2 |
| Collection rejection | A pin/format is invalid, a collection bound is exceeded, replay differs, or output cannot be created | 1 |

Outcome precedence is failure, attention, incomplete, observed. Always inspect
all incidents: an attention report can also have missing roles. `observed`
describes this bounded check set and is not an overall health or readiness
certificate. Unsupported views are listed separately for each artifact.

`coherentBlock` is true only when chain identity and the pinned block's
hash/number/timestamp/state root match, including the canonical block-number
lookup both before and after collection. A late reorg or failed final lookup
invalidates that common-block conclusion; earlier per-read matches remain
historical observations. The endpoint is trusted to report honestly. No receipt
proof, state proof, independent-provider quorum or finality verification occurs.

## Supported state and event coverage

Each call requires both its exact read-only ABI signature/output shape and the
matching compiler selector in the authenticated artifact. Runtime mismatch
withholds all ABI reads and event interpretation for that address.

| View | Retained observation |
| --- | --- |
| `genesisInitialized()` | Initialization boolean; false requires review |
| `governanceActionPolicyState()` | Candidate profile hash, catalog hash, entry count and revision |
| `entropyPolicyInventory()` | Count, serial and ID digest |
| `incompleteFinalityRecoveryRefreshPlanCount()` | Pending count; nonzero requires review |
| `recoveryExecutorBinding()` | Bound executor and code hash |
| `paused()` | Pause boolean; true requires review |

Counts and hashes are observations, not comparisons against an approved policy
baseline. The tool does not traverse per-collection policies, execute recovery,
verify recovery executor code, or infer per-sale pauses. In particular, current
Dutch sales has no global pause getter; no such selector is guessed.

The finite `EVENT_NAMES` allowlist in the source covers selected genesis,
governance-policy, pause and recovery events. Signatures and topic hashes come
from each authenticated ABI. Only events in the anchor block are requested.
Returned records must match the address, block hash/number and expected topic
count, be non-removed, and have unique block log indices. Retained identities
include chain, block, transaction, log index and contract; raw data is hashed.
Selected events across all monitored products must agree on each transaction's
hash/index mapping and transaction order within the block.
Event payloads are not semantically decoded and an empty event list says
nothing about earlier blocks. This is not a historical indexer.

Input/response/transcript sizes and product/call/log counts are bounded in the
source. Incident IDs derive deterministically from the chain, anchor block,
severity, reason and subject. This permits a future caller to deduplicate
reports without requiring an external alert integration now.

## Contributor checks and pending rehearsal

```sh
python -m unittest tools.operations.test_current_health -v
python -m tools.docs.test_markdown_links
python -m tools.docs.check_markdown_links
python -m tools.docs.check_changelog
```

The offline suite exercises partial role coverage, pin/artifact tampering,
exact replay, malformed/refused reads, RPC error redaction, runtime drift,
reorgs, event inconsistencies and lossless uint256 values. Its synthetic ABI
fixtures are transport tests and must not be retained as actual-stack evidence.

The next acceptance step requires an authenticated deployment capture, native
artifacts and an available read-only RPC endpoint for that block. Retain the
real report and transcript, replay them, and record selected-graph versus
37-role coverage honestly. Full graph capture, current deployment rehearsal,
testnet rehearsal and hosted operation remain separate pending work.
