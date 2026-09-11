# Current native and ERC20 sale funding

The current fixed-price adapters fund the explicit collection `PRIMARY_SALE`
profile before mint completion. Revenue is either transferred to its verified
split wallet or recorded as an exact debt to that wallet in
[StreamRevenueEscrow](revenue-escrow.md). An escrowed sale is paid, but its funds
are not yet resident in the wallet. Flush the escrow before claiming that part
of the proceeds.

This is a bounded current-product implementation. It does not adopt the
proposed contract 20/9 orchestration architecture in
[ADR-0019](../adr/0019-payment-intent-orchestration.md), change that ADR's status,
or complete the universal settlement specification. Materialized templates,
undeployed profile funding, permits, prepared/custody mint flows and auction
migration remain separate work. Existing signature verification still uses the
native adapter's signature helper and the ERC20 adapter's raise-only signature
budget; this change adopts the factory's deposit and asset-policy budgets.

## Constructor and signing changes

The native constructor is now
`(mintManager, revenueResolver, platformSigner, artistRegistry, revenueEscrow)`.
The ERC20 constructor appends `revenueEscrow` to its existing four arguments.
The resolver must bind the same Core and artist facade as the manager/adapter;
its factory must match the escrow's pinned factory, registry, wallet runtime
and governance authority. The factory and escrow runtime hashes are retained
and checked during funding. Deployment governance must admit each adapter's
address and runtime as an escrow credit producer before enabling its fallback.

Native signing uses `6529StreamFixedPriceSale`, EIP-712 **version 2**, the actual
chain ID and adapter address. `SaleAuthorization` inserts
`bytes32 expectedPrimaryPolicyHash` immediately after `profileId`. Both creator
and platform sign the entire payload. The complete type string is:

```text
SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)
```

There is no version-1 signature or ABI fallback. Obtain the current commitment
from `primaryPolicy(collectionId)` before signing. It binds the actual resolver,
chain, revenue class, collection, fixed profile, verified wallet and full
assignment commitment, including the resolver's policy/finality facts. The
signed profile must equal that assignment. A zero underlying no-loosening
policy is valid; the resulting signed canonical commitment must be nonzero.

ERC20 sale authorizations and the PaymentIntent domain remain unchanged. Sale
registration and policy reads now accept only `keccak256("PRIMARY_SALE")` and
an explicit collection PROFILE assignment. A preconfigured alternate revenue
class, token/default inheritance or template cannot stand in for the artist's
supported economics authority. The adapter itself remains the allowance
spender and PaymentIntent verifying contract. An ERC20 payer approves that
adapter, never the escrow. An actual Safe payer can call directly through
`execTransaction`; a distinct relayer needs the Safe's valid ERC-1271
PaymentIntent authorization. Creator/platform Safe signatures use the actual
Safe fallback handler's `SafeMessage(abi.encode(StreamDigest))` wrapping.

## Atomic funding and failure behavior

Both adapters validate signatures and current artist/primary facts, then ask
the manager to preview a nonzero operation root and exactly one nonzero
operation ID **before payment**. After funding they recheck the current primary
assignment; ERC20 also rechecks ACTIVE asset status. The returned mint must
contain exactly one nonzero token and match both previewed identifiers. Any
recipient rejection, manager failure or identity mismatch reverts the entire
purchase, including replay state, allowances, proceeds, transfers and escrow
debt. Subsequent changes to authorizations cannot redirect retained escrow debt.

Direct calls use the factory's live `WALLET_DEPOSIT_GAS_LIMIT`. The native cap
includes the value-transfer stipend. Token balance/allowance reads, transfers
and approvals use that same current budget; independent registry status reads
use `ASSET_POLICY_GAS_LIMIT`. Full EIP-150 forwarding plus a local handling
reserve is required. Insufficient outer gas fails closed. A raised factory
budget is read by later purchases; fixture values are not a cold-gas sizing
recommendation.

Only a reverted or out-of-gas direct deposit can fall back: the EVM has already
rolled back every effect of that failed subcall. A successful ERC20 call that
returns false, a noncanonical return, no transfer, a fee or another nonexact
balance delta reverts the whole purchase. The fallback never preserves a
partial wallet payment and then charges the payer again.

For ERC20 fallback, the adapter pulls the exact sale price from its payer,
requires zero prior allowance to escrow, approves exactly that price, and lets
the admitted escrow pull from the adapter itself. The final allowance must be
zero. Both token balance deltas and the exact escrow debt increment are checked;
pre-existing adapter/escrow donations remain separate from sale proceeds.
Native fallback likewise checks exact adapter, wallet, escrow and debt deltas.
The helper exposes no arbitrary target, selector, payer pull or public spending
entry point.

After a successful mint, `SaleRevenueFunded` emits schema version 1, indexed
authorization ID, operation root and profile ID, plus wallet, asset, amount and
`escrowed`. Its identifiers match the settlement event and completed operation.
Zero-price native sales emit amount zero with `escrowed=false`; ERC20 sale
registration requires a positive price. Existing settlement events remain.

## Validation boundary

Focused tests use actual factory, resolver, wallet, asset registry and escrow,
and official Safe 1.4.1 singleton/proxy/compatibility-handler artifacts with
2-of-3 threshold owners. They exercise native/ERC20 payments and wallet payouts,
Safe caller/owner/signer/relayer paths, every public adapter selector, exact
replay and callback rollback, bounded gas-burn/revert-bomb fallback, invalid
token returns, residual allowance rejection, event identity and live deposit
budget changes. Native refusal is an explicitly value-specific injected wallet
failure, paired with real ordinary native deposits. ERC20 refusal executes in
the token's actual EVM call frame.

These domain tests use manager/Core/artist boundary fixtures and target-side
governance context fixtures. They do not substitute for real current-Core,
artist consent, Executor timelock, SDK/deployment migration or fully cold gas
evidence. Safe gas observations also include fixture warmth and helper work;
they establish executable compatibility at the tested budgets, not a universal
Safe configuration or transaction-gas guarantee.
