# React/Next Frontend Reference Architecture

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](../spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This is the INT-007 reference architecture for a 6529.io-style React and Next
frontend that consumes 6529Stream release artifacts. It is a pre-audit local
baseline, not production-ready, and not a security claim. Local evidence does
not replace fork/testnet/live evidence for public beta or production use.

The guide is intentionally architecture-only. It does not add a maintained
frontend package, generated SDK, Next app, React component library, viem client,
wagmi connector, TanStack Query setup, mobile app, or Electron shell to this
contracts repository. No package dependency is introduced.

## Maturity And Scope

Use this document when designing a web frontend, operator console, or future
6529.io integration layer that needs to read contract state, render metadata,
submit transactions, and reconcile indexer data against the current local
release baseline.

Current scope:

- React and Next application architecture for contract consumption.
- viem/wagmi-style client layering without pinning an unapproved dependency.
- TanStack Query-style query/cache boundaries without introducing a package.
- Generated types and artifact import flow for ABIs, addresses, interfaces,
  event topics, release manifests, and checksum bundles.
- Environment separation, chain config, transaction state, wallet/signature
  boundaries, metadata rendering, telemetry, and testing expectations.

Current non-scope:

- A production-ready frontend implementation.
- A stable SDK API.
- A supported package version matrix.
- A live public beta or production integration claim.
- Any browser custody of private keys, signer-service credentials, admin
  credentials, privileged RPC credentials, or unreleased drop payload secrets.

## Source Of Truth

Start from the integration entrypoint and release evidence before writing app
code:

- [docs/integrations/README.md](README.md)
- [docs/integrations/contract-flows.md](contract-flows.md)
- [docs/integrations/auction-flows.md](auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](wallets-and-signatures.md)
- [docs/integrations/events-and-indexing.md](events-and-indexing.md)
- [docs/integrations/metadata-rendering.md](metadata-rendering.md)
- [docs/integrations/integration-conformance-fixtures.md](integration-conformance-fixtures.md)
- [docs/integrations/fixtures/integration-conformance-fixtures.json](fixtures/integration-conformance-fixtures.json)
- [docs/integrations/examples/react-viem.md](examples/react-viem.md)
- [docs/integrations/examples/typescript-eip712-drop-authorization.md](examples/typescript-eip712-drop-authorization.md)
- [docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md](examples/typescript-event-decoding-and-indexer-ingestion.md)
- [docs/architecture.md](../architecture.md)
- [docs/threat-model.md](../threat-model.md)
- [docs/deployment.md](../deployment.md)
- [docs/drop-authorization-signing.md](../drop-authorization-signing.md)
- [docs/signer-custody-readiness.md](../signer-custody-readiness.md)
- [docs/release-readiness.md](../release-readiness.md)
- [docs/release-policy.md](../release-policy.md)
- [docs/non-local-release-evidence.md](../non-local-release-evidence.md)
- [docs/public-beta-evidence.md](../public-beta-evidence.md)
- [release-artifacts/README.md](../../release-artifacts/README.md)
- [release-artifacts/baselines/v0.1.0/abi-surface.json](../../release-artifacts/baselines/v0.1.0/abi-surface.json)
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

Raw ABI JSON is generated under ignored `out/` after `forge build`. Frontends
should not copy ABI fragments by hand. Use generated artifacts from a verified
checkout, then bind those ABI surfaces to the reviewed address book, deployment
manifest, release manifest, ABI checksum, event topic catalog, interface IDs,
release checksums, bytecode-to-release proof, risk register, and public-beta
evidence status for the target environment.

## Non-Goals

Do not treat this document as an SDK commitment. It names recommended
boundaries, not a supported import path.

This PR intentionally does not:

- add `package.json`, React, Next, viem, wagmi, TanStack Query, Playwright,
  WalletConnect, Electron, React Native, Expo, or mobile package dependencies;
- publish a generated TypeScript client;
- commit hardcoded mainnet addresses;
- expose a browser signing backend;
- assert public beta, production, live marketplace, or live indexer readiness.

## Application Layers

A 6529.io-style frontend should keep these layers separate:

| Layer | Responsibility | Browser boundary |
| --- | --- | --- |
| Artifact loader | Loads release manifest, ABI checksum, event topic catalog, interface IDs, deployment manifest, and address book for one chain ID | Public read-only data only |
| Chain config | Selects RPC transport, block explorer, deployment version, and confirmation depth for the active chain ID | Public RPC endpoints only |
| Contract clients | Wraps read/write calls for StreamCore, StreamDrops, StreamMinter, StreamAuctions, StreamCuratorsPool, randomizers, and DependencyRegistry | No signer secrets |
| Query cache | Caches contract reads, indexer rows, metadata JSON, and derived view models with explicit query key domains | No privileged payloads |
| Transaction orchestrator | Simulates, submits, waits for receipts, confirms, and re-reads state after events | Wallet action required |
| Wallet/signature adapter | Handles EOA wallets, ERC-1271 contract wallets, Safe, WalletConnect, chain switching, and user rejection | Never stores private keys |
| Indexer client | Serves event-derived entities and replay status using the event/indexer reconstruction spec | Treats indexer as eventually consistent |
| Metadata renderer | Renders tokenURI JSON, images, attributes, and animation sandbox surfaces | Sandboxed untrusted content |
| Telemetry adapter | Records no-secret diagnostics for user-visible failures and operational alerts | No raw signatures or secrets |

The app may use Next App Router, Pages Router, or a client-only React shell.
The contract-facing layer should not depend on a particular router. Server
components may fetch public artifacts or indexer snapshots, but wallet actions,
chain switching, transaction submission, and message signing remain client-side
wallet flows unless a separate backend signing service is explicitly reviewed.

## Artifact Import Flow

Use a generated artifact bundle per environment:

1. Run `forge build` locally or consume a reviewed release artifact package.
2. Load raw ABIs from ignored `out/` only in the build step that generates typed
   frontend bindings.
3. Verify the ABI surface against
   [release-artifacts/latest/abi-checksums.json](../../release-artifacts/latest/abi-checksums.json)
   and the release manifest.
4. Load the deployment manifest and address book for the selected chain ID and
   deployment version.
5. Verify the address book references the same deployment manifest SHA-256.
6. Bind each contract client to addresses by contract name, not by copied
   literals.
7. Load the event topic catalog and interface IDs for indexer subscriptions and
   interface checks.
8. Record the release manifest hash and checksum bundle hash in the app build
   metadata so bug reports can name the artifact set that produced the UI.

Recommended generated frontend artifacts:

- `streamReleaseManifest` from `release-manifest.json`.
- `streamAddressBookByChainId` from deployment address books.
- `streamContractArtifacts` from raw Foundry build output plus ABI checksums.
- `streamEventTopics` from `event-topic-catalog.json`.
- `streamInterfaceIds` from `interface-ids.json`.
- `streamReleaseChecksums` from `release-checksums.json` and `SHA256SUMS`.

Any generator should fail closed when the release manifest, address book,
deployment manifest, ABI checksum, chain ID, or contract name does not match.
The browser bundle may contain public ABIs and addresses. It must not contain
private keys, mnemonics, Safe signing secrets, signer-service credentials,
bearer tokens, admin secrets, unreleased signed drop payloads, or privileged
RPC credentials.

The INT-013 TypeScript artifact loading and chain config snippets in
[docs/integrations/examples/typescript-artifacts-and-chain-config.md](examples/typescript-artifacts-and-chain-config.md)
show the next level of detail for release artifact loading, address book
loading, release manifest hash validation, deployment manifest cross-checks,
ABI checksum awareness, fail-closed wrong-chain guards, no-secret
`NEXT_PUBLIC_*` parsing, and chain config construction.

The INT-015 TypeScript event decoding and indexer ingestion snippets in
[docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md](examples/typescript-event-decoding-and-indexer-ingestion.md)
show the next level of detail for event topic catalog loading, topic0
dispatch, normalized log identity, idempotent ingestion, read-after-event
queue construction, confirmation depth handling, and reorg rollback.

## Environment And Network Selection

Split public browser configuration from server-only configuration.

Suggested public environment fields:

- `NEXT_PUBLIC_STREAM_CHAIN_ID`
- `NEXT_PUBLIC_STREAM_NETWORK_NAME`
- `NEXT_PUBLIC_STREAM_DEPLOYMENT_VERSION`
- `NEXT_PUBLIC_STREAM_RELEASE_MANIFEST_URL`
- `NEXT_PUBLIC_STREAM_ADDRESS_BOOK_URL`
- `NEXT_PUBLIC_STREAM_PUBLIC_RPC_URL`
- `NEXT_PUBLIC_STREAM_INDEXER_URL`
- `NEXT_PUBLIC_STREAM_CONFIRMATION_DEPTH`

Suggested server-only fields:

- `STREAM_RELEASE_ARTIFACTS_DIR`
- `STREAM_SIGNER_SERVICE_URL`
- `STREAM_SIGNER_SERVICE_AUDIENCE`
- `STREAM_INDEXER_ADMIN_URL`
- `STREAM_PRIVATE_RPC_URL`

Never put secrets in `NEXT_PUBLIC_*`. Public RPC URLs should be rate-limited
and replaceable. Private RPC URLs, signer service tokens, Safe operator
credentials, API keys, bearer tokens, cookies, session exports, raw signatures,
and unreleased drop payload material belong outside the browser bundle.

The network selector should reject mismatched chain ID, missing address book,
stale release manifest hash, unsupported deployment version, and unknown
contract name before any contract call is prepared.

## Contract Client Layer

The contract client layer should look like viem/wagmi without requiring those
libraries here:

- A public client for reads, simulations, event logs, and receipt lookups.
- A wallet client for user transactions and message signatures.
- Contract clients generated from ABI artifacts and address-book entries.
- Typed action functions for fixed-price mints, auction submissions, bids,
  settlements, withdrawals, metadata reads, randomizer status reads, and
  curator reward claims.
- Error decoders that map custom errors from the ABI to user-facing recovery
  messages and telemetry codes.

Client functions should accept an explicit context:

- `chainId`
- `deploymentVersion`
- `releaseManifestHash`
- `contractName`
- `contractAddress`
- `blockTag` or `blockNumber` when reads must be stable
- `walletAddress` when a user action depends on connected account

Do not hide contract addresses in module globals. A future deployment
rehearsal, testnet, or production release must be able to select a different
address book without rewriting call sites.

## Query And Cache Boundaries

Use stable query keys that encode source and freshness:

- Contract read query key:
  `["contract-read", chainId, contractAddress, functionName, args, blockTag]`.
- Event-derived entity query key:
  `["indexer-entity", chainId, releaseManifestHash, entityType, entityId]`.
- Metadata query key:
  `["metadata", chainId, deploymentVersion, releaseManifestHash, coreAddress, tokenId, metadataState, metadataSchemaVersion, tokenURIHash]`.
- Wallet query key:
  `["wallet", chainId, walletAddress, capability]`.
- Transaction query key:
  `["transaction", chainId, transactionHash]`.

Cache invalidation must follow the event and metadata docs:

- `Transfer` mints and burns update ownership and token existence.
- ERC-721 transfer-to-zero and `TokenBurned` move tokens to burned state.
- `MetadataUpdate` and `BatchMetadataUpdate` invalidate token metadata JSON,
  rendered attributes, image caches, and animation_url sandboxes.
- `CollectionFrozen` invalidates mutable collection views and enables freeze
  proof UI states.
- `DependencyVersionPinned`, `DependencyVersionCreated`, and
  `DependencyVersionDeprecated` invalidate dependency-derived animation and
  renderer caches.
- Auction bid, outbid, settlement, no-bid settlement, cancellation, and credit
  withdrawal events invalidate auction and payment views.
- Randomizer pending, fulfilled, stale, failed, retry, and migration events
  invalidate token metadata state and retry controls.

Indexer data is eventually consistent. After a transaction receipt, the app
should do read-after-event checks against RPC or a confirmed indexer block
before displaying final state. Use confirmation depth and reorg policy from the
event/indexer guide; do not silently treat a zero-confirmation event as final
for production.

## Transaction Orchestration

Every transaction path should follow the same state machine:

1. Validate chain ID, release manifest, address book, deployment manifest, and
   connected wallet.
2. Load preflight reads from the relevant flow guide.
3. Simulate the call when the wallet/RPC stack supports it.
4. Present the exact action, collection, token, drop, auction, price, deadline,
   and signer assumptions to the user.
5. Submit through the wallet client.
6. Record pending transaction state with `transactionHash`, `chainId`,
   `contractAddress`, function, and args.
7. Wait for the transaction receipt.
8. Apply confirmation depth policy.
9. Re-read contract state or indexer state after the expected event.
10. Replace optimistic state with confirmed state.

Optimistic UI is allowed for reversible pending display only. Do not mark a
mint, auction bid, settlement, withdrawal, metadata finalization, freeze,
randomizer fulfillment, or credit balance as final until the receipt and
read-after-event check agree.

Required failure states:

- user rejected signature or transaction;
- wrong chain ID;
- missing wallet account;
- stale release manifest or address book;
- simulation failure;
- transaction reverted with custom errors;
- replaced, cancelled, or dropped transaction;
- expired EIP-712 payload;
- wrong signer, wrong domain, replayed, cancelled, or stale signer epoch;
- paused mint, bid, settlement, or withdrawal path;
- insufficient funds or allowance-like precondition;
- indexer lag or reorg.

## Wallet And Signature Boundaries

Read the wallet guide before implementing user actions:
[docs/integrations/wallets-and-signatures.md](wallets-and-signatures.md).

Frontend wallets submit user transactions. Drop authorization signing is a
backend signing-service concern unless a future design explicitly changes that
boundary. EIP-712 payload generation can be shown in the frontend, but signer
material, raw production signatures, signer-service tokens, signer private
keys, Safe owner credentials, and unreleased signed payloads must not enter the
browser.

Validate chain ID, release manifest, address book, deployment manifest, EIP-712
domain, signer epoch, and connected wallet before signing or transaction
submission. A chain/domain/address-book mismatch must stop the flow before a
signature prompt or transaction prompt appears.

Signed `DropAuthorization` fields and `tokenData` are immutable after issuance.
If a UI needs different token data, price, deadline, signer epoch, or drop
scope, it must request a new authorization instead of mutating the old one.

Wallet adapters should handle:

- EOAs;
- ERC-1271 contract signers when the product flow supports them;
- explicit ERC-1271 out-of-scope messaging when a flow does not support them;
- Safe apps and Safe-owned accounts;
- WalletConnect mobile handoff;
- chain switching and unsupported-chain recovery;
- typed-data display mismatch;
- signature rejection, timeout, replacement, and retry.

The UI should display EIP-712 domain name, version, chain ID, verifying
contract, deadline, nonce/drop ID, signer epoch, and collection/drop identifiers
whenever a user or operator reviews a signed action. Replay protection is
storage state plus consumed/cancelled/drop/signer controls; it is not provided
by EIP-712 encoding alone.

## Error, Toast, And Telemetry Policy

User-facing errors should be specific but no-secret:

- Decode custom errors from the ABI before falling back to raw revert data.
- Map known errors to actionable messages and recovery options.
- Include stable IDs in telemetry: chain ID, release manifest hash,
  deployment version, contract name, contract address, function selector,
  collection ID, token ID, drop ID, auction ID, request ID, transaction hash,
  and block number.
- Do not log private keys, mnemonics, signer-service credentials, cookies,
  bearer tokens, raw signatures, unreleased payloads, raw RPC authorization
  headers, or private RPC URLs.
- Keep toast state separate from confirmed protocol state.

Recommended toast families:

- Wallet action required.
- Transaction pending.
- Transaction confirmed, waiting for read-after-event.
- Indexer catching up.
- Action failed with decoded custom error.
- Action failed due to chain/account mismatch.
- Action needs a refreshed signature or signer epoch.
- Action blocked by release maturity or missing non-local evidence.

## Metadata, Animation, And Marketplace Rendering

Use [docs/integrations/metadata-rendering.md](metadata-rendering.md) for the
metadata state model, tokenURI behavior, ERC-4906 invalidation, cache keys,
animation sandbox, mobile/Electron boundaries, and marketplace evidence caveats.

Frontend renderers should:

- parse tokenURI JSON as untrusted input;
- enforce strict UTF-8 assumptions and schema expectations;
- render animation_url in an iframe sandbox with parent isolation;
- allow `allow-scripts` only inside a sandboxed renderer boundary;
- reject unexpected outbound HTTP(S) requests in local evidence checks;
- separate metadata cache from image and animation cache;
- invalidate on `MetadataUpdate`, `BatchMetadataUpdate`, `CollectionFrozen`,
  `TokenBurned`, ERC-721 transfer-to-zero, and dependency version events;
- keep OpenSea, Reservoir, Blur, Manifold, and other marketplace evidence
  separate from local browser evidence.

Electron and mobile apps need stricter boundaries. Electron renderers must not
have private key access, privileged IPC, filesystem write access, or wallet
session exports in the metadata animation process. Mobile apps should assume
foreground wallet handoff for WalletConnect signing and transaction approval.

## Indexer And Event Reconciliation

Use [docs/integrations/events-and-indexing.md](events-and-indexing.md) for the
canonical event and read-after-event reconstruction model.

A React/Next app can use direct RPC reads for fresh user flows and an indexer
for list views. The UI should show indexer lag when the latest indexed block is
behind the receipt block plus confirmation depth.

Recommended split:

- Direct RPC reads for transaction preflight, post-receipt confirmation,
  wallet-local balances, auction settlement eligibility, credit balances, and
  metadata state after a user action.
- Indexer reads for collection lists, token history, auction history,
  marketplace summaries, analytics, and recovery after page reloads.
- Full rescan and reorg handling in indexer services, not in React state.

Every entity should retain chain ID, deployment version, release manifest hash,
contract address, event block number, transaction hash, log index, and source
event topic when possible.

## Security And Secret Handling

The browser is public. Treat every browser-readable artifact as public:

- ABIs, address books, event topics, interface IDs, release manifests, and
  public RPC URLs can be shipped to the browser.
- Private keys, mnemonics, Safe signing secrets, signer-service credentials,
  HSM/KMS credentials, API keys, bearer tokens, cookies, private RPC URLs,
  raw signatures, unreleased signed payloads, and admin credentials cannot.
- Backend signing service calls must be authenticated server-side, rate-limited,
  audited, and designed so the browser never receives signing authority.
- CSP should restrict script sources and frame sources for the app shell.
- Metadata animation iframes should be isolated from wallet state, local
  storage, session storage, and parent-window privileged APIs.
- Error reports must redact secrets before telemetry leaves the device.

No frontend integration should weaken the pre-audit local baseline boundary.
Missing external audit, testnet/live deployment evidence, explorer
verification, production signatures, signer custody evidence, admin ceremony
evidence, and live metadata/indexer evidence remain release blockers.

## Testing Strategy

A future reference frontend should be tested in layers:

- Artifact loader unit tests for release manifest, address book, deployment
  manifest, ABI checksum, event topic catalog, interface IDs, release
  checksums, and wrong-chain rejection.
- Contract client tests with mocked public client, wallet client, custom error
  decoding, and contract address selection by chain ID.
- Query key tests for contract reads, event-derived entities, metadata, wallet
  capability, and transaction state.
- Cache invalidation reducer tests for Transfer, MetadataUpdate,
  BatchMetadataUpdate, CollectionFrozen, TokenBurned, DependencyVersionPinned,
  auction lifecycle, withdrawal, and randomizer events.
- Transaction state tests for preflight, simulation, submission, receipt,
  confirmation depth, read-after-event, replacement, dropped transaction,
  revert, and user rejection.
- Wallet tests for EOA, ERC-1271, Safe, WalletConnect, wrong chain, expired
  EIP-712 payload, wrong domain, stale signer epoch, replay, and cancellation.
- Metadata rendering tests using the committed metadata fixtures and sandbox
  policy.
- Indexer reconciliation tests for lag, reorg, duplicate log, and rescan
  behavior.
- INT-016 integration conformance fixtures for artifact loading, fail-closed
  chain config, EIP-712 domain expectations, event topic dispatch, normalized
  log identity, read-after-event queues, duplicate log idempotency, unknown
  emitter, unknown topic, reorg rollback, confirmation depth, and no-secret
  redaction diagnostics.
- End-to-end smoke tests against local Anvil deployment evidence before any
  public beta claim.

No production readiness claim should depend on mocked frontend tests alone.
Fork/testnet/live evidence remains required before public beta or production.

## Pseudocode Examples

Use [docs/integrations/examples/react-viem.md](examples/react-viem.md) for
small non-runnable pseudocode showing artifact loading, chain guards,
contract-client construction, query keys, transaction orchestration, and
secret-free environment handling.

Use
[docs/integrations/examples/typescript-artifacts-and-chain-config.md](examples/typescript-artifacts-and-chain-config.md)
for INT-013 TypeScript snippets focused on release artifact loading, address
book loading, deployment manifest validation, release manifest hash pinning,
ABI checksum validation, unsupported-chain handling, and fail-closed chain
config construction before wallet prompts or transaction submission.

Use
[docs/integrations/examples/typescript-eip712-drop-authorization.md](examples/typescript-eip712-drop-authorization.md)
for INT-014 TypeScript snippets focused on EIP-712 domain construction,
`DropAuthorization` message shape, drop ID derivation, token data hashing,
sale-mode validation, EOA/ERC-1271/Safe boundaries, signer separation,
submission preflight, and no-secret logging.

Use
[docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md](examples/typescript-event-decoding-and-indexer-ingestion.md)
for INT-015 TypeScript snippets focused on event topic catalog loading,
topic0 dispatch, ABI/topic drift checks, normalized log identity,
idempotent ingestion, read-after-event queues, confirmation depth, reorg
rollback, unknown emitter handling, unknown topic handling, and no-secret
diagnostics.

The examples are illustrative architecture shapes only. They are not a
generated SDK, not a dependency recommendation, and not a maintained app.

## Validation Commands

Run the focused checks after editing this guide:

```sh
python scripts/test_react_next_reference.py
python scripts/check_react_next_reference.py
python scripts/test_typescript_artifact_chain_config.py
python scripts/check_typescript_artifact_chain_config.py
python scripts/test_typescript_event_decoding_indexer.py
python scripts/check_typescript_event_decoding_indexer.py
python scripts/test_integration_conformance_fixtures.py
python scripts/check_integration_conformance_fixtures.py
python scripts/test_typescript_eip712_drop_authorization.py
python scripts/check_typescript_eip712_drop_authorization.py
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
- integration flow guides add new user-visible states or failure modes;
- metadata, animation sandbox, ERC-4906, dependency, or marketplace behavior
  changes;
- wallet/signature, EIP-712, ERC-1271, Safe, WalletConnect, signer custody, or
  backend signing-service boundaries change;
- a maintained SDK or reference frontend is intentionally introduced.

Keep this guide conservative. It should make a frontend team faster without
weakening the repo's pre-audit and not-production-ready boundary.
