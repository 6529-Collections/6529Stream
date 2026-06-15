# Wallets And Signatures

This document is the integration guide for wallet, EIP-712, ERC-1271, Safe,
WalletConnect, and backend signing-service handling around
`StreamDrops.DropAuthorization`. It is a pre-audit local baseline, not
production-ready, and not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this with the raw signing schema in
[`docs/drop-authorization-signing.md`](../drop-authorization-signing.md), the
signer custody readiness model in
[`docs/signer-custody-readiness.md`](../signer-custody-readiness.md), the
fixed-price flow in [`docs/integrations/contract-flows.md`](contract-flows.md),
the auction flow in [`docs/integrations/auction-flows.md`](auction-flows.md),
and the release-readiness dashboard in
[`docs/release-readiness.md`](../release-readiness.md).

## Maturity And Scope

This guide is for React, mobile, Electron, operator UI, indexer, and backend
signing service teams that need to build or verify wallet-facing signature
flows without guessing from Solidity tests.

It covers:

- EIP-712 domain and typed-data shape for `DropAuthorization`;
- replay, expiry, cancellation, and signer epoch boundaries;
- EOA signatures, including 65-byte and EIP-2098 compact signatures;
- ERC-1271 contract-signer behavior;
- Safe signing and validation expectations;
- WalletConnect and mobile handoff caveats;
- backend signing-service and production custody boundaries;
- frontend preflight reads and user-visible failure handling; and
- no-secret validation commands and source-of-truth artifacts.

It does not provide a production signing service, custody approval, live Safe
configuration, public-beta approval, audited signature UX, or production
deployment evidence. Those remain governed by
[`docs/signer-custody-readiness.md`](../signer-custody-readiness.md),
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md),
[`docs/public-beta-evidence.md`](../public-beta-evidence.md), and
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json).

## Source Of Truth

Use tracked committed sources before wiring a wallet or signing service.

| Need | Source of truth | Integration note |
| --- | --- | --- |
| Integration entrypoint | [`docs/integrations/README.md`](README.md) | Starts frontend, mobile, Electron, indexer, operator UI, and signing-service discovery |
| Raw signing guide | [`docs/drop-authorization-signing.md`](../drop-authorization-signing.md) | Canonical schema, fixtures, evidence template, and operator flow |
| Drop authorization ADR | [`docs/adr/0001-drop-authorization.md`](../adr/0001-drop-authorization.md) | Accepted design decision for typed authorization, replay, cancellation, ERC-1271, and signer epoch |
| Signer custody evidence | [`docs/signer-custody-readiness.md`](../signer-custody-readiness.md) | Production signer custody evidence model |
| Fixed-price transaction flow | [`docs/integrations/contract-flows.md`](contract-flows.md) | `saleMode = 1`, payer/value, recipient, credit, and failure-state guidance |
| Auction transaction flow | [`docs/integrations/auction-flows.md`](auction-flows.md) | `saleMode = 2`, zero payer/recipient/price, auction custody, bid, and settlement guidance |
| Release readiness | [`docs/release-readiness.md`](../release-readiness.md) | Current launch blocker dashboard |
| Non-local evidence policy | [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) | Retained fork/testnet/live evidence requirements |
| Public beta evidence | [`docs/public-beta-evidence.md`](../public-beta-evidence.md) | Public beta evidence posture |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) | Generated blocker and risk source |
| Release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) | Generated source-of-truth manifest |
| ABI review surface | [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json) | Tracked ABI baseline |
| ABI checksums | [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) | Integrator checksum source |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) | Indexer event signature source |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) | Interface lookup source |
| Local address book | [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json) | Local development addresses |
| Fork-mainnet address book | [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Retained fork rehearsal addresses |
| Contract implementation | [`smart-contracts/StreamDrops.sol`](../../smart-contracts/StreamDrops.sol) | Domain separator, digest, signer validation, replay, and sale validation |
| Admin and signer manager | [`smart-contracts/StreamAdmins.sol`](../../smart-contracts/StreamAdmins.sol) | Signer lifecycle and permission target reference |
| EIP-712 tests | [`test/StreamDropsEIP712.t.sol`](../../test/StreamDropsEIP712.t.sol) | EOA, wrong domain, wrong chain, expiry, replay, cancellation, epoch, malformed, and sale-field tests |
| ERC-1271 tests | [`test/StreamDropsERC1271.t.sol`](../../test/StreamDropsERC1271.t.sol) | Contract-signer success and fail-closed tests |
| Test helper | [`test/helpers/DropAuthTestHelper.sol`](../../test/helpers/DropAuthTestHelper.sol) | Digest/signature helpers and local signer keys |
| Fixed-price EOA fixture | [`test/fixtures/drop-authorization/fixed-price-eoa.json`](../../test/fixtures/drop-authorization/fixed-price-eoa.json) | Local signed fixed-price example |
| Auction EOA fixture | [`test/fixtures/drop-authorization/auction-eoa.json`](../../test/fixtures/drop-authorization/auction-eoa.json) | Local signed auction example |
| ERC-1271 fixture | [`test/fixtures/drop-authorization/erc1271-contract-signer.json`](../../test/fixtures/drop-authorization/erc1271-contract-signer.json) | Local contract-signer example |
| Unsigned fixed-price payload | [`test/fixtures/drop-authorization/payload-generator/fixed-price-output.json`](../../test/fixtures/drop-authorization/payload-generator/fixed-price-output.json) | Deterministic unsigned typed-data output |
| Unsigned auction payload | [`test/fixtures/drop-authorization/payload-generator/auction-output.json`](../../test/fixtures/drop-authorization/payload-generator/auction-output.json) | Deterministic unsigned typed-data output |
| Payload generator | [`scripts/generate_drop_authorization_payload.py`](../../scripts/generate_drop_authorization_payload.py) | No-secret typed-data payload generator |
| Fixture checker | [`scripts/check_drop_authorization_fixtures.py`](../../scripts/check_drop_authorization_fixtures.py) | Canonical domain/type/fixture validation |
| Signing evidence checker | [`scripts/check_drop_authorization_signing_evidence.py`](../../scripts/check_drop_authorization_signing_evidence.py) | Retained evidence validation |
| Signer custody checker | [`scripts/check_signer_custody_readiness.py`](../../scripts/check_signer_custody_readiness.py) | Signer custody readiness validation |

Raw ABIs are generated under ignored `out/` after `forge build`. Do not copy
ABI JSON by hand into frontend repositories without checking the ABI baseline,
ABI checksums, release manifest, and selected deployment address book.

## Domain And Typed Data

`StreamDrops` uses this EIP-712 domain:

```text
EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
```

The current domain fields are:

| Field | Required behavior |
| --- | --- |
| `name` | `6529StreamDrops` |
| `version` | `1` |
| `chainId` | The chain ID where the target `StreamDrops` contract is deployed |
| `verifyingContract` | The deployed `StreamDrops` address for the selected deployment |

The signed primary type is:

```text
DropAuthorization(
  bytes32 dropId,
  address poster,
  address recipient,
  address payer,
  uint256 collectionId,
  uint8 saleMode,
  bytes32 tokenDataHash,
  uint256 price,
  uint256 quantity,
  uint256 auctionReservePrice,
  uint256 auctionEndTime,
  uint256 salt,
  uint256 nonce,
  uint256 deadline,
  uint256 signerEpoch
)
```

`DROP_AUTHORIZATION_TYPEHASH` covers the payload above. `DROP_ID_TYPEHASH`
covers:

```text
DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)
```

`dropId` must equal `deriveDropId(signer, signerEpoch, nonce, salt)`.
`tokenDataHash` must equal `keccak256(bytes(tokenData))`. App teams should
display or log hashes, not raw unreleased art payloads, unless the release or
drop process explicitly allows that payload to be public.

EIP-712 is encoding/signing only. Replay protection requires domain
separation, storage-backed `consumedDropIds`, storage-backed
`cancelledDropIds`, signer-service-allocated `nonce` and `salt`, `deadline`,
current `signerEpoch`, signer rotation policy, and the on-chain consumed-state
write before mint or auction execution. There is no separate on-chain monotonic
nonce map; uniqueness is a signer-service obligation and is
enforced on chain through the derived `dropId` plus consumed/cancelled storage.

## Replay And Revocation Controls

The app must model these controls as separate state, not as one generic
"signature failed" bucket:

| Control | Contract/source behavior | Product handling |
| --- | --- | --- |
| Domain | `domainSeparator()` includes `name`, `version`, `chainId`, and `verifyingContract` | Stop on wrong chain or wrong contract before asking for a transaction |
| `dropId` | Derived from signer, signer epoch, nonce, and salt | Treat mismatch as payload construction failure |
| `nonce` / `salt` | Signer-service allocated; no on-chain monotonic nonce map exists | Track uniqueness per signer epoch in the signing service |
| Consumed storage | `consumedDropIds[dropId]` is written before sale execution | Show replayed or already executed; re-read token/drop state |
| Cancelled storage | `cancelledDropIds[dropId]` blocks later execution | Show cancelled by operator workflow |
| Signer epoch | `signerEpoch` must equal current contract state | Request a new payload after signer rotation or compromise response |
| Deadline | `deadline >= block.timestamp` is required | Request a fresh authorization after expiry |
| Token-data hash | Exact `tokenData` bytes must hash to `tokenDataHash` | Treat mismatch as stale or tampered metadata |

Operators should use per-drop cancellation for a single bad payload and signer
epoch rotation for signer compromise, signer migration, or broad invalidation.
If the drop surface itself is unsafe, use drop-execution pause before issuing
new signatures.

## EOA Wallet Flow

EOA signing is a backend/operator action in the current model. The frontend or
mobile app normally receives a signed `DropAuthorization`; it should not hold
the production signer key.

For an EOA signer:

1. The signing service builds or verifies typed data under the current domain.
2. The service signs the digest with the active `tdhSigner`.
3. The app submits the exact authorization, exact `tokenData`, signature bytes,
   sender, and value expected by the sale mode.
4. `StreamDrops` recovers the signer from the EIP-712 digest.
5. 65-byte EOA signatures and EIP-2098 compact 64-byte signatures are
   accepted.

EOA signatures fail closed for wrong signer, wrong domain, wrong chain,
expired deadline, replayed drop, cancelled drop, stale signer epoch, bad
drop ID, token data substitution, high-s malleable signature, invalid `v`,
zero recovered signer, and malformed signature length.

Wallet UIs should not offer "try again with edited fields." Any mutation to
`poster`, `recipient`, `payer`, `collectionId`, `saleMode`, `tokenDataHash`,
`price`, `quantity`, `auctionReservePrice`, `auctionEndTime`, `salt`, `nonce`,
`deadline`, or `signerEpoch` requires a fresh signature.

## ERC-1271 Contract Signer Flow

If the active `tdhSigner` is a contract, `StreamDrops` does not recover an EOA.
It calls:

```solidity
isValidSignature(bytes32 digest, bytes signature)
```

The call must:

- succeed;
- return exactly 32 bytes; and
- decode to the ERC-1271 magic value `0x1626ba7e`.

Invalid magic, empty return, short return, extra return, reverted validation,
wrong digest, wrong signature bytes, expired authorization, and replayed
authorization fail closed with no consumed-state rollback issue.

The ERC-1271 path uses the same EIP-712 digest and replay controls as the EOA
path. Smart wallet support is therefore not an alternative schema. It is a
different signer-validation path for the same `DropAuthorization` digest.

## Safe Signing Flow

Treat Safe signing as an ERC-1271 contract-signer integration until production
evidence proves a different signer model.

A Safe-based signing setup should define:

- the Safe address that will be the active `tdhSigner`;
- Safe network and chain ID;
- owner threshold and signer approval workflow;
- whether the Safe signs the EIP-712 typed data digest directly or validates a
  pre-approved message under its own message flow;
- how the returned `signature` bytes are constructed for
  `isValidSignature(bytes32,bytes)`;
- signer manager and signer epoch rotation authority;
- per-drop cancellation authority and procedure;
- retained evidence for digest, typed data, Safe transaction/message URL or
  redacted reference, reviewer approval, and validation output.

Before using Safe in public beta or production, retain signer custody
readiness evidence showing ERC-1271 status as `supported` or explicitly
documented otherwise. A frontend should show Safe validation failures as
operator/configuration failures, not as ordinary user wallet rejections.

## WalletConnect And Mobile Handoff

WalletConnect and mobile wallets are user-transaction channels in this repo's
current integration model. They are not the production drop-signing key path
unless a future custody decision explicitly changes that.

For mobile and WalletConnect:

- bind the selected chain to the signed EIP-712 domain before transaction
  submission;
- show collection, sale mode, recipient, payer, price or reserve, deadline,
  and signer epoch before asking the user to submit;
- preserve the exact `DropAuthorization` object and `tokenData` across deep
  links and app resumes;
- re-read `isDropConsumed`, `isDropCancelled`, `signerEpoch`, pause status,
  and relevant payment or auction state after reconnects;
- handle wallet rejection, session expiry, chain switch, and RPC replacement
  as retryable transport states only if the signed payload is still current;
  and
- never store private keys, mnemonics, production signing credentials, raw
  HSM credentials, RPC secrets, or unreleased payload secrets in mobile logs,
  crash reports, analytics, local storage, clipboard helpers, or support
  tickets.

If a mobile wallet requests EIP-712 signing for a user action, that should be
for the user's own wallet flow. Do not confuse user transaction approval with
the protocol's approved drop signer.

## Backend Signing Service Boundary

The backend signing service owns payload construction and signer coordination.
It should:

- load the selected address book and `StreamDrops` verifying contract;
- read `tdhSigner`, `signerEpoch`, and any signer lifecycle policy;
- allocate unique signer-scoped `nonce` and `salt` values;
- compute `dropId = deriveDropId(signer, signerEpoch, nonce, salt)`;
- compute `tokenDataHash = keccak256(bytes(tokenData))`;
- enforce fixed-price and auction field contracts;
- enforce a bounded `deadline`;
- sign with the approved EOA signer or coordinate ERC-1271 contract signer
  state;
- retain no-secret signing evidence, reviewer approval, digest, typed-data
  hash, signature verification, signer identity, signer epoch, and custody
  references; and
- return only signature bytes and public verification metadata to the app.

Frontend, mobile, and Electron clients should:

- request unsigned intent data or already-approved signatures from the service;
- display meaningful payload fields before submission;
- reject chain/domain mismatch before asking for a transaction;
- keep signed fields immutable after signature issuance;
- run an `eth_call` simulation with the exact sender and value before a paid
  transaction when practical; and
- avoid private key handling entirely.

## Frontend Preflight Reads

Before enabling a mint or auction submit button, read or derive:

| Read | Why |
| --- | --- |
| Connected wallet `chainId` | Must match the EIP-712 domain |
| Selected `StreamDrops` address | Must match `verifyingContract` |
| `domainSeparator()` | Confirms the live domain derived by the contract |
| `tdhSigner()` | Confirms expected EOA or ERC-1271 signer |
| `signerEpoch()` | Rejects stale payloads after rotation |
| `isDropConsumed(dropId)` | Rejects replayed payloads |
| `isDropCancelled(dropId)` | Rejects cancelled payloads |
| Drop execution pause state | Blocks new drop execution while paused |
| Fixed-price or auction contract state | Confirms payer/value or auction custody assumptions |

For fixed-price payloads, additionally follow
[`docs/integrations/contract-flows.md`](contract-flows.md). For auction
payloads, additionally follow
[`docs/integrations/auction-flows.md`](auction-flows.md).

## Failure States

Use specific failure messages and recovery paths:

| Failure | Likely source | Handling |
| --- | --- | --- |
| Wrong domain | Wrong `name`, `version`, `chainId`, or `verifyingContract` | Stop and regenerate or switch network |
| Wrong signer | EOA recovery or ERC-1271 signer does not match `tdhSigner` | Request operator review and new payload |
| Expired deadline | `deadline` is stale | Request fresh authorization |
| Replayed payload | `consumedDropIds[dropId]` is true | Show already executed and re-read token/drop state |
| Cancelled drop | `cancelledDropIds[dropId]` is true | Show cancelled and stop |
| Stale epoch | Payload `signerEpoch` differs from contract state | Request fresh authorization |
| Malleable signature | EOA high-s or invalid `v` | Reject and alert signing service |
| Invalid signature length | Not 65-byte EOA or EIP-2098 64-byte compact signature | Reject before submission if possible |
| Zero recovered signer | ECDSA recovery returns zero | Reject and alert signing service |
| Unsupported contract signature | ERC-1271 call reverts or returns bad length/magic | Treat as signer-configuration failure |
| Wrong digest | ERC-1271 signer validates a different digest | Request signer operator review |
| Zero-address signer | `tdhSigner` should never be an unconfigured zero signer | Treat as deployment/configuration failure |
| Zero-address recipient | Invalid for fixed-price; required for auction | Apply sale-mode-specific handling |
| Non-zero auction recipient | Invalid auction payload | Request fresh authorization |
| Free fixed-price payer mismatch | `payer` must be zero when `price == 0` | Request fresh authorization |
| Paid payer mismatch | `payer` must equal `msg.sender` when `price > 0` | Ask correct payer wallet or request fresh authorization |
| Value mismatch | `msg.value` does not equal signed `price` or zero auction value | Rebuild transaction with exact value |
| Token data substitution | `tokenDataHash` mismatch | Treat as stale or tampered payload |
| Wallet rejection | User rejects transaction | Retry only if payload is still current |
| WalletConnect session expired | Transport disconnect | Reconnect and re-run preflight |

Do not collapse these into "signature failed." The recovery path is different
for user rejection, wrong network, stale epoch, signer compromise, cancelled
drop, and contract-signer misconfiguration.

## Security And UX Requirements

Minimum app requirements:

- show the target network, contract, collection, sale mode, recipient or auction
  zero-recipient rule, payer, price or reserve, deadline, and signer epoch;
- keep the typed-data payload immutable after signing;
- hash and compare token data before submission;
- simulate `mintDrop` with the exact sender and value where practical;
- re-read consumed/cancelled/epoch state after wallet reconnect or pending
  transaction replacement;
- never auto-retry with mutated fields;
- never ask a user or operator to paste a private key or mnemonic;
- document the policy as no private keys in client, support, analytics, logs,
  fixtures, or release evidence;
- keep production signer material out of browser, mobile, Electron renderer,
  logs, analytics, crash reports, and committed fixtures;
- mark Safe/ERC-1271 validation failures as operator-signing failures; and
- link to signer custody and incident response when signer compromise is
  suspected.

Electron apps should isolate renderer processes from signing-service secrets.
If an Electron shell is used, it should treat release artifacts, typed data, and
signatures as untrusted external input until validated, and should not expose
backend signing credentials to renderer JavaScript.

## Validation Commands

Run these when editing this guide:

```sh
python scripts/test_wallet_signature_flows.py
python scripts/check_wallet_signature_flows.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/check_changelog.py
python scripts/generate_release_manifest.py --check
python scripts/generate_bytecode_release_proof.py --check
python scripts/generate_release_checksums.py --check
forge test --match-path test/StreamDropsEIP712.t.sol
forge test --match-path test/StreamDropsERC1271.t.sol
```

If release-manifest-tracked docs or scripts changed, regenerate and check the
release manifest, bytecode proof, and checksum bundle.

## Maintenance

Update this guide when any of these change:

- `StreamDrops.DropAuthorization` fields;
- `EIP712_NAME`, `EIP712_VERSION`, `EIP712_DOMAIN_TYPEHASH`,
  `DROP_AUTHORIZATION_TYPEHASH`, or `DROP_ID_TYPEHASH`;
- `domainSeparator()`, `deriveDropId()`, or `hashDropAuthorization()`;
- EOA recovery rules, EIP-2098 support, malleability checks, or zero signer
  handling;
- ERC-1271 `isValidSignature` behavior;
- `tdhSigner`, `signerEpoch`, `consumedDropIds`, or `cancelledDropIds`
  semantics;
- signer custody readiness evidence;
- Safe signing policy;
- WalletConnect, mobile, or Electron guidance; or
- fixed-price or auction sale-field contracts.
