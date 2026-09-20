# Stateful current gate campaign

This is an authored campaign against the original current Core, Artist,
Manager, Ledger, mint gates and Safe principals. Native execution is pending.
It reuses the accepted [standard gate fixture](current-standard-gates.md) at
integration source `f1acffbe800b0a52a1699b01aa46b750d231e60e`.

## Independent state model

The [handler](../../test/helpers/CurrentGateCampaignHandler.sol) maintains six
allowance buckets: three gate phases by two beneficiaries, each capped at three.
It records successful operations, denied operations, expected token owners and
content, authorization IDs, gate nullifiers and operation roots. Expected
eligibility comes from those counts, live-grant intentions and previously
consumed identities. Production counter reads and mint previews do not determine
the expected result.

After each action, actual state must match that model:

- Each beneficiary has exactly its intended counter debit. Payer and mint
  executor have none. The sum of six buckets equals minted supply.
- Token allocation, collection serials and Manager operation nonces advance
  only for successful tokens. Ownership and content match each requested mint.
- Original Manager and Ledger views agree with every observed authorization,
  nullifier and operation root's independently retained used/unused state.
- Failed calls preserve all prior values and leave no new token identity,
  content, prepared mint, entropy anchor, Safe nonce or receiver callback state.
- Successful mint operations alone increment the mint Safe nonce. Vault grant
  transactions have their own count and grant state.

The [driver](../../test/helpers/CurrentGateCampaignDriver.sol) signs and submits
original Safe envelopes. It accepts mutation requests only from the selected
handler. The original Artist ERC-1271 consent, delayed gate admission and Manager
phase configuration come from the unchanged fixture. The collection's test
supply is explicitly 18, matching six caps of three; original production size
and gate limits remain unchanged.

The external delegation ABI service and recipient fault remain explicit test
doubles. The vault Safe grants and revokes its collection right. The fault
recipient can grant its own right and reject a specified callback. Its grant is
not revoked in this bounded model. The existing entropy service is also a double.

## Actions and nonvacuity

The first 14 handler steps follow a required opening sequence: an allowlist
mint, authorization replay, changed-request/same-nullifier replay, invalid proof,
vault grant, delegated mint, revoke-and-exact-retry, wrong beneficiary, allowlist
callback rollback/retry, delegate callback rollback/retry, cap fill and excess
denial, signed-ticket mint, wrong phase, and vault revocation. Later steps use
the supplied random seed to select actions, gate, beneficiary, quantity and mint
path. Calls continue checking denied outcomes after a bucket is exhausted.

Both callback cases use two-token prepared batches. The first token must have
completed before the second receiver rejects. Reverted trace logs establish only
that ordering; they are not receipts. After repairing the external receiver, the
byte-identical Safe envelope must commit the same operation root and allocations.
Grant restoration similarly retries the saved envelope before another mint can
change its Safe nonce.

The handler exposes separate activity counters. `afterInvariant` requires actual
opening activity for all gates, both replay forms, invalid inputs, the cap,
revocation retry and both callback retries. The handler bounds sequences to 128
steps. Tests deliberately perturb only the oracle's bucket, owner or replay
history, require its assertions to fail, and confirm the reverted probe restored
the model. Another regression rejects callers outside the selected handler.

The [host](../../test/current/StreamCurrentGateInvariant.t.sol) has six
deterministic regressions, one input-fuzzed sequence property and one invariant.
The input property runs 14 opening steps plus 0–32 random steps. A separate
snapshot regression repeats 38 steps with fixed seed `0x65294703` and compares
its decision digest, attempts, successes and supply. The sequence expander is
`keccak256(abi.encode("CURRENT_GATE_CAMPAIGN_SEED_V1", previousSeed, index))`.

## Next native campaign plan

This plan is pending the integrator's frozen-source and compiler-slot decision.
The post-commit handoff records the exact candidate commit/tree, source-byte
hashes and ABI compiler capture. If integration changes a dependency, freeze a
new source capture and retain the earlier one. A HEAD label alone is insufficient.

1. Select exactly
   `test/current/StreamCurrentGateInvariant.t.sol:StreamCurrentGateInvariantTest`.
   Run the existing
   [current acceptance wrapper](../../tools/development/run_current_acceptance.py)
   with that `--host`, the frozen `--project`, an unused task-owned `--artifacts`
   directory and the installed native Solidity 0.8.19 executable via `--solc`.
   It captures the original creation closure, Safe/schema fixture bytes, tools
   and compiler settings before building. Do not use the older `scripts/dev.py
   campaign` selection, which names two different hosts.
2. Require Foundry 1.7.1, current profile, Solidity 0.8.19, via-IR, optimizer 200,
   Paris, no metadata bytecode hash or CBOR, one Forge worker and no fork RPC.
   Compile the exact captured host and prepare its matching current/native graph
   artifacts. All required original production artifacts must pass the retained
   runtime 24,576-byte and creation 49,152-byte limits. ABI-only evidence supplies
   no new size measurements; do not bypass a failing preflight.
3. Execute the entire selected host: six deterministic regressions, the sequence
   property with 256 inputs, and 32 invariant runs at depth 64 with
   `fail_on_revert=true` and checks after each step. The wrapper pins Forge seed
   `0x6529`; this is distinct from the regression's internal seed. It requires
   exact ABI case inventory, full reported budgets and zero handler reverts.
   Intended Safe target failures are handled actions, not handler reverts.
4. Retain capture/config, build-info, product sizes, graph hashes, raw Forge
   output, handler metrics, source/artifact inventories and both failure corpora.
   Match the source and generated graph bytes before and after execution.
   Report failures or missing budgets honestly; only actual complete execution
   can support a campaign pass.

The aggregate local test gas/memory allowances are not collector transaction
budgets. This campaign does not cover paid settlement, upstream delegate.xyz or
oracle behavior, other counter modes, arbitrary principals, configuration
rotation, token transfers/burns, accepted-abort recovery or fallback migration.
Those require separately joined fixtures and oracles. Complete protocol fuzzing,
gas, CI, release and testnet acceptance remain separate. Shared runners, catalogs,
production sources and immutable RC1 evidence are unchanged.
