# Standard ERC20 Dutch sales

`StreamERC20DutchSale` is a separate singleton sale carrier. It supports a fixed
linear or stepped Dutch schedule, a canonical Sales-v1 signer, or public purchases
executed by the token payer. It does not implement clearing rebates or reinterpret
an existing fixed-sale signature or record.

## Admission and configuration

Admit the actual carrier runtime as `DUTCH_AUCTION_ADAPTER`, with module version
`keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")` and the original
`IStreamERC20SaleExecution` interface. The additive
`IStreamERC20DutchSaleResolution` capability must report the exact
`keccak256("6529STREAM_ERC20_STANDARD_DUTCH_V1")` profile. The sole pulling Payment
adapter retains its original role and interface. Each sale captures both actual
Registry registration records; their original lifecycle and code checks apply.

`IStreamERC20DutchSale.Configuration` contains the common sale configuration,
asset, actual Payment adapter, immutable Dutch schedule and a `declaredFree`
election. The common configuration uses `saleKind = 3`, `unitPrice = 0`, a positive
supply limit, strict fixed collection PROFILE rights, current mint policy and
current primary-policy hash. Its start equals the schedule start. A time-limited
sale ends after the schedule end; the explicit manual-close profile has no end.
Zero resting price requires `declaredFree`. Original Artist policy/sale consent,
phase executor admission, signer membership, pauses and collection association
remain independent requirements.

## Authority and price

Signed mode uses every original `SaleAuthorization` field, the original
`6529Stream Sales` / `1` EIP-712 domain at this actual carrier, and explicit EOA or
ERC1271 kind. The original Manager authorization ID derives from that full digest.
The authorization binds payer, executor, recipient and beneficiary arrays, token
data, mint commitments, collection, phase, sale, asset, policies, nonce and deadline.
Ungated Manager normalization remains authorizer zero; the sale signer is separate.

The immutable schedule computes the inclusion price. Without a price override,
that charge cannot exceed the signed authorization's `unitPrice`. A proven price
leaf **replaces** that signed price role: charge is the minimum of schedule price
and leaf price. A valid leaf may therefore authorize a charge above the original
signed base ceiling. The request maximum and the original PaymentIntent maximum
remain independent limits on actual token units. The same original leaf/proof
bytes reach the Manager and Ledger.

Public mode has a literal-zero seller authorization and signature. Payment
requires its actual caller to equal the candidate payer, including when the charge
is zero. A sale-wide PaymentIntent cannot authorize an unrelated public executor
or recipient redirection. A threshold Safe can be both payer and executor by
calling Payment through its original Safe transaction path.

## Execution and permits

The four `IStreamERC20DutchPayments` entries accept a `Request` containing the exact
carrier address/runtime, sale/config hash, maximum amount and canonical encoded
`Execution`. Payment first locks its original phase, then asks only that admitted
carrier to resolve the current candidate. Preview is a quote, not a frozen price
or a substitute for inclusion validation. The carrier recomputes the same complete
candidate in its callback and rechecks current price, policy, admission, rights and
Artist state after funding and mint. Paid execution uses the original active
commitment-before-callback/funding sequence and Recorder result checks.

Allowance and PaymentIntent paths preserve their existing meanings. The additive
EIP2612 maximum signs a permit value that may exceed the actual charge; only the
current amount is pulled and the required remaining allowance is checked. Permit2
likewise signs `TokenPermissions.amount = maximum` while requesting only the
actual current amount. Its upstream nonce and attested allowance rules remain in
force. An existing fixed-payment entry still uses exact equal permit/pull amounts.

A declared zero outcome uses the separate authenticated carrier free callback.
It invokes no permit or token pull, consumes no PaymentIntent nonce and creates no
official amount-zero revenue settlement. The returned settlement tuple is literal
zero. Canonical sale and Manager replay still prevent a second mint. Historical
carrier receipts identify the free mint without presenting it as official revenue.

Native call value is separate from ERC20 price. The original reveal quote,
preflight and fund-and-attempt helpers apply to paid and free outcomes. Only the
bound executor owns excess credit and chooses a pull-refund recipient. Failed
accounting, callbacks or minting revert the whole transaction; bounded provider
failure retains the original reveal semantics.

## Validation boundary

The new Payment keeps all 60 previous ABI entries and its full recursive storage
layout. Fixed read/encoding workers contain no authorization or replay writer.
Original interfaces, fixed entrypoints, domains and nonce types remain available.
Eight selected production products fit the original code limits on Solidity0.8.19,
via-IR200, Paris, no CBOR. The final joined capture measures the carrier at
24,482 runtime / 30,799 creation bytes and Payment at 19,589 / 22,758. This source
includes the separately reviewed canonical claims and Dutch Recorder dependency.

Twenty-six tests are authored and typechecked in a 512-source closure. Twenty-one
use actual current Core/Manager/Ledger, carrier/Payment/Recorder, Registry, wallets,
conservation floor, Metadata and upstream Safe/Permit2 with typed Artist, entropy,
ERC20 fault and target-side governance boundaries. Five finite controls exercise
the original fixed Payment entrypoints and closed transport with their original
typed fixture. Runtime execution of this new source remains pending. Earlier price
or original ERC20 run results do not establish acceptance of this new Payment.
Full current-stack, cold-budget and deployment acceptance are separate work.
