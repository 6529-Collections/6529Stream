# Changelog

All notable release-impacting changes are recorded here. The project follows
the release policy in `docs/release-policy.md`.

## Unreleased

### Added

- Added release change approval policy and a local/CI changelog gate for
  release-impacting contract, deployment, artifact, and release-workflow
  changes.
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

## v0.1.0 - Initial Local Baseline

### Added

- Established the first local release-artifact baseline, including ABI
  checksums, bytecode checksums, interface IDs, event topic catalog, ABI
  compatibility baseline, local deployment manifest, local address book, and
  signable checksum bundle.
