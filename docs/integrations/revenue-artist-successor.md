# Revenue reads after Artist authority hydration

A completed original operation-60 handoff can keep the same primary and royalty
Resolvers. Their constructor getters still identify the original Artist registry.
Their assignment, policy, mode-election and token-snapshot hashes, stored
configuration, ownership and replay state do not move to the successor.

Current consent and beneficiary reads use the Core-selected successor only after
`StreamRevenueArtistSelection` authenticates all of these existing facts:

- The original and selected registry runtime pins, the original cutover seal
  naming that successor, and exactly one imported predecessor binding with its
  original runtime, nonzero root/manifest and snapshot at or before the seal.
- The current Coordinator's exact original constructor configuration commitment,
  including all sixteen live target runtime pins and its finality/provider pins.
  Its suite must name this actual Resolver in the primary or royalty field.
- Distinct original/current Coordinators and all seven current owner hydration
  commitments, each nonzero and equal.

These are committed-state provenance checks for the original op60 producer.
They do not replace the Coordinator's operation lock, atomic evidence append or
caller checks, and they are not a general in-flight completion signal. Another
registry, an unrelated Resolver attached to the same Core, incomplete hydration,
a changed constructor recipe or malformed/failed reads do not fall back to the
predecessor. More than one predecessor hop is outside this consumer profile.

The current proof uses the pinned predecessor Registry's existing governed
`ARTIST_FINALITY_READ_GAS` ceiling. Every untrusted fixed return has an exact
length and bounded allocation. Calls retain a local decoding/error reserve and
may use less than the full ceiling when the outer call has sufficient available
gas. No new gas parameter, constructor argument or public Resolver selector is
introduced. The original-selection branch requires no hydration capability.

After completing the ordinary history import and op60 flow, callers continue to
use the existing Resolver selectors. Carried approvals are read from the current
Artist binding; new approvals use the successor's original Artist authorization
domain and nonce. Existing owner-only configuration remains owner-only. Template
materialization reads the current payout designation without changing symbolic
source identities or raw assignment hashes. Snapshot admission still requires
its exact mode-bound approval; an old live-royalty approval does not authorize a
snapshot. Snapshot context keeps the immutable origin for both source/proof
readbacks, while its consent check authenticates the current registry each time.

Pure stored royalty disclosure and the original context-free static/SALE_POSTER
materialization route remain independent of current Artist availability.
Collection/token/default precedence, configured-disabled behavior, frozen token
history and original signed payment or sale identities are unchanged.

## Validation scope

The new `StreamArtistResolverSuccessor.t.sol` composes the unchanged economics
hydration test with eight authored controls for retained facts and owner writes,
unrelated actual Resolver rejection, all seven completion markers, malformed
lineage/configuration, an identical serialized threshold-Safe retry, current
payout materialization, mode-bound snapshot-source consent and cold named-target
reads below the full per-read ceiling. It uses actual Artist owners, Registry,
Coordinator, Archive, Resolvers, factory and Safe. Core/governance remain the
existing explicit typed fixture boundaries. The snapshot-source case supplies
only that typed Core's pre-mint serial for election; it does not establish actual
Core prepared mint execution. The cold case is not an all-dependency transaction
gas or capacity claim.

A 734-source ABI/type check passes. The two complete public ABIs and recursive
storage layouts match the original baseline. Selected Solidity 0.8.19 via-IR,
optimizer-200, Paris code generation fits: primary Resolver 23,356 runtime bytes,
royalty Resolver 15,966, shared selection worker 5,062, primary identity worker
1,596 and snapshot worker 10,370; their creation sizes also fit. Native execution
of the new cases and the joined repaired graph remains pending. The earlier
native2 successor failures are retained evidence of the original defect.
