# Project Status

6529Stream is pre-audit and not production-ready.

The current Gate A smoke baseline proves:

- Foundry is configured to compile `smart-contracts`.
- `forge build` runs against Solidity `0.8.19`.
- `forge build --sizes --via-ir --skip test --skip script --force` runs as the production
  size gate. Current `StreamCore` production runtime size is 23,139 bytes,
  leaving 1,437 bytes of EIP-170 headroom under the IR-optimized deployment
  profile.
- `forge test -vvv` executes real tests for admin guards, target-scoped
  function-admin permission regressions, domain-scoped pause controls,
  signer-manager lifecycle controls with approved targets, EIP-712 and ERC-1271
  drop authorization,
  auction custody and payment credits, fixed-price pull-payment credits,
  curator reward claim credits, and randomness lifecycle behavior. Current
  emergency-withdrawal target-state tests also cover explicit emergency
  recipients, `StreamMinter` surplus withdrawal, `NextGenRandomizerRNG` reserve
  boundaries, dependency-script segment-safe content hashing, explicit
  local-initialization regressions, vendored OpenZeppelin utility-library
  provenance/behavior regressions, and retained airdrop mint-accounting
  behavior after removal of dead public/allowlist counters.
- Payment sequence fuzzing now covers mixed fixed-price mint, auction bid,
  auction settlement, curator claim, withdrawal, emergency withdrawal,
  randomizer reserve, and forced-balance operations, proving the current local
  ledgers keep category totals, owed totals, balance coverage, reserves, and
  emergency-withdrawable surplus coherent after each step. Current value-holding
  payment surfaces also expose ADR-style local-ledger aliases for reserved
  balances and surplus where applicable.
- Randomizer tests now cover request lifecycle views, callback validation,
  raw-output hash storage, failed post-processing state, bounded deterministic
  post-processing retry, and the conservative provider-migration policy that
  blocks lifecycle-aware provider replacement while collection requests are
  pending. They also prove `RandomizerNXT` cannot be configured as a
  production randomizer after removal of the concrete weak `XRandoms` helper
  from production source.
- Metadata tests now prove dependency chunk boundaries are included in typed
  content hashes while preserving the existing rendered generative script
  output. `StreamDependencyRegistry.t.sol` proves immutable dependency version
  records, provenance/deprecation views, collection dependency
  key/version/content-hash/registry-address pins, explicit repinning, and
  output stability after later registry versions or registry swaps.
  `StreamMetadataGolden.t.sol` locks current off-chain pending/final URIs plus
  schema-v1 on-chain pending/final base64 JSON data URIs against fixtures. The
  on-chain schema exposes `metadata_schema_version` and `metadata_state`, and
  pending on-chain metadata no longer runs final generative HTML with a zero
  token hash. `StreamMetadataEvents.t.sol` proves ERC-4906 interface support and
  current metadata update event semantics for token-level updates, and it now
  proves optional ERC-721 Enumerable support is not advertised while the
  contract preserves a live `totalSupply()` view.
  collection-range updates, randomness fulfillment, mint-only paths, and burn.
  `StreamMetadataFreeze.t.sol` proves the current collection freeze boundary:
  ended mint window, elapsed final-supply delay, final live-token metadata,
  stored manifest hash/event, final supply tightening, and post-freeze rejection
  for current `StreamCore` metadata-significant mutation paths.
  `StreamCoreBurn.t.sol` proves burn metadata semantics: burned tokens lose
  ownership and `tokenURI` availability, emit protocol burn audit events, retain
  audit state, exclude burned supply from live collection supply, reject remint
  attempts for previously burned token IDs, and allow valid VRF/arRNG post-burn
  fulfillment to record audit-only randomness without ERC-4906 metadata updates
  or freeze-manifest changes. `StreamMetadataEscaping.t.sol` proves the current
  on-chain JSON string escaping and raw attribute structural guard: escaped
  collection/image fields decode to parseable JSON, brackets inside quoted
  attribute values remain valid, and breakout/control-character/unterminated
  attribute fragments revert. It also decodes final animation HTML and proves
  the wrapper escapes the external library attribute, embeds `tokenData` and
  dependency script content through escaped JavaScript strings, and neutralizes
  closing-script sequences so hostile metadata inputs do not create extra raw
  wrapper `</script>` tags.
- `StreamDeploymentManifest.t.sol` proves the first Gate E local deployment
  rehearsal can deploy and wire the stack, configure sample admin/pause/signer
  ceremony state, transfer Ownable control to the configured Safe placeholder,
  revoke the temporary deployment admin, and parse the deployment manifest
  schema/example JSON artifacts.
- `forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir`
  executes as part of the local/CI smoke gate.
- `scripts/test_release_artifacts.py` and
  `scripts/generate_release_artifacts.py --check` prove the committed
  `release-artifacts/latest/` baseline matches current Foundry ABI/event output,
  including ABI checksums, bytecode checksums, standard/custom interface IDs,
  and event topic catalog entries.
- `scripts/test_source_verification_inputs.py` and
  `scripts/generate_source_verification_inputs.py --check` prove the committed
  `release-artifacts/latest/source-verification-inputs.json` retains production
  contract source hashes, compiler settings, constructor ABI, bytecode/linking
  status, and verification command templates from the current Foundry artifacts.
- `scripts/test_abi_compatibility.py` and
  `scripts/check_abi_compatibility.py --check` prove the current production
  contract ABI surface remains compatible with the committed
  `release-artifacts/baselines/v0.1.0/abi-surface.json` baseline. The first
  baseline fails on removed or changed functions, events, custom errors,
  constructors, fallback, or receive entries and reports additive entries as
  compatible.
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
- `scripts/test_release_manifest.py` and
  `scripts/generate_release_manifest.py --check` prove the generated top-level
  release manifest ties the release artifact catalog, ABI compatibility
  baseline, deployment manifests, address books, schemas, changelog, governance
  docs, and unavailable release-ceremony outputs together without drift.
- `scripts/test_release_checksums.py` and
  `scripts/generate_release_checksums.py --check` prove the committed
  `release-artifacts/latest/SHA256SUMS` and
  `release-artifacts/latest/release-checksums.json` bundle covers the current
  release artifact, broadcast fixture, deployment manifest, address-book,
  config, schema, and release-manifest files.
- `scripts/test_changelog_check.py` and `scripts/check_changelog.py` prove
  release-impacting branch changes include a non-placeholder `Unreleased`
  changelog entry before they can pass the local/CI gate.
- CI can run the same build/test smoke commands and publish logs.

The current tests are regression tripwires, not a correctness proof. Known
blockers remain tracked in `ops/ROADMAP.md`, including any future unified
pull-payment ledger abstraction or protocol-wide aggregation layer, fuller
randomizer reserve lifecycle accounting,
canonical randomizer lifecycle ownership, lower-impact static-analysis cleanup beyond the now-triaged
high/medium baseline, fork/testnet deployment rehearsals, production manifest
generation from live broadcast outputs, detached checksum signatures, signed
release tags, production address books, verified live
deployment hashes and explorer submissions, remaining generated
HTML/JavaScript render-sandbox hardening, metadata size limits, dependency
artifact packaging and migration runbooks beyond registry provenance strings,
semantic attribute schema validation, URI policy, invalid UTF-8 policy, browser
render-sandbox automation, deployment discipline, and the broader P0/P1 test
suite.

Contributor and security intake files exist so future work can be packaged and
reviewed consistently, but they do not change the pre-audit status.
