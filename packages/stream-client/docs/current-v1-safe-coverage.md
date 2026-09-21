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

The [canonical native/ERC20 Dutch clients](current-canonical-dutch.md) separately
retain ABI121 for original purchase/payment entry points, pull refunds and
historical Manager revocation. Carrier callbacks remain protocol-only.

The [tagged full-policy VIEW client](current-tagged-policy-view-v2.md) separately
retains ABI125 for actual Router adoption and original current/historical
serving. Nominal library methods remain separate from wallet call plans; this
profile adds no VIEW publication or finality ceremony.

The [scoped full-policy graph client](current-scoped-policy-graph-v2.md)
separately retains ABI129 for the original scoped source factory and fixed
seven-child publication factory. Graph preparation grants no publication or
finality authority and preserves the separate COLLECTION and VIEW profiles.

The [scoped full-policy publication client](current-scoped-policy-publication-v2.md)
extends that same ABI129 profile with original checkpoint, covered-output and
root-free snapshot calls. Snapshot writer grants, Artist root consent and
governance/finality authority remain separate requirements.

The [scoped full-policy root client](current-scoped-policy-root-v2.md) retains
the same original source profile for Artist operation-17 consent and Router
root adoption. The signed collection-wide family, historical aggregate and
actual consent consumption remain distinct commitments.

The [scoped full-policy reference client](current-scoped-policy-reference-v2.md)
continues the original ABI129 profile with environment and file-inventory
preparation plus reference publication. It preserves the distinction between
fresh external coverage, the original current receipt pair and immutable history.

The [scoped inventory and bundle archive clients](current-scoped-policy-inventory-archive-v2.md)
add the original seventeen inventory and five bundle writes under ABI129.
Authenticated ordered segment rows, immutable admissions, current inventory
sources and current-environment refresh retain their separate evidence roles.

The [historical scoped-policy finality client](current-scoped-policy-finality-v2.md)
adds Registry manifest staging and the original Executor's payload publication,
class-2 scheduling and execution. Archived Registry finalization is the nested
target call. Provider and Discovery are read-only, and a Safe does not acquire
the Executor's authority by encoding the Registry call. This profile remains
tied to ABI129 and rejects unsupported newer current-authority and VIEW profiles.

The [complete VIEW binding client](current-view-complete-binding.md) starts the
separate ABI146 profile for both genuine preservation providers. Its three
outer writes publish, schedule and execute one complete class-2 binding through
the original Executor. The nested provider call consumes the same one-use guard
as basic binding and records both receipts. Direct and Safe CALL preparation
does not establish native execution or complete VIEW finality.

The [token preservation V2 output client](current-token-preservation-output-v2.md)
adds checkpoint begin/append and covered-manifest begin/verify callers under the
same ABI146 source. Each selected Registry admission retains its actual
original or current-Artist producer profile. Large append calldata has a local
bounded transport path; the original historical transport limits remain fixed.

The [token preservation V2 snapshot client](current-token-preservation-snapshot-v2.md)
adds collection and scoped `publishSnapshot` calls with the actual caller's
SNAPSHOT and IDENTITY family-writer grants. Preview, retained canonical bytes,
direct/Safe receipt evidence and operative currentness remain distinct stages.
Currentness reuses recorded grants; a new publication checks fresh grants.

The [token preservation V2 reference client](current-token-preservation-reference-v2.md)
adds four permissionless environment/inventory preparation calls and the
collection/scoped `publishReference` call. Publication uses the actual
recorder's class-3/class-8 CURATOR grant and retains both payload and submitted
publication bytes. First/last samples verify the saved producer's current
Registry admission; fresh coverage and current receipt-pair checks remain distinct.

The [current-authority preservation inventory client](current-authority-preservation-inventory-v1.md)
adds the nineteen original writes on each collection/scoped inventory host.
Permissionless materialization preserves the resolver-selected Artist route,
original receipt witnesses, ordered archive origins and their runtime rows.
The nominal V1 hosts use the fixed token preservation V2 family. Sealed
inventory evidence and current eligibility remain separate from archive coverage.

The [current-authority preservation archive client](current-authority-preservation-archive-v1.md)
adds five operations per collection/scoped host under the ABI155 source witness.
It preserves original proofs, exact V2 byte correspondence and ordered archive
origins, with separate historical evidence and current coverage refresh.
Initial automatic refresh observation chains remain observed-only; explicit
refresh transitions can be reconstructed from their captured prior state.

The [attributed VIEW retrieval witness client](current-view-retrieval-v1.md)
adds the separate ABI157 producer's two ordinary publish/revoke calls. It
preserves the original raw observation digest, institutional writer, scope-shared
nonce and mined-time receipt commitment. The companion retrieval-enabled VIEW
inventory and Bundle consumer are separate pending workflows. Source and client
checks do not establish actual Safe execution or linked runtime provenance.

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
