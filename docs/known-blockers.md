# Known Blockers

This file summarizes the high-level blockers from `ops/ROADMAP.md` for
contributors who start from the README.

- Drop execution uses EIP-712 authorization for EOA and ERC-1271 contract
  signers, but production signing examples, fixtures, and external tooling still
  need to be added before public beta.
- Auction custody and settlement need an accepted state-machine model.
- Push payments must move to pull-payment accounting before production use.
- Randomizer request and callback validation need production hardening.
- Slither high/medium findings are captured in `ops/SLITHER_BASELINE.md` and
  need triage before audit readiness.
- Meaningful auction, payment, randomness, metadata, and invariant tests are
  still missing.
- Deployment scripts, manifests, and rehearsal runbooks are missing.

Do not treat the current build/test smoke baseline as a security claim.
