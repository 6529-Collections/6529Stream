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

The eight cases cover:

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
- Same-Ledger and new-Ledger successors configure their first phase only after
  completed import and governed activation. Missing fresh Artist consent rolls
  back registration; a new signature under the original Artist/Manager domain
  permits the identical governance action. Executor admission requires a second
  exact policy receipt, and replaying either signed consent fails.
- A fresh successor authorization cannot spend the imported raw entitlement
  again. A different entitlement reaches a rejecting ERC-721 receiver and
  rolls back counters, replay state, operation nonce and Safe nonce. Accepting
  delivery permits the byte-identical signed Safe transaction to mint the next
  lifetime token and serial. It consumes the one remaining global/collection
  allowance; another fresh claim exceeds the imported cap and leaves it intact.

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

The original Artist suite and original adapters remain bound to their original
Manager. The successor cases use the completed exact-pair lineage admission and
newly computed policy consent under the original Artist authorization domain.
They independently reconstruct that domain and retain the original policy
receipt. No previous policy hash or adapter is silently transferred. Actual
post-replacement mint execution and imported-entitlement rejection are authored
assertions here; their native runtime acceptance remains pending the frozen run.

## Later frozen run

Include this exact host in the selected-host runner described in
[tooling](../tooling.md), together with the coordinator-selected current graph
and Safe suites. Source and native artifact hashes, production sizes and actual
test inventories must come from that frozen capture. Earlier failed or
interrupted captures remain historical evidence and must not be overwritten.

The protocol import order and commitments are specified in
[mint continuity](mint-continuity.md).
