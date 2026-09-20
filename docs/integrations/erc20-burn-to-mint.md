# ERC20 paid Stream burn-to-mint

`StreamERC20BurnMintSale` and `StreamERC20BurnMintGate` implement a dedicated
paid `BURN_TO_MINT` program (sale kind 8). One transaction burns the ordered
Stream source tokens, pays a positive ERC20 price through contract 20 and the
official recorder, and mints one new token through the current Manager/Ledger.
The [free and native paid routes](burn-to-mint.md) keep their existing APIs.

This is pre-audit source. The delivery ledger records executed validation for
each revision; this guide does not establish release or deployment readiness.

## Supported configuration

The payment profile is the existing order-one `PRE_REVENUE_SINGLE_STEP`, with
an ACTIVE token and strict collection PROFILE primary rights. The selected
coordinator must declare a zero native reveal fee. A nonzero live fee fails
before a burn or token pull, and liveness checks repeat after settlement and
mint callbacks. The held native-allowance proposal is not implemented here.

Link the carrier's fixed `StreamERC20BurnMintRuntime` and
`StreamERC20BurnMintSupport` libraries using the compiled link references.
They operate on compiler-typed carrier storage and cannot be selected by a
transaction caller. The carrier reserves sale replay and consumes its mutable
callback admission before entering the worker.

Deploy the carrier before the gate. The gate constructor pins its carrier
address and runtime code hash, along with Core, registry, parameter governance
and operator identity. Configure the carrier's governed reveal-attempt gas row
and the gate's dependency-read and burn-call gas rows.

Configure one immutable gate program per target collection using the original
`IStreamBurnMintGate.ProgramConfig` tuple. `prepared` must be false and
`nativeSaleAdapter` must be zero. This dedicated gate exposes no free burn
entry. The immutable carrier is bound through the gate's runtime identity.
The original program-hash preimage, source-set ordering, ratio, inclusive
window bounds and burn-nullifier domain remain unchanged.

Configure a singleton phase with this gate and its program hash, and authorize
the carrier as phase executor. Keep the normal counters and Artist policy
consent. Register the carrier's original universal transport capability and
the gate's normal mint-gate capability. Then register the sale using the
original `SaleConfig` fields: payment adapter, target collection and phase,
asset, price, window, mint-policy hash and expected primary-policy hash.
Obtain the normal exact sale-configuration Artist consent.

## Signatures and burn authority

The carrier retains the exact `UniversalSaleAuthorization` fields and EIP-712
domain name `6529StreamUniversalFixedPriceSaleAdapter`, version `1`, chain ID
and its own verifying-contract address. The platform signer and current
Artist authorize the original payload. Sale IDs retain the canonical sale
domain with kind 8. The Manager authorization remains the original TICKET
wrapping of that authorization digest.

Construct `Execution` as the original complete `SaleExecutionData` plus
`sourceTokenIds`. Sources must be strictly increasing, distinct and drawn
from the immutable allowed source collections; their count equals the
program's `sourcesPerMint`, with a maximum of 16.

The signed `executor` is the actual caller at contract 20. It must own each
source or hold a token-specific or collection-wide approval from its owner.
Independently, the burn gate needs approval to call Core's burn entry. An ERC20
PaymentIntent does not grant NFT burn authority. Payer, source owner, executor
and signed output recipient may be distinct accounts when these independent
permissions are present.

## Preview and payment

Call `previewExecution(execution)` using an ordinary RPC `eth_call`. The
function is nonpayable rather than Solidity `view`: the gate installs a
temporary prospective proof behind its reentrancy guard, invokes only the
fixed carrier's typed read-only callback, and clears the proof. The callback
uses `STATICCALL`, so its entire descendant call tree cannot mutate mint,
payment or replay state. The preview neither burns nor grants a reusable proof.

Pass the returned original `ERC20SettlementCandidate` and
`abi.encode(execution)` to an existing contract 20 entry:

| Route | Authority |
| --- | --- |
| `settleERC20PrimarySaleByPayer` | Actual caller is the token payer |
| `settleERC20PrimarySaleWithIntent` | Payer's separate original signed PaymentIntent |
| `settleERC20PrimarySaleWithEIP2612Permit` | Payer calls with the existing exact-amount permit |
| `settleERC20PrimarySaleWithPermit2` | Payer calls through the existing pinned Permit2 route |

The sale signature authorizes the named executor; a nonpayer executor still
needs the payer's PaymentIntent and its own source-burn authority. Safe
principals use ordinary zero-value CALL and their required threshold signatures.

The candidate commits to the complete execution, including the ordered source
IDs. Changed sources, recipient, executor, phase state or operation nonce can
invalidate it. Recompute after relevant state changes. Previewing does not
reserve sources, sale authorizations or mint capacity.

## Atomic execution and historical evidence

The carrier reserves the original Artist authorization nonce and execution
nonce before outbound execution. The gate validates every source and approval,
burns through Core, and checks the retained collection, serial and burned flag.
Only then does it expose the live proof around its fixed settlement callback.

Contract 20 and the official recorder preserve their original payment order
and exact-token accounting. The Manager consumes the original ticket and
per-source burn nullifiers before minting. The gate verifies the resulting
operation, replay state and retained output identity, then clears the proof.
A mismatch or late NFT-receiver failure rolls back burns, payment, permits,
revenue and all replay stores together. The original signed transaction may
then be retried after repairing its failed dependency.

The existing bounded zero-fee `AT_MINT` request is attempted after minting.
A provider-request failure remains failure-isolated and evented. Revenue
escrow follows the official recorder's existing behavior.

Reconstruct burn provenance from the original `BurnMintExecuted` and
`BurnMintBatchExecuted` events, Core burn/transfer events, normal Manager and
Ledger events, and original universal settlement/execution records. This
atomic route creates no separate custody purchase ID.

Before a freeze or finality action, apply the source and target warnings in
[SSA-BURN-FINALITY](../stream-sales-and-auctions.md#finality-interaction-rule).
Core's burn block, supply, freeze and finality enforcement remains authoritative.
