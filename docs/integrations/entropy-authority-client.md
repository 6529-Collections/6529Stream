# Artist entropy findings and hydration from the current client

`CurrentEntropyAuthorityClient` prepares the explicit entropy-unavailability
paths added by `IStreamArtistEntropyUnavailability` and
`IStreamArtistEntropyFindingHydration`. It uses caller-selected compiler ABIs;
existing generated catalogs and the ordinary entropy/content-consent helpers
remain unchanged. It creates unsigned calls and performs RPC reads/simulations.
It never signs, broadcasts, schedules governance or installs authority.

Supply the actual chain ID, Core, Artist facade and entropy Coordinator addresses,
and independently obtained runtime hashes. The helper checks code at a fixed
block, reciprocal Core and all seven owner bindings, then rechecks that block's
hash. Finding preparation and fresh recovery also require the actual current
Core Artist/entropy pointers and their runtime hashes. Hydration intentionally
permits the destination before Core cutover; its actual operation-60 simulation
must authenticate the original sealed source and complete request.

## One finding-backed recovery

1. Use `quoteFinding(provider, { artistId, recovery, unavailableEvidenceHash,
   reasonHash })`. It reads the full token **or** scope recovery intent and fresh
   preview, constructs the original target/evidence hash, and reads the actual
   finding context. The result includes the zero-value
   `recordEntropyUnavailabilityFinding` calldata and original scope/old/new hashes
   for the existing class-2 Arbiter action. Submit those through the existing
   governance stage workflow. The quote is not permission for a direct Artist
   Safe or arbitrary executor to record the finding. Rebuild the context before
   scheduling/execution if the target, state, policy or provider changed.
2. After that action executes and its notice expires, call
   `quoteRecovery(provider, executor, recovery, findingRecordHash, nativeAllowance)`.
   The complete original ten-word finding and supplemental target/intent/runtime
   evidence are checked against the original Registry returned by Identity owner
   **index 2**. The current Artist verifier independently checks current binding,
   latest finding, current activity, coordinator and intent. Hydration never
   substitutes a successor Registry into an old finding's hash domain.
3. Call `resume(provider, plan)` immediately before signing/submission. It repeats
   the current quote and simulates the exact payable request as `executor` at
   `pending`. The existing entropy role, block delay, request/provider admission,
   notice, fee, consumed finding and replay checks remain onchain. A changed fee
   or intent requires a new plan; the failed original is not rewritten.
4. `safeCall(plan)` produces a single `operation: 0` CALL for the executor Safe.
   `msg.value` is the executor's native allowance, separate from any sale payment.
   Only the quoted provider fee is spent; native excess remains that executor's
   original fee credit. Use the existing `prepareEntropyFeeCreditClaim` from the
   same executor when claiming it. No fresh draw or fee is reserved by a quote.
5. Require the original Safe's `ExecutionSuccess` for an independently verified
   complete Safe transaction hash using `requireSafeExecution`, then read the
   application result. `resume` recognizes completed recovery only from the
   entropy host's exact saved request-key finding/intent/notice evidence. A matching
   receipt is history, not permission to execute the request again.

The original operation-17 Artist content-consent path is still available in
`current-entropy.ts`. It does not silently become an entropy-finding path.
Artwork-finality findings are not accepted by this helper as entropy evidence.

## Complete operation-60 request

`quoteHydration(provider, caller, request)` encodes exactly:

```text
{ authority: { bindingIndex, artistId, collectionId, expectedSource[7],
               replayOrigins[7][], policies[] },
  includePayout, publications, economics[], attestations[] }
```

All integers, including `uint8`, revisions and full-width nonces, are `bigint`.
The tuple is copied and frozen before the first asynchronous read. Extra fields,
wrong array lengths and out-of-range integers reject. Economics requires payout;
attestations require economics; publication composition requires attestations.
The selected profile is `6529STREAM_ARTIST_ENTROPY_FINDING_HYDRATION_V1` under the
original permissionless operation 60. No new signature domain is introduced.

Build the request from the actual source owner's complete original checkpoint,
replay-origin, policy/economics/attestation history. This helper is a typed
transport and simulator; it does not discover omitted records, create source
proofs, or treat supplied rows as authorization. The contract validates all
seven source headers, original history/replay/nonce completeness and op23
admissions before the atomic owner/Archive transition. See the
[complete finding hydration profile](../guides/artist-entropy-finding-hydration.md)
for supported history and source bounds.

The initial simulation returns the actual expected completion commitment.
`resume` returns `pending` only after repeating the original call simulation with
that exact commitment, and `completed` only when all seven owner markers equal
it. Mixed or different markers fail. The pending call stays byte-identical after
an Archive failure. The in-memory plan belongs to its creating client; arbitrary
JSON or a spread-copy cannot be passed off as a validated plan. After a process
restart, re-quote from the saved original source request and compare the saved
call/commitment. If already completed, retain the successful transaction and all
seven marker readbacks instead of attempting another hydration.

## Runnable Safe preparation

From `packages/stream-client`:

```powershell
npm run build
node examples/current-entropy-authority.mjs CONFIG.json
node examples/current-entropy-authority.mjs CONFIG.json ORIGINAL_RECIPE.json EXTERNALLY_SAVED_HASH
```

The JSON config supplies `rpcURL`, an explicit `compilerFixture` path, `chainId`
as a decimal string, the six `deployment` address/runtime-pin fields, and one of:

- `operation: "finding-context"`, plus the `input` from step 1;
- `operation: "recovery"`, `caller`, `recovery`, `finding`, and decimal-string
  `nativeAllowance`;
- `operation: "hydration"`, `caller`, and the complete `request` above.

Inside the hydration JSON, encode each integer as `{ "$bigint": "123" }`.
Hashes and addresses remain strings. These tags make integer conversion explicit
without guessing from arbitrary text. The example uses an uncached RPC provider,
checks the Safe nonce before and after preparation, and prints a local recipe
hash over the exact CALL, nonce, runtime pins and observed commitment. Save the
output and that original hash separately. The optional retry arguments compare
those original coordinates; they do not recalculate an edited file's authority.
The local recipe hash is not a Safe transaction hash or signing domain.

The complete Safe transaction also contains gas/refund fields and signatures.
Keep those exact original bytes externally. Simulate that full transaction as
well: the client target simulation does not prove Safe signature/threshold or
refund success. A reverted `GS013` may preserve the nonce, while an emitted
`ExecutionFailure` can consume it. Re-read the actual nonce. Never assume failed
Safe execution permits the same signatures to be replayed. A changed nonce or
changed signed field requires newly authorized signatures.

## ABI and validation boundary

Generate an explicit encoding fixture from the selected compiler invocation:

```powershell
node scripts/generate-current-entropy-authority-fixture.mjs INPUT.json OUTPUT.json test/fixtures/current-entropy-authority-abi.json
```

The retained fixture is from the final finding-hydration compiler input supplied
by its author, integrated at `7209675b`; it selects actual facade, entropy,
Coordinator, Identity and Core ABI entries and records their source hashes.
It is not a deployment manifest. The focused tests use synthetic RPC responses
plus literal original hash preimages and compiler ABI oracles, including malformed
reads, notice, input drift, old-domain provenance, complete hydration, callback
failure/retry and Safe failure-event handling. They establish client encoding and
state handling, not actual onchain execution, gas/capacity, source completeness,
full Safe signature behavior or release readiness. No Solidity/native campaign
is part of this client batch.
