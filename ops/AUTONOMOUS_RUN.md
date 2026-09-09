# 6529Stream Delivery State

Updated 9 September 2026 UTC. The owner authorized the integrator to make
technical and delivery decisions autonomously and use parallel builders.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `6529-Collections/6529Stream` |
| Active PR branch | `codex/current-stack-integration` |
| Last merged PR | https://github.com/6529-Collections/6529Stream/pull/737 |
| Active issue | https://github.com/6529-Collections/6529Stream/issues/738 |
| Active PR | TBD |
| Next issue | TBD |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | 2026-09-09 |

## Target

Deliver a working current-stack contract system and an organized repository
that developers can navigate, then freeze a tested release candidate and
launch it on testnet. First complete transaction: collection creation, signed
native sale, mint through real Core/manager/ledger, split withdrawals, entropy
fulfillment, rendered metadata, transfer, and burn, alongside English auctions.
The full-v1 backlog remains visible; unsupported features are not complete.

## Integration baseline

- Remote: `6529-Collections/6529Stream`.
- Reviewed main: `92ea123380917032f01aae09691141a2a72df935` (PR #735).
- Active integration branch: `codex/current-stack-integration`.
- First compatibility fix: actual mint manager and ledger advertise the
  ERC-165 identities required by current Core pointer validation.
- Integrated native fixed-price sale: creator and platform signatures, exact
  payment, immutable split wallets, replay protection, and atomic rollback.
- Integrated concrete entropy coordinator and metadata router for current
  Core. Focused external randomness tests use a controllable test provider.
- Integrated English auctions, artist-accepted attribution, real royalty
  resolution, atomic genesis and a VRF v2.5 adapter.
- Five whole-stack tests passed: paid lifecycle, auction/refunds, failed
  delivery rollback, delayed operating controls and governance-root rotation.
- Four additional cross-domain tests passed for rejection recovery, payment
  conservation, lifetime supply and stale authorization policies.
- Maximum metadata content is measured through Core. The planner provides
  12 million router gas; read callers should allow at least 16 million total.
- Isolated deployment simulation passed: preparation 10,966,570 gas and
  activation/sealing 12,683,466 gas, both including intrinsic transaction cost.
- Delayed append-only catalog extension and rollback both passed against the
  real SystemManifest. All eleven current-stack integration scenarios pass.
- Dedicated Sepolia deployer received 0.20 test ETH. The actual VRF subscription
  is created and funded with 0.005 ETH; both transaction receipts succeeded.
  The selected final Solidity source is compiling for the live deployment.
- The pinned real-coordinator fork rehearsal includes all linked libraries:
  48 transactions, about 100.27 million estimated execution gas. Its largest
  transaction gas limit is 16,175,894, below Sepolia's 16,777,216 cap.

The default target-isolated Core size evidence remains
`release-artifacts/latest/bytecode-release-proof.json`. It describes that
engineering compilation; the exact Sepolia instance compilation is retained
separately under `deployments/current/sepolia-2026-09-09/compilation` and must
not be inferred from the default proof.

## Active owners

| Owner | Branch | Current output |
| --- | --- | --- |
| Integrator | `codex/current-stack-integration` | Actual deployment, whole-stack transactions, interfaces/docs, integration and release decisions |
| Deployment | `codex/sepolia-current-launch` | Exact-source deployment and actual VRF demonstration; exclusive deployer nonce ownership |
| Product/tooling | `codex/current-default-release-reconciliation` | Full validation and final default artifact reconciliation |
| Governance/review | `codex/catalog-evolution` | Catalog/genesis integration complete; finish existing PRs #737 and #736 |

## Working method

Builders own disjoint files and communicate shared interfaces directly. They
commit tested increments; the integrator reviews and incorporates them. No
independent builder waits for an unrelated PR to merge. Keep one integration
branch and at most three active builder worktrees. Rotate a builder into
independent integration review when the first complete flow works.

During implementation, use compile, focused behavior tests, and the combined
current-stack flow. Keep authorization, replay, accounting and failure cases
alongside new behavior. Broad Foundry, deployment size checks, CI/static
analysis, and final artifact reconciliation follow on a stable candidate.
An actual deployment-size failure is an immediate implementation blocker.

## 48-hour delivery checkpoints

| Elapsed time | Observable result |
| --- | --- |
| 0–12 hours | Real genesis and the first complete fixed-price flow work locally |
| 12–24 hours | Repeatable Anvil deployment and demonstration; auction integration; testnet provider/signing/funding setup |
| 24–36 hours | Testnet deployment with actual callbacks, withdrawals, metadata, addresses and transaction receipts |
| 36–48 hours | Stabilize supported behavior, broad validation, frozen source and deployment facts, precise remaining-feature list |

These are targets from implementation start, not claims of completion. The
integrator takes a missed critical-path checkpoint and redirects builders.

## Repository recovery and cleanup

The original checkout contains substantial unrelated uncommitted work. Keep
it intact while useful source is recovered into the current layout. Never
merge the entire old checkout. Preserve active artist-provenance work.

The September cleanup removed 50 obsolete worktrees and archived 18 superseded
tasks. Branch references remain. Verified recovery bundles, index and working
patches, and persistent recovery references preserve the retired dirty artist
and specification checkouts. Local preservation copies retain ignored notes,
untracked source and validation transcripts. The original dirty checkout and
active artist-provenance task remain intact. Remove the last temporary repair
and builder checkouts when their work is integrated and validation is complete.

## Remaining full-v1 work

Artist lifecycle and recovery, additional payment/sale
modes, complete deployment inventory, advanced entropy recovery, and external
release evidence are not implied by the first working flow. Use
[ROADMAP.md](ROADMAP.md) and [EXECUTION_BACKLOG.md](EXECUTION_BACKLOG.md) for
the underlying requirements. Review found issue #670 incorrectly closed by a
tooling-only PR; merged evidence, not issue status alone, determines completion.

Earlier run-state chronology is preserved in Git history. This file replaces
the July record naming PR #687 and the conflicting one-PR/eight-lane rules.
