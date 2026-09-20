# Full-v1 current delivery status

Updated 20 September 2026. The [feature status checklist](STREAM_FEATURE_STATUS.md)
records every feature family with separate build, testing and integration status.
Use it for the common delivery scope and remaining work. This file retains the
current narrative and historical evidence boundaries.
The [delivery ledger](V1_DELIVERY.md) retains implementation checkpoints and the
requirement index. Historical statements there do not override the newer state
below. These workstreams are not a feature-count or percentage denominator.

The supported RC1 is already deployed on Sepolia from
`569bf87f1fa808787d324f6e1582924b5ccf1d40`. The expanded full-v1 candidate is not
complete. No new funding is required. Automatic approval review has blocked
local inherited/global primary-freeze implementation pending a more specific
owner approval. The separate ERC-20 payable reveal-fee implementation is also
blocked by automatic review even after the owner explicitly approved that local
implementation. The exact unapplied patch is prepared and an artifact-specific approval is pending; other work continues.

## 20 September integrated batch

- Version-4 split wallets now use genuine deterministic clones with a pinned,
  locked implementation (`5e1b3902`). Independent source review is clear and
  84 focused wallet/authorization/clone cases pass, including real Safe
  versions. All seven captured production products fit deployment limits.
  Full current-genesis and final economic integration remain outstanding.
- The ordinary and incident-capable mint fallback is source-integrated as
  `60df1e3f`. Its original Ledger imports, permanent writer retirement and
  governed recovery have independent source review; all 13 focused recovery
  cases pass with actual Core/Ledger/fallback and typed surrounding boundaries.
  Nine current-contract Safe recipes, including stale-supply and late manifest
  rollback cases (`a575d215`), are authored and await joined execution.
- Core incident abort preserves consumed token IDs and collection serials.
  Fourteen focused actual-Core cases pass, including fuzzing and capped supply.
  Gap-aware inventory and four finality/preservation readers are integrated
  through `5f233476`. The inventory has 18 focused passes. Consumer execution found fixture setup
  omissions; reviewed test-only corrections74f91719 are in a cached retry.
  Scope/entropy consumers now pass 44 cases including two 256-input fuzz
  properties; five preservation bodies remain blocked by fixture setup.
  No complete consumer pass is claimed. Root passes all 63 affected offchain reference/snapshot tests.
  These captures exclude later entropy changes unless explicitly recorded.
- Frozen entropy successor policies and the configured ordinary backup are
  source-integrated as `cf57de5e`, independently reviewed. Eleven focused
  continuity cases and ten retained subject-identity cases pass on their
  recorded source. A cold-hook probe at 120,000 gas fails on both original
  and new implementations; that probe used the configured floor rather than
  the launch plan's actual 500,000 value. Corrected actual-launch success,
  receiver rollback/retry and low-budget fail-closed tests now pass 3/3
  (`6fb0d7c3`). The observed hook frame consumes 131,789 gas, so four times
  that observation is 527,156; this is scoped call-frame evidence, not a final
  complete-graph transaction measurement. EC-REGGAS additionally requires the
  new candidate's immutable floor to cover four times measured cold hook cost;
  the historical 120,000 floor is not accepted as final calibration evidence.
- Staged authenticated file-inventory preparation (`9a276348`) passes six
  focused worker/Store cases. Its 1,048-row finalization probe uses 12,768,072
  gas including intrinsic cost under named cooling, below 16,777,216; the
  fixture uses a minimal host, so production publication capacity is unproven.
  Exact full inventory identities and original byte encodings are preserved.
- Staged inventory clients (`11dcf32a`) pass all 529 root package tests,
  generation/build/strict types and the exact retained ABI fixture check.
  Independent interoperability review is clear. Safe plans and simulated RPC
  readback are not actual joined Safe execution. The later gap-aware inventory
  clients (`613d3750`) pass all 558 root package tests, generation/build/types;
  their exact serial lookup, bounded scans and receipt checks retain that scope.
- Publication header/single-decode transport (`23e45d78`) passes three focused
  parity cases, including 256 fuzz inputs; all three selected products fit.
  Independent source review is clear. Further payload/environment transport
  work continues because the earlier genuine full publication still fails
  `RouterEvidenceGas(6179424,6195238)` before its final assertions.
- Exact environment preparation (`5066ef97`) passes eight focused cases and
  256-input parity fuzzing. The original 1,048/102-row environment prepares at
  13,936,415 gas including intrinsic; prepared-read callee cost is 7,749,281.
  These are minimal guarded-host/worker/Store measurements. The real publisher
  successor is being prepared; complete publication capacity is still open.
- Six genuine missing genesis products are composed in `a960a5b1`, with five
  actual-current/Safe tests authored. Remaining role composition includes the
  final role assembly and activation. The narrow
  legacy-admin adapter is integrated as `0125573d`: seven current/Safe cases
  are authored; selected adapter size is 5,448 runtime/5,981 creation bytes.
  The new full-byte preservation producer is integrated as `09fd273d`: nine
  focused cases pass, including 256-input fuzz, full 24,576-byte/three-chunk
  reconstruction and threshold Safe, with typed surrounding boundaries.
  All 35 captured production products fit. MetadataV1 still supports 8,192
  against the specified 24,576; its capacity repair remains assigned.
  Source composition alone does not close all 37 genesis roles.
- General attestations, native Artist evidence and typed identity notarization
  are integrated as `9677f5bf`. Root passes 86 affected checks (63 functional
  and 23 documentation); fixture semantics and offline reconstruction do not
  establish actual institutional facts. The exact accepted-profile 15-case
  native run passes all 15 cases; source/size attestation is being recorded.
  Provisional no-IR codegen remains separate from accepted-profile evidence.
  This host also has an 8,192-byte payload bound with full 24,576 support queued.
- Original STATIC renderer/companion/registry composition is integrated as
  `8d1672ac`, independently source-reviewed. Six current/Safe cases are authored;
  fixture analysis and partial direct read rosters are explicitly synthetic.
  Complete transitive analysis, goldens and joined runtime remain required.

The latest complete-source ABI/type/storage pass at `5066ef97` covers 2,159
sources in 18.625 seconds with no errors. It does not generate bytecode or
prove whole-system execution. Earlier paid-burn acceptance remains 39 distinct
scoped cases, owner-notice adapters 93 affected root cases, and the populated
Museum recipe 150 affected cases. Those counts overlap or use different
sources and must not be added into a complete-system total.

Genuine native5 metric replay passes against all 102 platform prerequisites;
native6 retains four passes and four publication gas failures. Exact-byte pure
serialization retains eight scoped passes and three fuzz properties. Existing
Artist/Router deployment-size failures, the remaining product scopes and the
exact rejected proposals remain open. No rejected patch has been applied.
Full current-stack/Safe/fuzz/gas/CI acceptance, a source freeze and matching
new testnet candidate are still required. RC1 is unchanged.

## 19 September recovery and integration

Development resumed after the host reboot. The 16 September usage-limit
interruption left the previous source and completed compiler logs intact.
Existing builders are active again; no new chain or funding was needed.

- Museum typed native joins are integrated as `97e2bf70`, with independent
  functional review clear. Test-only `f01e62e4` follows the existing Metadata
  host-to-library extraction. All 90 affected/compatibility tests, three
  profile checks and 17 documentation tests pass. Genuine complete same-block
  captures and global dossier completeness remain outstanding.
- Metric supplement clients and staged Safe CALL workflows are integrated as
  `c3e19568`. Root passes all 415 package tests, generation/build/type checks
  and the exact retained ABI/replay-fixture generator check. This proves the
  client scope; full publisher/contract/Safe runtime acceptance remains open.
- ERC20 offer source remains independently reviewed. The completed original
  shared run has 70/71 passes; the carrier run has 41/42. Their failures were
  test setup: invalid asset deprecation grace and OWNER_WINDOW configuration
  in an AT_MINT test. Test-only corrections `f90f103f`/`a14d9e35` also add
  explicit negative/positive controls. Cached 40/15-case retries are pending.
- The preservation publication run failed during setup because the fixture
  saved a different original finality anchor from Router's durable anchor.
  The production check correctly refused that graph. A default-preserving
  fixture correction is independently source-reviewed and a cached successor
  is being prepared; no joined export or metric replay is accepted yet.
- Required ERC20 paid burn-to-mint and ERC20 offer clients are being built in
  parallel. The separate Merkle-price host/worker rewrite hit a new automatic
  review rejection over its broad settlement/storage-alias changes. The
  rejected command remains unapplied; concrete narrower-design review continues.

The original immutable RC1 remains the only supported deployed candidate.
Current source integration, scoped execution and complete-system acceptance
remain separate. The complete latest-stack Safe/fuzz/gas/CI/testnet pass follows
completion of the coherent feature batches.

## 16 September parallel implementation batch

Source through `2314878c` includes free-burn reveal credits, original Artist
withdrawal61, the native-price adapter size repair, distribution/burn/price
clients including saved refund-window purchase verification, museum authority reconciliation and expanded actual-current test hosts.
The [feature table](STREAM_FEATURE_STATUS.md#parallel-feature-batch-16-september)
records exact handoffs and evidence, superseding older queue descriptions.

All 2,098 Solidity sources pass ABI/type/storage checking at 2e0fca1a.
The later one-file preservation fixture correction has separate 351-source ABI evidence. Root passes all 398
client tests with generation/build/types, including the new curated callers, 131 museum authority/profile tests and
a separate 27-case archival export/publication cohort. The offline dossier and
legacy BagIt/hydration cohort also passes all 44 cases at a0d71d2.
These earlier cohorts do not automatically validate later Solidity increments.
Separate native cohorts pass mint101, Royalty11, Core29, entropy10, final burn49
and later burn-credit31 distinct cases. These captures have different sources
and component boundaries; counts must not be added into a complete-system claim.

The exact repaired native-price adapter passes 76 scoped cases, independently
attested against all 312 sources and 351 compiler metadata records. It measures
24,560 runtime bytes. Dutch/clearing price consumers are integrated as fbacfc7d
with all 26 scoped cases passing after test-only economics-consent correction
963cfce8. ERC20 consumer implementation and actual complete graph acceptance remain. Refund-window captured pricing is
integrated as 08775172. The original run passes 76/77, with one test incorrectly
expecting an inactive settlement getter to return zero instead of reverting.
Test-only correction fda1d244 passes all 14 focused retry cases: 77 distinct
cases are now accepted across the two runs, with 139 production products fitting.
Root matches all 291 corrected-capture sources to the exact production/test
commits. This is a scoped cohort, not latest current-stack acceptance. Original
signed authorization and refund accounting remain distinct. Artist
withdrawal has ten authored cases; Royalty successor tests and actual-governance
burn/Safe tests are authored but await complete current-stack execution.

Artist Attribution and Identity deployment measure 29,556 and 25,911 runtime
bytes at exact withdrawal source `13118faa`; the other 17 selected products fit.
STATIC Router also has a prior measured oversize failure. Four exact repair/consumer patches are preserved and their
specific approval question is pending after automatic review rejection; rejected
production changes remain unapplied. A separate collaborator co-signing mutation
was also rejected; its exact 21-path proposal is independently source-reviewed
and a separate specific approval question is pending.
Other work continues under the owner's delivery authorization.

Independent review reproduced a low-gas false-currentness error in the separate
STATIC content producer. The independently reviewed correction is integrated
as 40ae52f8 and passes two isolated actual-Renderer regressions.
STATIC output manifests are also integrated as 006a16bc: nine scoped tests pass,
including two fuzz properties and actual Renderer/checkpoint/schema/archival
composition. Root attests all 194 sources and 75 fitting production products.
Full rendered-byte retention and publication authority remain separate work.
These changes are separate from the held Router patch. Museum Type/declaration/later-review records now have an actual local Safe
capture and offline replay in 8ba023dc. Its RDF/JSON snapshot remains synthetic;
qualified external authority and wider schema/conformance remain. Archival
export 23477832 now retains all selected source claims in a compact immutable V3
manifest and publishes it through the actual local governed Metadata ARCHIVE
route. All 27 root tests pass; independent review also rebuilds its 24 original
inputs offline. Scoped dossier a0d71d2 now packages that authenticated
collection export and its selected local media, verifies complete original
inputs and dependency bytes offline, and preserves immutable OCFL versions.
Independent source review is clear and all 44 new/legacy tests pass. It uses a
distinct collection profile; full token object dossiers, authoritative render
inventory and institutional acceptance remain required. Actual-token capture
1db47ad9 now joins a fresh paid mint, 15 Safe-authorized
token records and exact source-block image bytes through one validated local
graph. Root passes all 62 tests; independent review verifies 305 selected
products and 27 original inputs. Offline export/BagIt/OCFL replay succeeds.
Controlled entropy, synthetic authority and trusted local RPC remain explicit;
complete record/ownership histories, authoritative render inventory and the
full OBJECT_DOSSIER remain active work. Object tooling 2503b218 adds concrete
native inventory reconstruction and partial assembly, with 60 root tests and
four definition checks passing. Its complete inventory transport is synthetic;
actual capture8 verifies only identity as a complete adopted requirement.
The remaining required inputs cannot be satisfied by labels or supplied opaque
bytes. Complete owner and independent catalogs plus anchored Core ownership
history are now integrated as 61b87646. Independent review is clear; all 111
root new/compatibility tests and three profile checks pass. Genesis receipt
walks, dynamic owner types, empty lanes and historical author pointers are
covered. Their complete transport controls remain synthetic; genuine same-block
captures, remaining hosts/scopes and canonical assembler joins continue. Two
fixture-URI Solidity regressions are authored but have not run.

Renderer repair `df440372` corrects three exact return sizes
from 416 to 384 bytes. Root attests all 226 frozen sources; four new actual
Metadata/DependencyRegistry cases pass. The wider scoped capture has 27 passing
cases and one remaining capacity failure: a 24,576-byte script needs about 46.7m
gas for full JSON, exceeding the fixture's 30m render budget. Increasing a test
budget is not target-chain acceptance. Pure encoding optimization 9753b496 now
passes 11 focused cases, including three 256-input fuzz properties. The isolated
24,576-byte ONCHAIN JSON workload drops from 42.69m to 7.71m gas with identical
bytes. Root verifies all 14 captured sources. The joined Renderer/checkpoint
run passes all nine behavior cases plus a scope diagnostic under the high-gas
harness, but its 24,576-byte append/current paths still cost 35.33m/21.41m gas.
Every bounded transaction attempt rejects at the complete read-budget guard.
The later byte-scan optimization 849bfd68/3fb128d6 preserves that guard and exact
outputs. Thirteen focused composition/gas and fifteen pure tests pass, including
five 256-input parity properties. Named cold 24 KB append/current transactions
now cost 9,512,309/6,072,737 gas including intrinsic cost; six rows work in 4+2
batches. Eight rows still refuse admission. These scopes meet the 16,777,216 gas
envelope, but the unchanged captured Router is 39,393 bytes and remains a
deployment blocker; complete-current gas acceptance is separate.

The selected-work fixed PUBLIC/COMMIT_REVEAL and buyer-bound private native
carriers are built and integrated as 161cda75, with actual recorder cases 2c9effb4.
Both fit deployment size (24,081/23,545 runtime bytes), and independent source
reviews are clear after refund repeat-unlock correction b25b3d16. Original 97
unit cases and overlapping corrected Book 35 pass. The frozen current run
finishes with 48 passes and two fixture failures: all 41 own fixed/private/Safe
sale cases pass. The missing block advance and incorrect mock royalty pointer
are corrected in test-only 301ccda9; its ten-case retry passes. Root verifies
55 distinct expected passes, all 379 captured sources and both log hashes.
This original 5605d019 production cohort excludes the separately tested later
refund correction. All 217
captured production products fit. Wallet callers 2b93a187 are integrated and
root passes all 375 package tests plus both compiled ABI fixture checks.
Remaining required sale profiles stay visible.

Versioned PERCEPTUAL_TOLERANCE/CURATED_EQUIVALENCE source now includes
correction 5e6c6140: exact signed condition references, an additive standard ABI
V2 document and fixed transport workers. Independent extraction and schema/closure
reviews are clear. Original V1 definitions and BYTE_EXACT are unchanged. Root's 11
metric tests pass. The exact 0a72dec4 preflight reports all 17 products within
size limits. Its native test compilation then stops with a Yul stack-layout
error after 1,682.74 seconds; none of the 12 authored cases execute. The original
inputs/log are retained and test code generation is being isolated. Complete
joined supplement/finality runtime, curated composition and institution-signer
alternatives remain.

The metric supplement is now source-integrated as 5562bdb0. It retains exact
source/runtime/replay evidence, requires its original-record-bound receipt for
full PERCEPTUAL finality and locks, and adds all fourteen supplement inventory
roles. Independent review verifies the committed source, original ABI/storage
prefix and retained proof capture. Seven native proof cases and 256 parity fuzz
runs pass; thirteen nonempty production products fit. The proof call costs
7,706,520 gas, which excludes the full publisher transaction. Root passes 81
offline preservation tests with one opt-in runtime test skipped, plus the new
profile check. Genuine combined browser/metric replay and complete publication,
Safe retry, lock, inventory and final transaction-capacity acceptance remain.
The separate joined fixture is still being completed; its export alone will
not establish acceptance.

CI batch 7d5ba35c lets repository checks overlap native compilation and cancels
obsolete independent PR jobs while retaining draft native runs and their caches.
The required Foundry smoke status still requires both native and repository
jobs to succeed on the same run. All original Forge commands remain; the Museum
workflow now has explicit toolchain-policy and checksum coverage. Root passes
49 orchestration tests, the policy/cardinality checks and actionlint syntax and
expression checks. Frozen release checksums still require final regeneration;
this is not a claim that remote CI or release verification passes.

Metric packaging dffb8444/2b333b74 now retains original source and the copied
interpreter/dependencies. Root passes 81 offline preservation checks and a
separate actual restored-runtime test in 56.516 seconds. The 46.27 MB package
executes without host import fallback and binds its typed transcript to exact
inputs, environment and original report. The fixture has synthetic PNG/context
inputs; combined browser execution and onchain finality joins remain separate.
Offline preservation checks are included in the existing Windows/Linux CI.

The status table's earlier moving-price selection gap was incorrect: it is an
explicit future extension. Free/Merkle families already exist; the specification
does not independently require every combination with selected artwork. Canonical
primary mint offers are explicitly required; the earlier custody-only offer
path did not fulfill them. Native primary offers are now source-integrated as
364ec9e2 with shared seam 9945d612. Selected and unselected paths preserve
original buyer/seller domains, independent replay stores and executor-funded
value. Independent source review is clear; all six final carrier products fit
and all seventy distinct cases pass across the independently verified 45-case
shared seam and 25-case carrier/current cohorts. Actual Core/Manager/Ledger and
2-of-2 Safe are included; typed Artist/entropy/governance remain explicit.
Offer clients 1c101938 pass all 398 root package tests and exact ABI fixture
regeneration. Complete full-graph/current/Safe acceptance remains pending. The ERC20 implementation and its pending execution are described below.

ERC20 primary offers are now source-integrated as d07d9537/42ab5d2d/2e0fca1a.
The positive-token-price, PROFILE/order-one path delivers directly to the buyer,
uses original buyer/seller signatures and separate payer intent, and requires
the exact official payment receipt before minting. Existing payment and native
sale contracts are unchanged. Nonzero native reveal fees are rejected; the held
native-fee allowance patch remains separate. Independent joined source review
is clear. All eight shared and seven carrier runtime products fit; Manager is
24,174 bytes and the carrier is 22,873. Root independently checks their changed
production source pins and compiler settings. Carrier creation size is not
emitted by the selected preflight and awaits native-artifact checks. The 71-case
shared and 42-case carrier/current captures are running; only the earlier 27
focused carrier signature/revocation cases have passed. Full current execution,
Safe/permit acceptance and matching clients remain pending.

Test-only 2314878c admits the preservation fixture's provider through its actual
lifecycle before configuration. The previous joined metric export failed during
that setup; its trace is preserved. The corrected cached capture is running,
with no production changes or successful metric export claimed yet.

Full current-stack/Safe/fuzz acceptance follows deployable integrated source.
The optional primary graph-transition proposal is not an adopted launch
requirement. RC1/main/Sepolia remain unchanged.

The tables and sections below retain earlier demonstrated workflows and history.

| Workflow | Demonstrated or integrated | Next acceptance / remaining implementation |
| --- | --- | --- |
| Native auctions, acquisition and payment | Governed commerce activation, deferred minting, curated works, collection templates and custody sales have independently accepted focused workflows. Prepared custody now creates the royalty snapshot during original acquisition and later transfers the same NFT (`603e885b`). | The newer frozen `80df18c3` graph plus its recorded governed-template admission overlay passes all 22 selected current-stack cases and the separate isolated cold-call case. This excludes later integrated production changes. Complete latest operator activation and transaction-capacity acceptance remain. |
| Artist-approved royalty terms | Positive collection snapshots and mode-bound Artist approval are integrated. Canonical configured-zero snapshots now retain immutable zero token royalties and suppress future fallback (`700f7712`), with independently accepted complementary Artist and Core cohorts. | Default-source snapshots are integrated (`93b489c9`), with independently reviewed complementary Artist and Core cases covering collection precedence, disabled/frozen defaults and collection-specific consent. Dynamic poster/collaborator primary templates are integrated (`217c996a`), with all 98 focused cases and one 256-input property passing. Actual Artist and actual Core cohorts remain complementary; joined dynamic transactions, remaining rights profiles and operator admission remain required. |
| Artist succession and recovery | Ordinary and accelerated first-estate continuation have independently accepted actual Artist/Safe/Archive cases. Accelerated continuation retains guardian veto, capability restrictions and atomic retry (`465aef77`). | Closed/dismissed first-estate continuation is integrated (`2e10aef8`) with 16 independently reviewed actual Artist/Safe/Archive cases and typed Core/governance boundaries. Standing-veto and living-estate ancestry are integrated (`4b52f2c0`), with all 22 actual Artist/Safe/Archive cases passing. Later executed rotations, remaining history/dormancy branches, actual delayed-governance composition and capacity still require acceptance. All 57 historical operations plus adopted operation 58 remain in scope. |
| Preservation, museum records and finality | An earlier graph passes one complete preservation/finality ceremony; the supported collection bundle and museum export increments have separate evidence. | Remaining scope variants, recovery/cutover, reconstruction, museum conformance and latest-system composition remain. One collection ceremony does not establish every finality or genesis profile. |
| Developer client and operator | RC1 client remains usable. Compiler-selected typed clients are integrated as `e409c134`, with 52 passing tests, independent review and exact generation/typechecking against accepted native output. Earlier local graph deployment completed 530 transactions within the deployment ceiling. | Four explicit current native auction/bid/custody signing helpers are integrated (`db3fca94`), with 59 client tests and independently reproduced actual-getter encoding vectors. Complete workflow examples and latest graph activation remain. The deployment rehearsal records `productsActivated=false`; it is not a full product launch. |
| Candidate and testnet | Immutable supported RC1 and its Sepolia evidence are complete. | Expanded full-v1 implementation, complete Safe call inventory, required fuzz/stateful campaigns, all 37 genesis roles, gas conformance, full CI, new source freeze and matching testnet evidence remain. |

## Disputes, views, recovery and redemption batch

Integrated source `0be87be5` adds CollectionViews (`63e3236b`), Artist disputes 44–46
(`6c8bb4ea`), shared revenue runtime lifecycle and incident escrow recovery
(`663aa5e6`) and burn-to-redeem (`c7f18a83`). Four explicit imports (`0d7c1b57`)
resolve a combined-tree alias collision; all 1,841 sources pass ABI/type checking.
The subsequent escrow helper correction changes only expected-revert handling.

Root focused runs pass all 17 burn-redemption tests (including 256 fuzz inputs
and a threshold Safe), all 9 CollectionViews tests, and all 17 escrow recovery
tests. The original escrow capture had3 failing Safe retry oracles; the exact
GS013 and complete rollback checks remain after their test-only correction.
All production products measured in these separate captures fit. Actual current
Core/governance/operator joins and the full paid-sale recovery flow remain.

The older frozen native4 run has completed: 167 tests pass and 39 fail; all 647
production products fit. Artist fixture/preimage/URI/recipe failures are assigned
to the Artist lead; root owns the five entropy-dependency failures and three
current-graph artifact harness failures. The failed capture is retained.
These results do not cover newer source or establish full-v1 acceptance.

Repudiation 47–50 handoff `d95e8aaa` is now integrated as `582b9181`; native execution remains pending.
The metadata lead is building mandatory selectable STATIC rendering; the revenue
lead is building frozen economic Resolver continuity. Root continues the missing
mint/gate/counter/burn-to-mint features and owns combined delivery. The shared
feature checklist records build, execution and runtime integration separately.

## Recovery, client and owner-capture source batch

Integrated through `a0f6535a`: designated-dormancy recovery after executed
rotations (`43b1d56e`), original closed-dormancy history (`5ff709dc`), the typed
entropy finding/hydration client (`50c553c9`) and actual-current OwnerRecords
capture recipe (`a0f6535a`). All1,808 sources pass ABI/type checking in14.422s.
All175 client tests plus generation/build/type checks pass on integration;
all10 OwnerRecords capture Python tests and deterministic fixtures pass.
Fourteen new Artist cases and three OwnerRecords contract cases are authored
and source-reviewed but remain native-pending. The native4 source excludes this
batch; its subsequently completed result is recorded above.

The shared checklist now explicitly separates missing multi-party collaborator
policy and ARTIST_DELEGATED consent from basic collaborator/delegation support.
The initial consent-mode wording was corrected against the actual binding
admission and normative modes; it did not represent implemented mode2 behavior.
Those three feature batches are now integrated as recorded above; their broader
acceptance and the remaining feature queues continue.

## Artist deployment repairs and continuing feature work

The first combined Artist run exposed deployment-size failures before behavior
could run. The original capture is retained. Fixed helpers now carry the
existing Registry encodings, Coordinator previews and common owner accumulators
(89bbf57f, 48ce2057), Attribution/Consent transports (f81d3107), rotation
acceptance (1e16a461) and Resolver identity reads (42cf2620). Public host
selectors, storage and authorization semantics are preserved. Independent
source review is clear for the completed batches; combined runtime validation
is still required.

Selected measurements put the Coordinator at 22,944 runtime bytes, Registry at
23,914, Registry reader at 22,648, its deployment helper at 24,136, Attribution
at 23,668, Consent writer at 22,668, rotation state at 22,611 and Resolver at
23,248. These are individual compiler captures, not a completed latest-graph
deployment. Identity/hydration/Estate extraction is integrated as 5ed14ff9:
Identity measures 21,032 bytes, Estate 21,226, and its deployment helper 23,237.
Every originally oversized product has a corrected individual measurement.
The complete 1,767-source ABI/type check passes at 5ed14ff9. Its frozen
737-source, eight-suite native run now completes: 32 cases pass and eight fail;
all 446 nonempty production products fit. Seven failures reach a fresh
post-migration revenue read that still expects the original Artist Registry.
The remaining failure is an empty history read returning an array panic after
the forged import was correctly rejected. Explicit bounds and regression cases
are integrated as 3f80697f; all seven HistoryImport cases now pass in the
next frozen b60ae515 run. Both revenue resolver families consume the
authenticated completed successor (b60ae515), including
live collection/template/snapshot consent paths. Independent source review is
clear, original host ABIs/storage are preserved, and all five measured products
fit; the Primary resolver is 23,356 runtime bytes. All twelve ResolverSuccessor
cases now pass at b60ae515, including the eight new scenarios and four retained
economics cases. The earlier 737-source capture predates those repairs and the
later Metadata and publication work below.

The integrator reran the existing owner accumulator suite: all five cases pass,
including 256 fuzz inputs, original flat-word state/record hash oracles, actual
collaborator acceptance events and replay rejection. All 522 original ABI
entries across Owner, Coordinator, Registry and Registry reader remain exact,
as do their recursive storage layouts. This focused result does not replace
the pending history, hydration, recovery and joined current-Core tests.

The source batch also includes complete content/readiness attestation hydration
(85980f21) and the saved native-surplus governance workflow (d0d460e9); their
new scenarios remain native-pending. Recorded PREMIS activity graph export
(bb17874a) passes all 32 graph/event tests on integration, and its retained
actual package independently verifies offline with the original manifest hash.

The Metadata successor-consumption bridge (f6d66d8b, repaired in 0e523bb2)
retains the original authorization-use map and authenticates the completed
successor against its sealed lineage, exact constructor configuration and all
seven owner completion commitments. Its final focused run passes all 23 cases,
including the 15 originals, 256 fuzz inputs and Safe failure/retry. The actual
Artist publication candidate callback succeeds cold in 207,951 gas within the
unchanged 400,000 budget. All 43 measured production products fit; Metadata
runtime is 24,239 bytes. The earlier 22/23 failure and oversized capture remain
historical evidence. The real Artist migration and same-Metadata fresh
publication join is integrated as 76f1ef26, with three new cases and all seven
original publication tests preserved. Independent source review is clear;
Core/governance/router boundaries remain explicit. These cases and the new
Resolver cases are included in the single frozen eleven-suite, 749-source native
run at b60ae515. That run completes in 2,882 seconds: 47 cases pass and 16 fail;
all 453 nonempty production products fit. All eight unaffected suites pass. The
six readiness, seven publication and three Metadata-join failures share an
unadmitted source replacement inside their test setup. The actual resolvers
correctly retain their initial Artist-suite pins. The test-only repair c5e34514
applies each compact URI at initial onboarding and retains those pins; both
independent review and focused typecheck are clear, while runtime rerun remains
pending. No production selection guard changed. This capture predates the new
Artist/entropy and current-Core commerce cases and subsequent fixture changes.

Complete original publication-attestation hydration is integrated as d7bfd3be.
The explicit operation-60 profile preserves original evidence, signatures,
publication records, nonce guards and seven-owner activation. Earlier selectors
remain strict, and existing Metadata consumption records remain authoritative.
Independent source review is clear; seven authored cases remain native-pending.
The combined 1,776-source ABI/type check passes at 3f80697f. All 13 selected
publication/history production products fit in the exact 448-source size
capture; Attribution runtime is 23,968 bytes, Coordinator 23,100 and Registry
23,898. Combined behavioral execution remains pending.

The Artist fixture now loads exact linked creation artifacts and executes
normal CREATE (64f27fde), preserving constructors, caller, nonce order and
production admission checks. The bounded prototype passes an actual Archive
constructor/storage probe and one unchanged Artist checkpoint case. Test
creation size decreased in the recorded captures, but those captures differ;
a matched-source compile-speed improvement has not yet been measured. The
same artifact-CREATE approach now replaces 60 further constructor embeddings
across six hydration/history fixtures (02afb088). Independent review confirms
unchanged constructor arguments, CREATE order/caller/value and test assertions.
Native execution of this extension remains pending.

Five actual Artist/Safe/Archive plus EntropyCoordinator recovery cases are
integrated as 6556d8b1. They cover exact operation-17 consent evidence, scope and
journal binding, changed inputs, provider callback rollback, executor fee credit,
Archive failure/retry and a fresh consent for a later recovery step. Core,
governance execution context, roles and the upstream provider remain explicit
typed boundaries. Independent source/oracle review is clear; these cases have
not executed and do not prove the actual mint/Executor/provider join.

Designated-dormancy recovery after closed standing-veto attempts is integrated
as 5602d753. It retains the original operation-43 appointment and separately
authenticates its closure, the vetoed pending rotation's closure and the latest
dismissal. Eight actual Artist/Safe/Archive cases are authored, with independent
production review clear. They include repeated standing dismissals, later
compromise dismissals, original history preservation and rollback/retry; native
execution and current-Core composition remain pending.

Recorded exhibition export is integrated as cd3e9b98 and 38461fb1. The exact
public independent receipt, registered schema, original subject and offline
source package determine its input. Repeated identical institution/venue
declarations share resources while retaining every record's provenance;
conflicting declarations reject. All 22 focused exhibition and existing
preservation-graph tests pass on integration, and deterministic schema/profile
checks pass. Positive exhibition controls are synthetic; the retained actual
package proves replay with no selected exhibition record, not a positive
exhibition capture or full museum conformance.

The complete 1,783-source ABI/type check passes at 38461fb1. Source integration
and these focused Python results do not replace the pending contract execution.
The current revenue/Safe client is integrated as a8a9e122. All 163 client tests,
generation, build and type checks pass on integration. Its owner setup and Artist
approval remain separate calls; configured-zero/default snapshots and original
poster/collaborator template identities remain explicit. The existing revenue,
secondary and inventory negative-type cases now run in the standard test command
(d1c79232), and that expanded type check passes.

Owner-record loan dossiers are integrated as 70ce4e7b with independent source
review clear. All 29 loan/exhibition cases and deterministic loan definitions
pass on integration. Original historical owner receipts, signature bundles,
selected valuation/condition references and complete offline reconstruction are
retained. Positive wire/transcript controls are synthetic; actual retained source
covers missing owner evidence. This does not establish custody, title,
countersignatures or operative valuation.

Five actual current-Core/Artist/Safe dynamic commerce cases are integrated as
de7b5166. They join configured-zero/default snapshots, symbolic primary terms,
actual prepared mint, escrow/wallet funding and secondary resale of the same NFT.
Independent fixture/test-oracle source review is clear; execution remains pending.
The shared current-stack fixture now also loads 17 unchanged constructor calls
from exact compiled artifacts (88608fc7). Independent mechanical review preserves
all arguments, order, caller, value and intervening initialization; its native
acceptance and compile-time effect remain pending.

Explicit entropy Artist-unavailability is integrated as ee0f0159. Original
operation-23 findings now bind the complete entropy recovery intent and use the
existing notice, authority-activity cancellation and replay lifecycle. Ten actual
Artist/Archive/Entropy/Safe cases are authored; independent source review is
clear. The selected size captures fit, with EntropyCoordinator at 24,419 runtime
bytes. All 1,009 prior ABI entries and storage layouts are preserved. The
supplemental finding-history implementation is now integrated as described below;
its runtime acceptance remains separate from original receipt reconstruction.

One frozen 28-suite native run is now active at ee0f0159, covering the repaired
Artist setup, new recovery and dynamic commerce cases, retained entropy tests,
and current-Core/Safe suites. All 1,056 selected source units pass ABI/type
compilation. Runtime, production-size and fuzz results remain pending; the
larger test-contract size allowance does not relax production deployment limits.

Complete entropy-finding hydration is integrated as 7209675b. Its explicit
operation-60 profile carries original record domains, supplemental target/intent,
current finding head, authority activity and both original replay dependencies
through the sealed seven-owner migration. It composes with the supported living
payout/economics/readiness/publication profiles; first-predecessor and default
timing limits remain explicit. All 717 prior ABI entries and eleven ordinary
storage layouts are preserved. Fifteen selected products fit after extracting
fixed source-inventory workers; Source runtime is 17,252 bytes and Identity is
21,465. Independent production and test-oracle reviews are clear, including two
repaired test-memory aliases. Nine authored cases await native execution.

Actual-token primary custody-rights composition is integrated as f0e651ef.
Seven authored cases use the actual Core, Artist, delayed Governor and threshold
Safes: original prepared acquisition, separately approved token PROFILE/TEMPLATE
terms, activation, paid delivery of the same NFT, exact rollback/retry and no-bid
return. Original mint and frozen royalty receipts remain unchanged. Independent
source/oracle review is clear; native execution and gas remain pending.

Typed valuation dossiers are integrated as fd5601d3. All 36 valuation and
retained loan tests pass on integration, and schema/profile generation checks
pass. Appraisal, book-value and insurance statements retain literal amounts,
dates, named roles and confidential-instrument references. Optional complete
valuation lanes and original receipt order qualify the exact loan-selected
reference, including same-block order and explicit supersession. They do not
establish legal operativeness or professional countersignatures. Positive wire
controls are synthetic; actual positive record capture is the next work item.

The whole-repository 1,803-source ABI/type check passes at 7209675b. These three
increments postdate the still-running ee0f0159 native capture. Builders continue
dormancy recovery after executed successor rotations, typed entropy-authority
Safe client workflows and an actual OwnerRecords museum capture recipe.

The independently reviewed resumable Safe inventory-opening client workflow
is integrated as 0f80e00a. All 150 client tests, generation, build and negative
type checks pass, including 13 new workflow cases. The complete 1,769-source
Solidity ABI/type check also passes at 0f80e00a. The current revenue client
batch now passes as described above; contract acceptance remains separately
scoped. The immutable RC1 and Sepolia instance remain unchanged.

## History, credit export and actual rights capture

Ordered fresh entropy recovery is integrated as c5a7d0c4, with explicit import
boundaries in bbff6342. Original token/scope inputs, exact Artist evidence,
provider proof, fee ownership and frozen late-reply arbitration pass all 100
focused cases across ten suites. Eight properties each pass 256 inputs. All 15
measured products fit; coordinator runtime is 24,522 bytes. The 79-source native
capture precedes two import-only edits: all 15 executable creation/runtime
programs and complete ABI entries remain identical after those edits. Actual
joined Artist/Executor recovery, the unavailability alternative, historical
entropy-host admission and maximum-depth gas remain required.

Canonical Artist/collection lanes and original operations 55-57 are integrated
as 6dabede5, with Cause completeness in 93dcd817, entropy content evidence in
76e52ce4 and complete producer guard/nonce inventories in 4892adc6. Distinct
operation 60 adds complete original-living hydration (d0664b91), payout history
(5d84075f) and direct economics history (7439f723). Independent source reviews
are clear. These exact profiles preserve source records, complete replay/nonce
guards and atomic seven-owner activation. They do not accept other histories
implicitly. The combined 708-source Artist native cohort completed compilation
but all seven suites failed during setup: the fixed extension factory rejected
an oversized Registry reader. No selected behavior test executed. Fourteen
production products exceeded deployment limits in that source capture.
The size repairs below precede the next combined run; actual current-Core
cutover and complete history-profile acceptance remain outstanding.

Six-host governed native surplus recovery is integrated as 85fa1d8b, followed
by complete credit discovery/export in 4c7887a4. Original locked liabilities,
claimable balances and zeroed historical accounts remain enumerable, including
retired hosts discovered through the Registry. The client records one pinned
block and reproduces original credit leaves and the ordered tree offline.
Both source reviews are clear and selected products fit. Eight credit-export
and nine surplus Solidity cases remain authored rather than runtime-accepted.

Actual preservation capture (81522bd3) executed 317 local transactions and
captured three preservation events plus one object. Metadata RIGHTS capture
(6f31d497) executed 535 local transactions, including three deliberate Safe
denials, and captured both class-7/8 receipts plus 22 independent records.
Root reproduced all 21 combined capture tests and independently verified the
RIGHTS package: 435 payload files plus its manifest. Genuine retained native
products use the documented unfulfilled, unselected Artist Coordinator
boundary. This demonstrates independent publication paths, not a complete
initialized Artist graph or institutional conformance.

The complete 1,735-source ABI/type check passes at 6f31d497. The current client
passes all 137 tests, generation checks and TypeScript validation, including
six new entropy incident/quote/recovery/Artist-consent/credit cases. Its original
operation-17 transport and Safe value are preserved; client encoding tests do
not replace contract runtime acceptance. The immutable RC1 and Sepolia evidence
remain unchanged.

## Latest feature batch

Reviewed source now includes native secondary inventory sales (`5f950745`),
account-directed delegated private/offer/inventory claims (`764ee2a4`), and
live delegate-signed offers (`9e6b3562`). Original principal payment, owner grants,
royalties, replay and pull claims remain shared with the existing paths.
Selected final offer products all fit; the adapter measures 23,610 runtime bytes.
These new commerce tests are authored; their native and combined acceptance remain pending.

Artist authority preimages and enumerable payload discovery are integrated
(`af6f1be0`). Fixed workers address the five previously measured Artist size
failures at the reviewed reconstruction snapshot; later full-graph size and
execution remain unaccepted. Full typed dormancy/steward event companions and
an independent reconstruction harness are integrated (`f79b5294`); five new
cases remain authored rather than runtime-accepted. Existing operations 1-58
and adopted operation 59 remain in scope. Further recovery histories and event
reconstruction continue. A separate steward-to-living-artist recovery proposal
remains unapplied after automatic review requested explicit owner approval of
that specific authority transition.

Complete chunked artwork snapshots and strict offline reconstruction/export
are integrated (`4d4b0c7f`). Museum BagIt/OCFL packaging and offline byte hydration
are integrated (`692236f6`, `ae80f67b`). All 27 packaging/hydration tests pass on
the integration checkout. Independent review found a shared-directory casing
bug; the integrated fix rejects inconsistent spellings before writes. These
formats preserve source qualifications and exact original evidence. Full-size
snapshot execution, broader PREMIS profiles and institutional conformance remain.

Governed entropy provider lifecycle is integrated as `3481e8fd`. Admission and
restoration require exact delayed actions; deprecation and incident revocation
use the tightening class. Deprecation preserves pending callbacks; revocation
blocks them until explicit restoration, preserving the original request/output.
All 41 focused native cases pass, including three 256-input fuzz properties and
actual Safe calls with explicit Core/provider/governance context boundaries.
All eight compiled production products fit: coordinator runtime 24,525 bytes,
creation 28,835. All 144 original ABI entries are retained, and all 58 captured
sources match the current checkout. Earlier oversize builds and one extracted
validation-order regression are retained; the final run fixes both.

Current graph admission and actual Safe/ARRNG transition recipes accompany the
lifecycle. Saved provider/operator stages are integrated as `e627676b`; their
five new cases and seven inherited cases all pass against the actual
foundation/Executor/coordinator/Safe. Test-only correction `f08bb466` fixes the
independent assertion of aggregate governance hashes. All 40 compiled production
products remain byte-identical to the original operator capture and fit deployment
limits. This capture precedes the later recovery-policy implementation. The
complete 1,681-source joined ABI/type check passes at `e627676b`; it establishes
that earlier source composition rather than latest full-system acceptance.
Complete current-stack/Safe, stateful/fuzz campaigns, gas, all 37 genesis roles,
CI and matching new testnet evidence remain required. Entropy unavailability recovery,
remaining interfaces/operator workflows and the separately blocked ERC-20 and
inherited/global-freeze changes remain explicit. RC1 and Sepolia are unchanged.

## Latest client and preservation additions

Artist rotation/estate authority execution-event reconstruction is integrated
as `217bdc8c`, with independent source review and five new authored cases.
Recorded PREMIS fixity events, reports and agents are integrated as `8798bb7e`.
All 14 new fixity cases pass on this integration checkout; the builder's broader
40-check result includes existing profiles. Positive typed examples are synthetic;
retained actual source covers missing evidence and offline package replay.

The broader preservation-event profile is integrated as `b690e5ee`: twelve
generic event kinds and six outcomes, existing strict fixity composition,
multiple object/agent links, noncompleted source states and offline replay.
All 24 generic/fixity module cases pass on integration after independent review.
Positive event examples in that profile are synthetic; its actual source supports
qualified missing-evidence and replay cases. The object/rights batch below adds
their canonical serializers.

Secondary inventory/delegated-claim/offer client helpers are integrated as
`0904ec7c`. The combined package passes all 97 tests, generated-catalog checks,
TypeScript build and negative type cases. It retains both the manifest and
secondary exports and requires explicitly selected current compiled ABIs.
Client RPC fixtures do not establish Solidity runtime or live deployment acceptance.

Frozen fresh-recovery policy configuration is integrated as `ce713350` through
an additive coordinator interface. Exact ordered hashes, class-1 governance,
role references, replay rejection and permanent freeze pass nine new policy
cases plus 27 provider/epoch/subject regressions. Three properties each pass 256
inputs. All nine production products fit, including coordinator runtime 24,141
bytes; all 162 prior ABI entries remain. This is the policy-registry checkpoint. The later collection binding is described
below; actual fresh requests and late arbitration are recorded in the newer
batch above. No fresh request is enabled by policy registration alone.
The joined 1,688-source Solidity ABI/type check passes on this implementation.

## Collection binding, delegated refunds and object/rights batch

Pre-mint frozen recovery-policy binding is integrated as `7323d1d3`. It requires
exact class-1 governance, selected active provider pins and ordered future
epochs; binding changes advance the original collection epoch. First token or
scope registration and Core freeze lock the binding. Finality reads retain the
original unbound commitments and disclose positive frozen recovery policies.
All 44 focused native cases pass, including three 256-input properties. All ten
production products fit; coordinator runtime is 24,553 bytes. All 62 captured
sources match integration and all 175 prior ABI entries remain. Independent
source review is clear. The first oversize run is retained; moving the new
transition encoding into the fixed read worker resolves it. Actual fresh
requests, Artist evidence consumption and late callbacks are integrated in the
newer batch above; this binding capture alone does not validate them.

Native fixed/price-program, Dutch, clearing and refund-window delegated claims
are integrated as `91847ee9`. The original account remains the destination, and
self-claims retain their existing exits. Optional delegation is checked through
its declared module and exact live relationship. Thirteen new current/Safe cases
are authored, with native acceptance pending. The combined client passes all
107 tests, generation checks and TypeScript validation on integration.

Canonical preservation objects and actual Metadata RIGHTS receipt adapters are
integrated as `c112d4ce`. The independent review's record-scoped licensor-ID
collision fix is included. All 14 object/rights tests pass on integration; the
builder's combined object/event/fixity suite passes 38. Positive receipt fixtures
remain synthetic, while retained actual source supports missing-evidence and
offline replay cases. The newer actual preservation and RIGHTS captures are described above; institutional conformance and latest-system acceptance
remain open.

## Earlier manifest and attestation batch

The integrated source now includes PLATFORM_WORKS royalty admission (`0385044d`),
live nested Artist attribution with an original-finality anchor (`ed2dc08d`),
full typed script/media manifest records (`bf828769`, `a9d7e7ec`), and state-bound
and delegated Artist attestations (`40c6169a`). Independent source reviews are
complete. Broad current-stack and Artist runtime acceptance remain pending.

The expanded Artist and metadata owners exceeded the runtime size limit.
Fixed linked workers restore size headroom while preserving existing public
interfaces and owner storage (`59a07181`, `8f63f71c`, `756b0b80`). Selected Artist
code generation checks all 16 affected hosts, workers and deployment libraries;
the latest full graph and transaction-capacity checks remain separate.

The joined 1,572-source ABI/type check passes at `756b0b80`. The metadata native
cohort then exposed an unsupported fixture URI and an overly restrictive
optional script-mirror validator. Correction `42a65b60` admits bounded content
references without executing them. All 13 focused cases now pass: nine actual
Router/metadata/blob/Safe manifest cases and four governed-budget parity cases.
Core, Artist and governance boundaries in that cohort are explicit typed
fixtures. All 67 captured production products fit the bytecode limits. The
captured production is exact in integration; one test differs only by formatting.
Initial failures remain retained. These results do not establish full-system
behavior or transaction gas conformance.

Manifest preview, original Artist content-consent signing and Safe CALL helpers
are integrated as `3c1915a2`, with independent source review and all 83 client
tests passing. They preserve absent external hashes and full-width integers.
Earlier entropy epoch implementation `c3c22d4a` retains its separate 16 passing
native cases and 256-input property; its accepted policy still excludes fresh
recovery and post-mint provider migration.

The later integrated lifecycle, platform-commerce and chunked-artwork batches
are described above. The ERC-20 and inherited/global-freeze approval restrictions
remain as stated above. No released RC1 source, tag or Sepolia evidence changed.

## Delivery sequencing

On 14 September the owner directed feature completion before comprehensive
integration/testing. Builders now finish larger source-reviewed domain batches
while existing frozen tests run. Cheap compilation/type checks and authored
regressions accompany implementation; full current-stack/Safe runs, campaigns,
gas conformance, CI and new release evidence follow the integrated feature
batch. Source integration and demonstrated runtime acceptance are reported
separately. [Current assignments](AUTONOMOUS_RUN.md#active-work) own this order.

## Source batch integrated before comprehensive testing

The 14 September feature-first batch adds current Artist/collaborator client
signing and Safe CALL preparation (`35911382`), governed dynamic-template
admission (`b08af8a8`), recovery after an estate-successor rotation (`a992f183`)
and token-PROFILE custody activation/settlement (`9d9147e1`). All 792 selected
Solidity source units pass combined ABI/type compilation. The client suite and
its additional Safe onboarding example pass their lightweight checks.

The next integrated feature batch adds successive/returned-address rotations
and closed terminal histories (`ce98c9eb`), token TEMPLATE and explicit default
PROFILE commerce (`80b99ee8`), and an offline four-format museum package
(`f38cbd4a`). The combined 813-source Solidity ABI/type check passes. New custody
client helpers (`4bfe443f`) prepare both approval domains, actual-getter readback and explicit
activation, bidding and settlement calls for Safe; all 72 client tests pass.
All 11 four-format museum package tests pass on public synthetic input. The
recorded-account package is now integrated (`c91bd027`), with all 30 package/account
replay tests passing. That initial checkpoint exported Linked Art only; the newer recorded-format
adapters described below supersede its limitation. Independent source review found no
actionable mismatch in the new custody client encoding and Safe call helpers.

The prior estate-rotation snapshot now passes all 28 actual Artist/Safe/Archive
cases, with typed Core/governance boundaries. This does not validate the later
multi-rotation history batch. The frozen token-PROFILE custody build compiled,
but its house measured 24,962 bytes, 386 above the runtime limit, so the size
gate stopped before any of its 120 tests. A fixed linked worker extraction is
integrated (`97e53de0`); its final size and the later rights batch runtime still
require the consolidated native build.

The next source batch integrates guardian supersession across historical vesting
(`2071ebc9`), repeated recovery (`4489d706`), default TEMPLATE commerce
(`7180d9eb`) and exact TEMPLATE clear/freeze consent (`db6de32c`). Original
Artist operation 15 and its signing domain are preserved for economics approval.

Recorded PREMIS (`2da5da31`), IIIF (`d3acf4fa`) and LIDO (`cb9a05d5`) are
integrated with exact selected source facts and explicit missing-data reports.
Focused adapter/compatibility runs pass 37 PREMIS, 37 IIIF and 13 LIDO cases;
these sets overlap and must not be summed. Complete positive controls are
synthetic. The newer complete-media capture (`a0824111`, `41dfe4ba`) publishes
11 records through actual native foundation contracts and a two-owner Safe. Its
four-format package independently reconstructs offline; nine input/loader/CLI
tests pass. The same captured source without its selected publisher withholds
only LIDO. This is a public test-image example on a selected local foundation,
not whole-product or institutional acceptance.

The native immediate-sale source now funds the live declared reveal fee apart
from official revenue, attempts AT_MINT after the mint and credits unused fee
allowance to the payer. The original purchase/signing surfaces remain, with an
additive quote/refund interface and explicit deployment gas parameter. Ten new
focused cases and the actual-current Safe success/fallback scenarios are
written; native runtime, final size and transaction gas remain pending. Read
[the caller guide](../docs/native-immediate-reveal.md) for the payment and Safe
refund semantics. The combined ABI/type check covers 877 Solidity inputs.
The immediate-sale client now prepares both preserved signing domains, exact
Safe payment/refund calls and quote/digest reads. All 78 client tests pass;
compiled ABI and literal Solidity preimages anchor the new encoding cases.
Live digest execution and the new contract runtime remain separate acceptance.

Artist PLATFORM_WORKS declaration/claims/correction is integrated (`be95e191`,
`0c2d7d65`) after independent review. It adds exact collection-subject archival
proofs and preserves declaration-versus-sanction finality history. The joined
886-source ABI/type check passes; runtime, paid platform commerce and full
attribution display remain pending. The next Artist and metadata work completes
the live attribution profile and the supporting canonical reads.

Closed and reopened repeated-recovery histories are integrated (`a3bea3b4`)
after root and independent production-source review. Six new scenarios are
authored; their runtime acceptance is pending. The final combined ABI/type
check covers 888 Solidity inputs. Artist and metadata work now builds the
complete live attribution display and its canonical attestation/claim reads. Inherited/global primary freezes remain blocked pending
the specific approval requested. Automatic review rejected the ERC-20 source
write again despite explicit owner approval; its exact patch is being prepared
for review. ADR 0045 records the selected denomination and refund design without
claiming that implementation has shipped.
Root owns immediate-sale entropy, operator/client and genesis completion,
followed by consolidated current-stack/Safe acceptance.

## Current integration batch

- Original `a65f7f3e` production graph: the repaired native-settlement cohort
  passes all seven cases. The reusable preparation fix then passes the full
  selected 21-case cohort and the separate isolated cold regression on an
  isolated copy of the retained native compiler outputs. Both runs skip
  compilation and preserve sources, native artifacts, cache and graph inputs.
  The earlier 18/3 failure remains historical evidence; latest production still
  needs its own combined checkpoint.
  The newer frozen `80df18c3` graph plus its recorded governed-template admission
  overlay has now compiled and passes all 22 selected cases and the isolated cold
  regression. A result-reader correction handled an omitted empty compiler map;
  compiled artifacts were preserved and no second build ran. This excludes the
  later estate-rotation, custody, native reveal and PLATFORM_WORKS changes.
- Dynamic primary templates `217c996a`: all 98 focused cases pass, including one
  256-input property. A fixed linked worker reduces Resolver runtime to 22,442
  bytes; all 600 production products fit. Full previous ABI/storage compatibility
  is retained. Complete current Artist/Core composition and gas remain open.
- Standing-veto/living-estate history `4b52f2c0`: all 22 focused cases pass,
  including all 16 retained cases. All 560 production products fit. The next
  artist slice follows an executed class-3 rotation after estate succession.
- Prepared custody, accelerated/closed estate recovery, disabled/default royalty
  snapshots and these two newest increments need latest combined acceptance.
- Current typed signing/call helpers are integrated, with 78 client tests.
  Complete workflow examples and operator activation remain open.
- Root owns latest integration, client/operator work, shared fixtures and
  candidate closure. Two builders continue the next artist and token-specific
  royalty workflows; the independent reviewer challenges source and behavior.

## Issues that affect delivery

The specified 500,000-gas all-cold collector ceiling remains unproven. The
retained 8,755,856-gas clearing trace is an earlier implementation's first
successful purchase after setup, rejection and consent; it is neither all-cold
nor a measurement of the current compressed implementation. Later optimized
domain measurements remain above the ceiling, and later actual-current tests
establish functional behavior without a current all-cold measurement. Fresh
current transaction measurements and shared-path cost work remain required.
Successful deployment within its separate transaction limit does not establish
collector conformance; the specification limit has not been waived.

Full CI is not green and release artifacts still describe the retained baseline.
Generate new candidate evidence from a stable integrated build, without changing
the published RC1. Compiler, packaging and test-oracle repairs are enabling work
and are not counted as additional completed features.

No replacement percentage or completion date is supported by a reconciled
remaining-effort inventory. Reports identify newly demonstrated workflows,
unfinished behavior, and the next concrete acceptance result.
