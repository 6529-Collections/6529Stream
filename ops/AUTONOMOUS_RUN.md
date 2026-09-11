# Stream delivery state

Updated 11 September 2026. The owner authorizes autonomous implementation,
repository reorganization, independent adversarial review, and testnet delivery.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream` |
| Active PR branch | `codex/developer-launch-kit` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/741` |
| Active issue | `https://github.com/6529-Collections/6529Stream/issues/738` |
| Active PR | `https://github.com/6529-Collections/6529Stream/pull/742` |
| Next issue | `TBD` |
| Source checkpoint | `afa176d3496601abc2c9028a40a757ce2deb838d` (merged PR #741 baseline) |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-09-11 UTC` |

## Active work

[PR #741](https://github.com/6529-Collections/6529Stream/pull/741) merged as
`afa176d3496601abc2c9028a40a757ce2deb838d` after all four CI jobs passed and all
seven review threads were resolved. Its merged tree matches the reviewed
`640cd995` tree. The original checkout is clean on main at that merge.

[PR #742](https://github.com/6529-Collections/6529Stream/pull/742) is the active
developer-kit increment on `codex/developer-launch-kit`. Current-stack tests,
campaigns, client validation and the completed public Sepolia flow are recorded
below. Current release coverage contains 704 files.

Final integration remains pending. The Windows CI job now builds the client
before operator tests, and the verifier-test fixture binds the reviewed Slither
source hash. Developer-tool review corrections have focused passing tests and
independent review, including ABI-ordered PowerShell authorization recovery.
Refresh the dependent release evidence and finish final local validation,
independent review and all six CI jobs before merging PR #742. The supported testnet candidate
freeze and publication follow that merge; neither has occurred. Historical
production and public-beta gate placeholders remain unchanged.

## Retained PR #741 implementation and validation

The following record retains its original checkpoints and rerun/merge-gate
language. Those pending references are historical; PR #741's final acceptance
is recorded above.

The owner requested further implementation while waiting for Sepolia funding.
That funding has arrived and the matching current deployment and native
demonstration have completed successfully.
The active branch is `codex/offline-release-completion`, from merged
[PR #740](https://github.com/6529-Collections/6529Stream/pull/740). This increment
has completed executable product paths in three parallel lanes. The contract changes are
stable. All four CI jobs and the complete source-bound native validation passed
on `3ab8be81`. Two final review corrections bind fallback compiler caches to
Foundry settings and reject literal failing guards in the source-policy checker.
Their focused tests and refreshed release package pass. The final CI run for
`640cd995` passed its earlier checks but reached the 90-minute job limit during
the concluding deployment rehearsal. That job is rerunning in
[run 34535587115](https://github.com/6529-Collections/6529Stream/actions/runs/34535587115).
The developer-kit increment moves checksum/verifier suites into an independent
CI job, removing that serial work from Solidity compilation and rehearsals.

| Owner | Delivery |
| --- | --- |
| Integrator | Governance-hosted state-export publication, challenge, supersession and historical reads ([#668](https://github.com/6529-Collections/6529Stream/issues/668)); shared integration and release evidence |
| Payment builder | Real ERC-20 fixed-price purchase using pinned payer intents, canonical primary policy, exact token settlement and current Core mint ([#664](https://github.com/6529-Collections/6529Stream/issues/664)) |
| Deployment builder | Corrected local/Sepolia runners, artist acceptance and receipt-based token discovery; actual local transactions and fresh-transaction entropy callback proof |
| Independent reviewer | Adversarial review of each implementation and integrated behavior; no implementation ownership |

The publisher stays on the actual Executor. Linked scheduling validation frees
runtime space without moving existing storage or the execution loop. The payment
lane installs the existing primary revenue resolver for supported fixed-profile
assignments; unsupported primary templates and deferred escrow remain explicit.
Both features are covered by real current-stack integration tests. The integrated
revision passes 1,379 default Foundry tests across 114 suites and 28 current-stack
tests across five suites. The current Windows wrapper also passes its 44 Python
tests. The exact current compilation exports 86 targets from 186 sources; the
independent release verifier and packaging review pass all 625 checksummed files.
The earlier 1,390-execution run included twelve additional via-IR executions of
the Core target suite. The latest run retains every distinct test and adds one
payment-cap regression; its smaller count reflects that compiler-profile duplicate.

The patched deployment runner completed a fresh local deployment with its normal
115% gas multiplier: all 43 deployment transactions succeeded after the complete
unsigned plan passed preflight. Paid native mint, final metadata, the Core update
event, both 90/10 split withdrawals, artist transfer and 40 bytecode readbacks
passed. A separate fresh-transaction VRF rehearsal passed with 500,000 gas
forwarded to the real provider/coordinator/Core path; its upstream coordinator is
a local mock, so this does not attest Chainlink service, billing or live fulfilment.
Independent reviewers cleared the implementation, package and local evidence.

The aggregate native check found a stale test-discovery assertion after three
diagnostic tests were added. Its count is corrected to 127 while retaining every
existing suite-partition assertion. Native validation subsequently completed all 285 wrapper statements through
source-bound continuations and focused final-input supplements. Original failed
logs remain retained. The last review-only delta passes 29 governance-policy
tests, 33 toolchain tests and the 625-file offline verifier; the new final CI run
remains a merge gate.

The merged baseline passed 1,346 configured Foundry tests across 111 suites,
eleven current-stack scenarios, thirteen gas snapshots, the complete native
wrapper and all four CI jobs. Its current export has 76 targets from one exact
168-source compiler input; the independent verifier covers 606 files. The source
layout evidence tag preserves the pre-squash provenance required by the release
package. These are completed baseline results, not results for this increment.

The reorganization received independent adversarial review. Automatic approval
review rejected the attempted `AGENTS.md` correction with only
`rejected: blocked by policy`; that file still has stale flat-script commands.
Working commands are in the contributor guides and `scripts/dev.py`. Do not retry
or bypass the rejected edit.

Builders hand over coherent changes to one integrator. Ordinary implementation
choices do not require owner decisions. Run focused checks during implementation;
run the broad integrated validation and deterministic artifact refresh after the
supported behavior stabilizes. Resolve substantive review findings before merge.

## Developer launch kit and testing upgrade

The active increment is [PR #742](https://github.com/6529-Collections/6529Stream/pull/742)
on `codex/developer-launch-kit`, following the now-merged PR #741. It does not
change production Solidity behavior. Completed pieces include the TypeScript
client, a selected-state snapshot exporter, a second-artist product demonstration
and resumable Sepolia stages.

- The client passes 38 tests plus its build, type checks and retained-ABI checks.
  Its snapshot records selected public facts at one block, with explicit coverage,
  canonical hashes and fresh RPC readback. It is not a complete archival export.
- The product demonstration executes 31 local transactions across native/ERC-20
  purchases, auction bids/refunds/settlement, withdrawals and export publication.
  A fresh scenario using the final 177-source production compilation and a
  separately compiled payment-token mock also passes all 31 transactions.
  Production compiler output and cache remain byte-identical. Repeating every
  stage sends no duplicate transactions.
- Launch recovery retains exact transaction intents, reconciles receipts before
  constructing fresh authorizations and provides credential-free status. Its
  independent journal/status suites pass 78 and 27 cases respectively.
- Collection two has completed its artwork, closure, burn block and collection/
  royalty freezes through the normal governance actions. Its portable collector
  package passes independent reconstruction and integrity checks; repeating the
  workflow sends no new transactions. Global metadata, entropy, artist and royalty
  pointers remain governed. This is scoped collection completion, not the full
  artwork-finality design or a freeze of all future rendering authority.
- Five input-fuzz properties cover native settlement and rounding, incorrect
  value, altered signatures, replay and expiry. The first focused run passes
  256 cases per property, plus 32 stateful runs with 2,048 actions and no unexpected
  reverts or discards. Both the successful-activity check and the deliberately
  corrupted payer-accounting oracle test pass. An initial test-helper compiler
  failure is retained separately from the corrected passing run.
- The campaign command and CI wiring pass 20 tooling regressions and independent
  review. The canonical-source quick run and two extended seeds pass 42,240 input
  cases and 133,120 stateful calls across 544 sequences, with no unexpected reverts
  or discards. The warm extended runs take about two minutes each. A separately
  labeled tiny tooling fixture proves failure retention, exact saved-case replay
  under a different seed and full-budget success after correcting the property.
  The focused campaigns use a 112-source closure. Separately, all 36 current
  tests across seven suites pass. A fresh deployment compilation exports 86
  targets from 177 sources; all selected ABI and bytecode files match the prior
  export exactly. Historical snapshots retain their original input identity.

Builders exchange adversarial reviews before integration. The owner explicitly
requests this testing upgrade and defers Lean verification until traditional
implementation stabilizes. The immutable non-release tag
`evidence/developer-kit-2026-09-10` preserves the reviewed collector and original
client/snapshot ancestry before integration. Historical snapshots retain their
original compiler/client provenance when current generated exports change.

## Sepolia and release

The [historical prototype](../deployments/current/sepolia-2026-09-09/README.md)
completed deployment, paid mint and a real VRF request. It predates the final
entropy correction. The prepared
[replacement compilation](../deployments/current/sepolia-current-rc-1/compilation/manifest.json)
is also retained exactly; its source paths predate this reorganization.

Funding was confirmed at Sepolia block 11,678,000 on 10 September at 23:00 UTC:
2.562757914017426305 ETH was available to the dedicated deployer
`0x26A3f4505145b5E6164260cc868e50ddd9863697`. The fresh 45-transaction plan passed
preflight against the matching 177-source compilation. All 45 transactions
succeeded from the frozen `codex/sepolia-launch-kit` checkout. Independent public
readback verifies 40 runtime addresses and 81 configuration checks. The real
paid mint, Chainlink callback, final metadata, both split withdrawals and transfer
to the dedicated artist also succeeded. The immutable non-release tag
`evidence/sepolia-deployment-2026-09-10` preserves the exact deployed source.
The [public instance package](../deployments/current/sepolia-2026-09-10/README.md)
retains independent deployment and demonstration verification. Sourcify reports
creation and runtime matches for all 34 named instances: 25 fresh submissions
and nine existing deterministic library records. Independent comparison of all
68 templates to the current compiler output passes with only declared library
link spans normalized. Final repository integration and review precede the
supported candidate freeze. Only the deployment owner broadcasts.

Core runtime measurements belong to the
[canonical bytecode proof](../release-artifacts/latest/bytecode-release-proof.json)
and its bound compiler/ABI inputs; they are not duplicated in this active run state.
Reread that proof after the reorganized tree is rebuilt and its evidence refreshed.
The source-bound local checks and completed Sepolia flow are distinct evidence.
A frozen testnet release candidate still requires the final reviewed package.

## Recovery and remaining scope

The original checkout is clean on merged main. Cleanup has retired 58 registered
worktrees and archived 19 superseded tasks. All 160 original changed/untracked
paths, recovery refs/bundles and 6,646 original ignored files were preserved and
verified. The latest three retirements additionally preserve 2,064 ignored files
and verified source bundles. Three registered worktrees remain: original,
developer launch kit and frozen Sepolia launch. The launch-kit checkout is active
implementation work. The retired integration directory is empty but a process
still holds its directory handle; its Git worktree registration has been removed.

After the final merge and validation finish, preserve and hash the developer
kit's remaining compiler outputs, caches and recovery files before retiring that
worktree. The intended two retained checkouts are the original repository and
the frozen Sepolia launch checkout. Retained evidence and prior user changes
must remain recoverable.

The separate Seize artist-provenance task completed; it is not a Stream implementation lane. An empty previously retired
directory remains after automatic approval review blocked its removal.

Issue [#738](https://github.com/6529-Collections/6529Stream/issues/738) tracks the
supported working release and testnet outcome. Full artist lifecycle/recovery,
broader payment modes, finality recovery, archival export operations, the full production
configuration and external audit evidence remain explicit unfinished work.
See [the roadmap](ROADMAP.md) and [execution backlog](EXECUTION_BACKLOG.md).
