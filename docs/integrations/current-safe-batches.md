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

The downstream-failure property varies the failure position and signed payment
amount, including zero and integer-rounding dust. Assertions compare against
independent before/after balances, identities and counters. The deterministic
provider models EVM request state and rollback; no live randomness-service
delivery or gas-conformance claim follows.

## Execution boundary

The four cases are authored and pass an 874-source Solidity 0.8.19 ABI/type
check. Their native execution remains pending. They are later than the frozen
six-suite `acceptance-20260915-b` capture. That capture was interrupted before
native compiler completion and produced no runtime or production-size results.

After building and preparing the current graph, run:

```text
python scripts/dev.py test --match-contract StreamCurrentSafeBatchTest
```

For a separate exact source capture, use the
[scoped acceptance runner](../tooling.md#scoped-acceptance-captures) with
`--host test/current/StreamCurrentSafeBatch.t.sol:StreamCurrentSafeBatchTest`.
The [test source](../../test/current/StreamCurrentSafeBatch.t.sol) contains the
complete assertions and original Safe transaction signing path.
