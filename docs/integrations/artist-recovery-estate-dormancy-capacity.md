# Estate and dormancy recovery worker capacity

Four existing recovery libraries exceeded the EIP-170 runtime limit in the
current Artist graph. They now retain their original public entry points and
nominal result types while calling six fixed, compiler-linked typed libraries.
No recovery profile, authority rule, recorded hash, storage root or gas limit
changes.

## Fixed boundaries

`StreamArtistRecoveryDormancyEvidence` and
`StreamArtistRecoveryEstateEvidence` contain the original provenance,
record-environment, contest, vesting and cause-hash helpers. Their separate
original recovered-history implementations remain separate. In particular,
Estate dismissal authentication still joins the native receipt to the exact
`contest_resolution` replay cell and original source point.

`StreamArtistRecoveryDormancyPlan` and
`StreamArtistRecoveryEstatePlan` retain the original directive and provisional
association checks. Dormancy's predecessor helper used to update its caller's
memory snapshot. It now explicitly returns that complete snapshot, and the
original host assigns it back to `f.previous`. The early no-predecessor return
preserves the supplied snapshot as before.

`StreamArtistRecoveryEstateClosure` retains both original dismissal checks and
the immutable first closure versus latest dismissal distinction.
`StreamArtistRecoveryEstateTerminal` receives the four complete fields it
actually reads from the original `Origin`: request, transition, vesting and
guardian head. The public host's original `Origin` type is unchanged.

All calls use literal compiler-linked libraries and typed original storage
references. Solidity library delegation preserves the host's `address(this)`,
incoming caller and storage context. There is no caller-selected worker or new
writer. The original host predicates and check order remain in place. The
Estate predecessor explicitly declares its existing zero-argument
`InvalidRecoveredHydrationProvenance` error so its error ABI remains available
after the private throwing helper moves.

## Selected capacity

The selected native capture uses Solidity 0.8.19, optimizer 200, via IR, Paris,
`bytecodeHash: none` and no CBOR. These libraries have no constructor arguments.

| Original library | Prior runtime | Current runtime | Creation |
| --- | ---: | ---: | ---: |
| DormancyPredecessor | 30,874 | 23,479 | 23,512 |
| DormancyRotation | 32,006 | 24,529 | 24,562 |
| EstatePredecessor | 30,662 | 21,273 | 21,305 |
| EstateRotation | 38,179 | 23,459 | 23,492 |

| New worker | Runtime | Creation |
| --- | ---: | ---: |
| DormancyEvidence | 10,220 | 10,252 |
| DormancyPlan | 6,218 | 6,250 |
| EstateEvidence | 10,399 | 10,431 |
| EstatePlan | 3,050 | 3,082 |
| EstateClosure | 7,271 | 7,303 |
| EstateTerminal | 7,853 | 7,885 |

All ten selected products fit the unchanged 24,576-byte runtime and 49,152-byte
initcode limits. DormancyRotation has only 47 bytes of runtime headroom.
Selection covers these ten products, not every transitive deployed dependency.
The six other concurrent Artist capacity repairs are separate work.

## Source and behavioral evidence

The saved inverse proof maps 22 extracted helper bodies and 12 retained host
functions back to the original source, after reversing only the documented
qualifiers and typed argument/return projections. All four original nominal
result structs, error ABI entries, eight compiled method identifiers and
storage layouts are retained. Independent source review also compares the
unchanged dependency closure. Final production formatting changes whitespace
only.

`test/unit/artist/StreamArtistRecoveryEstateDormancyWorkers.t.sol` adds eight
authored, type-checked cases. They cover complete predecessor return values and
input canaries, the no-predecessor branch, original literal hash preimages in
two delegate hosts (including fuzz inputs), closure and directive canonical
absence, ancestry/contestation distinctions, exact refusal/restoration, and
the original four zero-history-proof guards.

These tests use declared original storage types and explicit typed setters.
They do not authenticate or manufacture an admitted historical Artist suite.
The new cases have not been executed in this handoff. Existing actual Artist,
Archive and Safe recovery recipes remain unchanged and require a separately
owned current-stack run. Added library-call overhead, cold transaction limits,
linked deployment closure and complete recovery acceptance remain unmeasured.
