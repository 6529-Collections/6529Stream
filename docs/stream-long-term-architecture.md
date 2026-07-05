# Stream Long-Term Architecture

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md),
[ADR 0010](adr/0010-world-class-spec-pass.md),
[ADR 0011](adr/0011-world-class-pass-round-2.md),
[ADR 0012](adr/0012-world-class-pass-round-3.md),
[ADR 0013](adr/0013-world-class-pass-round-4.md), and
[ADR 0014](adr/0014-world-class-pass-round-5.md) and recorded in
[`docs/spec-open-questions.md`](spec-open-questions.md).

This document is the umbrella architecture specification for making
6529Stream durable over a 50+ year contract life. 6529Stream is permanent
infrastructure for the 6529 network: the first production deployment is the
permanent system, and every requirement here is classified by what can ever
change about it — Permanent, Replaceable, or Operational — rather than by
launch phase. It ties together the revenue, royalty, metadata, renderer,
entropy, and provider specs.

Companion specs:

- `docs/launch-v1-target-architecture.md` (Stream protocol v1 specification)
- `docs/revenue-splits-and-royalties.md`
- `docs/mint-policy-and-accounting.md`
- `docs/stream-sales-and-auctions.md`
- `docs/stream-artist-authority.md`
- `docs/adr/0004-admin-governance.md`
- `docs/adr/0008-revenue-splits-and-royalty-resolver.md`
- `docs/launch-conformance-matrix.md` (deployment conformance gates)
- `docs/metadata-router-and-renderer.md`
- `docs/collection-metadata-contract.md`
- `docs/stream-entropy-coordinator.md`
- `docs/stream-entropy-providers.md`

This document is the normative home of the cross-cutting patterns:
the Governed Gas Parameter model and its probe permanence rules, the
Governed Time Parameter model, the module registry record shape, the
Core satellite pointer policy, the token identity model, the token
enumeration posture, the freeze model, the artwork finality model, the
guardian module pattern, the state export
profile, the state-readable payload discovery pattern, and the hash and
manifest discipline. Subsystem specs instantiate these patterns and cite
this document; per the precedence rule in
[`docs/spec-policy.md`](spec-policy.md), restating a pattern is a defect.

## Design Thesis

`StreamCore` should be a small permanent ERC-721 identity root. Everything that
is likely to change over decades should live in versioned satellite contracts
with explicit registries, immutable implementation identities, evented
configuration, and one-way freeze options.

The durable boundary is:

```text
StreamCore
  - ERC-721 ownership, approvals, total supply, burn/mint facts
  - token ID to collection ID truth
  - Core-native ERC-2981 surface
  - tokenURI public surface
  - minimal pointers to approved satellites
  - one-way Core-level freeze hooks where product promises require them

Satellite contracts
  - revenue resolver and split wallets
  - metadata router, renderer, and collection metadata storage
  - entropy coordinator and provider adapters
  - future modules for views, token params, dynamic traits, cultural context,
    preservation records, alternate renderers, and new standards
```

The system should be easy to extend without forcing collectors, marketplaces,
or future engineers to understand a mutable black box. Every important choice
must be readable onchain, reconstructable from events, and bound to explicit
version or manifest hashes.

## Long-Term Principles

1. Keep Core permanent, small, and boring.
2. Keep `totalSupply()` in Core; keep `ERC721Enumerable` index storage out
   of Core. Enumeration is served by state exports, dense sequential IDs,
   and periphery lenses ([LTA-ENUMERATION]; ADR 0012 decision T10,
   superseding ADR 0010 decision D9.3).
3. Keep Core-native ERC-2981 in Core, but put mutable royalty policy in a
   resolver.
4. Keep marketplace-facing surfaces stable: `ownerOf`, `tokenURI`,
   `royaltyInfo`, `supportsInterface`, transfer, approval, and
   `totalSupply` reads.
5. Keep mutable economic, rendering, and entropy policy out of Core.
6. Prefer immutable profiles, immutable implementation versions, and mutable
   assignments over mutable internals.
7. Prefer explicit versioned registries over proxies as the default upgrade
   pattern.
8. Prefer pull accounting over push payments.
9. Prefer typed status over sentinel values.
10. Prefer `bytes32` identifiers and hashes for protocol identity, with
    optional metadata for human-readable names.
11. Prefer `abi.encode` with domains and explicit versions for every durable
    hash.
12. Prefer predeclared fallback policies over ad hoc admin discretion after
    partial outcomes are visible.
13. Prefer one-way freeze controls where the product promise says a policy is
    permanent.
14. Keep all important policies inspectable without relying on private storage
    layout or offchain operator memory.
15. Treat standards, marketplaces, randomness providers, and storage systems as
    replaceable over decades.
16. Prefer governed parameters with immutable floors over immutable caps
    for every external-call gas bound; a cap that cannot move is a bet
    against 50 years of opcode repricing (ADR 0010 decision D1; see
    Governed Gas Parameters).

## Core Minimalism

Core should own only facts that define the NFT:

- token existence;
- owner and approvals;
- global live-supply and allocation counters (`totalSupply()`,
  `lastAllocatedTokenId()`; [LTA-ENUMERATION]);
- collection ID for a token;
- collection-local serial when needed for names and open-ended collections;
- mint/burn audit facts;
- minimal pointers to current satellite contracts;
- minimal ERC-2981 fallback behavior.

Core should not own:

- split recipient lists;
- primary-sale revenue policy;
- mutable royalty assignment policy;
- metadata JSON or HTML assembly;
- collection script storage;
- dependency assembly;
- entropy provider callback handling;
- large event/recovery state machines;
- future optional display or agent metadata modules.

If Core bytecode becomes tight, the rule is not "drop Core-native ERC-2981" or
"drop `totalSupply()`." The rule is: move non-essential rendering, collection
metadata, entropy coordination, and other mutable policy out of Core until the
permanent surfaces fit with headroom.

## Satellite Versioning [LTA-MODULE-ID]

This section is the normative home of the module identity surface; the
protocol v1 mirror and subsystem specs cite this anchor (ADR 0013
decision U9).

Every satellite family must expose the canonical module identity surface
(ADR 0009 decision 3). The `stream` prefix follows the
`streamSystemManifest()` precedent and keeps these selectors unambiguous in
ABIs and explorers over decades; the selectors are golden-tested:

```solidity
function streamModuleType() external pure returns (bytes32);
function streamModuleVersion() external pure returns (bytes32);
function streamModuleInterfaceId() external pure returns (bytes4);
function streamModuleSchemaHash() external view returns (bytes32);
function streamModuleSupersedes() external view returns (address);
function streamModuleCodeHash() external view returns (bytes32);
function streamModuleDeploymentManifestHash() external view returns (bytes32);
function streamModuleManifest() external view returns (string memory uri, bytes32 hash);
```

`streamModuleSupersedes()` returns the immediate predecessor in the same
module family, or the zero address for a first-generation module.

Recommended module type examples:

```text
STREAM_REVENUE_RESOLVER
STREAM_SPLIT_FACTORY
STREAM_SPLIT_WALLET
STREAM_METADATA_ROUTER
STREAM_RENDERER
STREAM_COLLECTION_METADATA
STREAM_ENTROPY_COORDINATOR
STREAM_ENTROPY_PROVIDER
STREAM_GOVERNANCE_GUARDIAN
STREAM_ENUMERATION_LENS
```

Implementation contracts should expose enough immutable or read-only facts for
tools to prove which version is active. Factories and registries should bind
deterministic IDs to init code hash, runtime code hash, schema version,
interface ID, manifest hash, deployment manifest hash, chain ID, and factory
address.

## Registry Pattern [LTA-REGISTRY]

Use registries for replaceable modules, but keep registry authority narrow.
This section is the single normative home of the module registry interface
and record shape (ADR 0010 decision D10.2). Protocol v1 has exactly one
module-registry interface; mint gates, counter resolvers, sale-adapter
executors, renderers, entropy providers, artist registries, and Core
satellites are all registered through it.

Registry responsibilities:

1. Approve or deprecate implementation families.
2. Track code hashes and version manifests.
3. Emit reasoned lifecycle events.
4. Prevent unknown modules from being assigned to mutable scopes.
5. Allow deprecated modules to keep serving already-frozen or already-assigned
   scopes when safe.
6. Provide incident revocation when an implementation is unsafe, with a
   documented recovery path.

Registry states:

```text
UNKNOWN             rejected
ACTIVE              allowed for new assignments
DEPRECATED          no new assignments, existing uses may continue
INCIDENT_REVOKED    no new use, and normal use may be blocked pending recovery
```

Incident revocation must not imply admin sweep rights, hidden migration, or
silent policy substitution. It should freeze the affected surface until an
accepted recovery or successor path is published.

Canonical v1 registry surface, merging the umbrella and mint-layer draft
record shapes into the one record every consumer reads (ADR 0010 decision
D10.2):

```solidity
enum ModuleRegistryStatus {
    UNKNOWN,
    ACTIVE,
    DEPRECATED,
    INCIDENT_REVOKED
}

struct StreamModuleRecord {
    ModuleRegistryStatus status;
    bytes32 moduleType;
    bytes32 moduleVersion;
    bytes4 interfaceId;
    uint32 moduleGasLimit;
    bytes32 runtimeCodeHash;
    bytes32 deploymentManifestHash;
    bytes32 moduleManifestHash;
    string moduleManifestURI;
    uint64 registeredAt;
    uint64 statusUpdatedAt;
}

interface IStreamModuleRegistry {
    function moduleRecord(address module)
        external
        view
        returns (StreamModuleRecord memory);

    function isModuleEligible(
        address module,
        bytes32 expectedModuleType,
        bytes4 expectedInterfaceId
    ) external view returns (bool);

    function moduleRegistryManifest()
        external
        view
        returns (bytes32 manifestHash, string memory manifestURI);

    // Append-only module enumeration index (requirement 6;
    // ADR 0013 decision U2).
    function moduleCount() external view returns (uint256);

    function moduleAt(uint256 index) external view returns (address module);

    // Registration record-chain accumulator (requirement 7;
    // ADR 0013 decision U2).
    function registrationChainHash()
        external
        view
        returns (bytes32 chainHash, uint64 recordCount);
}
```

Registry record requirements:

1. `IStreamModuleRegistry`, `StreamModuleRecord`, and
   `ModuleRegistryStatus` are the only module-registry surface in protocol
   v1. A second registry interface, record shape, or status vocabulary for
   the same pattern is nonconformant. Draft mint-layer names —
   `IStreamMintModuleRegistry`, `MintModuleInfo`, `ModuleStatus`,
   `isModuleActive` — are superseded aliases; consumers that named
   `isModuleActive(module, interfaceId)` read
   `isModuleEligible(module, moduleType, interfaceId)` with their module
   type.
2. `ModuleRegistryStatus` numeric IDs are pinned in the Numeric ID Catalog:
   `UNKNOWN = 0`, `ACTIVE = 1`, `DEPRECATED = 2`, `INCIDENT_REVOKED = 3`.
   The mint-layer draft name `BLOCKED` denotes `INCIDENT_REVOKED`; there is
   no fifth state.
3. `moduleGasLimit` is the registry's recommended per-module external-call
   forwarding bound, consumed at configuration time by managers and routers
   that hash a per-module gas value into policy identity (for example the
   mint gate config in `docs/mint-policy-and-accounting.md` `[MPA-GATES]`).
   Zero means no module-specific bound. Runtime enforcement combines the
   policy-pinned value with the relevant Governed Gas Parameter; the
   registry field itself is configuration metadata, not a live gas read.
4. The conformance-matrix genesis deployment profile names every deployed
   registry instance. A deployment may serve all module types from one
   instance or split instances by subsystem, but every instance implements
   this interface, and every policy or pointer preimage that binds a
   registry address binds an instance listed in the genesis profile.
5. Registry lifecycle changes are governed actions under the ADR 0004
   action classes: registration and status loosening are
   `DELAYED_LOOSENING`; incident revocation is `IMMEDIATE_TIGHTENING`.
6. Append-only enumeration (ADR 0013 decision U2). Every registry
   instance exposes the state-only enumeration index in the canonical
   interface: `moduleCount()` returns the number of modules ever
   registered through the instance, and `moduleAt(index)` returns the
   module address registered at the zero-based registration index. The
   index is append-only: a registration appends exactly one entry,
   registering an already-known module address reverts, and no status
   change — deprecation and incident revocation included — ever edits
   or removes an entry. The index mirrors the split factory's
   [RSR-FACTORY-ENUM] posture in
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md):
   over decades the registry is the protocol's only ledger of which
   implementations were ever blessed, so a state-only archivist must be
   able to enumerate every module ever registered — later renderer
   versions, entropy providers, gates, sale adapters — from state reads
   alone, with no logs, no prior exports, and no operator. The golden
   interface tests and the conformance matrix's state-only
   payload-discovery walk (golden test 28) cover the index.
7. Registration record-chain lane (ADR 0013 decision U2). Every
   registration appends to an onchain rolling accumulator under the
   [CMC-RECORD-CHAIN] preimage of
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md),
   hosted on the registry with `scopeKey = 0`,
   `recordType = keccak256("MODULE_REGISTRATION")`, `recordIndex` equal
   to the module's requirement 6 enumeration index, and the typed
   record hash

   ```solidity
   bytes32 recordHash = keccak256(abi.encode(
       STREAM_MODULE_REGISTRATION_RECORD_V1,
       module,
       moduleType,
       interfaceId,
       moduleVersion,
       runtimeCodeHash,
       deploymentManifestHash,
       moduleManifestHash
   ));
   ```

   The domain constant is pinned in [LTA-DOMAINS]. The accumulator
   updates before `StreamModuleRegistered` is emitted and the event
   carries the updated chain hash; `registrationChainHash()` returns
   the stored `(chainHash, recordCount)`, `recordCount` must equal
   `moduleCount()`, and the stored pair is exported as a record-chain
   leaf ([LTA-EXPORT]). Replay of a recovered registration history is
   complete exactly when it reproduces the stored accumulator — provable
   from state alone even under full log expiry with operators gone.

The registry emits schema-versioned lifecycle events:

```solidity
event StreamModuleRegistered(
    uint16 schemaVersion,
    address indexed module,
    bytes32 indexed moduleType,
    bytes4 indexed interfaceId,
    bytes32 moduleVersion,
    uint32 moduleGasLimit,
    bytes32 runtimeCodeHash,
    bytes32 deploymentManifestHash,
    bytes32 moduleManifestHash,
    string moduleManifestURI,
    bytes32 recordChainHash
);

event StreamModuleStatusChanged(
    uint16 schemaVersion,
    address indexed module,
    bytes32 indexed moduleType,
    ModuleRegistryStatus status,
    bytes32 reasonHash,
    string reasonURI
);
```

Every pointer assignment, module registry check, and frozen-route
compatibility check must name the registry that supplied eligibility. A pointer
cannot be considered inspectable if tools can read only the target address and
must guess which registry, module type, interface, or manifest made that target
valid.
If a module registry itself becomes obsolete, unsupported, or unusable while
governance still functions, replacing it is a delayed pointer/governance action
with old/new registry manifests and a compatibility-matrix snapshot. Existing
Core pointer reads keep returning the cached registry status observed at their
last update until each pointer is revalidated against the successor registry.
If governance is lost before registry replacement, no hidden registry override
exists; mutable assignments halt and read-only/degraded mode continues from
cached pointer facts and frozen manifests.

## Core Satellite Pointer Policy [LTA-POINTERS]

The Core pointers to satellites are protocol-critical. A mutable resolver,
metadata router, collection metadata contract, or entropy coordinator can
redirect royalties, alter metadata, reinterpret randomness state, or change the
meaning of a freeze. Pointer changes therefore need their own shared policy.

Core satellite pointer families:

```text
ROYALTY_RESOLVER
METADATA_ROUTER
COLLECTION_METADATA
ENTROPY_COORDINATOR
MINT_MANAGER
MINT_LEDGER
ARTIST_REGISTRY
STREAM_ADMINS_OR_GOVERNANCE
ARTWORK_FINALITY_REGISTRY
SYSTEM_MANIFEST
```

Required pointer lifecycle:

1. New pointer targets must be approved by the relevant registry before they
   can be staged.
2. Staging uses the canonical governance action of
   [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-ACTION-ID]. Pointer-specific fields are encoded into the batch
   `callsHash` and the pointer manifest hash; this document does not define
   a second pointer operation preimage. A pointer move whose consistency
   obligations span contracts — pointer plus cached system-manifest fields,
   pointer plus catalog update, finality plus pointer freeze — must execute
   as one atomic [GOV-BATCH] batch (ADR 0010 decision D7.1).

3. Every staged operation emits old target, new target, code hash, manifest
   hash, earliest execution time, actor, indexed action ID, and reason URI/hash.
4. A staged operation can be cancelled before execution by the appropriate
   governance role.
5. Execution rechecks registry eligibility, code hash, manifest hash, and
   operation ID.
6. Emergency bypass is allowed only for incident response and must be limited to
   moving from an incident-revoked target to a pre-approved compatible target
   or to a safe read-only fallback. It must not redirect owed funds or final
   artwork arbitrarily.
   For `ENTROPY_COORDINATOR`, the pre-approved compatible target must be
   write-capable because mint registration is required; there is no read-only
   entropy fallback for live minting.
7. Pointer freezes are one-way. A frozen pointer cannot be changed except
   through a future Core successor declaration; do not add a hidden unfreeze.
8. Frozen collections and tokens keep using the module identity captured in
   their freeze/finality manifest unless the manifest explicitly points to an
   accepted recovery route.
9. Pointer changes must not alter already-finalized entropy seeds, already
   created split profiles, already credited escrow, or frozen artwork
   manifests.
10. Pointer replacement for metadata routers, renderers, collection metadata,
    dependency sources, or entropy coordinators is blocked while any frozen or
    finalized collection depends on the old target unless one of these is true:
    the collection is address-pinned and keeps reading the old target; the new
    target proves it supports the exact frozen route/snapshot; or an executed
    recovery manifest explicitly supersedes the frozen route.
11. Pre-approved fallback targets must exist before the incident
    (ADR 0011 decision R10). For every critical pointer family — at
    minimum `ENTROPY_COORDINATOR` and `MINT_MANAGER`, with the
    deployment manifest recording the full critical-family list —
    genesis requires at least one registry-`ACTIVE`, pre-approved
    compatible fallback target (for example a safe-mode coordinator or
    replacement mint manager) deployed and named in the
    conformance-matrix genesis deployment profile. Without a standing
    fallback, the rule 6 emergency bypass and the permissionless
    emergency move of [LTA-GOV] rule 7 decay into a multi-day
    `DELAYED_LOOSENING` registration cycle at the worst moment — a Safe
    cannot conjure a reviewed fallback inside a 4-hour emergency window.
    A rehearsed permissionless emergency move to each fallback is
    release evidence, and the conformance matrix gates the fallback
    inventory.

Frozen-route compatibility is reported through a small read:

```solidity
interface IStreamFrozenRouteAwareModule {
    function supportsFrozenRoute(
        uint256 collectionId,
        bytes32 finalityRecordHash,
        bytes32 frozenRouteHash
    ) external view returns (bool);
}

interface IStreamFrozenRouteRegistry {
    function frozenRoute(bytes32 routeType, uint256 collectionId)
        external
        view
        returns (
            bool pinned,
            address module,
            bytes32 routeHash,
            bytes32 finalityRecordHash
        );
}

event FrozenRoutePinned(
    uint16 schemaVersion,
    bytes32 indexed routeType,
    uint256 indexed collectionId,
    address indexed module,
    bytes32 routeHash,
    bytes32 finalityRecordHash
);
```

Protocol v1 routing model: Core stays small and calls the current global
`METADATA_ROUTER`. The metadata router, not Core, owns collection-level frozen
route dispatch. A replacement global router is deployment-conformant only if it
can serve or delegate every pinned frozen route reported by the frozen route
registry, or if an executed recovery manifest supersedes that route. Core does
not add arbitrary per-collection router pointers in v1.

Required events:

```solidity
event CoreSatellitePointerStaged(
    uint16 schemaVersion,
    bytes32 indexed pointerType,
    bytes32 indexed actionId,
    address indexed newTarget,
    address oldTarget,
    bytes32 newTargetCodeHash,
    bytes32 newTargetManifestHash,
    uint64 notBefore,
    bytes32 reasonHash,
    string reasonURI
);

event CoreSatellitePointerUpdated(
    uint16 schemaVersion,
    bytes32 indexed pointerType,
    bytes32 indexed actionId,
    address indexed newTarget,
    address oldTarget
);

event CoreSatellitePointerFrozen(
    uint16 schemaVersion,
    bytes32 indexed pointerType,
    bytes32 indexed actionId,
    address target,
    bytes32 manifestHash
);
```

Core must expose a required pointer read interface from genesis:

```solidity
interface IStreamCorePointerView {
    function getSatellitePointer(bytes32 pointerType)
        external
        view
        returns (
            address target,
            bytes32 codeHash,
            bool frozen,
            bytes32 moduleType,
            bytes4 interfaceId,
            address registry,
            ModuleRegistryStatus registryStatus,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash
        );
}
```

Finality discovery, the system manifest, monitoring, and indexers depend on
this interface rather than individual public variable getter names. Core must
not call the registry from this read. `registryStatus` is the cached status
observed and stored during the latest successful pointer scheduling/execution
recheck. If tools need the live registry status, they should call the registry
directly with their own gas policy and compare it with Core's cached value.

## Governed Gas Parameters [LTA-GGP]

An immutable gas cap is a bet against 50 years of opcode repricing: one
hard fork that reprices `SLOAD` or cold access can turn a fixed cap into a
permanent outage for a frozen collection whose route can never change.
Protocol v1 therefore contains no immutable external-call gas cap anywhere
(ADR 0010 decision D1). Every external-call gas bound — royalty resolver
reads, metadata router reads, entropy registration and view reads, ERC-1271
verification, finality component reads, gate calls, asset-policy checks,
escrow flush floors, and any future bound — is a Governed Gas Parameter
(GGP).

This section is the single normative home of the pattern. Subsystem specs
instantiate parameters — hosts, genesis values, floors, probes — and cite
this section; restating the model is a defect under the precedence rule.

A Governed Gas Parameter is:

1. a named constant whose current value is a storage-backed read on its
   host contract or parameter store, never a deploy-time immutable or a
   compiled-in constant;
2. paired with an immutable per-parameter floor set at deployment from
   measured need plus margin, below which the value can never be set;
3. recorded in the release manifest with its genesis value, floor,
   measurement evidence, and host;
4. a named member of the hard-fork/repricing review checklist (State
   Export And Archival Operations);
5. identified by
   `parameterId = keccak256("6529STREAM_GGP_" || <constant name>)`,
   recorded in the owning subsystem's domain table;
6. paired with a named probe contract — a Permanent-class genesis
   inventory member under the probe permanence rules of
   [LTA-GGP-PROBES], recorded per parameter in the release manifest,
   never a production read path — that anyone can call to execute the
   guarded path (or a faithful equivalent of it) at a candidate value
   and record the outcome onchain. The probe record is the verification
   locus for probe-gated lowering, emergency raising, and the
   permissionless conditional raise and re-lower (requirements 1–2
   and 11; ADR 0011 decision R5; ADR 0012 decision T1; ADR 0014
   decision V7).

The probe surface is canonical so that a Safe, an autonomous governor,
and a 2075 archivist verify the same onchain evidence:

```solidity
event GasParameterProbed(
    uint16 schemaVersion,
    bytes32 indexed parameterId,
    bytes32 indexed probeRunId,
    bool passed,
    uint256 probedValue,
    bytes32 evidenceHash
);

function lastProbeRun(bytes32 parameterId, uint256 probedValue)
    external
    view
    returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock);
```

A probe run must execute the guarded operation itself, or a faithful
equivalent measured on the production path, at `probedValue`;
`evidenceHash` commits to the run's measurement artifact. The
`GasParameterProbed` event and the `lastProbeRun` read are hosted on
the probe contract itself — the probe-run record lives on the probe,
never on the host (ADR 0012 decision T1) — and hosts consume the record
through the probe address bound at parameter registration. A probe may
additionally emit a parameter-named diagnostic alias event alongside
the canonical record; the event catalog must tag every such alias as a
member of the probe-record family, mirroring the requirement 4
change-event alias rule, and the canonical
`GasParameterProbed`/`lastProbeRun` record remains the only
verification locus (ADR 0013 decision U7). Each
parameter's release-manifest entry records its probe contract and the
probe recency bound `probeMaxAgeBlocks` consumed by the execution
rechecks below.

### GGP Probe Contracts [LTA-GGP-PROBES]

The probe record is the only evidence that can move a parameter after
total governance loss, so the probe is hardened like the surfaces it
protects (ADR 0012 decision T1):

1. Probe contracts are Permanent-class members of the genesis
   deployment inventory: named in the conformance-matrix genesis
   deployment profile, deployed deterministically ([LTA-DEPLOY]), and
   covered by the matrix static permanence checks, the golden interface
   tests, and the audit plan. A probe outside the production inventory
   is nonconformant.
2. Probes are immutable and permissionless: no owner, no upgrade path,
   no selfdestruct, no pause switch, and callable by anyone forever.
   A probe run must be executable with no role, allowlist, or fee.
3. The probe-run record — `GasParameterProbed` and `lastProbeRun` —
   lives on the probe contract. The host verifies probe records at
   execution rechecks through the probe address bound at parameter
   registration. While governance functions, a parameter's probe
   binding may move to a successor Permanent-class probe through the
   normal delay class with staging events and cancellation; with
   governance lost the binding is frozen, which is why every probe is
   Permanent-class.
4. Probe inputs are pinned per parameter: each probe executes a fixed,
   caller-independent scenario whose input corpus is recorded in the
   release manifest and committed by `evidenceHash`. No caller-supplied
   argument may select code paths, shape contract state, or alter the
   measured gas of the guarded execution.
5. Genuine-failure rule: before recording any outcome, the probe must
   prove the guarded execution actually received `probedValue` (or the
   live current value, for current-value runs). A run the prober
   under-funded, gas-shaped, or otherwise starved must revert without
   recording. A recordable failing run exists only when the guarded
   operation was genuinely given the probed value and still failed.
6. `probeMaxAgeBlocks` is recorded per parameter in the release
   manifest, enforced by the host at execution rechecks, and must be at
   least `PROBE_MAX_AGE_FLOOR_BLOCKS`. The planning floor is 50,400
   blocks (roughly seven days at twelve-second cadence); the deployed
   floor is pinned in the release manifest. The floor is generous by
   design: with governance gone nobody can widen the recency bound, and
   an over-tight bound would strand the conditional raise and
   re-lower it exists to serve.
7. A probe's own executability must not depend on a healthy value of
   any parameter it probes; a probe callable only when the guarded path
   is already healthy is nonconformant.
8. Probes hold no pointer, no funds, and no protocol authority beyond
   writing their own probe records; no production read path routes
   through a probe.
9. The zero-signer museum-mode drill executes the
   probe-and-conditional-raise path — and its conditional-re-lower
   twin ([LTA-GGP] requirement 11) — end to end against the deployed
   probe contracts with no governance signer (State Export And Archival
   Operations).

Requirements:

1. Raising a GGP is a service-restoring action with a bounded blast
   radius (ADR 0011 decision R5). Every raise — staged, emergency, or
   conditional — is bounded per action to at most 2x the parameter's
   current value; the host enforces the bound, and larger moves take
   multiple actions. Staged raises use the normal delay class. The
   emergency raise path is raise-only and health-probe-gated: it
   executes only while the parameter's named probe has recorded, within
   `probeMaxAgeBlocks`, a failing run at the current value — proof that
   the guarded path is actually degraded — and it may repeat, one
   bounded step at a time, while fresh probe runs keep proving failure.
   A failing run is recordable only under the genuine-failure rule
   ([LTA-GGP-PROBES] rule 5), so a manufactured under-funded call can
   never arm this path. An emergency path that could raise a healthy
   parameter is nonconformant; requirement 10 states why the raise
   direction needs this guard.
2. Lowering a GGP through governance must use the normal delay class,
   must revert below the
   immutable floor, and is probe-gated at the named locus: the lower's
   execution recheck must verify, through the parameter's named probe
   contract, a recorded passing run at exactly the proposed value no
   older than `probeMaxAgeBlocks` (ADR 0011 decision R5). The probe
   record is onchain evidence — a lower whose probe obligation is
   satisfiable only by an offchain artifact is nonconformant, because an
   autonomous governor could not verify it and a Safe could not prove
   it. Probe executions at candidate values live on the parameter's
   Permanent-class probe contract ([LTA-GGP-PROBES]), never in
   production read paths. The `FORWARDING_CAP` conditional re-lower of
   requirement 11 is the single permissionless exception, probe-gated
   at this same locus with its own per-action bound (ADR 0014
   decision V7).
3. GGP values are Operational-layer. They must be excluded from finality
   manifests, frozen-route identity, policy hashes, assignment hashes, and
   every Permanent preimage, so retuning gas never touches artwork or
   economic identity (ADR 0010 decision D1.3). Frozen collections keep
   working because the cap can always be raised.
4. Every GGP change executes through the canonical governance action
   ([GOV-ACTION-ID] in
   [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md))
   and emits the canonical change event:

   ```solidity
   event GasParameterUpdated(
       uint16 schemaVersion,
       bytes32 indexed parameterId,
       address indexed host,
       bytes32 indexed actionId,
       uint256 oldValue,
       uint256 newValue,
       uint256 floor
   );
   ```

   A host spec may instead pin a parameter-named alias event carrying at
   least `(schemaVersion, oldValue, newValue, floor)` where the parameter
   and host are implied by the emitter; the event catalog must tag every
   alias as a member of the GGP change family so indexers reconstruct
   every parameter's value history uniformly.
5. Every EIP-150 63/64 parent-gas precheck reads the current GGP value at
   call time, never a compiled-in constant (ADR 0010 decision D1.4).
6. Monitoring must alert when a measured guarded path exceeds two-thirds
   of its current GGP value or when margin falls below the
   release-manifest SLO, whichever is stricter.
7. The remediation order for a guarded path outgrowing its bound is:
   staged (or emergency raise-only) GGP raise first; a storage-compressed
   successor implementation second; a new deployment line only when the
   host contract itself is obsolete. Cap exhaustion is a recoverable
   operational incident, never a permanent outage.
8. The mint-path never-brick chain is explicit (ADR 0010 decision D1.5):
   entropy registration failure cannot permanently brick minting, because
   `ENTROPY_REGISTRATION_GAS_LIMIT` has no ceiling above its floor — any
   needed value is reachable in bounded 2x-per-action steps through
   staged governance, and the governed emergency raise path stays
   available while the probe proves failure (requirement 1) — ([EC-REGGAS]
   in
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md))
   and the `ENTROPY_COORDINATOR` pointer is replaceable under the Core
   Satellite Pointer Policy. As a `FAIL_CLOSED_PRECHECK` parameter it has
   no permissionless conditional raise — requirement 11 is
   `FORWARDING_CAP`-only (ADR 0012 decision T1): mint liveness is a
   governed-liveness guarantee, while read survival is the permissionless
   museum-mode guarantee. The same two-step recovery chain — raise the
   cap, then replace the pointer — applies to every guarded satellite
   read.
9. GGP floor/raise/lower/probe behavior is conformance-gated: the matrix
   governance gates must include a floor-rejection test, a raise-path
   test with a per-action raise-bound rejection, an emergency-raise
   probe-gate test (a healthy probe record blocks; a failing record
   admits), a probe-gated lower test, a permissionless
   conditional-raise test and a permissionless conditional-re-lower
   test, each executed with no governance signer, for every
   `FORWARDING_CAP` parameter (requirement 11), a scope-rejection test
   proving no conditional-raise or conditional-re-lower action exists
   — or that its execution reverts — for every `FAIL_CLOSED_PRECHECK`
   and `MIN_GAS_GATE` parameter, which the requirement 10
   reclassification rule extends to every parameter whose precheck
   shortfall reverts a user entry or settlement call, a
   forged-failure probe-integrity test proving an under-funded or
   input-shaped probe call reverts without recording a failing run
   ([LTA-GGP-PROBES] rules 4–5), the [LTA-GGP-PROBES] permanence checks
   (static permanence, golden interface, museum-mode drill), a
   host-introspection test proving `gasParameterInfo` (requirement 12)
   returns the pinned floor, probe binding, failure class, and recency
   bound for every deployed parameter, and change-event assertions for
   every deployed GGP.
10. Raise direction is not uniformly safe, and each parameter says so
    (ADR 0011 decision R5). Every release-manifest GGP entry records the
    parameter's failure-direction class: `FORWARDING_CAP` (bounds gas
    forwarded to a fail-safe read; raising restores service),
    `FAIL_CLOSED_PRECHECK` (consumed by an EIP-150 63/64 parent-gas
    precheck on a fail-closed path, such as
    `ENTROPY_REGISTRATION_GAS_LIMIT` and `MINT_GATE_GAS_LIMIT`; a raise
    beyond what parent transactions can supply halts the guarded
    operation at every call), or `MIN_GAS_GATE` (a minimum-gasleft
    admission gate such as `FLUSH_GAS_FLOOR`; an excessive raise blocks
    the gated operation). Classification follows observed failure
    direction on the guarded call, never read-path association
    (ADR 0014 decision V7): a parameter consumed by an EIP-150
    parent-gas precheck whose shortfall reverts a user entry or
    settlement call on a purchase or mint path is
    `FAIL_CLOSED_PRECHECK` even when the gas it bounds ultimately
    funds a failure-isolated read or attempt whose caught failure is
    safe — raising such a parameter raises every caller's revert
    threshold, so a permissionless raise would hand anyone a one-way
    ratchet on collector-transaction viability, exactly the hazard
    the class split exists to prevent. The anti-brick asymmetry —
    raising is
    service-restoring — holds only for `FORWARDING_CAP` parameters. For
    the other two classes the raise direction is itself a
    denial-of-service lever, which is exactly why every raise is bounded
    per action, staged raises take the normal delay class with staging
    events and cancellation, and the emergency path cannot fire while
    the probe reports the guarded path healthy (requirement 1). The
    probe for a `FAIL_CLOSED_PRECHECK` or `MIN_GAS_GATE` parameter must
    prove the guarded operation itself succeeds at the probed value — a
    registration completes, a flush is admitted — never merely that a
    read returns, and the staging artifact for any raise of such a
    parameter must record the proposed value as a fraction of the
    current block gas limit so reviewers see the halt threshold
    approaching. The permissionless conditional raise and re-lower of
    requirement 11
    never apply to these two classes (ADR 0012 decision T1).
11. Lost-governance survivability: permissionless conditional raises
    and re-lowers, for `FORWARDING_CAP` parameters only (ADR 0011
    decision R5; ADR 0012 decision T1; ADR 0014 decision V7). The
    host of every `FORWARDING_CAP` parameter
    must register at deployment a pre-approved conditional-raise action
    — a standing pre-authorized action in the spirit of the
    guardian-module pattern ([LTA-GUARDIAN]) — executable by anyone,
    with no live governance signer, when the parameter's named probe
    has recorded a failing run at the current value within
    `probeMaxAgeBlocks`. A conditional raise takes the same bounded
    per-action step as every other raise, may repeat while fresh probe
    runs keep proving failure, can never lower a value or touch any
    other parameter or pointer, and emits the canonical change event
    carrying the pre-registered action ID. Because probe runs are
    themselves permissionless, a gas repricing that degrades
    `tokenURI()`/`royaltyInfo()` for frozen collections after total
    governance loss is recoverable by anyone: run the probe, execute the
    conditional raise, and repeat until the probe passes. Read-only
    museum mode (State Export And Archival Operations) lists this as a
    surviving mechanism, and the museum-mode drills exercise it.

    The surviving ratchet is two-way (ADR 0014 decision V7). The host
    of every `FORWARDING_CAP` parameter must likewise register at
    deployment a pre-approved conditional re-lower action, executable
    by anyone with no live governance signer, whose execution recheck
    verifies through the parameter's named probe a recorded passing
    run at exactly the proposed lower value within
    `probeMaxAgeBlocks`. A conditional re-lower takes a bounded
    per-action step symmetric with the raise — no lower than half the
    current value per action — reverts below the immutable floor, can
    never raise a value or touch any other parameter or pointer, and
    emits the canonical change event carrying its pre-registered
    action ID. It exists because every raise also raises the minimum
    parent gas the parameter's EIP-150 precheck implies for callers,
    and onchain consumers that forward fixed caller stipends —
    2300-gas-class sends and capped `staticcall` wrappers in royalty
    engines and marketplace settlement paths — silently receive the
    fail-safe fallback below that threshold while `eth_call` readers
    see service restored. When a repricing that armed conditional
    raises is later reversed, anyone can walk the value back down to
    a probe-passing level instead of leaving fixed-stipend readers
    zeroed forever: probe runs, bounded raises, and bounded re-lowers
    together make the post-governance-loss cap self-correcting in
    both directions.

    No permissionless raise or re-lower exists for
    `FAIL_CLOSED_PRECHECK` or `MIN_GAS_GATE` parameters: registering a
    conditional-raise or conditional-re-lower action
    for either class is nonconformant, and those parameters raise only
    through governance (staged, or the requirement 1 emergency path).
    For a fail-closed or minimum-gas parameter the raise direction is a
    denial-of-service lever (requirement 10) — a manufactured failing
    run would let anyone ratchet a mint precheck or flush floor past
    what parent transactions can supply, and the corrective lower is a
    delayed governed action. The museum-mode guarantee never depended on
    those classes: with governance gone, reads survive permissionlessly;
    minting and flushing are governed-liveness surfaces (ADR 0012
    decision T1).
12. Pinned host introspection (ADR 0013 decision U2). Every GGP host
    exposes, for each parameter it hosts, the canonical storage-backed
    introspection read:

    ```solidity
    function gasParameterInfo(bytes32 parameterId)
        external
        view
        returns (
            uint256 value,
            uint256 floor,
            address probe,
            uint8 failureClass,
            uint64 probeMaxAgeBlocks
        );
    ```

    `value` and `floor` are the host's live storage values; `probe` is
    the probe binding consumed by the execution rechecks;
    `failureClass` is the requirement 10 failure-direction class with
    pinned numeric IDs `NONE = 0` (unregistered `parameterId`),
    `FORWARDING_CAP = 1`, `FAIL_CLOSED_PRECHECK = 2`, and
    `MIN_GAS_GATE = 3`, mirrored in the Numeric ID Catalog;
    `probeMaxAgeBlocks` is the recency bound the host enforces. An
    unregistered `parameterId` returns the zeroed tuple. Release
    manifests and mirror tables remain evidence and convenience — this
    read is the normative source on the lost-governance raise path, so
    a stranger executing requirement 11 locates the probe, floor,
    class, and recency bound from host state alone, with no manifest
    and no mirror. Hosts may keep narrower reads (for example the
    split-factory `gasParameter`/`gasParameterFloor` keys); the
    introspection read is additionally required of every host from
    genesis, golden-tested per host (requirement 9), and exercised by
    the zero-signer museum-mode drill ([LTA-GGP-PROBES] rule 9).

GGP inventory. The model is instantiated by the parameters below; each
home owns host, genesis value, floor sizing, failure-direction class,
and probe definition — what the probe executes, what the faithful
equivalent is for permissioned guarded paths, and what `evidenceHash`
commits to. An inventory row whose home lacks a probe definition or a
pinned failure-direction class is nonconformant; the matrix verifies
one probe definition and one class per row, mirroring the
GGP-identifier completeness rule (ADR 0012 decision T1). A row
instantiated on more than one host — `METADATA_ERC1271_VERIFY_GAS`
across the verifying metadata satellites, `VRF_CALLBACK_GAS_LIMIT`
across provider adapters — still binds exactly one Permanent-class
probe contract, counted once per row in the genesis inventory
(ADR 0013 decision U9): every host binds that probe at parameter
registration, the probe's pinned scenario executes the guarded path of
every bound host, `evidenceHash` commits to the per-host measurements,
a run records `passed = true` only when every bound host's guarded
execution genuinely received `probedValue` and succeeded, and each
host enforces its own `probeMaxAgeBlocks` recheck against the shared
record. For every row
the release manifest records the probe contract, `probeMaxAgeBlocks`,
failure-direction class, and — for `FORWARDING_CAP` rows — the
conditional-raise and conditional-re-lower registrations plus the
row's fixed-stipend inventory (requirements 10–11; ADR 0014 decision
V7): every known fixed-caller-stipend consumer class of the guarded
read — 2300-gas-class sends and the capped `staticcall` wrappers of
pinned marketplace and royalty-engine integrations — together with
the minimum parent gas the row's precheck implies at the genesis
value, so repricing reviews and the marketplace evidence gates can
prove that pinned integrators' forwarded stipends clear the
threshold at genesis and across raise chains:

| Parameter | Host | Normative home |
| --- | --- | --- |
| `ROYALTY_RESOLVER_GAS_LIMIT` | `StreamCore` | [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP], [RSR-2981-GAS] |
| `ROYALTY_RETURN_GAS_BUFFER` | `StreamCore` | [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP] |
| `ERC_1271_GAS_LIMIT` | split factory parameter store | [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-1271] |
| `ASSET_POLICY_GAS_LIMIT` | split factory parameter store | [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP], [RSR-ASSET-POLICY] |
| `WALLET_DEPOSIT_GAS_LIMIT` | split factory parameter store | [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP] |
| `FLUSH_GAS_FLOOR` | revenue escrow | [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP] |
| `MINT_GATE_GAS_LIMIT` | mint manager | [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-GATES] |
| `TICKET_ERC1271_GAS_LIMIT` | `StreamMintTicketGate` | [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-TICKET] |
| `ARTIST_AUTHORITY_GAS_LIMIT` | mint manager | [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-CONSENT] |
| `SALE_ERC1271_GAS_LIMIT` | sale adapters | [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS] |
| `DELEGATE_REGISTRY_GAS_LIMIT` | delegate gate | [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS] |
| `SALE_ARTIST_AUTHORITY_GAS_LIMIT` | sale adapters | [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS], [SSA-CONTEST-STOP] |
| `REVEAL_ATTEMPT_GAS_LIMIT` | sale adapters | [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-REVEAL], [SSA-GAS] (ADR 0013 decision U7) |
| `SALE_NFT_DELIVERY_GAS_LIMIT` | sale adapters | [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS] (ADR 0013 decision U6) |
| `METADATA_ROUTER_GAS_LIMIT` | `StreamCore` | [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md) [MRR-ROUTER-GGP] |
| `ENTROPY_VIEW_GAS_LIMIT` | metadata router | [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md) [MRR-ENTROPY-READ] |
| `ENTROPY_REGISTRATION_GAS_LIMIT` | `StreamCore` | [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md) [EC-REGGAS] |
| `ENTROPY_RESULT_PROBE_GAS_LIMIT` | entropy coordinator | [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md) [EC-INCIDENT-ROLE] |
| `VRF_CALLBACK_GAS_LIMIT` | provider adapters | [`docs/stream-entropy-providers.md`](stream-entropy-providers.md) [EP-VRF-CONFIG] |
| `ARTIST_ERC1271_VERIFY_GAS` | artist registry | [`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-SIGVER] |
| `METADATA_ERC1271_VERIFY_GAS` | verifying metadata satellites (owner records, attestations, artist-attestation host) | [`docs/collection-metadata-contract.md`](collection-metadata-contract.md) [CMC-SIGVER-GGP] |
| `FINALITY_COMPONENT_READ_GAS` | finality registry | this document (Artwork Finality Freeze) |

A future guarded path that is not in this inventory must still be a GGP;
the inventory grows by ordinary spec amendment, and the release manifest is
the authoritative deployed set.

The repricing-review membership is bidirectional: every hard-fork or
gas-schedule review (State Export And Archival Operations) remeasures every
inventory row against its current value and floor, and publishes raise
recommendations in the compatibility report before user impact, not after.

### Governed Time Parameters [LTA-GTP]

A frozen block count is the temporal twin of an immutable gas cap: block
cadence is not stable over 50 years, and a block-denominated liveness
window frozen at configuration time silently rescales its wall-clock
meaning with every consensus-timing change. Every host-level protocol
block-count window that gates a liveness, recovery, or SLO path —
entropy request timeouts, reveal SLO windows, fresh-recovery waiting
periods, and any future host-level block-denominated window — is
therefore a Governed Time
Parameter (GTP) under the same floor/raise/probe discipline as gas
(ADR 0012 decision T1); the per-collection declarations those windows
overlay are collection timing policies, a distinct non-parameter
concept (membership rules below; ADR 0013 decision U9). This
subsection is the single normative home of
the GTP pattern; subsystem homes instantiate parameters and cite it.

A Governed Time Parameter is:

1. a named constant whose current value is a storage-backed read on its
   host, never a deploy-time immutable, a compiled-in constant, or a
   collection timing policy. Collection timing policies — the
   per-collection artist-elected timing declarations a collection
   freezes at configuration, such as `requestTimeoutBlocks`,
   `requestSLOBlocks`, and `notBeforeBlocks` — are policy data, never
   parameters (ADR 0013 decision U9). Where a collection freezes a
   declared window, the declaration is a promised minimum that bounds
   the effective window from below, and the host GTP overlays it at
   evaluation time — the effective-window and config-freeze semantics
   are owned by the instantiating home ([EC-TIME] in
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md))
   — so cadence drift is correctable even for collections that can
   never be reconfigured;
2. paired with an immutable per-parameter floor (in blocks) plus a
   pinned wall-clock floor: the host stores, immutably per parameter,
   the minimum wall-clock width in seconds the window must cover — the
   value the cadence probe verifies candidates against — and the
   release manifest records genesis value, block floor, wall-clock
   floor, host, and sizing evidence;
3. identified by
   `parameterId = keccak256("6529STREAM_GTP_" || <constant name>)`,
   recorded in the owning subsystem's domain table;
4. Operational-layer, like GGP values (requirement 3 above): excluded
   from finality manifests, frozen-route identity, policy hashes,
   assignment hashes, and every Permanent preimage, so retuning a
   window never touches artwork or economic identity;
5. a named member of the repricing/consensus-timing review checklist:
   every review that observes a material block-time, timestamp, or
   finality change — in either direction: slowdown stretches every
   block-denominated window past its declared wall-clock intent, and
   acceleration shrinks it below (ADR 0014 decision V7) — remeasures
   every GTP row against its wall-clock
   intent and publishes raise/lower recommendations before user impact;
6. paired with a named cadence probe — a Permanent-class probe contract
   under [LTA-GGP-PROBES], with its own release-manifest entry and
   `probeMaxAgeBlocks` under those rules — that anyone can call to
   record observed block cadence onchain over a sampling window at
   least `CADENCE_SAMPLE_FLOOR_BLOCKS` wide (planning value 1,000
   blocks; deployed value pinned in the release manifest) and to record
   pass/fail for a candidate value against the parameter's pinned
   wall-clock floor at that observed cadence. One cadence probe
   contract may serve every GTP row of its host — observed cadence is
   a chain fact, not a per-parameter path — counted once in the
   genesis inventory, with the binding recorded per row in the release
   manifest (ADR 0013 decision U9);
7. readable through the canonical host introspection read, mirroring
   [LTA-GGP] requirement 12 (ADR 0013 decision U2):

   ```solidity
   function timeParameterInfo(bytes32 parameterId)
       external
       view
       returns (
           uint256 value,
           uint256 floorBlocks,
           uint64 wallClockFloorSeconds,
           address cadenceProbe,
           uint64 probeMaxAgeBlocks
       );
   ```

   Live value, both floors, the cadence-probe binding, and the recency
   bound come from host state alone — never from a release manifest or
   mirror — with the same per-host golden-test and museum-mode drill
   obligations as the GGP read; an unregistered `parameterId` returns
   the zeroed tuple.

GTP change discipline:

1. Every change executes through the canonical governance action
   ([GOV-ACTION-ID]) on the normal delay class, with staging events and
   cancellation. There is no emergency and no permissionless
   conditional raise or re-lower for GTPs: the lost-governance
   machinery exists for `FORWARDING_CAP` read survival only
   (requirement 11),
   and both GTP directions move liveness semantics — a raise delays
   recovery and fallback rights; a lower trips them early.
2. Raises are bounded per action to at most 2x the current value;
   lowers are bounded per action to no less than half the current
   value and revert below the floor. Larger moves take multiple
   staged actions.
3. A lower is probe-gated at the cadence locus: its execution recheck
   must verify a recorded cadence-probe run no older than the
   parameter's `probeMaxAgeBlocks` proving the proposed count still
   covers the pinned wall-clock floor at the observed cadence.
4. Every GTP change emits the canonical change event:

   ```solidity
   event TimeParameterUpdated(
       uint16 schemaVersion,
       bytes32 indexed parameterId,
       address indexed host,
       bytes32 indexed actionId,
       uint256 oldValue,
       uint256 newValue,
       uint256 floor
   );
   ```

   The cadence probe emits `TimeParameterProbed` with the same field
   shape as `GasParameterProbed`. A host spec may pin parameter-named
   alias events under the same event-catalog family rule as GGP
   requirement 4.
5. The staging artifact for every GTP change records the observed
   seconds-per-block from the latest cadence-probe run and the implied
   wall-clock window before and after the change, so reviewers see
   intent, not raw block counts.
6. GTP behavior is conformance-gated alongside GGPs: floor rejection,
   per-action raise and lower bounds, cadence-probe-gated lower, the
   host-introspection test (`timeParameterInfo`, definition item 7),
   and change-event assertions for every deployed GTP (Release Gates,
   governance gate 7).
7. Wall-clock floors bind in both directions, and scheduled
   acceleration is handled at the activation boundary (ADR 0014
   decision V7). Cadence slowdown lengthens every frozen
   block-denominated window, so escalations arrive late; a slot-time
   reduction shrinks every effective window's wall-clock width, so
   liveness, incident-eligibility, and recovery-pacing gates open
   early until corrective raises land. When a scheduled
   consensus-timing change would shrink any GTP-governed effective
   window below its pinned wall-clock floor or recorded intent,
   operations must stage the corrective GTP raises to execute at or
   before the change's activation — mirroring the activation-boundary
   drain rule of [EP-INFLIGHT] in
   [`docs/stream-entropy-providers.md`](stream-entropy-providers.md) —
   and the pre-activation staging alert joins the release-manifest
   monitoring plan. Instantiating homes state both residuals, never
   only the slowdown ([EC-TIME] in
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)).

The GTP inventory is owned by the subsystem homes; the genesis rows are
the coordinator-hosted entropy lifecycle windows —
`ENTROPY_REQUEST_TIMEOUT_BLOCKS`, `ENTROPY_REVEAL_SLO_BLOCKS`, and
`ENTROPY_RECOVERY_STEP_DELAY_BLOCKS`, overlaying the collection timing
policies (`requestTimeoutBlocks`, `requestSLOBlocks`,
`notBeforeBlocks`) — instantiated with their effective-window semantics
by [EC-TIME] in
[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md).

GTP membership is closed-world and decidable (ADR 0013 decision U9):

1. The name Governed Time Parameter is reserved for members of this
   pattern — host-hosted, block-denominated windows carrying the full
   identifier, floor, cadence-probe, and mirror-row obligations above.
   Labeling any other value a governed time parameter, or claiming
   this pattern's "floor-and-probe discipline" for it, is
   nonconformant.
2. A future host-level block-count liveness window that is not a GTP
   is nonconformant; the release manifest is the authoritative
   deployed set.
3. Collection timing policies are outside the GTP closed world: they
   are per-collection artist-elected timing declarations — overlaid
   policy minima, bound into collection configuration — and carry no
   `parameterId`, no cadence probe, no mirror row, and no inventory or
   probe-contract-count membership. Their semantics are owned by the
   instantiating homes (definition item 1; [EC-TIME]).
4. Seconds-denominated governed windows — deadline, notice, and
   coverage widths hosted by subsystem contracts and remeasured by
   wall-clock intent rather than block cadence — are not GTPs: they
   carry none of this pattern's probe, identifier, or mirror
   obligations, and their floors and staged change discipline are
   owned by their subsystem homes. An auditor decides membership by
   denomination and host: block-denominated host window means GTP,
   full suite required; anything else means no GTP obligations and no
   claim to the name.

## Token Identity Model [LTA-IDENTITY]

Protocol correctness must not depend on heuristic token ID range guesses.

Normative v1 rule:

1. Core stores an explicit `tokenId -> collectionId` mapping for every minted,
   same-transaction allocated, or burned token whose collection identity is
   authoritative.
2. Core stores or exposes an explicit collection-local serial for every minted
   token.
3. Token IDs are allocated sequentially from one global counter
   (ADR 0009 decision 1). Token ID arithmetic carries no meaning and is
   never authority for royalty, metadata, revenue, entropy, or freeze
   resolution.
4. Protocol v1 does not include a standalone premint reservation API. Premint or
   nonexistent token IDs without an authoritative same-transaction allocation
   mapping are unmapped. They may use default royalty behavior or zero, but
   must not be assigned to a collection from a range heuristic.
5. Burned tokens retain their last authoritative collection mapping for royalty
   disclosure and audit history. Burning removes ERC-721 ownership and
   decrements live supply, but it must not clear retained collection identity
   or burned-token audit state. `royaltyInfo()` therefore continues to resolve
   token, collection, then default scope for a burned token through
   `tokenCollectionIdentity`, while `tokenURI()` may still revert because the
   token no longer exists for ERC-721 metadata purposes.
6. Token-level revenue, royalty, metadata, and entropy assignments require an
   authoritative minted or same-transaction allocated token-to-collection
   mapping. They cannot be created for unknown token IDs.
7. Inherited collection freezes apply to token-level assignments through this
   authoritative mapping. No token override can escape an inherited freeze by
   being created before the mapping exists.
8. Core should preserve the conservative burn posture: a frozen
   or artwork-finalized collection is non-burnable unless its pre-freeze policy
   and finality manifest explicitly preserve a burn path and prove that burning
   cannot change the promised artwork, supply semantics, entropy interpretation,
   or revenue/royalty history. If that explicit policy is absent, burn attempts
   for frozen collections revert. Collection-scope artwork finality
   additionally requires the one-way Core burn block (finality
   requirement 7 below).
9. Core must emit `TokenCollectionRegistered(tokenId, collectionId,
   serial)` at every authoritative identity write (ADR 0010 decision
   D10.1). Sequential global token IDs carry no collection information, so
   without this event the token-to-collection mapping is unrecoverable
   from logs by design. The event schema and emission point are owned by
   the Core mint ABI in
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   `[MPA-CORE-ABI]`; event-only reconstruction of token identity and
   collection serial is a normative archival guarantee, listed in the
   protocol v1 event-reconstruction set and gated by the conformance
   matrix.

The baseline implementation's collection-range allocator must be replaced by
the sequential global allocator; the explicit mapping model above is the
long-term identity surface either way (ADR 0009 decision 1).

Sequential IDs inside one shared contract leave no marketplace-consumable
collection identity signal; that is the single reserved open question
(OQ-X8 in [`docs/spec-open-questions.md`](spec-open-questions.md)), and
the candidate directions live in
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
(collection discovery). The onchain identity model above is complete and
unaffected by how OQ-X8 resolves.

Canonical Core read surface:

```solidity
enum StreamTokenLifecycle {
    UNKNOWN,
    PREPARED_INCOMPLETE,
    MINTED,
    BURNED
}

interface IStreamCoreTokenIdentityView {
    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (
            bool mappingExists,
            uint256 collectionId,
            uint256 collectionSerial,
            bool burned
        );

    function tokenLifecycle(uint256 tokenId)
        external
        view
        returns (uint8 lifecycle);

    function coordinatorAtMint(uint256 tokenId)
        external
        view
        returns (address);
}
```

`mappingExists` is the public authoritative identity read. The read semantics
are Permanent; the v1 implementation may derive the result from live
ownership, burned-token audit state, and prepared-mint state rather than
storing a separate boolean. For a currently minted token, the
function returns `(true, collectionId, collectionSerial, false)`. For a burned
token that was once minted, it returns
`(true, lastCollectionId, lastCollectionSerial, true)`. For a prepared-incomplete
token, it returns `(true, preparedCollectionId, preparedCollectionSerial, false)`
while `tokenLifecycle(tokenId)` reports `PREPARED_INCOMPLETE`. For a premint,
nonexistent, or otherwise unmapped token, it returns `(false, 0, 0, false)`.
Royalties, metadata routing, finality components, indexers, and archival tools
should use this read surface rather than private mapping names, historical
`origin/main` helper names, or token ID range inference.
Prepared-incomplete tokens have authoritative identity for the manager-owned
operation but are not ordinary minted ERC-721 tokens. Satellites that can be
called during `PREPARED_INCOMPLETE` must check `tokenLifecycle(tokenId)` and
reject or render provisional state as their spec requires rather than falling
through to the unmapped `(false, 0, 0, false)` branch.
The cross-contract ABI returns `uint8`; the numeric values are pinned in the
Numeric ID Catalog as `UNKNOWN = 0`, `PREPARED_INCOMPLETE = 1`, `MINTED = 2`,
and `BURNED = 3`.

## Token Enumeration Posture [LTA-ENUMERATION]

Core does not carry `ERC721Enumerable` (ADR 0012 decision T10,
superseding ADR 0010 decision D9.3 and the pre-review "keep
`ERC721Enumerable` in Core" principle). The enumerable index structures
would have added roughly 45,000–50,000 gas to every all-cold mint and
roughly 60,000–70,000 gas to every all-cold wallet-to-wallet transfer —
a permanent per-collector tax on every ownership change for the life of
the system — plus several kilobytes against the Core headroom rule, to
serve needs that dense sequential IDs, state exports, and event replay
already serve. The decision is taken before genesis precisely because it
is irreversible after; it is recorded as an owner-flagged supersession
in ADR 0012.

Core enumeration surface:

1. Core exposes `totalSupply()` — the live token count, incremented at
   mint and decremented at burn — and `lastAllocatedTokenId()` — the
   sequential global allocator's high-water mark, zero before the first
   allocation — as Permanent reads from genesis, golden-tested and
   named in the release manifest.
2. Allocation is dense: every `tokenId` in
   `[1, lastAllocatedTokenId()]` has an authoritative
   `tokenLifecycle(tokenId)` and `tokenCollectionIdentity(tokenId)`
   result ([LTA-IDENTITY]), so a state-only walker enumerates every
   token that ever existed without logs, indexes, or heuristics.
3. Core implements no `tokenOfOwnerByIndex`, no `tokenByIndex`, and no
   owner-index or global-index storage, and
   `supportsInterface(0x780e9d63)` returns false, permanently. Adding
   the enumerable standard back is a successor-line decision.

Museum-mode and archival enumeration is served by three independent
lanes, each exercised by the museum-mode drill: state exports (ownership
and token-to-collection roots, [LTA-EXPORT]); sequential-ID iteration
over live state (rule 2 above — `ownerOf`/`tokenLifecycle` walks need
no operator and no logs); and Transfer/mint/burn event replay through
the reconstruction client and mirrored event-history snapshots
([LTA-RECON]; [LTA-EVENT-HISTORY]).

Live per-owner and per-collection reads for integrators are a periphery
concern, served by a stateless enumeration lens:

```solidity
interface IStreamEnumerationLens {
    function tokensOfOwnerInRange(
        address owner,
        uint256 startTokenId,
        uint256 endTokenId
    ) external view returns (uint256[] memory tokenIds);

    function tokensOfCollectionInRange(
        uint256 collectionId,
        uint256 startTokenId,
        uint256 endTokenId
    ) external view returns (uint256[] memory tokenIds);

    function liveTokensInRange(uint256 startTokenId, uint256 endTokenId)
        external
        view
        returns (uint256[] memory tokenIds);
}
```

Lens rules:

1. The lens is stateless: pure paged view walks over `ownerOf`,
   `tokenLifecycle`, and `tokenCollectionIdentity`. It holds no
   pointer, no funds, and no authority, writes nothing, and is never a
   dependency of any Permanent surface — Core has no transfer hooks
   ([LTA-STANDARDS]), so no live onchain index can exist, and none is
   pretended.
2. Callers choose range widths against their RPC budget; ranges are
   `[startTokenId, endTokenId]` inclusive with `endTokenId` capped by
   the caller at `lastAllocatedTokenId()`.
3. The lens registers under module type `STREAM_ENUMERATION_LENS`
   through the module registry ([LTA-REGISTRY]). The genesis deployment
   should deploy and register one lens, named in the genesis deployment
   profile; a deployment that omits it must record the rationale in the
   deployment manifest. Anyone may deploy a replacement lens
   permissionlessly forever.

## Assignment Hierarchy

Default, collection, and token scope should be consistent across revenue,
royalties, metadata, and entropy:

```text
token override
collection override
contract default
zero / disabled / pending fallback
```

Rules:

1. Resolution order must be explicit and tested.
2. A scope can be mutable, exactly frozen, inherited-frozen, or globally frozen.
3. A lower-scope override should not silently escape an inherited freeze unless
   the higher-scope freeze explicitly preserves existing descendants.
4. Set, clear, freeze, and recovery events must include scope, scope ID,
   module/version identity, previous value, new value, and actor.
5. Token-level assignments must be possible only when token identity is known
   before the relevant external effects.
6. Open-ended collections must not require final supply knowledge for revenue,
   royalty, metadata, or entropy policy.

## Freeze Model [LTA-FREEZE]

A 50-year contract needs both flexibility and finality. The system should use
explicit freeze semantics instead of relying on social promises. This
section is the single normative home of the freeze-loosening rule
(ADR 0010 decision D3.6); the protocol v1 Assignment And Freeze State rules
and the revenue-spec freeze mechanics are instantiations that cite it, and
a statement that conflicts with this section is a defect.

Freeze modes:

```text
NONE        mutable subject to governance
EXACT       freezes only the exact default/collection/token key
INHERITED   freezes the exact key and blocks lower-scope changes
GLOBAL      freezes every key in the policy family
```

Freeze rules:

1. Freezes are one-way by default, and there is exactly one loosening
   rule in the entire spec set. Timelocked loosening exists only for
   non-permanent freeze states (`EXACT`, `INHERITED`, and non-permanent
   `GLOBAL`), only for products that explicitly advertised mutable
   economics or loosening at assignment time, and only through the
   ADR 0004 `DELAYED_LOOSENING` action class with before/after policy
   hashes in the execution event. `PERMANENT_FROZEN` states, permanent
   global freezes, and artwork finality never loosen; their only exit is
   a successor Core line. Core satellite pointer freezes are permanent by
   construction and outside this loosening rule entirely ([LTA-POINTERS]
   rule 7). No other document may define a different loosening path;
   hidden unfreezes do not exist.
2. The default protocol posture treats economic and final artwork freezes
   as irreversible; advertising loosening is the explicit exception, never
   the default.
3. Because freeze state is bound into the relevant assignment/policy hash,
   executing a loosening changes that hash and invalidates every signed
   payload that bound the frozen hash (strict-match sales, consents,
   tickets). A later re-freeze to byte-identical policy values reproduces
   the identical hash, and hash-bound payloads validate again by hash
   equality; specs binding assignment hashes must rely on hash equality,
   never on freeze-transition history.
4. Executing any freeze whose class is irreversible (`PERMANENT_FROZEN`,
   permanent `GLOBAL`, artwork finality) must use the ADR 0004
   `TERMINAL_FREEZE` class with both a delay and an independent
   veto/guardian authority ([GOV-WINDOWS]; ADR 0010 decision D8.9). One
   compromised key plus one timelock window must never be sufficient to
   permanently freeze economics or artwork; the matrix governance gates
   verify the veto path.
5. Inherited freeze needs O(1) enforcement through counters, dirty bits, or
   explicit descendant materialization, not unbounded enumeration.
6. Freezing collection metadata should also freeze renderer choice, script
   manifest, dependency manifest, media manifests, and entropy policy if those
   facts define the final artwork.
7. Freezing revenue policy should be per revenue class, because primary-sale
   economics and royalties are separate promises.
8. Global freeze must state whether it also blocks future revenue
   classes, renderer families, provider families, or only existing keys;
   a deployment-wide global revenue freeze also blocks creation of new
   revenue classes (ADR 0009 decision 8).

## Artwork Finality Freeze [LTA-FINALITY]

Final artwork is cross-contract state. A collection cannot be honestly
described as final if the script is frozen but the renderer, dependency
manifest, media manifest, or entropy policy is still mutable — or if the
bound artist never signed it, or if the per-token bytes it promises were
never hash-bound and archived.

Define a single collection finality action hosted by a dedicated
`StreamArtworkFinalityRegistry` satellite. Core stays small; the finality
registry is the contract that performs cross-module discovery, verifies the
component hashes, stores the finality record, and asks Core or the metadata
router to emit any Core-linked refresh/finality event required by indexers.

```solidity
function finalizeCollectionArtwork(
    uint256 collectionId,
    FinalityComponentExpectation[] calldata components,
    bytes32 expectedFinalityRecordHash,
    FinalityManifestRef calldata manifest
) external;
```

Access control:

1. `finalizeCollectionArtwork` requires `ROLE_COLLECTION_FINALITY_ADMIN`,
   an ADR 0004 role reference ([GOV-ROLES]) resolved through the admin
   registry. Ordinary metadata, revenue, entropy, or collection admins
   cannot finalize artwork.
2. Finality is irreversible, so its staged execution uses the ADR 0004
   `TERMINAL_FREEZE` class: a delay plus an independent veto/guardian
   authority per [GOV-WINDOWS] (ADR 0010 decision D8.9). The platform role
   alone is never sufficient for an artist-bound collection: finality
   requirement 9 below additionally requires the verified artist sanction,
   so no operator can finalize an artist's series unilaterally.
3. `scheduleFinalityRecovery` and `cancelFinalityRecovery` require
   `ROLE_COLLECTION_FINALITY_ADMIN`.
4. `executeFinalityRecovery` is permissionless after the scheduled delay if the
   recovery record is still `SCHEDULED` and all execution preconditions recheck.
5. For artist-bound collections, a recovery with
   `artworkBytesChanged = true` additionally requires the artist-side
   approval or recorded-unavailability path of Finality Recovery rule 9;
   the platform finality role alone is never sufficient to change which
   bytes are served for a sanctioned work (ADR 0011 decision R7.3).

```solidity
struct FinalityManifestRef {
    string uri;
    bytes32 uriHash;
    bytes32 contentHash;
    bytes32 schemaId;
    bytes32 canonicalizationHash;
}

struct RecoveryManifestRef {
    string uri;
    bytes32 uriHash;
    bytes32 contentHash;
    bytes32 schemaId;
    bytes32 canonicalizationHash;
}
```

`uriHash = keccak256(bytes(uri))`. `contentHash` is the hash of the canonical
manifest bytes, not the hash of a URL string. The manifest should be
canonicalized through the schema named by `schemaId` and
`canonicalizationHash`, for example RFC 8785/JCS JSON or deterministic CBOR.
PREMIS, C2PA, IIIF, preservation, recovery, and human-readable reconstruction
records are bound through `contentHash` when they are part of the finality
manifest.

Every participating satellite must expose a finality read surface:

```solidity
struct FinalityComponentState {
    bool frozen;
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

struct FinalityComponentExpectation {
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

interface IStreamFinalityComponent {
    function finalityState(uint256 collectionId)
        external
        view
        returns (FinalityComponentState memory);
}

interface IStreamFinalityDiscovery {
    function finalityComponentCount(uint256 collectionId)
        external
        view
        returns (uint256);

    function finalityComponentAt(uint256 collectionId, uint256 index)
        external
        view
        returns (FinalityComponentExpectation memory);

    function finalityDiscoveryHash(uint256 collectionId)
        external
        view
        returns (bytes32);
}
```

The finality registry stores:

```solidity
struct CollectionFinalityRecord {
    bool finalized;
    bytes32 finalityRecordHash;
    bytes32 manifestContentHash;
    bytes32 manifestURIHash;
    string finalityManifestURI;
    bytes32 componentsHash;
    address manifestPointer;
    uint64 finalizedAt;
}

mapping(uint256 collectionId => CollectionFinalityRecord) finalityRecords;
mapping(uint256 collectionId => FinalityComponentExpectation[]) finalityComponents;
```

`manifestPointer` is the storage-backed discovery pointer for the
canonical manifest bytes required onchain by finality requirement 14:
the SSTORE2 blob address holding those bytes, or the registry's own
address when the bytes live in registry storage behind a typed
accessor. It is part of the state-readable payload discovery surface
([LTA-PAYLOAD-DISCOVERY]; ADR 0012 decision T3), so a post-expiry
archivist locates the bytes from state reads alone. It is discovery
data, not identity: it is not an input to `finalityRecordHash`.

`interfaceId` is the ERC-165-style four-byte interface identifier for the
component's finality read surface. If a component does not have an ERC-165
interface, the adapter must expose a Stream-defined `bytes4` interface ID.

`componentsHash` is:

```solidity
bytes32 componentsHash = keccak256(abi.encode(
    STREAM_FINALITY_COMPONENTS_V1,
    components
));
```

The submitted component list must be sorted ascending by `(componentType,
component, interfaceId, codeHash, moduleVersion, manifestHash, dataHash)` and
must not contain duplicates by that full identity tuple. Sorting is by
ABI-encoded field value, with addresses compared as 20-byte values and
`bytes4` compared as four-byte values. Any unsorted or duplicate list reverts
before finality is recorded.

`coreCollectionFactsHash` is computed onchain from Core through a small typed
read, not supplied as an opaque offchain assertion:

```solidity
struct CoreCollectionFinalityFacts {
    bool exists;
    bool hasMaxSupply;
    uint8 status;
    uint8 supplyMode;
    uint64 createdAt;
    uint64 maxSupply;
    uint64 mintedSupply;
    uint64 burnedSupply;
    uint64 nextCollectionSerial;
    bytes32 collectionConfigHash;
}

interface IStreamCoreFinalityFacts {
    function coreCollectionFinalityFacts(uint256 collectionId)
        external
        view
        returns (CoreCollectionFinalityFacts memory);
}

bytes32 coreCollectionFactsHash = keccak256(abi.encode(
    STREAM_CORE_COLLECTION_FACTS_V1,
    block.chainid,
    address(core),
    collectionId,
    facts.exists,
    facts.hasMaxSupply,
    facts.status,
    facts.supplyMode,
    facts.createdAt,
    facts.maxSupply,
    facts.mintedSupply,
    facts.burnedSupply,
    facts.nextCollectionSerial,
    facts.collectionConfigHash
));
```

`collectionConfigHash` is Core's hash of collection-level supply/status fields
that are not otherwise included above. It must not include mutable display
metadata, economic assignments, or event-only labels.
For protocol v1, if no additional Core-owned collection config fields affect
finality beyond the fields explicitly listed in `CoreCollectionFinalityFacts`,
`collectionConfigHash` is:

```solidity
bytes32 collectionConfigHash = keccak256(abi.encode(
    STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1,
    block.chainid,
    address(core),
    collectionId
));
```

If implementation adds another Core-owned collection config field that affects
minting, burning, supply, status, or finality, this spec must update the
preimage before deployment. A generic "whatever Core stores" hash is not
conformant.

Each component's `dataHash` preimage is component-owned but must be versioned,
typed, and named in that component's manifest. Genesis components must publish
their `dataHash` schema in the release manifest. A generic "hash whatever the
module wants" value is not deployment-conformant.

The registry computes the finality record hash onchain:

```solidity
bytes32 finalityRecordHash = keccak256(abi.encode(
    STREAM_FINALITY_V1,
    block.chainid,
    address(core),
    collectionId,
    coreCollectionFactsHash,
    componentsHash,
    manifest.uriHash,
    manifest.contentHash,
    manifest.schemaId,
    manifest.canonicalizationHash
));
```

`finalizeCollectionArtwork` reverts unless `finalityRecordHash ==
expectedFinalityRecordHash`. The offchain manifest at `manifest.uri` must
include the same component list, Core facts, preservation/provenance references,
and any richer human-readable reconstruction data. Onchain verification uses
the typed `components` calldata, live component reads, and manifest hashes. The
registry cannot and must not try to parse `manifest.uri` onchain.

Component discovery path:

1. The registry is bound to one Core.
2. Core exposes current pointers for `COLLECTION_METADATA`,
   `METADATA_ROUTER`, `ENTROPY_COORDINATOR`, and other Core-owned satellites.
3. The metadata router implements `IStreamFinalityDiscovery` for the resolved
   renderer, dependency source, media/source modules, and any snapshot route for
   `collectionId`.
4. Each discovered component implements `IStreamFinalityComponent` or is wrapped
   by a small finality adapter that reports the required state.
5. `finalizeCollectionArtwork` reverts unless the submitted component list
   exactly matches the discovered components, the submitted component hash
   equals `finalityDiscoveryHash(collectionId)`, and every live
   `FinalityComponentState` equals the corresponding expectation with
   `frozen = true`.
6. After finality, `finalityRecords(collectionId)` and
   `finalityComponents(collectionId, start, limit)` provide the durable
   onchain record and allow future tools to check whether live components still
   match.
7. Finality either freezes the relevant collection-scoped Core pointers in the
   same action or records the collection as address-pinned. If a later global
   pointer move occurs, `verifyFinality(collectionId)` must still compare
   against the address/codehash captured in the finality record and return
   false for the current route unless a public recovery manifest supersedes it.

Required component types include at least:

```text
COLLECTION_METADATA
METADATA_ROUTER
RENDERER
RENDER_CONTEXT
SCRIPT_SOURCE
DEPENDENCY_SOURCE
MEDIA_MANIFEST
ENTROPY_COORDINATOR
ARTIST_SANCTION             artist-bound collections
PLATFORM_WORKS_DECLARATION  artist-less collections
REFERENCE_RENDER            script-based (onchain/hybrid) works
OPTIONAL_SNAPSHOT_ROUTE
```

Exactly one of `ARTIST_SANCTION` and `PLATFORM_WORKS_DECLARATION` applies
to every collection; a finality submission carrying neither is
nonconformant. Both are served by the artist registry, and their component
semantics, `dataHash` preimages, and verification reads are owned by
[`docs/stream-artist-authority.md`](stream-artist-authority.md)
[AA-SANCTION] (ADR 0010 decision D2.3). `REFERENCE_RENDER` binds the
hash-committed reference output captures and execution-environment
manifest whose record schema is owned by
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-FINALITY-INPUTS] (ADR 0010 decision D4.2).

Core facts are not a `FinalityComponentExpectation` entry; they are the
separately computed `coreCollectionFactsHash` or `scopedCoreFactsHash` input to
the finality record. Finality is not valid if any required satellite component
is merely promised frozen offchain.
The finality registry must cap component count and calldata size. Planning
values are `MAX_FINALITY_COMPONENTS = 32` and
`MAX_FINALITY_CALLDATA_BYTES = 32_768`; the deployed constants are measured
before deployment and pinned in the release manifest.

The finality manifest must bind:

1. Core address, chain ID, collection ID, and collection-local supply facts.
2. Collection metadata contract address, module version, and frozen metadata
   root.
3. Metadata router address, router config, and renderer assignment.
4. Renderer address, code hash, renderer version, render context version, and
   renderer manifest hash.
5. Script source type, script bytes hash, script chunk count, and script
   manifest hash.
6. Dependency registry/source identity and dependency payload hashes.
7. Media manifest hashes, image/animation/content URI hashes, and rights or
   preservation manifests where configured.
8. Entropy coordinator address, provider config, provider epoch, collection
   salt commitment, pending/finalized policy, and any allowed post-finality
   entropy state.
9. The token content root, leaf count, and content-root schema for the
   finality scope
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-CONTENT-ROOT]).
10. For script-based works: the reference render captures, the
    execution-environment manifest (renderer build, render context
    version, browser/engine build, viewport, color space, capture
    toolchain), the archived execution-environment artifact references,
    and the pinned re-render acceptance mode, bound through the
    `REFERENCE_RENDER` component (ADR 0010 decision D4.2; ADR 0011
    decision R3).
11. The artist sanction record hash, or the platform-works declaration
    hash, and — for artist-bound collections — the `ARTIST_INTENT` record
    hash or its recorded artist-signed waiver
    ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
    [AA-SANCTION], [AA-INTENT]).
12. The archive receipts and fixity records satisfying the dual-family
    archival rule (finality requirement 11) for every offchain
    render-critical payload.
13. Post-freeze exceptions, if any, such as typo-only offchain label metadata
    or preservation mirrors that cannot change artwork bytes.

Finality requirements:

1. The action verifies that every participating module reports the required
   frozen state before finality is recorded.
2. The action emits one Core-originated or Core-linked finality event.
3. A read function returns the finality record hash, manifest content hash, and
   whether all component modules still match it.
4. Incident recovery cannot silently swap final artwork. It must publish a new
   recovery manifest and preserve the original finality manifest.
5. Frozen renderers may be deprecated for new collections, but they must keep
   serving historical frozen collections or a hash-bound snapshot route.
6. No finality at any scope, in any metadata mode — including `OFFCHAIN` —
   may execute unless a token content root covering every token in the
   finality scope has been recorded and its root and leaf count verify at
   execution
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-CONTENT-ROOT]; ADR 0010 decision D4.1). Onchain and hybrid
   collections additionally cannot be finalized unless a snapshot manifest
   hash covering assembled script bytes, dependency payloads, renderer
   context, metadata root, media hashes, and entropy policy has already
   been recorded in the collection metadata contract. Finality is
   forbidden while any render-critical payload resolves through mutable
   transport without a content-hash commitment; a frozen `baseURI` proves
   which URI was promised, never which artwork. Content-root leaf
   semantics for tokens whose entropy was never finalized are pinned at
   [CMC-CONTENT-ROOT] (ADR 0012 decision T3); the finality scope binds
   those pinned semantics, never an implementation guess.
7. Collection-level artwork finality that binds `mintedSupply`,
   `burnedSupply`, and `nextCollectionSerial` requires Core collection
   status `CLOSED` plus the one-way Core burn block, verified through
   `collectionBurnsBlocked(collectionId) == true` — equivalently, the
   activation-height read `collectionBurnsBlockedAtBlock(collectionId)`
   returning nonzero, golden-tested equivalent at the home (ADR 0013
   decision U4) — in the same staged
   action that records finality. `CLOSED` alone only ends minting and can
   never guarantee an immutable `burnedSupply`; the burn block is the
   Core-verifiable no-burn invariant, and its surface
   (`blockCollectionBurns`, `collectionBurnsBlocked`,
   `collectionBurnsBlockedAtBlock`,
   `CollectionBurnsBlocked`) is owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-BURN] (ADR 0010 decision D10.5). Burns between `CLOSED` and the
   burn block are allowed: Core supply facts are read at finality
   execution time, after the burn block, so late burns are bound into the
   facts hash, never raced. A collection that needs post-finality burns
   must never set the burn block and must use scoped token, release,
   season, or view finality; scoped Core facts intentionally do not bind
   collection-wide burned supply.
8. Ongoing open series use token-level, release-level, season-level, or
   view-level snapshot/finality records rather than collection-level finality
   for the still-open parent collection.
9. For any collection with a bound artist, finality requires the verified
   `ARTIST_SANCTION` component; for artist-less collections it requires
   the immutable `PLATFORM_WORKS_DECLARATION` component. The finality
   registry must compute the sanction subject hash from the Core facts,
   the non-sanction component list, and the manifest reference, must call
   `verifySanctionForSubject` on the artist registry, and must revert on
   mismatch ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
   [AA-SANCTION]; ADR 0010 decision D2.3). There is no unsigned
   finalization path for artist-bound collections; absence of sanction is
   always provable intent through the platform-works declaration, never
   silence.
10. Artist-bound collections additionally require an `ARTIST_INTENT`
    record or its explicit recorded artist-signed waiver before finality
    ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
    [AA-INTENT];
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
    [CMC-ARTIST-INTENT]; ADR 0010 decision D6.4).
11. Dual-family archival proof (ADR 0010 decision D4.6). For every
    hash-committed offchain render-critical payload in the finality scope
    — media masters, photography masters, large dependency payloads,
    IIIF manifests, oversized signature bundles — at least two onchain
    archive receipts on independent storage families, each with a passing
    fixity record, must be recorded before finality executes. The receipt
    and fixity record shapes are owned by
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
    (Preservation Receipts, [CMC-FIXITY-PROGRAM]); this requirement makes
    them a finality precondition, gated by the conformance matrix and
    checked by finality preview tooling. At least one receipt per payload
    must carry a cryptographically verifiable evidence class, and the
    finality preview/ceremony must independently retrieve and hash-verify
    every receipt named by the finality manifest, recorded as a fixity
    record by a verifier distinct from the receipt writer ([LTA-ARCHIVE]
    requirement 2; ADR 0011 decision R4). Hash commitments without
    enforced replicas verify in 2075 and recover nothing.
12. Script-based works (`ONCHAIN` and hybrid) require the
    `REFERENCE_RENDER` component before finality: hash-committed reference
    output captures for a pinned token sample or all tokens, the
    execution-environment manifest, the archived execution-environment
    artifact, and a pinned re-render acceptance mode, so a future
    re-render is both producible and verifiable against recorded ground
    truth (ADR 0010 decision D4.2; ADR 0011 decision R3;
    [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
    [MRR-FINALITY];
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
    [CMC-FINALITY-INPUTS]).

    For a sold collection these artifacts are sale-follows records,
    never ceremony creations (ADR 0014 decision V1): every `ONCHAIN`
    and hybrid collection's reference-render capture set and archived
    execution-environment artifact are due within the pinned window
    of first sale settlement on the sale-follows lane of the fixity
    program — the sold-token coverage lane of [CMC-FIXITY-PROGRAM] in
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md),
    with the record schemas of [CMC-FINALITY-INPUTS] rule 5 and the
    deadline parameters owned alongside the offchain coverage
    deadlines at [MRR-OFFCHAIN-BINDING] in
    [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
    — and the deadline is monitored like every coverage deadline.
    Finality verifies the already-recorded component; it never first
    creates it, so a collection that sells out and never finalizes
    still has its rendering-environment layer captured while the
    contemporary runtime still exists to archive.

    Captures are typed by media class (ADR 0013 decision U8). Every
    reference capture pins one capture class from the closed vocabulary
    owned by the `REFERENCE_RENDER` record schema at
    [CMC-FINALITY-INPUTS] — `STILL`, `FRAME_SEQUENCE`, `AV_CONTAINER`,
    or `SCRIPTED_SESSION` — and non-still classes pin their capture
    parameters in the record: duration and frame timing for
    `FRAME_SEQUENCE` and `AV_CONTAINER`, plus the hash-committed input
    script and its replay protocol for `SCRIPTED_SESSION`. A time-based
    (animated or audio-bearing) work must pin `FRAME_SEQUENCE` or
    `AV_CONTAINER`; an interactive work must pin `SCRIPTED_SESSION`; a
    still capture never satisfies the reference-render slot for a
    time-based or interactive work — otherwise motion, sound, and
    interaction can diverge invisibly behind drills that compare stills
    and report `MATCH`. The pinned token sample follows the
    minimum-coverage rule owned by [CMC-FINALITY-INPUTS], and the
    execution-environment manifest carries the class-appropriate
    capture-environment fields (viewport, DPR, and color space for
    stills; timing, audio, and input-delivery facts for the other
    classes) per the same home.

    The execution environment is an artifact, never only a citation: the
    browser/engine build and capture toolchain named by the manifest
    must be archived as a runnable container image or equivalent
    environment archive, recorded as an `EXECUTION_ENVIRONMENT`
    preservation object with fixity coverage and mirrored under the
    dual-family archival rule [LTA-ARCHIVE] before finality. Version
    strings without preserved binaries are how software-dependent art
    becomes unrenderable — in 2060 a browser version string is a
    citation, not an environment — and both the re-render verification
    and any future emulation strategy contemplated by the
    `ARTIST_INTENT` record depend on the preserved substrate. Naming an
    environment without archiving the artifact is nonconformant.
    Archived is not the same as lawfully redeployable, so environment
    composition follows the open-source-preferred rule (ADR 0014
    decision V8): environment archives should be assembled from
    open-source browsers, engines, codecs, and capture toolchains
    whose licenses permit preservation, redistribution, and future
    execution, and each proprietary component requires either a
    preservation-license note recording the license basis under which
    the archived binaries may be preserved, redeployed, and shared,
    or a documented open-source substitution. The license-basis field
    and its vocabulary belong to the `EXECUTION_ENVIRONMENT`
    preservation-object schema owned by [CMC-FINALITY-INPUTS]
    rule 5(c), and an undetermined license basis is warned at
    finality — a museum receiving a dossier bag must know whether it
    may lawfully run what it holds.

    Every `REFERENCE_RENDER` pins exactly one acceptance mode for its
    scope, matching variable-media conservation practice:

    - `BYTE_EXACT`: a re-render must reproduce the capture byte-hashes
      exactly. Permitted only when the archived capture toolchain pins
      deterministic software rasterization (GPU-independent, pinned
      engine build) in the execution-environment manifest; raster
      output of GPU-dependent browser rendering must not be promised
      byte-stable across decades of hardware.
    - `PERCEPTUAL_TOLERANCE`: comparison uses a perceptual or
      structural-difference metric registered in the schema registry
      with tool and version references, and a pinned per-work threshold
      recorded in the `REFERENCE_RENDER` record. The protocol default
      metric is SSIM with a per-work pinned threshold; a work may pin
      a different registered metric entry (an LPIPS-class entry, for
      example), never an unregistered name — an unregistered metric is
      unreproducible in 2075 and makes drill outcomes non-comparable
      across the corpus ([CMC-FINALITY-INPUTS] rule 5(d), the
      registered-metric parameter home; ADR 0013 decision U8).
    - `CURATED_EQUIVALENCE`: acceptance is a conservator attestation
      against the significant properties of the `ARTIST_INTENT` record,
      recorded as an attestation under the pinned attestor class and
      examiner-evidence requirements of [CMC-FINALITY-INPUTS] rule 5(d)
      in
      [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
      (ADR 0012 decision T8).

    A renderer that declares the `DYNAMIC` class (declared, per-version
    frozen external reads;
    [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
    [MRR-DETERMINISM]) must not pin `BYTE_EXACT`. The acceptance mode,
    metric, threshold, and environment-artifact references are fields of
    the `REFERENCE_RENDER` record schema owned by [CMC-FINALITY-INPUTS];
    preservation drills compare re-renders under the pinned mode
    ([LTA-RECON] requirement 4).
13. A renderer version may participate in finality only if it passed the
    renderer determinism static-analysis gate and its golden input/output
    vectors are pinned in the release manifest
    ([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
    [MRR-DETERMINISM]; ADR 0010 decision D4.3).
14. The canonical bytes of the finality manifest (and of every snapshot
    manifest it binds) must be stored onchain in contract storage or an
    SSTORE2 blob — a state-trie carrier, never only event data
    ([LTA-CATALOGS] rule 6; ADR 0011 decision R1) — at or before
    finality execution, with the pointer stored in the finality record
    (`manifestPointer`) and exposed through the state-readable payload
    discovery surface ([LTA-PAYLOAD-DISCOVERY]; ADR 0012 decision T3),
    and with the pointer evented for indexers (ADR 0010 decision
    D4.5). `manifest.uri` remains display and mirroring data; the
    onchain bytes are the recoverable truth, locatable from state
    reads alone.
15. Every executed finality (collection or scoped) must be followed by a
    state export that includes the new finality record and content root
    leaves (State Export And Archival Operations); the export-at-finality
    cadence is a conformance gate (ADR 0010 decision D4.4).

### Scoped Finality For Open Series

Open-ended collections are a first-class protocol v1 target. They need finality for
individual works, releases, seasons, exhibitions, and archival views without
pretending the parent collection has a final supply.

Canonical scoped-finality model:

```solidity
enum FinalityScopeType {
    COLLECTION,
    TOKEN,
    RELEASE,
    SEASON,
    VIEW
}

struct FinalityScope {
    FinalityScopeType scopeType;
    uint256 collectionId;
    uint256 tokenId;
    bytes32 scopeId;
}

struct ScopedFinalityRecord {
    bool finalized;
    FinalityScope scope;
    bytes32 finalityRecordHash;
    bytes32 manifestContentHash;
    bytes32 manifestURIHash;
    bytes32 componentsHash;
    string finalityManifestURI;
    address manifestPointer;
    uint64 finalizedAt;
}

function finalizeArtworkScope(
    FinalityScope calldata scope,
    FinalityComponentExpectation[] calldata components,
    bytes32 expectedFinalityRecordHash,
    FinalityManifestRef calldata manifest
) external;

function artworkScopeFinalityRecord(FinalityScope calldata scope)
    external
    view
    returns (ScopedFinalityRecord memory);

function verifyArtworkScopeFinality(FinalityScope calldata scope)
    external
    view
    returns (
        bool currentRouteMatches,
        bytes32 finalityRecordHash,
        bytes32 componentsHash
    );

function finalityComponentCountForScope(FinalityScope calldata scope)
    external
    view
    returns (uint256);

function finalityComponentsForScope(
    FinalityScope calldata scope,
    uint256 start,
    uint256 limit
) external view returns (FinalityComponentExpectation[] memory);

function verifyArtworkScopeFinalityRange(
    FinalityScope calldata scope,
    uint256 start,
    uint256 limit
) external view returns (
    bool rangeMatches,
    bytes32 finalityRecordHash,
    bytes32 expectedRangeHash,
    bytes32 observedRangeHash,
    uint256 nextStart
);

interface IStreamScopedFinalityComponent {
    function finalityStateForScope(FinalityScope calldata scope)
        external
        view
        returns (FinalityComponentState memory);
}

interface IStreamScopedFinalityDiscovery {
    function finalityComponentCountForScope(FinalityScope calldata scope)
        external
        view
        returns (uint256);

    function finalityComponentAtForScope(
        FinalityScope calldata scope,
        uint256 index
    ) external view returns (FinalityComponentExpectation memory);

    function finalityDiscoveryHashForScope(FinalityScope calldata scope)
        external
        view
        returns (bytes32);
}

interface IStreamScopedFrozenRouteRegistry {
    function frozenRouteForScope(bytes32 routeType, FinalityScope calldata scope)
        external
        view
        returns (
            bool pinned,
            address module,
            bytes32 routeHash,
            bytes32 finalityRecordHash
        );
}
```

Scope rules:

1. `COLLECTION` scope uses `collectionId` and requires `tokenId == 0` and
   `scopeId == bytes32(0)`.
2. `TOKEN` scope requires a minted or burned token whose retained Core identity
   maps to `collectionId`; `scopeId` is zero unless a future token-view schema
   explicitly defines it.
3. `RELEASE`, `SEASON`, and `VIEW` scopes require a nonzero `scopeId` whose
   schema and canonical manifest are published by collection metadata.
4. A scoped finality record binds the same component identity fields as
   collection finality, but component `dataHash` may be scoped to the token,
   release, season, or view.
5. Frozen-route compatibility keys include
   `(scopeType, collectionId, tokenId, scopeId, finalityRecordHash)`, not only
   `collectionId`.
6. A global router, renderer, collection metadata, or entropy pointer
   replacement is deployment-conformant only if it can serve every pinned scoped
   route or a delayed recovery manifest supersedes the affected scope.
7. Scoped finality recovery uses the same status machine as collection finality
   but its `recoveryId` preimage includes the full `FinalityScope`.
8. Collection-level finality may coexist with older token, release, season, or
   view records, but it cannot reinterpret them. Later broader finality records
   must reference prior scoped record hashes in their manifest when they depend
   on them.

Scoped finality hashes include the full scope:

```solidity
bytes32 scopedFinalityRecordHash = keccak256(abi.encode(
    STREAM_SCOPED_FINALITY_V1,
    block.chainid,
    address(core),
    uint8(scope.scopeType),
    scope.collectionId,
    scope.tokenId,
    scope.scopeId,
    scopedCoreFactsHash,
    componentsHash,
    manifest.uriHash,
    manifest.contentHash,
    manifest.schemaId,
    manifest.canonicalizationHash
));
```

Scoped Core facts:

```solidity
struct ScopedCoreFinalityFacts {
    bool scopeExists;
    uint8 scopeType;
    uint256 collectionId;
    uint256 tokenId;
    bytes32 scopeId;
    bool tokenMappingExists;
    uint256 collectionSerial;
    uint8 tokenLifecycle;
    bool burned;
    uint8 collectionStatus;
    uint8 collectionSupplyMode;
    bytes32 collectionConfigHash;
    bytes32 scopeManifestHash;
}

function scopedCoreFinalityFacts(FinalityScope calldata scope)
    external
    view
    returns (ScopedCoreFinalityFacts memory);

bytes32 scopedCoreFactsHash = keccak256(abi.encode(
    STREAM_SCOPED_CORE_FINALITY_FACTS_V1,
    block.chainid,
    address(core),
    uint8(scope.scopeType),
    scope.collectionId,
    scope.tokenId,
    scope.scopeId,
    facts.scopeExists,
    facts.tokenMappingExists,
    facts.collectionSerial,
    facts.tokenLifecycle,
    facts.burned,
    facts.collectionStatus,
    facts.collectionSupplyMode,
    facts.collectionConfigHash,
    facts.scopeManifestHash
));
```

For `TOKEN`, `scopeExists` requires `tokenCollectionIdentity(tokenId)` to map
to `collectionId`, and `scopeManifestHash` is zero unless token metadata names
a token-finality manifest. For `RELEASE`, `SEASON`, and `VIEW`, `scopeExists`
requires collection metadata to publish the `scopeId` and its manifest hash.
Scoped finality for an open parent collection does not bind `mintedSupply`,
`burnedSupply`, or `nextCollectionSerial`; it binds only the scoped facts above
and the component list for that scope.

Scoped recovery mirrors collection recovery:

```solidity
struct ScopedFinalityRecoveryRecord {
    FinalityRecoveryStatus status;
    FinalityScope scope;
    bytes32 oldFinalityRecordHash;
    RecoveryManifestRef recoveryManifest;
    bytes32 recoveryRouteHash;
    uint64 executeAfter;
    bool artworkBytesChanged;
    bytes32 reasonHash;
    string reasonURI;
}

function scheduleScopedFinalityRecovery(
    FinalityScope calldata scope,
    bytes32 recoveryId,
    bytes32 expectedOldFinalityRecordHash,
    RecoveryManifestRef calldata recoveryManifest,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function cancelScopedFinalityRecovery(
    FinalityScope calldata scope,
    bytes32 recoveryId,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function executeScopedFinalityRecovery(
    FinalityScope calldata scope,
    bytes32 recoveryId
) external;

function scopedFinalityRecoveryRecord(
    FinalityScope calldata scope,
    bytes32 recoveryId
) external view returns (ScopedFinalityRecoveryRecord memory);
```

`recoveryId` is `keccak256(abi.encode(STREAM_SCOPED_FINALITY_RECOVERY_V1,
block.chainid, address(finalityRegistry), uint8(scope.scopeType),
scope.collectionId, scope.tokenId, scope.scopeId,
expectedOldFinalityRecordHash, recoveryManifest.contentHash, recoveryRouteHash,
executeAfter, artworkBytesChanged, reasonHash))`.

Recommended scoped event:

```solidity
event ArtworkScopeFinalized(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed finalityRecordHash,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 componentsHash,
    bytes32 manifestContentHash,
    string finalityManifestURI
);

event ScopedFinalityRecoveryScheduled(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 oldFinalityRecordHash,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);

event ScopedFinalityRecoveryCancelled(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 reasonHash,
    string reasonURI
);

event ScopedFinalityRecoveryExecuted(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);
```

Recommended event:

```solidity
event CollectionArtworkFinalized(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed finalityRecordHash,
    address indexed actor,
    bytes32 componentsHash,
    bytes32 manifestContentHash,
    string finalityManifestURI
);
```

Required reads:

```solidity
function collectionFinalityRecord(uint256 collectionId)
    external
    view
    returns (CollectionFinalityRecord memory);

function finalityComponentCount(uint256 collectionId)
    external
    view
    returns (uint256);

function finalityComponents(uint256 collectionId, uint256 start, uint256 limit)
    external
    view
    returns (FinalityComponentExpectation[] memory);

function finalityStillMatches(uint256 collectionId)
    external
    view
    returns (bool);

function verifyFinality(uint256 collectionId)
    external
    view
    returns (
        bool currentRouteMatches,
        bytes32 finalityRecordHash,
        bytes32 componentsHash
    );

function verifyFinalityRange(
    uint256 collectionId,
    uint256 start,
    uint256 limit
)
    external
    view
    returns (
        bool rangeMatches,
        bytes32 finalityRecordHash,
        bytes32 expectedRangeHash,
        bytes32 observedRangeHash,
        uint256 nextStart
    );
```

`verifyFinality` and `finalityStillMatches` are non-reverting diagnostic reads
for already-recorded finality. They must use bounded `staticcall` to every
component, with a bounded returndata copy for the fixed return struct.
`FINALITY_COMPONENT_READ_GAS` is a Governed Gas Parameter hosted by the
finality registry ([LTA-GGP]): its genesis value is measured at deployment,
its immutable floor is at least twice the deepest measured all-cold
component read, and future repricing is remediated by raising the value —
archival verification never becomes permanently impractical behind a fixed
cap. Its failure-direction class is `FORWARDING_CAP` (it bounds gas
forwarded to fail-safe diagnostic reads; raising restores the
diagnostic), so it carries the conditional-raise and
conditional-re-lower registrations
([LTA-GGP] requirement 11). Its probe definition: the probe executes
`verifyFinalityRange` at the candidate value against a
release-manifest-pinned reference set of finalized collections
(including the deepest-component collection at pinning time), with
`evidenceHash` committing to the pinned collection set, range bounds,
and per-component gas measurements; the probe records a failing run
only when a pinned component read that received the probed value ran
out of that budget ([LTA-GGP-PROBES]). If any component read reverts,
runs out of its gas cap, returns malformed data, has no code, or no longer
matches the expected code hash, the read returns `currentRouteMatches = false`
or `false` and still returns the stored finality hash. It must not revert merely
because a historical component became unhealthy.
The release manifest must publish both per-component and total worst-case
diagnostic gas for `MAX_FINALITY_COMPONENTS`. If the full `verifyFinality`
read becomes impractical under future gas schedules, the first remediation
is raising the `FINALITY_COMPONENT_READ_GAS` GGP; `verifyFinalityRange`
remains the archival verification primitive. Archival tools can also
always bypass the capped diagnostic entirely: `finalityComponents` returns
the stored expectations, and a tool may read each component directly with
caller-chosen gas and compare — the diagnostic is a convenience, never the
only verification path. Implementations should expose a
documented diagnostic status such as `VERIFY_RANGE_REQUIRED` before attempting
component reads when the published full-read budget is not satisfiable, instead
of allowing callers to hit an unexplained out-of-gas condition.
The genesis planning value is `FINALITY_COMPONENT_READ_GAS = 30_000` and a
full diagnostic budget under 1,200,000 gas for 32 components; deployment
uses measured values plus margin, recorded with the floor in the release
manifest per [LTA-GGP]. Operator tooling should prefer
`verifyFinalityRange` for routine archival checks once a collection has more
than eight components.

Finality recording is stricter: `finalizeCollectionArtwork` reverts if any
required component read fails, returns malformed data, reports `frozen = false`,
or differs from the submitted expectation. `previewFinality(collectionId,
components)` or equivalent tooling must expose the same comparisons before a
state-changing finality transaction is sent, and operator runbooks must
require a successful preview artifact hash before execution.
`previewFinality` must also expose the computed sanction subject hash —
the domain-separated `SANCTION_SUBJECT_DOMAIN` preimage over the Core
facts, the non-sanction component hash (`ARTIST_SANCTION` entries
excluded), and the manifest reference, exactly as pinned at its home —
so the artist signs exactly what will execute
([`docs/stream-artist-authority.md`](stream-artist-authority.md)
[AA-SANCTION] requirement 2; ordered preimage inputs at [AA-DOMAINS]);
any drift between signing and finalization changes the subject hash and
invalidates the sanction.

### Finality Recovery

Artwork-finality recovery is a governed state machine:

```solidity
enum FinalityRecoveryStatus {
    NONE,
    SCHEDULED,
    CANCELLED,
    EXECUTED
}

struct FinalityRecoveryRecord {
    FinalityRecoveryStatus status;
    bytes32 oldFinalityRecordHash;
    RecoveryManifestRef recoveryManifest;
    bytes32 recoveryRouteHash;
    uint64 executeAfter;
    bool artworkBytesChanged;
    bytes32 reasonHash;
    string reasonURI;
}

event FinalityRecoveryScheduled(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 oldFinalityRecordHash,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);

event FinalityRecoveryCancelled(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 reasonHash,
    string reasonURI
);

event FinalityRecoveryExecuted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);

function scheduleFinalityRecovery(
    uint256 collectionId,
    bytes32 recoveryId,
    bytes32 expectedOldFinalityRecordHash,
    RecoveryManifestRef calldata recoveryManifest,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function cancelFinalityRecovery(
    uint256 collectionId,
    bytes32 recoveryId,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function executeFinalityRecovery(
    uint256 collectionId,
    bytes32 recoveryId
) external;

function finalityRecoveryRecord(
    uint256 collectionId,
    bytes32 recoveryId
) external view returns (FinalityRecoveryRecord memory);

function activeFinalityRecoveryRoute(uint256 collectionId)
    external
    view
    returns (bytes32 recoveryRouteHash, bytes32 recoveryId);
```

Rules:

1. Recovery cannot erase the original finality record.
2. Recovery is delayed governance and uses the finality/preservation role, not
   ordinary metadata admin.
3. Recovery manifests name the failed component, old component address/codehash,
   new component address/codehash or snapshot route, old and new manifest
   hashes, reason URI/hash, whether artwork bytes changed, and — for
   artist-bound collections when artwork bytes changed — the artist-side
   approval reference or the recorded artist-unavailability finding of
   rule 9.
4. If artwork bytes change, the recovery is artwork-affecting and must be
   displayed as such forever.
5. `verifyFinality` returns both original finality and current-route status so
   archives can distinguish "historically final" from "currently served through
   a recovery route."
6. A global pointer move, including emergency entropy-coordinator replacement,
   makes finalized collections whose manifests pinned the old pointer report
   `currentRouteMatches = false` until a recovery manifest supersedes that
   route.
7. `recoveryId` is `keccak256(abi.encode(STREAM_FINALITY_RECOVERY_V1,
   block.chainid, address(finalityRegistry), collectionId,
   expectedOldFinalityRecordHash, recoveryManifest.contentHash, recoveryRouteHash,
   executeAfter, artworkBytesChanged, reasonHash))`.
8. `executeFinalityRecovery` rechecks status `SCHEDULED`, delay, old finality
   record hash, recovery manifest hash, and the rule 9 artist-side
   precondition where it applies, before marking the recovery
   `EXECUTED`.
9. Artwork-bytes-affecting recovery is artist-gated wherever an artist
   is bound (ADR 0011 decision R7.3). For a collection or scope whose
   finality carried the `ARTIST_SANCTION` component, executing a
   recovery with `artworkBytesChanged = true` requires a verified
   artist-class approval — artist, estate/successor, or steward
   authority per
   [`docs/stream-artist-authority.md`](stream-artist-authority.md)
   [AA-SANCTION] — carried as a signed `StreamArtistRecoveryApproval`
   binding the exact old finality record hash and recovery manifest
   content hash of this recovery record, and verified at execution
   through the artist registry's `verifyRecoveryApproval` surface
   ([AA-RECOVERY]; the typed payload and its record domain are owned
   there).
   Where no live artist authority exists, the substitute is a recorded
   artist-unavailability finding plus arbiter approval under a long
   delay: `executeAfter` at least the [GOV-WINDOWS] terminal-freeze veto
   floor, with the terminal-freeze veto guardian able to veto. The
   approval reference or unavailability finding is bound into the
   recovery manifest and displayed with the recovery forever. The
   sanction ceremony made "the artist approved these exact bytes" the
   product; no platform-only path may decide what replaces a sanctioned
   work's serving route.
10. Owner notice and objection standing (ADR 0014 decision V8). In
    variable-media practice the owning institution is a party to
    migration decisions about works it holds, so post-finality
    recovery carries an owner-facing surface without granting any
    veto over artist moral-rights decisions. Scheduling a recovery
    with `artworkBytesChanged = true` obligates notice to the owner
    of record of each affected token and to any registered
    owner-records steward — for `TOKEN` scope always; for wider
    scopes up to the per-recovery notification bound recorded in the
    hash-committed operations runbook, with public notice beyond it —
    and the recovery manifest records the owner-notification evidence
    before execution. The span from `SCHEDULED` to `executeAfter` is
    the pinned objection window: owners and stewards may record a
    typed acknowledgment or objection through the owner-records lane
    (the record family is owned by [CMC-OWNER-RECORDS] in
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)),
    the recovery record references the recorded objections, and
    objections feed the rule 2 role's cancellation authority and the
    guardian-veto path of rule 9 — they inform a veto, they are never
    one, and the artist-side gates of rule 9 are unchanged.
    Notification evidence and recorded objections are displayed with
    the recovery forever, active and executed recoveries surface in
    the acquisition-packet and condition-report fields owned by
    [CMC-ACQUISITION-PACKET], and owner-notification routing joins
    the monitoring list (State Export And Archival Operations).

## Governance Staging [LTA-GOV]

"Use timelock" is not enough. Staged governance actions share one
implementable model, and this document does not restate it: the canonical
action ID and preimage (`STREAM_GOVERNANCE_ACTION_V1`), the atomic batch
execution rules, and the window floors and unpause classification are
defined once in
[`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
[GOV-ACTION-ID], [GOV-BATCH], and [GOV-WINDOWS] (ADR 0010 decisions D3.4,
D7.1, D7.2). Subsystem specs fold domain-specific fields into
`scopeHash`/`newValueHash` of that one preimage; defining a second
staged-operation preimage anywhere is nonconformant. The launch
enforcement model for action classes — which delay tiers the bytecode
enforces and which class labels are catalog vocabulary — is likewise
owned definitively by ADR 0004; class assignments in this document cite
that model (ADR 0012 decision T9).

Rules:

1. Default-scope economics, resolver replacement, metadata router replacement,
   renderer registry changes, entropy provider registry changes, global
   freezes, and artwork finality freezes require staged operations.
2. Staging and execution emit separate events.
3. Cancellation is evented and must be possible before execution.
4. Irreversible freezes — `PERMANENT_FROZEN`, permanent global freezes, and
   artwork finality — must carry both a delay and an independent
   veto/guardian authority through the ADR 0004 `TERMINAL_FREEZE` class
   and its `terminalFreezeVetoGuardian`/`vetoTerminalFreeze` surface, so
   one compromised key plus one timelock window can never instantly and
   permanently freeze artwork or economics (ADR 0010 decision D8.9). The
   matrix governance gates verify the veto path, not only the runbook.
5. Every atomicity obligation stated as "in the same governed execution"
   anywhere in the spec set — pointer plus cached manifest fields,
   finality plus collection-scoped pointer freeze, phase policy plus
   ledger registration — must be satisfied either by one externally
   callable entrypoint on one target or by one atomic [GOV-BATCH] batch;
   partial application must never be observable (ADR 0010 decision D7.1).
6. Windows must be sized for the actual holder. The obligated-role set
   is expressly non-exhaustive: it covers every role any spec obligates
   to act inside a window — the staged-action canceller, terminal-freeze
   vetoer, pause guardian, unpause admin, and emergency admin, and
   equally every subsystem obligation window, such as the entropy reveal
   SLO (`requestSLOBlocks`, [EC-REVEAL] in
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md))
   and arbiter/contest response windows (ADR 0012 decision T5). For each
   such role the deployment manifest must record the holder's worst-case
   execution latency (multisig coordination, governor
   proposal-to-execution time), and the configured window must be at
   least that latency plus margin, never below the [GOV-WINDOWS] floors
   (ADR 0010 decision D7.2). A veto window a governor cannot physically
   meet — or a declared SLO its holder structurally cannot meet — is a
   dead control and fails the governance gate.
7. Governor-held defensive roles must satisfy the guardian-module
   pattern specified below ([LTA-GUARDIAN]; ADR 0012 decision T5): the
   governor pre-authorizes a narrow, bounded, auto-expiring executor for
   pause/veto/cancel/incident-revoke so defense does not require a full
   proposal cycle.
   Emergency moves to registry-pre-approved fallback targets must be
   permissionlessly executable once the triggering incident condition is
   onchain-observable (for example a target marked `INCIDENT_REVOKED`).
8. Emergency operations must be narrower than normal governance. They can
   pause, deprecate, incident-revoke, or move to a pre-approved safe
   fallback, but they cannot sweep owed funds or change final
   artwork/economics without the normal recovery process. Unpause is its
   own no-timelock operational class held by a dedicated role, distinct
   from pause guardians ([GOV-WINDOWS]).
9. The role-admin hierarchy and delay values are deployment parameters and
   must be recorded in deployment manifests, together with the governance
   action policy catalog required by ADR 0004. Every executor named in
   that catalog or in an action manifest is a [GOV-ROLES] role reference
   resolved through the admin registry at execution time, never a raw
   address, per the ADR 0004 execution rules (ADR 0012 decision T5): a
   raw executor address is a frozen key that strands the scheduled
   action when its holder rotates between staging and execution.
10. Scheduled-action calldata preimages are onchain bytes (ADR 0013
    decision U5). The canonical governance action stores each scheduled
    action's full per-call calldata bytes in an SSTORE2 blob whose
    pointer lives in the action record for the open-to-execute window,
    per the ADR 0004 execution rules ([GOV-ACTION-ID] home; cited, not
    restated here). Executing a staged action therefore never depends
    on offchain preimage retention: a multisig that loses its
    transaction-builder artifacts to staff turnover or tooling change
    re-derives the exact bytes whose hash the action stores from state,
    instead of rescheduling an incident-critical action through another
    full delay. The stored bytes are onchain-bytes payloads under
    [LTA-CATALOGS] rule 6, discoverable through the action record's
    typed pointer ([LTA-PAYLOAD-DISCOVERY] rule 1).

### Guardian Module Pattern [LTA-GUARDIAN]

A standard governor's proposal-to-execution latency is days; pause,
veto, cancellation, and incident revocation have no configurable window
to widen — their window is the attack's duration. Where a governor (or
any holder whose recorded latency exceeds the emergency assumption)
holds a defensive role, the deployment must register a guardian module
so the defense is exercisable inside the emergency window
(ADR 0012 decision T5). This subsection is the pattern's normative
home.

```solidity
interface IStreamGovernanceGuardian {
    function guardianAuthorization(bytes32 authorizationId)
        external
        view
        returns (
            address agent,
            uint8 capabilityMask,
            bytes32 scopeHash,
            uint64 notAfter,
            uint64 usesRemaining,
            bool revoked
        );

    function executeGuardedAction(
        bytes32 authorizationId,
        uint8 capability,
        address target,
        bytes calldata callData
    ) external;

    function revokeGuardianAuthorization(
        bytes32 authorizationId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external;
}

event GuardianAuthorized(
    uint16 schemaVersion,
    bytes32 indexed authorizationId,
    address indexed agent,
    uint8 capabilityMask,
    bytes32 scopeHash,
    uint64 notAfter,
    uint64 maxUses
);

event GuardianActionExecuted(
    uint16 schemaVersion,
    bytes32 indexed authorizationId,
    address indexed agent,
    address indexed target,
    uint8 capability,
    bytes32 callDataHash
);

event GuardianRevoked(
    uint16 schemaVersion,
    bytes32 indexed authorizationId,
    bytes32 reasonHash,
    string reasonURI
);
```

Guardian rules:

1. The guardian module is a Replaceable module behind this frozen
   interface, registered under module type `STREAM_GOVERNANCE_GUARDIAN`
   through the module registry ([LTA-REGISTRY]). The admin registry
   grants the defensive roles to the module; the governor is the
   module's only authorizer and revoker.
2. The capability set is closed and tightening-only: `PAUSE` (bit 0),
   `VETO_TERMINAL_FREEZE` (bit 1), `CANCEL_STAGED_ACTION` (bit 2), and
   `INCIDENT_REVOKE` (bit 3), encoded in `capabilityMask`; the bit
   assignments are Permanent and mirrored in the Numeric ID Catalog. A
   guardian authorization can never unpause, loosen, move a pointer,
   grant a role, or touch funds — the [LTA-GOV] rule 8 narrowness
   applies by construction, and unpause remains its own role
   ([GOV-WINDOWS]).
3. Every authorization is bounded: a mandatory expiry `notAfter`, an
   optional bounded use count `maxUses` (zero means unlimited until
   expiry), and a `scopeHash` binding the exact target set. The agent
   can never extend, widen, or renew its own authorization; renewal is
   a fresh governor action. `executeGuardedAction` reverts when the
   authorization is expired, revoked, exhausted, out of scope, or
   carries a capability bit the mask does not grant.
4. `scopeHash` and `authorizationId` are domain-separated:

   ```solidity
   bytes32 scopeHash = keccak256(abi.encode(
       STREAM_GUARDIAN_SCOPE_V1,
       block.chainid,
       address(guardianModule),
       targets            // address[], ascending, no duplicates
   ));

   bytes32 authorizationId = keccak256(abi.encode(
       STREAM_GUARDIAN_AUTHORIZATION_V1,
       block.chainid,
       address(guardianModule),
       agent,
       capabilityMask,
       scopeHash,
       notAfter,
       maxUses,
       grantNonce         // governor-chosen, unique per grant
   ));
   ```

5. Every grant, use, and revocation is evented (`GuardianAuthorized`,
   `GuardianActionExecuted`, `GuardianRevoked`); `callDataHash` is
   `keccak256` of the executed calldata so incident forensics replay
   exactly what the agent did.
6. Gating: the governance gate must verify that every governor-held
   defensive role either (a) has a registered guardian module with a
   live authorization covering that capability, exercised in rehearsal,
   with its rule 7 renewal declaration recorded and its agents
   satisfying the rule 8 discipline, or (b) is held by a
   holder whose recorded worst-case latency meets
   the emergency assumption under [LTA-GOV] rule 6 (Release Gates,
   governance gate 11). Guardian authorizations expire; after expiry
   with governance gone, defensive controls halt — consistent with
   read-only museum mode, which needs no defensive mutations.
7. Renewal obligations and staleness monitoring (ADR 0013 decision
   U5). Authorizations expire by design, so keeping a defensive role
   exercisable is a monitored recurring obligation, never operator
   memory. For every guardian authorization backing a governor-held
   defensive role, the governance manifest records the renewal owner,
   the renewal cadence, and a staleness alarm threshold at no more
   than 80% of the authorization lifetime (grant to `notAfter`);
   monitoring alerts at the threshold, and guardian-authorization age
   joins the conformance matrix's monitored recurring-obligation
   regime alongside fixity cycles and export cadence. An authorization
   that expires while its defensive role is still governor-held is a
   declared monitored incident: the role has silently reverted to
   proposal-cycle latency — the exact dead control [LTA-GOV] rule 6
   fails at the deployment gate, now occurring where only monitoring
   can catch it. Authorizations covering capabilities that back
   emergency windows (`PAUSE`, `VETO_TERMINAL_FREEZE`) must renew
   before expiry, with an overlap of at least the governor's recorded
   worst-case execution latency, so no gap coincides with an incident.
   With governance gone, renewal is impossible and rule 6's expiry
   posture applies unchanged.
8. Agent holder-class, redundancy, and sunset discipline (ADR 0014
   decision V4). The module's capabilities are exercised by its
   agents, so agent identity mirrors the material-action holder
   classes ([GOV-MATERIAL] in
   [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)):
   every authorized agent must itself be a Safe-class multisig, a
   governor contract, or an equivalent contract executor, or the
   module must hold at least two live authorizations covering the
   capability to independently controlled agents with no
   single-signer EOA among them. A single-signer EOA agent is
   permitted only under the same documented
   bootstrap-exception-with-recorded-sunset rule as the ADR 0004 Role
   Model's hot-wallet pause guardian — never as a standing posture —
   and re-authorizing an agent past its recorded sunset without a
   fresh recorded exception is nonconformant. The [GOV-WINDOWS]
   rule 2 two-independent-holders requirement is judged at the agent
   layer: nominal holders whose only emergency-window fast paths
   converge on one agent key are one holder. The rule 6 gate and the
   rule 7 staleness monitoring verify agent class, redundancy, and
   sunset alongside authorization liveness, and an authorization
   whose agent set falls out of conformance while its defensive role
   is governor-held is a declared monitored incident under the rule 7
   regime.

## Deployment Chain Posture [LTA-CHAIN]

The normative chain posture is owned by the protocol v1 specification
([PV1-SCOPE] in
[`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md);
ADR 0012 decision T9), and this umbrella consumes it rather than
restating it: this Core line deploys on Ethereum mainnet — L1,
`block.chainid == 1` — and on no other chain. The architecture-level
consequences are owned here:

1. Every permanence figure in this document — gas ceilings,
   storage-growth economics, history-expiry posture, museum-mode read
   survival — is an Ethereum L1 figure; evidence captured on any other
   network is rehearsal input, never a product fact.
2. An L2, sidechain, or alternate-L1 deployment of this system is a
   declared successor-line decision through the successor machinery of
   [LTA-MANIFEST], never a redeployment of this line. The protocol
   recognizes no bridged or wrapped representation of these tokens as
   canonical: ownership truth is this chain's Core, and fork
   canonicality follows [LTA-HASH] (chain ID is replay protection,
   not fork choice).

## System Manifest And Successor Declaration [LTA-MANIFEST]

A future indexer, museum, or marketplace needs one deterministic way to discover
the active Stream system.

Required aggregate read:

```solidity
function streamSystemManifest()
    external
    view
    returns (
        bytes32 manifestHash,
        string memory manifestURI,
        address revenueResolver,
        address metadataRouter,
        address collectionMetadata,
        address entropyCoordinator,
        address mintManager,
        address mintLedger,
        address artistRegistry,
        address streamAdminsOrGovernance,
        address artworkFinalityRegistry,
        address moduleRegistry,
        address stateExportPublisher,
        bytes32 eventCatalogHash,
        bytes32 compatibilityMatrixHash,
        bytes32 numericIdCatalogHash,
        bytes32 schemaCatalogHash,
        bytes32 canonicalizationCatalogHash,
        bytes32 specBundleHash,
        bytes32 reconstructionClientHash
    );
```

The `streamSystemManifest()` read is hosted on Core and is a required Core
surface from genesis, not an optional convenience (ADR 0010 decision
D10.6). It is classified `permanent` in the Core bytecode planning budget:
it is never a size-pressure relocation candidate, the conformance-matrix
drop-order list must not contain it, and the Core Minimalism rule applies —
under bytecode pressure, other logic moves out until this read fits with
headroom. The release manifest records its selector,
interface ID if one is assigned, return shape, and gas measurement. The
manifest should include module addresses, versions, code hashes, registry
states, pointer freeze states, event catalog hash, compatibility matrix hash,
numeric ID catalog hash, schema catalog hash, canonicalization catalog hash,
spec bundle hash, reconstruction client hash, and deployment chain IDs.
`streamSystemManifest()` is a storage-only read. Core stores the manifest hash,
manifest URI, current Core pointer addresses, the state/export publisher
address, cached catalog hashes, and cached discovery hashes needed for the
return tuple. It must not call satellites,
registries, or offchain resolvers. Pointer updates and catalog updates that
change any returned field must update the cached system manifest fields in the
same governed execution and emit the corresponding pointer/catalog event. If a
catalog publisher needs richer data, it lives in the content-addressed manifest
named by `manifestURI` and committed by `manifestHash`, not in an external call
from Core.

The system-manifest payload — the canonical deployment-inventory
document committed by `manifestHash` — is itself an onchain-bytes
payload of the [LTA-CATALOGS] rule 2 class (ADR 0013 decision U2): its
canonical bytes are stored in contract storage or an SSTORE2 blob at
every publication, and Core exposes the storage-backed pointer reads

```solidity
function streamSystemManifestPointer()
    external
    view
    returns (address payloadPointer);

function streamSystemManifestPointerCount() external view returns (uint256);

function streamSystemManifestPointerAt(uint256 index)
    external
    view
    returns (
        address payloadPointer,
        bytes32 manifestHash,
        uint64 updatedAt
    );
```

sharing `streamSystemManifest()`'s Permanent classification in the Core
bytecode planning budget. The pointer history is append-only, matching
the successor-declaration history shape, so superseded manifest
payloads stay locatable from state ([LTA-PAYLOAD-DISCOVERY] rule 2);
`streamSystemManifestPointer()` returns the current entry, and the
current `manifestHash` commits to exactly its stored
bytes. The payload must name every genesis-profile contract — Core,
satellites, probe contracts, pre-approved fallback targets, sale
adapters, settlement contracts, the ticket gate, the claim router, the
schema registry, the record satellites, and every registry instance —
with module types, code hashes, probe and fallback bindings, and the
security-contact field ([LTA-DISCLOSURE]), so state-only discovery of
the deployment inventory bottoms out in state reads, never in a
mirrored document ([LTA-PAYLOAD-DISCOVERY] rule 3): the tuple above
carries the core pointers, the module registry enumerates every module
ever registered ([LTA-REGISTRY] requirement 6), and this payload names
everything else. Every governed update that changes `manifestHash`
stores the new payload bytes and appends the new pointer entry in the
same governed execution as the cached-field update above; entries are
never edited or deleted. `manifestURI`
remains display and mirroring data, and the conformance matrix's
genesis deployment profile remains the human-readable mirror of this
payload, never the discovery bootstrap.

Core should also support a non-mutating successor declaration for long-term
identity continuity:

```solidity
event StreamCoreSuccessorDeclared(
    address indexed successorCore,
    bytes32 indexed successorManifestHash,
    string successorManifestURI
);

event StreamCoreSuccessorRepudiated(
    address indexed successorCore,
    bytes32 indexed successorManifestHash,
    bytes32 indexed reasonHash,
    string reasonURI
);

function declareStreamCoreSuccessor(
    address successorCore,
    bytes32 successorManifestHash,
    string calldata successorManifestURI
) external;

function streamCoreSuccessorCount() external view returns (uint256);

function streamCoreSuccessorAt(uint256 index)
    external
    view
    returns (
        address successorCore,
        bytes32 successorManifestHash,
        string memory successorManifestURI,
        uint64 declaredAt
    );

function coreLifecycleStatus()
    external
    view
    returns (
        uint8 status,
        bytes32 latestSuccessorManifestHash
    );
```

A successor declaration does not migrate tokens, transfer ownership, or change
the old Core. It is a public breadcrumb for future chain migrations, L2
successors, archival mirrors, or a post-EIP standards replacement.
Outstanding old-Core signed mint tickets, sale authorizations, nullifiers, and
future-dated permissions are not honored by a successor Core. A successor
deployment starts with its own authorization/nullifier ledger and must require
fresh signatures or an explicit successor authorization scheme.
A successor Core also deploys or points to its own revenue resolver line. The
old resolver is bound to the old Core and must not be reused as if assignments
automatically apply to the successor.

Access control for `declareStreamCoreSuccessor` must use the ADR 0004
`SUCCESSOR_DECLARATION` governance class with the published delay, staged
operation ID, cancellation path, and reason URI/hash. It is not an emergency
bypass and cannot be executed by a narrow funds, metadata, entropy, or renderer
admin. The function may append to a successor history and expose the latest
declaration for convenience, but it must not mutate ERC-721 ownership, token
collection mappings, satellite pointers, royalty behavior, metadata behavior,
or freeze state.
When `coreLifecycleStatus().status != ACTIVE`, `streamSystemManifest()` must
continue returning the old Core's module set and catalog hashes. It must not be
repurposed to advertise successor module addresses. Successor discovery is
through the successor declaration history and successor manifest, with
`coreLifecycleStatus()` as the old Core's lifecycle read.

Emergency incident communication, public state export, monitoring alerts, and
publication of candidate successor artifacts for a critical Core bug are not
gated by the 30-day `SUCCESSOR_DECLARATION` delay. The delay gates only the
onchain canonical successor pointer/declaration execution.

The successor manifest must include old chain ID, old Core, new chain ID, new
Core, ownership snapshot hash, complete event-history snapshot hash (the
[LTA-EVENT-HISTORY] serialization), collection-snapshot root, activation
statement, and explicit old-Core status:
`ACTIVE`, `DEPRECATED_QUERYABLE`, or `DEPRECATED_ZERO_ROYALTIES`. Indexers must
not infer deprecation from the existence of a successor event alone; they should
read `coreLifecycleStatus()` or the successor manifest status that the read
hashes.

Successor declarations never re-identify works. The canonical scholarly
citation of any work — the CAIP-19-shaped `chainId:core:tokenId` form and
its `@recordState` qualifier — is owned by
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-CITATION] (ADR 0010 decision D6.6); the original triple remains the
permanent citation forever, successor manifests must carry the
cross-reference back to it, and the spec bundle republishes the citation
profile for offline use.

## Resolver Safety Invariants [LTA-RESOLVER]

Core read paths that call satellites must be bounded and boring. In particular,
the royalty resolver's `royaltyReceiverAndBps` path must be storage reads and
arithmetic only. It must not make external calls, deploy wallets, read ERC-20
balances, call receiver hooks, or depend on mutable marketplace context.
Every gas bound on these read paths is a Governed Gas Parameter
([LTA-GGP]); the royalty-read instantiation is owned by
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
[RSR-2981-GAS] and the router-read instantiation by
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
[MRR-ROUTER-GGP].

Deployment validation must include malicious resolvers that consume all gas,
return malformed data, return excess data, attempt external calls, or recurse
through another view. Core must return `(address(0), 0)` without reverting
under every resolver failure mode, and the production resolver implementation
must be audited against the no-external-call invariant.

`royaltyInfo()` and `tokenURI()` bounded reads are independent marketplace
entrypoints with independent top-level gas budgets. Production code must not add a
combined marketplace read that invokes both the royalty resolver and metadata
router within one shared `staticcall` frame or derives one gas cap from the
other.

## State Export And Archival Operations [LTA-EXPORT]

A 50-year system needs verifiable state export, not only live RPC reads.
The state export is the designated bridge across EIP-4444-style history
expiry and the input to successor declarations, so it must attest the
artwork and metadata knowledge layer with the same rigor as the economic
layer (ADR 0010 decision D4.4). Deployment and successor manifests define
the `StateExport` profile:

```text
STATE_EXPORT_V1
chainId
core address
block number/hash
token ownership root
token-to-collection root, including burned tokens with retained mappings
token data root                renderer-input tokenData byte-hashes;
                               burned tokens included
collection serial root
collection facts root
entropy seed/status root
revenue assignment root
split profile root
sale credit root              sale-adapter pull credits: outbid refunds,
                              clearing rebates, drift-envelope refunds,
                              maximum-price excess
finality record root
collection record-chain root   metadata, attestation, preservation,
                               owner-record, and artist-registry lanes
artwork manifest root          script/dependency/media manifests, token
                               content roots, snapshots, reference renders
lock root                      one-way metadata lock states
event history snapshot hash    [LTA-EVENT-HISTORY] serialization
export manifest URI/hash
```

The export may be produced offchain by indexers, but the format must be
canonical and independently reproducible from chain data. Successor
declarations should reference the latest state export hash. Every export —
not only successor manifests — must reference a content-addressed mirror
of every finalized assembled artwork snapshot for chains hosting onchain
art.

Export cadence requirements:

1. A genesis state export must be produced and published before public
   sale; the conformance-matrix Operations gate verifies it.
2. A state export must be produced after every executed finality
   (collection or scoped), including the new finality record, content
   root, and record-chain leaves (finality requirement 15).
3. Ongoing exports follow a published cadence recorded in the
   hash-committed operations runbook; the cadence, the responsible agent,
   and the alerting rule for a missed export are deployment-gated
   operational manifest content, not informal practice (ADR 0010 decision
   D4.4). The responsible agent holds `ROLE_EXPORT_PUBLISHER` — an
   operational role of the [GOV-ROLES] vocabulary in
   [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md),
   resolved through the admin registry, never a raw stored address
   (ADR 0013 decision U5) — and the operational manifest names the
   role, not a wallet.
4. Completeness of any replica is provable: every record lane carries the
   O(1) rolling `recordChainHash` accumulator owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-RECORD-CHAIN], exports carry per-lane `(chainHash, recordCount)`
   leaves, and a recovered event set is complete exactly when replay
   reproduces the stored accumulator. Latest-hash reads alone cannot prove
   a recovered history is complete; the accumulator closes that gap even
   under full log expiry with operators gone.
5. Every published export is itself a preservation-critical payload
   (ADR 0012 decision T3): the export artifact, its event-history
   chunks, and its manifest must be archived under the dual-family
   archival rule [LTA-ARCHIVE] — two independent storage families, at
   least one `ENDOWED`, with onchain archive receipts and fixity-program
   coverage — before the export satisfies any cadence obligation, and a
   published export lacking its receipts is a monitored incident. The
   export bridge across history expiry is worthless if the bridge itself
   decays with its operator.
6. Export on material change (ADR 0013 decision U2). Event-history
   chunks are the only carrier of event payload content after history
   expiry, so between-cadence mutations in the assignment and pointer
   families must not wait for the next scheduled export: executing a
   Core satellite pointer stage/execute/freeze, a module-registry
   registration or status change, a default- or collection-scope
   revenue or royalty assignment or freeze mutation, a catalog
   replacement, or a finality recovery triggers a supplemental export —
   at minimum the event-history chunks plus the record-chain, registry,
   and assignment leaves covering the change — within the bounded
   publication window recorded in the hash-committed operations
   runbook. A missed material-change export is a monitored incident
   under the same alerting rule as a missed cadence export
   (requirement 3), so an operator collapse between snapshots can
   strand at most one bounded window of the covered families —
   record-chain, registry, assignment, and pointer history — not an
   unquantified tail. The bound is scoped to those families and says
   so: Transfer, sale, and refund event payloads in the same terminal
   window carry no rolling accumulator and no material-change
   trigger, so once history expires, that window's transfer and sale
   provenance is a real loss that state cannot even prove; the
   museum-mode posture states the exposure honestly rather than
   extending the claim past its mechanism.

Discoverable export publication surface:

```solidity
event StateExportPublished(
    uint16 schemaVersion,
    uint256 indexed blockNumber,
    bytes32 indexed exportHash,
    bytes32 indexed manifestHash,
    bytes32 blockHash,
    string manifestURI
);

function latestStateExport()
    external
    view
    returns (
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 exportHash,
        bytes32 manifestHash,
        string memory manifestURI
    );
```

The event may be emitted by governance, a dedicated archive publisher, or a
successor/export satellite named in `streamSystemManifest()`. It does not make
an offchain export magically correct; it makes the claimed export discoverable,
hash-bound, and challengeable.
Export roots are computed at a named confirmation depth. If an export's block
range includes a later-reorged entropy fulfillment, escrow event, governance
action, or other state-changing event, the old export must be superseded
through `StateExportSuperseded`; it must not be silently corrected in place.

Challenge and supersession surface:

```solidity
event StateExportChallenged(
    uint16 schemaVersion,
    bytes32 indexed exportHash,
    bytes32 indexed challengeHash,
    address indexed challenger,
    string challengeURI
);

event StateExportSuperseded(
    uint16 schemaVersion,
    bytes32 indexed oldExportHash,
    bytes32 indexed newExportHash,
    bytes32 indexed reasonHash,
    string reasonURI
);
```

The same pattern should be available for recovery manifests and archive/fixity
receipts when a previously published artifact is found incomplete, corrupted,
or non-canonical. Supersession does not erase the old artifact; it creates a
public lineage.
If the state/export publisher becomes obsolete or unavailable, the cached
`stateExportPublisher` in `streamSystemManifest()` remains historical discovery
data. While governance works, replacement uses delayed pointer/catalog
governance. If governance is lost, independent archives can still publish
unofficial exports and challenges offchain, but old Core cannot bless a new
publisher; consumers should mark those exports as independently reproduced, not
Core-published.
Successor manifests must name the proof posture for the state export: Merkle
inclusion proofs over the exported roots, a future ZK proof if one is adopted,
or explicit social/governance attestation when cryptographic continuity is not
available. The chosen proof posture is part of the successor manifest hash.
If a declared successor manifest is later found compromised, governance may
publish `StreamCoreSuccessorRepudiated` under the same
`SUCCESSOR_DECLARATION` delay class. Repudiation does not erase the old
declaration; it adds a visible warning and replacement lineage.
Burned tokens are excluded from ownership roots after burn but included in
token-to-collection and collection-serial roots when Core retains their mapping.
Roots should be Merkle roots over sorted `(key, valueHash)` leaves with the leaf
schema named in the export manifest. The reference exporter can be maintained
offchain, but no export is canonical unless an independent indexer can reproduce
the same roots from archived chain data and the published event catalog.

Minimum v1 leaf schemas:

```solidity
bytes32 tokenCollectionLeaf = keccak256(abi.encode(
    STREAM_EXPORT_TOKEN_COLLECTION_LEAF_V1,
    uint256(tokenId),
    bool(mappingExists),
    uint256(collectionId),
    uint256(collectionSerial),
    bool(burned)
));

bytes32 collectionSerialLeaf = keccak256(abi.encode(
    STREAM_EXPORT_COLLECTION_SERIAL_LEAF_V1,
    uint256(collectionId),
    uint256(collectionSerial),
    uint256(tokenId),
    bool(burned)
));

bytes32 tokenDataLeaf = keccak256(abi.encode(
    STREAM_EXPORT_TOKEN_DATA_LEAF_V1,
    uint256(tokenId),
    bytes32(tokenDataHash),
    bool(burned)
));

bytes32 entropyLeaf = keccak256(abi.encode(
    STREAM_EXPORT_ENTROPY_LEAF_V1,
    uint256(tokenId),
    uint8(status),
    bytes32(seed),
    address(coordinatorAtMint),
    address(provider),
    uint32(providerEpoch),
    bytes32 requestKey,
    uint16 requestAttempt
));

bytes32 finalityLeaf = keccak256(abi.encode(
    STREAM_EXPORT_FINALITY_LEAF_V1,
    uint8(scope.scopeType),
    uint256(scope.collectionId),
    uint256(scope.tokenId),
    bytes32(scope.scopeId),
    bytes32(finalityRecordHash),
    bytes32(componentsHash),
    bytes32(manifestContentHash),
    uint64(finalizedAt)
));

bytes32 splitProfileLeaf = keccak256(abi.encode(
    STREAM_EXPORT_SPLIT_PROFILE_LEAF_V1,
    bytes32(profileId),
    address(wallet),
    bytes32(entriesHash),
    uint16(walletVersion),
    bytes32(runtimeCodeHash)
));

bytes32 splitEntryLeaf = keccak256(abi.encode(
    STREAM_EXPORT_SPLIT_ENTRY_LEAF_V1,
    bytes32(profileId),
    uint16(index),
    address(account),
    bytes32(labelId),
    uint32(sharePpm)
));

bytes32 revenueAssignmentLeaf = keccak256(abi.encode(
    STREAM_EXPORT_REVENUE_ASSIGNMENT_LEAF_V1,
    bytes32(revenueClass),
    uint8(scope),
    uint256(scopeId),
    bytes32(profileOrTemplateId),
    address(wallet),
    uint16(royaltyBps),
    uint8(freezeMode),
    bool(permanentFreeze),
    bytes32(assignmentHash)
));

bytes32 escrowCreditLeaf = keccak256(abi.encode(
    STREAM_EXPORT_ESCROW_CREDIT_LEAF_V1,
    bytes32(revenueClass),
    bytes32(profileId),
    address(wallet),
    address(asset),
    uint256(owed),
    address(storedFactory),
    bytes32(escrowRuntimeCodeHash)
));

bytes32 saleCreditLeaf = keccak256(abi.encode(
    STREAM_EXPORT_SALE_CREDIT_LEAF_V1,
    address(adapter),
    bytes32(saleId),
    address(account),
    address(asset),
    uint256(owed)
));

bytes32 mintCounterLeaf = keccak256(abi.encode(
    STREAM_EXPORT_MINT_COUNTER_LEAF_V1,
    bytes32(valueKey),
    uint64(counterValue),
    bytes32(policyHash)
));

bytes32 authorizationLeaf = keccak256(abi.encode(
    STREAM_EXPORT_AUTHORIZATION_LEAF_V1,
    bytes32(authorizationOrNullifierId),
    bool(used),
    bytes32(policyHash)
));

bytes32 registryRecordLeaf = keccak256(abi.encode(
    STREAM_EXPORT_REGISTRY_RECORD_LEAF_V1,
    address(registry),
    address(module),
    uint8(status),
    bytes32(moduleType),
    bytes4(interfaceId),
    bytes32(runtimeCodeHash),
    bytes32(moduleManifestHash)
));

bytes32 catalogLeaf = keccak256(abi.encode(
    STREAM_EXPORT_CATALOG_LEAF_V1,
    bytes32(catalogType),
    bytes32(catalogHash),
    bytes32(schemaId),
    bytes32(canonicalizationHash)
));

bytes32 recoveryLeaf = keccak256(abi.encode(
    STREAM_EXPORT_RECOVERY_LEAF_V1,
    bytes32(recoveryType),
    bytes32(recoveryId),
    uint8(status),
    bytes32(oldRecordHash),
    bytes32(recoveryManifestContentHash),
    uint64(executeAfter)
));

bytes32 recordChainLeaf = keccak256(abi.encode(
    STREAM_EXPORT_RECORD_CHAIN_LEAF_V1,
    address(laneHost),
    uint256(scopeKey),
    bytes32(recordType),
    bytes32(chainHash),
    uint64(recordCount)
));

bytes32 artworkManifestLeaf = keccak256(abi.encode(
    STREAM_EXPORT_ARTWORK_MANIFEST_LEAF_V1,
    uint256(collectionId),
    bytes32(manifestType),
    bytes32(subjectId),
    bytes32(contentHash),
    bytes32(schemaId),
    uint64(itemCount)
));

bytes32 lockLeaf = keccak256(abi.encode(
    STREAM_EXPORT_LOCK_LEAF_V1,
    uint256(collectionId),
    bytes32(lockId),
    bool(locked)
));
```

Token-data leaves cover every token with authoritative retained
identity — minted, prepared-incomplete, and burned alike: burn clears
ownership, never renderer input, and Core retains the tokenData bytes
for burned tokens
([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-CORE-ABI];
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-BURN]). `tokenDataHash` is the Core-stored commitment
`keccak256(tokenData)` (`keccak256("")` when the stored bytes are
empty). The bytes themselves are a state-recovered surface: no event
carries them, and the export leaf carries only this commitment, never
the bytes — a leaf proves recovered bytes; it cannot supply them.
Event replay alone can therefore never reconstruct the artwork-input
layer: exports attest it from state, and the reconstruction client
and the protocol v1 reconstruction profile
([`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
[PV1-RECON]) recover the bytes from Core state reads — live state or
an archival state snapshot — verified against the export's
token-data leaves, never from log replay (ADR 0011 decision R12). An
export bundle may additionally package the attested tokenData bytes
as a payload section under the packaging profile ([CMC-PACKAGING] in
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md));
the leaves remain the verification surface either way.

Record-chain leaves cover every accumulator lane in the deployment:
collection metadata records, attestations, preservation records, fixity
cycles, owner records, artist-registry records, and the module-registry
registration lanes ([LTA-REGISTRY] requirement 7). `laneHost` is the
lane-hosting contract, `scopeKey` and `recordType` follow the accumulator
preimage of
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-RECORD-CHAIN], and `(chainHash, recordCount)` are the stored
accumulator values at the export block. Artwork manifest leaves cover the
per-collection knowledge layer: `manifestType` is a pinned `bytes32`
vocabulary of at least `SCRIPT_MANIFEST`, `DEPENDENCY_MANIFEST`,
`MEDIA_MANIFEST`, `CONTENT_ROOT`, `SNAPSHOT_MANIFEST`,
`REFERENCE_RENDER`, and `EXECUTION_ENVIRONMENT`; `subjectId` uses the
pinned subject derivations of [CMC-SUBJECT-ID] where the manifest is
narrower than the collection; `itemCount` carries the leaf count for
content roots and zero where inapplicable. Lock leaves export every
one-way lock state of the metadata lock model.

Leaves are sorted by `(tokenId)` for the token-to-collection root and by
`(collectionId, collectionSerial, tokenId)` for the collection-serial root.
Token-data leaves and entropy leaves are sorted by `(tokenId)`.
Finality leaves are sorted by
`(scopeType, collectionId, tokenId, scopeId, finalityRecordHash)`.
Record-chain leaves are sorted by `(laneHost, scopeKey, recordType)`;
artwork manifest leaves by `(collectionId, manifestType, subjectId,
contentHash)`; lock leaves by `(collectionId, lockId)`.
Sale-credit leaves cover every unclaimed sale-adapter pull credit —
outbid refunds, Dutch clearing rebates, drift-envelope refunds, and
maximum-price excess, which the sales layer makes claimable forever —
and are sorted by `(adapter, saleId, account, asset)`
(ADR 0012 decision T3); the credit surfaces are owned by
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).
Split-profile leaf completeness is checkable against state: the export
manifest records the split factory's `profileCount()` at the export
block, read from the factory's append-only onchain enumeration index
(Split Profile Model in
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)).
Registry-record leaf completeness is checkable the same way
(ADR 0013 decision U2): the export manifest records each
genesis-profile registry's `moduleCount()` at the export block, read
from the registry's append-only enumeration index ([LTA-REGISTRY]
requirement 6), and the registry-record leaf set must cover exactly
the enumerated modules, with the registration record-chain leaf's
`recordCount` equal to that count ([LTA-REGISTRY] requirement 7).
Each additional root defines a deterministic sort key in the export manifest;
the field lists above are minimum v1 leaves and may be extended only by a new
leaf version.

Export bundles and object-dossier bundles are packaged for repository
ingest under the pinned BagIt/OCFL packaging profile owned by
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-PACKAGING] (ADR 0012 decision T8); an export published outside the
pinned packaging profile does not satisfy the cadence obligation.

Event-history snapshot serialization [LTA-EVENT-HISTORY] (ADR 0011
decision R12):

Every export and successor manifest carries an event-history snapshot
hash, and post-expiry recovery leans on mirrored event-history
snapshots, so the serialization is pinned like every other export
surface: two honest archives of the same logs must produce the same
hash, or the one artifact that carries event payload content after
history expiry cannot be cross-verified.

1. Record set. The snapshot covers every log emitted within its block
   range by the addresses in the export manifest's address set: Core,
   every genesis-profile contract, every module ever registered in a
   genesis-profile registry, and every factory-deployed split wallet.
   The address-set derivation rule is recorded in the export manifest
   so an independent indexer reproduces the same set. The split-wallet
   members are derivable from state alone through the split factory's
   append-only onchain enumeration index —
   `profileCount()`/`profileAt(index)`/`walletAt(index)`, owned by
   [RSR-FACTORY-ENUM] in
   [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   — and the module members are derivable from state alone through
   each registry's append-only enumeration index —
   `moduleCount()`/`moduleAt(index)`, [LTA-REGISTRY] requirement 6
   (ADR 0013 decision U2) — so deriving the address set never depends
   on prior export artifacts or expired logs (ADR 0012 decision T3).
2. Record encoding. Each log is one RFC 8785 (JCS) canonical JSON
   object with exactly these members and no others: `address`,
   `blockHash`, `blockNumber`, `data`, `logIndex`, `topics`,
   `transactionHash`, `transactionIndex`. Byte-valued members are
   `0x`-prefixed lowercase hex of even length; quantity-valued members
   (`blockNumber`, `logIndex`, `transactionIndex`) are `0x`-prefixed
   lowercase hex quantities with no leading zeros, per Ethereum
   JSON-RPC conventions.
3. Ordering and framing. Records are serialized one per line — each
   record's JCS bytes followed by one LF (0x0A) — in ascending
   `(blockNumber, transactionIndex, logIndex)` order, chunked into
   contiguous, non-overlapping, ascending block ranges. Each chunk's
   `(startBlock, endBlock, recordCount, chunkHash)` — `chunkHash` is
   `keccak256` of the chunk's JSONL bytes — is listed in the export
   manifest.
4. Hash construction:

   ```solidity
   struct EventHistoryChunk {
       uint64 startBlock;
       uint64 endBlock;
       uint64 recordCount;
       bytes32 chunkHash;
   }

   bytes32 eventHistorySnapshotHash = keccak256(abi.encode(
       STREAM_EXPORT_EVENT_HISTORY_V1,
       uint256(chainId),
       address(core),
       uint64(startBlock),
       uint64(endBlock),
       uint64(recordCount),
       chunks
   ));
   ```

   `chunks` is the full `EventHistoryChunk[]` in ascending `startBlock`
   order. `STREAM_EXPORT_EVENT_HISTORY_V1` is pinned in [LTA-DOMAINS]
   and mirrored in the protocol v1 domain-constants table with the same
   CI recomputation test as every other export domain.
5. Records are taken at the export's named confirmation depth; a
   snapshot whose range is later reorged is superseded through
   `StateExportSuperseded`, never corrected in place. An export or
   successor manifest whose event-history snapshot hash is computed
   over any other serialization is nonconformant.

Dual-family archival rule [LTA-ARCHIVE] (ADR 0010 decision D4.6;
ADR 0011 decision R4; ADR 0014 decision V2):

1. Every render-critical or preservation-critical offchain payload must
   be mirrored across at least two independent storage families —
   family identity and independence pinned by the requirement 8
   taxonomy; for
   example IPFS plus Arweave, Filecoin, an institutional archive, or
   another content-addressed medium — with an onchain archive receipt
   and a passing fixity record per family. For payloads referenced by
   any finality scope, those receipts and fixity records must exist
   before finality executes (finality requirement 11); for other
   payloads they must exist before the payload is declared
   preservation-covered.
2. Receipts are evidence-classed, and operator assertion alone is
   nonconformant (ADR 0011 decision R4). Every archive receipt carries
   its evidence class, and at least one of the two receipts per payload
   must be cryptographically verifiable: a content-addressed inclusion
   proof binding the storage identifier to the committed bytes (an
   IPFS-family receipt digest must equal the content CID of the
   committed bytes; an Arweave-class receipt must carry the transaction
   identifier and data-root inclusion path), or an attested possession
   proof signed by the storing agent and audited by the fixity program.
   Family-appropriate identifier fields are schema-validated. Receipt
   and fixity record shapes, the evidence-class field, and the
   validation rules are owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   (Preservation Receipts, [CMC-FIXITY-PROGRAM]). Without this rule the
   strongest finality precondition in the architecture would reduce to
   trusting the operator the architecture elsewhere refuses to trust.
3. At least one of the two families for every render-critical payload
   must carry pay-once endowed permanence economics, and `ENDOWED`
   means cryptoeconomic (ADR 0013 decision U3): an `ENDOWED` family is
   an Arweave-class, content-addressed storage endowment — permanence
   purchased once and enforced by the storage network's own economics —
   whose archive receipt carries the `CONTENT_ADDRESSED_INCLUSION`
   evidence class of [CMC-RECEIPTS] in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   wherever the payload class supports one. An institutional perpetual
   commitment, however credible, is not `ENDOWED`: its persistence
   depends on the continued existence and funding of a mortal
   organization — the trust class this rule exists to exclude, since
   fifty years exceeds most corporate lifespans — so it is recorded as
   `RENEWAL_FUNDED` in the funding manifest and can fill the second
   family slot at most. Renewal-funded families can never fill both
   slots (ADR 0011 decision R4): unfunded renewal is the most common
   real-world NFT permanence failure, and two renewal-funded families
   decay together when their payer disappears.
   Each family's economics class — `ENDOWED` or `RENEWAL_FUNDED` — is
   recorded in the funding manifest ([LTA-FUNDING]) and gated at
   deployment.
4. The manifest records storage locations, fixity hashes, last check
   time, and the agent that performed the check.
5. Ongoing verification is the mandated fixity program — annual full
   sweep, quarterly sampling, repair-from-mirror, supersession lineage —
   whose normative home is
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-FIXITY-PROGRAM]; this document consumes its cycle records in
   monitoring and the Operations gate.
6. HTTPS-only render-critical payloads are allowed only when the
   collection intentionally accepts service-backed mutability, and such
   collections can never satisfy the finality preconditions above.
7. State exports, event-history snapshot chunks, deployment and release
   manifests, and the reconstruction-client source archive are
   preservation-critical payloads under rule 1 (ADR 0012 decision T3):
   each published artifact carries dual-family receipts (one `ENDOWED`)
   and fixity-program coverage per [LTA-EXPORT] cadence requirement 5,
   the Operations gate verifies the receipts, and the funding manifest
   records the export-storage families and their economics classes
   ([LTA-FUNDING]). Event-history chunks are the only artifact class
   carrying event payload content after history expiry — artist-registry
   record contents, sale history, and assignment mutations reconstruct
   from them — so their mirroring is mandated, never assumed.
8. Pinned storage-family taxonomy (ADR 0014 decision V2). Family
   independence is a pinned judgment, never an example-shaped one:
   the funding manifest ([LTA-FUNDING] rule 1) carries the
   deployment's storage-family taxonomy — an append-only table of
   named storage families, each row recording the family identifier
   (`keccak256` of the ASCII family name, the vocabulary that
   [CMC-RECEIPTS] `archiveType` values in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   resolve onto), the storage network or protocol with its retrieval
   path, the operating or custodial organization, the funding model
   (`ENDOWED` or `RENEWAL_FUNDED`, requirement 3), and the governing
   jurisdiction. Two families are independent only when they share
   none of: storage network or protocol (including
   content-addressing and DAG tooling lineage), operator or
   custodian, funding dependency, and single point of retrieval. Two
   pinning providers on one network are one family; two networks
   operated or funded by one organization are one family. Every
   archive receipt and every funding-manifest storage row must
   resolve to a registered family, a receipt pair whose families
   fail the independence rule never satisfies requirement 1, and
   rows are append-only — additions are ordinary manifest and spec
   amendments, and no addition reinterprets a recorded receipt.
9. Family lifecycle and extinction migration (ADR 0014 decision V2).
   The pay-once guarantee rides one storage network's cryptoeconomics
   per payload, and no network's economics is a 50-year certainty, so
   each registered family carries a health status — `ACTIVE`,
   `DEGRADED`, or `DEPRECATED` — reviewed against the monitored
   economic and network-viability indicators named per family in the
   funding manifest, on the same cadence as the repricing review.
   Marking a family `DEGRADED` or `DEPRECATED` triggers a governed
   migration obligation: elect a registered successor family
   satisfying the requirement 8 independence rule — for an `ENDOWED`
   family, an `ENDOWED` successor — re-upload every payload whose
   requirement 1 coverage depended on the failing family, recording
   fresh archive receipts, and re-baseline fixity for the migrated
   corpus under [CMC-FIXITY-PROGRAM], all within the pinned migration
   window recorded in the funding manifest. Migration and
   repair-from-mirror must restore the requirement 3 `ENDOWED`-count
   invariant, never merely any mirror. A missed migration window is a
   monitored incident under the same alerting regime as a missed
   fixity cycle, the funding manifest carries the migration reserve
   of [LTA-FUNDING] rule 6, and post-operator, family-status findings
   and migration evidence remain recordable through the
   permissionless independent lane ([CMC-INDEPENDENT-ATTESTOR]).

Every Ethereum hard fork, L2 migration, or material gas-schedule change must
trigger a protocol-parameter review — the repricing review checklist that
every Governed Gas Parameter belongs to ([LTA-GGP]). The review remeasures
Core bytecode,
resolver gas, `SLOAD`/`STATICCALL` assumptions, split-wallet release gas,
metadata rendering limits, and any SSTORE2 or chunk-read assumptions,
remeasures every GGP inventory row against its current value and floor,
and publishes a compatibility report hash with raise recommendations
before user impact. Periodic reviews should also sample
marketplace, wallet, indexer, archive-node, and metadata-cache behavior for
ERC-2981, ERC-4906, tokenURI fallback handling, contract metadata discovery,
and frozen/recovered collection display.
If average block time, timestamp behavior, finality assumptions, or block-count
semantics materially change — a slowdown or an acceleration alike
([LTA-GTP]; ADR 0014 decision V7) — the review must remeasure every
Governed
Time Parameter row against its pinned wall-clock intent ([LTA-GTP]) and
re-evaluate governance delay UX, stale request windows, and any
block-number-based archival/export policy.

Reconstruction client requirements [LTA-RECON] (ADR 0010 decision D4.8):

1. Stream must maintain a minimum archival reconstruction client outside
   the production frontend. From genesis it must replay the event catalog
   and reconstruct token identity and collection serials (from
   `TokenCollectionRegistered` and the mint/burn events), split profiles,
   escrow balances, entropy status/seeds, renderer-input tokenData (a
   state-recovered surface, never log-replayed), collection metadata
   snapshots, record-chain lanes, and finality records from archived
   chain data and content-addressed manifests, reproducing the
   state-export roots.
2. The client is conformance-gated, not aspirational: the matrix
   Operations gate must verify that the client exists at genesis, that its
   source-archive hash equals `streamSystemManifest()`'s
   `reconstructionClientHash`, that its replay test vectors pass in CI,
   and that its reproducible-build instructions have been executed and
   verified. A deployment cannot pass its gates while the client is
   missing — an ungated must here would be exactly the artwork-critical
   social promise this framework exists to eliminate.
3. Its source archive, reproducible build instructions, and test-vector
   outputs must be mirrored with the deployment manifest under the
   dual-family archival rule [LTA-ARCHIVE].
4. Operations must schedule periodic preservation drills — cadence
   recorded in the hash-committed operations runbook — that
   independently rebuild the export roots, re-render at least one
   finalized onchain/hybrid collection from archived payloads inside an
   environment reconstructed from its archived execution-environment
   artifact, and compare the re-renders against the `REFERENCE_RENDER`
   captures under each work's pinned acceptance mode and pinned capture
   class — frame sequences, AV containers, and scripted sessions are
   reproduced with their pinned durations, frame timing, and input
   scripts, never reduced to stills (finality
   requirement 12; ADR 0011 decision R3; ADR 0013 decision U8). Drill
   reports classify every
   compared work as `MATCH`, `TOLERABLE_VARIANCE` (within the pinned
   mode's metric and threshold; unreachable under `BYTE_EXACT`), or
   `DIVERGENT` — never a bare byte pass/fail, so a future conservator
   can distinguish acceptable rasterization variance from actual loss
   instead of learning to ignore drill failures. Each drill must also
   prove that at least one archived execution-environment artifact
   still boots and reproduces a reference capture, and must publish the
   drill report hash.
5. Those drills must also prove that the reconstruction client still
   builds from archived source, pinned dependencies, and archived build
   instructions on contemporary tooling or in a preserved build container.
   If it does not, the replacement client and migration notes become
   preservation artifacts with their own URI/hash.
6. Environment artifacts get the same remediation rule as the client
   (ADR 0012 decision T8): a failed execution-environment boot check
   (requirement 4) must produce, within the remediation window recorded
   in the operations runbook, either a migrated or re-hosted environment
   artifact — hashed, archived under [LTA-ARCHIVE], and recorded as a
   preservation `MIGRATION` event linking the failed and replacement
   artifacts under the PREMIS profile of
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-PREMIS-PROFILE] — or a recorded infeasibility finding with the
   conservation options considered; the remediation workflow itself is
   owned by [CMC-ENV-REMEDIATION] in the same document. The drill report must reference the
   remediation artifact or finding; a boot failure that produces neither
   is a monitored incident. Detection without a mandated re-hosting
   deliverable would convert drills into documentation of loss, and the
   re-render verification and every `ARTIST_INTENT` emulation preference
   depend on an obtainable runtime, not a once-archived one.

Unfunded storage is the most common real-world cause of NFT permanence
failure, so the funding posture is a checked deployment artifact, not a
runbook note. Funding requirements [LTA-FUNDING] (ADR 0010 decision D4.8):

1. Genesis requires a published funding/endowment manifest hashed into the
   release manifest: funding source and parties, coverage horizon or term,
   covered payload and service classes (keepers, entropy request payments,
   monitoring, storage pinning/mirroring, state-export and event-history
   mirroring ([LTA-ARCHIVE] requirement 7), domain/ENS renewal, fixity
   cycles, preservation drills, and vulnerability-disclosure intake and
   bounty administration ([LTA-DISCLOSURE])), the storage-family
   taxonomy rows with per-family health status and monitored
   viability indicators ([LTA-ARCHIVE] requirements 8–9; ADR 0014
   decision V2), the economics class of
   every storage
   family in use — `ENDOWED` (pay-once permanence) or `RENEWAL_FUNDED` —
   and exhaustion alarm thresholds with alert routing. The
   conformance-matrix Operations gate fails if the manifest is missing
   or stale, if any storage family lacks its economics class or its
   registered taxonomy row, or if any
   render-critical payload has no `ENDOWED` family ([LTA-ARCHIVE]
   requirements 3 and 8; ADR 0011 decision R4).
2. The manifest must document what degrades, in what order, if funding
   disappears — honest degradation is part of the permanence claim.
3. A protocol-owned archival endowment — for example a revenue-class
   split entry labeled as a preservation fund feeding pinning contracts —
   should be configured at genesis under a separately accepted module
   spec, and the funding manifest must state the endowment decision
   explicitly either way: the configured endowment reference, or the
   recorded rationale for launching on funded arrangements alone. The
   operator-endowment decision is independent of the storage-side rule:
   render-critical payloads require an `ENDOWED` storage family
   regardless ([LTA-ARCHIVE] requirement 3), so no deployment's entire
   offchain payload layer can depend on recurring payments by a mortal
   operating entity (ADR 0011 decision R4).
4. The manifest must include a costed operating model
   (ADR 0012 decision T9): for every recurring obligation the spec set
   creates — fixity sweeps and sampling, export cadence, preservation
   and museum-mode drills, ceremony rehearsals, repricing and
   consensus-timing reviews, marketplace royalty re-verification,
   funding-manifest renewal, disclosure intake and response — the
   estimated person-hours and third-party fees per year, the staffing
   or contracting assumption behind them, and the aggregate annual
   cost. The coverage horizon of rule 1 must be computed against this
   costed total, never asserted, so the exhaustion alarms guard a
   number that was actually computed. Unfunded recurring labor — not
   design — is the most common failure of preservation programs, and
   every missed obligation here is a publicly computable incident.
5. Viability floor, automation posture, and the consolidated
   obligation calendar (ADR 0013 decision U9). The costed operating
   model is gated against a minimum, not merely published: the
   Operations gate fails unless committed funding — endowment plus
   committed operating funds — covers the rule 4 computed aggregate
   annual cost for at least the pinned coverage-horizon floor
   (planning value ten years; the deployed floor and an explicit
   endowment-multiple target are pinned in the funding manifest). An
   under-resourced steward of this machinery bleeds publicly
   computable incidents for decades, so under-resourcing is a gate
   failure, never a launch posture. For every recurring obligation
   whose trigger and deliverable are mechanically computable — fixity
   sampling and sweeps, export cadence and material-change exports
   ([LTA-EXPORT] requirements 3 and 6), probe runs, staleness and
   exhaustion alarms — the operating model records an automation
   posture: automated through named Operational tooling (keeper
   contracts, scheduled jobs) or manual with a recorded rationale;
   automation-first is the default. The manifest, or one
   hash-committed artifact it references, must carry a consolidated
   obligation calendar aggregating every recurring obligation the spec
   set creates across all manifests — owner, cadence, alarm rule, and
   estimated annual cost per row — so the total annual operational
   load is one reviewable artifact rather than facts scattered across
   ten manifests. The calendar is release evidence verified by the
   Operations gate.
6. Family-extinction migration reserve (ADR 0014 decision V2). The
   manifest carries a migration reserve line: a costed provision,
   computed with the rule 4 operating model, covering at least one
   full re-mirroring of every render-critical and
   preservation-critical payload to a successor `ENDOWED` family at
   current storage pricing, re-costed at every funding-manifest
   renewal and at every repricing review that re-prices storage. The
   [LTA-ARCHIVE] requirement 9 migration obligation is executable
   only if it is funded in advance — a migration rule without a
   reserve is a plan to fail during the exact crisis it anticipates —
   so a manifest missing the reserve line, or whose reserve no longer
   covers the current corpus at current pricing, fails the Operations
   gate.

The steward coupling is stated honestly rather than implied: this
obligation load is the heaviest part of the design, and every
recurring obligation above — fixity cycles, exports, drills,
re-verifications, renewals — depends on a funded steward's continued
performance, with every miss a publicly computable monitored incident
by construction. That visibility is the mechanism, not a defect:
preservation programs decay silently exactly where misses are not
computable. What never depends on the steward is the permanence core —
ownership, identity, frozen-artwork and royalty reads, split release
and escrow flush, the permissionless conditional raises and re-lowers
([LTA-GGP] requirement 11), the independent preservation and fixity
lanes, and independent export reproduction all survive steward
collapse (read-only museum mode, below), and `ENDOWED` families hold
committed payloads without renewal payments ([LTA-ARCHIVE]
requirements 3 and 9). A faltering steward therefore visibly degrades
the freshness and repair latency of the archival program while the
recorded corpus and its verification surfaces stand.

The specs, ADRs, event catalogs, release manifests, and reconstruction-client
source archives are themselves preservation objects. Each deployment and material
upgrade should publish a content-addressed spec bundle hash in the deployment
manifest and mirror it across independent storage families. Governance runbooks
should also name legal-entity succession and dissolution risks; the contracts do
not solve legal continuity, but operators should document who can act if the
original operating entity ceases to exist.
Event-log and state availability are operational assumptions, not protocol
guarantees. If EIP-4444-style history expiry, log pruning, state expiry, or RPC
retention changes make ordinary `eth_getLogs`/archive reads incomplete, Stream
relies on content-addressed state exports, mirrored event-history snapshots
([LTA-EVENT-HISTORY]), archival reconstruction clients, and independent
archive nodes named in the operations runbook — with the onchain
record-chain accumulators keeping lane completeness provable from state
alone, so a degraded archive can be audited rather than trusted
([LTA-EXPORT] requirement 4).

For literally unbounded open series, live per-token mappings are permanent
state growth. Protocol v1 keeps explicit `tokenCollectionIdentity` storage
because that is the most robust marketplace and royalty surface. A future
state-expiry or storage-rent era may add a successor deployment line in which
cold token identity proofs are served from a canonical state-export root, but
that is a successor-line decision. Core must not silently replace live
token identity reads with offchain proofs. The same posture applies to durable
mint ledger counters, authorization/nullifier state, escrow owed balances,
split release state, finality records, recovery records, and registry/catalog
state: v1 keeps them live where the protocol requires live reads, and any
future proof-backed cold-storage model is a successor-line decision with state
export roots and explicit user-facing tradeoffs.

Monitoring operations should define alert routing and escalation for:

1. resolver fallback-to-zero;
2. metadata router failure;
3. entropy pending/stale requests;
4. escrow owed aging;
5. unsupported asset receipt;
6. finality mismatch;
7. governance action scheduled/executed/cancelled;
8. fixity cycle results — `FIXITY_CYCLE_COMPLETED` missing past its
   published cadence, and every `FIXITY_FAILURE` record, per the fixity
   program in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-FIXITY-PROGRAM];
9. Governed Gas Parameter margin breaches ([LTA-GGP] requirement 6);
10. missed state exports past the published cadence or past the
    export-on-material-change window ([LTA-EXPORT] requirements 3 and
    6), and published exports missing their [LTA-ARCHIVE] receipts
    ([LTA-EXPORT] requirement 5);
11. marketplace cache divergence;
12. guardian-authorization staleness alarms,
    expired-while-role-held incidents, and agent-class or
    agent-redundancy nonconformance ([LTA-GUARDIAN] rules 7–8);
13. storage-family viability indicators, family health-status
    changes, and missed family-migration windows ([LTA-ARCHIVE]
    requirement 9);
14. recovery-notice routing to token owners of record and registered
    owner-records stewards, and the objection-window records of
    Finality Recovery rule 10 ([LTA-FINALITY]).

If immutable Core is found to have a critical bug, the default incident posture
is communication, pause/tightening where available, state export, and successor
declaration. The old Core's ownership history is not rewritten. Any migration
or social-canonical successor must carry ownership and event-history snapshot
hashes plus a clear statement of old-Core status.

Zero-admin and lost-quorum drills must cover the complete satellite set, not
only Core. The runbook should periodically prove degraded-mode reads and
operations for metadata router failure, finality verification, pending entropy,
split-wallet release, escrow flush, state export publication, event-catalog
reconstruction, and the permissionless probe-gated conditional-raise
and conditional-re-lower paths for
`FORWARDING_CAP` Governed Gas Parameters, executed end to end against the
deployed Permanent-class probe contracts with zero governance signers,
resolving each parameter's probe binding, floor, failure class, and
recency bound through the host introspection reads alone
([LTA-GGP] requirements 11–12; [LTA-GGP-PROBES] rule 9). If a degraded-mode
item depends on immutable gas assumptions that can fail under a future
gas schedule, the drill report must say so rather than treating the
guarantee as absolute.

Read-only museum mode is the explicit posture when all governance is lost.
Ownership, transfer, approvals, supply and sequential-ID iteration reads
([LTA-ENUMERATION]), retained token identity,
frozen/finalized metadata reads, royalty disclosure as configured, split-wallet
release, already-deployed-wallet escrow flush, finality verification ranges,
state-export discovery, the GGP/GTP host introspection reads
([LTA-GGP] requirement 12), permissionless GGP probe runs with their
pre-approved conditional raises and re-lowers for `FORWARDING_CAP`
read-survival
parameters ([LTA-GGP] requirement 11) — so a later
gas repricing cannot permanently zero `tokenURI()`/`royaltyInfo()` for
frozen collections, and a repricing's later reversal cannot strand
fixed-stipend readers behind a raised threshold — the
permissionless independent preservation and
fixity lanes, which keep accepting institution-signed records with no
operator or governance
([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-INDEPENDENT-ATTESTOR]; ADR 0011 decision R11), and archived
reconstruction should continue where their immutable dependencies still
work. New mint programs, pointer
moves, economic changes, metadata mutations, provider recovery, registry
replacement, and economics/artwork-affecting recovery halt unless fully
precommitted before quorum loss.

Museum mode is honest about its one degraded archival surface: current
ownership always survives in state, but the transfer, sale, and refund
provenance of the final pre-collapse export window survives only where
a mirrored event-history snapshot or an independent archive covers it.
Record-chain, registry, assignment, and pointer lanes stay
accumulator-provable ([LTA-EXPORT] requirements 4 and 6);
terminal-window transfer and sale history is not, and no claim here
extends past that mechanism. Independent parties can reproduce exports
permissionlessly and record their mirrors through the independent
preservation lane
([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-INDEPENDENT-ATTESTOR]), so the post-operator bootstrap has a
discoverable export lineage rather than a rumor of one.

## Hash And Manifest Discipline [LTA-HASH]

Every durable identity must be domain-separated and versioned.

`block.chainid` provides replay protection only. It does not establish fork
canonicality, because a contentious fork can preserve the same chain ID.
Canonical deployment and successor resolution are governance- and
manifest-declared, then observed through contract events and state exports.

Use `abi.encode`, not packed encoding, for:

- split profile IDs;
- primary template IDs;
- materialized profile metadata hashes;
- sale context hashes;
- royalty resolver assignment hashes;
- renderer manifests;
- metadata snapshots;
- view manifests;
- entropy request keys;
- entropy raw randomness compression;
- final entropy seed derivation;
- collection freeze manifests;
- versioned event catalog manifests.

Every offchain or externally fetched artifact that matters to artwork or
economics should have:

1. URI;
2. hash;
3. hash algorithm or schema version;
4. content type where relevant;
5. event trail for assignment and freeze.

The release artifact set must include a machine-readable event catalog with its
own hash. The catalog should list every event, schema version, indexed fields,
unindexed fields, semantic owner, deprecation status, and replacement event
when applicable. Successor declarations and deployment manifests must reference
the event catalog hash so indexers can prove which log vocabulary a deployment
used.

Protocol identity hashes are intentionally `keccak256`-fixed for their version.
Do not "upgrade" an existing profile ID, request key, seed, or assignment hash
to a different hash algorithm. Content and preservation hashes may be
algorithm-tagged for long-term agility:

```text
hashAlgorithm = HASH_KECCAK256 | HASH_SHA256 | HASH_BLAKE3 | HASH_MULTIHASH
```

Protocol v1 does not include a generic `OTHER` hash bucket. New hash algorithms
must be assigned explicit IDs through the append-only hash/canonicalization
registry and documented in a release manifest or successor schema.

Every verification path bottoms out in the interpretation-critical
catalogs — without the numeric ID catalog an archivist cannot decode
stored enum values, without the event catalog logs are uninterpretable,
without canonicalization profiles no manifest hash is checkable. For tens
of kilobytes of one-time storage the protocol does not leave its own
Rosetta stone to social mirroring. Onchain catalog requirements
[LTA-CATALOGS] (ADR 0010 decision D4.5):

1. The hash, canonicalization, schema, and enum ID spaces are governed by
   the append-only registry satellite from genesis — explicit IDs,
   URI/hash, status, and supersession links; the satellite architecture is
   owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-SCHEMA-REGISTRY]. A manifest-pinned allocation file alone is not a
   conformant genesis posture.
2. The genesis catalog payloads — event catalog, numeric ID catalog,
   schema catalog, canonicalization catalog, the fallback-JSON schema,
   and the system-manifest payload ([LTA-MANIFEST]; ADR 0013 decision
   U2) — must be stored as onchain bytes (contract storage or SSTORE2
   blobs — state-trie carriers; rule 6) referenced from the registry
   and from `streamSystemManifest()` — the system-manifest payload
   through Core's `streamSystemManifestPointer()` read; hash-plus-URI
   alone is nonconformant for
   these catalogs. Catalog updates replace the referenced bytes through
   staged governance and never reinterpret old IDs.
3. The canonical bytes of every finality manifest and snapshot manifest
   are stored onchain at publication (finality requirement 14; snapshot
   rule in the collection metadata spec).
4. The spec bundle and other large preservation objects remain
   hash-committed and mirrored under the dual-family archival rule
   [LTA-ARCHIVE]; onchain bytes are mandated for the compact
   interpretation-critical catalogs above, not for bulk archives.
5. New IDs are additions; old IDs are never reinterpreted.
6. Onchain bytes means state-trie bytes (ADR 0011 decision R1).
   Everywhere this spec set requires payload bytes to live onchain — the
   catalogs and system-manifest payload above, the canonical bytes of
   finality and snapshot
   manifests (finality requirement 14), meaning-bearing record-family
   payloads, scheduled-action calldata payloads (the action-record
   pointer of the ADR 0004 execution rules; [LTA-GOV] rule 10;
   ADR 0013 decision U5), and onchain signature bundles
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-RECONSTRUCTION], [CMC-ATTESTATIONS]) — the conformant carriers
   are contract storage and SSTORE2: bytes recoverable from an immutable
   onchain read of state. Event-embedded payloads never satisfy an
   onchain-bytes requirement, because log availability is an operational
   assumption that EIP-4444-style history expiry can remove
   ([LTA-EXPORT]): a post-expiry node holding only state could prove
   such bytes missing — the record-chain accumulators still verify — yet
   recover nothing. Events remain indexer-convenience discovery
   pointers to the stored bytes; the normative discovery surface is the
   state-readable pointer index below ([LTA-PAYLOAD-DISCOVERY]), and
   the with-operators-gone recovery guarantee may cite only state-trie
   carriers.

State-readable payload discovery [LTA-PAYLOAD-DISCOVERY]
(ADR 0012 decision T3). Stored bytes that only an expired log can
locate are bytes a stranger cannot recover: the payload survives in the
state trie, but finding the SSTORE2 blob without the pointer event
means brute-force scanning every contract account. Discovery therefore
rides state, not logs:

1. Every contract that stores payload bytes onchain under rule 6 —
   SSTORE2 blobs or typed contract-storage payloads — must expose a
   storage-backed discovery surface on the same host: either the
   enumerable pointer registry (count plus paged pointer/family/hash
   rows) whose canonical read signatures are owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-PAYLOAD-POINTERS], or, where the host's records are already
   exhaustively keyed, a typed pointer field or accessor on the keyed
   record read (the finality registry's `manifestPointer`, the catalog
   registry's stored-bytes references under rules 1–2 above).
2. The discovery surface is append-only: supersession adds rows or
   records (lineage by content hash); pointers are never edited or
   deleted, matching the record-chain posture.
3. A state-only archivist must be able to locate every onchain payload
   byte of the deployment from `streamSystemManifest()`,
   `streamSystemManifestPointer()`, and storage-backed reads alone —
   no logs, no prior exports, no operator, and no offchain document
   (ADR 0013 decision U2). The genesis deployment profile remains the
   human-readable mirror of the onchain system-manifest payload
   ([LTA-MANIFEST]), never the discovery bootstrap. The conformance
   matrix gates this with a
   golden test that walks every onchain-bytes surface from state reads
   only.
4. Events keep firing for indexers; they are convenience, never the
   recovery path.

Manifest canonicalization:

1. Onchain identity manifests should prefer typed `abi.encode` structs.
2. Offchain JSON manifests that are hash-committed should use a documented
   canonical JSON profile such as RFC 8785/JCS, or another explicitly named
   canonicalization scheme.
3. Raw JSON fragments used in metadata must be either validated before storage
   or marked as admin-trusted with a stored hash and schema.
4. Omitted field, null field, empty string, and empty array/object semantics
   must be specified for every manifest family before the owning spec
   reaches Final.

Privacy and redaction are part of manifest design. Provenance records may
include sensitive camera, location, institution, estate, model-release, or
rights information. Schemas should distinguish public payloads, redacted
payloads, sealed archive commitments, and finalized artwork bytes. A hidden
private record must not be required to render or verify a public final artwork
unless the collection's manifest explicitly accepts that dependency.
Sealed or redacted archival material needs an offchain custody and succession
policy: who may access it, rotate keys, attest to fixity, release it to an
institution or estate, or declare it lost. Onchain records should commit to the
sealed payload and custody policy hash without exposing secret material.

Signature suites are also time-bounded evidence. EIP-712, ERC-1271, W3C
Verifiable Credentials, DIDs, C2PA signatures, institutional attestations, and
archive receipts should record signature suite, public-key material reference,
verification method, timestamp, and signed payload hash. Old signatures remain
historical evidence under the suite used when recorded; future post-quantum or
successor signature suites should be added as new attestations or verification
bundles rather than rewriting old signatures. Preservation drills should
periodically re-attest finality-critical records under the current best
signature suite before an older suite is considered practically broken.

## Compatibility Matrix

Every assignment that connects two modules must verify compatibility at
assignment time.

Examples:

1. A metadata router can assign a renderer only if the renderer supports the
   configured render context version.
2. A collection metadata record can select a renderer only if its declared
   schema/compatibility range includes that renderer family.
3. An entropy coordinator can be assigned only if the metadata router supports
   the entropy view interface it exposes.
4. A revenue resolver can assign a split wallet only if the factory, wallet
   version, profile schema, and runtime code hash are approved.
5. A Core pointer update can execute only if the target module supports the
   expected interface ID and module type.

Optional interface:

```solidity
function supportsStreamModule(
    bytes32 moduleType,
    bytes32 moduleVersion,
    bytes32 contextVersion
) external view returns (bool);
```

Each deployment manifest must include a full compatibility-matrix snapshot:
one canonical hash over every approved module family, version, interface ID,
runtime code hash, registry status, and approved pair or exclusion. Pairwise
checks are necessary but not enough; future auditors need a single "these
versions were jointly blessed" artifact.

Cross-contract authority interfaces whose selectors are part of a release
manifest should use selector-stable parameter lists: value types, addresses,
fixed bytes, `bytes`, and `bytes32` commitments where practical. If a struct is
used in an external interface, the release manifest must pin the full canonical
signature, selector, ABI encoding, compiler version, and test vector so a
future compiler or language change cannot silently alter the contract between
modules.

Every deployed satellite should publish reproducible-build preservation data:
compiler version, optimizer settings, metadata hash mode, source bundle hash,
ABI hash, deployed bytecode, constructor arguments, linked libraries, runtime
code hash, creation code hash, compiler binary or container/Nix lock URI/hash,
Sourcify/Etherscan or successor verification status, verifier output hash, and
mirrored source archive URI/hash.

## Deterministic Deployment [LTA-DEPLOY]

Split wallets already receive the exemplary treatment: CREATE2 through
the factory with init-code and runtime-code hashes bound into the
profile identity
([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
Split Profile Model).
The genesis contract set states its deployment-determinism posture
explicitly rather than leaving the property to ceremony-time
improvisation (ADR 0011 decision R10):

1. Every contract in the conformance-matrix genesis deployment profile
   must be deployed through the deterministic deployment factory named
   in the deployment manifest, using CREATE2 with a pinned salt. The
   factory address, per-contract salts, and init-code hashes are
   recorded in the release/deployment manifest, so every genesis
   address is reproducible from the manifest alone and the deployment
   ceremony is auditable byte-for-byte before it runs.
2. Later module registrations and successor-line deployments should use
   the same factory-and-pinned-salt pattern; a deployment that
   intentionally does not must record that decision and its rationale
   in the module's deployment manifest.
3. Determinism is auditability, not identity: every identity preimage
   in the spec set binds concrete deployed addresses and code hashes,
   so no consumer may treat address predictability as a substitute for
   reading the pinned identity surfaces.

## Maximum On-Chain Options

The architecture should leave room for every reasonable long-term on-chain or
verifiable mode without putting all of them in Core.

Allowed storage and resolution families:

```text
INLINE_CHUNKS       simple v1 path for scripts and small JSON fragments
SSTORE2             large write-once payloads
ETHFS               shared onchain web assets
DEPENDENCY_REGISTRY shared JavaScript/library dependencies
ERC-4804/6860       raw onchain web views if product requires them
IPFS                content-addressed offchain storage
ARWEAVE             durable offchain archive storage
HTTPS               mutable or service-backed URI, only with explicit trust
CCIP_READ           verified offchain or L2-backed reads
WEB3_CALL           future onchain composable views
```

Rules:

1. Core must not care which source family a payload uses.
2. Protocol v1 may use inline chunks for auditability.
3. Offchain sources that matter to final artwork should carry hash commitments.
4. Mutable HTTPS is acceptable only when the product intentionally wants a
   mutable or service-backed surface and the metadata says so.
5. Future storage families should be added as metadata/renderer modules, not
   as Core rewrites.

Open-ended collections create unbounded state by design. Core stores
token-to-collection mappings, collection serials, and entropy/request
facts for every token. Token-level royalty snapshots,
token-level metadata overrides, and token-level preservation records should be
opt-in because they add per-token storage for potentially decades. Release
manifests should publish expected per-token storage writes and gas for the
default path, snapshot path, and token-override path, and future statelessness,
Verkle, or chain-migration strategies must preserve the explicit mapping model
rather than relying on token ID arithmetic.

Frozen onchain collections must publish a snapshot manifest hash over the
assembled script, dependency, and media payloads. This protects preservation
even if future RPC providers or gas limits make live `tokenURI()` rendering
difficult.

## Economics Boundary

Primary sales, royalties, curator rewards, refunds, and protocol surplus are
separate accounting domains.

Rules:

1. Primary revenue settlement is authoritative at sale settlement time.
2. Royalty disclosure is best-effort ERC-2981 at marketplace read time.
3. Royalty payment remains voluntary unless a separate enforcement design is
   accepted.
4. Recipient payments are pull-based.
5. Passive receipts and forced ETH must not become emergency surplus.
6. Split profiles are immutable; assignments choose which profile applies.
7. Future wallet versions can support larger recipient sets, Merkle claims, or
   asset adapters, but each version needs a new identity preimage and tests.
8. Unsupported ERC-20 assets must not block native ETH or other assets.

Escrow boundary:

1. Funds held by a protocol escrow are owed by the escrow, not yet received by
   the split wallet.
2. Split wallet `observedReceived(asset)` excludes escrow-pending funds until
   those funds are actually deposited into the wallet.
3. Wallet-level conservation excludes `escrowOwed`.
4. System-level conservation is:

   ```text
   walletReleased + walletReleasable + walletDust + escrowOwed
     <= officialDeposits + passiveReceipts + directTransfers + forcedETH
   ```

5. Escrow flush moves value from `escrowOwed` into wallet-resident balance and
   must be idempotent.
6. Escrow incident recovery can reroute only escrow-held funds, not funds
   already resident in a split wallet.

Incident-revoked escrow recovery:

1. An incident-revoked wallet runtime code hash blocks new credits and normal
   flushes for affected escrow.
2. A timelocked successor-wallet reroute may move escrow credit to a new
   verified wallet only through a published recovery manifest.
3. The recovery manifest must identify affected credit keys, old wallet,
   successor wallet, old profile, successor profile, runtime hashes, reason,
   and whether economics are identical or intentionally changed by governance.
4. If economics change, the reason must be explicit and the delay should be
   longer than ordinary config updates.
5. The reroute transfers only owed escrow accounting and escrow-held funds. It
   cannot seize or move balances already held by the old split wallet.

## Entropy Boundary

Entropy is a provenance-critical subsystem, not a renderer helper.

Rules:

1. Core mints tokens and registers entropy state.
2. The entropy coordinator owns canonical request lifecycle.
3. Provider adapters provide raw entropy and source provenance only.
4. Final seed derivation is coordinator-owned, domain-separated, and versioned.
5. Each token can receive at most one successful entropy output.
6. Delivery retry uses already-received randomness.
7. Fresh entropy recovery is an incident path, not a normal retry.
8. Provider rotation uses epochs and cannot reinterpret pending requests.
9. Metadata exposes pending, finalized, stale, failed, and recovery states.
10. Future entropy systems are added as adapters after review, not by changing
    Core.
11. Entropy registration failure can never permanently brick minting: the
    registration gas bound is a raisable Governed Gas Parameter and the
    coordinator pointer is replaceable ([LTA-GGP] requirement 8;
    [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
    [EC-REGGAS]; ADR 0010 decision D1.5).

For v1 high-value collections, fresh entropy recovery after an accepted provider
request should be disabled unless a complete recovery policy is configured and
frozen before mint. A complete policy includes fallback provider list, order,
deadlines, max attempts, proof that no valid raw randomness was received, and
adapter result-status reads. Without that policy, a stalled request remains
stuck but honest rather than becoming a reroll.

## Metadata And Artwork Boundary

The durable artwork primitive is not only the current marketplace JSON.

The reconstructable bundle is:

```text
Core token and collection facts
collection metadata manifest
renderer manifest
render context version
script manifest
dependency manifest
media manifest
entropy seed and provenance
view/snapshot manifest, if any
freeze manifest
```

Rules:

1. `tokenURI()` remains marketplace-friendly.
2. Rich protocol facts live under namespaced `properties`.
3. Renderer output must be deterministic: a pure function of contract
   state and the render request, enforced by the opcode-ban
   static-analysis gate and pinned golden output vectors whose normative
   home is
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   [MRR-DETERMINISM] (ADR 0010 decision D4.3).
4. Alternate views should not destabilize the default `tokenURI()` surface.
5. Metadata refresh events should originate from Core when marketplaces are
   expected to observe them.
6. Renderer deprecation must not break frozen historical collections.

Metadata failure model:

1. Mutable collections may move from a deprecated renderer/router to a new
   compatible module through staged governance.
2. Frozen collections keep their frozen renderer and manifests unless an
   accepted recovery manifest says otherwise.
3. Incident revocation of a renderer freezes new use and mutable assignment,
   but cannot silently alter frozen historical artwork.
4. A frozen snapshot route may be used only if it is bound by the original
   finality manifest or a published recovery manifest.

## Standards Drift

Over 50 years, standards and marketplace behavior will change.

The architecture should support:

- ERC-165 interface discovery;
- ERC-721 (the ERC-721 Enumerable index standard is permanently absent
  from Core; enumeration is periphery- and export-served,
  [LTA-ENUMERATION]);
- ERC-721 Metadata;
- ERC-2981 royalty disclosure;
- ERC-4906 metadata updates;
- ERC-7572-style contract metadata when bytecode allows;
- optional token-bound accounts;
- optional dynamic traits;
- optional multi-view metadata;
- optional CCIP Read or verified offchain reads;
- optional raw onchain web views.

Support for optional standards should live in satellites unless the standard is
part of the permanent NFT identity surface. New standards should be adopted by
adding module versions, renderer versions, or read adapters, not by weakening
Core invariants.

Core's `supportsInterface` set is part of the permanent Core surface. If a
future royalty, metadata, or identity standard requires new Core interface
advertisement that cannot be safely added to the existing Core, adoption should
use a successor Core declaration rather than pretending a satellite can change
old Core's ERC-165 truth.

Transfer openness is a Permanent Core invariant with permanent
consequences. Core has no transfer hooks and never conditions transfers,
so every transfer-conditioned mechanic is precluded on this Core line, not
merely unimplemented (ADR 0010 decision D9.2). Preclusions
[LTA-STANDARDS]:

1. Non-transferable and lockable tokens — soulbound editions, ERC-5192
   locks, exhibition mementos, artist proofs bound to a wallet — cannot
   exist on this Core line.
2. Rental and user-role standards (ERC-4907 and successors) that require
   transfer- or time-conditioned ownership semantics cannot exist on this
   Core line.
3. Transfer-restricting royalty enforcement is permanently impossible on
   this Core line; disclosure-only ERC-2981 is the permanent posture. A
   declared successor line that adds enforcement must preserve, not
   reinterpret, this line's recorded royalty terms: old-Core
   `royaltyInfo()` disclosure, the resolver assignment history, and the
   recorded artist acknowledgments of the disclosure-only term
   ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   [RSR-MARKETPLACE-ROYALTY]) remain the authoritative economic record
   for works minted here (ADR 0011 decision R12).
4. Adopting any of these requires a declared successor Core line.
   Exhibition, attendance, and membership artifacts should instead be
   modeled as separate contracts or as attestation records against the
   existing tokens — the documented attestation pattern is
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-MEMENTO] (ADR 0011 decision R9).

These preclusions are mirrored in the protocol v1 exclusions list so
absence is provably intentional.

## Governance And Operations

Governance should be boring, evented, and recoverable.

Required practices:

1. Use multisigs or equivalent durable governance for production roles.
2. Use two-step or timelocked changes for default-scope economics, renderer
   registries, entropy providers, and global freezes.
3. Emit reason URIs or content hashes for material changes.
4. Maintain runbooks for resolver failure, metadata incident, renderer
   deprecation, entropy provider incident, ERC-20 unsupported assets, and split
   wallet runtime-code revocation.
5. Keep all emergency actions scoped to the affected subsystem.
6. Never give emergency admins a path to sweep owed funds.
7. Treat fallback-to-zero royalty behavior, metadata router failure, and
   entropy request stalls as incidents requiring monitoring.

Royalty resolver readiness is a deployment gate. Before public sale, governance
should stage, execute, and optionally freeze or timelock the resolver pointer;
readiness evidence comes from recorded `probeRoyaltyInfo` runs covering
resolver health, configured defaults, gas behavior, and fallback-to-zero
incidents.

Example diagnostic surface:

```solidity
function probeRoyaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    returns (
        bool resolverCallSucceeded,
        address receiver,
        uint256 royaltyAmount,
        bytes32 assignmentHash,
        bytes32 failureReason
    );
```

`probeRoyaltyInfo` is hosted on the two named Permanent-class royalty
probe contracts — the `ROYALTY_RESOLVER_GAS_LIMIT` and
`ROYALTY_RETURN_GAS_BUFFER` probes of
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
[RSR-GGP] rules 5 and 11, genesis inventory members under
[LTA-GGP-PROBES] — never on Core, the resolver, or any governed
satellite (ADR 0013 decision U7). The probe is not used by
marketplaces. It exists so anyone can record incident evidence that
`royaltyInfo()` itself cannot emit because it is `view`: a run writes
the canonical `GasParameterProbed`/`lastProbeRun` record that gates
lowering, emergency raising, and the permissionless conditional raise
and re-lower,
and additionally emits `RoyaltyInfoProbed` — the parameter-named
diagnostic alias, tagged in the event catalog as a member of the
probe-record family ([LTA-GGP]). The alias schema is defined once at
its home,
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
[RSR-2981-PROBE]; this document does not restate it.

Diagnostics are operational tools, not permanent marketplace surfaces. If a
diagnostic such as `probeRoyaltyInfo`, full `verifyFinality`, or a catalog
consistency read becomes impractical under future gas schedules, the first
remediation is raising the relevant Governed Gas Parameter ([LTA-GGP]);
only if the diagnostic remains impractical at any justifiable value does
the successor
manifest or release manifest deprecate that diagnostic, point to a range
or offchain-verifiable replacement, and keep old selectors documented for
historical deployments. Production `royaltyInfo()` and `tokenURI()` behavior
must not depend on deprecated diagnostics.

### Vulnerability Disclosure And Bounty Posture [LTA-DISCLOSURE]

The incident playbook — pause, incident revocation, successor
declaration — depends on early discovery, so the intake channel for
third-party researchers is permanent operational surface, not repo
hygiene (ADR 0012 decision T9):

1. A standing vulnerability-disclosure channel must exist from genesis:
   a published security contact carried in `SECURITY.md`, in a
   `security.txt` at the operator domain, and as a security-contact
   field in the release manifest and in the system-manifest payload
   committed by `streamSystemManifest()`'s `manifestHash` and stored
   onchain ([LTA-MANIFEST]; ADR 0013 decision U2) — so the contact
   survives frontend and domain turnover and is discoverable from
   chain state alone.
2. The disclosure policy records a response SLO (acknowledgment and
   triage targets) and the escalation route into the incident runbook;
   intake is exercised periodically as a drill, and a missed
   acknowledgment SLO is a monitored incident.
3. The bounty posture is decided explicitly, either way: a funded bounty
   program with scope and payout policy, or a recorded no-bounty
   decision with rationale, revisited at every funding-manifest renewal.
   Silence is nonconformant.
4. Disclosure intake and bounty administration are funded obligations
   with a named owner and horizon in the funding manifest
   ([LTA-FUNDING] rule 1), and the disclosure-policy artifact is
   hash-committed release evidence verified by the conformance-matrix
   Operations gate.

### Institutional Custody Guidance [LTA-CUSTODY]

Owner-side custody is outside protocol control, but a spec this candid
about protocol degradation must be equally candid about the owner side
(ADR 0010 decision D6.7). This guidance is Operational.

1. Token custody is bearer custody. Loss of the owner key is irrecoverable
   loss of the asset: no protocol role, artist, or governance process can
   reassign ownership, and no successor declaration changes old-Core
   ownership. Acquisition committees should treat owner-key loss as a
   named total-loss mode in their risk memo.
2. Institutions holding for decades should hold through a Safe or
   equivalent contract wallet with a board-governed signer policy,
   documented signer succession, periodic signer-liveness rehearsal, and a
   qualified-custodian or estate fallback — the same posture this spec
   demands of protocol roles.
3. Custody transitions (accession, internal signer rotation, loans,
   deaccession) can be documented onchain without platform involvement
   through the owner-writable registrar records of
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-OWNER-RECORDS]; the object dossier export and citation profile
   give registrars a stable reference frame.
4. Read-only museum mode (State Export And Archival Operations) is the
   protocol-side guarantee that institutional reads — ownership,
   provenance, finality verification, archived reconstruction — survive
   total governance loss; institutional custody planning should assume no
   operator will exist and verify that the institution's own tooling can
   consume state exports and the reconstruction client.

## Observability

Every subsystem should expose both reads and events.

Minimum cross-cutting observability:

1. active module addresses and versions;
2. active, deprecated, and incident-revoked implementation/code-hash states;
3. default/collection/token assignment reads;
4. freeze state reads;
5. event reconstruction for every assignment mutation;
6. token-level final artwork provenance;
7. pending/stale/failed entropy dashboards;
8. payment owed, released, observed, escrowed, and unsupported asset states;
9. Core bytecode size and interface support checks in release artifacts.

Events are not enough by themselves. Critical current state also needs direct
view functions.

Event indexing policy:

1. Every event gets at most three indexed fields.
2. Each spec must name the canonical indexed fields for events used by
   indexers.
3. Non-indexed fields must still include the data needed for replay.
4. If an event has more than three natural query keys, the spec should name the
   primary query path and require secondary indexes off-chain.

## Failure And Recovery

The architecture should define failure modes before they occur.

Expected failure classes:

```text
resolver unavailable
resolver malformed return
split wallet wrong code at predicted address
split wallet runtime incident
unsupported ERC-20 asset
metadata router unavailable
renderer deprecated or unsafe
offchain payload unavailable
entropy provider stalled
entropy provider compromised
randomness callback stale
admin key or governance process compromised
marketplace cache divergence
```

Recovery principles:

1. Fail closed for mutation paths.
2. Fail safe for marketplace reads where reverting could break transfers or
   sales, such as `royaltyInfo()`.
3. Keep owed funds owed.
4. Make every incident path evented and reasoned.
5. Use predeclared fallbacks when outcomes could be manipulated.
6. Avoid hidden rerolls, hidden metadata swaps, or hidden payment reroutes.
7. Publish migration/reroute specs before moving stranded funds or changing
   frozen artwork/economics.

## Umbrella Domain Constants [LTA-DOMAINS]

This document is the normative home of the finality, state-export,
module-registry, and governance-guardian hash domains. Every constant
is Permanent: recorded
here with its string preimage and ordered inputs, mirrored as
checker-verified rows in the protocol v1 domain-constants table, and
recomputed by CI, which fails on drift between constants, homes,
mirrors, and release artifacts. The ordered `abi.encode` input lists are
pinned by the code blocks in Artwork Finality Freeze, State Export And
Archival Operations, the Registry Pattern, and the Guardian Module
Pattern; the table names
them without restating. New rows are computed and pinned by the
same CI recomputation before any gate consumes them.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_FINALITY_COMPONENTS_V1` | `6529STREAM_FINALITY_COMPONENTS_V1` | 0xf57efb77611ea13bd3a60968beee86ec330159736aa5d42707a9c0676dbc8898 | finality registry | `1` | domain; sorted `FinalityComponentExpectation[]` (Artwork Finality Freeze) |
| `STREAM_CORE_COLLECTION_FACTS_V1` | `6529STREAM_CORE_COLLECTION_FACTS_V1` | 0x387b66c3b8fdca5febff2a13faa7057fef7f711c4155493c8c8087e48b28c764 | finality registry | `1` | domain; chainid; core; collectionId; `CoreCollectionFinalityFacts` fields (Artwork Finality Freeze) |
| `STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1` | `6529STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1` | 0x6adebabfe6f92286e8678fc5f206cacb6b1a3b912afc80b6039e9240567e7f26 | `StreamCore` | `1` | domain; chainid; core; collectionId (Artwork Finality Freeze) |
| `STREAM_FINALITY_V1` | `6529STREAM_FINALITY_V1` | 0x569714204c899f0d33a0f98879ce85708169a5f1e11f763f2897f64e5d6c8493 | finality registry | `1` | domain; chainid; core; collectionId; coreCollectionFactsHash; componentsHash; manifest uriHash/contentHash/schemaId/canonicalizationHash |
| `STREAM_FINALITY_RECOVERY_V1` | `6529STREAM_FINALITY_RECOVERY_V1` | 0x521e8df5a00a793a5b47409e1e7711b4b8857ba9e6c833fe59a48dfa865b19ac | finality registry | `1` | domain; chainid; finalityRegistry; collectionId; expectedOldFinalityRecordHash; recoveryManifest.contentHash; recoveryRouteHash; executeAfter; artworkBytesChanged; reasonHash |
| `STREAM_SCOPED_FINALITY_V1` | `6529STREAM_SCOPED_FINALITY_V1` | 0x5b56313142e6381659f9d10163ccfa5ea22cb437617c8e69b37c31ecda6f3a50 | finality registry | `1` | domain; chainid; core; scopeType; collectionId; tokenId; scopeId; scopedCoreFactsHash; componentsHash; manifest uriHash/contentHash/schemaId/canonicalizationHash |
| `STREAM_SCOPED_CORE_FINALITY_FACTS_V1` | `6529STREAM_SCOPED_CORE_FINALITY_FACTS_V1` | 0x5c6390c543248a4d63630061d67c3d2245df223d9ac586deccabf40620b43f6e | finality registry | `1` | domain; chainid; core; scope fields; `ScopedCoreFinalityFacts` fields (Scoped Finality For Open Series) |
| `STREAM_SCOPED_FINALITY_RECOVERY_V1` | `6529STREAM_SCOPED_FINALITY_RECOVERY_V1` | 0x7111cd2afae740dbddcd349ab0b8b9269b6a81c331cef7ca8d542e87308bc54a | finality registry | `1` | domain; chainid; finalityRegistry; scope fields; expectedOldFinalityRecordHash; recoveryManifest.contentHash; recoveryRouteHash; executeAfter; artworkBytesChanged; reasonHash |
| `STREAM_EXPORT_TOKEN_COLLECTION_LEAF_V1` | `6529STREAM_EXPORT_TOKEN_COLLECTION_LEAF_V1` | 0x584f047f88b167145486935a02a69e85bf86fdaa6200d84996b4b03124922beb | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_COLLECTION_SERIAL_LEAF_V1` | `6529STREAM_EXPORT_COLLECTION_SERIAL_LEAF_V1` | 0x8868a51be1bdbae4624466a9fa15a9c14b03dd877a0d62e9fca92a2651a8ee2d | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_ENTROPY_LEAF_V1` | `6529STREAM_EXPORT_ENTROPY_LEAF_V1` | 0x0160b86ab41aa57205650b067fbed4e57e8e346b664d01f1a4595213af403c73 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_FINALITY_LEAF_V1` | `6529STREAM_EXPORT_FINALITY_LEAF_V1` | 0xe1aa59240cbf23c892175f79140c47438ec2db63500bb3c43dc2cddf36ed92c7 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_SPLIT_PROFILE_LEAF_V1` | `6529STREAM_EXPORT_SPLIT_PROFILE_LEAF_V1` | 0xa105567cd79aeddb669b7f22370bd8e375e8b74c131b5305b8fd5a0e614505e4 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_SPLIT_ENTRY_LEAF_V1` | `6529STREAM_EXPORT_SPLIT_ENTRY_LEAF_V1` | 0x63ac827ee22adfd396ab63e6c8e4a3bca7e4a645c6141abeb1bd36805095cc42 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_REVENUE_ASSIGNMENT_LEAF_V1` | `6529STREAM_EXPORT_REVENUE_ASSIGNMENT_LEAF_V1` | 0x063c43d4dce1eebd74b009c22e301aa2d76fdc560665c8bbc24daa19a801a2ad | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_ESCROW_CREDIT_LEAF_V1` | `6529STREAM_EXPORT_ESCROW_CREDIT_LEAF_V1` | 0x943bff9afcadeec1628590d3b88f68d5aea504c1ba5256b4333f3a7dd1db7af2 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_SALE_CREDIT_LEAF_V1` | `6529STREAM_EXPORT_SALE_CREDIT_LEAF_V1` | 0x4713509255935af0a6981e3a2eb9948df2dc272218d10db479716667ca9c280b | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT]; credit surfaces per [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) |
| `STREAM_EXPORT_MINT_COUNTER_LEAF_V1` | `6529STREAM_EXPORT_MINT_COUNTER_LEAF_V1` | 0xda394087539bfc7283e4d78855493bf4c1ef26a24f2074a930b51aff26cf2bf9 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_AUTHORIZATION_LEAF_V1` | `6529STREAM_EXPORT_AUTHORIZATION_LEAF_V1` | 0x8feca7dbfefa49f93018dd146f49b466753e8d55d2cfe1ddd455b87875411edf | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_REGISTRY_RECORD_LEAF_V1` | `6529STREAM_EXPORT_REGISTRY_RECORD_LEAF_V1` | 0x65511c163de32ba01544ff43eb9f587576c93f3682cf25798d4b19155ad5a338 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_CATALOG_LEAF_V1` | `6529STREAM_EXPORT_CATALOG_LEAF_V1` | 0xbfc5b9ed3abb2d26d65422468bd303f67c4ad17adc9a4cc71fbaefd97d880d17 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_RECOVERY_LEAF_V1` | `6529STREAM_EXPORT_RECOVERY_LEAF_V1` | 0xb325dd3c363b686878389fab871ec0303eb41e984e1856d9632cf3ff0b312160 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_RECORD_CHAIN_LEAF_V1` | `6529STREAM_EXPORT_RECORD_CHAIN_LEAF_V1` | 0xc0ec93115d32e7633c13d7414f7f77c5a20edf8a4c512bfbb1a0b8dbeaa6ace0 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT]; lane values per [CMC-RECORD-CHAIN] |
| `STREAM_EXPORT_ARTWORK_MANIFEST_LEAF_V1` | `6529STREAM_EXPORT_ARTWORK_MANIFEST_LEAF_V1` | 0x75a6b72b058ed053bc42e32ee8ed32283b8f973f455854e870e1c1a3727ea984 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_LOCK_LEAF_V1` | `6529STREAM_EXPORT_LOCK_LEAF_V1` | 0x2439a59cd6c4a767eefacdb9d4397317f88ac30c996c1c5dae92821f7159536b | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT] |
| `STREAM_EXPORT_TOKEN_DATA_LEAF_V1` | `6529STREAM_EXPORT_TOKEN_DATA_LEAF_V1` | 0x0c586b41736dd3049878e98663002a07e79c06ab6ab5f49c09f03c0e44fa4610 | `STATE_EXPORT_V1` profile | `1` | leaf schema in [LTA-EXPORT]; retention per [MPA-CORE-ABI]/[CMC-BURN] |
| `STREAM_EXPORT_EVENT_HISTORY_V1` | `6529STREAM_EXPORT_EVENT_HISTORY_V1` | 0xde2f44be2a232fbd4b086150b751c9483f78c1de4779a09d9d2acc84d4ac76ae | `STATE_EXPORT_V1` profile | `1` | domain; chainId; core; startBlock; endBlock; recordCount; `EventHistoryChunk[]` ([LTA-EVENT-HISTORY]) |
| `GGP_FINALITY_COMPONENT_READ_GAS` | `6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS` | 0xbf54fb4ba4a0942771e26fe4b1f829f8324f6f98ef66e080fd6885b75bdf3221 | finality registry | `1` | `keccak256` of the string preimage; no `abi.encode` inputs ([LTA-GGP]; `_ID` suffix retired, ADR 0013 decision U9) |
| `STREAM_MODULE_REGISTRATION_RECORD_V1` | `6529STREAM_MODULE_REGISTRATION_RECORD_V1` | 0x4b5b157069f454a5c1b78a95a28e2016af2d428d4eb4037917b271a668490869 | module registry | `1` | domain; module; moduleType; interfaceId; moduleVersion; runtimeCodeHash; deploymentManifestHash; moduleManifestHash ([LTA-REGISTRY] requirement 7) |
| `STREAM_GUARDIAN_SCOPE_V1` | `6529STREAM_GUARDIAN_SCOPE_V1` | 0x411f2ec1515973db8ec5774ffd6b9e7fbcd8e9c0fb9ffc2b8de7eab7f4325433 | guardian module | `1` | domain; chainid; guardianModule; ascending unique `targets` address array ([LTA-GUARDIAN]) |
| `STREAM_GUARDIAN_AUTHORIZATION_V1` | `6529STREAM_GUARDIAN_AUTHORIZATION_V1` | 0x1d7c055e54305625ad501d8d2766e4a0af244277f03ea3ce785360e63ef118fd | guardian module | `1` | domain; chainid; guardianModule; agent; capabilityMask; scopeHash; notAfter; maxUses; grantNonce ([LTA-GUARDIAN]) |

Component-type and manifest-type vocabularies (`keccak256` of the ASCII
name) are pinned by their owning sections: finality component types in
Artwork Finality Freeze (with `ARTIST_SANCTION` and
`PLATFORM_WORKS_DECLARATION` owned by
[`docs/stream-artist-authority.md`](stream-artist-authority.md)
[AA-DOMAINS]) and export manifest types in [LTA-EXPORT].

## Release Gates

No subsystem is deployable until these gates pass.

Core gates:

1. `forge build`.
2. Core bytecode below EIP-170 with documented headroom after each extraction
   and again after Core-native ERC-2981 is added.
   The governing rule is the deployment-conformance headroom target
   (ADR 0009 decision 2): Core runtime must retain at least 2,000 bytes of
   EIP-170 margin at the deployment gate, proven by one post-extraction
   measured build with the full mandatory hook set. The bytecode-spend
   baseline and exception ledger in `release-artifacts/contracts.json`
   remain the pre-deployment development control; interim exceptions cannot
   survive to the deployment gate.
3. interface IDs verified.
4. `totalSupply()`, `lastAllocatedTokenId()`, and dense sequential
   allocation verified; the `ERC721Enumerable` index surface is absent —
   no per-index selectors, no index storage, and
   `supportsInterface(0x780e9d63) == false` ([LTA-ENUMERATION]).
5. Core-native ERC-2981 tested under resolver failure.

Revenue gates:

1. split profile identity fuzz tests;
2. release accounting fuzz tests;
3. forced ETH and passive receipt tests;
4. escrow credit/flush tests;
5. ERC-20 unsupported/deprecated state tests;
6. primary settlement CEI and no-recipient-blocking tests.

Metadata gates:

1. JSON escaping tests;
2. script assembly determinism tests;
3. renderer manifest tests;
4. metadata refresh event tests;
5. freeze and override tests;
6. large payload gas/RPC envelope tests.
7. artwork finality freeze proves renderer, manifests, and entropy policy are
   jointly locked.
8. onchain collection finality is blocked unless the snapshot manifest hash has
   been recorded.
9. finality is blocked in every mode without a recorded token content root,
   the required artist sanction or platform-works declaration, the artist
   intent record or waiver, dual-family archive receipts (at least one of
   a verifiable evidence class) with passing fixity, and — for
   script-based works — the reference render component with its archived
   execution environment and pinned acceptance mode
   ([LTA-FINALITY] requirements 6, 9–12).
10. renderer determinism static-analysis gate and golden output vectors
    ([MRR-DETERMINISM]).

Entropy gates:

1. request lifecycle tests;
2. provider adapter tests;
3. stale callback tests;
4. no-reroll recovery tests;
5. provider-epoch tests;
6. active and backup/safe-mode coordinator registration tests;
7. monitoring/runbook dry run.

Governance gates:

1. role matrix reviewed;
2. timelock/two-step changes tested where used;
3. emergency actions prove no owed-fund sweep;
4. event and view reconstruction tests.
5. genesis role assignment proves no single EOA can execute material actions;
6. deployment manifest includes event catalog hash, ABI checksums, module
   manifest hashes, bytecode sizes, governance delay configuration, and
   the deterministic-deployment factory, salts, and init-code hashes
   ([LTA-DEPLOY]);
7. GGP floor-rejection, raise-bound, emergency and conditional
   probe-gated raise, probe-gated lower and conditional re-lower,
   conditional-raise/re-lower
   scope-rejection, forged-failure probe-integrity,
   host-introspection-read ([LTA-GGP] requirement 12), and change-event
   tests for every deployed parameter, plus the [LTA-GGP-PROBES]
   permanence checks and the [LTA-GTP] floor/bound/cadence-probe/
   introspection/change-event suite for every deployed Governed Time
   Parameter
   ([LTA-GGP] requirement 9; [LTA-GTP]);
8. terminal-freeze veto path exercised, and window widths verified against
   the recorded worst-case holder latencies ([LTA-GOV] rules 4 and 6);
9. batch-action atomicity tests for every cross-contract "same governed
   execution" obligation ([LTA-GOV] rule 5);
10. registry-`ACTIVE` pre-approved fallback targets verified for every
    critical pointer family, with a rehearsed permissionless emergency
    move as release evidence ([LTA-POINTERS] rule 11);
11. every governor-held defensive role proves either a registered
    guardian module with a live authorization exercised in rehearsal —
    its agents passing the holder-class, redundancy, and sunset checks
    of [LTA-GUARDIAN] rule 8 — or
    a holder latency within the emergency assumption ([LTA-GUARDIAN]
    rule 6).

Operations gates:

1. genesis state export produced and reproduced by an independent indexer;
2. export cadence, fixity program manifest, and funding/endowment manifest
   — including the costed operating model, the coverage-horizon
   viability floor, the consolidated obligation calendar, the
   storage-family taxonomy, and the family-extinction migration
   reserve — published and hashed
   ([LTA-EXPORT], [LTA-ARCHIVE] requirements 8–9, [LTA-FUNDING]
   rules 4–6);
3. reconstruction client build, replay vectors, and manifest hash match
   ([LTA-RECON]);
4. degraded-admin and museum-mode drill artifacts;
5. dual-family archive receipts with fixity coverage verified for the
   genesis state export and its event-history chunks ([LTA-EXPORT]
   requirement 5; [LTA-ARCHIVE] requirement 7);
6. the vulnerability-disclosure policy artifact published, hash-committed,
   and carried in the release and system manifests ([LTA-DISCLOSURE]).

## Accepted Tradeoffs [LTA-TRADEOFFS]

1. Satellite contracts add integration complexity, but protect Core from
   decades of changing policy.
2. Dropping `ERC721Enumerable` from Core trades onchain per-index
   enumeration for a permanently cheaper Core (ADR 0012 decision T10,
   superseding ADR 0010 decision D9.3). The index bookkeeping would
   have added roughly 45,000–50,000 gas to every all-cold mint and
   roughly 60,000–70,000 gas to every all-cold wallet-to-wallet
   transfer — several cold `SSTORE`s on every ownership change, paid by
   collectors on every marketplace sale for the life of the system —
   plus several kilobytes against the Core headroom rule, to serve an
   archival need that state exports, dense sequential IDs with the
   iteration surface, Transfer replay, and the conformance-gated
   reconstruction client already serve ([LTA-ENUMERATION]).
   `totalSupply()` stays. The costs of removal are accepted with open
   eyes: integrators that would have called
   `tokenOfOwnerByIndex`/`tokenByIndex` onchain must use the periphery
   enumeration lens or indexers (no such integrator is known), and
   museum-mode per-owner walks become paged range reads instead of O(1)
   index reads. The release manifest publishes the measured per-mint
   and per-transfer gas of the deployed lean bytecode as a gate
   artifact so the recovered cost stays quantified, not folkloric.
   Taken now, before genesis, precisely because it becomes irreversible
   at deployment; re-adding enumerable is a successor-line decision,
   and the supersession is owner-flagged in ADR 0012.
3. Pull payments require recipients to claim, but protect settlement from
   recipient behavior.
4. Core-native ERC-2981 costs bytecode, but is necessary for marketplace
   compatibility and should be protected by moving other logic out.
5. Freeze controls reduce future flexibility, but create credible permanence
   when used.
6. Hash commitments make offchain artifacts verifiable, but do not guarantee
   every future client will fetch or display them.
7. Provider-adapter optionality adds operational work, but avoids betting the
   entire protocol life on one randomness vendor.
8. Governed Gas Parameters reintroduce a governance dependency into read
   paths that could have been fully static, accepted for survivability:
   immutable floors, per-action raise bounds, staged delays, and probes
   bound the risk, and an immutable cap that strands a frozen collection
   after a repricing is the worse permanence failure (ADR 0010 decision
   D1; ADR 0011 decision R5).
9. Transfer openness permanently precludes soulbound tokens, rental
   standards, and every transfer-conditioned mechanic on this Core line
   ([LTA-STANDARDS]); the open-transfer guarantee to collectors and
   marketplaces is judged worth the loss, and the exclusion is recorded so
   absence is provably intentional.
10. The protocol layer is deliberately outside legal-compliance scope,
    and that is stated rather than implied (ADR 0011 decision R12).
    Immutable split profiles cannot be edited to remove a recipient for
    any legal reason — including a recipient later appearing on a
    sanctions list, a near-certain event somewhere in a 50+ year
    recipient population — and permissionless release means any caller
    can push owed funds to such a recipient; the no-sweep rule is
    absolute. Onchain catalogs, artwork bytes, and append-only records
    honor no takedown demand, and permanent records can embed personal
    data the protocol cannot redact — the schema-level privacy, sealed
    payloads, and redaction design of [LTA-HASH] is the only
    mitigation. Rights records are informational documentation, never
    legal instruments. Compliance therefore lives at the operational
    edge, never in a protocol mutation path: operators should screen
    split recipients and record subjects at profile and record creation
    time, apply jurisdiction-specific policy only in operator-run
    frontends and services, and must disclose this posture in writing
    to artists, recipients, and institutions in the same instrument as
    the estate-loss disclosure
    ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
    [RSR-ESTATE]).
11. Curated onboarding is a disclosed liveness assumption, not an
    accident (ADR 0011 decision R12): every collection and artist
    binding on this Core line originates from governed platform roles,
    so with governance gone no new collection or binding can ever be
    created here, while every existing work keeps every permanence
    guarantee. The stated posture and its consequences are owned by the
    protocol v1 exclusions
    ([`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
    [PV1-EXCL] item 9); this list records the acceptance.

## Recommended Genesis Implementation Order

1. Extract metadata router and renderer from Core.
2. Extract collection metadata storage from Core.
3. Extract entropy coordination from Core.
4. Implement revenue resolver and split wallets.
5. Add minimal resolver-backed Core ERC-2981.
6. Run bytecode and interface gates.
7. Freeze genesis module manifests and deployment runbooks.
8. Gather marketplace, indexer, and rendering evidence before public claims.

This order maximizes Core headroom before adding mandatory ERC-2981 and keeps
the riskiest mutable policies in satellite contracts from day one.
