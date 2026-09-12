# Standard native Dutch sales

`StreamNativeDutchSale` implements the signed, one-token standard Dutch profile
(`DUTCH_AUCTION = 3`). Its registry category remains
`NATIVE_PRIMARY_SALE_ADAPTER` with the `IStreamNativeSaleBinding` capability.
The configured schedule is immutable, and every positive execution uses the
existing native entry of the official primary-sale recorder. This implementation
does not add an ERC20 or arbitrary payment callback entry.

Register the actual consumer runtime through the canonical ModuleRegistry and
admit its Manager phase. The constructor pins the recorder, Manager, resolver,
factory, artist facade, reveal-fee coordinator and role registry to the same
Core and governance authority. Supply explicit `SALE_ERC1271_GAS_LIMIT`,
`SALE_ARTIST_AUTHORITY_GAS_LIMIT` and `REVEAL_ATTEMPT_GAS_LIMIT` rows, each with
failure class 2. The test values are planning inputs, not fully cold genesis
measurements. The inherited raise route remains restricted to the exact
governance executor and action context.

The sale's full configuration commits the fixed mint policy, price schedule,
time and quantity limits, declared-free flag, registration primary-policy
baseline and primary assignment. Gas values are excluded. Registration is
inert: purchases require the current facade's caller-bound sale consent before
proof validation and funds move. An elected REQUIRED consent also yields a
bounded canonical evidence read for `SaleConsentRecorded`. Missing capability,
malformed reads and absent required consent fail closed.

The registration `expectedPrimaryPolicyHash` is immutable historical evidence.
Immediate STRICT mode checks each purchase's freshly signed concrete policy
against its execution preview. It does not require that signed hash to equal
the registration baseline. The assignment must still match registration. A
lawful COLLECTION_ARTIST payout designation change therefore requires a new
concrete purchase proof, while the underlying template terms remain fixed.
This is not a sale-wide lock on the original payout address.

For LINEAR0, the charge is
`startPrice - floor((startPrice - restingPrice) * elapsed / duration)`.
The charge rounds upward, so linear rounding never creates an early zero.
For STEPPED1, each completed `stepSeconds` interval subtracts `stepAmount`,
clamped at the resting price. At `endTime` the resting price applies even if
the final step interval is partial. Pre-start quotes show the starting price;
purchases before the start reject. Unused LINEAR step fields must be zero,
reserved decay kinds reject, and positive flat schedules are valid.

The signed `unitPrice` is a maximum. It remains unchanged in the complete
EIP712 authorization digest and canonical Manager authorization ID when a
later block lowers the charge. The payer supplies at least the execution-time
price plus the separately captured live reveal fee. Only the price enters
official revenue; excess is credited to that payer under the originating sale.
`claimRefund(saleId, recipient)` debits only that sale's credit and the aggregate
liability. Claims remain independent of pause, close, provider availability and
current artist state. Rejected receivers preserve the entire credit for retry.
Forced surplus is excluded from buyer credit and is not swept by this profile.

A zero resting price requires an immutable declared-free configuration;
`startPrice = 0` always rejects. At the declared zero boundary, the result is
FREE1 and there is no primary-rights lookup, materialization, official key,
wallet deposit or revenue-escrow credit. The actual Manager's eligibility and
artist/economics floors still apply, and the declared reveal fee remains owed.
A missing or undeclared fee policy is never interpreted as zero.

Positive purchases return PAID2. The recorder materializes an authorized
template once before mint callbacks, and subsequent checks retain that exact
profile and wallet. A later callback payout revision can affect the next
purchase but cannot redirect this execution. Commercial signature nonces and
per-sale execution nonces are separate consumed lanes. Full preview root and
single operation ID must match the actual mint result. Current artist identity,
binding generation, active authority, selected providers and consent are checked
again after external effects.

The immediate execution captures one reveal fee and request mode. It funds that
quote exactly even if a later callback updates the policy. AT_MINT requires
actual coordinator requester admission in the deployment plan. The entire
request uses the explicit governed attempt budget; EIP150 admission failure
reverts the purchase, while an admitted request revert, OOG or malformed result
is recorded with a bounded prefix and preserves the paid mint and fee escrow.
The separate coordinator owns retry and fallback behavior. OWNER_WINDOW does
not make an automatic request.

The domain tests use real factory/wallet/escrow/recorder/ModuleRegistry/
RoleRegistry and official Safe contracts. Core, Manager, artist facts,
reveal-fee endpoint and governance-action context are explicit domain doubles.
Actual current-stack composition, requester admission and fully cold gas sizing
remain integration evidence. Universal ERC20 Dutch and permit paths, uniform
clearing rebates, public/Merkle authorization, generalized content/quantity
profiles, delegated claims and governed surplus/export tooling remain separate
delivery slices. A standard native Dutch test does not establish those branches.
