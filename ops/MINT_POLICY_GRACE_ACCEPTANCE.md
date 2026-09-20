# Mint policy grace producer acceptance

## Scope and source

Based on `ac14604f2404eb67df8320994a9dafeb04f6c87c`, 20 September 2026.
This batch closes a production reachability gap: Ledger, Manager readers,
gates and sale consumers already supported grace, but both Manager registration
paths always supplied zero. It adds an owner-only executor update with a
caller-supplied grace deadline. Phase/counter reconfiguration remains excluded.

The production change is limited to
[Manager](../smart-contracts/domains/mint/StreamMintManager.sol), its existing
[policy worker](../smart-contracts/domains/mint/StreamMintManagerPolicy.sol) and
the new [capability](../smart-contracts/interfaces/stream/mint/IStreamMintPolicyGrace.sol).
No storage layout, original Manager interface ID, ticket digest, operation
identity, Ledger code, counter rule or current Artist authority check changes.
The linked policy worker receives the deadline after the same original
mutation, hash, consent and policy-write sequence. Ledger rejects excessive
deadlines atomically. Ordinary `setPhaseExecutor` still supplies zero.

The additive selector/interface ID is `0xdef72e30`, verified with `cast sig` for
`setPhaseExecutorWithGrace(uint256,bytes32,address,bool,uint64)`. The coordinator
owns its exact class-1 current deployment and shared-fixture catalog rows.
Those rows are required for the current Safe recipes to execute after handoff;
this task does not introduce a wildcard, owner replacement or test impersonation
to bypass that dependency. Fallback inherits the capability through Manager,
but each admitted Manager address needs its own exact governance row.

## Authored acceptance

[Focused tests](../test/unit/mint/StreamMintPolicyGrace.t.sol): 16 cases with
actual Manager, Ledger, Module Registry and signed-ticket gate. Core, Artist
and governance are explicitly typed boundaries. Production grace is always
created through Manager's public owner entrypoint; no storage injection or
prank as Manager manufactures a tuple. A separate small writer tests Ledger's
initial-registration rejection and is labeled as Ledger-only evidence.

The focused cases cover exact independently reconstructed operation identity
and eight receipt tuples; inclusive, expired and maximum deadlines; rejection
beyond 30 days with complete rollback; immediate predecessor replacement;
zero-grace clearing on a real rotation; unchanged request rejection/preservation
without a revision increment; owner and removed-executor checks; Artist failure
and retry; loss of current Artist mint authority after a successful rotation;
late Core failure; replay; and deterministic A-to-B-to-A restoration.
Current cap enforcement remains in the original code. Existing Ledger tests
that explicitly tighten registered caps remain separate from this additive
executor-only producer; this batch does not pretend to reconfigure counters.

[Current helper](../test/helpers/CurrentMintPolicyGraceFixture.sol) and
[current tests](../test/current/StreamCurrentMintPolicyGrace.t.sol): five cases
using original artifact construction, actual Core/Artist/Manager/Ledger/gate,
real governance delay, and separate official threshold-two Artist, Governor,
ticket signer and mint executor Safes. The external entropy provider and the
deliberately rejecting recipient are explicit test boundaries.

1. Missing exact new-policy Artist consent rolls back an already scheduled
   Governor action. Recording the actual Artist Safe consent permits the same
   signed Governor transaction. An original previously signed ticket then
   mints under its distinct predecessor hash, emits exact current/bound Ledger
   evidence, reveals through the real Coordinator and rejects replay.
2. A predecessor ticket mints at the inclusive deadline. A second unchanged
   signed ticket previews successfully then rejects one second later while
   its own deadline remains live. A current-policy ticket still mints.
3. Two actual delayed Governor rotations discard the oldest hash before its
   former deadline. Immediate-predecessor and current tickets share the same
   cap; a third mint cannot exceed it or consume a new authorization.
4. Removing the original executor denies its live predecessor ticket while
   another admitted Safe's original predecessor ticket still succeeds.
5. A two-token prepared batch reaches Ledger and the second recipient rejects
   delivery. All allocation, preparation, counter, replay, root and Safe nonce
   writes roll back. Repairing that external recipient permits the identical
   original signed Safe batch. Reverted logs identify the attempted root;
   only the successful retry supplies committed receipt evidence.

## Checks and remaining work

The combined ABI/type check is clean across 995 sources and finds all 21 authored
tests. Its final retained capture is
`artifacts/native-assembly/counter-scopes/mint-policy-grace-combined-abi-final-2/`:

- Input SHA-256: `d9716e0047a56664572033cace7657a4a630f858ac4c4b06459ce9c9b276fa58`.
- Output SHA-256: `7ab47caf4d0cba08152bf6c2964b1ea353a3d007ec4e4b70198da7efa2d42397`.
- All 995 captured source contents match the working source after newline
  normalization. Comparing compiled Manager ABI with the preceding offer-batch
  capture removes or changes no existing entry; only the new function and
  `InvalidPolicyGrace(uint64)` error are added.
- Separate baseline/changed storage-layout compilation compares all 19 Manager
  storage entries, slots, offsets and recursively expanded types with no change.
  Its capture is `artifacts/native-assembly/counter-scopes/mint-policy-grace-storage-1/result.json`.

Two preliminary captures retain test-only missing preview/cheatcode-selector
errors. Solidity 0.8.19, via IR, optimizer 200, Paris, no CBOR and no bytecode
metadata hash are the requested settings; ABI-only output does not execute
native code generation or tests.

Independent source review covers the producer and both test compositions.
Seventeen documentation checker tests, link validation, changelog validation
and scoped Windows whitespace checks pass. New Solidity files and the policy
worker pass formatting; unrelated pre-existing Manager formatting is preserved.
Native code generation, 21 test executions, Manager/fallback runtime size,
gas/fuzz evidence, generated release artifacts and full candidate acceptance
remain pending. In particular the inherited fallback previously had limited
runtime headroom; this source addition is not a size acceptance claim. The
coordinator chooses the joined source including the exact governance row and
retains all prior frozen captures.
