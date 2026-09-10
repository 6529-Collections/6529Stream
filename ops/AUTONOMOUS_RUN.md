# 6529Stream Delivery State

Updated 10 September 2026 UTC. The owner authorized autonomous technical and
delivery decisions, parallel builders, repository cleanup and testnet launch.
This file owns current execution state; earlier chronology remains in Git.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `6529-Collections/6529Stream` |
| Active PR branch | `codex/current-stack-integration` |
| Last merged PR | https://github.com/6529-Collections/6529Stream/pull/736 |
| Active issue | https://github.com/6529-Collections/6529Stream/issues/738 |
| Active PR | https://github.com/6529-Collections/6529Stream/pull/739 |
| Next issue | TBD |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | 2026-09-10 |

## Target

Ship a frozen, tested current-stack release candidate and a matching Sepolia
demonstration, with a repository that developers can navigate. The implemented
stack includes actual Core/registry/manager/ledger integration, accepted artist
attribution, signed native sales and English auctions, immutable splits and
withdrawals, royalties, VRF entropy, metadata, committed genesis and delayed
governance/catalog evolution. The public Core interface remains protected.

Start with [the product guide](../docs/current-stack.md),
[source map](../smart-contracts/README.md),
[interface map](../smart-contracts/interfaces/stream/README.md) and
[deployment guide](../script/current/README.md).

## Integration baseline

- The configured default Foundry suite passes 1,342 tests across 110 suites.
  All thirteen retained gas snapshots pass with unchanged ceilings.
- The corrected-source current wrapper passes eleven real-stack integration
  scenarios and 34 Python checks, plus layout, formatting and Core ABI checks.
- The maximum-content metadata test also passes with fresh transaction
  contexts: router 11,391,401 gas within its 12,000,000 allocation; full Core
  read 12,209,673 gas within a 16,000,000 call. The complete 63,193-byte URI
  and ABI response envelope are preserved.
- Fresh Slither capture covers all 143 production Solidity files. Its
  44 High/Medium detector rows retain 30 Open and 14 reviewed false-positive
  dispositions. This is not an external audit.
- Current-stack, Windows and Slither CI pass at `cac42353`. The full default
  release wrapper and final CI remain in progress. The wrapper found stale
  receipt/catalog/config hashes in the illustrative non-production candidate;
  refreshed bindings pass materialization and its exact check.
- Final checksum/manifest/bytecode/lock verification must run against the
  final integrated inputs after that correction. Do not treat an earlier
  artifact check as proof of a later changed tree.
- All seven CodeRabbit threads have verified fixes or accepted rationale.
  Recheck incremental review before merge. Issue #670 remains open; PR #739
  has no automatic issue-closing references.

The default target-isolated Core size evidence remains
[`release-artifacts/latest/bytecode-release-proof.json`](../release-artifacts/latest/bytecode-release-proof.json).
It describes the engineering compilation. The exact corrected Sepolia candidate
compilation is retained separately under
`deployments/current/sepolia-current-rc-1/compilation` and must not be inferred
from the default proof. Historical proof details are not duplicated in this active run state.

## Corrected Sepolia launch

The exact corrected compilation is retained under
[`deployments/current/sepolia-current-rc-1/compilation`](../deployments/current/sepolia-current-rc-1/compilation/manifest.json).
It contains 148 input sources, no tests, Solidity 0.8.19, global via-IR,
optimizer 200 and Paris. Its manifest retains the exact per-contract size evidence.
The actual-subscription simulation passes with 36 transactions at a 115%
gas margin; its largest signed limit is 16,413,798, below 16,777,216.

Broadcast and the full corrected demonstration are pending funding. The
dedicated deployer is `0x26A3f4505145b5E6164260cc868e50ddd9863697`.
An additional 1.20 Sepolia ETH was requested for redeployment, demonstration
and Chainlink's native-payment reserve. Last observed deployer balance is
0.062757914017426305 ETH with pending nonce 52. These are observations, not
fixed future preflight values; reread balances and fees before broadcasting.

The deployment owner alone controls deployer nonces. Reuse the existing
subscription and isolated RC output, cache, broadcast and operational-state
paths. Its older pending request may fulfill after reserve funding; record
that as historical activity and reread reserve before the corrected request.
The corrected instance needs its own paid mint, actual VRF callback, final
metadata, both split withdrawals and transfer to the artist. Then export
public observations, compare deployed bytecode, verify source and audit the
configuration at one pinned block. Freeze only the supported, tested source
and matching deployment facts; the current candidate is not frozen yet.

The [9 September prototype](../deployments/current/sepolia-2026-09-09/README.md)
predates the source correction. Its 45 deployment transactions, paid mint,
VRF request, 36-instance bytecode comparison, 30 source matches and public
wiring observations are preserved as historical evidence.

## Owners and next actions

| Owner | Current responsibility |
| --- | --- |
| Integrator | Final integrated checks, PR/review/merge, developer interfaces, public deployment evidence and checkout cleanup |
| Deployment | Corrected Sepolia launch and live demonstration; exclusive deployer nonce ownership |
| Product/tooling | Finish the configured default wrapper and reconcile the final artifact tail |
| Independent review | Completed flow/tooling/issue reviews; available for bounded follow-up without a retained builder checkout |

1. Finish the default release checks, reconcile their inputs once, and obtain
   green CI on the integrated change. Merge after review is resolved.
2. On funding arrival, complete the corrected launch and public observations.
   Do not substitute a fork callback for the actual provider callback.
3. Restore the original checkout to merged main from verified recovery state
   and retire the remaining builders once their evidence is preserved.
4. Freeze the candidate and reconcile issue #738 against its actual acceptance.

Builders hand over coherent tested increments to one integrator. Independent
implementation does not wait for unrelated PR cycles. During development use
focused behavior and current-stack tests; broad release validation follows a
stable implementation. Ordinary engineering choices do not go to the owner.

## Repository recovery and remaining scope

Cleanup has retired 54 worktrees and archived 19 superseded tasks. Branch refs,
verified bundles, patches and preserved local files retain the old work. Five
registered worktrees remain: original checkout, integration, deployment,
validation and the immutable review baseline. The original 129 changed tracked
paths and 31 untracked paths are independently preserved and remain untouched.
The active artist-provenance task is retained. One previously retired empty
directory remains after automatic approval review blocked its removal; it has
no worktree registration or source files.

All 29 open issues were reconciled against current implementation and remaining
acceptance; ten stale descriptions were corrected without changing acceptance
or closing unfinished work. Both older PRs #737 and #736 are merged.

Full artist lifecycle/recovery, ERC-20 and additional sale modes, finality and
state-export recovery, the complete production deployment/parameter topology,
advanced entropy recovery and external audit/release evidence remain outside
this first supported build. Their requirements remain in
[ROADMAP.md](ROADMAP.md) and [EXECUTION_BACKLOG.md](EXECUTION_BACKLOG.md).
