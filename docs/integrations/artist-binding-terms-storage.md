# Binding terms storage worker

`StreamArtistBindingLifecycle` delegates its existing private `_storeTerms`
body to the fixed linked `StreamArtistBindingTermsStorage` library. The owner
passes its original two storage mappings, collection ID, generation and
collaborator calldata at the original proposal call site. Proposal admission,
binding writes, replay, commits, events and constructor behavior remain in
their original order.

The worker retains the 32-row bound, nonzero accounts, strict account/role
ordering, every appended row, and the original collaborator/capability hashes.
It does not validate a different proposal profile or add a storage namespace.
Linked library execution uses the original owner's storage and caller context.
The private owner wrapper remains; no public owner selector changes.

The motivating native capture at `e5174d6f` emitted a 24,669-byte Binding
runtime, 93 bytes above the unchanged 24,576-byte limit. That failed capacity
result is retained separately. The repair's source check restores the entire
original host by removing one import and restoring one body, and compares the
worker body independently. The original 57 ABI entries, 42 method identifiers
and recursive storage layout are unchanged.

Seven focused cases cover literal full terms hashes, empty terms, full-width
coordinates, ordered roles for one account, bound/error precedence, invalid
row rollback and retry, a later host revert after completed worker writes,
and fuzzed full-field storage. They use the actual fixed worker and hash
library through a typed storage harness. They do not establish real Artist
proposal admission, full recovery, or the gas cost of the complete operation.

Native capacity and focused execution results are recorded in the task's
immutable handoff; full shared closure and actual Platform/Artist test-host
acceptance remain separate obligations. Existing size and transaction limits
are unchanged.

The repaired native capture emitted all thirteen shared products and the four
focused test/worker products together. All seventeen fit. Binding is 24,052
runtime bytes and 25,328 bytes of full initcode, including its unchanged
160-byte constructor arguments; the storage worker is 1,327/1,361 bytes.
Coordinator remains exactly 24,576 runtime bytes and Consent full initcode
remains 48,896 bytes. These are source-bound capacity results, not a complete
shared-library deployment or actual hydration acceptance result.
