# Same-call metric supplement validation

This page retains the first same-call transport's measurements. The additive
[compact transport](reference-metric-compact.md) replaces its large internal
proof projection while preserving the original public oracle paths.

Metric supplement publication and the required-supplement reader reuse the full
publication and mode evidence authenticated during the same call. The previous
paths read, decode and hash those large immutable records again before checking
the metric proof. This change removes that duplicate work while preserving the
original fresh source checks and full-byte integrity checks.

The host still checks the original known record, current head and revision
first. The fixed write worker then checks current source/runtime/schema facts,
the full publication/evidence context and retained payload, followed by the
original lock, writer authority, once-only supplement state, definitions and
complete metric proof. The fixed read worker performs the same current-source
checks before validating the complete stored supplement and original receipt.
No checked value persists between calls or is accepted from an external caller.

The metric proof receives every field its original implementation uses: the
metric implementation and parameter commitments, threshold, report and evaluation
time; full environment object/manifest identity and all package members; viewport
and pixel ratio; every repeated-capture digest; and the complete authenticated
context hash. The original proof body remains available through its original
public wrapper. Platform prerequisites, browser facts and captured HTML remain
in the full context even though the metric algorithm does not inspect them
individually.

The original host ABI, storage layout, receipt/hash domains, event fields and
mutation order are unchanged. Standalone currentness and the original public
Storage/Proof entrypoints remain available. Other finality/locking paths retain
their original semantics. No gas cap or admission guard changes.

## Evidence boundary

The selected original-settings size gate covers all six affected production
products. Runtime sizes are 23,100 bytes for the write worker, 20,995 for the
read worker, 14,978 for Proof, 18,443 for Storage, 24,307 for Preparation and
22,561 for the publication host. The earlier combined-worker size failures are
retained separately. Compiler ABI/storage comparison preserves all 98 original
host ABI entries and its full semantic storage layout; Proof adds one fixed
projection entrypoint without changing its original entries.

The focused test fixture uses an actual immutable Store, complete 1,048-member
package and 102-member platform corpus, and the original metric proof. Its
source/facts/definition boundaries are explicitly mocked and its writer grant
is a typed boundary. Its replay context is rebound synthetic test evidence,
not a new archived-runtime execution. Tests compare literal original runtime,
replay and receipt preimages, complete payload bytes, proof results, error order,
source drift, lock/writer denial, corruption rollback and retry. Fresh-frame gas
diagnostics use shared warmed dependencies and are not a cold transaction-cap
claim. The frozen 134-source capture passes all 17 cases, including two 256-case fuzz runs. All 140 artifact metadata records and 2,673 source Keccak joins match the retained inputs; the six native product sizes match the selected gate.

The measured isolated publication path falls from 28,288,606 to 20,627,939 gas;
required-supplement validation falls from 31,706,338 to 25,059,552. These savings
do not establish capacity: both new measurements still exceed 16,777,216 before
transaction overhead, and the reader also exceeds the original 14m validation
budget. The source transport is equivalent and smaller in gas cost, but the
remaining proof/serialization cost needs further work before an actual retry.

## Actual publisher limitation

The retained native14 graph passes seven of its nine original cases after an
independent restored metric execution regenerated the exact native13 context.
The actual reference publication uses 15,664,912 gas including calldata intrinsic
cost and fits the original 16,777,216 transaction envelope. Two supplement-stage
cases remain failures: the bounded required-supplement read exhausts its 14m
validation budget, and supplement publication reaches the original writer
read without enough parent gas after currentness validation. This focused
transport repair does not close either actual-graph failure until a separately
authorized frozen successor runs those unchanged envelopes successfully.
