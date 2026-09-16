# Current mint succession acceptance

`test/current/StreamCurrentMintContinuity.t.sol:StreamCurrentMintContinuityTest`
joins actual current Core, Artist, Manager, Ledger, ModuleRegistry, SystemManifest,
GovernanceExecutor and threshold-two Safe 1.4.1 contracts. It is source-authored
acceptance coverage, with native runtime execution pending the coordinator's
frozen current-graph capture. An ABI/type check is not runtime acceptance.

## Covered transitions

The fixture first executes a paid sale and an ordinary gated mint. The latter
consumes global-recipient and collection-constant counters and a raw eligibility
nullifier through the actual Manager and Ledger. No storage mutation, writer
impersonation or substituted Artist supplies the recorded state.

The six cases cover:

- Same-Ledger and new-Ledger succession with the original paid NFT, lifetime
  supply, token IDs, operation receipts, wallet proceeds and counter floors
  preserved.
- Actual Safe scheduling, post-genesis delays, module admission and a class-3
  Core pointer batch with its SystemManifest publication. A failed Manager
  guard rolls back the preceding Ledger inventory update. Completing the import
  lets the identical scheduled action and calldata succeed.
- An admitted, real second Manager cannot borrow another Manager's completed
  import. The exact predecessor Ledger, predecessor Manager and candidate must
  match.
- A real class-1 root commitment rejects a still-live predecessor writer and
  succeeds through the same scheduled action after permanent retirement.
- Wrong governance commitments, repeated import leaves and incomplete profile
  copying fail. The incomplete-profile check runs after every data leaf has
  been imported, so it isolates profile completeness.
- A corrupted third counter proof rolls back the earlier valid leaves and
  progress. A newly authorized corrected batch imports those same leaves and
  completes normally.

The test reconstructs normalized counter subjects, value keys, double-hashed
import leaves and the manifest descriptor independently. The retired onchain
profile list contains one retained legacy interpretation plus two defined
scopes; copying all three is checked separately from the offchain leaf counts.

## Explicit boundaries

The external entropy service is the existing fixture provider. A small typed
gate is the only eligibility substitute: it defines a test lifetime claim whose
nullifier excludes Manager and Ledger while each authorization binds both,
the caller and the complete batch. Current first-party allowlist/delegation
gates use Manager-scoped nullifiers, and the ticket gate returns none. These
tests therefore do not establish a first-party migration-stable eligibility
product.

Manager and Ledger inventory pointers change in one governed batch. Mint
authority reads the selected Manager's immutable Ledger; the test does not
invent a separate consumer of Core's Ledger inventory pointer.

Successful post-replacement mint execution and replay of an imported entitlement
remain pending the separately owned Artist/Manager compatibility join. The
original Artist suite and original adapters are bound to their original
Manager. Any admitted successor needs newly computed policy consent under the
original Artist authorization domain; no previous policy hash or adapter is
silently transferred.

## Later frozen run

Include this exact host in the selected-host runner described in
[tooling](../tooling.md), together with the coordinator-selected current graph
and Safe suites. Source and native artifact hashes, production sizes and actual
test inventories must come from that frozen capture. Earlier failed or
interrupted captures remain historical evidence and must not be overwritten.

The protocol import order and commitments are specified in
[mint continuity](mint-continuity.md).
