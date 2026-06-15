# Contract Flows

This document is the integration flow spec for fixed-price minting through
`StreamDrops.mintDrop`. It is a pre-audit local baseline, not production-ready,
and not a security claim. Local evidence does not replace fork/testnet/live
evidence for public beta or production.

Use this with the integration source-of-truth entrypoint in
[`docs/integrations/README.md`](README.md), the signing guide in
[`docs/drop-authorization-signing.md`](../drop-authorization-signing.md), and
the release-readiness dashboard in
[`docs/release-readiness.md`](../release-readiness.md). The flow below
describes the current fixed-price path only; auction-specific UX remains
future `INT-003` work.

## Maturity And Scope

This page is for React, mobile, Electron, indexer, operator UI, and backend
signing service teams that need to execute or observe a fixed-price mint
without guessing from Solidity tests.

It covers:

- artifact and address inputs;
- preflight reads before asking for a signature or transaction;
- `DropAuthorization` payload construction for `saleMode = 1`;
- EIP-712 EOA signing and ERC-1271 contract-signer handling;
- `mintDrop(DropAuthorization,string,bytes)` transaction submission;
- events and post-transaction reads;
- poster/protocol credit withdrawal UX;
- curator reserve accounting;
- common negative states and user-facing handling.

It does not provide a production signing service, production signer custody,
marketplace proof, public-beta approval, or live deployment evidence. Those
remain governed by
[`docs/signer-custody-readiness.md`](../signer-custody-readiness.md),
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md), and
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json).

## Fixed-Price Mint Overview

The fixed-price path is:

1. Load the target network's `StreamDrops` address and ABI surface from tracked
   release artifacts.
2. Read the deployed `StreamDrops` domain, current signer, `signerEpoch`, pause
   status, and payment-recipient configuration.
3. Build no-secret unsigned EIP-712 typed data for `DropAuthorization`.
4. Ask the backend signing service or approved signer to sign the digest.
5. Submit `StreamDrops.mintDrop` with the exact `DropAuthorization`,
   `tokenData`, signature bytes, and `msg.value == price`.
6. Observe `DropAuthorizationConsumed`, mint/transfer events, and
   `FixedPriceCreditCreated` events.
7. Read consumed/drop/token/payment state and show any poster or protocol
   withdrawable credits.

`StreamDrops` validates authorization before execution, writes
`consumedDropIds[dropId] = true`, emits `DropAuthorizationConsumed`, mints via
the configured minter, and records payment credits if `price` is non-zero.

## Source Of Truth

Use these committed sources before wiring an app:

| Need | Source |
| --- | --- |
| Integration index | [`docs/integrations/README.md`](README.md) |
| Signing schema and fixtures | [`docs/drop-authorization-signing.md`](../drop-authorization-signing.md) |
| Signer custody boundary | [`docs/signer-custody-readiness.md`](../signer-custody-readiness.md) |
| Metadata and token state | [`docs/metadata.md`](../metadata.md) |
| Release readiness | [`docs/release-readiness.md`](../release-readiness.md) |
| Non-local evidence policy | [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) |
| Public-beta status | [`docs/public-beta-evidence.md`](../public-beta-evidence.md) |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) |
| Release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) |
| ABI compatibility baseline | [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json) |
| ABI checksums | [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) |
| Local address book | [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json) |
| Retained fork address book | [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) |
| Contract implementation | [`smart-contracts/StreamDrops.sol`](../../smart-contracts/StreamDrops.sol) |
| Fixed-price payment tests | [`test/StreamFixedPricePayments.t.sol`](../../test/StreamFixedPricePayments.t.sol) |
| EIP-712 tests | [`test/StreamDropsEIP712.t.sol`](../../test/StreamDropsEIP712.t.sol) |
| ERC-1271 tests | [`test/StreamDropsERC1271.t.sol`](../../test/StreamDropsERC1271.t.sol) |
| Fixed-price EOA fixture | [`test/fixtures/drop-authorization/fixed-price-eoa.json`](../../test/fixtures/drop-authorization/fixed-price-eoa.json) |
| ERC-1271 fixture | [`test/fixtures/drop-authorization/erc1271-contract-signer.json`](../../test/fixtures/drop-authorization/erc1271-contract-signer.json) |
| Unsigned fixed-price payload | [`test/fixtures/drop-authorization/payload-generator/fixed-price-output.json`](../../test/fixtures/drop-authorization/payload-generator/fixed-price-output.json) |
| Payload generator | [`scripts/generate_drop_authorization_payload.py`](../../scripts/generate_drop_authorization_payload.py) |

Raw ABIs are generated under ignored `out/` after `forge build`. Do not copy
ABI JSON by hand into frontend repositories without also checking the tracked
ABI compatibility baseline and ABI checksums.

## Artifact Inputs

An app needs these inputs for a fixed-price mint:

- chain ID from the connected wallet/provider;
- `StreamDrops` address from the selected address book;
- `StreamDrops` ABI from a local `forge build` output or generated package;
- event topics from `event-topic-catalog.json`;
- `DropAuthorization` typed-data schema from the signing guide or generated
  payload fixture;
- token metadata expectations from `docs/metadata.md`;
- current readiness state from release-readiness and public-beta evidence docs.

If the connected chain does not match the signed EIP-712 domain, stop before
requesting a transaction. A wrong chain or wrong domain must be shown as an
operator/configuration error, not as a wallet retry prompt.

## Preflight Reads

Before asking for a signature or transaction, read:

| Read | Why |
| --- | --- |
| `domainSeparator()` | Confirms current EIP-712 domain for chain ID and verifying contract |
| `tdhSigner()` | Identifies the active EOA or ERC-1271 signer |
| `signerEpoch()` | Binds the signature to the current signer epoch |
| `adminsContract()` then `isPaused(DROP_EXECUTION)` | Blocks UI submission while drop execution is paused |
| `payOutAddress()` | Identifies the protocol credit recipient |
| `curatorsPoolAddress()` | Identifies the curator reserve account |
| `isDropConsumed(dropId)` | Rejects replayed or already executed payloads |
| `isDropCancelled(dropId)` | Rejects cancelled payloads |
| `fixedPricePosterCredits(poster)` | Shows existing poster withdrawable credit |
| `fixedPriceProtocolCredits(payOutAddress)` | Shows existing protocol withdrawable credit |
| `fixedPriceCuratorReserveCredits(curatorsPoolAddress)` | Shows reserved curator funds, not direct withdrawal UX |
| `totalFixedPriceOwed()`, `totalReserved()`, `surplus()` | Lets operator views reconcile owed funds and emergency-withdrawable surplus |

The pause domain name in code is `StreamPauseDomains.DROP_EXECUTION`. The app
should present a paused drop as unavailable, while keeping withdrawal UI
available unless a future incident runbook says otherwise.

For the safest preflight, also run an `eth_call` simulation of `mintDrop` with
the exact payer, `msg.value`, authorization, token data, and signature. This
eth_call simulation should use the same sender and value planned for the real
transaction. Simple reads do not prove ERC-721 receiver hooks, token-data
length limits, downstream `StreamMinter` phase and supply checks, `StreamCore`
freeze checks, or configured randomizer behavior.

## Authorization Payload

Fixed-price mints use `saleMode = 1`. The `DropAuthorization` message must
include:

- `dropId = deriveDropId(signer, signerEpoch, nonce, salt)`;
- `poster` as the poster credited for the drop;
- non-zero `recipient` as the minted NFT receiver;
- `payer = msg.sender` when `price > 0`;
- `payer = address(0)` when `price == 0`;
- target `collectionId`;
- `tokenDataHash = keccak256(bytes(tokenData))`;
- exact `price`;
- `quantity = 1`;
- `auctionReservePrice = 0`;
- `auctionEndTime = 0`;
- unique signer-scoped `nonce` and `salt`;
- `deadline` after the latest acceptable execution time;
- current `signerEpoch`.

The backend signing service should construct or verify the typed data from a
no-secret request, then return only the signature and any public verification
metadata. Frontend code must never handle private keys, mnemonics, HSM secrets,
or production signing credentials.

## Signing Paths

For EOA signers, `StreamDrops` recovers the signer from the EIP-712 digest and
accepts 65-byte signatures or EIP-2098 compact 64-byte signatures. High-s,
invalid-v, zero-signer, malformed length, wrong signer, wrong domain, and token
data substitution fail closed.

For ERC-1271 contract signers, `StreamDrops` calls
`isValidSignature(bytes32 digest, bytes signature)`. The call must succeed,
return exactly 32 bytes, and decode to `0x1626ba7e`. Invalid magic, empty
return, short return, extra return, revert, wrong digest, and wrong signature
bytes fail closed.

Replay protection is storage-backed. EIP-712 is the encoding/signing layer;
`consumedDropIds`, `cancelledDropIds`, `signerEpoch`, nonce/salt allocation,
and `deadline` are the replay and revocation controls.

## Submit Transaction

Submit:

```solidity
StreamDrops.mintDrop{value: authorization.price}(
    authorization,
    tokenData,
    signature
)
```

The transaction sender must equal `authorization.payer` when `price > 0`. For
a free fixed-price mint, `authorization.payer` must be zero and `msg.value`
must be zero.

The app should treat `mintDrop` as a single atomic operation. If downstream
minting reverts, the Solidity tests assert the drop remains unconsumed and no
payment credits remain.

## Events And Indexing

Indexers should watch:

- `DropAuthorizationConsumed` for `dropId`, signer, poster, recipient, payer,
  collection ID, sale mode, token data hash, deadline, and signer epoch;
- ERC-721 transfer/mint events from the core token contract;
- `FixedPriceCreditCreated` for poster, protocol, and curator reserve
  accounting;
- `FixedPriceCreditWithdrawn` for poster and protocol credit withdrawals;
- `DropAuthorizationCancelled`, `SignerEpochChanged`, and `DropSignerChanged`
  for invalidating pending payloads.

Use `retrieveTokenID(dropId)`, `retrieveDropInfo(dropId)`,
`retrieveDropID(tokenId)`, and `retrieveExecutionAddress(tokenId)` to reconcile
post-transaction state. Metadata may still be pending after mint; do not assume
an ERC-4906 final metadata update happened at mint time.

## Credits And Withdrawals

Paid fixed-price mint proceeds are credited as:

- poster credit: `msg.value / 2`;
- curator reserve credit: `msg.value / 4`;
- protocol credit: `msg.value - posterCredit - curatorReserveCredit`.

These ratios are pinned by
`testFixedPriceMintCreditsProceedsWithoutPushPayouts`,
`testFixedPriceOddWeiRemainderAccruesToProtocolCredit`, and
`testOneWeiFixedPriceRemainderCreditsOnlyProtocol` in
[`test/StreamFixedPricePayments.t.sol`](../../test/StreamFixedPricePayments.t.sol).

Poster and protocol recipients use `withdrawFixedPriceCredit()` or
`withdrawFixedPriceCreditTo(recipient)` for withdrawable credits.
`FixedPriceCreditWithdrawn` is emitted for each withdrawn credit category.
Failed withdrawals preserve credit and owed totals because the state reset is
reverted with the failed ETH transfer.

Curator reserve accounting is different. `fixedPriceCuratorReserveCredits` and
`totalFixedPriceCuratorReserveOwed` keep curator reserve funds included in
`totalFixedPriceOwed()`, `totalReserved()`, and `totalOwed()`, but the current
fixed-price withdrawal function does not directly withdraw curator reserve
credit. UI should show curator reserve as reserved/owed protocol accounting,
not as an immediate user withdrawal button.

Forced ETH only increases `surplus()` and `emergencyWithdrawable()`. Emergency
flows must not withdraw owed poster, protocol, or curator reserve funds.

## Failure States

A product UI should classify these states before or after submission:

| State | Likely handling |
| --- | --- |
| Wrong chain or wrong domain | Stop; ask user to switch network or operator to regenerate payload |
| `DROP_EXECUTION` paused | Stop minting; keep credit withdrawal views available |
| Expired deadline | Request a new authorization |
| Consumed drop ID or replay | Show already executed; read token and drop state |
| Cancelled drop ID | Show cancelled by admin/signer workflow |
| Wrong signer or stale `signerEpoch` | Request a new payload from the signing service |
| Zero recipient | Treat as invalid fixed-price payload |
| Token data hash mismatch | Treat as payload tampering or stale metadata |
| `msg.value != price` or insufficient payment | Ask user to resubmit with the exact signed price |
| Non-zero auction fields | Treat as wrong sale mode payload |
| Failed downstream mint | Do not mark executed; re-read `isDropConsumed` and payment credits |
| Failed withdrawal | Credit is preserved; let the recipient retry or withdraw to another address |
| ERC-1271 validation failure | Ask the contract signer operator to verify digest/signature support |

Do not auto-retry with mutated fields. Any payload field change requires a new
signature, and any signer compromise path should use signer epoch rotation,
drop cancellation, or drop-execution pause before new signatures are issued.

## Frontend State Machine

Suggested UI states:

1. `unconfigured`: no supported address book or chain config.
2. `wrong-chain`: wallet chain does not match the payload domain.
3. `preflight-loading`: reading signer, epoch, pause, consumed/cancelled, and
   credit state.
4. `needs-authorization`: no current signature or stale signature.
5. `ready-to-submit`: payload, token data, signature, payer, and value match.
6. `submitted`: transaction hash known, waiting for confirmation.
7. `minted-pending-metadata`: mint confirmed, metadata may still be pending.
8. `credits-available`: poster or protocol credit can be withdrawn.
9. `failed-retryable`: failed withdrawal, wallet rejection, or network error.
10. `failed-terminal`: cancelled, consumed, expired, wrong signer, or invalid
    payload.

Use an indexer for history, but re-read the contract directly for critical
execution and credit state before submitting transactions.

## Backend Signing Service Boundary

The backend signing service should:

- allocate nonce/salt pairs per signer and signer epoch;
- verify collection, poster, recipient, price, payer, deadline, and token data
  hash against the approved drop record;
- produce or approve EIP-712 typed data;
- sign with the active EOA signer or coordinate ERC-1271 signer state;
- return signature bytes and public verification metadata only;
- retain signing evidence through the drop authorization signing evidence
  process.

The frontend should:

- request unsigned intent data without secrets;
- display chain, collection, recipient, price, and deadline before transaction
  submission;
- enforce no private keys in browser, mobile, Electron, logs, support tickets,
  or committed fixtures;
- never ask users or operators to paste private keys;
- never mutate signed fields locally after a signature is issued;
- surface signer-epoch, cancellation, and pause failures as operator states.

## Validation Commands

Run these when editing this flow:

```sh
python scripts/test_contract_flows.py
python scripts/check_contract_flows.py
python scripts/check_integrations_readme.py
python scripts/check_release_readiness.py
python scripts/check_changelog.py
```

If release-manifest-tracked docs or scripts changed, also run the relevant
release manifest and checksum drift checks.

## Maintenance

Update this spec when:

- `StreamDrops.DropAuthorization` fields change;
- `mintDrop` validation, payment accounting, or events change;
- signer custody, ERC-1271, or payload generator behavior changes;
- address-book, ABI, event-topic, or release-manifest artifact names move;
- future INT-003/INT-004 docs split auction or wallet guidance into more
  specific flow pages.
