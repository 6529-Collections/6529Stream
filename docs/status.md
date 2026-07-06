# Project Status

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.


6529Stream is pre-audit and not production-ready.

The current Gate A smoke baseline proves:

- The checked fresh-contributor path in
  [`docs/first-30-minutes.md`](first-30-minutes.md) covers pinned tool
  expectations, `forge` not being on `PATH`, Windows PowerShell wrapper usage,
  known warning noise, generated artifact drift, docs-only paths, Solidity/test
  paths, and no-secret maturity boundaries.
- The checked GitHub issue-template surface captures integration reports,
  public-safe audit finding intake, and release evidence requests while
  preserving pre-audit, not-production-ready, no-secret, and private security
  reporting boundaries.
- The checked PR-template surface requires roadmap/gate linkage, validation
  evidence, release-impact classification, generated-artifact impact, and
  breaking-change approval references before review.
- Foundry is configured to compile `smart-contracts`.
- `forge build` runs against Solidity `0.8.19`.
- `forge build --sizes --via-ir --skip test --skip script --force` runs as the production
  size gate. `python scripts/check_contract_size_budget.py` checks every
  production contract against EIP-170 and enforces the configured `StreamCore`
  release floor from `release-artifacts/contracts.json`. The committed
  `release-artifacts/latest/bytecode-release-proof.json` records the current
  measured `StreamCore` production runtime size as 24,111 bytes, leaving
  465 bytes of EIP-170
  headroom under the IR-optimized deployment profile. This passes the EIP-170
  deployability gate and the current 384-byte minimum release floor, but it is
  below the 512-byte warning threshold under the accepted CON-012
  bytecode-spend exception; large non-trivial `StreamCore` feature work should
  still measure bytecode deltas and explicitly accept any size-budget exception.
  The stricter bytecode-spend ceiling remains the reviewed 22,184-byte approved
  baseline with 2,392 bytes of baseline margin.
  The architecture policy in
  [`docs/architecture.md#product-extension-and-size-budget-policy`](architecture.md#product-extension-and-size-budget-policy)
  makes future collector/product surfaces satellite-first by default through
  satellite contracts, read adapters, linked libraries, release artifacts, or
  documentation-only evidence unless Core ownership/security invariants require
  otherwise.
- `python scripts/test_solidity_formatting.py` and
  `python scripts/check_solidity_formatting.py` enforce the scoped Solidity
  formatting policy: 34 formatting-required first-party/provider files pass
  `forge fmt --check`, and the raw all-files diagnostic is allowed to fail
  only for the 17 documented vendored/provenance formatting exemptions.
- `python scripts/test_warning_dispositions.py`,
  `python scripts/run_forge_size_log.py --log cache/forge-size.log`, and
  `python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log` enforce the checked warning
  disposition baseline in
  [`docs/warning-dispositions.md`](warning-dispositions.md). That baseline
  records fixed NatSpec warning cleanup and accepted solc, documentation,
  linter, vendored, test-only, ABI-compatibility, and `StreamCore`
  size-tradeoff warning rows without treating warning quietness as protocol
  correctness proof.
- `python scripts/test_natspec_coverage.py` and
  `python scripts/check_natspec_coverage.py` enforce the checked NatSpec
  coverage baseline in [`docs/natspec-coverage.md`](natspec-coverage.md) and
  `release-artifacts/baselines/v0.1.0/natspec-coverage.json`. The current
  baseline is a burn-down queue for missing release-surface NatSpec, not proof
  that API documentation is complete.
- `forge test -vvv` executes real tests for admin guards, target-scoped
  function-admin permission regressions, domain-scoped pause controls,
  signer-manager lifecycle controls with approved targets, EIP-712 and ERC-1271
  drop authorization,
  auction custody and payment credits, fixed-price pull-payment credits,
  curator reward claim credits, and randomness lifecycle behavior. Current
  emergency-withdrawal target-state tests also cover explicit emergency
  recipients, `StreamMinter` surplus withdrawal, `NextGenRandomizerRNG` reserve
  boundaries, request-level randomizer reserve lifecycle accounting,
  dependency-script segment-safe content hashing, explicit
  local-initialization regressions, vendored OpenZeppelin utility-library
  provenance/behavior regressions, and retained airdrop mint-accounting
  behavior after removal of dead public/allowlist counters.
- Focused randomizer reserve lifecycle tests now cover arRNG request-cost
  spending, multiple pending requests, fulfilled requests, stale requests,
  failed post-processing, deterministic retry, forced ETH, and unauthorized
  emergency-withdrawal attempts while proving remaining provider reserves stay
  represented by `totalRandomnessReserved()`, `totalOwed()`, and
  `totalReserved()` with zero emergency-withdrawable surplus.
- Randomizer operations evidence now has a schema, local Anvil evidence bundle,
  and local/CI checker. The local bundle records deployed adapter addresses,
  placeholder provider addresses, provider epochs, local funding status,
  lifecycle-control evidence, reserve-accounting evidence, retained artifacts,
  and redaction policy. Fork/testnet/live provider funding and request-health
  evidence remains future Gate E release work.
- Payment sequence fuzzing now covers mixed fixed-price mint, auction bid,
  auction settlement, curator claim, withdrawal, emergency withdrawal,
  randomizer reserve, and forced-balance operations, proving the current local
  ledgers keep category totals, owed totals, balance coverage, reserves, and
  emergency-withdrawable surplus coherent after each step. Current value-holding
  payment surfaces also expose ADR-style local-ledger aliases for reserved
  balances and surplus where applicable.
- Supply/replay/freeze sequence fuzzing now covers mixed fixed-price mints,
  drop cancellations, consumed-drop replay attempts, cancelled-drop mint
  attempts, burns, metadata edits, freeze attempts, stored freeze-manifest
  stability, final-supply tightening, and post-freeze mint/burn/token-data
  rejection. The invariant reasserts global and collection live supply,
  minted-ever counters, burn counters, burn audit state, and
  consumed/cancelled drop ID state after each step.
- Auction consistency sequence fuzzing now covers mixed signed auction-drop
  registration, escrow custody, cancellation, first bids, higher outbids,
  underbid and late-bid rejection, no-bid and with-bid settlement, repeat
  settlement attempts, bidder/proceeds withdrawals, emergency surplus, and
  forced-balance operations. The invariant reasserts known token custody,
  active highest-bid escrow, previous-bidder credits, settlement proceeds
  credits, terminal ownership, failed invalid-operation preservation, and
  auction-local `totalOwed()`/`totalReserved()`/`surplus()` view coherence
  after each step.
- Randomizer tests now cover request lifecycle views, callback validation,
  raw-output hash storage, failed post-processing state, bounded deterministic
  post-processing retry, and the conservative provider-migration policy that
  blocks lifecycle-aware provider replacement while collection requests are
  pending. They also prove `RandomizerNXT` cannot be configured as a
  production randomizer after removal of the concrete weak `XRandoms` helper
  from production source.
- Randomizer/admin stateful coverage now composes arRNG reserve funding, request
  costs, unique token requests, fulfillment, stale marking, failed
  post-processing, retry success/failure, provider and epoch replacement
  attempts, randomness-request pauses, token-collection drift, and
  emergency-withdrawal calls in bounded generated sequences while reasserting
  lifecycle indexes, pending counters, terminal request fields, retry limits,
  core token hashes, and zero-surplus reserve views. This is local adversarial
  coverage only; fork/testnet/live provider operations evidence remains future
  release work.
- Auction/drop/arRNG composition tests now execute signed auction drops through
  the real drop, auction, core, and arRNG contracts, proving randomness-request
  pauses roll back drop execution without consuming the authorization, pending
  arRNG requests block randomizer migration without auction drift, and auction
  settlement before fulfillment preserves winner custody, credits, total owed
  values, and token/request binding after later fulfillment. This remains local
  adversarial coverage only; it does not replace fork/testnet/live provider
  operations evidence.
- The same auction/drop/arRNG composition suite now covers post-execution signer
  lifecycle controls: signer-epoch invalidation, signer rotation, replay
  attempts, consumed-drop cancellation attempts, and drop-execution pauses after
  auction creation leave existing auction custody, bid accounting, pending
  request bindings, settlement, and later arRNG fulfillment coherent. This
  remains local adversarial coverage and does not replace production signer,
  Safe, or provider operations evidence.
- The auction/drop/arRNG composition suite now covers no-bid and
  cancellation-like terminal paths: no-bid settlement before fulfillment,
  contract-poster pending no-bid claims, pre-bid auction cancellation,
  cancelled signed auction authorizations, and rejected terminal repeats preserve
  custody or claimant state, zero-accounting boundaries, pending request
  bindings, and later arRNG fulfillment. This remains local adversarial coverage
  and does not replace fork/testnet/live provider operations evidence.
- Fixed-price/drop/arRNG composition tests now execute paid fixed-price drops
  through the real drop, minter, core, and arRNG contracts, proving
  randomness-request pauses roll back drop execution without consuming the
  authorization or crediting payments, post-execution signer lifecycle controls
  do not disturb fixed-price credits or pending request bindings, and
  poster/protocol withdrawals before arRNG fulfillment do not break later
  fulfillment. This remains local adversarial coverage and does not replace
  production signer, Safe, or provider operations evidence.
- Fixed-price and auction arRNG request-ID collision tests now force a reused
  provider request ID through the public signed-drop paths, proving the second
  drop reverts with `RandomnessRequestAlreadyExists` without consuming the
  authorization, minting or registering a token, changing supply or drop
  counts, creating payment credits or auction state, changing pending request
  accounting, or breaking fulfillment of the first token's request. This
  remains local adversarial coverage and does not replace fork/testnet/live
  provider operations evidence.
- Burned pending arRNG composition tests now cover paid fixed-price and settled
  auction drops that burn before fulfillment, proving payment/proceeds
  accounting, consumed-drop state, request bindings, burned-token audit
  randomness, no-metadata-update fulfillment, freeze eligibility, and frozen
  manifest stability remain coherent. This remains local adversarial coverage
  and does not replace fork/testnet/live provider operations evidence.
- Metadata tests now prove dependency chunk boundaries are included in typed
  content hashes while preserving the existing rendered generative script
  output. `StreamDependencyRegistry.t.sol` proves immutable dependency version
  records, provenance/deprecation views, collection dependency
  key/version/content-hash/registry-address pins, explicit repinning, and
  output stability after later registry versions or registry swaps.
  `StreamMetadataGolden.t.sol` locks current off-chain pending/stale/failed/final
  URIs plus schema-v1 on-chain pending/stale/failed/final base64 JSON data URIs
  against fixtures. The on-chain schema exposes `metadata_schema_version` and
  `metadata_state`; pending, stale, and failed metadata omit final animation
  HTML while the token hash remains zero; lifecycle lookup failures fall back to
  `pending`; and final token hashes override lifecycle display state.
  `StreamMetadataEvents.t.sol` proves ERC-4906 interface support and
  current metadata update event semantics for token-level updates, and it now
  proves optional ERC-721 Enumerable support is not advertised while the
  contract preserves a live `totalSupply()` view.
  collection-range updates, randomness fulfillment, mint-only paths, and burn.
  `StreamMetadataFreeze.t.sol` proves the current collection freeze boundary:
  ended mint window, elapsed final-supply delay, ADR 0006 rejection of live
  tokens whose randomness remains pending, stale, or failed instead of final,
  stored manifest hash/event, final supply tightening, and post-freeze rejection
  for current `StreamCore` metadata-significant mutation paths.
  `StreamCoreBurn.t.sol` proves burn metadata semantics: burned tokens lose
  ownership and `tokenURI` availability, emit protocol burn audit events, retain
  audit state, exclude burned supply from live collection supply, reject remint
  attempts for previously burned token IDs, and allow valid VRF/arRNG post-burn
  fulfillment to record audit-only randomness without ERC-4906 metadata updates
  or freeze-manifest changes. `StreamMetadataEscaping.t.sol` proves the current
  on-chain JSON string escaping and raw attribute schema guard: escaped
  collection/image fields decode to parseable JSON, brackets inside quoted
  attribute values remain valid, valid JSON string escapes are accepted, and
  breakout/control-character/unterminated/malformed semantic attribute fragments
  revert. It also decodes final animation HTML and proves the wrapper escapes
  the external library attribute, embeds `tokenData` and dependency script
  content through escaped JavaScript strings, and neutralizes closing-script
  sequences so hostile metadata inputs do not create extra raw wrapper
  `</script>` tags. `StreamMetadataSizeLimits.t.sol` proves byte caps
  for collection display fields, collection script chunks and counts, token
  data, token images, token raw attributes, generated `tokenURI` output,
  dependency script chunks and counts, and dependency provenance strings.
  `StreamMetadataUriPolicy.t.sol` proves the renderer content/script URI
  policy helpers and the production URI guards for allowed `https://`,
  `ipfs://`, and `ar://` content URIs plus rejected empty required token image
  URIs, JavaScript, hostless HTTPS, whitespace-bearing token image/base URI
  inputs, and non-HTTPS external library URLs.
  `StreamMetadataUtf8.t.sol` proves the shared strict UTF-8 scanner accepts
  valid ASCII and multibyte sequences, rejects invalid lead/continuation,
  overlong, surrogate, out-of-range, and truncated sequences; enforces that
  `DependencyRegistry` rejects invalid UTF-8 dependency scripts/provenance;
  and enforces that `StreamCore` rejects invalid UTF-8 collection fields,
  collection script chunks, token data, token image URIs, and token raw
  attributes while preserving size-before-UTF-8 error ordering.
  `StreamRandomizerLifecycle.t.sol` also proves unsupported lifecycle providers
  do not block randomizer migration, while lifecycle-aware providers whose
  pending-request probe fails still block replacement.
  `StreamCoreCustomErrors.t.sol` proves the typed failure selectors used to
  recover `StreamCore` bytecode headroom for function-admin authorization,
  artist-signature authorization, metadata-array length validation, and
  final-supply timing, plus missing collection data rejection before final
  supply math and the compact `TokenNotMinted()` selector used by Core metadata
  views.
  `scripts/test_metadata_fixtures.py` and
  `scripts/check_metadata_fixtures.py` validate the committed metadata golden
  fixtures outside Foundry by strictly decoding JSON and HTML data URIs,
  parsing metadata JSON, rejecting invalid UTF-8 fixture payloads, validating
  semantic attribute shape, checking current URI scheme policy, and asserting
  the generated final animation wrapper has exactly the expected script
  boundaries.
  `scripts/test_metadata_browser_sandbox.py` and
  `scripts/check_metadata_browser_sandbox.py` execute the committed final
  on-chain animation fixture in Chromium inside a sandboxed iframe, serve the
  expected external dependency through a deterministic stub, fail unexpected
  outbound HTTP(S) requests, assert the bootstrap values, capture page/console
  errors, and prove parent-document access is blocked.
  `scripts/test_rehearsal_metadata_browser_sandbox.py` and
  `scripts/check_rehearsal_metadata_browser_sandbox.py` execute metadata
  generated by a local deployment rehearsal: the Forge script deploys the local
  stack, mints through the EIP-712 drop authorization path, finalizes
  randomness/image/attribute inputs, returns the generated on-chain `tokenURI`,
  and the Python checker runs that generated final animation through the same
  Chromium sandbox policy.
- `StreamDeploymentManifest.t.sol` proves the first Gate E local deployment
  rehearsal can deploy and wire the stack, configure sample admin/pause/signer
  ceremony state, transfer Ownable control to the configured Safe placeholder,
  revoke the temporary deployment admin, parse the deployment manifest
  schema/example JSON artifacts, and run a local auction ceremony from signed
  auction drop through active auction custody, bid escrow, with-bid settlement,
  poster/protocol/curator proceeds withdrawals, and zero owed funds. It also
  proves a local emergency redeployment rehearsal with distinct
  old/replacement deployment versions, manifests, drop EIP-712 domains, core,
  drops, and auction addresses, Safe-rooted admin ceremony state on both
  deployments, temporary deployer-admin removal, and a replacement fixed-price
  mint smoke path. The suite-level test proves
  `script/RehearseDeploymentSuite.s.sol` returns deployment, auction, and
  emergency result groups plus a combined suite hash.
- `forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir`
  executes the three local rehearsal flows as an aggregate suite-level evidence
  command. The local/CI smoke gate also runs the three standalone `forge script`
  entrypoints, keeping the original script execution contexts automated while
  retaining one combined suite result for release-gate review.
- `scripts/test_deployment_rehearsal_gate.py` and
  `scripts/check_deployment_rehearsal_gate.py` statically guard the aggregate
  suite command, all three standalone rehearsal commands, and the CI retained
  log names across Make, Bash, PowerShell, and CI before the Forge rehearsal
  scripts execute. This is wiring-parity evidence for the local gate, not
  fork, testnet, or live deployment evidence.
- `scripts/test_release_artifacts.py` and
  `scripts/generate_release_artifacts.py --check` prove the committed
  `release-artifacts/latest/` baseline matches current Foundry ABI/event output,
  including ABI checksums, bytecode checksums, standard/custom interface IDs,
  and event topic catalog entries.
- `scripts/test_protocol_surface_report.py` and
  `scripts/generate_protocol_surface_report.py --check` prove the committed
  `release-artifacts/latest/protocol-surface-report.json` matches the current
  production Foundry artifacts for functions, selectors, events, topic0 values,
  custom errors, ABI hashes, bytecode hashes, and runtime sizes.
- `scripts/test_source_verification_inputs.py` and
  `scripts/generate_source_verification_inputs.py --check` prove the committed
  `release-artifacts/latest/source-verification-inputs.json` retains production
  contract source hashes, compiler settings, constructor ABI, bytecode/linking
  status, and verification command templates from the current Foundry artifacts.
- `scripts/test_dependency_artifact_manifest.py` and
  `scripts/generate_dependency_artifact_manifest.py --check` prove committed
  dependency artifact descriptors under `release-artifacts/dependencies/`
  resolve only to packaged dependency files, reject malformed keys and duplicate
  identities, and keep
  `release-artifacts/latest/dependency-artifact-manifest.json` current.
- `docs/dependency-operations.md` documents the production dependency ceremony:
  proposal, review, source packaging, registry registration, unfrozen
  collection repinning, deprecation, rollback by corrective version, frozen
  collection immutability, and source-retention evidence.
- `scripts/test_abi_compatibility.py` and
  `scripts/check_abi_compatibility.py --check` prove the current production
  contract and published interface ABI surfaces remain compatible with the
  committed `release-artifacts/baselines/v0.1.0/abi-surface.json` baseline.
  The first baseline fails on removed or changed functions, events, custom
  errors, constructors, fallback, or receive entries and reports additive
  entries as compatible.
- `scripts/test_broadcast_manifest_input.py` and
  `scripts/generate_broadcast_manifest_input.py --check` prove the sanitized
  Foundry broadcast fixture maps exactly to the expected Anvil deployment
  contract set, chain ID, transaction hashes, successful receipts, and
  non-duplicate deployed addresses without committing secret-like keys.
- `scripts/test_deployment_manifest.py` and
  `scripts/generate_deployment_manifest.py --check` prove the local Anvil
  placeholder manifest is generated from committed inputs, references current
  ABI/runtime bytecode hashes, and carries a deterministic manifest checksum.
  The same generator also checks the sanitized broadcast-derived manifest input
  with `--config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json`.
- `scripts/test_address_books.py` and
  `scripts/generate_address_books.py --check` prove the generated local Anvil
  address books are compact, deterministic projections of the committed
  placeholder and broadcast-derived deployment manifests plus release artifact
  contract metadata.
- `scripts/test_ceremony_evidence.py` and
  `scripts/check_ceremony_evidence.py` prove the committed no-secret local
  Anvil ceremony evidence bundle follows
  `deployments/schema/ceremony-evidence.schema.json`, references existing
  deployment manifests, address books, checksum inputs, rehearsal scripts, and
  verification status by SHA-256, rejects stale file hashes and secret-like
  keys, and reserves fork/testnet/live retained evidence contents for later
  Gate E ceremonies.
- `scripts/test_release_manifest.py` and
  `scripts/generate_release_manifest.py --check` prove the generated top-level
  release manifest ties the release artifact catalog, dependency artifact
  manifest, ABI compatibility baseline, deployment manifests, address books,
  ceremony evidence, public-beta evidence status, schemas, changelog,
  governance docs, and unavailable release-ceremony outputs together without
  drift.
- `scripts/test_release_checksums.py` and
  `scripts/generate_release_checksums.py --check` prove the committed
  `release-artifacts/latest/SHA256SUMS` and
  `release-artifacts/latest/release-checksums.json` bundle covers the current
  release artifact, dependency artifact source, broadcast fixture, deployment
  manifest, address-book, config, schema, public-beta evidence status, and
  release-manifest files.
- `scripts/test_markdown_links.py` and `scripts/check_markdown_links.py` prove
  the contributor, docs, ops, GitHub template, and release-artifact Markdown
  surfaces do not contain stale local file links, missing heading anchors,
  duplicate-anchor drift, repository escapes, or invalid line anchors.
- `scripts/test_release_signatures.py` and
  `scripts/check_release_signatures.py` prove the committed no-secret local
  release signature evidence follows
  `release-artifacts/schema/release-signature-evidence.schema.json`, records
  the self-referential release manifest/checksum bundle boundary, rejects
  stale retained hashes, symlinked evidence refs, and secret-like values, and
  reserves production detached checksum signatures, signed Git tags, signer
  identity, and verification output for public release ceremonies.
- `scripts/test_non_local_release_evidence.py`,
  `scripts/check_non_local_release_evidence.py`,
  `scripts/test_marketplace_indexer_evidence.py`, and
  `scripts/check_marketplace_indexer_evidence.py` fail future reviewed
  release evidence closed unless generic non-local retained artifacts,
  marketplace/indexer evidence envelopes, and retained Markdown references are
  ordinary repo-relative files, not symlinked files or files reached through
  symlinked directories.
- `scripts/test_drop_authorization_signing_evidence.py` and
  `scripts/check_drop_authorization_signing_evidence.py` prove the committed
  no-secret drop authorization signing evidence template follows
  `release-artifacts/schema/drop-authorization-signing-evidence.schema.json`,
  ties retained signing ceremony metadata to a generated unsigned EIP-712
  payload, validates domain/message/digest fields, signer epoch, reviewer and
  signature metadata, retained artifact hashes, and path boundaries, and keeps
  production signing evidence blocked until reviewed non-local evidence exists.
- `scripts/test_signer_custody_readiness.py` and
  `scripts/check_signer_custody_readiness.py` prove the committed no-secret
  signer custody readiness template follows
  `release-artifacts/schema/signer-custody-readiness.schema.json`, validates
  custody owner, signer manager, signer epoch source, signer-service class,
  ERC-1271 support status, rotation/revocation readiness, monitoring/runbook
  references, reviewer metadata, retained artifact hashes, path boundaries, and
  no-secret policy, and keeps public-beta readiness blocked until reviewed
  non-local custody evidence exists.
- `scripts/test_live_deployment_manifest_evidence.py` and
  `scripts/check_live_deployment_manifest_evidence.py` prove the committed
  template for future `live_deployment_manifest` evidence is public-safe and
  fail future pending/reviewed evidence closed unless retained manifest files
  are live mainnet chain ID 1, have finalized nonzero contract addresses,
  retain bytecode hashes and constructor arguments, agree with the retained
  address book, avoid symlinked retained files, avoid symlinked retained-file
  directories and secret-shaped content, and match optional declared `sha256:`
  digests. Issue #227 remains open until real reviewed live manifest evidence
  is retained.
- `scripts/test_live_metadata_browser_evidence.py`,
  `scripts/check_live_metadata_browser_evidence.py`,
  `scripts/test_production_broadcast_retention.py`, and
  `scripts/check_production_broadcast_retention.py` share the retained-path
  resolver with the other release evidence checkers so future pending/reviewed
  live metadata-browser and production broadcast retention evidence cannot
  reference symlinked leaf files or files reached through symlinked
  directories. Issues #473 and #226 remain open until real reviewed evidence is
  retained.
- `scripts/test_testnet_deployment_rehearsal_evidence.py` and
  `scripts/check_testnet_deployment_rehearsal_evidence.py` fail future
  pending/reviewed Sepolia deployment rehearsal evidence closed unless retained
  transcript, broadcast, manifest, address-book, and gas/invariant files are
  ordinary repo-relative files, not symlinked files, and remain no-secret. Issue
  #217 remains open until real reviewed testnet deployment evidence is retained.
- `scripts/test_public_beta_evidence.py` and
  `scripts/check_public_beta_evidence.py` prove the committed no-secret
  public-beta evidence status follows
  `release-artifacts/schema/public-beta-evidence.schema.json`, keeps public
  beta and production release blocked while non-local audit, deployment,
  ceremony, randomizer, signature, signed tag, address, broadcast, and explorer
  evidence is missing, rejects stale retained hashes, rejects secret-like keys
  or values, and rejects ready claims while blockers remain.
- `scripts/test_architecture_threat_model.py` and
  `scripts/check_architecture_threat_model.py` prove
  `docs/architecture.md` and `docs/threat-model.md` retain the current
  auditor-facing component map, role boundaries, value/custody flows, threat
  categories, residual risks, evidence links, and pre-audit/no-production-claim
  maturity language before the audit package and release manifest are checked.
- `scripts/test_audit_package.py` and `scripts/check_audit_package.py` prove
  `docs/audit-package.md` remains a complete auditor-facing index over current
  maturity, scope, ADRs, invariants, Slither disposition, local deployment and
  release evidence, known blockers, accepted local-baseline dispositions, and
  security reporting. The generated release manifest records the architecture,
  threat model, and audit package hashes as governance documents before the
  checksum bundle is refreshed.
- `scripts/test_release_readiness.py` and
  `scripts/check_release_readiness.py` prove
  `docs/release-readiness.md` remains a Gate G dashboard that separates
  passing local evidence from missing fork/testnet/live evidence, production
  signatures, signed Git tags, verified deployed addresses, explorer
  verification, external audit, and post-audit remediation blockers before the
  release manifest and checksum bundle are refreshed.
- `forge snapshot --match-path test/StreamGasSnapshot.t.sol --check
  release-artifacts/baselines/v0.1.0/gas-snapshot.snap` proves the committed
  local gas snapshot still matches the focused Gate D operations for
  fixed-price mint, auction bid, auction settlement, curator claim, final
  on-chain `tokenURI`, and dependency/script reads.
- `scripts/test_changelog_check.py` and `scripts/check_changelog.py` prove
  release-impacting branch changes include a non-placeholder `Unreleased`
  changelog entry before they can pass the local/CI gate.
- CI can run the same build/test smoke commands and publish logs.

The current tests are regression tripwires, not a correctness proof. Known
blockers remain tracked in `ops/ROADMAP.md`, including any future unified
pull-payment ledger abstraction or protocol-wide aggregation layer,
canonical randomizer lifecycle ownership, lower-impact static-analysis cleanup
beyond the now-triaged high/medium baseline, fork/testnet deployment
rehearsals, production manifest generation from live broadcast outputs,
production detached checksum signatures, signed release tags, production address books,
verified live deployment hashes and explorer submissions, remaining generated
HTML/JavaScript render-sandbox hardening beyond the committed browser fixture
and local deployment-rehearsal check, fork/testnet/live production metadata
browser evidence, fork/testnet/live ceremony evidence contents,
fork/testnet/live emergency redeployment evidence contents,
fork/testnet/live randomizer operations evidence contents, deployment
discipline, and fork/testnet/live invariant coverage.
Fixture-level invalid UTF-8 regressions, dependency registry production UTF-8
guards, and Core-level production UTF-8 guards are now covered.

Contributor, security intake, architecture, threat-model, audit package,
public-beta evidence, and release-readiness files exist so future work can be
packaged and reviewed consistently, but they do not change the pre-audit
status.
