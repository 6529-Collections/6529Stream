# ADR 0032: Governance foundation before product activation

Status: Accepted for the undeployed full-v1 implementation. Foundation tests and
complete staged product deployment remain separate implementation gates.

Issue: [#743](https://github.com/6529-Collections/6529Stream/issues/743).

## Problem

[ADR 0031](0031-quorum-anchored-estate-archival-profile.md) requires the archival
provider to validate the canonical Executor and its actual RoleRegistry at
construction. The artist facade then pins that deployed provider. The previous
deployment script creates every product before preparing the Executor's genesis
plan. Consequently, that sequence cannot construct the new artist facade:
the provider needs the initialized Executor, and the original initialization
catalog needs the already deployed artist targets.

Predicted addresses do not solve this dependency. Catalog admission checks live
target code hashes. A zero or unbound role pin would weaken the provider's
construction guarantees.

## Decision

Use the existing genesis and ordinary governance paths in two stages. No
Permanent contract semantics, constructor validation or governance delay changes.

1. Deploy the Executor, its owned RoleRegistry, ModuleRegistry, Core and
   SystemManifest, with the intended governance root and redundant guardians.
2. Commit, initialize and seal a governance foundation. Register the registry
   and manifest, install and freeze the manifest pointer, and publish the exact
   foundation payload. Its inventory contains five leaves: two pointers, one
   registry header and two module records. Product pointers are canonically unset.
3. Deploy the checkpoint verifier, coverage provider, artist suite and other
   products. All constructor pins now refer to actual deployed dependencies.
4. Extend the governance catalog with exact deployed target/selector/code-hash
   entries. Register and select product modules through ordinary governed calls,
   including the required system-manifest publication tail. Complete role,
   artist, payment and reveal activation before enabling the supported flows.

The foundation catalog must admit the class-3 catalog extension itself, the
Core pointer update, module registration, required base role actions and manifest
publication under each supported action class. New product-specific permissions
are admitted after deployment; the foundation does not contain fictitious targets.

The shared planner is
[`StreamGovernanceGenesisPlan.sol`](../../script/current/StreamGovernanceGenesisPlan.sol).
The existing full-product script must migrate to this sequence before a new
candidate can claim estate-enabled deployment. Ordinary action delays apply to
the later stages and must appear in the operator schedule; local test time
advancement is not a testnet deployment shortcut.

## Evidence and release meaning

The sealed bootstrap state is an immutable historical commitment to the initial
foundation. It deliberately retains its original five-leaf inventory. It is not
the full-v1 genesis/release inventory required by
[ADR 0004](0004-admin-governance.md).

Later registrations remain enumerable in the canonical ModuleRegistry, pointer
changes have governed transition records, and the current SystemManifest derives
the current product addresses. Release tooling must independently capture and
validate the complete activated deployment, its role assignments, linked
contracts, constructor pins and required profile configuration. A foundation seal
alone cannot advance a full deployment or release gate.

## Validation and rollout

Focused tests must show a real sealed foundation with a threshold Safe root,
rejection of provider construction before the canonical role binding, rejection
of an altered committed plan, and successful provider construction after binding.
The subsequent integration must exercise delayed catalog extension, product
registration, pointer selection with its manifest tail, exact reciprocal archival
pins and an estate flow through actual Core and artist contracts. Existing
current-stack scenarios must still pass after migrating their shared fixture.

Roll out through the integration branch and a fresh candidate. Preserve RC1,
its deployed contracts and its release evidence. This decision introduces no
mutable provider fallback, initialization bypass or mainnet deployment claim.
