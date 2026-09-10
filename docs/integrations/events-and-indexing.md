# Events and indexing

This is the current stack's event model, **pre-audit and not production-ready**.
Use each deployed contract's exact ABI and address. The
[legacy catalog](../reference/legacy-stack/integrations/events-and-indexing.md)
describes a different stack.

## Identify the emitter first

Key events by `(chainId, blockHash, transactionHash, logIndex)` and retain block
number and emitting address. Decode only with the ABI assigned to that address.
An unrelated contract can emit a plausible signature in the same receipt; topic
alone does not establish provenance. Token identity is `(chainId, coreAddress, tokenId)`.

| Emitter | Events | Meaning |
| --- | --- | --- |
| Core | `Transfer`, `Approval`, `ApprovalForAll` | ERC-721 ownership and approvals |
| Sale adapter | `NativeSaleSettled`, `SaleParticipants` | Purchase token, operation root, paid profile, payer and recipient |
| Sale adapter | `SaleAuthorizationCancelled`, `SalePlatformSignerChanged`, `SalesPauseChanged` | Offer cancellation and invalidation |
| Auction house | `AuctionCreated`, `AuctionTerms`, `AuctionBidPlaced` | Identity, terms and updated bid deadline |
| Auction house | `AuctionRefundCredited`, `AuctionRefundWithdrawn`, `AuctionRecipientChanged` | Refund ownership and delivery choices |
| Auction house | `AuctionSettled`, `AuctionCancelled`, `NoBidAuctionNFTClaimPending` | Completed or pending custody exits |
| Split factory | `SplitProfileCreated`, `SplitProfileEntry`, `SplitWalletDeployed`, `SplitWalletDiscovered` | Immutable profile and wallet |
| Split wallet | `NativeReleased`, `ERC20Released` | Actual withdrawals |
| Artist registry | `CollectionArtistNominated`, `CollectionArtistAccepted` | Nomination versus accepted attribution |
| Mint-time coordinator | `EntropyRegistered`, `EntropyRequested`, `EntropyFinalized`, `EntropyRequestTerminal` | Bound request and terminal output |
| Core | `MetadataUpdate`, `BatchMetadataUpdate` | ERC-4906 cache refresh hints |

`NativeSaleSettled` indexes authorization ID, operation root and token ID; its data
contains digest, profile, wallet and amount. Correlate `SaleParticipants` through
authorization ID. Do not count arbitrary wallet deposits as official sales.

## Minimal purchase receipt handling

```typescript
// saleInterface is ethers.Interface for the exact deployed sale ABI.
const matches = receipt.logs
  .filter(log => log.address.toLowerCase() === saleAddress.toLowerCase())
  .map(log => { try { return saleInterface.parseLog(log); } catch { return null; } })
  .filter(event => event?.name === "NativeSaleSettled");
if (matches.length !== 1) throw new Error("Expected one sale settlement");
const settled = matches[0];
if (settled.args.authorizationDigest !== expectedDigest) {
  throw new Error("Unexpected authorization");
}
const tokenId = settled.args.tokenId;
```

Process only successful receipts. After your confirmation threshold, reconcile
Core ownership, auction status and credit at a consistent block. Keep provisional
UI state separate, and roll back derived rows whose block hash is no longer
canonical. Use block timestamps and bigint values, not local time or floating point.

## Entropy and metadata

Resolve `coordinatorAtMint` for each token instead of assigning old tokens to the
current coordinator pointer. `EntropyFinalized` makes output available; metadata
notification may fail independently, so absent ERC-4906 events do not prove no seed
exists. Reread `tokenSeed`, `tokenEntropyStatus` and `tokenURI` when needed. NFT transfer and
metadata finalization are separate transitions.

Definitions are grouped by [caller domain](../../smart-contracts/interfaces/stream/README.md).
The [metadata](metadata-rendering.md), [payment](withdrawals-and-credits.md) and
[current demo](../../script/current/README.md) guides explain follow-up reads.
Keep private keys and RPC credentials out of diagnostics; security reports go
through [SECURITY.md](../../SECURITY.md).
