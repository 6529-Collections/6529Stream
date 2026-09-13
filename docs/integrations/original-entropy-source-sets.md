# Original entropy source sets

A finality entropy route must cover every coordinator that actually contributed
to its scope. [StreamFinalityEntropySourceFactory](../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol)
prepares one immutable [source-set adapter](../../smart-contracts/domains/finality/StreamFinalityEntropySourceSet.sol)
from the complete original-coordinator inventory. Its single component commits
all native source identities and policies. This keeps the existing one-route-per-family
recovery model unambiguous when Core's entropy pointer has changed.

## Construction and current discovery

Deploy the factory from already-live Core, generic Metadata, authoritative scope
membership and coordinator inventory, with their exact runtime hashes and chain.
The factory does not depend on the later provider, original Finality registry or
artist Coordinator. Complete discovery pins this factory and its runtime once.

For an actual scope:

1. Finish the token and original-coordinator inventories using their bounded
   indexing calls. Every actual native policy in the scope must be locked.
2. Call `prepareSourceSet(scope)`. The factory derives the plan from authoritative
   current membership and constructs a child only after validating the complete,
   nonempty original inventory. Preparation is permissionless and idempotent.
3. Obtain `requireCurrentComponent(scope)` from the fixed factory. It checks
   the immutable prepared child, complete current inventory, every original policy
   and the currently selected generic Metadata. Whole discovery includes this
   single expectation in its normal sorted component list.

An unprepared scope, empty source set, unlocked policy, stale inventory or
changed source is rejected. The factory has no setter for a scope's source set
and accepts no caller-supplied coordinator list. A new membership plan receives
its own child; an old child and its recorded evidence remain inspectable.
The factory is only the entropy-family projection; it does not implement the
complete finality discovery or admit a new finality candidate by itself.

## Exact retained evidence

The child exposes its original scope, all eight membership facts, inventory plan
and completion hash, ordered policy-chain hash, source count and every full
native policy tuple. The source-set manifest hash binds the versioned profile,
fixed dependency configuration and original token-inventory runtime. Its data
hash additionally binds scope, plan, complete inventory/policy commitments and
membership facts. These are distinct from a native coordinator's module identity.

Every `finalityState` read checks every original source's current runtime,
module identity and exact locked native policy against the retained tuple.
It reports the source-set adapter's own code, profile, manifest and data hash.
Historical reads do not require today's selected entropy pointer or newly
extended collection membership. New discovery separately requires current
completeness. The indexing-time code pin does not prove mint-time code.

## Token serving and recovery

The adapter explicitly advertises `IStreamFinalityEntropySourceSet`; it does
not claim the native `IStreamEntropyCoordinator` API. The frozen metadata path
recognizes this capability on the already-authenticated route adapter and calls
`tokenSeedForFinality`. Existing native-host adapters retain their original
`tokenSeed` path.

The resolver first checks actual Core token identity and minted/burned lifecycle.
A collection token must lie within the captured inventory count and equal the
original token at its exact collection serial. TOKEN requires exact identity;
RELEASE, SEASON and VIEW require the original sealed membership facts and inclusion.
It then derives `coordinatorAtMint`, authenticates that source against its
retained policy/runtime and returns the actual native seed and completion flag.
A later token using the same coordinator cannot enter an older collection prefix.
Pending entropy remains pending.

The existing recovery approval/manifest semantics replace one complete entropy
route. The route's component health depends on all retained sources; a broken
source fails the complete component check until the applicable recovery occurs.
This increment does not itself complete registry execution or end-to-end recovery.

## Validation and gas profile

The source-set cohort exercises two actual native coordinators, including actual
registration, requests and fulfillment through a test randomness provider.
Metadata, Schema, Store and both inventories are actual contracts; Core and
governance are explicit fixtures. A separate frozen-serving cohort checks the
production route/renderer dispatch with a typed composite boundary. Snapshot
and prior policy cases are retained in the same compiler capture.

Typed serving reserves a 6,000,000-gas callee envelope; native-host serving retains
150,000. Tests use 500,000 per-source reads and 3,000,000 membership reads, through
an 8,000,000-gas outer harness, and include a low-parent-gas failure followed by
exact retry. These caps are nested calling-frame requirements, not measured
transaction costs. Reported cold measurements name the accounts cooled by the
test and exclude transaction intrinsic gas.

Preparation, retained policy storage and full component validation scale with
original source count. Two-source results do not establish arbitrary-count or
maximum collection capacity. Complete full-stack construction, governed caller
budgets and the entire Safe selector/version/nesting matrix remain separately
tracked in the delivery ledger.

The reviewed combined capture passes 65 cases in both default and IR modes:
31 source-set/policy cases (15 new source-set cases and 16 inherited policy
cases), 23 snapshot cases, and 11 frozen-serving cases. These are component
and dispatch tests with the explicit boundaries above; they do not establish
a complete deployed Registry, companion and provider graph.

Under the named cold-account setup, published-family dispatch uses 320,148 gas
in default mode and 302,445 in IR. All five scope families pass through the
8-million outer call and 6-million typed serving envelope; the deliberately
insufficient outer call rejects and its exact funded retry succeeds. These
figures exclude transaction intrinsic gas and are not an arbitrary inventory
capacity or universal cold-state claim. All captured production runtimes fit
the EVM size limit, including the factory's embedded child creation code.

## Actual Core and governed replacement

A separate four-case IR capture uses actual Core, Governance Executor, role and
module registries, System Manifest and a threshold Safe. Two new cases execute
native-source registration, governed pointer replacement, real mint-time source
retention and callback fulfillment. They prove pending and completed seeds,
retained reads after burn, exclusion of later collection tokens, and unchanged
published RELEASE/SEASON/VIEW membership after the parent collection grows.
The production typed entropy-serving path returns each token's original seed.
Two existing governed-foundation cases also pass in this capture.

Mint-manager admission and artist/original-Finality selection remain fixture
boundaries, and randomness is supplied by an explicit test provider. This closes
the earlier Core/governance boundary for the named flows without claiming an
assembled original Registry, complete provider or external VRF integration.
