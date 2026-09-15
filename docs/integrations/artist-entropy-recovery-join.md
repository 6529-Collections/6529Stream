# Artist consent and entropy recovery integration

The joined regression suite exercises the actual Artist facade, seven semantic
owners and Archive with the actual entropy coordinator, recovery workers and a
threshold Safe. The entropy transition supplies the content-state commitment
that the Artist signs through original operation 17. Recovery then consumes
that exact Artist record and commits it in its immutable receipt and evidence
event. Both modules share the same Core address and selected satellite pointers.

The five cases cover:

- Original scope request inputs, Artist record and Archive preimages, evidence
  event, resulting content state and provider fulfillment.
- Missing consent, changed reason or provider evidence, and a changed selected
  entropy host, followed by restoration of the original authorized request.
- Provider reentry rejection with atomic Safe nonce, receipt, consumption and
  ETH accounting rollback; identical retry credits unused ETH to the supplying
  Safe.
- A failed Archive append that cannot leave usable Artist authorization,
  followed by the original consent calldata and successful recovery.
- A second failed request requiring fresh Artist consent for its new journal
  and policy step, while retaining the first receipt and frozen late-reply rule.

Core collection state, governance execution context, role resolution and
upstream randomness remain explicit typed test boundaries. Governance calls use
distinct action IDs and the original entropy replay checks. These cases do not
prove delayed Executor authorization, token minting, upstream provider service,
transaction gas conformance or the artist-unavailability alternative.

Source: [StreamArtistEntropyRecoveryJoin.t.sol](../../test/unit/artist/StreamArtistEntropyRecoveryJoin.t.sol).
The 766-source ABI/type check passes. Native execution remains pending; the
existing frozen migration cohort predates these tests and is not restarted.

```sh
forge test --match-contract StreamArtistEntropyRecoveryJoinTest -vvv
```

See [fresh recovery](entropy-fresh-recovery.md) for the supported production
workflow and remaining implementation boundaries.
