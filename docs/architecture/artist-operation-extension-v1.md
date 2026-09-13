# Artist operation extension: identity dismissal

The [extension manifest](artist-operation-extension-v1.json) records the accepted
operation-58 design in [ADR 0029](../adr/0029-identity-contest-dismissal-and-cohort-closure.md).
Implementation and current-contract acceptance are still pending. It does not
change the source or evidence of the published testnet candidate.

The effective inventory is the exact ordered 57-row historical matrix followed
by the new row. The manifest pins six historical packets and their five schemas
by raw SHA-256. Their fields, stop overlays and checker expectations remain
unchanged. All 18 operation columns are retained. A successful design check
means the extension is internally consistent with those inputs; it does not
mean all 58 operations are implemented.

Three different identifiers need to remain distinct:

| Meaning | Identifier |
| --- | --- |
| Semantic write ID, derived from the named operation preimage | `0x7433c9e2` |
| Callable `dismissArtistIdentityContest(Request)` ABI selector | `0x1ae10cc1` |
| Callable `identityContestDismissalContext(Request)` ABI selector | `0x3df50249` |

The request is one seven-field tuple. The public context read derives the exact
state and intent for staging. At execution, the immutable Executor must provide
the matching per-call action context, and its recorded proposer must still hold
the arbiter role. There is no artist-signature typehash or invented validation
entry point. The eight proposed public methods have interface ID `0x6ddc41b6`.

Identity owns dismissal, its cause and resolution records, terminal cohort
closures and revision continuation. Its snapshot/read/write masks are `0x04`.
Payout uses its next separately authorized operation-18 write to detach an exact
abandoned candidate using a typed Coordinator snapshot. Both operation-31 vetoes
and operation-33 filings must capture their actual cause before changing status.
The manifest explicitly records these prerequisites, including rotation and
operative-read updates. Historical record preimages and consumed replay survive.

Run the design check and its adversarial fixtures from the repository root:

```text
python -m tools.protocol.check_artist_operation_extension
python -m tools.protocol.test_artist_operation_extension
```

The checker derives ABI selectors, interface ID, domain hashes, event topics,
record joins and the effective prefix. It checks Identity ownership, exact replay
scopes, typed fields and prerequisites, then verifies the reviewed design digest.
The tests mutate history, schema bytes, IDs, order, fields, selectors, masks,
events, replay and stops. `--require-implementation` deliberately fails until
matching source/configuration and real Executor/Safe acceptance are supplied.
The existing 57-operation checkers retain their historical purpose.

The first source increment restores only an ACTIVE artist under its unchanged
incumbent. SUCCEEDED and DORMANCY_NOTICE restoration, captured notice timing and
the required appeal path remain part of full-v1 delivery.
