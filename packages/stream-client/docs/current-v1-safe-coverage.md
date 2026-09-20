# Whole-v1 Safe caller inventory

[The machine-readable inventory](current-v1-safe-coverage.json) is a bounded
source audit of ABI102 at `70c0d9c37f6435c480b87083af8d1cbd4fa7098d`.
It starts with the canonical 37 genesis roles and the original Artist operation
register, then includes concrete companion contracts discovered in the current
graph construction source. It does not prove deployed instances or their
activation.

## Read the stages separately

Each implementation lists exact compiler signatures and selectors, mutability,
native-value requirements, source declaration evidence and candidate client
references. Named support profiles identify manually reviewed bounded clients
with their own retained source/ABI fixtures. A profile can cover only part of a
method's behavior, such as one hydration graph or one attestation subject.

| Field | Interpretation |
| --- | --- |
| Role mapping | Source-backed implementation candidate, including explicit alternatives and unresolved names. |
| Endpoint | Proven caller restriction where available; otherwise review is required. |
| Native value | Zero for nonpayable writes; payable amounts need the original method's accounting rules. |
| Lexical client candidate | A place to inspect; a method-name occurrence establishes no support. |
| Support profile | A bounded, source-qualified client implementation and its evidence references. |
| Stage | Encoding, typed preparation, caller/value checks, simulation, direct receipt, Safe composition, Safe receipt or typed read. |

`review-required` is an unresolved audit item. `verified` applies only to the
named profile's client evidence and source. The current personhood profile has
focused client tests and independent source review; older profiles retain their
historical qualifications. Neither establishes every current ABI102 behavior or
actual Safe execution. A matching selector cannot establish that deeper runtime
behavior stayed unchanged.

The role count is not a function count. Governance may comprise several hosts;
fallback instances are distinct deployments with a shared ABI; Artist and
Metadata facades route to companion contracts. The split-wallet implementation
is locked and user claims target initialized clones. Missing deployment mappings
and fallback routing evidence remain explicit.

## Safe and protocol callers

Use the shared `createSafeCallPlan` for an already reviewed ordinary CALL.
It preserves target, calldata, caller and value but supplies no protocol
authority. An Executor-only action still needs its genuine current-action
context. A callback callable only by a Manager, settlement host or the contract
itself remains part of that enclosing protocol flow.

View/pure functions do not require transactions. Their caller restrictions still
matter: an external self-only read frame is not a general wallet query. Typed
read support is recorded separately from transaction support.

## Implementation queue

The first added caller from this audit is the
[canonical personhood reference profile](current-artist-personhood.md) of the
original principal Artist operation 24. A later
[recovered-history operation-60 caller](current-artist-recovered-hydration.md)
is qualified separately against ABI104, including its reviewed delegation and
attestation compositions. The additive
[recovered content and freeze consent caller](current-artist-recovered-consent-hydration.md)
is qualified against ABI106 and its explicit 511 feature profile. This machine
inventory retains its ABI102 snapshot
and original client evidence. ABI102 supports the class-1/class-3 singleton
profile and direct-economics extension; recovered personhood and delegation
feature bit 64 remain excluded at that earlier source.

The later [revenue pull and recovery client](current-revenue-pull.md) is qualified
separately against ABI107 for initialized clone claims, Router batches and
Escrow flush/recovery, including the required Executor stages.

The [canonical native sales client](current-canonical-native-sales.md) separately
retains ABI113 for fixed/open and free/PWYW purchases, excess refunds and original
Manager revocation. It preserves the earlier native-adapter signing profiles.

The [recipient Merkle distribution client](current-distribution-merkle.md)
separately retains ABI117 for published recipient allowances and original
distribution/claim CALLs. Earlier STATIC program hashes and evidence are preserved.

This retained inventory still records gaps for governance/control families,
clone claims and escrow, original records/read surfaces, Core/mint controls, and broader
Artist variants. It is an implementation queue and review register, not a
whole-v1 completion or release-readiness claim.

## Reproduce

Using the retained ABI102 files, run from this package:

```sh
node scripts/generate-current-v1-safe-coverage.mjs ABI_INPUT ABI_OUTPUT --check
node --test test/current-v1-safe-coverage.test.mjs
```

The generator verifies exact input/output hashes and frozen source references.
It does not compile Solidity, change global ABI exports or generate deployment
artifacts. Client files changing can change their candidate references and
require regeneration. Run the full package once the coherent caller batch is
frozen; source inventory does not replace runtime acceptance.
