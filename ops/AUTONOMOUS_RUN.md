# Stream delivery state

Updated 11 September 2026. The owner authorizes autonomous completion of the
remaining full v1 features, independent adversarial review and matching testnet
delivery. [V1_DELIVERY.md](V1_DELIVERY.md) is the active execution ledger.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream` |
| Active PR branch | `codex/v1-integration` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/742` |
| Active issue | `https://github.com/6529-Collections/6529Stream/issues/743` |
| Active PR | `TBD` |
| Next issue | `TBD` |
| Source checkpoint | `569bf87f1fa808787d324f6e1582924b5ccf1d40` |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-09-11 UTC` |

## Active work

One integrator owns technical decisions, shared interfaces and current-stack
integration. Two builders and a separate independent reviewer work concurrently.

| Lane | Branch | Current deliverable |
| --- | --- | --- |
| Integrator | `codex/v1-integration` | Full-v1 feature ledger, shared artist/payment/finality decisions, metadata/revenue provider reads and integration |
| Artist | `codex/v1-artist-authority` | Real identity, two-sided binding and eligible mint consent with mandatory floor records; manager hooks and independent pause |
| Revenue | `codex/v1-revenue` | Stateless claim aggregation over at least 20 real wallets; failure isolation and event-based discovery |
| Reviewer | Read-only across the above | Independent interface, source, adversarial-test and scope review |

No feature in this new phase is yet marked integrated. The artist first slice
covers operation IDs 1/2/14/15/18/24/52, including repeated economics and
attestation records where the specification requires them. Root and the reviewer
resolve the exact shared dependency reads; builders do not create readiness flags
or silently bypass required consent. The first payment increment is independent
of universal settlement, allowing both lanes to advance together.

The next draft PR will include a coherent tested implementation increment.
Builders run focused compilation and tests before handoff; root owns broad
validation, deterministic artifact refresh, integration and public deployment.
The first 48-hour sprint is a delivery target, not a full-v1 completion claim.

## Completed supported RC1

[PR #742](https://github.com/6529-Collections/6529Stream/pull/742) merged as
`569bf87f1fa808787d324f6e1582924b5ccf1d40`; its tree matches reviewed
`66f48d55b17a3cb79ba9b8bb0fcaa0ba4e8102f8`. All six final CI jobs and four
rehearsals passed. The [published testnet RC1](https://github.com/6529-Collections/6529Stream/releases/tag/testnet/current-rc-1)
contains the exact source archive and independently verified freeze record.
Issue #738 is closed completed.

The Sepolia native demonstration completed a paid mint, actual Chainlink
fulfillment, final metadata, both split withdrawals and artist transfer. The
public package records 45 deployment and nine activation/demo transactions.
Current validation passed 36 tests, 38 client tests, 42,240 input-fuzz cases and
133,120 stateful calls. The default suite passed 1,387 distinct tests; the
release verifier checked 704 files. ERC-20, auction, export and collection
completion have their separately scoped local demonstrations.

All nine reported CodeRabbit findings were resolved. Its final requested rerun
was rate-limited; the final source and published assets received separate
independent review. Broader v1 and audit acceptance were not claimed.

Cleanup retired 59 worktrees, archived 19 superseded tasks and retired 285 merged
origin branches after exact preservation. Original main and the frozen Sepolia
checkout were retained. This phase adds only one integration and two builder
worktrees; retire them after reviewed integration. Preserve recovery bundles,
source tags, private deployment evidence and the security remote.

The [RC1 run-state history](https://github.com/6529-Collections/6529Stream/blob/569bf87f1fa808787d324f6e1582924b5ccf1d40/ops/AUTONOMOUS_RUN.md)
retains earlier checkpoints. Its pending-merge/funding language is historical.
Automatic approval review previously rejected correcting AGENTS.md and one empty
retired-folder deletion with only `blocked by policy`; neither was bypassed.
Current commands are in CONTRIBUTING.md, docs/tooling.md and scripts/dev.py.

## Continuation

Read the current feature ledger and process/commit checkpoint before resuming.
Continue active workers rather than creating duplicate compilers or broadcasts.
The completed RC1 checkpoint is historical; this phase has a separate full-v1
checkpoint and tracker. Report meaningful delivered capabilities, failures or
critical-path changes. Keep routine choices with the integrator.

Lean remains deferred. External audit and production acceptance stay separate
from feature implementation. A new candidate must have its own source identity
and deployment evidence; never move the RC1 tag or reuse its public proof for
changed contracts.
