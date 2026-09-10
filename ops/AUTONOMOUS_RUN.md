# Stream delivery state

Updated 10 September 2026. The owner authorizes autonomous implementation,
repository reorganization, independent adversarial review, and testnet delivery.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream` |
| Active PR branch | `codex/offline-release-completion` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/740` |
| Active issue | `https://github.com/6529-Collections/6529Stream/issues/738` |
| Active PR | `TBD` |
| Next issue | `TBD` |
| Source checkpoint | `2e675281b18f8881b341eb47cd26cd60ad63f6b0` (merged baseline) |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-09-10 UTC` |

## Active work

The owner requested further implementation while Sepolia funding is pending.
The active branch is `codex/offline-release-completion`, from merged
[PR #740](https://github.com/6529-Collections/6529Stream/pull/740). This increment
builds executable product paths in three parallel lanes, then integrates and
validates the resulting source once it stabilizes.

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
Both features require real current-stack integration tests. Existing tests and
artifacts do not attest these new changes.

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

## Sepolia and release

The [historical prototype](../deployments/current/sepolia-2026-09-09/README.md)
completed deployment, paid mint and a real VRF request. It predates the final
entropy correction. The prepared
[replacement compilation](../deployments/current/sepolia-current-rc-1/compilation/manifest.json)
is also retained exactly; its source paths predate this reorganization.

Additional test ETH is still outstanding for the replacement deployment and
Chainlink native-payment reserve. The dedicated deployer is
`0x26A3f4505145b5E6164260cc868e50ddd9863697`; its last observed balance was
0.062757914017426305 ETH. Reread live balances, fees and nonces before use.
Only the deployment owner broadcasts. Funding arrival does not authorize using
a stale compilation: reconcile the reorganized source and compiler artifacts
first, then run the matching paid mint, real callback, final metadata, both split
withdrawals and artist transfer. Publish public source/bytecode/configuration
verification and freeze the supported candidate after those steps pass.

Core runtime measurements belong to the
[canonical bytecode proof](../release-artifacts/latest/bytecode-release-proof.json)
and its bound compiler/ABI inputs; they are not duplicated in this active run state.
Reread that proof after the reorganized tree is rebuilt and its evidence refreshed.
The previous revision's passing checks above do not attest the new compilation.

## Recovery and remaining scope

The original checkout is clean on merged main. Prior cleanup retired 55 worktrees
and archived 19 superseded tasks. All 160 original changed/untracked paths, recovery
refs/bundles and 6,646 ignored files were preserved and verified. Four registered
worktrees remain: original, integration, deployer and immutable review baseline.
The separate Seize artist-provenance task completed; it is not a Stream implementation lane. An empty previously retired
directory remains after automatic approval review blocked its removal.

Issue [#738](https://github.com/6529-Collections/6529Stream/issues/738) tracks the
supported working release and testnet outcome. Full artist lifecycle/recovery,
broader payment modes, finality recovery, archival export operations, the full production
configuration and external audit evidence remain explicit unfinished work.
See [the roadmap](ROADMAP.md) and [execution backlog](EXECUTION_BACKLOG.md).
