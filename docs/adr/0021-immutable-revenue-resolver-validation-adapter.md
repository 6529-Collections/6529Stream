# ADR 0021: Immutable Revenue-Resolver Validation Adapter

## Status

Proposed for pre-genesis review on 2026-07-24.

This ADR does not authorize implementation while it remains `Proposed`.
Acceptance, implementation, normative-spec reconciliation, generated-artifact
regeneration, and deployment evidence are separate gates. In particular, this
ADR does not make the protocol production-ready and does not authorize a
deployment.

## Metadata

| Field | Value |
| --- | --- |
| Issue | [#670](https://github.com/6529-Collections/6529Stream/issues/670) |
| Related work | [#669](https://github.com/6529-Collections/6529Stream/issues/669), [#684](https://github.com/6529-Collections/6529Stream/issues/684), [#656](https://github.com/6529-Collections/6529Stream/issues/656), [#677](https://github.com/6529-Collections/6529Stream/issues/677), [#658](https://github.com/6529-Collections/6529Stream/issues/658) |
| Related ADRs | [ADR 0004](0004-admin-governance.md), [ADR 0007](0007-upgrade-redeployment.md), [ADR 0008](0008-revenue-splits-and-royalty-resolver.md), [ADR 0009](0009-protocol-v1-open-question-resolutions.md), [ADR 0017](0017-raise-only-parameter-governance.md) |
| Permanence class | Replaceable genesis royalty-resolver implementation topology; no change to the Permanent Core ABI or royalty-pointer interface |
| Implementation gate | A separately reviewed acceptance change must move this ADR to `Accepted` before source implementation begins |

## Problem

Issue #670 requires a concrete genesis royalty resolver that implements the
complete assignment, authority, freeze, mint-snapshot, continuity, and
marketplace-read behavior specified by ADR 0008 and
`docs/revenue-splits-and-royalties.md`. It must remain outside `StreamCore` and
preserve the Permanent one-function Core pointer surface:

```solidity
royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)
```

The selector and ERC-165 interface ID remain `0x54f77a09`. This ADR does not
narrow that interface or move any work into Core.

A conformant monolithic implementation is not deployable. The first optimized
via-IR checkpoint measured 31,231 runtime bytes and 34,160 init bytes. Removing
informational preview entries and compacting an internal governance commitment
reduced it to 30,167 runtime bytes and 33,117 init bytes. The second checkpoint
still exceeds the 24,576-byte EIP-170 runtime limit by 5,591 bytes. Both
measurements are non-normative implementation evidence from the issue #670
worktree; they are not release-bytecode evidence.

Reaching this ADR's explicit 2,000-byte production runtime margin, matching the
production Core margin policy, requires the resolver to reach at most 22,576
bytes. The extraction must therefore remove at least 7,591 bytes from the latest
resolver checkpoint while preserving every required behavior.

Continuing micro-optimization would either leave an unreviewably small margin
or encourage omission of required behavior. Narrowing the Permanent resolver
requirements, adding Core bytecode, retaining zero-value interface stubs, or
introducing upgradeable delegation is not acceptable. The remaining option is
a bounded extraction that changes deployment topology without changing which
contract owns policy, state, authority, or the Core-facing pointer.

## Current Behavior

No accepted production implementation of the architecture in this ADR exists.
The issue #670 implementation worktree is intentionally frozen at the size
checkpoint above.

ADR 0007 requires immutable, versioned redeployments and rejects proxy,
delegatecall, beacon, and diamond upgradeability absent a separate accepted
architecture. ADR 0008 makes the resolver a Replaceable module but requires its
Core-facing royalty read to remain O(1), storage-only, and free of every
`CALL`, `STATICCALL`, `DELEGATECALL`, `CREATE`, and `CREATE2` reachable from
`royaltyReceiverAndBps`. ADR 0017 permits no new probe or ad hoc governed gas
parameter to justify an otherwise fixed external-call cap.

## Decision

If accepted, issue #670 will use one registered `StreamRevenueResolver` and one
unregistered, implementation-private
`StreamRevenueResolverValidationAdapter`. The following decisions are one
indivisible architecture contract.

### A1. The resolver remains the only module, authority boundary, and state owner

`StreamRevenueResolver` remains:

- the sole Registry V2 row for this resolver topology and the sole target of
  the Permanent `ROYALTY_RESOLVER` Core pointer;
- the sole owner and writer of royalty assignments, consumed nonces, freeze
  state, mint snapshots, continuity state, mutable-descendant counters, and all
  other resolver state;
- the sole emitter of assignment, freeze, snapshot, continuity, and
  authorization-related events;
- the sole enforcer of Governance V2 caller, selector, action ID, action class,
  scope, old-state, and new-state commitments;
- the sole enforcer of artist authorization or consent; and
- the only contract that applies state transitions under a non-reentrant
  checks-effects-interactions sequence.

The adapter's answer is validation data, never authorization. A successful
adapter call cannot cause a transition by itself. The resolver compares every
returned value with its locally authenticated request and writes state and
emits events only after all checks pass. The adapter owns no nonce namespace,
freeze bit, snapshot, counter, cached assignment, event history, or authority
record.

The Core-facing `royaltyReceiverAndBps` call graph remains entirely inside
resolver storage and pure computation. It must not reach the validation
adapter or any other external contract.

### A2. The adapter is a stateless implementation-private dependency

`StreamRevenueResolverValidationAdapter` is a standalone deployed contract,
but it is not a module, pointer target, authority, registry, proxy, or state
extension. It may use Solidity immutables embedded in its runtime bytecode. It
must have:

- no mutable storage;
- no owner, role, administrator, signer, or authority entry;
- no payable entry, value transfer, fund custody, `receive`, or dispatching
  `fallback`;
- no proxy, implementation slot, upgrade hook, initializer, reinitializer,
  reachable `CALL`, `DELEGATECALL`, `CALLCODE`, `SELFDESTRUCT`, `CREATE`, or
  `CREATE2`; the only reachable external-call opcode is `STATICCALL`;
- no generic target, selector, calldata, or `bytes` router; and
- no interpretation of `msg.sender` as Governance V2, artist, owner, or any
  other authorization identity.

The adapter cannot mutate or authorize resolver state and cannot call the
resolver. The intended production caller is the resolver instance that
immutably pins the adapter. The adapter does not pin or authenticate that
resolver, and direct third-party calls must be harmless and must not alter its
answer for identical calldata and dependency observations. Static analysis and
bytecode inspection must prove the prohibited opcodes and generic dispatch
shapes are absent.

The adapter is listed in a separate implementation-private dependency
inventory/instance surface and in candidate, deployment, source-verification,
manifest, receipt, and checksum evidence. Its exact private-dependency key is
`REVENUE_RESOLVER_VALIDATION_ADAPTER`, assigned system-manifest contract
inventory ID `38` immediately after the retained ordinary IDs `1` through `37`.
That ordering applies only to the complete deployed-contract inventory.

The adapter is not an ordinary genesis-profile entry, does not increase the
37-entry module/profile inventory, has no `moduleType`, is not included in
`registryEntries` or the Registry V2 aggregate, is never registered as a
Registry V2 module, and is never installed into a Core pointer family. The
profile schema, system-manifest generator, deployment candidate, and their
checkers must explicitly support this decoupled evidence shape rather than
synthesizing a thirty-eighth module row.

### A3. One resolver instance immutably pins one exact adapter instance

The resolver constructor must immutably pin all of:

- the nonzero adapter address;
- the adapter's deployed runtime `extcodehash`;
- one implementation-versioned ERC-165 interface ID;
- one fixed adapter marker;
- one fixed adapter schema/version;
- one fixed adapter `dependencyBindingHash`; and
- every adapter dependency identity that the resolver must include in its
  validation-intent commitments.

The adapter marker, schema, interface, and every validation entry are
implementation-versioned. A separately reviewed normative interface appendix
and freeze commit must publish and approve their exact signatures, selectors,
ERC-165 XOR, constants, request and result tuple schemas, canonical encodings,
reserved words, and fixed calldata and returndata lengths before any adapter or
resolver Solidity implementation begins. An unversioned interface, a
configured literal that does not equal its selector XOR, or a permissive
fallback is nonconformant.

Construction fails unless the address has code, the runtime code hash is exact,
and all of the following exact probes pass:

- `supportsInterface(0x01ffc9a7)` returns one canonical 32-byte ABI `true`;
- `supportsInterface(versionedAdapterInterfaceId)` returns one canonical
  32-byte ABI `true`;
- `supportsInterface(0xffffffff)` returns one canonical 32-byte ABI `false`;
- the fixed marker selector returns exactly one canonical 32-byte word equal to
  the pinned marker; and
- the fixed schema selector returns exactly one canonical 32-byte word equal to
  the pinned schema/version; and
- fixed `dependencyBindingHash()` returns exactly one canonical 32-byte word
  equal to the resolver-computed dependency binding.

The normative interface appendix must pin the dependency-binding domain and
exact `abi.encode` tuple. At minimum it commits the bound Core, split factory,
artist registry, their live runtime code hashes and required interfaces/
markers/schemas, and the allowed split-wallet runtime code hash. The resolver
computes that digest independently from its constructor arguments and rejects
construction unless the adapter's immutable digest is equal.

Each construction probe uses fixed calldata, zero value, available-gas
`STATICCALL`, one exact fixed return length, bounded copy, canonical decoding,
and no returndata bubbling or dynamic returndata allocation. Revert,
out-of-gas, fallback-only success, short/oversized/malformed return, or a
noncanonical boolean fails construction.

Before every validation call, the resolver compares the live adapter
`extcodehash` with the pinned hash. Because the code hash binds the constructor
immutables in deployed runtime, a matching code hash plus the response
commitments below binds the same reviewed implementation and dependency set on
every use.

Every validation request carries the complete dependency tuple and binding
hash. The adapter rejects a request if any dependency address, code hash,
interface, marker, schema, or wallet-code fact differs from its own immutables.
The resolver includes the same tuple and binding hash in the full-intent digest.

There is no setter, rebind path, mutable implementation pointer, registry
lookup, or emergency override for the adapter. Replacing the adapter requires
deploying a new resolver and following the normal Registry V2 registration,
state-continuity, and governed Core-pointer replacement process. The old
resolver and its adapter remain immutable historical evidence.

### A4. Validation uses exact typed calls and exact canonical responses

Each supported write operation has a dedicated, fixed-width, versioned adapter
entry. No entry accepts an arbitrary selector, target, dynamic `bytes`, or
operation-dispatch enum. The pre-implementation normative interface appendix
and freeze commit must identify the exact selector, request tuple, request
calldata length, result tuple, result length, digest domains, magic, reserved
words, and canonical encoding for every extracted operation; absence is
prohibition. The adapter rejects any short request, oversized request, or
otherwise trailing calldata. Implementation remains blocked until that
complete transcript packet is independently reviewed and approved.

For each write, the resolver:

1. acquires its non-reentrant lock;
2. validates the relayer/caller, `msg.sig`, Governance V2 context or exact
   recorded artist-authorization context, action ID, action class, scope, and
   current state resolver-side; a royalty-freeze relayer need not be the artist;
3. computes a local full-intent digest;
4. verifies the live adapter code hash; and
5. performs the exact typed, zero-value `STATICCALL`.

The full-intent digest must use an implementation-versioned domain and
`abi.encode`. It binds at least:

- `block.chainid`, resolver address, bound Core, adapter address, pinned adapter
  code hash, versioned interface, marker, and schema;
- the dedicated validation-entry selector and resolver write selector;
- authenticated caller and, where applicable, Governance V2 action ID, class,
  scope hash, old-state hash, and new-state hash;
- revenue class, assignment scope and ID, current assignment/snapshot/freeze/
  continuity/counter context consumed by the transition;
- the complete requested assignment, profile, bps, policy, loosening, freeze,
  snapshot, continuity, or nonce fields for that operation; and
- every expected dependency address, interface, code hash, and immutable
  context used by validation.

Every adapter entry returns one operation-specific, fixed-length ABI tuple.
Every such tuple begins with:

1. a fixed implementation-versioned magic value;
2. the exact echoed full-intent digest; and
3. an observations digest over the full-intent digest and every external
   dependency observation; and
4. a result digest over the full-intent digest, observations digest, and every
   remaining returned word.

The remaining fixed-width words return every computed hash, identity, address,
numeric value, enum, and flag the resolver will use for the transition. A bare
boolean success result is forbidden. Unused words in an operation-specific
shape must be zero. The resolver independently recomputes both digests from the
exact returned words and compares every word before writing. Including the
full-intent digest in both derived digests prevents observations or results
from being transplanted between otherwise similar transcripts.

The approved pre-implementation transcript packet must pin the exact tuple and
byte length for each entry. The resolver must reject:

- wrong code hash, interface, marker, schema, magic, intent digest,
  observations digest, or result digest;
- fallback-only success or a return from an unrecognized selector;
- revert or out-of-gas;
- empty, short, oversized, or otherwise malformed returndata;
- nonzero upper bits in an address, boolean, bounded integer, or enum word;
- booleans other than zero or one, out-of-range enums, nonzero reserved bits,
  or nonzero unused words; and
- any returned value that differs from the resolver's authenticated request or
  locally expected transition.

The resolver uses bounded assembly returndata handling. It checks
`returndatasize()` against the one exact expected size before copying that
fixed size, uses no high-level call that allocates attacker-sized returndata,
creates no dynamic returndata object, and never bubbles adapter returndata.
Every failure occurs before mutation or event emission.

The transient non-reentrant lock is the only write permitted before validation.
Every Governance V2, artist, dependency, adapter, transcript, and state check,
including frozen-route and continuity computation, completes before the first
economic state write or event. After that first economic write the resolver
makes no external call. In particular, extraction must not make the current
post-write frozen-route append or any continuity update call the adapter. A
downstream internal failure after validation reverts the entire transaction,
including all resolver writes and events.

The complete `royaltyReceiverAndBps` callgraph remains storage/pure-only and
does not share an external-calling validation helper.

Preview functions, if an accepted implementation exposes any, are
informational only. A preview result cannot be cached, consumed, or presented
later to authorize a mutation; the mutation performs a fresh validation against
its current authenticated context.

### A5. Adapter reads are closed-world, caller-insensitive, and dependency-pinned

The adapter may make only the exact caller-insensitive read-only calls
enumerated by the approved pre-implementation interface packet and callgraph:

- authoritative collection and token-scope identity reads from the
  constructor-pinned Core;
- split-profile existence, wallet derivation, entry-hash, metadata-hash, and
  approved wallet-code facts from the constructor-pinned split factory;
- exact `profileId()` verification on a factory-derived wallet only after its
  nonzero address and runtime code hash match the constructor-pinned wallet
  code hash;
- exact `requireEconomicsConsent(uint256,bytes32,uint8,uint256,bytes32)` reads
  from the constructor-pinned artist registry, with exact zero-length success
  returndata; and
- exact `isRoyaltyFreezeAuthorized(uint256,bytes32)` reads from that registry,
  with one canonical 32-byte boolean result.

Those artist-registry results are dependency observations, not adapter
authorization decisions. The resolver remains the semantic consumer and sole
enforcer: it authenticates the relayer and exact recorded artist-authorization
context, commits the request, and accepts or rejects the transition after
checking the returned transcript. The adapter performs the physical
implementation-private `STATICCALL`, so the artist registry observes the
adapter as `msg.sender`. If this ADR is accepted, the later normative appendix
must reconcile the current "resolver must call" wording for economics consent
and royalty freeze to mean this resolver-owned enforcement with an exact
adapter-mediated observation; this Proposed ADR does not rewrite that
normative text.

The accepted implementation may use a strict subset of this list. Adding a
target, selector, callback, or observation outside the accepted list requires
a new reviewed architecture change. During resolver-to-adapter validation, the
adapter observes `msg.sender == resolver`; during each nested dependency call,
Core, factory, artist registry, or derived wallet observes
`msg.sender == adapter`. Only selectors whose result is independent of caller
identity are permitted. Neither the adapter nor a dependency may treat those
caller identities as Governance V2, artist, owner, or another authority.

Governance `currentAction()` verification, artist-authority decisions,
snapshot-caller authorization, action consumption, and nonce consumption stay
resolver-side. The adapter must not read Governance V2 authority state,
interpret Governance V2 action context, call the resolver, infer collection
identity from token arithmetic, or query an unpinned registry for a replacement
dependency.

Every direct dependency address, runtime code hash, interface, marker, and
schema is constructor-pinned in adapter runtime. The sole derived target is the
split wallet returned by the pinned factory; its exact allowed runtime code
hash is constructor-pinned. Immediately before every nested read, the adapter
checks the live target code hash against the pinned expected hash. All
dependency observations and derived identities are included in the returned
words and observations digest, and therefore in the resolver's exact comparison
before mutation.

Every nested read is a typed, zero-value, available-gas `STATICCALL` to the one
exact target and selector with fixed calldata, one exact fixed returndata
length, bounded copy, canonical decoding, and no bubbling or dynamic returndata
allocation. Each nested call site has its own closed external-call inventory
row.

A dependency revert, out-of-gas, missing code, runtime drift, malformed return,
noncanonical return, wrong interface, wrong marker/schema, mismatched wallet,
or mismatched observation fails closed. The adapter has no resolver callback,
so there is no adapter/resolver recursion path. A malicious external dependency
that attempts a resolver callback encounters the resolver's already-acquired
non-reentrant lock.

### A6. Every validation-layer call forwards available gas and creates no new GGP

The resolver-to-adapter call and every adapter-to-Core/factory/artist/wallet
read are exact-code trusted infrastructure on a state-changing path. Each uses
`staticcall(gas(), ...)`, with normal EIP-150 retention, fixed calldata, exact
fixed-length returndata handling, and no fixed or caller-selected call-gas
parameter. These calls are `AVAILABLE_GAS`, not bounded-gas or capped-gas
calls. Only their calldata and returndata shapes are bounded.

This is the narrow issue #669 disposition:

- every resolver-constructor adapter handshake probe, every resolver-to-adapter
  validation call site, and every adapter-to-Core/factory/artist/wallet call
  site must each be present in the closed external-call inventory as an
  exact-code, `AVAILABLE_GAS`, fail-closed `STATICCALL`;
- the inventory and checker must prove every forwarded-gas expression is
  `gas()`/available gas, not a literal, immutable cap, calldata value, storage
  value, or overloaded existing parameter;
- static opcode and callgraph evidence must prove the exact target and
  selectors, bounded return handling, fail-closed behavior, and absence from
  the Core-facing royalty-read callgraph; and
- gas measurements must include cold dependencies, worst-case conformant
  returns, revert, out-of-gas, and repricing-sensitive mocks.

No twenty-third GGP is created, and no existing GGP is overloaded for any
validation-layer call. An `AVAILABLE_GAS` call is not a gas parameter and adds
no #684 row unless a later accepted design introduces an actual cap. Issue
#684 retains ownership of its existing parameter rows, values, floors, host
bindings, and measurement evidence. This ADR adds no parameter row and makes no
readiness claim about #684.

Available-gas forwarding is safe here only because a failure reverts the
authenticated write before any durable effect and the exact adapter and
dependency code identities are immutable. It is not precedent for untrusted
user callbacks, value-bearing calls, marketplace reads, or calls whose failure
must preserve liveness.

### A7. Deployment and evidence follow one acyclic adapter-first DAG

The production deployment graph is acyclic and ordered:

1. Deploy and verify every upstream dependency that the adapter candidate pins.
2. Materialize and deploy the adapter from canonical isolated creation
   bytecode with its exact immutable dependency arguments.
3. Retain the adapter creation receipt and verify its address, constructor
   arguments, full initcode hash, deployed runtime SHA-256, deployed runtime
   EVM Keccak/`EXTCODEHASH`, versioned ERC-165 handshake, marker, schema,
   dependency binding, source verification, and zero-owner/zero-role posture.
4. Materialize and deploy the resolver with the verified adapter address,
   deployed runtime EVM Keccak/`EXTCODEHASH`, interface, marker, schema, and
   dependency binding as exact constructor arguments.
5. Retain and verify the resolver receipt, constructor arguments, full initcode
   and runtime hashes, source verification, ownership/role handoff, and all
   other launch dependencies.
6. Register only the resolver for this topology as the live Registry V2 row.
7. Execute the ordinary Governance V2 Core-pointer install and any later
   pointer freeze.
8. Deploy, configure, or capture only downstream consumers after the resolver
   identity is final.

The adapter does not contain the resolver address, cannot call it, and is
deployed first. The resolver contains the already deployed adapter facts.
Therefore the topology creates no CREATE/CREATE2 address, initcode-hash, runtime
hash, profile, or candidate-identity fixed-point cycle.

The implementation PR must preserve the 37 ordinary module/profile entries and
add exact adapter facts only to the separate implementation-private dependency
inventory/instance surface, candidate-instance constructor dependencies, CREATE
ordering, fresh rehearsal result, address book, deployment manifest, source-
verification inputs, retained receipts, lockfile, and checksum bindings. That
surface must explicitly exclude the adapter from `registryEntries`, the
Registry V2 aggregate, module-type derivation, and pointer/module installation.
Rehearsal must prove the adapter has no ownership or role handoff and the
resolver completes its normal authority handoff.

Candidate evidence must carry the adapter's actual deployed-runtime EVM
Keccak/`EXTCODEHASH` in addition to SHA-256. It must prove that immutable
substitution and constructor encoding produced those exact deployed bytes, and
that the resolver constructor binds the same adapter address, deployed-runtime
hash, versioned interface, marker, and schema. A non-production fixture or
creation-bytecode hash is not production deployed-runtime evidence.

The current exact manifests and address books are unversioned singleton
catalogs. Historical broadcasts and manifests remain immutable historical
evidence and must not be rewritten to imply that an adapter existed. Before
adding adapter evidence, the implementation must introduce a versioned
contract-set catalog/schema: the exact pre-adapter singleton contract set is
retained as immutable version `1`, the adapter-first set is a fresh version
`2`, and every manifest/checker binds and validates the exact version and
content hash that applied to its capture. Validators must continue to validate
old manifests against version `1` unchanged rather than comparing them with
the current version `2` singleton.

The adapter-first graph uses a fresh canonical rehearsal and candidate capture
under version `2`. Before that evidence can be captured, rehearsal must first
repair its stale resolver construction: the existing seven-argument path does
not represent the current eleven-argument resolver dependency set and omits the
current artist and Governance dependencies.

Issue #656 owns candidate identity and evidence, issue #677 owns canonical
executor/evidence wiring, and issue #658 owns the final release/Slither
regeneration. #656 and #677 own the deployed-runtime EVM Keccak and exact
constructor-binding proof. Their outputs must consume the merged adapter-first
graph rather than duplicating or guessing it.

### A8. Hostile tests cover identity, returns, dependencies, and atomicity

Before acceptance of an implementation, focused and integration tests must
cover at least:

- differential golden vectors against the repaired monolithic reference and
  the normative revenue specification, proving identical storage state,
  assignment/policy/preimage hashes, event topics/data, revert classes,
  freeze, snapshot, counter, continuity, and `royaltyReceiverAndBps` outputs for
  every conformant and failing sequence;
- zero/non-contract adapter, wrong code hash, interface ID, selector XOR,
  marker, version, schema, dependency-binding hash, validation-request
  dependency tuple, constructor dependency, and immutable argument;
- runtime code drift after construction and drift between a preflight read and
  the validation call;
- reverting, out-of-gas, missing-function, and fallback-only adapters;
- empty, every short length, every oversized length, malformed ABI,
  noncanonical address/bool/uint/enum/reserved words, wrong magic, wrong echoed
  intent, wrong observations digest, wrong result digest, and mutation of every
  returned field;
- each allowed dependency returning missing code, wrong code hash/interface/
  marker/schema, revert, nested out-of-gas, short, oversized, malformed,
  noncanonical, or semantically mismatched data;
- a factory-derived wallet with zero address, wrong runtime, wrong profile ID,
  and profile/code/hash drift;
- adapter or dependency attempts to reenter resolver write paths;
- adapter attempts to interpret resolver `msg.sender` as Governance, artist,
  owner, or another authority;
- wrong Governance caller, selector, action ID, class, scope, old state, new
  state, artist consent, nonce, freeze, snapshot, counter, and continuity
  context;
- direct and signed nonce reuse, stale preview reuse, stale Governance/artist
  context, old/new-state drift, and event/preimage mismatch; and
- exact atomic rollback: no nonce consumption, counter change, snapshot,
  assignment, freeze, continuity change, or event on any failed validation or
  downstream revert; and
- exact size-checker boundaries for each contract: runtime 22,576 passes and
  22,577 fails; full initcode including encoded constructor arguments 47,152
  passes and 47,153 fails.

Positive tests must recompute every intent, observation, assignment, policy,
state, event, and continuity commitment independently from stored inputs.
Opcode and callgraph tests must prove the adapter cannot write state, receive or
send value, deploy code, delegate, authorize, call the resolver, or reach any
`CALL` opcode; only the enumerated `STATICCALL` sites are reachable. A separate
static proof must continue to show no external-call or creation opcode is
reachable from `royaltyReceiverAndBps`.

### A9. Both contracts require independent production-size and release proof

After every patch that changes either runtime, and again on the final merged
base, the implementation work must record for both the adapter and resolver:

- exact optimized Solidity 0.8.19 via-IR runtime bytes and EIP-170 margin;
- exact creation bytecode and full initcode, including encoded constructor
  arguments, plus exact EIP-3860 margin;
- creation/initcode hashes, deployed-runtime SHA-256, and deployed-runtime EVM
  Keccak/`EXTCODEHASH`; and
- the exact canonical isolated-build receipt and compiler inputs.

Passing either protocol limit by one byte is not sufficient. This ADR requires
both contracts to preserve an explicit 2,000-byte margin, matching the
production Core runtime-margin policy:

- each deployed runtime must be no larger than 22,576 bytes under EIP-170; and
- each full initcode, including exact encoded constructor arguments, must be no
  larger than 47,152 bytes under EIP-3860.

The exact remaining runtime and initcode margins must be recorded after every
relevant patch and on the final canonical isolated build. If transcript
handling, release-evidence discipline, or any other required behavior leaves
either contract with less than either required 2,000-byte margin,
implementation acceptance stops for an accepted versioned redesign; required
behavior must not be stubbed or dropped to fit.

Final validation includes:

- full optimized via-IR build;
- focused and full Foundry suites;
- Slither;
- static opcode and callgraph proofs;
- the closed issue #669 external-call inventory and available-gas disposition;
- a release checker that fails either target above 22,576 runtime bytes or
  above 47,152 full-initcode bytes and binds the exact encoded constructor
  arguments, runtime SHA-256, and deployed-runtime EVM Keccak;
- canonical deployment rehearsal and source-verification checks;
- the documented release/checksum chain;
- the Windows aggregate gate; and
- the repository whitespace/diff gate.

Measurements from an aggregate build are diagnostic. Production claims must
come from the canonical isolated release build on the final serialized base.
No size result, test pass, or Proposed/Accepted ADR is a readiness claim.

## Security Impact

This design adds one immutable call boundary to resolver write paths. It does
not add a mutable trust root or second authorization system. Exact deployed
code, closed dependency reads, a locally computed intent digest, exact return
shape, and resolver-side comparison prevent the adapter from substituting a
different request or silently deciding authority. Acquiring the resolver lock
before validation and writing only afterward makes callback and partial-effect
failures atomic.

The principal security cost is write-path denial of service if the exact
adapter or one of its exact dependencies becomes incompatible with the active
gas schedule or returns failure. The architecture intentionally fails closed:
there is no fallback validator and no bypass. Recovery requires deploying a
new resolver, proving continuity, registering it, and changing the Core pointer
through Governance V2. This is consistent with ADR 0007 immutable
redeployment, but it increases operational work during an incident.

The Core marketplace read path does not gain the adapter call and retains ADR
0008's fail-soft, gas-bounded behavior. The adapter never receives funds and
cannot affect royalty payment custody.

## Release Impact

This ADR PR changes only this record and the ADR index. It does not change
source, ABI artifacts, specifications, catalogs, profiles, candidates,
deployment scripts, manifests, checksums, release notes, maturity language, or
readiness state.

If accepted, the later implementation and normative-reconciliation changes
will affect at least the resolver constructor and implementation-private
interface, the new implementation-private dependency inventory/instance
surface and its versioned contract-set schema/checkers, candidate dependency
graph, canonical CREATE ordering, fresh rehearsal and candidate capture,
address book, resolver-only Registry V2 module evidence, source verification,
external-call inventory, dual runtime/initcode margin checker and boundary
tests, runtime SHA-256 and deployed EVM-Keccak proof, release manifest,
lockfile, and checksum bundle. The 37 ordinary module/profile entries,
Permanent Core ABI, and Core bytecode remain unchanged.

## Test Plan

The implementation test plan is the complete hostile matrix in decision A8,
the dual-contract size and evidence gates in A9, and the deployment-order
proofs in A7. The ADR-only slice runs Markdown-link, changelog-consistency, and
whitespace checks. It does not use passing documentation checks as evidence
that the proposed contracts exist or are conformant.

## Rollout Plan

1. Review this two-file ADR slice while issue #670 implementation remains
   frozen.
2. Accept, revise, or reject the ADR in a separate explicit decision. A draft
   PR or CodeRabbit approval is not acceptance.
3. After ADR acceptance, publish and independently approve the complete
   normative interface appendix and freeze commit: exact entries, selectors,
   request calldata lengths, ERC-165 XOR, marker, schema, domains, magic,
   request/result tuples, observations/result digests, reserved words,
   canonical encodings, and fixed returndata lengths.
4. Only after that interface freeze, reconcile the normative revenue
   specification and conformance matrix, then implement the adapter, resolver,
   and focused tests.
5. Measure both contracts after every runtime or constructor/initcode change.
   Stop implementation acceptance immediately if either contract exceeds
   22,576 runtime bytes or 47,152 full-initcode bytes on any relevant patch or
   the final canonical isolated build.
6. Rebase the coordinator-defined shared-input train before regenerating
   catalog, profile, inventory, candidate, deployment, release, and checksum
   evidence in their documented ownership order.
7. Obtain independent security and integration review before publishing the
   implementation PR for merge consideration.

## Alternatives Considered

### Continue monolithic micro-optimization

Rejected. Two optimized measurements remain 5,591 bytes over EIP-170 after the
allowed reductions. Further local compression is not a credible route to the
2,000-byte runtime margin required by this ADR and would create pressure to
omit required semantics.

### Narrow the Permanent resolver behavior or keep advertised stubs

Rejected. The Permanent Core pointer ID and complete genesis resolver behavior
are launch requirements. An ERC-165 claim backed by missing or zero-valued
semantics is nonconformant.

### Add resolver logic or ABI to StreamCore

Rejected. Issue #670 authorizes no Core ABI or bytecode spend, and the current
Core already fails its separate production-headroom gate.

### Proxy, delegatecall, facet, or mutable implementation pointer

Rejected. These shapes move code without preserving the immutable state and
authority proof, add upgrade governance and storage-layout risk, and conflict
with ADR 0007. This ADR creates no exception for them.

### Put resolver state or authorization in the adapter

Rejected. Multiple state owners or authority boundaries create replay,
atomicity, continuity, and event-order ambiguity. The adapter is validation-
only and cannot authorize.

### Register both contracts as modules

Rejected. Core has one Permanent royalty-resolver pointer and Registry V2 row.
Registering the helper would expose an implementation detail as a replaceable
protocol authority and complicate continuity.

### Add a fixed gas cap or a new Governed Gas Parameter

Rejected. A fixed cap reintroduces issue #669's repricing failure. A new GGP
would create a twenty-third parameter and mutable policy for an exact-code,
fail-closed internal write dependency. Available-gas forwarding with bounded
returndata is the narrower design.

## Non-Goals

- No adapter, resolver, interface, test, script, catalog, profile, candidate,
  manifest, or release-artifact implementation in this ADR PR.
- No change to Core code, Core ABI, the `0x54f77a09` royalty-pointer interface,
  or Core's gas-capped fail-soft marketplace read.
- No change to artist-registry implementation architecture.
- No new governance role, nonce namespace, pointer family, module type, GGP,
  probe, emergency bypass, mutable dependency, or recovery shortcut.
- No specification finality, audit completion, deployment authorization,
  release, or readiness claim.

## Accepted Risks

These risks are proposed, not accepted, until this ADR is explicitly accepted:

- One additional exact-code dependency increases deployment, verification,
  audit, and monitoring surface.
- A defect or gas-schedule incompatibility in the immutable adapter can halt
  resolver writes until a new resolver is deployed and governed into service.
- Adapter replacement necessarily changes the resolver address and requires
  the full continuity and pointer-replacement process.
- Exact intent/observation comparison duplicates some work across the resolver
  and adapter and increases write gas.
- Available-gas forwarding allows a failing adapter call to consume most of a
  transaction's gas, although EIP-150 retains parent gas and all state remains
  atomic.

These risks are considered preferable to an undeployable monolith, omitted
royalty semantics, mutable upgrade indirection, or a second authority/state
owner.
