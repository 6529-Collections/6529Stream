# Canonical native free claims and chosen prices

`StreamNativeClaimSales` consumes the original 24-field `SaleAuthorization`
under `6529Stream Sales`, version `1`, at its own deployed address. It supports
ZERO_PRICE_CLAIM (`12`) and PAY_WHAT_YOU_WANT (`13`) through separate signed and
unsigned public entries. Each execution mints one token through the actual
Manager and Ledger. A zero-price execution creates no official revenue or
conservation settlement receipt.

## First profile

| Setting | Accepted values |
| --- | --- |
| Authority | SIGNED (`1`) or PUBLIC (`2`) |
| Quantity and supply | One token per purchase; positive immutable sale cap |
| Payment | Native; the caller is the explicit payer and executor |
| Mint phase | Existing, authorized, single-step capable and ungated |
| Paid rights | Collection PROFILE or static TEMPLATE, STRICT (`0`) |
| Allowlist | One original Merkle price counter, or none |
| Closing | Timed, or manual with `endsAt = 0` |

The configuration wraps the original immediate-sale configuration as `sale`
and appends `maxUnitPrice`. The purchase wraps the original request as `mint`
and appends `chosenUnitPrice`. Configuration, request and execution hashes use
the claim family's distinct domains. The existing fixed/open adapter and its
selectors retain their supported kinds and positive-price requirement.

Use the [canonical immediate setup](native-immediate-sales.md) for deployment,
governed signer membership, native module admission, phase authorization,
Artist consent, pauses and reveal parameters. Consent binds the complete
registered claim configuration, including its price band. The Manager also
enforces its own phase, counter, royalty and replay policies.

## Price and authorization

For ZERO_PRICE_CLAIM, configured minimum and maximum, chosen price, signed
`unitPrice` and expected primary-policy hash are zero. A proven positive Merkle
override is rejected. Free claims do not resolve paid primary rights.

For PAY_WHAT_YOU_WANT, the configuration's `sale.unitPrice` is the immutable
band floor. The maximum is positive and at least that floor. A signed
authorization's `unitPrice` is a minimum; a public purchase starts with the
configured floor. An authenticated price override replaces the signed/public
minimum, then the configured floor still applies:

```text
effective minimum = max(configured floor, proven override or authority minimum)
effective minimum <= chosenUnitPrice <= configured maximum
```

A proven zero can replace a signed minimum of 1000 when the configured band is
`[0, 2000]`; it cannot permit zero in a band starting at 1000. The adapter and
Manager receive the identical original resolver proof bytes and beneficiary.
The override flag distinguishes an explicit zero from an absent override.

SIGNED mode binds all original authorization fields, including this chain,
adapter, Manager, immutable sale/phase/kind, explicit parties, tagged one-token
array hashes, expected mint policy, nonce and deadline. Quantity is one;
asset, primary-policy mode, selected-content hash and finalize-by are zero.
PWYW binds its configured expected primary-policy hash. The caller chooses
the final price in calldata; that price is included in the mint request and
operation identities, while the seller signature authorizes its minimum.

PUBLIC mode has no seller signature and preserves a zero Sales digest. Its
Manager replay ID uses `6529STREAM_NATIVE_PUBLIC_CLAIM_MINT_AUTHORIZATION_V1`
and binds chain, adapter, Manager, configuration and the complete request.
SIGNED mode wraps the original Sales digest in the existing MintTicket ID
domain. Historical revocation uses Manager's original immediate-sale binding
and full-payload method, including after signer disablement or sale closure.

## Free and positive executions

At zero price, Manager consumes the authorization and operation identities,
mints the token and executes the original reveal path. The adapter records
the execution and emits `FreeClaimExecuted`; `settlementKey` remains zero.
There is no paid public-candidate witness, recorder call, official total or
first-sale conservation receipt.

At a positive price, the entire chosen amount is official primary revenue.
The original native recorder checks strict rights and the permanent floor,
routes funds and stores its original result before minting. Public settlement
uses the existing exact active-candidate commitment. A tip is not routed as a
separate transfer.

Without a declared reveal policy, send exactly the chosen price, including
zero for a free claim. With a declared policy, quote and fund the original
reveal fee in addition to the chosen price; unused allowance becomes payer
pull credit. A declared zero fee still permits pull credit. Refunds remain
independently claimable after closure or pause.

All executions recheck retained admission, mint policy and Artist facts after
external interactions. Positive executions also retain the paid-rights check.
A receiver, fee, floor or retained-policy failure rolls back funds, receipts,
sale counters and Manager/Ledger consumption, permitting an identical valid
retry after repair.

A prior free mint grants no exemption to a later paid mint. Core does not
permit a new conservation-tier declaration after minting has begun. Declare
any intended WAIVED tier before the first mint; an undeclared collection's
later paid purchase still needs the genuine LITE evidence. A missing paid
floor cannot be repaired by treating an earlier free claim as a receipt.

## Validation boundary

The focused source suite covers signed/public free claims, chosen-price bands,
Merkle overrides, reveal credits, Safe retries and later paid-floor refusal.
Its Artist and entropy collaborators are explicit typed boundaries; other
listed settlement and mint contracts are actual implementations. These cases
are separate from the shared full-current capture, production link/size gates,
gas checks and release evidence. Source implementation is not deployment or
audit acceptance.
