# Required packet producers: conservation and condition

Source review: integration `e0eb03c38fefab405a3b14f259c0b75de2994a05`,
20 September 2026. Relevant producers were unchanged from `7d20df15`; later
implementation is outside this recorded review. This ledger identifies work
required by the [collection metadata specification](collection-metadata-contract.md),
especially CMC-MUSEUM-GRADE, CMC-ACQUISITION-PACKET and CMC acceptance case 56.
These dependencies remain required implementation, not waivable qualifications.

## Later source and consumer implementations

The historical missing-producer table below describes its recorded source only.
The canonical condition catalog is now frozen at
`f7a05e0734b95f1e2ff1a038b73511c0d94b6f81`, with the permanent Core binding at
`758572df4e7f3969f549dd58aef0c369202e2b27`. The
[condition capture consumer](museum-condition-source.md) follows those exact
interfaces: complete retained membership and lanes, original governance and
publication receipts, and latest selection by block/transaction/log position.
Replaced hosts and pre-admission records remain in scope. Unsupported newest
records remain selected and unresolved; complete empty lanes establish only
catalog-scoped absence. Packet item 15 still needs the examination and protocol
joins listed by the capture. Producer/native runtime and joined current-stack
acceptance are separate from synthetic Python replay validation.

The later [conservation source adapter](museum-conservation-source.md) now
captures and replays the existing selected intent/interview producers. That
partial item-13 consumer does not supply the missing tier declaration/default or
sale-floor inputs in this recorded dependency review. The additive
[packet V3 schema](museum-acquisition-packet-v3.md) also permits zero optional
condition captures. The new condition consumer above now follows the frozen
authoritative source-set producer; examination joins remain separate.

Ownership follows [the autonomous run](../ops/AUTONOMOUS_RUN.md): the Metadata
lead owns native metadata/records/preservation/finality; Root owns Core and
shared-interface decisions; the Museum lead owns offchain source, schema and
assembly work. Root coordinates settlement ownership where a sale gate joins
these components.

## Historical producer gaps at the recorded source

| Requirement | Missing producer or consumer | Accountable owner | Required acceptance evidence |
| --- | --- | --- | --- |
| Item 13: explicit tier declaration | No native implementation/interface for `declareConservationTier(uint256,bytes32)`, no `CollectionConservationTierDeclared(uint256,bytes32,uint16)` producer or durable declaration read. | Metadata/records lead; Root for shared Core and authority binding. | Actual authorized direct/Safe declarations; reject unauthorized, unknown tier, second declaration and post-first-mint declaration; exact retained state/event correspondence. |
| Item 13: default tier | Complete declaration history/state from the actual bound producer, joined to the collection's completed first mint, including replacement history. A missing declaration writer does not prove “undeclared.” | Metadata lead and Root Core owner; Museum consumes evidence. | Undeclared completed mint yields MUSEUM_GRADE_LITE; allocation alone does not; burns do not reset it; omitted declarations or replaced hosts cannot manufacture absence. |
| Item 13: tier-dependent pre-sale floor | Native tier-dependent enforcement was not found. A packet declaration cannot enforce the sale boundary. | Metadata lead, Root and settlement owner. | Actual first sale fails without required floor inputs; full tier additionally requires captures/environment; only explicitly declared CONSERVATION_WAIVED bypasses the floor. |
| Item 13: selected intent/interview | Museum capture/replay consumer remains to be built for existing real selection and original-record producers. | Museum lead; Metadata for producer defects; Root for authoritative provider/Core binding. | Actual op24-backed intent/waiver, PRESENT/WAIVED interview, complete predecessor/catalog history and lock; reject arbitrary selector, changed graph/association/interview; retain historical evidence after eligibility changes. |
| Item 15: canonical host denominator | No canonical condition-host/source-set binding with retained replacement history. Current registry enumeration excludes unregistered compatible hosts and prior registry instances. | Metadata/records lead; Root approves shared binding/interface; Museum follows with the consumer. | Two compatible hosts, an unregistered host and replacement history: reject canonical latest/none claims from arbitrary or incomplete source sets. |
| Item 15: current/latest and none-recorded | Canonical selection across the bound source set remains unspecified/unimplemented. Per-author latest is insufficient. Existing complete lanes can derive the selected record once the denominator and ordering rule exist. | Metadata/records lead and Root for semantics; Museum for derivation/replay. | Multiple authors, intervening other-token records, same-block publications, unsupported latest payload and truly empty scope. Never silently use an older interpretable record. |
| Item 15: captures representation | The original packet condition-present branch requires at least one capture; normative JSON condition records allow zero optional captures. This separate schema gap is preserved by the authority-only V2 change. | Museum schema/assembly lead; Root integration. | Valid zero-capture report exports an empty list; nonempty capture entries stay complete; curated ABI condition data never becomes JSON condition data. |

## Existing evidence that should be reused

Core's `collectionMintedEver` tracks completed minting through `_completeMint`.
`TokenCollectionRegistered` is emitted earlier during allocation. The two events
cannot be substituted when deriving a post-first-mint default.

The native conservation selector already provides `adoptIntent`, `adoptWaiver`,
prepared-interview adoption, `currentConservation`, `conservationSelectionAt`,
`selectionCatalogCount/At`, `intentLock` and `requireCurrent`. Artist and estate
lineages remain separate; the interview must come from the selected parent
locator. This is a missing Museum consumer join, not permission to invent a tier
declaration or substitute an estate head for Artist intent.

OwnerRecords already supplies complete per-token lanes and per-owner latest
records. Independent records supply complete collection lanes, `recordSubject`
and per-subject/per-recorder latest. Their mixed-subject lane denominators must
remain in the evidence. An empty admitted host establishes only that scoped
observation until the required canonical host/selection producers exist.

The current native curated-condition ABI uses its own schema. Its family name
does not authorize reinterpretation as the broad JSON condition report.
