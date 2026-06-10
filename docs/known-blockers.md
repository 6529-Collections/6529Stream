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
  reserve credits instead of pushing ETH during mint execution. Broader payment
  accounting, shared ledger views, richer randomizer reserve lifecycle
  accounting, and cross-contract payment invariants still need full
  pull-payment accounting before production use.
- Curator reward claims now validate the Merkle claim and record
  `StreamCuratorsPool` curator credits instead of pushing ETH to the reward
  address. Curator pool emergency withdrawal is bounded by local curator credits
  owed, but protocol-wide payment invariants and shared ledger views remain
  open.
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
  operations, deployment admin ceremony, and richer collection-admin roles
  remain open.
- VRF and arRNG randomizer adapters now record request lifecycle state, expose
  request and token-level lifecycle views, and validate request ID, the core
  token-to-collection binding, provider, and collection randomizer epoch before
  writing a token hash. Remaining randomness blockers include deterministic
  post-processing retry, callback-after-burn policy, richer metadata state
  exposure, provider configuration runbooks, and full handling of weak helper
  randomness beyond disabling `RandomizerNXT` as a production randomizer.
- Slither high/medium findings are captured in `ops/SLITHER_BASELINE.md` and
  need triage before audit readiness.
- Auction custody, auction bid/outbid payment, auction settlement-credit,
  fixed-price pull-payment, curator reward-credit, StreamMinter
  emergency-surplus, randomizer request lifecycle, randomizer callback
  validation, and randomizer reserve-boundary regressions now exist, but
  broader payment, randomness retry, metadata, deployment,
  production-governance, and invariant tests are still missing.
- Deployment scripts, manifests, and rehearsal runbooks are missing.

Do not treat the current build/test smoke baseline as a security claim.
