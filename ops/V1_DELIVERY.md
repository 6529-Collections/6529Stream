# Full v1 implementation delivery

Started 11 September 2026 under the owner's autonomous delivery authority.
This is the active implementation plan. The normative specification set in
[spec policy](../docs/spec-policy.md) still defines v1; this plan organizes its
completion and does not narrow its requirements.

## Starting point and outcome

Supported testnet RC1 is complete and published from
`569bf87f1fa808787d324f6e1582924b5ccf1d40`. Its source tag and deployment evidence
remain immutable. The next outcome is the full specified feature set running
through actual current contracts, with independent review, tests, developer
interfaces and a newly identified candidate. External audit and production
ceremony acceptance remain separately visible requirements.

The prior 45-60% assessment was a qualitative feature estimate, not a measured
requirements pass rate or estimate of remaining time. This ledger replaces
percentage-based progress reporting with concrete capabilities and evidence.

## Latest integration: 12 September

The Router now implements [artist-approved content-root publication](../docs/integrations/content-root-publication.md).
Seventeen focused cases and 256 fuzz inputs pass in both compiler modes. Four
cases compose actual Router rendering, schema/store, inventory, checkpoint,
leaf verification and archival artifact aggregation, including threshold Safe
publication. Core membership, governance execution, artist approvals, archival
receipts/families and Finality/provider bindings remain explicit boundaries.
Exact registered definition bytes, publisher/grant revision, artist association,
lineage, full events, late rollback and nested gas headroom are checked.
The final Router fits at 24,248 bytes default and 23,666 IR; its original ABI
and storage prefix are preserved. The retained 61 rendering cases pass. Two
maximum-content cases also pass with the actual TokenReads library binding
verified and cooled: Router 11,909,000 gas, Core 12,725,439 and complete
63,193-byte URI. These remain fixture account-cooling measurements.

The delegation compiler repair (`54087312`) preserves its signed commitments;
the separate admission fix (`c7de0ad6`) distinguishes Router from the generic
metadata record host. Both have independent focused reviews. Operation 13's
full 303-name artist cohort is running; actual finality execution, typed scope
provider/discovery and complete constructor/deployment migration remain open.

Museum IIIF correspondence is integrated as `22318d25`. Independent root
readback accepts 108 exact files plus preserved/added license line-ending rules,
all seven generators and all 28 four-media example outputs. The reviewed test
union has 183 distinct cases (182 original plus 34 after one corrected identity
predicate); this is not a single latest-source 183-case run. Windows/Linux CI
passes the preceding 149-test revision at `d0094ca6`, run 34709755563. The new
CI step checks IIIF and allows 25 minutes for the expanded cohort. LIDO and the
remaining museum formats, packaging, chain authentication and institutional
acceptance continue in parallel.

Signed artist sanctions and canonical finality admission are integrated as
`50bd3935`, followed by the separate historical-test migration `cb332bc7`.
Independent review binds all 293 artist test names: 292 passing original cases
plus one corrected configuration-hash oracle against unchanged production.
The correction adds the actual finality/provider runtime pins and operation 12
to the expected configuration. The separate migration passes 101 cases in both
compiler modes: 79 preserved historical lifecycle cases and 22 current read or
retirement checks. The old local-clock lifecycle is explicitly historical;
current preview replacement and archive-proof finalization remain required.
All reviewed production products fit, with prior artist ABI and storage
compatibility retained. Root-owned current fixtures and deployment constructors
still need migration before whole-stack acceptance.

The [content leaf manifest verifier](../docs/integrations/content-leaf-manifests.md)
passes 13 focused cases and two 256-input fuzz properties in both compiler modes.
It compares every field with the actual checkpoint and reads complete preserved
manifest bytes through the actual artifact aggregator and document store.
Final admission rechecks membership and current archival coverage while retaining
the original completion identity. Actual Safe 1.4.1 exercises both writes and
all public reads; immutable gas mutation rejects a Safe caller. Archival receipt,
schema, Core/router and finality boundaries remain explicit in this fixture.
Independent review accepts the bounded verifier and exact compiler artifacts.
Authoritative root publication needs the
Router's exact artist-content consent path and registered interpretation
documents. The existing 64-chunk artifact limit allows 2,729 leaves here;
larger composed manifests remain required, with no new collection supply cap.

Stable router presentation is integrated as `f445ac79` from the independently
reviewed `89dc713d` handoff. Its retained 40-case rendering cohort, two actual
current-contract Safe cases and exact-context cold-rendering check pass. The
latter uses 11,900,916 gas against the existing 12,000,000 cap; it is evidence
for that captured source, before the subsequent Base64 repair.

The artist owner/acceptance stack repair is integrated as `1e3087a2`, retaining
exact commitment preimages, event arguments and the prior ABI/storage. The
complete compilation result remains open. Latest observed CI at `4c7cc4b6`
has passing client/wrapper jobs, running smoke compilation, cancelled current
integration and failing release-artifact/Slither jobs. The later `d0094ca6` CI
run is pending while its museum workflow passes. Independent execution probes also reject
the deployment script's self-view calls under default Foundry protection.
Moving a self-call outside broadcast did not solve that issue. A compatible
planning boundary was therefore extracted into a stateless local helper. Six
plan/catalog tests and 256 fuzz inputs pass, preserving exact inline plan bytes
and actual governance execution. A separate real Core/Executor/roles/registry/
manifest rehearsal passes default script protection with no helper nonce and
exactly three resumed governance writes. The complete product entry-point
compile reached its 600-second bound without a result. Full build and complete
deployment-script execution remain unaccepted.

The [onchain content checkpoint](../docs/integrations/onchain-content-checkpoints.md)
passes 17 reviewed computation cases and 256 fuzz inputs in both compiler modes.
Seven additional composition cases pass with actual Core, router, inventory and
checkpoint contracts, including Safe custody/burns, complete odd-sized roots,
maximum script/token data and atomic retry. Governance, module registry,
Manager, artist and external entropy remain explicit boundaries in that fixture.
Root publication is now implemented in the scoped increment above. Typed scope
inputs, complete archival receipts and full finality remain implementation work.

Actual composition found that the router could not admit inline images; a fixed
image-only helper now supports canonical Base64 PNG/JPEG/GIF/WebP admission
under the existing 2,048-byte limit. Fuzzing also found a shared Base64 padding
bug, repaired in `164f867b` with exact caller-memory preservation. Nineteen
image/vendor tests and two 256-input fuzz properties pass in both modes. The
complete retained renderer cohort passes 61 cases in IR. Pure configuration
preparation moved into the existing fixed renderer after an intermediate
25,025-byte Router exceeded the runtime limit. The corrected actual Router is
24,035 bytes in default mode and 23,711 in IR, with all 64 common contracts'
ABIs and runtimes matching the final source. Historical failing captures remain
preserved. Complete system compilation and final deployment evidence remain open.
The two maximum-size rendering cases also pass after cooling the router's
actual linked renderer: 11,887,094 gas for Router and 12,698,145 for Core,
returning the complete 63,193-byte URI. These are fixture account-cooling
measurements, not universal all-state-cold or deployment acceptance.

The museum abstract/nonvisual increment is integrated as `db3c8153` from the
reviewed `dab6d08e` handoff. All 132 tests, five generators and dependency checks
pass again in the integration environment. The original 104 tests and 115-file
v1 package remain unchanged. Explicit abstract works, linguistic content and
nonvisual source assertions retain their proper entities and complete field
accounting. Public fixtures remain distinct from authenticated chain records;
PREMIS/LIDO/IIIF correspondence, packaging and institutional evidence continue.

The first PREMIS file-object correspondence is integrated as `9f6afe60`, with
149 independently reviewed tests and six generation checks. It preserves the
previous 132 tests and both public output versions, joins exact source fields
to the pinned PREMIS 3 schema, and distinguishes asserted fixity from a fresh
check of actual file bytes. Full PREMIS and the other formats remain in scope.
The 149-test version and all six generators pass Windows/Linux CI at `4c7cc4b6`
([run 34708017861](https://github.com/6529-Collections/6529Stream/actions/runs/34708017861)).

The dedicated [independent-attestor host](../docs/integrations/independent-attestations.md)
is integrated as `4673f248` from `4c277b0e`. Its 22 reviewed cases and 256 fuzz
inputs cover retained bytes, signatures, history, replay, actual Safe calls and
canonical governance. Both production profiles fit (17,301 / 16,641 bytes).
Core membership uses an explicit fixture; renderer/export/current-stack
composition remains open.

Actual artist-registry-to-metadata-host publication is integrated as `85f44fbd`
from `7d9f108e`. Four cases pass independent review, covering principal and
relayer Safe paths, estate intent capability, rotation and atomic append failure.
The actual artist owners, metadata host, schema/store and module registry are
composed; Core/Executor are explicit boundaries. Existing production sources
and prior artist tests remain unchanged. The initial timestamp-restore test
oracle failure is retained separately from the corrected passing run.

The integrator's [collection token inventory](../docs/integrations/collection-token-inventory.md)
passes 14 focused tests in both compiler modes and 256 fuzz inputs. It verifies
actual Core collection serials and completed lifecycles, including burns,
replacement-Manager abort/reuse and callback rollback. It supplies membership
for the [typed finality producer](../docs/adr/0041-typed-finality-evidence-provider.md);
complete roots, serving evidence, discovery and full finality remain active work.

Exact artist record-publication authorization is integrated as `a7114aeb`
from `36237a1a`. The complete 271-test artist cohort passes in one unpruned
run, including all 262 prior cases and nine publication/related regressions.
Independent review checks the prior ABI/storage prefixes and all 121 nonempty
production runtimes. Its candidate metadata host is an explicit fixture; the
separate actual-host composition above supplies the next four checks.

Museum review/selection is integrated as `f5a23d72`, resource projection as
`ff1a899d`, and offline package reproduction as `66aebd4a`. All 104 combined
museum tests pass again in the root's pinned environment. Each increment has
independent review and an exact source-to-integration bridge. These tools use
explicit public fixtures; authenticated chain adapters, complete cross-format
mapping and institutional acceptance remain open. The prior 65-test source
at `49b3e072` passed museum CI on both Windows and Linux. The new 104-test
source at `dac4d4ed` also passes both platforms, including all four generators
([run 34697427952](https://github.com/6529-Collections/6529Stream/actions/runs/34697427952)).

The developing [current metadata record host](../docs/integrations/metadata-records.md),
integrated as `72c4b099`,
retains complete payload bytes, original authors, interpretation identities,
record chains and per-author history. Its corrected 23-case host/adapter cohort
passes both compiler modes with 256 fuzz inputs. Root-only delayed catalog and
family-grant configuration includes the live root revision; independent actual
Executor tests reject a registered proposer's self-grant and accept a genuine
second batch element. The host cohort uses actual schemas/store and Safe 1.4.1,
with explicit Core/Executor/artist boundaries. Full artist publication,
typed finality production and all-selector Safe composition remain next.
The earlier 19-case cohort is superseded: its tests passed, but independent
review found the missing target-side stored-proposer check.

Complete archival artifact coverage is integrated as `880bac6d` from the
reviewed thirteen-file handoff `062a6208`; three interfaces were already exact
in the integration tree. Twenty-six tests and 256 fuzz inputs pass review,
including actual chunk retention and Safe calls. Immutable completion
commitments remain stable across successful revalidation; current fixity
freshness is separate. The tested dependencies include explicit finality/Core
boundaries, so this does not close the actual full-finality flow.

The schema-derived museum inventory is integrated as `ef3b1631`, with thirteen
new cases passing again locally and a reviewed 65-test combined suite. It
accounts for applicable schema branches and exact source values before format
projection. The independent museum CI has passed on both Linux and Windows
for the preceding 52-test snapshot at `63d8c1f9`.

Offline Linked Art validation is integrated as `ef107a22`. Its original
52-test museum cohort passed independent review, again in a fresh root
environment with all 15 pinned dependencies. Thirteen retained schemas have
complete local reference validation and three explicit interpretation repairs;
original standard bytes are unchanged. A separate Windows/Linux museum CI
workflow keeps these fast checks independent of Solidity compilation.

The [content-root primitives and host adapters](../docs/finality-host-adapters.md)
pass independent review: seven content/subject tests with 256 fuzz inputs and
eight adapter tests pass in both compiler modes. The adapter cases include a
real threshold Safe calling all eleven public reads. Core and host evidence
are explicit boundary doubles here; actual metadata publication, complete
scope evidence, discovery wiring and the first full finality flow remain the
integrator's next implementation work.

The reviewed estate increment is integrated as `34932659` from `9af9a107`:
234 domain cases pass, all 115 nonempty production runtimes fit, and constructor
and historical interface/storage checks are retained. The optimized clearing
increment is integrated as `73ae34c3` from `1407caf3`: 70 domain cases and six
fuzz properties pass. These results are scoped to their captured inputs.

The shared current fixture initializes the canonical governance foundation
before constructing the archival provider and artist facade. Nine current
clearing, catalog and archival-governance cases pass independent review
(`b2e33422`). Three estate cases now execute through the actual current
contracts and Safe wallets, including notice, activation, cancellation and
retry (`d4e73f1a`). Their observers are local test signers; the tests do not
claim a live archival quorum or a commercial mint after estate activation.

Native secondary private offers and custody sales are integrated (`7139688b`)
with 42 reviewed domain cases and fuzzing. These use an actual registry and
ERC-721 with Core/royalty doubles; full-current secondary delivery remains open.
Seven Safe governance planning cases also pass independent review (`d0695608`):
exact saved actions, real delays, stale-catalog rejection and idempotent resume.
Eleven catalog-stage cases pass independent review (`1ef25f34`), including
complete inventory validation before the first admission. The version-2 local
deployment dry run (`266fc055`) also passes independent review: 287 exact source
inputs, 104 CREATEs and one CREATE2 bind the actual constructor arguments,
library links and initialization order. Governance initializes before archival
and artist construction. The returned seven old-product registrations and
70 catalog additions still need staged activation; this is not a complete v1
inventory or a broadcast. Each catalog extension invalidates
older scheduled actions, so chunk preparation requires observed execution and
fresh scheduling against the resulting catalog.

Primary token economics and corrected-binding consent are integrated as
`e7250886`, with 249 distinct reviewed domain cases. Full-payload ticket and
offer revocation at the Manager/Ledger boundary is integrated as `37f57cf6`:
49 domain cases with fuzzing and two actual Executor/Safe governance cases.
Seven actual current Safe setup/mint/reveal cases pass on the combined source;
that composition does not itself execute the ticket-gate revocation path.
Royalty token assignments are integrated as `763944c2`, with 262 distinct
reviewed artist/provider cases. Both resolver compiler profiles fit; explicit
disabled royalties retain a nonzero assignment, while clear restores inherited
selection. Full-current composition of those new royalty paths remains pending.
The first museum
schema/fixture/exporter foundation is integrated as `c7752f11`, with 32 reviewed
tests and both deterministic generators passing again in the integration
checkout. Its publication plans and synthetic sources remain explicitly
unregistered. The interpretation-document registry passes 18 reviewed current
governance/document cases with 256 fuzz inputs plus an exact-event/Safe-call
case; both production profiles fit and exact-source artifact review is clear. It retains complete documents up to
524,288 bytes and does not yet constitute registered museum schemas or complete
metadata integration.
Complete metadata,
finality, recovery, other sales and the full Safe call matrix retain their scope.

Collector gas remains above its specified ceiling. ADR 0033 permits identified
test-asset engineering deployments while preserving the failed candidate gate;
it does not authorize a conforming-candidate claim from domain tests or a small
rehearsal. The owner adopted the full museum semantic profile with reviewed
refinements on 12 September (ADR 0036). Its [delivery plan](MUSEUM_DELIVERY.md) runs profile,
record and exporter work alongside contract engineering; all twelve museum
gates remain required for full-v1 acceptance. Adoption is not implementation
or institutional-conformance evidence.

Earlier remote CI on `266fc055` was red. It identified a default-mode
artist hash-helper stack limit and a separate full current-profile Yul compiler
failure; Slither provenance and release bundles also need their planned refresh.
The hash-helper repair is integrated as `e43dbed5`, with exact preimage vectors
and fuzzing against the old IR and both new compiler modes. The isolated whole-current dynamic-linking diagnostic
failed with the same Yul stack-layout error after 1,801 seconds on the exact
`e43dbed5` Solidity snapshot. The reviewer isolated the failing deployment-script
combination of a large returned struct and an internal catalog builder. The
source-reviewed repair (`04338eda`) computes that catalog through an additive external view
after broadcasting stops; the minimal reproducer and configuration-return
variant compile. The full patched deployment target timed out and is not yet
a passing complete-build result. Repository compiler settings remain unchanged.
Focused runtime cohorts do not replace complete compilation and the final
matching artifact pass.

## Team and ownership

Four agents work concurrently: one integrator, two builders and one independent
reviewer. The integrator remains responsible for decisions and delivery.

| Role | First assignment | Continuing responsibility |
| --- | --- | --- |
| Integrator | Shared artist/payment/finality decisions; feature ledger and integration | Core/governance, dependency order, merged tests, API coherence, CI, deployment, release and cleanup |
| Artist builder | Identity, two-sided acceptance and genuinely eligible mint consent | Artist lifecycle, sanctions and the artist side of finality/recovery |
| Revenue builder | Stateless claims across 20 real split wallets | Wallet completion, settlement/escrow, then missing sale mechanisms |
| Independent reviewer | Challenge both first slices before integration | Adversarial source and test review; challenge scope omissions and false completion claims |

The two builders have separate branches and worktrees. The reviewer needs no
worktree of its own. The integrator owns one integration worktree; original
main and the frozen Sepolia checkout are retained. Retire a builder worktree
after its handoff is merged and preserved instead of accumulating old branches.

Builders may not edit the same production files concurrently. Interface owners
publish a concrete typed contract before dependent builders use it. A handoff
contains one coherent commit, exact validation, unresolved limitations and the
next useful slice. Root owns global manifests, release artifacts and integration
fixtures. No builder independently pushes, merges or broadcasts transactions.

## Delivery rules

1. Work in executable vertical increments. Each increment ends with an actual
   usable behavior through the current stack, including its failure paths.
   A directory, interface, mock-only test or always-failing admission path is
   not feature completion.
2. Resolve ordinary design choices internally. Old Proposed packets identify
   decisions to finish, not requests to return to the CEO. Preserve accepted
   semantics, record exact changes and obtain independent technical review.
   Do not blanket-flip implementation-authorized flags or erase unresolved
   requirements. Any genuine semantic amendment gets a concise decision record
   and corresponding spec/test reconciliation before dependent code is accepted.
3. One writer owns each semantic state, replay key and event. Keep cross-domain
   calls typed and atomic. No generic execution router or second source of
   payment, artist, governance or finality authority.
4. Integrate each coherent passing increment promptly. Independent work does
   not wait for another feature's PR, full cold build or release bundle.
5. Compile the smallest relevant import closure first. Reuse only caches whose
   complete source and toolchain inputs match. Run focused behavior and current
   integration checks during development; broad validation, artifact generation
   and testnet rehearsals follow meaningful integration checkpoints.
6. Preserve an independent reviewer. Rotate that role only after a handoff;
   a builder never supplies the sole acceptance of its own feature.
7. Every new money/authority path receives negative and adversarial tests,
   appropriate fuzzing and stateful accounting checks. Tests must show successful
   operations and independent expected results, not just attempted calls.
8. Keep status fresh in this ledger and the active issue. Report what now works,
   the current critical path and any actual forecast change. Historical issue
   text about the completed RC is not a new blocker.

## First integration checkpoints

The first 48 hours are an aggressive implementation sprint, not a promise that
every remaining specification requirement can be completed in that time.
Re-estimate the critical path from the first actual integrated deliveries.

| Checkpoint | Required result |
| --- | --- |
| First working increments | One transaction claims from at least 20 real wallets; real artist facts can satisfy one complete policy-consent path, including all mandatory floor records |
| Expanded commerce and authority | Complete wallet exits and typed settlement/escrow; artist changes invalidate or preserve consent exactly as specified |
| New products and recovery | Missing sales consume shared payment/mint/artist boundaries; fallback entropy and finality use real dependencies |
| Full feature candidate | Every ledger row and mandatory genesis role has executable evidence; all 57 artist operations are explicitly accounted for; broad tests, fuzz campaigns, independent review and a fresh matching testnet rehearsal pass |

An integration checkpoint is a concrete capability, not a time spent, document
count or arbitrary test-count target. Aim for a new demonstrable increment each
working half-day; investigate and split any lane that produces only paperwork.

## Feature completion ledger

States: `Building` means source work is assigned; `Queued` means a named owner
will take it after the listed dependency. Neither means complete. Promote a row
to `Integrated` only with code and actual current-stack tests, and to `Verified`
only with independent review and the specified demonstration. Keep links to
commits, tests and retained results in the evidence column when advancing it.

| ID | Capability and completion test | Owner / dependencies | Initial state |
| --- | --- | --- | --- |
| FOUND-01 | Actual metadata content-state and primary/royalty assignment reads plus required mutation/consent hooks supply the artist floor records | Integrator; parallel with ART-01, no dependency on advanced ART-03 or META-01 | Building |
| ART-01 | Identity, binding, acceptance, exact mint consent and independent pause; actual economics, first-release and attestation prerequisites make an eligible mint possible | Artist; internal typed/storage decision | Building |
| ART-02 | Collaborators, scoped delegation, payout/economics consent and royalty rights; stale or revoked grants cannot authorize mutations | Artist + integrator; ART-01 | Building: prospective fixed-profile economics and exact defensive royalty freeze integrated through actual providers and Safe; scoped economics/freeze delegation source integrated; refusal/withdrawal and collaborators active |
| ART-03 | Sanction, disputes, attribution/content authority and record-family authority work through actual consuming modules | Artist; ART-01/02, FOUND-01; extend with META-01 | Building: actual content consent/freeze owners and metadata host; wider sanction/dispute/finality admission still pending |
| ART-04 | Rotation contests, guardians, recovery, estate and dormancy complete their real lifecycle and replay rules | Artist; ART-01/02 | Building: rotation, identity filing and succession source integrated; dismissal has 202 independently accepted domain cases plus twelve actual-current dismissal/refund/dispute cases. Corrected lifecycle5 plus Dutch4/refund4 pass independent review (`d98650ba` test-only nonce correction). Archival prerequisite `ee21cff9` has 29 reviewed cases and two fuzz properties; actual coverage composition and estate activation, recovery and dormancy remain |
| ART-05 | History import/archive and all 57 historical operation rows plus accepted extension 58 have explicit implementation and test evidence | Artist; ART-01..04 | Queued |
| PAY-01 | Stateless claimMany/syncAndClaimMany across 20 real wallets, event-based discovery, atomic and continue-on-failure cases | Revenue; existing factory/wallet | Integrated: `f6cac4ef`, 21 focused tests in both compiler profiles; candidate validation pending |
| SAFE-01 | Every supported public/external ABI function is classified and covered for correctly authorized Safe calls, reads or intentional protocol-only restrictions; real signatures, claims, NFT custody and client workflows pass the [Safe acceptance matrix](SAFE_ACCEPTANCE.md) | Integrator + both builders; shared fixtures first, verification accompanies each feature | Building |
| PAY-02 | Signed release/revocation and specified deprecated-asset exits preserve owed funds and nonce rules | Revenue; existing wallet/asset policy | Building: source integrated as `6d2074fb`; 121 focused tests per compiler profile; combined current-stack acceptance pending |
| PAY-03 | Revenue escrow records exact owed assets, captures the destination binding and supports permissionless flush/recovery | Revenue; typed settlement decision | Building: deferred registration/discovery and single-factory exact-credit/flush source integrated; fixed-sale and auction adoption source integrated; current acceptance and recovery still pending |
| PAY-04 | One ERC-20 payer boundary, official settlement owner, exact typed mint orchestration and execution-bound replay, including specified permit branches | Revenue + integrator; PAY-03, ADR 0019 reconciliation | Building: universal ERC-20 recorder/payer/consumer integrated `18dbe54c`, 29 tests plus fuzzing independently accepted; canonical authorization fix `5ecae362` accepted with two tests; `4e9a41b1` actual-Core universal/content/Safe ten-case composition independently accepted; native and broader orchestration pending |
| PAY-05 | Required primary/royalty assignment profiles, templates, token overrides and freeze behavior work through current resolvers | Revenue; artist economics, PAY-04 | Building: immutable primary artist binding integrated as `8eb37037`; 38 focused tests per profile; remaining semantics and current-stack acceptance pending |
| SALE-01 | Fixed/open-edition sale variants, zero/PWYW pricing and refund-window custody obey drift, cancellation, reveal and pause rules | Revenue; PAY-04 and artist consent | Building: signed free/open/PWYW programs and REQUIRED consent have separately captured current/Safe acceptance. Refund source `ea107e58` has 63 reviewed domain cases and two fuzz properties; actual refund4 plus retained dispute4 now pass independent review on the pre-dismissal snapshot. Wider variants and candidate acceptance remain |
| SALE-02 | Dutch schedule, clearing rebates and maximum-price excess credits conserve funds | Revenue; PAY-04 | Building: standard native Dutch and supplemental settlement have independently reviewed current composition. Clearing consumer `d807421e` has 59 reviewed domain cases, five fuzz properties and both compiler profiles; two actual-current Safe clearing cases pass independent review (`d9d7d46b`). A qualified full-current trace measures 8,755,856 gas in the first consumer call versus the 500,000 ceiling. Aggregate/storage optimization and shared mint/rights/settlement costs remain open; no cold gas or deployment acceptance |
| SALE-03 | Private sales/offers and owner-signed consignment grants have exact revocation and secondary-settlement semantics | Revenue; PAY-04 and artist consent | Building: `7139688b` implements native secondary PRIVATE_SALE and OFFER_SALE, with 42 reviewed domain cases and fuzzing. Prior collector delivery, actual-current Core/royalty composition and broader inventory sale kinds remain |
| SALE-04 | Remaining English-auction branches, including first-bid-starts and mint-at-settlement, use shared authority and settlement | Revenue; PAY-04 | Queued |
| MINT-01 | Signed tickets, burn-to-mint and delegate gates, counter/nullifier continuity and required content-selection behavior | Integrator / revenue builder; shared artist/payment interfaces | Building: full-payload ticket/offer revocation at the Manager/Ledger boundary is assigned; other listed behaviors retain their acceptance scope |
| ENT-01 | Reviewed non-VRF provider and safe-mode fallback instances are installed; actual provider failure/recovery follows the specified lifecycle | Integrator / freed builder; provider docs and exact interfaces | Building: ARRNG adapter and four actual-current Safe/Executor cases accepted in `72c208f2`; safe-mode, full recovery and deployed upstream acceptance remain |
| ENT-02 | Scope/reveal policies, fee escrow, keeper/SLO fallback and recovery preserve committed entropy without discretionary rerolls | Integrator / freed builder; ENT-01 | Building: policy/escrow/typed quote source integrated `66d70e04`, with 44 focused cases, 30 metadata regressions and six planner cases; separate 14-case actual current/Safe composition independently accepted with its captured pre-unique-holder planner; governed timing/SLO source has 54 accepted domain cases and 30 metadata regressions, with a separately accepted seven-case actual governance/Safe run captured before operation 33; AT_MINT attempts and recovery remain |
| META-01 | Schema, owner records, attestations, views and preservation modules cover required genesis metadata and authority | Integrator / freed builder; FOUND-01 and typed ART-03 interface, build owners in parallel with ART-03 | Building: immutable document registry and reviewed content/subject primitives are integrated; actual record hosts, schema admission and remaining families continue |
| META-02 | Rendering-input manifests, offchain first-sale binding, archive receipt/fixity semantics and required museum schemas round-trip | Integrator / museum builder; META-01 | Building: actual checkpoint, preserved leaf manifest and artist-approved root publication with 17 focused cases; museum IIIF183 union and seven generators reviewed. Other profiles, full receipt/artist/finality composition and remaining museum targets continue |
| FIN-01 | Collection/token/release/season/view finality binds actual Core, metadata, discovery, entropy and artist sanction | Artist + integrator; ART-03, META-01/02, ENT-02 | Building: fixed-host adapters reviewed; canonical governance registry and actual metadata/sanction evidence are in progress, with no full finality-flow acceptance yet |
| FIN-02 | Governance-owned recovery, owner notice/objection, recovered-route lineage and bounded refresh/cutover work end to end | Artist + integrator; FIN-01, owner records, ADR 0020 reconciliation | Queued |
| ARCH-01 | Complete state/event reconstruction and export preservation can rebuild required records, lineage and artwork without relying on the app | Integrator / freed builder; current publisher, META/ART/FIN | Queued |
| GOV-01 | Complete governed parameter hosts, call-budget behavior and distinct fallback instances fit the real candidate | Integrator; integrated modules | Queued |
| APP-01 | SDK, human-readable artist signing, event-based claims and operator recovery expose every supported new workflow | Integrator / freed builder; each accepted interface increment | Building: Safe CALL/receipt helpers integrated; exact phase setup/Safe handoff planner passes seven actual-current tests; matching v1 ABI/signing, full identity onboarding and runner migration pending |
| VERIFY-01 | Full mandatory feature traceability, integrated hostile tests, fuzz/stateful campaigns, normative all-cold collector gas ceilings and interaction measurements, and real candidate demonstrations | Reviewer + integrator; all implementation rows | Queued |
| RELEASE-01 | Complete genesis inventory, exact compiler/deployment binding, new frozen source and matching testnet evidence | Integrator; VERIFY-01 | Queued |

The [normative v1 scope](../docs/launch-v1-target-architecture.md),
[genesis profile and gate inventory](../docs/launch-conformance-matrix.md),
[sales specification](../docs/stream-sales-and-auctions.md),
[artist operation matrix](../release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json)
and [artist domain matrix](../docs/architecture/artist-semantic-owner-matrix-v2.json)
own the detailed requirements. This grouped ledger is an execution index, not
a replacement for those requirements or a count-based percentage score.

## Critical path and parallelism

Artist authority and settlement are the shared prerequisites for many remaining
features, so they begin immediately. Claim aggregation is an independent first
payment increment while the universal settlement decision is resolved. Artist
floor records are included in the first vertical flow; an acceptance-only
registry with permanently unavailable mint eligibility is not its end state.
FOUND-01 is a parallel prerequisite owned by the integrator. Its small real
provider/read and mutation hooks do not wait for the complete museum metadata
system. ART-03 and META-01 agree typed interfaces first, then build their own
state owners in parallel; neither waits for the other's entire implementation.

Once the first interfaces and integrated contracts are stable, move available
builder capacity to entropy and metadata. Full finality follows real artist
sanction and metadata inputs. Recovery follows finality. Rich sales use the
shared payment and mint boundaries instead of inventing new accounting.

The integrator may split or reorder rows to keep both builders productive, but
must retain every v1 requirement and record changed dependencies. Avoid adding
more concurrent worktrees or overlapping writers to conceal a blocked lane.

## Feature acceptance and external release obligations

For every mandatory feature, retain: its normative anchors; actual owning
contract and interface; successful and rejected current-stack operations;
state/event/replay assertions; applicable fuzz/invariant evidence; independent
review disposition; developer usage; and deployment/configuration requirements.
Measure the normative all-cold and interaction gas envelopes as features become
integrated. A real ceiling breach needs implementation slimming or an explicitly
reviewed semantic amendment, not a silently increased test allowance.
Do not infer completion from a source filename, isolated mocked test, deployed
address count or a generated checker reporting that a placeholder is honest.

External audit, institutional/marketplace validation, production signer custody,
funding/endowment operations and production ceremonies remain separate visible
acceptance obligations. A feature-complete testnet candidate does not close
them. Lean remains deferred until the traditional implementation stabilizes.

## Resume and preservation

The integrator records active commits, processes, cache owners, review results
and next actions in the local continuation checkpoint as well as this ledger's
capability state. Resuming work begins by reading current assignments and
reusing active workers; do not spawn duplicate compilers or broadcasts.

RC1, its deployment checkout, source tags, original-work recovery and retired
branch bundles remain preserved. New contracts or changed semantics require a
new candidate identifier and matching deployment evidence. Never move RC1's tag
or relabel its Sepolia instance as the new v1 implementation.

## Integration checkpoint: 11 September, evening

Artist onboarding (`53fcf977`) and bounded nonce/fixed-size authority reads
(`717827de`) are on the integration branch. These implement operations
1, 2, 14, 15, 18, 24 and 52 for the explicit primary-only collection profile;
they do not complete the other artist operation families. Phase configuration
extraction (`32b94199`) preserves the Manager ABI and all 13 recursive storage
entries while bringing its runtime to 24,142 bytes. Independent review accepted
the extraction after 17 focused tests and exact compiler/storage comparison.

The payment release/asset-exit increment (`6d2074fb`) and primary resolver
binding (`8eb37037`) are integrated source. Primary and royalty constructors pin
the actual Core and artist facade before committed genesis; live operations
require the selected Core pointer and admitted runtime hash. Sale adapters
consume the narrow attribution interface. Provider tests pass 12 cases per
compiler mode, including 256 royalty fuzz cases; the shared sale attribution
guard passes seven per mode. Official Safe foundation tests pass four per mode.

The combined actual-current native and Safe slice now passes seven tests:
real artist owners and mandatory records, governance, paid mint, reveal and
metadata, auction custody/bids/refunds/settlement, NFT transfer/burn and split
withdrawals. Safe 1.4.1 executes as artist, buyer, NFT holder, beneficiary and
governor, including a delayed Safe-to-Executor parameter raise. Only the
external entropy service is mocked. Independent review verified exact sources,
retained compiler provenance and production runtime sizes for this snapshot.
The complete Safe selector acceptance matrix remains open.

The actual-current ERC-20 and invariant slice passes ten tests, including
relayed/direct payment, recipient and token callbacks, atomic rollback and
stateful conservation. Its quick invariant campaign completed 32 sequences
of 64 operations (2,048 calls, zero handler reverts). This run used isolated
dynamic test linking; its inputs and artifacts are retained separately from
the normal native/Safe compile. The combined `b0b7bf66` snapshot completed with
27 passes and two fixture failures: missing prospective artist policy consent
before a changed executor list, and an export probe created after its address
was required by the genesis catalog. Both fixtures are corrected; their focused
follow-up passes all 14 adversarial/export cases, including 256 lineage fuzz
cases, against the retained original snapshot. These results are not evidence
for later production changes.

Prospective fixed-profile economics and exact defensive royalty-freeze authority
are integrated as `4f77bba8` / `acd90b8a`, with actual resolver counterparts in
`648b71a4`. The resolver suite passes 40 tests in each compiler mode, and the
artist suite uses the actual primary and royalty providers and separate split
factories (`7b19e7bc`, 30 tests). Independent review accepted both. This adds
operation 20 to the seven earlier operation IDs; the remaining 49 operations
remain explicit work. Scoped economics/freeze delegation is the next artist
increment, with collaborator and other delegation capabilities still pending.

The new actual-current Safe snapshot (`a46424a9`) passes all three cases,
including prospective economics approval, real governed primary replacement,
exact defensive royalty freeze and a subsequent eligible mint/custody/release
flow. Independent review matched all 62 production artifacts to retained compiler
outputs and confirmed their runtime sizes fit. This is a separately retained
dynamic snapshot, not a full-repository or complete Safe-selector acceptance.

Deferred profile registration and append-only wallet discovery are integrated
as `e39a8dce` (150 focused tests per compiler mode). Single-factory escrow is
integrated as `9f15cab8` (29 tests per mode, including fuzzing): exact native and
token credit, governed producer admission, retained destination identity and
permissionless flush. Independent review accepted these increments. Escrow
recovery and successor routing remain pending. Revenue work now connects actual
fixed sales to bounded wallet funding with escrow fallback. The native signed
sale payload becomes an explicit version 2 with an exact primary-policy hash;
both native and ERC-20 lanes require the supported `PRIMARY_SALE` profile.
This does not complete universal settlement or the remaining permit branches.

The integrator owns current-stack acceptance and shared constructor, deployment
and client migration. Older deployment and unit-fixture callsites still need
migration; no full-repository build or new release-candidate pass is claimed.
The migrated entropy/metadata domain suite passes 19 tests, including 256 fuzz
cases, maximum-content rendering and exact ratified-content mutation rejection.
Its artist read boundary deliberately rejects all mint-consent operations;
these domain and gas results do not substitute for actual artist integration.
All other ledger rows remain in scope with their stated dependencies. The
published RC1 and its deployment evidence remain unchanged.

## Integration checkpoint: commerce, lifecycle and test migration

Fixed-sale funding is integrated as `452f2c65`, with 26 focused tests per compiler
profile and independent review. Version-2 native authorization commits the
primary policy. Auction funding is integrated as `dce4cb4f`, with 16 tests plus
fuzzing per mode; settlement retains the rights approved at auction creation.
Scoped delegation is integrated as `64856e73`, with 44 focused artist tests.

Refusal/withdrawal and expected-binding acceptance (`02e9ceed`, 53 focused tests)
raise the integration source to 12 supported artist operation IDs. Collection
template materialization (`a8052c8b`, 23 tests plus fuzzing per mode) uses the
accepted identity's explicit payout designation. Typed template economics facts
are integrated as `b4600d8e`, with 34 tests plus fuzzing per mode. All received
independent source and scoped runtime review.

Collaborator operations 5/6/7 are integrated as `90369bf0` (67 focused tests).
Actual current-template economics consent is integrated as `871046b2` (74 focused
artist tests), bringing the integrated source to 15 of the 57 operation IDs.
Template fixed-sale funding is integrated as `ddf01864` (76 tests and four fuzz
properties per mode). Governed permit-capability attestations are integrated as
`3287fcd5` (13 tests plus fuzzing per mode). Independent review accepted these
increments. Revocation operation 54 is integrated as `6a0f5a4f`, bringing the
source to 16 operation IDs. Content consent/freeze operations 17 and 21 are
integrated as `bcb43e06`, bringing the source to 18; 96 domain tests and exact
production artifacts received independent review. Identity revision operation 25
is integrated as `3f6a5dd4`, bringing the source count to 19; its 109 tests and
30 production artifacts are independently accepted. Guardian configuration and
two-sided principal rotation are the next artist increment.

Root's completed combined snapshot passed 36 cases: all nine ERC-20 and all 22
native-sale/auction unit cases passed. One new Safe test asserted the wrong event
layout; that assertion is corrected. The invariant failure replayed an older
counterexample from the wrong working directory. An unchanged-source follow-up
with isolated persistence passes all three invariant tests, 32 sequences of 64
calls, zero handler reverts. Exact original failure evidence remains preserved.

The next combined snapshot completed with all 39 executed Safe, ERC-20, native,
auction and invariant cases passing. This includes actual Safe template consent,
paid mint, deferred profile registration, escrow, deployment, flush and claim,
plus 2,048 stateful calls without handler reverts. Its 11 royalty cases were
blocked by a test scheduling window shorter than the required seven-day floor.
The corrected-window snapshot passed five cases and exposed six fixture errors:
three omitted mint authorization IDs and three wrong mapped-collection arguments.
The corrected requests pass all 11 cases in a separate unchanged-production
snapshot, independently reviewed. The evidence is the original 39 cases plus
this separate 11-case run, not a latest-source full pass. Original sources,
compiler outputs and failures remain preserved. Planning allowances do not
establish cold-gas conformance.

The metadata host now implements content-family commitments, one-use consent
consumption, actual evolution witnesses, and permissionless defensive freezes.
Its independently reviewed 30-case domain suite covers replay/staleness, exact
events, BASE_URI combined-setter closure, actual Safe administration and a
separate Safe freeze relayer. It uses an explicit artist authorization boundary;
actual artist operations 17/21 are now source-integrated, with two actual-current
content/mint workflows and the five existing Safe cases now passing together,
independently reviewed against the exact `af37d8ed` inputs and artifacts. The
executed-finality provider remains pending. The two narrow content-authority
interfaces are integrated as `8b1a048b`.

Migration checkpoints independently accepted during this integration:

- 58 historical Manager/manifest cases with exact RC1 companion provenance.
- Six isolated earlier flat-attribution cases, preserving their signature oracles.
- 16 current ERC-20 adapter domain cases, including exact token failure modes,
  payer-pull rollback, wallet-failure escrow, later flush and same-intent retries.
- 75 resolver/factory/auction domain cases with governed constructor authority.

The royalty suite now uses actual current artist consent and canonical governance
publication. Five preserved resolver tests pass independently after retirement of
the uninstalled foundation settlement API (`f803f482`). The universal recorder,
sole ERC-20 payer adapter and signed fixed-profile consumer (`18dbe54c`) pass 29
domain tests plus 256 fuzz inputs with independent review. Actual Core/Manager/
artist composition now passes. Native official settlement and its fixed-profile/
COLLECTION_ARTIST consumer are integrated as `f9162df3`. The independently
reviewed domain snapshot passes 55 cases and three properties with 256 fuzz inputs
each. Actual Core/Manager/artist native composition passes all three cases alongside
the existing three ERC-20 cases against the changed recorder. Independent review
binds all 245 compiler artifacts and confirms 95 production runtimes fit. The
original five-pass/one-fail setup snapshot remains retained; governed template
creation fixes the test without a production authorization change. The separate correction
`5ecae362` binds the ERC-20 Manager authorization
ID to the full signed message digest required by MPA-TICKET; two focused cases
and exact unchanged interface/storage checks received independent review. The
ten-case current run passes three universal payment cases, two content and five
existing Safe cases. It includes the identity revision and independently checks
actual Manager authorization consumption and rollback. Independent review binds
all 218 Solidity sources and three Safe fixtures to `4e9a41b1`, all 237 relevant
artifacts to retained compiler outputs, and confirms all 90 nonempty production
runtimes fit. Later native and rotation changes require their own acceptance.

The retained whole-repository ABI-only check covers 488 Solidity sources with zero
errors, including the operator and native setup tests. Broad compilation and candidate
validation remain pending; focused results apply only to their retained snapshots.

The next artist increment (`c71003dc`, from `72bafbf4`) adds rotation, guardian
contests, provisional records and governed timing windows. Independent review
accepted 133 focused cases plus two extension prototypes, all 153 compiler inputs,
60 nonempty production artifacts, preservation of 15 prior ABI/storage prefixes,
and seven actual constructor CREATE traces. Identity and facade runtimes are
21,128 and 21,463 bytes; the largest Consent runtime is 24,501 bytes. The prior
size failures are resolved through typed libraries and constructor-fixed
extensions. The next twelve-case current-stack run passes with these production
sources and exercises the governed artist window through its actual Identity
owner. This does not complete recovery, estate, dormancy or finality.

The signed native price-program increment (`9eae0d67`, from `0ede006a`) adds open,
zero-price and pay-what-you-want sales. Its 72 cases and four 256-input fuzz
properties passed independent review, with complete compiler outputs in both
production profiles. The original 37 native ABI selectors remain present. These
new formats now pass actual-Core Safe free, PWYW and open-edition purchases in
the twelve-case run. The earlier six-case result at `1b41cff4` remains separately
scoped. Sale consent,
explicit attribution facts and refund-window custody now proceed in parallel.

The combined run captures production source at `ed8f0e40` plus its two new test
files: five native, three universal and four ARRNG cases pass. Independent review
binds all 247 Solidity inputs, three pinned Safe fixtures and 276 relevant
artifacts to complete compiler outputs, excluding unrelated cached artifacts.
It checks every dynamic constructor substitution and all 107 nonempty
production runtimes. The ARRNG tests exercise actual Core, Manager, artist,
Executor and threshold Safes, with only the external oracle service doubled.
They cover mint/reveal/custody, revocation followed by retained-output retry,
governed source-owner/payment changes and artist timing. Later reveal-fee and
sale-consent changes require new composition evidence; deployed ARRNG service
and its incoming callback gas remain separate acceptance work.

The client Safe helpers preserve exact CALL payloads and distinguish an outer
receipt from actual Safe execution. The full client suite passes 47 tests; three
additional Foundry cases exercise actual pinned Safe1.3.0/1.4.1/1.5.0 success and
failure receipts with threshold signatures. Its generated contract ABIs and signing
payloads still target retained RC1; the documentation makes that boundary explicit.
This helper work does not complete the full Safe selector acceptance matrix.

The exact saved artist-activation plan is implemented. A proposed immediate
genesis version failed three execution tests at the required final-root proposer
check; it is withdrawn without changing production authorization. That snapshot's
five existing Safe cases still pass. Delayed activation remains the supported
operator path. The stateless phase-consent/configuration/final Manager handoff
planner now passes seven actual-current tests with real two-owner Safes, sparse
nonce handling, confirmed-state resumption, two-phase ordering and an actual paid
mint/reveal. Independent review verified 203 Solidity inputs, three Safe fixtures
and 223 exact compiler artifacts. The planner runtime is 11,219 bytes; existing
protocol contracts are unchanged. The initial identity onboarding consumer and older deployment
runners remain to be completed. Complete
ABI/client migration, metadata, entropy, finality, recovery, new sale mechanisms
and every other ledger row remain in scope. No new candidate is claimed.
