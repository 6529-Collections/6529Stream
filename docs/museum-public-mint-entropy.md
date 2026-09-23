# Public mint and original-coordinator entropy capture

`PublicMintEntropySource` applies the original native mint/entropy checks at
public-chain block heights through the frozen [public-history reader](museum-public-history-capture.md).
The separate `public_mint_entropy_capture` command retains the complete source
capture, native mint events, original entropy packet fragment and exact ABI
leaf preimage, then verifies them offline before publishing.

The original strict `MintEntropySource`, its genesis-walk transcript/profile,
and earlier capture/examination profiles remain unchanged. The new profile
explicitly trusts provider log completeness and canonical block mapping.
It does not establish a complete paid-sale authorization record, full acquisition
packet, consensus, oracle quality or actual-chain acceptance.

## Two source-derived history stages

The primary scan covers numeric block zero through the exact anchor with four
filters: Core allocation/reversion events for the token, Core transfers for the
token, original-coordinator entropy registration for the token, and that
coordinator's token request/finalization events.

The reader derives request keys from the returned request/finalization events.
Those keys supply three control filters: terminal events by request key and
recovery-supersession events by either indexed request key. With no derived
keys, the control scan is explicitly `not_queried_no_request_keys`. The native
state must still reconcile with the observed unrequested registration.
Caller-supplied keys, filters, deployment starts and transaction hints are rejected.

Both stages use the same bounded window/split algorithm and retain every query
range. The union is checked again across stages: complete matching receipt logs,
duplicate observations, global block log positions/order, transaction block
identity, touched-header timestamps and adjacent parent links must agree.
A control event already visible inside a primary receipt cannot disappear from
the control queries. State/code reads use the pinned canonical block hash, and
both header mappings are repeated after all native reads.

The existing native checks bind Core identity/lifecycle and
`coordinatorAtMint`, original mint allocation/registration/Transfer chronology,
locked initial policy, every observed request's policy/hash/provider ID,
terminal transitions, fresh recovery and late-original supersession. The
original entropy leaf and event-reference schema remain unchanged.

### Active attempt and observed request history

Late original fulfillment can restore **active attempt 1** after **attempt 2**
was requested. The leaf retains the actual active request and attempt. A separate
`requestHistoryObservation` retains `observedRequestCount` and
`observedMaximumAttempt`; neither claims a proven lifetime highwater.

For example, the late-original control has two original request records and
three request/finalization event references, while its final leaf has
`requestAttempt: "1"`. Treating that leaf field as a lifetime count would discard
the superseded recovery request. Provider omissions remain possible even when
all retained events and native state agree.

Supported statuses remain `REGISTERED`, `REQUESTED`, `FINALIZED`, `STALE` and
`FAILED`. Only reconciled `FINALIZED` is terminal-eligible within this profile.
`NONE`, `DISABLED` and `NOT_REQUIRED` fail; this reader admits no writer or
renderer-based exemption for those statuses. Missing current policy/recovery
getters also fail, including on historical deployments with similar interfaces.

## Bounds and outputs

The two stages share one 64 MiB transcript and 100,000-call cap. The combined
union is limited to 8,192 matching logs, 4,096 receipts and 4,096 touched blocks.
There are at most 64 request/finalization events and derived request keys, a
16,384-byte token-data bound, and a 4 MiB snapshot bound. Each stage retains
the public-history query/response/split limits. Any exceeded bound or unavailable
history fails the capture, without publishing a partial result.

The package contains:

- Exact `source/anchor.json`, `source/transcript.json`, `source/snapshot.json`.
- Frozen source/history/RPC/capture definitions and `capture/report.json`.
- `mint/evidence.json` with original native mint/allocation/registration events
  and `mint/transfers.jsonl` with the token's returned transfer history.
- `entropy/packet-fragment.json`, `entropy/leaf-preimage.bin` and
  `entropy/request-history-observation.json`.
- A closed, externally pinned `manifest.json` over every retained file.

The original mint transaction's full receipt is retained in the transcript.
This source does not obtain transaction input/signature bytes or perform the
complete paid-sale reconstruction described in the
[retained-mint composer](museum-mint-entropy-evidence.md).

## Capture and replay

Use the [Museum Python environment](../tools/museum/README.md). Construct the
same closed anchor fields as the original mint/entropy reader, with the new
`STREAM_MUSEUM_PUBLIC_MINT_ENTROPY_SOURCE_V1` profile: `chainId`, `core`,
`coordinator`, `tokenId`, `collectionId`, `blockHash`, `blockNumber`, `timestamp`,
`stateRoot`, `environment`, `deploymentEvidenceHash`, `codePins` and `profile`.
Pin the original coordinator, its actual runtime and the exact source block.
The code-pin list contains 2–32 distinct `{address, runtimeHash}` entries.

```text
python -m tools.museum.public_mint_entropy_capture profiles

python -m tools.museum.public_mint_entropy_capture capture --anchor out/public-entropy-anchor.json --anchor-hash 0x<external-anchor-hash> --source-profile-hash 0x<public-entropy-source-profile-hash> --rpc-env STREAM_PUBLIC_RPC --disclosure public --output out/public-entropy-capture

python -m tools.museum.public_mint_entropy_capture verify out/public-entropy-capture --manifest-hash 0x<external-result-manifest-hash>
```

The endpoint comes only from the named process environment variable. It must
serve the entire historical log range and exact historical state/code reads.
Output must be new with an existing parent. Disclosure, anchor schema/pins and
output constraints are checked before endpoint use. The tool fully reconstructs
the capture offline before atomic no-overwrite publication; the common package
verifier also dispatches this distinct mode. Verification requires no network.

## Historical RC1 boundary

The deployed September 10 RC1 predates four required entropy getters and the
fresh-recovery producer. The current public entropy reader cannot consume it.
The [concrete RC1 recipe](museum-rc1-public-capture.md) uses its supported
ownership ABI, retains immutable source/runtime/block pins, and explains the
observed public-provider history limitation. A future historical entropy reader
would require its own admitted RC1 profile; fixed values or missing calls must
not be fabricated for this current profile.
