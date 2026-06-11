# Known Blockers

This file summarizes the high-level blockers from `ops/ROADMAP.md` for
contributors who start from the README.

- Drop execution uses EIP-712 authorization for EOA and ERC-1271 contract
  signers, but production signing examples, fixtures, and external tooling still
  need to be added before public beta.
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
  owed, and mixed payment-operation invariants now cover the current local
  curator accounting. A unified protocol-wide ledger remains future work if the
  project introduces that abstraction.
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
  audit-only randomness without restoring live metadata. Remaining randomness
  blockers include richer stale metadata state exposure, provider configuration
  runbooks, and canonical core/coordinator lifecycle ownership.
- Dependency script retrieval now has segment-safe typed chunk and content
  hashes, so the former packed/dynamic chunk-boundary Slither finding is fixed.
  Current metadata golden fixtures now lock the pre-beta off-chain pending/final
  URI behavior and schema-v1 on-chain pending/final base64 JSON output with
  explicit `metadata_schema_version` and `metadata_state` fields. Pending
  on-chain metadata no longer runs final generative HTML with a zero token hash.
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
  string fields, rejects raw attribute fragments that can break out of the
  enclosing attribute array, escapes generated animation wrapper fields, parses
  `tokenData` from an escaped string, and neutralizes closing-script sequences
  in generated HTML. Remaining metadata blockers include dependency artifact
  packaging and deployment migration runbooks beyond registry provenance
  strings, browser render-sandbox automation, semantic attribute schema
  validation, URI policy, invalid UTF-8 policy, and size limits.
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
  bounded payment sequence invariant baseline now exist, but browser-level
  generated metadata render-sandbox tests, metadata size-limit tests, deployment,
  production-governance, richer supply/replay/freeze invariant tests, and any
  future shared-ledger invariants are still missing.
- Deployment scripts, manifests, and rehearsal runbooks are missing.

Do not treat the current build/test smoke baseline as a security claim.
