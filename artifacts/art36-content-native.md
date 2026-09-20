# Recovered content component native evidence

Source: `af2cbe8fd3b42eab1a455ca0f20c7bbee9502c99`.
Tree: `474e2aba02d942303f98782354bece8d4040b8d8`.
This is the integrator's source after the content capacity refactor.

## Integrator's selected size capture

The retained `joined-content-capacity-20260920` native capture covers727 sources,
has zero compiler errors and reports all15 selected products below the runtime
deployment limit. Relevant runtime byte counts are:

| Product | Bytes |
| --- | ---: |
| RecoveredContentConsentHydration | 19,200 |
| RecoveredContentConsentReads | 13,978 |
| RecoveredContentConsentValidation | 12,513 |
| RecoveredContentConsentFactRows | 8,235 |
| ConsentFinalityLifecycle | 21,951 |
| OnboardingCoordinator | 24,532 |
| IdentityWriterExtension | 24,535 |

The former ContentConsentFacts library is now an internal projection facade;
its four-byte emitted shell is not an independent validation runtime. The actual
validator is the linked FactRows product above. Consent bare creation is48,318
bytes. Bare creation does not include constructor arguments. Prepared's separate
106,169-byte source remains under repair and is not included in this acceptance.

Selected-size input SHA256:
`070b4be97b652bcdacc36045f9958e72c097318f9e953007d4f4b3a1b00b894f`;
output SHA256:
`48c593c03d4912f80f73130f6753d968a353799b2986a31a4a488e2d53eff8c8`.
Independent retained-artifact review verifies all727 input sources byte-for-byte
against this Git commit and recomputes every selected runtime/creation size.
The15 selected input products, output products and result rows agree exactly.
There are256 compiler warnings and no size/initcode warning. Coordinator and
IdentityWriter have only44 and41 runtime bytes of headroom, respectively.
The result file SHA256 is
`74b04c1d2be9ab74e35cb8deda2c81c275b53292e11331d13a351aa8eeb85251`.

## Focused execution scope

The integrator authorized exactly20 ContentConsentHydration codec/parity tests
and15 ContentConsentFacts tests. Their233-file import closure is captured from
the source above without altering Solidity bytes. The component fixture directly
constructs its contracts; it needs no RPC, file fixtures, native-graph projection
or actual seven-owner operation60 host. Imported test contracts outside the two
anchored suite names are compiled but not executed.

The task-local capture retains full native build-info, artifacts, source hashes,
the exact configuration, command logs, expected cases, actual results and all
nonempty production runtime/bare-creation sizes. It uses Forge1.7.1, Solidity0.8.19,
viaIR, optimizer200, Paris, no CBOR and no bytecode hash. Only current-profile
test discovery changes from test/current to test; original fixture gas, memory
and test-host code-size limits remain. No production size acceptance is inferred
from those aggregate fixture limits.

The first native capture stopped before execution after921.078 seconds with a
via-IR stack exception naming `var_f_124842_mpos`. Exact AST-only diagnosis maps
that variable to the return value of the imported economics test's `_fixture`.
No selected test executed, and that failed capture remains unchanged.

The test-only repair splits ordered fixture writes and the subsequent provenance/
collection read into self-only external helper calls. The Coordinator fixture
still sees the test contract, and the actual Consent owner still sees its original
Coordinator. All values, classes, nonces, ordering and13 imported economics test
bodies/assertions remain unchanged. Independent source review is clear at
SHA256 `655f07cedf71f12a9d06db5eab5c95a58d6a3b738bb0c0b87837b5a2a8eb7a3c`.
The two selected Content hosts are untouched.

The repaired233-source AST/ABI capture has zero errors. Selected native code
generation for the exact formerly failing test host now completes with zero
errors in84.812 seconds, retaining input SHA256
`5df3ef41838920569db7983518537c06b1134eff359b0daa35117cd96721ba8e`
and output SHA256
`b55ec483aae29d987ac93e5e06b3ff8419458523a2a2a48bef828a9ffd9dad39`.
This confirms test-host compilation only; the focused35 runtime retry remains
pending at this source checkpoint.

Independent capture review verifies all233 Solidity files byte-for-byte against
the source Git blobs, exact import-closure membership, the sole configuration
change and the runner's exact20/15 suite/case checks. Captured inputs and native
artifacts must remain unchanged through execution.

## Evidence limits

Codec execution covers actual original owner6 writes, revisions and replay,
canonical bytes and linked workers, copied map/head/delegation state, malformed
input rejection and the enclosing two-phase import caller's rollback. The15
fact cases use partial synthetic certificates for cross-owner reconciliation.
The fixture's authority, binding and grant facts are supplied at its typed
Coordinator boundary; a repeated-era component certificate is explicitly synthetic.

This is not actual seven-owner operation60, genuine recovery/Safe authorization,
live grant-capability authorization, Archive rollback or genuine repeated-import
acceptance. Constructor-argument capacity, Prepared, full graph, gas, fuzz and
invariants, full CI and release acceptance remain separate gates.
