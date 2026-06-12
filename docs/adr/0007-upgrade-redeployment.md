# ADR 0007: Upgrade And Redeployment

## Status

Accepted.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P2-UPGRADE-ADR](https://github.com/6529-Collections/6529Stream/issues/53) |
| Blocks | Gate B2, Gate E, Gate G, deployment scripts, release manifests, external audit package |
| Related issues | [P0-AUTH-ADR](https://github.com/6529-Collections/6529Stream/issues/17), [P0-AUCT-ADR](https://github.com/6529-Collections/6529Stream/issues/21), [P0-PAY-ADR](https://github.com/6529-Collections/6529Stream/issues/24), [P0-ADMIN-ADR](https://github.com/6529-Collections/6529Stream/issues/33), [P0-RAND-ADR](https://github.com/6529-Collections/6529Stream/issues/14), [P1-META-ADR](https://github.com/6529-Collections/6529Stream/issues/45) |
| Related ADRs | [ADR 0001](0001-drop-authorization.md), [ADR 0002](0002-auction-custody.md), [ADR 0003](0003-payment-accounting.md), [ADR 0004](0004-admin-governance.md), [ADR 0005](0005-randomness.md), [ADR 0006](0006-metadata-freeze.md) |
| Affected contracts | All first-party 6529Stream contracts, deployment scripts, manifests, release artifacts, indexers, and off-chain signing pipelines |
| Work type | `DESIGN` |

## Problem

6529Stream needs an explicit upgrade and redeployment strategy before public
beta deployment, audit packaging, and open-source release claims. The contracts
are a multi-contract protocol: authorization, auctions, payments, admin roles,
randomness, metadata, dependency scripts, curators, and release artifacts all
interlock.

Before public beta, the protocol needs to decide:

- whether deployed contracts are upgradeable proxies or immutable contracts
- how new versions are deployed, named, verified, and published
- how old contracts are deprecated without stranding NFTs, ETH, signatures,
  auctions, randomness requests, or frozen metadata proofs
- how deployment manifests, ABI hashes, event topics, and release checksums are
  generated and compared
- which state can be migrated, snapshotted, replayed, or intentionally not
  migrated
- how signer rotation, EIP-712 domains, Safe ownership, and role grants behave
  across redeployments
- what qualifies as a breaking change
- what emergency redeployment runbooks must prove before maintainers tell users
  and integrators to move

Without this ADR, deployment work can accidentally create the riskiest shape of
upgradeability: mutable authority without storage-layout discipline, manifest
provenance, audit evidence, or user-visible compatibility rules.

## Current Behavior

Current source references:

- The repository has no proxy, beacon, UUPS, diamond, or delegatecall-based
  upgrade system in first-party contracts.
- `smart-contracts/StreamCore.sol`,
  `smart-contracts/StreamDrops.sol`,
  `smart-contracts/StreamMinter.sol`,
  `smart-contracts/AuctionContract.sol`,
  `smart-contracts/StreamAdmins.sol`,
  `smart-contracts/StreamCuratorsPool.sol`, and randomizer contracts use
  constructors and ordinary contract addresses.
- `smart-contracts/StreamCore.sol#updateContracts` can change several
  downstream contract references, including minter, randomizer, dependency
  registry, and curators-pool references.
- `smart-contracts/StreamMinter.sol#updateContracts` can change the core,
  drops, and admins references.
- `smart-contracts/StreamDrops.sol#updateTDHsigner` can change the drop signer,
  but ADR 0001 and ADR 0004 require a fuller signer lifecycle before public
  beta.
- `smart-contracts/StreamAdmins.sol` inherits `Ownable`; ADR 0004 requires the
  production root authority to become Safe-rooted and role-scoped.
- Emergency withdrawals currently exist in multiple contracts and sweep full
  balances; ADR 0003 rejects that model for public beta.
- Randomizer contracts hold provider configuration and request-local state;
  ADR 0005 requires randomizer epochs and migration semantics before public
  beta.
- Metadata and dependency content can currently be mutable through admin paths;
  ADR 0006 requires immutable freeze manifests and versioned dependencies.
- `script/README.md` states deployment scripts are not implemented yet.
- The roadmap records no deployed address book, manifest schema, ABI checksum
  process, event topic catalog, storage layout snapshot, or release artifact
  process.

The current repository is pre-audit and not production-ready. No production
migration promise exists for any deployed copy of the current contracts.

## Decision

6529Stream will use immutable, versioned redeployments for public beta.

The public-beta target design is:

1. First-party 6529Stream protocol contracts are not upgradeable proxies for
   public beta.
2. Contract logic changes require a new deployment version and a new deployment
   manifest.
3. Any future proxy, beacon, diamond, storage-slot, or delegatecall-based
   upgrade system requires a separate ADR, storage-layout discipline,
   proxy-admin governance design, additional tests, and explicit audit scope.
4. Mutable cross-contract wiring remains an operational risk and must be
   minimized, role-gated by ADR 0004, evented, manifest-tracked, and tested.
5. Deployment manifests are canonical release artifacts. They bind code,
   addresses, constructor arguments, ABI hashes, bytecode hashes, external
   dependencies, admin roles, signer configuration, randomizer configuration,
   metadata schema versions, freeze manifest references, and verification
   inputs.
6. A redeployment never silently migrates state. Every migration or handoff is a
   documented operation with preconditions, scripts or manual runbooks, event
   evidence, and postconditions.
7. Old deployments remain verifiable historical records. Frozen metadata,
   emitted events, contract addresses, and release manifests must not be edited
   in place to pretend an old deployment is the new one.
8. EIP-712 signed payloads are bound to the verifying contract. A redeployment
   invalidates old payloads by default unless a later ADR explicitly defines a
   replay-safe cross-deployment authorization scheme.
9. Active auctions, owed payment credits, pending randomness requests, and
   mutable metadata states must be closed, settled, stale-marked, or explicitly
   supported before a deployment is retired.
10. Public docs and release artifacts must identify which deployment is active,
    deprecated, retired, or emergency-superseded.

This choice optimizes for auditability and user clarity over in-place upgrade
convenience.

## Definitions

| Term | Meaning |
| --- | --- |
| Protocol release | A named source release, such as `v0.3.0`, that bundles code, docs, ABI artifacts, and release notes |
| Deployment version | A network-specific deployment instance of a protocol release, such as `mainnet-6529stream-v0.3.0-001` |
| Contract version | A per-contract implementation version used in docs, manifests, and optionally contract views |
| ABI version | A semantic version for externally consumed ABI shape, including functions, events, errors, and structs |
| Metadata schema version | The metadata schema accepted by ADR 0006 |
| Authorization schema version | The EIP-712 domain and typed-data version accepted by ADR 0001 |
| Deployment manifest | Machine-readable JSON artifact that identifies a deployment and its verification evidence |
| Redeployment | Deploying replacement contracts and publishing a new deployment manifest |
| Migration | Any explicit state or operational handoff between old and new deployments |
| Deprecation | Marking a deployment as no longer preferred for new actions while preserving user exits and historical reads |
| Retirement | Ending all supported mutable operations for a deployment after all required exit criteria pass |

## Deployment Lifecycle

Every public-beta deployment must have one lifecycle state in the release docs
and manifest index.

| State | Meaning | Allowed next states |
| --- | --- | --- |
| `Planned` | Deployment definition exists but is not executed | `Rehearsed`, `Cancelled` |
| `Rehearsed` | Anvil and fork rehearsals passed with manifest output | `Active`, `Cancelled` |
| `Active` | Preferred deployment for new public-beta activity | `Deprecated`, `EmergencySuperseded` |
| `Deprecated` | New activity is discouraged or paused; exits and reads continue | `Retired`, `EmergencySuperseded` |
| `EmergencySuperseded` | A security or correctness incident caused maintainers to redirect users quickly | `Deprecated`, `Retired` |
| `Retired` | Required exits, settlements, and postconditions are complete | None |
| `Cancelled` | Planned or rehearsed deployment was abandoned before activation | None |

Activation requires:

- `make check` or the documented equivalent passing locally and in CI
- Slither high/medium baseline fixed, accepted, or explicitly carried as a
  release-blocking risk
- Anvil deployment rehearsal passing
- fork deployment dry run passing for the target chain or documented test
  network
- deployment manifest generated and checksummed
- contracts verified, or verification failure documented as a release blocker
- admin ceremony completed in rehearsal and ready for production execution
- signer setup completed according to ADR 0001 and ADR 0004
- randomizer setup completed according to ADR 0005
- release notes, security docs, and known-risk docs updated

Deprecation requires:

- a deprecation reason
- active lifecycle state of all drops, auctions, payment credits, randomness
  requests, metadata freeze states, and dependency versions
- documented user and integrator impact
- event or release-note evidence that indexers can consume
- continued withdrawal support for owed funds until balances are zero or a
  later public process documents the final treatment

Retirement requires:

- no active auctions
- no claimable no-bid NFT custody left in the deprecated deployment
- no owed payment credits unless a later public process documents the final
  treatment
- no pending randomness requests unless they are explicitly stale or the old
  deployment remains callable for fulfillment-only support
- frozen metadata and dependency proofs remain readable from the old deployment
  or from immutable published artifacts
- final manifest status update and release notes

## Proxy And Upgradeability Policy

No first-party 6529Stream public-beta contract may use proxy upgradeability
unless a later ADR accepts all of the following:

- proxy pattern and admin model
- storage layout rules
- initializer and reinitializer policy
- upgrade delay, emergency path, and veto process
- storage-layout snapshots in CI
- proxy-admin Safe roles and event monitoring
- audit scope that includes proxy mechanics
- user and integrator disclosure
- tests for storage compatibility, initializer safety, admin separation,
  rollback, and unauthorized upgrade rejection

Until that later ADR exists, the release rule is simple: source changes produce
new deployments, not in-place logic replacement.

Mutable references such as `updateContracts` are not proxy upgrades. They are
configuration changes. Public-beta implementations must still treat them as
deployment-sensitive operations:

- authorize them through ADR 0004 roles
- emit events with old and new addresses
- update deployment manifests or manifest amendments
- test that only the intended target reference changes
- reject zero addresses unless a specific disable path is documented
- include a rollback or incident plan where appropriate

## Versioning Model

6529Stream will use several explicit versions instead of overloading one
number.

| Version | Owner | Change examples | Required artifact |
| --- | --- | --- | --- |
| Protocol release | Maintainers | Any source, docs, tooling, or artifact release | Git tag, changelog, checksums |
| Deployment version | Maintainers/deployment operator | New network deployment or redeployment | Deployment manifest |
| Contract version | Contract implementers | Logic or external surface change for one contract | ABI hash and source hash |
| ABI version | Integrations/docs | Function, event, error, struct, or interface change | ABI diff and event topic catalog |
| Authorization schema version | Drop signing pipeline | EIP-712 field/domain changes | Signing docs and schema hash |
| Metadata schema version | Metadata protocol | Token JSON or freeze manifest schema changes | Golden files and schema docs |

Before audit, release versions may remain `0.x`. After a public audited release,
semantic versioning should follow:

- MAJOR: breaking contract, event, metadata, authorization, role, or deployment
  manifest behavior
- MINOR: backward-compatible functionality or new optional views/events
- PATCH: bug fixes, docs, tooling, or non-breaking manifest corrections

## Deployment Manifest

Deployment manifests are mandatory for public beta.

The manifest schema must include at least:

- manifest schema version
- protocol release version
- deployment version
- lifecycle state
- network name and chain ID
- block number and transaction hash for each deployment transaction
- git commit and release tag
- Solidity compiler version
- Foundry version
- Slither version and baseline reference
- CI run URL
- deployer address
- governance Safe/multisig address
- contract names, addresses, source paths, constructor arguments, creation
  transaction hashes, bytecode hashes, runtime bytecode hashes, and ABI hashes
- external dependencies such as VRF coordinator, arRNG controller, LINK token,
  Safe, marketplace or royalty dependencies if any, and dependency registries
- admin role grants and owner transfers after the ceremony
- signer addresses, signer epochs, and signer-domain configuration
- randomizer provider configuration, provider epoch, subscription or funding
  references, and callback gas settings where applicable
- payment ledger or escrow initialization assumptions
- collection, dependency, metadata schema, and freeze manifest versions where
  relevant
- event topic catalog hash
- ABI artifact checksums
- deployment script command and arguments
- verification input references
- post-deploy smoke test results

Manifests must be deterministic enough to diff. Where a value is environment
specific, the field must still be present with an explicit value, not omitted.

Manifest amendments are allowed only for post-deploy facts that cannot be known
at initial generation, such as verification URLs or lifecycle-state changes.
Amendments must preserve the original manifest hash and publish their own hash.

## State Handoff Rules

Redeployment state handoff is domain-specific. A deployment runbook must prove
each relevant row before activation, deprecation, or retirement.

| Domain | Handoff rule |
| --- | --- |
| Drop authorization | Old EIP-712 signatures are invalid on a new deployment because `verifyingContract` changes. Signer epochs must be rotated or explicitly recorded. Consumed drop IDs are not silently migrated. |
| Fixed-price drops | New drops use the new deployment. Executed old drops remain historical facts on the old deployment. |
| Auctions | Active auctions must be settled, cancelled under ADR 0002 rules, or left on the old deployment with documented settlement support. Active bid escrow cannot be migrated by assumption. |
| Payment credits | Owed balances stay withdrawable from the deployment that recorded them until zero or until a later public process documents otherwise. New deployments do not inherit old credits. |
| Curator rewards | Claimed leaves and owed curator credits stay with the deployment that recorded them. Any new Merkle root must use a new root epoch and manifest reference. |
| Admin roles | New deployments run a fresh ADR 0004 ceremony. Old deployments are paused, role-reduced, or deprecated according to the incident or deprecation plan. |
| Signers | New deployment signer sets and signer epochs are explicit manifest fields. Compromised signers require epoch rotation and drop-execution pause according to ADR 0004. |
| Randomness | Pending requests remain owned by the deployment and provider epoch that created them. A redeployment cannot redraw randomness for those tokens unless a later ADR defines an unbiased process. |
| Metadata | Frozen metadata remains tied to the old deployment address, manifest hash, dependency versions, and event history. New deployments may reference old proofs but cannot rewrite them. |
| Dependencies | Frozen dependency versions remain immutable. New deployments can deploy or reference new dependency registries only through manifest-tracked versions. |
| Burned tokens | Burn state and audit state remain in the deployment that burned the token. A redeployment must not resurrect ownership or `tokenURI`. |
| Royalties | ERC-2981 configuration belongs to the deployment and token state that exposes it. Changed royalty behavior is a breaking change unless explicitly versioned. |

## Breaking Changes

The roadmap's breaking-change definition is accepted and expanded here.

Breaking changes include:

- function removal
- function selector change
- function argument or return-value semantic change
- event signature change
- event indexed-field change
- custom error signature change in an externally documented path
- changed revert behavior that integrations rely on
- changed metadata schema
- changed metadata freeze manifest schema
- changed authorization schema or EIP-712 domain fields
- changed role or permission semantics
- changed payment, withdrawal, auction, or settlement semantics
- changed randomizer provider lifecycle semantics
- changed deployment manifest schema
- changed contract address for a deployment version
- changed interface ID support

Breaking changes require:

- release-note callout
- ABI or schema diff
- manifest version update
- integration guidance
- test update
- audit-package update when the release is audit-targeted

## Redeployment Triggers

A redeployment is required or strongly preferred when:

- contract logic changes
- an accepted ADR changes public-beta protocol behavior
- a high or critical security issue cannot be fixed through safe configuration
- EIP-712 domain or typed-data schema changes
- metadata schema or freeze manifest schema changes
- event signatures or indexed fields change
- admin, signer, randomizer, payment, or auction state model changes
- a constructor argument, immutable address, or external dependency must change
- dependency registry versioning or provenance changes materially
- the current deployment cannot pass release or audit gates

A redeployment is not required for:

- docs-only updates that do not change protocol promises
- issue-template, contributor, or CI changes without protocol artifact changes
- release notes that describe already deployed behavior
- off-chain indexer fixes that do not require contract or schema changes
- non-production local/anvil rehearsal changes

Configuration changes may avoid redeployment only if:

- they are authorized by ADR 0004
- they are documented in the deployment manifest or amendment
- they emit events
- they preserve all accepted ADR invariants
- they are covered by rehearsal tests or manual runbook evidence

## Emergency Redeployment

Emergency redeployment is allowed only to reduce active user, fund, NFT,
metadata, or authorization risk. It must not become a shortcut around normal
release discipline.

Emergency runbook minimum:

1. Identify impacted deployment version, contracts, chain IDs, and release
   manifests.
2. Pause the narrow affected domains under ADR 0004 where doing so reduces risk.
3. Preserve withdrawals for owed funds unless withdrawal itself is the affected
   vulnerability.
4. Snapshot active auctions, owed credits, signer epochs, consumed drop IDs,
   pending randomness requests, metadata freeze states, and role grants.
5. Decide whether active auctions settle on the old deployment, are cancelled
   under ADR 0002, or remain paused pending a public plan.
6. Rotate or disable compromised signers and record the new signer epoch.
7. Deploy replacement contracts from a reviewed commit.
8. Generate and publish an emergency deployment manifest.
9. Verify contracts and run post-deploy smoke tests.
10. Complete the admin ceremony and remove deployer authority.
11. Publish user, integrator, and indexer guidance.
12. File a post-incident follow-up issue and update accepted-risk docs.

Emergency deployments still require evidence. If a step is skipped, the
manifest or incident note must record the owner, reason, risk, and expiry.

## Security Impact

This ADR reduces:

- proxy-admin key risk
- unreviewed storage-layout risk
- silent in-place behavior changes
- ambiguous contract address changes
- signer replay across deployments
- accidental migration of owed funds or active escrow
- frozen metadata rewriting by social convention
- indexer confusion during contract replacement

It introduces or preserves:

- operational coordination cost during redeployments
- the need to keep old deployments callable for exits and historical reads
- more release artifacts to generate, verify, and publish
- the possibility that users must interact with old and new deployments during
  a transition

The accepted tradeoff is that immutable deployments with explicit manifests are
easier to audit and explain than upgradeable contracts before the protocol has a
complete test, deployment, and audit baseline.

## Migration Impact

Before public beta, no production migration is promised.

For public beta and later:

- contract state is not automatically migrated
- old deployment owed balances remain claims against the old deployment
- old deployment NFTs remain valid NFTs at their original contract address
- old frozen metadata proofs remain valid at the original deployment and
  manifest
- old EIP-712 payloads are invalid on the new deployment by default
- frontends and indexers must select active deployment versions from the
  manifest index
- deprecation communications must tell users which actions remain on old
  deployments and which actions move to new deployments

Any future state migration helper contract must have its own issue, tests,
manifest entry, audit scope, and user docs.

## Implementation Requirements

Future implementation PRs must:

- add deployment scripts for local/anvil, testnet, and fork rehearsal
- add a deployment manifest schema and examples
- generate ABI hashes and event topic catalogs
- add deployment lifecycle status docs
- add a release manifest index
- add admin ceremony scripts or checklists that prove deployer authority is
  removed
- add signer setup and signer epoch verification
- add randomizer provider setup and epoch verification
- add post-deploy smoke tests for fixed-price drop, auction creation,
  settlement or cancellation path, payment withdrawal, metadata mode, freeze
  readiness, and randomness request/fulfillment where practical
- add fork tests or scripts that prove manifests match deployed bytecode,
  constructor arguments, owners, roles, and external dependencies
- add ABI diff checks for release PRs
- add storage-layout snapshots only if a later ADR introduces upgradeability
- update `docs/deployment.md`, `docs/security.md`, release docs, and the audit
  package index

## Tests Required

Deployment and release work must add tests or scripted checks for:

- manifest JSON schema validation
- deterministic manifest checksums
- ABI hash generation
- event topic catalog generation
- Anvil deployment rehearsal
- fork deployment dry run
- constructor argument capture
- source verification input retention
- owner transfer to Safe or test multisig
- role grants and deployer-role removal
- signer setup and signer epoch checks
- drop-domain verification after deployment
- fixed-price smoke mint
- auction smoke creation and settlement/no-bid handling according to ADR 0002
- payment withdrawal and surplus view checks according to ADR 0003
- pause-domain smoke checks according to ADR 0004
- randomness request and fulfillment smoke checks according to ADR 0005
- metadata pending/stale/failed/final/freeze smoke checks according to ADR 0006
- deprecation runbook checks for active auctions, owed credits, pending
  randomness, and frozen manifests
- emergency redeployment rehearsal on an Anvil or fork environment
- ABI breaking-change detection
- release checklist completion before tag creation

Intended test and script targets:

- `script/Deploy.s.sol`
- `script/RehearseDeployment.s.sol`
- `script/VerifyDeployment.s.sol`
- `test/StreamDeployment.t.sol`
- `test/StreamDeploymentFork.t.sol`
- `test/StreamDeploymentManifest.t.sol`
- `test/StreamReleaseArtifacts.t.sol`
- `docs/deployment.md`

## Rollout Plan

1. Merge this ADR and link it from the roadmap.
2. Treat Gate B2 as complete once ADR 0006 and ADR 0007 are both merged.
3. Implement P0 contract fixes and tests before deployment scripts become
   public-beta release blockers.
4. Add deployment manifest schema and local/anvil deployment rehearsal.
5. Add admin ceremony checks for Safe ownership, roles, signers, randomizers,
   dependency registry, curator pool, and auction wiring.
6. Add fork dry-run support for target networks.
7. Add release artifact generation for ABIs, checksums, event topics, manifests,
   verification inputs, and changelog entries.
8. Add lifecycle status docs for active, deprecated, emergency-superseded, and
   retired deployments.
9. Include this ADR, manifests, deployment transcripts, and release artifacts in
   the external audit package.

## Alternatives Considered

### Transparent Or UUPS Proxies For Public Beta

Rejected for public beta. Proxies can be appropriate for mature protocols, but
they introduce storage-layout, initializer, proxy-admin, and upgrade-governance
risk that this repo is not ready to carry. A later ADR may reconsider proxies
after tests, deployment scripts, governance, and audit scope mature.

### Beacon Or Diamond Upgradeability

Rejected for public beta. These patterns add even more indirection and require
careful selector, facet, and storage discipline. They are not justified for the
current pre-audit repository.

### Central Registry Pointer As The Only Upgrade Layer

Rejected as the sole strategy. A registry can help frontends discover active
deployments, but it does not solve on-chain state, owed balances, active
auctions, randomness requests, frozen metadata proofs, or authorization-domain
semantics.

### Migrate All State Automatically

Rejected. Automatic migration across NFT ownership, auctions, owed ETH,
randomness, and metadata freeze state would be large, risky, and audit-heavy.
This ADR prefers explicit domain-by-domain handoff and leaves any future
migration helper to its own issue and audit scope.

### Do Nothing Until First Deployment

Rejected. Deployment and upgrade decisions shape authorization domains,
manifests, tests, indexer behavior, release notes, and security docs. Waiting
until deployment would make the first production release harder to review.

## Non-Goals

- Implementing contract, test, CI, deployment, manifest, or release code in
  this ADR PR.
- Choosing final mainnet, testnet, Safe, signer, VRF, arRNG, or dependency
  registry addresses.
- Supporting migration from any existing unofficial deployment.
- Defining DAO governance, token voting, or timelock mechanics.
- Defining final marketplace integration docs.
- Introducing upgradeable proxies.
- Guaranteeing that old deployments can be retired while funds, auctions, or
  pending randomness remain unresolved.

## Accepted Risks

- Immutable redeployments require more operational coordination than proxy
  upgrades.
- Users and integrators may need to understand old and new deployment addresses
  during a transition.
- Owed balances can keep an old deployment alive longer than maintainers would
  prefer.
- Emergency redeployment may need to proceed before every normal release
  artifact is complete. Any skipped artifact must be documented with risk and
  expiry.
- If a later ADR introduces upgradeability, the repository will need additional
  tests, docs, storage snapshots, and audit scope beyond this ADR.

## Open Follow-Ups

- Implement deployment scripts and manifest schema.
- Add `docs/deployment.md`.
- Add release artifact generation and ABI/event diff checks.
- Add deployment rehearsal tests.
- Add deployment lifecycle docs and manifest index.
- Add emergency redeployment runbook.
- Add storage layout snapshots only if a later ADR introduces upgradeability.
