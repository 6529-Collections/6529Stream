# Current native primary offer signing

`current-primary-offer-signing.ts` contains the pure signing and identity
producers for the native primary `OFFER_SALE` carrier. The final carrier source
is commit `6d69483cc7eeee748271f531821ed2bf7643a787`. The selected compiler capture
uses source commit `cf268d24bd0098c90ece4cd2b9d306802d9c1b62`, tree
`ca5b8a92`, and includes the Mint test seam at `3158865`. These helpers do not
read a chain, validate a signature, inspect replay storage, or prepare a
transaction.

## Two signatures and two replay stores

An acceptance carries two complete original Sales payloads:

1. The buyer's permanent 12-field `SaleOffer`.
2. The admitted seller's permanent 24-field `SaleAuthorization`.

Both use EIP-712 domain name `6529Stream Sales`, version `1`, the selected chain
and the primary offer carrier address. Primary offers keep `tokenId`, native
`asset`, and `finalizeBy` zero. The sale is kind `6`; it is not the kind-`5`
private carrier and it is not an ERC-20 offer.

The replay identities remain separate:

- `primaryOfferBuyerAuthorizationId` wraps the full buyer offer digest once in
  `6529STREAM_MINT_TICKET_AUTHORIZATION_V1`. Manager and Ledger consume or void
  this TICKET.
- `primaryOfferSellerReplayDigest` is the full seller authorization EIP-712
  digest itself. The carrier's `digestConsumed` and `digestRevoked` mappings use
  it directly.

A new seller nonce does not change an already consumed or voided buyer offer.
The offer digest, seller digest, sale ID, purchase ID and later prepared-mint
receipt coordinates are all different values.

## Actual one-token arrays

`primaryOfferBatchHashes` commits the exact arrays used by the Manager:

- initial recipients `[carrier]`;
- beneficiaries `[buyer]`;
- raw token data `[tokenData]`; and
- mint commitments `[mintCommitment]`.

The helper accepts complete token bytes up to the carrier's 8192-byte bound and
a nonzero mint commitment. Do not replace the hash of the `bytes[]` array with
the hash of its single byte string.

## Selected and collection-level offers

`primaryOfferSigningSnapshot` normalizes the nested configuration, both signed
messages, raw token data and mint commitment into immutable copies. It then
requires every shared term and all four array hashes to agree.

For a selected unminted work:

- the manifest root and token-data hash are nonzero;
- both signatures use the original double-hashed content leaf; and
- the configuration pins the selected content ID and token-data hash.

For a collection-level offer:

- manifest root, configured content ID and configured token-data hash are all
  exactly zero; and
- both signed `contentSelectionHash` fields are exactly zero.

The collection path still signs the actual raw token bytes through
`tokenDataArrayHash`. The zero selection does not mean an empty token payload.
Gate absence and live phase admission are transaction-preparation checks in the
carrier workflow module, outside this pure signing surface.

The seller deadline may not exceed the immutable sale end. The buyer deadline
is allowed to extend beyond it because the carrier independently enforces the
sale window at acceptance. Both signatures use `finalizeBy = 0`.

## Historical revocations

Buyer revocation uses `MintTicketRevocation(chainId, manager, ledger,
authorizationId)` under the original Sales domain. Manager's full-payload
`voidMintOffer` authenticates the original buyer, even when a delegated signer
signed the offer. A custody-path `SaleOfferRevocation` is a different operation
and cannot void the primary-mint TICKET.

Seller revocation uses `SaleAuthorizationRevocation(chainId, saleAdapter,
authorizer, authorizationDigest)` under the Sales domain. The carrier accepts a
direct call from the historical configured signer or a relayed signature over
that exact payload. It consumes the same seller digest used by acceptance.

The workflow caller must submit the full original offer or authorization and
check the historical carrier, Manager and Ledger state. These pure payloads do
not establish current admission, signer membership, deployment identity,
payment availability, signature validity, or runtime acceptance.
