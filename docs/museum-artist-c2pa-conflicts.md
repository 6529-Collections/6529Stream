# Museum Artist C2PA standing conflicts

The additive [V2 consumer](../tools/museum/artist_c2pa_conflicts.py) interprets
supplied conflict history from Artist source commit
`e21d58e402f171a94009696b7f9373c12ed3a64f`. Its
[prospective profile](../schemas/museum/artist-c2pa-v2/profile.json) pins the
original source files and the unchanged [V1 profile](museum-artist-c2pa.md).
V1 credentials, reconciliation reports and the six-word Display keep their
existing meaning and profile bytes.

## Supplied evidence

`consume(ScopeEvidence)` checks one collection-and-subject history. The scope
contains the V1 `Context`, report definition, current Selection, complete
revision-ordered Selection prefix, Display and original `ReportEvidence` tuples.
It adds the exact `standingConflict` return, the complete conflict prefix,
historical acknowledgements and the supplied Attribution and chunk-store
addresses. All reads are inert bytes; the consumer performs no RPC calls.

| Evidence | Exact native return |
| --- | --- |
| Standing | Six static words, 192 bytes |
| Conflict | Twelve static words, 384 bytes |
| Resolution | Five static words, 160 bytes |
| Original Artist dispute Head | Seven static words, 224 bytes |
| Original Artist dispute Resolution | Fifteen static words, 480 bytes |
| Original Artist dispute opening Record | Nineteen static words, 608 bytes |
| Collection archival coverage facts | Twelve static words, 384 bytes |

Each `ConflictEvidence` retains `conflictAt`'s identifier, the original Conflict,
Resolution and ABI-wrapped `resolutionNarrative` return. The consumer joins every
conflict to the original adverse Selection, requires contiguous revisions and
checks the native conflict and chain hashes. Only reports that assert authorship
and record `DIVERGENT` create conflicts. Superseded or stale reports remain in
the history. The latest unresolved conflict determines the Standing tail;
clearing all conflicts preserves the full revision count and chain hash.

`consume_static(token_id, raw, collection_scope, token_scope)` checks the static
companion's 384-byte token/collection Standing pair. Both scopes are retained
independently with their canonical subjects and matching source context. Token
ID zero requires an empty token Standing and no token scope. No collection
history is suppressed by a token-specific result.

ABI inputs must round-trip exactly, including narrow integers, offsets,
booleans, padding and trailing bytes. Each history is bounded to 256 entries.
All input byte occurrences, including repeated bytes across both scopes, count
toward a 16 MiB limit before result construction. Supplied archival coverage
runtime is bounded to 24,576 bytes. These are offline consumer bounds.

## Historical acknowledgement

A nonempty stored Resolution requires a separate `Acknowledgement`. It records
the source block number, hash and timestamp and retains these original reads:

- `attributionDisputeResolution(actionId)` from the fixed Attribution owner;
- the closed `attributionDispute(collectionId, originalGeneration)` Head at
  acknowledgement time and `attributionDisputeRecord(disputeRecordHash)`;
- ABI-wrapped evidence and disposition-narrative chunk returns;
- the Artist registry's archival coverage address and code-hash returns,
  supplied coverage runtime and collection evidence coverage facts.

The acknowledgement timestamp must equal the stored `acknowledgedAt`, its block
cannot follow the observation block, and a same-block observation must use the
same block hash. Acknowledgements sharing one chain and block number must agree
on hash and timestamp, including across token and collection scopes. Original
resolution time must fall between conflict recording and acknowledgement.
The checks reproduce the native clearing guards for the original collection,
artist, binding and generation, action and opening record, resolution/action
classes, actor/proposer/witness, typed evidence, exact disposition narrative and
coverage/runtime commitments. They do not promote a later binding to the
historical conflict's scope.

The optional `current_head` is a separate original-generation Head observation
at the current context block. A later open dispute is retained without replacing
the historical closed Head or automatically reviving a cleared conflict. The
result reports the number of checked acknowledgements explicitly. Supplied
closed Heads cannot prove what actually existed at an earlier block without
independent capture authentication.

## Evidence boundary

Original op46 does **not** emit an `artistNativeReceipt`. Its action identifier
is a governance identifier, not a hash of the returned Resolution tuple. This
consumer invents neither a receipt nor a governance preimage. It also does not
recompute an opening Record using a presumed current Registry: historical
hydration may retain an earlier domain, and the native clearing guard checks
the original getter fields directly.

Successful output establishes supplied-byte and guard correspondence. Source
authentication, original op46 governance/signatures/events/archive evidence,
underlying archival coverage receipts, C2PA cryptography, current authority and
full dossier acceptance remain separate. The supplied Display remains live and
separate from both recorded reports and Standing. Changing the full output JSON
makes an earlier full-output hash stale; this reader establishes no universal
frozen JSON or freeze-safe rendering.

Run with the repository's Museum Python environment:

```text
python -m tools.museum.artist_c2pa_conflicts --check
python -m unittest tools.museum.test_artist_c2pa_conflicts tools.museum.test_artist_c2pa
```

Omitting `--check` regenerates only the prospective V2 profile. Native graph
execution, authenticated historical capture and release evidence are separate
validation work.
