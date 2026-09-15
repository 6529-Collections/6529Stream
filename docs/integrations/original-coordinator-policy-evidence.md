# Complete original-coordinator policy evidence

[StreamFinalityCoordinatorPolicyReads](../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReads.sol)
reads the native policy of every coordinator recorded by the
[original-coordinator inventory](original-coordinator-inventory.md). It keeps
first-occurrence order, including sources retained across Core pointer replacement
and burned members of a scope.

## Consumer bindings

The consuming provider fixes four addresses and their runtime hashes: Core,
generic Metadata, authoritative scope membership and coordinator inventory. It
also fixes the chain and separate per-call source/inventory gas budgets. Do not
accept those dependencies from an untrusted caller as the provider's evidence.
The public linked library itself grants no Stream authority.

Call requireCurrent with the exact scope and inventory plan. The library checks
current complete membership through the original inventory, reconstructs the
plan and completion commitments, and reads every indexed original coordinator.
It reconstructs the complete ordered source chain and rejects missing, changed,
substituted or out-of-order sources. There is no caller-supplied coordinator list
or shortcut to today's selected entropy pointer.

Each source must retain its indexed runtime and expected Core, native entropy
interfaces and module identity. The result includes its module schema, deployment
and manifest commitments, actual native policy hash, provider, epoch and salt.
The component data hash uses the original single-coordinator provider preimage.
A separate ordered policy commitment also binds each source's observed lock state
and the complete inventory identity.

## Interpretation and scope

A declared but unlocked native policy is returned with frozen false. allFrozen
requires a nonempty source set and every source locked. An empty complete scope
has no invented frozen policy. An absent or malformed policy is rejected. The
collection, token and published release/season/view scopes are authenticated by
the original membership host; a parent collection plan cannot substitute for a
subset plan.

The runtime hash was observed at inventory indexing. Core retained the original
address, not its mint-time runtime hash. These reads do not establish token seeds,
external randomness-provider liveness or code, reveal completion, archival
coverage, runtime dependency closure, component-adapter discovery or finality.

The complete read's work and returned bytes grow with the number of distinct
original coordinators. Per-call gas limits and bounded return copying protect
individual source reads; they do not establish an arbitrary-size aggregate gas
ceiling. A snapshot consumer must separately require locked policies and the
complete applicable artwork and preservation evidence.

## Validation

Sixteen focused cases pass in both compiler modes, including 256 fuzz inputs
per mode and calls through a real threshold Safe. The fixture uses actual
Metadata, Schema, Store, membership, inventory and two native coordinators.
Core, governance and the randomness provider are explicit test boundaries.
Independent review binds the tested sources and compiler outputs; complete
deployment composition and maximum aggregate capacity remain separate.
