# Native conservation sale receipts

`StreamConservationFloor` owns successful primary-sale conservation receipts for
one Core deployment. Core binds it once under the original delayed governance
transition. The permanent binding and ledger history survive Metadata, source
provider, and settlement-recorder replacement. This source implementation is
not deployment or release-readiness evidence.

## Preparation and payment

The additive `IStreamConservationFloorPreparation` capability exposes
`preparePrimarySale(recorder, candidate, expectedResult)`. Any account may prepare
the exact projected accounting candidate and expected result. The ledger checks
the admitted recorder and genuine current source evidence and stores immutable
preparation records. Preparation does not consume settlement, record first-sale
time, or claim that payment occurred. Direct and escrow outcomes can be prepared
separately when either is possible.

The paid recorder later calls `recordPrimarySale` through the fixed original
settlement-emission library. The ledger verifies the actual caller's current
registry admission, original identity and runtime pins, consumed settlement key,
and exact stored result. Every overlapping candidate/result field must agree.
The common accounting projection omits some native, prepared and custody
lifecycle fields: its payload hash is retained separately from the original
recorder's candidate commitment and is not described as reconstructing it.

First collection and new semantic-release evidence is checked at payment. An
exact matching preparation can be reused. If none exists, the paid transaction
stores the freshly authenticated immutable evidence and seed before linking the
successful sale. Changed source heads, tier, documentary facts or membership
cannot be supplied by a stale preparation. A successful sale writes compact
links and its actual payment timestamp. Full historical
getters and events reconstruct the original receipt tuples and hash domains
from immutable local preparation records. They do not depend on reading an old
recorder or provider, and they never reconstruct evidence solely from events.

Preparation is optional and preserves the original one-transaction purchase
APIs. An operator or relayer may prepare an exact candidate in advance as an
optimization. Inline persistence authenticates the same evidence and grants no
missing-floor bypass. A later revert removes all newly stored preparations,
paid links and payment effects together. The protocol's entire paid-transaction
gas target remains an integration measurement; cold inline evidence storage is
not claimed to meet that target merely because paid links are compact.

## Collection and release boundaries

Raw Core tier zero still means no explicit declaration. Before a completed
mint, the public effective-tier getter also returns zero. The paid sale floor
prospectively enforces `MUSEUM_GRADE_LITE` for an undeclared collection.
`CONSERVATION_WAIVED` skips documentary floor requirements, while retaining a
genuine authenticated paid receipt. It is never inferred from absent evidence.

The first successful sale fixes the collection receipt. A later successful sale
of the same semantic release retains its original release receipt. Every sale
still authenticates the current provider and its current sale-to-release
mapping. A changed complete media inventory, script, renderer or supported
release membership creates a new release requirement. Metadata/provider
addresses, archive heads, transaction labels and native manifest locator hashes
do not define semantic release identity.

The current native provider describes a complete COLLECTION scope with the
three explicitly selected shared native media slots. It refuses opaque media
manifests, alternate inventories and token-derived animation recipes. A selected
empty native manifest is distinguishable from an absent manifest. Supported
script profiles bind the full native script manifest and original finalized
stored bytes; a nonzero library dependency is unavailable in this versioned
profile rather than omitted from its denominator.

`currentReleaseContext(collectionId)` is a source diagnostic for prospective
evidence preparation. It does not consume reference evidence or certify floor
completion. `saleRelease` checks current supported semantic membership. Full
prospective evidence is required by `requireReleaseFloor` for the first or a new
semantic release. Benign lock, configuration or locator changes cannot force a
new capture for an identical release that already has a genuine successful
receipt. Completed-token render samples never establish that receipt.

The native provider reads original RIGHTS, intent/interview and master/waiver
evidence. Documentary personhood verification remains explicitly unavailable;
an opaque personhood schema head does not satisfy it. Artist collections cannot
complete this provider's collection floor while that original verification is
unavailable. Platform collection facts do not invent an artist identity, and
platform media archives require their own genuine producer.

## Supplemental accounting and rollback

Native supplemental settlement uses a separate read-only floor join. It must
authenticate the exact original successful floor receipt, recorder/runtime,
native candidate commitment, accounting projection, stored original/current
results, purchase context and token lineage. It neither reruns collection
first-sale requirements nor creates a second first-sale receipt. A caller
cannot request this exemption with a boolean.

All original primary settlement emitters converge on the fixed floor call after
storing their authenticated result. A floor failure reverts the same transaction,
including funding, accounting, consumption markers and any receipt links. The
floor therefore cannot leave a paid receipt after a later transaction failure.

This join covers the official recorder paths. The separately documented original
`StreamFixedPriceSaleAdapter`, `StreamERC20FixedPriceSaleAdapter` and
`StreamEnglishAuctionHouse` paid paths still require their additive authenticated
direct-sale join. Their existence prevents a claim that every supported primary
purchase is covered by this batch. An auction's paid settlement is the relevant
boundary, not its earlier custody mint, bids or refunds.

## Validation scope

The earlier tier and condition-source batch has a separate frozen 51-case
native result. That result does not validate this ledger or provider. This
batch adds preparation/history/freshness tests, actual-recorder integration
cases, original native record tests and explicit typed source-boundary tests.
Native execution, deployment sizes and paid marginal gas must be reported for
their exact final source capture before claiming those checks passed.
