# Stream feature status

Updated **15 September 2026 (UTC)**. This is the shared feature checklist for
the **complete v1 contract system and the adopted museum proposal**, including
the agreed additions. It replaces informal percentage estimates. The integrator
owns the whole result; domain builders supply implementation and evidence.

**Where we stand:** the supported RC1 is already on Sepolia. The expanded v1
has substantial working code and several demonstrated contract workflows, but
it is not feature-complete or fully integrated. Missing implementation includes
standard mint/delegation gates, shared mint counters and ledger continuity,
burn programs, seven Artist dispute/repudiation operations, broader Artist
migration/recovery, economic recovery/continuity, CollectionViews and parts of
the museum profile. Separately, much recently written code still needs execution
against the complete current system.

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
| Current local and remote integration baseline reviewed | `b2fc0c3cbcee85fb42c90db2d697653788df3706`, branch `codex/v1-integration`; clean and matching remote at inventory start |
| Active delivery PR | Draft [#744](https://github.com/6529-Collections/6529Stream/pull/744); expanded v1 is not merged to main |
| Deployed supported RC1 | `569bf87f1fa808787d324f6e1582924b5ccf1d40`; its Sepolia evidence does not cover the newer branch |
| Unmerged Artist handoff | `49f22c34dac90d444560e88de1d0354ce9cf5525`: designated dormancy followed by executed rotations; ART23 |
| Further unmerged Artist handoff | `9ea144c85768050ec910cc8534af13bcac82e20d`, received during assembly: closed-origin dormancy/rotation extension on the preceding handoff; ART24 |
| Unmerged entropy client handoff | `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`; client.entropy-authority |
| Unmerged actual OwnerRecords capture handoff | `57ac8d041c9adc479f1061fafec748c8330ac974`; MUSEUM-36 |
| Latest broad cheap compilation evidence | 1,803-source ABI/type check passes at `7209675b`; this is not a runtime test |
| Pending native batch | Frozen `ee0f01599b638ae8437ac794e43d83fe1a2be9f5`, 28 suites / 1,056 sources. Still compiling at inventory read; no result claimed. Excludes subsequent finding-hydration, custody and valuation increments. |

Earlier implementation notes use “integrated” to mean source merged. In this
document, that is only **code location**; runtime integration has its own column.
Source paths below are relative to the integration repository unless a handoff
is explicitly named. The snapshot is fixed even while builders continue working.

## Priority work still to build

| Area | Missing implementation / incomplete product | Accountable delivery owner |
| --- | --- | --- |
| Mint eligibility and distribution | Concrete ticket/allowlist and vault-delegation gates, differentiated Merkle caps, collection/global counters, replacement continuity, burn-to-mint/redeem and full airdrop product | Integrator; Revenue builder for sale consumers |
| Artist authority | Dispute/repudiation operations 44–50, advanced rotation/dormancy/recovery combinations, broad history migration, C2PA reconciliation and complete signing ceremonies | Artist builder; integrator owns final integration |
| Revenue | Executor ETH allowance with ERC20 payments, inherited/global freeze, frozen Resolver replacement continuity, runtime/factory lifecycle and incident escrow recovery | Revenue builder; integrator |
| Metadata and permanence | CollectionViews; selectable/versioned renderer interface; remaining required preservation/finality scope profiles; exact genesis implementation correspondence | Metadata/museum builder; integrator |
| Museum | Remaining owner/institutional and conservation mappings, external authority reconciliation, rich geography, semantic authoring, complete schema/profile coverage and institutional conformance | Museum builder; integrator |
| Final delivery | Latest real component joins, all-call Safe inventory, fuzz/stateful campaigns, gas/capacity, complete genesis activation, final CI/source freeze and matching new testnet deployment | Integrator |

The ERC20 native-fee, inherited/global primary-freeze and steward-to-living
patches remain unapplied following earlier automatic approval-review denials.
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

Also: [all 60 Artist operations](#artist-operation-crosswalk), [37 genesis component roles](#genesis-component-crosswalk), [museum requirements and schemas](#museum-requirement-and-schema-crosswalk), [intentional exclusions](#intentional-exclusions-and-later-work), [evidence](#feature-evidence).

These 160 rows are capabilities and delivery checks of different sizes. Row counts are **not** an effort-weighted completion percentage. Crosswalk rows below are references, not extra features.

### Core and mint policy

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [core.nft](#corenft-evidence) NFT ownership, approvals, transfers, receiver callbacks and burn | Built | Partly tested | Partial | Current Core ERC-721 lifecycle, permanent token identity and standard read interfaces. Earlier current-stack/Safe captures demonstrate principal flows. **Remaining:** Rerun on the final combined source; burn-to-mint and physical redemption are separate products. |
| [core.collections](#corecollections-evidence) Fixed, capped-open and uncapped collections; global token IDs | Built | Partly tested | Partial | Collection lifecycle, bounded supply changes, dense global allocation and identity retained after burn/abort. **Remaining:** Final boundary and batch-capacity acceptance on the combined candidate. |
| [core.prepared](#coreprepared-evidence) Prepare, complete and abort a mint atomically | Built | Partly tested | Partial | Manager-only preparation and settlement; entropy registration and receiver failure roll back together. Earlier current tests pass on their recorded source. **Remaining:** Recheck all latest sale, snapshot and reveal combinations. |
| [core.pointers](#corepointers-evidence) Governed modules, permanent Core boundaries and bounded external calls | Built | Partly tested | Partial | Interface/codehash admission, pointer selection, metadata/royalty hooks and gas budgets. **Remaining:** Latest dependency replacement, fallback and full gas acceptance. |
| [mint.static](#mintstatic-evidence) Static caps, counter subjects and phase-policy grace windows | Built | Partly tested | Partial | Static increment/cap engine and recipient, payer, executor, constant and context subjects; phase-bound counters and prior-policy grace. **Remaining:** Final combined policy/replay fuzz campaign; expanded scopes below are not implemented by this row. |
| [mint.merkle-caps](#mintmerkle-caps-evidence) Different wallet allowances from a pinned Merkle root | Not started | Not tested | Not integrated | Mandatory MERKLE_STATIC counter cap mode, distinct from a generic eligibility gate. Current enum has NONE/STATIC/RESOLVER only. **Remaining:** Add proof-bound caps and acceptance through actual Manager and Ledger. |
| [mint.cross-scope](#mintcross-scope-evidence) Collection-wide and global shared mint counters | Not started | Not tested | Not integrated | Mandatory counters shared across phases/collections. Current value-key derivation always binds manager, collection and phase. **Remaining:** Implement explicit collection/GLOBAL scopes, with cross-phase and cross-collection consumption/replay cases. |
| [mint.continuity](#mintcontinuity-evidence) Preserve mint allowances and replay state across replacement | Not started | Not tested | Not integrated | Mandatory Merkle-proofed Manager/Ledger succession. Ordinary policy grace and a new authorized writer are narrower capabilities. **Remaining:** Implement authenticated continuity/import and prove no allowance reset or authorization reuse. |
| [mint.delegate-registry](#mintdelegate-registry-evidence) Hot-wallet minting for a vault through a pinned delegation registry | Not started | Not tested | Not integrated | Mandatory genesis DelegateRegistryGate: bounded live registry checks, hot payer, vault recipient/beneficiary and recipient counters. Sale-side delegated offers do not implement it. **Remaining:** Build gate, pinned registry/configuration, revocation/use-case checks and actual vault/Safe mint scenarios. |

### Sales, auctions and distribution

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [sales.phase-ledger](#salesphase-ledger-evidence) Current mint phases, admission and replay ledger | Built | Partly tested | Partial | Current Manager/ledger, admitted executors, gate protocol, counted prepared and single-step mint operations; not every gate implementation. **Remaining:** Latest full phase/operator/commercial combination and capacity validation; standard gate-kit row remains separate. |
| [sales.standard-gates](#salesstandard-gates-evidence) Concrete allowlist and signed-ticket gate kit | In progress | Partly tested | Not integrated | Generic closed-world gate validation, nullifier/replay transport and original ticket hashes exist. A current deployable standard eligibility allowlist/ticket gate was not found; auction content selection is a different gate. **Remaining:** Implement/identify actual standard gate producers and their current Core/Safe admission/negative cases. Do not treat typed test gates or signature-hash utilities as the product. |
| [sales.ticket-revocation](#salesticket-revocation-evidence) Complete signed mint authorization revocation | Built | Partly tested | Partial | Original authorization IDs and complete-ticket revocation, separate from a gate's positive admission. **Remaining:** Reproduce complete gate/operator/Safe workflows on the final graph; no positive gate implementation inferred. |
| [sales.native-fixed](#salesnative-fixed-evidence) Native fixed-price and open-edition sales | Built | Partly tested | Partial | Current native paid immediate consumer, original Artist/platform signatures, exact settlement and phase accounting. **Remaining:** Latest actual-current transaction/receipt/reveal/capacity acceptance. Earlier accepted current graph captures do not validate all later code. |
| [sales.free-pwyw](#salesfree-pwyw-evidence) Free phases and pay-what-you-want price programs | Built | Partly tested | Partial | Declared zero-price and native chosen-amount/minimum programs; original signature/payment rules retained. **Remaining:** Final actual-current paid/free/reveal/Safe matrix; do not infer arbitrary batch airdrops from a zero-price single mint. |
| [sales.english](#salesenglish-evidence) Native English auction lifecycle | Built | Partly tested | Partial | Reserve/minimum bid/anti-snipe/first-bid start, old exits, escrowed native bids and delayed settlement. **Remaining:** Latest full actual-Artist/Core authority, exits and transaction-capacity acceptance. ERC20 bidding is expressly non-genesis. |
| [sales.curated](#salescurated-evidence) Chosen curated-work auction and content selection | Built | Partly tested | Partial | Explicit immutable curated content leaf/proof and original mint/acquisition coordinates; fixed-price/private selection coverage is not assumed complete. **Remaining:** Remaining selection combinations require source mapping/current runtime; moving-price selection is a later profile. |
| [sales.dutch](#salesdutch-evidence) Native descending-price Dutch sales | Built | Partly tested | Partial | Linear/stepped native schedule and signed maximum/current paid price. **Remaining:** Latest current-core/Safe paid/reveal/royalty composition and collector gas; no generic ERC20 Dutch implementation claimed. |
| [sales.clearing](#salesclearing-evidence) Uniform-clearing Dutch and buyer rebates | Built | Partly tested | Partial | Native clearing book, price fixing, sparse/compressed purchase records, permanent rebates and supplements. **Remaining:** Latest complete conservation/clock/rights/escape runtime. Retained consumer gas measurements exceed 500,000; old 8,755,856 trace was warm-up preceded, not all-cold/current. |
| [sales.refund-window](#salesrefund-window-evidence) Native refund-window sales and unconditional escape | Built | Partly tested | Partial | Original held deposits, finalization/refund/escape clocks and own-account credits. **Remaining:** Final graph settlement/delegation/export/surplus and timing/callback invariant execution; native-only scope explicit. |
| [sales.private-offer](#salesprivate-offer-evidence) Native private sales and atomic offers | Built | Partly tested | Partial | Principal-funded offer/private purchase, owner custody, royalty-itemized secondary receipts, replay and seller/royalty credits. **Remaining:** Execute later actual-current/Safe variants together; ERC20 private/offer obligations need separate normative reconciliation, not an inferred blanket implementation. |
| [sales.inventory-consignment](#salesinventory-consignment-evidence) Secondary inventory and declared consigned resale | Built | Tests written | Not integrated | Immutable sorted original-owner inventory; per-token sale/replay/royalty, genuine previously delivered token resale profile and proceeds claims. **Remaining:** Independent 017172a0 source/oracle review clear; seven authored cases require combined native execution. Prior delivery cannot be inferred merely from MINTED. |
| [sales.prepared-custody](#salesprepared-custody-evidence) Original prepared acquisition and same-NFT custody sale | Built | Partly tested | Partial | Snapshot created at original acquisition; original config/origin/acquisition grants retained and later payment transfers the same NFT. **Remaining:** Final whole current graph plus new rights activations and royalty/reveal invariants; earlier source cohorts are not latest runtime. |
| [sales.token-rights](#salestoken-rights-evidence) Known-token PROFILE/TEMPLATE and default rights activation | Built | Tests written | Not integrated | Pre-bid append-only scoped activation, exact original auction/acquisition IDs and shared consumed/replay; old bid route excluded after activation. **Remaining:** ba0db85d seven actual Artist/Core/Safe source cases integrated as f0e651ef; native execution pending. Do not list token overrides/default templates as absent. |
| [sales.platform-rights](#salesplatform-rights-evidence) PLATFORM_WORKS template/custody/known-token rights | Built | Tests written | Not integrated | Explicit declaration-bound families 8–13, actual original poster, uncontested/correction admission and current actual-token policy; no fake Artist0 consent. **Remaining:** Independently reviewed source; latest native and real declaration/current transaction joining still required. Typed platform client flow remains incomplete. |
| [sales.erc20-immediate](#saleserc20-immediate-evidence) ERC20 immediate sales, PaymentIntent and permits | Built | Partly tested | Partial | Universal original ERC20 payer/executor separation, exact token delta, EIP-2612/Permit2/Safe authorization and settlement; not every native sale-family variant. **Remaining:** Final actual-current ERC20 wallet/asset/full-Safe matrix; reveal fee route below is absent. Do not use old ERC20 fixed-adapter guide's narrower permit boundary as current Universal status. |
| [sales.erc20-reveal](#saleserc20-reveal-evidence) Executor-funded native reveal allowance for ERC20 immediate sales | Not started | Not tested | Not integrated | Separate wei allowance/excess executor credit; token PaymentIntent/Permit2 quantities stay token-only. **Remaining:** Exact inert source/test patch remains unapplied under automatic-review restriction. Owner approved local intent; do not imply shipped or apply denied artifact. |
| [sales.burn-mint](#salesburn-mint-evidence) Current Stream-token burn-to-mint consumer | Not started | Not tested | Not integrated | Required genesis gate/adapter product; current low-level Core burn is not the complete atomic burn/mint/finality/payment workflow. **Remaining:** Root now owns implementation. No current deployable burn-to-mint consumer found in inspected current mint source. |
| [sales.burn-redeem](#salesburn-redeem-evidence) Current burn-to-redeem / physical redemption consumer | Not started | Not tested | Not integrated | Required genesis Stream-token burn/redemption receipt/authorization workflow. **Remaining:** Root now owns implementation. Keep-the-token and external-collection forms are later profiles, not this row. |
| [sales.airdrop](#salesairdrop-evidence) Current operator batch distribution product | In progress | Partly tested | Not integrated | Current Manager supports batched recipient/accounting primitives, but no dedicated current airdrop product/complete operator recipe was identified; legacy airdrop code is excluded. **Remaining:** Resolve supported operator batch path and build/execute complete authorized current distribution; generic primitives alone do not finish SSA-AIRDROP. |
| [sales.delegated-authority](#salesdelegated-authority-evidence) Native delegated offers, claims and refunds | Built | Tests written | Not integrated | Exact immutable/live NFTDelegation witness; principal remains payer/owner for offers; delegated claim/refund destination fixed to credited account; own exits remain independent. **Remaining:** Independent source reviews efd5336d/d3d293ec/77222cc clear. Later13 refund +6 offer/Safe authored cases await combined native; no generic delegated spending authority. |
| [sales.surplus](#salessurplus-evidence) Native six-host surplus recovery | Built | Tests written | Not integrated | Only native balance above all liabilities, including forced ETH; exact current Executor action and dynamic emergency recipient; no ERC20/NFT sweep or owed-credit diversion. **Remaining:** 9db00712 nine authored cases and fixed-worker source review clear; full paid private/English liabilities and final callback/capacity execution remain. |
| [sales.owed-export](#salesowed-export-evidence) Complete historical sale-credit keys and canonical export | Built | Tests written | Not integrated | Producer-owned six-host historical key enumeration reads original ledgers, preserves zeroed keys/retired producers and liabilities; canonical native credit leaf/tree transcript. **Remaining:** 1dcbb865 source/index/client reviews clear;8 authored current recipes pending native. Offchain registry enumeration and anchored full key/owed reconciliation remain required for each export. |

### Revenue and royalties

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [revenue.asset-policy](#revenueasset-policy-evidence) Approved ERC20 assets, permit policies and non-stranding deprecated exits | Built | Partly tested | Partial | Governed standard-token admission and permanent exit grace; asset and permit policy registry source exists. **Remaining:** Final supported asset-family/permit and deprecated-exit acceptance through actual settlement and split wallets. |
| [revenue.factory-wallets](#revenuefactory-wallets-evidence) Canonical split profiles, deterministic wallets and pool | Built | Partly tested | Partial | Canonical account/label shares, deterministic registered/deployed profiles, common wallet identity and curator-pool primitive. **Remaining:** Final all-entry/account asset/deployment/rounding/capacity matrix and actual pool admission; does not include runtime/factory incident lifecycle. |
| [revenue.claims](#revenueclaims-evidence) Split-wallet pull releases and claim aggregation | Built | Partly tested | Partial | Account-directed permissionless releases, original signed redirection/revocation, per-asset accounting and fixed claim router. **Remaining:** Final real-wallet/Safe/ERC20 policy changes, hostile callbacks and full conservation envelope; no generic estate legal entitlement inference. |
| [revenue.live-royalties](#revenuelive-royalties-evidence) Live royalty precedence and explicit token/collection/default overrides | Built | Partly tested | Partial | Actual token > collection > default, configured disabled distinct from absent, maximum cap and original canonical policy hashes. **Remaining:** Final current-token/live-to-snapshot/frozen/callback combination; old narrow fixture results are not all modes. |
| [revenue.snapshots](#revenuesnapshots-evidence) Original-mint royalty snapshots including configured-zero/default | Built | Partly tested | Partial | Collection-specific source-0 consent wrapper, positive/zero frozen token disclosure and original acquisition-time snapshots. **Remaining:** ec06 five actual Artist/Core dynamic/snapshot/same-NFT authored cases are integrated and await native. Prior complementary Artist/Core cohorts passed; not absent product. |
| [revenue.primary-templates](#revenueprimary-templates-evidence) Static, poster and paid-collaborator primary materialization | Built | Partly tested | Partial | Exact source identity, original poster, current Artist/collaborator payouts, per-row coverage and concrete profile/escrow materialization; max64 entries/8 dynamic sources. **Remaining:** dynamic148 accepted98 cases plus one256 property on its exact earlier source; five newer actual-Core/actual-Artist joined cases authored, latest gas/native/capacity pending. |
| [revenue.artist-economics](#revenueartist-economics-evidence) Artist-approved low-take and exact scoped economics | Built | Partly tested | Partial | Original Safe op15 profile/template approval, exact collection/token/default coordinates, low-take and current binding/payout/collaborator requirements. **Remaining:** Execute final fully joined scoped consent/owner installation/settlement tests; Artist consent does not grant owner/global mutation authority. |
| [revenue.exact-mutations](#revenueexact-mutations-evidence) Exact-key TEMPLATE CLEAR and freeze | Built | Tests written | Not integrated | Original exact-key clear/freeze selectors, separate prospective freeze approval and existing precedence after clear. **Remaining:** Final native execution and typed end-to-end CLEAR/exact-FREEZE client recipe. This is not inherited/global freezing. |
| [revenue.inherited-freeze](#revenueinherited-freeze-evidence) Inherited/global primary freeze and descendant mutability | Not started | Not tested | Not integrated | Distinct INHERITED/global freeze modes with required mutable lower-scope accounting; cannot be represented by the existing exact frozen bit. **Remaining:** Specific local implementation remains blocked awaiting exact approval. Do not apply denied source artifacts or call exact-key freeze full conformance. |
| [revenue.resolver-continuity](#revenueresolver-continuity-evidence) Frozen economic continuity on Resolver replacement | Not started | Not tested | Not integrated | Spec's IStreamRevenueResolverContinuity for frozen/snapshot route preservation across replacement; distinct from a retained Resolver following an Artist successor. **Remaining:** No current interface/producer named IStreamRevenueResolverContinuity or equivalent economic continuity manifest found in inspected contracts; implement/prove this dedicated replacement guarantee. |
| [revenue.artist-lineage](#revenueartist-lineage-evidence) Retained revenue consumer follows authenticated Artist successor | Built | Partly tested | Partial | Original immutable Resolver origin and approval state retained; current facade requires authenticated one-predecessor completed seven-owner lineage/current suite and runtime pins. **Remaining:** Root native3 passed all12 ResolverSuccessor cases including8new+4inherited; other joined compact-source fixture paths failed setup and were repaired separately. Final combined successor/current paths remain pending. |
| [revenue.escrow-flush](#revenueescrow-flush-evidence) Captured owed revenue escrow and ordinary flush | Built | Partly tested | Partial | Exact native/ERC20 credit key and captured factory/runtime, normal/verified-wallet flush, producer admission and liability conservation. **Remaining:** Final full native/ERC20 callback/gas/conservation graph; no incident routing or successor factory capability in this base primitive. |
| [revenue.escrow-recovery](#revenueescrow-recovery-evidence) Incident-revoked escrow recovery and successor routing | In progress | Not tested | Not integrated | Missing launch primitive: approved-factory and wallet-runtime ACTIVE/DEPRECATED/INCIDENT_REVOKED lifecycle, original schedule/cancel/execute recovery ABI, identical terms default and affected-account consent or terminal-delay path. Runtime lifecycle also governs new assignments/credits versus retained releases/flushes; escrow-local controls alone do not establish factory-wide assignment conformance. New types/common runtime-registry implementation has begun in the builder working tree; integrated host behavior and tests are not yet present. **Remaining:** B has begun local source implementation after client handoff: exact interface/types and common registry are uncommitted; no host integration or behavioral test yet. Build and authenticate the currently absent factory/runtime lifecycle prerequisite, then recovery. Preserve owed funds, exact expected amount, stored original identity, canonical manifest, onchain affected-account calculation, consent nonces, terminal notice and full execution rechecks. |

### Artist identity, consent and succession

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [ART01](#art01-evidence) Fixed Artist module, seven owners, governed parameters and deployment | Built | Partly tested | Partial | Fixed facade/Coordinator/seven owners/Archive; original EIP-165/domain/storage pins, GGP and implemented rotation/estate/dormancy/unavailability windows. **Remaining:** Latest composed deployment sizes/cold gas and complete manifest/window coverage; repudiation window belongs to the missing dispute family. No full-v1 deployability claim. |
| [ART02](#art02-evidence) Identity registration, documents, revision and personhood/deployment prerequisites | Built | Partly tested | Partial | Canonical identity ID, stored document/display name, revision chain, direct/contract-wallet signatures and original personhood/deployment attestation checks. **Remaining:** Historical authority/import permutations are separate rows; institutional identity truth is intentionally not proved. |
| [ART03](#art03-evidence) Two-sided binding proposal, acceptance, refusal and withdrawal | Built | Partly tested | Partial | Actual primary acceptance; claimed/refused/withdrawn lifecycle and generation/hash pinning, with explicit acceptance prerequisites. **Remaining:** Post-acceptance dispute/revocation/repudiation writes are missing ART06; migration of multiple generations is ART34. |
| [ART04](#art04-evidence) Collaborator identity and complete collaborator acceptance | Built | Tests written | Not integrated | Original collaborator identities, roles/hash arrays, separate primary/collaborator acceptance and payout checks. **Remaining:** New actual-current dynamic commerce composition is authored/root-owned; collaborator migration and complete latest runtime remain pending. |
| [ART05](#art05-evidence) Permissionless artist-bound attribution claims | Built | Tests written | Not integrated | Append-only permissionless evidence claims, combined Artist/Platform claim reads; filing does not itself adjudicate attribution. **Remaining:** Claims are not the missing adjudicated dispute/repudiation workflow. |
| [ART06](#art06-evidence) Attribution dispute, counterstatement, resolution, revocation and repudiation | Not started | Not tested | Not integrated | Canonical operations44–50: open dispute; counterstatement; arbiter resolution; artist revocation; independently vetoable delayed repudiation/cancel/execute. **Remaining:** No corresponding production function occurs in current smart-contracts. Binding refusal/withdrawal, identity compromise, permissionless claims and Platform contests are distinct and do not supply this workflow. |
| [ART07](#art07-evidence) Live attribution display and exact attestation/deployment reads | Built | Tests written | Not integrated | Five-value O(1) attestation status, exact historical signing class, raw binding and sanction reads, deployment reference and combined claim count; Metadata renderer owns projection. **Remaining:** Full live renderer/current-Core matrix and C2PA reconciliation ART38 remain; unknown historical class never defaults to Artist. |
| [ART08](#art08-evidence) Typed EOA/Safe signatures, nonce/replay and authorization revocation | Built | Partly tested | Partial | Original typed domains, bounded ERC1271, retained full signatures, per-identity/acceptance/delegate nonce guards and explicit nonce/digest revocation. **Remaining:** All wallet classes/full negative matrix and carried complex-history guards need remaining profiles; historical passing Safe paths do not validate every signature family. |
| [ART09](#art09-evidence) Delegation grant, revoke and authenticated delegated writes | Built | Tests written | Not integrated | Scoped delegation/revocation and delegated attestation/economics/freeze consumers with exact return-hash and original zero-record Identity chain semantics. **Remaining:** Latest runtime/current-Core joined delegation and migration of active/revoked/delegated histories. |
| [ART10](#art10-evidence) Mint policy modes, ratification and optional sale-parameter consent | Built | Partly tested | Partial | NONE/PER_PHASE/SNAPSHOT policy path, immutable mode election, per-phase and exact sale-configuration consent, collection ratification/current mint prerequisites. **Remaining:** All latest current commerce families and post-migration sale-consent histories; prepared sale adapters remain revenue-owned. |
| [ART11](#art11-evidence) Platform Works declaration, contest and corrective Artist generation | Built | Tests written | Not integrated | Canonical covered declaration; permissionless Platform claim; governed contest/correction; real two-sided corrected binding and saved scope finality selection. Canonical five-word commitment document does not prove narrative content. **Remaining:** Latest actual-current zero-Artist commerce, contested/corrected permutations and Platform history hydration. |
| [ART12](#art12-evidence) Artist sanction, scoped finality and confirmation | Built | Partly tested | Partial | Collection and supported scoped sanction candidates/records/review evidence, original current binding/capability, finality confirmation; steward collection minted/burn-before-appointment guard. **Remaining:** Full latest real Core/Finality/Executor ceremony and all profile combinations; scoped steward sanctions are intentionally excluded. Earlier supported collection ceremony is included under finality.collection; it does not accept these later profiles. |
| [ART13](#art13-evidence) Finality recovery approval and Artist unavailability finding | Built | Partly tested | Not integrated | Original finality recovery approval/scoped reader and actual unavailability lifecycle with activity invalidation; entropy has an explicit separate target/intent profile. **Remaining:** Root native4 has no completed result; live external-provider/current-governance join and mixed finality-finding migration remain. |
| [ART14](#art14-evidence) State-bound kinds1–10, delegated/steward attestations and detached publication | Built | Tests written | Not integrated | Actual subject-owner hashes for generic1–6; detached7/8 publication, deployment9/personhood10, exact persisted class and signatures; eligible delegated/steward authority supported. **Remaining:** Complete native/current-owner subject and wallet matrix; C2PA credential enumeration/reconciliation is ART38. |
| [ART15](#art15-evidence) Payout designation and historical split-right continuity | Built | Partly tested | Partial | Canonical payout heads/history/provisional associations and current beneficiary facts; rotation/recovery does not rewrite balances or historical split recipients. **Remaining:** Complex transitioned payout hydration; financial custody/claims remain revenue-owned. |
| [ART16](#art16-evidence) Economics consent for live/default/token PROFILE and TEMPLATE assignments | Built | Partly tested | Partial | Original op15 exact scope0/1/2 approvals; configured/default/disabled royalty snapshots; static/dynamic template poster/collaborator dependencies; current and prospective SET/CLEAR/FREEZE consent transports. **Remaining:** Newest actual Artist/Core commerce joins and every mode/permutation native; inherited/global-primary-freeze denied implementation remains separate and unapplied. |
| [ART17](#art17-evidence) Original content consent/freeze and explicit entropy consent host | Built | Partly tested | Partial | Original metadata op17/op21 and actual one-use host mutation; additive host-aware op17 entropy family with exact selected Coordinator/runtime/intent. Original content freeze does not authorize new global-freeze semantics. **Remaining:** Entropy joined native4 pending; complete metadata-family/host migration and latest cold gas acceptance. |
| [ART18](#art18-evidence) Guardian history, authority rotation, standing and compromise dismissal | Built | Partly tested | Partial | Two-sided op29, guardian acceleration/veto, executed32, compromise33, prior-standing51, canonical dismissal58 and abandoned/mature provisional cohorts; complete lifetime history. **Remaining:** Full latest rotation/cause/closure combinations and current graph replay after later fixed-worker changes. |
| [ART19](#art19-evidence) Successor/directive records and governed estate activation | Built | Partly tested | Partial | Original designation/directive and legal-document commitments; covered request38, cancellation39, ordinary/accelerated40 and original capability/guardian transition. **Remaining:** Full latest actual estate commerce and all history/permutation acceptance. Original rotated-origin closed op40 remains an unsupported recovery profile ART25. |
| [ART20](#art20-evidence) Elected identity recovery, lifetime veto and adjudicated guardian supersession | Built | Partly tested | Not integrated | Original34/35 with actual registered action/election, Safe acceptance, three receipts and replay; supported living, estate, prior living ancestry, rotated/closed estate and immediate/closed repeated recovery. Arbiter versus Appeal exclusions are distinct. **Remaining:** Unsupported transition combinations are explicit ART25–27; broad actual-current Executor and capacity remain pending. |
| [ART21](#art21-evidence) Dormancy lifecycle, artist grant and later steward capability grant | Built | Tests written | Not integrated | 19 living artist sanction grant; 41 notice, all authenticated activity cancellation42, second governed completion43; original class3/4 appointment and later exact TERMINAL_FREEZE59 permits only economics/sanction bits within directives. **Remaining:** Latest native/current Executor ceremony and complete revoked/provisional profiles. This does not implement steward-origin elected recovery. |
| [ART22](#art22-evidence) First recovery after designated dormancy and same-head dismissals | Built | Tests written | Not integrated | Original op43 class3 origin; original/later kind1 dismissals and kind2 standing attempts; earlier living parent, immutable plan, full lifetime prefix, exact action/Archive retry. **Remaining:** Native4 includes prior standing suite, not later rotated branches. Enumerated dormancy supersession remains unsupported ART27. |
| [ART23](#art23-evidence) Designated dormancy followed by executed class3 rotations and first recovery | Built | Tests written | Not integrated | Committed49f: original unclosed op43 plus one/multiple op32, returning address/intermediate guardian, actual intermediate/terminal closures and first op35. **Unmerged handoff.** **Remaining:** Nine authored cases /752-source ABI only; bounded Revenue builder production review clear; root merge and native/size pending at inventory read. |
| [ART24](#art24-evidence) Closed original dormancy followed by executed rotation and first recovery | Built | Tests written | Not integrated | Committed closed-origin extension: the original kind1/kind2 operation43 closure is authenticated under its appointed principal, separately from terminal/current authority; prior empty-origin proofs remain unchanged. **Unmerged handoff.** **Remaining:** Handoff 9ea144c85768050ec910cc8534af13bcac82e20d on 49f22c34: five new authored cases and 754-source ABI/storage check clean. Independent review of the two production paths is clear; root merge, test review, native execution and size acceptance remain pending. |
| [ART25](#art25-evidence) Remaining executed-rotation recovery combinations | Not started | Not tested | Not integrated | Repeat35 after a legitimate intervening executed rotation/standing head; original closed40 followed by rotation(s); broader mixed repeated authority histories. **Remaining:** Continuation requires latest execution/transition remain prior35; rotated estate proof requires original40 closure empty. No general history walker/profile exists. |
| [ART26](#art26-evidence) Adjudicated steward-origin identity recovery | Not started | Not tested | Not integrated | Explicit adjudicated class4-origin recovery to proved living authority or non-superseded rightful designated class3 successor. **Remaining:** Current elected recovery admits classes1/3, not class4 source. Steward-to-living proposal was blocked by automatic approval review and remains unapplied; no default class relabeling. |
| [ART27](#art27-evidence) Dormancy-origin supersession and expanded adjudication histories | Not started | Not tested | Not integrated | Enumerated supersession during dormancy-origin first recovery and additional complex prior-recovery/appointment authority chains. **Remaining:** Current dormancy path explicitly rejects nonempty supersededRecordHashes. Existing living/estate Arbiter/Appeal supersession does not imply dormancy support. |
| [ART28](#art28-evidence) Archive, canonical record preimages, payload catalog and event reconstruction | Built | Partly tested | Not integrated | Original Archive atomicity; permanent retained payloads, recordPreimageBytes/count/at; exact32/35/40/43 preimages; original19/41–43/59 and execution-context event companions; native receipts include op31/33 Causes. **Remaining:** Complete all-family independent event fold/public recomputation client and imported advanced records remain incomplete; bytes never retained are not reconstructed. |
| [ART29](#art29-evidence) History lanes, original55–57 and narrow Core successor admission | Built | Partly tested | Not integrated | Canonical ordered Artist/collection lanes, committed predecessor root, exact tip proofs, completed seal and immutable read-through prefix; replacement-only Core pin seam. Lane membership alone grants no authority. **Remaining:** Native3 passed scoped actual two-registry tests with typed Core; real-current cutover plus all imported-authority consumer profiles still required. |
| [ART30](#art30-evidence) Seven-owner complete checkpoint and nonce/replay export | Built | Tested* | Not integrated | Current owner headers, enumerated original replay surfaces/origins, typed nonce prefixes and exact dependency checkpoints; rolling roots are not reconstructed from current cells alone. **Remaining:** Passed four exact native3 cases at b60ae515; current later source not independently rerun. Advanced authority exports/imports remain separate. |
| [ART31](#art31-evidence) Operation60 living baseline, payout and direct economics hydration | Built | Tested* | Not integrated | Single original living Artist/accepted generation1 collection, full original policy/revocation guards, optional linear payout and original direct economics dependencies; atomic seven-owner readiness and fresh successor-domain Safe writes. **Remaining:** Scoped native3 passes do not prove actual-current Core migration. No collaborator/transitioned/repeated/oversize import. All guard/dependency completeness is required. |
| [ART32](#art32-evidence) Operation60 readiness and detached publication hydration/consumers | Built | Partly tested | Not integrated | Original52/17/24 direct class1 kinds1–6/9/10 plus explicit7/8 full publication evidence, catalog/signatures/latest heads; successor deployment needs fresh approval; same Metadata consumed map remains authoritative. **Remaining:** Native3 readiness6/publication7/join3 failed at fixture source pin; compact-source repair integrated, native4 pending. Metadata cold proof separately passed23 typed-provider cases; actual-current migration is not demonstrated. |
| [ART33](#art33-evidence) Operation60 complete entropy finding history hydration | Built | Tests written | Not integrated | Original ten-word findings plus exact entropy target/intent/admission/runtime, original-domain origin, complete ordered23 records/latest/activity and both replay cells; current selected intent/epoch still required. **Remaining:** fa688 integrated7209675b; nine source-reviewed tests /787-source ABI,15 distinct selected products fit across recorded captures; native4 predates this feature. Only default timing and complete single-collection living profiles. |
| [ART34](#art34-evidence) Migration of multiple identities, collaborators and corrected binding generations | Not started | Not tested | Not integrated | Multi-Artist/multi-collection state; complete collaborator graphs; corrected/rebound generations, accepted attribution disputes and Platform correction histories. **Remaining:** Current inventory requires one binding/acceptance and one original Artist/collection, with no collaborator owner receipts; explicit complete profiles/consumers are missing. |
| [ART35](#art35-evidence) Migration of delegated, rotated, estate, dormancy and recovered authority | Not started | Not tested | Not integrated | Complete delegation/guardian/provisional/closure/vesting/supersession and original transition chains, with permanent nonce/revocation/veto guards. **Remaining:** Current Identity export profile remains original living with optional54/23; receipts for authority transitions and active delegation are rejected. No readiness from partial imports. |
| [ART36](#art36-evidence) Migration of sanctions, sale/freeze/recovery approval and mixed finding histories | Not started | Not tested | Not integrated | Complete other original record families and host dependencies, including artwork-finality findings or mixed finality/entropy findings, changed timing-action histories. **Remaining:** Current complete inventory admits only original1/2/14/15/17/18/23(entropy)/24/52/54 rows. It does not silently discard unsupported receipts or copy external one-use guards. |
| [ART37](#art37-evidence) Repeated successor migration and larger complete hydration capacity | Not started | Not tested | Not integrated | Source that itself contains imported predecessor state, multiple history generations, complete lazy/bulk or chunked authority hydration beyond current finite envelope. **Remaining:** Current target must have no earlier hydration/native records; explicit128-receipt/512-cell/256-prefix and inline Archive bounds apply. No partial activation to evade limits. |
| [ART38](#art38-evidence) C2PA credential/key-history authorship reconciliation | Not started | Not tested | Not integrated | Operative Artist credential enumeration and validation outcome consistent/divergent/unevaluated against binding and authority history. **Remaining:** Current smart-contracts contain only the generic C2PA record family/metadata references; no actual reconciliation producer/consumer or current attribution outcome. Generic attestations do not supply this rule. |
| [ART39](#art39-evidence) Complete Artist signing/recomputation client and measured ceremony rehearsal | In progress | Partly tested | Not integrated | Typed current Artist SDK and activation scripts exist; B is adding exact entropy-finding/op60 workflow helpers. Full named all-family human-readable signing and independent recomputation tool are not complete. **Remaining:** Resolve all signing facts, explicit stale-consent churn, supported-wallet disclosures, complete record/sanction hash recomputation, actual onboarding→mint→sanction rehearsal with per-ceremony latency and required acknowledgments/runbooks. |
| [ART40](#art40-evidence) Full Artist current-graph conformance, limits and operational acceptance | In progress | Partly tested | Partial | Retained exact current Core/Executor/Safe content/lifecycle/estate subsets and broader typed-unit history/recovery cohorts; root runs one expanded frozen graph. **Remaining:** Latest combined runtime, individual cold gas and complete limit/fuzz/stateful matrix; full ceremony with actual governance and all dependency classes; latest deployment/testnet evidence. No overall full-v1 test/audit claim. |

### Reveal and randomness

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [entropy.registration](#entropyregistration-evidence) Token and sale/collection-scope randomness registration | Built | Partly tested | Partial | Immutable request subjects/inputs, token-versus-scope identity and locked collection configuration. Principal current mint flow has older runtime evidence. **Remaining:** Execute latest Artist consent and all supported sale-scope joins. |
| [entropy.fulfillment](#entropyfulfillment-evidence) Asynchronous reveal, callback delivery and retry without reroll | Built | Partly tested | Partial | Pinned provider requests and seed provenance; failed delivery retains committed entropy and permits retry. **Remaining:** Latest complete provider/Core/Metadata rollback and cold callback acceptance. |
| [entropy.providers](#entropyproviders-evidence) VRF and ARRNG provider adapters | Built | Partly tested | Partial | Both current adapters and focused tests exist; ARRNG actual governance/Safe recipe is implemented. **Remaining:** Verify the final selected real upstream provider configuration and funded testnet callbacks; local/synthetic upstream evidence alone is insufficient. |
| [entropy.lifecycle](#entropylifecycle-evidence) Admit, suspend, incident-revoke and restore providers | Built | Tested* | Partial | Focused capture at 3481e8fd passes 41 native cases and three 256-input fuzz properties. Separate actual Safe lifecycle plan passes 12 cases. **Remaining:** Repeat affected lifecycle cases in the latest complete graph; freeze deployment-specific provider policy. |
| [entropy.funding](#entropyfunding-evidence) Reveal fees, quotations, sponsors and pull refunds | Built | Partly tested | Partial | Coordinator-hosted reveal-fee escrow and provider quote validation with native sale funding; dedicated focused suite included in the 100-case entropy capture. **Remaining:** Latest fee/callback/escrow conservation acceptance. ERC20 executor allowance is separately absent. |
| [entropy.incidents](#entropyincidents-evidence) Timeouts, service-level findings and precommitted fresh recovery | Built | Tested* | Partial | Frozen incident/recovery policies, epochs and collection/token fresh recovery. Recorded focused run passes 100 cases across ten suites, including eight 256-input properties. **Remaining:** Complete latest actual Artist/governance/upstream-provider transaction composition. |
| [entropy.artist-join](#entropyartist-join-evidence) Real Artist consent and unavailability findings in reveal recovery | Built | Tests written | Partial | Actual Artist/Safe/Archive joins and explicit operation-23 unavailable finding source exist; five recovery-join and ten unavailable-join cases await native acceptance. **Remaining:** Run the frozen current batch, then include later complete finding hydration and actual mint/Executor/provider composition. |
| [entropy.fallback-continuity](#entropyfallback-continuity-evidence) Coordinator replacement, retained old reads and distinct safe-mode fallback | In progress | Partly tested | Not integrated | Core pins entropy provenance and fallback roles are specified. The complete distinct-instance safe-mode activation/continuity product is not demonstrated. **Remaining:** Implement or establish the full safe-mode profile, deploy the distinct fallback, and prove old-token reads and fresh-token routing through real cutover. |

### Metadata and records

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [metadata.renderer-routing](#metadatarenderer-routing-evidence) Independently selectable, versioned token and collection renderers | Not started | Not tested | Not integrated | Required IStreamRenderer/RenderRequest selection by default, collection and token is absent. Current fixed linked TokenRenderer/BundleRenderer paths serve supported native content but do not implement this routing surface. **Remaining:** Implement the required renderer contract/interface and versioned read-set selection, then reconcile exact StreamRendererV1 genesis identity. |
| [MUSEUM-01](#museum-01-evidence) Canonical Core identity and metadata boundaries | Built | Partly tested | Integrated* | Current Core subjects, full record preimages and semantic tooling preserve work/token/file and protocol authority boundaries. This is the implemented boundary, not completion of all dependent museum features. **Remaining:** Whole adopted source-family and full-finality acceptance remain; source-preserving adapters do not grant new mint/finality authority. |
| [MUSEUM-02](#museum-02-evidence) Immutable schema and interpretation document registry | Built | Tested* | Integrated* | Registered exact-name/version documents, ordered bounded chunks, full original bytes and canonicalization identity; actual delayed Executor and Safe capture uses these contracts. **Remaining:** Complete required genesis catalog registration and every maximum-size operational envelope remain separate. |
| [MUSEUM-03](#museum-03-evidence) Current collection record writers and source history | Built | Partly tested | Integrated* | MetadataV1 generic class-scoped writers, full payload/receipt/history, independent author heads and one-use Artist publication; sealed complete successor consumption preserves the original host consumed map. **Remaining:** Generic byte admission is not typed meaning for every named record. The newest genuine post-cutover join remains in root native cohort, distinct from earlier demonstrated generic/RIGHTS writes. |
| [MUSEUM-04](#museum-04-evidence) Permanent independent account record lane and ordered capture | Built | Tested* | Integrated* | Actual direct/relayed account receipt/signature/schema/payload capture at a pinned block, original per-lane heads and authenticated receipt/header ordering, renderer firewall preserved. **Remaining:** Historical account authorship does not prove named person/institution identity or qualified reviewer authority; other source lanes require their own adapters. |
| [MUSEUM-05](#museum-05-evidence) Token owner record host and historical evidence adapter | Built | Partly tested | Partial | Original direct/relayed token-owner records, exact 14-word signature envelope, original owner and nonce/chain/signature evidence. Offline adapter currently admits selected embedded LOAN/VALUATION/CONDITION_REPORT wire evidence. **Remaining:** Actual current minted-token museum capture is authored, not executed; full remaining owner-family semantic adapters are absent. Source host support does not supply institutional instruments. |
| [MUSEUM-06](#museum-06-evidence) Preservation record host and typed archival producers | In progress | Partly tested | Partial | PreservationRecords exists; typed reference-render publication, inventory and archival-coverage producers provide selected native paths. The old generic host alone is not a complete full-byte museum record implementation. **Remaining:** Complete generic required preservation/archive family coverage, all applicable inventory/hash methods and full system dossier integration remain. Do not infer a finished museum host from its name. |
| [MUSEUM-07](#museum-07-evidence) Independent collection views host | Not started | Not tested | Not integrated | Adopted StreamCollectionViews surface is named by the specification; no concrete CollectionViews implementation was found in the current contract source. Core collection identity views and MetadataRouter reads are different surfaces. **Remaining:** Implement the specified view host, authority/current-selection behavior and actual integration; root should reconcile any separately owned unmerged implementation. |
| [MUSEUM-08](#museum-08-evidence) Artist, general and notarized attestation museum authority mapping | In progress | Partly tested | Partial | Artist attestation producers and detached publication exist. Actual positive museum captures are demonstrated for bounded independent-account and historical Metadata RIGHTS lanes. Additional Owner/exhibition adapters are built with synthetic controls and positive capture pending; complete Artist/general/institutional/notarized identity semantics remain unmapped. **Remaining:** Add exact actual Artist/general attestation and notarization source/identity/reviewer mappings, current/historical/disputed authority qualifications and complete original evidence; no name or SELF review may substitute. |
| [MUSEUM-09](#museum-09-evidence) Typed work description and format catalog | Built | Partly tested | Partial | Closed bounded WORK_DESCRIPTION JSON interpretation, original shared Artist/curator authority, registered format catalog and fixed selection. Pure work-to-LIDO profile exists; full general actual-record semantic composition remains partial. **Remaining:** Broader faithful work/physical/interactive source coverage and actual current joined exporter acceptance; raw schema presence is not complete semantic mapping. |
| [MUSEUM-10](#museum-10-evidence) Typed Artist intent, waiver and interview | Built | Partly tested | Partial | Full typed intent/waiver/interview and format interpretation, selected original authority/binding/record and interview checks exist in fixed consumers; estate statements remain distinct. **Remaining:** Complete interview/instrument/participant/transcript semantic dossier projection and all admissible source/archival variants remain; raw source schemas and selectors are built. |
| [MUSEUM-11](#museum-11-evidence) Typed RIGHTS interpretation, selection and museum source | Built | Tested* | Integrated* | Exact full RIGHTS JSON, class/family/subject/registered-definition selection and immutable historical receipt capture; separate six-use-class PREMIS/semantic rights output keeps independent links distinct from grants. **Remaining:** Full initialized Artist/Metadata-to-museum positive capture and all later-current selection cases remain separate. Test-fixture legal statements never prove real legal ownership/permission. |
| [MUSEUM-12](#museum-12-evidence) Steward designation and recovery response/notice records | Built | Partly tested | Partial | Typed steward/response schemas and original owner notice/action consumers exist, including bounded incremental endpoint publication and original 72-hour clock. Publisher delivery claims remain claims. **Remaining:** Museum semantic/dossier adapter for these notices and complete operational delivery evidence remain; do not conflate protocol publication with receipt by an institution. |
| [MUSEUM-13](#museum-13-evidence) Remaining named owner/institutional record semantic adapters | Not started | Not tested | Not integrated | No complete museum typed adapter for ACCESSION/TITLE_BINDING, DEACCESSION, REDEMPTION_CLAIM, citation records and their authoritative instruments. Generic record storage does not implement those semantic workflows. **Remaining:** Implement schema/actual-source admission, instrument and original actor binding, exact typed projections and reconstruction; retain title, physical custody, token ownership and accession as separate facts. |
| [MUSEUM-14](#museum-14-evidence) Full condition report and conservation-treatment mapping | Not started | Not tested | Not integrated | Loan adapter retains condition references and bytes; the new local condition fixture deliberately uses an opaque test schema. It is not the required protocol-state/render/fixity/recovery-linked CONDITION_REPORT core. **Remaining:** Implement exact full condition/examination and treatment semantics, actual citation/route/fixity/render/recovery joins, independent and owner evidence, outbound-return comparisons. |
| [MUSEUM-15](#museum-15-evidence) Native reference render and render-critical archival inventory | Built | Tested* | Partial | Finite actual original native onchain COLLECTION plus STATIC/BYTE_EXACT reference publication, executable archive/environment/captures, source inventory and dual-family coverage. Exact raw payload versus artifact/list commitments stay distinct. **Remaining:** PERCEPTUAL_TOLERANCE and CURATED_EQUIVALENCE finality acceptance evidence, supported script/environment closure, noncollection families and additional actual correspondence methods remain; all-program/all-size gas and institutional acceptance absent. DYNAMIC renderer implementation is a later excluded extension. |
| [MUSEUM-16](#museum-16-evidence) Script/media manifests, large bundles and full snapshot export | Built | Partly tested | Partial | Typed current manifests, logical32x24576 script chunks, bounded SSTORE2 append/finalize/full-read and frozen source reconstruction; explicit chunked snapshot embedded JSON and offline export preserve original inline domains. **Remaining:** Full actual upper-bound executable/frozen-route joined acceptance and additional renderer/dependency profiles remain; compact references never count as complete executable export. |
| [MUSEUM-17](#museum-17-evidence) Complete object dossier, acquisition packet and canonical citation adapter | In progress | Partly tested | Partial | Versioned source-bound package builders and many typed derivatives are implemented; they retain exact supplied dossiers and citations. Full canonical acquisition packet/all required dossier item gathering is not complete. **Remaining:** Implement complete actual canonical citation qualifiers, all packet source/attestation/identity/provenance/rights/finality items and their dossier relationships; externally supplied descriptors do not establish completeness. |

### Artwork finality and permanence

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [finality.collection](#finalitycollection-evidence) Freeze a collection artwork bundle with Artist sanction | Built | Partly tested | Partial | Registry, fixed native evidence provider, Artist sanction and finalization ceremony. An earlier actual graph demonstrates one supported collection ceremony. **Remaining:** Repeat on latest source with independent exported evidence and full gas limits. Collection evidence is not proof of other scope types. |
| [finality.facts](#finalityfacts-evidence) Reconstruct content, description, conservation and entropy facts | Built | Partly tested | Partial | Typed source readers, input manifests, image review, provenance and immutable provider/discovery bindings. **Remaining:** Latest complete native source-set and off-chain reconstruction acceptance. |
| [finality.membership](#finalitymembership-evidence) Publish and validate named token-scope membership | Built | Partly tested | Partial | Canonical membership publication, current-Core inventory and capacity tests exist. **Remaining:** Accept final membership producers and connect each supported scope to the full ceremony. |
| [finality.all-scopes](#finalityall-scopes-evidence) Token, release, season and view finality ceremonies | In progress | Partly tested | Not integrated | Enums, scope primitives and membership support exist. Current native evidence provider explicitly accepts COLLECTION only. **Remaining:** Implement non-collection producer composition and demonstrate each complete sanction/finalization/recovery path. |
| [finality.recovery](#finalityrecovery-evidence) Recover frozen artwork state and switch serving components | Built | Partly tested | Partial | Recovery commitments, route validation, retired lifecycles and executor-only ownership primitives exist. **Remaining:** Accept every supported original scope through actual replacement, continuity/reconstruction and retry. |
| [finality.hosts](#finalityhosts-evidence) Retain verifiable content on original or replacement serving hosts | Built | Partly tested | Partial | Core/finality adapters, current source inventory, on-chain content checkpoints and serving-host checks. **Remaining:** Final independent byte reconstruction and migration against all supported artwork profiles. |

### Museum mapping, export and authoring

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [MUSEUM-18](#museum-18-evidence) Pinned standards/profile schemas and bounded dependency closure | In progress | Partly tested | Partial | Three exact semantic schema candidates, finite interpreted subset and complete local context/schema/vocabulary dependencies; immutable profile versions and acyclic bounded document preparation exist. Bounded account profile was actually registered in captures. **Remaining:** Register and validate the complete adopted mapping/authority/place/schema closure; current finite account/format profiles do not establish every required full-v1 schema. Optional live Linked Art API is neither required nor claimed. |
| [MUSEUM-19](#museum-19-evidence) Stable entity identity, references and declaration selection | In progress | Partly tested | Partial | Stable explicit IRIs, work/token/file/physical/person distinctions, package resolution and incompatible selected declaration rejection; exact same-kind repeated exhibition/loan/valuation declarations preserve multiple provenance sources. **Remaining:** General authenticated declaration continuation/correction/merge/split lineage and all source-family token/work bindings remain. Same text, wallet or namespace cannot provide continuity. |
| [MUSEUM-20](#museum-20-evidence) Field-level crosswalk, semantic validation and full coverage accounting | In progress | Partly tested | Partial | Closed schema inventory, exact scalar/array/null/absence accounting, pinned class/domain/range, v2 abstract/visual/linguistic/E73 distinctions and explicit unsupported sidecars. Full requirements are larger than this implemented subset. **Remaining:** All named source families, physical realizations, complete dimensions/media and geographic patterns, exact reverse mapping and named vectors for every required crosswalk entry remain. |
| [MUSEUM-21](#museum-21-evidence) Attributed assertions, review and conflict selection | In progress | Partly tested | Integrated* | Immutable assertion/revision/profile/field selectors, exact earlier review targets, source-selected conflict withholding, provenance indexes and explicit same-account SELF review. Actual independent-account recorded profile works. **Remaining:** General independent institutional reviewer eligibility and cross-authority actual source policy, not just SELF/account lanes, remain. No arbitrary reviewer label/list grants authority. |
| [MUSEUM-22](#museum-22-evidence) External authority matching and archived reconciliation | Not started | Partly tested | Not integrated | Schemas and generic attributed assertion machinery exist, but no complete typed Getty TGN/ULAN/VIAF/AAT/Wikidata match production/admission/reconciliation adapter is implemented. **Remaining:** Implement authority concept versus focus IRI, exact snapshot bytes/reuse terms, entity/context checks, unreviewed-to-reviewed proof, matchKind projection, historical rename/merge/split and non-escalation. Fixture scaffolding is not authority implementation. |
| [MUSEUM-23](#museum-23-evidence) Historical, uncertain and role-specific place semantics | Not started | Partly tested | Not integrated | Explicit exhibition Place/venue nodes and generic disputed-geography fixtures exist. Complete required geographic role and historical geometry policy is absent. **Remaining:** Implement all9 baseline roles, names/dates/context, spatial versus catalog/political hierarchy, CRS/uncertainty/source/date, fictional/unknown/broad places and intentional public precision. |
| [MUSEUM-24](#museum-24-evidence) File roles, observed ingest and physical-event relationships | In progress | Partly tested | Partial | Distinct carriers, original/derived resources and named activities; explicit local preservation observations and evidence links. Planned/cancelled/unknown activities are withheld from performed graph output. **Remaining:** Complete software/dependency/reference-render and physical production/custody/accession/title relations, described/received/verified evidence for every source kind, and actual website safety-scan path parity remain. |
| [MUSEUM-25](#museum-25-evidence) Deterministic recorded export and database-free offline replay | In progress | Tested* | Integrated* | Bounded deterministic package partitions, exact original source/transcript/schema bytes, pinned block/read scope, hashes, dependency resolution, whole-package recomputation, public-disclosure refusal and immutable derivatives work for named finite profiles. **Remaining:** Full canonical STREAM_SEMANTIC_EXPORT_V1 source-family coverage and actual ARCHIVE_SEMANTIC_EXPORT publication/admission/reconstruction remain; current finite manifests are explicit derivative profiles, not complete normative record acceptance. |
| [MUSEUM-26](#museum-26-evidence) Linked Art and CRM projection | Built | Tested* | Integrated* | Pinned offline JSON-LD expansion and finite Linked Art/CRM entity projection with extension sidecars, complete input/output correspondence for supported profiles. **Remaining:** Complete adopted crosswalk and all real record-family source adapters remain. Archival URNs and data-model validity do not claim optional HTTP API conformance. |
| [MUSEUM-27](#museum-27-evidence) PREMIS file/fixity facts and recorded source adapter | Built | Tested* | Integrated* | Original pinned PREMIS3 schema, exact file IDs/size/digest/format and correspondence from selected registered source facts. Missing fields yield explicit unsupported diagnostics. **Remaining:** General source coverage beyond selected account facts remains; a declared digest alone does not prove a performed fixity check. |
| [MUSEUM-28](#museum-28-evidence) IIIF Presentation3 archival manifest | Built | Tested* | Integrated* | Same-source four-media presentation, original numeric/URI semantics, complete local context lock and exact correspondence to file/semantic facts. **Remaining:** Full additional artwork/presentation profiles and external viewer/availability behavior remain. Hash-addressed media needs a compatible resolver; validation does not claim that service exists. |
| [MUSEUM-29](#museum-29-evidence) LIDO1.1 work/media/publisher export | Built | Tested* | Integrated* | Pinned XSD closure, work/creation/creator/media and explicit selected publisher per contributing account. Account identity never becomes a named legal body automatically. **Remaining:** Complete expanded loan/valuation/condition/authority semantics across LIDO remain; derivatives retain old LIDO bytes rather than claiming monetary/event mappings absent from its current profile. |
| [MUSEUM-30](#museum-30-evidence) Performed fixity and generic preservation event/report/agent semantics | Built | Tested* | Integrated* | Typed actual performed-check/report/agent joins, separate local observation comparison; twelve generic event kinds and six reported outcomes with noncompleted dispositions preserved. Event time/tool/identity remain original claims unless separately established. **Remaining:** Full operational periodic fixity program, all actual captured event/outcome combinations and generalized trustworthy external execution/scanner evidence remain; FIXITY_CHECK has its original narrower outcome rules. |
| [MUSEUM-31](#museum-31-evidence) Preservation objects, rights and activity graph derivatives | Built | Tested* | Partial | Canonical PreservationObjectRef with explicit properties/relations, rights source qualification and complete recorded event-to-Activity correspondence; software/opaque agents stay sidecars. **Remaining:** Full actual-source activity-graph capture across remaining object/event/rights combinations and whole acquisition/physical relationships remain. Existing object/right captures and synthetic graph controls are distinct. |
| [MUSEUM-32](#museum-32-evidence) Typed exhibition semantic dossier | Built | Tested* | Not integrated | Exact class5 independent exhibition source, typed institutions/venues/dates/status and all original document references. Exact repeated same-kind declarations merge provenance; conflicting/cross-kind declarations reject. **Remaining:** Positive actual exhibition record capture and owner-EXHIBITION lane adapter remain; no loan/custody/display permission is inferred. |
| [MUSEUM-33](#museum-33-evidence) Typed owner loan semantic dossier | Built | Tested* | Not integrated | Exact original owner receipt and full LOAN shape, opaque condition and valuation references, distinct party roles, completed-only Activity plus complete evidence sidecars and literal replay. **Remaining:** Actual owner publication/capture remains authored in 57ac; typed condition core and legal/custody/countersignature evidence require independent adapters, not names/timestamps. |
| [MUSEUM-34](#museum-34-evidence) Typed valuation and ordered loan-insurance evidence join | Built | Tested* | Not integrated | Exact insurance/appraisal/book basis, amount/currency/date/instrument/confidentiality/countersignatures; complete bounded valuation lane and canonical receipt/transaction/log order support explicit referenced-unsuperseded status. **Remaining:** Actual current owner capture pending; legal operativeness, professional assent and hidden instrument contents are not inferred. Unsupported old schema/order gives precise unavailable status. |
| [MUSEUM-35](#museum-35-evidence) BagIt, OCFL and offline fetch hydration | Built | Tested* | Partial | Exact public payload/tag fixity, immutable OCFL version lineage and versioned local-byte fulfillment of complete fetch set. Original nested package and supplied descriptor provenance retained. **Remaining:** Full render inventory, all authoritative dossier inputs, genesis profile registration, actual distribution/availability and institutional ingest remain separate. No automated untrusted network fetching. |
| [MUSEUM-36](#museum-36-evidence) Actual-current OwnerRecords museum publication/capture recipe | In progress | Partly tested | Not integrated | New actual-current Core/Artist/Safe minted-token test with real Schema/OwnerRecords registration and three positive/replay/retry recipes. Python publication, read-only capture and offline loan+valuation composition now implemented. **Unmerged handoff.** **Remaining:** Execute three new native cases in root next coordinated batch, then actual initialized current graph loopback publication/RPC capture at shared final anchor; no running chain/snapshot currently claimed. |
| [MUSEUM-37](#museum-37-evidence) Semantic authoring, draft confirmation and later-edit workflow | Not started | Partly tested | Not integrated | Schema/payload generators, stable synthetic draft fixtures and CLI validation exist; no complete artist-friendly capture/review/confirmation and later-documentation application workflow. **Remaining:** Build workflow without ontology expertise, explicit machine/human enrichment, source-confirmation/review, durable ID reuse, draft_preview and initial/later reuse with actual binding. Mint UI is outside this addendum. |
| [MUSEUM-38](#museum-38-evidence) Complete media/history corpus and institutional conformance | In progress | Partly tested | Not integrated | Named eight-scenario fixture ledger and numerous finite positive/negative exporter tests exist. Complete adopted gate closure, current-source whole corpus and named institutional/practitioner acceptance are not present. **Remaining:** Complete photograph/two prints, written+AV interview, interactive, historical geography, conflicting records, independent participants and offline revision with exact source/profile hashes; obtain required repository/practitioner evidence. Synthetic passes do not count as institutional integration. |
| [MUSEUM-39](#museum-39-evidence) Additional preservation/render/finality profiles and dossier state | In progress | Partly tested | Partial | Actual fixed STATIC native reference and inventory/finality adapters exist; required finality acceptance modes, fixity cycles, alternate scopes and recovery-linked dossier state extend beyond that bounded profile. **Remaining:** Complete PERCEPTUAL_TOLERANCE/CURATED_EQUIVALENCE typed parameters and evidence, all required scope profiles, periodic fixity lifecycle and finality/recovery-to-museum citations/condition/acquisition assembly. DYNAMIC renderer implementation is excluded from genesis/v1. |
| [MUSEUM-40](#museum-40-evidence) Complete genesis museum schema catalog and worked examples | In progress | Partly tested | Partial | Required29 names in CMC genesis schema table mapped below; several exact schemas/interpreters exist and bounded current captures actually register selected definitions. Presence of a JSON candidate is not genesis registration. **Remaining:** Deliver/register complete required catalog, each canonical document/interpretation/positive worked example and operational admission evidence. Current native-specific reference/snapshot or derivative format profiles do not silently fulfill broader named genesis profiles. |

### Governance, continuity and operations

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [governance.roles](#governanceroles-evidence) Role registry, Safe authority and bootstrap handover | Built | Partly tested | Partial | Actual role registry, bootstrap and governance Executor; Safe owners do not inherit the Safe contract's role. **Remaining:** Latest complete product ownership transfer and all-role acceptance. |
| [governance.actions](#governanceactions-evidence) Delayed governance actions, cancellation and append-only action catalog | Built | Partly tested | Partial | Authenticated scheduling/execution and typed action policy; native commerce stage has a recorded 25-case acceptance with typed Artist/entropy boundaries. **Remaining:** Complete latest catalog, all target actions and graph-wide recovery composition. |
| [governance.parameters](#governanceparameters-evidence) Governed gas limits and time parameters | Built | Partly tested | Partial | Parameter hosts/stores, identifiers, delayed updates and raise-only restrictions on applicable budgets. **Remaining:** Reconcile every final product selector/parameter and measure complete ceremonies. |
| [governance.manifest](#governancemanifest-evidence) Public system manifest and dependency inventory | Built | Partly tested | Partial | Manifest commitment and current graph discovery foundation. **Remaining:** Bind the complete 37-role genesis deployment, approved equivalents and distinct fallback instances. |
| [governance.state-export](#governancestate-export-evidence) Publish, challenge and supersede reconstructable state exports | Built | Tests written | Partial | Current export publisher, role/epoch binding and pointer-drift/reorg rejection tests exist. **Remaining:** Run latest native export cases and reconstruct a fully activated final graph from independent records. |
| [governance.recovery](#governancerecovery-evidence) Governed recovery and component cutover | In progress | Partly tested | Partial | Recovery policy, executor context, typed route ownership and current Core-refresh/composition cases exist. **Remaining:** Complete supported cross-domain recovery combinations, succession proofs and actual full graph cutover. |
| [operator.full-genesis](#operatorfull-genesis-evidence) Deploy and activate the complete full-v1 system | In progress | Partly tested | Partial | Saved governance stages and resumable deployment foundation. Earlier 530-transaction rehearsal records productsActivated=false and predates new modules. **Remaining:** Finish all 37 genesis component roles, selected providers, ownership/custody, complete product activation and restart/resume proof. No final genesis launch is claimed. |
| [operator.monitoring](#operatormonitoring-evidence) Operational monitoring, incident response and recovery rehearsal | In progress | Partly tested | Partial | Runbooks and evidence/checkpoint tooling exist; saved lifecycle/surplus plans cover selected incidents. **Remaining:** Connect the complete deployed graph to monitoring and exercise provider failure, halted sales, recovery and operator handover. |

### Developer clients and commerce operations

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [client.commerce](#clientcommerce-evidence) Typed native/revenue/secondary and saved inventory workflows | Built | Tested* | Partial | Actual compiler-selected original signing, bigint values, Safe CALLs, secondary/delegate/inventory saved workflow and Artist revenue/snapshot/template helper. **Remaining:** PLATFORM_WORKS families8–13 and exact-key template CLEAR/freeze still need complete typed operator recipes; full live RPC/deployment/actual Safe execution not established by offline suite. |
| [client.entropy-authority](#cliententropy-authority-evidence) Explicit entropy finding and op60 hydration Safe client | Built | Tested* | Not integrated | New current finding context, full original domain/target/intent provenance, current pointer/notice/fee checks, complete op60 typed request and seven markers, unsigned Safe retry example. **Unmerged handoff.** **Remaining:** Handed over642d017d but not in inspected integration b2fc0c3c. C bounded source review clear; no reviewer execution.12 focused synthetic RPC/ABI cases, exact fixture regeneration, package: 175 tests passed; no native/live-chain/full Safe signature evidence. |
| [operator.commerce](#operatorcommerce-evidence) Saved governance, mint setup and native surplus plans | Built | Partly tested | Partial | Current deployment/catalog activation primitives and saved phase/surplus/lifecycle plans with exact current call/state checks. **Remaining:** Final full product graph deployment/activation and all caller-compatible saved workflows. Earlier deployment productsActivated=false is not a launch. c9d0353d six new surplus-plan tests are authored/source reviewed; root owns native acceptance. |
| [conformance.commerce-gas](#conformancecommerce-gas-evidence) Collector gas, capacity and complete cross-mode conservation | In progress | Partly tested | Not integrated | Required conformance across public paid/current Safe paths and complete liabilities; this is not a new sale feature. **Remaining:** Do not waive500,000 paid single-step ceiling. Retained partial-cold/warm clearing measurements exceed it;8,755,856 historical trace is not current/all-cold. Final all-cold collector, worst-case capacity/stateful fuzz, six-host financial conservation and final-source native campaigns remain integrator-owned. |

### Verification and release

| Feature | Build | Tests | Integration | Scope and remaining work |
| --- | --- | --- | --- | --- |
| [quality.repo](#qualityrepo-evidence) Developer layout, domain interfaces and contributor documentation | Built | Partly tested | Partial | Current Core/domain/interface split, explicit legacy reference area, current-stack guides, tooling and examples. **Remaining:** Keep public docs aligned with this feature register and finish examples for remaining features. A tidy layout is not product completeness. |
| [quality.fuzz](#qualityfuzz-evidence) Modern Foundry unit, negative, fuzz and stateful testing system | Built | Partly tested | Partial | Current integration, Safe, fuzz and invariant suites exist. Multiple scoped 256-input campaigns have passed; newer batches remain pending. **Remaining:** Run meaningful broad fuzz/stateful campaigns on the final combined feature set and resolve failures. |
| [quality.safe](#qualitysafe-evidence) Safe compatibility for every supported call | In progress | Partly tested | Partial | Actual threshold-two Safe workflows across minting, custody, payment, Artist and governance are covered in several captures. **Remaining:** Reconcile every final public/external ABI selector, overload, read, receive/fallback and callback with a successful Safe flow or tested protocol-only restriction. |
| [quality.capacity](#qualitycapacity-evidence) Full-system gas, deployment size and transaction capacity | In progress | Partly tested | Partial | Individual oversized products were repaired; scoped captures verify runtime/initcode limits and cold calls. Whole-repo ABI/type check passes for 1,803 sources at 7209675b. **Remaining:** Complete latest production bytecode checks, full ceremonies, batch limits and collector transaction ceilings. ABI/type checking is not execution. |
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
| 2 | `acceptArtistBinding` | Built; bounded profiles | [ART03](#art03-evidence) |
| 3 | `refuseArtistBinding` | Built; bounded profiles | [ART03](#art03-evidence) |
| 4 | `withdrawArtistBinding` | Built; bounded profiles | [ART03](#art03-evidence) |
| 5 | `proposeCollaboratorIdentity` | Built; bounded profiles | [ART04](#art04-evidence) |
| 6 | `acceptCollaboratorIdentity` | Built; bounded profiles | [ART04](#art04-evidence) |
| 7 | `acceptCollaborator` | Built; bounded profiles | [ART04](#art04-evidence) |
| 8 | `declarePlatformWorks` | Built; bounded profiles | [ART11](#art11-evidence) |
| 9 | `filePlatformWorksClaim` | Built; bounded profiles | [ART11](#art11-evidence) |
| 10 | `fileAttributionClaim` | Built; bounded profiles | [ART05](#art05-evidence) |
| 11 | `setPlatformWorksContest` | Built; bounded profiles | [ART11](#art11-evidence) |
| 12 | `recordArtistSanction` | Built; bounded profiles | [ART12](#art12-evidence) |
| 13 | `confirmSanctionFinalized` | Built; bounded profiles | [ART12](#art12-evidence) |
| 14 | `recordPolicyConsent` | Built; bounded profiles | [ART10](#art10-evidence) |
| 15 | `recordEconomicsConsent` | Built; bounded profiles | [ART16](#art16-evidence) |
| 16 | `recordSaleConsent` | Built; bounded profiles | [ART10](#art10-evidence) |
| 17 | `recordContentConsent` | Built; bounded profiles | [ART17](#art17-evidence) |
| 18 | `recordPayoutDesignation` | Built; bounded profiles | [ART15](#art15-evidence) |
| 19 | `recordStewardSanctionGrant` | Built; bounded profiles | [ART21](#art21-evidence) |
| 20 | `authorizeArtistRoyaltyFreeze` | Built; bounded profiles | [ART16](#art16-evidence) |
| 21 | `authorizeArtistContentFreeze` | Built; bounded profiles | [ART17](#art17-evidence) |
| 22 | `recordRecoveryApproval` | Built; bounded profiles | [ART13](#art13-evidence) |
| 23 | `recordUnavailabilityFinding` | Built; bounded profiles | [ART13](#art13-evidence) |
| 24 | `recordArtistAttestation` | Built; bounded profiles | [ART14](#art14-evidence) |
| 25 | `recordIdentityRevision` | Built; bounded profiles | [ART02](#art02-evidence) |
| 26 | `grantArtistDelegation` | Built; bounded profiles | [ART09](#art09-evidence) |
| 27 | `revokeArtistDelegation` | Built; bounded profiles | [ART09](#art09-evidence) |
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
| 44 | `openAttributionDispute` | Not started | [ART06](#art06-evidence) |
| 45 | `recordCounterStatement` | Not started | [ART06](#art06-evidence) |
| 46 | `resolveAttributionDispute` | Not started | [ART06](#art06-evidence) |
| 47 | `revokeAttribution` | Not started | [ART06](#art06-evidence) |
| 48 | `vetoAttributionRepudiation` | Not started | [ART06](#art06-evidence) |
| 49 | `cancelAttributionRepudiation` | Not started | [ART06](#art06-evidence) |
| 50 | `executeAttributionRepudiation` | Not started | [ART06](#art06-evidence) |
| 51 | `revokePriorAddressStanding` | Built; bounded profiles | [ART18](#art18-evidence) |
| 52 | `recordContentRatification` | Built; bounded profiles | [ART10](#art10-evidence) |
| 53 | `approvePlatformWorksCorrection` | Built; bounded profiles | [ART11](#art11-evidence) |
| 54 | `revokeArtistAuthorization` | Built; bounded profiles | [ART08](#art08-evidence) |
| 55 | `commitArtistHistoryImportRoot` | Built; bounded profiles | [ART29](#art29-evidence) |
| 56 | `verifyImportedLaneTip` | Built; bounded profiles | [ART29](#art29-evidence) |
| 57 | `observeRegistryCutover` | Built; bounded profiles | [ART29](#art29-evidence) |
| 58 | `dismissArtistIdentityContest` | Built; bounded profiles | [ART18](#art18-evidence) |
| 59 | `grantStewardCapabilities` | Built; bounded profiles | [ART21](#art21-evidence) |
| 60 | `hydrateArtistAuthority` | Built; bounded profiles | [ART31](#art31-evidence), [ART32](#art32-evidence), [ART33](#art33-evidence), [ART34](#art34-evidence), [ART35](#art35-evidence), [ART36](#art36-evidence), [ART37](#art37-evidence) |

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
| 13 | `MINT_TICKET_GATE` | [sales.standard-gates](#salesstandard-gates-evidence) | Concrete required gate not built. |
| 14 | `FIXED_PRICE_SALE_ADAPTER` | [sales.native-fixed](#salesnative-fixed-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 15 | `ENGLISH_AUCTION_HOUSE` | [sales.english](#salesenglish-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 16 | `DUTCH_AUCTION_ADAPTER` | [sales.dutch](#salesdutch-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 17 | `PRIVATE_SALE_ADAPTER` | [sales.private-offer](#salesprivate-offer-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 18 | `BURN_MINT_GATE` | [sales.burn-mint](#salesburn-mint-evidence) | Current burn consumer not built. |
| 19 | `DELEGATE_REGISTRY_GATE` | [mint.delegate-registry](#mintdelegate-registry-evidence) | Concrete required vault-delegation gate not built. |
| 20 | `ERC20_PRIMARY_SETTLEMENT_ADAPTER` | [sales.erc20-immediate](#saleserc20-immediate-evidence), [sales.erc20-reveal](#saleserc20-reveal-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 21 | `ARTIST_REGISTRY` | [ART01](#art01-evidence), [ART06](#art06-evidence), [ART34](#art34-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 22 | `METADATA_ROUTER` | [MUSEUM-01](#museum-01-evidence), [MUSEUM-16](#museum-16-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 23 | `RENDERER_V1` | [metadata.renderer-routing](#metadatarenderer-routing-evidence), [MUSEUM-15](#museum-15-evidence), [MUSEUM-39](#museum-39-evidence) | Exact required StreamRendererV1 has no approved alias. Current fixed StreamMetadataTokenRenderer/StreamMetadataBundleRenderer and Router helpers do not implement its selectable/versioned interface; reference-render evidence is separate. |
| 24 | `COLLECTION_METADATA` | [MUSEUM-03](#museum-03-evidence), [MUSEUM-09](#museum-09-evidence) | Legacy StreamCollectionMetadata/IStreamCollectionMetadata and current StreamCollectionMetadataV1 have different interfaces; exact genesis correspondence remains unresolved. |
| 25 | `SCHEMA_REGISTRY` | [MUSEUM-02](#museum-02-evidence), [MUSEUM-40](#museum-40-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 26 | `OWNER_RECORDS` | [MUSEUM-05](#museum-05-evidence), [MUSEUM-36](#museum-36-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 27 | `PRESERVATION_RECORDS` | [MUSEUM-06](#museum-06-evidence), [MUSEUM-39](#museum-39-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 28 | `COLLECTION_ATTESTATIONS` | [MUSEUM-04](#museum-04-evidence), [MUSEUM-08](#museum-08-evidence) | Source/profile status is in the linked rows; complete final manifest, interface/codehash and activation acceptance remain. |
| 29 | `COLLECTION_VIEWS` | [MUSEUM-07](#museum-07-evidence) | Current CollectionViews host not built. |
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

**Static caps, counter subjects and phase-policy grace windows**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [StreamMintLedger.sol](../smart-contracts/domains/mint/StreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintOperationIdentity.sol](../smart-contracts/domains/mint/StreamMintOperationIdentity.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintLedger.t.sol](../test/unit/mint/StreamMintLedger.t.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.merkle-caps evidence

**Different wallet allowances from a pinned Merkle root**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [IStreamMintLedger.sol](../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintPhaseState.sol](../smart-contracts/domains/mint/StreamMintPhaseState.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.cross-scope evidence

**Collection-wide and global shared mint counters**. Owner: Integrator. Requirements: [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — Protocol v1 Scope.

- [StreamMintLedger.sol](../smart-contracts/domains/mint/StreamMintLedger.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamMintOperationIdentity.sol](../smart-contracts/domains/mint/StreamMintOperationIdentity.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### mint.continuity evidence

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

**Hot-wallet minting for a vault through a pinned delegation registry**. Owner: Integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — SSA-DELEGATE.

- [IStreamMintGate.sol](../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### revenue.asset-policy evidence

**Approved ERC20 assets, permit policies and non-stranding deprecated exits**. Owner: Revenue builder / Integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md).

- [StreamAssetPolicyRegistry.sol](../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.
- [StreamERC20PrimarySettlementAdapter.sol](../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol). Source `b2fc0c3c`. Source inventory; execution claims are limited to the evidence notes in this row.


### metadata.renderer-routing evidence

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

**Attribution dispute, counterstatement, resolution, revocation and repudiation**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dispute; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-state.

- [StreamArtistAttributionLifecycle.sol](../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol); [StreamArtistAttributionBindingMutation.sol](../smart-contracts/domains/artist/StreamArtistAttributionBindingMutation.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


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

- `smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotation.sol` (handoff only; `49f22c34dac90d444560e88de1d0354ce9cf5525`); [StreamArtistRecoveryDormancyGuardians.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyGuardians.sol); [StreamArtistDormancyRecovery.sol](../smart-contracts/domains/artist/StreamArtistDormancyRecovery.sol); `test/unit/artist/StreamArtistDormancyRotationRecoveryActual.t.sol` (handoff only; `49f22c34dac90d444560e88de1d0354ce9cf5525`). Source `49f22c34dac90d444560e88de1d0354ce9cf5525`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART24 evidence

**Closed original dormancy followed by executed rotation and first recovery**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard.

- `smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotationOrigin.sol` (handoff only; `9ea144c85768050ec910cc8534af13bcac82e20d`); `smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotation.sol` (handoff only; `9ea144c85768050ec910cc8534af13bcac82e20d`); `test/unit/artist/StreamArtistDormancyClosedOriginRotationRecoveryActual.t.sol` (handoff only; `9ea144c85768050ec910cc8534af13bcac82e20d`). Source `9ea144c85768050ec910cc8534af13bcac82e20d`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART25 evidence

**Remaining executed-rotation recovery combinations**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-estate.

- [StreamArtistRecoveryContinuation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryContinuation.sol); [StreamArtistRecoveryEstateRotation.sol](../smart-contracts/domains/artist/StreamArtistRecoveryEstateRotation.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART26 evidence

**Adjudicated steward-origin identity recovery**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-guard; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-dormancy.

- [StreamArtistDormancyRecovery.sol](../smart-contracts/domains/artist/StreamArtistDormancyRecovery.sol); [StreamArtistRecoveryDormancyPredecessor.sol](../smart-contracts/domains/artist/StreamArtistRecoveryDormancyPredecessor.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART27 evidence

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

**Migration of multiple identities, collaborators and corrected binding generations**. Owner: Artist builder; integrator. Requirements: [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-import; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-collab; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-binding; [stream-artist-authority.md](../docs/stream-artist-authority.md) — aa-platform.

- [StreamArtistHydrationSourceInventory.sol](../smart-contracts/domains/artist/StreamArtistHydrationSourceInventory.sol). Source `b2fc0c3cbcee85fb42c90db2d697653788df3706`. Current source presence and exact named authored test files; no automatic runtime claim.


### ART35 evidence

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

**Concrete allowlist and signed-ticket gate kit**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-AUTH]; [mint-policy-and-accounting.md](../docs/mint-policy-and-accounting.md) — [MPA-GATES, MPA-TICKET].

- [StreamMintGateValidator.sol](../smart-contracts/domains/mint/StreamMintGateValidator.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [IStreamMintGate.sol](../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [StreamMintTicketHash.sol](../smart-contracts/domains/mint/StreamMintTicketHash.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


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


### sales.burn-redeem evidence

**Current burn-to-redeem / physical redemption consumer**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-REDEEM, SSA-BURN-FINALITY].

- [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [IStreamCoreBurn.sol](../smart-contracts/interfaces/stream/core/IStreamCoreBurn.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


### sales.airdrop evidence

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

**Incident-revoked escrow recovery and successor routing**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — [RSR-ESCROW-RECOVERY] rules1-10; [0008-revenue-splits-and-royalty-resolver.md](../docs/adr/0008-revenue-splits-and-royalty-resolver.md); [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Implementation Requirements / Split Factory (lines 4010-4023).

- [StreamRevenueEscrow.sol](../smart-contracts/domains/revenue/StreamRevenueEscrow.sol). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.
- [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md). Source `b2fc0c3c`. Source inspected at integration b2fc0c3c; no new native execution in this inventory.


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

**Typed native/revenue/secondary and saved inventory workflows**. Owner: Revenue builder; integrator. Requirements: [stream-sales-and-auctions.md](../docs/stream-sales-and-auctions.md) — [SSA-GATES]; [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Operator UX.

- [current-secondary.ts](../packages/stream-client/src/current-secondary.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.
- [current-inventory-workflow.ts](../packages/stream-client/src/current-inventory-workflow.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.
- [current-revenue.ts](../packages/stream-client/src/current-revenue.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.
- [current-custody.ts](../packages/stream-client/src/current-custody.ts). Source `b2fc0c3c`. Integrated revenue client at a8a9e122 passes all 163 package tests, generation/build/type checks. The later 175-test result belongs to unmerged entropy client 642d017d; it is not a new run at b2fc0c3c. Earlier actual-getter vectors have their separately retained scope.


### client.entropy-authority evidence

**Explicit entropy finding and op60 hydration Safe client**. Owner: Revenue builder; integrator. Requirements: [revenue-splits-and-royalties.md](../docs/revenue-splits-and-royalties.md) — Operator UX; [artist-entropy-finding-hydration.md](../docs/guides/artist-entropy-finding-hydration.md).

- `packages/stream-client/src/current-entropy-authority.ts` (handoff only; `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`). Source `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`. Worker commit642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265, direct7209675b. Evidence paths are on that commit.
- `packages/stream-client/test/current-entropy-authority.test.mjs` (handoff only; `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`). Source `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`. Worker commit642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265, direct7209675b. Evidence paths are on that commit.
- `docs/integrations/entropy-authority-client.md` (handoff only; `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`). Source `642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265`. Worker commit642d017d9d0cd8ee9b6b813abbdbe10a4c6b1265, direct7209675b. Evidence paths are on that commit.


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

**Independent collection views host**. Owner: Museum/metadata builder; integrator. Requirements: `LCM-GENESIS component29 COLLECTION_VIEWS`; `CMC-MUTATIONS`.

- [collection-metadata-contract.md](../docs/collection-metadata-contract.md); [check_genesis_deployment_profile.py](../tools/protocol/check_genesis_deployment_profile.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


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

**Remaining named owner/institutional record semantic adapters**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-OWNER-RECORDS 8-9,13`; `CMC-GENESIS-SCHEMAS`; `MSM-MAPPING 3`; `MSM-RELATIONS 5`.

- [collection-metadata-contract.md](../docs/collection-metadata-contract.md); [owner_record_source.py](../tools/museum/owner_record_source.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-14 evidence

**Full condition report and conservation-treatment mapping**. Owner: Museum/metadata builder; integrator. Requirements: `CMC-GENESIS-SCHEMAS 3`; `CMC-EXHIBITION-LOAN 2`; `MSM-MAPPING 3`; `MSM-RELATIONS 3-6`.

- [loans.py](../tools/museum/loans.py); `test/fixtures/metadata/current-owner-museum/condition-schema.json` (handoff only; `57ac8d041c9adc479f1061fafec748c8330ac974`); `docs/museum-current-owner-capture.md` (handoff only; `57ac8d041c9adc479f1061fafec748c8330ac974`). Source `57ac8d041c9adc479f1061fafec748c8330ac974`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


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

**External authority matching and archived reconciliation**. Owner: Museum/metadata builder; integrator. Requirements: `MSM-AUTHORITIES 1-9`; `MSM-06-AUTHORITIES`.

- [museum-semantic-mapping.md](../docs/museum-semantic-mapping.md); [STREAM_SEMANTIC_ASSERTION_V1.json](../schemas/museum/STREAM_SEMANTIC_ASSERTION_V1.json); [semantic_selection.py](../tools/museum/semantic_selection.py). Source `7209675bfb1787bd3e6a73927120dce21cbed585`. Current source inspected; no new test or compilation run for this register. Specific historic evidence remains qualified by its original source.


### MUSEUM-23 evidence

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

- `test/current/StreamCurrentOwnerMuseumCapture.t.sol` (handoff only; `57ac8d041c9adc479f1061fafec748c8330ac974`); `tools/museum/current_owner_capture.py` (handoff only; `57ac8d041c9adc479f1061fafec748c8330ac974`); `tools/museum/test_current_owner_capture.py` (handoff only; `57ac8d041c9adc479f1061fafec748c8330ac974`); `docs/museum-current-owner-capture.md` (handoff only; `57ac8d041c9adc479f1061fafec748c8330ac974`). Source `57ac8d041c9adc479f1061fafec748c8330ac974`. 57ac8d04:876-source ABI clean3 authored;10 Python PASS4.948s. B one-file Solidity source clear. Qualified offline smoke with retained actual four-format base plus SYNTHETIC owner/history passed full replay; not genuine owner capture.


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

Source `ee0f01599b638ae8437ac794e43d83fe1a2be9f5`. Root-owned frozen 28-suite run; no result.json exists at inventory read; no completion inferred.

Retained local capture directory: `D:/temp/6529stream-v1-delivery-20260911/integration/current-artist-native4-20260915`. No result was available at the inventory read.

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
