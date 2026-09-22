# Stream feature status

Updated **22 September 2026 (UTC)**. This is the shared feature checklist for
the **complete v1 contract system and the adopted museum proposal**, including
the agreed additions. It replaces informal percentage estimates. The integrator
owns the whole result; domain builders supply implementation and evidence.

**Where we stand:** supported RC1 is on Sepolia. Expanded v1 is not yet
feature-complete or accepted as a combined system. The integrated branch now
includes delegated Artist consent, first dormancy guardian supersession, bounded
mint-policy grace, complete 37-role construction and activation helpers, scoped
content-root publication, and the complete Museum schema source catalog.
Remaining product gaps, deployment-size repairs and actual publication capacity
are explicit below. Source integration and successful system execution are
different milestones.

## Latest integration checkpoint: 22 September

Expanded full v1 remains incomplete. Integrated source `19f0ed0b` includes
the current collaborator repair, client scheduling repairs and new Museum
profiles. ABI206 checks **4,686 Solidity sources with zero errors** at
`60025e9a`; later changes are Museum software only. The canonical inventory
contains **3,136 production paths**. Source integration and scoped tests do not
establish full current-stack acceptance. RC1 and Sepolia remain unchanged.

- **Artist contracts:** `07265d875` integrates the current collaborator repair
  while preserving the later sanction12/13 and ratification52 features. Both
  independent and root source reviews are clear. Twenty-seven regression cases
  are authored; one bounded native campaign is running. Complete History and
  repeated-import/Safe test composition remain source-integrated, not accepted
  through the full current graph. Class4 activation is still open.
- **Museum exports:** `a35a05d34` adds authenticated native IIIF painting and
  PREMIS events, agents and rights in the portable package. All **46 focused
  root tests pass** on that exact source. Retained synthetic inputs remain
  identified; this does not establish institutional acceptance or a current
  public-chain capture.
- **Museum declarations and review:** `b7cd578e` adds explicit correction,
  merge and complete split lineage. `1a899e47` and `19f0ed0b` add a separately
  registered profile and exact source/reviewer admission policies. Old profile
  bytes and authority boundaries remain intact. Independent review is clear;
  all **89 combined root tests pass**. These are software/replay controls.
  The builder has also retained an actual local registered account-review
  capture using explicitly historical contract products; root intake and
  selection tests follow. General and Artist review adapters remain separate
  implementation work; account qualification does not prove human independence.
- **Clients and CI:** the original 51 Inventory lifecycles now run in 17
  independent stages, with all assertions retained. Platform11/53 provider
  regression coverage and measured timing inputs are integrated. The timing
  tools pass 14 root checks; the eight new provider tests pass on the producer.
  The current client plan has **246 files and 1,472 execution units** across
  the same 16 shards and original time limits. The last remote matrix on the
  older `bf0e803e` source passed 15 shards; its unpartitioned Inventory unit
  timed out. A new remote run must validate the repairs. Full CI is not green.
- **Preservation execution:** the frozen `39ed249c` campaign passes all
  **31 manifest cases**, including two 256-input fuzz properties. The complete
  44-case campaign has prepared 163 products across 25 verified native contexts;
  checkpoint execution and full-constructor/gas checks remain pending. Two
  compiler-side lint failures are retained separately. The new genuine
  checkpoint-to-manifest three-case batch is source-integrated as `158ba55c`
  and remains unexecuted.
- **Capacity and remaining integration:** current preservation size repairs
  remain measured at `5104c901`/`402bad28`; checkpoints are 22,475 runtime bytes
  and manifests 14,293. Older isolated Collector captures still contain the
  original overruns and cannot reuse these newer results. Owner test artifact
  assembly and isolated paid-flow optimization continue. Neither is actual
  full current-stack acceptance, and the 500,000-gas paid-flow ceiling remains.

Remaining delivery work includes missing feature combinations and Museum
adapters, current deployment-size/gas checks, actual current-stack and all-call
Safe integration, complete fuzz/stateful campaigns, full CI and matching release
evidence, then a frozen candidate and new testnet demonstration. No new funding
is required. Audit, production ceremonies and Lean remain separate.

Automatic approval review has blocked several destination-specific task
handoffs, a Class4 handoff read and the separate Artist native run. The exact
permission questions remain pending; held payloads and operations have not
been routed through alternative executors. Unaffected work continues.


## How to read this document

Build, testing and integration are separate facts. Read all three columns;
there is no single status that turns a local unit test into a shipped feature.

| Column | Status | Meaning |
| --- | --- | --- |
| Build | Not started | No implementation of the stated capability was found in the reviewed source. A specification, interface reservation or an unapplied patch does not count as built. |
| Build | In progress | Some implementation exists or the assigned builder is actively implementing it; the stated feature still has missing parts. |
| Build | Built | Source implements the explicitly bounded scope in the row. Any broader unsupported profile has its own row or is stated as remaining. |
| Tests | Not tested | No executable acceptance evidence was identified for this feature. This is not a claim that every historical branch was searched. |
| Tests | Tests written | Tests exist, but a successful behavioral run has not been established for the stated feature. Compilation alone is insufficient. |
| Tests | Partly tested | Only a subset, earlier version, primitive or synthetic control has passing evidence, or the current acceptance batch is unresolved. |
| Tests | Tested* | A successful scoped run is identified. The evidence below states its source, cases and limits; this never means that all later edits or all of v1 passed. |
| Integration | Not integrated | No demonstrated interaction across the feature's required current components. Code may already be committed to the integration branch. |
| Integration | Partial | Some real component/workflow interaction is demonstrated, or only part of the complete integration is present. Typed substitutes and missing latest acceptance are called out. |
| Integration | Integrated* | The stated bounded workflow has run through its required real components, or an actual recorded source has been exported and replayed. The evidence identifies the snapshot and scope. |

An asterisk always means **read the bounded evidence**, not “latest full-v1
acceptance.” Synthetic museum documents can test semantic exporters; they
cannot prove that the corresponding positive record was captured from actual
contracts. LegacyStreamCore/legacy minter tests do not prove the current stack.

This is a feature-level inventory, with operation/component/schema crosswalks.
It is not a completed audit or a line-by-line proof of every normative MUST.
The [specification policy](../docs/spec-policy.md) controls requirements; this
document records delivery status without narrowing those requirements.

## Source and delivery boundaries

| Item | Snapshot / state |
| --- | --- |
| Current integration source | `904f1bc3`: corrected Artist phase6 `50bd67116`, Complete History clients `904f1bc3`; production repair remains `402bad28`; full source ABI202. Runtime evidence stays source-specific. |
| Active delivery PR | Draft [#744](https://github.com/6529-Collections/6529Stream/pull/744); expanded v1 is not merged to main |
| Deployed supported RC1 | `569bf87f1fa808787d324f6e1582924b5ccf1d40`; its Sepolia evidence does not cover the newer branch |
| Integrated Artist handoff | `49f22c34dac90d444560e88de1d0354ce9cf5525`: designated dormancy followed by executed rotations; ART23 |
| Further integrated Artist handoff | `9ea144c85768050ec910cc8534af13bcac82e20d`, received during assembly: closed-origin dormancy/rotation extension on the preceding handoff; ART24 |
| Integrated entropy client handoff | `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`; client.entropy-authority |
| Integrated OwnerRecords capture handoff | Original `57ac8d04`; composition `65312baa` adds 24 focused root passes, actual RPC pending; MUSEUM-36. |
| Latest broad cheap compilation evidence | ABI202: 4,634 sources at `904f1bc3`, zero errors in 56.015s; types/interfaces/storage/method IDs only. |
| Completed broader native batch | Frozen `ee0f01599b638ae8437ac794e43d83fe1a2be9f5`: 28 suites /1,056 sources,167 passed /39 failed; all 647 production products fit. See [native4 failures and assignments](#cohort-native4). Later source is excluded. |
| Latest focused native evidence | Reader51 passes at exact `9db6df06`; historical8 and Metadata7 pass at exact `7053ab06`, all independently reviewed and sealed. Metadata7 includes 256 fuzz inputs. Archive correspondence adds six native passes and fuzz256 at `e93cb091`. Publication11 now passes with fresh export and independent replay on `9d4af023`; Registry6 passes on `6d9729c6`. Provider12 passes all 12 original cases at frozen `eda052c7`, including one 256-run fuzz case, with independent native creation/link/caller review. This does not accept the later complete graph. |

Earlier implementation notes use “integrated” to mean source merged. In this
document, that is only **code location**; runtime integration has its own column.
Source paths below are relative to the integration repository unless a handoff
is explicitly named. The snapshot is fixed even while builders continue working.

## Priority work still to build

| Area | Missing implementation / incomplete product | Accountable delivery owner |
| --- | --- | --- |
| Mint eligibility and distribution | Required Merkle price consumers are built; demonstrate actual Artist successor-Manager, burn, imports and distribution workflows | Mint and burn visible tasks; integrator owns Core |
| Artist authority | Ten observed recovery helper size failures have reviewed integrated repairs with fitting selected builds; complete broader recovered aggregate/corrected/collaborator profiles and actual all-operation ceremonies. Recovered base multiplicity and op24/C2PA singleton history are source integrated; current runtime acceptance remains pending. | Two local Artist builders; integrator owns final integration |
| Revenue | Finish broader canonical sales/economic continuity and inherited/global freeze; ERC20 native allowance and same-leaf price carrier are source integrated with focused runtime validation active | Revenue builder; integrator |
| Metadata and permanence | Selectable/versioned STATIC and VIEW Discovery/external correspondence are source integrated. Remaining acceptance includes exact genesis correspondence, transitive renderer analysis/goldens, supplied browser observations and current capacity. CollectionViews is built with 9 passing tests; actual full activation remains | Metadata/museum builder; integrator |
| Museum | Remaining qualified authority/institutional joins, archival-export publication, actual institutional/examination joins, remaining schema/profile coverage and institutional conformance; bounded semantic authoring and condition-package tools are built | Museum builder; integrator |
| Final delivery | Latest real component joins, actual all-call Safe execution against the built inventory, fuzz/stateful campaigns, gas/capacity, complete genesis activation, final CI/source freeze and matching new testnet deployment | Integrator |

The ERC20 native-fee implementation received renewed exact-artifact approval
and is source integrated. Inherited/global primary-freeze and steward-to-living
proposals remain unapplied following earlier automatic approval-review denials.
The owner has authorized delivery; these are tooling restrictions, not a new
product decision or a claim that owner permission is missing. Their affected
features remain visibly incomplete. Other implementation continues.

## Feature tables

Each ID is stable and links to its implementation, specification and scoped
test evidence below. “Remaining” includes unbuilt behavior and the next
acceptance step, so a Built row may still require substantial verification.

- [Core and mint policy](#core-and-mint-policy)
- [Sales, auctions and distribution](#sales-auctions-and-distribution)
- [Revenue and royalties](#revenue-and-royalties)
- [Artist identity, consent and succession](#artist-identity-consent-and-succession)
- [Reveal and randomness](#reveal-and-randomness)
- [Metadata and records](#metadata-and-records)
- [Artwork finality and permanence](#artwork-finality-and-permanence)
- [Museum mapping, export and authoring](#museum-mapping-export-and-authoring)
- [Governance, continuity and operations](#governance-continuity-and-operations)
- [Developer clients and commerce operations](#developer-clients-and-commerce-operations)
- [Verification and release](#verification-and-release)

Also: [all 61 Artist operations](#artist-operation-crosswalk), [37 genesis component roles](#genesis-component-crosswalk), [museum requirements and schemas](#museum-requirement-and-schema-crosswalk), [intentional exclusions](#intentional-exclusions-and-later-work), [evidence](#feature-evidence).

These 164 rows are capabilities and delivery checks of different sizes. Row counts are **not** an effort-weighted completion percentage. Crosswalk rows below are references, not extra features.

### Core and mint policy

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [core.nft](#corenft-evidence) NFT ownership, approvals, transfers, receiver callbacks and burn | Built | Partly tested | Partial | Current Core ERC-721 lifecycle, permanent token identity and standard read interfaces. Earlier current-stack/Safe captures demonstrate principal flows. **Remaining:** Rerun on the final combined source; burn-to-mint and physical redemption are separate products. |
| [core.collections](#corecollections-evidence) Fixed, capped-open and uncapped collections; global token IDs | Built | Partly tested | Partial | Collection lifecycle, bounded supply changes, monotonic global allocation, identity retained after burn and permanent consumed gaps after incident abort. **Remaining:** Final boundary and batch-capacity acceptance on the combined candidate. |
| [core.prepared](#coreprepared-evidence) Prepare, complete and abort a mint atomically | Built | Partly tested | Partial | Manager-only preparation and settlement; entropy registration and receiver failure roll back together. Incident-abort source6e21/2feb passes14 focused actual-Core cases including capped supply and fuzzing. Later entropy hook execution and measured genesis gas calibration remain separate. **Remaining:** Recheck all latest sale, snapshot and reveal combinations. |
| [core.pointers](#corepointers-evidence) Governed modules, permanent Core boundaries and bounded external calls | Built | Partly tested | Partial | Interface/codehash admission, pointer selection, metadata/royalty hooks and gas budgets. **Remaining:** Latest dependency replacement, fallback and full gas acceptance. |
| [mint.static](#mintstatic-evidence) Static caps, counter subjects and phase-policy grace windows | Built | Partly tested | Partial | Original grace and mode-2 consent consumers are source-integrated. One-way governed phase FreezePolicy (`0ab60204`) retains same-Ledger restrictions and executor ceilings; 23 focused tests pass on exact `8f2e9157`, independently verified. Final selected Manager/fallback runtimes fit at 24,396/24,513. **Remaining:** Actual-current governance/continuity, grace/rollback and combined fuzz acceptance; advisory reads are tracked separately below. |
| [mint.reads](#mintreads-evidence) Advisory mint eligibility and counter read API | Built | Partly tested | Partial | canMint (`dc0122af`) returns explicit-executor gate eligibility and complete projected counter diagnostics. All 21 focused Manager/Ledger/Registry/gate cases pass on exact `b7378eeb`, with typed Core/Artist/governance. Original raw/derived values and proof-aware resolution/remaining reads are source-integrated (`ea92b7d4`), with fifteen reviewed cases and nine fitting selected products (Manager/fallback 24,211/24,328). All36 combined read/preview/configuration cases now pass on exact `82f41c88` after a test-only fixed-deadline correction; all90 captured production products fit. **Remaining:** Actual-current/Safe acceptance. Earlier preview passes remain tied to `b7378eeb`. |
| [mint.merkle-caps](#mintmerkle-caps-evidence) Different wallet allowances from a pinned Merkle root | Built | Tested* | Partial | Canonical inline MERKLE_STATIC proofs bind differentiated allowances and projected batch consumption. Integrated feda72d3; included in the 87-case mint cohort. **Remaining:** Actual Core/Artist/sale integration and full batch gas limits; required sale-price consumption is tracked separately under sales.merkle-prices; e7eb51f0 authenticates enabled prices and rejects undeclared nonzero values. |
| [mint.cross-scope](#mintcross-scope-evidence) Collection-wide and global shared mint counters | Built | Tested* | Partial | PHASE/COLLECTION/GLOBAL accounting, immutable first-use definitions including legacy selection, and projected duplicate checks. Integrated feda72d3; scoped actual Manager/Ledger tests pass. **Remaining:** Latest actual paid-sale/current-Core composition and capacity. |
| [mint.continuity](#mintcontinuity-evidence) Preserve mint allowances and replay state across replacement | Built | Tested* | Partial | Imports preserve counters, nullifiers, definitions and bounded exact-pair ancestry. Artist consumers accept the actual admitted descendant while preserving original signing domains and requiring fresh successor policy consent. Integrated 31a840cf/b172a016; 101 scoped cases pass. Core guard separately passes 29. **Remaining:** Execute the eight authored actual Artist/Core/delayed-governance cases, including post-replacement mint and original Safe retry; current scoped cohorts retain typed seams. |
| [mint.delegate-registry](#mintdelegate-registry-evidence) Hot-wallet minting for a vault through a pinned delegation registry | Built | Tested* | Partial | Concrete pinned v2 delegation gate delivers to the vault while the hot wallet pays; scoped actual Manager/Ledger/gate/Safe tests are included in the 87-case cohort. **Remaining:** Actual external registry and complete current-Core/Artist/Safe workflow; existing external registry responses are typed fixtures. |

### Sales, auctions and distribution

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [sales.phase-ledger](#salesphase-ledger-evidence) Current mint phases, admission and replay ledger | Built | Partly tested | Partial | Current Manager/ledger, admitted executors, gate protocol, counted prepared and single-step mint operations; not every gate implementation. **Remaining:** Latest full phase/operator/commercial combination and capacity validation; standard gate-kit row remains separate. |
| [sales.standard-gates](#salesstandard-gates-evidence) Concrete allowlist and signed-ticket gate kit | Built | Tested* | Partial | Full-payload EOA/ERC1271 ticket and proof allowlist gates, optional batch-gate capability, replay and bounded result/gas handling integrated feda72d3. **Remaining:** Complete current-Core/Artist/operator admission and latest sale joins beyond the 87 scoped mint cases. |
| [sales.merkle-prices](#salesmerkle-prices-evidence) Authenticated per-wallet prices across required sale profiles | Built; required profiles | Partly tested | Not integrated | Native immediate fixed/open-edition/free/PWYW consumption is integrated as e7eb51f0, size repair as 84145594 and callers as 837683ed. The repaired-source scoped cohort passes 76 cases; the adapter measures 24,560 bytes. Dutch/clearing consumers fbacfc7d and captured-price refund windows 08775172 are integrated, with all 26 moving-price cases passing after test-only correction 963cfce8 and 14 passing refund retry cases. The refund cohort accepts 77 distinct cases across its original and corrected runs, and refund callers pass in the root client suite. **Remaining:** Actual current graph execution; the separate interrupted ERC20 capture remains held. Required ERC20 consumers are already source integrated. Original signing domains, replay and refund ownership remain unchanged. ERC20 same-leaf carrier is source-integrated and its latest scoped run passes35/35 at `307ed239`. Native proven ceilings replace stale signed maxima in `fb6f3bf5`; genuine-floor fixtures are `75d787bc`. |
| [sales.ticket-revocation](#salesticket-revocation-evidence) Complete signed mint authorization revocation | Built | Partly tested | Partial | Original authorization IDs and complete-ticket revocation, plus full-payload historical private-sale revocation in 33ddd132 with authored direct/relayed/Safe cases. **Remaining:** Reproduce complete gate/operator/Safe workflows on the final graph; no positive gate implementation inferred. |
| [sales.native-fixed](#salesnative-fixed-evidence) Native fixed-price and open-edition sales | Built | Partly tested | Partial | Current native paid immediate consumer, original Artist/platform signatures, exact settlement and phase accounting. **Remaining:** Latest actual-current transaction/receipt/reveal/capacity acceptance. Earlier accepted current graph captures do not validate all later code. Canonical original Sales-v1 signed/public carrier is integrated; current three-case recorder admission is corrected in `3c78cc5a`. The frozen Immediate successor passes25/25 at `e52482db`; its production deployment closure and upstream Safe artifacts are verified. The earlier24/25 result is retained; latest full-current composition remains pending. |
| [sales.free-pwyw](#salesfree-pwyw-evidence) Free phases and pay-what-you-want price programs | Built | Partly tested | Partial | Declared zero-price and native chosen-amount/minimum programs; original signature/payment rules retained. **Remaining:** Final actual-current paid/free/reveal/Safe matrix; do not infer arbitrary batch airdrops from a zero-price single mint. Canonical kinds12/13 and original verifier are integrated in `65dc2b2b`; verifier11 passes and current claims8 source is corrected by `3c78cc5a`, with current runtime pending. |
| [sales.english](#salesenglish-evidence) Native English auction lifecycle | Built | Partly tested | Partial | Reserve/minimum bid/anti-snipe/first-bid start, old exits, escrowed native bids and delayed settlement. **Remaining:** Latest full actual-Artist/Core authority, exits and transaction-capacity acceptance. ERC20 bidding is expressly non-genesis. |
| [sales.curated](#salescurated-evidence) Chosen curated-work auction and content selection | Built | Partly tested | Partial | Existing curated auction plus native fixed PUBLIC/COMMIT_REVEAL and buyer-bound private carriers are integrated 161cda75; 55 distinct current-cohort cases pass on original 5605d019 plus test-only 301ccda9. Later refund correction b25b3d16 has separate 35-case coverage. Curated clients 2b93a187 pass root 375 package tests. Native primary offers with selected work are now source-integrated as 364ec9e2; exact source review is clear and 70 distinct complementary cases pass, with explicit typed Artist/entropy/governance boundaries. **Remaining:** Final current/Safe/cold acceptance and explicit supported-profile reconciliation. Moving-price selection is a future extension; unsupported free/Merkle/ERC20 selected combinations are not automatically separate genesis blockers. |
| [sales.dutch](#salesdutch-evidence) Native descending-price Dutch sales | Built | Partly tested | Partial | Linear/stepped native schedule and signed maximum/current paid price. Canonical original Sales-v1 native Dutch (`41212e86`) and ERC20 Dutch (`0f199287`) are source-built; the recorded ERC20 capture now passes26/26 with193 production products fitting (`00686b79`). Native claim/PWYW and canonical Dutch41 pass at `9bdabdf2` with declared Artist/entropy/governance doubles. **Remaining:** latest full-current/Safe paid/reveal/royalty composition and collector gas; unsupported broader profiles are not inferred. |
| [sales.clearing](#salesclearing-evidence) Uniform-clearing Dutch and buyer rebates | Built | Partly tested | Partial | Native clearing book, price fixing, sparse/compressed purchase records, permanent rebates and supplements. **Remaining:** Latest complete conservation/clock/rights/escape runtime. Retained consumer gas measurements exceed 500,000; old 8,755,856 trace was warm-up preceded, not all-cold/current. |
| [sales.refund-window](#salesrefund-window-evidence) Native refund-window sales and unconditional escape | Built | Partly tested | Partial | Original held deposits, finalization/refund/escape clocks and own-account credits. **Remaining:** Final graph settlement/delegation/export/surplus and timing/callback invariant execution; native-only scope explicit. |
| [sales.private-offer](#salesprivate-offer-evidence) Private sales and atomic native/ERC20 offers | Built | Partly tested | Partial | Custody private/offer purchases, royalty-itemized secondary receipts and buyer-bound primary private selections are built. Canonical native primary mint OFFER_SALE (tokenId=0, optionally selected) is source-integrated in 364ec9e2/9945d612 with original dual-digest replay/revocation and independently reviewed source. Seventy distinct complementary cases pass, including actual Core/Manager/Ledger and 2-of-2 Safe, with typed Artist/entropy/governance. Nine current native-offer economics campaign cases are source-integrated (`6187c0e0`) with independently reviewed conservation/nonce/rollback oracles; native execution is pending. **Remaining:** Final full-graph/current/Safe acceptance. ERC20 primary-offer shared/carrier source 42ab5d2d/2e0fca1a now preserves separate payer intent and direct-to-buyer minting under zero native fees; independent source review is clear, 71 shared and 42 carrier cases now pass across independently verified original/retry source unions after test-only f90f103f/a14d9e35. Clients 0d2b62ea are integrated with all 447 root package tests passing; full latest-graph acceptance remains. Nonzero native-fee support remains held separately. |
| [sales.inventory-consignment](#salesinventory-consignment-evidence) Secondary inventory and declared consigned resale | Built | Tests written | Not integrated | Immutable sorted original-owner inventory; per-token sale/replay/royalty, genuine previously delivered token resale profile and proceeds claims. **Remaining:** Independent 017172a0 source/oracle review clear; seven authored cases require combined native execution. Prior delivery cannot be inferred merely from MINTED. |
| [sales.prepared-custody](#salesprepared-custody-evidence) Original prepared acquisition and same-NFT custody sale | Built | Partly tested | Partial | Snapshot created at original acquisition; original config/origin/acquisition grants retained and later payment transfers the same NFT. **Remaining:** Final whole current graph plus new rights activations and royalty/reveal invariants; earlier source cohorts are not latest runtime. |
| [sales.token-rights](#salestoken-rights-evidence) Known-token PROFILE/TEMPLATE and default rights activation | Built | Tests written | Not integrated | Pre-bid append-only scoped activation, exact original auction/acquisition IDs and shared consumed/replay; old bid route excluded after activation. **Remaining:** ba0db85d seven actual Artist/Core/Safe source cases integrated as f0e651ef; native execution pending. Do not list token overrides/default templates as absent. |
| [sales.platform-rights](#salesplatform-rights-evidence) PLATFORM_WORKS template/custody/known-token rights | Built | Tests written | Not integrated | Explicit declaration-bound families 8–13, actual original poster, uncontested/correction admission and current actual-token policy; no fake Artist0 consent. **Remaining:** Independently reviewed source; latest native and real declaration/current transaction joining still required. Typed families 8–13 signing, registration/activation, inspection, bid/settlement and Safe CALL recipes are implemented; their full live composition is still required. |
| [sales.erc20-immediate](#saleserc20-immediate-evidence) ERC20 immediate sales, PaymentIntent and permits | Built | Partly tested | Partial | Universal original ERC20 payer/executor separation, exact token delta, EIP-2612/Permit2/Safe authorization and settlement; not every native sale-family variant. **Remaining:** Final actual-current ERC20 wallet/asset/full-Safe matrix; the approved reveal-fee route below passes its focused 93-case native campaign. Do not use old ERC20 fixed-adapter guide's narrower permit boundary as current Universal status. |
| [sales.erc20-reveal](#saleserc20-reveal-evidence) Executor-funded native reveal allowance for ERC20 immediate sales | Built; bounded immediate profile | Partly tested | Partial | Approved implementation preserves token-only signing, executor pull refunds and original storage. Real-floor fixture repair `7b78943d` passes nine scoped unit cases; the repaired 93-case run passes with independent source/artifact readback at `5df9808e`. **Remaining:** Final combined current-stack/Safe acceptance after subsequent features. No new deployment. |
| [sales.burn-mint](#salesburn-mint-evidence) Current Stream-token burn-to-mint consumer | In progress | Partly tested | Partial | Free, prepared and native-paid paths are integrated as 9acd68f7; free-entry maximum reveal allowance/caller pull credits as 8b991c53. Root verifies final-source 49-case burn and later 31-distinct-case credit cohorts. Dedicated zero-native-fee ERC20 paid source c717a3e1 is independently reviewed; 21 focused gate and 18 current-contract tests pass with independently verified source/artifact bindings; four production products fit. Clients0466f9d3 pass502 root tests. **Remaining:** Actual combined graph, authored governed-surplus/Safe retry execution and finality/payment composition. Nonzero native-fee support remains held separately. Later native price repairs are excluded from the earlier burn captures. Seven actual-current source/target policy and exact Safe retry cases are integrated as `0b2c1d6f`, runtime pending. |
| [sales.burn-redeem](#salesburn-redeem-evidence) Current burn-to-redeem / physical redemption consumer | Built | Partly tested | Partial | Canonical same-transaction Stream burn, original redemption/events and append-only fulfillment history.17 focused tests pass, including a 256-input property and real threshold Safe. **Remaining:** Actual current Core/module/governance/operator workflow, cold gas and full acceptance. Focused Core identity/governance/registry boundaries are typed substitutes; burn-to-mint remains separate.  Actual-current 12-case source `452d0f17` adds real admission, separate threshold Safes, signed retry and Core burn-block rollback; runtime execution is pending. |
| [sales.airdrop](#salesairdrop-evidence) Current operator batch distribution product | Built | Tested* | Partial | Ordered distribution and account-directed claims are source integrated. Actual Manager-resolved PHASE supply scope fix1a6522bc passes27 focused cases including256 fuzz inputs; legacy definition interpretation and recipient scopes are preserved. Explicit DISABLED/INSTANT policies are supported by the shared source. **Remaining:** Actual current governance/Artist/Manager/terminal-policy execution, genesis activation and cold capacity. Recipient MERKLE_STATIC publication-bound distribution is integrated as `a2d38f50` with18 new cases; its bounded compile timed out before execution. |
| [sales.delegated-authority](#salesdelegated-authority-evidence) Native delegated offers, claims and refunds | Built | Tests written | Not integrated | Exact immutable/live NFTDelegation witness; principal remains payer/owner for offers; delegated claim/refund destination fixed to credited account; own exits remain independent. **Remaining:** Independent source reviews efd5336d/d3d293ec/77222cc clear. Later13 refund +6 offer/Safe authored cases await combined native; no generic delegated spending authority. |
| [sales.surplus](#salessurplus-evidence) Native six-host surplus recovery | Built | Tests written | Not integrated | Only native balance above all liabilities, including forced ETH; exact current Executor action and dynamic emergency recipient; no ERC20/NFT sweep or owed-credit diversion. **Remaining:** 9db00712 nine authored cases and fixed-worker source review clear; full paid private/English liabilities and final callback/capacity execution remain. |
| [sales.owed-export](#salesowed-export-evidence) Complete historical sale-credit keys and canonical export | Built | Tests written | Not integrated | Producer-owned six-host historical key enumeration reads original ledgers, preserves zeroed keys/retired producers and liabilities; canonical native credit leaf/tree transcript. **Remaining:** 1dcbb865 source/index/client reviews clear;8 authored current recipes pending native. The existing typed client already enumerates the complete pinned registry, retired producers and zeroed keys, reconciles liabilities, and replays its closed transcript. Complete current-graph export and canonical StateExport publication remain to be demonstrated; a second exporter is not missing implementation. |

### Revenue and royalties

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [revenue.asset-policy](#revenueasset-policy-evidence) Approved ERC20 assets, permit policies and non-stranding deprecated exits | Built | Partly tested | Partial | Governed standard-token admission and permanent exit grace; asset and permit policy registry source exists. **Remaining:** Final supported asset-family/permit and deprecated-exit acceptance through actual settlement and split wallets. |
| [revenue.factory-wallets](#revenuefactory-wallets-evidence) Canonical split profiles, deterministic wallets and pool | Built | Partly tested | Partial | Canonical account/label shares, deterministic registered/deployed profiles, common wallet identity and curator-pool primitive. Version4 genuine pinned clones are integrated5e1b3902;84 scoped wallet/authorization/clone tests pass and all seven captured production products fit. Historical RC1 identities remain unchanged. **Remaining:** Final all-entry/account asset/deployment/rounding/capacity matrix and actual pool admission; does not include runtime/factory incident lifecycle. |
| [revenue.claims](#revenueclaims-evidence) Split-wallet pull releases and claim aggregation | Built | Partly tested | Partial | Account-directed permissionless releases, original signed redirection/revocation, per-asset accounting and fixed claim router. **Remaining:** Final real-wallet/Safe/ERC20 policy changes, hostile callbacks and full conservation envelope; no generic estate legal entitlement inference. Eight actual-current revenue/Safe claim, revocation, atomic/partial rollback recipes are integrated as `4cb8fef4`; runtime pending, official native versus passive ERC20 receipts remain distinct. |
| [revenue.live-royalties](#revenuelive-royalties-evidence) Live royalty precedence and explicit token/collection/default overrides | Built | Partly tested | Partial | Actual token > collection > default, configured disabled distinct from absent, maximum cap and original canonical policy hashes. **Remaining:** Final current-token/live-to-snapshot/frozen/callback combination; old narrow fixture results are not all modes. |
| [revenue.snapshots](#revenuesnapshots-evidence) Original-mint royalty snapshots including configured-zero/default | Built | Partly tested | Partial | Collection-specific source-0 consent wrapper, positive/zero frozen token disclosure and original acquisition-time snapshots. **Remaining:** ec06 five actual Artist/Core dynamic/snapshot/same-NFT authored cases are integrated and await native. Prior complementary Artist/Core cohorts passed; not absent product. |
| [revenue.primary-templates](#revenueprimary-templates-evidence) Static, poster and paid-collaborator primary materialization | Built | Partly tested | Partial | Exact source identity, original poster, current Artist/collaborator payouts, per-row coverage and concrete profile/escrow materialization; max64 entries/8 dynamic sources. **Remaining:** dynamic148 accepted98 cases plus one256 property on its exact earlier source; five newer actual-Core/actual-Artist joined cases authored, latest gas/native/capacity pending. |
| [revenue.artist-economics](#revenueartist-economics-evidence) Artist-approved low-take and exact scoped economics | Built | Partly tested | Partial | Original Safe op15 profile/template approval, exact collection/token/default coordinates, low-take and current binding/payout/collaborator requirements. **Remaining:** Execute final fully joined scoped consent/owner installation/settlement tests; Artist consent does not grant owner/global mutation authority. |
| [revenue.exact-mutations](#revenueexact-mutations-evidence) Exact-key TEMPLATE CLEAR and freeze | Built | Partly tested | Partial | Original exact-key TEMPLATE clear/freeze selectors and independent client assignment reconstruction integrated 571371e0. Current client package passes 220 tests including retained exact-mutation cases. **Remaining:** Complete actual contract/Safe native execution; inherited/global freeze is a separate feature. |
| [revenue.inherited-freeze](#revenueinherited-freeze-evidence) Inherited/global primary freeze and descendant mutability | Not started | Not tested | Not integrated | Distinct INHERITED/global freeze modes with required mutable lower-scope accounting; cannot be represented by the existing exact frozen bit. **Remaining:** Specific local implementation remains blocked awaiting exact approval. Do not apply denied source artifacts or call exact-key freeze full conformance. |
| [revenue.resolver-continuity](#revenueresolver-continuity-evidence) Frozen economic continuity on Resolver replacement | In progress | Partly tested | Partial | Protected Royalty inventory/import, original hash origins and canonical governance are integrated 43da6f0e/fc6c5a32; fixture c80b68ca passes 11 unit/Safe cases. Core guard c010f9ec passes seven cases again within the latest 29-case Core cohort. **Remaining:** Execute actual-current import/cutover/continued use and remaining separately required freeze profiles. Proposed primary graph replacement is not an adopted requirement or completed authority feature. |
| [revenue.artist-lineage](#revenueartist-lineage-evidence) Retained revenue consumer follows authenticated Artist successor | Built | Partly tested | Partial | Original immutable Resolver origin and approval state retained; current facade requires authenticated one-predecessor completed seven-owner lineage/current suite and runtime pins. **Remaining:** Root native3 passed all12 ResolverSuccessor cases including8new+4inherited; other joined compact-source fixture paths failed setup and were repaired separately. Final combined successor/current paths remain pending. |
| [revenue.escrow-flush](#revenueescrow-flush-evidence) Captured owed revenue escrow and ordinary flush | Built | Partly tested | Partial | Exact native/ERC20 credit key and captured factory/runtime, normal/verified-wallet flush, producer admission and liability conservation. **Remaining:** Final full native/ERC20 callback/gas/conservation graph; no incident routing or successor factory capability in this base primitive. |
| [revenue.escrow-recovery](#revenueescrow-recovery-evidence) Incident-revoked escrow recovery and successor routing | Built | Tested* | Partial | Common runtime/factory lifecycle, pinned binding, exact original recovery manifest, affected-account consent, terminal-delay and atomic execution are integrated.17/17 focused tests pass after correcting only the expected-revert Safe helper. **Remaining:** The two authored actual-governance/Safe cases, full paid-sale-to-recovery join and operational notice delivery acceptance; typed governance in the focused cohort does not prove those paths. |

### Artist identity, consent and succession

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [ART01](#art01-evidence) Fixed Artist module, seven owners, governed parameters and deployment | Built | Partly tested | Partial | Fixed facade/Coordinator/seven owners/Archive and original domain/storage pins. Reviewed admission and explicit creation carriers are source integrated (`fed9fc01`); Owner7 and original ABI/layout checks pass. **Remaining:** Joined Attribution capacity after recovery/personhood, actual deployment, cold gas and complete manifest/window acceptance. Other held artifacts remain distinct. |
| [ART02](#art02-evidence) Identity registration, documents, revision and personhood/deployment prerequisites | Built | Partly tested | Partial | Original identity and op24-selected proof/summary/currentness production (`8972da42`) plus actual conservation consumer (`abbf0cb7`) are source integrated. Reader16 passes on `fbff83a3`; provider19 and original28 producer cases remain separately qualified. RESOLVED summary, WAIVER record, registration/operative identity and original imported registry stay distinct. **Remaining:** Actual producer/consumer/Safe and paid-current acceptance, recovered personhood/C2PA composition. |
| [ART03](#art03-evidence) Two-sided binding proposal, acceptance, refusal and withdrawal | Built | Partly tested | Partial | Actual primary acceptance; claimed/refused/withdrawn lifecycle and generation/hash pinning, with explicit acceptance prerequisites. **Remaining:** Post-acceptance dispute/revocation/repudiation and withdrawal are built under ART06 but native-pending; migration of multiple generations is ART34. |
| [ART04](#art04-evidence) Collaborator identity and complete collaborator acceptance | Built | Tests written | Not integrated | Original collaborator identity, roles/hash arrays and separate acceptance are implemented under the admitted PRIMARY_ONLY policy. **Remaining:** Multi-party ALL_COLLABORATORS/THRESHOLD/COLLABORATOR_QUORUM policy creation and use are missing ART41; actual-current dynamic commerce execution and collaborator migration remain pending. |
| [ART05](#art05-evidence) Permissionless artist-bound attribution claims | Built | Tests written | Not integrated | Append-only permissionless claims and combined Artist/Platform claim reads; filing alone does not adjudicate attribution. **Remaining:** Latest native acceptance; the separate dispute/repudiation recipes and withdrawal are tracked in ART06. |
| [ART06](#art06-evidence) Attribution dispute, counterstatement, resolution, revocation, repudiation and withdrawal | Built | Tests written | Not integrated | Operations 44–50 and additive61 are source-integrated; withdrawal 57da88e9 preserves the original opener/signing payload and appends the canonical outcome. Independent source review is clear; ten new withdrawal cases join the earlier 30 authored cases. **Remaining:** Exact withdrawal source `13118faa` still measures Attribution 29,556 and Identity deployment 25,911 bytes; other 17 selected products fit. Its ten runtime cases were not executed past the size gate. Complete size repair, native execution, delegated/Safe acceptance and history hydration remain. |
| [ART07](#art07-evidence) Live attribution display and exact attestation/deployment reads | Built | Tests written | Not integrated | Five-value O(1) attestation status, exact historical signing class, raw binding and sanction reads, deployment reference and combined claim count; Metadata renderer owns projection. **Remaining:** Full live renderer/current-Core matrix and C2PA reconciliation ART38 remain; unknown historical class never defaults to Artist. |
| [ART08](#art08-evidence) Typed EOA/Safe signatures, nonce/replay and authorization revocation | Built | Partly tested | Partial | Original typed domains, bounded ERC1271, retained full signatures, per-identity/acceptance/delegate nonce guards and explicit nonce/digest revocation. **Remaining:** All wallet classes/full negative matrix and carried complex-history guards need remaining profiles; historical passing Safe paths do not validate every signature family. |
| [ART09](#art09-evidence) Delegation grant, revoke and authenticated delegated writes | Built | Tests written | Not integrated | Delegation grant/revoke, attestation, economics, royalty-freeze, intent and CAP_DISPUTE 16 are source-integrated. ART42 now source-integrates mode2 policy/sale consent. **Remaining:** Full latest delegated Safe execution and exact final-source acceptance. |
| [ART10](#art10-evidence) Mint policy modes, ratification and optional sale-parameter consent | Built | Partly tested | Partial | ARTIST_SIGNED_POLICY exact per-phase consent, optional saleConsentScope and ratification are implemented; PLATFORM_WORKS is covered separately in ART11. ART42 now source-integrates ARTIST_DELEGATED creation and policy/sale consumption; native acceptance remains pending. NONE is a sale-consent scope and snapshots are royalty modes, not Artist consent modes; the initial table mixed these concepts. |
| [ART11](#art11-evidence) Platform Works declaration, contest and corrective Artist generation | Built | Tests written | Not integrated | Canonical covered declaration; permissionless Platform claim; governed contest/correction; real two-sided corrected binding and saved scope finality selection. Canonical five-word commitment document does not prove narrative content. **Remaining:** Latest actual-current zero-Artist commerce, contested/corrected permutations and Platform history hydration. |
| [ART12](#art12-evidence) Artist sanction, scoped finality and confirmation | Built | Partly tested | Partial | Collection and supported scoped sanction candidates/records/review evidence, original current binding/capability, finality confirmation; steward collection minted/burn-before-appointment guard. **Remaining:** Full latest real Core/Finality/Executor ceremony and all profile combinations; scoped steward sanctions are intentionally excluded. Earlier supported collection ceremony is included under finality.collection; it does not accept these later profiles. |
| [ART13](#art13-evidence) Finality recovery approval and Artist unavailability finding | Built | Partly tested | Not integrated | Original finality recovery approval/scoped reader and actual unavailability lifecycle with activity invalidation; entropy has an explicit separate target/intent profile. **Remaining:** Native4 completed with 39 failures overall, including the unavailability test-name/harness defect and five entropy-recovery join failures. Live external-provider/current-governance join and mixed finality-finding migration remain. |
| [ART14](#art14-evidence) State-bound kinds1–10, delegated/steward attestations and detached publication | Built | Tests written | Not integrated | Actual subject-owner hashes for generic1–6; detached7/8 publication, deployment9/personhood10, exact persisted class and signatures; eligible delegated/steward authority supported. **Remaining:** Complete native/current-owner subject and wallet matrix; C2PA credential enumeration/reconciliation is ART38. |
| [ART15](#art15-evidence) Payout designation and historical split-right continuity | Built | Partly tested | Partial | Canonical payout heads/history/provisional associations and current beneficiary facts; rotation/recovery does not rewrite balances or historical split recipients. **Remaining:** Complex transitioned payout hydration; financial custody/claims remain revenue-owned. |
| [ART16](#art16-evidence) Economics consent for live/default/token PROFILE and TEMPLATE assignments | Built | Partly tested | Partial | Original op15 exact scope0/1/2 approvals; configured/default/disabled royalty snapshots; static/dynamic template poster/collaborator dependencies; current and prospective SET/CLEAR/FREEZE consent transports. **Remaining:** Newest actual Artist/Core commerce joins and every mode/permutation native; inherited/global-primary-freeze denied implementation remains separate and unapplied. |
| [ART17](#art17-evidence) Original content consent/freeze and explicit entropy consent host | Built | Partly tested | Partial | Original metadata op17/op21 and actual one-use host mutation; additive host-aware op17 entropy family with exact selected Coordinator/runtime/intent. Original content freeze does not authorize new global-freeze semantics. **Remaining:** Five original EntropyRecoveryJoin failures were traced to a mock/canonical RoleRegistry mismatch; current test-only fix2c39c316 is integrated. Seven corrected runtime cases remain pending. Complete metadata-family/host migration and latest cold gas acceptance remain. |
| [ART18](#art18-evidence) Guardian history, authority rotation, standing and compromise dismissal | Built | Partly tested | Partial | Two-sided op29, guardian acceleration/veto, executed32, compromise33, prior-standing51, canonical dismissal58 and abandoned/mature provisional cohorts; complete lifetime history. **Remaining:** Full latest rotation/cause/closure combinations and current graph replay after later fixed-worker changes. |
| [ART19](#art19-evidence) Successor/directive records and governed estate activation | Built | Partly tested | Partial | Original designation/directive and legal-document commitments; covered request38, cancellation39, ordinary/accelerated40 and original capability/guardian transition. **Remaining:** Full latest actual estate commerce and all history/permutation acceptance. Closed op40 followed by rotations is now source-integrated under ART25; its native acceptance remains pending. |
| [ART20](#art20-evidence) Elected identity recovery, lifetime veto and adjudicated guardian supersession | Built | Partly tested | Not integrated | Original34/35 with actual registered action/election, Safe acceptance, three receipts and replay; supported living, estate, prior living ancestry, rotated/closed estate and immediate/closed repeated recovery. Arbiter versus Appeal exclusions are distinct. **Remaining:** Unsupported transition combinations are explicit ART25–27; broad actual-current Executor and capacity remain pending. |
| [ART21](#art21-evidence) Dormancy lifecycle, artist grant and later steward capability grant | Built | Tests written | Not integrated | 19 living artist sanction grant; 41 notice, all authenticated activity cancellation42, second governed completion43; original class3/4 appointment and later exact TERMINAL_FREEZE59 permits only economics/sanction bits within directives. **Remaining:** Latest native/current Executor ceremony and complete revoked/provisional profiles. This does not implement steward-origin elected recovery. |
| [ART22](#art22-evidence) First recovery after designated dormancy and same-head dismissals | Built | Tests written | Not integrated | Original op43 class3 origin; original/later kind1 dismissals and kind2 standing attempts; earlier living parent, immutable plan, full lifetime prefix, exact action/Archive retry. **Remaining:** Native4 includes prior standing suite, not later rotated branches. First designated-origin guardian supersession is now source-integrated under ART27; native acceptance remains pending. |
| [ART23](#art23-evidence) Designated dormancy followed by executed class3 rotations and first recovery | Built | Tests written | Not integrated | Designated operation43 followed by one or more executed class3 rotations and first elected recovery. Source 49f22c34 is merged as 43b1d56e; independent production review is clear. **Remaining:** Nine authored cases; native execution, size and latest complete graph acceptance pending. |
| [ART24](#art24-evidence) Closed original dormancy followed by executed rotation and first recovery | Built | Tests written | Not integrated | The original appointed-principal closure is authenticated separately from terminal/current authority. Source 9ea144c8 is merged as 5ff709dc; bounded production and integrator test-source review are clear. **Remaining:** Five new authored cases, native execution and changed-product size acceptance pending. |
| [ART25](#art25-evidence) Remaining executed-rotation recovery combinations | Built; bounded profiles | Tests written | Not integrated | Source-integrated `7a274c04`: latest35 followed by one or more32 rotations, and original closed40 followed by rotations; original/terminal closures remain distinct. Complete admitted history uses original writer/epoch invariants without a caller-selected prefix. Independent source review and ABI checks pass; 27 cases are authored. **Remaining:** Native execution, sizes and real intervening40/43 composition; broader dormancy/recovery histories are tracked in ART27. |
| [ART26](#art26-evidence) Adjudicated steward-origin identity recovery | Not started | Not tested | Not integrated | Explicit adjudicated class4-origin recovery to proved living authority or non-superseded rightful designated class3 successor. **Remaining:** Current elected recovery admits classes1/3, not class4 source. Steward-to-living proposal was blocked by automatic approval review and remains unapplied; no default class relabeling. |
| [ART27](#art27-evidence) Dormancy-origin supersession and expanded adjudication histories | In progress | Tests written | Not integrated | First designated43 guardian supersession (`91e223f5`) uses the actual current vesting cutoff and original APPEAL/ARBITER/Archive rules; 16 cases are authored and source review is clear. Repeated43-to35 recovery is now source-integrated (`0c5de0d9`), with14 further authored cases preserving the original43 capability/epoch. Living35-to43 origin proof (`ed4d5572`) adds 17 source-reviewed actual-owner cases. Active-notice dismissal (`9ff19e55`,14 cases) and cancelled-notice histories (`ff60c308`,15 cases) are source-integrated and reviewed. Complete repeated-living history (`22e90a3b`) adds 18 reviewed cases; current-cause aborted-pending recovery (`d5e3fbcb`) adds seven reviewed cases. First/repeated living/class-3/current-veto and cancelled-Estate predecessor joins (`6544ff47`/`1647c5c0`) add eighteen independently reviewed cases. Evidence-bound adjudication V2 (`5310fc7b`) now builds complete C1/C2 class1/class3 ancestry, earliest declared vesting, genuine provisional/NONE lanes and explicit completed-empty guardian selection; 44 cases are authored and independent production review is clear. Current living-notice recovery (`055f2396`) adds ten reviewed/type-checked cases. Joined three-host capacity is repaired (`6d3e55df`). Typed six-family V3 rewinds (`e4ccdba4`) are now source-integrated, with55 authored cases and independent joined-host review. **Remaining:** New joined sizing, native/current-stack acceptance and separate class4 ART26. |
| [ART28](#art28-evidence) Archive, canonical record preimages, payload catalog and event reconstruction | Built | Partly tested | Not integrated | Original Archive atomicity; permanent retained payloads, recordPreimageBytes/count/at; exact32/35/40/43 preimages; original19/41–43/59 and execution-context event companions; native receipts include op31/33 Causes. **Remaining:** Complete all-family independent event fold/public recomputation client and imported advanced records remain incomplete; bytes never retained are not reconstructed. |
| [ART29](#art29-evidence) History lanes, original55–57 and narrow Core successor admission | Built | Partly tested | Not integrated | Canonical ordered Artist/collection lanes, committed predecessor root, exact tip proofs, completed seal and immutable read-through prefix; replacement-only Core pin seam. Lane membership alone grants no authority. **Remaining:** Native3 passed scoped actual two-registry tests with typed Core; real-current cutover plus all imported-authority consumer profiles still required. |
| [ART30](#art30-evidence) Seven-owner complete checkpoint and nonce/replay export | Built | Tested* | Not integrated | Current owner headers, enumerated original replay surfaces/origins, typed nonce prefixes and exact dependency checkpoints; rolling roots are not reconstructed from current cells alone. **Remaining:** Passed four exact native3 cases at b60ae515; current later source not independently rerun. Advanced authority exports/imports remain separate. |
| [ART31](#art31-evidence) Operation60 living baseline, payout and direct economics hydration | Built | Tested* | Not integrated | Single original living Artist/accepted generation1 collection, full original policy/revocation guards, optional linear payout and original direct economics dependencies; atomic seven-owner readiness and fresh successor-domain Safe writes. **Remaining:** Scoped native3 passes do not prove actual-current Core migration. No collaborator/transitioned/repeated/oversize import. All guard/dependency completeness is required. |
| [ART32](#art32-evidence) Operation60 readiness and detached publication hydration/consumers | Built | Partly tested | Not integrated | Original52/17/24 direct class 1 kinds1–6/9/10 plus explicit 7/8 full publication evidence, catalog/signatures/latest heads; successor deployment needs fresh approval; same Metadata consumed map remains authoritative. **Remaining:** Native4 readiness6/publication7/join3 fail on missing guard preimages, invalid URI or Safe-wrapped join inputs. Artist lead repairs the source-backed fixture defects; rerun required. The earlier23-case typed-provider proof is a separate scope. Original op52 ratification-history codec is source-integrated as `d8873564`, with ten authored cases; actual A/B/C runtime acceptance remains pending. |
| [ART33](#art33-evidence) Operation60 complete entropy finding history hydration | Built | Tests written | Not integrated | Original ten-word findings plus exact entropy target/intent/admission/runtime, original-domain origin, complete ordered23 records/latest/activity and both replay cells; current selected intent/epoch still required. **Remaining:** fa688 integrated7209675b; nine source-reviewed tests /787-source ABI,15 distinct selected products fit across recorded captures; native4 predates this feature. Only default timing and complete single-collection living profiles. |
| [ART34](#art34-evidence) Migration of multiple identities, collaborators and corrected binding generations | In progress | Partly tested | Not integrated | Original-living generation-1 PRIMARY_ONLY multiple-Artist/multiple-collection hydration is source-integrated (`8cc47857`) with ten reviewed actual-owner/Safe cases. Complete per-Artist guards and seven-owner/Archive atomicity are preserved. The delegation successor (`48754d47`) repairs those new size overruns at its exact source; all eighteen selected products fit. Combined multiple-Artist delegation (`588341d2`) adds fourteen reviewed actual-owner/Safe recipes with complete global journal and grant-use accounting. Complete original living record combinations (`75ad082d`) now include exhaustive economics/attestation witnesses and atomic seven-owner imports, with twenty independently reviewed authored cases. Joined11-product capacity repair (`6d3e55df`) fits at its exact563-source capture. Pending PRIMARY_ONLY binding generations (2–128) with refusal/withdrawal history and final acceptance are now source-integrated (`05e3f402`); 19 scoped stage cases and eight 256-input fuzz properties pass. **Remaining:** Actual complete migration, mixed record-family combinations, collaborator graphs, other corrected/rebound histories, attribution disputes and Platform correction histories. Generation2–128 plus complete original op24 history is source-integrated as `c686a29f`; eight selected products fit and ten new cases are authored. Complete pending-generation grants/mode2 and delegated consent composition is integrated as `4ff6e414`; ten new cases are authored and12 selected products fit. Governed post-revocation ingress and complete accepted-generation imports remain in build. Platform continuation (`08365ec5`) and delegated-generation validator routing (`43987159`) are source-integrated; corrected-history imports and actual composed execution remain.  Accepted-generation/correction histories are source-integrated as `7e358470`, with eight actual-owner/Safe cases authored and selected size checks; remaining signed/cross-era histories and composed runtime stay open. Complete History phase5 `da61ee5f` combines nonempty family histories, exact signed Safe retry and genuine repeated op60; one new/four strengthened cases remain unexecuted. Class3-rich/recovery-payout phase6 `b7819e27a` plus correction `50bd67116` adds three independently reviewed, ABI-checked cases; all remain unexecuted. |
| [ART35](#art35-evidence) Migration of delegated, rotated, estate, dormancy and recovered authority | In progress | Partly tested | Partial | Singleton and bounded multiple-generation, consent, attestation, unbound Platform, dispute and PRIMARY_ONLY collaborator profiles are source integrated. Current collaborator workers have twelve scoped passes plus256 fuzz inputs; dispute workers have twelve scoped passes. Binding capacity repair9671 preserves ABI/storage and passes seven focused cases plus256 fuzz inputs. **Remaining:** Complete legal mixed histories and changed-Artist chronology, aggregate12/13, existing class4/op59 migration, actual operation60 across current owners/Safe, complete capacity and gas acceptance. Original52 is source integrated asfc492/c30 with26 authored, unexecuted cases; CompleteHistory chronology source12083/d489 is integrated without activation. Historical source-specific evidence is retained below. |
| [ART36](#art36-evidence) Migration of sanctions, sale/freeze/recovery approval and mixed finding histories | In progress | Partly tested | Not integrated | Original 17/20/21 history and royalty witnesses, plus sanction12/confirmation13 history (`8e15d977`) and complete joined HISTORY_CONTENT (`51d8ed8f`, 13 new independently reviewed cases), are source integrated; content and cross-owner consent/attestation workers fit selected captures. Prepared extraction `dc3d3e9b` passes 19 scoped framing/facts cases. **Remaining:** Actual operation60, full linked capacity, broader findings/sanctions/timing and mixed histories. |
| [ART37](#art37-evidence) Repeated successor migration and larger complete hydration capacity | In progress | Partly tested | Not integrated | Bounded recovered provenance/guards and fixed preparation/read stages are source integrated. Real Owner Metadata cold recipe passes unchanged 400k/150k limits at `d88ee108`; the corrected actual-Owner fixture passes 46 retained cases at `33baa284`. **Remaining:** Actual migration execution, broader histories, larger transport and whole linked deployment/transaction capacity. Transport/export/continuations `e2713593` fit22 selected products; full Import `e1fa284c` fits nine, with six real Records/Payload rollback component tests passing. Complete op60 runtime remains pending. |
| [ART38](#art38-evidence) C2PA credential/key-history authorship reconciliation | Built; bounded profile | Partly tested | Not integrated | Original op24 credential history and typed reconciliation (`142a3cdb`) retain unresolved standing conflicts (`22095475`) until the exact covered original op46 disposition. Root47 related offline passes; scoped worker native13 plus256 fuzz inputs pass on retained sources. Current composition/read plans are source-integrated (`a86febaa`). Museum Standing V2 (`3f0967f`) passes 27 consumer cases and preserves original historical acknowledgement guards. **Remaining:** Authenticated history capture, actual Artist/Renderer/current-graph execution, complete STATIC admission and existing Artist host size repair. Live provenance can stale original full-output hashes; their semantics are unchanged. |
| [ART39](#art39-evidence) Complete Artist signing/recomputation client and measured ceremony rehearsal | In progress | Partly tested | Partial | Original principal and identity/delegation callers, delegated14/16 (`b99b3781`) and mint-grace workflow (`9ac63a11`) and delegated economics15/royalty-freeze20 (`6b71507e`) are source-integrated. Mode-2 grace (`e5ec5fae`) and original delegated attestation24 (`122d2288`) add exact ABI56 support. The current full client package passes1,233 cases, generation/build/strict types, with source-specific fixture checks recorded above. Collection-policy/INSTANT clients are integrated with separate source fixtures; op35 V2 adjudication/notice (`3113e16c`) and V3 rewind (`68fb843a`) clients are integrated with separate frozen profiles. **Remaining:** Other original operation families and measured actual Safe ceremonies; simulated RPC is not native execution. Recovered MULTIPLE_BASE client `df8e84ca` and schema-only optimization `13a84574` are integrated with exact99e/ABI167 profile. Root build/types and cache/mutation cases pass; all20named MULTIPLE_BASE mocked workflows pass at `a2580872`. MULTIPLE_CONSENTS client `9a1a3d29` is source integrated with112 distinct producer pure/oracle/mocked-workflow passes and independent review. MULTIPLE_ATTESTATIONS (`4fd80175`), original guardian/rotation (`708a97ae`), collaborator (`91ae4002`) and attribution (`45828ad0`) callers are source integrated with scoped root validation recorded under client.commerce. Multiple-generation callers (`d2b9c72c`/`33912f72`) are integrated with build/types and58 distinct focused passes across source-pinned runs; actual all-call Safe remains. |
| [ART40](#art40-evidence) Full Artist current-graph conformance, limits and operational acceptance | In progress | Partly tested | Partial | Earlier native4 completed 167 passed /39 failed on its frozen source. Fixture and harness repairs are now integrated, with 21 Python harness checks passing. **Remaining:** Rerun affected native cases on the selected combined source after capacity repair; cold gas, full fuzz/stateful limits and actual-governance/testnet acceptance. |
| [ART41](#art41-evidence) Multi-party collaborator approval policies | In progress | Not tested | Not integrated | Immutable policy creation/read changes exist only in isolated incomplete builder work. Automatic approval review rejected the co-signed producer/transport/gate mutation; the exact 21-path inert patch is source-reviewed and its specific owner question is pending. Eight authored tests remain uncompiled. Integrated BindingLifecycle still admits only PRIMARY_ONLY with zero threshold and no overrides. **Remaining:** Complete atomic policy consumption across affected consent/authority families and real multi-party Safe/quorum tests. |
| [ART42](#art42-evidence) Delegated mint-policy and sale-consent mode | Built | Tests written | Not integrated | Mode2 admission and delegated policy/sale-consent producers are source-integrated (`6d333842`), with original op14/16 domains/records, capability masks and durable exact consents. Independent source review and combined ABI pass; 16 Artist and four paid current-Safe cases are authored. **Remaining:** Native joins, complete clients and sizing, including the Estate deployment helper at24,765 bytes. |

### Reveal and randomness

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [entropy.policy](#entropypolicy-evidence) Explicit entropy policy, freeze and non-random token states | Built | Partly tested | Partial | Original explicit configuration (`e7b509ca`), direct reads (`4010ec2a`), commerce (`128c8378`) and terminal metadata/STATIC (`86074453`) are integrated. Commerce28/two256-input properties and consumer28 pass with recorded typed boundaries. Actual current terminal10 is authored/reviewed/type-checked. **Remaining:** Its native execution, complete V2 output/finality and exact successor import/relay. |
| [entropy.instant](#entropyinstant-evidence) LOW_SECURITY synchronous provider requests after mint | Built; producer and commerce | Partly tested | Partial | Integrated `4010ec2a` preserves delayed request timing, bounded STATIC provider call, zero fee/full caller credit and original domains without mint-commitment influence;47 scoped producer cases pass. Commerce `128c8378` and clients `be336ace` are integrated with scoped passing tests. **Remaining:** Actual-current/Safe eight-case runtime (`5af68676`/`6ad73f77` is source-integrated, reviewed and type-checked), INSTANT rendering/finality, successor relay and matching release evidence. |
| [entropy.registration](#entropyregistration-evidence) Token and sale/collection-scope randomness registration | Built | Partly tested | Partial | Immutable request subjects/inputs, token-versus-scope identity and locked collection configuration. Principal current mint flow has older runtime evidence. **Remaining:** Execute latest Artist consent and all supported sale-scope joins. |
| [entropy.fulfillment](#entropyfulfillment-evidence) Asynchronous reveal, callback delivery and retry without reroll | Built | Partly tested | Partial | Pinned provider requests and seed provenance; failed delivery retains committed entropy and permits retry. **Remaining:** Latest complete provider/Core/Metadata rollback and cold callback acceptance. |
| [entropy.providers](#entropyproviders-evidence) VRF and ARRNG provider adapters | Built | Partly tested | Partial | Both current adapters and focused tests exist; ARRNG actual governance/Safe recipe is implemented. **Remaining:** Verify the final selected real upstream provider configuration and funded testnet callbacks; local/synthetic upstream evidence alone is insufficient. |
| [entropy.lifecycle](#entropylifecycle-evidence) Admit, suspend, incident-revoke and restore providers | Built | Tested* | Partial | Focused capture at 3481e8fd passes 41 native cases and three 256-input fuzz properties. Separate actual Safe lifecycle plan passes 12 cases. **Remaining:** Repeat affected lifecycle cases in the latest complete graph; freeze deployment-specific provider policy. |
| [entropy.funding](#entropyfunding-evidence) Reveal fees, quotations, sponsors and pull refunds | Built | Partly tested | Partial | Coordinator-hosted reveal-fee escrow and provider quote validation with native sale funding; dedicated focused suite included in the 100-case entropy capture. **Remaining:** Latest fee/callback/escrow conservation acceptance. ERC20 executor allowance is separately absent. |
| [entropy.incidents](#entropyincidents-evidence) Timeouts, service-level findings and precommitted fresh recovery | Built | Tested* | Partial | Frozen incident/recovery policies, epochs and collection/token fresh recovery. Recorded focused run passes 100 cases across ten suites, including eight 256-input properties. **Remaining:** Complete latest actual Artist/governance/upstream-provider transaction composition. |
| [entropy.artist-join](#entropyartist-join-evidence) Real Artist consent and unavailability findings in reveal recovery | Built | Partly tested | Partial | Actual Artist/Safe/Archive tests and operation23 finding source exist. Canonical role-registry/role grant and test-name fixes are integrated 5104173c/2c39c316. **Remaining:** Execute the repaired recovery/unavailability joins, then complete actual mint/Executor/provider composition and finding hydration acceptance. |
| [entropy.fallback-continuity](#entropyfallback-continuity-evidence) Coordinator replacement, retained old reads and distinct safe-mode fallback | In progress | Partly tested | Partial | Frozen V2 successor permission, covered pending-request admission, original host provenance and configured ordinary backup helper are source-integratedcf57de5e with independent review. Eleven continuity and ten prior subject-identity cases pass on recorded sources. Actual-Core launch500000 registration/receiver rollback and low-budget atomic rejection pass 3/3 at6fb0d7c3. Complete policy import/original-provider relay (`44edac4e`/`dffb8daa`) passes210 scoped cases; actual Core/Executor/Manifest/Coordinator and2-of-3Safe LEGACY cutover (`65cf7db5` test correction) passes16 cases on producer18c42131, including whole-batch rollback/retry. **Remaining:** Actual Artist-consented EXPLICIT/paid-mint/full-render joins, final source cold gas floors and complete genesis activation. Existing32-step export measurements use a typed fixture and do not establish production Coordinator gas. |

### Metadata and records

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [metadata.renderer-routing](#metadatarenderer-routing-evidence) Independently selectable, versioned token and collection renderers | In progress | Partly tested | Partial | Renderer/Registry, STATIC routing/configuration, ScopeMembership, raw Artist facts and complete selection checkpoint are source-integrated, including 01bc7081/099d8ba7. Fixed formatter/Metadata repairs and frozen-ONCHAIN full-output checkpoints 40ae52f8 are integrated. A low-parent-gas currentness error is repaired with two passing actual-Renderer regressions. The complete output-hash manifest/schema/coverage join is integrated as 006a16bc with nine scoped passes. Exact bundle ABI repair df440372 has four new passing actual-contract regressions. Pure encoding optimization 9753b496 passes 11 focused parity/fuzz cases. Pure byte scans 849bfd68/3fb128d6 add 13 focused composition and 15 pure passes; named 24 KB and six-row scopes fit transaction gas, eight rows refuse. Bounded STATIC analyzer (`d823d82c`) adds31 integrated controls but does not close the full current renderer GAS/copy paths. **Remaining:** Full current cold renderer/checkpoint and Router size acceptance, transitive opcode/read-set analysis, exact goldens/genesis correspondence, supplied browser observations and combined capacity. Selectable/versioned STATIC, output-retention and publication-authority joins are present in source; prior failed manual encoder evidence remains historical. |
| [MUSEUM-01](#museum-01-evidence) Canonical Core identity and metadata boundaries | Built | Partly tested | Integrated* | Current Core subjects, full record preimages and semantic tooling preserve work/token/file and protocol authority boundaries. This is the implemented boundary, not completion of all dependent museum features. **Remaining:** Whole adopted source-family and full-finality acceptance remain; source-preserving adapters do not grant new mint/finality authority. |
| [MUSEUM-02](#museum-02-evidence) Immutable schema and interpretation document registry | Built | Tested* | Integrated* | Registered exact-name/version documents, ordered bounded chunks, full original bytes and canonicalization identity; actual delayed Executor and Safe capture uses these contracts. **Remaining:** Complete required genesis catalog registration and every maximum-size operational envelope remain separate. |
| [MUSEUM-03](#museum-03-evidence) Current collection record writers and source history | Built | Partly tested | Integrated* | MetadataV1 generic class-scoped writers, full payload/receipt/history, independent author heads and one-use Artist publication; sealed complete successor consumption preserves the original host consumed map. Full 24,576-byte chunked payload capacity is integrated as a7c984bf with 23 focused passes, unchanged original ABI/storage and small-record semantics; five actual Artist cases await native. **Remaining:** Generic byte admission is not typed meaning for every named record. The newest genuine post-cutover join remains in root native cohort, distinct from earlier demonstrated generic/RIGHTS writes. |
| [MUSEUM-04](#museum-04-evidence) Permanent independent account record lane and ordered capture | Built | Tested* | Integrated* | Actual direct/relayed account receipt/signature/schema/payload capture at a pinned block, original per-lane heads and authenticated receipt/header ordering, renderer firewall preserved. **Remaining:** Historical account authorship does not prove named person/institution identity or qualified reviewer authority; other source lanes require their own adapters. |
| [MUSEUM-05](#museum-05-evidence) Token owner record host and historical evidence adapter | Built | Partly tested | Partial | Original direct/relayed token-owner records, exact 14-word signature envelope, original owner and nonce/chain/signature evidence. Offline adapter currently admits selected embedded LOAN/VALUATION/CONDITION_REPORT wire evidence. **Remaining:** Actual current minted-token museum capture is authored, not executed; full remaining owner-family semantic adapters are absent. Source host support does not supply institutional instruments. |
| [MUSEUM-06](#museum-06-evidence) Preservation record host and typed archival producers | Built | Partly tested | Partial | Full-byte PreservationRecordsV1 is integrated09fd273d with original authority, six explicit preservation families, immutable history and complete ordered 24,576-byte payloads. Nine focused cases pass, including fuzz and threshold Safe; all 35 captured production products fit. **Remaining:** Actual full current graph, all typed consumers and complete dossier/finality integration. Legacy host/adapter remain distinct. |
| [MUSEUM-07](#museum-07-evidence) Independent collection views host | Built | Tested* | Partial | Immutable full manifest/revision history, complete65,536-byte payload with bounded reads, schema binding and current DISPLAY authority/selection are integrated.9/9 tests pass with actual MetadataV1, SchemaRegistry/store and threshold Safe. **Remaining:** Actual current Core/Executor/module composition, renderer adoption and full genesis activation; those focused boundaries are typed. Canonical adopted VIEW/STATIC source `b256a3c1` passes21 scoped cases and two256-input fuzz properties; tagged VIEWV2 is source-integrated (`9939ef3c`) with16 selected fitting products and a30-pass/two-test-fixture-failure predecessor; successor and complete finality remain pending. |
| [MUSEUM-08](#museum-08-evidence) Artist, general and notarized attestation museum authority mapping | In progress | Partly tested | Partial | General/native Artist/notarized producers and explicit recorded-source/dossier adapters are integrated9677f5bf. Root passes 86 affected checks and 15 focused native cases pass with exact compiler/artifact evidence. Institutional and estate claims do not become verified identity; historical Artist evidence retains original authority. General 24,576-byte successor2e0c3443 and explicit V2 replay pass64 affected root checks; its own frozen native cohort passes25 with23,179-byte host runtime. Full graph/gas acceptance remains pending. **Remaining:** Separate native statement capacity, genuine current-graph captures, complete reviewer/source mappings and whole dossier conformance. |
| [MUSEUM-09](#museum-09-evidence) Typed work description and format catalog | Built | Partly tested | Partial | Closed bounded WORK_DESCRIPTION JSON interpretation, original shared Artist/curator authority, registered format catalog and fixed selection. Pure work-to-LIDO profile exists; full general actual-record semantic composition remains partial. **Remaining:** Broader faithful work/physical/interactive source coverage and actual current joined exporter acceptance; raw schema presence is not complete semantic mapping. |
| [MUSEUM-10](#museum-10-evidence) Typed Artist intent, waiver and interview | Built | Partly tested | Partial | Full typed intent/waiver/interview and format interpretation, selected original authority/binding/record and interview checks exist in fixed consumers; estate statements remain distinct. Original intent/waiver/interview dossier `fcf5af68` retains all semantic fields, instruments, participants, transcripts, references and four Artist/estate history lanes; 25 new/shared offline tests pass. V2 dossier `e278ddcf` adds original byte/Archive correspondence, typed semantic resources and complete retained-package reconstruction; 33 focused cases pass at root. **Remaining:** Actual RPC capture, complete canonical dossier composition and opaque unsupported encodings; supplied-evidence consistency does not establish participant identity, consent, institutional acceptance or media delivery. |
| [MUSEUM-11](#museum-11-evidence) Typed RIGHTS interpretation, selection and museum source | Built | Tested* | Integrated* | Exact full RIGHTS JSON, class/family/subject/registered-definition selection and immutable historical receipt capture; separate six-use-class PREMIS/semantic rights output keeps independent links distinct from grants. **Remaining:** Full initialized Artist/Metadata-to-museum positive capture and all later-current selection cases remain separate. Test-fixture legal statements never prove real legal ownership/permission. |
| [MUSEUM-12](#museum-12-evidence) Steward designation and recovery response/notice records | Built | Partly tested | Partial | Typed steward/response schemas and original owner notice/action consumers exist, including bounded incremental endpoint publication and original 72-hour clock. Publisher delivery claims remain claims. Source-preserving semantic/notice evidence and closed offline dossier adapters62dc2990 pass93 affected root tests with independent source review. **Remaining:** Positive actual capture, full dossier composition and complete operational delivery evidence; do not conflate protocol publication with receipt by an institution. |
| [MUSEUM-13](#museum-13-evidence) Remaining named owner/institutional record semantic adapters | In progress | Partly tested | Not integrated | Source-bound ACCESSION/TITLE_BINDING, DEACCESSION and first-claim REDEMPTION_CLAIM adapters, retained institutional instruments and bounded exact Transfer receipt capture/replay are integrated. Root22 institutional/Transfer cases pass. Accession/title V5 export `e031ce6f` adds11-source packet derivation, with39 builder cases and five offline CLI cases passing; legal/institutional authority is not inferred. **Remaining:** Actual current token records, authenticated institutional/title evidence and full conformance. Synthetic Transfer controls do not establish legal title, physical custody or a receipt-trie proof. |
| [MUSEUM-14](#museum-14-evidence) Full condition report and conservation-treatment mapping | In progress | Partly tested | Partial | Typed condition/conservation, original owner/frozen independent-source admission, outbound/return comparison and exact-source offline dossier replay package are integrated, including 64cac28f. Five package cases pass within the root 19-case package/authoring cohort. Native canonical append-only source catalog (`2758868f`) is source-integrated; canonical current/source replay (`569be86d`) passes 36 root source/wrapper/compatibility cases. All matching original lanes remain complete; positive fixtures are synthetic and examination joins remain required. **Remaining:** Actual examination-time/fixity/render/recovery joins and positive current independent capture; opaque historic same-name schemas remain unsupported. |
| [MUSEUM-15](#museum-15-evidence) Native reference render and render-critical archival inventory | Built | Tested* | Partial | Finite actual original native onchain COLLECTION plus STATIC/BYTE_EXACT reference publication, executable archive/environment/captures, source inventory and dual-family coverage. Exact raw payload versus artifact/list commitments stay distinct. **Remaining:** PERCEPTUAL_TOLERANCE and CURATED_EQUIVALENCE finality acceptance evidence, supported script/environment closure, noncollection families and additional actual correspondence methods remain; all-program/all-size gas and institutional acceptance absent. DYNAMIC renderer implementation is a later excluded extension. |
| [MUSEUM-16](#museum-16-evidence) Script/media manifests, large bundles and full snapshot export | Built | Partly tested | Partial | Typed current manifests, logical32x24576 script chunks, bounded SSTORE2 append/finalize/full-read and frozen source reconstruction; explicit chunked snapshot embedded JSON and offline export preserve original inline domains. **Remaining:** Full actual upper-bound executable/frozen-route joined acceptance and additional renderer/dependency profiles remain; compact references never count as complete executable export. |
| [MUSEUM-17](#museum-17-evidence) Complete object dossier, acquisition packet and canonical citation adapter | In progress | Partly tested | Partial | Versioned source-bound packages and typed derivatives retain original records and citations. Scoped collection dossier a0d71d2 now joins actual selected records, required media bytes and offline BagIt/OCFL replay, with 44 new/legacy tests passing. Source-driven examination gathering and native citation qualifiers (`79339af6`) add47 root passes, exact original-byte extraction and a19-item missing-evidence index. Full token dossier and canonical acquisition packet remain incomplete. Explicit-version repository export/import (`bee91ae5`) adds eleven root passes with full-history semantic replay and atomic exact-byte restore. Current default citation (`84c69bc3`) has ten isolated codec passes and separate current admission recipes. Mint/entropy composition (`1216379d`) adds41 root passes; selected RIGHTS item7 (`5975396a`) adds31. Public RIGHTS/ownership (`b5ec1031`) and mint/entropy/RC1 recipe (`7d20df15`) have56/39 root passes in overlapping cohorts. Acquisition/accession/native ownership join (`f541a56e`) adds38 root passes, with explicit synthetic provenance. PacketV2 (`4012efce`) passes53 root cases. Selected conservation capture and additive packetV3 (`a288d58a`) pass100 root new/compatibility cases, retaining all19 gaps and original schema bytes; this is synthetic/offline evidence. The actual RC1 capture attempt failed on pruned historical logs. **Remaining:** Successful actual public-chain captures, complete packet source/attestation/identity/provenance/finality items and their dossier relationships; externally supplied descriptors do not establish completeness. Complete supplied V5 packet `bb38b542` passes31 root cases; additive native attribution/sanction `b2f1459c` passes51, preserving original confirmation versus latest sanction and incomplete authoritative source coverage. Original scoped STATIC/V7 (`729bfa4c`) adds98 builder passes and four offline replay/export cases. Complete authority and archival preimages remain explicitly incomplete; policyV2/VIEW continue separately. Canonical V10 acquisition composition and V3 dossier consumers `4784061d` add 72 focused root passes for supplied preservation/work/recovery/observation joins; all 19 packet/49 dossier requirements remain explicit, with actual capture and complete archival evidence pending. Preserved tool/runtime archives and V10/V3 replay `186dcc3f` add37 independent focused passes and four retained vectors reproduced twice; native release authority, actual full capture and institutional acceptance remain unproven. |

### Artwork finality and permanence

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [finality.collection](#finalitycollection-evidence) Freeze a collection artwork bundle with Artist sanction | Built | Partly tested | Partial | Registry, fixed native evidence provider, Artist sanction and finalization ceremony. An earlier actual graph demonstrates one supported collection ceremony. **Remaining:** Repeat on latest source with independent exported evidence and full gas limits. Collection evidence is not proof of other scope types. |
| [finality.facts](#finalityfacts-evidence) Reconstruct content, description, conservation and entropy facts | Built | Partly tested | Partial | Typed source readers, input manifests, image review, provenance and immutable provider/discovery bindings. **Remaining:** Latest complete native source-set and off-chain reconstruction acceptance. |
| [finality.membership](#finalitymembership-evidence) Publish and validate named token-scope membership | Built | Partly tested | Partial | Canonical membership publication, current-Core inventory and capacity tests exist. **Remaining:** Accept final membership producers and connect each supported scope to the full ceremony. |
| [finality.all-scopes](#finalityall-scopes-evidence) Token, release, season and view finality ceremonies | In progress | Partly tested | Not integrated | TOKEN/RELEASE/SEASON snapshots and BYTE_EXACT references now join complete scoped inventory/archive, V2 provider/STATIC and profile Discovery source (`94a987a8`).85 scoped cases are authored; selected combined provider24,574 fits with only2bytes margin. **Remaining:** Actual complete scoped ceremony, joined runtime/capacity, required VIEW adopted-source and genuine prospective pre-sale reference. Collection evidence does not accept these profiles. Actual scoped full-policy factory `5ad8163c` is integrated, with12 authored cases. Full-policy reference/inventory/bundle/factory (`8dfea94f`) and tagged VIEWV2 (`9939ef3c`) are source-integrated; provider/discovery `52969b88` is source-integrated with27 authored cases; tagged VIEW33 passes at `9bdabdf2`. Acyclic per-plan COLLECTION construction is source-integrated as `b752f5bd`; bounded checkpoint serving passes9 (`5ae72668`). Complete publication/finality/runtime acceptance remains; original scoped V1 evidence is separate. Complete VIEW output checkpoints pass12 and ordered manifest parts/index pass13 plus256 fuzz on their exact source. Full-policy actual ceremony (`8002ef1c`) exposes the sanction/live-render circularity and transaction-capacity gap; these are open acceptance failures, not fixture waivers.  Standard root24 and VIEW output46 pass on their separately pinned sources; reviewed reference and once-bound provider source are integrated through `842eb31e`. Complete VIEW inventory/finality, Discovery and exact external correspondence are source integrated; genuine prospective reference observations, current capacity and actual full ceremony acceptance remain. See the latest checkpoint for exact boundaries. |
| [finality.recovery](#finalityrecovery-evidence) Recover frozen artwork state and switch serving components | Built | Partly tested | Partial | Recovery commitments, route validation, retired lifecycles and executor-only ownership primitives exist. **Remaining:** Accept every supported original scope through actual replacement, continuity/reconstruction and retry. |
| [finality.hosts](#finalityhosts-evidence) Retain verifiable content on original or replacement serving hosts | Built | Partly tested | Partial | Core/finality adapters, current source inventory, on-chain content checkpoints and serving-host checks. **Remaining:** Final independent byte reconstruction and migration against all supported artwork profiles. |

### Museum mapping, export and authoring

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [MUSEUM-18](#museum-18-evidence) Pinned standards/profile schemas and bounded dependency closure | In progress | Partly tested | Partial | Three exact semantic schema candidates, finite interpreted subset and complete local context/schema/vocabulary dependencies; immutable profile versions and acyclic bounded document preparation exist. Bounded account profile was actually registered in captures. **Remaining:** Register and validate the complete adopted mapping/authority/place/schema closure; current finite account/format profiles do not establish every required full-v1 schema. Optional live Linked Art API is neither required nor claimed. |
| [MUSEUM-19](#museum-19-evidence) Stable entity identity, references and declaration selection | In progress | Partly tested | Partial | Stable explicit IRIs, work/token/file/physical/person distinctions, package resolution and incompatible selected declaration rejection; exact same-kind repeated exhibition/loan/valuation declarations preserve multiple provenance sources. **Remaining:** General authenticated declaration continuation/correction/merge/split lineage and all source-family token/work bindings remain. Same text, wallet or namespace cannot provide continuity. |
| [MUSEUM-20](#museum-20-evidence) Field-level crosswalk, semantic validation and full coverage accounting | In progress | Partly tested | Partial | Closed schema inventory, exact scalar/array/null/absence accounting, pinned class/domain/range, v2 abstract/visual/linguistic/E73 distinctions and explicit unsupported sidecars. Full requirements are larger than this implemented subset. Exact-source field inventory, four-format ledger and native correspondence `269dd02d` add 42 focused root passes; native WORK-to-LIDO `7e5209e5` adds 41 broader batch passes. **Remaining:** All named source families, physical realizations, complete dimensions/media and geographic patterns, exact reverse mapping and named vectors for every required crosswalk entry remain. Native four-format package `fdb36e3f` adds 49 focused root passes across Linked Art/PREMIS/IIIF/LIDO correspondence, preserving the complete original field/family denominator and unselected records. Native media/PREMIS package `a35a05d34` adds 46 focused root passes, including authenticated painting and events/agents/rights. These retained controls are not institutional acceptance. |
| [MUSEUM-21](#museum-21-evidence) Attributed assertions, review and conflict selection | In progress | Partly tested | Integrated* | Immutable assertion/revision/profile/field selectors, exact earlier review targets, source-selected conflict withholding, provenance indexes and explicit same-account SELF review. Actual independent-account recorded profile works. **Remaining:** General independent institutional reviewer eligibility and cross-authority actual source policy, not just SELF/account lanes, remain. No arbitrary reviewer label/list grants authority. Qualified account profile and exact per-source/per-review policy are now integrated `1a899e47`/`19f0ed0b`; same-account review requires explicit SELF admission, rejects and conflicts withhold selected claims. The 89-case combined root suite passes. General/Artist adapters and actual registered selection acceptance remain open. |
| [MUSEUM-22](#museum-22-evidence) External authority matching and archived reconciliation | In progress | Partly tested | Partial | fef4b2f6 adds retained authority snapshots/reconciliation; 8ba023dc adds versioned Type/declaration/continuation support, preserves original schema hashes, and replays an actual local Safe declaration/alignment/later SELF review. Root 131 authority/profile/regression tests pass. **Remaining:** Qualified external/artist/curator/institution lanes, full conformance and public/latest-graph acceptance. The positive RDF/JSON remains explicitly synthetic; separately retained Getty SPARQL bytes do not prove publisher-backed equivalence. |
| [MUSEUM-23](#museum-23-evidence) Historical, uncertain and role-specific place semantics | In progress | Partly tested | Not integrated | Nine-role draft projection retains historic/uncertainty/precision controls. Recorded exhibition binding (`0a5104e6`) replays the exact original owner location commitment and earlier Place declaration, retaining separate TGN review authority; 18 distinct producer and three root regressions pass on synthetic originals. **Remaining:** Other recorded place-role joins, actual source/reviewer capture and complete conformance. Unverified draft matches cannot emit equivalence. |
| [MUSEUM-24](#museum-24-evidence) File roles, observed ingest and physical-event relationships | In progress | Partly tested | Partial | Distinct carriers, original/derived resources and named activities; explicit local preservation observations and evidence links. Planned/cancelled/unknown activities are withheld from performed graph output. Native VIEW reference/file-role semantics `679936f0` add ten occurrence-specific roles, original-history/authority retention and complete source-based package replay;30 root tests pass. Eight integrated positive same-object ZIP/PNG receipt cases also pass (`f26e0d43`). Explicit recorded physical-production statements (`6b75f19a`) add17 integrated passes, complete original source replay and embedded Production output for supported completed statements. Acquisition/custody mapping (`697bda0c`) adds six root passes for supported recorded statements. **Remaining:** Complete physical custody/accession/title coverage, institutional source joins, described/received/verified relations and actual website safety-scan parity. Positive fixtures remain synthetic. |
| [MUSEUM-25](#museum-25-evidence) Deterministic recorded export and database-free offline replay | In progress | Tested* | Integrated* | Bounded deterministic package partitions, exact original source/transcript/schema bytes, pinned block/read scope, hashes, dependency resolution, whole-package recomputation, public-disclosure refusal and immutable derivatives work for named finite profiles. Compact immutable V3 export 23477832 now has actual class-6 Safe ARCHIVE publication and offline replay; all 27 root tests and independent artifact review pass. Scoped collection dossier a0d71d2 adds selected-media and offline package integration, with 44 tests passing. Actual-token capture/replay 1db47ad9 adds 62 passing tests and a fresh paid-token/15 Safe-record/source-block PNG join. Object tooling 2503b218 adds a concrete native-inventory reader and honest partial assembly, with 60 root tests passing; its complete inventory vector is synthetic. Catalog/history readers 61b87646 add complete owner/independent lanes and Core ownership history, with 111 root compatibility tests passing; genuine captures and assembler joins remain separate. **Remaining:** Complete source-family coverage, canonical token object-dossier/full media inventory, subsequent-export lineage, latest graph and full institutional conformance; original V1/V2 stay immutable. Retained complete VIEW BagIt/OCFL transport `a8562dc5` now passes 31 root new/shared offline cases; actual capture and full conformance remain separate. Canonical semantic export `a5d23fb8`/`ec5b9b8a` preserves original subjects and alternatives, with34 root tests. Script/dependency source and offline replay `f9123670`/`3b8bf3c0` add58 root cases. Actual chain/institutional acceptance remains separate. Unified V4 dossier (`4494df9b`) and fixed-slot script/dependency joins (`f4a084ea`) are source integrated; the latter has twenty-one root integration checks at `3e7fc352`. Original nineteen-group/forty-nine-assessment bytes remain intact; complete family/media/institutional coverage stays open. Five fixed evidence-slot joins0bca2121 add38 root passes; media/render/preservation evidence stays source-bound and original assessments remain unchanged. Native four-format package `fdb36e3f` replays the original V4 source and retained dependencies offline; all49 new focused root cases pass. Synthetic source and partial semantic coverage remain explicit. |
| [MUSEUM-26](#museum-26-evidence) Linked Art and CRM projection | Built | Tested* | Integrated* | Pinned offline JSON-LD expansion and finite Linked Art/CRM entity projection with extension sidecars, complete input/output correspondence for supported profiles. **Remaining:** Complete adopted crosswalk and all real record-family source adapters remain. Archival URNs and data-model validity do not claim optional HTTP API conformance. |
| [MUSEUM-27](#museum-27-evidence) PREMIS file/fixity facts and recorded source adapter | Built | Tested* | Integrated* | Original pinned PREMIS3 schema, exact file IDs/size/digest/format and correspondence from selected registered source facts. Missing fields yield explicit unsupported diagnostics. Direct native-catalog retained-file projection (`a69c377e`) adds exact supplied-byte measurements and complete replay; 53 root cases pass. Complete authority-field accounting (`53aae1b0`) adds 62 root new/compatibility/docs passes, retaining 17 bound/eight local/ten unresolved example fields. **Remaining:** General source/authority coverage and actual institutional capture; local measurements do not invent historical fixity events. `a35a05d34` adds native registered preservation-event/agent/rights correspondence with 46 combined root passes; no historical fixity event is inferred from a local measurement. |
| [MUSEUM-28](#museum-28-evidence) IIIF Presentation3 archival manifest | Built | Tested* | Integrated* | Same-source four-media presentation, original numeric/URI semantics, complete local context lock and exact correspondence to file/semantic facts. **Remaining:** Full additional artwork/presentation profiles and external viewer/availability behavior remain. Hash-addressed media needs a compatible resolver; validation does not claim that service exists. Native WORK adapter `fdb36e3f` adds exact descriptive manifests and representable extent Canvases; painting lists remain empty without authenticated artwork/media correspondence. `a35a05d34` now joins actual retained VIEW media references to native painting annotations; unsupported or unmatched references retain explicit diagnostics. Forty-six combined root cases pass on synthetic/offline records. |
| [MUSEUM-29](#museum-29-evidence) LIDO1.1 work/media/publisher export | Built | Tested* | Integrated* | Pinned XSD closure, work/creation/creator/media and explicit selected publisher per contributing account. Account identity never becomes a named legal body automatically. **Remaining:** Complete expanded loan/valuation/condition/authority semantics across LIDO remain; derivatives retain old LIDO bytes rather than claiming monetary/event mappings absent from its current profile. |
| [MUSEUM-30](#museum-30-evidence) Performed fixity and generic preservation event/report/agent semantics | Built | Tested* | Integrated* | Typed actual performed-check/report/agent joins, separate local observation comparison; twelve generic event kinds and six reported outcomes with noncompleted dispositions preserved. Event time/tool/identity remain original claims unless separately established. **Remaining:** Full operational periodic fixity program, all actual captured event/outcome combinations and generalized trustworthy external execution/scanner evidence remain; FIXITY_CHECK has its original narrower outcome rules. |
| [MUSEUM-31](#museum-31-evidence) Preservation objects, rights and activity graph derivatives | Built | Tested* | Partial | Canonical PreservationObjectRef with explicit properties/relations, rights source qualification and complete recorded event-to-Activity correspondence; software/opaque agents stay sidecars. **Remaining:** Full actual-source activity-graph capture across remaining object/event/rights combinations and whole acquisition/physical relationships remain. Existing object/right captures and synthetic graph controls are distinct. |
| [MUSEUM-32](#museum-32-evidence) Typed exhibition semantic dossier | Built | Tested* | Not integrated | Exact class5 independent exhibition source, typed institutions/venues/dates/status and all original document references. Exact repeated same-kind declarations merge provenance; conflicting/cross-kind declarations reject. The owner-EXHIBITION lane, source-bound projection and full offline package/BagIt/OCFL path are now integrated (`5d832333`), with nineteen new root tests passing and source/oracle review clear. **Remaining:** Positive actual-chain exhibition record capture and practitioner acceptance; synthetic receipt controls do not establish these. No loan/custody/display permission is inferred. |
| [MUSEUM-33](#museum-33-evidence) Typed owner loan semantic dossier | Built | Tested* | Not integrated | Exact original owner receipt and full LOAN shape, opaque condition and valuation references, distinct party roles, completed-only Activity plus complete evidence sidecars and literal replay. **Remaining:** Actual owner publication/capture remains authored in 57ac; typed condition core and legal/custody/countersignature evidence require independent adapters, not names/timestamps. All ten owner-family semantic interpretations and additive V2 export are integrated as `965608f3`, with36 focused root passes. Historical authority, opaque future records and redemption receipt order are retained; actual capture and legal/institutional evidence remain separate. |
| [MUSEUM-34](#museum-34-evidence) Typed valuation and ordered loan-insurance evidence join | Built | Tested* | Not integrated | Exact insurance/appraisal/book basis, amount/currency/date/instrument/confidentiality/countersignatures; complete bounded valuation lane and canonical receipt/transaction/log order support explicit referenced-unsuperseded status. **Remaining:** Actual current owner capture pending; legal operativeness, professional assent and hidden instrument contents are not inferred. Unsupported old schema/order gives precise unavailable status. |
| [MUSEUM-35](#museum-35-evidence) BagIt, OCFL and offline fetch hydration | Built | Tested* | Partial | Exact public payload/tag fixity, immutable OCFL version lineage and versioned local-byte fulfillment of complete fetch set. Original nested package and supplied descriptor provenance retained. Scoped collection dossier a0d71d2 adds authenticated source/media reconstruction and every-version verification, with 44 new/legacy tests passing. Actual-token 1db47ad9 rebuilds BagIt/OCFL from 27 exact originals within its 62 passing tests. Explicit-version repository export/import (`bee91ae5`) adds eleven root passes with full-history semantic replay and atomic exact-byte restore. **Remaining:** Full token render inventory, all authoritative dossier inputs, genesis profile registration, actual distribution/availability and institutional ingest remain separate. No automated untrusted network fetching. Retained complete VIEW BagIt/OCFL transport `a8562dc5` now passes 31 root new/shared offline cases; actual capture and full conformance remain separate. |
| [MUSEUM-36](#museum-36-evidence) Actual-current OwnerRecords museum publication/capture recipe | Built | Partly tested | Not integrated | Actual-current OwnerRecords publication/capture recipe and offline loan/valuation composition are merged as a0f6535a. Ten Python tests and deterministic fixtures pass on integration; three Solidity cases are ABI-checked and source-reviewed. **Remaining:** Native execution and actual positive OwnerRecords RPC capture. Synthetic-owner offline composition is not genuine on-chain capture. |
| [MUSEUM-37](#museum-37-evidence) Semantic authoring, draft confirmation and later-edit workflow | In progress | Tested* | Partial | Source-bound CLI/package workflow63d18fae preserves exact original statements, nullable unsupplied prompts, durable IDs, explicit versioned confirmation/review and append-only later edits. All52 root cases pass; reopening reconstructs every revision from retained OwnerRecordSource or supported recorded-account originals. NativeAttribution adapter `269dd02d` and General/V4 history `7e5209e5` are integrated with 42 and 41 focused root passes respectively (broader batch counts). **Remaining:** Complete adopted source-family coverage and actual authority/publication acceptance. Draft declarations do not establish authenticated identity or publication authority. |
| [MUSEUM-38](#museum-38-evidence) Complete media/history corpus and institutional conformance | In progress | Partly tested | Not integrated | Named eight-scenario fixture ledger and numerous finite positive/negative exporter tests exist. Complete adopted gate closure, current-source whole corpus and named institutional/practitioner acceptance are not present. **Remaining:** Complete photograph/two prints, written+AV interview, interactive, historical geography, conflicting records, independent participants and offline revision with exact source/profile hashes; obtain required repository/practitioner evidence. Synthetic passes do not count as institutional integration. |
| [MUSEUM-39](#museum-39-evidence) Additional preservation/render/finality profiles and dossier state | In progress | Partly tested | Partial | Mode producers/consumers 2351111e plus correction 5e6c6140 are integrated: signed condition references, enum-complete additive ABI_V2 and fixed codecs independently reviewed. Root passes 81 preservation controls and an actual restored metric runtime after 2b333b74; synthetic context/PNG remain explicit. Solidity 12 authored. Original V1/BYTE_EXACT unchanged. **Remaining:** Native execution after the exact final-source compiler failure, joined browser/metric supplement publication and finality acceptance, full curated composition, institution-signer profile, other required scopes and fixity/recovery-linked dossier state. DYNAMIC renderer implementation is excluded from genesis/v1. |
| [MUSEUM-40](#museum-40-evidence) Complete genesis museum schema catalog and worked examples | Built; source catalog | Tested* | Partial | All29 exact canonical names and examples are source-integrated (`8b3f01f8`); original19 schema bytes unchanged. Root89 tests, six profile checks and complete catalog regeneration/check pass. Independent review verifies51 documents/78 ordered chunks. **Remaining:** Actual complete genesis registration, authoritative inputs, full family semantics and institutional conformance; the plan is prospective. The complete51-document current-registry consumer `6be384af` is integrated with23 independently passing synthetic tests; actual capture/registration remains pending. |

### Governance, continuity and operations

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [governance.roles](#governanceroles-evidence) Role registry, Safe authority and bootstrap handover | Built | Partly tested | Partial | Actual role registry, bootstrap and governance Executor; Safe owners do not inherit the Safe contract's role. **Remaining:** Latest complete product ownership transfer and all-role acceptance. |
| [governance.actions](#governanceactions-evidence) Delayed governance actions, cancellation and append-only action catalog | Built | Partly tested | Partial | Authenticated scheduling/execution and typed action policy; native commerce stage has a recorded 25-case acceptance with typed Artist/entropy boundaries. **Remaining:** Complete latest catalog, all target actions and graph-wide recovery composition. |
| [governance.parameters](#governanceparameters-evidence) Governed gas limits and time parameters | Built | Partly tested | Partial | Parameter hosts/stores, identifiers, delayed updates and raise-only restrictions on applicable budgets. **Remaining:** Reconcile every final product selector/parameter and measure complete ceremonies. |
| [governance.manifest](#governancemanifest-evidence) Public system manifest and dependency inventory | Built | Partly tested | Partial | Manifest commitment and current graph discovery foundation. **Remaining:** Bind the complete 37-role genesis deployment, approved equivalents and distinct fallback instances. |
| [governance.state-export](#governancestate-export-evidence) Publish, challenge and supersede reconstructable state exports | Built | Tests written | Partial | Current export publisher, role/epoch binding and pointer-drift/reorg rejection tests exist. **Remaining:** Run latest native export cases and reconstruct a fully activated final graph from independent records. |
| [governance.recovery](#governancerecovery-evidence) Governed recovery and component cutover | In progress | Partly tested | Partial | Recovery policy, executor context, typed route ownership and current Core-refresh/composition cases exist. **Remaining:** Complete supported cross-domain recovery combinations, succession proofs and actual full graph cutover. |
| [operator.full-genesis](#operatorfull-genesis-evidence) Deploy and activate the complete full-v1 system | In progress | Tests written | Partial | `24d3c0f1` constructs all37 distinct original roles and25 direct support entries; `9ad53bd4` adds delayed module/policy/record/provider activation plans. Fifteen construction/record and11 Governor-Safe activation cases are authored, source reviewed. Canonical51-document/78-chunk Museum admission (`29cd8b2d`) adds11 actual-current Safe recipes. **Remaining:** Native execution, deployment-size repairs, full transitive inventory, genuine STATIC/schema admission and complete launch gas/restart acceptance. |
| [operator.monitoring](#operatormonitoring-evidence) Operational monitoring, incident response and recovery rehearsal | In progress | Partly tested | Partial | Read-only pinned current-stack monitor `d8e42dc5` is source-integrated with 25 focused root passes, exact offline RPC replay and reorg/failure controls. Runbooks and evidence/checkpoint tooling cover selected incidents. **Remaining:** Connect the complete deployed graph and exercise provider failure, halted sales, recovery and operator handover. |

### Developer clients and commerce operations

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [client.commerce](#clientcommerce-evidence) Typed native/revenue/secondary and saved inventory workflows | Built; bounded profiles | Tested* | Partial | DIRECT29, personhood, 37-role inventory and recovered 255/511 workflows are source integrated. Revenue17 callers `4fa32ae1` are integrated; canonical native, Merkle and Dutch callers `411f7b0e`/`611be306`/`95cc0e0e` are integrated and root passes1,739 tests. Historical ABI identities remain explicit. VIEW Inventory/Bundle clients `791cb767` add 22 typed writes and direct/Safe workflows, with 73 independently passing mock/oracle tests and root build/type checks. Tagged VIEW callers are integrated as `896899f7` with46 root focused passes; closed consent/root transport `cfcbc4ea` and strict repaired-source companion `34d27678` add64 root pure/mock passes. Executor9/RoleRegistry2 `e6a00086` pass78 root focused pure/mock tests. Aggregate attestation recovery `4fd80175` adds 151 distinct producer cases and 30 root focused passes. Guardian administration/rotation `708a97ae` adds 57 independently passing client cases; two corrected negative fixtures, root build and strict types pass. Original PRIMARY_ONLY collaborator (`91ae4002`) adds60 root passes; attribution operations10/44-50/61 (`45828ad0`) add107 distinct producer and47 root pure/workflow passes, with build/types passing. Multiple-generation callers (`d2b9c72c`/`33912f72`) add58 distinct focused passes across source-pinned runs; initial300-second combined timeout retained. **Remaining:** Actual all-call current/Safe execution and later profile callers. Mocked client workflows do not establish actual Safe execution. Complete History `904f1bc3` adds 62 root focused source/codec/provider/Safe-envelope passes on unchanged inputs across two runs; independent source review is clear. Platform11/53 provider-path additions and actual Safe execution remain separate. |
| [client.entropy-authority](#cliententropy-authority-evidence) Explicit entropy finding and op60 hydration Safe client | Built | Tested* | Not integrated | Complete original entropy finding/target/intent context and typed operation60 hydration with seven owner commitments. Source 642d017d is merged as 50c553c9; independent source review is clear. **Remaining:** All 175 package tests and generation/build/type checks pass on the integration checkout; real deployed Safe/provider composition remains pending. |
| [operator.commerce](#operatorcommerce-evidence) Saved governance, mint setup and native surplus plans | Built | Partly tested | Partial | Current deployment/catalog activation primitives and saved phase/surplus/lifecycle plans with exact current call/state checks. **Remaining:** Final full product graph deployment/activation and all caller-compatible saved workflows. Earlier deployment productsActivated=false is not a launch. c9d0353d six new surplus-plan tests are authored/source reviewed; root owns native acceptance. |
| [conformance.commerce-gas](#conformancecommerce-gas-evidence) Collector gas, capacity and complete cross-mode conservation | In progress | Partly tested | Not integrated | Required conformance across public paid/current Safe paths and complete liabilities; this is not a new sale feature. **Remaining:** Do not waive500,000 paid single-step ceiling. Retained partial-cold/warm clearing measurements exceed it;8,755,856 historical trace is not current/all-cold. Final all-cold collector, worst-case capacity/stateful fuzz, six-host financial conservation and final-source native campaigns remain integrator-owned. |

### Verification and release

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [quality.repo](#qualityrepo-evidence) Developer layout, domain interfaces and contributor documentation | Built | Partly tested | Partial | Current Core/domain/interface split, explicit legacy reference area, current-stack guides, tooling and examples. **Remaining:** Keep public docs aligned with this feature register and finish examples for remaining features. A tidy layout is not product completeness. |
| [quality.fuzz](#qualityfuzz-evidence) Modern Foundry unit, negative, fuzz and stateful testing system | Built | Partly tested | Partial | Recorded64/256-input scoped properties pass. Actual-current20-action and documentary9-action sources are integrated with complete-case/progress gates; three independently qualified stateful hosts are prepared. **Remaining:** Execute the final genuine linked current/stateful/fuzz campaigns and resolve failures. |
| [quality.safe](#qualitysafe-evidence) Safe compatibility for every supported call | In progress | Partly tested | Partial | Actual Safe cohorts cover selected mint, custody, payment, Artist and governance flows; generic ordered CALL plans are integrated. Seven actual all-CALL batch tests are authored through ebcff757 but native-pending. Three-version owner matrix9 (`f0c55176`/`fd7dc021`) and terminal mint/distribution10 (`3baa6c13`/`1a4858fd`) are reviewed/type-checked, native-pending. **Remaining:** Every final ABI selector/overload/read/receive/fallback/callback needs its supported Safe path or a tested protocol-only restriction. |
| [quality.capacity](#qualitycapacity-evidence) Full-system gas, deployment size and transaction capacity | In progress | Partly tested | Partial | Prepared, record/delegation, consent/attestation and external guard extractions fit their selected native captures; earlier 15-host joined Artist evidence is retained. Real Owner metadata cold recipe passes unchanged limits. **Remaining:** All reachable products in one final source context, constructor arguments, current/Safe transaction limits, metric failures, full CI and testnet evidence. |
| [quality.ci](#qualityci-evidence) Complete conformance, generated artifacts and CI for the new candidate | In progress | Partly tested | Not integrated | Deterministic tooling/checkers and release pipeline exist, with partial spec-rule and feature evidence coverage. **Remaining:** Refresh after implementation stabilizes: exact ABI/storage, complete requirement mapping, generators, notes/manifests, checksum bundle and full CI. |
| [release.rc1](#releaserc1-evidence) Supported RC1 contract release and Sepolia deployment | Built | Tested* | Integrated* | Existing frozen supported release at 569bf87f1fa808787d324f6e1582924b5ccf1d40, with recorded Sepolia evidence. **Remaining:** No full-v1 completeness is implied by this earlier release. |
| [release.full-v1](#releasefull-v1-evidence) Freeze and launch the complete expanded v1 candidate on testnet | In progress | Partly tested | Not integrated | Active implementation branch contains the expanded candidate, plus separately authored handoffs listed below. **Remaining:** Finish missing features, integrate and test the final system, freeze its source and deploy matching testnet evidence. |
| [release.external](#releaseexternal-evidence) Independent audit and external/operator acceptance | Not started | Not tested | Not integrated | Independent builder/adversarial reviews are being used during development; they are not an external audit. **Remaining:** External audit and operational/marketplace/provider acceptance are separately tracked when applicable; they do not block writing the remaining features. |

## Artist operation crosswalk

All 57 original writes and adopted operations 58–60 are included. Presence of
a public transport is narrower than complete support for every history/profile;
the linked feature rows control that scope. In particular, operation 60 does
not yet migrate arbitrary Artist histories. Canonical operation 36 is exposed
as `recordSuccessorDesignation` in the current facade.

| Operation | Canonical name | Transport built | Feature rows / missing scope |
| --- | --- | --- | --- |
| 1 | `proposeArtistBinding` | Built; bounded profiles | [ART02](#art02-evidence), [ART03](#art03-evidence) |
| 2 | `acceptArtistBinding` | Built; bounded profiles | [ART03](#art03-evidence), [ART41](#art41-evidence) |
| 3 | `refuseArtistBinding` | Built; bounded profiles | [ART03](#art03-evidence) |
| 4 | `withdrawArtistBinding` | Built; bounded profiles | [ART03](#art03-evidence) |
| 5 | `proposeCollaboratorIdentity` | Built; bounded profiles | [ART04](#art04-evidence), [ART41](#art41-evidence) |
| 6 | `acceptCollaboratorIdentity` | Built; bounded profiles | [ART04](#art04-evidence), [ART41](#art41-evidence) |
| 7 | `acceptCollaborator` | Built; bounded profiles | [ART04](#art04-evidence), [ART41](#art41-evidence) |
| 8 | `declarePlatformWorks` | Built; bounded profiles | [ART11](#art11-evidence) |
| 9 | `filePlatformWorksClaim` | Built; bounded profiles | [ART11](#art11-evidence) |
| 10 | `fileAttributionClaim` | Built; bounded profiles | [ART05](#art05-evidence) |
| 11 | `setPlatformWorksContest` | Built; bounded profiles | [ART11](#art11-evidence) |
| 12 | `recordArtistSanction` | Built; bounded profiles | [ART12](#art12-evidence) |
| 13 | `confirmSanctionFinalized` | Built; bounded profiles | [ART12](#art12-evidence) |
| 14 | `recordPolicyConsent` | Built; bounded profiles | [ART10](#art10-evidence), [ART42](#art42-evidence) |
| 15 | `recordEconomicsConsent` | Built; bounded profiles | [ART16](#art16-evidence) |
| 16 | `recordSaleConsent` | Built; bounded profiles | [ART10](#art10-evidence), [ART42](#art42-evidence) |
| 17 | `recordContentConsent` | Built; bounded profiles | [ART17](#art17-evidence) |
| 18 | `recordPayoutDesignation` | Built; bounded profiles | [ART15](#art15-evidence) |
| 19 | `recordStewardSanctionGrant` | Built; bounded profiles | [ART21](#art21-evidence) |
| 20 | `authorizeArtistRoyaltyFreeze` | Built; bounded profiles | [ART16](#art16-evidence) |
| 21 | `authorizeArtistContentFreeze` | Built; bounded profiles | [ART17](#art17-evidence) |
| 22 | `recordRecoveryApproval` | Built; bounded profiles | [ART13](#art13-evidence) |
| 23 | `recordUnavailabilityFinding` | Built; bounded profiles | [ART13](#art13-evidence) |
| 24 | `recordArtistAttestation` | Built; bounded profiles | [ART14](#art14-evidence) |
| 25 | `recordIdentityRevision` | Built; bounded profiles | [ART02](#art02-evidence) |
| 26 | `grantArtistDelegation` | Built; bounded profiles | [ART09](#art09-evidence), [ART42](#art42-evidence) |
| 27 | `revokeArtistDelegation` | Built; bounded profiles | [ART09](#art09-evidence), [ART42](#art42-evidence) |
| 28 | `setArtistGuardians` | Built; bounded profiles | [ART18](#art18-evidence) |
| 29 | `rotateArtistAddress` | Built; bounded profiles | [ART18](#art18-evidence) |
| 30 | `approveArtistRotation` | Built; bounded profiles | [ART18](#art18-evidence) |
| 31 | `vetoArtistRotation` | Built; bounded profiles | [ART18](#art18-evidence) |
| 32 | `executeArtistRotation` | Built; bounded profiles | [ART18](#art18-evidence) |
| 33 | `contestArtistIdentity` | Built; bounded profiles | [ART18](#art18-evidence) |
| 34 | `vetoIdentityRecovery` | Built; bounded profiles | [ART20](#art20-evidence) |
| 35 | `recoverArtistIdentity` | Built; bounded profiles | [ART20](#art20-evidence) |
| 36 | `designateSuccessor` | Built; bounded profiles | [ART19](#art19-evidence) |
| 37 | `recordEstateDirective` | Built; bounded profiles | [ART19](#art19-evidence) |
| 38 | `requestEstateActivation` | Built; bounded profiles | [ART19](#art19-evidence) |
| 39 | `cancelEstateActivation` | Built; bounded profiles | [ART19](#art19-evidence) |
| 40 | `executeEstateActivation` | Built; bounded profiles | [ART19](#art19-evidence) |
| 41 | `initiateArtistDormancy` | Built; bounded profiles | [ART21](#art21-evidence) |
| 42 | `cancelArtistDormancy` | Built; bounded profiles | [ART21](#art21-evidence) |
| 43 | `completeArtistDormancy` | Built; bounded profiles | [ART21](#art21-evidence) |
| 44 | `openAttributionDispute` | Built; 14-case dispute cohort authored, native pending | [ART06](#art06-evidence) |
| 45 | `recordCounterStatement` | Built; 14-case dispute cohort authored, native pending | [ART06](#art06-evidence) |
| 46 | `resolveAttributionDispute` | Built; 14-case dispute cohort authored, native pending | [ART06](#art06-evidence) |
| 47 | `revokeAttribution` | Source integrated582b9181; native/combined capacity pending | [ART06](#art06-evidence) |
| 48 | `vetoAttributionRepudiation` | Source integrated582b9181; native/combined capacity pending | [ART06](#art06-evidence) |
| 49 | `cancelAttributionRepudiation` | Source integrated582b9181; native/combined capacity pending | [ART06](#art06-evidence) |
| 50 | `executeAttributionRepudiation` | Source integrated582b9181; native/combined capacity pending | [ART06](#art06-evidence) |
| 51 | `revokePriorAddressStanding` | Built; bounded profiles | [ART18](#art18-evidence) |
| 52 | `recordContentRatification` | Built; bounded profiles | [ART10](#art10-evidence), [ART42](#art42-evidence) |
| 53 | `approvePlatformWorksCorrection` | Built; bounded profiles | [ART11](#art11-evidence) |
| 54 | `revokeArtistAuthorization` | Built; bounded profiles | [ART08](#art08-evidence) |
| 55 | `commitArtistHistoryImportRoot` | Built; bounded profiles | [ART29](#art29-evidence) |
| 56 | `verifyImportedLaneTip` | Built; bounded profiles | [ART29](#art29-evidence) |
| 57 | `observeRegistryCutover` | Built; bounded profiles | [ART29](#art29-evidence) |
| 58 | `dismissArtistIdentityContest` | Built; bounded profiles | [ART18](#art18-evidence) |
| 59 | `grantStewardCapabilities` | Built; bounded profiles | [ART21](#art21-evidence) |
| 60 | `hydrateArtistAuthority` | Built; bounded profiles | [ART31](#art31-evidence), [ART32](#art32-evidence), [ART33](#art33-evidence), [ART34](#art34-evidence), [ART35](#art35-evidence), [ART36](#art36-evidence), [ART37](#art37-evidence) |
| 61 | `withdrawAttributionDispute` | Built; native acceptance pending | [ART06](#art06-evidence); [ADR0050](../docs/adr/0050-attribution-dispute-withdrawal.md) |

## Genesis component crosswalk

The [genesis inventory](../release-artifacts/genesis-deployment-profile.json)
has **37 component roles**, not 37 features or museum schemas. A role can require
multiple contracts. Code with a similar purpose/name is not automatically an
approved interface/implementation equivalent. Every role still needs acceptance
in the complete final deployment; this table is not a list of deployed addresses.

| # | Required component role | Feature coverage | Genesis correspondence / deployment work |
| --- | --- | --- | --- |
| 1 | `STREAM_CORE` | [core.nft](#corenft-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 2 | `GOVERNANCE_LAYER` | [governance.roles](#governanceroles-evidence), [governance.actions](#governanceactions-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 3 | `MODULE_REGISTRY` | [core.pointers](#corepointers-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 4 | `REVENUE_RESOLVER` | [revenue.live-royalties](#revenuelive-royalties-evidence), [revenue.resolver-continuity](#revenueresolver-continuity-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 5 | `SPLIT_FACTORY` | [revenue.factory-wallets](#revenuefactory-wallets-evidence), [revenue.escrow-recovery](#revenueescrow-recovery-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 6 | `SPLIT_WALLET_IMPLEMENTATION` | [revenue.factory-wallets](#revenuefactory-wallets-evidence), [revenue.claims](#revenueclaims-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 7 | `REVENUE_ESCROW` | [revenue.escrow-flush](#revenueescrow-flush-evidence), [revenue.escrow-recovery](#revenueescrow-recovery-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 8 | `ASSET_POLICY_REGISTRY` | [revenue.asset-policy](#revenueasset-policy-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 9 | `PRIMARY_SALE_SETTLEMENT` | [sales.native-fixed](#salesnative-fixed-evidence), [revenue.primary-templates](#revenueprimary-templates-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 10 | `CLAIM_ROUTER` | [revenue.claims](#revenueclaims-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 11 | `MINT_MANAGER` | [sales.phase-ledger](#salesphase-ledger-evidence), [mint.static](#mintstatic-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 12 | `MINT_LEDGER` | [mint.static](#mintstatic-evidence), [mint.cross-scope](#mintcross-scope-evidence), [mint.continuity](#mintcontinuity-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 13 | `MINT_TICKET_GATE` | [sales.standard-gates](#salesstandard-gates-evidence) | Concrete Ticket gate integratedfeda72d3; scoped tests pass, full genesis/current-system acceptance pending. |
| 14 | `FIXED_PRICE_SALE_ADAPTER` | [sales.native-fixed](#salesnative-fixed-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 15 | `ENGLISH_AUCTION_HOUSE` | [sales.english](#salesenglish-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 16 | `DUTCH_AUCTION_ADAPTER` | [sales.dutch](#salesdutch-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 17 | `PRIVATE_SALE_ADAPTER` | [sales.private-offer](#salesprivate-offer-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 18 | `BURN_MINT_GATE` | [sales.burn-mint](#salesburn-mint-evidence) | Free/prepared/native-paid and zero-native-fee ERC20 source integrated; remaining fee-profile and actual-current acceptance stay explicit. |
| 19 | `DELEGATE_REGISTRY_GATE` | [mint.delegate-registry](#mintdelegate-registry-evidence) | Concrete vault-delegation gate integratedfeda72d3; scoped tests pass, actual external registry and full genesis acceptance pending. |
| 20 | `ERC20_PRIMARY_SETTLEMENT_ADAPTER` | [sales.erc20-immediate](#saleserc20-immediate-evidence), [sales.erc20-reveal](#saleserc20-reveal-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 21 | `ARTIST_REGISTRY` | [ART01](#art01-evidence), [ART06](#art06-evidence), [ART34](#art34-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 22 | `METADATA_ROUTER` | [MUSEUM-01](#museum-01-evidence), [MUSEUM-16](#museum-16-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 23 | `RENDERER_V1` | [metadata.renderer-routing](#metadatarenderer-routing-evidence), [MUSEUM-15](#museum-15-evidence), [MUSEUM-39](#museum-39-evidence) | Renderer/Registry, raw Artist facts, selection and fixed formatting source integrated; Router capacity, genesis and complete STATIC/finality acceptance remain. |
| 24 | `COLLECTION_METADATA` | [MUSEUM-03](#museum-03-evidence), [MUSEUM-09](#museum-09-evidence) | Legacy StreamCollectionMetadata/IStreamCollectionMetadata and current StreamCollectionMetadataV1 have different interfaces; exact genesis correspondence remains unresolved. |
| 25 | `SCHEMA_REGISTRY` | [MUSEUM-02](#museum-02-evidence), [MUSEUM-40](#museum-40-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 26 | `OWNER_RECORDS` | [MUSEUM-05](#museum-05-evidence), [MUSEUM-36](#museum-36-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 27 | `PRESERVATION_RECORDS` | [MUSEUM-06](#museum-06-evidence), [MUSEUM-39](#museum-39-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 28 | `COLLECTION_ATTESTATIONS` | [MUSEUM-04](#museum-04-evidence), [MUSEUM-08](#museum-08-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 29 | `COLLECTION_VIEWS` | [MUSEUM-07](#museum-07-evidence) | Built; 9 focused tests pass; full current activation pending. |
| 30 | `ENTROPY_COORDINATOR` | [entropy.registration](#entropyregistration-evidence), [entropy.incidents](#entropyincidents-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 31 | `ENTROPY_PROVIDER_VRF` | [entropy.providers](#entropyproviders-evidence) | VRF source exists; final upstream/deployment acceptance pending. |
| 32 | `ENTROPY_PROVIDER_FALLBACK` | [entropy.providers](#entropyproviders-evidence) | ARRNG source exists; one selected fallback provider and real upstream acceptance required. |
| 33 | `ARTWORK_FINALITY_REGISTRY` | [finality.collection](#finalitycollection-evidence), [finality.all-scopes](#finalityall-scopes-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 34 | `ENTROPY_COORDINATOR_FALLBACK` | [entropy.fallback-continuity](#entropyfallback-continuity-evidence) | Must be a distinct instance; complete safe-mode/activation proof pending. |
| 35 | `MINT_MANAGER_FALLBACK` | [mint.continuity](#mintcontinuity-evidence), [operator.full-genesis](#operatorfull-genesis-evidence) | Must be a distinct instance; complete fallback activation and ledger continuity pending. |
| 36 | `STREAM_SYSTEM_MANIFEST` | [governance.manifest](#governancemanifest-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 37 | `STREAM_CORE_FINALITY_ADAPTER` | [finality.hosts](#finalityhosts-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |

## Museum requirement and schema crosswalk

The adopted [museum specification](../docs/museum-semantic-mapping.md) remains
the full delivery target. Its conformance is tracked separately from contract
testnet delivery. The following maps all twelve museum requirement/gate families;
it does not claim that any entire gate has passed just because one exporter works.

| Requirement family | Acceptance gate | Feature rows |
| --- | --- | --- |
| `MSM-SCOPE` | `MSM-01-SCOPE` | [MUSEUM-01](#museum-01-evidence) |
| `MSM-PROFILE` | `MSM-02-PROFILE-LOCK` | [MUSEUM-02](#museum-02-evidence), [MUSEUM-18](#museum-18-evidence), [MUSEUM-40](#museum-40-evidence) |
| `MSM-IDENTITY` | `MSM-03-IDENTITY` | [MUSEUM-19](#museum-19-evidence) |
| `MSM-MAPPING` | `MSM-04-CROSSWALK` | [MUSEUM-09](#museum-09-evidence), [MUSEUM-10](#museum-10-evidence), [MUSEUM-11](#museum-11-evidence), [MUSEUM-12](#museum-12-evidence), [MUSEUM-13](#museum-13-evidence), [MUSEUM-14](#museum-14-evidence), [MUSEUM-17](#museum-17-evidence), [MUSEUM-20](#museum-20-evidence), [MUSEUM-26](#museum-26-evidence), [MUSEUM-30](#museum-30-evidence), [MUSEUM-31](#museum-31-evidence), [MUSEUM-32](#museum-32-evidence), [MUSEUM-33](#museum-33-evidence), [MUSEUM-34](#museum-34-evidence) |
| `MSM-ASSERTIONS` | `MSM-05-AUTHORSHIP` | [MUSEUM-03](#museum-03-evidence), [MUSEUM-04](#museum-04-evidence), [MUSEUM-05](#museum-05-evidence), [MUSEUM-08](#museum-08-evidence), [MUSEUM-21](#museum-21-evidence) |
| `MSM-AUTHORITIES` | `MSM-06-AUTHORITIES` | [MUSEUM-22](#museum-22-evidence) |
| `MSM-PLACES` | `MSM-07-PLACES` | [MUSEUM-23](#museum-23-evidence) |
| `MSM-RELATIONS` | `MSM-08-RELATIONS` | [MUSEUM-10](#museum-10-evidence), [MUSEUM-11](#museum-11-evidence), [MUSEUM-13](#museum-13-evidence), [MUSEUM-14](#museum-14-evidence), [MUSEUM-15](#museum-15-evidence), [MUSEUM-24](#museum-24-evidence), [MUSEUM-30](#museum-30-evidence), [MUSEUM-31](#museum-31-evidence), [MUSEUM-32](#museum-32-evidence), [MUSEUM-33](#museum-33-evidence), [MUSEUM-34](#museum-34-evidence) |
| `MSM-EXPORT` | `MSM-09-EXPORT` | [MUSEUM-16](#museum-16-evidence), [MUSEUM-17](#museum-17-evidence), [MUSEUM-25](#museum-25-evidence), [MUSEUM-35](#museum-35-evidence), [MUSEUM-36](#museum-36-evidence) |
| `MSM-INTEROP` | `MSM-10-INTEROP` | [MUSEUM-26](#museum-26-evidence), [MUSEUM-27](#museum-27-evidence), [MUSEUM-28](#museum-28-evidence), [MUSEUM-29](#museum-29-evidence), [MUSEUM-30](#museum-30-evidence), [MUSEUM-31](#museum-31-evidence), [MUSEUM-36](#museum-36-evidence) |
| `MSM-AUTHORING` | `MSM-11-AUTHORING` | [MUSEUM-37](#museum-37-evidence) |
| `MSM-CONFORMANCE` | `MSM-12-INSTITUTIONAL` | [MUSEUM-38](#museum-38-evidence) |

The separate **29-name museum schema inventory** is below. A schema definition,
typed semantic adapter and actual on-chain registration are different work.
All29 exact definitions and worked examples are now source-built (`8b3f01f8`),
with 89 root tests and a reviewed51-document/78-chunk admission plan.
Complete genesis registration has not been established for this catalog.

| Required museum schema/profile | Implementation and remaining semantics |
| --- | --- |
| `STREAM_ACCESSION_V1` | [MUSEUM-13](#museum-13-evidence), [MUSEUM-17](#museum-17-evidence) |
| `STREAM_CONDITION_REPORT_V1` | [MUSEUM-14](#museum-14-evidence), [MUSEUM-33](#museum-33-evidence) |
| `STREAM_EXHIBITION_V1` | [MUSEUM-32](#museum-32-evidence) |
| `STREAM_LOAN_V1` | [MUSEUM-33](#museum-33-evidence), [MUSEUM-36](#museum-36-evidence) |
| `STREAM_DEACCESSION_V1` | [MUSEUM-13](#museum-13-evidence) |
| `STREAM_CITATION_RECORD_V1` | [MUSEUM-13](#museum-13-evidence), [MUSEUM-17](#museum-17-evidence) |
| `STREAM_VALUATION_V1` | [MUSEUM-34](#museum-34-evidence), [MUSEUM-36](#museum-36-evidence) |
| `STREAM_STEWARD_DESIGNATION_V1` | [MUSEUM-12](#museum-12-evidence) |
| `STREAM_RECOVERY_RESPONSE_V1` | [MUSEUM-12](#museum-12-evidence) |
| `STREAM_REDEMPTION_CLAIM_V1` | [MUSEUM-13](#museum-13-evidence) |
| `STREAM_ARTIST_INTENT_V1` | [MUSEUM-10](#museum-10-evidence) |
| `STREAM_ARTIST_INTENT_WAIVER_V1` | [MUSEUM-10](#museum-10-evidence) |
| `STREAM_ARTIST_INTERVIEW_V1` | [MUSEUM-10](#museum-10-evidence) |
| `STREAM_MASTER_WAIVER_V1` | [MUSEUM-08](#museum-08-evidence), [MUSEUM-39](#museum-39-evidence) |
| `STREAM_IDENTITY_NOTARIZATION_V1` | [MUSEUM-08](#museum-08-evidence), [MUSEUM-17](#museum-17-evidence) |
| `STREAM_OBJECT_DOSSIER_V1` | [MUSEUM-17](#museum-17-evidence), [MUSEUM-25](#museum-25-evidence) |
| `STREAM_ACQUISITION_PACKET_V1` | [MUSEUM-17](#museum-17-evidence), [MUSEUM-38](#museum-38-evidence) |
| `STREAM_RIGHTS_V1` | [MUSEUM-11](#museum-11-evidence) |
| `STREAM_PREMIS_V3_PROFILE` | [MUSEUM-27](#museum-27-evidence), [MUSEUM-30](#museum-30-evidence), [MUSEUM-31](#museum-31-evidence) |
| `STREAM_REFERENCE_RENDER_V1` | [MUSEUM-15](#museum-15-evidence), [MUSEUM-39](#museum-39-evidence) |
| `STREAM_METRIC_SSIM_V1` | [MUSEUM-39](#museum-39-evidence) |
| `STREAM_IIIF_P3_MIN_V1` | [MUSEUM-28](#museum-28-evidence) |
| `STREAM_WORK_DESCRIPTION_V1` | [MUSEUM-09](#museum-09-evidence) |
| `STREAM_MUSEUM_SEMANTIC_PROFILE_V1` | [MUSEUM-18](#museum-18-evidence), [MUSEUM-40](#museum-40-evidence) |
| `STREAM_SEMANTIC_ASSERTION_V1` | [MUSEUM-18](#museum-18-evidence), [MUSEUM-21](#museum-21-evidence) |
| `STREAM_SEMANTIC_EXPORT_V1` | [MUSEUM-25](#museum-25-evidence) |
| `STREAM_LIDO_PROFILE_V1` | [MUSEUM-29](#museum-29-evidence) |
| `STREAM_BAGIT_PROFILE_V1` | [MUSEUM-35](#museum-35-evidence) |
| `STREAM_COLLECTION_IDENTITY_V1` | [MUSEUM-01](#museum-01-evidence), [MUSEUM-16](#museum-16-evidence) |

## Intentional exclusions and later work

These are not silently counted as missing genesis implementation. A future
extension needs its own accepted scope. This list does not defer any adopted
museum requirement, mandatory gate, Artist operation or required ERC20 primary
settlement behavior listed above.

| Item | Scope decision / source |
| --- | --- |
| Resolver-defined caps/deltas, general policy VMs, private/ZK claims, resolver-backed counter identities, ERC2771 mint forwarding | Explicitly outside protocol-v1 mint scope. MERKLE_STATIC caps and ordinary gate nullifiers remain required. [Mint scope](../docs/mint-policy-and-accounting.md) |
| Live TDH/network-profile eligibility implementation | Future gate trust/interface profile is specified; implementation is excluded at genesis. Snapshot allowlists and disclosed signed tickets remain required fallbacks. [SSA-NETWORK-ELIGIBILITY](../docs/stream-sales-and-auctions.md) |
| English ERC20 bidding, sealed/ranked bids, raffles, lots/hybrid formats and other later auction profiles | Explicit later/non-genesis sale profiles. Scope-entropy primitives alone do not constitute a raffle product. [Sales specification](../docs/stream-sales-and-auctions.md) |
| Preburned/external-collection burn claims beyond accepted ticket fallback | Not the mandatory same-transaction Stream-token burn consumer. [Sales specification](../docs/stream-sales-and-auctions.md) |
| Lean formal verification | Owner agreed to pursue it after traditional implementation/testing stabilizes. Not started; separate later work. |
| DYNAMIC/evolving renderer implementations and post-mint interactive modules | Explicitly excluded from genesis/v1; STATIC selectable/versioned routing remains required. PERCEPTUAL_TOLERANCE and CURATED_EQUIVALENCE are required finality acceptance modes, not permission to omit their evidence merely because rendering is STATIC. [Renderer scope](../docs/metadata-router-and-renderer.md), [finality inputs](../docs/collection-metadata-contract.md) |
| Registry legal enforcement, identity truth guarantees, third-party display enforcement and retroactive rewriting of finality/owed rights | Explicit architectural boundaries, not missing smart-contract features. [Artist authority](../docs/stream-artist-authority.md) |

## Feature evidence

### Parallel feature batch 16 September

The latest source is `2314878c`. All 2,098 Solidity inputs at `2e0fca1a` pass
ABI/type/storage checking in 18.015 seconds, including complete ERC20 offer source,
without bytecode or runtime acceptance. Root client 375, museum authority 131, archive 27 and
dossier 44 results retain their original source scopes. The following new batches supersede older queue notes.

- Native primary mint OFFER_SALE is source-integrated as `3406e669`,
  `9945d612`, `f125e548` and `364ec9e2`. It supports unselected tokenId=0 and
  selected unminted work with the original buyer Offer and complete seller
  SaleAuthorization. Buyer-offer Ledger replay and seller-authorization replay
  remain separate; the signed executor supplies native funds, and the buyer
  receives the token and pull refund. Full historical revocation, explicit
  EOA/ERC1271 signers and Safe CALL cases are included. Independent review is
  clear for exact carrier/shared production. All six final carrier products
  fit; the carrier is 23,649 runtime bytes. The exact committed Manager and
  recorder now measure 23,098/20,797 in the native capture. All 70 distinct
  cases pass: 25 carrier/current/Safe plus 45 shared-seam cases. The latter
  combines 21 unchanged passes with a 24-case retry after test-only e1bf2306
  fixes buyer prank ordering and adds real-grant success controls. Independent
  review verifies both case sets, all source/artifact pins and unchanged
  production. The carrier uses actual Core/Manager/Ledger/recorder and 2-of-2
  Safe; Artist/entropy/governance remain typed, so full-graph acceptance is separate. Eleven import-only test/deployment
  corrections preserve all other tokens; the whole 2,061-source ABI/type/storage
  check passes at `fbd9dcec`. The separate ERC20 offer batch below now implements its payer-intent profile. See [native primary offers](../docs/integrations/native-primary-offers.md).
- ERC20 primary offers `4bb37e53`/`1d4e7236`/`94eaedc3` are integrated as
  `d07d9537`/`42ab5d2d`/`2e0fca1a`. Independent joined source review is clear.
  The original buyer/seller signatures, three independent replay owners,
  actual contract20 payer/intent boundary and exact recorded settlement before
  minting are preserved. The buyer receives the NFT directly. This nonpayable
  positive-price PROFILE/order-one profile rejects nonzero native reveal fees;
  no held allowance implementation is included. All eight shared and seven
  carrier runtime products fit, including Manager 24,174 and carrier 22,873;
  root verifies changed production source pins and compiler settings. Carrier
  creation output is absent from the selected preflight and remains unverified.
  Seventy-one shared and forty-two carrier/current cases are authored and their
  frozen native captures are running. The prior focused carrier authorization/
  revocation cohort passes 27 cases; it is not the actual-current result.
  Clients and final current/Safe/fuzz acceptance remain. See
  [ERC20 primary offers](../docs/integrations/erc20-primary-offers.md).
- Preservation fixture `a64a2e97` is integrated as `2314878c`. Its provider now
  follows the actual ACTIVE lifecycle transition before configuration, while
  governance remains the existing named typed boundary. The original failed
  metric-export setup trace is preserved; corrected cached runtime is pending.
  Production is unchanged and its 351-source ABI check passes separately.

- Primary-offer clients `dc4828b7` are integrated as `1c101938`. Root passes
  all 398 package tests including generation, build and TypeScript checks;
  the complete 396-source compiler fixture also regenerates exactly in check
  mode. Original 12/24-field signatures, selected/unselected paths, dual replay,
  historical revocation and executor-funded Safe CALL plans are covered.
  This is client/encoding/simulated-RPC acceptance, separate from contract runtime.
- Museum object-dossier tooling `352bb01b` is integrated as `2503b218`.
  Independent source review is clear; root passes all 60 focused tests in
  165.032 seconds and all four definition checks. The native inventory adapter
  reconstructs exact context, item/segment chains, required stages, runtime pins
  and receipt ancestry. Its complete transport vector remains synthetic. The
  actual capture8 partial assembler preserves original files, accounts for 49
  fixed requirements and verifies identity only as a complete requirement;
  supplied opaque components cannot imply conformance. Full histories, actual
  completed native-inventory RPC capture, complete render bytes and full dossier
  acceptance remain. These are evidence-coverage diagnostics, not a protocol
  completion percentage. See [object dossier](../docs/museum-object-dossier.md).

- Complete owner/independent catalogs and Core ownership history `f392856d`
  are integrated as `61b87646`. Root passes all 111 new and compatibility
  tests in 67.517 seconds and all three profile checks; independent source
  review is clear. Readers reconstruct dynamic owner types and every receipt
  from genesis, closed independent types, full record/author heads and token
  mint/transfer/burn history. Empty and opaque data remain explicit. Complete
  controls are synthetic; genuine same-graph/block capture, remaining native
  hosts/scopes and canonical assembler joins remain. Fixture URI inputs are
  repaired without changing retained captures; two native URI regressions
  are authored and await the next coordinated native run. No full dossier or
  complete event-archive acceptance is claimed.

- Dutch/clearing retry `ba735199` is integrated as `963cfce8`. All 26 cases
  pass (15 Dutch and 11 clearing), with exact economics-consent behavior added
  only to typed Artist fixtures. Production is unchanged from the original
  25/26 run. Independent review verifies all 301 source inputs, 303 selected artifact
  metadata records and 154 fitting production products. It exercises actual sale/proof/recorder/registry/wallet/
  escrow with typed Core/Manager/Artist/entropy/governance and counter-read
  seams; complete current-graph acceptance remains separate.

- Native selected-work fixed PUBLIC/COMMIT_REVEAL and buyer-bound private
  carriers `187a55af` are integrated as `161cda75`, with four actual recorder/
  Safe rollback cases `2c9effb4`. All 128 size inputs match the commit; fixed
  runtime is 24,081 bytes and private 23,545. Ninety-seven distinct scoped unit
  cases pass across retained runs. Independent review found a repeat-refund
  ordering edge; `b25b3d16` fixes it with an original failing regression and
  35/35 corrected book tests, including conservation fuzzing. This overlaps the
  original unit cohort. The frozen 5605d019 current-contract run finishes with
  48 passes and two fixture failures (50 results from 55 intended cases because
  six revocation cases fail setup). All 41 own fixed/private/Safe sale cases pass,
  including 256-run selection fuzzing. The independently reviewed test-only
  correction 301ccda9 adds the missing block advance and accurately represents
  the revocation fixture's absent royalty resolver. Its ten-case retry passes:
  55 distinct expected cases pass across the two runs. Root independently checks
  all 379 source inputs, exactly two test-only differences and both original log
  hashes; no production changed between runs. All 217 captured production
  products fit. Later refund correction b25b3d16 remains covered by its separate
  35-case book capture, not this original-production current cohort.
  See [selected-work sales](../docs/integrations/native-curated-selected-sales.md).
- Curated clients `28703540` are integrated as `2b93a187`: complete manifest
  bytes/proofs, fixed purchase/commit/reveal/refunds, private full-payload TICKET
  and historical revocation, and Safe CALL plans. Root passes all 375 package
  tests including generation/build/types, and both exact-source ABI fixture
  checks. This is caller/encoding/simulated-RPC evidence, separate from native
  contract tests and full deployed Safe acceptance. See the
  [fixed caller](../packages/stream-client/docs/current-curated-fixed.md) and
  [private caller](../packages/stream-client/docs/current-curated-private.md).
- STATIC scan optimization `78fdf46e`/`c4967b10` is integrated as
  `849bfd68`/`3fb128d6`. All 13 focused composition/gas tests and 15 pure tests
  pass, including five 256-input parity properties. The named cold 24 KB append
  costs 9,512,309 gas including intrinsic cost; current validation costs
  6,072,737. Six rows fit using 4+2 batches; eight rows still refuse admission.
  The full gas guards and Router body are unchanged. The captured Router is
  39,393 bytes and still cannot deploy under the normal limit. These measured
  fixture scopes are not complete current-graph acceptance. See
  [capacity limits](../docs/integrations/static-checkpoint-capacity.md).
- Versioned PERCEPTUAL_TOLERANCE/CURATED_EQUIVALENCE source 2351111e now
  includes correction `0a72dec4` as `5e6c6140`: exact signed institution and
  credential archive obligations, additive enum-complete ABI_V2 and fixed
  preparation/dependency/inventory workers. Both independent reviews are clear.
  All five original V1 documents and BYTE_EXACT remain unchanged. Standard ABI
  encode/decode of a populated 12,672-byte payload is independently identical;
  all 288 nested ABI nodes and all six registered document hashes match. Root's
  11 metric tests and generator check pass. The exact 0a72dec4 size preflight
  reports all 17 products within bounds. The subsequent native test compiler
  fails with a Yul stack-layout error after 1,682.74 seconds; none of the 12
  authored cases execute. Original inputs and logs remain retained while the
  test-codegen trigger is isolated. Full curated composition, joined metric
  supplement/finality runtime and institution-signer alternatives remain. See
  [mode scope](../docs/integrations/reference-finality-modes.md).

- Metric supplement `7ca6a2df` is integrated as `5562bdb0`. Full PERCEPTUAL
  finality now binds retained source/runtime/replay closure to the original
  publication, lock and twenty-two-item interpretation inventory. Original
  V1 ABI/storage prefix and other finality identities are preserved. Independent
  source/artifact review is clear; seven native proof cases and 256 parity fuzz
  inputs pass, with thirteen nonempty production products fitting. Proof-call
  gas is 7,706,520; complete publisher capacity remains pending. Root passes 81
  offline preservation tests with one opt-in skip and exact profile generation.
  Genuine combined replay and joined publisher/Safe/lock/inventory acceptance
  remain separate. See [metric supplement](../docs/integrations/reference-metric-supplement.md).
- CI throughput `95a21a28` is integrated as `7d5ba35c`. Repository checks run
  independently of native compilation; obsolete independent PR jobs cancel,
  while draft native runs retain their caches. The required Foundry smoke
  result still requires both same-run jobs to succeed and all original native
  commands remain. Root passes 49 orchestration tests, policy/cardinality and
  actionlint syntax/expression checks. Frozen checksum refresh and full remote
  CI acceptance remain pending; no release artifact was rewritten.

- Scope reconciliation: moving-price selection is extension 19 and
  [SSA-CONTENT-TIME](../docs/stream-sales-and-auctions.md#content-selection-on-time-varying-kinds),
  not unfinished genesis work. Free claims and Merkle free tiers are required
  mechanic families with existing implementations; the specification does not
  independently require every free/price/asset/selection combination. Unsupported
  combinations remain documented as such. Canonical primary mint OFFER_SALE,
  including a selected unminted work, is an explicit genesis capability, now
  source-integrated in the native offer batch above. Existing custody offers
  alone did not satisfy this mint path.
  The ERC20 source batch above now implements those separate payer-intent obligations for its stated zero-native-fee profile; actual-current acceptance remains pending.

- Actual-token museum capture `fe176620` is integrated as `1db47ad9`. Root
  passes all 62 new tests; independent review verifies 305 selected products
  and all 27 retained original inputs. Fresh local token 1 in collection 1
  joins its paid mint, 15 Safe-authorized token records, exact source-block
  Core/metadata reads and original 70-byte PNG. The offline packet rebuilds
  its semantic export, BagIt and immutable OCFL without executing retained
  source snapshots. Controlled entropy, synthetic authority and trusted local
  RPC remain explicit. Full OBJECT_DOSSIER, complete record/ownership histories
  and authoritative render inventory remain required. See the
  [token capture guide](../docs/museum-token-capture.md).
- Retained metric package `a5f8fba2`/`07ecfa23` is integrated as
  `dffb8444`/`2b333b74`. Original metric source, report domains and V1 schemas
  remain unchanged. Root passes 81 offline preservation checks (one opt-in
  execution test skipped), then the actual restored-runtime test separately
  in 56.516 seconds. The 46,267,502-byte archive retains 684 members; execution
  observes 210 Python modules, 25 package native images and 25 explicit Windows
  prerequisites. Its canonical transcript and 219,264-byte supplement verify
  against the exact input/environment/report. This uses synthetic PNG/context
  inputs; joined browser, onchain publication and finality acceptance are
  separate. Offline preservation checks now run in existing Windows/Linux CI;
  CI does not execute arbitrary archives. See the
  [metric package guide](../docs/integrations/reference-metric-package.md).

- Scoped museum dossier `79813a60` is integrated as `a0d71d2`. Root passes all
  44 new/legacy dossier, BagIt and hydration tests in 189.36 seconds; independent
  source review is clear. The actual collection export is reconstructed offline,
  with all original files, selected admitted media, exact SHA/CID/size checks,
  missing-byte refusal and immutable OCFL versions. Historical tool snapshots
  remain inert and unchanged. Existing V1/V2/V3 schemas/profiles/fixtures stay
  byte-identical. This distinct collection profile does not complete the required
  token object dossier or authoritative render inventory. See the
  [scoped dossier guide](../docs/museum-scoped-dossier.md).
- Shared curated purchase seam `61fa4eba` is integrated as `33ddd132`. Independent
  review covers all 17 paths, 223 captured sources, original Manager/recorder
  ABI and storage, all four actual batch-array commitments and historical full
  private revocation. Original mutation bodies and domains remain unchanged;
  the recorder adds per-purchase replay while retaining auction replay. Six
  stored view encodings move into the existing fixed view library. All ten
  selected products fit: Manager 22,694 and recorder 20,128 runtime bytes. Ten
  focused cases are authored, not executed. Concrete sale/gate carriers and
  actual paid-purchase tests continue in parallel. See the
  [integration guide](../docs/integrations/prepared-native-content-purchases.md).
- Pure encoding `8b2f530d` is integrated as `9753b496`. Root/C source review
  is clear and all 14 frozen inputs match. Eleven tests pass, including three
  256-input differential fuzz properties. Identical 24,576-byte ONCHAIN pure
  HTML drops from 16.96m to 5.11m gas and JSON from 42.69m to 7.71m. Formatter
  runtime is 12,594 bytes. The joined capture passes the original nine behavior
  cases plus a scope diagnostic at high gas, but its 24,576-byte append/current
  paths cost 35,327,996/21,409,844 gas. All bounded transaction attempts reject
  at the full read-budget guard. Capacity remains unfinished; output-preserving
  byte-scan work is active, without weakening that guard.
- Archival export `a60ba4e0` is integrated as `23477832`. All 27 root tests pass
  in 89.969 seconds. Independent source/artifact review reconstructs all 24
  retained inputs, 25 source selectors and the actual class-6 Safe ARCHIVE
  publication. The 5,043-byte V3 manifest commits complete child selections;
  original V1/V2 bytes and synthetic-snapshot qualifications remain. This is
  pinned local trusted-RPC evidence, not consensus or full Museum conformance.
- Refund-window native source `90e68ebf` originally passed 76/77; the sole
  failing oracle expected an inactive getter to return zero instead of its
  specified revert. Test-only `33fefd7c` is integrated as `fda1d244` and all 14
  focused retry cases pass, preserving rollback/proof/accounting/exact-retry
  assertions. This accepts 77 distinct cases across two runs. Root matches all
  291 retry inputs and the log hash; 139 captured production products fit.
  Actual recorder/book/factory/wallet/escrow/Safe are used, with typed
  Manager/Core/Artist/entropy boundaries; this is not latest current-stack proof.
- Refund-window callers `6c25d003` are integrated as `fdb00c77`. Independent
  source/encoding review is clear; root generation/build/types and all 347 tests
  pass. Original signed public price remains separate from captured charge;
  canonical saved-proof/readback and payer-owned credits are covered. This is
  client/encoding evidence, not deployed Safe or historical admission proof.
- Refund-window same-leaf prices `90e68ebf` are integrated as `08775172`.
  Original signed public prices remain unchanged; separate captured charge/proof
  facts determine deposit, refund, finalization and counter-exhaustion evidence.
  Independent accounting/host/worker reviews and root review are clear. Fourteen
  new cases are authored; the 77-case native result and test correction are above. Selected
  host runtime is 24,202 bytes. Root corrected a transitive generic import alias
  collision as `81858484`; the first failed broad compile remains retained.
- Dutch/clearing callers `604a751e` are integrated as `18e8396a`, with strict
  original-domain boolean signing, full-width ceilings and immutable async
  inputs. Root's 327-case client run includes generation, build and type checks.
- Museum typed authority `b6526097` is integrated as `8ba023dc`. Independent
  review confirms all 11 original V1 documents are byte-identical and all 23
  retained fixture inputs match their commitments. Forty-two original registry
  documents and a local Safe Type/declaration/alignment/later-review flow replay
  in the 131-case root cohort. The reconciled snapshot is synthetic; the separate
  Getty response is retained as SPARQL-results bytes and is not used to claim
  publisher-backed equivalence. Native artifacts prove their pinned source,
  not the latest integrated graph.
- Exact withdrawal source `13118faa` now has selected production sizing:
  Attribution 29,556 and Identity deployment 25,911 bytes fail the runtime ceiling;
  the other 17 products and all creation sizes fit. Its ten runtime bodies remain
  unexecuted. Read-only investigation found no credible sufficient pure-only
  extraction; held authorization/codec proposals remain unchanged.
- URI fixture repair `4af81efd` and Renderer shape fix `ee7bbb4b` are integrated
  as `c1a0f2c9` and `df440372`. Exactly three expected lengths change from 416
  to the actual twelve-word (384-byte) return; all 50 original ABI entries and
  source/code pins remain. Root matches all 226 frozen sources. Four new actual
  Metadata/DependencyRegistry cases pass, alongside retained cases: 27 distinct
  passes and one large-render capacity failure. The original nine are 8/9.
  Missing exact Safe input was restored and both affected cases pass; the failed
  capture is retained. Full JSON for the 24,576-byte script measures 46.7m gas,
  above the 30m fixture budget and the 16,777,216 transaction cap on Sepolia.
  View-call limits are separate. The newer pure optimization is recorded above;
  full transaction acceptance remains, with no weakened production assertion.
  [Target gas-cap guidance](https://blog.ethereum.org/2025/10/21/fusaka-gascap-update).

The exact collaborator proposal is now complete and independently source-reviewed:
21 paths, including eight authored/uncompiled tests. Its separate specific
approval question is pending, alongside the existing four-patch question. No
rejected production proposal has been applied or compiled.

Earlier checkpoints retain their original status and evidence boundaries:

Latest integrated source `006a16bc` passes all 1,969 Solidity ABI/type/storage
inputs (17.282 seconds, no errors). Client and museum counts remain the separate
304 and 34 root-run cohorts recorded below.

- Native Dutch and clearing same-leaf price consumers `2dc3ea7e` are integrated
  as `fbacfc7d`. Independent join review is clear; 26 new cases are authored and
  runtime-pending. Original signatures/ABI/storage prefixes remain, with one
  appended mapping per host. Selected Dutch runtime is 22,239 bytes; clearing
  is 24,099, execution worker 23,356 and registration worker 4,529. This does not
  complete the separate refund-window or ERC20 price consumers.
- STATIC output manifest `7ae0072c` is integrated as `006a16bc`. Root independently
  matches all 194 captured sources to the commit (CRLF/LF only), reads all nine
  passing results including two 256-input properties, and verifies all 75
  compiled production products fit. The verifier is 14,789 runtime bytes.
  Actual Renderer/content producer/SchemaRegistry/SSTORE2/ArtifactCoverage and
  official Safe participate; Core/route/selection/Artist/archive-family/finality
  authority remain explicit typed boundaries. This preserves every original
  output row's hashes/commitments and canonical interpretation; full rendered
  bytes and publication authority are separate remaining obligations.
- The repaired immediate-price capture `766c5dfd` is independently attested:
  all 312 raw captured sources match Git, all 351 artifact metadata source maps
  match captured source hashes, all 76 tests pass and all 157 production products
  fit. This supersedes the earlier attestation-pending statement below. No
  additional native rerun was needed.

Earlier checkpoints retain their original status and evidence boundaries:

The final source checkpoint in this batch is `40ae52f8`: all 1,959 Solidity
ABI/type/storage inputs pass (17.015 seconds, no errors). It adds the STATIC
full-output producer `4ac22cc2` together with its reviewed gas fix `40ae52f8`.
Original source falsely accepted recovered attribution at a 2,000,000 parent
gas budget; the fixed producer rejects that case and passes both regressions,
including an 18-budget sweep. Its recorded runtime is 16,459 bytes. These tests
use the actual Renderer and producer with typed surrounding dependencies; the
original nine larger recipes and complete current-system acceptance remain
pending. The committed gas test differs from the tested source only by formatter
output. No held Router production change is included.

The exact native-price repair `766c5dfd` now passes 76 cases across eight suites,
including the full 16-counter reader case. The builder attests 312 sources and
157 fitting production products; root is independently verifying the capture.
This supersedes the earlier repaired-source runtime-pending statement below,
without covering the separate Dutch/clearing handoff `2dc3ea7e` or the full graph.

The latest integrated source is `837683ed`. Root passes all 1,954 Solidity
ABI/type/storage inputs (16.937 seconds, no errors), all 304 client tests with
generation/build/type checks, and 34 authority-reconciliation tests. These are
separate evidence sets; no complete-system pass is inferred.

- Free-burn reveal allowances and caller-owned pull credits `9310d6e9` are
  integrated as `8b991c53`. Root matches all 123 captured sources to the commit;
  48 test executions cover 31 distinct cases (inherited cases repeat), with
  64-input fuzzing. Gate runtime is 23,370 bytes and credit library 2,864;
  all 123 production artifacts fit. Actual-current delayed-governance surplus,
  failed recipient/exact Safe retry and preserved buyer-credit tests are
  integrated as `2acb5c3b`; native execution remains pending.
- Original Artist dispute withdrawal, operation 61, is integrated as `57da88e9`.
  Independent source review is clear. Ten Artist/Safe/Archive cases are authored;
  native runtime and combined deployment size remain pending. Complete imported
  dispute histories remain unsupported by the bounded operation60 profile.
- Royalty successor tests are integrated as `a218a205`/`24ca477c`: 12 new cases
  plus two retained cases cover real import/mint/Safe boundaries and malformed
  or stale dependencies. They are authored, not runtime-passing evidence. The
  separately accepted inactive interface/storage scaffold `242c92c9` grants no
  successor-consumer behavior; the rejected production consumer remains unapplied.
- Native immediate same-leaf prices passed a 75-case scoped functional cohort
  at `f1745f33`, whose adapter exceeded the deployment limit. Size repair
  `766c5dfd`, integrated as `84145594`, measures 24,560 runtime bytes for the
  adapter and 16,213 for its worker: both fit, with 16 bytes of adapter margin.
  The exact repaired-source native rerun is pending. Dutch, clearing, refund
  and ERC20 price consumers remain separate work.
- Distribution, burn/refund and native-price callers are integrated as
  `bf4b593a`, `4e31cbf6` and `837683ed`. Price-enabled gate proofs are included.
  Root's 304 passing client tests cover simulated RPC/encoding behavior, not
  deployed Safe or complete current-contract acceptance.
- Museum authority reconciliation `85b473cc` is integrated as `fef4b2f6`.
  Exact retained Getty/VIAF/Wikidata snapshots, qualified drafts, strict recorded
  original review admission and append-only corrections have 34 passing tests.
  Positive authority fixtures are synthetic; actual positive recorded joins,
  Type profile support and wider institutional conformance remain.
- The actual-current stateful driver `2f917fef` adds mandatory counter, replay,
  per-payer conservation and receiver-failure retry coverage. Execution of the
  expanded campaign and seven-case all-CALL Safe host remains pending.

Independent review reproduced a low-parent-gas false-currentness result in the
separate STATIC content producer `9a5c23b0`. Its producer-local correction passes
two isolated actual-Renderer regressions and is under independent source review;
this handoff is not yet integrated. It does not apply the rejected Router cache.

Four exact Artist-size/Router-cache/Royalty-consumer patches are preserved in an
immutable local review bundle. Their specific approval question is pending;
none of the rejected production changes is applied. A separate collaborator
co-signing mutation was also rejected by automatic review. Its incomplete
creation work remains isolated while a reviewable proposal is prepared.

Earlier checkpoints below preserve the source and limits known at their time:

Further integrated source `e7eb51f0` adds native immediate same-leaf Merkle prices,
current ticket/delegation/allowlist input clients (`2d092a4a`) and three more
actual Safe caller/entitlement/receiver retry cases (`ebcff757`). Root passes
all 1,944 Solidity ABI/type/storage inputs and 268 client tests. The new native
price cohort is compiling; the seven-case actual Safe host is authored only.
Gate callers currently retain their exact older false/zero-price scope pending
the additive price caller update.

The final burn `57d70b58` rerun now passes all 49 cases across six suites,
including its two final view-wrapper changes. Root verifies all 306 captured
sources against that commit (CRLF/LF only), and all 301 compiled production
artifacts fit runtime/creation limits. Gate runtime is 21,170 bytes; the native
adapter is 24,322. This replaces the earlier pre-final runtime qualification for
that commit only. Later maximum-allowance and price changes need their own run.
Actual current Core/Artist/governance burn acceptance remains separate.


The preceding integrated source `3520bbb4`: 1,940-source ABI/type/storage checking
passes at `a45c566c`; the later two-file client fix does not change Solidity. This extends the earlier batch below; it does not replace
its retained evidence with a full-system pass.

- Mint lineage/Artist consumption `bba738e9` and fixture `37cb1641` are integrated
  as `31a840cf`/`b172a016`: 101/101 scoped cases, 130 exact captured sources.
  Manager runtime is 24,538 bytes. Eight actual-current governance/Artist/Safe
  cases are integrated as `5b8ee1e7`/`db25251c`, but native execution is pending.
- Burn source `57d70b58` is integrated as `9acd68f7`. Independent source review
  is clear. Its 49-pass capture predates two final sale-ID view-wrapper edits;
  the exact-source rerun is separate. New fixed callback/mint libraries must be
  linked. Free-entry reveal allowance and ERC20 paid burn remain implementation.
- Artist STATIC facts and codec repairs `cc6ebea2` are merged. Selected production
  sizes fit for 12 of 14 products; Attribution and Identity deployment remain
  over the limit. Six independent admission tests are authored in `16a61840`.
- STATIC selection `96f2d6c9` and accepted formatting/Metadata repair `33e56ee2`
  are integrated as `01bc7081`/`099d8ba7`. Source review and ABI checks pass;
  combined deployment/runtime acceptance remains open.
- Royalty clients `a1aef2a3` are integrated as `90ffce0f`, with root 234/234 tests.
  Mint callers `6a816422` are integrated as `a45c566c`, with correction `3520bbb4` for root-identified mutable inspection inputs.
  Root now passes all 256 client tests, generation, build and type checks.
- Transfer capture `b0d91558`, condition package `e4cc727a` and semantic authoring
  `1d23f75a` are integrated as `27bfdf7e`/`64cac28f`/`591db107`. Root separately
  passes 22 institutional/Transfer cases and 19 package/authoring cases. These
  overlap earlier controls and do not prove actual positive onchain records.

Automatic review additionally rejected two Artist size refactors, the STATIC
Router canonical-record cache, and Royalty successor consumption/provenance.
Their exact inert patches are being independently reviewed for one consolidated
specific approval request. None is applied or counted as built. These tooling
restrictions do not withdraw the owner's general delivery authorization.

The mandatory Merkle sale-price consumer is now owned by the mint task; the burn
task owns the free-entry reveal allowance correction. Final combined native
execution waits for deployable Artist/STATIC products. Older compiler/test
captures retain their recorded scope.

Earlier batch evidence follows:

Source through `88cf4522`; all1,909 Solidity sources pass ABI/type/storage checking. All behavioral results below have explicit component boundaries.
The five visible tasks and three local leads remain active; root owns integration.

- Mint source `20cc16a9` integrated `feda72d3`: 87/87 tests across nine suites,
  128 captured sources exactly attested to the commit. Actual Manager/Ledger,
  ModuleRegistry and Safe; typed Core/Artist/governance/external registry. All
  measured products fit; Manager runtime24,538. See [migration](../docs/integrations/mint-continuity.md),
  [counter profiles](../docs/integrations/mint-counter-profiles.md),
  [ticket](../docs/integrations/mint-ticket-gate.md),
  [allowlist](../docs/integrations/mint-allowlist-gate.md) and
  [delegation](../docs/integrations/mint-delegate-registry.md).
- Root Core guard `88cf4522`: eight mint, seven royalty, two Artist-history and
  twelve permanent-target cases pass (29/29,57 sources). Core runtime19,275;
  external-read worker10,971. Real Core with typed producer/governance boundaries;
  exact migration and retained prepared-mint abort behavior are covered.
- Royalty producer fixture `1a9670b8` integrated `c80b68ca`: 11/11 focused cases,
  77 exact captured sources; actual Resolver/Factory/Safe with typed Core/Artist/
  governance. All21 products fit. Failed initial2/9 capture is preserved. Actual
  import/cutover cases remain pending; see [continuity guide](../docs/guides/royalty-economic-continuity.md).
- Entropy direct STATIC getter `8f030e02`:10/10 cases; actual storage fact parity
  and unavailable old-reader independence, all measured products fit. Runtime
  Coordinator24,571 leaves five bytes of headroom.
- Distribution `292cb0f3` integrated `d8f39826`: builder21/21 scoped cases,
  real Safe and64-input fuzz; independent source review clear. Actual-current
  test is authored but native-pending; see [distribution](../docs/guides/operator-distribution.md).
- Client `6a928cda`/`49fda215` integrated `571371e0`/`d013c623`: root220/220 package
  tests, generation, build and type checks pass. Includes exact revenue mutation,
  eight Artist families, generic Safe CALL plans and PLATFORM8–13; no runtime
  Safe acceptance inferred from mocked RPC or independent digest vectors.
- Museum `faa58a49`/`19e64cf3`/`da1a01d8` integrated `7079aa30`/`438cfd00`/`87f844eb`:
  root72/72 institutional, condition, geography, retained loan and owner-capture
  checks pass. New controls are synthetic; actual institutional/title/examination
  joins remain. See [institutional](../docs/museum-institutional-records.md),
  [condition](../docs/museum-condition.md) and [geography](../docs/museum-geography.md).
- Harness source `0b78d6d6` plus entropy repair `2c39c316` and Safe batch `53658f79`
  are integrated. Root21/21 Python checks pass. Interrupted acceptance-20260915-b
  retained no completed compilation/runtime result; it is not acceptance evidence.

At that earlier source checkpoint, Artist and STATIC size repair, successor
consumption, burn and remaining Artist/museum profiles were still incomplete.
The latest batch and feature rows above supersede that implementation queue. The
proposed primary graph-transition ADR has not been adopted into launch scope.
The required economic pointer check is the RSR Royalty replacement guarantee.


The following is the audit trail for the tables, not a new test run. Repository
paths identify source and tests; recorded execution evidence identifies the
accepted source separately. Native compilation pending, a written test and a
passing Python/synthetic control are deliberately kept distinct.


### core.nft evidence

**NFT ownership, approvals, transfers, receiver callbacks and burn**. Owner: Integrator. Requirements: [launch-v1-target-architecture.md](../docs/launch-v1-target-architecture.md).

- [StreamCore.sol](../smart-contracts/core/StreamCore.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStack.t.sol](../test/current/StreamCurrentStack.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentSafe.t.sol](../test/current/StreamCurrentSafe.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### core.collections evidence

**Fixed, capped-open and uncapped collections; global token IDs**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [StreamCore.sol](../smart-contracts/core/StreamCore.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCorePermanentTarget.t.sol](../test/unit/core/StreamCorePermanentTarget.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### core.prepared evidence

**Prepare, complete and abort a mint atomically**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [StreamCore.sol](../smart-contracts/core/StreamCore.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStack.t.sol](../test/current/StreamCurrentStack.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### core.pointers evidence

**Governed modules, permanent Core boundaries and bounded external calls**. Owner: Integrator. Requirements: [launch-v1-target-architecture.md](../docs/launch-v1-target-architecture.md) — Core Hook Budget.

- [StreamCore.sol](../smart-contracts/core/StreamCore.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamModuleRegistry.sol](../smart-contracts/domains/modules/StreamModuleRegistry.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCorePermanentTarget.t.sol](../test/unit/core/StreamCorePermanentTarget.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.static evidence

`0ab60204` adds governed one-way phase freezes. Exact `8f2e9157` has 23 focused native passes (17 Ledger and six configuration), 159 exact sources and 72 fitting production products; current governance11/continuity11 (including three new cases) remain pending. `701263db` adds four reviewed actual snapshot-royalty freeze/successor cases with explicit governed fixture gas settings; their native execution remains pending.

**Static caps, counter subjects and phase-policy grace windows**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [StreamMintLedger.sol](../smart-contracts/domains/mint/StreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintOperationIdentity.sol](../smart-contracts/domains/mint/StreamMintOperationIdentity.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintLedger.t.sol](../test/unit/mint/StreamMintLedger.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.reads evidence

[Advisory preview guide](../docs/integrations/mint-eligibility-preview.md) and
[exact acceptance evidence](MINT_PREVIEW_ACCEPTANCE.md) describe `dc0122af`.
Root verifies all 191 source files, 218 metadata artifacts and 4,249 source
hashes for the 21 passing cases. All 89 nonempty captured production products
fit. This does not validate later counter-read work or the complete current stack.

[Counter-read guide](../docs/integrations/mint-counter-reads.md) and
[counter-read acceptance](MINT_COUNTER_READS_ACCEPTANCE.md) describe `ea92b7d4`.
All fifteen new cases, 194 ABI sources and 155 selected-size sources are reviewed;
old host ABI and nineteen recursive storage roots are preserved. All nine
selected products fit. The corrected combined36 run passes all cases on exact `82f41c88` in305.890
seconds. Root matches all194 source files,221 metadata artifacts and4,470
source hashes; all90 captured production products fit. The original35/1 result
and generated-code test-clock diagnosis are preserved. Actual-current/Safe
acceptance remains separate.
Original requirements remain in [Read API](../docs/mint-policy-and-accounting.md#read-api).

### mint.merkle-caps evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Different wallet allowances from a pinned Merkle root**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [IStreamMintLedger.sol](../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintPhaseState.sol](../smart-contracts/domains/mint/StreamMintPhaseState.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.cross-scope evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Collection-wide and global shared mint counters**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [StreamMintLedger.sol](../smart-contracts/domains/mint/StreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintOperationIdentity.sol](../smart-contracts/domains/mint/StreamMintOperationIdentity.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.continuity evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Preserve mint allowances and replay state across replacement**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [IStreamMintLedger.sol](../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintLedger.sol](../smart-contracts/domains/mint/StreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### governance.roles evidence

**Role registry, Safe authority and bootstrap handover**. Owner: Integrator. Requirements: [0004-admin-governance.md](../docs/adr/0004-admin-governance.md).

- [StreamRoleRegistry.sol](../smart-contracts/domains/governance/StreamRoleRegistry.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamGovernanceBootstrap.sol](../smart-contracts/domains/governance/StreamGovernanceBootstrap.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentGovernanceBootstrap.t.sol](../test/current/StreamCurrentGovernanceBootstrap.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### governance.actions evidence

**Delayed governance actions, cancellation and append-only action catalog**. Owner: Integrator. Requirements: [0004-admin-governance.md](../docs/adr/0004-admin-governance.md); [0024-append-only-governance-catalog.md](../docs/adr/0024-append-only-governance-catalog.md).

- [StreamGovernanceExecutor.sol](../smart-contracts/domains/governance/StreamGovernanceExecutor.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamGovernanceActionPolicy.sol](../smart-contracts/domains/governance/StreamGovernanceActionPolicy.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamNativeCommerceGovernance.t.sol](../test/current/StreamNativeCommerceGovernance.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### governance.parameters evidence

**Governed gas limits and time parameters**. Owner: Integrator. Requirements: [0017-raise-only-parameter-governance.md](../docs/adr/0017-raise-only-parameter-governance.md).

- [StreamGasParameterHost.sol](../smart-contracts/domains/parameters/StreamGasParameterHost.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamTimeParameterHost.sol](../smart-contracts/domains/parameters/StreamTimeParameterHost.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentSafe.t.sol](../test/current/StreamCurrentSafe.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### governance.manifest evidence

**Public system manifest and dependency inventory**. Owner: Integrator. Requirements: [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md) — LCM-GENESIS.

- [StreamSystemManifest.sol](../smart-contracts/domains/governance/StreamSystemManifest.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamGenesisManifestPlan.sol](../script/current/StreamGenesisManifestPlan.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamSystemManifest.t.sol](../test/unit/governance/StreamSystemManifest.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### governance.state-export evidence

**Publish, challenge and supersede reconstructable state exports**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md) — LTA-EXPORT.

- [StreamStateExport.sol](../smart-contracts/domains/governance/StreamStateExport.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStateExport.t.sol](../test/current/StreamCurrentStateExport.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### governance.recovery evidence

**Governed recovery and component cutover**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md); [0020-executor-only-finality-recovery.md](../docs/adr/0020-executor-only-finality-recovery.md).

- [StreamGovernanceRecoveryPolicy.sol](../smart-contracts/domains/governance/StreamGovernanceRecoveryPolicy.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamRecoveryGovernanceComposition.t.sol](../test/unit/governance/StreamRecoveryGovernanceComposition.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamRecoveryCoreRefresh.t.sol](../test/unit/governance/StreamRecoveryCoreRefresh.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### operator.full-genesis evidence

**Deploy and activate the complete full-v1 system**. Owner: Integrator. Requirements: [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md) — LCM-GENESIS.

- [README.md](../script/current/README.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStagedProductActivation.t.sol](../test/current/StreamCurrentStagedProductActivation.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [genesis-deployment-profile.json](../release-artifacts/genesis-deployment-profile.json). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### operator.monitoring evidence

**Operational monitoring, incident response and recovery rehearsal**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md).

- [monitoring.md](../docs/monitoring.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [dependency-operations.md](../docs/dependency-operations.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [README.md](../script/current/README.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.policy evidence

Explicit Artist-consented configuration and terminal non-random token registration:
[policy interface](../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol),
[producer guide](../docs/integrations/explicit-entropy-collection-policy.md), and
[terminal sale handling](../docs/integrations/terminal-entropy-sales.md).
Sources `e7b509ca`, `4010ec2a`, `128c8378` and `86074453`; native evidence is scoped as stated above. See also [terminal consumers](../docs/integrations/terminal-entropy-consumers.md).

### entropy.instant evidence

Required by [EC-INSTANT and EC-CONFIG](../docs/stream-entropy-coordinator.md).
Producer `4010ec2a` has47 focused native passes; commerce `128c8378` and
[INSTANT clients](../packages/stream-client/docs/current-entropy-instant.md)
(`be336ace`) are integrated. Actual-current/Safe, rendering and successor relay
acceptance remain separate from those source-specific passes.

### entropy.registration evidence

**Token and sale/collection-scope randomness registration**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md).

- [StreamEntropyCoordinator.sol](../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropySubjectIdentity.t.sol](../test/unit/entropy/StreamEntropySubjectIdentity.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStack.t.sol](../test/current/StreamCurrentStack.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.fulfillment evidence

**Asynchronous reveal, callback delivery and retry without reroll**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md).

- [StreamEntropyFulfillment.sol](../smart-contracts/domains/entropy/StreamEntropyFulfillment.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyRequestPlan.sol](../smart-contracts/domains/entropy/StreamEntropyRequestPlan.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyMetadata.t.sol](../test/unit/entropy/StreamEntropyMetadata.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.providers evidence

**VRF and ARRNG provider adapters**. Owner: Integrator. Requirements: [stream-entropy-providers.md](../docs/stream-entropy-providers.md).

- [StreamEntropyProviderVRF.sol](../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyProviderARRNG.sol](../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentARRNG.t.sol](../test/current/StreamCurrentARRNG.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.lifecycle evidence

**Admit, suspend, incident-revoke and restore providers**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md) — Provider Registry.

- [StreamEntropyProviderLifecycle.sol](../smart-contracts/domains/entropy/StreamEntropyProviderLifecycle.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyProviderLifecycle.t.sol](../test/unit/entropy/StreamEntropyProviderLifecycle.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentEntropyLifecyclePlan.t.sol](../test/current/StreamCurrentEntropyLifecyclePlan.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.funding evidence

**Reveal fees, quotations, sponsors and pull refunds**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md) — Reveal Ownership And Funding.

- [StreamEntropyCoordinator.sol](../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamRevealFeeEscrow.t.sol](../test/unit/entropy/StreamRevealFeeEscrow.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyProviderFeeQuote.t.sol](../test/unit/entropy/StreamEntropyProviderFeeQuote.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.incidents evidence

**Timeouts, service-level findings and precommitted fresh recovery**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md) — Fresh Entropy Recovery.

- [StreamEntropyFreshRecovery.sol](../smart-contracts/domains/entropy/StreamEntropyFreshRecovery.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyCollectionRecovery.sol](../smart-contracts/domains/entropy/StreamEntropyCollectionRecovery.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyFreshRecovery.t.sol](../test/unit/entropy/StreamEntropyFreshRecovery.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.artist-join evidence

**Real Artist consent and unavailability findings in reveal recovery**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md); [stream-artist-authority.md](../docs/stream-artist-authority.md).

- [StreamArtistEntropyRecoveryJoin.t.sol](../test/unit/artist/StreamArtistEntropyRecoveryJoin.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamArtistEntropyUnavailabilityJoin.t.sol](../test/unit/artist/StreamArtistEntropyUnavailabilityJoin.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyUnavailabilityEvidence.sol](../smart-contracts/domains/entropy/StreamEntropyUnavailabilityEvidence.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### entropy.fallback-continuity evidence

**Coordinator replacement, retained old reads and distinct safe-mode fallback**. Owner: Integrator. Requirements: [stream-entropy-coordinator.md](../docs/stream-entropy-coordinator.md) — Coordinator Replacement And State Continuity.

- [StreamCore.sol](../smart-contracts/core/StreamCore.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamEntropyCoordinator.sol](../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [genesis-deployment-profile.json](../release-artifacts/genesis-deployment-profile.json). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### finality.collection evidence

**Freeze a collection artwork bundle with Artist sanction**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md); [native-finality-provider.md](../docs/integrations/native-finality-provider.md).

- [StreamArtworkFinalityRegistry.sol](../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamFinalityNativeEvidenceProvider.sol](../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamNativeFinalityAssembly.t.sol](../test/current/StreamNativeFinalityAssembly.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### finality.facts evidence

**Reconstruct content, description, conservation and entropy facts**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md).

- [StreamFinalityNativeMetadataFacts.sol](../smart-contracts/domains/finality/StreamFinalityNativeMetadataFacts.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamFinalityInputManifestReads.t.sol](../test/unit/finality/StreamFinalityInputManifestReads.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [finality-input-manifests.md](../docs/integrations/finality-input-manifests.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### finality.membership evidence

**Publish and validate named token-scope membership**. Owner: Integrator. Requirements: [scope-membership.md](../docs/scope-membership.md).

- [StreamScopeMembershipPublication.t.sol](../test/unit/finality/StreamScopeMembershipPublication.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamScopeMembershipCurrentCore.t.sol](../test/unit/finality/StreamScopeMembershipCurrentCore.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [scope-membership.md](../docs/scope-membership.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### finality.all-scopes evidence

**Token, release, season and view finality ceremonies**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md).

- [StreamFinalityNativeEvidenceProvider.sol](../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [native-finality-provider.md](../docs/integrations/native-finality-provider.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [scope-membership.md](../docs/scope-membership.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### finality.recovery evidence

**Recover frozen artwork state and switch serving components**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md); [0020-executor-only-finality-recovery.md](../docs/adr/0020-executor-only-finality-recovery.md).

- [StreamArtworkFinalityRecovery.t.sol](../test/unit/finality/StreamArtworkFinalityRecovery.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamFinalityRecoveryRoutes.t.sol](../test/unit/finality/StreamFinalityRecoveryRoutes.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamFinalityRecoveryScopeMembership.t.sol](../test/unit/finality/StreamFinalityRecoveryScopeMembership.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### finality.hosts evidence

**Retain verifiable content on original or replacement serving hosts**. Owner: Integrator. Requirements: [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md).

- [StreamOnchainContentComposition.t.sol](../test/unit/finality/StreamOnchainContentComposition.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamFinalityServingHostAdapter.t.sol](../test/unit/finality/StreamFinalityServingHostAdapter.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [finality-host-adapters.md](../docs/finality-host-adapters.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### quality.repo evidence

**Developer layout, domain interfaces and contributor documentation**. Owner: Integrator. Requirements: `Owner requirement: clear developer-facing repository`.

- [README.md](../README.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [README.md](../smart-contracts/README.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [architecture.md](../docs/architecture.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [current-stack.md](../docs/current-stack.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [tooling.md](../docs/tooling.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### quality.fuzz evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older inventories below retain their original scope.

**Modern Foundry unit, negative, fuzz and stateful testing system**. Owner: Integrator. Requirements: `Owner requirement: updated testing system and fuzzing`.

- [foundry.toml](../foundry.toml). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStackFuzz.t.sol](../test/current/StreamCurrentStackFuzz.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentStackInvariant.t.sol](../test/current/StreamCurrentStackInvariant.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [tooling.md](../docs/tooling.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### quality.safe evidence

**Safe compatibility for every supported call**. Owner: Integrator. Requirements: `Owner requirement: all calls, not just signing`.

- [SAFE_ACCEPTANCE.md](../ops/SAFE_ACCEPTANCE.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamCurrentSafe.t.sol](../test/current/StreamCurrentSafe.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### quality.capacity evidence

**Full-system gas, deployment size and transaction capacity**. Owner: Integrator. Requirements: [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md).

- [0033-engineering-rehearsals-and-collector-gas.md](../docs/adr/0033-engineering-rehearsals-and-collector-gas.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [V1_CURRENT_STATUS.md](../ops/V1_CURRENT_STATUS.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### quality.ci evidence

**Complete conformance, generated artifacts and CI for the new candidate**. Owner: Integrator. Requirements: [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md).

- [tooling.md](../docs/tooling.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [release-readiness.md](../docs/release-readiness.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### release.rc1 evidence

**Supported RC1 contract release and Sepolia deployment**. Owner: Integrator. Requirements: `Original milestone: frozen tested RC and testnet`.

- [V1_CURRENT_STATUS.md](../ops/V1_CURRENT_STATUS.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [AUTONOMOUS_RUN.md](../ops/AUTONOMOUS_RUN.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### release.full-v1 evidence

**Freeze and launch the complete expanded v1 candidate on testnet**. Owner: Integrator. Requirements: `Owner target: complete v1 plus adopted museum profile`.

- [V1_CURRENT_STATUS.md](../ops/V1_CURRENT_STATUS.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [V1_DELIVERY.md](../ops/V1_DELIVERY.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### release.external evidence

**Independent audit and external/operator acceptance**. Owner: Integrator. Requirements: `Production maturity beyond current pre-audit/testnet target`.

- [audit-package.md](../docs/audit-package.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [release-readiness.md](../docs/release-readiness.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.delegate-registry evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Hot-wallet minting for a vault through a pinned delegation registry**. Owner: Integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — SSA-DELEGATE.

- [IStreamMintGate.sol](../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### revenue.asset-policy evidence

**Approved ERC20 assets, permit policies and non-stranding deprecated exits**. Owner: Revenue builder / Integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md).

- [StreamAssetPolicyRegistry.sol](../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamERC20PrimarySettlementAdapter.sol](../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### metadata.renderer-routing evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Independently selectable, versioned token and collection renderers**. Owner: Integrator. Requirements: [metadata-router-and-renderer.md](../docs/metadata-router-and-renderer.md); [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md) — RENDERER_V1.

- [StreamMetadataRouter.sol](../smart-contracts/domains/metadata/StreamMetadataRouter.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMetadataTokenRenderer.sol](../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [metadata-router-and-renderer.md](../docs/metadata-router-and-renderer.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### ART01 evidence

**Fixed Artist module, seven owners, governed parameters and deployment**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-module; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-perm; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-roles; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-limits; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-interfaces; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-domains.

- [StreamArtistOnboardingRegistry.sol](../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol); [StreamArtistOnboardingCoordinator.sol](../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol); [StreamArtistOwner.sol](../smart-contracts/domains/artist/StreamArtistOwner.sol); [StreamArtistWindowConfiguration.sol](../smart-contracts/domains/artist/StreamArtistWindowConfiguration.sol); [StreamArtistDeploymentSplit.t.sol](../test/unit/artist/StreamArtistDeploymentSplit.t.sol); [StreamArtistOwnerCommit.t.sol](../test/unit/artist/StreamArtistOwnerCommit.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_lifecycle](#cohort-current-lifecycle). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART02 evidence

**Identity registration, documents, revision and personhood/deployment prerequisites**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-identity.

- [StreamArtistIdentityState.sol](../smart-contracts/domains/artist/StreamArtistIdentityState.sol); [StreamArtistIdentityRevisionState.sol](../smart-contracts/domains/artist/StreamArtistIdentityRevisionState.sol); [StreamArtistAttestationSubjectReads.sol](../smart-contracts/domains/artist/StreamArtistAttestationSubjectReads.sol); [StreamArtistOnboarding.t.sol](../test/unit/artist/StreamArtistOnboarding.t.sol); [StreamArtistNonceAvailability.t.sol](../test/unit/artist/StreamArtistNonceAvailability.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_lifecycle](#cohort-current-lifecycle). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART03 evidence

**Two-sided binding proposal, acceptance, refusal and withdrawal**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-binding; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-state.

- [StreamArtistBindingLifecycle.sol](../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol); [StreamArtistAcceptanceLifecycle.sol](../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol); [StreamArtistBindingOperations.sol](../smart-contracts/domains/artist/StreamArtistBindingOperations.sol); [StreamArtistOnboarding.t.sol](../test/unit/artist/StreamArtistOnboarding.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_content](#cohort-current-content). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART04 evidence

**Collaborator identity and complete collaborator acceptance**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-collab.

- [StreamArtistCollaboratorLifecycle.sol](../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol); [StreamArtistCollaboratorIdentityState.sol](../smart-contracts/domains/artist/StreamArtistCollaboratorIdentityState.sol); [StreamArtistCollaboratorOperations.sol](../smart-contracts/domains/artist/StreamArtistCollaboratorOperations.sol); [StreamArtistCollaboratorBindingHash.t.sol](../test/unit/artist/StreamArtistCollaboratorBindingHash.t.sol); [StreamArtistOnboarding.t.sol](../test/unit/artist/StreamArtistOnboarding.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART05 evidence

**Permissionless artist-bound attribution claims**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dispute.

- [StreamArtistAttributionClaimState.sol](../smart-contracts/domains/artist/StreamArtistAttributionClaimState.sol); [StreamArtistAttributionClaimOperations.sol](../smart-contracts/domains/artist/StreamArtistAttributionClaimOperations.sol); [StreamArtistAttributionClaims.t.sol](../test/unit/artist/StreamArtistAttributionClaims.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART06 evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older inventories below retain their original scope.

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Attribution disputes and repudiation**. Owner: Artist lead; integrator. Requirements: [Artist authority](../docs/stream-artist-authority.md), original operations 44–50.

- Integrated `6c8bb4ea` from `63ecfc24`: [dispute guide](../docs/artist-attribution-disputes.md), [interface](../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol), [admission](../smart-contracts/domains/artist/StreamArtistDisputeAdmission.sol), [operations](../smart-contracts/domains/artist/StreamArtistDisputeOperations.sol) and [14 authored cases](../test/unit/artist/StreamArtistAttributionDisputes.t.sol). Original authority, original records/events and permanent replay state are preserved; CAP_DISPUTE is16. Independent source review is clear; 758-source ABI checking and retained ABI/storage checks do not establish runtime acceptance.
- Separate `d95e8aaa2359baa3fde2ae23dd846e86ccb68ab5` handoff adds47–50 with 16 authored cases, guardian veto/current liveness and permanent reason 3 revocation. 767-source ABI check passes and independent source review is clear. Integrated as582b9181; native and joined size acceptance remain pending. Withdrawal remains a distinct missing recipe.

### ART07 evidence

**Live attribution display and exact attestation/deployment reads**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-display.

- [StreamArtistAttributionReadEncoding.sol](../smart-contracts/domains/artist/StreamArtistAttributionReadEncoding.sol); [StreamArtistRegistryReadExtension.sol](../smart-contracts/domains/artist/StreamArtistRegistryReadExtension.sol); [StreamArtistDisplayFacts.t.sol](../test/unit/artist/StreamArtistDisplayFacts.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART08 evidence

**Typed EOA/Safe signatures, nonce/replay and authorization revocation**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-sigver; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-revoke.

- [StreamArtistIdentityState.sol](../smart-contracts/domains/artist/StreamArtistIdentityState.sol); [StreamArtistAuthorizationState.sol](../smart-contracts/domains/artist/StreamArtistAuthorizationState.sol); [StreamArtistNonceAvailability.sol](../smart-contracts/domains/artist/StreamArtistNonceAvailability.sol); [StreamArtistOnboarding.t.sol](../test/unit/artist/StreamArtistOnboarding.t.sol); [StreamArtistAuthorityCheckpoint.t.sol](../test/unit/artist/StreamArtistAuthorityCheckpoint.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_lifecycle](#cohort-current-lifecycle). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART09 evidence

**Delegation grant, revoke and authenticated delegated writes**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-deleg.

- [StreamArtistDelegationState.sol](../smart-contracts/domains/artist/StreamArtistDelegationState.sol); [StreamArtistIdentityState.sol](../smart-contracts/domains/artist/StreamArtistIdentityState.sol); [StreamArtistDelegatedReturn.t.sol](../test/unit/artist/StreamArtistDelegatedReturn.t.sol); [StreamArtistSubjectAttestation.t.sol](../test/unit/artist/StreamArtistSubjectAttestation.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART10 evidence

**Mint policy modes, ratification and optional sale-parameter consent**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-consent; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-sale-consent; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-intent.

- [StreamArtistConsentState.sol](../smart-contracts/domains/artist/StreamArtistConsentState.sol); [StreamArtistSaleOperations.sol](../smart-contracts/domains/artist/StreamArtistSaleOperations.sol); [StreamArtistOnboardingReads.sol](../smart-contracts/domains/artist/StreamArtistOnboardingReads.sol); [StreamArtistOnboarding.t.sol](../test/unit/artist/StreamArtistOnboarding.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_content](#cohort-current-content). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART11 evidence

**Platform Works declaration, contest and corrective Artist generation**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-platform.

- [StreamArtistPlatformState.sol](../smart-contracts/domains/artist/StreamArtistPlatformState.sol); [StreamArtistPlatformOperations.sol](../smart-contracts/domains/artist/StreamArtistPlatformOperations.sol); [StreamArtistPlatformWorks.t.sol](../test/unit/artist/StreamArtistPlatformWorks.t.sol); [StreamArtistPlatformRoyaltySnapshot.t.sol](../test/unit/artist/StreamArtistPlatformRoyaltySnapshot.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART12 evidence

**Artist sanction, scoped finality and confirmation**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-sanction.

- [StreamArtistSanctionState.sol](../smart-contracts/domains/artist/StreamArtistSanctionState.sol); [StreamArtistSanctionOperations.sol](../smart-contracts/domains/artist/StreamArtistSanctionOperations.sol); [StreamArtistSanctionConfirmationState.sol](../smart-contracts/domains/artist/StreamArtistSanctionConfirmationState.sol); [StreamArtistSanctionReviewProfiles.t.sol](../test/unit/artist/StreamArtistSanctionReviewProfiles.t.sol); [StreamArtistSanctionConfirmationReads.t.sol](../test/unit/artist/StreamArtistSanctionConfirmationReads.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART13 evidence

**Finality recovery approval and Artist unavailability finding**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-recovery.

- [StreamArtistRecoveryApprovalState.sol](../smart-contracts/domains/artist/StreamArtistRecoveryApprovalState.sol); [StreamArtistUnavailabilityState.sol](../smart-contracts/domains/artist/StreamArtistUnavailabilityState.sol); [StreamArtistEntropyUnavailabilityAdmission.sol](../smart-contracts/domains/artist/StreamArtistEntropyUnavailabilityAdmission.sol); [StreamArtistRecoveryApprovalScopes.t.sol](../test/unit/artist/StreamArtistRecoveryApprovalScopes.t.sol); [StreamArtistEntropyUnavailabilityJoin.t.sol](../test/unit/artist/StreamArtistEntropyUnavailabilityJoin.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART14 evidence

**State-bound kinds1–10, delegated/steward attestations and detached publication**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-attest; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-intent.

- [StreamArtistAttestationOperations.sol](../smart-contracts/domains/artist/StreamArtistAttestationOperations.sol); [StreamArtistAttestationSubjectReads.sol](../smart-contracts/domains/artist/StreamArtistAttestationSubjectReads.sol); [StreamArtistAttributionAttestations.sol](../smart-contracts/domains/artist/StreamArtistAttributionAttestations.sol); [StreamArtistSubjectAttestation.t.sol](../test/unit/artist/StreamArtistSubjectAttestation.t.sol); [StreamArtistSuccessorSubjectAttestation.t.sol](../test/unit/artist/StreamArtistSuccessorSubjectAttestation.t.sol); [StreamArtistRecordPublicationEnvelope.t.sol](../test/unit/artist/StreamArtistRecordPublicationEnvelope.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART15 evidence

**Payout designation and historical split-right continuity**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-payout; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-splits.

- [StreamArtistPayoutLifecycle.sol](../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol); [StreamArtistProfilePayoutReads.sol](../smart-contracts/domains/artist/StreamArtistProfilePayoutReads.sol); [StreamArtistOnboarding.t.sol](../test/unit/artist/StreamArtistOnboarding.t.sol); [StreamArtistPayoutAuthorityHydration.t.sol](../test/unit/artist/StreamArtistPayoutAuthorityHydration.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_content](#cohort-current-content). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART16 evidence

**Economics consent for live/default/token PROFILE and TEMPLATE assignments**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-econ.

- [StreamArtistEconomicOperations.sol](../smart-contracts/domains/artist/StreamArtistEconomicOperations.sol); [StreamArtistEconomicsHashes.sol](../smart-contracts/domains/artist/StreamArtistEconomicsHashes.sol); [StreamArtistSnapshotRoyaltyConsent.t.sol](../test/unit/artist/StreamArtistSnapshotRoyaltyConsent.t.sol); [StreamArtistDefaultTemplateConsent.t.sol](../test/unit/artist/StreamArtistDefaultTemplateConsent.t.sol); [StreamArtistTemplateMutationConsent.t.sol](../test/unit/artist/StreamArtistTemplateMutationConsent.t.sol); [StreamArtistDynamicTemplateConsent.t.sol](../test/unit/artist/StreamArtistDynamicTemplateConsent.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_content](#cohort-current-content). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART17 evidence

**Original content consent/freeze and explicit entropy consent host**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-content.

- [StreamArtistContentOperations.sol](../smart-contracts/domains/artist/StreamArtistContentOperations.sol); [StreamArtistEntropyUnavailabilityAdmission.sol](../smart-contracts/domains/artist/StreamArtistEntropyUnavailabilityAdmission.sol); [StreamArtistEntropyContentConsent.t.sol](../test/unit/artist/StreamArtistEntropyContentConsent.t.sol); [StreamArtistEntropyRecoveryJoin.t.sol](../test/unit/artist/StreamArtistEntropyRecoveryJoin.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_content](#cohort-current-content). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART18 evidence

**Guardian history, authority rotation, standing and compromise dismissal**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-rotate; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard.

- [StreamArtistRotationState.sol](../smart-contracts/domains/artist/StreamArtistRotationState.sol); [StreamArtistGuardianState.sol](../smart-contracts/domains/artist/StreamArtistGuardianState.sol); [StreamArtistIdentityDismissalState.sol](../smart-contracts/domains/artist/StreamArtistIdentityDismissalState.sol); [StreamArtistGuardianVestingActual.t.sol](../test/unit/artist/StreamArtistGuardianVestingActual.t.sol); [StreamArtistIdentityRecoveryActual.t.sol](../test/unit/artist/StreamArtistIdentityRecoveryActual.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_lifecycle](#cohort-current-lifecycle). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART19 evidence

**Successor/directive records and governed estate activation**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-estate.

- [StreamArtistSuccessionState.sol](../smart-contracts/domains/artist/StreamArtistSuccessionState.sol); [StreamArtistEstateState.sol](../smart-contracts/domains/artist/StreamArtistEstateState.sol); [StreamArtistEstateRecoveryActual.t.sol](../test/unit/artist/StreamArtistEstateRecoveryActual.t.sol); [StreamArtistAcceleratedEstateRecoveryActual.t.sol](../test/unit/artist/StreamArtistAcceleratedEstateRecoveryActual.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [current_estate](#cohort-current-estate). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART20 evidence

**Elected identity recovery, lifetime veto and adjudicated guardian supersession**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard.

- [StreamArtistIdentityRecoveryContext.sol](../smart-contracts/domains/artist/StreamArtistIdentityRecoveryContext.sol); [StreamArtistRecoveryContinuation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryContinuation.sol); [StreamArtistRecoveryEstateRotation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryEstateRotation.sol); [StreamArtistGuardianSupersessionCutoff.sol](../smart-contracts/domains/artist/StreamArtistGuardianSupersessionCutoff.sol); [StreamArtistHistoricalGuardianSupersessionActual.t.sol](../test/unit/artist/StreamArtistHistoricalGuardianSupersessionActual.t.sol); [StreamArtistClosedRepeatedRecoveryActual.t.sol](../test/unit/artist/StreamArtistClosedRepeatedRecoveryActual.t.sol); [StreamArtistEstateHistoryBatchActual.t.sol](../test/unit/artist/StreamArtistEstateHistoryBatchActual.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART21 evidence

**Dormancy lifecycle, artist grant and later steward capability grant**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-estate.

- [StreamArtistDormancyState.sol](../smart-contracts/domains/artist/StreamArtistDormancyState.sol); [StreamArtistStewardSanctionState.sol](../smart-contracts/domains/artist/StreamArtistStewardSanctionState.sol); [StreamArtistStewardCapabilityState.sol](../smart-contracts/domains/artist/StreamArtistStewardCapabilityState.sol); [StreamArtistDormancyLifecycle.t.sol](../test/unit/artist/StreamArtistDormancyLifecycle.t.sol); [StreamArtistStewardSanctionState.t.sol](../test/unit/artist/StreamArtistStewardSanctionState.t.sol); [StreamArtistStewardCapabilities.t.sol](../test/unit/artist/StreamArtistStewardCapabilities.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART22 evidence

**First recovery after designated dormancy and same-head dismissals**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard.

- [StreamArtistRecoveryDormancyPredecessor.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyPredecessor.sol); [StreamArtistRecoveryDormancyClosure.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyClosure.sol); [StreamArtistRecoveryDormancyStanding.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyStanding.sol); [StreamArtistDormancyRecoveryActual.t.sol](../test/unit/artist/StreamArtistDormancyRecoveryActual.t.sol); [StreamArtistClosedDormancyRecoveryActual.t.sol](../test/unit/artist/StreamArtistClosedDormancyRecoveryActual.t.sol); [StreamArtistDormancyStandingHistoryActual.t.sol](../test/unit/artist/StreamArtistDormancyStandingHistoryActual.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART23 evidence

**Designated dormancy followed by executed class3 rotations and first recovery**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard.

- [StreamArtistRecoveryDormancyRotation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotation.sol); [StreamArtistRecoveryDormancyGuardians.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyGuardians.sol); [StreamArtistDormancyRecovery.sol](../smart-contracts/domains/artist/StreamArtistDormancyRecovery.sol); [StreamArtistDormancyRotationRecoveryActual.t.sol](../test/unit/artist/StreamArtistDormancyRotationRecoveryActual.t.sol). Source `49f22c34dac90d444560e88de1d0354ce9cf5525`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART24 evidence

**Closed original dormancy followed by executed rotation and first recovery**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard.

- [StreamArtistRecoveryDormancyRotationOrigin.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotationOrigin.sol); [StreamArtistRecoveryDormancyRotation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotation.sol); [StreamArtistDormancyClosedOriginRotationRecoveryActual.t.sol](../test/unit/artist/StreamArtistDormancyClosedOriginRotationRecoveryActual.t.sol). Source `9ea144c85768050ec910cc8534af13bcac82e20d`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART25 evidence

**Remaining executed-rotation recovery combinations**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-estate.

- [StreamArtistRecoveryContinuation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryContinuation.sol); [StreamArtistRecoveryEstateRotation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryEstateRotation.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART26 evidence

**Adjudicated steward-origin identity recovery**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy.

- [StreamArtistDormancyRecovery.sol](../smart-contracts/domains/artist/StreamArtistDormancyRecovery.sol); [StreamArtistRecoveryDormancyPredecessor.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyPredecessor.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART27 evidence

`9ff19e55` and `ff60c308` add original active-notice dismissal and cancelled-notice histories with 14 and 15 source-reviewed cases respectively. `22e90a3b` adds the complete repeated-living walker and 18 authored cases. `d5e3fbcb` adds seven reviewed current-cause aborted-pending rotation cases. First-recovery/class-3/current-veto and cancelled-Estate predecessor joins and native acceptance remain pending.

**Dormancy-origin supersession and expanded adjudication histories**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy.

- [StreamArtistDormancyRecovery.sol](../smart-contracts/domains/artist/StreamArtistDormancyRecovery.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART28 evidence

**Archive, canonical record preimages, payload catalog and event reconstruction**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-records; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-recon; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-events.

- [StreamArtistArchiveV2.sol](../smart-contracts/domains/artist/StreamArtistArchiveV2.sol); [StreamArtistRegistryHistoryEncoding.sol](../smart-contracts/domains/artist/StreamArtistRegistryHistoryEncoding.sol); [StreamArtistIdentityAuthority.sol](../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol); [StreamArtistReconstructionActual.t.sol](../test/unit/artist/StreamArtistReconstructionActual.t.sol); [StreamArtistDormancyEventReconstruction.t.sol](../test/unit/artist/StreamArtistDormancyEventReconstruction.t.sol); [StreamArtistAuthorityEventReconstruction.t.sol](../test/unit/artist/StreamArtistAuthorityEventReconstruction.t.sol); [StreamArtistHistoryCauseReceipts.t.sol](../test/unit/artist/StreamArtistHistoryCauseReceipts.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [native3](#cohort-native3). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART29 evidence

**History lanes, original55–57 and narrow Core successor admission**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-records.

- [StreamArtistHistoryState.sol](../smart-contracts/domains/artist/StreamArtistHistoryState.sol); [StreamArtistHistoryOperations.sol](../smart-contracts/domains/artist/StreamArtistHistoryOperations.sol); [StreamArtistHistoryProof.sol](../smart-contracts/domains/artist/StreamArtistHistoryProof.sol); [StreamArtistHistoryImport.t.sol](../test/unit/artist/StreamArtistHistoryImport.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [native3](#cohort-native3). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART30 evidence

**Seven-owner complete checkpoint and nonce/replay export**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-records.

- [StreamArtistAuthorityCheckpoint.sol](../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol); [StreamArtistHydrationSourceGuards.sol](../smart-contracts/domains/artist/StreamArtistHydrationSourceGuards.sol); [StreamArtistAuthorityCheckpoint.t.sol](../test/unit/artist/StreamArtistAuthorityCheckpoint.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [native3](#cohort-native3). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART31 evidence

**Operation60 living baseline, payout and direct economics hydration**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import.

- [StreamArtistAuthorityHydrationOperations.sol](../smart-contracts/domains/artist/StreamArtistAuthorityHydrationOperations.sol); [StreamArtistPayoutHydration.sol](../smart-contracts/domains/artist/StreamArtistPayoutHydration.sol); [StreamArtistEconomicsHydration.sol](../smart-contracts/domains/artist/StreamArtistEconomicsHydration.sol); [StreamArtistAuthorityHydration.t.sol](../test/unit/artist/StreamArtistAuthorityHydration.t.sol); [StreamArtistPayoutAuthorityHydration.t.sol](../test/unit/artist/StreamArtistPayoutAuthorityHydration.t.sol); [StreamArtistEconomicsAuthorityHydration.t.sol](../test/unit/artist/StreamArtistEconomicsAuthorityHydration.t.sol); [StreamArtistResolverSuccessor.t.sol](../test/unit/artist/StreamArtistResolverSuccessor.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [native3](#cohort-native3). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART32 evidence

**Operation60 readiness and detached publication hydration/consumers**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-attest; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-content.

- [StreamArtistReadinessHydrationFacts.sol](../smart-contracts/domains/artist/StreamArtistReadinessHydrationFacts.sol); [StreamArtistPublicationHydration.sol](../smart-contracts/domains/artist/StreamArtistPublicationHydration.sol); [StreamArtistReadinessAuthorityHydration.t.sol](../test/unit/artist/StreamArtistReadinessAuthorityHydration.t.sol); [StreamArtistPublicationAuthorityHydration.t.sol](../test/unit/artist/StreamArtistPublicationAuthorityHydration.t.sol); [StreamArtistMetadataPublicationJoin.t.sol](../test/unit/artist/StreamArtistMetadataPublicationJoin.t.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.
- Recorded cohort: [native3](#cohort-native3). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### ART33 evidence

**Operation60 complete entropy finding history hydration**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-recovery.

- [StreamArtistEntropyFindingHydration.sol](../smart-contracts/domains/artist/StreamArtistEntropyFindingHydration.sol); [StreamArtistEntropyFindingHydrationOperations.sol](../smart-contracts/domains/artist/StreamArtistEntropyFindingHydrationOperations.sol); [StreamArtistEntropyUnavailabilityAdmission.sol](../smart-contracts/domains/artist/StreamArtistEntropyUnavailabilityAdmission.sol); [StreamArtistEntropyFindingHydration.t.sol](../test/unit/artist/StreamArtistEntropyFindingHydration.t.sol). Source `fa68860d0d7f285e35288f5529922bd37f46e77e`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART34 evidence

`8cc47857` implements original-living multiple-Artist/multiple-collection hydration with ten source-reviewed current-owner/Safe cases. The delegation successor `48754d47` repairs the new Identity/Coordinator overruns at its exact source: 24,555/24,072 bytes, with all eighteen selected products fitting. Joined-source sizing, native acceptance and broader profiles in this row are still required.

**Migration of multiple identities, collaborators and corrected binding generations**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-collab; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-binding; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-platform.

- [StreamArtistHydrationSourceInventory.sol](../smart-contracts/domains/artist/StreamArtistHydrationSourceInventory.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART35 evidence

`48754d47` adds the [original-living delegation profile](../docs/guides/artist-delegation-authority-hydration.md), ten reviewed actual-owner/Safe recipes and exact history/nonce/consent preservation. All eighteen selected products fit at builder source `0bf8a970`; native execution, joined-source sizing and remaining authority profiles are pending.

**Migration of delegated, rotated, estate, dormancy and recovered authority**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-deleg; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-estate; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy.

- [StreamArtistHydrationSourceInventory.sol](../smart-contracts/domains/artist/StreamArtistHydrationSourceInventory.sol); [StreamArtistIdentityHydration.sol](../smart-contracts/domains/artist/StreamArtistIdentityHydration.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART36 evidence

**Migration of sanctions, sale/freeze/recovery approval and mixed finding histories**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-sanction; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-recovery; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-content; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-sale-consent.

- [StreamArtistHydrationSourceInventory.sol](../smart-contracts/domains/artist/StreamArtistHydrationSourceInventory.sol); [StreamArtistEntropyFindingHydration.sol](../smart-contracts/domains/artist/StreamArtistEntropyFindingHydration.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART37 evidence

**Repeated successor migration and larger complete hydration capacity**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-gates.

- [StreamArtistHydrationSourceInventory.sol](../smart-contracts/domains/artist/StreamArtistHydrationSourceInventory.sol); [StreamArtistAuthorityHydrationOperations.sol](../smart-contracts/domains/artist/StreamArtistAuthorityHydrationOperations.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART38 evidence

**C2PA credential/key-history authorship reconciliation**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-c2pa; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-display.



### ART39 evidence

**Complete Artist signing/recomputation client and measured ceremony rehearsal**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-tooling.



### ART40 evidence

**Full Artist current-graph conformance, limits and operational acceptance**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-gates; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-limits; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-tooling.

- Recorded cohort: [current_lifecycle](#cohort-current-lifecycle). Only the recorded source and named behaviors; later source and unsupported profiles are not validated.


### sales.phase-ledger evidence

**Current mint phases, admission and replay ledger**. Owner: Revenue builder; integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — [MPA-POLICY-HASH, MPA-AUTHZ]; [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-IDENTITY, SSA-ADAPTER].

- [StreamMintManager.sol](../smart-contracts/domains/mint/StreamMintManager.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMintLedger.sol](../smart-contracts/domains/mint/StreamMintLedger.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentMintSetup.t.sol](../test/current/StreamCurrentMintSetup.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.standard-gates evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Concrete allowlist and signed-ticket gate kit**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-AUTH]; [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — [MPA-GATES, MPA-TICKET].

- [StreamMintGateValidator.sol](../smart-contracts/domains/mint/StreamMintGateValidator.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [IStreamMintGate.sol](../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMintTicketHash.sol](../smart-contracts/domains/mint/StreamMintTicketHash.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.merkle-prices evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older inventories below retain their original scope.

**Authenticated per-wallet prices across required sale profiles.** Owner: mint
lead, with revenue ownership for shared settlement. Requirements: MPA-MERKLE
rules 2/3/5 and SSA-AUTH rule 3.

- [Native allowlist price programs](../docs/integrations/native-allowlist-price-programs.md)
  documents the implemented native immediate scope and remaining sale profiles.
- Source `f1745f33` is integrated as `e7eb51f0`. Old Manager/Ledger/adapter ABI
  entries are retained; the adapter appends one policy mapping after burn context.
  Combined root ABI/type/storage checks pass, but native runtime and size are
  pending. Focused tests include the real Manager/Ledger leaf reader and actual
  settlement with typed Manager/Core/Artist boundaries; no full graph claim.

### sales.ticket-revocation evidence

**Complete signed mint authorization revocation**. Owner: Revenue builder; integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — [MPA-TICKET]; [0037-full-payload-mint-authorization-revocation.md](../docs/adr/0037-full-payload-mint-authorization-revocation.md).

- [StreamMintRevocation.sol](../smart-contracts/domains/mint/StreamMintRevocation.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMintTicketHash.sol](../smart-contracts/domains/mint/StreamMintTicketHash.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMintTicketHash.t.sol](../test/unit/revenue/StreamMintTicketHash.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.native-fixed evidence

**Native fixed-price and open-edition sales**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-FIXED, SSA-EDITIONS].

- [StreamNativeFixedPriceSaleAdapter.sol](../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeSettlement.t.sol](../test/current/StreamCurrentNativeSettlement.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [native-primary-settlement.md](../docs/integrations/native-primary-settlement.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.free-pwyw evidence

**Free phases and pay-what-you-want price programs**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-ZERO, SSA-PWYW].

- [StreamNativePriceProgram.sol](../smart-contracts/domains/mint/StreamNativePriceProgram.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamNativeFixedPriceSaleAdapter.sol](../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [current-native-sales.ts](../packages/stream-client/src/current-native-sales.ts). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.english evidence

**Native English auction lifecycle**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-ENGLISH].

- [StreamEnglishAuctionHouse.sol](../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeEnglishAuction.t.sol](../test/current/StreamCurrentNativeEnglishAuction.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.curated evidence

- [Native selected-work guide](../docs/integrations/native-curated-selected-sales.md): source 161cda75, recorder tests 2c9effb4 and refund correction b25b3d16; exact scoped results and current-runtime limits are recorded in the latest parallel batch above.

**Chosen curated-work auction and content selection**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-CONTENT, SSA-ENGLISH].

- [StreamNativeAuctionContentGate.sol](../smart-contracts/domains/auctions/StreamNativeAuctionContentGate.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeCuratedAuction.t.sol](../test/current/StreamCurrentNativeCuratedAuction.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamPreparedNativeContentExecution.sol](../smart-contracts/domains/mint/StreamPreparedNativeContentExecution.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.dutch evidence

**Native descending-price Dutch sales**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-DUTCH].

- [StreamNativeDutchSale.sol](../smart-contracts/domains/mint/StreamNativeDutchSale.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamDutchPricing.sol](../smart-contracts/domains/mint/StreamDutchPricing.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentDutchSale.t.sol](../test/current/StreamCurrentDutchSale.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.clearing evidence

**Uniform-clearing Dutch and buyer rebates**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-DUTCH-CLEARING].

- [StreamNativeClearingSale.sol](../smart-contracts/domains/mint/StreamNativeClearingSale.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentClearingSale.t.sol](../test/current/StreamCurrentClearingSale.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [native-clearing-sales.md](../docs/integrations/native-clearing-sales.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.refund-window evidence

**Native refund-window sales and unconditional escape**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-REFUND].

- [StreamNativeRefundWindowSale.sol](../smart-contracts/domains/mint/StreamNativeRefundWindowSale.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [native-refund-window-sales.md](../docs/integrations/native-refund-window-sales.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.private-offer evidence

**Native private sales and atomic offers**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-PRIVATE, SSA-OFFER].

- [StreamPrivateSaleAdapter.sol](../smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamPrivateSaleOfferExecution.sol](../smart-contracts/domains/mint/StreamPrivateSaleOfferExecution.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentDelegatedOffers.t.sol](../test/current/StreamCurrentDelegatedOffers.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.inventory-consignment evidence

**Secondary inventory and declared consigned resale**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-INVENTORY, SSA-CONSIGN].

- [StreamNativeInventorySale.sol](../smart-contracts/domains/mint/StreamNativeInventorySale.sol). Source `b2fc0c3c`. 017172a0 source reviewed by A; integrated product source. No reviewer native run.
- [StreamNativeInventoryPayment.sol](../smart-contracts/domains/mint/StreamNativeInventoryPayment.sol). Source `b2fc0c3c`. 017172a0 source reviewed by A; integrated product source. No reviewer native run.
- [StreamCurrentSecondaryInventory.t.sol](../test/current/StreamCurrentSecondaryInventory.t.sol). Source `b2fc0c3c`. 017172a0 source reviewed by A; integrated product source. No reviewer native run.


### sales.prepared-custody evidence

**Original prepared acquisition and same-NFT custody sale**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-CUSTODY-ENTRY]; [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Mint-Time Royalty Snapshots.

- [StreamCurrentPreparedCustodySnapshot.t.sol](../test/current/StreamCurrentPreparedCustodySnapshot.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamPreparedNativeMintExecution.sol](../smart-contracts/domains/mint/StreamPreparedNativeMintExecution.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeCustodyAuction.t.sol](../test/current/StreamCurrentNativeCustodyAuction.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.token-rights evidence

**Known-token PROFILE/TEMPLATE and default rights activation**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Assignment Semantics; [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-CUSTODY-ENTRY, SSA-ENGLISH].

- [StreamCurrentTokenProfileCustodyAuction.t.sol](../test/current/StreamCurrentTokenProfileCustodyAuction.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentCustodyRightsBatch.t.sol](../test/current/StreamCurrentCustodyRightsBatch.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentArtistCustodyRights.t.sol](../test/current/StreamCurrentArtistCustodyRights.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.platform-rights evidence

**PLATFORM_WORKS template/custody/known-token rights**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — [RSR-TEMPLATES]; [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-CUSTODY-ENTRY]; [stream-artist-authority.md](../docs/stream-artist-authority.md) — [AA-PLATFORM].

- [StreamCurrentPlatformCustodyAuction.t.sol](../test/current/StreamCurrentPlatformCustodyAuction.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentPlatformTemplateCustody.t.sol](../test/current/StreamCurrentPlatformTemplateCustody.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentPlatformTokenCustody.t.sol](../test/current/StreamCurrentPlatformTokenCustody.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamPlatformTokenPrimary.sol](../smart-contracts/domains/revenue/StreamPlatformTokenPrimary.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.erc20-immediate evidence

**ERC20 immediate sales, PaymentIntent and permits**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — [RSR-PAYMENT-INTENT]; [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-ADAPTER].

- [StreamUniversalFixedPriceSaleAdapter.sol](../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamPermitExecution.sol](../smart-contracts/domains/revenue/StreamPermitExecution.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamUniversalPermits.t.sol](../test/unit/revenue/StreamUniversalPermits.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamUniversalSafe.t.sol](../test/unit/revenue/StreamUniversalSafe.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.erc20-reveal evidence

**Executor-funded native reveal allowance for ERC20 immediate sales**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-REVEAL]; [0045-native-reveal-fees-for-token-sales.md](../docs/adr/0045-native-reveal-fees-for-token-sales.md).

- [0045-native-reveal-fees-for-token-sales.md](../docs/adr/0045-native-reveal-fees-for-token-sales.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.burn-mint evidence

**Current Stream-token burn-to-mint consumer**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-BURN].

- [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [IStreamCoreBurn.sol](../smart-contracts/interfaces/stream/core/IStreamCoreBurn.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- Dedicated ERC20 batch `83c67868` is integrated as `c717a3e1`; see the
  [caller guide](../docs/integrations/erc20-burn-to-mint.md). Independent source
  review covers exact caller/replay, fixed static preview, source authority,
  candidate/result joins and atomic rollback. The 31-source focused gate cohort
  passes all 21 tests. The selected 70-source capture fits all four products;
  eighteen authored current-stack cases remain unexecuted. This source batch
  does not change shared Core, Manager, Ledger, payment adapter or recorder.


### sales.burn-redeem evidence

**Same-transaction burn-to-redeem**. Owner: integrator. Requirements: [SSA-REDEEM and SSA-BURN-FINALITY](../docs/stream-sales-and-auctions.md).

- Integrated `c7f18a83`: [caller guide](../docs/integrations/burn-redemption.md), [interface](../smart-contracts/interfaces/stream/mint/IStreamBurnRedemption.sol), [host](../smart-contracts/domains/mint/StreamBurnRedemption.sol) and [focused suite](../test/unit/mint/StreamBurnRedemption.t.sol).
- Root capture `burn-redemption-native2-20260915` passes 17 tests, including 256 fuzz inputs and real 2-of-2 Safe 1.4.1. Every captured source is verified against `0be87be5`; the capture retains its original base/hash overlay. 28-source compile; 6 production products fit; host runtime 15,876 /creation 19,389 bytes. Immutable terms/window, separate owner/executor approval, original redemption event ABI, retained identity, atomic burn/record rollback and append-only fulfillment history are covered.
- The focused Core boundary uses an ERC721 implementation with explicit identity behavior, and Core/governance/module boundaries are typed substitutes. Actual current Core/operator/governance, cold gas and complete system activation remain pending. Physical fulfillment is an operator's recorded assertion. Burn-to-mint has its separate implementation and remaining acceptance in the preceding row.

### sales.airdrop evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Current operator batch distribution product**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-AIRDROP].

- [IStreamMintManager.sol](../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMintManagerExecution.sol](../smart-contracts/domains/mint/StreamMintManagerExecution.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMinter.sol](../smart-contracts/domains/mint/legacy/StreamMinter.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.factory-wallets evidence

**Canonical split profiles, deterministic wallets and pool**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Split Factory; `[RSR-TEMPLATES]`; `StreamCuratorsPool`.

- [StreamSplitFactory.sol](../smart-contracts/domains/revenue/StreamSplitFactory.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamSplitWallet.sol](../smart-contracts/domains/revenue/StreamSplitWallet.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCuratorsPool.sol](../smart-contracts/domains/revenue/StreamCuratorsPool.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamSplitFactoryRegistration.t.sol](../test/unit/revenue/StreamSplitFactoryRegistration.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.claims evidence

**Split-wallet pull releases and claim aggregation**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — [RSR-RELEASE-AUTH]; `Claim Aggregation Periphery`.

- [StreamSplitWallet.sol](../smart-contracts/domains/revenue/StreamSplitWallet.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamClaimRouter.sol](../smart-contracts/domains/revenue/StreamClaimRouter.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamSplitWalletAuthorization.t.sol](../test/unit/revenue/StreamSplitWalletAuthorization.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamClaimRouter.t.sol](../test/unit/revenue/StreamClaimRouter.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.live-royalties evidence

**Live royalty precedence and explicit token/collection/default overrides**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Royalties; `Assignment Semantics`.

- [StreamRoyaltyResolver.sol](../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamRoyaltyResolver.t.sol](../test/unit/revenue/StreamRoyaltyResolver.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [current-revenue.ts](../packages/stream-client/src/current-revenue.ts). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.snapshots evidence

**Original-mint royalty snapshots including configured-zero/default**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Mint-Time Royalty Snapshots.

- [StreamArtistSnapshotRoyaltyConsent.t.sol](../test/unit/artist/StreamArtistSnapshotRoyaltyConsent.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamArtistPlatformRoyaltySnapshot.t.sol](../test/unit/artist/StreamArtistPlatformRoyaltySnapshot.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentDynamicRoyaltyCommerce.t.sol](../test/current/StreamCurrentDynamicRoyaltyCommerce.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.primary-templates evidence

**Static, poster and paid-collaborator primary materialization**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — [RSR-TEMPLATES].

- [StreamDynamicPrimaryTemplateRules.sol](../smart-contracts/domains/revenue/StreamDynamicPrimaryTemplateRules.sol). Source `b2fc0c3c`. Earlier dynamic148 runtime98PASS/one256; complementary actual Artist/typed Core and actual Core/typed Artist qualification retained.
- [StreamDynamicPrimaryBeneficiaries.sol](../smart-contracts/domains/revenue/StreamDynamicPrimaryBeneficiaries.sol). Source `b2fc0c3c`. Earlier dynamic148 runtime98PASS/one256; complementary actual Artist/typed Core and actual Core/typed Artist qualification retained.
- [dynamic-primary-template-commerce.md](../docs/dynamic-primary-template-commerce.md). Source `b2fc0c3c`. Earlier dynamic148 runtime98PASS/one256; complementary actual Artist/typed Core and actual Core/typed Artist qualification retained.
- [StreamCurrentDynamicRoyaltyCommerce.t.sol](../test/current/StreamCurrentDynamicRoyaltyCommerce.t.sol). Source `b2fc0c3c`. Earlier dynamic148 runtime98PASS/one256; complementary actual Artist/typed Core and actual Core/typed Artist qualification retained.


### revenue.artist-economics evidence

**Artist-approved low-take and exact scoped economics**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Artist Economics Binding; [stream-artist-authority.md](../docs/stream-artist-authority.md) — [AA-ECONOMICS].

- [StreamArtistEconomicOperations.sol](../smart-contracts/domains/artist/StreamArtistEconomicOperations.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [current-revenue.ts](../packages/stream-client/src/current-revenue.ts). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentArtistCustodyRights.t.sol](../test/current/StreamCurrentArtistCustodyRights.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.exact-mutations evidence

**Exact-key TEMPLATE CLEAR and freeze**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Assignment Semantics; [custody-template-and-default-commerce.md](../docs/custody-template-and-default-commerce.md).

- [StreamCurrentTemplateMutationCommerce.t.sol](../test/current/StreamCurrentTemplateMutationCommerce.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [custody-template-and-default-commerce.md](../docs/custody-template-and-default-commerce.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.inherited-freeze evidence

**Inherited/global primary freeze and descendant mutability**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Assignment Semantics; `[RSR-STAGED-GOVERNANCE]`.

- [custody-template-and-default-commerce.md](../docs/custody-template-and-default-commerce.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.resolver-continuity evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Frozen economic continuity on Resolver replacement**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Resolver Replacement And Frozen Economic Continuity.

- [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.artist-lineage evidence

**Retained revenue consumer follows authenticated Artist successor**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Artist Economics Binding; [revenue-artist-successor.md](../docs/integrations/revenue-artist-successor.md).

- [StreamRevenueArtistSelection.sol](../smart-contracts/domains/revenue/StreamRevenueArtistSelection.sol). Source `b2fc0c3c`. da06ebfb production/source review clear. Native3 exact12 ResolverSuccessor PASS; not whole graph acceptance.
- [revenue-artist-successor.md](../docs/integrations/revenue-artist-successor.md). Source `b2fc0c3c`. da06ebfb production/source review clear. Native3 exact12 ResolverSuccessor PASS; not whole graph acceptance.


### revenue.escrow-flush evidence

**Captured owed revenue escrow and ordinary flush**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Primary Sales; `Escrow Lifecycle`.

- [StreamRevenueEscrow.sol](../smart-contracts/domains/revenue/StreamRevenueEscrow.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamRevenueEscrow.t.sol](../test/unit/revenue/StreamRevenueEscrow.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [revenue-escrow.md](../docs/integrations/revenue-escrow.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### revenue.escrow-recovery evidence

**Incident escrow recovery and shared runtime lifecycle**. Owner: revenue lead; integrator. Requirements: [RSR-ESCROW-RECOVERY](../docs/revenue-splits-and-royalties.md) and [ADR0008](../docs/adr/0008-revenue-splits-and-royalty-resolver.md).

- Integrated `663aa5e6` from `ca63bcd9`: [implementation guide](../docs/guides/revenue-runtime-escrow-recovery.md), [runtime registry](../smart-contracts/domains/revenue/StreamRevenueRuntimeRegistry.sol), [escrow host](../smart-contracts/domains/revenue/StreamRevenueEscrow.sol) and [focused recovery tests](../test/unit/revenue/StreamRevenueEscrowRecovery.t.sol). Exact manifests, original credit identity/amount, affected-account consent, factory/runtime status, original notice timing and execution-time rechecks are implemented. Independent source reviews are clear; ordinary ABI/storage are retained.
- Initial `escrow-views-native1-20260915` passes 14 escrow tests and fails3 Safe retry tests. All three reach the expected original failure and GS013, then the helper incorrectly asserts on Foundry's substituted return. Test-only correction `0be87be5` retains exact GS013, signatures, nonce, funding and complete rollback assertions. Root `escrow-retry-native2-20260915` passes all 17 tests in 66.656 seconds, 37 sources and 15 fitting production products; escrow runtime 22,427 /creation 26,117 bytes.
- Actual Factory, wallets, escrow/runtime Registry and threshold Safe interact in this focused suite; governance facts are typed. The two authored actual-governance/Safe cases and full paid-sale-to-incident recovery join remain unexecuted. Onchain notices do not prove private delivery or institutional receipt.

### sales.delegated-authority evidence

**Native delegated offers, claims and refunds**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-DELEGATE] rules8-9.

- [StreamPrivateSaleDelegatedClaims.sol](../smart-contracts/domains/mint/StreamPrivateSaleDelegatedClaims.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamNativeRefundDelegation.sol](../smart-contracts/domains/mint/StreamNativeRefundDelegation.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeRefundDelegation.t.sol](../test/current/StreamCurrentNativeRefundDelegation.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentDelegatedOffers.t.sol](../test/current/StreamCurrentDelegatedOffers.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.surplus evidence

**Native six-host surplus recovery**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-ADAPTER].

- [StreamNativeSurplus.sol](../smart-contracts/domains/mint/StreamNativeSurplus.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamNativeSurplusHost.sol](../smart-contracts/domains/mint/StreamNativeSurplusHost.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeSurplus.t.sol](../test/current/StreamCurrentNativeSurplus.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.owed-export evidence

**Complete historical sale-credit keys and canonical export**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-ADAPTER]; [stream-long-term-architecture.md](../docs/stream-long-term-architecture.md) — [LTA-EXPORT].

- [StreamNativeSaleCreditIndex.sol](../smart-contracts/domains/mint/StreamNativeSaleCreditIndex.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamNativeSaleCreditReads.sol](../smart-contracts/domains/mint/StreamNativeSaleCreditReads.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeSaleCredits.t.sol](../test/current/StreamCurrentNativeSaleCredits.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [current-native-sale-credits.ts](../packages/stream-client/src/current-native-sale-credits.ts). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### client.commerce evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older inventories below retain their original scope.

PLATFORM families 8–13 already have complete bounded typed caller recipes in
[current-platform.ts](../packages/stream-client/src/current-platform.ts) and the
[platform workflow guide](../packages/stream-client/docs/current-platform.md).
The client task reconfirmed 36 focused cases (20 platform and 16 Safe) passing,
also included in root's 347-case suite. Exact TEMPLATE CLEAR/FREEZE recipes are
also present. These are encoding and simulated-RPC results; complete deployed
contract/Safe execution remains required. Neither feature is an unbuilt caller gap.

**Typed native/revenue/secondary and saved inventory workflows**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-GATES]; [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Operator UX.

- [current-secondary.ts](../packages/stream-client/src/current-secondary.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.
- [current-inventory-workflow.ts](../packages/stream-client/src/current-inventory-workflow.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.
- [current-revenue.ts](../packages/stream-client/src/current-revenue.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.
- [current-custody.ts](../packages/stream-client/src/current-custody.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.


### client.entropy-authority evidence

**Explicit entropy finding and op60 hydration Safe client**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Operator UX; [artist-entropy-finding-hydration.md](../docs/guides/artist-entropy-finding-hydration.md).

- [current-entropy-authority.ts](../packages/stream-client/src/current-entropy-authority.ts). Source `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`. Worker commit642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265, direct7209675b. Evidence paths are on that commit.
- [current-entropy-authority.test.mjs](../packages/stream-client/test/current-entropy-authority.test.mjs). Source `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`. Worker commit642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265, direct7209675b. Evidence paths are on that commit.
- [entropy-authority-client.md](../docs/integrations/entropy-authority-client.md). Source `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`. Worker commit642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265, direct7209675b. Evidence paths are on that commit.


### operator.commerce evidence

**Saved governance, mint setup and native surplus plans**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Operator UX; [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-ADAPTER].

- [StreamNativeCommerceDeployment.sol](../script/current/StreamNativeCommerceDeployment.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamNativeSurplusRecoveryPlan.sol](../script/current/StreamNativeSurplusRecoveryPlan.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [PrepareNativeSurplusRecovery.s.sol](../script/current/PrepareNativeSurplusRecovery.s.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamCurrentNativeSurplusRecoveryPlan.t.sol](../test/current/StreamCurrentNativeSurplusRecoveryPlan.t.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### conformance.commerce-gas evidence

**Collector gas, capacity and complete cross-mode conservation**. Owner: Revenue builder; integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — [MPA-GAS-BUDGET]; [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-GAS, SSA-ADAPTER].

- [native-clearing-sales.md](../docs/integrations/native-clearing-sales.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [V1_CURRENT_STATUS.md](../ops/V1_CURRENT_STATUS.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### MUSEUM-01 evidence

**Canonical Core identity and metadata boundaries**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-CORE`; `CMC-SUBJECT-ID`; `CMC-RECORD-CHAIN`; `MSM-SCOPE 1-5`; `MSM-01-SCOPE`.

- [StreamMetadataSubjects.sol](../smart-contracts/domains/metadata/StreamMetadataSubjects.sol); [StreamCollectionRecordHashes.sol](../smart-contracts/domains/records/StreamCollectionRecordHashes.sol); [canonical.py](../tools/museum/canonical.py); [museum-semantic-mapping.md](../docs/museum-semantic-mapping.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-02 evidence

**Immutable schema and interpretation document registry**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-SCHEMA-REGISTRY`; `CMC-RECORD-PAYLOAD`; `CMC-PAYLOAD-POINTERS`; `MSM-PROFILE 2-4,8`; `MSM-02-PROFILE-LOCK`.

- [StreamSchemaRegistry.sol](../smart-contracts/domains/metadata/StreamSchemaRegistry.sol); [StreamSchemaDocumentStore.sol](../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol); [current_museum_capture.py](../tools/museum/current_museum_capture.py); [museum-current-media-capture.md](../docs/museum-current-media-capture.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Actual current foundation/media capture7 and root independent 420-file replay; registry scope does not prove all genesis documents registered.


### MUSEUM-03 evidence

**Current collection record writers and source history**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-AUTHZ`; `CMC-RECORD-PAYLOAD`; `CMC-RECORD-CHAIN`; `CMC-MUTATIONS`; `MSM-ASSERTIONS 1-3`.

- [StreamCollectionMetadataV1.sol](../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol); [StreamMetadataArtistSelection.sol](../smart-contracts/domains/metadata/StreamMetadataArtistSelection.sol); [metadata-records.md](../docs/integrations/metadata-records.md); [StreamArtistMetadataPublicationJoin.t.sol](../test/unit/artist/StreamArtistMetadataPublicationJoin.t.sol). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Actual class-7/8 RIGHTS capture1ed26e68; Metadata focused original suite and successor budget repair tested separately. Root latest joined Artist native results own current join acceptance.


### MUSEUM-04 evidence

**Permanent independent account record lane and ordered capture**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-INDEPENDENT-ATTESTOR`; `CMC-ATTESTATIONS`; `MSM-ASSERTIONS 1-3,9-10`; `MSM-05-AUTHORSHIP`.

- [StreamCollectionAttestations.sol](../smart-contracts/domains/metadata/StreamCollectionAttestations.sol); [independent_source.py](../tools/museum/independent_source.py); [independent_publication.py](../tools/museum/independent_publication.py); [museum-independent-publications.md](../docs/museum-independent-publications.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Retained actual local account capture plus current foundation complete-media and preservation captures; offline replay exists.


### MUSEUM-05 evidence

**Token owner record host and historical evidence adapter**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OWNER-RECORDS`; `CMC-RECORD-PAYLOAD`; `CMC-RECORD-CHAIN`; `MSM-ASSERTIONS 1-3`.

- [StreamOwnerRecords.sol](../smart-contracts/domains/metadata/StreamOwnerRecords.sol); [StreamOwnerRecordSignatures.sol](../smart-contracts/domains/metadata/StreamOwnerRecordSignatures.sol); [owner_record_source.py](../tools/museum/owner_record_source.py); [owner-records.md](../docs/integrations/owner-records.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Owner/source synthetic controls passed; 57ac8d04 adds three actual-current authored cases, ABI clean, no native or positive RPC owner capture yet.


### MUSEUM-06 evidence

**Preservation record host and typed archival producers**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-PREMIS-PROFILE`; `CMC-RECORD-PAYLOAD`; `CMC-OBJECT-DOSSIER`.

- [StreamPreservationRecords.sol](../smart-contracts/domains/preservation/StreamPreservationRecords.sol); [StreamReferenceRenderPublication.sol](../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol); [StreamArchivalCoverage.sol](../smart-contracts/domains/preservation/StreamArchivalCoverage.sol); [preservation-inventory.md](../docs/guides/preservation-inventory.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-07 evidence

**Independent collection views host**. Owner: metadata/museum lead; integrator. Requirements: [collection metadata](../docs/collection-metadata-contract.md), CMC-MUTATIONS and genesis component 29.

- Integrated `63e3236b` from `734d63b1`: [guide](../docs/integrations/collection-views.md), [interface](../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol), [host](../smart-contracts/domains/metadata/StreamCollectionViews.sol) and [focused suite](../test/unit/metadata/StreamCollectionViews.t.sol). Independent source review is clear.
- Root `escrow-views-native1-20260915` passes all 9 CollectionViews cases against actual MetadataV1, SchemaRegistry/document store and threshold Safe. Covers exact full manifest/record identity, revision history,65,536-byte payload/8KiB reads, RAW schema matching, DISPLAY grant classes 7/8, class 8 lock, current selection/ACTIVE status and Safe rollback/retry. The122-source shared capture has 48 fitting production products; Views runtime 16,608 /creation 21,109 bytes; MetadataV1 runtime 24,239 /creation 28,172 bytes.
- Core, Executor and module-registry facts are typed boundaries. Renderer adoption, original Artist interaction and full current genesis activation remain pending. A current metadata view surface does not itself complete STATIC rendering or museum conformance.

### MUSEUM-08 evidence

**Artist, general and notarized attestation museum authority mapping**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-ARTIST-ATTESTATION`; `CMC-ATTESTATIONS`; `CMC-MUSEUM-GRADE`; `MSM-ASSERTIONS 1-10`; `MSM-05-AUTHORSHIP`.

- [StreamArtistAttestationOperations.sol](../smart-contracts/domains/artist/StreamArtistAttestationOperations.sol); [StreamArtistAttestationSubjectReads.sol](../smart-contracts/domains/artist/StreamArtistAttestationSubjectReads.sol); [recorded_semantic.py](../tools/museum/recorded_semantic.py); [museum-recorded-account.md](../docs/museum-recorded-account.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-09 evidence

**Typed work description and format catalog**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-TOMBSTONE`; `CMC-PREMIS-PROFILE 4`; `MSM-MAPPING 1-4,6-10`; `MSM-04-CROSSWALK`.

- [STREAM_WORK_DESCRIPTION_V1.json](../schemas/records/STREAM_WORK_DESCRIPTION_V1.json); [StreamWorkRecordSelection.sol](../smart-contracts/domains/metadata/StreamWorkRecordSelection.sol); [work_profile.py](../tools/metadata/work_profile.py); [work_lido.py](../tools/museum/work_lido.py); [work-description-json-profile.md](../docs/work-description-json-profile.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-10 evidence

**Typed Artist intent, waiver and interview**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-ARTIST-INTENT`; `CMC-GENESIS-SCHEMAS 5`; `MSM-MAPPING 3-4`; `MSM-RELATIONS 1,6`.

- [STREAM_ARTIST_INTENT_V1.json](../schemas/records/STREAM_ARTIST_INTENT_V1.json); [STREAM_ARTIST_INTERVIEW_V1.json](../schemas/records/STREAM_ARTIST_INTERVIEW_V1.json); [StreamConservationRecordSelection.sol](../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol); [StreamConservationRecordReads.sol](../smart-contracts/domains/records/StreamConservationRecordReads.sol); [conservation-record-selection-profile.md](../docs/architecture/conservation-record-selection-profile.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-11 evidence

**Typed RIGHTS interpretation, selection and museum source**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-RIGHTS-SCHEMA`; `MSM-MAPPING 3`; `MSM-RELATIONS 5,7`.

- [StreamRightsRecordJson.sol](../smart-contracts/domains/records/StreamRightsRecordJson.sol); [StreamRightsRecordSelection.sol](../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol); [metadata_rights_source.py](../tools/museum/metadata_rights_source.py); [preservation_resources.py](../tools/museum/preservation_resources.py); [museum-current-rights-capture.md](../docs/museum-current-rights-capture.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Actual local Metadata class-7/8 RIGHTS capture1ed26e68 source-reviewed by root+B; object/rights38 aggregate Python controls, integrator: 14 reproduction. Capture used explicitly unfulfilled/unselected Coordinator reservation.


### MUSEUM-12 evidence

**Steward designation and recovery response/notice records**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OWNER-RECORDS 11-12`; `CMC-GENESIS-SCHEMAS`; `MSM-MAPPING 3`.

- [owner_notice_profile.py](../tools/metadata/owner_notice_profile.py); [StreamOwnerNoticeAdmission.sol](../smart-contracts/domains/records/StreamOwnerNoticeAdmission.sol); [StreamOwnerRecoveryNoticePreparation.sol](../smart-contracts/domains/records/StreamOwnerRecoveryNoticePreparation.sol); [owner-recovery-notices.md](../docs/integrations/owner-recovery-notices.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-13 evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Remaining named owner/institutional record semantic adapters**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OWNER-RECORDS 8-9,13`; `CMC-GENESIS-SCHEMAS`; `MSM-MAPPING 3`; `MSM-RELATIONS 5`.

- [collection-metadata-contract.md](../docs/collection-metadata-contract.md); [owner_record_source.py](../tools/museum/owner_record_source.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-14 evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Full condition report and conservation-treatment mapping**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-GENESIS-SCHEMAS 3`; `CMC-EXHIBITION-LOAN 2`; `MSM-MAPPING 3`; `MSM-RELATIONS 3-6`.

- [loans.py](../tools/museum/loans.py); [condition-schema.json](../test/fixtures/metadata/current-owner-museum/condition-schema.json); [museum-current-owner-capture.md](../docs/museum-current-owner-capture.md). Source `57ac8d041c9adc479f1061fafec748c8330ac974`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-15 evidence

**Native reference render and render-critical archival inventory**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-FINALITY-INPUTS 5`; `CMC-OBJECT-DOSSIER`; `CMC-PACKAGING`; `MSM-RELATIONS 1-4`.

- [StreamReferenceRenderPublication.sol](../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol); [StreamRenderCriticalInventory.sol](../smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol); [native-reference-render.md](../docs/guides/native-reference-render.md); [preservation-inventory.md](../docs/guides/preservation-inventory.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Native reference guide records19 actual IR cases,6 serializer cases and18 offline cases with separately qualified cold/Safe probes. Full museum integration remains partial.


### MUSEUM-16 evidence

**Script/media manifests, large bundles and full snapshot export**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-RECORD-PAYLOAD`; `CMC-SCRIPT-MANIFEST`; `CMC-MEDIA-MANIFEST`; `CMC-OBJECT-DOSSIER`; `MSM-EXPORT 4,9,11`.

- [StreamCollectionManifests.sol](../smart-contracts/domains/metadata/StreamCollectionManifests.sol); [StreamScriptBundles.sol](../smart-contracts/domains/metadata/StreamScriptBundles.sol); [StreamChunkedCollectionSnapshots.sol](../smart-contracts/domains/metadata/StreamChunkedCollectionSnapshots.sol); [chunked_snapshot_profile.py](../tools/metadata/chunked_snapshot_profile.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. 59f8b4c1 bundle and138f1d5f chunked snapshot source independently reviewed. Root manifest cohort13 passed; six chunked composition cases authored/typechecked, execution not claimed here.


### MUSEUM-17 evidence

**Complete object dossier, acquisition packet and canonical citation adapter**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OBJECT-DOSSIER`; `CMC-ACQUISITION-PACKET`; `CMC-CITATION`; `MSM-MAPPING 3`; `MSM-EXPORT 1-4,11`.

- [package_recorded.py](../tools/museum/package_recorded.py); [package_v2.py](../tools/museum/package_v2.py); [bagit.py](../tools/museum/bagit.py); [collection-metadata-contract.md](../docs/collection-metadata-contract.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-18 evidence

**Pinned standards/profile schemas and bounded dependency closure**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-PROFILE 1-8`; `MSM-02-PROFILE-LOCK`; `CMC-GENESIS-SCHEMAS`.

- [schemas.py](../tools/museum/schemas.py); [publication.py](../tools/museum/publication.py); [linked_art.py](../tools/museum/linked_art.py); [STREAM_MUSEUM_SEMANTIC_PROFILE_V1.json](../schemas/museum/STREAM_MUSEUM_SEMANTIC_PROFILE_V1.json); [museum-linked-art-validation.md](../docs/museum-linked-art-validation.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-19 evidence

**Stable entity identity, references and declaration selection**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-IDENTITY 1-8`; `MSM-03-IDENTITY`.

- [identity.py](../tools/museum/identity.py); [semantic_selection.py](../tools/museum/semantic_selection.py); [projection_v2.py](../tools/museum/projection_v2.py); [exhibitions.py](../tools/museum/exhibitions.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-20 evidence

**Field-level crosswalk, semantic validation and full coverage accounting**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-MAPPING 1-10`; `MSM-04-CROSSWALK`.

- [schema_inventory.py](../tools/museum/schema_inventory.py); [vocabulary.py](../tools/museum/vocabulary.py); [projection.py](../tools/museum/projection.py); [projection_v2.py](../tools/museum/projection_v2.py); [museum-abstract-nonvisual-projection.md](../docs/museum-abstract-nonvisual-projection.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-21 evidence

**Attributed assertions, review and conflict selection**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-ASSERTIONS 1-10`; `MSM-05-AUTHORSHIP`.

- [review.py](../tools/museum/review.py); [semantic_selection.py](../tools/museum/semantic_selection.py); [recorded_semantic.py](../tools/museum/recorded_semantic.py); [museum-review-literal.md](../docs/museum-review-literal.md); [museum-recorded-account.md](../docs/museum-recorded-account.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-22 evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older inventories below retain their original scope.

**External authority matching and archived reconciliation**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-AUTHORITIES 1-9`; `MSM-06-AUTHORITIES`.

- [museum-semantic-mapping.md](../docs/museum-semantic-mapping.md); [STREAM_SEMANTIC_ASSERTION_V1.json](../schemas/museum/STREAM_SEMANTIC_ASSERTION_V1.json); [semantic_selection.py](../tools/museum/semantic_selection.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-23 evidence

Latest source and validation: [16 September batch](#parallel-feature-batch-16-september). Older source inventories below retain their original date and do not override the updated table.

**Historical, uncertain and role-specific place semantics**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-PLACES 1-7`; `MSM-07-PLACES`.

- [exhibitions.py](../tools/museum/exhibitions.py); [disputed_geography.json](../schemas/museum/fixtures/disputed_geography.json); [museum-semantic-mapping.md](../docs/museum-semantic-mapping.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-24 evidence

**File roles, observed ingest and physical-event relationships**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-RELATIONS 1-7`; `MSM-08-RELATIONS`.

- [preservation_events.py](../tools/museum/preservation_events.py); [preservation_resources.py](../tools/museum/preservation_resources.py); [preservation_graph.py](../tools/museum/preservation_graph.py); [loans.py](../tools/museum/loans.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-25 evidence

**Deterministic recorded export and database-free offline replay**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-EXPORT 1-12`; `MSM-09-EXPORT`.

- [package_recorded.py](../tools/museum/package_recorded.py); [package_v2.py](../tools/museum/package_v2.py); [chain_rpc.py](../tools/museum/chain_rpc.py); [museum-multiformat-package.md](../docs/museum-multiformat-package.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-26 evidence

**Linked Art and CRM projection**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-MAPPING 1-10`; `MSM-INTEROP 1-5`; `MSM-10-INTEROP`.

- [linked_art.py](../tools/museum/linked_art.py); [projection_v2.py](../tools/museum/projection_v2.py); [recorded_projection.py](../tools/museum/recorded_projection.py); [museum-current-media-capture.md](../docs/museum-current-media-capture.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Actual current complete-media capture7 reconstructs Linked Art with all four formats. Broader graph fixture tests are separately synthetic.


### MUSEUM-27 evidence

**PREMIS file/fixity facts and recorded source adapter**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-PREMIS-PROFILE`; `MSM-INTEROP 1-5`; `MSM-10-INTEROP`.

- [premis.py](../tools/museum/premis.py); [recorded_premis.py](../tools/museum/recorded_premis.py); [museum-recorded-premis.md](../docs/museum-recorded-premis.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Positive current media capture and offline XML replay; no universal preservation conformance claim.


### MUSEUM-28 evidence

**IIIF Presentation3 archival manifest**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-IIIF`; `MSM-INTEROP 1-5`; `MSM-10-INTEROP`.

- [iiif.py](../tools/museum/iiif.py); [recorded_iiif.py](../tools/museum/recorded_iiif.py); [museum-recorded-iiif.md](../docs/museum-recorded-iiif.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Actual complete-media capture7 includes replayed IIIF Manifest; source/presentation absence negative keeps other formats independent.


### MUSEUM-29 evidence

**LIDO1.1 work/media/publisher export**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-TOMBSTONE`; `MSM-INTEROP 1-5`; `MSM-10-INTEROP`.

- [lido.py](../tools/museum/lido.py); [recorded_lido.py](../tools/museum/recorded_lido.py); [museum-recorded-lido.md](../docs/museum-recorded-lido.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Actual current media LIDO positive plus withheld-LIDO-only missing-publisher control; full source/archive replay.


### MUSEUM-30 evidence

**Performed fixity and generic preservation event/report/agent semantics**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-PREMIS-PROFILE`; `MSM-MAPPING 3`; `MSM-RELATIONS 3-4,6`; `MSM-INTEROP`.

- [recorded_fixity.py](../tools/museum/recorded_fixity.py); [preservation_events.py](../tools/museum/preservation_events.py); [current_preservation_capture.py](../tools/museum/current_preservation_capture.py); [museum-preservation-events.md](../docs/museum-preservation-events.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. e3f9d5be performed-check and2c4f68b3 events source reviewed; current local successful/failed SHA256 and copy report capture4724fb70. Root24-event-module reproduction passed.


### MUSEUM-31 evidence

**Preservation objects, rights and activity graph derivatives**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-PREMIS-PROFILE`; `MSM-MAPPING 1,3`; `MSM-RELATIONS 1,5-7`; `MSM-INTEROP`.

- [preservation_resources.py](../tools/museum/preservation_resources.py); [resource_package.py](../tools/museum/resource_package.py); [preservation_graph.py](../tools/museum/preservation_graph.py); [preservation_graph_package.py](../tools/museum/preservation_graph_package.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Object/rights implementation c112d4ce has 14 reproduced focused tests. Recorded activity graph integration bb17874a has 32 passing graph/event tests and retained-package offline replay. Those results do not establish every positive object/event/rights combination in the latest full graph.


### MUSEUM-32 evidence

`5d832333` adds the [owner exhibition flow](../docs/museum-owner-exhibitions.md). All nineteen new source/package/CLI/restore cases pass at the root integration checkout in58.336 seconds. Independent review covers exact original schema/JCS/receipt authority, token/collection joins, cross-source consistency, projection and tamper oracles. Synthetic owner-wire controls remain explicit; actual current-chain capture is pending.

**Typed exhibition semantic dossier**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-EXHIBITION-LOAN 1`; `MSM-MAPPING 3`; `MSM-RELATIONS 5-6`.

- [exhibitions.py](../tools/museum/exhibitions.py); [exhibition_package.py](../tools/museum/exhibition_package.py); [museum-recorded-exhibitions.md](../docs/museum-recorded-exhibitions.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. f81f94f9 source independently clear;14 focused tests passed. Positive admitted-wire fixtures are synthetic, not institutional or actual-chain exhibition integration.


### MUSEUM-33 evidence

**Typed owner loan semantic dossier**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-EXHIBITION-LOAN 2`; `CMC-OWNER-RECORDS`; `MSM-MAPPING 3`; `MSM-RELATIONS 5-6`.

- [loans.py](../tools/museum/loans.py); [loan_package.py](../tools/museum/loan_package.py); [STREAM_LOAN_V1.json](../schemas/museum/loan/STREAM_LOAN_V1.json); [museum-recorded-loans.md](../docs/museum-recorded-loans.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. 66015c2c source root+B clear;15 offline cases. No positive actual OwnerRecords loan capture yet.


### MUSEUM-34 evidence

**Typed valuation and ordered loan-insurance evidence join**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OWNER-RECORDS 10`; `CMC-EXHIBITION-LOAN 2`; `MSM-MAPPING 3`; `MSM-RELATIONS 5`.

- [valuations.py](../tools/museum/valuations.py); [valuation_history.py](../tools/museum/valuation_history.py); [valuation_package.py](../tools/museum/valuation_package.py); [museum-recorded-valuations.md](../docs/museum-recorded-valuations.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. de0469f7 source review clear;21 valuation tests,36 combined loan/valuation tests passed, not actual publication integration.


### MUSEUM-35 evidence

**BagIt, OCFL and offline fetch hydration**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-PACKAGING`; `MSM-EXPORT 4,9-11`.

- [bagit.py](../tools/museum/bagit.py); [ocfl.py](../tools/museum/ocfl.py); [hydration.py](../tools/museum/hydration.py); [museum-bagit-hydration.md](../docs/museum-bagit-hydration.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. e25984e6 BagIt/OCFL plus reviewed casing repair/hydration;27 offline cases reproduced by root; no institutional acceptance inferred.


### MUSEUM-36 evidence

**Actual-current OwnerRecords museum publication/capture recipe**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OWNER-RECORDS`; `CMC-EXHIBITION-LOAN`; `MSM-EXPORT`; `MSM-INTEROP`.

- [StreamCurrentOwnerMuseumCapture.t.sol](../test/current/StreamCurrentOwnerMuseumCapture.t.sol); [current_owner_capture.py](../tools/museum/current_owner_capture.py); [test_current_owner_capture.py](../tools/museum/test_current_owner_capture.py); [museum-current-owner-capture.md](../docs/museum-current-owner-capture.md). Source `57ac8d041c9adc479f1061fafec748c8330ac974`. 57ac8d04:876-source ABI clean3 authored;10 Python PASS4.948s. B one-file Solidity source clear. Qualified offline smoke with retained actual four-format base plus SYNTHETIC owner/history passed full replay; not genuine owner capture.


### MUSEUM-37 evidence

**Semantic authoring, draft confirmation and later-edit workflow**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-AUTHORING 1-5`; `MSM-11-AUTHORING`.

- [museum-semantic-mapping.md](../docs/museum-semantic-mapping.md); [fixtures.py](../tools/museum/fixtures.py); [publication.py](../tools/museum/publication.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-38 evidence

**Complete media/history corpus and institutional conformance**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-CONFORMANCE 1-4`; `MSM-12-INSTITUTIONAL`; `CMC-MUSEUM-GRADE`; `CMC-ACQUISITION-PACKET`.

- [fixtures.py](../tools/museum/fixtures.py); [museum-semantic-mapping.md](../docs/museum-semantic-mapping.md); [launch-conformance-matrix.md](../docs/launch-conformance-matrix.md). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-39 evidence

**Additional preservation/render/finality profiles and dossier state**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-FINALITY-INPUTS`; `CMC-FIXITY-PROGRAM`; `CMC-MUSEUM-GRADE`; `CMC-OBJECT-DOSSIER`.

- [native-reference-render.md](../docs/guides/native-reference-render.md); [preservation-inventory.md](../docs/guides/preservation-inventory.md); [StreamArtworkFinalityRegistry.sol](../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol); [StreamMetadataFinalityServing.sol](../smart-contracts/domains/metadata/StreamMetadataFinalityServing.sol). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-40 evidence

**Complete genesis museum schema catalog and worked examples**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-GENESIS-SCHEMAS 1-5`; `MSM-PROFILE 1-2,8`; `MSM-02-PROFILE-LOCK`.

- [collection-metadata-contract.md](../docs/collection-metadata-contract.md); [STREAM_WORK_DESCRIPTION_V1.json](../schemas/records/STREAM_WORK_DESCRIPTION_V1.json); [STREAM_RIGHTS_V1.json](../schemas/records/STREAM_RIGHTS_V1.json); [STREAM_SEMANTIC_ASSERTION_V1.json](../schemas/museum/STREAM_SEMANTIC_ASSERTION_V1.json). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.

### ART41 evidence

**Multi-party collaborator approval policies.** Owner: Artist builder; integrator. Requirements: [Artist collaborator policy](../docs/stream-artist-authority.md).

- [BindingLifecycle](../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol), source `a0f6535a`: `propose` requires policy mode0, threshold0 and empty capability overrides. Collaborator identity/acceptance does not establish quorum-policy support. This is a source-confirmed gap, not a new scope request.

### ART42 evidence

**Delegated mint-policy and sale-consent mode.** Owner: Artist builder; integrator. Requirements: [Artist consent and delegation](../docs/stream-artist-authority.md).

- `6d333842` adds mode2 through the original binding/delegation/consent producers. Original op14/16 records, signing domains and durable recorded-consent semantics remain. Twenty Artist/current-Safe cases are authored; combined ABI52 and independent source review pass. Native execution, updated clients and Estate helper sizing remain pending.

## Recorded Artist cohorts

### Cohort current-lifecycle

Source `cb8ab7807709e03883f1ef2c51a870f20989a36f`. Five actual-current artist lifecycle cases plus four corrected Dutch and four refund regressions, including the integrated supplemental19 recorder. Actual Core, Manager, artist owners, Archive, RoleRegistry, Executor and threshold Safe1.4.1. Direct36/relayed37 records, all succession read endpoints, exact proof replay; all five provisional families contested before/equal/after original expiry followed by delayed58, stable revision continuation and lazy Payout detachment; exact retirement standing removal and independent fresh-proof guardian authority. External randomness service remains a double. Provider12 is integrated but not yet composed into facade/estate. No estate activation, new clearing consumer or cold deployment gas acceptance.

Recorded exit code: `0`.

Retained local result: `D:/temp/6529stream-v1-delivery-20260911/integration/current-lifecycle13-nonce-corrected-tests.json`.

### Cohort current-content

Source `bcb43e06e352b4bcfbda082bdb35c3eb9c514d94`. Actual current artist operations17/21 and metadata host composition, subsequent Safe paid mint/reveal; all five existing Safe cases including default template catalog. Copied old outputs are cache inputs only, not new test evidence. Solidity0.8.19 optimizer200 Paris viaIR dynamic test linking; not a full repository/release validation.

Recorded exit code: `0`.

Retained local result: `D:/temp/6529stream-v1-delivery-20260911/integration/current-content-safe-composition-tests.json`.

### Cohort current-estate

Source `2d11c0f9bde31570a1cf50ab2eb6d9ff6591c5e3`. Three actual-current estate cases: Core/artist owners/Archive/checkpoint/coverage, real Safe delayed family admissions and RoleRegistry fixity grant; living/governor2of2 and successor2of3 pinnedSafe1.4.1. Request exact180day notice, early rejection, permissionless activation at equality, exactone Identity owner event and preserved binding/current authority/mint-consent read; livingSafe cancellation and consumed request nonce plus fresh retry; wrong coverage rolls both replay lanes back before retry with same direct authorization tuple but changed Safe calldata/digest. Retained Arweave network4byte/native inclusion fixture is authenticated by local observer fixture keys; receipt/fixity are local EOA signatures, not external network quorum/receipt evidence. Initial foundation uses Actor/deployer setup. No actual estate purchase/mint, cold gas, allselectors/versions or full candidate acceptance.

Recorded exit code: `0`.

Retained local result: `D:/temp/6529stream-v1-delivery-20260911/integration/current-estate3-current-stack-tests.json`.

### Cohort native3

Source `b60ae515`. Actual Artist suites/Archive/Safes with typed unit Core/governance; 47 PASS / 16 FAIL. Readiness6, publication7 and genuine Metadata join3 fail in source bootstrap; corrected fixture exists but rerun remains pending. No actual-current Core migration claim.

Retained local result: `D:/temp/6529stream-v1-delivery-20260911/integration/artist-successor-native3-20260915/result.json`.

### Cohort native4

Source `ee0f01599b638ae8437ac794e43d83fe1a2be9f5`. Completed root-owned frozen 28-suite/1,056-source run: **167 passed,39 failed,0 skipped** in 8,688.125 seconds. All647 nonempty production products fit the independent runtime/initcode ceilings. This does not cover subsequent handoffs.

The39 failures are: 14 DormancyStandingHistoryActual; 5 EntropyRecoveryJoin; 1 EntropyUnavailabilityJoin removed testFail-prefix name; 3 MetadataPublicationJoin; 7 PublicationAuthorityHydration; 6 ReadinessAuthorityHydration; 3 current-stack setup failures from unprepared/unpermitted graph artifacts. Artist lead owns the original fixture/preimage/URI/recipe repairs and the test rename. Root owns entropy dependency diagnosis and canonical current-graph artifact preparation, including required full build-info/AST and permissions. No production guard is being relaxed to make a fixture pass.

The original failed result/log/products remain in `D:/temp/6529stream-v1-delivery-20260911/integration/current-artist-native4-20260915`. All former references to this run as pending describe earlier checkpoints; this completed result supersedes them. Later burn, escrow and Views passes are separate captures and do not erase these39 failures.

## Keeping the checklist current

The integrator updates affected rows after each coherent feature batch, using
the existing evidence rather than generating a new governance exercise. Keep
IDs stable. Record the source commit and move Build, Tests and Integration
independently. A new feature or newly discovered gap gets an explicit row.

Do not upgrade a row from a compilation pass, source merge, old fixture or
synthetic example alone. When tests fail, preserve the failed capture and record
the repair/rerun state. The [current delivery narrative](V1_CURRENT_STATUS.md)
and [active assignments](AUTONOMOUS_RUN.md) link here; historical logs retain
their original scope. This document is the common checklist for what remains.
