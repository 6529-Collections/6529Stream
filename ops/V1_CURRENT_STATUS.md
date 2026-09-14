# Full-v1 current delivery status

Updated 14 September 2026. This is the current reporting entry point.
The [delivery ledger](V1_DELIVERY.md) retains implementation checkpoints and the
requirement index. Historical statements there do not override the newer state
below. These workstreams are not a feature-count or percentage denominator.

The supported RC1 is already deployed on Sepolia from
`569bf87f1fa808787d324f6e1582924b5ccf1d40`. The expanded full-v1 candidate is not
complete. No new funding or owner decision is required for current work.

| Workflow | Demonstrated or integrated | Next acceptance / remaining implementation |
| --- | --- | --- |
| Native auctions, acquisition and payment | Governed commerce activation, deferred minting, curated works, collection templates and custody sales have independently accepted focused workflows. Prepared custody now creates the royalty snapshot during original acquisition and later transfers the same NFT (`603e885b`). | The frozen `a65f7f3e` combined run now executes: both actual Artist/Safe consented-commerce cases and both royalty-snapshot cases pass. The 21-case aggregate has 18 passes and three graph-setup failures; retained-export cleanup and separate cold acceptance remain under investigation. It excludes later integrated production changes. Complete latest operator activation and transaction-capacity acceptance remain. |
| Artist-approved royalty terms | Positive collection snapshots and mode-bound Artist approval are integrated. Canonical configured-zero snapshots now retain immutable zero token royalties and suppress future fallback (`700f7712`), with independently accepted complementary Artist and Core cohorts. | Default-source snapshots are integrated (`93b489c9`), with independently reviewed complementary Artist and Core cases covering collection precedence, disabled/frozen defaults and collection-specific consent. Dynamic templates, remaining rights profiles and joined acceptance remain required. |
| Artist succession and recovery | Ordinary and accelerated first-estate continuation have independently accepted actual Artist/Safe/Archive cases. Accelerated continuation retains guardian veto, capability restrictions and atomic retry (`465aef77`). | Closed/dismissed first-estate continuation is integrated (`2e10aef8`) with 16 independently reviewed actual Artist/Safe/Archive cases and typed Core/governance boundaries. Remaining historical/rotation/estate/dormancy branches, actual delayed-governance composition and capacity still require acceptance. All 57 historical operations plus adopted operation 58 remain in scope. |
| Preservation, museum records and finality | An earlier graph passes one complete preservation/finality ceremony; the supported collection bundle and museum export increments have separate evidence. | Remaining scope variants, recovery/cutover, reconstruction, museum conformance and latest-system composition remain. One collection ceremony does not establish every finality or genesis profile. |
| Developer client and operator | RC1 client remains usable. Compiler-selected typed clients are integrated as `e409c134`, with 52 passing tests, independent review and exact generation/typechecking against accepted native output. Earlier local graph deployment completed 530 transactions within the deployment ceiling. | New signing-domain parity, complete workflow examples and latest graph activation remain. The deployment rehearsal records `productsActivated=false`; it is not a full product launch. |
| Candidate and testnet | Immutable supported RC1 and its Sepolia evidence are complete. | Expanded full-v1 implementation, complete Safe call inventory, required fuzz/stateful campaigns, all 37 genesis roles, gas conformance, full CI, new source freeze and matching testnet evidence remain. |

## Current integration batch

- Frozen current graph: `a65f7f3e`. Native compilation completed in 143 minutes.
  A Python projection fix permits cached execution: 18 of the selected 21 cases
  pass, including all four new actual Artist commerce/snapshot cases. Three
  older cases fail during graph setup. The successor runner then stopped on
  an artifact-tree guard: compiled projections were unchanged, but retained
  native exports were removed and test render outputs added. Investigation and
  the separate isolated cold-call case remain open; the batch is not accepted.
- Integrated after that freeze: prepared custody `603e885b`, accelerated
  estate `465aef77`, disabled royalties `700f7712`, default snapshots `93b489c9`,
  and closed-estate recovery `2e10aef8`. Their focused acceptance is retained;
  they need a subsequent combined checkpoint.
- Client bindings `e409c134` preserve the RC1 export and support explicit current
  compiler catalogs. New signing domains and complete workflow migration remain.
- Artist and revenue builders continue standing-contest/later-estate history
  and dynamic primary-template work.
  Root owns integration, client/operator work and candidate closure. Independent
  review challenges source and test behavior before expensive compilation.

## Issues that affect delivery

The specified all-cold collector gas ceiling remains unresolved: a previously
captured current clearing call used 8,755,856 gas against a 500,000 ceiling.
Successful deployment within the separate transaction limit does not resolve
that gap. Required behavior must be made to conform or an explicit specification
decision must be recorded; the limit has not been silently waived.

Full CI is not green and release artifacts still describe the retained baseline.
Generate new candidate evidence from a stable integrated build, without changing
the published RC1. Compiler, packaging and test-oracle repairs are enabling work
and are not counted as additional completed features.

No replacement percentage or completion date is supported by a reconciled
remaining-effort inventory. Reports identify newly demonstrated workflows,
unfinished behavior, and the next concrete acceptance result.
