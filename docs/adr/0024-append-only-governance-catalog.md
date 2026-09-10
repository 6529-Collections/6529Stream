# ADR 0024: Append-only governance catalog evolution

Status: Accepted for the current pre-genesis implementation, 2026-09-09.

The delivery decision is to support administering replacement satellites on the
same Core and Executor. This supersedes only ADR 0004's prohibition on catalog
extensions. Existing entries, exact-target authority, native-value restrictions,
and ordinary action delays remain unchanged.

The initial catalog is revision zero. A root-proposed class-3 action, delayed
at least 48 hours, may append 1–64 entries to a catalog of at most 1,024 entries.
This fits the existing 24,575-byte calldata publication even with the required
manifest tail and its maximum 2,048-byte URI.
Each addition retains the existing entry schema and must name an exact action
class, target, selector, live code hash, profile identity, call type and value
policy. Additions sort by the existing policy key; duplicate keys, including
keys already in the catalog, reject. An existing entry cannot be removed or
reinterpreted. EIP-7702 designations remain inadmissible.

`extendGovernanceActionPolicy(uint64,bytes32,bytes32,GovernanceActionPolicyEntry[])`
commits the expected revision, old catalog root, new catalog root and exact
additions. The new root commits the previous root, next revision, previous
entry count, candidate identity, chain, Executor and ABI-encoded additions.
The per-call scope and old/new state hashes additionally commit both counts.
`StreamGovernanceActionPolicy.extensionTransition` supplies these commitments.
The original candidate identity continues to identify the genesis lineage; it
does not attest review of later entries.

An extension must be the first of exactly two calls, followed by publication
to the immutable SystemManifest. The Executor updates its current catalog
commitment and mirrored lifecycle fields in the same transaction. Publication
failure rolls everything back. The payload should describe the new catalog
revision; as with other manifest payloads, Solidity validates its content hash
and publication transition, not its prose. Genesis binding/seal events remain
historical evidence; `governanceActionPolicyState` reports the current revision.

Actions scheduled under an older catalog root cannot execute after an extension;
operators cancel or expire them and schedule again under the new root. Root
revision and proposer authorization checks continue to apply. Execution still
validates only selected immutable entries and their live code, rather than
walking the whole catalog. The extension itself remains admitted through its
original immutable class-3 row, selector `0x9ad52a32`.

This avoids replacing permanent Core or adding wildcard calls, proxy authority,
or a deployer backdoor. The finite 1,024-entry budget and deliberate invalidation
of queued actions are accepted operational costs. Removal of entries and
changing existing value policies are outside this decision. Existing deployments
without the extension entrypoint cannot adopt this behavior.

Validation covers replacement admission and subsequent ordinary configuration,
original-entry continuity, exact transition/revision checks, root-only authority,
48-hour delay, sorted bounded additions, code drift, stale scheduled actions and
atomic publication rollback. Existing pagination and root/guardian regressions
cover the unchanged read ABI and authority boundaries. This is an implementation
decision, not audit or production-readiness evidence.

Deployment preparation may bind the exact committed catalog and initial
governance lifecycle in a separate transaction using `prepareGenesis(binding,
batches)`. It authenticates the same complete plan as `initializeGenesis`, may
run only once, and does not initialize products or seal. Ordinary pre-seal
scheduling is blocked once a plan is committed. The final initializer applies
all product batches and seals atomically; a failed attempt retains only the
already committed preparation and can retry the identical plan. This separates
catalog storage costs from product setup for the Ethereum transaction gas cap;
the deployment script must measure each transaction, including cold access and
intrinsic gas. The initializer may still perform both phases atomically for a
smaller plan. No deployment authority survives the final seal.
