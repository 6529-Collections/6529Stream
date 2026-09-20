# Universal same-leaf ERC20 price carrier

This additive ADR0019 carrier was applied after renewed review of the exact v8
packet on 20 September 2026 (approval tool165646). Earlier denied proposals and
review evidence remain preserved. The 42 tests are authored and typechecked; the bounded unit run and its
limits are recorded below. Current-stack and launch acceptance remain pending. Existing
Universal and Payment contracts are unchanged.

`StreamUniversalAllowlistPriceSale` uses the existing one-token, order-1,
fixed collection PROFILE rights path. Admit its actual runtime under
`FIXED_PRICE_SALE_ADAPTER` / `6529STREAM_UNIVERSAL_SETTLEMENT_V1` and the original
`IStreamERC20SaleExecution` capability, then separately admit it as the Manager
phase executor with the actual Artist policy/sale consents. This does not make
it a proofless `IStreamUniversalFixedPriceSaleAdapter` implementation.

Register the original positive-base-price SaleConfig together with exactly one
phase Merkle price-counter ID and an immutable `allowFree` election. The config
commitment is `keccak256(abi.encode(ALLOWLIST_CONFIG_V1,
keccak256(abi.encode(original CONFIG_V1,saleId,config)),policy))`. The selected
original PAYER/RECIPIENT leaf supplies its exact price override or the base price.
The complete canonical resolver bytes go unchanged to price verification and
Manager mint execution. Ledger still enforces its original cap and subject.

Use `previewAllowlistExecution(execution,resolverData)` and pass both results
unchanged to one of the original Payment adapter's four ERC20 entrypoints.
Platform/Artist authorization keeps the original UniversalSaleAuthorization
type, name, version and chain domain; its verifying address is this new carrier.
Old-carrier signatures and replay state are never imported. PaymentIntent,
EIP2612 and Permit2 remain the original sole-spender protocols with token amounts
in asset base units. Supply native allowance as call value independently.

`saleRevealQuote` exposes the shared native quote; `allowlistRevealQuote` is an
additive alias. Both paid and free routes capture the current quote before
funding/replay, call the original preflight and fundAndAttempt helpers, and credit
exact excess to the signed executor. Later operational fee changes do not change
the captured fee; pointer/runtime and token/policy checks still apply. Accounting
failures revert everything. Provider request failures remain bounded and isolated.

A proven zero tier is executable only if `allowFree` was registered. Its separate
payable `executeAllowlistFreeMint` requires the signed executor; it does not call
Payment, consume a payment intent or record official ERC20 revenue. Zero token
price does not imply zero native reveal fee. Positive tiers cannot use this path.

The existing `IStreamImmediateSaleReveal` refund interface exposes amount,
liability and retained sale/executor enumeration. Only the credited executor can
choose a refund recipient; the token payer has no implicit claim when distinct.
Claims work while paused, cancelled or module-retired. State is consumed before
the recipient call, the reentrancy guard remains active, and failed transfer or
unexpected balance changes revert credit consumption. Passive surplus is not a
purchase or an executor credit. Normal successful mutations return through the
guard epilogue. The view-only helper has typed mapping references and no writes.

The constructor pins actual current Core/Manager/recorder/Artist dependencies and
the original SplitFactory governance authority, and registers one canonical
REVEAL_ATTEMPT_GAS_LIMIT row (floor at least100000, failure class2). The new
carrier owns all storage, including appended native credit rows. No existing
contract slot, selector, schema, authority, fee rule or signing domain changes.

Authored tests include35 bounded unit cases and7 current-stack recipes. Unit
Core/Artist/Manager/counter/entropy/governance boundaries are typed fixtures;
Payment, Recorder, Registry, wallets, Permit2 and threshold Safe are actual.
The current recipe uses actual Core/Artist/Manager/Ledger/Safe and its inherited
WAIVED conservation setup; external entropy and ERC20 are explicit fixtures.
Those seven current recipes retain zero-native execution; native fees and refunds
are covered by the separate authored unit-boundary cases. Inherited fixture gas
settings do not establish production cap acceptance. The seven current recipes
remain unexecuted.
The selected five-product capture passes Solidity 0.8.19 via-IR, 200 runs, Paris
with no CBOR metadata: this carrier is 22,005 runtime / 27,506 creation bytes.
Its original 121 ABI entries and recursive storage layout are unchanged. The
two admission calls use the already accepted fixed SaleExecution worker; its
original checks and caller context are retained. The isolated 302-source unit graph includes the reviewed genuine conservation
floor fixture correction. All **35 bounded unit cases pass** on Solidity0.8.19,
via-IR200/Paris/no-CBOR. Its102 artifacts (100 concrete production products) pass
exact source/compiler/link/metadata verification and the original production code
limits before tests. All302 source files match the committed corrected recipe.
The cached tests invoked no compiler and left every artifact unchanged.

Earlier negative captures remain retained. The fixture corrections evaluate the
same public-library encoding before one-shot Foundry prank/revert expectations,
and expect the original `ReentrancyGuardReentrantCall()` custom error for token
and refund callbacks. They change no production byte or accounting assertion.
The positive scope is the35 typed-boundary unit cases described above. It does
not include the seven current-stack recipes, the later Dutch Payment changes,
or launch acceptance.

This profile does not implement the separate `6529Stream Sales` signing family,
public unsigned sales, Dutch/PWYW/clearing programs, multi-token/prepared batches,
or dynamic template/token rights. It does not change Offer/Burn native-value
policies, transfer or approve funds externally, or authorize a testnet deployment.
