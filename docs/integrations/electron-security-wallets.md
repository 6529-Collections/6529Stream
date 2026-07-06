# Electron Security And Wallet Integration Guide

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](../spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This is the INT-009 integration guide for Electron clients that consume
6529Stream release artifacts. It is a pre-audit local baseline, not
production-ready, and not a security claim. Local evidence does not replace
fork/testnet/live evidence for public beta or production use.

The guide is documentation-only. It does not add an Electron app, native
desktop app, wallet package dependency, autoUpdater integration, desktop SDK,
generated SDK, maintained frontend package, code-signing implementation, or
production wallet integration to this contracts repository.

## Maturity And Scope

Use this guide when building an Electron shell for a 6529.io-style product
surface that needs to mint, submit auctions, bid, settle, withdraw credits,
render metadata, reconcile indexer state, and hand wallet actions to safe
wallet-mediated or hardware-backed flows.

Current scope:

- Electron main process, renderer process, and preload script boundaries;
- BrowserWindow defaults, navigation policy, permission policy, and window-open
  handling;
- renderer hardening with contextIsolation, disabled nodeIntegration,
  sandboxing where feasible, and Content-Security-Policy;
- contextBridge and IPC allowlist design;
- wallet provider boundaries for EIP-1193, WalletConnect, EIP-712, ERC-1271,
  and Safe flows;
- DropAuthorization preflight, replay-state checks, and transaction prompts;
- metadata animation_url and token HTML sandboxing with WebView caveats;
- local storage, cache, crash-report, telemetry, and no-secret support policy;
  and
- signed updates, code signing, autoUpdater caveats, rollback, and release
  integrity expectations.

Current non-scope:

- a production-ready Electron app or public beta implementation;
- an Electron, WalletConnect, EIP-1193, or autoUpdater package
  recommendation;
- a reviewed desktop secure-storage design;
- a reviewed production code-signing or notarization pipeline;
- a production signing service or signer custody approval; and
- live marketplace, live indexer, live wallet, or live auto-update evidence.

## Source Of Truth

Start from the integration entrypoint and release evidence before writing
desktop code:

- [docs/integrations/README.md](README.md)
- [docs/integrations/contract-flows.md](contract-flows.md)
- [docs/integrations/auction-flows.md](auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](wallets-and-signatures.md)
- [docs/integrations/events-and-indexing.md](events-and-indexing.md)
- [docs/integrations/metadata-rendering.md](metadata-rendering.md)
- [docs/integrations/frontend-reference-architecture.md](frontend-reference-architecture.md)
- [docs/integrations/mobile-walletconnect.md](mobile-walletconnect.md)
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

Raw ABI JSON is generated under ignored `out/` after `forge build`. Electron
apps should consume a reviewed artifact bundle, address book, deployment
manifest, release manifest, ABI checksum, event topic catalog, interface IDs,
release checksums, bytecode-to-release proof, risk register, and public-beta
evidence status for the target environment. Do not copy ABI fragments or
contract addresses by hand.

## Non-Goals

This guide is not a maintained Electron reference app commitment and does not
define a supported desktop framework matrix.

This PR intentionally does not:

- add Electron, WalletConnect, wagmi, viem, TanStack Query, autoUpdater, native
  keychain, code-signing, notarization, or installer dependencies;
- publish generated desktop bindings;
- create an Electron app, native desktop app, packaged installer, or desktop
  SDK;
- commit production RPC, WalletConnect project IDs, code-signing certificates,
  notarization credentials, auto-update credentials, or analytics credentials;
- implement a production signing service, signer custody module, or hardware
  wallet integration; or
- claim public beta, production, live wallet, live marketplace, live indexer,
  signed-update, or live auto-update readiness.

## Electron Process Model

Electron integrations should treat the main process as a narrow privileged
coordinator, the renderer process as untrusted UI, and the preload script as a
small typed bridge.

Required responsibilities:

| Layer | Responsibility | Boundary |
| --- | --- | --- |
| Main process | Creates BrowserWindow instances, owns app lifecycle, validates update and filesystem requests, owns restricted native capabilities | No protocol signer custody, no raw wallet secrets |
| Renderer process | Displays UI, reads public artifacts, builds unsigned user prompts, and requests wallet actions through safe adapters | No Node APIs, no private keys, no privileged IPC |
| Preload script | Exposes a small contextBridge API for allowed operations | Typed allowlist only |
| Wallet adapter | Talks to injected EIP-1193 providers, WalletConnect, Safe apps, or hardware-backed wallets | User-controlled signing and transactions only |
| Artifact loader | Loads release manifest, address book, deployment manifest, ABI checksum, event topic catalog, interface IDs, and risk register | Public read-only data |
| Metadata renderer | Displays tokenURI JSON, image output, and animation_url content | Untrusted sandbox |
| Update channel | Downloads, verifies, and applies app updates | Product release assumption, not a contract guarantee |

Do not make the Electron app the protocol's production drop signer. Drop
authorization signing remains a backend signing-service and signer custody
concern unless a future accepted decision explicitly changes that boundary.

## Renderer Isolation And CSP

Renderer windows that display 6529Stream UI should default to a hardened
BrowserWindow configuration.

Minimum renderer policy:

- enable `contextIsolation`;
- disable `nodeIntegration`;
- enable `sandbox` where feasible;
- disable or tightly scope `enableRemoteModule` if present in legacy Electron
  versions;
- block unexpected navigation with a strict allowlist;
- block unexpected `window.open` and new-window creation;
- grant permissions only through explicit main-process checks;
- use a strict Content-Security-Policy;
- avoid inline scripts unless a reviewed hash or nonce policy exists; and
- treat all remote content, metadata, image, and animation output as untrusted.

Renderer code must not receive private keys, seed phrases, mnemonics,
signer-service credentials, HSM/KMS credentials, admin credentials, bearer
tokens, private RPC authorization headers, WalletConnect pairing secrets,
session topics, symmetric keys, raw signatures, unreleased signed
DropAuthorization payloads, or unrestricted filesystem paths.

## Preload And IPC Contract

The preload script should expose a minimal contextBridge API. Treat IPC as a
security boundary, not as an internal convenience bus.

Required IPC rules:

- every channel is named, documented, and allowlisted;
- renderer input is schema-validated before any privileged action;
- main-process responses are typed and contain only no-secret data;
- filesystem reads are scoped to explicitly selected public files or release
  artifact directories;
- shell opens are explicit user actions against validated URLs;
- update checks, downloads, and installs require release-integrity checks;
- wallet actions pass through wallet adapters rather than privileged IPC
  signing helpers; and
- rejected IPC requests emit diagnostic events that do not include secrets.

Do not expose generic IPC primitives such as `invoke(channel, ...args)` to
renderer code. Prefer named functions such as `loadReleaseManifest`,
`openExternalExplorer`, `requestWalletAction`, and `getAppBuildInfo`, with
strictly typed arguments and outputs.

## Wallet Provider Boundaries

Electron wallet flows should match the browser and mobile integration
assumptions unless a future audited desktop wallet module exists.

Supported wallet boundary:

- EIP-1193 provider calls are user-mediated;
- WalletConnect is a transport/session layer, not a protocol authorization
  layer;
- EIP-712 typed-data prompts are displayed by the user's wallet or Safe flow;
- ERC-1271 contract-signature checks are treated as on-chain verification
  behavior, not renderer trust;
- Safe signing and contract-wallet flows follow the wallet/signature guide;
- hardware-backed wallets remain outside renderer custody; and
- user transactions are submitted through the wallet provider, not through
  stored private keys in Electron.

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
  and
- the typed `tokenData` bytes hash to the signed `tokenDataHash`.

EIP-712 is encoding/signing only. Replay protection requires domain separation,
storage-backed `consumedDropIds`, storage-backed `cancelledDropIds`,
signer-service allocated `nonce` and `salt`, current `signerEpoch`, signer
rotation policy, `deadline`, and the on-chain consumed-state write before mint
or auction execution. Electron, WalletConnect, and EIP-712 alone do not provide
replay protection.

## Signing And Transaction Flows

Desktop clients submit user transactions and may ask the connected user wallet
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

Wallet adapters should distinguish user rejection, provider timeout, wrong
chain, account changed, simulation failure, transaction revert with decoded
custom error, transaction replacement, dropped transaction, indexer lag after
receipt, and stale payload after provider reconnect.

Do not auto-retry by mutating signed fields. A different recipient, payer,
price, quantity, reserve, end time, token data, deadline, nonce, salt, or signer
epoch requires a fresh authorization.

## Metadata Animation Sandbox

Use [docs/integrations/metadata-rendering.md](metadata-rendering.md) and
[docs/integrations/events-and-indexing.md](events-and-indexing.md) for the
canonical cache and reconstruction model.

Electron clients should:

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
- render animation_url content in a sandbox that cannot access wallet state,
  session state, local files, Node APIs, privileged IPC, or preload helpers; and
- avoid loading untrusted metadata content in a privileged WebView.

If a WebView, iframe, or BrowserView is used for animation, it must have a
separate permission policy and no bridge to wallet providers, signing APIs,
filesystem writes, shell opens, update APIs, local secret storage, or support
export APIs.

## Local Storage Cache And Secrets

Electron has tempting local storage surfaces. Treat every persistent store as a
designed data boundary.

Allowed local diagnostic/cache fields:

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
- wallet lifecycle state without session secret material;
- app build ID, platform, and update channel; and
- public release artifact cache metadata.

Forbidden local, telemetry, crash-report, and support fields:

- private keys;
- seed phrases or mnemonics;
- signer-service credentials;
- HSM/KMS credentials;
- admin credentials;
- code-signing certificates or notarization credentials;
- auto-update publish credentials;
- bearer tokens, cookies, or private RPC authorization headers;
- WalletConnect pairing URIs, session topics, symmetric keys, or relay secrets;
- raw signatures;
- raw unreleased `tokenData`;
- unreleased signed `DropAuthorization` payloads;
- Safe owner exports; and
- support screenshots that expose secret-shaped payloads.

Support tooling should ask for transaction hash, chain ID, release manifest
hash, app build ID, and decoded error. It should not ask users to paste seed
phrases, private keys, WalletConnect internals, raw signatures, unreleased drop
data, or desktop storage exports that may contain secrets.

## Updates Downloads And Release Integrity

Electron update delivery is a product and release assumption, not a smart
contract guarantee.

A production Electron product should define:

- code signing and notarization requirements for every supported platform;
- signed updates and update manifest verification;
- autoUpdater channel policy, including stable, beta, and emergency channels;
- rollback policy for a bad update;
- release manifest and checksum bundle pinning for contract artifacts;
- app build provenance, including commit, tag, CI run, and artifact hashes;
- download integrity checks before install;
- secret-free update logs and crash reports;
- emergency kill-switch and forced-upgrade communication policy; and
- operator review for any update that changes wallet, signing, IPC, metadata,
  or artifact-loading behavior.

Do not treat app update signatures as protocol authorization. Contract actions
still require the on-chain and wallet preflight described above.

## Telemetry Support And No-Secret Logs

Support and telemetry should make desktop debugging possible without leaking
wallet, signing, or update secrets.

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
- wallet lifecycle state without session secret material;
- BrowserWindow profile ID or renderer route without user secrets;
- app build ID, code-signing status, update channel, and platform; and
- no-secret IPC channel name for rejected requests.

Forbidden diagnostic fields:

- private keys;
- seed phrases or mnemonics;
- signer-service credentials;
- HSM/KMS credentials;
- admin credentials;
- code-signing certificates or notarization credentials;
- autoUpdater publish credentials;
- bearer tokens, cookies, or private RPC authorization headers;
- WalletConnect pairing URIs, session topics, symmetric keys, or relay secrets;
- raw signatures;
- raw unreleased `tokenData`;
- unreleased signed `DropAuthorization` payloads;
- unrestricted filesystem paths; and
- screenshots or renderer dumps that expose secret-shaped payloads.

## Security Checklist

Minimum Electron security requirements:

- Halt on wrong chain, wrong address book, wrong deployment manifest, wrong
  verifying contract, or wrong EIP-712 domain before wallet prompts.
- Re-run preflight after WalletConnect reconnect, app resume, account change,
  chain change, transaction replacement, and offline recovery.
- Keep signed `DropAuthorization` fields immutable.
- Attribute replay protection to on-chain consumed/cancelled/signer-epoch state,
  not Electron, EIP-712, or WalletConnect alone.
- Keep production signer keys, signer-service tokens, admin credentials,
  privileged RPC credentials, code-signing credentials, and auto-update
  credentials out of Electron clients.
- Treat ERC-1271 and Safe signer failures as operator/configuration failures
  unless the product flow explicitly asks a user-owned contract wallet to act.
- Redact all secret-shaped values before telemetry or support export.
- Treat metadata animation sandboxes, WebViews, iframes, and remote content as
  untrusted rendering contexts.
- Keep renderer processes isolated from Node APIs, filesystem access, wallet
  secrets, privileged IPC, update controls, and local secret storage.
- Keep desktop update, code-signing, rollback, and release-integrity decisions
  explicit instead of smuggling them into contract integration docs.

## Testing Strategy

A future Electron reference implementation should include:

- BrowserWindow configuration tests for contextIsolation, disabled
  nodeIntegration, sandbox policy, navigation allowlists, permission handling,
  and window-open blocking;
- preload and IPC tests for allowed channels, denied channels, schema
  validation, no generic invoke exposure, and no-secret responses;
- wallet-provider tests for EIP-1193 request routing, WalletConnect reconnect,
  wrong chain, account change, user rejection, provider timeout, and stale
  payload rejection;
- typed-data tests for wrong domain, wrong signer, expired deadline, replay,
  cancelled drop, stale signer epoch, tokenData hash mismatch, EOA signatures,
  and ERC-1271/Safe boundaries;
- transaction state tests for simulation, submission, receipt, confirmation
  depth, replacement, dropped transaction, decoded revert, and user rejection;
- metadata rendering tests for image, animation_url, sandboxed WebView,
  `MetadataUpdate`, `BatchMetadataUpdate`, `CollectionFrozen`, and burned
  tokens;
- local storage and cache tests for public release artifacts, stale metadata,
  stale auction state, stale credit state, and forbidden secret fields;
- update tests for signed update verification, rollback, channel selection,
  checksum mismatch, and secret-free update logs;
- telemetry redaction tests for private keys, mnemonics, raw signatures,
  WalletConnect pairing URIs, session topics, cookies, bearer tokens, code
  signing secrets, auto-update credentials, and unreleased payloads; and
- end-to-end local Anvil smoke tests before any public beta claim.

Mocked Electron tests are not production evidence. Fork/testnet/live evidence,
reviewed signer custody evidence, explorer verification, signed release
artifacts, marketplace proof, external audit evidence, and reviewed update
pipeline evidence remain required before public beta or production.

## Validation Commands

Run the focused checks after editing this guide:

```sh
python scripts/test_electron_security_wallets.py
python scripts/check_electron_security_wallets.py
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
- Electron BrowserWindow, contextBridge, preload, IPC, CSP, sandbox, WebView,
  or autoUpdater assumptions change;
- wallet/signature, EIP-712, ERC-1271, Safe, signer custody, WalletConnect, or
  backend signing-service boundaries change;
- fixed-price, auction, credit, metadata, randomizer, or indexer flow docs add
  new user-visible states; or
- a maintained SDK, Electron reference app, desktop installer, or production
  update pipeline is intentionally introduced.

Keep this guide conservative. It should help Electron implementers move
quickly without weakening the repo's pre-audit and not-production-ready
boundary.
