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
| Source checkpoint | `bcb43e06` (active integration); RC1 remains `569bf87f1fa808787d324f6e1582924b5ccf1d40` |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-09-11 UTC` |

## Active work

One integrator owns technical decisions and delivery. Two builders and a separate
reviewer advance independent domains; all rows in [V1_DELIVERY.md](V1_DELIVERY.md)
remain in scope. [Safe acceptance](SAFE_ACCEPTANCE.md) covers every supported
contract call, including owner actions, payments, NFT custody and reads.

| Lane | Branch | Current deliverable |
| --- | --- | --- |
| Integrator | `codex/v1-integration` | Current-stack composition, remaining unit fixtures, operator onboarding, client/signing migration, CI and release |
| Artist | `codex/v1-artist-authority` | Content consent and defensive freeze handoff, then remaining identity and authority operations |
| Revenue | `codex/v1-revenue` | Actual shared settlement and permit consumers, then missing sale mechanisms |
| Reviewer | Read-only across the above | Independent source, adversarial behavior, interface compatibility and matching runtime acceptance |

Fixed-sale and auction funding, scoped delegation, refusal/withdrawal and
expected-binding acceptance are integrated. Collaborator operations 5/6/7
(`90369bf0`) and current template economics consent (`871046b2`) bring the
integration source to 15 of the 57 artist operation IDs. Revocation operation 54
is integrated as `6a0f5a4f`; content-authority operations 17 and 21 are integrated
as `bcb43e06`, bringing the source count to 18. Their 96-case domain suite and
exact production artifacts received independent review. The metadata counterpart
is committed separately as `f73882e0`; actual composition tests are running.

Collection template materialization and typed economics facts are integrated.
Template fixed-sale funding (`ddf01864`) passed 76 focused tests and four fuzz
properties per compiler mode. Governed asset permit-capability attestations
(`3287fcd5`) passed 13 tests plus fuzzing per mode. These increments received
independent review. Revenue work now implements actual shared settlement and
permit consumers; registry capability declarations alone do not complete them.

The completed combined snapshot passed 36 cases, including all nine ERC-20 and
22 native-sale/auction cases. Two failures were an incorrect Safe event-layout
assertion and an old invariant counterexample loaded from the wrong directory.
The corrected runner passes all three invariant tests with 32 sequences of 64
calls and zero reverts against the unchanged snapshot. Original failed evidence
is preserved. The Safe assertion is corrected in source.

The new combined snapshot passed all 39 executed Safe, ERC-20, native-sale,
auction and invariant cases, including actual Safe template consent/purchase/
escrow/flush/claim and 2,048 stateful calls with zero reverts. Its 11 royalty cases
were initially blocked by a one-day execution window below the seven-day floor.
The corrected window exposed six fixture errors: three omitted authorization
IDs and three reads passed the wrong mapped collection. Five tests passed.
The corrected requests pass all 11 cases in a separate unchanged-production
snapshot, independently reviewed. Original results remain. The evidence is the
original 39 cases plus this separate 11-case run, not a latest-source full pass.
These planning gas allowances do not establish normative cold-gas acceptance.

The metadata host counterpart for artist content consent and defensive freezes
passes 30 domain tests, including actual Safe administration and a separate Safe
freeze relayer. One-use approval records, exact content evolution and versioned
events are independently reviewed. Actual modular artist authorization and
executed-finality composition remain pending; no substitute readiness provider
was added. The source export/client projection still requires migration.

The saved artist-authority activation plan publishes calldata and checks exact
commitments, submission headroom, resumption and prior execution. Operator
onboarding, phase completion and final Manager ownership handoff still need a
complete resumable consumer. The client now prepares exact Safe CALL payloads
and checks the expected Safe execution result. Its ABI/signing projection still
targets retained RC1; migration to the new stack remains explicit work.

Independently accepted fixture migration checkpoints include 58 historical
Manager/manifest, six flat-attribution, 16 ERC-20 adapter and 75 resolver/factory/
auction domain tests. The royalty fixture now uses actual current artist consent
and canonical governance publication. The latest ABI-only check covers 443
Solidity sources with no errors before the content-owner integration; the latest
check includes 446 sources without errors. This is not a broad build or candidate
acceptance. Client checks pass 47 tests; three new tests also
exercise successful and failed calls through actual pinned Safe versions.

The next draft PR will contain a coherent tested implementation increment.
Builders run focused checks before handoff; root owns broad validation,
deterministic artifacts, deployment and completion of the entire v1 ledger.

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
