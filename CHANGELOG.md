# Changelog

All notable release-impacting changes are recorded here. The project follows
the release policy in `docs/release-policy.md`.

## Unreleased

### Changed

- Removed the immutable 30,000-gas ERC-165 probe ceiling from governed
  `StreamModuleRegistry` registration. The registry now forwards available gas
  into a bounded read, accepts only successful exact 32-byte canonical `true`
  returndata, and fails closed on revert, short, oversized, false, or
  noncanonical results. Added repricing and malformed-returndata Solidity
  regressions plus a deterministic all-`smart-contracts/` call-gas inventory
  gate that also rejects implicit fixed-gas `.transfer(...)` and `.send(...)`
  calls, parses a strict duplicate-free inventory, and pins the sole
  probe-under-test exception to its normative architecture authority. This
  slice does not change `StreamCore`. It is only the first control-plane
  remediation for
  [issue #669](https://github.com/6529-Collections/6529Stream/issues/669):
  eleven finality, minting, and revenue call sites and eleven literal
  declarations remain explicitly open in the checked inventory rather than
  accepted as risk. Protocol maturity and production readiness are unchanged.
- Hardened canonical release builds so configured targets, retained build-info
  compiler inputs, and artifact metadata fail closed if any resolved source is
  under `test/` or `script/`; added focused regressions for both restricted
  roots; made the runtime-size and Core bytecode-spend checker CLIs retain the
  validated canonical receipt and hash the exact artifact bytes they consume;
  extended that receipt-bound single-read/hash/decode model through the release,
  source-verification, protocol-surface, and ABI consumers; made the canonical
  producer derive config, Foundry-config, artifact, and retained compiler-input
  receipt hashes from the exact snapshots it validates and writes; bound
  source-verification checkout reads to the receipt's compiler/metadata source
  hashes and carried each source snapshot forward without reopening it;
  required one canonical-path, Windows-alias-safe manifest-wide source identity
  across production and interface metadata/compiler records; bound every
  size/Core artifact import read to that
  identity with missing and non-file replacements rejected; made release JSON
  generation hash one serialization, atomically install those exact bytes, and
  verify installed bytes before success; and
  consistently labeled the aggregate all-source size/warning build as
  diagnostic rather than production evidence. Canonical retention now validates
  the exact Forge worktree path
  carriers and projects only those fields to stable `.` / `lib` values before
  hashing. It also normalizes only Forge's platform packaging timestamp while
  retaining the exact semantic version, commit, build profile, and identity
  self-hash, so otherwise identical Windows and POSIX builds produce
  byte-identical compiler inputs and receipt hashes without weakening source,
  compiler, toolchain, or artifact binding. This addresses
  [issue #675](https://github.com/6529-Collections/6529Stream/issues/675)
  without changing `foundry.toml`, Solidity bytecode, ABI, via-IR test
  compilation, or release maturity.
- Made release bytecode generation reproducible under Solidity 0.8.19 by
  compiling each configured production source and its import closure in an
  isolated via-IR Forge invocation, retaining a deterministic build receipt,
  and using staged replacement with rollback on caught failures to restore the
  configured named artifacts plus retained compiler inputs and receipt to
  dedicated ignored `out-release/` before release, ABI, size, and
  explorer-verification generators run. The aggregate all-source size build
  remains a diagnostic warning input, not the release-bytecode authority. This
  closes the local release/verification evidence gap tracked by
  [issue #674](https://github.com/6529-Collections/6529Stream/issues/674), but
  does not make Forge deployment scripts or broadcasts consume that canonical
  initcode; [issue #677](https://github.com/6529-Collections/6529Stream/issues/677)
  remains a production blocker. Protocol maturity is unchanged.
- Made generated fork deployment, ceremony, and randomizer command provenance
  quote-exact across Windows and POSIX shells. The non-local evidence generator
  can now read a canonical retained Markdown `Command` field instead of
  transporting shell-sensitive text through native argv, and the checker
  rejects missing, ambiguous, malformed, or quote-drifted replay commands
  without changing release readiness.
- Replaced the transitional Governance V1 executor boundary with the atomic
  Governance V2 schema: seven-field per-call transition commitments, derived
  batch scope/old/new hashes, six-return target context, exact SSTORE2 calldata
  publication, action classes `0..6`, target-scoped terminal-freeze veto
  indexing, manifest-tail composition, append-only class-6 eligibility, and an
  executor-first one-way system-manifest bootstrap bind/seal ceremony.
  ModuleRegistry, RoleRegistry, and governed gas/time hosts now recheck the
  executing action ID, class, scope, old state, new state, revision, and probe
  evidence; V1 action-ID calldata and domains are rejected. Bootstrap and
  live-registry reads forward EIP-150-clamped available gas with bounded
  returndata and canonical decoding instead of compiled-in call caps. Added
  focused malformed-return, high-gas, sequential-probe, role-history,
  bootstrap-envelope, and holder-rehearsal coverage. Deployment-input
  generators and candidate artifacts remain a separate follow-up release
  evidence slice. This partial source/test slice does not complete
  [GOV-V2-CUTOVER] or close #665. This is pre-audit work and not a
  production-readiness claim.
- Cut `StreamArtworkFinalityRegistry` and `StreamArtworkFinalityPreview` over
  from the retired aggregate/facade Core-read seam to separately bound actual
  Core, collection metadata, and `StreamCoreFinalityAdapter` dependencies. The
  registry now validates dependency code, the adapter's exact ERC-165 support,
  immutable bindings, canonical probe values, and exact 9-word/13-word
  aggregate returns through fixed-size buffers; hashes the actual Core rather
  than the adapter; requires exact discovery count, hash, and ordered component
  enumeration; bounds strict, preview, and diagnostic reads without copying
  attacker-sized returndata; rejects unknown metadata-mode, collection-status,
  and supply-mode values; enforces the actual Core's collection burn-block and
  freeze gates; compares aggregate supply as `uint256`; and removes the
  controller/facade gate and
  `facadeBindingSatisfied` preview field. Focused adapter, registry, preview,
  component-floor, ABI, domain-golden, malformed-dependency, impostor-binding,
  raw-scope, large-supply, discovery, and gate-parity tests cover the cutover.
  This is a zero-Core-delta change: `StreamCore` source, ABI, and runtime
  bytecode remain unchanged. It does not clear production deployment because
  the current Core, metadata, discovery, and sanction implementations remain
  incomplete for the target production path.
- Closed two governance-v2 target ambiguities before implementation: the
  six-return `currentAction()` is now explicitly the complete target-readable
  context while ordered call index/selector validation remains at the
  executor's descriptor/`callsHash` boundary, and module registration now pins
  a separately named 2,048-byte, nonempty, strict-UTF-8 module-manifest URI
  policy alongside the existing registry-manifest URI bound.
- Pinned Linux CI and release mode to CPython `3.12.13`, replaced floating pip
  upgrades and live transitive resolution with one binary-only SHA-256 lock,
  added fail-closed workflow/lock policy tests, documented lock refresh and the
  separate Playwright browser-runtime boundary, and checksum-bound the complete
  Python toolchain provenance without changing release maturity.
- Aligned seven ADR 0010 citations in the collection-metadata and
  metadata-router specifications with the D-prefixed decision-id format and
  refreshed the hash-bound release evidence; this is documentation-only and
  does not change deployed protocol behavior.
- Hardened release mode so expired, future, or inverted risk-acceptance windows
  fail; external-audit evidence and all production evidence are non-waivable;
  local release targets run the aggregate check; and the manual workflow fails
  unless invoked from the protected default branch before running the full
  repository gate. Production release mode also validates the checksum-covered
  `StreamCore` build measurement against the normative 2,000-byte EIP-170
  deployment headroom requirement, keeping issue #654 fail-closed while the
  current 424-byte margin is recovered. Reconciled current roadmap and
  non-normative architecture notes to the artifact-backed 24,152-byte runtime
  and confirmed that the measured build already uses plain non-enumerable
  ERC-721, so recovery must come from real compression, extraction, or
  authorized relocation rather than assumed enumerable-removal savings. The
  readiness surfaces now expose the canonical profile while keeping the
  separate issue #656 genesis inventory limitation fail-closed because
  instance-aware deployment reconciliation remains incomplete.
- Rebuilt `StreamCore` token identity onto the specification's sequential
  model: one monotone global token ID counter starting at 1 replaces the
  reserved-range allocator, per-token `(collectionId, collectionSerial)`
  identity records are written at allocation and retained across burns,
  `TokenCollectionRegistered` (leading `uint16 schemaVersion`) is emitted at
  every authoritative identity write before dependent effects, burn is
  reshaped to `burn(uint256)` with the `StreamTokenBurned` event and the
  `collectionBurnsBlockedAtBlock` height read, the Permanent identity and
  enumeration reads land (`tokenLifecycle`, `lastAllocatedTokenId`,
  `lastAllocatedCollectionId`, storage-backed `tokenCollectionIdentity`),
  transfer/approval conditioning overrides are removed so ERC-721 transfers
  stay unconditioned, the vendored `ERC721Enumerable` pair is deleted, and
  every `10^10` range derivation is purged from Core, the minter read path,
  and the metadata renderer (`TokenOutsideCollectionRange` is renamed to
  `TokenIdentityUnknown`).

### Added

- Added the first non-production issue #677 canonical deployment-plan
  materializer. It validates the issue #674 isolated build receipt and exact
  artifact hashes, derives constructor ABI encoding plus creation/runtime
  library and immutable ranges, and emits ordered full initcode and expected
  runtime hashes from a pinned Anvil-only `DependencyRegistry` fixture. It
  carries the exact validated receipt, release-config, Foundry-config, and
  artifact byte snapshots through plan construction without reopening those
  files, strictly decodes the carried receipt, config, and every artifact JSON
  before target selection, and reuses parsed artifact snapshots across repeated
  instances. The underlying canonical validator now applies the same
  duplicate-free, non-floating-point I-JSON policy to config, receipt, all
  artifacts, retained compiler inputs, and string-form metadata without
  rereading them, so post-validation filesystem replacement cannot alter the
  resulting plan. Focused regressions cover exact read counts, post-validation
  mutation, forged snapshot sets, and ambiguous selected or unselected inputs.
  It enforces the full 49,152-byte
  EIP-3860 initcode limit,
  directly pins its `eth-abi` encoder, uses a directly pinned `jsonschema`
  engine for actual Draft 2020-12 candidate/plan validation, and applies one
  runtime/schema portable path policy that rejects Windows-invalid controls,
  characters, device names, dot aliases, and trailing dot/space aliases. It
  checksum-binds the implementation/tests and runs the unit plus real-fixture
  materialize/reparse-check sequence after canonical builds in the Make, Bash,
  PowerShell, and Linux CI gates. The tool refuses production/readiness flags,
  writes only ephemeral `tmp/` output, and does not add a broadcaster, a strict
  issue #656 instance-aware candidate, or any release-readiness evidence;
  issues #656 and #677 remain open and protocol maturity is unchanged.
- Added the immutable, read-only `StreamCoreFinalityAdapter` with its exact
  four-function ERC-165 ABI and fixed Core/collection-metadata bindings. It
  composes collection facts from granular target-Core reads, derives checked
  burned supply as minted minus live supply, carries aggregate supply values as
  `uint256` with no `createdAt`, and resolves canonical TOKEN scopes from
  retained Core identity/lifecycle state and RELEASE/SEASON/VIEW scopes from
  metadata manifests while returning semantic negatives for malformed or
  unknown scope shapes.
- Closed the finality-recovery refresh executability gap without spending Core
  bytecode: recovery schedules require a nonzero manifest content hash;
  artwork-changing execution snapshots the global token high-water mark and
  creates a stored monotonic plan; exact permissionless collection/scoped
  continuations emit one existing Core batch refresh of at most 5,000 IDs per
  transaction with rollback on failure; collection/release/season/view plans
  use a safe global-ID superset, token plans use one ID, superseded and complete
  plans reject, and progress is reconstructible through exact reads/events.
  New recoveries carry an incomplete predecessor invalidation into a fresh
  snapshot plan even when their own artwork-change flag is false. A global
  active-incomplete count and exact same-batch zero-count assertion prevent a
  finality-registry pointer replacement from stranding old-registry plans;
  monitoring/keepers drain them before cutover. Post-snapshot mints already
  resolve through the recovered route. The Core ABI is unchanged.
- Added the checksum-covered, normative
  `stream-core-permanent-interface.json` target for issue #654. It locks the
  complete Permanent `StreamCore` function/event surface (58 active functions
  and 19 active events), excludes the five facade-readiness functions and three
  events deferred by ADR 0016, omits the redundant `MetadataRouterUpdated`
  alias in favor of `CoreSatellitePointerUpdated`, includes the native
  `StreamMetadataRefresh` event, moves the system-manifest five-function/event
  surface to its Permanent satellite, and maps every active entry into a closed
  bytecode-budget group whose only sizing authority is the complete linked
  via-IR runtime measurement. It records explicit pre-genesis dispositions for
  all 60 current functions and 6 current events that do not survive unchanged,
  and is validated independently of Foundry output with
  `check_abi_compatibility.py --target-only`. Custom errors, constructor, and
  Medium/Replaceable surfaces remain separately cataloged; fallback and receive
  are fail-closed `required_absent` categories enforced against implementation
  ABI output. The canonical genesis target now contains 60 derived entries:
  `StreamSystemManifest` is Permanent deployment entry 36,
  `StreamCoreFinalityAdapter` is immutable Permanent entry 37, the 22
  per-parameter GGP probes occupy entries 38-59, and the shared cadence probe is
  entry 60. Checker goldens pin both satellites' module/interface identities
  and immutable bindings, including the manifest's frozen Core pointer and
  append-only history and the adapter's Core-native-only finality boundary,
  without claiming a deployed candidate exists. A separate reviewed lock now
  pins the exact ordered `(signature, mutability, returns)` shape of all 58
  active functions and `(signature, indexed, anonymous, schema_version)` shape
  of all 19 active events, with every event explicitly non-anonymous and every
  protocol event fixed to schema version `1`, to
  fixed SHA-256 digest
  `2513151416a7fc01753226120b415de67ba4f1e5ebf79e6e7ae8a1a3e8aefdc4`,
  so count-preserving status substitution, dummy replacement, shape drift, or
  reordering fails. A second reviewer-pinned canonical-JSON digest,
  `18992066d0c6b22c27d37112b13e6b7d3d7efe5d8e46b4ded9fa25d6d0652f55`,
  covers every top-level target semantic plus all ordered active and retired
  rows. Baseline reconciliation is bidirectional: every current Core
  function/event has exactly one active or retired disposition, and every
  retirement matches a current-baseline shape. Target, config, baseline,
  genesis-profile, and candidate JSON now reject invalid UTF-8, duplicate keys,
  non-finite/floating values, and unsafe integers. The complete canonical
  profile rows for Core, governance, `StreamSystemManifest`, and
  `StreamCoreFinalityAdapter` pin all reviewed fields. Candidate reconciliation
  requires the exact implementation/interface/marker sets for the three
  safety-critical non-governance entries, including rejecting an extra
  `IERC721Enumerable` Core advertisement, while governance remains composite
  and pins its exact three normative homes. The governance profile entry now
  proves its genesis `STATE_EXPORT_PUBLISHER` role through
  `IStreamStateExportPublisher`, the exact `latestStateExport()` selector, and
  all three publication/challenge/supersession event topics. Its complete
  machine lock also pins the read's
  five ordered return types, all three event indexed masks, and non-anonymous
  emission to fixed digest
  `535217fe4e980b1c72bc1a24f0352a7704928a3cd25f4197bdff0604d7645ea7`;
  candidate proof validation recomputes that digest over type-strict canonical
  JSON, so integer `0`/`1` values cannot masquerade as booleans, and matching
  interface/marker strings cannot replace the separate structured proof. The
  proof is governance-exclusive: every matched non-governance candidate rejects
  a non-null publisher proof. The StreamCore genesis entry also pins the exact
  advertised `IERC165`, `IERC721`, `IERC721Metadata`, `IERC4906`, `IERC2981`,
  and `IERC7572` interface tuple. The
  system-manifest vector records the publisher surface
  explicitly, and its `STATE_EXPORT_PUBLISHER` pointer plus the governance
  registry record now carry the real one-function publisher interface ID
  `0x77faad4f`, rather than the synthetic composite `0xa5971448`. A separately
  implemented fixed-golden JCS/Keccak/ABI oracle prevents the generator and
  primary checker from self-confirming the same codec or formula defect.
- Added a canonical normalized Slither baseline and fail-closed drift gate for
  first-party production High/Medium findings. The current 38 rows (4 High and
  34 Medium) are all explicitly Open: one confirmed gap, six design-review
  rows, and 31 pending dispositions, with no suppressions, acceptances, or
  false-positive claims. Fast default checks validate provenance, counts,
  classifications, and Markdown parity; a dedicated pinned CI job reruns
  Slither and fails on exact semantic-set drift. The generated risk register now
  treats the baseline as a high-severity release blocker under issue #658, and
  both public-beta and production release-mode decisions fail closed while any
  first-party production High/Medium row remains Open. Release-mode Make targets
  and the protected-branch workflow also rerun the live exact Slither comparison
  before evaluating the strict decision.
- Added the canonical machine-readable Genesis Deployment Profile and a
  structural checker plus catalog-level diagnostics. The profile derives its
  exhaustive count from contiguous entries, pins every contract role and
  GGP/GTP probe, keeps legacy aliases unapproved by default, distinguishes the
  SplitWallet implementation from on-demand clones, and records the required
  fallback roles. The v1 `contracts.json` catalog can report missing, extra,
  duplicate, ambiguous, wrong-scope, wrong-interface, and wrong-marker mapping
  gaps, but it can never clear production mode because it cannot prove
  deployment-instance identity, fallback-address distinctness, or probe
  parameter bindings. Production remains fail-closed until a checked,
  instance-aware candidate reconciles deployment manifests, address books,
  source-verification inputs, the on-chain system-manifest payload, retained
  rehearsal/live evidence, and the release candidate lockfile. This is a
  permanently production-blocking foundation for issue #656, not completion of
  that issue.
- Added the Governed Gas Parameter and Governed Time Parameter machinery per
  `[LTA-GGP]`/`[LTA-GGP-PROBES]`/`[LTA-GTP]`: reusable
  `StreamGasParameterHost`/`StreamTimeParameterHost` bases with concrete
  `StreamGasParameterStore`/`StreamTimeParameterStore` deployables (storage-backed
  values, immutable floors, derived `keccak256("6529STREAM_GGP_"||name)` ids,
  2x-per-action raise bounds, probe-gated emergency raise and exact-value
  probe-gated lowering, `FORWARDING_CAP`-only permissionless conditional
  raise/re-lower standing actions registered at deployment, governed
  rebinding of probe bindings to successor Permanent-class probes with
  `GasParameterProbeRebound`/`TimeParameterProbeRebound` events, canonical
  `GasParameterUpdated`/`TimeParameterUpdated` events, and
  `gasParameterInfo`/`timeParameterInfo` introspection), the Permanent-class
  probe family (`StreamGasProbe` base enforcing the genuine-failure
  gas-delivery proof and a run-time codeless-target guard so a scenario
  target that loses its code can never record a vacuous pass,
  `StreamForwardingCapProbe` reference probe,
  `StreamCadenceProbe` for block-cadence observation with pinned wall-clock
  floors), the `IStreamGovernedParameterAuthority` governance-executor wiring
  seam, and the requirement 9 conformance suites including parameterId
  derivation goldens against the spec-pinned catalog, scope-rejection tests,
  forged-failure probe-integrity tests, and the zero-signer museum-mode
  conditional raise/re-lower drill.
- Added the staged-governance machinery and canonical module registry:
  `StreamGovernanceExecutor` implements the ADR 0004 [GOV-ACTION-ID] and
  [GOV-BATCH] canonical action identity (golden-tested
  `STREAM_GOVERNANCE_ACTION_V1`/`STREAM_GOVERNANCE_CALLS_V1` typehashes,
  byte-identical single-call wrappers, atomic payable batches with exact
  per-call value sums and surplus rejection, onchain SSTORE2 calldata
  preimage publication), the [GOV-WINDOWS] delay and window floors (48h
  delayed, 72h terminal-freeze veto with `terminalFreezeVetoGuardian`/
  `vetoTerminalFreeze`, 14d funds recovery, 30d successor declaration, 7d
  open-to-execute floor), and the scheduled-action transition table with
  cancellation, veto, and expiry materialization; `StreamRoleRegistry`
  pins the [GOV-ROLES] `ROLE_*` vocabulary as keccak-of-own-name
  constants with root/operational grant classes, registry-resolved
  `emergencyRecipient()`, pause/unpause disjointness, and role-redundancy
  views; `StreamModuleRegistry` + `IStreamModuleRegistry` implement the
  canonical [LTA-REGISTRY] record shape with append-only
  `moduleCount()`/`moduleAt()` enumeration, the
  `registrationChainHash()` record-chain lane under
  `STREAM_MODULE_REGISTRATION_RECORD_V1`, `INCIDENT_REVOKED` status
  vocabulary, zero-means-unbounded `moduleGasLimit`, and lifecycle
  changes gated through governed action classes; plus the canonical
  eight-function `IStreamModule` [LTA-MODULE-ID] identity surface with a
  `StreamModuleBase` adoption base and a minimal `SSTORE2` helper, all
  covered by golden typehash, lifecycle, batch-semantics, window-floor,
  role-resolution, and registry append-only/chain-hash test suites.
- Added the `StreamArtworkFinalityRegistry` satellite with all five finality
  scopes at genesis (COLLECTION, TOKEN, RELEASE, SEASON, VIEW per ADR 0009
  decision 6): onchain finality-record-hash recomputation over the pinned
  `STREAM_FINALITY_V1`/`STREAM_SCOPED_FINALITY_V1` preimages; sorted-unique
  component manifests verified against live
  `finalityState`/`finalityStateForScope` reads; the mandatory
  component-type floor enforced onchain per collection metadata mode
  ([LTA-FINALITY] requirement 1 — COLLECTION_METADATA, METADATA_ROUTER,
  RENDERER, RENDER_CONTEXT, MEDIA_MANIFEST, ENTROPY_COORDINATOR for every
  mode, plus SCRIPT_SOURCE, DEPENDENCY_SOURCE, REFERENCE_RENDER for
  ONCHAIN/hybrid script works) independent of the optional discovery module,
  which layers an exact-match superset gate on top when bound; the
  artist-sanction and platform-works exactly-one component rule with onchain
  `SANCTION_SUBJECT_DOMAIN` subject-hash computation; the CLOSED-plus-burn-block
  collection gate; token content-root and leaf-count verification; the
  ONCHAIN/hybrid assembled-snapshot-manifest gate ([CMC-FINALITY-INPUTS]
  rule 3); the `EXTERNAL_FACADE` identity binding carried as a submitted
  `IDENTITY_FACADE_BINDING` finality component (entering `componentsHash` and
  the permanent `finalityRecordHash`, re-surfaceable through
  `verifyFinality`/`frozenRouteForScope`) with the `CORE_NATIVE` no-component
  rule; registry-stored canonical manifest bytes behind `manifestPointer`;
  never-revert bounded diagnostics (`verifyFinality`/`verifyFinalityRange`
  under the genesis `FINALITY_COMPONENT_READ_GAS` budget); the [LTA-FREEZE]
  freeze-mode vocabulary with a single staged TERMINAL_FREEZE path (72-hour
  veto floor, an independent guardian re-resolved at veto and execution time,
  7-day open-to-execute floor); a bound `StreamArtworkFinalityPreview`
  periphery exposing every execution comparison plus the computed sanction
  subject hash; narrow `IStreamFinality*` consumer seams for the Core,
  metadata, artist-registry, and governance surfaces built in parallel; and
  golden tests recomputing every pinned finality domain constant from its
  spec preimage.
- Resolved OQ-X8 through ADR 0015 by protocol-owner ratification: the
  on-chain collection-metadata reads plus `properties.stream.collection`
  token JSON are the normative marketplace collection-identity signal, a
  two-named-signed-commitments gate precedes public sale, and the
  per-collection ERC-721 facade line is specified as a dormant extension
  profile (`docs/stream-collection-facade-profile.md`) with its
  facade-readiness genesis surfaces (per-collection identity mode,
  one-way pre-first-mint transfer-controller registry, controlled
  mutation path, event-doctrine carve-out, finality identity binding)
  carved into the protocol v1 spec, umbrella doctrine, metadata specs,
  artist consent surface, and conformance-matrix gates, closing the
  open-question register.
- Added the launch v1 target architecture spec and hardened the payment,
  royalty, mint, metadata, and entropy specs for Core-native ERC-2981,
  event-sourced reconstruction, and long-lived module boundaries.
- Expanded the launch v1 outside-Core scope to require approved-standard ERC-20
  primary settlement, museum-grade C2PA/IIIF/PREMIS-style preservation surfaces,
  richer preservation satellites, and an explicit ARRNG/Pyth fallback versus
  VRF-only entropy decision.
- Added the first outside-Core split factory and split wallet skeleton with
  deterministic fixed-profile wallet deployment, immutable entry validation,
  native ETH pull-release accounting, and release-artifact surface coverage.
- Added the launch asset policy registry and approved-standard ERC-20 split
  wallet release/sync surface, with deployment manifest coverage, strict
  default-deny asset policy, exact ERC-20 transfer invariants, canonical
  registry status validation, high-water freeze documentation, and fail-closed
  tests for unsupported token behavior.
- Added outside-Core primary revenue resolver and primary-sale settlement
  satellites, covering deterministic assignment hashes, dynamic `SALE_POSTER`
  primary templates, verified split-wallet native ETH deposits,
  approved-standard ERC-20 primary settlement, replay protection, policy drift
  events, deployment rehearsal wiring, and adversarial settlement tests.
- Added the Core mint-manager hook surface, including a validated
  `mintManager` pointer, manager-only mint and prepared-mint calls, canonical
  `tokenCollectionIdentity` reads, prepared operation binding, and focused
  rollback/callback coverage for the launch mint-manager migration, with
  mint-manager replacement left available as the Core recovery path for a
  stranded prepared mint. This uses accepted Core bytecode-spend exception
  `CORE-SPEND-2026-06-24-001` for the measured `StreamCore` runtime of
  24,150 bytes, a +1,966-byte delta over the 22,184-byte approved baseline, and
  426 bytes of EIP-170 margin, which is above the 384-byte release floor but
  below the 512-byte warning threshold.
- Added the `StreamMintLedger` static counter accounting foundation, with
  deployed-contract ledger writers, registered phase policy hashes,
  launch-safe static counter policies, cap-checked counter consumption,
  authorization replay protection, and focused ledger tests, without adding
  Core bytecode or routing existing sale/drop/auction flows through the mint
  manager yet.
- Added the `StreamMintManager` phase policy and prepared-mint execution
  surface, with launch-static counter policy registration, executor allowlists,
  phase pause/window guards, bounded ledger consumption construction,
  stale-policy and authorization replay protection, Core prepare/complete
  execution, deployment rehearsal wiring, release-artifact coverage, and focused
  rollback/reentrancy tests while keeping gates, resolver counters, callable
  nullifiers, and existing Drops/Auctions routing as follow-up slices.
- Added launch v1 `StreamCollectionMetadata` and `StreamPreservationRecords`
  satellites, with schema-bound collection metadata records, immutable
  snapshot publication, PREMIS/C2PA/IIIF/fixity-ready preservation records,
  tagged hash references, post-freeze append-only preservation behavior,
  deployment rehearsal wiring, release-artifact coverage, and focused
  event-reconstruction/admin/freeze tests while keeping attestations and view
  references as follow-up satellites.
- Added the launch v1 mint gate and module registry foundation, with
  `IStreamMintGate`, `IStreamMintModuleRegistry`,
  `StreamMintModuleRegistry`, optional phase gate pins in `StreamMintManager`,
  gate-derived authorization and authorizer accounting, mint-time registry
  revalidation, deployment rehearsal wiring, release-artifact coverage, and
  focused fail-closed tests while keeping concrete ticket/Merkle/TDH gates and
  callable nullifiers as follow-up slices.
- Added drop-authorization ZK nullifier binding helpers and docs, using
  `salt = uint256(nullifierHash)` so ERC-1271 verifier contracts can stay
  read-only while `StreamDrops` consumes the derived drop ID as the replay
  guard.
- Added proposed pre-launch revenue split and royalty resolver specs covering
  arbitrary labeled split profiles, primary-sale templates, pull-based split
  wallets, native/ERC-20 release accounting, scoped assignment freezes, and
  Core-native resolver-backed ERC-2981 as the launch target.
- Added a root `AGENTS.md` operating guide for automated coding agents,
  covering task startup, scope discipline, validation choices, PR/bot workflow,
  and security boundaries, with markdown-link checker coverage for the new
  guide.
- Added a production-readiness execution packet for the remote-main release
  candidate, recording the frozen commit, local gates that passed, local
  toolchain blockers, and the remaining public-beta and production evidence
  rows without changing readiness claims.
- Added release-manifest and checksum coverage for the production-readiness
  execution packet so the packet participates in the release integrity chain.
- Centralized symlink-safe release evidence retained-path validation across
  non-local release evidence, release-signature evidence, marketplace/indexer
  evidence, live deployment-manifest evidence, live metadata-browser evidence,
  and production broadcast retention evidence so symlinked leaf files and
  symlinked intermediate directories fail before hashing or artifact
  validation.
- Hardened the testnet deployment rehearsal retained-artifact checker to reject
  symlinked retained transcript, broadcast, manifest, address-book, and
  gas/invariant files before future reviewed Sepolia evidence can pass.
- Added burned pending arRNG composition regressions proving paid fixed-price
  and settled auction drops can be burned before fulfillment while preserving
  payment/proceeds accounting, request bindings, burned-token audit randomness,
  freeze eligibility, and frozen manifest stability.
- Added fixed-price and auction arRNG request-ID collision composition
  regressions proving a reused provider request ID fails with
  `RandomnessRequestAlreadyExists` while preserving drop authorization state,
  mint/drop counts, payment or auction accounting, pending request accounting,
  and the first token's fulfillable request binding.
- Added auction/drop/arRNG composition regressions proving randomness-request
  pauses roll back signed auction-drop execution without consuming
  authorizations, pending arRNG requests block randomizer migration without
  auction drift, and auction settlement before fulfillment preserves custody,
  credits, total owed values, and token/request binding.
- Extended auction/drop/arRNG composition regressions to cover post-execution
  signer lifecycle controls, proving signer-epoch invalidation, signer
  rotation, consumed-drop cancellation attempts, replay attempts, and
  drop-execution pauses cannot disturb existing auction custody, bid
  accounting, pending request bindings, settlement, or later arRNG fulfillment.
- Added fixed-price/drop/arRNG composition regressions proving randomness-request
  pauses roll back paid fixed-price drop execution without consuming
  authorizations or crediting payments, post-execution signer lifecycle controls
  cannot disturb fixed-price credits or pending request bindings, and
  poster/protocol credit withdrawals before arRNG fulfillment do not break later
  fulfillment.
- Added auction terminal/drop/arRNG composition regressions proving no-bid
  settlement, contract-poster pending no-bid claims, pre-bid auction
  cancellation, cancelled signed auction authorizations, and invalid terminal
  operations preserve auction custody, claimant state, zero-accounting
  boundaries, pending request bindings, and later arRNG fulfillment.
- Extended the autonomous run-state consistency checker to reject stale detailed
  execution-backlog `Status:` paragraphs that still claim active work after the
  corresponding issue or PR has closed.
- Strengthened the offline release artifact verifier to reject unchecksummed
  regular files and symlinks under `release-artifacts/latest`, while preserving
  the self-referential checksum bundle exceptions for `SHA256SUMS` and
  `release-checksums.json`.
- Hardened the offline release artifact verifier to reject symlinked
  checksum-covered inputs, symlinked release directories, and release
  directories outside the checkout before accepting matching hashes.
- Added a deployment rehearsal gate parity checker that locks the aggregate
  suite and standalone deployment, auction, and emergency rehearsal commands
  across Make, Bash, PowerShell, and CI before the scripts execute.
- Added an aggregate local deployment rehearsal suite that runs the deployment,
  auction ceremony, and emergency redeployment rehearsals through one
  release-gate script while preserving the individual scripts for targeted
  debugging, retained evidence capture, and automated standalone-entrypoint
  coverage.
- Added a no-secret Sepolia evidence preflight checker that validates committed
  deployment/evidence prerequisites and optionally checks only operator
  environment variable presence, never values, before future public-beta
  evidence runs for issues #217, #221, and #222.
- Added a retained exact-linked live release-evidence issue audit after the
  live deployment manifest checker merge, syncing issue #227 to the dedicated
  retained-artifact body, proving it remains open, and refreshing archive,
  release-manifest, and checksum coverage while keeping production release
  blocked on real reviewed live evidence.
- Added portable command-provenance normalization and checker coverage for
  retained live-audit reports so release evidence does not embed
  operator-specific absolute Windows paths.
- Extended ABI compatibility checks and the committed baseline to cover
  published interface ABIs from `release-artifacts/contracts.json` in addition
  to production contracts, failing removed or changed interface entries while
  continuing to report additive entries as compatible.
- Documented ABI compatibility diagnostics so `subject` is the canonical
  production contract or published interface identifier while `contract`
  remains a deprecated compatibility alias for existing consumers.
- Added a no-network autonomous run-state consistency checker so stale active
  PR, issue, or branch markers in `ops/AUTONOMOUS_RUN.md` and
  `ops/EXECUTION_BACKLOG.md` fail local and CI gates.
- Strengthened release artifact verification so nested release manifest,
  bytecode proof, and release-candidate lockfile file records must be covered
  by `SHA256SUMS` with matching hashes, and expanded the checksum bundle to
  include release-manifest source docs referenced by those records.
- Added an exact linked-issue mode to the release-evidence issue snapshot
  exporter so retained live audit reports fetch the committed tracker issue
  map directly instead of relying on paginated `gh issue list` results, then
  retained and archived a fresh no-secret live audit report after PR #560 while
  keeping public beta blocked on the remaining missing evidence rows.
- Added reviewed fork/testnet marketplace and indexer evidence for
  `fork_testnet_marketplace_indexer_evidence`, retaining a supplemental
  reviewed artifact, equivalent collector/indexer tooling transcript,
  non-local evidence envelope, and release artifact updates under the shared
  public-beta evidence manifest while keeping public beta blocked on the
  remaining missing evidence rows.
- Added reviewed fork metadata browser evidence for
  `fork_testnet_metadata_browser_evidence`, retaining the mainnet-fork browser
  summary, generated `tokenURI`, redacted execution transcript, non-local
  evidence envelope, and release artifact updates under the shared public-beta
  evidence manifest while keeping public beta blocked on the remaining missing
  evidence rows.
- Added an authenticated live release-evidence issue sync gate that fetches the
  exact linked GitHub tracker issues, checks live body drift and premature
  closure against committed release artifacts, and tolerates Windows UTF-8 BOM
  snapshots while keeping the default CI gate network-free.
- Added a fork/testnet metadata-browser evidence draft generator that converts
  retained browser capture outputs into a checker-compatible pending-review
  evidence bundle, with no-secret validation, deployed-contract assertion, and
  local/CI/Windows gate coverage while keeping issue #218 blocked until real
  reviewed fork/testnet evidence is linked.
- Added retained-output flags to the local metadata browser rehearsal checker
  so operators can export deterministic browser summary JSON, generated
  `tokenURI`, and redacted transcript artifacts before future fork/testnet
  metadata browser evidence review.
- Added reviewed fork randomizer operations evidence for
  `fork_testnet_randomizer_operations_evidence`, retaining the mainnet-fork
  deployment broadcast, fork deployment manifest, fork address book, redacted
  provider export, fork transaction bundle, post-state request views, and local
  lifecycle/adversarial/retry/payment/pause/emergency test proof under the
  shared public-beta evidence manifest while keeping public beta blocked on the
  remaining missing evidence rows.
- Added reviewed fork ceremony evidence for `fork_testnet_ceremony_evidence`,
  retaining the mainnet-fork deployment broadcast, fork deployment manifest,
  fork address book, Safe/admin placeholder export, post-state views, and local
  mint/auction/emergency dry-run ceremony evidence under the shared public-beta
  evidence manifest while keeping public beta blocked on the remaining missing
  evidence rows.
- Added a checked public-beta verified-addresses retained-artifact template
  and offline checker for future `verified_deployed_addresses` and
  `explorer_verification_status` evidence, covering Sepolia address-book,
  deployment-manifest, explorer verification, bytecode proof, retained file
  path and optional declared `sha256:` validation, no-secret redaction,
  local/CI/Windows gate wiring, release-packet mapping, and checksum coverage
  while keeping issues #221 and #222 open until real reviewed public-beta
  address evidence is retained.
- Added a checked production release-signing retained-artifact template and
  offline checker for future `production_signatures` and `signed_git_tag`
  evidence, covering checksum bundle references, detached signature evidence,
  signed-tag verification, signer fingerprint/custody/rotation notes, retained
  file path and optional declared `sha256:` validation, no-secret redaction,
  local/CI/Windows gate wiring, release-packet mapping, and checksum coverage
  while keeping issues #223 and #224 open until real reviewed release ceremony
  evidence is retained.
- Added a checked live deployment-manifest retained-artifact template and
  offline checker for future `live_deployment_manifest` evidence, covering
  production chain ID, deployment version, finalized contract addresses,
  bytecode hashes, constructor arguments, address-book agreement,
  repo-relative retained files, optional declared `sha256:` validation,
  no-secret redaction, local/CI/Windows gate wiring, release-packet mapping,
  and checksum coverage while keeping issue #227 open until real reviewed live
  manifest evidence is retained.
- Added stronger production verified-addresses retained-artifact validation so
  future pending or reviewed production address-book and live explorer
  verification evidence must reference existing repo-relative retained UTF-8
  files, avoid symlinked evidence, remain no-secret, preserve address-book,
  deployment-manifest, explorer, and bytecode proof agreement, and match
  optional declared `sha256:` hashes before issues #225 or #230 can be
  considered for closure.
- Added stronger live randomizer operations retained-artifact validation so
  future pending or reviewed mainnet provider operations evidence must
  reference existing repo-relative retained UTF-8 files, avoid symlinked
  evidence, remain no-secret, and match optional declared `sha256:` hashes
  before issue #229 can be considered for closure.
- Added stronger live ceremony retained-artifact validation so future pending
  or reviewed mainnet ceremony evidence must reference existing repo-relative
  retained UTF-8 files, avoid symlinked evidence, remain no-secret, and match
  optional declared `sha256:` hashes before issue #228 can be considered for
  closure.
- Added stronger live metadata browser retained-artifact validation so future
  pending or reviewed mainnet evidence must reference existing repo-relative
  retained files, remain no-secret, and match optional declared `sha256:`
  hashes before issue #473 can be considered for closure.
- Added stronger testnet deployment rehearsal retained-artifact validation so
  future pending or reviewed Sepolia evidence must reference existing
  repo-relative retained files, remain no-secret, and match optional declared
  `sha256:` hashes before issue #217 can be considered for closure.
- Added a checked fork/testnet randomizer operations retained-artifact template
  and offline checker for future
  `fork_testnet_randomizer_operations_evidence`, covering fork/testnet
  environment and chain IDs, provider configuration, funding, reserve,
  request-health, lifecycle controls, retained-file and optional declared
  `sha256:` validation, no-secret redaction, local, Windows, and CI gate
  wiring, release-packet mapping, and checksum coverage while preserving the
  blocked public-beta baseline until reviewed evidence is retained.
- Added a checked fork/testnet ceremony retained-artifact template and offline
  checker for future `fork_testnet_ceremony_evidence`, covering fork/testnet
  environment and chain IDs, deployer/admin Safe or multisig/signer/emergency
  participants, ownership and role ceremonies, metadata/freeze, auction,
  emergency controls, dry-run and monitoring handoff evidence, no-secret
  redaction, local, Windows, and CI gate wiring, release-packet mapping, and
  checksum coverage while preserving the blocked public-beta baseline until
  reviewed evidence is retained.
- Added fork deployment rehearsal retained-artifact reference validation so
  reviewed and pending fork rehearsal evidence now proves retained files stay
  inside the repository, exist on disk, remain no-secret, and match declared
  `sha256:` hashes; refreshed the reviewed fork broadcast, deployment manifest,
  address-book, public-beta evidence, release packet, manifest, lockfile, and
  checksum hashes that the stricter checker surfaced as stale.
- Added a checked fork/testnet metadata-browser retained-artifact template and
  offline checker for future `fork_testnet_metadata_browser_evidence`, covering
  fork/testnet environment and chain IDs, deployed-contract metadata fetches,
  retained browser summary JSON, sandbox outcomes, no-secret redaction, local,
  Windows, and CI gate wiring, release-packet mapping, and checksum coverage
  while preserving the blocked public-beta baseline until reviewed evidence is
  retained.
- Added manifest-aware marketplace/indexer evidence validation so complete
  public-beta or production marketplace/indexer rows must reference reviewed
  non-local envelopes whose retained Markdown artifacts pass the detailed
  coverage, hash, environment, and no-secret checks while templates remain
  reusable preparation material.
- Added `ADV-013` randomizer request-binding parity tests covering VRF and
  arRNG wrong-collection pending-state preservation, plus nested stale-mark and
  retry reentry during the external core write without production bytecode
  changes.
- Added `ADV-014` bounded randomizer/admin stateful invariant tests covering
  arRNG reserve funding, request-cost changes, unique token requests,
  fulfillment, stale marking, failed post-processing, retry success/failure,
  provider/epoch replacement attempts, randomness-request pauses, token-binding
  drift, and emergency-withdrawal reserve views without production bytecode
  changes.
- Added `StreamAuctions.minimumNextBid(tokenId)` and
  `retrieveNoBidAuctionClaimant(tokenId)` read views for auction integrations,
  with focused bid-threshold, fail-closed, custody-alias, invariant, docs, and
  release-artifact coverage.
- Added a checked `AUD-003` external audit finding workflow covering
  public-safe intake, severity/status triage, audited scope, remediation PRs,
  required tests, retest, accepted-risk decisions, closure gates, release
  evidence handoff, no-secret redaction, and local/CI/Windows gate wiring.
- Added a generated release-candidate lockfile that ties the release manifest,
  bytecode release proof, public-beta evidence, risk register, release notes,
  blocker reports, release evidence issue outputs, release-signature evidence,
  and non-release commit/tag/signature status into a checksum-covered local
  baseline, with focused tests and local/CI/Windows gate wiring.
- Added a checked `GOV-008` bad metadata/dependency drill retained-artifact
  template, source-aware checker, and regression tests covering metadata
  schema/state, token URI snapshots, URI/UTF-8/raw-attributes and browser
  sandbox evidence, dependency key/version/content hash, freeze manifest,
  repin boundaries, ERC-4906/cache invalidation, marketplace/indexer handoff,
  recovery decisions, review, redaction, and local/CI/Windows gate wiring.
- Added a checked `GOV-007` failed-randomness drill retained-artifact template,
  source-aware checker, and regression tests covering request identity, provider
  type, provider epoch, pending/stale/failed/final lifecycle state, invalid
  callback handling, retry or stale marking, metadata state, provider migration
  boundaries, monitoring handoff, review, redaction, and local/CI/Windows gate
  wiring.
- Added a checked `GOV-006` stuck-auction drill retained-artifact template,
  source-aware checker, and regression tests covering auction identity, stuck
  condition, custody, pause/unpause, terminal settlement or cancellation,
  bidder/proceeds credits, withdrawal availability, emergency-surplus boundary,
  monitoring handoff, review, redaction, and local/CI/Windows gate wiring.
- Added a checked `GOV-005` signer-compromise drill retained-artifact template,
  source-aware checker, and regression tests covering drop-execution pause,
  signer rotation or revocation, epoch invalidation, per-drop cancellation,
  stale/cancelled/wrong-domain payload rejection, recovered fixed-price and
  auction payloads, monitoring handoff, review, redaction, and
  local/CI/Windows gate wiring.
- Added a checked `GOV-010` operator dashboard query model covering
  environment/release, admin, signer, fixed-price, auction, randomizer,
  payment/credit, metadata/dependency, release blocker, and incident drill
  panels, with query inputs, source artifacts, freshness, severity,
  no-secret telemetry, local/CI/Windows gate wiring, release-readiness and
  integration navigation, release-manifest coverage, and release-checksum
  coverage.
- Added a checked `GOV-009` protocol monitoring specification covering admin,
  signer, auction, randomness, credits, metadata/dependency, release evidence,
  alert severity, dashboard queries, incident handoff, local/CI/Windows gate
  wiring, release-readiness/integration navigation, release-manifest coverage,
  and release-checksum coverage.
- Added a checked Markdown link gate covering local files, heading anchors,
  duplicate GitHub-style anchors, line anchors, local/CI/Windows wiring, and
  release-manifest/checksum coverage.
- Added a checked pull request template release-impact checklist covering
  roadmap linkage, validation evidence, generated-artifact impact,
  breaking-change approval references, and release-manifest/checksum coverage.
- Added checked GitHub issue templates for integration reports, public-safe
  audit finding intake, and release evidence requests, with no-secret and
  pre-audit maturity language, local/CI/Windows gate wiring, and
  release-manifest/checksum coverage.
- Added a checked first-30-minutes contributor guide covering fresh checkout
  setup, Foundry/Python/Windows prerequisites, `forge` not being on `PATH`,
  canonical local gates, docs-only and Solidity/test validation paths, known
  warning noise, generated artifact drift, no-secret maturity boundaries,
  local/CI/Windows gate wiring, and release-manifest/checksum coverage.
- Added checked INT-016 integration conformance fixtures for frontend, mobile,
  Electron, indexer, operator UI, and signing-service teams, covering artifact
  loading, fail-closed chain config, EIP-712 domain expectations, event topic
  dispatch, normalized log identity, read-after-event queues, duplicate log
  idempotency, unknown emitter/topic rejection, confirmation depth, reorg
  rollback, no-secret redaction diagnostics, local/CI/Windows gate wiring, and
  release-manifest/checksum coverage.
- Added checked INT-015 TypeScript event decoding and indexer ingestion
  snippets covering event topic catalog loading, `topic0` dispatch, normalized
  log identity, ABI/topic drift checks, idempotent ingestion, confirmation
  depth, reorg rollback, read-after-event queues, no-secret diagnostics,
  local/CI/Windows gate wiring, and release-manifest/checksum coverage for
  frontend and indexer teams.
- Added checked INT-014 TypeScript EIP-712 payload construction snippets
  covering domain construction, `DropAuthorization` message shape, drop ID
  derivation, token data hashing, sale-mode validation, EOA/ERC-1271/Safe
  boundaries, submission preflight, no-secret logging, local/CI/Windows gate
  wiring, and release-manifest/checksum coverage for frontend and signing
  service teams.
- Added checked INT-013 TypeScript artifact loading and chain config snippets
  covering release manifest loading, address book loading, deployment manifest
  cross-checks, release manifest hash validation, ABI checksum awareness,
  no-secret public environment parsing, and fail-closed wrong-chain guards for
  frontend teams.
- Added a checked withdrawal and credit UX integration flow spec covering
  fixed-price, auction, curator reward, surplus, mobile, Electron, and
  indexer handling with source-aware checker coverage for contract credit
  surfaces.
- Added a checked curator rewards integration flow spec covering reward root
  publication, domain-separated Merkle leaf encoding, direct and delegated
  claims, pull-payment curator credits, withdrawal/failure UX, events,
  indexer reconstruction, and release artifact coverage for frontend teams.
- Added a checked root README maturity/navigation gate that keeps the public
  repo front door aligned with current pre-audit status, role-specific docs
  paths, local/Windows validation commands, release-readiness blockers, and
  release-manifest/checksum coverage.
- Added live solc warning baseline enforcement for the warning-disposition gate:
  aggregate size/warning diagnostic output is retained in local/CI logs and
  checked against the reviewed warning rows so new or resolved compiler
  warnings require an explicit code or disposition update, and removed or
  relocated accepted warnings require a reviewed baseline refresh.
- Added a checked incident drill retained-artifact template and validation gate
  for mint pause, bid pause, settlement pause, withdrawal policy, failed
  randomness, stuck auction, bad metadata/dependency, bad Merkle root, and
  signer compromise drills without claiming completed fork, testnet, or live
  drill evidence.
- Added a checked `StreamCore` bytecode-spend policy gate that pins the current
  22,184-byte approved production runtime baseline, fails unreviewed Core
  runtime increases even when the EIP-170 floor still passes, records rejected
  no-gain/negative-gain headroom experiments, and wires focused tests into
  local, CI, Windows, release-manifest, and checksum paths.
- Added a no-secret live randomizer operations retained-artifact template and
  checker for future `live_randomizer_operations_evidence`, with provider
  configuration, provider funding, reserve, request health, lifecycle control,
  monitoring, retained-artifact, reviewer, redaction, local/CI/Windows gate,
  packet-index, release-manifest, and checksum coverage while preserving the
  blocked production-release baseline until reviewed live randomizer operations
  evidence is retained.
- Added a no-secret live ceremony retained-artifact template and checker for
  future `live_ceremony_evidence`, with governance participant, ownership/role,
  signer, metadata/freeze, auction, emergency-control, dry-run, monitoring,
  retained-artifact, reviewer, redaction, local/CI/Windows gate, packet-index,
  release-manifest, and checksum coverage while preserving the blocked
  production-release baseline until reviewed live ceremony evidence is
  retained.
- Added a no-secret post-audit remediation retained-artifact template and
  checker for future `post_audit_remediation` evidence, with finding-by-finding
  remediation, retest, accepted-risk, release-note, reviewer-signoff, local/CI/
  Windows gate, packet-index command, release-manifest, and checksum coverage
  while preserving the blocked production-release baseline until reviewed
  post-audit remediation evidence is retained.
- Added `live_metadata_browser_evidence` as a production-release evidence row
  with a no-secret retained-artifact template, offline checker, focused tests,
  local/CI/Windows gate wiring, release-evidence tracker issue #473, and packet
  index/checksum coverage while preserving the blocked production-release
  baseline until reviewed live metadata browser evidence is retained.
- Added a no-secret production verified-addresses retained-artifact template
  and checker for future `production_address_books` and
  `live_explorer_verification` evidence, with address-book/deployment-manifest
  agreement checks, verified explorer row validation, focused tests,
  local/CI/Windows gate wiring, release-readiness/tooling docs, packet-index
  command coverage, and checksum coverage while preserving the blocked
  production-release baseline until reviewed live address evidence is retained.
- Added a no-secret production broadcast retention retained-artifact template
  and checker for future `production_broadcast_retention` evidence, with
  focused tests, local/CI/Windows gate wiring, release-readiness/tooling docs,
  and checksum coverage while preserving the blocked production-release
  baseline until reviewed live broadcast artifacts are retained.
- Added an opt-in release-mode evidence gate with
  `scripts/check_release_mode.py`, focused tests, manual Makefile targets, a
  workflow-dispatch GitHub Actions profile, release-readiness/tooling docs, and
  checksum coverage. Default CI validates the checker and the structurally
  blocked evidence baseline; release-mode checks intentionally fail until
  public-beta or production-release evidence rows are complete or explicitly
  accepted as risk.
- Added a deterministic dependency provenance attestation bundle generated from
  the dependency artifact manifest, with descriptor/source hash revalidation,
  no-secret checks, validation commands, local/CI/Windows gate wiring, release
  manifest/checksum coverage, and explicit local-baseline limitations for
  non-live dependency evidence.
- Added deterministic release notes generation from changelog and committed
  release evidence, with JSON/Markdown outputs, tests, local/CI/Windows gate
  wiring, release-manifest/checksum coverage, and explicit no-overclaim
  readiness boundaries for the pre-audit local baseline.
- Added `scripts/verify_release_artifacts.py`, an offline third-party verifier
  for the committed release bundle, with focused tests, local/CI/Windows gate
  wiring, checksum coverage for the verifier script, and documentation of what
  the check proves versus live deployment/readiness evidence it does not prove.
- Added `IStreamCompatibility` and release-tracked compatibility views on the
  `StreamContractMetadata` adapter for frontend/indexer protocol checks:
  protocol name, protocol version, metadata schema version, release tag/hash,
  and adapter-or-core interface probing, with focused tests, integration docs,
  release-manifest/checksum coverage, and regenerated deployment/release
  artifacts while preserving `StreamCore` bytecode size.
- Added a checked NatSpec coverage gate for the release-relevant protocol
  surface with `scripts/check_natspec_coverage.py`,
  `release-artifacts/baselines/v0.1.0/natspec-coverage.json`,
  `docs/natspec-coverage.md`, local/CI/Windows gate wiring, release-manifest
  and checksum coverage, and explicit baseline debt for undocumented
  functions, public variable getters, events, and custom errors.
- Added a generated custom-error catalog with
  `release-artifacts/latest/custom-error-catalog.json`,
  `docs/custom-errors.md`, generator/test wiring, local/CI/Windows gates,
  release-manifest and checksum coverage, and auditor/integrator traceability
  for release-relevant custom errors without changing Solidity behavior.
- Added `StreamMetadataCrossInvariants.t.sol`, a focused ADV-007 suite covering
  frozen dependency pins under registry version/deprecation churn, rejected
  late randomness writes against frozen live metadata, and post-freeze burned
  pending-token callback audit behavior without moving frozen manifests.
- Added `StreamRandomizerAdversarial.t.sol`, a focused ADV-006 suite covering
  VRF and arRNG duplicate callback reentry during core post-processing plus
  stale-provider fulfillment attempts that must preserve pending request state
  until explicit stale marking.
- Added `StreamCustomErrorNegative.t.sol`, a mutation-style negative suite that
  pins representative release-tracked custom-error selectors and argument
  encodings across admin, minter, dependency, metadata, contract-metadata, and
  randomizer lifecycle failure paths.
- Added gas envelope coverage for high-risk user flows: expanded the local
  Foundry gas snapshot to fixed-price withdrawal, near-end outbid, bidder
  refund withdrawal, no-bid settlement, auction proceeds withdrawal, and curator
  credit withdrawal; added `gas-envelopes.json` plus checker/test wiring across
  local gates, CI, release manifest, and checksum coverage.
- Added `StreamMEVTiming.t.sol`, a focused MEV/timing adversarial suite
  covering third-party signed-payload submission semantics, paid-drop payer
  binding, inclusive deadline behavior, strict post-end auction bid rejection,
  exact-end bid extension, near-end outbid credits, and custody/accounting
  preservation on failed timing attempts.
- Added `StreamSafeERC1271ForkSmoke.t.sol`, a no-RPC Safe-shaped ERC-1271
  smoke suite covering approved-hash threshold validation, fixed-price and
  auction drops, wrong-chain rejection, and wrong-verifying-contract rejection.
- Added `StreamEventReconstructability.t.sol`, an indexer-style log
  reconstruction suite that proves representative fixed-price, auction, minter
  bridge, and admin-reference flows can be rebuilt from emitted logs plus the
  documented read-after-event calls.
- Added additive `StreamMinter` event coverage for indexers and frontend read
  models: collection phase updates, fixed-price batch mint ranges, auction
  mint custody/end-time bridges, minter-side auction end-time edits, and
  minter contract-reference updates, with focused event tests and integration
  docs/checker coverage.
- Added a generated protocol surface report with
  `docs/protocol-surface.md`,
  `release-artifacts/latest/protocol-surface-report.json`, a
  generator/test pair, local/CI/Windows gate wiring, release-manifest and
  checksum coverage, and explicit boundaries that the report is deterministic
  review evidence rather than protocol correctness or production-readiness
  proof.
- Added a third `StreamCore` headroom recovery slice that moves tokenURI and
  metadata-state dispatch helpers into the linked `StreamMetadataRenderer`
  library while preserving exact off-chain/on-chain metadata output behavior;
  that slice measured `StreamCore` at 22,184 runtime
  bytes with 2,392 bytes of EIP-170 headroom, with the gas snapshot refreshed
  for a -12 gas auction-settlement delta, a -2,569 gas final on-chain
  `tokenURI` delta, and a +32 gas fixed-price mint delta.
- Added a second `StreamCore` headroom recovery slice that moves
  field-specific metadata validation profiles into the linked
  `StreamMetadataRenderer` library while preserving public Core size constants,
  custom-error selectors, and metadata output behavior; the production via-IR
  size gate now measures `StreamCore` at 22,390 runtime bytes with 2,186 bytes
  of EIP-170 headroom, with the gas snapshot refreshed for a +45 gas
  dependency-script read delta, a -24 gas final on-chain `tokenURI` delta, and
  a +38 gas fixed-price mint delta.
- Added a `StreamCore` headroom recovery slice that moves collection and
  dependency script assembly into the linked `StreamMetadataRenderer` library
  while preserving the `retrieveGenerativeScript` Core surface; the production
  via-IR size gate now measures `StreamCore` at 23,159 runtime bytes with
  1,417 bytes of EIP-170 headroom, with the gas snapshot refreshed for the
  small dependency-script read decrease and final metadata/mint read-path
  increases.
- Added ONE-007 warning-disposition coverage with
  `docs/warning-dispositions.md`, a checker/test pair, local/CI/Windows gate
  wiring, release-manifest and risk-register coverage, first-party NatSpec
  header cleanup, and explicit accepted dispositions for solc unused-parameter,
  pure/view, documentation, linter, vendored, test-only, ABI-compatibility, and
  `StreamCore` size-tradeoff warning rows.
- Added ONE-006 satellite-extension architecture policy coverage with checked
  architecture-doc size-budget requirements, release-policy/status hooks, and
  explicit rules for measured `StreamCore` bytecode deltas, size-budget
  exceptions, and satellite/read-adapter/library/release-artifact defaults for
  future 1/1 product surfaces, plus required link-target existence checks and
  bytecode-release-proof size-evidence matching for the architecture and
  threat-model evidence docs.
- Added ONE-005 marketplace/indexer retained evidence coverage with
  `docs/integrations/marketplace-indexer-evidence.md`, fork/testnet and live
  retained-artifact templates, public-beta and production evidence rows,
  release-packet/backlog/body-sync/manifest/checksum coverage, local/CI checker
  wiring, and explicit boundaries that template files are not completion
  evidence and no public-beta or production-readiness claim depends on
  marketplaces honoring royalties.
- Added ONE-004 collector-verifiable permanence package support with
  `docs/permanence-packages.md`, a checked JSON schema, no-secret retained
  artifact template, generated
  `release-artifacts/latest/one-of-one-permanence-manifest.json`, local/CI
  checker and generator wiring, integration/release-readiness documentation,
  release-manifest/checksum coverage, and explicit boundaries that permanence
  package evidence is not final collector proof, marketplace proof, royalty
  enforcement, ownership proof beyond chain state, or production release
  approval until reviewed non-local or final-drop evidence exists.
- Added ONE-003 royalty policy coverage with `docs/royalty-policy.md`, a
  checker/test pair, local/CI gate wiring, integration/release-readiness
  navigation, release-manifest/checksum coverage, and explicit ERC-2981
  disclosure boundaries that state royalty information is not payment
  enforcement and no production-readiness claim depends on marketplaces
  honoring royalties.
- Added ONE-002 1/1 provenance manifest support with
  `docs/provenance-manifests.md`, a checked JSON schema, no-secret retained
  artifact template, generated
  `release-artifacts/latest/one-of-one-provenance-manifest.json`, local/CI
  checker and generator wiring, integration/release-readiness documentation,
  release-manifest/checksum coverage, and explicit boundaries that provenance
  evidence is not token metadata finality, marketplace proof, royalty
  enforcement, or ownership proof beyond chain state.
- Added ONE-001 contract-level metadata support with a release-tracked
  `StreamContractMetadata` adapter, `IERC7572`/`IStreamContractMetadata`
  interfaces, `contractURI()`/`contractURIHash()` views,
  `ContractURIUpdated` event catalog coverage, metadata-pause enforcement,
  deployment rehearsal wiring, generated manifest/address-book/source
  verification artifacts, and integration docs that preserve the current
  marketplace-evidence boundary.
- Added INT-010 operator admin UI specification with
  `docs/integrations/operator-admin-ui.md`, a checker/test pair, local/CI gate
  wiring, integration/release-readiness navigation, release-manifest coverage,
  and no-production-readiness boundaries so operator UI implementers can trace
  Safe/multisig ceremony, role grants, signer lifecycle, pause domains,
  metadata freeze, dependency, randomizer, emergency, monitoring, and
  no-secret evidence flows without treating local evidence as public beta or
  production proof.
- Added INT-009 Electron security and wallet integration guide with
  `docs/integrations/electron-security-wallets.md`, a checker/test pair,
  local/CI gate wiring, release-readiness navigation, release-manifest
  coverage, and no-Electron-app/no-production-readiness boundaries so desktop
  implementers can trace main/renderer/preload responsibilities,
  BrowserWindow hardening, context isolation, IPC allowlists, wallet-provider
  boundaries, metadata animation sandboxing, local cache/secrets policy,
  signed-update and code-signing expectations, telemetry, and no-secret support
  constraints without treating local evidence as public beta or production
  proof.
- Added INT-008 mobile and WalletConnect integration guide with
  `docs/integrations/mobile-walletconnect.md`, a checker/test pair, local/CI
  gate wiring, release-readiness navigation, release-manifest coverage, and
  no-mobile-SDK/no-production-readiness boundaries so mobile browser, native
  shell, and WalletConnect implementers can trace session lifecycle, foreground
  wallet handoff, deep links, account/chain changes, typed-data and transaction
  guards, offline/background recovery, metadata/indexer refresh, telemetry, and
  no-secret support expectations without treating local evidence as public beta
  or production proof.
- Added INT-007 React/Next frontend reference architecture with
  `docs/integrations/frontend-reference-architecture.md`,
  `docs/integrations/examples/react-viem.md`, a checker/test pair, local/CI
  gate wiring, release-readiness navigation, release-manifest coverage, and
  no-SDK/no-production-readiness boundaries so 6529.io-style frontend teams can
  trace artifact import, chain config, contract-client layering, query/cache,
  transaction, wallet/signature, metadata, indexer, environment, telemetry, and
  testing expectations without hardcoded addresses or browser secrets.
- Added INT-006 metadata rendering, cache, animation sandbox, and marketplace
  integration guide with `docs/integrations/metadata-rendering.md`, a
  checker/test pair, local/CI gate wiring, release-readiness navigation, and
  release-manifest coverage so frontend, mobile, Electron, marketplace, cache,
  analytics, and indexer teams can trace metadata states, tokenURI behavior,
  ERC-4906 cache invalidation, animation sandbox boundaries, cache keys,
  refresh triggers, marketplace evidence gaps, and public-beta evidence
  boundaries without production-readiness or live-marketplace overclaims.
- Added INT-005 event and indexer reconstruction spec with
  `docs/integrations/events-and-indexing.md`, a checker/test pair, local/CI gate
  wiring, release-readiness navigation, and release-manifest coverage so
  frontend, mobile, Electron, operator UI, backend signing-service,
  marketplace, analytics, and indexer teams can trace source artifacts, indexed
  entities, event-to-state updates, read-after-event calls,
  confirmation/reorg policy, full-rescan recovery, and known event/read gaps
  without production-readiness or live-indexer overclaims.
- Added INT-004 wallet, EIP-712, ERC-1271, and Safe signing guide with
  `docs/integrations/wallets-and-signatures.md`, a checker/test pair,
  local/CI gate wiring, release-readiness navigation, and release-manifest
  coverage so React, mobile, Electron, operator UI, indexer, and backend
  signing-service teams can trace domain fields, replay controls, EOA and
  contract-signer behavior, Safe/WalletConnect caveats, failure states, and
  no-secret custody boundaries without production-readiness overclaims.
- Added INT-003 auction frontend and indexer flow spec with
  `docs/integrations/auction-flows.md`, a checker/test pair, local/CI gate
  wiring, release-readiness navigation, and release-manifest coverage so
  frontend and indexer teams can trace auction submission, bidding, settlement,
  no-bid claims, cancellation, credits, withdrawals, pause domains, events, and
  known event/read gaps without production-readiness overclaims.
- Added INT-002 fixed-price mint and drop authorization flow spec with
  `docs/integrations/contract-flows.md`, a checker/test pair, local/CI gate
  wiring, release-readiness navigation, and release-manifest coverage so
  frontend and backend signing service teams can trace preflight reads,
  EIP-712/ERC-1271 payload handling, transaction submission, events, credits,
  withdrawals, and failure states without production-readiness overclaims.
- Added INT-001 integrations entrypoint with `docs/integrations/README.md`, a
  checker/test pair, local/CI gate wiring, release-readiness navigation, and
  release-manifest coverage so frontend, mobile, Electron, indexer, operator
  UI, and backend signing service teams can find canonical integration
  artifacts without weakening the pre-production readiness boundary.
- Added AUD-002 generated risk register support with
  `release-artifacts/latest/risk-register.json`, a retained schema, generator,
  checker, focused tests, local/CI gate wiring, audit-package and
  release-readiness links, release-manifest coverage, and checksum coverage so
  launch blockers, planned mitigations, and accepted local-baseline risks stay
  machine-checkable.
- Refreshed the AUD-001 external audit package with a current protocol
  snapshot, explicit local-versus-external evidence gaps, bytecode-to-release
  proof and signed release tag references, release-artifact traceability, and
  an audit submission checklist enforced by the audit package checker.
- Added REL-003 bytecode-to-release proof generation with a checked
  `release-artifacts/latest/bytecode-release-proof.json` tying committed
  deployment manifests, address books, runtime bytecode hashes, source
  verification inputs, and the current release manifest together while keeping
  production live-bytecode proof explicitly blocked until reviewed evidence
  exists.
- Added REL-002 signed release tag verification with a default non-release
  local/CI gate, strict release-mode checks for matching signed Git tags,
  signer fingerprints, current checksum bundles, and post-bundle
  release-signature evidence, plus release docs that prevent detached checksum
  signatures from self-invalidating the `SHA256SUMS` bundle they verify. The
  strict verifier now also requires an explicit good-signature marker, a
  mandatory signer fingerprint matched as a bounded token, and a tighter
  Git-safe release tag name.
- Added on-chain artist approval hashes for finalized collection state and
  refreshed release/deployment artifact catalogs.
- Added EIP-712 artist approval signatures with compact EIP-2098 support and
  refreshed release/deployment artifact catalogs.
- Changed artist approval validity so stored approvals become stale when the
  finalized collection-state digest changes, while retaining the original
  approval text/signature as provenance.
- Added ERC-1271 contract-wallet artist approval support with strict
  `isValidSignature(bytes32,bytes)` magic-value validation.
- Documented artist approval provenance semantics for direct, EIP-712, and
  ERC-1271 approvals, including stale state-bound approval handling.
- Hardened artist approval digests to bind approval hashes to the freeze
  manifest, supply settings, final-supply delay, core address, and chain ID.
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
- Added ADV-003 signer compromise and revocation coverage with a deterministic
  pause/rotation/epoch/cancellation recovery drill plus bounded fuzz over
  fixed-price and auction signed payload invalidation paths.
- Added ADV-004 pause and settlement matrix coverage for auction bid pauses,
  with-bid and no-bid settlement pauses, failed fixed-price, bidder-credit, and
  proceeds withdrawals, user withdrawal liveness, forced-surplus
  emergency-withdrawal boundaries, and duplicate-settlement rejection without
  production contract changes.
- Added ADV-005 payment and forced-ETH invariant coverage for failed
  fixed-price, auction bidder/proceeds, and curator withdrawals, auction curator
  proceeds withdrawals in generated sequences, randomizer forced-reserve
  accounting, and explicit randomizer balance/reserve equality without
  production contract changes.
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

### Changed

- Pinned Solidity metadata off in `foundry.toml` (`bytecode_hash = "none"`,
  `cbor_metadata = false`) so contract creation and runtime bytecode is
  deterministic and self-contained, with no embedded IPFS metadata-hash
  pointer to off-chain metadata. This removes the incidental metadata churn
  whereby adding an unrelated source file perturbed the embedded metadata of
  unrelated curated contracts and staled their release-artifact checksums.
  All release artifacts (release-artifact catalog, protocol surface, custom
  error catalog, source-verification inputs, deployment and broadcast
  manifests, address books, dependency and provenance attestations, risk
  register, release notes, one-of-one permanence/provenance manifests,
  release manifest, bytecode release proof, release-candidate lockfile, and
  release checksums) were regenerated from a clean production `--via-ir`
  build, and the offline deployment rehearsal suite was re-run to confirm the
  contracts still deploy in-memory under the new build settings. This is a
  deployment-semantics change aligned with the project's on-chain permanence
  doctrine: verified bytecode no longer depends on any off-chain metadata
  artifact.
- Applied the nine-lens round-5 resolutions through accepted
  `docs/adr/0014-world-class-pass-round-5.md`: preservation now attaches
  fully to the sale (ENDOWED archive receipt at or before first sale;
  sale-follows lanes for reference renders and execution environments;
  still-image masters for museum-grade), a pinned storage-family taxonomy
  gains a family-extinction migration rule, artist attribution hardens
  (staged revocation with guardian veto, old-key veto expiry, onchain
  succession import verification, platform-works repair path, artist name
  in attribution JSON, first-release content ratification), governance
  closes the tail (standing handover latency proofs, guardian-module
  holder discipline, superseded P0 direct-execution risk, treasury and
  entropy-admin roles), sales pin zero-value overrides, fair-allocation
  raffles, seller-action disclosure, anti-snipe exhaustion states, and a
  pattern-coverage matrix, revenue pins the revocation typehashes and the
  ERC-20 single-step realization, GGP classification closes the
  purchase-path ratchet loophole and gains permissionless re-lower, and
  the museum floor defaults to declared tiers with owner
  notice-and-objection standing in recovery. The autonomous iteration
  loop closes at five rounds (instrument ceiling 9.0/lens) pending
  protocol-owner decisions on OQ-X8 and the merge bar.
- Applied the nine-lens round-4 resolutions through accepted
  `docs/adr/0013-world-class-pass-round-4.md`: typed artist payout
  resolution (`artistPayoutAccount` reads with artist-signed designation
  records) fixes the mechanically unimplementable `COLLECTION_ARTIST`
  template source; the module registry gains state enumeration and a
  registration record-chain lane and the system-manifest payload joins the
  onchain-bytes class; the ENDOWED archival slot requires cryptoeconomic
  storage; heirless-artist steward authority, guardian-veto survival,
  permissionless attribution claims, a pinned identity-document schema,
  and entropy-consent scope land in the artist spec; governance gains
  batch payable semantics, a completed role vocabulary with the emergency
  recipient as a role reference, onchain scheduled-calldata publication,
  and the 72-hour terminal-freeze floor everywhere; the sales layer pins
  reveal-fee escrow, Dutch price floors, external burn-to-mint, airdrop
  failure isolation, EIP-7702-safe claim paths, and waivable auction
  floors; the museum conservation floor moves to before-first-sale for
  museum-grade collections with preservation masters, capture semantics
  for time-based works, and an institutional-validation gate; and the
  open-questions register restates OQ-X8's lifecycle gate decidably.
- Applied the nine-lens round-3 resolutions through accepted
  `docs/adr/0012-world-class-pass-round-3.md`: GGP probe contracts become
  Permanent-class genesis inventory with a zero-signer museum drill, and
  permissionless conditional raises are restricted to read-survival
  parameters (killing the fail-closed DoS ratchet); entropy block-count
  windows become Governed Time Parameters; preservation follows the sale
  (sold tokens in open offchain collections require endowed dual-family
  receipts and fixity within a pinned window of each sale); every onchain
  payload family gains state-readable pointer discovery and exports gain
  their own archival mandate; ERC721Enumerable is removed from Core
  (periphery enumeration lens specified; totalSupply retained); artist
  estate flows gain third-party contest paths, identity-document revisions,
  sanction authority classes, platform-works sale stops, and
  successor-registry history import; the sales layer adds airdrop, raffle,
  consignment/custody-grant, cross-sale content uniqueness, and editions
  posture with revocation typehashes pinned; claimRefund semantics, escrow
  conservation invariants, and PaymentIntent domain binding are pinned;
  the museum dossier adds the ownership-provenance chain, a tombstone
  cataloguing schema, packaging mappings, and rights floors; ADR 0004 gains
  ROLE_PAUSE_GUARDIAN, the definitive two-tier enforcement statement, and
  material-action executability rehearsals; a baseline-record header now
  quarantines all fourteen legacy operational documents from the
  specification set; and the deployment chain posture (Ethereum mainnet L1)
  plus a vulnerability-disclosure obligation are stated normatively.
- Applied the nine-lens round-2 resolutions through accepted
  `docs/adr/0011-world-class-pass-round-2.md`: onchain bytes now means
  contract storage or SSTORE2 (event data demoted to discovery pointers);
  offchain-mode collections bind per-token content hashes at mint/sale time;
  execution environments are archived as runnable artifacts with pinned
  per-work re-render acceptance modes; archival receipts require a
  cryptographically verifiable class and one pay-once endowed family;
  Governed Gas Parameter raises are 2x-bounded with named probe contracts
  and permissionless pre-approved conditional raises for lost governance;
  escrow-holding sale modes bind drift envelopes so buyer funds can never
  strand (Dutch purchases pay max-price with pull-credit excess; phase
  pause moves out of the policy hash via the V2 phase-config preimage);
  artist identity gains rotation contest windows, guardian sets,
  platform-independent estate activation, pre-finality content veto, and
  post-finality recovery signatures; sale-scoped randomness, reveal-owner
  SLOs, SaleKind vocabulary growth, zero-price/PWYW/custody-inventory
  kinds, and deposit-bonded sealed bids join the sales spec; nonces are
  per-signer everywhere; museum registrar/conservation/rights schemas are
  pinned with a PREMIS mapping and an operator-independent attestor lane;
  mirrors now carry every governance and GGP domain; and 51 further
  minor-tier refinements land across the set.
  `scripts/check_mint_manager_domain_constants.py` additionally enforces the
  revenue-layer `6529STREAM_` domain-namespace rule across the home table
  and its protocol v1 mirror.
- Hardened the full specification set through accepted
  `docs/adr/0010-world-class-spec-pass.md`, resolving all 112 findings of a
  nine-lens independent review (permanence, artist provenance, Safe/TDH
  operability, minting coverage, best-in-world comparison, good patterns,
  anti-patterns, meta-consistency, museum practice): added
  `docs/stream-artist-authority.md` (two-sided artist identity, artist
  sanction as a finality component, mint-path consent modes, estate and
  succession, artist economics rights) and `docs/stream-sales-and-auctions.md`
  (sale adapter conformance, English/Dutch auctions with anti-snipe and
  increments, burn-to-mint, Merkle allowlists, refund windows, delegated
  minting); replaced every immutable gas cap with Governed Gas Parameters
  (immutable floors, staged raise/lower, health probes — minting can never
  brick and marketplace reads can never permanently zero under gas
  repricing); extended finality with per-token content roots for all
  metadata modes, reference-render capture, renderer-determinism gates, and
  dual-family archival proof; extended state exports to the artwork/metadata
  layer with record-chain accumulators; added the museum object dossier
  (pinned token subject IDs, owner-writable accession/condition/exhibition/
  deaccession records, a mandated fixity program, artist-intent records,
  C2PA media binding, IIIF profile, citation profile); defined the canonical
  governance action-ID preimage with atomic batch execution and
  multisig-sized window floors in ADR 0004; adopted single-sourcing with
  normative homes, precedence, and requirement anchors in the spec policy;
  pinned 175 new hash-domain and EIP-712 typehash constants; closed the
  reviewed anti-patterns (PaymentIntent binding for ERC-20 pulls,
  authorizerKind replacing address(0) conventions, manager-scoped
  nullifiers, VRF callback try/catch persistence, fee-quote-bound entropy
  payments); and opened `OQ-X8` (marketplace collection identity signal
  under sequential token IDs) as the single owner-reserved question.
  Corrected the ADR 0009/register decision count from 24 to 25.
- Resolved all 24 open questions raised by the specification permanence
  reframe through accepted `docs/adr/0009-protocol-v1-open-question-resolutions.md`
  and accepted ADR 0008 (amended by ADR 0009 decisions 8 and 9): sequential
  global token IDs with stored collection serials, the 2,000-byte Core
  headroom rule as the governing size gate, dual genesis entropy providers
  (VRF plus reviewed ARRNG/Pyth fallback; VRF-only nonconformant), the full
  five-scope genesis finality registry, one canonical `stream`-prefixed
  module identity surface, mandatory Core `contractURI()` and
  Core-originated ERC-4906 refresh emitters, `maxRoyaltyBps = 1000`,
  frozen-bit-only assignment-hash binding, deployment-wide global freeze
  blocking new revenue classes, `COLLECTION_SCOPE_PHASE_ID = 0` cross-phase
  counter derivation, `fulfillEntropy` outcome codes for stale-result
  handling, and the metadata/collection-metadata decisions recorded in the
  ADR. Removed every inline `OQ-*` marker and moved the register to
  Resolved.
- Reframed the Stream specification set from launch-phase language onto
  permanence classes for permanent 6529-network infrastructure: added
  `docs/spec-policy.md` (Permanent/Replaceable/Operational taxonomy,
  Draft/Review/Final lifecycle, ADR-gated amendments) and
  `docs/spec-open-questions.md` (tracked `OQ-*` decisions), retitled the
  launch v1 target architecture to the Stream protocol v1 specification and
  the launch conformance matrix to the deployment conformance matrix, swept
  launch/pre-launch/future-module wording from the umbrella, revenue, mint,
  metadata, collection metadata, and entropy specs, canonicalized the
  `royaltyReceiverAndBps` (`0x54f77a09`) resolver selector across the matrix
  and umbrella spec, and marked genuinely open decisions with inline `OQ-*`
  markers instead of deferral hedges. Spec file names are unchanged;
  normative requirements are unchanged except where hedges became tracked
  open questions.
- Recovered 392 bytes of measured `StreamCore` runtime headroom with
  behavior-preserving storage caching and invariant-bounded unchecked counter
  arithmetic; that release step measured production via-IR runtime at 21,831
  bytes with 2,745 bytes of EIP-170 margin under the then-current 22,184-byte
  approved ceiling. Later Core mint-manager hook work supersedes the current
  runtime measurement and approved exception ceiling in the Unreleased section.
  Added explicit mint/burn/final-supply counter regressions and a checked
  negative-delta convention for accepted headroom-recovery records.

### Fixed

- Hardened discovery-bound artwork-finality diagnostics after finalization:
  `finalityStillMatches`, `verifyFinality`, and `verifyArtworkScopeFinality` now
  compare the live discovery count and route hash with the stored component set,
  returning `false` while preserving the stored record and component hashes when
  discovery drifts, loses its code, reverts, exhausts its bounded gas, or returns
  malformed or oversized data. Discovery reads use the existing 30,000-gas
  finality read budget, retain parent-frame gas for fail-closed completion, and
  use an exact-word return buffer so hostile returndata cannot turn the full
  diagnostic into an unbounded copy; collection and scoped regressions cover the
  new behavior without changing paginated component-range semantics.
- Aligned `StreamArtworkFinalityPreview` finality preview with execution by
  mirroring the `[LTA-FREEZE]` rule 4 live veto-guardian gate in
  `_stagedFreezeReady`: the preview now re-resolves the terminal-freeze veto
  guardian through the registry governance authority and reports a staged freeze
  as not-ready (`stagedFreezeReady`/`wouldExecute` false) when the guardian was
  cleared after scheduling, matching the `FinalityFreezeGuardianUnset` revert in
  `StreamArtworkFinalityRegistry._requireExecutableFreeze` so
  `previewFinality(...).wouldExecute` can no longer report an unexecutable freeze
  as ready. The view-only edit shifted the IR-optimized `StreamCore` runtime to
  24,152 bytes with 424 bytes of EIP-170 headroom via the whole-program
  optimizer, and the release-artifact, deployment, and evidence pin chain plus
  the `StreamCore` size figures in the architecture, status, known-blockers,
  release-policy, tooling, and target-architecture docs were regenerated to match.
- Hardened the Windows checked-native helper so successful commands that write
  accepted warning output to stderr still pass based on exit code, with runtime
  harness coverage for stderr-on-success behavior, and taught the Solidity
  formatting checker to ignore CRLF-only diffs for formatting-required files
  while preserving the documented vendored exemption set.
- Corrected reviewed fork metadata browser evidence so non-local retained
  `tokenURI` metadata self-describes the fork/testnet rehearsal, and hardened
  Forge broadcast return parsing to validate decoded field shapes and skip
  malformed `returns` records before retaining evidence.
- Reconciled stale autonomous backlog status rows for previously merged
  integration, 1/1 product-readiness, contract-size, and randomizer test work,
  and refreshed the dependent risk-register and release-artifact hashes.
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
- Recovered additional `StreamCore` runtime bytecode headroom by replacing the
  unused inherited ERC-2981 default-royalty machinery with equivalent fixed
  `royaltyInfo` logic and explicit ERC-2981 interface support. The production
  IR-optimized runtime is now 24,047 bytes with 529 bytes of EIP-170 headroom.
- Recovered another 386 bytes of `StreamCore` runtime bytecode headroom by
  moving off-chain token URI formatting, token-name formatting, and randomizer
  lifecycle probe helpers into the linked `StreamMetadataRenderer` library
  while preserving metadata state and migration behavior. The PR #421
  production IR-optimized runtime measured 23,661 bytes with 915 bytes of
  EIP-170 headroom before later mainline additions; the current release proof
  records the rebased `StreamCore` runtime as 23,781 bytes with 795 bytes of
  EIP-170 headroom.
- Hardened the runtime size-budget checker so it validates compiler metadata,
  optimizer settings, EVM version, compilation target, and current source
  Keccak hashes before trusting Foundry artifacts, with focused regression
  tests for stale and wrong-profile artifacts.

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
  replacing inherited ERC-2981 default-royalty machinery with equivalent fixed
  royalty logic, plus generated creation/runtime bytecode size fields and
  bytecode-release-proof size assertions.
- Gate D/G now enforces the `StreamCore` runtime size budget from
  `release-artifacts/contracts.json` in local checks, CI, and the Windows
  wrapper.
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
