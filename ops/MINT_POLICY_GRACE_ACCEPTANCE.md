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

## Producer-batch checks and remaining work

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

## Selected runtime-size follow-up

The coordinator integrated the producer in `8c60b099` and its exact governance
catalog rows in `9dd5aeaa4f0620a3684e5431dbac7cd37a2c9d19`. A bounded native size
capture at that source found both original Manager products exceed the
24,576-byte runtime limit. The comparison baseline is the pre-grace integration
`91e223f522f69191ca96cb6e180b5d498e265a81`; it is not the immediate Git parent of
`9dd5aeaa`. Their complete selected import closures differ only in the three
grace production paths.

| Selected runtime | Pre-grace baseline | Integrated grace | Fixed-worker extraction | Flat-tuple experiment |
| --- | ---: | ---: | ---: | ---: |
| `StreamMintManager` | 24,174 | 25,030 | 24,611 | 25,050 |
| `StreamMintManagerFallback` | 24,310 | 25,166 | 24,732 | 25,171 |
| `StreamMintManagerPolicy` | 1,943 | 1,988 | 2,570 | 2,637 |
| `StreamMintPhaseState` | 8,440 | 8,440 | 8,440 | 8,440 |
| `StreamMintFallbackRecovery` | 5,142 | 5,142 | 5,142 | 5,142 |

The better fixed-worker extraction is retained as part of the final repair. It moves the
existing executor mutation, no-op handling, policy refresh and original event
into the already-linked Policy library. Host ownership, reentrancy and
configured-phase guards remain in Manager; all eight storage references and
the original context come directly from that host. Delegatecalls preserve
Manager identity and the actual owner/Executor caller. The exact
`InvalidPolicyGrace(uint64)` declaration is retained in Manager's compiled ABI.
Direct and actual Governor Safe cases additionally assert the original event
emitter, indexed fields, policy and admin. Hash, consent, write and Ledger
registration order are unchanged.

By itself this extraction remains **35 bytes over for Manager and 156 bytes over
for fallback** and cannot close the size gate. The
flat-tuple experiment made size worse and was restored byte-for-byte to the
better extraction; its failed capture is retained. No test execution or gas
conformance follows from these size measurements.

These four captures use the same original five selected products, Solidity
`0.8.19+commit.7dd6d404`, via IR, optimizer 200, Paris, no CBOR and no bytecode
metadata hash. Source closure counts are 147 before grace and 148 after it.
Independent verification matches both baseline/integrated Git blobs and 738
artifact metadata source references, compiler settings and every fixed-width
library-link placeholder. No broad native build was run.

Retained directories under `artifacts/native-assembly/counter-scopes/`:

- `mint-grace-size-parent-91e223f5-1`: exact pre-grace baseline.
- `mint-grace-size-9dd5aeaa-1`: integrated grace failure.
- `mint-grace-size-repair-1`: retained fixed-worker extraction; output SHA-256
  `9c0954b28679d5bde416b0fd9e8325430320e51bc3bd6054cef619029a901310`.
- `mint-grace-size-flat-1`: larger abandoned tuple; output SHA-256
  `5236f5b031b92f49d217f575654e676d67ac45877f87585211d0d0c8bdf0a721`.
- `mint-grace-size-repair-abi-final`: all 21 retained test ABIs type-check in
  the 1,002-source integrated closure. Test runtime remains pending.

### Final bounded repair

The final repair additionally moves the original nine-field `previewSubjectKey`
decoding and context construction into the already-linked Views library.
Manager retains the exact public signature and passes its immutable Ledger.
The static tuple retains strict enum/address decoding. The original Accounting
worker still reads counter configuration and Manager-scoped Ledger definitions
at the actual Manager, normalizes the same scope and computes the same subject
formula. No new phase-admission rule or mutable dependency is introduced.

The selected native capture `mint-grace-size-subject-1` compiles the exact
148-source integrated closure with only Manager, Policy and Views changed.
It uses the same settings above and selects Views in addition to the original
five products. Compilation completes without errors; all six selected products
fit the runtime limit:

| Product | Runtime bytes | Remaining bytes |
| --- | ---: | ---: |
| `StreamMintManager` | 24,331 | 245 |
| `StreamMintManagerFallback` | 24,452 | 124 |
| `StreamMintManagerPolicy` | 2,570 | 22,006 |
| `StreamMintManagerViews` | 4,069 | 20,507 |
| `StreamMintPhaseState` | 8,440 | 16,136 |
| `StreamMintFallbackRecovery` | 5,142 | 19,434 |

- Size input SHA-256:
  `959d4c3a9af16f47377533102f26350d42194a06b5e17f9c593ffa66273fa76e`.
- Size output SHA-256:
  `5d59a9fe74ee40a74d66e1c77d9aef0b8dd5479f6cab4373a3f49f05cfaaa68f`.
- Independent source/artifact verification confirms all 148 baseline blobs,
  exactly three permitted overlays, six outputs, 397 metadata source hashes,
  168 fixed-width library links and 71 bounded immutable slots. PhaseState and
  Recovery runtime artifacts remain identical to the integrated baseline.
- `mint-grace-subject-compatibility-1/result.json` compares both original hosts
  with `9dd5aeaa`: exact public ABIs (183 Manager and 185 fallback entries) and
  all 19 storage entries, slots, offsets and recursively expanded types match.
- `mint-grace-subject-abi-final-1/result.json` type-checks 1,003 sources and all
  28 authored cases. Every source matches the working checkout after newline
  normalization; the 145 shared size/test sources match each other. Fallback,
  Recovery and its interface are checked in the separate selected size closure.
  ABI input SHA-256 is
  `a29fbff11b7951ea4e2ace4370a99cacd88de4ccc10a823edc59b2cca59f7d21`;
  output SHA-256 is
  `923583511fa11b60e067619ff5e0c0837228d8e5bda9ae21e208572f33d22e1d`.

The seven new [subject-preview cases](../test/unit/mint/StreamMintSubjectPreview.t.sol)
compare the copied original function and actual Manager on identical inputs,
including exact returndata/revert bytes and independently written hash formulas.
They cover all valid modes, missing subjects, three scopes, unknown/zero phase
coordinates, invalid enum/address words, truncated/trailing calldata, an external
caller advertising different configuration, immutable Ledger and current-chain
identity. Definitions are registered before use so both comparison hosts select
the same Manager-scoped definition history; this reference host does not claim
to reproduce distinct late-definition histories.

This establishes the bounded runtime-size result, with only 124 bytes of
fallback headroom. Execution of the 28 tests, gas/fuzz checks, broad native/CI
validation, regenerated release evidence and full candidate acceptance remain
pending. Earlier failures and intermediate captures remain unchanged.
