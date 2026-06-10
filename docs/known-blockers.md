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
- Fixed-price payouts, broader payment accounting, curator rewards, randomizer
  reserves, remaining emergency-withdrawal surplus boundaries, and
  cross-contract payment invariants still need full pull-payment accounting
  before production use.
- Randomizer request and callback validation need production hardening.
- Slither high/medium findings are captured in `ops/SLITHER_BASELINE.md` and
  need triage before audit readiness.
- Auction custody and auction bid/outbid payment regressions now exist, but
  broader payment, randomness, metadata, admin/pause, deployment, and invariant
  tests are still missing.
- Deployment scripts, manifests, and rehearsal runbooks are missing.

Do not treat the current build/test smoke baseline as a security claim.
