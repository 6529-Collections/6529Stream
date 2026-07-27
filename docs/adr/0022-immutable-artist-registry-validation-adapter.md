# ADR 0022: Immutable Artist-Registry Validation Adapter

## Status

Proposed for pre-genesis review on 2026-07-26.

This ADR does not authorize implementation while it remains `Proposed`.
Acceptance, the normative interface freeze, specification reconciliation,
implementation, generated evidence, and deployment are separate gates. This
ADR does not make the protocol production-ready.

## Metadata

| Field | Value |
| --- | --- |
| Issue | [#670](https://github.com/6529-Collections/6529Stream/issues/670) |
| Related work | [#667](https://github.com/6529-Collections/6529Stream/issues/667), [#669](https://github.com/6529-Collections/6529Stream/issues/669), [#684](https://github.com/6529-Collections/6529Stream/issues/684), [#690](https://github.com/6529-Collections/6529Stream/issues/690), [#656](https://github.com/6529-Collections/6529Stream/issues/656) |
| Related ADRs | [ADR 0004](0004-admin-governance.md), [ADR 0007](0007-upgrade-redeployment.md), [ADR 0017](0017-raise-only-parameter-governance.md), [ADR 0020](0020-executor-only-finality-recovery.md), [ADR 0021](0021-immutable-revenue-resolver-validation-adapter.md) |
| Permanence class | Replaceable genesis artist-registry implementation topology; no change to the Permanent artist interfaces or Core ABI |
| Implementation gate | A separately reviewed acceptance change and a complete independently approved interface/transcript freeze are required before source implementation |

## Problem

Issue #670 requires one concrete genesis artist registry implementing the
complete Permanent `IStreamArtistRegistry`, `IStreamArtistConsent`, and
`IStreamArtistRecoveryEvidence` surfaces. The registry must also implement the
binding, collaborator, consent, payout, sanction/finality, platform-work,
attestation, delegation, guardian/rotation, repudiation, succession, dormancy,
estate, recovery, record-chain, and evidence lifecycles normatively specified
by `docs/stream-artist-authority.md`.

The first optimized via-IR checkpoint is not a conforming implementation. It
measures 23,614 runtime bytes and 25,609 init bytes, leaving only 962 bytes
under EIP-170, while still advertising pure-zero or unconditional-empty
implementations for at least:

- guardian sets, staged rotations, and prior-address standing revocation;
- collaborator enumeration and acceptance-linked identity;
- staged attribution repudiation;
- platform-work declarations, contests, claims, and corrections;
- attribution claims and artist attestations;
- delegation;
- succession, steward sanction grants, dormancy, and estate activation.

The checkpoint also returns no operative identity revision. These are
normative lifecycle reads, not optional preview conveniences. Keeping the
interface claims while returning permanent zero stubs is nonconformant.
Implementing the omitted state, transitions, records, events, and tests in the
remaining 962 bytes is not credible.

ADR 0021 solves the separate revenue-resolver size problem and explicitly
makes no artist-registry architecture change. Its adapter cannot be reused:
the two modules have different authority, dependency, state, transcript, and
failure domains. A second explicit design decision is therefore required
before issue #670 source work can continue.

## Current Behavior

No accepted production implementation of the architecture in this ADR exists.
The issue #670 worktree is frozen at the measurement above.

The current checkpoint correctly establishes several useful invariants: one
registered artist module, one Core binding, one role registry, one Governance
V2/GGP host, one registry-owned nonce and record-chain namespace, and
storage-backed consent and recovery facts. It also contains an ERC-1271
verification gas parameter. None of those partial facts make the advertised
Permanent interface complete.

ADR 0007 prohibits proxy, delegatecall, beacon, diamond, and mutable
implementation-pointer patterns without a separately accepted design. ADR
0017 permits the existing governed ERC-1271 verification limit but prohibits
ad hoc probes and ungoverned external-call caps. ADR 0020 remains Proposed and
does not authorize its finality-recovery source lifecycle.

## Decision

If accepted, issue #670 will use one registered, state-owning
`StreamArtistRegistry` and one unregistered, implementation-private
`StreamArtistRegistryValidationAdapter`. The following constraints are one
indivisible architecture.

### B1. The registry remains the only module, authority boundary, and state owner

`StreamArtistRegistry` remains:

- the sole Registry V2 row and sole target of the Permanent artist-registry
  Core pointer;
- the sole owner and writer of every identity, binding, collaborator, consent,
  payout, sanction, finality, platform-work, claim, attestation, delegation,
  guardian/rotation, repudiation, succession, dormancy, estate, recovery,
  nonce, record-chain, payload-index, and evidence fact;
- the sole emitter of every externally meaningful artist-authority event;
- the sole host and reader of artist-registry Governed Gas Parameters;
- the sole enforcer of caller, role, artist, collaborator, Governance V2,
  nonce, deadline, current-state, and capability authorization; and
- the only contract that applies state transitions under one non-reentrant
  checks-effects-interactions sequence.

The registry must implement every advertised Permanent read from its own
storage and pure computation. A read may not call the adapter. Empty values are
valid only when the corresponding lifecycle has no operative record; there
must be a conforming transition capable of creating every nonempty state the
normative specification requires.

The adapter returns validation data, never authorization. A successful
response cannot mutate registry state, consume a nonce, establish standing,
grant a capability, accept a collaborator, or emit an event. The registry
compares the response with its locally authenticated request and current state
before writing.

### B2. The adapter is stateless, immutable, and implementation-private

`StreamArtistRegistryValidationAdapter` is deployed code but is not a module,
pointer target, registry, state store, proxy, authority, or GGP host. It may
use Solidity immutables embedded in its runtime. It must have:

- no mutable storage, owner, role, administrator, signer, or initializer;
- no payable entry, custody, value transfer, `receive`, or dispatching
  `fallback`;
- no proxy, implementation slot, upgrade hook, `DELEGATECALL`, `CALLCODE`,
  `SELFDESTRUCT`, `CREATE`, or `CREATE2`;
- no arbitrary target, selector, calldata, record-family, operation enum, or
  generic `bytes` router; and
- no interpretation of `msg.sender` as an artist, collaborator, guardian,
  steward, successor, delegate, registry administrator, or Governance V2.

The adapter may perform only the exact typed read-only calls approved in the
normative interface packet. Direct third-party calls are harmless and produce
the same result for identical calldata and dependency observations.

The adapter is not an ordinary genesis-profile entry, has no `moduleType`, is
not registered in Registry V2, and is never installed into a Core pointer. It
is recorded in the implementation-private dependency inventory and complete
deployed-contract evidence as
`ARTIST_REGISTRY_VALIDATION_ADAPTER`, system-manifest contract inventory ID
`39`, immediately after ADR 0021's revenue adapter at ID `38`. The ordinary
module/profile inventory remains exactly 37 entries.

### B3. One registry immutably pins one exact adapter and dependency set

The registry constructor pins the adapter address, deployed runtime
`EXTCODEHASH`, implementation-versioned ERC-165 interface, fixed marker,
schema/version, and dependency-binding hash. The adapter pins the exact
dependencies it is permitted to observe.

Before implementation, a separate normative appendix and freeze commit must
publish:

- every adapter entry, canonical signature, selector, and ERC-165 XOR;
- marker, schema, domains, magic, dependency-binding preimage, and constants;
- exact static and bounded-dynamic calldata encodings;
- exact request and result tuples, reserved words, return lengths, and digest
  preimages; and
- the complete per-entry dependency callgraph.

Construction fails unless the adapter has exact code and each fixed probe
returns one canonical 32-byte word:

- ERC-165 true for `0x01ffc9a7`;
- ERC-165 true for the versioned adapter interface;
- ERC-165 false for `0xffffffff`;
- exact marker;
- exact schema/version; and
- exact dependency-binding hash independently computed by the registry.

Every probe is a zero-value, available-gas `STATICCALL` with fixed calldata,
exact return length, bounded copy, canonical decoding, and no returndata
bubbling. Revert, fallback-only success, short, oversized, malformed, or
noncanonical return fails construction.

Before every validation request, the registry compares the live adapter code
hash with the pinned hash. There is no setter, rebind, emergency bypass, or
mutable implementation path. Replacing the adapter requires deploying a new
registry and completing Registry V2 continuity and Core-pointer governance.

### B4. Dedicated validation entries bind complete transition intent

Every supported transition has one dedicated, versioned adapter selector.
There is no operation-dispatch enum and no arbitrary call or record router.
The interface packet may share fixed request/result structs only when every
unused word is required to be zero and each dedicated selector has an exact
allowed-field mask.

For each transition, the registry:

1. acquires its non-reentrant lock;
2. validates the caller, role or artist authority, selector, current state,
   nonce, deadline, capability, and Governance V2/GGP context locally;
3. validates dynamic-input bounds and computes hashes over the exact bytes;
4. computes a full-intent digest that binds the complete current state and
   requested transition;
5. verifies the live adapter code hash; and
6. performs the exact typed, zero-value validation `STATICCALL`.

The intent uses an implementation-versioned domain and `abi.encode`. It binds
at least:

- chain ID, registry, bound Core, adapter address and code hash, versioned
  adapter interface, marker, schema, and dependency binding;
- adapter selector and registry write selector;
- authenticated caller, authority class, role/capability proof, Governance V2
  action context where applicable, current nonce, deadline, and replay state;
- every current identity, binding, collaborator, consent, payout, sanction,
  finality, claim, attestation, delegation, guardian/rotation, repudiation,
  succession, dormancy, estate, recovery, chain, or evidence fact consumed by
  the transition; and
- every requested static value plus the length and Keccak hash of each bounded
  dynamic value.

Each result is one exact fixed-length tuple beginning with versioned magic,
echoed full-intent digest, observations digest, and result digest. Remaining
words return every hash, identity, address, count, deadline, nonce, enum, flag,
and state value the registry will use. Unused and reserved words are zero.
The registry independently recomputes both digests and compares every result
word before mutation.

Empty, short, oversized, malformed, noncanonical, wrong-magic, wrong-intent,
wrong-observation, wrong-result, out-of-range, nonzero-reserved, or
semantically mismatched results fail before any state or event change. Return
handling is bounded assembly: exact `returndatasize()`, fixed copy, no dynamic
returndata allocation, and no bubbling.

### B5. Bounded dynamic inputs have one canonical ABI encoding

Artist registration, identity evidence, reason strings, signature bundles, and
content-freeze class lists contain bounded dynamic data. The interface packet
must pin for each such entry:

- the exact ABI head offsets, element count or byte length, right-padding, and
  total calldata length formula;
- a protocol maximum no greater than the registry's locally enforced maximum;
- whether empty content is permitted;
- the Keccak hash included in the intent and result;
- rejection of nonminimal offsets, overlapping tails, gaps, nonzero padding,
  trailing data, and length arithmetic overflow; and
- a fixed-length result independent of input length.

The registry validates the same bounds and hashes before calling. The adapter
may read only the approved calldata range and never copies attacker-sized
returndata. A generic dynamic record envelope is forbidden.

### B6. External calls are closed-world and preserve existing gas governance

The registry continues to enforce role, Governance V2, and current artist
authority locally. The adapter may make only the exact caller-insensitive
reads enumerated by the approved callgraph. The intended set is:

- ERC-1271 `isValidSignature(bytes32,bytes)` on the exact signer supplied by
  registry-authenticated current identity state, after live signer code-hash
  checks required by the interface packet; and
- any exact Core, role-registry, or Governance read that the approved packet
  proves is caller-insensitive and worth extracting.

The accepted implementation may use a strict subset. A new target or selector
requires a reviewed architecture change.

Registry-to-adapter validation forwards available gas and has a closed
inventory row for issue `#669`. ERC-1271 verification retains the existing
`ARTIST_ERC1271_VERIFY_GAS` Governed Gas Parameter and its #684 host row; the
registry authenticates and commits the live value, and the adapter may use
only that exact value at the one approved signer callsite. No new GGP,
fixed literal cap, calldata-selected cap, or overloaded parameter is allowed.

Every target address, code hash, required interface, marker, and schema is
constructor-pinned or included in the exact registry-authenticated request as
the interface packet specifies. Missing code, runtime drift, malformed return,
wrong magic, revert, out-of-gas, or callback attempt fails closed before
mutation. The acquired registry lock blocks reentrant write paths.

### B7. The adapter does not split state, records, events, or continuity

The adapter owns no identity, nonce, record chain, payload pointer, consent,
sanction, finality, claim, recovery, or succession fact. It emits no normative
artist event. It cannot call back into a registry write and cannot become an
alternative source for Permanent reads.

The registry stores every accepted transition and appends every required
collection and artist record-chain commitment. Evidence payloads remain
registry-owned facts even when their bytes use an approved immutable storage
primitive. The registry alone proves continuity to a successor deployment.

This design does not authorize multiple state-owning artist components. Such a
topology would require a separate decision covering cross-contract atomicity,
continuity, state export, failure recovery, and Registry V2 evidence.

### B8. Deployment is acyclic and evidence is complete

The deployment graph is:

1. deploy and verify upstream Core, role, Governance/GGP, and other approved
   dependencies;
2. deploy the artist validation adapter with exact immutable dependencies;
3. retain its constructor, initcode, runtime, code-hash, interface, marker,
   schema, dependency, source-verification, and zero-authority evidence;
4. deploy the artist registry with the verified adapter facts;
5. verify and hand off the registry's normal authority/GGP posture;
6. deploy ADR 0021's resolver adapter against the final artist registry;
7. deploy and register the revenue resolver; and
8. register only the artist registry and revenue resolver as ordinary modules
   before governed Core-pointer installation.

The artist adapter does not pin or call the registry, so the graph has no
address or initcode fixed-point cycle.

ADR 0021's versioned contract-set work must include both #670 private
dependencies in version `2`: revenue adapter ID `38` and artist adapter ID
`39`. Neither appears in `registryEntries`, Registry V2 aggregates, module-type
derivation, or the 37-entry ordinary profile. Historical version `1`
manifests remain immutable and continue validating against their original
contract set.

### B9. Hostile tests cover every authority and transcript boundary

Before implementation acceptance, focused and integration tests cover:

- differential vectors against every normative artist-authority requirement
  and every nonempty Permanent read;
- every formerly pure-zero lifecycle, including creation, update, conflict,
  freeze/finality, supersession where allowed, and exact empty-state behavior;
- zero/non-contract adapter, wrong code hash/interface/marker/schema/
  dependency binding, runtime drift, fallback-only success, revert, and
  out-of-gas;
- empty, short, oversized, trailing, overlapping, gapped, nonminimal-offset,
  nonzero-padding, and length-overflow dynamic calldata;
- empty, short, oversized, malformed, and noncanonical result words, wrong
  magic/digests, mutated fields, and nonzero reserved words;
- wrong caller, role, authority class, binding generation, collaborator,
  guardian, prior address, steward, successor, delegate, capability, nonce,
  deadline, Governance action, current-state hash, and GGP value;
- EOA and ERC-1271 signatures, high-`s`, wrong `v`, compact signatures,
  signer runtime drift, cap boundaries, callback attempts, and replay;
- exact rollback of nonce, record chains, payload indexes, state, and events on
  every failed validation or downstream failure; and
- no adapter call reachable from any Permanent read.

Positive tests independently recompute record preimages, intent,
observations/result digests, chain commitments, events, and stored state.
Static opcode/callgraph tests prove the adapter has no state writes, value
path, deployment, delegation, arbitrary router, or registry callback.

### B10. Both contracts require explicit production-size margin

After every relevant patch and on the final serialized base, record for both
the artist registry and its adapter:

- optimized Solidity 0.8.19 via-IR runtime bytes and EIP-170 margin;
- creation bytecode and full initcode with exact constructor arguments and
  EIP-3860 margin;
- initcode hash, runtime SHA-256, and runtime EVM Keccak/`EXTCODEHASH`; and
- canonical isolated-build compiler inputs and receipt.

Each runtime must be no larger than 22,576 bytes and each full initcode no
larger than 47,152 bytes, preserving 2,000-byte margins. Boundary tests prove
22,576/47,152 pass and 22,577/47,153 fail. If either contract cannot meet both
margins without omitting behavior, implementation acceptance stops for a new
reviewed design.

Final validation includes focused and full Foundry, optimized build, Slither,
opcode/callgraph proof, #669 external-call inventory, #684 GGP binding,
canonical deployment/source verification, full release/checksum chain, the
Windows aggregate gate, and whitespace checks. Passing any gate is not a
readiness claim.

## Security Impact

This design adds one immutable validation boundary to artist-registry write
paths while preserving one authority and state owner. Exact code, locally
authenticated intent, bounded canonical calldata, fixed results, and
registry-side comparison prevent the adapter from inventing authority or
substituting a transition. The registry lock and pre-write validation preserve
atomicity under callbacks and failures.

The main cost is denial of service if the exact adapter or an exact dependency
becomes incompatible with the active gas schedule. The design fails closed:
there is no bypass. Recovery requires a new registry, continuity proof,
Registry V2 registration, and governed Core-pointer replacement under ADR
0007.

Permanent reads do not gain cross-contract coupling. The adapter never holds
funds and cannot affect payout custody.

## Release Impact

This ADR PR adds this record and its ADR index row, updates the changelog and
release-integrity source lists, and refreshes generated release metadata. It
does not change contract source, ABI, normative specs, catalogs, profiles,
candidates, deployment scripts, non-release manifests, maturity, or readiness.

If accepted, the implementation affects the artist-registry constructor,
implementation-private interface, private-dependency inventory and versioned
contract set, deployment order, external-call inventory, dual-size proof,
source verification, rehearsal, candidate, manifest, lockfile, and checksums.
The Permanent artist interfaces, Core ABI/bytecode, 37 ordinary profile rows,
and artist module type remain unchanged.

## Test Plan

The implementation test plan is B9 and B10. This ADR-only slice runs Markdown
link, changelog, generated release-tail, and whitespace checks. Documentation
checks do not prove the proposed contracts feasible or conforming.

## Rollout Plan

1. Review this ADR while issue #670 source remains frozen.
2. Accept, revise, or reject it in a separate explicit decision; a draft PR or
   bot approval is not acceptance.
3. After acceptance, publish and independently approve the complete normative
   interface, dependency, dynamic-encoding, transcript, and callgraph packet.
4. Reconcile `docs/stream-artist-authority.md`, the conformance matrix, ADR
   0020 recovery integration, and issue #690 record-family authorization.
5. Implement the adapter and complete registry without zero stubs, measuring
   both contracts after every runtime or constructor change.
6. Rebase the coordinator-defined predecessor train before final catalog,
   profile, inventory, candidate, deployment, release, and checksum
   regeneration.
7. Obtain independent security and integration review before publication for
   merge consideration.

## Alternatives Considered

### Keep zero stubs until after launch

Rejected. The Permanent interface advertises normative state and consumers
cannot distinguish an unimplemented lifecycle from a genuine empty state.

### Add the missing lifecycles to the monolith

Rejected. The incomplete checkpoint has only 962 bytes of EIP-170 margin,
already below the required 2,000-byte production margin.

### Split artist state across implementation-private components

Rejected for this ADR. Multiple state owners create cross-contract atomicity,
continuity, export, and failure-recovery problems. The narrower stateless
validation extraction preserves one state owner.

### Proxy, delegatecall, facets, or a mutable implementation

Rejected under ADR 0007. These patterns add upgrade authority and
storage-layout risk and do not preserve immutable release evidence.

### Add artist behavior or ABI to StreamCore

Rejected. Issue #670 authorizes no Core bytecode spend and Core has its own
headroom gate.

### Reuse the revenue validation adapter

Rejected. A shared adapter would combine unrelated dependency, authority,
transcript, and release domains, enlarge blast radius, and make replacement
coupled.

## Non-Goals

- No adapter, registry, interface, test, script, catalog, profile, candidate,
  manifest, or release implementation in this ADR PR.
- No change to Permanent artist interfaces, Core ABI or bytecode, module type,
  Registry V2 pointer families, GGP count, or ordinary 37-entry profile.
- No multiple artist state owners, proxying, delegation, mutable dependency,
  generic record router, emergency bypass, or readiness promotion.
- No acceptance of ADR 0020, finality-recovery implementation, deployment, or
  audit completion.

## Accepted Risks

These risks are proposed, not accepted, until this ADR is explicitly accepted:

- one additional immutable dependency expands deployment, verification,
  monitoring, and audit surface;
- adapter or dependency failure can halt artist writes until a new registry is
  deployed and governed into service;
- bounded dynamic ABI validation is complex and requires independent golden
  vectors and hostile encoding tests;
- validation duplicates some work and increases write gas; and
- replacing the adapter necessarily replaces the registry and invokes the
  full continuity and pointer-governance process.

These risks are preferable to advertised zero behavior, an undeployable
monolith, multiple state owners, mutable upgrade indirection, or Core bytecode
spend.
