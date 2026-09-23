# Artist recovery history fixed workers

The recovery history capacity repair moves existing function bodies from six
Artist libraries into nine fixed linked libraries. Public host selectors,
nominal structs, storage roots, errors, events, validation order and history
coordinates retain their original meanings. The deployment inventory must
include every new compiler-declared library link.

| Existing host | Fixed linked workers |
| --- | --- |
| `StreamArtistRecoveryAdjudicationHistory` | `StreamArtistRecoveryAdjudicationOrigins` |
| `StreamArtistRecoveryFamilyHistory` | `StreamArtistRecoveryFamilyEpisodes`, `StreamArtistRecoveryFamilyEligibility` |
| `StreamArtistRecoveryRewindCapabilityReads` | `StreamArtistRecoveryRewindCurrentCapabilities`, `StreamArtistRecoveryRewindCapabilityBounds` |
| `StreamArtistRecoveryRotationClosure` | `StreamArtistRecoveryRotationClosureRecords` |
| `StreamArtistRecoveryStagingHistory` | `StreamArtistRecoveryStagingEstateHistory`, `StreamArtistRecoveryStagingHeadHistory` |
| `StreamArtistRotationState` | `StreamArtistRotationExecution` |

## Execution boundary

Extracted private helpers that cross a library boundary become public library
entries with typed arguments. The compiler binds their targets statically.
Their calls retain the original host, caller and storage context; no new
mutable target or generic dispatcher is introduced. Original host entry points
continue to perform their existing work in the same order.

The Family episode collector previously replaced `h.episodes` through a shared
memory reference. Its linked worker now returns that array explicitly, and the
original helper assigns it at the original call position. Other fields of the
original `Chain` remain in the caller. The Rotation execution worker receives
the original storage roots and contexts and returns the same `Mutation` to the
original wrapper. Its replay, timestamp checks, state writes, checkpoint notes,
event and return remain in their original order. Errors that would otherwise
disappear from a host ABI are explicitly retained as declarations.

Duplicate or secondary native receipt records retain their original local
positions and multiplicity. No receipt, closure, environment, provenance,
capability or timing predicate is removed to reduce bytecode.

## Verification scope

The source comparison preserves all 1,573 existing products, 12,356 ABI entries,
method identifiers and recursively expanded storage layouts in the bounded
compiler closure. Original function bodies are compared after explicit link,
visibility and nominal type substitutions, with the Family array return checked
separately. Selected native compilations provide source-specific size evidence
for the six hosts, nine workers and unchanged Coordinator. The Coordinator
remains exactly at the runtime limit; final combined native and gas acceptance
remain separate.

Eight focused cases in
[`StreamArtistRecoveryHistoryWorkers.t.sol`](../../test/unit/artist/StreamArtistRecoveryHistoryWorkers.t.sol)
are authored and type-checked. They cover Rotation host storage, caller, event,
replay, refusal order and rollback; Family array propagation and maturity;
native receipt occurrence and secondary operation35 positions; and original
Estate capability reads. These are typed storage and read fixtures. They do
not establish admitted recovery histories, Safe authorization, EVM execution,
full current-stack behavior or release readiness.

The fixed code placement follows
[ADR 0025](../adr/0025-artist-authority-windows-and-fixed-extensions.md).
The original recovery and cohort semantics remain governed by
[ADR 0029](../adr/0029-identity-contest-dismissal-and-cohort-closure.md).
