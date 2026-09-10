# ERC-20 fixed-price purchases

The current `StreamERC20FixedPriceSaleAdapter` can take an approved ERC-20,
fund a verified split wallet, and mint through the actual Stream manager and
Core in one transaction. A failed payment leg, mint, recipient callback, or
mint-identity comparison reverts the entire purchase.

This is a new adapter alongside the [native purchase path](contract-flows.md).
It does not change native sale signatures. Deployment of the adapter does not
approve any token or open a sale: governance must admit the token, configure
the mint phase, assign a primary split and register the sale first.

## Read the deployed configuration

Use the caller interfaces, without importing implementation contracts:

```solidity
import {IStreamERC20FixedPriceSaleAdapter} from
    "smart-contracts/interfaces/stream/mint/IStreamERC20FixedPriceSaleAdapter.sol";
import {IStreamPaymentIntentVerifier} from
    "smart-contracts/interfaces/stream/revenue/IStreamPaymentIntentVerifier.sol";
```

Read `mintManager`, `artistRegistry`, `revenueResolver`, `splitFactory` and
`assetPolicyRegistry` from the adapter. The primary revenue resolver is a
separate dependency from the Core's royalty resolver. The factory pins the
same asset policy used by split wallets.

Read `saleRecord(saleId)` and check its cancellation flag, time window and
`paused()`. Its immutable configuration contains:

| Field | Meaning |
| --- | --- |
| `collectionId`, `phaseId` | Current manager mint phase |
| `asset`, `price` | Exact token address and smallest-unit amount for one NFT |
| `revenueClass` | Primary-assignment namespace selected by the sale |
| `mintPolicyHash` | Manager policy committed when the sale was registered |
| `expectedPrimaryPolicyHash` | Strict current primary-assignment commitment |
| `startsAt`, `endsAt` | Inclusive purchase window |

`primaryPolicy(collectionId, revenueClass)` returns the live canonical policy
hash, profile ID and verified wallet. It resolves collection then default
assignments for token ID zero, before minting. The hash uses
`6529STREAM_PRIMARY_POLICY_V1` and binds the actual resolver, revenue class,
collection, zero token/template context, profile, wallet and assignment hash.
The assignment hash includes its frozen state. An assignment change or freeze
can therefore make an existing sale stale; register a new sale and obtain new
authorizations instead of silently accepting changed economics.

## Sale identity and creator consent

Governance calls `registerSale(SaleConfig)` after mint-phase and asset setup.
The adapter assigns a monotonically increasing `saleNonce`, starting at one:

```solidity
saleId = keccak256(abi.encode(
    keccak256("6529STREAM_SALE_V1"),
    block.chainid,
    address(adapter),
    uint8(0), // FIXED_PRICE
    collectionId,
    phaseId,
    saleNonce
));
```

The returned record's `configHash` binds all stored commercial terms. The
platform and currently accepted collection artist each sign the same
`ERC20SaleAuthorization`:

```text
ERC20SaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 nonce,uint64 deadline,uint64 signerEpoch)
```

Use `authorizationDigest(authorization)` for the digest. Read `signerEpoch()`
immediately before creating the payload. The artist nonce is independent of
the payer's intent nonce and is scoped to `(artist, nonce)` at this adapter.
Each successful purchase consumes it. `cancelAuthorization(nonce)` lets the
artist invalidate it, including while purchases are paused.

The sale's immutable `configHash` is part of this signature, so a signature
cannot be reused with another asset, price, phase or revenue policy even
though those fields are read from the sale record rather than repeated in the
authorization. Multiple purchases may use one sale ID with distinct artist
authorizations and payer nonces.

## Payer allowance and signed intent

The payer approves the **ERC-20 sale adapter address** as spender. The adapter
itself performs `transferFrom(payer, adapter, price)` and then transfers the
exact amount to the verified wallet. Approving a relayer or the older
`StreamPrimarySaleSettlement` address does not authorize this path.

A relayed purchase requires this exact payload:

```text
StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)
```

`saleRef` is exactly the registered `saleId`, not a settlement key, mint root
or authorization digest. The intended amount may be at most `maxAmount`;
the sale's exact price remains independently enforced. The asset and primary
policy must match the same sale.

All three signature surfaces in this adapter—commercial authorization,
payment intent and intent revocation—use the domain reported by
`eip712Domain()`:

```text
name:              6529StreamPaymentIntentVerifier
version:           1
chainId:           current chain ID
verifyingContract: ERC-20 sale adapter address
```

Their distinct struct type hashes separate the payloads. Use
`paymentIntentDigest(intent)` for payer signing; the pinned intent type hash
is `0x72c99e6f6f9e2422510a5dd5c2dc2f9ffd83c776670a8de4ffab990e45f825cd`.

Construct one purchase from public reads:

```solidity
IStreamERC20FixedPriceSaleAdapter.SaleRecord memory record =
    adapter.saleRecord(saleId);
IStreamERC20FixedPriceSaleAdapter.SaleAuthorization memory authorization =
    IStreamERC20FixedPriceSaleAdapter.SaleAuthorization({
        saleId: saleId,
        saleConfigHash: record.configHash,
        payer: payer,
        recipient: recipient,
        artist: acceptedArtist,
        tokenDataHash: keccak256(tokenData),
        mintCommitment: mintCommitment,
        nonce: artistNonce,
        deadline: deadline,
        signerEpoch: adapter.signerEpoch()
    });
IStreamPaymentIntentVerifier.PaymentIntent memory intent =
    IStreamPaymentIntentVerifier.PaymentIntent({
        payer: payer,
        asset: record.config.asset,
        maxAmount: record.config.price,
        saleRef: saleId,
        expectedPrimaryPolicyHash: record.config.expectedPrimaryPolicyHash,
        nonce: payerNonce,
        deadline: deadline
    });
// Obtain platformSignature and artistSignature over adapter.authorizationDigest(authorization).
// Obtain payerSignature over IStreamPaymentIntentVerifier(address(adapter)).paymentIntentDigest(intent).
(uint256 tokenId, bytes32 operationRoot) = adapter.buy(
    authorization, tokenData, platformSignature, artistSignature, intent, payerSignature
);
```

When the payer directly calls `buy`, an empty `payerSignature` selects the
literal caller exemption. The intent argument is then unused; the commercial
authorization, registered price, artist approval and allowance still apply.
A forwarding contract or relayer cannot use that exemption on behalf of an
EOA. It must supply the payer's signature. No `tx.origin`, forwarded sender,
caller allowlist, Permit2 or EIP-2612 shortcut is supported.

## Replay, revocation and receipts

`isPaymentIntentNonceUsed(payer, nonce)` reports both consumed and revoked
nonces. Consumption is recorded before the first token transfer and rolls
back if the transaction fails. The same nonce value is independent for two
different payers.

The payer can call `revokePaymentIntent(nonce)` directly. For a relayed
revocation, sign:

```text
StreamPaymentIntentRevocation(address payer,bytes32 nonce,uint64 deadline)
```

Use `paymentIntentRevocationDigest(payer, nonce, deadline)`, then submit
`revokePaymentIntentBySignature(payer, nonce, deadline, signature)`. Its pinned
type hash is `0x3a5991afab010b2aa3f78362da982cf536e46d406a9e205c1f27b0f0e4c42e50`.
The deadline only limits relay time: an accepted revocation never expires.

Filter logs by the configured adapter address. `PaymentIntentConsumed`
identifies the payer, sale and nonce, with schema version, asset and actual
amount. Direct-caller purchases do not emit that event.
`ERC20SaleSettled` identifies the sale, mint root, token ID, commercial
authorization, profile, wallet, asset and amount; `ERC20SaleParticipants`
records artist, payer, recipient and primary policy. Confirm Core ownership
and manager replay state using those IDs. Entropy and metadata then follow
the [current entropy and metadata flow](metadata-rendering.md).

`proceeds(profileId, asset)` and `totalProceeds(asset)` count this adapter's
successful payments only. Donations do not create sale credit. Recipients
withdraw from the split wallet with `release(asset, account, recipient)`;
third parties may release only to the entitled account itself. See
[payments and withdrawals](withdrawals-and-credits.md).

## Supported boundary

This path supports standard, ACTIVE ERC-20s with canonical 32-byte balance
and boolean transfer responses, fixed-profile collection/default assignments,
strict primary-policy matching and one NFT per authorization. Taxed, rebasing,
no-op, malformed-return and unsupported tokens revert on exact balance checks.
Templates, token-specific primary overrides, deferred escrow and permits are
not implemented here. The older unprotected primary-settlement adapter is not
installed by this current path.

Canonical EOA signatures and bounded ERC-1271 are supported. A delegated EOA
retains its own-key ECDSA route when an EIP-7702 designation is observed.
Contract verification starts with a 400,000-gas stipend; the adapter owner,
normally the delayed Executor, can only raise it. This adapter-local setting
is not the factory-wide governed parameter store specified for the complete
revenue protocol, and the test wallet is not certification of every supported
production wallet class.

Issue #664 remains open for those broader conformance and release obligations;
issue #694's universal settlement/escrow identity remains separate. The
working current-stack purchase path does not establish production readiness.
