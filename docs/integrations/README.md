# Integrations

This integrations entrypoint is for teams building against 6529Stream from a
fresh checkout: React web apps, mobile apps, Electron apps, indexers, operator
UI surfaces, and backend signing service components.

The repository is a pre-audit local baseline. It is not production-ready and
this document is not a security claim. Local evidence does not replace fork/testnet/live evidence
for public beta or production use.

## Maturity And Scope

Use this file to find the current integration source of truth. It points at
tracked artifacts, docs, and generated evidence that are committed in the repo.
It does not promise stable mainnet addresses, production signatures, reviewed
external audit evidence, marketplace display proof, or live indexer proof.

Current maturity for integrators:

- Local and retained fork-mainnet rehearsal artifacts exist.
- Public beta remains blocked by missing external audit, testnet/live evidence,
  verified deployed addresses, explorer verification, metadata browser
  evidence, and randomizer operations evidence.
- Production remains blocked by missing production signatures, signed Git tags,
  live ceremony evidence, live deployment manifests, live explorer
  verification, live randomizer evidence, and post-audit remediation evidence.
- Raw ABIs are generated under ignored `out/` after `forge build`. The tracked
  source of truth for review is the ABI surface baseline, ABI checksums,
  protocol surface report, interface IDs, event topic catalog, release
  manifest, and checksum bundle.

## Consumer Surfaces

Supported consumer categories for this entrypoint:

| Consumer | Current entrypoint | Status |
| --- | --- | --- |
| React web app | Use the generated address books, ABI surface/checksum artifacts, signing docs, metadata docs, provenance docs, permanence package docs, royalty policy, release-readiness dashboard, [`contract-flows.md`](contract-flows.md), [`auction-flows.md`](auction-flows.md), [`curator-rewards.md`](curator-rewards.md), [`withdrawals-and-credits.md`](withdrawals-and-credits.md), [`wallets-and-signatures.md`](wallets-and-signatures.md), [`events-and-indexing.md`](events-and-indexing.md), [`metadata-rendering.md`](metadata-rendering.md), [`marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md), [`frontend-reference-architecture.md`](frontend-reference-architecture.md), [`integration-conformance-fixtures.md`](integration-conformance-fixtures.md), [`fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json), [`examples/typescript-artifacts-and-chain-config.md`](examples/typescript-artifacts-and-chain-config.md), [`examples/typescript-eip712-drop-authorization.md`](examples/typescript-eip712-drop-authorization.md), and [`examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md) | Fixed-price, auction, curator rewards, withdrawal and credit UX, wallet/signature, event/indexer, metadata rendering, 1/1 provenance manifest, collector-verifiable permanence package, ERC-2981 royalty disclosure, cache, animation sandbox, retained marketplace/indexer evidence, React/Next reference architecture, INT-013 TypeScript artifact loading and chain config snippets, INT-014 TypeScript EIP-712 payload construction snippets, INT-015 TypeScript event decoding and indexer ingestion snippets, and INT-016 integration conformance fixtures are documented for the local baseline |
| Mobile app | Use the same contract surface artifacts plus [`wallets-and-signatures.md`](wallets-and-signatures.md), [`contract-flows.md`](contract-flows.md), [`auction-flows.md`](auction-flows.md), [`metadata-rendering.md`](metadata-rendering.md), and [`mobile-walletconnect.md`](mobile-walletconnect.md) | Fixed-price, auction, WalletConnect, mobile handoff signatures, mobile foreground wallet action, deep links, reconnect, offline/background limits, and mobile metadata/cache caveats are documented |
| Electron app | Use web-app artifacts plus [`wallets-and-signatures.md`](wallets-and-signatures.md), [`metadata-rendering.md`](metadata-rendering.md), and [`electron-security-wallets.md`](electron-security-wallets.md) | Signature, wallet, renderer/process isolation, preload/IPC, metadata animation sandbox, local cache, signed-update, and no-secret desktop boundaries are documented |
| Indexer | Use event topic catalog, interface IDs, deployment manifests, address books, release manifest, one-of-one provenance manifest, one-of-one permanence manifest, royalty policy, [`auction-flows.md`](auction-flows.md), [`curator-rewards.md`](curator-rewards.md), [`withdrawals-and-credits.md`](withdrawals-and-credits.md), [`events-and-indexing.md`](events-and-indexing.md), [`integration-conformance-fixtures.md`](integration-conformance-fixtures.md), [`fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json), [`metadata-rendering.md`](metadata-rendering.md), and [`marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md) | Auction lifecycle, curator reward claims, withdrawal and credit reconstruction, full event replay, read-after-event reconstruction, metadata state, 1/1 provenance artifact discovery, collector-verifiable permanence package discovery, ERC-2981 royalty display boundary, cache invalidation, INT-016 integration conformance fixtures, and retained marketplace/indexer evidence requirements are documented for the local baseline |
| Operator UI | Use deployment docs, ceremony evidence, randomizer operations docs, risk register, release-readiness dashboard, and [`operator-admin-ui.md`](operator-admin-ui.md) | Current `INT-010` operator personas, Safe/multisig ceremony, role, signer, pause, metadata, dependency, randomizer, emergency, monitoring, and evidence-boundary guidance is documented |
| Backend signing service | Use EIP-712, ERC-1271, Safe, signer custody, drop authorization signing docs, and [`wallets-and-signatures.md`](wallets-and-signatures.md) | Local templates and integration guidance only; production signing evidence remains blocked |

## Source Of Truth

Use tracked generated artifacts rather than hand-maintained copies.

| Need | Source of truth | Notes |
| --- | --- | --- |
| Repo status and public caveats | [`README.md`](../../README.md), [`docs/release-readiness.md`](../release-readiness.md), [`docs/known-blockers.md`](../known-blockers.md) | These are the first stop before any release or integration claim |
| Architecture and protocol boundaries | [`docs/architecture.md`](../architecture.md), [`docs/threat-model.md`](../threat-model.md) | Use before designing frontend trust assumptions |
| Deployment process | [`docs/deployment.md`](../deployment.md), [`deployments/README.md`](../../deployments/README.md) | Deployment docs explain local and retained evidence boundaries |
| Release artifact policy | [`release-artifacts/README.md`](../../release-artifacts/README.md), [`docs/release-policy.md`](../release-policy.md) | Release artifacts are generated and checked |
| Contract list | [`release-artifacts/contracts.json`](../../release-artifacts/contracts.json) | Catalog of release-tracked contracts |
| ABIs | Run `forge build` and read ignored `out/` artifacts locally | Raw ABI JSON is not a committed release artifact |
| ABI review surface | [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json), [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json) | ABI compatibility baseline and checksums are tracked |
| Protocol surface report | [`docs/protocol-surface.md`](../protocol-surface.md), [`release-artifacts/latest/protocol-surface-report.json`](../../release-artifacts/latest/protocol-surface-report.json) | Generated functions, selectors, events, topic0 values, custom errors, ABI hashes, bytecode hashes, and runtime sizes for review |
| Custom error catalog | [`docs/custom-errors.md`](../custom-errors.md), [`release-artifacts/latest/custom-error-catalog.json`](../../release-artifacts/latest/custom-error-catalog.json) | Generated decoded-error categories, selectors, severity, caller guidance, and test traceability for release-relevant custom errors |
| Address books | [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json), [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Generated integrator-facing address source, not hand-edited |
| Deployment manifests | [`deployments/examples/anvil-6529stream-v0.1.0-001.json`](../../deployments/examples/anvil-6529stream-v0.1.0-001.json), [`deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json) | Manifests are generated from deployment config and broadcast inputs |
| Deployment schemas and chain config | [`deployments/schema/deployment-manifest.schema.json`](../../deployments/schema/deployment-manifest.schema.json), [`deployments/schema/address-book.schema.json`](../../deployments/schema/address-book.schema.json), [`deployments/config/sepolia-6529stream-v0.1.0-001.template.json`](../../deployments/config/sepolia-6529stream-v0.1.0-001.template.json) | Sepolia config is a template until reviewed testnet evidence exists |
| Top-level release manifest | [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json) | Generated source of truth tying artifacts, docs, and evidence state together |
| Release artifact catalog | [`release-artifacts/latest/release-artifact-manifest.json`](../../release-artifacts/latest/release-artifact-manifest.json) | Generated ABI, bytecode, interface, and event catalog index |
| Source verification inputs | [`release-artifacts/latest/source-verification-inputs.json`](../../release-artifacts/latest/source-verification-inputs.json) | Local verification inputs, not live explorer proof |
| Interface IDs | [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json) | Generated interface identifiers |
| Event topic catalog | [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json) | Generated event topic source for indexers |
| Bytecode proof | [`release-artifacts/latest/bytecode-release-proof.json`](../../release-artifacts/latest/bytecode-release-proof.json) | Local proof only; live bytecode proof remains future evidence |
| Signable checksums | [`release-artifacts/latest/SHA256SUMS`](../../release-artifacts/latest/SHA256SUMS), [`release-artifacts/latest/release-checksums.json`](../../release-artifacts/latest/release-checksums.json) | Checksum bundle is signable but not currently a production signature |
| Public readiness | [`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json), [`docs/public-beta-evidence.md`](../public-beta-evidence.md), [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md) | public-beta evidence status is the readiness source |
| Risk register | [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json) | Generated launch blockers, planned mitigations, and accepted local-baseline risks |
| Metadata | [`docs/metadata.md`](../metadata.md) | Metadata schema, contract-level metadata adapter, cache, browser, and freeze semantics |
| 1/1 provenance | [`docs/provenance-manifests.md`](../provenance-manifests.md), [`release-artifacts/latest/one-of-one-provenance-manifest.json`](../../release-artifacts/latest/one-of-one-provenance-manifest.json), [`release-artifacts/schema/one-of-one-provenance-manifest.schema.json`](../../release-artifacts/schema/one-of-one-provenance-manifest.schema.json), [`release-artifacts/provenance/one-of-one-provenance-template.provenance.json`](../../release-artifacts/provenance/one-of-one-provenance-template.provenance.json) | Artifact-only provenance model for artist/story/authenticity context; not token finality, ownership, royalty enforcement, marketplace readiness, or indexer readiness proof |
| 1/1 permanence | [`docs/permanence-packages.md`](../permanence-packages.md), [`release-artifacts/latest/one-of-one-permanence-manifest.json`](../../release-artifacts/latest/one-of-one-permanence-manifest.json), [`release-artifacts/schema/one-of-one-permanence-package.schema.json`](../../release-artifacts/schema/one-of-one-permanence-package.schema.json), [`release-artifacts/permanence/one-of-one-permanence-template.permanence.json`](../../release-artifacts/permanence/one-of-one-permanence-template.permanence.json) | Artifact-only collector-verifiable permanence package model for replay commands, renderer/dependency/source hashes, browser proof, output hashes, and fully on-chain versus decentralized storage boundaries |
| Royalty policy | [`docs/royalty-policy.md`](../royalty-policy.md), [`test/StreamRoyalty.t.sol`](../../test/StreamRoyalty.t.sol), [`smart-contracts/StreamCore.sol`](../../smart-contracts/StreamCore.sol), [`smart-contracts/IERC2981.sol`](../../smart-contracts/IERC2981.sol) | Current `ONE-003` ERC-2981 royalty disclosure, not payment enforcement; No production-readiness claim depends on marketplaces honoring royalties |
| Drop signing | [`docs/drop-authorization-signing.md`](../drop-authorization-signing.md) | EIP-712 and ERC-1271 local fixture guidance |
| Fixed-price mint flow | [`docs/integrations/contract-flows.md`](contract-flows.md) | Current `INT-002` transaction, event, credit, and failure-state guide |
| Auction flow | [`docs/integrations/auction-flows.md`](auction-flows.md) | Current `INT-003` auction submit, bid, settlement, credit, pause, and indexer guide |
| Curator rewards flow | [`docs/integrations/curator-rewards.md`](curator-rewards.md) | Current `INT-011` reward root, Merkle proof, delegated claim, pull-payment credit, withdrawal, failure-state, and indexer guide |
| Withdrawals and credits flow | [`docs/integrations/withdrawals-and-credits.md`](withdrawals-and-credits.md) | Current `INT-012` fixed-price, auction, curator, pull-payment, withdrawal, failure-state, surplus, mobile, Electron, and indexer guide |
| Wallet and signature guide | [`docs/integrations/wallets-and-signatures.md`](wallets-and-signatures.md) | Current `INT-004` EIP-712, ERC-1271, Safe, WalletConnect, backend signer, and failure-state guide |
| TypeScript EIP-712 payload snippets | [`docs/integrations/examples/typescript-eip712-drop-authorization.md`](examples/typescript-eip712-drop-authorization.md) | Current `INT-014` domain construction, `DropAuthorization` message shape, drop ID derivation, token data hashing, sale-mode validation, EOA/ERC-1271/Safe boundaries, submission preflight, and no-secret logging snippets |
| TypeScript event decoding snippets | [`docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md) | Current `INT-015` event topic catalog loading, topic0 dispatch, normalized log identity, confirmation depth, reorg rollback, read-after-event queue, idempotent ingestion, unknown emitter, unknown topic, and no-secret diagnostics snippets |
| Integration conformance fixtures | [`docs/integrations/integration-conformance-fixtures.md`](integration-conformance-fixtures.md), [`docs/integrations/fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json) | Current `INT-016` checked local fixture bundle for artifact loading, fail-closed chain config, EIP-712 domain expectations, event topic dispatch, normalized log identity, read-after-event queues, duplicate log idempotency, unknown emitter, unknown topic, reorg rollback, confirmation depth, and no-secret redaction diagnostics |
| Event and indexer guide | [`docs/integrations/events-and-indexing.md`](events-and-indexing.md) | Current `INT-005` event subscriptions, indexed entities, read-after-event calls, reorg policy, and known event/read gaps |
| Metadata rendering guide | [`docs/integrations/metadata-rendering.md`](metadata-rendering.md) | Current `INT-006` metadata state, tokenURI, ERC-4906 cache invalidation, animation sandbox, cache key, and marketplace evidence-boundary guide |
| Marketplace/indexer evidence guide | [`docs/integrations/marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md) | Current `ONE-005` retained marketplace/indexer evidence requirements for OpenSea, Reservoir, Blur, Manifold, equivalent collector/indexer tooling, contract metadata, token metadata refresh, animation rendering, royalty display, transfer/listing/sale paths, event replay, and cache invalidation |
| Contract metadata adapter | [`smart-contracts/StreamContractMetadata.sol`](../../smart-contracts/StreamContractMetadata.sol) | Release-tracked ERC-7572-style `contractURI()` adapter with `ContractURIUpdated` and URI hash views |
| Interface/version compatibility | [`docs/integrations/interface-versioning.md`](interface-versioning.md), [`smart-contracts/IStreamCompatibility.sol`](../../smart-contracts/IStreamCompatibility.sol), [`smart-contracts/StreamContractMetadata.sol`](../../smart-contracts/StreamContractMetadata.sol) | Current `CON-007` adapter-based protocol name, protocol version, metadata schema version, release tag/hash, and interface-probe guidance for fail-closed frontend compatibility checks |
| React/Next reference architecture | [`docs/integrations/frontend-reference-architecture.md`](frontend-reference-architecture.md) | Current `INT-007` artifact import, client layering, query/cache, transaction, wallet, metadata, indexer, environment, and testing guide |
| TypeScript artifact and chain config snippets | [`docs/integrations/examples/typescript-artifacts-and-chain-config.md`](examples/typescript-artifacts-and-chain-config.md) | Current `INT-013` release artifact loading, address book loading, deployment manifest cross-checks, release manifest hash validation, ABI checksum awareness, fail-closed chain config, and no-secret public environment snippets |
| Mobile and WalletConnect guide | [`docs/integrations/mobile-walletconnect.md`](mobile-walletconnect.md) | Current `INT-008` mobile browser, native shell, WalletConnect session, foreground handoff, deep-link, reconnect, offline/background, telemetry, and no-secret guide |
| Electron security and wallet guide | [`docs/integrations/electron-security-wallets.md`](electron-security-wallets.md) | Current `INT-009` Electron main/renderer/preload, context isolation, IPC allowlist, wallet-provider, metadata sandbox, signed-update, and no-secret guide |
| Operator admin UI guide | [`docs/integrations/operator-admin-ui.md`](operator-admin-ui.md) | Current `INT-010` operator personas, Safe/multisig ceremony, roles, signer lifecycle, pause domains, metadata freeze, dependency, randomizer, emergency, monitoring, and no-secret evidence guidance |
| Release signatures | [`docs/release-signatures.md`](../release-signatures.md) | No production signatures are committed |

## Canonical Artifacts

The table above is intentionally redundant with the links below so the checker
can prove the entrypoint keeps all required local targets reachable:

- [`README.md`](../../README.md)
- [`docs/release-readiness.md`](../release-readiness.md)
- [`docs/deployment.md`](../deployment.md)
- [`docs/drop-authorization-signing.md`](../drop-authorization-signing.md)
- [`docs/metadata.md`](../metadata.md)
- [`docs/provenance-manifests.md`](../provenance-manifests.md)
- [`docs/permanence-packages.md`](../permanence-packages.md)
- [`docs/royalty-policy.md`](../royalty-policy.md)
- [`docs/release-policy.md`](../release-policy.md)
- [`docs/release-signatures.md`](../release-signatures.md)
- [`docs/public-beta-evidence.md`](../public-beta-evidence.md)
- [`docs/non-local-release-evidence.md`](../non-local-release-evidence.md)
- [`docs/architecture.md`](../architecture.md)
- [`docs/threat-model.md`](../threat-model.md)
- [`docs/known-blockers.md`](../known-blockers.md)
- [`docs/integrations/contract-flows.md`](contract-flows.md)
- [`docs/integrations/auction-flows.md`](auction-flows.md)
- [`docs/integrations/curator-rewards.md`](curator-rewards.md)
- [`docs/integrations/withdrawals-and-credits.md`](withdrawals-and-credits.md)
- [`docs/integrations/wallets-and-signatures.md`](wallets-and-signatures.md)
- [`docs/integrations/events-and-indexing.md`](events-and-indexing.md)
- [`docs/integrations/metadata-rendering.md`](metadata-rendering.md)
- [`docs/integrations/marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md)
- [`docs/integrations/interface-versioning.md`](interface-versioning.md)
- [`docs/integrations/frontend-reference-architecture.md`](frontend-reference-architecture.md)
- [`docs/integrations/integration-conformance-fixtures.md`](integration-conformance-fixtures.md)
- [`docs/integrations/fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json)
- [`docs/integrations/examples/typescript-artifacts-and-chain-config.md`](examples/typescript-artifacts-and-chain-config.md)
- [`docs/integrations/examples/typescript-eip712-drop-authorization.md`](examples/typescript-eip712-drop-authorization.md)
- [`docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md)
- [`docs/integrations/mobile-walletconnect.md`](mobile-walletconnect.md)
- [`docs/integrations/electron-security-wallets.md`](electron-security-wallets.md)
- [`docs/integrations/operator-admin-ui.md`](operator-admin-ui.md)
- [`docs/integrations/examples/react-viem.md`](examples/react-viem.md)
- [`release-artifacts/README.md`](../../release-artifacts/README.md)
- [`release-artifacts/contracts.json`](../../release-artifacts/contracts.json)
- [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../../release-artifacts/baselines/v0.1.0/abi-surface.json)
- [`release-artifacts/latest/abi-checksums.json`](../../release-artifacts/latest/abi-checksums.json)
- [`release-artifacts/latest/protocol-surface-report.json`](../../release-artifacts/latest/protocol-surface-report.json)
- [`release-artifacts/latest/release-artifact-manifest.json`](../../release-artifacts/latest/release-artifact-manifest.json)
- [`release-artifacts/latest/release-manifest.json`](../../release-artifacts/latest/release-manifest.json)
- [`release-artifacts/latest/bytecode-release-proof.json`](../../release-artifacts/latest/bytecode-release-proof.json)
- [`release-artifacts/latest/SHA256SUMS`](../../release-artifacts/latest/SHA256SUMS)
- [`release-artifacts/latest/release-checksums.json`](../../release-artifacts/latest/release-checksums.json)
- [`release-artifacts/latest/source-verification-inputs.json`](../../release-artifacts/latest/source-verification-inputs.json)
- [`release-artifacts/latest/event-topic-catalog.json`](../../release-artifacts/latest/event-topic-catalog.json)
- [`release-artifacts/latest/interface-ids.json`](../../release-artifacts/latest/interface-ids.json)
- [`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json)
- [`release-artifacts/latest/risk-register.json`](../../release-artifacts/latest/risk-register.json)
- [`release-artifacts/latest/one-of-one-provenance-manifest.json`](../../release-artifacts/latest/one-of-one-provenance-manifest.json)
- [`release-artifacts/schema/one-of-one-provenance-manifest.schema.json`](../../release-artifacts/schema/one-of-one-provenance-manifest.schema.json)
- [`release-artifacts/provenance/one-of-one-provenance-template.provenance.json`](../../release-artifacts/provenance/one-of-one-provenance-template.provenance.json)
- [`release-artifacts/latest/one-of-one-permanence-manifest.json`](../../release-artifacts/latest/one-of-one-permanence-manifest.json)
- [`release-artifacts/schema/one-of-one-permanence-package.schema.json`](../../release-artifacts/schema/one-of-one-permanence-package.schema.json)
- [`release-artifacts/permanence/one-of-one-permanence-template.permanence.json`](../../release-artifacts/permanence/one-of-one-permanence-template.permanence.json)
- [`deployments/README.md`](../../deployments/README.md)
- [`deployments/schema/deployment-manifest.schema.json`](../../deployments/schema/deployment-manifest.schema.json)
- [`deployments/schema/address-book.schema.json`](../../deployments/schema/address-book.schema.json)
- [`deployments/config/sepolia-6529stream-v0.1.0-001.template.json`](../../deployments/config/sepolia-6529stream-v0.1.0-001.template.json)
- [`deployments/address-books/anvil-6529stream-v0.1.0-001.json`](../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [`deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json)
- [`deployments/examples/anvil-6529stream-v0.1.0-001.json`](../../deployments/examples/anvil-6529stream-v0.1.0-001.json)
- [`deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json`](../../deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json)

## Integration Flows

This file is an entrypoint, not the complete flow book. Use these backlog items
to understand what is still intentionally future work:

- `INT-002`: fixed-price mint and drop authorization flow spec is now
  [`contract-flows.md`](contract-flows.md).
- `INT-003`: auction frontend and indexer flow spec is now
  [`auction-flows.md`](auction-flows.md).
- `INT-004`: wallet, EIP-712, ERC-1271, and Safe signing guide is now
  [`wallets-and-signatures.md`](wallets-and-signatures.md).
- `INT-005`: event and indexer reconstruction spec is now
  [`events-and-indexing.md`](events-and-indexing.md).
- `INT-006`: the metadata rendering, cache, animation sandbox, and marketplace
  integration guide is now [`metadata-rendering.md`](metadata-rendering.md).
- `CON-007`: interface and version views for frontend compatibility are now
  documented in [`interface-versioning.md`](interface-versioning.md), using the
  release-tracked `IStreamCompatibility` adapter surface on
  `StreamContractMetadata`.
- `INT-007`: the React/Next frontend reference architecture is now
  [`frontend-reference-architecture.md`](frontend-reference-architecture.md),
  with pseudocode examples in
  [`examples/react-viem.md`](examples/react-viem.md).
- `INT-013`: the TypeScript snippets for artifact loading and chain config are
  now
  [`examples/typescript-artifacts-and-chain-config.md`](examples/typescript-artifacts-and-chain-config.md),
  covering release artifact loading, address book loading, deployment manifest
  checks, release manifest hash validation, ABI checksum awareness,
  fail-closed chain config, wrong-chain guards, and no-secret public env
  parsing.
- `INT-014`: the TypeScript EIP-712 payload construction snippets are now
  [`examples/typescript-eip712-drop-authorization.md`](examples/typescript-eip712-drop-authorization.md),
  covering domain construction, DropAuthorization message shape, drop ID
  derivation, token data hashing, sale-mode validation, EOA/ERC-1271/Safe
  boundaries, submission preflight, and no-secret logging.
- `INT-015`: the TypeScript event decoding and indexer ingestion snippets are
  now
  [`examples/typescript-event-decoding-and-indexer-ingestion.md`](examples/typescript-event-decoding-and-indexer-ingestion.md),
  covering event topic catalog loading, topic0 dispatch, normalized log
  identity, confirmation depth, reorg rollback, read-after-event queue,
  idempotent ingestion, unknown emitter, unknown topic handling, and no-secret
  diagnostics.
- `INT-016`: the integration conformance fixtures are now
  [`integration-conformance-fixtures.md`](integration-conformance-fixtures.md)
  and
  [`fixtures/integration-conformance-fixtures.json`](fixtures/integration-conformance-fixtures.json),
  covering artifact loading, fail-closed chain config, EIP-712 domain
  expectations, event topic dispatch, normalized log identity,
  read-after-event queues, duplicate log idempotency, confirmation depth,
  reorg rollback, unknown emitter, unknown topic, and no-secret redaction
  diagnostics.
- `INT-008`: the mobile and WalletConnect integration guide is now
  [`mobile-walletconnect.md`](mobile-walletconnect.md).
- `INT-009`: the Electron security and wallet integration guide is now
  [`electron-security-wallets.md`](electron-security-wallets.md).
- `INT-010`: the operator admin UI specification is now
  [`operator-admin-ui.md`](operator-admin-ui.md).
- `INT-011`: the curator rewards frontend flow spec is now
  [`curator-rewards.md`](curator-rewards.md).
- `INT-012`: the withdrawal and credit UX flow spec is now
  [`withdrawals-and-credits.md`](withdrawals-and-credits.md).
- `ONE-003`: the royalty policy is now
  [`docs/royalty-policy.md`](../royalty-policy.md), recording the current
  ERC-2981 royalty disclosure, not payment enforcement boundary.
- `ONE-004`: the collector-verifiable permanence package is now
  [`docs/permanence-packages.md`](../permanence-packages.md), recording the
  artifact-only one-of-one permanence manifest, replay commands, browser proof,
  output hashes, and fully on-chain versus decentralized storage boundaries.
- `ONE-005`: the retained marketplace/indexer evidence guide is now
  [`marketplace-indexer-evidence.md`](marketplace-indexer-evidence.md),
  recording the fork/testnet/live evidence model for contract metadata,
  token metadata refresh, animation rendering, royalty display,
  transfer/listing/sale paths, event replay, cache invalidation, and platform
  coverage across OpenSea, Reservoir, Blur, Manifold, or equivalent
  collector/indexer tooling.

Until the remaining specs exist, integrators should treat the linked artifacts
as source material and the existing tests/docs as examples, not as a finished
SDK or frontend contract.

## Readiness Boundaries

Do not use local artifacts as public beta or production approval. In
particular:

- Address books currently cover local Anvil and retained fork-mainnet rehearsal
  examples, not a reviewed Sepolia or production deployment.
- Source verification inputs are local inputs, not live explorer verification.
- `bytecode-release-proof.json` proves committed local/fork artifact
  consistency, not live chain bytecode.
- Signing and signer custody docs are no-secret templates or local fixtures,
  not reviewed production signing evidence.
- Metadata/browser checks and the `INT-006` guide are local evidence, not
  marketplace or collector-tool proof.
- `ONE-005` retained marketplace/indexer templates are template-only and are
  not release readiness proof until reviewed fork/testnet/live evidence is
  linked from the shared evidence status manifest.
- The 1/1 provenance manifest is a checked release-artifact model for
  artist/story/authenticity context, not a tokenURI finality signal,
  marketplace discovery claim, royalty enforcement mechanism, or ownership
  proof beyond chain state.
- The collector-verifiable permanence package is a checked release-artifact
  model for replay commands, renderer/dependency/source hashes, browser proof,
  output hashes, and fully on-chain versus decentralized storage boundaries,
  not final-drop completion evidence until reviewed non-local or final package
  artifacts exist.
- The royalty policy is a checked local governance/integration document for
  ERC-2981 royalty disclosure, not payment enforcement. No
  production-readiness claim depends on marketplaces honoring royalties.
- The `INT-007` React/Next guide is a local architecture reference, not a
  maintained frontend package, generated SDK, public beta implementation, or
  production integration proof.
- The `INT-008` mobile and WalletConnect guide is a local integration
  reference, not a maintained mobile SDK, React Native app, WalletConnect
  dependency recommendation, public beta implementation, or production
  integration proof.
- The `INT-009` Electron security and wallet guide is a local integration
  reference, not a maintained Electron app, native desktop app, desktop SDK,
  code-signing implementation, signed-update implementation, public beta
  implementation, or production integration proof.
- The `INT-010` operator admin UI guide is a local integration reference, not a
  maintained operator dashboard, Safe app, multisig transaction builder,
  monitoring service, production signer custody implementation, public beta
  implementation, or production integration proof.
- Indexer teams still need retained non-local event replay and metadata refresh
  evidence before relying on production reconstruction.

## Validation Commands

Run the focused entrypoint checks before editing integration docs:

```sh
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_auction_flows.py
python scripts/check_auction_flows.py
python scripts/test_curator_rewards_flow.py
python scripts/check_curator_rewards_flow.py
python scripts/test_withdrawals_credits_flow.py
python scripts/check_withdrawals_credits_flow.py
python scripts/test_wallet_signature_flows.py
python scripts/check_wallet_signature_flows.py
python scripts/test_events_and_indexing.py
python scripts/check_events_and_indexing.py
python scripts/test_metadata_rendering.py
python scripts/check_metadata_rendering.py
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/test_one_of_one_provenance_manifest.py
python scripts/check_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_provenance_manifest.py --check
python scripts/test_one_of_one_permanence_package.py
python scripts/check_one_of_one_permanence_package.py
python scripts/generate_one_of_one_permanence_manifest.py --check
python scripts/test_royalty_policy.py
python scripts/check_royalty_policy.py
python scripts/test_react_next_reference.py
python scripts/check_react_next_reference.py
python scripts/test_typescript_artifact_chain_config.py
python scripts/check_typescript_artifact_chain_config.py
python scripts/test_typescript_eip712_drop_authorization.py
python scripts/check_typescript_eip712_drop_authorization.py
python scripts/test_typescript_event_decoding_indexer.py
python scripts/check_typescript_event_decoding_indexer.py
python scripts/test_integration_conformance_fixtures.py
python scripts/check_integration_conformance_fixtures.py
python scripts/test_mobile_walletconnect.py
python scripts/check_mobile_walletconnect.py
python scripts/test_electron_security_wallets.py
python scripts/check_electron_security_wallets.py
python scripts/test_operator_admin_ui.py
python scripts/check_operator_admin_ui.py
python scripts/check_release_readiness.py
python scripts/check_changelog.py
```

For full local release-readiness verification, run the repo check wrapper from
the root after installing Foundry and Python dependencies:

```sh
make check
```

## Maintenance

Update this file when any of the following change:

- Canonical release, deployment, address-book, event, interface, ABI, or
  checksum artifact names.
- Public-beta or production readiness status.
- Integration flow docs under future `INT` work.
- Signing, metadata, royalty policy, deployment, or release policy docs that
  frontend and indexer teams depend on.

Keep this page conservative. It should help integrators start quickly without
weakening the repo's pre-audit and not-production-ready boundary.
