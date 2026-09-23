# ERC-20 immediate sale native reveal allowance

The local implementation accompanying ADR 0045 is applied. Solidity 0.8.19
ABI/type and recursive storage checks pass, preserving original selectors,
signing tuples and the existing storage prefix. All 93 focused native regression
cases across 12 test contracts pass, with no skipped cases. Captured production
bytecode sizes also pass. This is local behavioral evidence, not production gas
capacity, full-graph release acceptance, an audit, or deployment approval.

The four ERC-20 settlement entrypoints retain their selectors and all original
PaymentIntent, EIP-2612, Permit2 and UniversalSaleAuthorization fields. Their
payable mutability permits a separate allowance in wei. The already-bound
transaction executor supplies that allowance; no token price or signed maximum
contains wei. The token payer may be a different Safe/account on the intent
route. Direct and permit routes still require payer equals executor.

The payment adapter forwards all msg.value through the existing authenticated
sale callback. Its native balance must return to its pre-call baseline. The
sale captures the selected coordinator, runtime and declared policy before any
token funding or mint effect. Underfunding rejects. After the original official
token settlement and Manager mint return it funds the exact captured wei fee,
then makes the existing bounded zero-value AT_MINT request. Operational fee
changes during callbacks do not alter that captured fee. Pointer or accounting
failure rolls back the whole transaction; a provider request failure is instead
a bounded ImmediateRevealAttempt result. Current request authorization remains
necessary: deployment must grant the sale the original coordinator requester
capability through canonical governance. This patch does not bypass that rule.

Unused wei is an append-only discoverable, per-sale credit of c.executor. Only
that account may call claimRefund and select a destination. The shared reveal
interface retains its parameter/event field name payer for ABI continuity; in
this ERC-20 route that means native funder, not ERC-20 payer. Refunds remain
available when the sale is paused, cancelled or loses module admission. Failed
recipient calls restore credit. Passive native surplus belongs to no purchase
and is excluded from both fee charging and refund liabilities.

The Universal constructor gains an explicit REVEAL_ATTEMPT_GAS_LIMIT config.
Its canonical GGP authority is the existing SplitFactory authority. The
fixture budget is 1,000,000 with a 100,000 floor; this is a test configuration,
not a measured production requirement or gas-capacity claim. The original owner,
reentrancy and six sale storage declarations move together into a base that
precedes the new GGP and refund storage. Recursive compiler comparison preserves
the existing eight entries at slots 0 through 7; new state occupies slots 8
through 14. Manager,
Core, revenue-result, signature preimage, selector, permit capability and
token allowance semantics are unchanged.

The Universal adapter links its existing lifecycle and Artist admission checks
through StreamUniversalSaleExecution. All original arguments, check order,
adapter ABI (including errors), and recursive storage are retained. Solidity
0.8.19, via IR, optimizer 200, Paris and no CBOR metadata produce these selected
runtime sizes: Payment 24,244; Universal 23,708; Offer 22,873; Burn 14,524; new
admission library 5,475 bytes. Universal has 868 bytes of EIP-170 headroom. These
measurements agree with the genuine native artifacts from the passing campaign.

The native campaign covers zero-fee OWNER_WINDOW/AT_MINT, two distinct threshold
Safes, native funder refunds, live fee drift, complete signed Safe retry after a
real late funding call, provider revert/large return/out-of-gas/malformed results,
callback reentry and pointer drift, exact native/token deltas, failed refund
recipients, and permit nonce/bitmap rollback. Actual Core/Manager/Ledger cases
retain explicit typed Artist/entropy/governance boundaries. The actual
Coordinator mode cases described below run in the same campaign.

The shared callback ABI is payable, but the current primary-offer and burn-mint
profiles still reject any nonzero value before their reentrancy guard and sale
effects, retaining the original empty callback revert. Their zero-native-fee
rules are unchanged. The payment adapter wraps a rejected callback in its
original PaymentCallbackFailed error. Existing native surplus is preserved.
Current-stack regression sources exercise each rejection and retry identical
signed payment calldata with zero value, preserving original receipt and replay
checks (and actual source ownership/burn checks for burn-mint).

The refreshed fee-drift test uses an armed hostile token and an exact count of
one transferFrom across the underfunded attempt and repaired complete payment.
A separate authenticated-callback probe asserts SaleRevealFeeBelowRequired;
it explicitly impersonates the bound payment adapter to observe the error that
the real payment route wraps. A funded hostile-token control requires two pulls
across its failed and healthy attempts. These boundary oracles pass in native
execution. The current shared reveal/entropy-policy implementation
is retained, including DISABLED/INSTANT and terminal request-skipping checks.
Six additional regression sources compose the actual payment, Universal sale,
Core, Manager, Ledger and Coordinator for DISABLED, INSTANT with either render
requirement, and ASYNC NOT_REQUIRED. They cover exact token revenue, executor
excess, terminal status without an at-mint request, a later-block production
Instant draw, and real recipient rejection followed by identical signed payment
retry. This fixture selects the production Coordinator first; it does not bypass
Core successor continuity. Artist content evidence and the governance execution
context remain explicitly typed boundaries. Its Core registration gas config is
1,920,000 and sale reveal config is 2,000,000; these are fixture budgets, not a
production gas-capacity claim. All six regressions pass in native execution.

The settlement fixtures bind the actual conservation-floor ledger before a
sale. Unit fixtures retain an explicit typed Core/Metadata WAIVED declaration
boundary and register the real recorder. Current-Core fixtures select their
Metadata writer, declare WAIVED before mint, and bind the real floor through
Core governance checks. The floor validates the original recorder, candidate
and stored settlement result; no receipt is seeded. Existing unset-floor and
missing-tier negative fixtures remain separate and unchanged. These fixtures
do not establish actual Artist/Metadata documentary authorization.
