# Changelog

All notable release-impacting changes are recorded here. The project follows
the release policy in `docs/release-policy.md`.

## Unreleased

### Added

- Added a reusable ADV-001 protocol state-machine smoke harness with
  deterministic cross-contract coverage for fixed-price minting, auction
  outbid/settlement, known credit withdrawals, pause/signer/cancel controls,
  randomness-finalized metadata, metadata mutation, collection freeze, and
  owed-balance/surplus assertions without production contract changes.
- Added ADV-002 deterministic protocol state-machine adversarial tests for
  cancelled, expired, stale-signer, and replayed drop authorizations,
  fixed-price withdrawal rollback to rejecting receivers, auction
  pre-settlement ordering, settlement idempotence, late bids, and failed
  auction withdrawal rollback without production contract changes.
- Expanded the reviewer-supplied 1/1 product-excellence roadmap into
  issue-ready backlog entries and strategic release requirements for
  contract-level metadata, provenance manifests, royalty policy, collector
  permanence packages, marketplace/indexer evidence, satellite-extension
  architecture, and release-grade warning disposition.
- Recorded the clean-main reviewer rebaseline in the roadmap and execution
  backlog, including reviewer-confirmed fixed protocol surfaces, remaining
  production-trust and 1/1 product gaps, benchmark inputs, and PR #373
  verification metadata.
- Added a no-secret deployment admin ceremony evidence schema, template,
  retained-artifact checklist, checker, tests, local/CI gate wiring, release
  manifest coverage, checksum coverage, and deployment/readiness/runbook docs
  for issue #362 while keeping reviewed fork/testnet/live admin ceremony
  evidence missing until real ceremony artifacts are retained.
- Added a no-secret Sepolia deployment rehearsal config template, a
  `runSepolia()` Foundry script entrypoint, deployment/runbook documentation,
  and template regression coverage for issue #360 while keeping
  `testnet_deployment_rehearsal` missing until real reviewed Sepolia evidence
  is retained.
- Added a dedicated testnet deployment rehearsal retained-artifact template and
  checker for issue #217, wiring it into local/CI evidence gates and generated
  release evidence trackers while keeping `testnet_deployment_rehearsal`
  missing until real reviewed Sepolia evidence is retained. Added
  `ops/EXECUTION_BACKLOG.md` as the PR-sized 10/10 implementation map for the
  combined roadmap, external assessment, and integration-readiness work, now
  including reviewer-supplied 1/1 product-excellence items for contract-level
  metadata, collector provenance, royalty philosophy, permanence packaging,
  marketplace/indexer evidence, Core size discipline, and warning burn-down.
- Added a dedicated external audit report retained-artifact template and
  checker for issue #215, wiring it into local/CI evidence gates and generated
  release evidence trackers while keeping `external_audit_report` missing until
  a real reviewed audit report is retained.
- Accepted reviewed mainnet-fork deployment rehearsal evidence for issue #216,
  moving `fork_deployment_rehearsal` to `complete`, dropping #216 from the
  active evidence tracker backlog/link/body-sync set, and preserving blocked
  public-beta readiness on the remaining missing evidence rows.
- Added a retained no-secret live audit report and snapshot bundle after
  syncing issue #216 from `missing` to the committed `pending`
  fork-deployment-rehearsal body, with refreshed live-audit archive, release
  manifest, and checksum evidence while preserving blocked public-beta
  readiness.
- Added pending-review mainnet-fork deployment rehearsal evidence for issue
  #216, including a sanitized Foundry broadcast, generated fork deployment
  manifest, generated fork address book, non-local evidence envelope, and
  refreshed public-beta evidence artifacts while keeping public-beta readiness
  blocked until review is accepted.
- Added fork-mainnet broadcast-derived manifest and address-book drift checks
  to the local and CI deployment-manifest gates.
- Added broadcast manifest generator support for explicitly ignored linked
  library/helper deployments and Foundry unlocked-broadcast receipt-hash drift
  fallback when the receipt order and deployed address still prove the same
  deployment.
- Added a fork deployment rehearsal retained-artifact Markdown shape and
  checker so issue #216 evidence can be structurally validated without changing
  public-beta readiness claims.
- Added Windows check-wrapper native exit-code enforcement and a focused policy
  test so `scripts/check.ps1` fails fast when `forge` or Python checks return
  non-zero under Windows PowerShell 5.1.
- Added an executable PowerShell runtime harness for the Windows checked native
  wrapper so zero-exit and non-zero-exit native command behavior are both
  validated without running the full local gate.
- Added a lightweight Windows PowerShell CI job for the checked native-command
  wrapper harness so Windows-specific native exit handling is covered without
  running the full Foundry gate on Windows, plus a focused policy test for the
  workflow wiring.
- Added fork-specific release evidence tracker routing so issue #216 points to
  the canonical fork deployment rehearsal retained-artifact template and
  checker commands instead of the generic public-beta placeholder.
- Added a retained live audit report and snapshot bundle after the fork issue
  #216 body sync, with refreshed live-audit archive, release manifest, and
  checksum evidence while preserving blocked public-beta readiness.
- Added a scoped Solidity formatting gate that requires formatted first-party
  files while tracking the current vendored/provenance formatting exemption
  policy.
- Added curator reward Merkle root epochs and domain-separated reward leaves
  that bind proofs to the leaf domain, chain ID, pool address, collection ID,
  claimant, amount, and root epoch.
- Added release change approval policy and a local/CI changelog gate for
  release-impacting contract, deployment, artifact, and release-workflow
  changes.
- Added deterministic release evidence tracker label checks with an optional
  live GitHub issue snapshot audit mode for label drift.
- Added the applied release evidence tracker label taxonomy for live tracker
  issues: `evidence` plus `public-beta` or `production-release` phase labels.
- Added a release evidence issue snapshot exporter so live label, body, and
  closure audits can write UTF-8 JSON without shell redirection.
- Added a release evidence issue snapshot audit orchestrator so operators can
  export and check live label, body, and closure issue snapshots with one
  no-secret command while CI stays network-free.
- Added a retained no-secret release evidence live audit report bundle mode for
  the issue snapshot orchestrator, including deterministic JSON/Markdown report
  output, snapshot digests, command provenance, and blocked-readiness warnings.
- Added a release evidence live audit report schema, checked no-secret template,
  and offline checker for retained report bundles.
- Added a release evidence live audit Markdown parity checker and checked
  no-secret Markdown template for retained report bundles.
- Added a deterministic release evidence live audit report archive index for
  retained JSON/Markdown report bundles, with no-secret validation and
  local/CI drift checks.
- Added the live audit report archive retention workflow, including the
  canonical retained-bundle directory, naming convention, no-secret rule,
  validation command sequence, and readiness-claim boundary.
- Added a deterministic retained live audit dry-run report bundle under the
  canonical archive directory, with regenerated archive, release manifest, and
  checksum evidence.
- Added snapshot freshness/currentness guards for retained live audit reports
  so historical issue-label, issue-body, and issue-closure snapshots cannot be
  presented as current without explicit blocked-readiness markers.
- Added deterministic release evidence tracker body checks with optional
  live GitHub issue snapshot audit mode and body-file remediation output for
  body drift.
- Added deterministic release evidence tracker closure/readiness checks with
  optional live GitHub issue snapshot audit mode so tracker issues cannot close
  before committed evidence is complete or explicitly risk-accepted.
- Added a non-local release evidence metadata generator that computes retained
  artifact digests, validates generated evidence envelopes, and supports
  `--check` drift detection without changing release readiness claims.
- Added a deterministic machine-readable release manifest that ties release
  artifacts, ABI compatibility, deployment manifests, address books, governance
  docs, and release-ceremony status together under `release-artifacts/latest/`.
- Added deterministic source-verification input generation under
  `release-artifacts/latest/`, including source hashes, compiler settings,
  constructor ABI, bytecode/linking status, and verification command templates.
- Added deterministic Foundry broadcast manifest-input ingestion from sanitized
  broadcast JSON, with generated broadcast-derived deployment manifest and
  address-book artifacts covered by release manifest and checksum gates.
- Added contract-enforced metadata byte limits for collection display fields,
  collection scripts, token data, token images, token attributes, generated
  `tokenURI` output, dependency scripts, and dependency provenance strings.
- Added metadata golden-fixture safety checks for JSON/data-URI decoding,
  current URI scheme policy, and generated animation HTML script-boundary
  validation in local and CI gates.
- Added renderer URI policy helpers and production token image URI validation
  for required metadata image inputs.
- Added production collection base URI and external library URL validation,
  keeping those fields optional while rejecting unsafe non-empty URI values.
- Added focused `StreamCore` custom-error regressions covering function-admin
  authorization, artist signatures, metadata array lengths, and final-supply
  timing.
- Added deterministic dependency artifact descriptors and
  `release-artifacts/latest/dependency-artifact-manifest.json`, with local/CI
  drift checks for packaged dependency source files.
- Added metadata fixture regressions proving invalid UTF-8 JSON/HTML data URI
  payloads and non-semantic attribute entries fail the committed fixture gate.
- Added production raw-attribute schema enforcement so token attributes must be
  empty or comma-separated objects with `trait_type` and `value` string fields.
- Added a strict UTF-8 scanner and production dependency registry enforcement
  for dependency script chunks and provenance, with focused invalid-sequence and
  size-before-UTF-8 tests.
- Added production `StreamCore` UTF-8 enforcement for collection metadata
  fields, collection script chunks, token data, token image URIs, and token raw
  attributes, with valid multibyte acceptance, invalid-sequence, field-specific
  selector, direct-update-path, and size-before-UTF-8 tests.
- Added Playwright-backed metadata browser sandbox checks for the committed
  final on-chain animation fixture, with deterministic dependency stubbing,
  unexpected-network rejection, bootstrap assertions, and parent-frame
  isolation proof in local and CI gates.
- Added a local deployment-rehearsal metadata browser sandbox gate that deploys
  the stack, mints through EIP-712 drop authorization, finalizes generated
  metadata inputs, and executes the resulting on-chain animation in Chromium.
- Added a local auction ceremony rehearsal gate that deploys the stack, signs
  and mints an auction drop, proves auction custody, bids, settles, withdraws
  poster/protocol/curator proceeds, and checks zero owed funds.
- Added a local emergency redeployment rehearsal gate that deploys impacted and
  replacement stacks with distinct deployment versions, manifests, EIP-712 drop
  domains, and contract addresses, then proves replacement fixed-price mint
  smoke evidence after Safe-rooted admin ceremonies.
- Added a deployment ceremony evidence schema, local Anvil evidence bundle, and
  local/CI checker so admin, signer, metadata-browser, auction, emergency
  redeployment, artifact, verification, and redaction evidence has a
  deterministic no-secret release format.
- Added a committed local gas snapshot baseline for fixed-price mint, auction
  bid, auction settlement, curator reward claim, final on-chain `tokenURI`, and
  dependency/script reads, with local/CI drift checks.
- Added a bounded supply/replay/freeze invariant baseline covering fixed-price
  drop mints, cancellations, replay attempts, burns, metadata updates,
  freeze-manifest stability, and post-freeze mutation rejection.
- Added a bounded auction-consistency invariant baseline covering auction-drop
  registration, escrow custody, first bids, outbids, cancellation, settlement,
  invalid-operation preservation, withdrawals, and auction-local owed/reserve
  surplus coherence.
- Added focused randomizer reserve lifecycle tests covering arRNG request-cost
  spending, multiple pending requests, fulfillment, stale marking, failed
  post-processing, retry, forced ETH, and emergency-withdrawal boundaries.
- Added a randomizer operations evidence schema, local Anvil evidence bundle,
  and local/CI checker covering provider configuration, funding status,
  lifecycle controls, reserve policy, retained artifacts, and redaction rules.
- Added no-secret drop authorization signing examples, deterministic EIP-712
  and ERC-1271 fixtures, local/CI fixture validation, and release
  manifest/checksum coverage for the signing evidence.
- Added a no-secret drop authorization payload generator, fixed-price and
  auction input/output examples, local/CI generator validation, and docs wiring
  for unsigned EIP-712 payload evidence.
- Added a no-secret drop authorization signing evidence schema, checked
  template, retained-artifact hash validation, local/CI checker, and release
  manifest/checksum coverage.
- Added a no-secret signer custody readiness evidence schema, checked
  template, retained-artifact hash validation, local/CI checker, and release
  manifest/checksum coverage for production signer readiness evidence without
  committing private keys, HSM credentials, signer-service secrets, or live
  unreleased payloads.
- Added a release signature evidence schema, local placeholder bundle, and
  local/CI checker covering detached checksum signatures, signed Git tags,
  signer identity, retained verification artifacts, and no-secret redaction
  rules.
- Added an external audit package index and local/CI checker so current
  maturity, scope, ADRs, invariants, static-analysis disposition, local
  deployment/release evidence, known blockers, accepted local-baseline
  dispositions, and security reporting remain linked for auditors.
- Added architecture and threat-model docs plus a local/CI checker so current
  system components, trust boundaries, value/custody flows, threat categories,
  residual risks, and evidence links remain complete before audit packaging.
- Added a release-readiness dashboard and local/CI checker so Gate G local
  evidence, public-beta blockers, production release blockers, required
  evidence links, and release-readiness commands remain visible before release
  manifest and checksum generation.
- Added a public-beta evidence status manifest, schema, and local/CI checker so
  fork/testnet/live, external audit, signature, signed tag, address,
  broadcast-retention, explorer-verification, and post-audit blockers stay
  machine-checkable before any public-beta or production release claim.
- Added a generated public-beta blocker report under
  `release-artifacts/latest/public-beta-blockers.md`, with local/CI drift
  checks and release manifest/checksum coverage for the current incomplete
  evidence rows without changing readiness claims.
- Added a generated production-release blocker report under
  `release-artifacts/latest/production-release-blockers.md`, with local/CI drift
  checks, per-requirement production template links, and release
  manifest/checksum coverage without changing readiness claims.
- Added a generated release evidence packet index under
  `release-artifacts/latest/`, with JSON/Markdown outputs, local/CI drift
  checks, blocker-row/template/retained-artifact/validation-command mappings,
  and release manifest/checksum coverage without changing readiness claims.
- Added a generated release evidence issue backlog under
  `release-artifacts/latest/`, with JSON/Markdown outputs, local/CI drift
  checks, issue-ready titles, labels, bodies, completion gates, validation
  commands, and release manifest/checksum coverage without auto-creating issues
  or changing readiness claims.
- Added a committed release evidence issue-link map under
  `release-artifacts/latest/`, with local/CI checks tying every generated
  backlog entry to a GitHub tracker issue without treating tracker closure as
  retained evidence.
- Added generated release evidence issue body-sync artifacts under
  `release-artifacts/latest/`, with exact no-secret GitHub issue body payloads,
  a Markdown review view, local/CI drift checks, and release manifest/checksum
  coverage without automatically updating GitHub or changing readiness claims.
- Added a non-local release evidence intake runbook so fork/testnet/live,
  audit, explorer, gas, invariant, checksum-signature, and signed-tag evidence
  has required retained fields, no-secret redaction rules, reviewer
  expectations, and public-beta requirement mapping before status rows are
  marked complete.
- Added a non-local release evidence metadata schema, checked template,
  retained placeholder artifact, checker, and local/CI gate so future reviewed
  non-local evidence can be machine-validated before release manifest and
  checksum generation.
- Added checked per-requirement public-beta evidence templates under
  `release-artifacts/evidence/public-beta-templates/`, with checker coverage
  proving every public-beta requirement has a template while readiness remains
  blocked until reviewed non-local evidence exists.
- Added checked per-requirement production-release evidence templates under
  `release-artifacts/evidence/production-release-templates/`, with checker
  coverage proving every production-release requirement has a template while
  readiness remains blocked until reviewed non-local evidence exists.
- Added a protocol incident-response runbook and local/CI checker covering
  stuck auctions, failed or stale randomness, bad Merkle roots, bad metadata or
  dependency configuration, signer compromise, and release artifact/evidence
  mistakes before release manifest and checksum generation.
- Added a production dependency operations runbook covering dependency version
  proposal, review, source packaging, registry registration, unfrozen
  collection repinning, deprecation, rollback by corrective version, frozen
  collection protection, and source-retention evidence.
- Added lifecycle-aware stale and failed randomness metadata states for minted
  tokens whose hash is still unset, with off-chain URI fixtures, schema-v1
  on-chain JSON fixtures, token state view coverage, fallback-to-pending
  coverage, and final-hash override coverage.
- Added focused randomizer migration regressions proving unsupported lifecycle
  providers do not block migration while lifecycle-aware providers with failed
  pending-request probes still block replacement.
- Pinned release-artifact, JavaScript, and Python text files to LF line endings
  so dependency artifact source hashes stay deterministic across Windows and
  Linux checkouts.

### Fixed

- Retired provider and integration files from the prior Solidity formatting
  exception baseline, so arRNG, VRF, delegation, and randomizer integration
  interfaces are now enforced by `make fmt-check`.
- Retired first-party interface files from the prior Solidity formatting
  exception baseline, so `INextGenCore2.sol`, `IStreamDrops.sol`, and
  `IStreamMinter.sol` are now enforced by `make fmt-check`.
- Converted the remaining Solidity formatter baseline from generic baseline
  language into an explicit 17-file vendored/provenance exemption policy.
- Clarified production-release evidence tracker completion gates so
  `public-beta-evidence.json` is described as the shared release evidence
  status manifest rather than a public-beta-only completion target.
- Persisted collection base URI values during full collection metadata updates
  and hardened admin, minter, and randomizer marker probes so invalid targets
  revert with typed custom errors.
- Rejected initial zero collection supply with a typed supply error instead of
  arithmetic panic, and rejected dependency registry swaps to non-contract
  addresses with `InvalidDependencyRegistryContract()`.
- Recovered `StreamCore` runtime bytecode headroom by replacing selected legacy
  string reverts with typed custom errors and tightening repeated
  `setCollectionData` storage access, bringing the production IR-optimized
  runtime to 24,135 bytes with 441 bytes of EIP-170 headroom.
- Rejected `setFinalSupply` for collections with missing collection data using
  `CollectionDataMissing(collectionId)` before final supply math can underflow.
- Recovered enough `StreamCore` bytecode for Core UTF-8 production enforcement
  by moving reusable metadata guards into the linked renderer library and
  replacing inherited `_requireMinted` string reverts with `TokenNotMinted()`;
  after lifecycle-aware stale/failed metadata state display, the production
  IR-optimized runtime remains deployable at 24,348 bytes with 228 bytes of
  EIP-170 headroom and is tracked as below the 384-byte release floor.
- Recovered the documented `StreamCore` minimum release floor by moving freeze
  metadata hash helpers into the linked renderer library, inlining final-token
  metadata checks, reusing known collection IDs in token-name rendering, caching
  generative-script storage lookups, and replacing the old-randomizer lifecycle
  probe with equivalent low-level staticcalls that preserve pending-probe
  revert data. The production IR-optimized runtime is now 24,139 bytes with 437
  bytes of EIP-170 headroom.

### Release Impact

- Gate G now requires release-impacting PRs to update this `Unreleased` section
  before merge.
- Gate G now checks `release-artifacts/latest/release-manifest.json` before the
  signable checksum bundle. The checksum bundle covers the release manifest, so
  the manifest records checksum-bundle digests as self-referentially unavailable
  rather than embedding a hash cycle.
- Gate G now checks `release-artifacts/latest/source-verification-inputs.json`
  before the release manifest so retained verification inputs are covered by
  both the top-level manifest and the signable checksum bundle.
- Gate E/G now checks sanitized broadcast-derived deployment evidence before
  deployment manifests, address books, release manifests, and checksums are
  considered current.
- Gate D/G release artifacts now include the ABI and bytecode deltas from the
  metadata size-limit custom errors and public limit constants.
- Gate D now runs metadata fixture safety checks in `make check`, CI, and the
  platform check wrappers.
- Gate D/G release artifacts now include the ABI and bytecode deltas from the
  metadata URI policy helper functions and `UnsafeMetadataURI()` custom error.
- Gate D/G release artifacts now include the ABI and bytecode deltas from
  collection URI production enforcement and custom errors replacing legacy
  `StreamCore` revert strings on metadata, mint, randomizer, and wiring paths.
- Gate D/G release artifacts now include the ABI, bytecode, and custom-error
  deltas from dependency registry UTF-8 enforcement and the shared renderer
  UTF-8 scanner.
- Gate D/G release artifacts now include the ABI and bytecode deltas from the
  `StreamMetadataRenderer.supportsContractMarker` helper used to keep marker
  probe hardening deployable under EIP-170.
- Gate D/G release artifacts now include the ABI and bytecode deltas from
  explicit initial zero-supply rejection and dependency registry target
  validation.
- Gate D/G release artifacts now include the ABI and bytecode deltas from
  moving collection-script and token-metadata freeze hash helpers into
  `StreamMetadataRenderer`.
- Gate D/G release artifacts now include dependency artifact manifest coverage
  and checksum coverage for dependency descriptors/source files under
  `release-artifacts/dependencies/`.
- Gate D/G release artifacts now include the bytecode delta from production
  raw-attribute schema enforcement in `StreamMetadataRenderer`.
- Gate D/G release artifacts now include the ABI and bytecode deltas from
  `StreamCore` size-recovery custom errors:
  `ArtistSignatureUnauthorized()`, `FunctionAdminUnauthorized()`,
  `InvalidTokenMetadataInput()`, and `FinalSupplyTimeNotPassed()`.
- Detached checksum signatures, signed release tags, production address books,
  and verified live deployment addresses remain future release-ceremony work.
- Gate F release evidence now includes `docs/audit-package.md` as a
  release-manifest governance document before the checksum bundle is refreshed.

## v0.1.0 - Initial Local Baseline

### Added

- Established the first local release-artifact baseline, including ABI
  checksums, bytecode checksums, interface IDs, event topic catalog, ABI
  compatibility baseline, local deployment manifest, local address book, and
  signable checksum bundle.
