# Current terminal-entropy integration recipes

## Scope and validation status

The [ten named cases](../../test/current/StreamCurrentTerminalEntropy.t.sol) use
one [new helper](../../test/helpers/CurrentTerminalEntropyFixture.sol) on source
base `5310fc7be2e0725031ce6549318cbeca9a95eb61`. They join the explicit collection
policy and immediate-sale terminal handling to actual Core, Artist, Executor,
Mint Manager, Ledger, sale settlement, split wallet and Coordinator contracts.
Artist, payer and operator/governor are original two-signature Safe 1.4.1 proxies.

This batch is source-only. Formatting and documentation checks are separate from
compiler, native execution, gas and release acceptance, which remain pending.
The integrator requested no competing compiler while the joined Artist facades
are being repaired. Existing production size and gas guards remain active.

These recipes complement the thirteen typed-boundary cases in
[terminal entropy sales](terminal-entropy-sales.md). They do not relabel those
cases as current-stack evidence. The paid consumer is the original
`StreamNativeFixedPriceSaleAdapter`, which calls the changed shared helper.
The separate Dutch reveal path is outside this batch.

## Finite matrix

Each paired row has one DISABLED case and one ASYNC / NOT_REQUIRED case.

| Cases | Actual flow and assertions |
| --- | --- |
| 1–2 | Safe governor schedules an exact class-1 configuration. Missing Artist evidence fails without consuming the action. Actual Artist Safe records original operation-17 consent; the same scheduled action applies the policy. Separate class-2 freeze needs its own consent; configuration evidence cannot authorize it. Executed action replay has the exact original error. |
| 3–4 | Safe payer purchases an actual token for 1,000 wei. DISABLED funds zero reveal fee; NOT_REQUIRED retains the declared 100 wei fee. Both credit 37 wei excess to the original payer, then close that liability through the original Safe pull claim. No token randomness request or attempt event occurs. |
| 5–6 | Safe operator executes a committed two-beneficiary distribution. A one-wei fee mismatch fails with the exact original error and preserves the batch, nonce, counters and value. The same batch succeeds with the correct payment; DISABLED costs zero and NOT_REQUIRED funds 100 wei per token. Original supply and recipient counters and delivery receipts are checked. Used-slice replay is refused. |
| 7–8 | During actual mint delivery the receiver attempts to burn and observes Core's exact `MintExecutionInProgress` error. Its separate delivery rejection rolls back mint, payment and replay state. After receiver acceptance, the byte-identical saved Safe transaction succeeds. A later custody-transfer callback burns the completed token, preserving its permanent identity and original Coordinator. The actual terminal helper accepts that genuinely burned identity. |
| 9 | A NOT_REQUIRED token stays terminal while a real allocation scope registers, requests and finalizes randomness. The scope pays its own 100 wei provider fee, credits and later refunds its own 37 wei excess, and leaves the token's 100 wei reveal escrow intact. The resulting scope seed uses the original independent preimage. |
| 10 | A separate original ASYNC / REQUIRED profile retains genuine paid-token request and finalization, the original attempt receipt and the original seed preimage. It has no explicit V2 policy. |

The distribution retry changes the transaction's supplied value to the required
amount; its committed batch is unchanged. The receiver retry preserves the
entire saved signed Safe transaction, including its value and nonce.

## Independent records and accounting

Configuration tests reconstruct the original explicit policy hash and its
content-state hash. They verify the actual stored mode, security class, render
requirement, provider epoch, revision, action ID and consumed Artist record.
The configuration receipt binds the complete original policy tuple, provider
runtime/configuration pins and recovery fields. The freeze receipt preserves
the policy hash and epoch while advancing the policy revision.

Original Artist operation-17 records are reconstructed independently from the
original record domain, chain, registry, content host, Core, collection, family,
new state, Artist identity, signer, authority class, nonce and observed time.
The original consent owner's receipt and host-bound evidence read must match.
Failed policy execution preserves all seven Artist owner snapshots and leaves
the governance action scheduled for its authorized retry.

Paid mint asserts official settlement consumption, exact split-wallet proceeds,
original sale replay lanes, Manager operation root/nonce, independent Ledger
authorization and counter keys, token bytes, permanent identity and Core
`Transfer`. Distribution independently reconstructs its slice and authorization
preimages and checks both beneficiary counter keys and all four mint/delivery
transfers. It creates no sale revenue or buyer credit.

Terminal token reads retain their actual `DISABLED` or `NOT_REQUIRED` status,
provider identity/epoch, zero request fields, zero seed and false finalized
flag. Exact token request refusal is checked. Registration events bind each
unique token to the explicit policy; no event may claim an unattempted reveal.

Scope accounting deliberately keeps two balances separate: a terminal token's
declared reveal escrow and the scope caller's own payment and excess credit.
The scope request key and final seed include the original Coordinator, Core,
collection, scope, provider epoch/configuration, inputs and request identity.
Scope finalization must leave the terminal token unchanged.

## Boundaries

Only the inherited external entropy provider and the explicitly rejecting or
burning recipient are controlled test boundaries. Safes, authorization owners,
policy producers, governance execution, sale helper, mint graph and escrow are
actual contracts. Public deterministic test keys have no real funds.

Core's mint-time burn guard is preserved. The later burn is a separate custody
callback after mint and payment completion, not a claim that mint-time burning
is supported. The typed helper's earlier permissive burn fixture remains
separate evidence.

The original required-entropy profile remains a distinct control. This batch
does not migrate STATIC, INSTANT, renderer/finality profiles, provider succession,
deferred sales, capture profiles or current-policy read implementations. It does
not change production, shared fixtures, runner/catalog entries, gas parameters,
release artifacts or RC1. Its native-sale request budget is the existing fixture's
2,000,000 planning value; this is not cold-call acceptance.

Freeze the final joined source, type-check it and execute the named host with
the original guards before claiming these ten cases pass. Full-37 construction,
genesis, capacity, broad CI and release evidence remain separate acceptance work.
