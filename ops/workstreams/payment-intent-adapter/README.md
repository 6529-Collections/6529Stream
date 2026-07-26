# PaymentIntent Adapter Workstream

## Charter

Own issue #664 through coordinator-approved sequential review-ready draft PRs.
The current slice is the partial Proposed ADR 0019 review surface that must
precede the payer-bound approved-standard ERC-20 `PaymentIntent` settlement
adapter implementation.

## Reload Order

1. `active-context.md`
2. `run-log.md`
3. issue #664
4. `ops/skills/6529-autonomous-manager/SKILL.md`
5. `ops/skills/write-prs/SKILL.md`
6. `[RSR-PAYMENT-INTENT]` in `docs/revenue-splits-and-royalties.md`
7. applicable payment and signature ADRs

## Owned Surfaces

- the issue #664 ERC-20 payment-intent adapter and interface
- focused adapter tests and test-only adversarial helpers
- narrowly required primary-settlement integration
- deployment, release, and documentation surfaces required by the concrete
  adapter

## Forbidden Surfaces

- issue #688 Manager/Ledger/Core operation-root, operation-ID, and prepared-mint
  replay semantics
- issues #684, #685, #669, #671, and #673 governance/gas ownership
- acceptance or freeze of provisional ADR 0019 surfaces before #688 identity
  and #684 exact gas-host bindings land
- unrelated fixed-price, auction, private-sale, or other sale adapters
- merge, deployment, release, live-chain, and readiness actions

## Evidence Standard

- exact EIP-712 domain and pinned intent/revocation typehashes
- payer-scoped replay and revocation views
- canonical EOA and bounded ERC-1271 signature behavior
- payer, asset, amount, sale reference, policy hash, nonce, and deadline binding
- exact ADR-0018 operation-root plus current/bound mint-policy propagation,
  including current-only consent, module, gate, counter, and cap enforcement
- exact manager preview selector/caller/return semantics, configured-gate
  equality, ungated normalization, and full preview/execution vector comparison
- checks-effects-interactions before every allowance pull
- exact token deltas, active asset policy, accounting, and atomic rollback
- replay, expiry, revocation, substitution, signer separation, malformed
  signature, gas, token, and reentrancy negatives
- focused Foundry checks followed by the proportional full repository and
  release-artifact validation ladder

## Escalation Triggers

- the accepted architecture does not define a safe payer-is-caller call frame
  for a standalone downstream adapter
- exact ERC-1271 verification depends on a split-factory parameter-host binding
  owned by issue #684
- accepted settlement requires an unimplemented revenue escrow or sale-adapter
  ABI outside issue #664
- satisfying the issue would require changing issue #688 operation identity
