# Native selected-work fixed and private sales

These satellites compose a published content manifest with the current
Core, Manager, Ledger and official native recorder. Their implementation is
separate from the existing custody private-sale and curated-auction adapters.
See the [shared prepared purchase boundary](prepared-native-content-purchases.md)
for the Manager and recorder checks.

This is pre-audit source. Focused ABI checks do not establish runtime,
deployment, cold-call gas or release acceptance. The coordinating delivery
ledger records acceptance for each captured source version.

## Supported profile

| Carrier | Selection and authority | Primary rights |
| --- | --- | --- |
| `StreamNativeCuratedFixedPriceSale` | Explicit `PUBLIC`, or default `COMMIT_REVEAL` | PUBLIC: `STRICT_MATCH`; commit/reveal: `ALLOW_CURRENT` |
| `StreamNativeCuratedPrivateSale` | One buyer and one declared leaf, original signed `SaleAuthorization` | `STRICT_MATCH` only |

Both require a positive fixed native price, a collection PROFILE assignment,
one token per execution and a published manifest. `COMMIT_REVEAL` is enum value
zero and is required for differentiated content. PUBLIC requires a recorded
disclosure that pending selections expose the work to competing buyers.
Neither carrier accepts free overrides, Merkle price overrides, Dutch prices
or primary offers in this profile. Private mode 1 and nonzero `finalizeBy`
reject; a signature's policy mode is never rewritten.

## Deployment and configuration

The carriers use fixed linked libraries for registration, prepared execution,
receipt validation, runtime checks and read encoding, alongside the content,
clock and commitment helpers. Deploy and link the exact compiler products as
one release graph; these are typed calls in the carrier's storage and caller
context, with no buyer-selected execution target. The carrier retains its
operational reentrancy guard and buyer liabilities.

1. Deploy a carrier with the actual Manager, native recorder, Artist facade,
   RoleRegistry, governance authority and platform identity. The four governed
   gas rows, in order, are `SALE_ERC1271_GAS_LIMIT`,
   `SALE_ARTIST_AUTHORITY_GAS_LIMIT`, `REVEAL_ATTEMPT_GAS_LIMIT` and
   `SALE_NFT_DELIVERY_GAS_LIMIT`, all failure class 2. Optional native delegation
   uses the existing pinned deployment declaration.
2. Admit the carrier's existing prepared-sale module role. Predict the next
   original sale ID with `saleIdFor` and `nextSaleNonce`.
3. Deploy and admit `StreamNativeCuratedContentGate` for that exact carrier,
   sale, collection and phase. Publish every sorted manifest row, including
   its token-data hash and preview URI. Empty token data is valid when its
   actual hash is declared. The new gate declares the distinct purchase
   capability; the original auction gate cannot substitute for it.
4. Configure the phase with that gate, this carrier as executor, batch limit
   one and an enabled CONTEXT/static/static content counter with cap one and
   increment one. Registration pins the exact counter definition. A finite
   phase initially contains the entire nominal sale window.
5. Register immutable carrier terms, then obtain the actual Artist sale
   consent for the returned sale ID and configuration hash. Registration
   previews rights; it neither mints nor creates official revenue. Buyers
   cannot execute without consent.

Private registration additionally pins the buyer, selected content ID/hash,
and explicit collection signer membership: address, kind, revision, evidence
hash and admitting authority. Kind 1 uses ECDSA; kind 2 uses ERC-1271. Live
membership is required at purchase, while
`curatedSaleAuthorizationBinding(saleId)` always returns the historical
160-byte membership binding needed for later revocation.

## Identity and replay

The original sale ID and sale creation nonce stay unchanged across works.
`nextPurchaseNonce(saleId,buyer)` starts at one and advances exactly once when
a purchase or funded commitment is admitted. The purchase ID uses the existing
`6529STREAM_SALE_PURCHASE_V1` preimage with chain, carrier, original sale ID,
buyer and purchase nonce. Configuration and selected leaf bind separately.

The official receipt's execution ID is the existing prepared-native execution
hash. It is distinct from the purchase ID. Manager/Ledger authorization replay,
the cap-one content counter and the recorder's `(adapter,purchaseId)` replay
are independently enforced. Content uniqueness is scoped to the declared
sale/context; publishing a new sale does not prove collection-lifetime
uniqueness for a work.

PUBLIC supplies an empty commercial authorization and uses its prepared intent
hash as Manager's authorization ID. Private purchase uses the original
24-field Sales EIP-712 `SaleAuthorization` and canonical TICKET digest. The
signature binds the actual payer, transaction executor, full price, selected
leaf, policies and all four batch hashes. Initial custody is the carrier;
the private beneficiary is the configured buyer. Full-payload Manager
revocation uses the same TICKET lane, including after expiry.

## Buyer flows

### PUBLIC

Read the configuration, complete manifest, selected proof, next purchase nonce
and live `saleRevealQuote`. Call `purchaseSelectedContent` with the exact raw
token data, its declared hash/proof, mint commitment, final recipient and nonce.
Send price plus the live reveal fee. Excess becomes a buyer credit.

### COMMIT_REVEAL

Create the original domained content commitment from buyer, sale, selected leaf
and salt. `commitSelection` takes exactly the immutable positive purchase price;
it captures no reveal-fee allowance and creates no official settlement.
The emitted envelope joins the commitment to its purchase ID/nonce, nominal
deadline and finite absolute escape.

Windows are half open and non-overlapping:
`commitOpen < commitClose <= revealOpen < revealClose`. Reveal must come from
the committing buyer in a strictly later block. Call `revealSelection` with
the original purchase nonce, selection and salt, funding the live reveal fee.
Ledger's content counter resolves competing valid selections. Failure restores
the pending commitment and every payment/replay effect atomically.

Global, per-sale and synchronized collection stops toll only the union of
stops overlapping live commit/reveal windows. They never toll prestart time or
the gap, and never revive expired windows. `selectionWindows` reports the same
effective deadlines used by entrypoints. The finite absolute escape bounds
deposits even through an indefinite stop. Manager phase admission remains
independent of carrier clock extensions.

### Private selected work

Call `purchasePrivateContent` with the full original authorization, explicit
signature kind, selected proof/raw data and native delegation witness. The
configured buyer calls directly or uses an admitted live native delegate;
the authorization still names the actual executor. Pay the positive price and
live reveal fee. Success terminally completes that private sale. Expiry and
owner cancellation do not erase its historical authorization binding.
The private carrier's ERC-5267 `eip712Domain` reports `6529Stream Sales`, version
`1`, the current chain and that carrier's address.

## Settlement, delivery and refunds

Prepared minting initially gives the carrier custody. Its guarded callback
checks the exact Manager facts and forwards only the price to official native
settlement. The carrier verifies the returned receipt and independent purchase
replay, funds the live reveal fee, then attempts bounded safe NFT delivery.
Phase, policy, gate, Artist association and sale admission are checked again
after callbacks. A rejecting receiver reverts the entire purchase; a committed
buyer keeps the pending deposit for a retry or refund. This profile has no
separate NFT claim obligation.

`unlockSelectionRefund` converts a pending deposit into its buyer's full pull
credit after maturity, cancellation or absolute escape. It uses local state;
provider unavailability cannot block this exit. Before maturity,
`unlockSelectionRefundForReason` independently proves one of these facts:

- Phase ended.
- Collection supply or a supported static counter is exhausted.
- Bound mint policy is no longer current or in grace.
- The original Artist association is disputed or revoked.
- A referenced module is incident-revoked.

Selected-context exhaustion additionally proves the original commitment,
selected leaf and exact saved counter definition. An arbitrary failed external
call is not an unlock reason. Credits, pending deposits and refundable deposits
remain separate accounted liabilities; surplus sweeping cannot spend them.

Use `claimSelectionRefund` for commitment refunds and `claimRefund` for excess
reveal-fee credits. Direct claims choose a recipient. Delegated claims require
a live pinned grant and always pay the original buyer. Claims do not require
live sale, Artist, phase, entropy or module approval. Failed transfers preserve
the credit. Pause controls never disable claims or time escape.

Collection contest state is synchronized permissionlessly with a bounded exact
Artist read. Entry actions use the local stop flag. Governance ceremonies and
monitoring must keep it synchronized; ordinary sales do not add that external
contest read. Unchanged successful synchronization is idempotent.
