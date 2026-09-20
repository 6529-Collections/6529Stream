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
evidence. For Artist collections, `requireCollectionFloor` also reads the actual
current personhood head from the fixed Attribution owner. It first requires the
current conservation selection, which authenticates its retained Artist facade,
Coordinator, Identity, Binding and Attribution runtime pins. The personhood join
then checks the configured Core/Metadata/Artist pins, current selected pointers,
Metadata's original facade and the actual Coordinator suite and owner bindings.
Newly sampled code hashes alone do not replace those retained graph pins.

A RESOLVED selection must have both current identity and notarization, the exact
original evidence schema and reference profile, and the original scoped report
head and recorder. The provider retains the original authenticated
`personhoodProofSummaryHash` in `personhoodEvidenceHash`. It uses the producer's
bounded currentness and complete retained-summary authentication; it does not
reparse documentary payloads or reauthorize historical signatures at payment.
An explicit current WAIVER under the original native waiver schema instead
retains its native `recordHash` in that field. These are distinct original hash
domains. A waiver does not contain a documentary reference or proof summary.
Missing, stale, opaque or malformed records never imply a waiver.

The collection facts retain the immutable registration `identityRecordHash`.
Personhood follows the current operative identity; those hashes need not be
equal. Valid imported evidence keeps its original source registry and original
hashes, even when the currently selected registry differs. The diagnostic
`currentCollectionRecords` still returns zero personhood and does not certify
the floor. Platform collection facts do not invent an artist identity, and
platform media archives require their own genuine producer.

`originalConfiguration()` returns the exact stored constructor `Configuration`:
all ten addresses and code hashes, the executor, and the three original gas
configurations. It exposes the original `configurationHash` preimage without
changing that hash domain, constructor or existing interface IDs. Original gas
genesis values remain in this getter after governance raises the live values;
read `gasParameterInfo` for the current governed settings.

## Original direct sale receipts

The additive `IStreamDirectPrimaryConservationFloor` capability accepts
`recordDirectPrimarySale(authorizationId)` from an admitted original direct
adapter. It reads the adapter's complete typed paid receipt and deployment
bindings, including the original authorization digest, mint operation, payment
and registry history. It does not construct a universal settlement candidate.
The adapter must store that receipt only after its original funding and mint or
custody-transfer checks succeed; a failed floor call reverts those effects.

Immediate products require active admission. A deprecated English auction may
settle only when its original creation timestamp and registry revision both
precede deprecation. Unknown and revoked adapters cannot record payment. The
floor independently checks the pinned Manager's used operation root and Core's
completed token and collection. The original code-pinned adapter validates the
mint-returned token and operation vector; Core has no token-to-operation receipt
getter that could replace that check.

`directPrimarySaleFloorReceipt(directKey)` returns the locally retained full
receipt, original adapter receipt hash, bindings, tier and first/release receipt
hashes. `ConservationDirectPrimarySaleRecorded` carries the same tuple. Its hash
uses `6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1`, chain ID, Core, floor address
and the tuple with `receiptHash` zero. The original adapter key and receipt use
the separate domains in `StreamDirectPrimarySaleHash`.

First-sale and release receipts may refer to either an official recorder or a
direct adapter in their existing `recorder` field. Their original hash recipes
and immutable evidence remain unchanged. Consumers must use the corresponding
typed history getter: `settlementReceipt(directKey)` returns an empty universal
tuple, and a direct receipt cannot authorize universal supplemental settlement.
Historical direct reads never depend on the old adapter or provider.

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

The official recorder join and typed direct consumer are separate surfaces. The
original
`StreamFixedPriceSaleAdapter`, `StreamERC20FixedPriceSaleAdapter` and
`StreamEnglishAuctionHouse` adapter changes and their actual floor integration
tests are tracked separately. The consumer alone does not demonstrate coverage
of every supported purchase. An auction enters the floor at successful paid
settlement; custody creation, bids, refunds and no-bid closure create no paid
receipt. A genuinely free native fixed-price purchase also creates none.

## Validation scope

The earlier tier and condition-source batch has a separate frozen 51-case
native result. That result does not validate this ledger or provider. This
batch adds preparation/history/freshness tests, actual-recorder integration
cases, original native record tests and explicit typed source-boundary tests.
Native execution, deployment sizes and paid marginal gas must be reported for
their exact final source capture before claiming those checks passed.

The personhood-consumer cases exercise the real helper and identity-graph reader
against exact typed read boundaries, including proof/waiver selection, imported
origins, currentness, malformed responses and changed dependency pins. They do
not exercise actual operation-24 recording, its documentary proof producer or a
complete paid Artist transaction. The configuration tests independently rebuild
the original hash preimage and check all three gas configurations after actual
governed increases. Separate Solidity 0.8.19 captures pass all 16 helper cases
and 19 provider cases at `36c871f4` plus the test-only `fbff83a3` correction.
All emitted production contracts in those captures fit the checked size limits.
These results remain separate from actual Artist recording and paid execution.

Additional source regressions join genuine Safe-authorized operation-24 records
and operation-25 identity revisions to the actual Metadata, RIGHTS, conservation
and provider contracts. They cover explicit waiver selection, opaque-head
replacement without fallback, and stale operative identity with fresh waiver
recovery. The documentary extension uses actual signed General COLLECTION
notarizations, the exact General v2 registry admission, original op24 references
and independently reconstructed retained summary hashes. A newer original
recorder-scoped report invalidates current acceptance until fresh op24 selection.
Core, governance and the original suite Router remain explicit typed boundaries;
documentary references are fixture data, not assertions of external truth.
These additional actual-owner cases have not been executed. Actual Artist
deployment size, complete current-graph execution, paid transactions and gas
acceptance remain pending.
