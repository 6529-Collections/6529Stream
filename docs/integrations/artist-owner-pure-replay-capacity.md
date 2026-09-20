# Artist pure replay-key capacity repair

This repair shares only the original nine-word replay-key hash through the
already linked `StreamArtistOwnerCommit` library. `StreamArtistOwner._consume`
retains its original validation, replay-cell writes and checkpoint recording
in the original source location. No replay storage reference or mutation plan
is passed to the new pure function.

The preimage remains the original V2 tag, deployment chain, Artist Registry,
Coordinator, Archive, actual owner, owner domain, surface and scope, in that
order. The owner supplies every field explicitly. The pure library does not
derive authority from its direct caller or the live chain. Its existing commit
functions are unchanged. Linked runtime identities must come from the same
fresh build; historical deployment artifacts are not updated by this change.

The only Attribution-local change is the return data location of
`staticPlatformWorksState`: `memory` becomes `calldata`. The external ABI and
the original twenty-word storage encoder are unchanged. Every path reaches
the existing unconditional assembly `RETURN`; no default calldata value is
read or returned by Solidity. Direct STATIC, C2PA, personhood and mutation
behavior is retained.

## Frozen evidence

The paired source base is `d60b459c87bef94da75e84ee60a9d3a9c2af0ea3`,
combining the accepted Identity terminal-read repair with root `7752f977`.
Both selected captures use the same 685-source closure and Solidity 0.8.19,
via IR, optimizer 200, Paris, no CBOR and no metadata bytecode hash.
Creation sizes below exclude constructor arguments.

| Product | Original runtime | Repaired runtime | Repaired creation |
| --- | ---: | ---: | ---: |
| AttributionLifecycle | 25,369 | 23,989 | 25,336 |
| IdentityAuthority | 23,393 | 23,393 | 30,700 |
| OwnerCommit | 1,597 | 1,916 | 1,950 |
| PayoutLifecycle on this earlier source | 25,473 | 24,855 | 26,006 |

Attribution has 587 bytes of runtime margin; its five-address constructor
adds 160 bytes, making its complete initcode 25,496 bytes. Identity adds
288 constructor bytes, making its complete initcode 30,988 bytes. Both
remain below the original 24,576-byte runtime and 49,152-byte initcode limits.
The Payout measurement predates the separate Payout capacity repair and is
still 279 bytes over the runtime limit. It is not final joined evidence.

Separate ABI-only original/final captures retain all 48,336 original ABI
entries and all 4,262 recursive storage layouts; these counts include test
and historical definitions. The sole additive original-contract ABI entry
is the library's pure `replayKey`. All 2,774 final source inputs match the
working source after line-ending normalization.

`StreamArtistOwnerReplayHashTest` passed its three native cases, including
256 fuzz runs against an independently assembled flat nine-word preimage.
The tests cover zero fields and different calling contracts with the same
explicit captured environment. This is pure hash execution evidence.

The separate 52-source capture containing the seven original
`StreamArtistOwnerAdmissionTest` cases failed in compiler code generation
before any test ran (`dst_9` / `src_9` Yul stack error). The failure is retained;
the unchanged recovered-owner hydration dependency is under separate repair.
Actual Owner execution, cold read budgets, the final joined size gate and
current Artist/Safe integration remain pending for this source.

Local inputs, outputs, preservation comparisons and native results are retained
under `D:/repos/6529Stream/.tmp-artist-pure-replay-hash`. This change does not
apply the separately held Attribution replay-mutation proposal.
