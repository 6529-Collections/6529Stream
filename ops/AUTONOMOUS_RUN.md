# Stream delivery state

Updated 10 September 2026. The owner authorizes autonomous implementation,
repository reorganization, independent adversarial review, and testnet delivery.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream` |
| Active PR branch | `codex/developer-experience-reorganization` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/739` |
| Active issue | `https://github.com/6529-Collections/6529Stream/issues/738` |
| Active PR | `https://github.com/6529-Collections/6529Stream/pull/740` |
| Next issue | `TBD` |
| Source checkpoint | `7b4ef22b052419e88d56cf7f207a7a7738dba7a7` |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-09-10 UTC` |

## Active work

PR [#739](https://github.com/6529-Collections/6529Stream/pull/739) merged as
`330ac1d40b1a0d385399ca68423503c892ea0c04`. Its tree matches the tested integration:
1,342 default Foundry tests, eleven current-stack scenarios, all final CI checks,
and eight resolved review threads. These results describe that revision.

The active branch is `codex/developer-experience-reorganization`, based on that
merged commit. The owner requested a full first-principles organization and
documentation pass before freezing the supported release candidate. The work
includes coherent public interfaces, accurate integration guides, a focused
contributor workflow, organized tests and maintenance tooling, and a separate
adversarial reviewer. A final review and validation pass must cover the actual
reorganized tree; earlier tests alone do not validate later edits.

The reorganization is now in [PR #740](https://github.com/6529-Collections/6529Stream/pull/740).
Its source checkpoint passes 1,346 configured Foundry tests across 111 suites,
including maximum-size artwork through the current Core. All eleven current
integration scenarios and thirteen retained gas snapshots pass. The fresh current
export contains 76 targets from one exact 168-source compiler input. The independent
offline verifier passes all 589 covered files; the full native wrapper and PR CI
are still running. These results do not complete the funded Sepolia demonstration.

Independent adversarial review has cleared the source/API organization, developer
commands, current export, historical provenance, cleanup, and package integrity
changes. One instruction-surface defect remains: automatic approval review rejected
the attempted `AGENTS.md` update with only `rejected: blocked by policy`. That file
retains stale flat-script commands. The contributor guides and `scripts/dev.py`
contain the working commands; no retry or bypass of the rejected edit was attempted.

| Owner | Responsibility |
| --- | --- |
| Integrator | Tooling, test organization, shared decisions, final integration and delivery |
| Solidity builder | Domain interfaces, caller capabilities, NatSpec and ABI/runtime comparison |
| Documentation builder | Current developer journey, integration examples and reference organization |
| Independent reviewer | Adversarial newcomer tasks and repeated review of the resulting repository |

Builders hand over coherent changes to one integrator. Ordinary implementation
choices do not require owner decisions. The reviewer remains independent of
implementation. Review ends when meaningful findings are resolved, not after a
fixed number of passes.

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
The active artist-provenance task is retained. An empty previously retired
directory remains after automatic approval review blocked its removal.

Issue [#738](https://github.com/6529-Collections/6529Stream/issues/738) tracks the
supported working release and testnet outcome. Full artist lifecycle/recovery,
additional payment modes, finality/state-export recovery, the full production
configuration and external audit evidence remain explicit unfinished work.
See [the roadmap](ROADMAP.md) and [execution backlog](EXECUTION_BACKLOG.md).
