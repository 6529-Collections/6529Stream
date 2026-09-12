# Stream delivery state

Updated 12 September 2026. The owner authorizes autonomous completion of the
remaining full v1 features, independent adversarial review and matching testnet
delivery. [V1_DELIVERY.md](V1_DELIVERY.md) is the active execution ledger.

## Current Repository State

| Field | Value |
| --- | --- |
| Remote | `https://github.com/6529-Collections/6529Stream` |
| Active PR branch | `codex/v1-integration` |
| Last merged PR | `https://github.com/6529-Collections/6529Stream/pull/742` |
| Active issue | `https://github.com/6529-Collections/6529Stream/issues/743` |
| Active PR | Draft [#744](https://github.com/6529-Collections/6529Stream/pull/744) |
| Next issue | `TBD` |
| Source checkpoint | Stable router `f445ac79`, artist compiler repair `1e3087a2`, museum abstract/nonvisual132 `db3c8153` and Base64 repair `164f867b` are integrated. Content-checkpoint computation/composition is independently accepted. Actual typed finality and deployment planner integration remain active. RC1 remains `569bf87f1fa808787d324f6e1582924b5ccf1d40` |
| Roadmap file | `ops/ROADMAP.md` |
| Execution backlog file | `ops/EXECUTION_BACKLOG.md` |
| State file | `ops/AUTONOMOUS_RUN.md` |
| Last updated | `2026-09-12 UTC` |

## Active work

Exact artist publication authorization is integrated as `a7114aeb`, with the
complete 271-test artist cohort independently reviewed. Actual registry-to-
metadata-host publication passes four reviewed cases and is integrated as
`85f44fbd`; Core and Executor remain explicit unit boundaries. The dedicated
independent-attestor host is integrated as `4673f248`, with 22 reviewed cases,
256 fuzz inputs and both production profiles fitting. Artist finality/sanction
is the artist builder's current task. Stable router presentation is integrated
as `f445ac79`; the second builder resumes the remaining museum mappings.
The integrator's 17-case checkpoint suite and seven actual Core/router cases
pass, including Safe custody, burns and atomic retry. Inline-image admission
and the Base64 padding repair (`164f867b`) have 19 focused tests with fuzzing.
The corrected Router fits both compiler modes; the retained renderer cohort
passes 61 IR cases. The typed evidence producer and full finality remain open.

The latest museum increment adds faithful abstract/nonvisual projections as
`db3c8153`, retaining the original package and source identity. All 132 tests
and five generators pass again locally. Its predecessor's 104 tests pass
Windows and Linux CI; the new version has a matching fifth generator CI check.
The builder continues the first PREMIS cross-format increment.
Full authenticated-chain exports and institutional acceptance remain open.
Complete archival artifact coverage is integrated as `880bac6d`, with 26
reviewed domain tests and fuzzing. The corrected metadata host/adapter cohort
passes 23 tests in both compiler modes; separate actual-Executor tests cover
root authority, ordinary-proposer rejection and multi-call execution. Actual
artist publication, typed finality and discovery still need composition.

The artist owner/acceptance compiler repair is integrated as `1e3087a2`, with
exact preimage/event checks and matching owner interfaces/storage. Latest remote
CI at `90c8fdcf` predates that repair and still fails compilation. Deployment
planning remains unresolved: the catalog self-view call helps minimal compiler
probes but fails current Foundry execution protection, even outside broadcasting.
An independent separate-helper simulation passes default protection without an
extra broadcast nonce; integration into Stream's actual planner is next.
No complete-build or working deployment-script repair is claimed. Release
checksums and the Slither snapshot also await the later
stabilized-source regeneration. See [V1_DELIVERY.md](V1_DELIVERY.md).

One integrator owns technical decisions and delivery. Two builders and a separate
reviewer advance independent domains; all rows in [V1_DELIVERY.md](V1_DELIVERY.md)
remain in scope. [Safe acceptance](SAFE_ACCEPTANCE.md) covers every supported
contract call, including owner actions, payments, NFT custody and reads.

| Lane | Branch | Current deliverable |
| --- | --- | --- |
| Integrator | `codex/v1-integration` | Actual metadata/finality producers and discovery, staged product/operator activation, whole-current compiler diagnostic, client and release |
| Artist | `codex/v1-artist-authority` | Archival artifact coverage integrated; full artist publication regression, actual finality/sanction/recovery and typed preparation |
| Revenue | `codex/v1-revenue` | Museum package104 integrated; museum abstract/nonvisual132 integrated; remaining format and chain-adapter work |
| Reviewer | Read-only across the above | Independent source, adversarial behavior, interface compatibility and matching runtime acceptance |

Signing-domain discovery is integrated as `134e0f58`. The native fixed,
native price-program and universal fixed families retain their distinct signed
preimages and existing interface IDs. Four focused tests and 256 fuzz inputs
pass independent review, including actual threshold Safe reads and native
purchases. Both production compiler profiles fit; that domain suite uses
explicit Core, Manager and artist fixtures. The
[integration guide](../docs/integrations/sale-signing-domains.md) explains which
getter clients must use. Full ABI/client and selector acceptance remain open.

Refund-window source is integrated as `ea107e58`: all 38 files match the
independently accepted handoff, with 63 tests, two 256-input fuzz properties,
128 compiler sources, 160 artifacts and both production profiles verified.
The current refund composition passes all eight cases with independent review:
four refund workflows and four retained identity-dispute regressions. It covers
real Core, Manager, artist, settlement, entropy, governance and threshold Safe
contracts; only the external randomness service is doubled. This captured run
predates dismissal. Standard native Dutch source is integrated as `b3152198`,
with 33 domain cases and two 256-input fuzz properties independently accepted.
Its separate four-case current-contract run passes independent review after
correcting a test-only role name. The initial three-pass/one-fail
snapshot is retained, and the production snapshot is unchanged by the correction.

Dismissal operation 58 is integrated as `3489d360` with the separate timing
interface move `09afe2b8`. The final 202-case domain run passes independent
review. Four actual Executor/Safe dismissal cases plus eight refund/dispute
regressions now pass independent review. Five new current lifecycle tests cover
succession records, rotated-cohort timing and retirement-specific standing.
All five now pass alongside four Dutch and four refund regressions on the
integrated supplemental recorder, with independent source and artifact review.
The initial twelve-pass/one-fail run is retained: the succession test supplied
nonce zero despite reading nonce eleven. The one-line correction submits the
observed nonce; all production artifacts are unchanged. The effective
source/configuration gate remains separate work.

Supplemental clearing settlement is integrated as `f49e7bc1`, with 21 new tests,
103 prior regressions, five 256-input fuzz properties and both production
compiler profiles independently accepted. This is a financial primitive tied
to an original paid mint. The complete clearing consumer is now integrated as
`d807421e`: 59 domain cases, five fuzz properties and both compiler profiles
pass independent review. Two actual-current Safe cases also pass independent
review (`d9d7d46b`): required artist consent, paid mints, excess and immediate
rebate claims, official supplemental settlement, and partial escape preserving
NFT custody. They use a fixed profile, zero reveal fee and the explicit external
randomness double. The original domain purchase measured 6,843,542 gas. A
separate actual-current trace measures 8,755,856 gas in the first consumer call;
its real Manager and recorder calls each exceed the 500,000 collector ceiling
alone. These are qualified in-test measurements, not a cold-call admission.
Compression and storage optimization continue, with shared-path gas work kept
explicit so it does not serialize every remaining sale feature.
The new fixed linked libraries are documented in its
[integration guide](../docs/integrations/native-clearing-supplemental-settlement.md).

The archival provider prerequisite is integrated as `ee21cff9`: 14 checkpoint
tests and 15 coverage tests, two fuzz properties and separate default compiler
products pass independent review. Its explicit observer-quorum profile, native
inclusion checks and independent storage/fixity records are described in
[ADR 0031](../docs/adr/0031-quorum-anchored-estate-archival-profile.md).
The network-derived native inclusion fixture in `352e3e26` passes four cases
and fuzzing in both profiles with independent review. It verifies a historical
four-byte public payload and real native paths retrieved through one gateway;
quorum and consensus authentication remain distinct. Five new current-contract
2-of-3 Safe governance cases pass independent review (`c980f8d6`). Estate domain
activation and cancellation have nine independently reviewed cases on the
builder's branch; its complete 225-case regression run is in progress.
Estate/current-stack composition, complete network rehearsal and the full call
gas budget remain open.

The actual constructor dependency exposed a deployment-order gap: the provider
requires initialized canonical roles before the artist suite can deploy.
[ADR 0032](../docs/adr/0032-governance-foundation-before-product-activation.md)
resolves this through the existing governance foundation and later product
activation paths. The shared planner and two actual-current foundation tests
pass independent review (`97599d12`). The original five-leaf foundation seal is
historical evidence, distinct from the complete release inventory. A further
three-case cohort exercises delayed Safe catalog extension and mint-product
activation; migration of the shared artist fixture and broadcast script remains
integration work.

The deployment script's large positional return expression caused the isolated
CI compiler failure. Named return fields fix that exact reproduction without
changing its ABI or compiler settings (`fa52a5b3`). The separate compile against
260 integrated deployment inputs also passes independent review; this is script
code generation, not a deployment or full CI pass. Shared sale/permit interfaces
are separated in `c2332e48`. The active source inventory now contains 392 files
and the layout check passes; the refresher's 46 tests passed at its earlier
365-file checkpoint. Scoped formatting still identifies three artist collaborator
files and the entropy coordinator for their owners to format at the next source
checkpoint. Historical artist-57
checks now execute against their exact RC1 baseline while enforcing unchanged
frozen files in the active checkout. Current design and contract checks continue
against current sources. Full CI, generated
candidate artifacts and the new testnet rehearsal remain pending.

The twelve-case snapshot at `72c208f2` passes independent review for actual
Core/Manager/artist/Executor/Safe composition: five native sale cases, three
universal ERC-20 cases and four ARRNG cases. Its captured production inputs are
`ed8f0e40`; later fee and consent source changes need their own evidence.
Rotation (`c71003dc`) and price programs (`9eae0d67`) are integrated with their
133-case and 72-case focused reviews. Sale consent and attribution state now have
144 distinct focused cases and a corrected actual-Safe negative follow-up.
The 29-case legacy rejection and 82-case native/universal enforcement results
are independently accepted, and all 30 integrated source files match their
accepted handoffs. The ten-case explicit-capability correction is integrated as `592635fc`.
The next current snapshot passed all fourteen prior cases, including the final
unique-holder activation planner. Its three new REQUIRED purchase tests failed
in their direct artist-approval nonce setup; the corrected two-file fixture
change has independent source review and its separate three-case runtime now
passes independent artifact review. All 114 production artifacts match the
original snapshot; the original fourteen-pass/three-fail result is retained. This captured composition predates governed entropy timing
and the later operation-33 artist source.

The reveal-fee increment has independently reviewed 44-case domain and
30-case actual-Core metadata results, plus six planner regressions using the
actual RoleRegistry and an explicit execution-context fixture. Both production
compiler profiles fit. The fourteen-case current composition has passed and
received independent source/artifact review, including actual Safe-funded
ARRNG mint, reveal, residual treasury withdrawal and requester credit.
The final planner adds unique treasury/reveal-owner checks after that run's
capture; its separate six-case proof must not be confused with actual Executor
composition. The new governed timing host and permissionless lapsed-SLO request
have independently accepted 54-case domain and 30-case metadata results; both
production compiler profiles fit. Its separate seven-case actual Executor/Safe
composition passes independent review, including the final unique-holder planner.
That run predates the later operation-33 artist source. This constructor and
storage-layout increment is for new
deployments. The later refund composition now proves admitted AT_MINT requests
and provider-failure retry. Complete entropy recovery remains. Every feature
row in the ledger stays in scope.

Identity-compromise operation 33 is integrated as `677b9ae9`: 159 focused tests,
existing interface/storage compatibility and seven actual deployment traces
passed independent review. Actual current composition `b002c4d4` adds four
Safe/Executor cases alongside seven retained entropy cases, all independently
accepted against 245 captured files and 273 compiler artifacts. It covers exact
delayed arbitration, per-call batch context, role-loss/reason rollback and mint
denial without blocking held-NFT transfers. Class 2 proves the indexed guardian
window and delayed execution, not a guardian veto. Deployment catalog admission
is separately source-reviewed. This run predates succession.

Succession operations 36/37 are integrated as `8227e0b6` from the independently
reviewed 17-file handoff: 185 tests, 201 compiler sources, 87 production artifacts,
25 prior ABI/storage comparisons and eight actual CREATE traces pass. Its new
fixed reader deployment library preserves Registry child nonces and pins. Only
the existing IR artist profile is accepted; actual current succession and
deployment inventory composition remain to be demonstrated.

[ADR 0029](../docs/adr/0029-identity-contest-dismissal-and-cohort-closure.md)
defines the missing dismissal transition and history-preserving cohort closure.
The design requires typed cause capture on both veto and filing paths. Its
[effective extension design](../docs/architecture/artist-operation-extension-v1.md)
preserves all historical packet/schema bytes and adds the exact typed row 58.
The design check and eleven adversarial tests pass. Source and domain runtime
are now integrated; effective source/configuration and actual Executor/Safe
acceptance remain pending. Estate implementation continues in parallel.

Fixed-sale and auction funding, scoped delegation, refusal/withdrawal and
expected-binding acceptance are integrated. Collaborator operations 5/6/7
(`90369bf0`) and current template economics consent (`871046b2`) bring the
integration source to 15 of the 57 artist operation IDs. Revocation operation 54
is integrated as `6a0f5a4f`; content-authority operations 17 and 21 are integrated
as `bcb43e06`, bringing the source count to 18. Their 96-case domain suite and
exact production artifacts received independent review. The metadata counterpart
is committed separately as `f73882e0`. Actual composition (`af37d8ed`) passes
seven tests: two content workflows and five Safe workflows, including real
minting and template settlement. Independent review binds the captured inputs
and all 209 relevant artifacts. Identity revision operation 25 (`3f6a5dd4`)
brings the source count to 19. Its 109 tests, preserved interface/storage
prefixes and 30 production artifacts received independent review; its current
composition now passes with the payment, content and Safe workflows below.

Collection template materialization and typed economics facts are integrated.
Template fixed-sale funding (`ddf01864`) passed 76 focused tests and four fuzz
properties per compiler mode. Governed asset permit-capability attestations
(`3287fcd5`) passed 13 tests plus fuzzing per mode. These increments received
independent review. Shared settlement, the ERC-20 payer adapter and signed
fixed-profile consumer are integrated as `18dbe54c`. Their 29 tests plus 256 fuzz
inputs pass with independent source/artifact review. Current-Core composition now
passes in the ten-case snapshot below. Native shared settlement is integrated as
`f9162df3`: 55 domain cases and three fuzz properties with 256 inputs each pass
with independent source/artifact review. Both product compiler profiles fit the
runtime caps and preserve the preceding recorder interface/storage and ERC-20
payer implementation. The native domain suite uses actual resolver, factory,
wallet, escrow and Safe contracts. The separate actual Core/Manager/artist
composition now passes all three native cases and three ERC-20 regressions.
Independent review verifies the captured sources and all 245 compiler artifacts,
with all 95 nonempty production runtimes within the deployment cap. The original
five-pass/one-fail snapshot is retained; its template setup was corrected to
create the template through its actual governance owner before assignment.
The canonical full-digest Manager authorization correction is integrated as
`5ecae362`, with two focused tests and independent source/artifact review. A
ten-case actual-current run passes all three new universal payment workflows,
two content and five existing Safe cases, using the accepted identity revision.
Independent review matched all 218 Solidity sources and three Safe fixtures to
`4e9a41b1`, bound 237 artifacts to retained compiler outputs, and confirmed all
90 nonempty production runtimes fit. These actual mint, replay and rollback
results do not establish full-repository or new-candidate acceptance.

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
events are independently reviewed. Actual modular artist composition now passes
the separate seven-case current run. Executed-finality composition and the
source export/client projection still require implementation and migration.

The saved artist-authority activation plan publishes calldata and checks exact
commitments, submission headroom, resumption and prior execution. The new
stateless phase setup planner passes seven actual-current tests with real
two-owner Safes, exact direct consent nonces, confirmed-state resumption,
multiple phases, final Manager handoff and an actual paid mint/reveal. Its JSON
encoder uses the matching compiled planner ABI. Independent review verified
203 Solidity inputs, three Safe fixtures and 223 exact compiler artifacts; the
planner runtime is 11,219 bytes and the protocol contracts are unchanged.
Full identity onboarding and
the older deployment runners still need a complete consumer. A proposed immediate genesis activation failed
three actual tests because the bootstrap actor cannot propose final-root role
mutations. That prototype is withdrawn; the same snapshot's five existing Safe
cases pass. The accepted delayed activation and production guards are retained.
The client prepares exact Safe CALL payloads
and checks the expected Safe execution result. Its ABI/signing projection still
targets retained RC1; migration to the new stack remains explicit work.

Independently accepted fixture migration checkpoints include 58 historical
Manager/manifest, six flat-attribution, 16 ERC-20 adapter and 75 resolver/factory/
auction domain tests. The royalty fixture now uses actual current artist consent
and canonical governance publication. Five preserved resolver tests (`f803f482`)
replace the old fixture's still-supported resolver assertions; the obsolete
settlement API is retired. The latest ABI-only check covers 474 Solidity sources,
including the operator setup tests, with zero
errors. This is not a broad build or candidate
acceptance. Client checks pass 47 tests; three new tests also
exercise successful and failed calls through actual pinned Safe versions.

Draft [PR #744](https://github.com/6529-Collections/6529Stream/pull/744) exposes
the current integrated implementation and its exact acceptance boundaries.
CodeRabbit review is requested. Builders run focused checks before handoff; root owns broad validation,
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
