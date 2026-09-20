# Canonical condition sources and selection

This boundary implements the explicit source denominator required by acquisition
packet item 15. It reuses the original OwnerRecords and independent-record
producers. It does not reinterpret curated-condition ABI records as JSON condition
reports. The broader requirement remains in
[the collection metadata specification](collection-metadata-contract.md).

## Canonical binding and permanent membership

`IStreamConditionSources` exposes the catalog's immutable `core`, `coreCodeHash`,
`governanceAuthority`, `executorCodeHash`, and `deploymentChainId`. Canonical use
requires the matching Core's one-time, governed address/runtime-hash binding;
finding a compatible catalog or listing the current module registry is not a
substitute for that binding. The Core binding is integrated separately by the Core
owner. A missing binding is unavailable evidence, never an empty source set.

`StreamConditionSources.appendSource(host,lane,replacesSourceId)` admits a host
through the actual Executor's delayed class-1 context. The target checks the
current governance root and original root proposer, exact scope and old/new state
hashes, immutable Executor runtime, host interface, and host's actual `core()`.
There is no direct administrator or Safe shortcut. `sourceTransition` returns the
exact scheduling commitments; another admission or root rotation invalidates a
previously prepared transition.

The lanes are `OWNER = 0` and `INDEPENDENT = 1`. IDs start at one. Every admission
pins the host runtime hash and appends to the source-set accumulator. A replacement
identifies a prior source of the same lane, but the predecessor remains a source
forever. There is no removal, disable, reordering, or in-place replacement method.
Admission and reads are constant work and the catalog has no operational host-count
cap. Compatible hosts can be admitted whether or not they are in any module
registry. Registry succession cannot erase source membership.

Admission includes all historical records of that host. It does not establish a
publication cutoff. Retired and replaced hosts remain in the denominator for new
publications too. This prevents replacement from silently hiding continued
owner/independent statements. An unreadable or changed source makes complete
selection unavailable; it cannot be treated as empty or dropped.

`sourceAt(id)` retains the original host, runtime hash, lane, predecessor ID,
admission timestamp, and actual action ID. `ConditionSourceAdded` emits the same
identity and predecessor plus old/new accumulator heads. Timestamps and action IDs
are execution receipts and are not precomputed into scheduled state hashes.

For `D = keccak256("6529STREAM_CONDITION_SOURCE_SET_V1")`, the empty head is
`keccak256(abi.encode(D, chainId, core, catalog))`. Each next head is
`keccak256(abi.encode(D, previousHead, uint64(sourceId), host, codeHash, lane,
uint64(replacesSourceId)))`. State transition hashes are
`keccak256(abi.encode(D, chainId, core, catalog, uint64(count), head))`.

## Complete capture and deterministic latest selection

The Museum capture/replay consumer owns this selection algorithm. The catalog
does not pretend record timestamps supply transaction order. At one pinned chain
anchor the consumer must:

1. Authenticate the original Core binding and catalog runtime/dependency pins.
2. Read `sourceSetHead`, enumerate exactly IDs `1..count`, reconstruct all heads,
   and reconcile the retained admission events and original governance receipts.
   Check `requireSourceSet(count,head)` at that same anchor. Current captures also
   repeat their anchor and source-set reads after collection. This API detects a
   changed or foreign commitment; it is not itself proof that a caller actually
   enumerated records.
3. For every OWNER source, capture the complete token's `CONDITION_REPORT` lane,
   including every author's records and the chain head/count.
4. For every INDEPENDENT source, capture the complete collection's
   `INDEPENDENT_CONDITION` lane, including intervening records for other tokens or
   subjects. Validate each original `recordSubject`; then retain matching TOKEN
   subjects for the requested original token and collection. Per-author latest
   reads do not prove completeness.
5. Authenticate every original publication receipt and its canonical block,
   transaction index and log index. Select each lane's greatest tuple
   `(blockNumber, transactionIndex, logIndex)` across all matching records in all
   admitted hosts. These authenticated positions, not `effectiveAt`,
   `recordedAt`, source admission order, author address, schema support, or an
   arbitrary record hash, define latest. Multiple publications in the same block
   and transaction therefore remain ordered. Duplicate or conflicting receipt
   positions fail validation.
6. Interpret only the selected original record under its original schema and
   canonicalization definitions. If its schema/payload is unsupported, retain
   that exact selected locator with an unresolved interpretation. Never fall back
   to an older interpretable record. A valid zero-capture JSON report retains an
   empty captures list.

`none_recorded` is valid only when the complete canonical denominator and complete
original lanes prove no matching record. It is scoped to this explicit source set;
it makes no claim about arbitrary unadmitted contracts. Omitting an admitted
unregistered host, any replacement predecessor, a lane suffix, or an intervening
independent record invalidates the canonical claim. Records from an arbitrary
compatible host cannot expand or replace the canonical denominator.

The existing public-history profile's provider-log-completeness trust remains
explicit. This boundary adds no consensus proof or fabricated chain ordering.

## Validation boundary

The authored catalog suite uses an actual sealed Executor/RoleRegistry and an
actual two-of-three Safe. Core and record-host handshakes in that suite are typed
boundaries. It covers admission receipts, complete-set commitments, retained
replacement history, governance and Safe rejection, stale-batch rollback, changed
code, malformed reads and a completeness fuzz property. Core binding, actual
record publication across multiple hosts, Museum receipt capture and final packet
selection require their respective joined acceptance evidence. Compilation and
runtime results are reported with the source capture; authoring these tests does
not establish that they passed.

`StreamCoreMuseumAnchors.t.sol` separately authors actual-Core declaration,
mint/prepare/complete/burn, code-pin, replacement, completion-callback, one-time
binding and atomic-rollback cases. It uses typed surrounding governance, metadata,
mint, entropy and catalog handshakes, with no synthetic Core storage writes. This
does not replace the complete actual-catalog/current-stack/Safe join.
