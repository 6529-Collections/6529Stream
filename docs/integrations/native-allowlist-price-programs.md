# Native allowlist price programs

`IStreamNativeAllowlistPricePrograms` adds single-token Merkle pricing to the
existing `StreamNativeFixedPriceSaleAdapter` price-program consumer. The frozen
allowlist leaf, `AllowlistProof[][]` encoding, Manager ABI, existing sale structs,
EIP-712 domains and replay keys remain unchanged.

## Create a sale

Configure the Manager phase with an inline `MERKLE_STATIC` payer or recipient
counter. Publish its canonical allowlist and pin its definition/root in the
phase policy. Call:

```solidity
registerAllowlistPriceProgram(config, AllowlistPricePolicy(counterId, allowFree))
```

The selected counter must exist in that phase, have a registered matching
Merkle definition and a positive ceiling. The policy selects the single
counter allowed to supply a price. Other Merkle counters still require their
normal proofs, but an enabled price on any other counter rejects to avoid
ambiguous pricing. This consumer supports the phase's inline counter route;
its empty gate data and original sale authorization do not substitute for a
separate gate's authorization protocol.

`allowFree` is a creation-time declaration for fixed/open-edition programs
(kinds `0` and `1`). It must be false for explicit zero-price claims (`12`) and
pay-what-you-want programs (`13`), which already define their zero-price rules.
There is no policy setter. Read the retained policy with `allowlistPricePolicy`.

The new record's configuration hash is:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_NATIVE_ALLOWLIST_PRICE_PROGRAM_CONFIG_V1"),
    originalPriceProgramConfigHash,
    AllowlistPricePolicy(counterId, allowFree)
))
```

`NativePriceProgramConfigured` and `NativeAllowlistPricePolicy` emit the same
final hash. Original Artist sale consent and both execution signatures bind
that hash. Existing `registerPriceProgram` records retain their original hash.

## Price and execution

Pass exactly `abi.encode(AllowlistProof[][])` to
`previewAllowlistPriceProgram(execution, resolverData)` and
`executeAllowlistPriceProgram(execution, resolverData)`. For this single-token
consumer every Merkle counter has one proof. Groups follow configured Merkle
counter order; payer counters bind the actual payer and recipient counters bind
the delivered beneficiary. The sale independently verifies root, chain,
Manager, collection, phase, counter, account, cap and price, then passes the
same bytes into `MintBatch.resolverData` for independent Manager verification.

| Kind | Enabled leaf override | No override |
| --- | --- | --- |
| Fixed/open edition `0`/`1` | Chosen price must equal the leaf price exactly | Original fixed price |
| Zero-price claim `12` | Only zero accepted | Zero |
| Pay what you want `13` | Minimum is `max(config.minUnitPrice, leafPrice)`; configured maximum still applies | Original signed minimum and configured band |

For fixed/open editions, the original signed unit price still equals the
record's public fixed price. The independently proven leaf replaces the
charged price. Zero requires `allowFree`; otherwise
`SalePriceOverrideZeroUndeclared(saleId)` rejects. A declared free mint skips
official settlement, payout materialization and official revenue events, while
retaining Artist admission, reveal funding, mint caps and replay consumption.
PWYW zero overrides only lower the signed minimum to the configured floor;
they do not waive that floor or the maximum. False/nonzero leaf values reject.

An allowlist record cannot use the original entrypoint to avoid proofs: the
same stored policy applies and missing proofs reject. The proof-bearing
entrypoint rejects records without an allowlist price policy. Used signatures
and execution nonces are shared with the original entrypoint. Resolver bytes
are included in the new sale execution commitment and in the Manager batch;
prices, counters, replay state, settlement, reveal fees and payer-owned excess
credits remain one atomic transaction.

## Normative mapping and remaining consumers

The owning requirements are [MPA-MERKLE rules 2–5](../mint-policy-and-accounting.md)
and [SSA-AUTH rule 3](../stream-sales-and-auctions.md). Manager/Ledger accounting
ignores price; the sale verifies the same leaf and enforces its role. The
current generic allowlist gate authenticates prices without charging them.

This increment covers native immediate price-program kinds `0`, `1`, `12` and
`13`. The original `registerSale`/`purchase`, burn-purchase callback and refund
credit interfaces are preserved. Dutch proof ingress/ceiling charging, clearing
proof-to-signed-ceiling equality, refund-window retained proof accounting, and
ERC20 proof-bearing payment/mint entrypoints require their own consumer joins.
Clearing already has signed ceiling/floor/rebate math, but that does not verify
a Merkle leaf. No batch purchase, generic gate envelope or public unsigned sale
is introduced here.

Focused tests use actual Manager/Ledger for proof/accounting checks and actual
settlement contracts with typed Core/Manager/Artist boundaries for the native
payment matrix. Full current-stack Artist/governance, callback composition and
cold gas acceptance remain separate integration evidence.
