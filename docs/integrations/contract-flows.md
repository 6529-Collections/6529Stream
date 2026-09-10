# Fixed-price purchase

This guide covers `StreamFixedPriceSaleAdapter.buy`. It is **pre-audit and not
production-ready**. The earlier API is preserved in the
[legacy reference](../reference/legacy-stack/integrations/contract-flows.md).

## Contract boundary

The adapter validates platform and accepted-artist consent, pays the signed split
profile's wallet, then asks the mint manager for exactly one token. The manager
applies phase policy and counters; permanent Core owns token identity, ownership
and supply. Failure in any step reverts the entire purchase, including payment,
nonce consumption, counters and minting.

Use the [sale interface](../../smart-contracts/interfaces/stream/mint/IStreamFixedPriceSaleAdapter.sol),
[mint reads](../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol) and
[Core interface](../../smart-contracts/interfaces/stream/core/IStreamCore.sol).
The [current integration tests](../../test/current/) exercise actual wired contracts.

## Preflight

At a consistent block, read the sale's `mintManager`, `splitFactory`,
`artistRegistry`, `platformSigner`, `signerEpoch` and `paused`. Check the manager's
`core` is your intended NFT contract. Then:

1. Read `artistRegistry.acceptedArtist(collectionId)`. A nomination alone does not
   authorize a sale; accepted attribution must match `sale.artist`.
2. Read `manager.phase(collectionId, phaseId)`,
   `manager.phasePolicyHash(collectionId, phaseId)` and
   `manager.phaseExecutor(collectionId, phaseId, saleAdapter)`. Bind the exact
   current policy hash after executor configuration.
3. Check `splitFactory.splitWalletExists(profileId)` and
   `splitFactory.walletFor(profileId)`. Display that immutable profile's accounts
   and shares before either party signs.
4. Check `authorizationUsed(artist, nonce)`, deadline, chain ID, payer, recipient,
   price and `keccak256(tokenData)`. Use a fresh nonzero nonce.
5. Simulate `buy` with the real payer, signatures and exact `msg.value` using
   `eth_call`. Inclusion can still fail if state changes after simulation.

A stale policy, changed signer epoch, filled cap, pause, cancellation or invalid
recipient may invalidate an offer. Refresh those reads before submitting.

## Authorization and submission

`SaleAuthorization` binds collection, phase, payer, recipient, accepted artist,
split profile, token bytes, mint commitment, phase policy, price, nonce, deadline
and signer epoch. Both parties sign the same EIP-712 digest. See the complete
[typed-data example](wallets-and-signatures.md#fixed-price-typed-data).

```solidity
(uint256 tokenId, bytes32 operationRoot) = saleAdapter.buy{value: authorization.price}(
    authorization,
    tokenData,
    platformSignature,
    artistSignature
);
```

Only `authorization.payer` may submit. `msg.value` must equal `price`, including
zero for an explicitly signed free sale. This API accepts native ETH, not ERC-20
payment. Token bytes must hash to `tokenDataHash`. A contract recipient must accept
safe minting. Nonces are scoped to artist and this adapter's chain/address, across
collections. The artist can call `cancelAuthorization(nonce)` before consumption.
A successful purchase consumes the nonce; a reverted purchase does not.

## Receipt and next actions

Wait for a successful receipt and your confirmation policy. Filter
`NativeSaleSettled` by the **configured sale adapter address**, then require the
expected authorization ID, digest and profile. Take `tokenId` and `operationRoot`
from that event; do not pick an arbitrary transfer log. `SaleParticipants` adds
collection, artist, payer and recipient. Confirm `core.ownerOf(tokenId)`.

Entropy registration occurs during minting, but final randomness may arrive later.
Read Core's mint-time coordinator and [request and render](metadata-rendering.md)
without treating pending metadata as a failed mint. Split accounts can read
`wallet.releasable(address(0), account)` and [release proceeds](withdrawals-and-credits.md).

Track draft, awaiting signatures, submitting, mined and confirmed purchase states
separately from metadata pending/final state. Decode reverts with the deployed ABI;
do not silently change a signed field. A backend may construct offers, but platform
signing belongs behind its authorization policy and custody boundary. Never ship
a platform private key in the browser or sign arbitrary client input automatically.
See [signer custody](../signer-custody-readiness.md) and
[private vulnerability reporting](../../SECURITY.md).
