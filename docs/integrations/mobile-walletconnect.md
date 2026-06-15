# Mobile And WalletConnect Integration Guide

This is the INT-008 integration guide for mobile and WalletConnect clients that
consume 6529Stream release artifacts. It is a pre-audit local baseline, not
production-ready, and not a security claim. Local evidence does not replace
fork/testnet/live evidence for public beta or production use.

The guide is documentation-only. It does not add a React Native app, Expo app,
native mobile shell, WalletConnect package dependency, mobile SDK, generated
SDK, maintained frontend package, Electron shell, or production wallet
integration to this contracts repository.

## Maturity And Scope

Use this guide when building a mobile browser flow, native mobile shell, or
WalletConnect adapter for a 6529.io-style product surface that needs to mint,
submit auctions, bid, settle, withdraw credits, render metadata, and reconcile
indexer state against the current local release baseline.

Current scope:

- mobile browser and native mobile shell boundaries;
- WalletConnect pairing, session lifecycle, reconnect, and expiry handling;
- foreground wallet action and return-to-app handling;
- QR pairing, deep links, universal links, and app links;
- account changes, chain changes, wrong-network handling, and domain guards;
- EIP-712 typed-data prompts, ERC-1271/Safe boundaries, and transaction
  prompts;
- offline, background, and push-notification assumptions;
- metadata, event, and indexer refresh behavior; and
- no-secret telemetry, crash-report, support, and local-storage policy.

Current non-scope:

- a production-ready mobile app or public beta implementation;
- a WalletConnect version or package recommendation;
- a reviewed native secure-storage design;
- a production signing service or signer custody approval;
- live marketplace, live indexer, or live push-notification evidence; and
- Electron renderer/main-process security guidance beyond explicit INT-009
  boundaries.

## Source Of Truth

Start from the integration entrypoint and release evidence before writing
mobile code:

- [docs/integrations/README.md](README.md)
- [docs/integrations/contract-flows.md](contract-flows.md)
- [docs/integrations/auction-flows.md](auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](wallets-and-signatures.md)
- [docs/integrations/events-and-indexing.md](events-and-indexing.md)
- [docs/integrations/metadata-rendering.md](metadata-rendering.md)
- [docs/integrations/frontend-reference-architecture.md](frontend-reference-architecture.md)
- [docs/integrations/examples/react-viem.md](examples/react-viem.md)
- [docs/drop-authorization-signing.md](../drop-authorization-signing.md)
- [docs/signer-custody-readiness.md](../signer-custody-readiness.md)
- [docs/release-readiness.md](../release-readiness.md)
- [docs/non-local-release-evidence.md](../non-local-release-evidence.md)
- [docs/public-beta-evidence.md](../public-beta-evidence.md)
- [docs/architecture.md](../architecture.md)
- [docs/threat-model.md](../threat-model.md)
- [docs/deployment.md](../deployment.md)
- [docs/release-policy.md](../release-policy.md)
- [release-artifacts/README.md](../../release-artifacts/README.md)
- [release-artifacts/latest/release-manifest.json](../../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/abi-checksums.json](../../release-artifacts/latest/abi-checksums.json)
- [release-artifacts/latest/event-topic-catalog.json](../../release-artifacts/latest/event-topic-catalog.json)
- [release-artifacts/latest/interface-ids.json](../../release-artifacts/latest/interface-ids.json)
- [release-artifacts/latest/release-checksums.json](../../release-artifacts/latest/release-checksums.json)
- [release-artifacts/latest/SHA256SUMS](../../release-artifacts/latest/SHA256SUMS)
- [release-artifacts/latest/bytecode-release-proof.json](../../release-artifacts/latest/bytecode-release-proof.json)
- [release-artifacts/latest/risk-register.json](../../release-artifacts/latest/risk-register.json)
- [release-artifacts/latest/public-beta-evidence.json](../../release-artifacts/latest/public-beta-evidence.json)
- [deployments/schema/deployment-manifest.schema.json](../../deployments/schema/deployment-manifest.schema.json)
- [deployments/schema/address-book.schema.json](../../deployments/schema/address-book.schema.json)
- [deployments/config/sepolia-6529stream-v0.1.0-001.template.json](../../deployments/config/sepolia-6529stream-v0.1.0-001.template.json)
- [deployments/address-books/anvil-6529stream-v0.1.0-001.json](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json)
- [deployments/examples/anvil-6529stream-v0.1.0-001.json](../../deployments/examples/anvil-6529stream-v0.1.0-001.json)
- [deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json](../../deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json)

Raw ABI JSON is generated under ignored `out/` after `forge build`. Mobile
apps should consume a reviewed artifact bundle, address book, deployment
manifest, release manifest, ABI checksum, event topic catalog, interface IDs,
release checksums, bytecode-to-release proof, risk register, and public-beta
evidence status for the target environment. Do not copy ABI fragments or
contract addresses by hand.

## Non-Goals

This guide is not a mobile SDK commitment and does not define a supported
mobile framework matrix.

This PR intentionally does not:

- add React Native, Expo, Swift, Kotlin, WalletConnect, wagmi, viem, TanStack
  Query, or Electron dependencies;
- publish generated mobile bindings;
- add a QR-code or deep-linking library;
- commit production RPC, WalletConnect project IDs, push credentials, or mobile
  analytics credentials;
- create a mobile reference app;
- claim public beta, production, live wallet, live marketplace, or live indexer
  readiness.

## Mobile Architecture Boundaries

A mobile integration should keep these layers separate:

| Layer | Responsibility | Mobile boundary |
| --- | --- | --- |
| Artifact loader | Loads release manifest, address book, ABI checksum, event topics, interface IDs, and deployment manifests | Public read-only data only |
| Network selector | Chooses chain ID, deployment version, RPC, indexer URL, confirmation depth, and explorer links | Public endpoints only unless server-mediated |
| Wallet session adapter | Tracks injected wallet, WalletConnect, native wallet, QR pairing, deep links, and active account | No private keys or seed phrases |
| Transaction orchestrator | Simulates, submits, waits for receipts, applies confirmation depth, and re-reads state | Foreground wallet action required |
| Signature preflight | Validates EIP-712 domain, signer epoch, consumed/cancelled state, and payload immutability | No production signer material |
| Local cache | Stores public artifacts, pending transaction IDs, metadata cache keys, and non-secret session state | No raw signatures, pairing URIs, or unreleased payloads |
| Indexer client | Reads event-derived state and latest indexed block | Eventually consistent |
| Metadata renderer | Renders tokenURI JSON, image URLs, and animation_url sandbox policy | Treat metadata as untrusted |
| Telemetry adapter | Records no-secret diagnostics and support IDs | Redact wallet session material |

The production drop signer is not a mobile client. WalletConnect and mobile
wallets are user transaction channels in this repo's current integration
model. Drop authorization signing remains a backend signing-service and signer
custody concern unless a future accepted decision explicitly changes that
boundary.

## WalletConnect Session Lifecycle

Mobile clients must treat WalletConnect as a transport/session layer, not as a
protocol authorization layer.

Required lifecycle states:

| State | Meaning | Required handling |
| --- | --- | --- |
| `unpaired` | No active WalletConnect pairing exists | Show connect action and supported wallets |
| `pairing_requested` | QR, deep link, or universal link was opened | Persist only non-secret request metadata |
| `session_pending` | Wallet is reviewing the session proposal | Show foreground wallet action required |
| `connected` | Session has accounts, chain IDs, and namespaces | Validate chain/account against selected release artifacts |
| `wrong_chain` | Connected chain does not match selected deployment | Halt signing and transactions before wallet prompts |
| `account_changed` | Active account differs from pending flow account | Re-run preflight and clear unsafe optimistic state |
| `session_expired` | Session TTL elapsed or wallet disconnected | Reconnect and re-run all domain/state guards |
| `session_rejected` | User rejected pairing or session proposal | Clear pending pairing state without mutating signed payloads |
| `transport_error` | Relay, RPC, or wallet bridge failed | Retry transport only after payload freshness checks |
| `reconnected` | Session recovered after app resume or network return | Re-read signer epoch, consumed/cancelled state, pause state, and transaction receipts |

Do not assume that a recovered WalletConnect session means a pending
transaction, signature, or typed-data payload is still valid. Reconnect is only
a transport event. The app must re-run contract and release-artifact preflight.

## Deep Link And Foreground Handoff

Mobile wallet actions normally leave the app foreground. The UI must assume
handoff and resume, not a synchronous browser modal.

Required behavior:

1. Before opening a wallet link, snapshot the non-secret flow state:
   `chainId`, deployment version, release manifest hash, address-book hash,
   contract address, function name, stable flow ID, drop ID or auction ID,
   expected wallet address, and payload hash.
2. Open the wallet through QR pairing, deep link, universal link, app link, or
   WalletConnect request.
3. Show a "wallet action required" state while the app is backgrounded or the
   wallet is foregrounded.
4. On resume, re-query the wallet session, active account, chain ID,
   transaction status, and receipt if a transaction hash exists.
5. Re-read `isDropConsumed`, `isDropCancelled`, `signerEpoch`, pause state,
   payment credits, auction state, metadata state, and indexer block height
   before showing final success.
6. If the wallet returns no transaction hash or signature result, treat the
   flow as unresolved and let the user retry only after preflight confirms the
   payload remains current.

Never store WalletConnect pairing URIs, session topics, symmetric keys, raw
signatures, unreleased drop payloads, private RPC credentials, or signer-service
credentials in crash reports, analytics, support bundles, screenshots, local
storage, clipboard helpers, or push payloads.

## Network Account And Domain Guards

Every mobile flow must halt before a wallet prompt when release-artifact or
domain state is inconsistent.

Pre-prompt guards:

- selected `chainId` equals the address book and deployment manifest chain ID;
- selected `StreamDrops` address equals the EIP-712 `verifyingContract`;
- domain name is `6529StreamDrops`;
- domain version is `1`;
- connected wallet chain ID equals the selected chain ID;
- connected wallet account equals the payer or bidder expected by the flow;
- `release-manifest.json`, address book, deployment manifest, ABI checksums,
  event topic catalog, interface IDs, release checksums, bytecode-to-release
  proof, risk register, and public-beta evidence are from the same artifact set;
- `tdhSigner` and `signerEpoch` match the signed payload;
- `isDropConsumed(dropId)` and `isDropCancelled(dropId)` are false;
- relevant mint, bid, settlement, and withdrawal pause states allow the action;
- the typed `tokenData` bytes hash to the signed `tokenDataHash`.

EIP-712 is encoding/signing only. Replay protection requires domain separation,
storage-backed `consumedDropIds`, storage-backed `cancelledDropIds`,
signer-service allocated `nonce` and `salt`, current `signerEpoch`, signer
rotation policy, `deadline`, and the on-chain consumed-state write before mint
or auction execution. WalletConnect does not provide replay protection.

## Typed Data And Transaction Flows

Mobile clients submit user transactions and may ask the connected user wallet
to sign user-scoped messages. They must not hold the protocol's production drop
signing key.

For fixed-price minting, follow
[docs/integrations/contract-flows.md](contract-flows.md):

- display collection, recipient, payer, price, quantity, deadline, signer
  epoch, and network;
- ensure the connected account is the payer when price is nonzero;
- set `msg.value` exactly to signed price for paid mints;
- use zero payer for free fixed-price drops when required by the flow; and
- re-read consumed drop and token state after the receipt.

For auction creation, bidding, settlement, and withdrawals, follow
[docs/integrations/auction-flows.md](auction-flows.md):

- submit auction drops with zero payer, zero recipient, zero price, and
  `msg.value == 0`;
- display reserve, auction end time, collection, drop ID, and signer epoch;
- keep highest-bid and bidder-credit views separate;
- treat outbid refunds as withdrawable credits, not direct wallet refunds;
- handle settlement and no-bid settlement as idempotent user flows; and
- re-read auction state and credit balances after receipt confirmation.

Wallet adapters should distinguish:

- user rejected pairing;
- user rejected signature;
- user rejected transaction;
- wallet timed out;
- wallet session expired;
- wrong chain;
- account changed;
- simulation failed;
- transaction reverted with decoded custom error;
- transaction replaced, dropped, or cancelled;
- indexer lag after receipt; and
- stale payload after reconnect.

Do not auto-retry by mutating signed fields. A different recipient, payer,
price, quantity, reserve, end time, token data, deadline, nonce, salt, or signer
epoch requires a fresh authorization.

## Offline Background And Reconnect Policy

Mobile apps are frequently suspended. Treat backgrounding, offline mode, and
push notifications as product and infrastructure assumptions, not contract
guarantees.

Required policy:

- A transaction is pending until receipt lookup and confirmation depth agree.
- A receipt is not final UI state until read-after-event reconciliation agrees.
- An indexer row is eventually consistent and may lag the receipt block.
- Reorg handling follows the confirmation depth and rescan guidance in
  [docs/integrations/events-and-indexing.md](events-and-indexing.md).
- Push notifications are hints only; they cannot mark mints, auctions,
  withdrawals, metadata, or credits final without RPC/indexer verification.
- Background refresh should avoid privileged RPCs in the client. Use public
  endpoints or server-mediated no-secret summaries.
- Offline cached metadata and auction views must show stale state when the
  latest confirmed block is unknown.
- On resume, re-run wallet session, account, chain, release artifact,
  transaction receipt, confirmation depth, and read-after-event checks.

If a mobile OS kills the app between wallet prompt and receipt handling, the
app should recover from the transaction hash, wallet session history, or
indexer/RPC state. Recovery must not require raw signatures, private keys,
WalletConnect pairing secrets, or unreleased payloads in local storage.

## Metadata Event And Indexer Refresh

Use [docs/integrations/metadata-rendering.md](metadata-rendering.md) and
[docs/integrations/events-and-indexing.md](events-and-indexing.md) for the
canonical cache and reconstruction model.

Mobile clients should:

- treat tokenURI JSON as untrusted input;
- cache metadata by chain ID, deployment version, release manifest hash,
  contract address, token ID, metadata state, schema version, and tokenURI hash;
- invalidate token views on `Transfer`, `TokenBurned`, `MetadataUpdate`, and
  `BatchMetadataUpdate`;
- invalidate collection views on `CollectionFrozen`;
- invalidate dependency-rendered output on `DependencyVersionPinned`,
  `DependencyVersionCreated`, and `DependencyVersionDeprecated`;
- show pending, stale, failed, final, frozen, and burned metadata states
  distinctly;
- sandbox animation_url rendering away from wallet/session state; and
- avoid loading untrusted animation content in a privileged native WebView.

If a mobile shell uses a native WebView for animation, that WebView must not
expose wallet bridges, signing APIs, privileged IPC, filesystem writes,
session exports, or local secret storage to untrusted metadata content.

## Telemetry Support And No-Secret Logs

Support and telemetry should make debugging possible without leaking wallet or
drop secrets.

Allowed diagnostic fields:

- chain ID;
- deployment version;
- release manifest hash;
- address-book hash;
- contract name and address;
- function name or selector;
- collection ID, token ID, drop ID, auction ID, request ID;
- transaction hash;
- receipt status;
- block number and confirmation depth;
- latest indexed block;
- decoded custom error name;
- WalletConnect lifecycle state without session secret material; and
- app build ID and platform.

Forbidden diagnostic fields:

- private keys;
- seed phrases or mnemonics;
- signer-service credentials;
- HSM/KMS credentials;
- admin credentials;
- bearer tokens, cookies, or private RPC authorization headers;
- WalletConnect pairing URIs, session topics, symmetric keys, or relay secrets;
- raw signatures;
- raw unreleased `tokenData`;
- unreleased signed `DropAuthorization` payloads;
- Safe owner exports; and
- support screenshots that expose secret-shaped payloads.

Support tooling should ask for transaction hash, chain ID, release manifest
hash, and decoded error. It should not ask users to paste seed phrases,
private keys, WalletConnect internals, raw signatures, or unreleased drop data.

## Security Checklist

Minimum mobile security requirements:

- Halt on wrong chain, wrong address book, wrong deployment manifest, wrong
  verifying contract, or wrong EIP-712 domain before wallet prompts.
- Re-run preflight after WalletConnect reconnect, app resume, account change,
  chain change, transaction replacement, and offline recovery.
- Keep signed `DropAuthorization` fields immutable.
- Attribute replay protection to on-chain consumed/cancelled/signer-epoch state,
  not EIP-712 or WalletConnect alone.
- Keep production signer keys, signer-service tokens, admin credentials, and
  privileged RPC credentials out of mobile clients.
- Treat ERC-1271 and Safe signer failures as operator/configuration failures
  unless the product flow explicitly asks a user-owned contract wallet to act.
- Redact all secret-shaped values before telemetry or support export.
- Treat push notifications as hints that require verification.
- Treat mobile WebViews and animation sandboxes as untrusted rendering
  contexts.
- Keep Electron-specific main-process, renderer, IPC, filesystem, and auto
  updater decisions in INT-009 rather than smuggling them into the mobile guide.

## Testing Strategy

A future mobile reference implementation should include:

- artifact loader tests for release manifest, address book, deployment
  manifest, ABI checksums, event topics, interface IDs, and wrong-chain
  rejection;
- WalletConnect session tests for pairing, approval, rejection, session expiry,
  reconnect, account change, chain change, wrong namespace, and relay failure;
- deep-link resume tests for backgrounding before signature, before
  transaction, after transaction hash, and after receipt;
- transaction state tests for simulation, submission, receipt, confirmation
  depth, replacement, dropped transaction, decoded revert, and user rejection;
- typed-data tests for wrong domain, wrong signer, expired deadline, replay,
  cancelled drop, stale signer epoch, tokenData hash mismatch, EOA signatures,
  and ERC-1271/Safe boundaries;
- offline tests for stale metadata, stale auction state, stale credit state,
  and indexer lag after reconnect;
- metadata rendering tests for image, animation_url, sandboxed WebView,
  `MetadataUpdate`, `BatchMetadataUpdate`, `CollectionFrozen`, and burned
  tokens;
- telemetry redaction tests for private keys, mnemonics, raw signatures,
  WalletConnect pairing URIs, session topics, cookies, bearer tokens, and
  unreleased payloads; and
- end-to-end local Anvil smoke tests before any public beta claim.

Mocked mobile tests are not production evidence. Fork/testnet/live evidence,
reviewed signer custody evidence, explorer verification, marketplace proof,
and external audit evidence remain required before public beta or production.

## Validation Commands

Run the focused checks after editing this guide:

```sh
python scripts/test_mobile_walletconnect.py
python scripts/check_mobile_walletconnect.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

Run the full local release gate before merging:

```sh
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this guide when:

- release artifact names or manifest schemas change;
- deployment manifest or address-book schemas change;
- ABI, event, interface, or checksum artifact paths change;
- WalletConnect session, namespace, or pairing assumptions change;
- mobile deep-link, app-link, universal-link, background, or push-notification
  assumptions change;
- wallet/signature, EIP-712, ERC-1271, Safe, signer custody, or backend
  signing-service boundaries change;
- fixed-price, auction, credit, metadata, randomizer, or indexer flow docs add
  new user-visible states; or
- a maintained SDK, mobile reference app, or Electron guide is intentionally
  introduced.

Keep this guide conservative. It should help mobile implementers move quickly
without weakening the repo's pre-audit and not-production-ready boundary.
