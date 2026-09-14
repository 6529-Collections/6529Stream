# Full-v1 current delivery status

Updated 14 September 2026. This is the current reporting entry point.
The [delivery ledger](V1_DELIVERY.md) retains implementation checkpoints and the
requirement index. Historical statements there do not override the newer state
below. These workstreams are not a feature-count or percentage denominator.

The supported RC1 is already deployed on Sepolia from
`569bf87f1fa808787d324f6e1582924b5ccf1d40`. The expanded full-v1 candidate is not
complete. No new funding is required. Automatic approval review has blocked
local inherited/global primary-freeze implementation pending a more specific
owner approval. The separate ERC-20 payable reveal-fee implementation is also
blocked by automatic review even after the owner explicitly approved that local
implementation. The exact patch is being prepared for review; other work continues.

| Workflow | Demonstrated or integrated | Next acceptance / remaining implementation |
| --- | --- | --- |
| Native auctions, acquisition and payment | Governed commerce activation, deferred minting, curated works, collection templates and custody sales have independently accepted focused workflows. Prepared custody now creates the royalty snapshot during original acquisition and later transfers the same NFT (`603e885b`). | The newer frozen `80df18c3` graph plus its recorded governed-template admission overlay passes all 22 selected current-stack cases and the separate isolated cold-call case. This excludes later integrated production changes. Complete latest operator activation and transaction-capacity acceptance remain. |
| Artist-approved royalty terms | Positive collection snapshots and mode-bound Artist approval are integrated. Canonical configured-zero snapshots now retain immutable zero token royalties and suppress future fallback (`700f7712`), with independently accepted complementary Artist and Core cohorts. | Default-source snapshots are integrated (`93b489c9`), with independently reviewed complementary Artist and Core cases covering collection precedence, disabled/frozen defaults and collection-specific consent. Dynamic poster/collaborator primary templates are integrated (`217c996a`), with all 98 focused cases and one 256-input property passing. Actual Artist and actual Core cohorts remain complementary; joined dynamic transactions, remaining rights profiles and operator admission remain required. |
| Artist succession and recovery | Ordinary and accelerated first-estate continuation have independently accepted actual Artist/Safe/Archive cases. Accelerated continuation retains guardian veto, capability restrictions and atomic retry (`465aef77`). | Closed/dismissed first-estate continuation is integrated (`2e10aef8`) with 16 independently reviewed actual Artist/Safe/Archive cases and typed Core/governance boundaries. Standing-veto and living-estate ancestry are integrated (`4b52f2c0`), with all 22 actual Artist/Safe/Archive cases passing. Later executed rotations, remaining history/dormancy branches, actual delayed-governance composition and capacity still require acceptance. All 57 historical operations plus adopted operation 58 remain in scope. |
| Preservation, museum records and finality | An earlier graph passes one complete preservation/finality ceremony; the supported collection bundle and museum export increments have separate evidence. | Remaining scope variants, recovery/cutover, reconstruction, museum conformance and latest-system composition remain. One collection ceremony does not establish every finality or genesis profile. |
| Developer client and operator | RC1 client remains usable. Compiler-selected typed clients are integrated as `e409c134`, with 52 passing tests, independent review and exact generation/typechecking against accepted native output. Earlier local graph deployment completed 530 transactions within the deployment ceiling. | Four explicit current native auction/bid/custody signing helpers are integrated (`db3fca94`), with 59 client tests and independently reproduced actual-getter encoding vectors. Complete workflow examples and latest graph activation remain. The deployment rehearsal records `productsActivated=false`; it is not a full product launch. |
| Candidate and testnet | Immutable supported RC1 and its Sepolia evidence are complete. | Expanded full-v1 implementation, complete Safe call inventory, required fuzz/stateful campaigns, all 37 genesis roles, gas conformance, full CI, new source freeze and matching testnet evidence remain. |

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
