# Current WORK and RIGHTS evidence

`StreamFinalityDescriptionReads` consumes the two authoritative record selectors
for one exact scope. It supplies the work-description and rights-statement inputs
needed by the developing complete finality provider. It does not publish records,
select new heads, grant legal rights or establish finality readiness by itself.

## Fixed deployment graph

The consuming provider supplies `Dependencies` from its fixed deployment
configuration: Core, generic metadata, schema registry, byte store, WORK selector
and RIGHTS selector, followed by their six original runtime hashes, chain ID,
small-read budget and validating-selector budget. A caller must never choose
this graph through a provider's public evidence method.

The provider may precede selector deployment. Bind the exact predicted selector
addresses and expected compiled runtime hashes as described in
[ADR 0041](../adr/0041-typed-finality-evidence-provider.md). Every operative read
requires live matching code and checks each selector's four source addresses,
four source runtime hashes, chain and interface. There is no mutable binding or
missing-code success path.

The selector's own `requireCurrent` verifies its original metadata/artist graph,
Core-selected host and complete registered interpretation documents. WORK also
rechecks the current applicable artist association and format catalog. Original
publisher and selector grants are historical facts; revoking a grant does not
replay or erase an earlier authorized selection.

## Returned facts

`requireCurrent(dependencies, scope)` returns the canonical scope subject and the
two current record hashes, payload hashes, selection hashes and revisions. For
each family it reads the complete current selection, reconstructs its original
selection commitment, calls `requireCurrent` for that exact head/revision, and
requires the complete returned tuple to match. WORK has 33 static ABI words and
RIGHTS has 14; short, oversized or different responses are rejected.

The actual nine-word metadata receipt corroborates collection, recorder,
authorization class, original lane index and registered definition hashes. WORK
also compares its saved chain hash and original artist-publication backlink.
That receipt contains no subject, payload or URI. Their authority comes from the
pinned selector's prior full-witness admission and retained selection, not from
reconstructing the whole original record using the receipt alone.

A later generic record does not supersede either selected head. Authorized
selection advances its own predecessor/revision. A recorded dated description
absence and a recorded rights statement with unspecified grants are explicit
inputs; a missing head is rejected.

## Scope and remaining composition

Subject derivation validates tuple shape. The complete provider must independently
validate actual scope membership, including TOKEN's collection mapping: the token
subject commits chain, Core and token ID, while the requested collection is a
separate fact. This consumer does not inherit collection records into TOKEN,
RELEASE, SEASON or VIEW scopes.

The two description inputs do not supply ROOT, snapshot, reference render,
intent/waiver, interview, render-critical inventory, archival coverage or the
independent finality manifest. They must be joined with the other actual
producers before `requireFinalityScopeInputs` can succeed. Historical selector
reads remain distinct from these new-consumption checks.

The focused tests compose actual WORK/RIGHTS selectors, Metadata, Schema and
Store. Core, Executor, artist owners and the fixed consuming provider remain
explicit test boundaries. Their selected-source budget is 3 million gas and
small-read budget 500,000; the named cold composed read uses an explicit
8-million outer envelope. These are forwarding/test budgets, not a governed
whole-finality transaction limit.

All 23 focused cases pass both compiler modes, including 256 selection-hash
inputs and actual threshold-Safe 1.4.1 calls to the fixed consumer and the linked
library. The named cold normal-source read costs 1,143,601 / 1,118,178 gas.
An exact 8,192-byte registered WORK catalog with 2,048-byte definition and both
original record URIs costs 1,290,614 / 1,259,858 with the named sources cooled.
That maximum-catalog case has an uncapped outer call and retains the same
internal 500,000/3-million read caps; only the normal case forwards 8 million.
Linked libraries are not all cooled; these are call measurements excluding
transaction intrinsic gas. The large test setups publish multiple documents
and records and are not one-transaction deployment claims. Complete deployment
and Safe acceptance remain tracked in the [delivery ledger](../../ops/V1_DELIVERY.md).
