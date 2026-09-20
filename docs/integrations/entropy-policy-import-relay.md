# Entropy policy import and original-provider relay

This developing profile lets a replacement Coordinator preserve the configured
collection policies of its predecessor. The two additive contracts are
[`IStreamEntropyPolicyContinuity`](../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol)
and [`IStreamEntropyOriginRelay`](../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol).
Combined runtime, deployment-size and current-stack acceptance remain pending.
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
evidence: AUTH 100,000 (class 2), INSTANT relay 750,000 (class 2), delivery 500,000
(class 1). They use the existing delayed monotone at-most-2x raise mechanism.

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

Focused tests separately exercise inventory completeness, original policy and
recovery preimages, governed import workers, relay execution, and actual
Coordinator succession. The compact direct-read encoders have differential
native tests against standard `abi.encode`, including maximum recovery arrays
and randomized fields. Typed Core, Artist, module eligibility, governance and
upstream-provider fixtures are explicit boundaries; these tests do not prove
the complete Core/Artist/Safe deployment graph. Source-specific size and native
results must accompany the final integration handoff.
