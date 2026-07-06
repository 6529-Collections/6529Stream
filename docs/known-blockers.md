# Known Blockers

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.


This file summarizes the high-level blockers from `ops/ROADMAP.md` for
contributors who start from the README.

- The scoped Solidity formatting gate now passes for formatting-required
  first-party and provider/integration files and blocks any new unformatted
  file outside the documented vendored/provenance exemption set. The raw
  `forge fmt --check smart-contracts` diagnostic still fails on 17
  vendored OpenZeppelin-style files; any change to that exemption set requires
  a focused provenance review and must not be mixed into behavior changes.
- Drop execution uses EIP-712 authorization for EOA and ERC-1271 contract
  signers, and no-secret local signing examples plus deterministic fixtures now
  live in [`docs/drop-authorization-signing.md`](drop-authorization-signing.md).
  The same guide links no-secret unsigned payload-generator templates for
  fixed-price and auction drops, plus a checked drop authorization signing
  evidence schema/template for future reviewed ceremonies. A checked
  [`docs/signer-custody-readiness.md`](signer-custody-readiness.md) model now
  defines the no-secret readiness evidence for custody owner, signer manager,
  signer epoch source, signer-service class, ERC-1271 status,
  rotation/revocation drills, monitoring, and incident-response links.
  Production signer custody, production signing service integration, retained
  fork/testnet/live signing evidence contents, reviewed signer custody
  readiness evidence, and approved external signer integration still need to
  be completed or explicitly accepted before public beta.
- Auction custody and settlement state-machine coverage now exists for ADR 0002:
  auction NFTs are escrowed by the auction contract, no-bid and with-bid
  settlement are explicit, outbid refunds use bidder credits, and auction-local
  settlement proceeds use pull credits.
- Fixed-price mints now record `StreamDrops` poster, protocol, and curator
  reserve credits instead of pushing ETH during mint execution. Current local
  ledgers now have fixed scenario coverage plus bounded sequence fuzz invariants
  for owed totals, total-reserved aliases, surplus aliases, reserves, and
  emergency-withdrawable views. Broader shared ledger architecture or
  protocol-wide aggregation, plus richer randomizer reserve lifecycle
  accounting, remain open before production use.
- Curator reward claims now validate the Merkle claim and record
  `StreamCuratorsPool` curator credits instead of pushing ETH to the reward
  address. Curator pool emergency withdrawal is bounded by local curator credits
  owed, reward leaves are domain-separated by chain, pool address, collection,
  claimant, amount, and root epoch, and mixed payment-operation invariants now
  cover the current local curator accounting. A unified protocol-wide ledger
  remains future work if the project introduces that abstraction.
- `StreamMinter` now treats its balance as surplus with `totalOwed() == 0` and
  emergency withdrawal bounded by `emergencyWithdrawable()`.
  `NextGenRandomizerRNG` conservatively treats its full adapter balance as
  randomness reserve and exposes zero emergency-withdrawable balance until
  fuller provider reserve accounting lands.
- Admin selector and function-admin target-scope regressions now cover
  P0-ADMIN-001: protected functions require the intended selector, function
  grants are scoped to the target contract and selector, revoked grants fail,
  owner/root role recovery exists, unsupported collection-admin lookups return
  false, and global-admin bypass remains explicit. P0-ADMIN-002 adds
  domain-scoped pause controls for drop execution, minting, bidding,
  settlement, metadata mutation, and randomness requests, keeps user credit
  withdrawals unpaused by default, and makes emergency withdrawal recipients
  explicit through `StreamAdmins.emergencyRecipient()`. Signer lifecycle
  authority is now separated from drop-signing identities through root-managed
  signer managers with exact lifecycle grants on owner-approved drop targets.
  Deployment admin ceremony and richer collection-admin roles remain open.
- VRF and arRNG randomizer adapters now record request lifecycle state, expose
  request and token-level lifecycle views, and validate request ID, the core
  token-to-collection binding, provider, and collection randomizer epoch before
  writing a token hash. Ordinary provider migration is blocked while the current
  lifecycle-aware adapter reports pending requests; admins must explicitly mark
  affected requests stale before migrating. Deterministic post-processing
  failures now become observable `FailedPostProcessing` requests with stored
  derived seed and failure-data hash instead of rolling back to pending. Admins
  can retry deterministic post-processing with the stored seed through a bounded
  retry path that cannot request new randomness. Request records now store a
  canonical raw-output hash alongside the derived seed and expose both values in
  fulfillment, failure, and retry events without storing full provider word
  arrays. `RandomizerNXT` remains impossible to configure as a production
  randomizer, and the concrete weak `XRandoms` helper has been removed from
  production source. Valid VRF/arRNG fulfillments after burn now record
  audit-only randomness without restoring live metadata. Minted tokens whose
  hash remains unset now expose lifecycle-aware `stale` and `failed` metadata
  states when the configured randomizer reports those states. Remaining
  randomness blockers include provider configuration runbooks and canonical
  core/coordinator lifecycle ownership.
- Dependency script retrieval now has segment-safe typed chunk and content
  hashes, so the former packed/dynamic chunk-boundary Slither finding is fixed.
  Current metadata golden fixtures now lock the pre-beta off-chain
  pending/stale/failed/final URI behavior and schema-v1 on-chain
  pending/stale/failed/final base64 JSON output with explicit
  `metadata_schema_version` and `metadata_state` fields. Pending, stale, and
  failed on-chain metadata no longer run final generative HTML with a zero token
  hash.
  ERC-4906 support and current `MetadataUpdate` / `BatchMetadataUpdate`
  semantics now cover `StreamCore` metadata mutations. Collection freeze now
  records a manifest hash/event, requires final live-token metadata and the
  final-supply boundary, finalizes supply, and rejects current `StreamCore`
  metadata-significant writes after freeze. Dependency registry updates now
  create immutable version records with typed content hashes, provenance strings,
  deprecation state, and collection key/version/content-hash/registry-address
  pins; existing and frozen collection output stays stable across later registry
  versions or registry swaps until an unfrozen collection is explicitly
  repinned. Burned tokens now follow ERC-721 token-existence semantics, emit a
  protocol burn audit event, expose retained burn audit state, and can record
  valid post-burn randomness for audit only. On-chain metadata now escapes JSON
  string fields, enforces raw attribute entries as `trait_type` / `value` string
  pairs, escapes generated animation wrapper fields, parses `tokenData` from an
  escaped string, and neutralizes closing-script sequences in generated HTML.
  Numeric byte limits now cover collection display fields,
  collection scripts, token data, token images, token attributes, generated
  `tokenURI` output, dependency scripts, and dependency provenance. Token image
  writes, collection base URI writes, and external library URL writes now reject
  unsafe URI inputs, and renderer helpers define the current content/script URI
  scheme policy for tests and fixture checks. Dependency registry writes now
  reject invalid UTF-8 dependency script chunks and provenance with typed field
  errors while preserving size-before-UTF-8 error ordering. `StreamCore`
  metadata writes now reject invalid UTF-8 collection fields, collection script
  chunks, token data, token image URIs, and token raw attributes with typed
  field errors while preserving size-before-UTF-8 ordering. The dependency
  operations runbook now documents production dependency proposal, review,
  packaging, pinning, deprecation, rollback, frozen-collection protection, and
  source-retention ceremonies beyond registry provenance strings.
  Local deployment-rehearsal metadata browser execution now exists; remaining
  metadata blockers include fork/testnet/live production browser evidence for
  release ceremonies.
  Committed metadata fixtures now have
  Python checks for JSON/data-URI decoding, current URI scheme policy, and final
  animation HTML wrapper/script boundaries, plus a Playwright-backed Chromium
  sandbox check for the committed final animation fixture.
- `StreamCore` now uses a linked metadata renderer library, removes optional
  ERC-721 Enumerable support, preserves a live `totalSupply()`
  view, and has a production-only size gate:
  `forge build --sizes --via-ir --skip test --skip script --force`. The
  committed `release-artifacts/latest/bytecode-release-proof.json` currently
  records `StreamCore` runtime size at 24,159 bytes with 417 bytes of EIP-170 headroom,
  which passes deployability and the documented 384-byte minimum release floor
  but sits below the 512-byte warning threshold under the accepted CON-012
  bytecode-spend exception. Large non-trivial Core feature work still needs
  bytecode deltas to be measured or an explicit size-budget exception, and
  deployment scripts, manifests, and rehearsals still need to use this
  production profile.
- Dead public/allowlist mint-count mappings and retrieval APIs were removed
  from `StreamCore`; the retained airdrop counter now has explicit regression
  tests for zero initial state, authorized increments, and failed-mint rollback.
- First-party production `uninitialized-local` Slither rows now initialize their
  default locals explicitly and have targeted regressions for string counting,
  delegation status/gating, empty-script rendering, and minter return indexes.
- Slither high/medium findings are captured in `ops/SLITHER_BASELINE.md`;
  current high/medium rows are now fixed, documented as false positives for
  retained OpenZeppelin utility libraries, or accepted as test-only helper
  findings. Vendored-library provenance is tracked in
  `docs/vendored-libraries.md`. Low, informational, and optimization findings
  remain outside the current CI gate.
- Auction custody, auction bid/outbid payment, auction settlement-credit,
  fixed-price pull-payment, curator reward-credit, StreamMinter
  emergency-surplus, randomizer request lifecycle, randomizer callback
  validation, deterministic randomizer retry, raw-output hash storage,
  randomizer reserve-boundary regressions, local payment-ledger view aliases,
  collection freeze-boundary tests, dependency version/pinning tests, and a
  bounded payment sequence invariant baseline now exist. A local gas snapshot
  baseline and gas envelope baseline now cover fixed-price mint and withdrawal,
  auction bid, near-end outbid, bidder refund withdrawal, no-bid settlement,
  with-bid settlement, auction proceeds withdrawal, curator reward claim and
  withdrawal, final on-chain `tokenURI`, and dependency/script reads under
  `release-artifacts/baselines/v0.1.0/`. The local deployment
  rehearsal also includes an auction ceremony from signed auction drop through
  bid, settlement, proceeds withdrawal, and zero owed funds plus a local
  emergency redeployment rehearsal with distinct old/replacement manifests,
  drop domains, addresses, Safe-rooted ceremony state, and replacement mint
  smoke evidence. A no-secret deployment ceremony evidence schema, local Anvil
  bundle, and checker now exist; the checker enforces the current no-secret and
  `retained_artifacts` contract for evidence files. Fork/testnet/live
  production metadata browser evidence, deployment, production-governance,
  richer supply/replay/freeze invariant tests, detailed non-local broadcast and
  verification evidence contents, and any future shared-ledger invariants are
  planned for future non-local ceremonies.
- Live fork/testnet deployment rehearsals, production broadcast retention,
  production address books, explorer verification, and detailed retained
  fork/testnet/live emergency redeployment evidence contents are planned for
  future non-local ceremonies.
- The structured public-beta and production blocker status lives in
  [`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json)
  and is documented in [`docs/public-beta-evidence.md`](public-beta-evidence.md).

Do not treat the current build/test smoke baseline as a security claim.
