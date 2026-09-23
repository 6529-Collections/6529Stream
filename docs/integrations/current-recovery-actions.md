# Bounded current recovery actions

This authored campaign joins original Core prepared-mint abort and fallback
succession with original native auction settlement and pull refunds. Native
execution is pending. It starts from integration source
`f8f78e99ba3aeee1ac96072d39f3439985f52686` and leaves the
[initial gate campaign](current-gate-campaign.md) unchanged.

## Reused fixture and explicit seams

The original [incident regressions](../../test/current/StreamCurrentMintFallbackIncident.t.sol)
retain their three cases. Their setup, two real Ledger imports, actual
threshold-two Safe governance and production fallback recovery are extracted
into a [shared fixture](../../test/helpers/StreamMintFallbackIncidentFixture.sol).
The default preparation is still token 3. A derived fixture can create an
additional completed liability before cutover and provide its expected token
and completed-mint counts.

The nonconforming test Manager is necessary to leave a durable preparation:
normal production Manager entrypoints complete or revert within one transaction.
Its separately governed hook calls original `Core.prepareMintFromManager`; no
Core code, storage, writer or owner is substituted. The migration-stable
entitlement gate and external entropy provider remain explicit test seams.
Recipient faults reject NFT delivery or native refunds. This fixture does not
establish migration support in a production launch gate.

The [recovery action model](../../test/helpers/CurrentRecoveryActions.sol) adds
one original English auction before either incident. Its 0.02 ETH first bid and
0.03 ETH winning bid create a real refund credit and escrow liability. Token 2
is actually burned; the preparation consumes token 4 and serial 4. Recovery must
clear that preparation while retaining both high-water marks. A subsequent
production fallback prepared mint receives token 5 and serial 5.

## Actions and independent expectations

Only the selected handler can invoke the action driver. Foundry targets only
that handler's `step` selector. Sixteen required opening actions cover:

- Scheduling incident retirement, complete import and recovery through the
  actual Safe, followed by rejection before import completion.
- Failed refund delivery and settlement callbacks, with successful exits on
  either side of recovery depending on the supplied seed.
- Import of all four genuine counter leaves, the spent lifetime nullifier and
  complete definition/ancestor inventories.
- A late manifest-tail failure after the original Core abort hook, rollback of
  the entire Safe envelope, and a newly scheduled valid recovery proposal with
  the ordinary class-3 delay and one exact recovery event.
- Fresh Artist policy consent, imported-nullifier replay rejection, failed
  prepared delivery and byte-identical signed Safe retry.
- Rejected restoration of both retired writers through the actual Ledger owner,
  rejected recovery outside its Executor context, and rejected completed-action
  replay.
- A fresh outer Safe envelope carrying the already consumed mint authorization,
  plus a new entitlement that exceeds the imported counter cap.

After the opening, bounded random choices repeat replay, writer restoration,
cap, settlement and refund denials. The maximum is 64 steps. No action accepts
a protocol flag or counter read as its expected success condition.

After every action, the independent model checks consumed IDs/serials, live and
burned identities, content, preparation and entropy anchors, original and
successor operation nonces, selected Manager and unchanged canonical Ledger
pointer, permanent writer retirement, complete imports and exact Safe nonce
increments. The three original authorizations and operation roots remain spent
in their original Manager namespace; imports carry the lifetime nullifier and
counter floors rather than copying authorization/root identities into a new
namespace. Failed and over-cap claims stay unused. The successful retry must
commit the root observed in its earlier reverted trace. Reverted logs are
execution observations, never successful transaction receipts.

The economic model independently expects exact original auction terms, NFT
custody, bid escrow, refund credit, total liabilities, retained balance, zero
surplus, native proceeds, recipient balances and zero fallback revenue-escrow
liability. It checks both commercial replay maps, the paid baseline and exact
successful settlement/refund events. The auction here is the existing native
`StreamEnglishAuctionHouse` path; it does not use contract 9's universal
settlement recorder or establish ERC-20/custody-offer accounting coverage.

## Validation scope

The [host](../../test/current/StreamCurrentRecoveryActions.t.sol) has seven
deterministic tests, one input-fuzzed sequence property and one invariant.
It includes both economic orderings, fixed-seed snapshot replay, three deliberate
oracle corruptions that must revert, and rejection of an unselected driver caller.
The fuzz property selects 16–32 steps. The regression seed is `0x6529AB04`;
each step expands it with
`keccak256(abi.encode("CURRENT_RECOVERY_ACTION_SEED_V1", seed, index))`.
`afterInvariant` requires every opening category to have occurred.

The handoff retains ABI-only inputs, outputs and exact source hashes. A later
coordinated native run must select both this host and the three original
incident regressions through the existing
[acceptance wrapper](../../tools/development/run_current_acceptance.py), retain
all original deployment size checks and matched graph artifacts, and report
complete case inventory. The intended fuzz/invariant budgets remain 256 inputs
and 32 runs at depth 64, seed `0x6529`, zero handler reverts. No native test,
campaign, size, gas, release or full-v1 acceptance is claimed here.

## Selected gate-host size preflight plan

Before the separate native gate campaign, freeze the final integrated
`StreamCurrentGateInvariantTest` source closure and compare it with the original
campaign's captured source inventory. Retain a fresh capture if any dependency
changed. The handoff supplies one prepared, unexecuted standard-JSON input for
ten selected production outputs: Core; Artist onboarding registry, onboarding
coordinator and identity authority; Metadata Router; Manager; Ledger; Allowlist,
Delegate Registry and Ticket gates. This selects the gate path and large shared
authority surfaces without generating test-host bytecode.

Run that single input only in the integrator's assigned compiler slot, using
Solidity 0.8.19, via-IR, optimizer 200, Paris and no metadata hash or CBOR. Keep
the compiler input/output, executable hash, diagnostics, elapsed time, selected
creation/runtime lengths, immutable references and library link references in
a new directory. Fail on compiler errors, missing/empty selected outputs or
runtime above 24,576 bytes / creation above 49,152 bytes. Link placeholders have
fixed byte lengths; a size result alone is not a deployed-runtime identity proof.

This is a selected preflight, not an all-product size pass. The subsequent
matched-source native wrapper must still check every compiled production
artifact and every original fixture deployment guard, including dependencies
outside the ten selected outputs. Do not start a second broad build to produce
this preliminary result. The initial campaign handler, shared runners, catalogs,
production sources and immutable RC1 evidence remain unchanged.
