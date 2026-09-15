# Historical native sale-credit export

This source increment implements the owed-funds read boundary in SSA-ADAPTER
requirements 14–16 and the existing LTA-EXPORT sale-credit leaf. It does not
publish a StateExport snapshot, change a payment authorization, or grant a
claim. Solidity runtime acceptance remains pending. The client has focused
offline tests; those RPC fixtures are not a chain capture.

## Original ledgers and retained keys

All six native sale hosts advertise `IStreamNativeSaleCredits`:

| Host | Original owed amount | Immediately claimable amount |
| --- | --- | --- |
| Fixed price and price programs | Existing per-sale payer refund | Same refund |
| Dutch | Existing per-sale refund | Same refund |
| Clearing | Paid sum less the original floor for each purchase, settled supplements and claimed entitlement, plus remaining excess | Existing `refundableBalance` |
| Refund window | Original pull credit plus every original purchase still pending, including its saved reveal fee | Existing per-sale pull credit |
| English auction | Original refund credit plus the current active winning deposit and saved reveal fee | Original refund credit |
| Private offers and secondary inventory | Original consignor proceeds, excess and failed-royalty credits | Same three original credits |

A cleared account stays in its producer-owned index with owed zero. Fixed price
reuses its original refund account arrays. The other hosts append only the
identity `(saleId, account)` at the actual original ledger/basis creation site.
The separate namespaced index contains no amount, claimant permission, or
current-admission cache. Its schema-1 first-key event records the index and
original key. Claims, royalty retries, settlement, and surplus sweeps never
remove the identity or reset the index. Failed transactions roll it back along
with the original accounting. Existing storage roots and all original selectors
remain intact; this is new-deployment source, not an index migration for an
already deployed older host.

`nativeSaleCreditState()` returns account count, original total liabilities and
native balance. `nativeSaleCreditPage(index, cursor, limit)` returns the original
sale/account, disjoint owed and claimable amounts, and the next cursor. Start at
zero, sum each page, and stop only when next cursor is zero. Limit is 1–64. Most
hosts return one page and reject nonzero cursors. Refund-window cursors count
original sequential purchase nonces: each page reconstructs the canonical
purchase ID and checks the retained sale, payer and nonce. The original pull
credit occurs only on page zero. This keeps a long history readable in bounded
calls without introducing a second pending-amount ledger.

Owed includes funds temporarily locked for winning bids, pending mints and
clearing supplements. It is not a promise that every exported amount can be
withdrawn immediately. The separate claimable field preserves that distinction.
Summed owed must equal original total liabilities. Forced ETH and donations are
balance minus liabilities, never an owed account. Views continue to work when
current admission is unavailable; original self-claim rules and destinations
are unchanged. Offchain exports must anchor completed block state, not combine
transient callback observations from different execution points.

## Complete source inventory and canonical leaf

The TypeScript helper enumerates the pinned registry's entire `moduleCount` /
`moduleAt` history and reads each original `moduleRecord`. It selects the four
original current native registration types covering these six hosts and keeps
ACTIVE, DEPRECATED and INCIDENT_REVOKED rows. It validates retained runtime
hashes and advertised credit capability. A relevant old host without the index
makes the export incomplete and fails; it is not silently omitted. There is no
caller-supplied account list. Zero historical keys are included. Registry
replacement lineage and adapters outside these four named native registration
types require their own original registry capture; this profile does not claim
global completeness across undiscovered registries or other assets.

Each call and code read uses EIP-1898 `blockHash` with `requireCanonical: true`.
The helper checks chain, confirmed depth, source code, exact canonical ABI
return bytes, unique index keys, page progression, original liability
reconciliation, solvency, and the final canonical block. Read budgets fail
without returning a partial export. No fallback to latest or current-only
admission exists. The caller supplies explicit compiler-selected interface
ABIs; retained generated contract catalogs are not relabeled as current.

The leaf is exactly:

```solidity
keccak256(abi.encode(
    STREAM_EXPORT_SALE_CREDIT_LEAF_V1,
    adapter, saleId, account, address(0), owed
))
```

The fixed domain is
`0x4713509255935af0a6981e3a2eb9948df2dc272218d10db479716667ca9c280b`.
No credit-kind field is added. Leaves sort by `(adapter, saleId, account, asset)`.
The explicitly named `ORDERED_KECCAK256_PROMOTE_ODD_V1` tree hashes left then
right without re-sorting siblings, promotes an odd final node unchanged, and
uses zero for an empty root. The export manifest names this construction and the
original leaf schema; it does not assert that a hash has been accepted by the
StateExport publisher. Protocol integers remain full-width decimal strings in
saved JSON. Original RPC responses, inventory records, key indices and the
transcript hash accompany the root so an independent reader can reconstruct it.

`replayNativeSaleCreditExport` consumes every saved RPC observation and repeats
all reads, reconstruction and reconciliation without network access. That
proves artifact self-consistency. Authenticity of the RPC block and canonical
publication still need independent chain verification and the original
StateExport governance/role path. Museum or institutional authority is not
inferred from a matching root.

## Validation boundary

Authored Solidity cases cover actual current fixed/Dutch/clearing/refund flows,
Safe failed-claim identical retry, a governed surplus sweep, original English
outbid/winner deposits, and failed secondary inventory royalties. English and
inventory retain their existing explicit typed Artist/governance/entropy
fixture boundaries; the test file states no joined full-current acceptance.
The clearing surplus test's prior 217-wei owed expectation is corrected to 1017:
800 of original supplemental reserve and 217 excess. The production surplus
getter already used the correct total liability. No native run or collector
gas-conformance claim is made by this batch.

The English host also moves only the shared twelve-word decoder of its two
existing acquisition digest getters into the existing CustodyStart fixed
worker. Both original digest bodies remain literal, and both getters still
sign their distinct original domains/types. An additional authored test rebuilds
every field independently, including values above JavaScript's safe integer
range. No custody mutation, replay domain, or authorization field changes.
