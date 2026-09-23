# Current standard gate and Merkle counter joins

The [current gate cohort](../../test/current/StreamCurrentStandardGates.t.sol)
adds fourteen authored cases against original Core, Artist, Manager, Ledger,
ModuleRegistry and governance contracts. Native execution is pending. The
source baseline is `6b71507ecab6c351762b189cc5c1098dd071d616`; this recipe is not
a passing full-graph, gas, deployment or whole-v1 acceptance result.

## What is joined

The [fixture](../../test/helpers/CurrentStandardGateFixture.sol) deploys the
original products:

- [StreamMintAllowlistGate](../../smart-contracts/domains/mint/StreamMintAllowlistGate.sol)
  verifies full-batch eligibility against its immutable root and required counter.
- [StreamDelegateRegistryGate](../../smart-contracts/domains/mint/StreamDelegateRegistryGate.sol)
  checks live vault-to-payer delegation and requires delivery and beneficiary to
  remain the same vault.
- [StreamMintTicketGate](../../smart-contracts/domains/mint/StreamMintTicketGate.sol)
  checks an actual threshold Safe's ERC-1271 signature. Its new case exercises
  the independent Merkle counter proof after a valid signature.

The original counter path is
[StreamMintCounterPreparation](../../smart-contracts/domains/mint/StreamMintCounterPreparation.sol),
[StreamMintCounterPolicy](../../smart-contracts/domains/mint/StreamMintCounterPolicy.sol)
and [StreamMintLedger](../../smart-contracts/domains/mint/StreamMintLedger.sol).
This source has no separate deployed `StreamMintCounterResolver` product. No
substitute resolver, receipt-only Core, Manager boundary or replay map is used.

Each phase uses `MERKLE_STATIC` caps, a `RECIPIENT` subject and a `PHASE` scoped
definition in the real Ledger. Two leaves commit separate beneficiary addresses,
the actual Manager, chain, collection, phase, counter, cap and price fields.
The proof supplies a cap of three and each token increments it by one. These
are explicit local fixture inputs, not a sale-price or transaction-gas claim.

Five separate Safe 1.4.1 accounts have two owners and threshold two: Artist,
mint executor, vault, ticket signer and governance root. The root registers the
three original gates with a SystemManifest tail, then schedules the original
Manager's phase and executor calls through the delayed Executor. Artist consent
uses the original record operation with the Artist Safe's ERC-1271 proof.
The mint executor submits signed Safe envelopes to the actual Manager.

The fixture's external delegation service implements only the exercised
delegate-v2 contract/right response ABI. The vault Safe calls its grant/revoke
method; this does not authenticate upstream delegate.xyz behavior or bytecode.
The external entropy service remains the existing explicit double. A recipient
fault contract can reject a chosen callback; it is not a protocol replacement.

## Authored cases and observations

| Boundary | Cases |
| --- | --- |
| Construction and authority | Actual gate runtime/metadata pins, Ledger definitions and policies, original Artist consent, rejected wrong threshold Safe caller |
| Allowlist accounting | Two different beneficiaries with different delivery addresses; payer and executor receive no beneficiary debits; wrong proof, beneficiary and phase reject |
| Allowlist replay and cap | Exact authorization replay and a changed request reusing the same gate nonce reject in the original Ledger; repeated-subject batches cannot exceed the projected proof cap |
| Delegate accounting | Collection-right grant from the vault Safe; delivery, beneficiary and counter remain the vault; wrong payer, route or collection right reject |
| Live delegation and counters | Revocation blocks a saved Safe envelope; restoring the grant permits its identical retry; an otherwise valid grant still requires the original Merkle proof |
| Delegate replay | Exact authorization and changed-request/same-nullifier replays reject in the original Ledger |
| Late failure | Separate allowlist and delegate prepared batches complete the first original token before the second receiver fails; identical Safe envelopes retry after the external receiver is repaired |
| Signed-ticket counter join | A valid Safe ticket cannot use another phase's Merkle proof; the original proof then mints and debits its beneficiary once |

Successful cases compare actual Ledger consumption events with independently
derived subject keys, counter value keys and per-token proof-resolution hashes.
They also check the original authorization and operation-root state, nullifiers
where the gate supplies them, Core ownership/content, allocation, operation nonce
and Safe nonce. The existing
[ticket cohort](../../test/current/StreamCurrentMintTicket.t.sol) retains its
normal ticket, signature, direct/relayed void and late-delivery cases.

Late-failure cases inspect reverted trace logs only to establish that the first
prepared token completed before the receiver failure. Those logs are not
committed receipt evidence. Durable reads must show no surviving token identity,
content, preparation, entropy anchor, root, authorization, nullifier, counter
debit, Manager nonce, Safe nonce or recipient callback state. The successful
retry must emit the same operation root and commit both token occurrences once.

## Validation boundary

The production EIP-170 checks in the current fixture and additional original
gate checks remain enforced. Gate registrations use an explicit local 600,000
read budget; no existing production bound, shared launch value or source is
changed. The publication payload is a fixture, not regenerated release evidence.

Solidity ABI/type checking does not execute these cases, generate their native
bytecode or establish size/gas readiness. Run this fourteen-case cohort only
after matching-source current-graph preparation and original product size checks
under the integrator's coordinated native campaign. Retain failures as well as
passes. Live upstream delegation, paid settlement, external entropy callbacks,
combined fuzz/invariants, full CI and whole-system testnet acceptance remain
separate. Frozen RC1 artifacts are unchanged.
