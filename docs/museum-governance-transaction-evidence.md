# Original governance transaction evidence

The Museum consumer can recover the original ordered `GovernanceCall` records
and action-ID preimage from the Executor's scheduling and execution transaction
inputs. A new standalone `STREAM_ACQUISITION_GOVERNANCE_TRANSACTIONS_V1`
fragment records that evidence. Its assembler preserves the complete V6
package and exports the exact same V6 packet bytes.

This is prospective, unregistered tooling. Encoded transaction fixtures and
offline replay do not establish native execution, historical authority, source
authenticity, consensus, acquisition acceptance or deployment readiness.

## Original evidence and reconstruction

The source profile is pinned to native source commit
`e031ce6f5f7a79f8c098d4ad0242ee02ce1b0116`. It first replays an externally
pinned [original native finality capture](museum-acquisition-finality-v6.md).
That capture supplies the source state, Executor address and runtime commitment,
original schedule and execution events, successful receipts, and block headers.
The new source derives both transaction lookup hashes from those events.

The separate RPC profile allows exactly a chain-ID request and the two original
transaction lookups. It retains canonical JSON bytes for each returned
transaction, including its complete input, and the original capture's receipt
and header bytes. The returned hash, block hash, block number and transaction
index must match the original event and receipt. The header must contain that
transaction in the exact slot. Complete receipt logs must agree with the native
capture. Receipt sender/recipient fields are compared when present; they are
never inserted into the original bytes.

The first profile understands canonical direct Executor inputs for:

- `scheduleGovernanceBatch` and `executeGovernanceBatch`.
- `scheduleGovernanceAction` and `executeGovernanceAction`.

Each recovered call retains target, value, selector, calldata hash, scope hash,
old-value hash and new-value hash. The verifier checks every call against the
original scheduled calldata carrier and preserves call order. It recomputes the
V2 calls hash and the three independent aggregate transition hashes. Even a
single-call wrapper uses those aggregate hashes. The stored target and selector
describe the first call; its value describes the sum of all calls.

The action-ID preimage uses the original chain and Executor, action class,
calls hash, aggregate transitions, scheduling-event nonce, time window, reason
hash and manifest hash. The event nonce is distinct from the Ethereum
transaction nonce. The original reason URI and callers must also match, though
they are not action-ID fields. The finality call is checked at its actual index,
including target, zero value, selector and original per-call execution context.

Single-action execution omits the private per-call transition hashes. The
verifier recovers them from original scheduling input when available; it cannot
invert the stored aggregate hashes to fill missing evidence.

## Availability and authority are separate

| Original inputs | Report |
| --- | --- |
| Both supported inputs agree | `reconstructed`; ordered call and action-ID preimages checked |
| Scheduling missing, batch execution available | `partial`; call/action preimages may still be checked |
| Scheduling missing, single-action execution available | `partial`; private per-call transition preimages unavailable |
| Execution missing, supported scheduling available | `partial`; scheduling-derived preimages may be checked |
| RPC returns null | Retained as `not_returned`; pruning is not inferred |
| Indirect wrapper, unknown selector or noncanonical encoding | Original bytes retained with an explicit partial reason |

RPC errors abort rather than becoming missing or empty evidence. Recognized,
decoded contradictions in calls, action IDs, actors or source anchors reject.
The canonical-encoding restriction is an availability policy: native dispatch
may accept encodings with trailing bytes that this profile reports as partial.
Likewise, 64 calls, 32,768 bytes per call, 131,072 bytes per transaction and the
24,576-byte saved carrier bound are reader limits, not new protocol limits.

If the transaction includes `chainId`, it must match the source chain. An
absent legacy field is recorded through `chainBoundBy: source_anchor_and_block`;
the verifier does not invent a transaction field or recompute a signed
transaction envelope. RPC hashes and senders remain provider observations.

Complete preimages do not establish historical roles, policy catalogs,
bootstrap delay exceptions, signer authorization or EVM execution. Current
roles and Core facts are never substituted. Historical Core facts remain
hash-only, `completeAuthority` stays false, and acquisition item 3 remains
partial. The original V5/V6 schemas, native fragment, source profiles and V6
packet claims retain their published bytes.

Scoped, STATIC, policy V2 and VIEW native finality semantics remain required
following batches. The collection-only profile is a bounded first step, not a
full-v1 exclusion. Wrapper-specific transaction capture and historical authority
evidence also remain separate work.

## Capture and replay

Use the existing isolated Python environment from the
[Museum tooling guide](../tools/museum/README.md). Print the new profile hashes:

```bash
python -m tools.museum.public_governance_transaction_capture profiles
python -m tools.museum.acquisition_governance_transactions_v1 profiles
```

Live read-only capture takes a previously verified native capture and its
external manifest commitment. The endpoint stays in a process environment
variable; it is not saved in the package:

```bash
python -m tools.museum.public_governance_transaction_capture capture \
  --native original-native-capture --native-hash NATIVE_MANIFEST_HASH \
  --source-profile-hash SOURCE_PROFILE_HASH --rpc-env PUBLIC_RPC_URL \
  --disclosure public --output original-governance-capture
```

For offline replay, replace `capture` with `replay` and replace `--rpc-env` with
`--transcript`, `--transcript-hash`, and explicit `--provenance trusted_rpc` or
`--provenance synthetic_fixture`. Provenance must match the original native
capture. The replay consumes every retained request in exact order.

The capture contains the whole original capture under `inputs/native-finality/`,
a new source anchor/transcript/snapshot, exact new definitions, the standalone
fragment at `governance/transactions.json`, and a reconstruction report.

```bash
python -m tools.museum.public_governance_transaction_capture verify \
  original-governance-capture --manifest-hash CAPTURE_MANIFEST_HASH
python -m tools.museum.acquisition_governance_transactions_v1 assemble \
  --packet original-v6 --packet-hash V6_MANIFEST_HASH \
  --transactions original-governance-capture --transactions-hash CAPTURE_MANIFEST_HASH \
  --disclosure public --output v6-with-governance-evidence
```

Assembly requires byte equality between the entire native capture retained in
V6 and the one retained in the new capture. All original V6 paths survive;
only its manifest moves to `inputs/finality-v6-manifest.json`. New evidence is
under `acquisition-governance/`, with the additive report at
`governance/assembly.json`. The existing V6 packet remains at
`finality/acquisition-packet-v6.json`.

The assembly commands `verify`, `export-packet`, and `complete-packet` accept
the output directory and `--manifest-hash`. Export returns the original V6
bytes. Complete-packet continues to refuse unresolved source coverage.
The common package verifier dispatches both new modes.

Generate/check only the new standalone schema with:

```bash
python -m tools.metadata.acquisition_governance_transactions_v1 --check
```

Focused tests use real canonical Executor ABI encodings, complete single/batch
preimages, an actual non-first finality index, missing inputs, noncanonical and
indirect inputs, tampered/reordered calls and cross-chain/source refusals. CLI
replay, verification, assembly and export run with sockets disabled. No live
RPC request or onchain action is needed for these checks.
