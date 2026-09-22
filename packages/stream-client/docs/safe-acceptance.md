# Executable Safe acceptance inventory

This offline tool enumerates the supported source graph and reconciles explicit
per-call evidence. Its [compact summary](safe-acceptance-current-summary.json)
and [supported-contract backlog](safe-acceptance-backlog.md) are **uncovered**,
not Safe acceptance. The full machine report and expanded selection profile are
retained outside tracked documentation, with their exact hashes in the summary.
It implements the inventory promised by [the acceptance plan](../../../ops/SAFE_ACCEPTANCE.md).
The historical `current-v1-safe-coverage.*` ABI102 client inventory remains frozen.

## Current capture and scope

The externally retained `safe-acceptance-current-profile.json` pins ABI176 at source
`aa2ca4a2764ca981630c668966a665637692842d`, compiler input/output bytes,
compiler settings, the 37-role genesis profile, and the planning deployment
candidate. Its inputs contain 4,279 literal Solidity sources. ABI176 is an
ABI/type/storage/method-identifier capture, with **no AST or native runtime**.
It does not establish runtime compilation settings or acceptance of later source.

The source profile records explicit graph products, constructor/creation-code
edges, qualified library calls, inheritance and named forwarding routes. The
64 original graph enum entries, 37 logical roles, compiled products, libraries
and deployed instances are different inventories. Source reachability includes
code candidates; it is not a deployed graph. Unresolved using directives,
dynamic creation, clones and facade routing remain visible gaps. The planning
candidate contains no instances. Distinct genesis roles are retained even when
they share an implementation ABI.

Every selected compiler ABI function is enumerated, including inherited methods,
getters and overloads. Keys contain the full `source.sol:Contract`, complete
signature, selector, ABI/source hashes and capture identity. Receive and fallback
entries come only from the compiler ABI. Callback obligations are separate;
an external Safe receiver obligation does not invent a protocol contract.
Compiler method identifiers retain nominal library signatures. Missing AST
declaration origin and ambiguous library selectors stay unresolved.

The full machine report contains 8,958 ABI functions, three receive entries and four
callback obligations. Another 3,305 `compiler-method` records preserve exact
compiler signatures/selectors whose ABI linkage is unresolved; they may represent
the same functions as tuple-expanded ABI records and are **not** 3,305 additional
proven callable functions. Of the ABI functions, 1,783 have no resolved selector.
The 1,529 selected products comprise 164 source-declared contracts and 1,365
libraries; declaration kinds have not been compiler-AST verified. Full ABI arrays
stay in the authenticated compiler output; the report retains their hashes and
all enumerated entries. Its profile hash binds the explicit selection manifest.

The primary backlog is **6,553 functions across 164 supported contract surfaces**.
It excludes the 2,405 library ABI functions and 3,305 unresolved compiler aliases.
Each product's explicit `safeExposure` distinguishes `supported-contract`,
`implementation-only`, and an opt-in `externally-supported-library`. Missing
exposure stays unclassified. Implementation-only libraries need evidence through
the actual business path and applicable call guard; their classification alone
does not establish testing or add a mandatory independent Safe transaction.
Receive/fallback, callbacks and actual deployment bindings stay separate.

## Run without compilation

Use Node 22 and the package's existing pinned dependencies. From the repository
root, with the authentic retained `abi-input.json` and `abi-output.json` paths:

```powershell
$abiCapture = 'PATH/TO/parallel-feature-batch176-20260922'
$safeEvidence = 'PATH/TO/retained-safe-call-inventory'
node packages/stream-client/scripts/reconcile-safe-acceptance.mjs `
  --input "$abiCapture/abi-input.json" `
  --output "$abiCapture/abi-output.json" `
  --profile "$safeEvidence/safe-acceptance-current-profile.json" `
  --claims packages/stream-client/docs/safe-acceptance-claims.json `
  --genesis release-artifacts/genesis-deployment-profile.json `
  --deployment deployments/config/canonical-deployment-candidate-v2-planning.json `
  --report "$safeEvidence/safe-acceptance-current.json" `
  --summary packages/stream-client/docs/safe-acceptance-current-summary.json `
  --backlog packages/stream-client/docs/safe-acceptance-backlog.md `
  --check
```

Omit `--check` to write the deterministic report, compact summary and backlog.
Keep the expanded profile and full report in an ignored artifact directory or
external evidence location, not tracked documentation. Add `--source-root .` when
checking whether the current checkout still matches **all** captured sources.
Only UTF-8 CRLF-to-LF transport is allowed for that comparison. A changed source
fails the comparison; the tool never relabels historical capture evidence.
Without that option, the command reconciles the explicitly pinned snapshot.

Missing classifications and execution evidence produce a valid uncovered report.
Malformed identities, stale hashes, dangling claims and report drift fail the
command. Exit zero means the offline report was produced or reproduced; it does
not mean Safe acceptance. No compiler, EVM, RPC, new dependency, CI wiring or
release approval is involved.

Focused verifier tests:

```powershell
node --test packages/stream-client/test/safe-acceptance-inventory.test.mjs packages/stream-client/test/safe-acceptance-reconciler.test.mjs
```

The tests use conspicuously synthetic documents to test the verifier. They are
never imported into the current report as execution evidence.

## Add classifications and evidence

`safe-acceptance-claims.json` binds to the exact capture. Each classification
names one `entryId`, caller class, route, caller sensitivity, rationale and
source references. References use a captured Solidity path, its full-content
SHA256, and one-based `startLine`/`endLine`. A reviewed classification is not an
execution claim.

Supported contract caller classes are `user`, `artist`, `admin`, `permissionless`,
`read` and `protocol-only`. Required scenarios include `authorized-safe`; role-bearing
calls also require `invalid-role-safe` and `owner-eoa`. Protocol-only calls need
`enclosing-safe-workflow` success and `direct-safe-rejection`, with the independent
classification review already required by the acceptance plan. Safe reads need
`return-in-safe-context`; invoking a read and later checking it from another
caller does not discharge that assertion. Every scenario names its caller,
expected outcome and exact assertion kinds.

An implementation-library classification uses `callerClass: "implementation-only"`
and route `safe-initiated-protocol`. Its `enclosing-safe-workflow` scenario must
assert both `enclosing-business-path` and `applicable-callguard`; it does not
automatically require a separate direct Safe transaction for each helper ABI.
Unmatched compiler aliases must be resolved before they can be classified as
calls. Neither source classification changes runtime evidence status.

Deployment bindings are explicit: source capture, FQN, address, chain, runtime
hash, linked libraries, immutables and deployment configuration identity. Local
test deployments have `scope: "local-test"`. They never fill the planning
candidate's absent production instances. Safe configurations pin version,
fixture bytes, threshold, owner count, modules, guards and nesting. The checked-in
baseline templates are 2-of-3 Safes for 1.3.0, 1.4.1 and 1.5.0. A 2-of-2 test
cannot stand in for any of those templates. Larger and nested configurations
remain unspecified acceptance work.

Evidence kinds `mock-client`, `authored-only` and `source-reviewed` are retained
as candidates and cannot increase runtime coverage. Current candidates identify
real source assertions and clearly state their missing execution and configuration
boundaries. No test-name search, broad suite count or historical prose pass can
populate coverage.

The `actual-safe-native` adapter accepts retained execution from
`tools/development/run_native_execution_view.py`. It requires hashed result,
execution view, exact host stdout, effective config, native build-info and host
artifact references. It checks an actual `PASS_EXACT_TEST_ROSTER` run with
`listOnly: false`, empty integrity errors, an exact successful ABI test case,
view/host/build joins, dispatch/input hashes, exact source closure and target ABI.
Native Paris/IR/optimizer-200 settings are checked separately from ABI176's
ABI-only settings. It does not run or repair that evidence.

An execution claim also needs an explicit reviewed per-call assertion map:
reviewer and captured source ranges, exact deployment target and Safe configuration,
transaction route/to/data/value/operation/nonce/hash/domain, caller, inner outcome
and each scenario's state/event/return assertions. Protocol hops identify the exact
inner FQN/signature/selector/target. Direct protocol-only rejection uses a direct
Safe call; the owner-EOA negative uses `owner-eoa-call`. Outer transaction success
alone does not establish inner success. Safe failure/nonce behavior must be part
of the relevant scenario assertions.

This adapter verifies the identity and provenance of an explicitly reviewed
mapping; it does **not** statically prove that a Solidity assertion executes or
is sufficient. That review is visible in the claims. Fabricated or incorrectly
reviewed evidence is not made trustworthy by hashing it. A qualifying cell is
therefore labeled `covered-local-reviewed-test`, scoped to one deployment,
scenario and Safe configuration. Live receipt reconciliation, complete dynamic
route/clone witnesses, cold gas, all-configuration acceptance and audit readiness
are outside that label. `completeAcceptance` deliberately remains false.

When source or supported products change, obtain a new authentic ABI capture
from the compilation owner, revise the explicit product/edge and role mappings,
then regenerate. Old entry IDs and cross-source claims will fail. Carry evidence
forward only through a new reviewed source/deployment binding; this tool does
not infer equivalence from matching selectors or unchanged function text.
