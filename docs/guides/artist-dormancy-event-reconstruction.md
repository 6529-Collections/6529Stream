# Dormancy and steward event reconstruction

The existing operations 41, 42, 43 and 59 now emit additive schema-1 typed
context events immediately after their original events. Original event
signatures and payloads, record domains, storage, authorization, replay and
Archive recipes are unchanged. A fixed linked emission library executes in
the Identity owner's context; the original Identity address remains the emitter.

| Original event | Companion | Additional reconstructible state |
| --- | --- | --- |
| `ArtistDormancyInitiated` | `ArtistDormancyNoticeContext` | Complete original Notice, including incumbent, times, timing revision, prior activity and governance witness commitment |
| `ArtistDormancyCancelled` | `ArtistDormancyCancellationContext` | Complete cancellation Terminal and the original incremented activity count |
| `ArtistDormancyCompleted` | `ArtistDormancyCompletionContext` | Complete Terminal, original selected plan, appointment, evidence, governance witness commitment and delegation epoch |
| `StewardCapabilitiesGranted` | `ArtistStewardCapabilityContext` | Complete original operation-59 Record, including terms, exact governance witness and predecessor head |

Every companion carries the constructor-captured chain ID, Registry, actual
Identity owner, recorder and recorder authority class. Governance-authored
notice, completion and later capability grants use recorder class 0: the
Executor is not being represented as an Artist signer. The completion's
separate Terminal/Plan class remains the actually vested class 3 or 4.
Authenticated cancellation retains its actual signer and class 1, 2 or 3.

The typed values retain their nonzero record hash for joining events and reads.
Recompute the notice hash with the original notice domain and its ordered
fields. For cancellation, completion and operation 59, copy the emitted tuple,
set only its self-hash field to zero, and encode the original domain, captured
chain, Registry and Identity owner followed by that tuple. Cancellation also
appends the emitted activity count. These are the existing preimages, not new
record domains or generic opaque reconstruction payloads.

A reader must pin its chain/Registry/Identity context and authenticate log
provenance independently. A caller-supplied array containing an emitter field
is not proof of an actual chain receipt. After authenticating the log source,
pair each original event with its following typed companion, verify all repeated
fields and the record hash, then apply the chronological transition. Reject
missing or orphan companions, duplicate records, foreign context and invalid
predecessor ordering. A complete-prefix claim still needs a trusted start/end
boundary or final state comparison; an internally valid suffix is not proof
that all earlier history was supplied.

The independent `ArtistDormancyEventFold` test reader uses only log bytes and
explicit pins. It does not call the producers, load payload pointers, or read
state while reconstructing. Its authored scenarios compare the resulting
Notice/Terminal/grant records and timeline heads to ordinary reads afterward.
They exercise actual Safe cancellation followed by a second notice, actual
class-3 and class-4 completion, two sequential capability grants, missing,
duplicate, reordered and altered events, and late-Archive failure with the
same Safe nonce and calldata retry. Exact two-call Archive expectations witness
both the failed attempt and healthy retry. Reverted-frame inspector LOGs are
not claimed as durable receipt evidence; rollback is checked through the
original roots, notice state and Safe nonce, and only the successful retry's
emissions enter the reconstructed durable timeline.

This is one finite AA-RECON 1–2 slice. Other record families, historical imports,
contested/dismissed timeline presentation, both global record-chain accumulators,
mirrored event-history snapshots and complete-history evidence remain separate.
The state-carried authority bytes and payload catalog remain available under
[Artist state reconstruction](artist-state-reconstruction.md).

Five new regression bodies are authored over the actual Artist/Safe/Archive
fixture, with explicit typed Core/governance boundaries. ABI/type checks are
recorded separately; this source batch does not claim native execution, complete
current-stack coverage, all-product size acceptance or transaction capacity.

```powershell
python scripts/dev.py test --suite unit --via-ir --match-path test/unit/artist/StreamArtistDormancyEventReconstruction.t.sol --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

The command uses the original aggregate unit fixture and CREATE order. Include
its original Arweave JSON files in any isolated runtime capture.
