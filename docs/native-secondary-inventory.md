# Native secondary inventory

This source increment adds public `CUSTODY_INVENTORY_FIXED_PRICE` (14) to the
existing `StreamPrivateSaleAdapter`. It extends the accepted native private/offer
profile in [ADR0035](adr/0035-native-secondary-private-offers.md) and implements
the secondary branch of [SSA-INVENTORY and SSA-CUSTODY-ENTRY](stream-sales-and-auctions.md).
ABI compilation and selected bytecode measurement are recorded in the handoff.
The authored current-contract regressions have not been executed; native and
joined release validation remain pending.

The secondary declaration remains subject to the original transfer-history
conformance gate. Current owner, collection mapping and `MINTED` lifecycle alone
do not prove previous collector delivery. The new current tests explicitly
complete a PLATFORM_WORKS primary auction, record its official payment and
actually deliver the token to a collector Safe before resale. An unsold operator
return must not be declared secondary. General primary inventory and a universal
onchain transfer-history classification proof remain separate work.

## Configuration and custody

The original owner and per-collection configuration delegation authorize listing.
`registerInventory` accepts the exact immutable, strictly increasing set of 1 to
64 token IDs, a positive native unit price, original consignor, absolute time
bounds and optional per-buyer cap (zero means no cap). Every token must currently
belong to that consignor. The stored `inventoryHash` is `keccak256(abi.encode(ids))`;
`configHash` commits the `6529STREAM_NATIVE_SECONDARY_INVENTORY_CONFIG_V1` domain,
chain, adapter, nonce, original platform signer, complete config and inventory
hash. The sale ID uses the original sale domain with kind14 and phase zero.
The 64-item bound makes registration, opening and unsold cancellation finite;
it is not transaction-capacity evidence.

Each item enters only through the unchanged full `SaleCustodyGrant`, under the
original `6529Stream Sales` version1 EIP712 domain and canonical type string.
Its sale reference is the actual inventory ID. Both direct owner calls and
bounded ERC1271/EOA signatures retain the original verification, owner/Core/token
binding, append-only consumed digest and Core transfer ordering. The separate
`openInventory` call requires all manifest tokens still in custody. A revoked
item before initial opening prevents opening that incomplete manifest; a new
listing and fresh grant can be configured. After opening, revoking one unsold
item leaves other items available. No manifest is edited.

`revokeCustodyGrant` keeps its original selector, full-payload presentation and
revocation type/domain; known inventory grants dispatch to their item state.
Only the owner can authorize revocation, a relayer cannot redirect release,
and sold grants remain spent. `cancelSale` and `expireSale` stage all unsold
custody for original-consignor pull claims. They preserve completed items and
buyer claims. Original per-sale pause/unpause also recognizes inventory IDs.
Claims, expiry and revocation retain their provider-independent exits.

## Payment and disclosure

`purchaseInventory(id,tokenId,expectedConfigHash)` is a public native at-price
purchase with caller as payer and buyer. The immutable onchain standing config
is the purchaser's committed offer; no new signing family or fake zero buyer
signature is introduced. The exact config hash must match. Per-buyer caps and
one-way token state prevent repeated execution. At least the fixed price must
be supplied; excess is a separate caller pull credit.

Before purchase, `inventoryRoyaltyQuote` returns Core's current royalty receiver
and amount for that exact token/price, `secondaryConsignment=true` and
`externalRoyaltiesDisclosureOnly=true`. Original `saleRecord` exposes kind14,
zero primary policy, zero phase and native asset. No primary template, artist
floor, new mint or revenue-recorder call exists on this rail. Current PLATFORM_WORKS
contests block primary admission, not an owner's secondary disposal. The same
secondary boundary applies to Artist-bound collections.

Execution verifies state/custody/payment, marks the token sold and records its
buyer, then reads actual Core `royaltyInfo`. It credits consignor proceeds and
buyer excess, attempts bounded royalty payment, and finally attempts the Core
safe NFT transfer. Invalid royalty reads revert all effects. A rejecting royalty
receiver cannot block settlement: the amount becomes that receiver's royalty
pull credit. A rejecting NFT receiver gets its own perpetual claim. Guarded
callbacks cannot enter another purchase, revoke grants or alter custody claims.
Canonical `ConsignmentSettled` and the item record retain the assessed receiver
and amount even after later policy changes; `InventoryPurchased` additionally
identifies each public purchase.

The existing `refundableBalance`, `creditBreakdown`, `totalLiabilities` and
`claimRefund` cover original private/offer and inventory IDs in the same isolated
money store. `retryInventoryRoyalty(id,receiver)` permissionlessly retries exactly
that sale's aggregate royalty bucket for that recorded receiver, never proceeds
or buyer excess. Multiple items with the same receiver share that bucket, while
their immutable royalty assessments remain item-specific. Claiming the bucket
first prevents a later retry; a failed retry restores it. `claimInventoryNft`
lets only the beneficiary choose a destination; `retryInventoryNft` targets only
that beneficiary. None of these routes re-assesses or re-sells the item.

The original private/offer interface ID, selectors, signing preimages and storage
prefix remain unchanged. A new `IStreamNativeInventorySale` capability and one
appended inventory state root identify the extension. Existing module role,
version and constructor remain unchanged. The new workers use fixed compiler
links. Terminal assembly
returns are confined to the two new view encoders and the unchanged original
`saleDetails` tuple encoding moved into the worker; all mutations return normally
through the original reentrancy modifier cleanup.

ERC20 inventory, primary unsold-operator inventory, auction consignment, delegate
execution/refunds, surplus governance and comprehensive current release evidence
remain explicit follow-ups. This increment does not claim their completion.
