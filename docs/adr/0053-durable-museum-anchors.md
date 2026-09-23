# ADR 0053: Durable conservation and condition-source anchors

## Status

Accepted under the owner's autonomous full-v1 delivery authority, 20 September
2026. This decision implements the existing conservation-tier and acquisition
packet requirements; it does not waive their remaining producer or sale checks.

## Decision

Core retains each collection's explicit conservation tier in an append-only
mapping. Only the live, code-pinned selected Metadata facade can record it. The
facade checks the dedicated CONSERVATION family grant (collection class 7 or
global class 8). Core independently checks the closed three-tier vocabulary,
known collection, no earlier declaration and zero completed mints. Mint
completion callbacks cannot change the declaration. Allocation alone does not
freeze it, and burns do not reopen it. Replacing Metadata cannot erase it.

The raw Core getter returns zero for no explicit declaration. Consumers must
check collection existence and `collectionMintedEver`: an undeclared collection
has no effective tier before its first completed mint and defaults to
MUSEUM_GRADE_LITE afterward. Zero never means CONSERVATION_WAIVED. Core records
the durable write and Metadata emits the specified public declaration event.

Core also binds one immutable append-only condition-source catalog through an
exact class-1 governance transition. Admission checks the catalog interface,
Core, governance authority, chain and runtime identities with bounded canonical
reads; delegated EOAs are rejected. The binding cannot be reset. The catalog
retains every admitted source and replacement predecessor in its denominator.
Compatible hosts can be explicitly admitted without having been globally
registered as modules; individual record authority still needs verification.

Canonical offchain current/latest selection authenticates the complete bound
source-set count/root and every relevant original lane at one capture anchor.
It orders original receipts by block, transaction index and log index. Local
indices and equal timestamps cannot establish cross-host order. An unsupported
newest record stays selected-but-unresolved; it never silently selects an older
interpretable record. This decision adds no invented native global sequence.

## Permanent sale-floor receipt owner

A separate additive Core interface binds one immutable conservation-floor ledger
with the same delayed class-1 transition and bounded identity/head checks. Its
scope and state domains are distinct from the condition catalog. The pointer and
runtime hash append after the other Museum storage roots; neither Metadata nor
settlement-recorder replacement resets genuine first-sale or release receipts.

The ledger must authenticate the currently selected primary settlement recorder
and its already-written settlement result before recording a floor receipt.
Supplemental payments must identify their genuine original receipt. Artist
intent/interview, rights and documentary identity prerequisites are recorded on
first sale; new releases still require their own complete media/reference facts.
An undeclared tier enforces the LITE floor prospectively during first-sale
settlement, even when mint completion is later in the atomic operation. This
does not change the public effective-tier getter before first completed mint.

Core binding only establishes the permanent owner. Native evidence producers,
settlement integration, complete flow/capacity tests and the separately held
personhood proposal remain explicit required work.

## Consequences and evidence

The new Core interfaces are additive and original storage roots stay in place.
This makes declarations and the canonical source denominator independent of
Metadata replacement. The catalog remains extensible by append-only governance.
The floor still needs actual native intent/interview, rights, masters and
reference producers, and its separate personhood dependency remains explicit.
Neither these anchors nor passing ABI checks prove sale-floor conformance.

Focused direct/Safe, replacement, malformed-read, replay, callback and mint/burn
regressions accompany the producer batch. Source-specific size, cold gas and
full-system acceptance remain required before freezing the candidate.
