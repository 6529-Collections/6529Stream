# Native delegated claims for private sales and inventory

StreamPrivateSaleAdapter exposes the additive IStreamPrivateSaleDelegatedClaims
capability for private-sale kind 5, accepted-offer kind 6 and native secondary
inventory kind 14. This implements the claim caller requirements in
[SSA-ADAPTER and SSA-DELEGATE](stream-sales-and-auctions.md).
Offer signing authority is unchanged.

## Deployment and authority

The deployment tuple appends an optional delegateRegistry, delegationUsecase,
baseModuleManifestHash and delegationGas configuration. An entirely zero
optional configuration retains the original self-only deployment. A nonzero
registry pins its runtime hash and the original deployment chain; the
DELEGATE_REGISTRY_GAS_LIMIT parameter is registered during construction and
keeps the existing delayed governance rules.

This capability reuses the existing retained-row NFTDelegation profile and its
literal compact manifest encoding, including the historical
6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1 domain. The encoded chain,
actual adapter address, base manifest, Core, registry address/runtime and
usecase distinguish each declaration. delegationManifest() returns the exact
bytes whose hash must be registered for this adapter. Both private-sale and
inventory registration verify this commitment before consuming the sale nonce.

A witness contains only walletWide and the registry row index. The fixed worker
reads the full original registry row at claim time, under the governed cap and
parent-gas precheck. It requires the exact vault/delegate, live start and expiry,
all-token scope and token coordinate zero. Core-wide or wallet-wide scope uses
the configured usecase. Missing, expired, revoked, malformed, reverting or
runtime-replaced registry facts fail closed. No new signature or caller-provided
authority facts replace the registry.

## Claims

- claimRefundFor(saleId, account, witness) pays all that account's original
  excess, consignor and saved royalty credits to account.
- claimNftFor(saleId, account, witness) delivers only to the saved buyer or
  original consignor who owns the private-sale/offer claim.
- claimInventoryNftFor(saleId, tokenId, account, witness) applies the same
  rule to the exact inventory token.

A delegate cannot select another receiver or another beneficiary. These calls
share the existing credits, per-token claim flags, liabilities, events and
reentrancy guard. Failed native refunds roll back the entire claim; failed
bounded NFT delivery preserves the original NFT claim. A successful claim
cannot be replayed through another entrypoint.

Earned claims do not repeat current sale/module admission, pause, Artist,
royalty-source or mint authorization. The delegation read stays live for a
delegate-triggered claim. Original claimRefund, claimNft and claimInventoryNft
let the account choose a receiver and remain independent of registry
availability. Original permissionless NFT retries still deliver only to the
stored account. No new mint, reveal or primary revenue occurs.

## Compatibility and validation boundary

Original external sale/signing selectors, wire structs, signature domains,
sale/configuration hashes, custody grants and replay meanings remain unchanged.
The constructor tuple changes explicitly as above; the existing fixtures pass
the all-zero optional configuration. Original storage roots are retained.

To keep the host within the runtime limit, fixed compiler-linked code handles
the new claim dispatch, four original terminal read encoders and the original
sale-record writer. The writer still follows all admission/ownership reads and
the original nonce consumption, makes no external call, and preserves original
hash/write/event ordering. Raw terminal returns occur only in views; mutation
returns run the host guard cleanup.

Nine new authored cases cover actual current token delivery/payment, both
private/offer and inventory claims, two-owner Safe delegation, exact manifest
admission, live scopes/revocation/expiry/malformed reads, preserved own exits,
and byte-identical Safe retry after authorization and actual refund callback
failure. Original inventory cases are inherited with unchanged default setup;
the new current cohort enables the declaration profile explicitly. The unit
zero-mode case retains its typed Core/governance boundary.

This handoff includes ABI/source checks and selected production bytecode
measurement. The authored behavior cases have not been executed in this batch.
The current fixture retains typed Artist, entropy and governance action
contexts; it does not establish a full candidate, gas-capacity or audit result.
Delegate-signed offers and other adapters' missing claim surfaces remain
separate work.
