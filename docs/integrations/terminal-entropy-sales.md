# Terminal entropy in immediate sales

The shared `StreamImmediateSaleReveal` library supports the explicit collection
policy introduced by [the entropy policy interface](explicit-entropy-collection-policy.md).
Native sales, distributions and existing zero-native-fee ERC-20 consumers use
this same library. Their external call signatures, quote tuple and refund
ownership are unchanged.

| Collection policy | Quoted reveal policy | Funding | Token request |
| --- | --- | --- | --- |
| Original ASYNC / REQUIRED | Original declared policy | Original captured fee | Original AT_MINT or OWNER_WINDOW behavior |
| Explicit DISABLED | Undeclared, all fields zero | Zero | None |
| Explicit ASYNC / NOT_REQUIRED | Original declared policy | Original captured fee remains owed | None |

NOT_REQUIRED concerns the token's render requirement. It does not erase the
ASYNC collection's declared fee or its allocation-scope obligations. The usual
maximum allowance, pull credit and exact escrow-delta checks remain in force.
No `ImmediateRevealAttempt` event is emitted when no request was attempted.
Disabled quotes no longer require an otherwise unused request gas budget. The
original ASYNC preflight gas requirement remains, including NOT_REQUIRED.

A missing capability, failed policy read, zero hash or renderer label cannot
create an exemption. The helper recognizes the additive collection-policy
interface and validates its complete fixed tuple and original content-state
hash. After mint, an exemption also requires a frozen explicit policy and the
original token-to-collection identity and coordinator. Token status, seed,
provider epoch and request fields must describe the same terminal non-random
state. A receiver may have burned the just-minted token; its permanent identity
and original coordinator still apply. No terminal token is called FINALIZED.
The pre-existing selected-pointer, runtime and same-Core checks remain.

The scope is DISABLED and ASYNC NOT_REQUIRED. INSTANT required-token commerce,
coordinator policy succession, deferred-sale fee reconciliation and full current
Safe/contract integration remain separate work. Earlier source-specific sale
captures do not validate this changed linked dependency.

## Validation

The focused `StreamImmediateSaleEntropyPolicyTest` executes the actual two linked
sale helpers against explicitly typed Core and Coordinator fixtures. All thirteen
cases pass, including 256 fee/refund conservation fuzz inputs. Negative cases
cover an undeclared legacy policy, malformed capability, missing consent, changed
full hash, unfrozen policy, foreign collection/coordinator, incomplete lifecycle,
false seed/finalization/request data, and exact rollback/retry. Callback-burn
identity and the original required-ASYNC path are retained controls.

This is focused worker evidence. It does not establish genuine current Core,
Artist or Safe execution, final linked graph capacity, deployment manifests or
release acceptance. Native fixture limits are test allowances only.
