# 6529Stream Delivery State

Updated 9 September 2026 UTC. The owner authorized the integrator to make
technical and delivery decisions autonomously and use parallel builders.

## Target

Deliver a working current-stack contract system and an organized repository
that developers can navigate, then freeze a tested release candidate and
launch it on testnet. First complete transaction: collection creation, signed
native sale, mint through real Core/manager/ledger, split withdrawals, entropy
fulfillment, rendered metadata, transfer, and burn. Integrate auctions next.
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
- Actual whole-stack deployment and transaction tests are being assembled.
  These are the next acceptance checkpoint, not a completed result.

## Active owners

| Owner | Branch | Current output |
| --- | --- | --- |
| Integrator | `codex/current-stack-integration` | Actual deployment, whole-stack transactions, interfaces/docs, integration and release decisions |
| Mint and sales | `codex/runtime-sales` | Native sale integrated; English auction implementation next |
| Entropy and metadata | `codex/entropy-metadata` | Coordinator/router integrated; real VRF v2.5 provider next |
| Genesis and governance | `codex/genesis-integration` | One-time atomic initialization, actual SystemManifest, deployment planner, executor bytecode size |

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

The September cleanup removed 42 obsolete merged worktrees and archived nine
superseded tasks. Branch references remain. Local preservation copies retain
ignored notes and validation transcripts from explicit cleanup candidates.
Four active delivery checkouts and ten review/recovery checkouts remain.
Clean up recovery checkouts after their useful work is incorporated or saved.

## Remaining full-v1 work

Artist lifecycle and recovery, royalty resolution, additional payment/sale
modes, complete deployment inventory, advanced entropy recovery, and external
release evidence are not implied by the first working flow. Use
[ROADMAP.md](ROADMAP.md) and [EXECUTION_BACKLOG.md](EXECUTION_BACKLOG.md) for
the underlying requirements. Review found issue #670 incorrectly closed by a
tooling-only PR; merged evidence, not issue status alone, determines completion.

Earlier run-state chronology is preserved in Git history. This file replaces
the July record naming PR #687 and the conflicting one-PR/eight-lane rules.
