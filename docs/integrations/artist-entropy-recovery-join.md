# Artist consent and entropy recovery integration

The joined regression suite exercises the actual Artist facade, seven semantic
owners and Archive with the actual entropy coordinator, recovery workers and a
threshold Safe. The entropy transition supplies the content-state commitment
that the Artist signs through original operation 17. Recovery then consumes
that exact Artist record and commits it in its immutable receipt and evidence
event. Both modules share the same Core address and selected satellite pointers.

The seven cases cover:

- Original scope request inputs, Artist record and Archive preimages, evidence
  event, resulting content state and provider fulfillment.
- Missing consent, changed reason or provider evidence, and a changed selected
  entropy host, followed by restoration of the original authorized request.
- Canonical role-registry drift, including the original `InvalidDependency`
  rejection, atomic Safe rollback and the same consent after pin restoration.
- Actual incident-role revocation after consent, followed by a governed regrant
  and recovery using the retained consent and frozen policy.
- Provider reentry rejection with atomic Safe nonce, receipt, consumption and
  ETH accounting rollback; identical retry credits unused ETH to the supplying
  Safe.
- A failed Archive append that cannot leave usable Artist authorization,
  followed by the original consent calldata and successful recovery.
- A second failed request requiring fresh Artist consent for its new journal
  and policy step, while retaining the first receipt and frozen late-reply rule.

Entropy uses the actual `StreamRoleRegistry` already selected by the shared
canonical governance fixture. Its two required roles are granted through exact
class-1 call contexts, including the original membership, per-role and global
chain/revision commitments. Entropy administration belongs to the typed Executor;
incident declaration and recovery belong to the actual threshold Safe.

Core collection state, Artist admin roles, governance execution context and
upstream randomness remain explicit typed test boundaries. Governance calls use
distinct action IDs and the original role/entropy checks. These cases do not
prove delayed Executor authorization, token minting, upstream provider service,
transaction gas conformance or the artist-unavailability alternative.

Source: [StreamArtistEntropyRecoveryJoin.t.sol](../../test/unit/artist/StreamArtistEntropyRecoveryJoin.t.sol).
The corrected fixture passes an 801-source ABI/type check with Solidity 0.8.19.
Native execution of the correction and two new cases remains pending. The
historical `ee0f0159` native capture retains all five original failures: its
fixture pinned a separate mock role registry while the canonical Executor
selected the actual preservation registry. The first role-gated configuration
correctly rejected that mismatch. No production dependency guard was changed,
and that preserved failure result is not a runtime pass for this correction.

```sh
forge test --match-contract StreamArtistEntropyRecoveryJoinTest -vvv
```

See [fresh recovery](entropy-fresh-recovery.md) for the supported production
workflow and remaining implementation boundaries.
