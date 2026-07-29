# ADR 0021/0022 Validation Adapters: Security Freeze Gates

## Status

**Execution authorized only for bounded, reversible pre-freeze measurement
prototypes. Packet publication, packet acceptance, normative freeze, production
source implementation, deployment, and readiness promotion remain blocked
until the evidence gates in this document pass.**

This document records security invariants and stop gates for the candidate
interface packets:

- [ADR 0021 revenue adapter packet](0021-revenue-resolver-validation-adapter-interface-packet.md)
- [ADR 0022 artist adapter packet](0022-artist-registry-validation-adapter-interface-packet.md)

Its machine-readable companion is
[`security-evidence-gates-v1.json`](../../release-artifacts/issue-670-adapter-freeze/security-evidence-gates-v1.json).
Both artifacts are based on `origin/main`
`8a045029185efc807edeac08d6f76b95c4387dd1`.

This document does not accept ADR 0022, approve either candidate packet,
choose an unresolved protocol design, freeze an interface, authorize production
implementation, supply missing measurements, or authorize deployment.

## Bounded pre-freeze measurement authorization

The user authorized execution without another approval pause only to remove
the evidence deadlock that otherwise requires final gas or byte-size facts
before implementation can start. The authorization is limited to isolated,
reversible measurement prototypes and harnesses that:

1. implement only enough candidate behavior to measure compiler output,
   calldata/returndata handling, EIP-150 reserves, and direct callsites;
2. use no production address, key, RPC secret, broadcast, registration,
   governance action, pointer install, release candidate, or readiness claim;
3. do not replace a missing normative decision with an implementation choice;
4. do not mark a gate passed without retained, independently reproducible
   evidence; and
5. may be discarded or revised when a packet decision changes.

The authorization does not permit a measurement result to silently become a
normative constant. Measured gas, byte sizes, compiler inputs, runtime hashes,
and initcode hashes remain absent until produced. Packet publication and
acceptance remain blocked until the applicable evidence is recorded and
reviewed.

## Shared non-negotiable invariants

The following rules apply to both host/adapter pairs:

1. The host contract is the only authority and state owner. Adapter success is
   validation evidence, never independent authorization.
2. The host acquires its contract-wide non-reentrant lock before validation or
   any external call.
3. Except for the transient lock, no state, nonce, replay bit, record, payload
   index, signature evidence, counter, continuity fact, or normative event may
   change before the complete transcript is accepted.
4. Every request binds the chain, host, adapter, live adapter code hash,
   versioned interface, marker, schema, dependency binding, adapter selector,
   host write selector, authenticated actor, current/replay state, and every
   operation-specific field consumed by the transition.
5. The host independently recomputes the request, observations, result hashes,
   canonical words, reserved-word rules, and semantic result values. Digest
   equality alone is insufficient.
6. Empty, short, oversized, trailing, malformed, noncanonical, wrong-selector,
   wrong-codehash, wrong-domain, wrong-intent, wrong-observation,
   wrong-result, nonzero-reserved, revert, and out-of-gas outcomes fail closed.
   Revert data is not bubbled and returndata copying is bounded.
7. The host rechecks every mutable host fact whose staleness could affect the
   transition after transcript acceptance and before mutation.
8. No external call occurs after the first durable write.
9. Any failure reverts the transient lock and every attempted effect. No nonce,
   replay consumption, counter, assignment, freeze, snapshot, record,
   continuity append, payload, signature evidence, or event may survive.
10. Adapter address, runtime code hash, interface, marker, schema, and
    dependency binding are constructor-pinned. Every validation call rechecks
    live adapter code.
11. Neither adapter has mutable storage, authority, payable behavior, fallback,
    receive function, proxy, `DELEGATECALL`, `CALLCODE`, deployment opcode,
    `SELFDESTRUCT`, arbitrary direct target, arbitrary selector, or generic
    router.
12. Replacement requires a new host deployment, continuity proof, Registry V2
    registration where applicable, and governed pointer replacement. There is
    no setter, rebind, bypass, or mutable implementation path.

## Revenue resolver: exact host and adapter boundaries

### Resolver-host-only calls

The resolver owns authorization and may make these exact host-side reads while
the lock is held:

| Target | Exact read | Required use |
| --- | --- | --- |
| Governance V2 | `currentAction()` | Default primary set/replace/clear and every Governance-routed primary freeze; byte-identical pre/post transcript |
| Core | `getSatellitePointer(bytes32)` | Active mint-manager discovery for O9 |
| Active mint manager | `mintLedger()` | Exact constructor-pinned ledger identity for O9 |
| Mint ledger | `isManagerOperationRootUsed(address,bytes32)` | Canonical true for the authenticated manager and root |
| Core | `preparedMint(uint256)` | Exact existing token operation and collection identity |

The adapter must not call Governance V2, Core pointer discovery, the mint
manager, the mint ledger, `preparedMint`, or the resolver.

For O9 create, the resolver completes the whole manager/pointer/ledger/Core
proof before the adapter, accepts the adapter transcript, repeats all proof
reads, and requires the same proof hash before writing. O9's idempotent no-op
and mismatch/rejection paths complete one full host proof but make no adapter
call, produce no adapter transcript, change no state, and emit no event.

### Adapter direct callgraph

The revenue adapter may issue only zero-value, available-gas `STATICCALL`s to:

| Target | Allowed selectors |
| --- | --- |
| Pinned Core | `lastAllocatedCollectionId()`, `tokenCollectionIdentity(uint256)` |
| Pinned split factory | `profileExists(bytes32)`, `splitWalletExists(bytes32)`, `walletFor(bytes32)`, `profileEntriesHash(bytes32)`, `profileMetadataURIHash(bytes32)` |
| Factory-derived wallet with the allowed live runtime code hash | `profileId()` |
| Pinned artist registry | `requireEconomicsConsent(uint256,bytes32,uint8,uint256,bytes32)`, `isRoyaltyFreezeAuthorized(uint256,bytes32)` |

The asset-policy registry has no adapter callsite in V1. Its pinned identity and
live code hash remain committed dependency facts. Every direct dependency code
hash is checked before use; the derived wallet code hash is checked before its
one read. The artist reads must be caller-insensitive because they observe the
adapter as `msg.sender`. The resolver remains the semantic authority.

`royaltyReceiverAndBps(address,uint256,uint256,uint256,bool)` and every other
marketplace royalty read remain storage-only and cannot reach the adapter or
any external contract.

### Revenue replay and rollback

- Default primary operations and governed freezes bind one exact Governance
  action and require an exact pre/post `currentAction()` match.
- Collection/token owner routes bind zero Governance words and recheck owner,
  assignment, template, freeze, and counter state before mutation.
- O9 binds the authenticated active manager, used operation root, prepared
  operation ID, prepared collection, pointer facts, ledger facts, and
  snapshot-proof hash.
- O9 separately binds the source per-key assignment hash, immutable assignment
  policy hash, canonical source royalty hash, token per-key next hash, and
  canonical token royalty return hash. Artist consent receives only the token
  per-key `nextAssignmentHash`.
- A complete O9 no-op returns the recomputed canonical token royalty hash
  without mutation. Any partial or inconsistent existing state rejects.
- All mutable-descendant counters remain resolver-owned and use the exact
  create/replace/clear/freeze deltas in the candidate packet.

## Artist registry: signer and external-call boundary

### Registry-host-only dependencies

Core, role-registry, Governance V2, pointer, finality-registry, and predecessor-
registry reads remain registry-side. They occur under the registry lock and
before the adapter call. Their exact addresses, constructor/runtime code
hashes, selectors, calldata, return lengths, canonical decoders, and semantic
predicates must be frozen before acceptance.

The artist adapter must not call any of those dependencies or call back into
the registry directly.

### Allowed direct and transitive signer execution

The artist adapter has only these direct execution targets:

1. the fixed `ecrecover` precompile for an EOA proof; and
2. the exact request-bound ERC-1271 signer for
   `isValidSignature(bytes32,bytes)`.

An ERC-1271 signer is opaque adversarial code. Under the adapter's zero-value
`STATICCALL` and the exact per-signer GGP cap, it may perform arbitrary
transitive static execution, consume its cap, revert, return malformed data, or
attempt callbacks. Those transitive targets are not adapter-controlled
dependencies, are not dependency-pinned by this packet, and confer no
authority. Static context, the registry lock, bounded return handling, exact
magic comparison, the gas cap, and fail-closed transcript comparison contain
the execution.

### Ordered signer-proof rules

The candidate bundle is bounded to one through 33 canonical proofs:

- participant indices are strictly increasing and unique;
- participant index zero is the primary;
- collaborator positions use indices 1 through 32;
- a one-authority operation has exactly one proof at index zero;
- rotation has exactly two proofs, old authority at zero and new authority at
  one;
- duplicate indices, duplicate signers, reordered, missing, surplus, unlinked,
  or policy-ineligible proofs reject before the adapter call;
- the registry determines required participants for primary-only,
  all-collaborator, threshold, and quorum policies;
- at most one proof may use direct mode;
- the direct signer equals the registry-authenticated original `msg.sender`,
  uses empty inner signature bytes, and causes no signature call;
- every other proof uses EOA or ERC-1271 mode with nonempty bounded signature
  bytes;
- EOA mode requires no live code, canonical 64-byte EIP-2098 or 65-byte
  `(r,s,v)`, nonzero exact recovery, low `s`, and canonical `v`;
- ERC-1271 mode requires a nonzero registry-authenticated signer code hash, an
  exact live adapter recheck, the exact operation EIP-712 digest, one capped
  `STATICCALL`, exact accepted return shape, and fail-closed error handling;
  and
- the registry validates counts, ordering, identities, authority classes,
  modes, code hashes, nonce/deadline/timestamp rules, signature bounds,
  signer-set hash, and dynamic hashes before calling. The adapter repeats the
  canonical ABI, signature, code-hash, and digest checks.

Every signed operation uses the registry EIP-712 domain and an explicitly
frozen operation typehash. The full 57-row matrix must mark unsigned branches
`NONE`. `refuseArtistBinding` and `revokeArtistDelegation` require distinct new
typehash decisions; they cannot borrow an ambiguous digest. Typed intent and
record identities remain independent of raw signature representation. Raw
signatures enter only the signature-evidence dynamic hash, ordered
observations, and retained signature evidence.

### GGP source and revision

`StreamArtistRegistry` is the sole host and reader of
`ARTIST_ERC1271_VERIFY_GAS`. Its identifier, floor, genesis value, delayed
monotonic raise chain, revision, and evidence remain registry-owned. The
adapter has no GGP storage, getter, raise authority, alternate cap, or new gas
parameter.

The registry authenticates one live cap and revision before the adapter call.
The same pair is committed in the request and applied independently to each
ERC-1271 signer. The exact source getter/ABI for the revision is not yet frozen
and is a stop gate. A caller-selected cap, fixed adapter cap, shared
first-come signer pool, lower, emergency path, overloaded parameter, or
twenty-third GGP is forbidden.

## Core and finality dependency predicates

No address or runtime hash is supplied by this document. The accepted packet
must bind exact constructor identities and expected runtime code hashes and
must recheck live runtime code before every relevant read.

For steward sanction, the registry must prove and commit before the adapter:

1. the signer is the currently vested steward and
   `stewardAppointedAtBlock != 0`;
2. the effective non-forbidden capabilities include `CAP_SANCTION` from an
   operative artist-signed grant or separately executed terminal governance
   grant;
3. scope is collection-only, with token and other scope identifiers zero;
4. the collection is the exact binding for the same artist and generation;
   and
5. Core's one-way `collectionBurnsBlockedAtBlock(collectionId)` is nonzero and
   no greater than `stewardAppointedAtBlock`.

For steward recovery approval, the registry must additionally prove:

1. the named finality record is exact, current, and executed;
2. it is collection scope for the same Core and collection, with every
   non-collection identifier zero or absent under the frozen ABI;
3. the typed recovery manifest equals the exact finality-side staged recovery
   facts for the artwork-bytes-changing path; and
4. finality and burn-cutoff observations remain current at the lock-held
   transition point.

No steward fact is reusable across a different Core, collection, binding
generation, finality registry, finality record, recovery manifest,
appointment, or grant lineage. Exact selectors, calldata, returndata,
construction/runtime code hashes, current/executed predicates, one-way-latch
assumptions, same-transaction reread policy, state-digest preimages, and event
mappings remain mandatory evidence.

## Stop gates

All gates below are fail-closed. A missing artifact is a failure, not a waiver.

| Gate | Required evidence | Stop condition |
| --- | --- | --- |
| Normative freeze | Every revenue R1-R13 and artist AR-01-AR-33 disposition; complete field/signature/state/record/event matrices; explicit freeze commit | Any unresolved or contradictory decision |
| 57-write completeness | All 57 artist writes, including the 44 absent checkpoint writes; every Permanent nonempty read; exact empty behavior; records, events, history, continuity, and hostile tests | Any zero stub, omitted transition, or unproved read |
| Revenue transcript | Nine-entry candidate, all host-only branches, selectors/XOR, ABI lengths, 29-word results, O2/O3/O4/O9 matrices, five O9 hashes, and independent golden vectors | Any mismatch, alias, or unreviewed branch |
| Signature/replay | 57-row EIP-712/`NONE` matrix, two missing typehashes, signer bundle codec, per-operation signer modes, nonce/revocation/current/replay preimages, record/event vectors | Any ambiguous digest, replay namespace, signer policy, or timestamp |
| Dynamic ABI | Exact root/nested offsets, bounds, empty rules, aggregate signature/archival-proof transport, dynamic hashes, overflow and hostile vectors | Any unbounded, noncanonical, aliased, gapped, or trailing encoding |
| Revenue gas | Cold/warm nested EIP-150 measurements, maximum transcript handling, post-call and failure reserves, compiler/fork inputs | Any missing measurement or insufficient reserve |
| Artist GGP/gas | Exact cap/revision ABI, 1/2/33 mixed-signer reverse-composed reserves, maximum bundle/wallet class, failure reserve, #684 candidate-host evidence | Any mismatch, overflow, starvation, or unsupported worst case |
| External callgraph | Static opcode/callsite proof and issue #669 inventory matching this document; hostile callback/reentrancy/gas tests | Any extra direct target, selector, value path, state write, deployment, delegation, or generic router |
| Core/finality | Exact constructor/runtime identities, code hashes, selectors, canonical decoders, collection-scope/current/executed predicates, state preimages, reread rules, hostile vectors | Any unresolved dependency, stale read, wrong scope, or code drift |
| Static analysis | Slither and repository security checks on the final serialized source; every finding dispositioned with retained output | Missing output or unreviewed actionable finding |
| Runtime size | Optimized Solidity 0.8.19 via-IR runtime for each host and adapter, isolated compiler inputs and receipt | More than 22,576 bytes for any contract |
| Initcode size | Exact constructor encoding and full initcode for each host and adapter; initcode hash and receipt | More than 47,152 bytes for any contract |
| Size boundaries | Tests showing 22,576/47,152 pass and 22,577/47,153 fail | Missing or incorrect boundary behavior |
| Deployment evidence | Exact constructor arguments, initcode/runtime hashes, source verification, receipts, authority/GGP handoff, Registry V2/Governance V2 rehearsal, 39-contract/37-registry projection | Any mismatch, missing receipt, unexpected authority, or cyclic order |
| Release chain | Focused/full Foundry, release generators, manifest/lockfile/checksums, Windows aggregate gate, whitespace checks, independent security and integration review | Any failed or stale gate |

If gas, runtime size, or initcode size fails while preserving all required
behavior, work stops for a newly reviewed versioned architecture. Behavior may
not be omitted; no zero stub, waiver, second adapter, state split, proxy,
delegatecall, mutable dependency, emergency bypass, or overloaded GGP may be
introduced without a new explicit design decision.

## Current disposition

The topology, transcript, signature, dependency, and evidence shapes above are
security requirements for review. They are not accepted protocol decisions.
No measured gas, runtime size, initcode size, runtime code hash, initcode hash,
deployment address, or receipt is recorded here.

The next permissible work is limited to:

1. resolving missing normative decisions in reviewed text;
2. building bounded measurement prototypes under the authorization above;
3. retaining independently reproducible gas, size, callgraph, and static-
   analysis evidence; and
4. updating the gate artifact without marking publication or acceptance ready
   until every applicable stop gate passes.
