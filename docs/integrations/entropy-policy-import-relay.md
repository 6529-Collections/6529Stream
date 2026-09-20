# Entropy policy import and original-provider relay

This developing profile lets a replacement Coordinator preserve the configured
collection policies of its predecessor. The two additive contracts are
[`IStreamEntropyPolicyContinuity`](../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol)
and [`IStreamEntropyOriginRelay`](../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol).
The focused 210-test suite passes and all 38 compiled entropy products fit their
deployment-size limits. A separate 16-test actual governance-foundation suite
also passes. Complete current-stack acceptance remains pending.
This is a new-deployment profile, with no upgrade or migration of an existing
Coordinator's storage.

## Ownership and preserved facts

New mints select the current Coordinator. Each existing token retains its
original `coordinatorAtMint`; its subjects, requests, seeds, credits, escrow and
recovery journals remain on that host. An imported collection keeps its ultimate
`policyOrigin`, including across several replacements. Its original provider
continues to accept only that origin as caller.

The ordered policy inventory includes every configured LEGACY and EXPLICIT
collection. Import preserves mode, security class, render requirement, provider
identity and epoch, salt, request controls, reveal terms and operational fee,
frozen state, original action/revision/Artist receipt, and complete bound frozen
recovery definitions. Explicit policy hashes keep their original origin domain.
LEGACY retains its own hash branch and zero explicit revision/action/Artist
receipt; undeclared reveal keeps its unavailable `policyHash == 0`.

Escrow and requester credits are never copied. Importing a fee amount does not
fund that amount on the candidate. Provider lifecycle admission is also local:
operators must admit the referenced providers on the fresh candidate before
beginning its import.

## Import sequence

| Step | Call and evidence |
| --- | --- |
| Prepare | Deploy a fresh candidate for the same Core and authority; register eligible module/runtime and locally admit the referenced providers. |
| Begin | Obtain `entropyPolicyImportTransition(predecessor, manifestHash)` and execute the exact class-1 `beginEntropyPolicyImport`. |
| Copy | Call `importNextEntropyPolicy(expectedIndex)` in authoritative inventory order. Contents come from the pinned predecessor, never caller-supplied tuples. |
| Admit routes | At each collection's ultimate origin, obtain `entropyRelayAdmissionTransition` and execute the class-1 `admitEntropyRelay` for this candidate/runtime/import hash/collection/policy hash. |
| Confirm | On the candidate call `confirmEntropyRelayRoute(collectionId)` once for each required route. |
| Seal | Obtain `entropyPolicyImportSealTransition()` and execute the exact class-1 seal after all collections and required routes are complete. |
| Activate | Schedule the exact class-3 activation commitment and execute Core pointer replacement followed by `activateEntropyPolicyImport()` in one atomic governed batch. |

Copy and confirmation are permissionless within the authenticated session.
DISABLED and INSTANT/NOT_REQUIRED policies require no relay route. ASYNC with
NOT_REQUIRED still requires one because its scope requests remain supported.

`entropyPolicyInventory()` returns count, mutation serial and ordered-ID digest.
Begin pins all three plus predecessor runtime and Core pointer revision. Every
copy, seal and activation rechecks that evidence. Configuration, fee changes or
first registration can change the source serial; an obsolete session requires
a fresh candidate. There is one import session and no reset. Staging and sealing
block ordinary candidate operations; a candidate previously used for content,
funding or subjects cannot begin import.

`entropyPolicyImportReady(...)` is true only for the complete SEALED session
matching the supplied source header. Core must independently authenticate that
live header and retain its pending-request coverage checks. Missing export
support, malformed replies, partial inventory or unconfirmed routes fail closed.
Activation requires the candidate's exact next Core pointer revision. The
resulting ACTIVE receipt remains latched: later source fee changes do not revoke
it or prevent historically registered subjects from requesting entropy.

The inventory and readiness reads are direct local reads. Policy exports are
exactly 1,184 bytes; the import receipt is 544 bytes. Recovery export is the
canonical dynamic ABI, bounded to 32 ordered steps and 5,696 bytes. Existing
recovery tuples, hashes and replacement targets are retained. An existing
one-successor recovery permission is never retargeted for a later replacement.

## Saved governance plans

[`StreamEntropyPolicySuccessionPlan`](../../script/current/StreamEntropyPolicySuccessionPlan.sol)
builds the exact begin, origin-admission and seal calls as separate class-1
batches. Its catalog helper returns sorted additional rows for those calls and
class-3 activation; it rejects duplicate origins and pins deployed runtimes.
Retain the original admission inventory, remove already-admitted identical rows,
and use the existing catalog-stage planner. Core pointer and SystemManifest
publication admissions remain required. Finish catalog changes before saving
subsequent action journals, because those journals bind the observed catalog.

After import and sealing, `cutover` checks the complete live predecessor header,
the selected Core pointer, candidate registration and current manifest. It
returns one class-3 batch ordered as Core pointer replacement, candidate
activation, then the original SystemManifest publication with the new entropy
module. Retain the exact payload and returned calldata in the existing
`StreamGovernanceStagePlan` journal. A later activation or manifest failure
reverts the pointer change too; no partial cutover is an accepted result.
The helper prepares calls only. Actual Core/Executor/manifest/Safe execution
and cold-path gas acceptance are separate tests.

## Request and result flow

The successor first writes the real request, original provider snapshot and
immutable local relay witness. The origin authenticates its permanent admission,
the successor runtime and ACTIVE import, exact live policy hash, actual subject
identity and the complete request witness. For a token, Core must still identify
that successor as `coordinatorAtMint`. A later current pointer is not required
for that historical subject.

For ASYNC, the origin forwards exactly the live quote to the original provider
with the successor's original request key and context. Both hosts bind the
actual returned provider ID. All failures roll back the request, fees, credits
and route together. The shared host reentrancy guard rejects synchronous
callbacks before the ID binding finishes.

The provider calls its original Coordinator. That origin stores the first raw
value with a separate `rawReceived` flag, so zero is valid. A conflicting later
raw value is rejected. Provider acknowledgment means the raw value was captured;
it does not claim that the successor finalized. Origin provider revocation
blocks delivery while retaining captured output for a possible later retry.

Delivery calls only the recorded successor/runtime. The successor authenticates
the origin, relay ID, both request/provider-ID bindings, context, snapshot and
exact raw receipt, then uses its original seed derivation and finalization path.
Only outcome 0 marks the origin relay delivered. Every nonzero outcome, failed
call or malformed response remains retryable. `retryEntropyRelay(relayId)` is
permissionless, reuses the same captured value and makes no new provider request.
An unrelated later finalization is not evidence that this result was delivered.

For INSTANT, the successor makes a bounded STATIC call to the ultimate origin,
which authenticates the same request and forwards the bounded STATIC provider
read. The successor derives the final seed. This path creates no origin raw
receipt or cash entry and retains the existing later-block request requirement
and mint-commitment exclusion.

## Gas and operational boundaries

Three distinct Coordinator parameters govern relay authentication reads, the
outer INSTANT read, and asynchronous delivery. Every capped call checks full
EIP-150 availability and a parent reserve; it never silently reduces the cap.
Current implementation values/floors are provisional pending measured release
evidence: AUTH 100,000 (failure class 2), INSTANT relay 750,000 (failure class 2),
delivery 500,000 (failure class 1). Failure classes describe the call budget;
they are not the governance action class. These parameters use the existing
delayed monotone at-most-2x raise mechanism.

The earlier typed-source diagnostic fails at the default 100,000 AUTH cap and
imports after raising the candidate through 200,000 to 400,000. Its 5,696-byte
export consumes 249,442 caller gas, including 247,531 inside the fixture getter.
That getter uses ordinary Solidity encoding. These retained measurements are
not a gas minimum for the production Coordinator's direct encoder, and that
fixture does not prove production origin-route admission.

### Supported maximum-recovery read configuration

The production
[`StreamEntropyRecoveryAuthCapacityTest`](../../test/unit/entropy/StreamEntropyRecoveryAuthCapacity.t.sol)
passes with one configured collection containing **32 recovery steps**. This is
not a 32-collection inventory limit. The complete definition is exported,
including any unused suffix, in 5,696 bytes. Genuine public calls configure,
freeze and bind the definition; both exporting hosts are production Coordinators.

| Production getter branch | Minimum successful forwarded gas in this capture | One gas less |
| --- | ---: | --- |
| Original recovery definition | 258,900 | Fails with empty return data |
| Imported recovery definition | 263,001 | Fails with empty return data |

These are exact thresholds for the captured runtime and state after storage
access warmth is reset inside one test transaction. They are not an entirely
cold fresh-transaction measurement or a universal release floor. Both branches
return byte-identical complete definitions at 400,000. The real import and
origin-admission paths fail atomically at 100,000 and 200,000, then succeed at
400,000 without replacing the import session, index or admission commitments.
Core, Artist, module eligibility and executing governance remain typed boundaries
in this gas test; the full Artist/Safe deployment is a separate acceptance path.

For this supported maximum-step read profile, configure **AUTH = 400,000** on
each importing candidate and on the ultimate origin that admits its route:

1. Read that host's `gasParameterInfo` for
   `keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT")`.
2. For an untouched row, derive its exact `gasParameterTransition(id, 200000)`
   and execute `raiseGasParameter(id, 200000)` through an admitted, delayed
   class-1 governance action.
3. Derive the next transition and execute `raiseGasParameter(id, 400000)` under
   a distinct class-1 action. Observe the Executor's current minimum delay and
   execute the increases in order. One action cannot change the same row twice.
4. Verify `(value, floor, failureClass, revision) == (400000, 100000, 2, 3)` for
   each previously untouched host before retrying copy or route admission.

The importing candidate's row funds its recovery-export read. The ultimate
origin has a separate row for admission reads of the immediate predecessor's
definition. Raising one does not raise the other. An exporting predecessor's
own cap does not fund a call into its call-free getter; when that predecessor
also acts as the admitting origin, its caller role still needs the increase.
Every later candidate needs its own configuration. The original 100,000 default
and immutable floor are unchanged.

At a bounded read site, the implementation requires
`floor((available - reserve) / 64) * 63 >= cap`. A 400,000 cap therefore requires
at least **416,400** parent gas at the import read site (10,000 reserve), or
**421,400** at the origin authentication read site (15,000 reserve). Earlier
work, subsequent storage writes and transaction intrinsic gas are additional.
The measured caller costs for the complete one-policy import and origin
admission were respectively **3,992,505** and **4,002,278** gas under the stated
storage-cooled test boundaries; neither the 400,000 cap nor those read-site
requirements are total transaction gas budgets.

A provider's callback budget need not fit the whole second-host delivery.
Capture first and a separate retry preserve output when the nested delivery
cannot be attempted. Operators must distinguish `rawReceived`, `delivered` and
the retryable `lastOutcome` rather than treating provider success as finality.

The ultimate origin must remain usable. This mechanism does not supply a new
provider draw if that host is unavailable, change historical Artist recovery
authority, or waive frozen recovery/incident requirements. Those remain separate
constraints under the [fresh-recovery profile](entropy-fresh-recovery.md).

After activation, a semantic edit to an imported unlocked policy can make that
policy local only if its proposed nonzero provider and each used recovery
provider accept the new host. Keeping original-bound providers while silently
changing their caller is rejected. Fee-only edits preserve the original origin.

## Verification scope

The focused native run covers 210 tests across 15 suites at production source
`393faf78529b1b911db408b26829339371268e29`, with a subsequent test-only relay
fixture correction. All 210 pass, including inventory completeness, original
policy and recovery preimages, governed import, original-provider retry, actual
Coordinator succession, and the production INSTANT, ARRNG and VRF adapters.
The compact direct-read encoders are compared with standard `abi.encode`,
including maximum recovery arrays and two 256-input fuzz properties. Retained
request, fee, recovery and incident cases use pinned upstream Safe 1.4.1
bytecode where required.

The exact-source capture uses Solidity 0.8.19, viaIR, optimizer 200, Paris and no
CBOR. All 38 compiled entropy products fit the 24,576-byte runtime and 49,152-byte
creation limits: Coordinator is 24,282/30,146 bytes and its execution worker is
13,736/13,770. All 221 original Coordinator ABI entries and 22 ordinary storage
entries match the earlier INSTANT profile. The INSTANT runtime checker passes
against the genuine Foundry artifact, cache and build-info dependency set.

Typed Core, Artist, module eligibility, governance and upstream-provider
fixtures remain explicit boundaries of that 210-test capture.

The separate
[`StreamCurrentEntropyPolicySuccessionTest`](../../test/current/StreamCurrentEntropyPolicySuccession.t.sol)
capture at `18c42131be84070641d071005b94abfbd73d23cc` passes nine new cutover cases
and seven inherited governance cases. It uses actual Core, Executor,
ModuleRegistry, RoleRegistry, SystemManifest, Coordinators and pinned 2-of-3
Safe 1.4.1. It covers empty and complete LEGACY inventories, source mutation,
exact pointer revision, route confirmation, required manifest publication and
whole-batch rollback. Activation and manifest faults preserve the original
scheduled action and Safe nonce; the identical signed transaction then succeeds.
All 180 captured sources and 201 artifacts were independently verified, and all
76 nonempty production products fit their runtime and creation limits.

That foundation capture uses a test provider and does not deploy Artist, perform
paid minting or exercise the full renderer graph. The new
[`StreamCurrentExplicitEntropySuccessionTest`](../../test/current/StreamCurrentExplicitEntropySuccession.t.sol)
authors those actual Artist/paid-mint/request joins; its source review and ABI
compilation are complete, while native execution waits for the exact deployment
graph's size checks. None of these scoped results establishes release gas floors,
full CI or deployment readiness. The integrator retains source captures,
complete test inventories, fixture hashes, artifact provenance and failed runs.
