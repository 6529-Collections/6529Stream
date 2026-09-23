# Current Safe batch acceptance

`StreamCurrentSafeBatchTest` exercises official Safe 1.4.1 proxies, threshold
signatures, the compatibility handler and `MultiSendCallOnly` against the
current Core, Manager, Ledger, Artist owners, Executor, revenue split and
entropy coordinator. The upstream entropy provider is a deterministic test
substitute. A caller-owned postcondition contract supplies a downstream
rejection without altering any protocol rule.

The Safe delegates to the official `MultiSendCallOnly` wrapper so enclosed
calls originate from the Safe. Every enclosed protocol operation is `CALL`.
The suite separately requires the wrapper to reject an inner `DELEGATECALL`.
This describes the test's exact execution path; it is not client guidance to
delegate directly into a protocol contract.

## Authored cases

| Case | Required outcome |
| --- | --- |
| Paid mint, entropy request and transfer in one Safe transaction | One authorization and lifetime mint, exact signed payment, one upstream request and the requested final NFT owner; later actual coordinator fulfillment and Artist-Safe split withdrawal |
| Downstream failure after purchase, request or transfer | Revert prior Core allocation/counters, Manager nonce, sale consumption, split value, entropy/provider state and the outer Safe nonce; byte-identical batch succeeds after the caller repairs its postcondition |
| Same authorization twice in a batch | Second use rejects and rolls back the first purchase; original authorization remains usable |
| Inner delegatecall following a purchase | Official call-only wrapper rejects it and rolls back payment, mint and Safe nonce |
| Buyer identity | A Safe owner EOA and another threshold Safe with identical owners cannot substitute the signed payer; the intended Safe can still use that authorization |
| Artist payout redirection and downstream failure | Only the Artist Safe can redirect its entitlement; a later rejection rolls back payment and release accounting, then the exact signed Safe transaction succeeds once |
| NFT delivery to a Safe without a receiver handler | A late safe transfer rolls back purchase, request and approval; installing the official handler on the recipient permits the exact signed buyer transaction, and transfer clears approval |

The downstream-failure property varies the failure position and signed payment
amount, including zero and integer-rounding dust. Assertions compare against
independent before/after balances, identities and counters. The deterministic
provider models EVM request state and rollback; no live randomness-service
delivery or gas-conformance claim follows.

The payout property varies the actual sale amount, including integer-rounding
dust, and independently computes the Artist's 900,000-ppm entitlement. It checks
recipient balances, unreleased value, cumulative receipts and release counters,
then rejects replay of the consumed Safe envelope. Both role-negative cases use
the actual distinct Safe identities despite shared signing keys.

## Execution boundary

The seven cases are authored, with Solidity 0.8.19 ABI/type checking only.
Their native execution remains pending. They are later than the frozen six-suite
`acceptance-20260915-b` capture. That capture was interrupted before native
compiler completion and produced no runtime or production-size results. These
cases use two-owner, threshold-two Safe 1.4.1; the complete selector inventory,
other versions, thresholds, nesting and transaction capacity remain separate
acceptance obligations.

After building and preparing the current graph, run:

```text
python scripts/dev.py test --match-contract StreamCurrentSafeBatchTest
```

For a separate exact source capture, use the
[scoped acceptance runner](../tooling.md#scoped-acceptance-captures) with
`--host test/current/StreamCurrentSafeBatch.t.sol:StreamCurrentSafeBatchTest`.
The [test source](../../test/current/StreamCurrentSafeBatch.t.sol) contains the
complete assertions and original Safe transaction signing path.
