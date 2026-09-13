# Owner recovery action witnesses

`StreamOwnerRecoveryActionReads` is a linked, stateless reader for the fixed
OwnerRecords host. It authenticates a complete published governance-call witness
when opening a notice. It does not create owner standing, a notice clock,
recipient delivery, an objection count or authority to execute recovery.

The host constructs `Config` from its immutable Core and Executor addresses and
runtime hashes. `ownerEvidence` must be that host: the library requires
`address(this) == ownerEvidence` in the linked execution context. These values
must never come from the caller's witness. `readGas` covers fixed dependency
reads. The separately governed `intentReadGas` covers admission's complete
recovery preparation, including its nested dependency calls. Both caps must be
nonzero and fit uint64. Raising the admission cap does not raise other reads.

Call `admit(config, actionId, completePublishedCalls, request)` and retain the
returned `Binding` under that exact action ID. The array is the complete ordered
`GovernanceCall[]`, including unrelated calls. The stored five-word
`governanceActionFacts` must identify a nonzero, unexpired SCHEDULED class2
action. The exact existing governance calls-domain preimage must match its
`callHash`. Exactly one call anywhere in the array must use
`executeFinalityRecovery`; its value must be zero and its calldata commitment
must equal `keccak256(abi.encodeCall(executeFinalityRecovery, (request)))`.
The first call's target or selector is not a substitute for this proof.

The reader independently checks the pinned Core's current
`ARTWORK_FINALITY_RECOVERY` pointer, target runtime, module type and primary
interface ID. All narrow fields in the ten-word pointer are canonically decoded.
It also joins the target's immutable Core, governance authority and owner-evidence
addresses. The full request's canonical scope and immutable original-finality
hash are joined to the target's exact four-word `requireArtistRecoveryIntent`
result. The actual companion validates its registered complete request, staged
704-byte intent, current lineage and replacement route before returning that
result. The reader retains the exact request, manifest and complete batch hashes
along with the transition, runtime and expiry commitments. It does not retrieve
or reinterpret a truncated dynamic request, and it adds no independent
ACTIVE-only registry rule.

`eligibility(config, binding, actionId, scope, manifestHash)` proves **owner-notice
action liveness**, not full recovery readiness. It checks the saved deployment,
scope, manifest, current selected target and reciprocal graph, as well as the
stored action's complete call hash, class and expiry. A SCHEDULED action may
qualify before `notBefore`, allowing its notice interval to run during the
governance delay. Expiry equality is allowed, matching the Executor's strict
`timestamp > expiresAfter` expiry rule.

An EXECUTED action qualifies only during the exact live Executor context: active,
same action ID, class2 and all three per-call transition hashes, with the
execution delay elapsed. After that context closes it returns false. It does
not rewrite or invalidate the historical notice record. Other inactive states,
changed action commitments and elapsed windows return false. Malformed reads,
changed runtime pins and invalid graph/scope witnesses revert fail closed; the
host's evidence endpoint can report those failures as invalid current evidence.

Eligibility deliberately does not call recovery preparation recursively. A
saved notice may remain live while the preparation provider fails or the route
lineage has become stale. Actual companion execution validates complete
preparation before reading owner evidence and repeats it afterward, checking the
same facts, selection and execution context before appending. That execution
check remains necessary. Historical notice readers use saved evidence directly
and do not call this current-liveness function.

Every external read uses an explicit gas cap, exact return length, bounded copy
and an EIP150 parent-gas check after allocating calldata/output. The largest
output copied here is the 320-byte Core pointer. A 150,000-gas cap for the whole
companion preparation cannot cover its own nested 150,000-gas reads and parent
reserve. The focused capacity tests exercise actual registered requests and the
largest word-aligned SSTORE2 request, with named cold dependencies; they do not
establish a full cold current OwnerRecords evidence-callback budget. That
composition must set and measure the governed admission profile and the existing
owner-evidence callback budget separately.

The tests distinguish raw dependency boundaries from actual sealed
Executor/RoleRegistry publication, scheduling and execution. The latter retains
explicit Core, manifest, guardian actor, recovery-intent and owner-host fixtures.
The capacity tests use the actual recovery companion and stored request/intent
with explicit Core/Executor/artist/owner boundaries. Neither suite proves the
complete current owner notice system, public deployment, all supported recovery
scopes, delivery to recipients or finality readiness. Existing interfaces,
hosts, notice serializers and their six HashRef algorithms are unchanged.
