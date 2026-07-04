# Stream Artist Authority

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md). Its decisions are taken by
[ADR 0010](adr/0010-world-class-spec-pass.md) (decision D2) and
[ADR 0011](adr/0011-world-class-pass-round-2.md) (decision R7); it contains
no open questions.

This document is the normative home of the 6529Stream artist authority
model (ADR 0010 decision D2, single-sourced per ADR 0010 decision D3.1).
It defines how an artist is bound to a collection, how that binding is
proven, rotated, delegated, inherited, disputed, and revoked, how artist
consent gates minting, economics, and artwork finality, and how every
consumer surface must display attribution truthfully. Other specifications
cite this document; they do not restate its definitions.

6529Stream is permanent infrastructure for the 6529 network. The premise of
this document is that artist provenance must be provable from chain data
alone, without trusting the platform operator, for at least 50 years —
through artist key loss, artist death, estate administration, operator
turnover, and attribution disputes. Consent is the product (ADR 0010,
Accepted Risks).

## Design Summary

```text
StreamArtistRegistry (genesis satellite)
  - artist identity objects (artistId, current authority address, status)
  - two-sided collection bindings (operator proposes, artist accepts)
  - typed collaborator sets with per-collaborator acceptance
  - attribution state machine per collection binding
  - consent modes: ARTIST_SIGNED_POLICY | ARTIST_DELEGATED | PLATFORM_WORKS
  - phase-policy consent records consumed by StreamMintManager
  - economics consent records and artist royalty freeze authorizations
    consumed by the revenue resolver
  - ARTIST_SANCTION / PLATFORM_WORKS_DECLARATION finality components
    consumed by StreamArtworkFinalityRegistry
  - state-bound artist attestations with staleness reads
  - scoped, expiring, revocable delegations
  - artist content consent and unilateral content freeze between first
    mint and finality
  - key rotation staged behind a contest window with a pre-registered
    artist guardian set and arbiter-adjudicated identity recovery
  - successor designation, pre-signed estate directives, and
    permissionless estate activation after public notice
  - governed dormancy procedure with long public notice
  - append-only dispute, counter-statement, and revocation records with a
    governed, delay-classed, appealable arbiter
  - append-only third-party platform-works claims with an arbiter
    CONTESTED display state
  - artist-side approval of artwork-bytes-affecting finality recovery
  - onchain signature verification (EIP-712 + ERC-1271, GGP-governed gas)
  - onchain storage of verified signature bytes and identity documents
  - rolling record-chain accumulators for provable history completeness

Consumers
  - StreamMintManager: refuses artist-bound phases without verified consent
  - Revenue resolver: refuses artist-bound assignment changes without
    verified artist co-signature; applies artist royalty freezes
  - StreamArtworkFinalityRegistry: requires the artist sanction component;
    requires artist recovery approval for artwork-bytes-changing recovery
  - StreamMetadataRouter / renderers: expose attribution state in token JSON
  - StreamCollectionMetadata: stores display fields and record satellites;
    refuses post-mint content-affecting writes without artist content
    consent and applies artist content freezes
```

The registry holds authority truth. Display fields, statements, media, and
identity documents live in the
[`collection-metadata-contract.md`](collection-metadata-contract.md)
satellites and are evidence, not authority.

## Permanence Classification [AA-PERM]

Requirements are classified per [`docs/spec-policy.md`](spec-policy.md):

| Surface | Class |
| --- | --- |
| Artist identity semantics: `artistId` derivation, binding preimages, acceptance semantics, attribution states and numeric values, consent-mode semantics and numeric values, authority classes, sanction subject and record preimages, typehash strings, event schemas, canonical orderings, rotation contest and guardian semantics, content consent/freeze semantics, recovery-approval semantics, estate-activation semantics, platform-works claim semantics, the normative attribution JSON schema (`AA-DISPLAY`) | Permanent |
| `IStreamArtistRegistry`, `IStreamArtistConsent`, and the finality component read surfaces this registry implements | Permanent |
| The two-sided binding rule, the unverified-attribution display rule, the artist-sanction finality requirement, the platform-works immutability rule, the append-only record discipline | Permanent |
| `StreamArtistRegistry` genesis implementation, its storage layout, and its byte limits | Replaceable (genesis module behind the Permanent interfaces) |
| `ARTIST_ERC1271_VERIFY_GAS` value; dormancy notice, dormancy inactivity, rotation contest, estate-activation notice, and unavailability-recovery notice values above their immutable floors | Operational (governed parameters, excluded from finality identity) |
| Artist ceremony tooling, rehearsal evidence, and measurement artifacts (`AA-TOOLING`) | Operational |
| Outreach runbooks, dormancy evidence collection, estate onboarding, signature-suite re-attestation drills | Operational |

Changing a Permanent surface after deployment means declaring a successor
registry line; the deployed registry is never patched. A successor registry
must import the full append-only record history of its predecessor by
Merkle-proofed snapshot and must preserve every `artistId`.

## Relationship To Other Specifications [AA-HOME]

Single-sourcing map (ADR 0010 decision D3.1). This document owns the model;
the documents below own their storage and flows and cite this document:

1. [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   owns the finality registry, `FinalityComponentState`,
   `FinalityComponentExpectation`, `IStreamFinalityComponent`,
   `IStreamScopedFinalityComponent`, `STREAM_FINALITY_V1`,
   `STREAM_SCOPED_FINALITY_V1`, and `STREAM_FINALITY_COMPONENTS_V1`. This
   document owns the `ARTIST_SANCTION` and `PLATFORM_WORKS_DECLARATION`
   component semantics and the sanction subject/record preimages.
2. [`mint-policy-and-accounting.md`](mint-policy-and-accounting.md) owns
   phase policy, `policyHash`, `MintTicket`, mint execution order, and the
   operational phase pause flag, which lives outside the phase-config
   preimage and therefore outside `policyHash`
   (ADR 0011 decision R6). This document owns the consent-mode model and
   the consent records the mint manager must verify before registering or
   serving artist-bound phases.
3. [`revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   owns split profiles, templates, `assignmentHash`, freeze mechanics, and
   release authorization. This document owns the artist economics rights
   that constrain those flows for artist-bound collections.
4. [`collection-metadata-contract.md`](collection-metadata-contract.md)
   owns collection display metadata, record storage satellites, locks, and
   snapshots. `CollectionPeople.artistAddress` and collaborator display
   fields are display data; the registry binding defined here is the
   authority. The metadata contract's artist attestation storage adopts the
   state-bound payload defined here, and its content-affecting record
   families enforce the artist content consent and freeze reads of
   `AA-CONTENT` (ADR 0011 decision R7.2).
5. [`metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   owns token JSON mechanics: placement, scope-membership resolution, and
   rendering modes. This document owns the attribution states and the
   single normative attribution JSON schema (`AA-DISPLAY`); the renderer
   and collection metadata specs cite that schema and never restate or
   fork it (ADR 0011 decision R7.6).
6. [ADR 0004](adr/0004-admin-governance.md) owns roles, the canonical
   governance action ID (`STREAM_GOVERNANCE_ACTION_V1`), delay classes, and
   batch execution. Every governed action in this document stages through
   that one preimage; this document defines no second staged-operation
   preimage (ADR 0010 decision D3.4).
7. [`launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
   carries the checker-verified mirror rows for the domain constants and
   typehashes defined here.
8. [`launch-conformance-matrix.md`](launch-conformance-matrix.md) carries
   the deployment gates named in `Conformance Gates [AA-GATES]`.

## Roles And Authority Classes [AA-ROLES]

Platform roles are ADR 0004 governance roles, enumerated in the role
vocabulary home
([`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
[GOV-ROLES]); this document defines the authority of three:

```text
ROLE_ARTIST_REGISTRY_ADMIN   proposes bindings, declares platform works,
                             withdraws unaccepted proposals
ROLE_ATTRIBUTION_ARBITER     governed arbiter for attribution disputes,
                             platform-works contests, artist-unavailability
                             findings, identity recovery, and
                             post-revocation rebinding approval
ROLE_ARTIST_DORMANCY_ADMIN   initiates and completes the governed dormancy
                             procedure through staged governance actions
```

Every arbiter action stages through the canonical ADR 0004 governance
action under the `DELAYED` window class of
[`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
[GOV-WINDOWS] or a stricter class — never `IMMEDIATE` — and is subject to
the counter-statement and appeal rules of `AA-DISPUTE`
(ADR 0011 decision R7.7).

No platform role can accept a binding, sign a sanction, grant a delegation,
consent to policy or economics, rotate an artist key, or designate a
successor. Those actions require artist-side authority, classified as:

```solidity
enum ArtistAuthorityClass {
    AUTH_NONE,      // 0 invalid
    AUTH_ARTIST,    // 1 the bound artist address itself
    AUTH_DELEGATE,  // 2 an active scoped delegation (AA-DELEG)
    AUTH_SUCCESSOR, // 3 an activated artist-designated successor (AA-ESTATE)
    AUTH_STEWARD    // 4 a governance-appointed steward after dormancy
                    //   without designation (AA-DORMANCY)
}
```

Requirements:

1. Every artist-side record must store and emit the acting address and its
   `ArtistAuthorityClass` so consumers can permanently distinguish
   artist-authored, delegated, estate, and steward authority.
2. `AUTH_STEWARD` authority is restricted to `STEWARD_CAPABILITIES`
   (`AA-DORMANCY`); it must never satisfy new-work policy consent.
3. `AUTH_SUCCESSOR` authority is bounded by the capabilities granted in the
   activating designation or estate directive (`AA-ESTATE`).
4. Numeric values of `ArtistAuthorityClass` are pinned above, enter the
   numeric ID catalog, and are never reused with different meaning.
5. Zero addresses are invalid as artist, collaborator, delegate, successor,
   or steward addresses; there is no blessed `address(0)` authorizer
   anywhere in this document (ADR 0010 decision D8.3).

## Registry Module Identity [AA-MODULE]

`StreamArtistRegistry` is a genesis satellite in the mandatory deployment
profile. It exposes the canonical module identity surface defined in
[`stream-long-term-architecture.md`](stream-long-term-architecture.md)
(Satellite Versioning) with:

```text
streamModuleType() = keccak256("STREAM_ARTIST_REGISTRY")
```

Requirements:

1. The registry must be bound to exactly one `StreamCore` at deployment and
   must reject records for collections that do not exist in that Core.
2. The registry must be registered in the module registry and referenced by
   the Core satellite pointer family `ARTIST_REGISTRY` under the Core
   Satellite Pointer Policy of
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md);
   pointer moves follow that policy unchanged.
3. The registry must implement `IStreamFinalityComponent` and
   `IStreamScopedFinalityComponent` (owned by the umbrella spec) for the
   component semantics in `AA-SANCTION`.
4. State-changing registry functions must use checks-effects-interactions
   and a registry-wide reentrancy guard. The only external calls the
   registry makes are bounded ERC-1271 `staticcall`s (`AA-SIGVER`).
5. All registry writes are append-only records: no record is ever deleted
   or mutated; later records supersede earlier ones through the state
   machine and generation rules below.

## Artist Identity Objects [AA-IDENTITY]

An artist is a first-class registry object, not a per-collection address
field. This lets one rotation, succession, or dormancy event cover every
collection the artist is bound to.

```solidity
enum ArtistIdentityStatus {
    IDENTITY_NONE,      // 0 unallocated
    IDENTITY_ACTIVE,    // 1 normal operation
    IDENTITY_DORMANCY_NOTICE, // 2 dormancy initiated, notice running
    IDENTITY_SUCCEEDED, // 3 authority vested in successor or steward
    IDENTITY_CONTESTED  // 4 rotation veto or identity-compromise contest
                        //   pending arbiter resolution (AA-GUARD)
}

struct ArtistIdentity {
    bytes32 artistId;            // stable forever, derivation below
    address authorityAddress;    // current signing/acting address
    ArtistAuthorityClass authorityClass; // ARTIST, SUCCESSOR, or STEWARD
    ArtistIdentityStatus status;
    bytes32 identityRecordHash;  // canonical identity document hash
    string identityRecordURI;    // locator; hash is the commitment
    uint64 registeredAt;
    uint64 lastAuthorityActionAt; // liveness clock for dormancy
    uint256 nonce;               // unordered-nonce allocator hint only
                                 // (requirement 4); not a sequence bound
}
```

`artistId` derivation is Permanent:

```solidity
bytes32 artistId = keccak256(abi.encode(
    ARTIST_ID_DOMAIN,
    uint256(block.chainid),
    address(this),          // the registry
    address(firstAddress),  // the first bound artist address
    bytes32(identityRecordHash),
    uint256(registrationNonce) // registry-wide monotonic counter
));
```

Requirements:

1. `artistId` never changes across rotation, succession, dormancy, or
   registry succession. It is the durable join key for catalogues,
   museums, and indexers.
2. `identityRecordHash` commits to a canonical identity document (RFC 8785
   JSON) containing display name, biographical references, public-key
   history references, and — where the artist uses C2PA — the C2PA signing
   credential enumeration (`AA-C2PA`). The hash, not the URI, is
   authoritative. The identity document is the onchain commitment mapping
   an `artistId` to a human, so it joins the onchain-bytes and dual-family
   archival rules (ADR 0011 decision R7.10): the canonical document bytes
   must be stored in registry contract storage (SSTORE2-style permitted)
   at identity registration, bounded by `MAX_IDENTITY_RECORD_BYTES`
   (`AA-LIMITS`), readable via `identityRecordBytes(artistId)`, and
   `keccak256` of the stored bytes must equal `identityRecordHash`; a
   document exceeding the bound is rejected at registration. The document
   must additionally be mirrored under the dual-family archival rule with
   at least one verifiable receipt class
   ([`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-ARCHIVE]; ADR 0011 decisions R1 and R4) before any binding
   acceptance for the identity completes; the identity-archival gate
   (`AA-GATES`) enforces both halves. Log data never substitutes for the
   stored bytes.
3. Every authenticated artist-side action (acceptance, sanction, consent,
   attestation, delegation grant or revocation, rotation, designation,
   directive, dispute action) must update `lastAuthorityActionAt`.
4. Nonces are per-identity and unordered (ADR 0011 decision R10). Every
   typed payload in this document names a `uint256` nonce; the registry
   keeps a per-`artistId` consumed-value map (bitmap representation
   permitted) and consumes exactly the value a verified payload names. Any
   unused value may be consumed in any order — the registry must not
   require sequential consumption, so a Safe, estate DAO, or governor
   signer can hold multiple outstanding payloads whose relayed submissions
   land in unpredictable order. A consumed or revoked value is never
   reusable. The stored `nonce` field is an allocator hint (a value no
   payload has yet named), never a validity bound; signing tools should
   allocate increasing values so the highest-nonce-operative rules of
   `AA-ESTATE` behave intuitively. Nonce state is scoped to the named
   `artistId`: consuming or revoking a value in one identity's space can
   never invalidate a payload of another identity, and the conformance
   suite includes a reverse-order two-payload test plus a cross-identity
   isolation test (`AA-GATES`).
5. An address may control at most one `IDENTITY_ACTIVE` identity at a time.
   Museums resolving an address must still join through `artistId`, never
   through the address alone.

## Two-Sided Artist Binding [AA-BINDING]

Attribution is never a platform assertion (ADR 0010 decision D2.1). An
operator proposes; the artist accepts from the named address or by verified
signature. Until acceptance completes, the attribution is unverified
everywhere.

```solidity
enum ArtistConsentMode {
    CONSENT_UNSET,          // 0 collection not yet registered here
    ARTIST_SIGNED_POLICY,   // 1 every phase policy hash requires artist
                            //   signature; delegation not accepted for
                            //   policy consent
    ARTIST_DELEGATED,       // 2 policy consent may come from the artist or
                            //   an active scoped delegation
    PLATFORM_WORKS          // 3 immutable artist-less declaration
}

enum CollabPolicyMode {
    PRIMARY_ONLY,       // 0 primary artist authority alone acts
    ALL_COLLABORATORS,  // 1 primary plus every accepted collaborator
    THRESHOLD,          // 2 primary plus threshold-many collaborators
    COLLABORATOR_QUORUM // 3 threshold-many of the full accepted set;
                        //   the primary counts as one ordinary member
                        //   and is not mandatory (ADR 0011 decision R7.8)
}

struct CollaboratorRecord {
    address account;      // collaborator authority address
    bytes32 role;         // open vocabulary, see AA-COLLAB
    bytes32 shareLabelId; // split-profile label reference, see AA-ECON
}

struct CapabilityPolicyOverride {
    uint32 capabilityMask;  // AA-DELEG capability bits this row governs
    CollabPolicyMode mode;  // policy mode for those capabilities
    uint32 threshold;       // THRESHOLD / COLLABORATOR_QUORUM rows only
}

struct ArtistBindingProposal {
    bytes32 artistId;         // zero to allocate a new identity
    address artistAddress;    // proposed authority address
    bytes32 identityRecordHash;
    string identityRecordURI;
    ArtistConsentMode consentMode;      // must not be CONSENT_UNSET
    CollabPolicyMode collabPolicyMode;
    uint32 collabThreshold;             // THRESHOLD / QUORUM modes only
    CollaboratorRecord[] collaborators; // sorted, see AA-COLLAB
    CapabilityPolicyOverride[] capabilityPolicyOverrides; // see AA-COLLAB
    bytes32 reasonHash;
    string reasonURI;
}
```

The binding hash is Permanent:

```solidity
bytes32 collaboratorSetHash = keccak256(abi.encode(
    COLLABORATOR_SET_DOMAIN,
    collaborators // sorted ascending by (account, role, shareLabelId)
));

bytes32 capabilityPolicySetHash = keccak256(abi.encode(
    CAPABILITY_POLICY_SET_DOMAIN,
    capabilityPolicyOverrides // sorted ascending by capabilityMask;
                              // disjoint masks; empty array permitted
));

bytes32 bindingHash = keccak256(abi.encode(
    ARTIST_BINDING_DOMAIN,
    uint256(block.chainid),
    address(this),            // the registry
    address(core),
    uint256(collectionId),
    uint64(bindingGeneration),
    bytes32(artistId),
    address(artistAddress),
    bytes32(identityRecordHash),
    uint8(consentMode),
    uint8(collabPolicyMode),
    uint32(collabThreshold),
    bytes32(collaboratorSetHash),
    bytes32(capabilityPolicySetHash)
));
```

Acceptance is a pinned EIP-712 payload (ADR 0010 decision D3.5), signable
by an EOA or an ERC-1271 wallet, or satisfied by a direct transaction from
`artistAddress`:

```text
StreamArtistAcceptance(
    address core,
    uint256 collectionId,
    uint64 bindingGeneration,
    bytes32 bindingHash,
    bytes32 identityRecordHash,
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. `proposeArtistBinding` requires `ROLE_ARTIST_REGISTRY_ADMIN`, allocates
   the next `bindingGeneration` for the collection, computes `bindingHash`
   onchain, stores the proposal, and emits `ArtistBindingProposed`. It must
   revert if the collection has a `PLATFORM_WORKS` declaration, an
   unresolved prior generation in `CLAIMED` state, or a live generation in
   `ARTIST_ACCEPTED`, `ARTIST_SANCTIONED`, or `DISPUTED` state.
2. Acceptance must verify against the exact stored `bindingHash`. The
   acceptance therefore ratifies the artist address, identity record,
   consent mode, collaborator policy, capability policy overrides, and
   full collaborator set in one signature. Any change to any of those
   fields before acceptance requires a new generation.
3. Acceptance is valid only by direct call from `artistAddress` or by a
   verified `StreamArtistAcceptance` signature under `AA-SIGVER`. Platform
   roles must not be able to accept; there is no admin bypass. Artist and
   collaborator acceptance records are hashed under
   `ACCEPTANCE_RECORD_DOMAIN` (`AA-DOMAINS`) so acceptance evidence is
   recomputable from events like every other record.
4. The binding becomes authoritative (`ARTIST_ACCEPTED`) only when the
   primary artist and every listed collaborator have individually accepted
   (`AA-COLLAB`). Partial acceptance stays `CLAIMED`.
5. The named artist may refuse a `CLAIMED` proposal
   (`refuseArtistBinding`), and the proposer may withdraw it
   (`withdrawArtistBinding`); both terminate the generation as `REVOKED`
   with a coded reason and are evented.
6. Rewrites of an authoritative binding are impossible. Rotation of the
   authority address flows through `AA-ROTATE`; changes of artist require a
   revocation (`AA-DISPUTE`) plus an arbiter-approved new generation.
7. Every binding event includes `bindingGeneration` so history reconstructs
   without ambiguity. Generations are never reused.
8. Attribution-change history is fully evented with reason hashes; no
   binding state exists that events cannot reconstruct (`AA-RECON`).
9. Binding acceptance must exist (or `PLATFORM_WORKS` must be declared)
   before any mint phase policy for the collection can be registered
   (`AA-CONSENT`); attribution can never be pending while works are sold.

## Collaborator Sets [AA-COLLAB]

Collaborative and multi-artist works have first-class onchain standing
(ADR 0010 decision D2.1).

Role vocabulary is open `bytes32`; examples:

```text
keccak256("co-artist")
keccak256("studio")
keccak256("collective-member")
keccak256("fabricator")
keccak256("composer")
keccak256("software-contributor")
```

Per-collaborator acceptance uses a pinned EIP-712 payload:

```text
StreamCollaboratorAcceptance(
    address core,
    uint256 collectionId,
    uint64 bindingGeneration,
    bytes32 bindingHash,
    address collaborator,
    bytes32 role,
    bytes32 shareLabelId,
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. A binding may list up to `MAX_COLLABORATORS = 32` collaborator records,
   sorted ascending by `(account, role, shareLabelId)` with no duplicate
   `(account, role)` pairs; unsorted or duplicated sets revert.
2. Each collaborator must accept individually, by direct call from
   `collaborator` or by verified `StreamCollaboratorAcceptance` signature.
   Collaborator identities are `ArtistIdentity` objects with the same
   rotation, succession, dormancy, and delegation rights as the primary
   artist, scoped to their collaborator standing.
3. Each collaborator may submit state-bound attestations (`AA-ATTEST`) for
   the collection and appears in attribution displays with role and
   verification state. An unaccepted collaborator renders as unverified.
4. `collabPolicyMode` plus `collabThreshold` — pinned in `bindingHash` and
   ratified by every acceptance — define how many co-signatures
   artist-gated actions need:
   `PRIMARY_ONLY` requires the primary artist authority only;
   `ALL_COLLABORATORS` requires the primary plus every accepted
   collaborator; `THRESHOLD` requires the primary plus at least
   `collabThreshold` accepted collaborators; `COLLABORATOR_QUORUM`
   requires at least `collabThreshold` members of the full accepted set —
   primary and collaborators counted as equal members, no member
   mandatory — so a collective can act without any single unavoidable
   human (ADR 0011 decision R7.8). `collabThreshold` must be at least 1
   and at most the accepted-set size for the quorum mode. The binding's
   top-level mode applies to sanction, policy consent, economics consent,
   royalty freeze, content consent, content freeze, recovery approval,
   and revocation actions unless a `CapabilityPolicyOverride` row pins a
   different mode for a capability: override rows are sorted ascending by
   `capabilityMask`, masks must be disjoint and nonzero, and each row
   applies its mode and threshold to exactly the `AA-DELEG` capability
   bits it names (revocation of attribution follows the `CAP_DISPUTE`
   row when present). Per-capability designation exists so primary
   incapacity never stalls defensive actions: operator tooling should
   propose `COLLABORATOR_QUORUM` overrides for `CAP_DISPUTE`,
   `CAP_ROYALTY_FREEZE`, and `CAP_ATTEST` on every multi-collaborator
   binding.
5. `shareLabelId` references the split-profile label under which the
   collaborator is paid (`AA-ECON`). A zero `shareLabelId` declares an
   explicitly unpaid credited role and must be stated in the identity
   record; it is not a default.
6. The collaborator set is immutable per generation. Adding or removing a
   collaborator requires a new generation accepted by everyone, and is
   blocked once the collection has an executed finality record, because the
   sanctioned attribution set is part of the finalized promise.

## Attribution State Machine [AA-STATE]

Each collection binding generation carries one attribution state:

```solidity
enum AttributionState {
    ATTR_NONE,          // 0 no binding generation exists
    CLAIMED,            // 1 proposed, not fully accepted: unverified
    ARTIST_ACCEPTED,    // 2 two-sided binding complete
    ARTIST_SANCTIONED,  // 3 verified sanction over executed finality exists
    DISPUTED,           // 4 open dispute filed (AA-DISPUTE)
    REVOKED             // 5 terminal for the generation
}
```

Transitions (append-only; the state is derived from the record log):

```text
ATTR_NONE        -> CLAIMED            proposeArtistBinding
CLAIMED          -> ARTIST_ACCEPTED    final required acceptance recorded
CLAIMED          -> REVOKED            refuseArtistBinding |
                                       withdrawArtistBinding
ARTIST_ACCEPTED  -> ARTIST_SANCTIONED  collection-scope sanction verified
                                       and its finality record executed
ARTIST_ACCEPTED  -> DISPUTED           openAttributionDispute
ARTIST_SANCTIONED-> DISPUTED           openAttributionDispute
CLAIMED          -> DISPUTED           openAttributionDispute (arbiter only)
DISPUTED         -> prior state        resolveAttributionDispute(UPHELD)
DISPUTED         -> REVOKED            resolveAttributionDispute(REVOKE)
ARTIST_ACCEPTED  -> REVOKED            revokeAttribution (artist authority)
ARTIST_SANCTIONED-> REVOKED            revokeAttribution (artist authority)
REVOKED          -> DISPUTED           openAttributionDispute (arbiter
                                       reopen with new evidence;
                                       ARBITER_REVOKED generations only,
                                       AA-DISPUTE requirement 9)
REVOKED          -> (new generation)   proposeArtistBinding with
                                       ROLE_ATTRIBUTION_ARBITER approval
```

Requirements:

1. Numeric values are pinned above, enter the numeric ID catalog, and are
   never reused. The cross-contract ABI returns `uint8`.
2. Every transition emits `ArtistAttributionStateChanged` with old state,
   new state, generation, actor, authority class, record hash, and reason
   hash. No silent transitions exist.
3. `ARTIST_SANCTIONED` at collection level requires a verified
   collection-scope sanction whose finality record executed (`AA-SANCTION`).
   The elevation is recorded by a permissionless
   `confirmSanctionFinalized(collectionId)` call that checks the finality
   registry's stored `collectionFinalityRecord` for an executed record
   whose component set includes the collection's sanction record hash,
   then emits the state change; the registry never guesses execution.
   Scoped sanctions (token, release, season, view) do not change the
   collection-level state; consumers read them per scope.
4. While `DISPUTED`, the registry must reject new sanctions, policy
   consents, economics consents, delegation grants, and attestations for
   the collection; existing executed finality records are unaffected.
   Counter-statements (`AA-DISPUTE` requirement 8) remain recordable.
   Attribution state never gates operational incident response: the
   mint-path phase pause flag is not a registry consent, lives outside
   `policyHash`, and must remain operable by the mint-layer pause roles
   during any attribution state, including `DISPUTED` and `REVOKED`
   (ADR 0011 decision R6). What a dispute stops is minting itself: the
   per-mint `requireMintConsent` cadence (`AA-CONSENT` requirement 6)
   fails closed on `DISPUTED` at the next mint.
5. `REVOKED` is terminal per generation and prospective only: it changes
   display and future authority, and it never rewrites executed finality
   records, mint history, or economics history. Posthumous or corrective
   rebinding starts a new generation at `CLAIMED` and requires
   `ROLE_ATTRIBUTION_ARBITER` approval when the prior generation ended
   `REVOKED`, so an operator cannot spam re-claims over a repudiation.
   One append-only exception exists to per-generation terminality: a
   generation revoked by arbiter resolution (`ARBITER_REVOKED`) may be
   reopened with new evidence under `AA-DISPUTE` requirement 9;
   artist repudiations, refusals, and withdrawals are never reopenable.
6. Reads:

```solidity
function attributionState(uint256 collectionId)
    external view returns (uint8 state, uint64 generation);

function attributionBinding(uint256 collectionId, uint64 generation)
    external view
    returns (
        bytes32 bindingHash,
        bytes32 artistId,
        address artistAddress,
        uint8 consentMode,
        uint8 collabPolicyMode,
        uint32 collabThreshold,
        bytes32 collaboratorSetHash,
        uint8 state
    );
```

## Attribution Display And Token JSON [AA-DISPLAY]

Marketplaces, wallets, and archives consume token JSON, not registry
internals. The distinction between platform-claimed and artist-verified
attribution must reach them.

Canonical display strings for `AttributionState` (Permanent):

```text
claimed | artist_accepted | artist_sanctioned | disputed | revoked
```

This section is the single normative home of the attribution JSON schema
(ADR 0011 decision R7.6). Exactly one attribution object shape exists in
the spec set — the nested object below — and every emitting or citing
surface ([`metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
[MRR-ATTRIBUTION],
[`collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-PEOPLE] and [CMC-ATTRIBUTION-DISPUTES]) cites this schema rather than
restating it. The earlier flat fields
(`properties.provenance.attribution_status`,
`properties.provenance.artist_attestation_status`,
`properties.provenance.consent_mode`) are superseded by this object and
must not be emitted as normative surfaces.

Normative attribution object (Permanent; all values lowercase snake_case;
hashes and addresses are 0x-prefixed lowercase hex):

```text
properties.provenance.attribution = {
  state:               claimed | artist_accepted | artist_sanctioned |
                       disputed | revoked            (always present)
  works_class:         artist_bound | platform_works (always present)
  consent_mode:        artist_signed_policy | artist_delegated |
                       platform_works               (always present)
  artist_id:           bytes32 hex                  (artist_bound only)
  artist_address:      address hex                  (artist_bound only)
  binding_generation:  integer                      (artist_bound only)
  collaborators:       array per requirement 5      (when collaborators)
  attestation_status:  none | attested_current | attested_stale |
                       disputed                     (artist_bound only)
  attestation_record:  bytes32 hex                  (when one exists)
  attested_state_hash: bytes32 hex                  (when one exists)
  sanction_record:     bytes32 hex        (when a sanction covers the
                                           token's resolved scope)
  contested:           boolean            (platform_works only; true
                                           while or after a sustained
                                           contest, AA-PLATFORM)
  contest_record:      bytes32 hex        (when contested is true)
  c2pa_authorship_status: consistent | divergent | unevaluated
                                          (when stored C2PA records
                                           carry authorship assertions,
                                           AA-C2PA)
}
```

Requirements:

1. Until a binding reaches `ARTIST_ACCEPTED`, every consumer surface —
   token JSON, `contractURI`, operator frontends, marketplace feeds — must
   render the attribution as unverified (ADR 0010 decision D2.1). The
   default renderer satisfies this by emitting
   `properties.provenance.attribution.state = "claimed"` and must not
   present the artist name as verified fact in that state.
2. For artist-bound collections, default token JSON must include the
   attribution object above with every always-present and artist-bound
   field populated: `state` is resolved for the token's scope,
   `attestation_status` derives from `AA-ATTEST`, `attestation_record`
   and `attested_state_hash` carry the staleness-aware attestation record
   hash and its attested digest when one exists, and `sanction_record`
   carries the sanction record hash when a sanction covers the token, so
   the token JSON alone links a token to its onchain sanction record and
   binding generation. Platform assertion is never rendered as artist
   fact, and no conformant surface may omit, rename, re-case, or flatten
   these fields.
3. For `PLATFORM_WORKS` collections, default token JSON must include the
   attribution object with `works_class = "platform_works"`, must omit
   artist fields rather than fabricate them (`AA-PLATFORM`), and must
   emit `contested = true` plus `contest_record` while a platform-works
   contest stands or after one is sustained (`AA-PLATFORM` requirement
   6). Artist-bound collections expose `works_class = "artist_bound"`.
4. A token's displayed state is the highest-precedence applicable state:
   `revoked > disputed > artist_sanctioned > artist_accepted > claimed`.
   `artist_sanctioned` applies to a token when a verified collection-scope
   sanction exists, or when a verified scoped sanction covers that token's
   token, release, season, or view scope as published by collection
   metadata. The metadata router owns scope membership resolution and the
   JSON schema mechanics
   ([`metadata-router-and-renderer.md`](metadata-router-and-renderer.md));
   this section owns the states and semantics.
5. Accepted collaborators must be listed with role and verification state
   in the attribution object or a hash-committed attribution document
   referenced from it; the second artist of a duo is never reduced to an
   unverifiable offchain note.
6. Renderer conformance tests must cover all five states, both works
   classes, staleness, the disputed override, the contested
   platform-works display, and — as golden assertions — the presence and
   exact paths of `artist_id`, `binding_generation`, `sanction_record`,
   `works_class`, and `consent_mode` in the elected nested shape
   (`AA-GATES`; ADR 0011 decision R7.6).
7. Display locks never bind authority. The collection metadata
   `ARTIST_IDENTITY` lock and every similar display lock
   ([`collection-metadata-contract.md`](collection-metadata-contract.md),
   Lock Model) freeze display fields only; they must not block, and are
   never a precondition for, registry rotation, delegation, succession,
   dormancy, dispute, or revocation. The consequence matrix for a locked
   display identity is: pre-lock registry truth keeps governing display
   verification state; post-lock succession and rotation continue in the
   registry and are surfaced through attribution state and authority
   class (posthumous authority is `AUTH_SUCCESSOR`/`AUTH_STEWARD`-marked,
   never retroactive); and a locked-but-fraudulent display identity is
   repudiable through `AA-DISPUTE` with the registry state overriding the
   locked display field on every conformant surface.

## Signature Verification [AA-SIGVER]

All artist-side signatures in this document are verified onchain at
submission — never committed-but-unverified (ADR 0010 decision D2.6).

The registry is an EIP-712 verifying contract:

```text
EIP712Domain(string name,string version,uint256 chainId,
             address verifyingContract)
name    = "6529StreamArtistRegistry"
version = "1"
```

Requirements:

1. EOA signatures use ECDSA recovery under the one canonical-form rule
   that governs every ECDSA surface in the spec set,
   [`mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MPA-AUTHZ] rule 2 (ADR 0011 decision R7.10): the recovered address
   must be nonzero and must exactly match the required signer — a zero
   recovery result is a verification failure, never a wildcard (ADR 0010
   decision D8.3) — and non-canonical signatures are rejected: `s` above
   the secp256k1 half-order (EIP-2) or `v` outside `{27, 28}`. Stored
   signature bundles (requirement 6) therefore only ever contain
   canonical-form bytes, keeping 50-year evidentiary records free of
   malleated variants.
2. Contract signers use ERC-1271 `isValidSignature` through a bounded
   `staticcall` with `ARTIST_ERC1271_VERIFY_GAS`, a Governed Gas Parameter
   under the model home,
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP] (ADR 0010 decision D1) — floors, governance classes, probes,
   change events, manifest recording, and the Operational-layer exclusion
   follow the home unchanged. The floor is sized by measured Safe n-of-m
   verification (ADR 0010 decision D7.3); initial planning values are a
   90,000-gas floor and a 150,000-gas genesis value, and deployment
   records measured values in the release manifest.
3. The ERC-1271 call must use the EIP-150 63/64 parent-gas precheck against
   the current parameter value, capped returndata copying, and exact
   magic-value comparison. Failure, out-of-gas, malformed returndata, or a
   wrong magic value is a verification failure that reverts the submission
   before any state change.
4. The supported contract-wallet class is defined once at ADR 0004
   [GOV-1271-CLASS] and cited here, never redefined (ADR 0011 decision
   R10): any wallet whose `isValidSignature` completes within the
   verifying layer's Governed Gas Parameter — for this registry,
   `ARTIST_ERC1271_VERIFY_GAS`. Because the parameter is raisable, a
   future heavier wallet in that class can be supported without a
   registry redeploy.
5. Every typed payload includes `nonce` (consumed from the identity's nonce
   space) and, except long-lived designations and directives, `deadline`.
   Expired payloads revert. Replay across chains and registries is blocked
   by the EIP-712 domain; replay across Cores by the `core` field.
6. Verified signature bytes are stored onchain at submission, bounded by
   `MAX_STORED_SIGNATURE_BYTES = 4,096` (SSTORE2-style storage permitted),
   keyed by record hash and readable via `signatureBundle(recordHash)`.
   A signature bundle exceeding the bound is rejected at submission unless
   the submission carries a dual-family archival proof for the full bundle
   per ADR 0010 decision D4.6, in which case the registry stores the bundle
   hash and the archival record reference. Verification therefore never
   decays to trust in platform-hosted storage.
7. Signature suites are time-bounded evidence; re-attestation of
   finality-critical records under successor suites follows
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   (Hash And Manifest Discipline) and never rewrites stored signatures.

## Artist Delegations [AA-DELEG]

A delegation is an artist-signed, scoped, expiring, revocable grant to a
named signer (ADR 0010 decision D2.4). It replaces the previously undefined
"delegated artist signer" everywhere in the spec set.

Capability bits (uint32, pinned; unused bits must be zero):

```text
CAP_ATTEST            = 1 << 0   state-bound attestations
CAP_POLICY_CONSENT    = 1 << 1   phase policy consent (ARTIST_DELEGATED
                                 collections only)
CAP_ECONOMICS_CONSENT = 1 << 2   assignment co-signature
CAP_SANCTION          = 1 << 3   finality sanction
CAP_DISPUTE           = 1 << 4   open or withdraw disputes
CAP_ROYALTY_FREEZE    = 1 << 5   authorize the artist royalty freeze
CAP_INTENT_RECORDS    = 1 << 6   artist intent and preservation records
CAP_CONTENT_CONSENT   = 1 << 7   content-affecting write consent
                                 (ARTIST_DELEGATED collections only,
                                 AA-CONTENT)
```

Pinned typed payload:

```text
StreamArtistDelegation(
    address core,
    address delegate,
    uint256 collectionId,   // 0 = every collection bound to the artistId
    uint32 capabilities,
    uint64 notBefore,
    uint64 expiresAt,
    uint64 maxUses,         // 0 = unlimited within the validity window
    bytes32 constraintsHash, // canonical JSON of narrative constraints
    uint256 nonce
)
```

Requirements:

1. A delegation is granted by direct artist-authority call or verified
   `StreamArtistDelegation` signature, and recorded with
   `delegationRecordHash` (`AA-DOMAINS`). Grants and revocations emit
   events with capabilities, scope, and validity window.
2. `expiresAt` is mandatory and must be greater than `notBefore`; unbounded
   delegations do not exist. `maxUses` is enforced by a per-delegation use
   counter consumed on every delegated action.
3. The granting authority may revoke at any time
   (`revokeArtistDelegation`), by direct call or verified signature;
   revocation is immediate and evented. Rotation of the artist authority
   address (`AA-ROTATE`) does not revoke delegations; succession and
   dormancy completion (`AA-ESTATE`, `AA-DORMANCY`) revoke all outstanding
   delegations automatically.
4. A delegated action is valid only when the delegation is within its
   validity window, unrevoked, under `maxUses`, scoped to the collection,
   and carries the required capability bit. Delegated records store and
   emit `AUTH_DELEGATE` plus the delegation record hash.
5. `CAP_POLICY_CONSENT` is only usable on `ARTIST_DELEGATED` collections;
   the registry must reject delegated policy consent on
   `ARTIST_SIGNED_POLICY` collections regardless of the delegation's bits.
6. `CAP_SANCTION` delegation is permitted but operator tooling must warn:
   sanction is the strongest provenance statement, and artists should keep
   it undelegated. The sanction record's authority class makes any
   delegated sanction permanently visible.
7. Delegates never gain rotation, guardian-set, successor-designation,
   directive, delegation-granting, or revocation-of-attribution powers;
   those are non-delegable.

## Consent Modes For The Mint Path [AA-CONSENT]

The platform can never extend an artist-bound series without a verifiable
artist authorization chain (ADR 0010 decision D2.4). Consent modes pin, per
collection, what that chain must look like, and the mint manager enforces
it before any phase policy exists.

Pinned typed payload for policy consent:

```text
StreamArtistPolicyConsent(
    address core,
    address mintManager,
    uint256 collectionId,
    bytes32 phaseId,
    bytes32 policyHash,
    uint256 nonce,
    uint64 deadline
)
```

`policyHash` is the canonical phase policy fingerprint defined in
[`mint-policy-and-accounting.md`](mint-policy-and-accounting.md) (Policy
Fingerprints); this document does not restate its preimage. Because the
consent record binds the exact `policyHash`, the artist's signature covers
phase timing, gates, counters, executors, batch limits, and module pins —
the complete mintability policy. The phase pause flag is deliberately not
part of that preimage: the deployed phase-config preimage excludes the
pause field, pause state lives in a separate operational flag owned by the
mint-policy spec, and pausing or unpausing therefore never produces a new
`policyHash`, never constitutes a policy re-registration, and never
requires artist authorization (ADR 0011 decision R6). Emergency stop is an
operator incident-response action gated by mint-layer pause roles alone;
what the artist consents to is the unpaused mintability policy.

Mint-facing interface (Permanent):

```solidity
interface IStreamArtistConsent {
    function consentMode(uint256 collectionId)
        external view returns (uint8);

    function isPolicyConsented(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash
    ) external view returns (bool consented, bytes32 consentRecordHash);

    function requireMintConsent(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash
    ) external view;

    function requireEconomicsConsent(
        uint256 collectionId,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) external view;

    function isRoyaltyFreezeAuthorized(
        uint256 collectionId,
        bytes32 expectedAssignmentHash
    ) external view returns (bool);

    // content authority reads consumed by the collection metadata
    // contract and its satellites (AA-CONTENT)
    function requireContentConsent(
        uint256 collectionId,
        bytes32 familyId,
        bytes32 newStateHash
    ) external view;

    function isContentFreezeAuthorized(
        uint256 collectionId,
        bytes32 lockClass
    ) external view returns (bool authorized, bytes32 freezeRecordHash);
}
```

Requirements:

1. A collection's consent mode must be pinned in the registry — through an
   accepted artist binding (`AA-BINDING`) or a `PLATFORM_WORKS` declaration
   (`AA-PLATFORM`) — before the mint manager may register any phase policy
   for it. `requireMintConsent` reverts for `CONSENT_UNSET`.
2. Consent modes are immutable once pinned. `ARTIST_SIGNED_POLICY` and
   `ARTIST_DELEGATED` are ratified by the artist's binding acceptance
   (`bindingHash` includes the mode); `PLATFORM_WORKS` is immutable by
   declaration. No transition between modes exists on this registry line.
3. For `ARTIST_SIGNED_POLICY` collections, every phase policy registration
   and re-registration requires a verified `StreamArtistPolicyConsent` over
   the exact `policyHash`, signed by the artist authority
   (`AUTH_ARTIST` or an activated `AUTH_SUCCESSOR` whose grant includes
   policy consent), satisfying the collaborator policy (`AA-COLLAB`).
   Delegated consent is invalid in this mode.
4. For `ARTIST_DELEGATED` collections, the same requirement holds, except
   the consent may be produced by an active delegation carrying
   `CAP_POLICY_CONSENT` (`AA-DELEG`).
5. For `PLATFORM_WORKS` collections, no artist consent exists or is
   implied, and `requireMintConsent` succeeds on the declaration alone.
6. `requireMintConsent` must revert unless all of the following hold for
   artist-bound collections: attribution state is `ARTIST_ACCEPTED` or
   `ARTIST_SANCTIONED` (never `CLAIMED`, `DISPUTED`, or `REVOKED`); a
   consent record matches the exact active `policyHash`; and the economics
   prerequisite of `AA-ECON` requirement 4 is satisfied. The calling
   cadence is pinned (ADR 0011 decision R6): the mint manager must call it
   before registering or re-registering a phase policy and on every mint
   execution — once per mint transaction, before any token is created —
   not merely when the active policy hash changes. A dispute filed
   mid-drop therefore stops the next mint without any operator action,
   while the operational pause flag stays independently available in
   every attribution state
   ([`mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   mirrors this as a mint-path requirement under its bounded
   registry-read gas parameter).
7. Consent records are append-only and bound to `(collectionId, phaseId,
   policyHash)`. A changed policy produces a different `policyHash` and
   therefore requires fresh consent; stale consents authorize nothing.
8. Mint events for artist-bound collections must make artist authorization
   reconstructable per token: the consent record hash for the active
   policy is emitted at policy registration, and every mint event already
   carries the active `policyHash`, so the chain
   `token -> policyHash -> consentRecordHash -> verified signature` is
   complete from events alone.
9. Open-ended series gain per-release artist control structurally: each new
   phase (release, season, drop) has a new `policyHash` and therefore a new
   consent ceremony. Decades-long series remain artist-gated by
   construction, and a compromised platform signer cannot mint "new works
   by the artist" (ADR 0010 decision D2.4).

## Platform Works Declaration [AA-PLATFORM]

Collections with no natural author — protocol artifacts, platform editions,
test collections — declare it instead of leaving artist fields empty.

```solidity
bytes32 platformWorksDeclarationHash = keccak256(abi.encode(
    PLATFORM_WORKS_DOMAIN,
    uint256(block.chainid),
    address(this),
    address(core),
    uint256(collectionId),
    bytes32(statementHash),   // canonical declaration document hash
    uint64(declaredAt)
));
```

Requirements:

1. `declarePlatformWorks` requires `ROLE_ARTIST_REGISTRY_ADMIN`, must
   execute before any phase policy registration for the collection, and is
   immutable: a `PLATFORM_WORKS` collection can never gain an artist
   binding on this registry line, and an artist-bound collection can never
   be redeclared platform works. This prevents attribution laundering in
   both directions (ADR 0010 decision D2.3).
2. The declaration is evented and displayed (`AA-DISPLAY` requirement 3).
3. The declaration acts as the collection's finality component in place of
   the artist sanction (`AA-SANCTION` requirement 7).
4. Immutability does not mean uncontestability (ADR 0011 decision R7.5).
   `filePlatformWorksClaim(collectionId, evidenceHash, reasonHash,
   reasonURI)` lets any address assert third-party authorship of a
   declared collection's works — the misappropriation path the
   anti-laundering rule would otherwise leave permanently silent. Claims
   are append-only, permissionless, evented
   (`PlatformWorksClaimFiled`), and hashed under
   `PLATFORM_WORKS_CLAIM_RECORD_DOMAIN`; both hashes must be nonzero and
   commit to canonical evidence documents stored through the metadata
   record satellites and dual-family mirrored (`AA-DISPUTE` requirement 2
   evidence discipline). Claims never mutate the declaration and grant
   the claimant no authority.
5. `ROLE_ATTRIBUTION_ARBITER` may elevate a filed claim by setting the
   declaration's contest state to `CONTESTED`, and must later resolve it
   to `CONTEST_DISMISSED` (restoring normal display) or
   `CONTEST_SUSTAINED` (the contested display becomes permanent and the
   sustaining resolution record is linked). Both actions are staged,
   reasoned governance actions under the arbiter discipline of
   `AA-ROLES`, are evented (`PlatformWorksContestChanged`) with the claim
   record hash they adjudicate, and enter the numeric ID catalog
   (`CONTESTED`, `CONTEST_DISMISSED`, `CONTEST_SUSTAINED`).
6. While the contest state is `CONTESTED` and after `CONTEST_SUSTAINED`,
   every consumer surface must display the contest through the
   attribution object (`AA-DISPLAY`: `contested = true` plus
   `contest_record`); the collection can never again present an
   uncontested artist-less assertion once a contest is sustained.
7. While the contest state is `CONTESTED`, the registry serves the
   `PLATFORM_WORKS_DECLARATION` finality component with `frozen = false`,
   blocking finality until the arbiter resolves — finality must never
   permanently bind a declaration the arbiter has open doubts about. A
   sustained contest recorded before finality keeps blocking; a contest
   opened after an executed finality record changes display only, per the
   prospective-only discipline of `AA-STATE` requirement 5. Rebinding to
   an artist remains impossible on this registry line (requirement 1); a
   sustained contest plus the successor-line import rule (`AA-PERM`) is
   the recovery path for a proven misappropriation.

## Artist Sanction As A Finality Component [AA-SANCTION]

For any collection with a bound artist, artwork finality requires an
`ARTIST_SANCTION` component: an EIP-712/ERC-1271 signature by the accepted
artist authority over the finality record preimage, verified onchain
(ADR 0010 decision D2.3). A collector or museum can then prove from chain
data alone that the artist sanctioned this exact final artwork.

The sanction subject is the finality record preimage computed without the
sanction component itself, which removes the self-reference while binding
everything the finality record binds:

```solidity
bytes32 sanctionSubjectHash = keccak256(abi.encode(
    SANCTION_SUBJECT_DOMAIN,
    uint256(block.chainid),
    address(core),
    address(finalityRegistry),
    uint8(scopeType),        // COLLECTION=0 for collection finality
    uint256(collectionId),
    uint256(tokenId),        // zero outside TOKEN scope
    bytes32(scopeId),        // zero outside RELEASE/SEASON/VIEW scope
    bytes32(coreFactsHash),  // coreCollectionFactsHash or
                             // scopedCoreFactsHash per the umbrella spec
    bytes32(nonSanctionComponentsHash),
    bytes32(manifestURIHash),
    bytes32(manifestContentHash),
    bytes32(manifestSchemaId),
    bytes32(manifestCanonicalizationHash)
));
```

`nonSanctionComponentsHash` is `componentsHash` per
[`stream-long-term-architecture.md`](stream-long-term-architecture.md)
(Artwork Finality Freeze) — same `STREAM_FINALITY_COMPONENTS_V1` domain,
same sort order — computed over the submitted component list with every
`ARTIST_SANCTION`-type entry excluded. The artist therefore signs the Core
supply facts, every artwork component (metadata, renderer, scripts,
dependencies, media, entropy), and the finality manifest itself.

Pinned typed payload:

```text
StreamArtistSanction(
    address core,
    uint8 scopeType,
    uint256 collectionId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 sanctionSubjectHash,
    bytes32 statementHash,
    uint256 nonce,
    uint64 deadline
)
```

Sanction record hash (also the component `dataHash`; this preimage is the
component's published dataHash schema required by the umbrella spec):

```solidity
bytes32 sanctionRecordHash = keccak256(abi.encode(
    SANCTION_RECORD_DOMAIN,
    uint256(block.chainid),
    address(this),           // the registry
    bytes32(artistId),
    address(signer),
    uint8(authorityClass),
    uint8(scopeType),
    uint256(collectionId),
    uint256(tokenId),
    bytes32(scopeId),
    bytes32(sanctionSubjectHash),
    bytes32(statementHash),
    uint256(nonce),
    uint64(signedAt)
));
```

Finality-facing read (Permanent):

```solidity
function verifySanctionForSubject(
    uint8 scopeType,
    uint256 collectionId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 sanctionSubjectHash
) external view returns (
    bool valid,
    bytes32 sanctionRecordHash,
    address signer,
    uint8 authorityClass
);
```

Requirements:

1. `recordArtistSanction` verifies the signature onchain under `AA-SIGVER`,
   enforces the collaborator policy (`AA-COLLAB` requirement 4) by
   requiring the full co-signature set in one submission, stores the
   record and signature bytes, and emits `ArtistSanctionRecorded`. It must
   revert while the collection is `DISPUTED` or `REVOKED`.
2. The expected `sanctionSubjectHash` is produced by the finality
   registry's preview surface (`previewFinality` in the umbrella spec) so
   the artist signs exactly what will execute. Any drift in any component,
   Core fact, or manifest between signing and finalization changes the
   subject hash and invalidates the sanction for that finalization; a
   sanction can never be stale-but-accepted.
3. The registry implements the finality component read surfaces with
   `componentType = keccak256("ARTIST_SANCTION")` for artist-bound
   collections: `frozen = true` and `dataHash = sanctionRecordHash` exactly
   when a verified, undisputed, unrevoked sanction exists for the scope.
   `finalizeCollectionArtwork` and `finalizeArtworkScope` must include this
   component for artist-bound collections, must call
   `verifySanctionForSubject` with the subject hash they compute from the
   non-sanction components, and must revert on mismatch. The umbrella spec
   mirrors this as a required component type and finality rule; the
   conformance matrix gates it (`AA-GATES`).
4. Because the sanction component's `dataHash` is inside `componentsHash`,
   the executed `finalityRecordHash` permanently binds the verified artist
   signature; `verifyFinality` therefore exposes artist sanction state to
   any future tool with no new read surface.
5. Sanctions record `authorityClass`. `AUTH_SUCCESSOR` and `AUTH_STEWARD`
   sanctions are permanently distinguishable from lifetime artist
   sanctions — posthumous authority is clearly marked and never
   retroactive. A steward sanction is valid only for works minted before
   the steward's appointment.
6. Scoped finality for open series uses the same mechanism per scope;
   the sanction subject includes the full `FinalityScope`, so a release
   sanction cannot be replayed against a season or the collection.
7. For `PLATFORM_WORKS` collections the registry serves
   `componentType = keccak256("PLATFORM_WORKS_DECLARATION")` with
   `dataHash = platformWorksDeclarationHash` and `frozen = true` — except
   while the declaration's contest state is `CONTESTED`, when it serves
   `frozen = false` (`AA-PLATFORM` requirement 7); finality for
   artist-less collections binds the immutable declaration instead of
   a sanction. Exactly one of the two component types applies to any
   collection; a finality submission carrying neither, for any collection,
   is nonconformant.
8. There is no unsigned finalization path for artist-bound collections.
   Key loss and death do not soften this rule; they route through
   succession and dormancy (`AA-ESTATE`, `AA-DORMANCY`), which produce an
   authorized, clearly-classified signer. Absence of artist sanction is
   therefore always provable intent (`PLATFORM_WORKS`), never silence.
9. The sanction ceremony must be human-readable, and that readability
   must be provable later (ADR 0011 decision R7.7). `statementHash` must
   commit to a canonical RFC 8785 ceremony document under the pinned
   schema `keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_V1")`
   (`AA-DOMAINS`) recording what the artist actually reviewed before
   signing: the full sanction subject preimage field values, the finality
   manifest content hash, the content root or media hashes covered, the
   reference-render hashes the artist reviewed, the human-readable
   statement text, and the name and version of the signing tool that
   rendered the payload (`AA-TOOLING`). Operator tooling must deliver the
   complete preimage bundle — every input of `sanctionSubjectHash` — to
   the artist before signature, and an independently published
   recomputation tool must let the artist (or any future researcher)
   recompute `sanctionSubjectHash` from that bundle without operator
   infrastructure (`AA-TOOLING` requirement 4). The ceremony document is
   dual-family archived with the sanction record (`AA-RECORDS`
   requirement 5), so "the artist did not know what they sanctioned" is
   answerable from evidence, not testimony.

## Artist Intent Prerequisite [AA-INTENT]

Bits without intent cannot support a defensible migration decision. The
`ARTIST_INTENT` record family — display parameters, acceptable variability,
migration/emulation guidance, interview references — is defined by the
museum object dossier surfaces under ADR 0010 decision D6.4 and stored
through the collection metadata record satellites
([`collection-metadata-contract.md`](collection-metadata-contract.md)).
This section owns who may author it and when finality may proceed.

Requirements:

1. An `ARTIST_INTENT` record for an artist-bound collection is valid only
   when authored under artist authority: `AUTH_ARTIST`, an activated
   `AUTH_SUCCESSOR`, or a delegation carrying `CAP_INTENT_RECORDS`.
2. Finality for an artist-bound collection requires either a recorded
   `ARTIST_INTENT` record referenced in the finality manifest, or an
   explicit artist-signed intent waiver recorded as a state-bound
   attestation with `subjectKind = SUBJECT_ARTIST_INTENT` and a
   waiver statement hash. Absence of both blocks finality; the waiver
   makes the absence provable intent (ADR 0010 decision D6.4).
3. Finality recovery manifests for artist-bound collections must state
   conformance or documented deviation from the recorded intent, per the
   recovery rules of the umbrella spec, and artwork-bytes-changing
   recovery additionally requires the artist-side approval of
   `AA-RECOVERY`.
4. The recorded artist interview is core variable-media documentation,
   not an optional attachment (ADR 0011 decision R11). The pinned intent
   schema owned by
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-ARTIST-INTENT] carries interview references as first-class
   entries with dual-family mirroring; this document adds the
   authority-side rule: pre-finality tooling must emit a distinct warning
   — separate from the missing-intent warning — whenever an artist-bound
   script-based collection approaches finality without an archived
   interview reference, and museum-grade finality requires an interview
   reference or a recorded waiver per that home. Absence of an interview
   is therefore always a visible, deliberate choice, never an oversight
   default.

## Post-Finality Recovery Approval [AA-RECOVERY]

Finality makes "the artist approved these exact bytes" the product; a
recovery path that changes which bytes are served must not hand the
operator back the pen (ADR 0011 decision R7.3).

Pinned typed payload:

```text
StreamArtistRecoveryApproval(
    address core,
    address finalityRegistry,
    uint256 collectionId,
    bytes32 finalityRecordHash,
    bytes32 recoveryManifestHash,
    uint256 nonce,
    uint64 deadline
)
```

Finality-facing read (Permanent):

```solidity
function verifyRecoveryApproval(
    uint256 collectionId,
    bytes32 finalityRecordHash,
    bytes32 recoveryManifestHash
) external view returns (
    bool valid,
    bytes32 approvalRecordHash,
    address signer,
    uint8 authorityClass
);
```

Requirements:

1. For artist-bound collections, executing a finality recovery whose
   staged record carries `artworkBytesChanged = true`
   ([`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   Finality Recovery) requires a verified `StreamArtistRecoveryApproval`
   over the exact `finalityRecordHash` being recovered and the exact
   `recoveryManifestHash` being executed. Approval is sanction-class
   authority: `AUTH_ARTIST`, an activated `AUTH_SUCCESSOR` whose grant
   includes `CAP_SANCTION`, `AUTH_STEWARD` (stewards hold `CAP_SANCTION`
   for pre-appointment works), or a delegation carrying `CAP_SANCTION`;
   the collaborator policy (`AA-COLLAB` requirement 4) applies. The
   finality registry must call `verifyRecoveryApproval` before executing
   such a recovery and revert on mismatch; the umbrella spec mirrors this
   as a recovery-path requirement. Recoveries with
   `artworkBytesChanged = false` (route repointing that provably serves
   identical bytes) need no artist approval.
2. When no artist authority can sign — key loss without designation
   before dormancy completes, or a contested identity — the fallback is
   never silent operator discretion: `ROLE_ATTRIBUTION_ARBITER` must
   first record an artist-unavailability finding (evidence hash, reason
   hash, evented, hashed under
   `UNAVAILABILITY_FINDING_RECORD_DOMAIN`), and the recovery may then
   execute only after an additional public notice of
   `ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS` (`AA-LIMITS`) beyond
   the umbrella spec's recovery delay, during which any authenticated
   act of artist authority cancels the finding and voids the fallback
   (ADR 0011 decision R7.3). The finding, like every arbiter action,
   stages under the `AA-ROLES` delay discipline.
3. The executed recovery manifest must reference the approval record hash
   or the unavailability finding record hash it relied on, so every
   post-finality change to served bytes carries its artist-side evidence
   (or the documented absence of it) in the manifest the recovery
   permanently records. Approvals are append-only, consume a nonce, bind
   one exact recovery manifest, and authorize nothing else; a changed
   recovery manifest requires a fresh approval.

## State-Bound Artist Attestations [AA-ATTEST]

An attestation that does not commit to what was approved proves only that
an address published a string. Artist attestations bind the exact state
they approve and expose staleness.

```solidity
enum AttestationSubjectKind {
    SUBJECT_NONE,                // 0 invalid
    SUBJECT_COLLECTION_SNAPSHOT, // 1 latest snapshot manifest hash
    SUBJECT_SCRIPT_MANIFEST,     // 2 script manifest hash
    SUBJECT_MEDIA_MANIFEST,      // 3 media manifest hash
    SUBJECT_FINALITY_RECORD,     // 4 executed finality record hash
    SUBJECT_PHASE_POLICY,        // 5 policy hash
    SUBJECT_ECONOMICS,           // 6 assignment hash
    SUBJECT_ARTIST_INTENT,       // 7 intent record hash or waiver
    SUBJECT_FREEFORM             // 8 statement only; no staleness read
}
```

Pinned typed payload:

```text
StreamArtistAttestation(
    address core,
    uint256 collectionId,
    uint8 subjectKind,
    bytes32 subjectId,
    bytes32 subjectStateHash,
    bytes32 schemaId,
    bytes32 statementHash,
    bytes32 statementURIHash,
    uint256 nonce,
    uint64 signedAt
)
```

Staleness read (pure comparison; the caller supplies the live value it
already reads from the owning contract, so the read is O(1),
non-reverting, and adds no cross-contract gas coupling):

```solidity
function artistAttestationStatus(
    uint256 collectionId,
    uint8 subjectKind,
    bytes32 subjectId,
    bytes32 currentSubjectStateHash
) external view returns (
    uint8 status,           // 0 NONE, 1 ATTESTED_CURRENT,
                            // 2 ATTESTED_STALE, 3 DISPUTED
    bytes32 attestationRecordHash,
    bytes32 attestedSubjectStateHash,
    uint64 signedAt
);
```

Requirements:

1. `recordArtistAttestation` verifies the signature onchain under
   `AA-SIGVER` (EOA and ERC-1271 alike, from genesis), stores the record
   and signature bytes, and emits `ArtistAttestationRecorded`. Authority is
   `AUTH_ARTIST`, an activated `AUTH_SUCCESSOR`, or a delegation with
   `CAP_ATTEST`; the record stores the authority class.
2. `subjectStateHash` must be the canonical hash the subject kind names
   (snapshot manifest hash, script hash, media manifest hash, finality
   record hash, policy hash, or assignment hash, each owned by its home
   spec). An attestation approves that exact state; any later change makes
   it `ATTESTED_STALE` through the comparison read. Nobody can present a
   pre-change attestation as approval of post-change state.
3. This payload supersedes the unbound
   `{signer, statement, statementHash, signedAt}` artist attestation shape:
   the collection metadata contract and the `StreamCollectionAttestations`
   satellite must store artist attestations in this form and must route
   authority through this registry
   ([`collection-metadata-contract.md`](collection-metadata-contract.md)
   mirrors the storage side). Hedged deferral of signature verification is
   retired; verification is a genesis behavior (ADR 0010 decision D2.6).
4. The renderer derives `attestation_status` (`AA-DISPLAY` requirement 2)
   from this staleness read using the live subject hash it already reads
   while rendering.
5. Attestations are append-only. A newer attestation for the same
   `(collectionId, subjectKind, subjectId)` supersedes for display; history
   remains reconstructable (`AA-RECON`).
6. Institutional, curatorial, and estate attestations stored by the
   metadata satellites must also be signature-verified at submission from
   genesis; their authority classes are defined by the metadata and museum
   specs, and their verification mechanics follow `AA-SIGVER`.

## C2PA Authorship Reconciliation [AA-C2PA]

C2PA is the industry authorship substrate for capture-based media; a
VALID C2PA manifest naming a different author than the accepted binding
is an attribution conflict, not background noise (ADR 0011 decision
R7.9). C2PA record storage, binding validity, and validator classes are
owned by [`collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-C2PA]; this section owns the reconciliation rule against registry
attribution.

Requirements:

1. The identity document (`AA-IDENTITY` requirement 2) should enumerate
   the artist's C2PA signing credentials (certificate or key references
   with validity periods). An artist may supplement or update the
   enumeration at any time with a state-bound attestation whose
   `schemaId = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1")`
   (`AA-DOMAINS`); the latest such attestation is the operative
   enumeration.
2. When a stored C2PA manifest carries authorship assertions for an
   artist-bound collection, verifier-class validation ([CMC-C2PA] rule 4)
   must reconcile the claim signer against the operative credential
   enumeration and the registry's key history for the bound `artistId`.
   The result is recorded on the validation record as `consistent`
   (signer matches an enumerated credential), `divergent` (signer
   matches none), or `unevaluated` (no enumeration exists); a divergent
   result is an explicit divergence flag, never a silent coexistence.
3. Consumer surfaces must expose the reconciliation result through the
   attribution object (`AA-DISPLAY` `c2pa_authorship_status`). A
   `divergent` result changes display only; authority stays with the
   registry binding, and the dispute path for a genuinely contested
   authorship is `AA-DISPUTE` (artist-bound) with the divergence record
   as evidence.

## Artist Economics Rights [AA-ECON]

Where consent mode binds an artist, the artist holds three economics
rights: a first-class beneficiary position, a co-signature over changes,
and a unilateral defensive freeze (ADR 0010 decision D2.5).

Pinned typed payloads:

```text
StreamArtistEconomicsConsent(
    address core,
    address resolver,
    bytes32 revenueClass,
    uint8 scope,
    uint256 scopeId,
    bytes32 assignmentHash,
    uint256 nonce,
    uint64 deadline
)

StreamArtistRoyaltyFreeze(
    address core,
    address resolver,
    uint256 collectionId,
    bytes32 revenueClass,
    bytes32 expectedAssignmentHash,
    uint256 nonce,
    uint64 deadline
)
```

`assignmentHash` is the canonical preimage owned by
[`revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
(Assignment Semantics); it binds the resolver context, scope context,
profile or template pointer context, policy hash, and frozen bit. An
economics consent therefore covers the exact profile entries, shares, and
policy mode that pay the artist.

Requirements:

1. The canonical `ARTIST` beneficiary class is the split-profile label
   `keccak256("artist")` (matching the label vocabulary of the revenue
   spec). Split profiles and primary templates serving an artist-bound
   collection must include at least one `artist`-labeled entry whose
   account is the artist payout address stated in the identity record, and
   one entry per collaborator with a nonzero `shareLabelId` (`AA-COLLAB`).
2. The artist-take posture is explicit: genesis default primary templates
   for artist-bound collections must be artist-majority — aggregate
   `artist`-labeled shares of at least `500_000` ppm — and every
   collection's primary split must be disclosed in collection metadata and
   operator UX before sale start. Historical three-bucket defaults
   (50/25/25) are non-normative context and must not be presented as the
   protocol default. The revenue spec owns the template tables and mirrors
   this posture.
3. Setting, clearing, or replacing a primary or royalty assignment at
   collection or token scope for an artist-bound collection requires a
   verified `StreamArtistEconomicsConsent` over the exact resulting
   `assignmentHash`, satisfying the collaborator policy. The resolver must
   call `requireEconomicsConsent` before applying such changes
   (the revenue spec mirrors this as an assignment-path requirement).
   Governance timelocks remain; artist consent is additive, not a
   replacement for staging.
4. Public mint of an artist-bound collection additionally requires recorded
   economics consent for the active primary revenue class assignment and
   the `ROYALTY_ERC2981` assignment that will govern its tokens; this is
   part of `requireMintConsent` (`AA-CONSENT` requirement 6). Economics
   are artist-ratified before the first sale, not after.
5. The artist authority may unilaterally freeze the royalty assignment for
   their own collection: `authorizeArtistRoyaltyFreeze` records a verified
   `StreamArtistRoyaltyFreeze`; any caller may then relay it to the
   resolver, which must verify `isRoyaltyFreezeAuthorized` and apply an
   `EXACT` freeze on the `ROYALTY_ERC2981` collection-scope assignment
   whose current hash equals `expectedAssignmentHash`. The right is freeze
   -only: it cannot change the receiver, cannot unfreeze, and cannot touch
   other collections. It converts "trust governance forever" into a
   one-way artist-held guarantee.
6. Artist economics rights are exercised through the same authority chain
   as everything else: rotation, delegation (`CAP_ECONOMICS_CONSENT`,
   `CAP_ROYALTY_FREEZE`), succession, and steward rules apply.

## Artist Content Consent And Freeze [AA-CONTENT]

Policy consent binds mintability; it does not bind what minted tokens
render. Between the first mint and executed finality, the artist holds a
standing veto over the content of their own already-sold works and a
unilateral defensive freeze (ADR 0011 decision R7.2).

Content-affecting record families are the collection metadata surfaces
that change what a minted token renders or resolves to: the script
manifest, dependency manifest, media manifest, renderer assignment, and
snapshot-route families, identified by the family and lock identifiers
owned by [`collection-metadata-contract.md`](collection-metadata-contract.md)
(Lock Model and record families); that document owns the exact family
list and mirrors the storage-side enforcement of this section.

Pinned typed payloads:

```text
StreamArtistContentConsent(
    address core,
    address metadataContract,
    uint256 collectionId,
    bytes32 familyId,        // content-affecting family identifier
    bytes32 newStateHash,    // canonical hash of the resulting state
    uint256 nonce,
    uint64 deadline
)

StreamArtistContentFreeze(
    address core,
    address metadataContract,
    uint256 collectionId,
    bytes32[] lockClasses,   // sorted ascending, unique, nonzero;
                             // metadata-contract lock vocabulary
    bytes32 expectedStateHash, // current collection content state pinned
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. For an artist-bound collection, from the first minted token until an
   executed finality record exists, every write to a content-affecting
   record family requires a verified `StreamArtistContentConsent` over
   the exact resulting family state hash (the same canonical hash the
   family's staleness read exposes, `AA-ATTEST` requirement 2). The
   collection metadata contract must call `requireContentConsent` before
   applying such writes; before the first mint, and after executed
   finality (where content locks and the recovery rules of `AA-RECOVERY`
   govern), no content consent is required and iteration stays free.
2. Authority follows consent mode: on `ARTIST_SIGNED_POLICY` collections
   the consent must be signed by the artist authority (`AUTH_ARTIST` or
   an activated `AUTH_SUCCESSOR` whose grant includes
   `CAP_CONTENT_CONSENT`), and delegated content consent is invalid; on
   `ARTIST_DELEGATED` collections an active delegation carrying
   `CAP_CONTENT_CONSENT` may also consent. The collaborator policy
   applies per `AA-COLLAB` requirement 4. Consents are append-only,
   consume a nonce, bind one `(collectionId, familyId, newStateHash)`,
   and authorize exactly one applied write: a changed target state
   requires fresh consent, and an unused consent authorizes nothing
   else.
3. The artist authority may unilaterally freeze content for their own
   collection at any time between first mint and executed finality:
   `authorizeArtistContentFreeze` records a verified
   `StreamArtistContentFreeze`; any caller may relay it to the metadata
   contract, which must verify `isContentFreezeAuthorized` and apply the
   named one-way locks when the collection's current content state
   matches `expectedStateHash`. The right is freeze-only and defensive,
   exactly parallel to the royalty freeze (`AA-ECON` requirement 5): it
   cannot change content, cannot unlock, and cannot touch other
   collections. Locks applied this way are ordinary metadata-contract
   one-way locks; nothing about them blocks registry authority
   (`AA-DISPLAY` requirement 7).
4. Content consent gates content-affecting families only. It never gates
   the operational phase pause flag, preservation-receipt appends,
   owner records, or display-metadata families that cannot change served
   artwork bytes; the metadata contract's family classification is the
   boundary, and disputes about the boundary resolve to the stricter
   class.
5. Records and events: content consents and freezes are hashed under
   `CONTENT_CONSENT_RECORD_DOMAIN` and `CONTENT_FREEZE_RECORD_DOMAIN`,
   store signature bytes per `AA-SIGVER`, emit
   `ArtistContentConsentRecorded` / `ArtistContentFreezeAuthorized`, and
   enter the record chains (`AA-RECORDS`). While the collection is
   `DISPUTED`, new content consents are blocked (`AA-STATE` requirement
   4) but the defensive content freeze remains available.

## Estate Interaction With Split Wallets [AA-SPLITS]

Split profiles are immutable and entitlements are address-bound; this
section states exactly what succession can and cannot recover, so artists
consent knowingly.

Requirements:

1. Normative guidance, enforced by operator tooling defaults and stated in
   artist onboarding: artist and collaborator payout accounts should be
   ERC-1271 smart accounts (Safe-class) with documented owner rotation and
   estate procedures, not raw EOAs. The registry supports EOAs, but the
   irrecoverability below is the cost.
2. What succession recovers: future receipts. After succession or dormancy
   completion, new assignments for future revenue route to estate-designated
   profiles through the ordinary assignment flow, co-signed under
   `AUTH_SUCCESSOR` authority (`AA-ECON` requirement 3), subject to
   existing freezes.
3. What succession does not recover: funds already owed to a lost-key EOA
   inside an immutable split wallet. Per the revenue spec (Payment
   Accounting), release to an alternate recipient requires the entitled
   account's signature; permissionless release only pushes to the entitled
   address itself. A lost-key EOA entitlement is therefore permanently
   claimable only by that address — economically stranded — and a frozen
   assignment pointing at it cannot be repointed. This is irreversible by
   design and must be disclosed verbatim in artist onboarding.
4. A smart-account payout address avoids the stranding entirely: the estate
   rotates the account's owners and signs ordinary `ReleaseAuthorization`
   payloads per the revenue spec. Registry authority (this document) and
   payment entitlement (the account) are deliberately separate systems;
   rotating one never silently moves the other.
5. Pre-signed estate directives (`AA-ESTATE`) may include payout-routing
   instructions for future assignments as directive payload content; they
   cannot and do not override split-wallet release authorization, and the
   spec set contains no mechanism that lets the registry move owed funds.

## Artist Key Rotation [AA-ROTATE]

Artists rotate their bound address without operator involvement
(ADR 0010 decision D2.2). Rotation is two-sided: the old key authorizes,
the new key accepts, so authority can never be rotated to an address the
artist does not control. Rotation is also never instant: it stages behind
a contest window so a stolen key cannot instantly and permanently take
the identity (ADR 0011 decision R7.1; `AA-GUARD`).

Pinned typed payloads:

```text
StreamArtistKeyRotation(
    bytes32 artistId,
    address oldAddress,
    address newAddress,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 deadline
)

StreamArtistRotationAcceptance(
    bytes32 artistId,
    address oldAddress,
    address newAddress,
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. `rotateArtistAddress` requires old-side evidence (direct call from the
   current authority address or a verified `StreamArtistKeyRotation`) and
   new-side evidence (direct call from `newAddress` or a verified
   `StreamArtistRotationAcceptance`); both may land in one transaction.
   Satisfying both sides stages the rotation — it does not execute it:
   the registry records the pending rotation under
   `ROTATION_RECORD_DOMAIN`, sets
   `contestEndsAt = block.timestamp + ARTIST_ROTATION_CONTEST_SECONDS`,
   and emits `ArtistRotationStaged`. At most one rotation may be pending
   per identity.
2. A staged rotation executes through exactly one of two evented paths
   (`AA-GUARD` owns the contest mechanics):
   (a) permissionlessly, by any caller via `executeArtistRotation`, once
   `contestEndsAt` has passed without a veto; or
   (b) immediately, once `approvalThreshold`-many registered guardians
   have approved the pending rotation — a guardian quorum is the fast
   path for artists who pre-registered one. A veto under `AA-GUARD`
   cancels the pending rotation and sets the identity status to
   `IDENTITY_CONTESTED`.
   Execution updates `authorityAddress` for the `artistId` across every
   binding at once, emits `ArtistAddressRotated` with old address, new
   address, authority class, and reason hash, and preserves the full
   address history in events. `artistId` and all bindings, consents,
   sanctions, and attestations are unaffected: history stays attributed
   to the identity, not the key. Verification against the current
   authority address (`AA-SIGVER`) means outstanding payloads signed by
   the pre-rotation key stop verifying at execution with no further
   action.
3. Rotation never changes split-wallet entitlements (`AA-SPLITS`
   requirement 4) and never revokes delegations (`AA-DELEG` requirement 3).
4. A compromised-key response is: stage a rotation, have guardians
   approve it for immediate execution (or ride out the contest window),
   and revoke any outstanding unused signed payloads
   (`revokeArtistAuthorization`, `AA-REVOKE`); operator runbooks must
   document this sequence, and the registry must allow staging plus
   revocations in one transaction. If the attacker stages a rotation
   first, the response is a veto (`AA-GUARD` requirement 3) — the true
   artist still holds the same key the attacker holds, and any prior
   authority address retains contest standing (`AA-GUARD` requirement
   5), so the attacker can never win by racing.
5. Rotation is available to collaborator identities identically.

## Artist Guardians And Rotation Contest [AA-GUARD]

Over 50 years, artist key compromise is a population-level certainty. The
guardian set and contest window make identity takeover loud, slow, and
reversible without ever giving guardians authorship powers
(ADR 0011 decision R7.1).

Pinned typed payload (long-lived; `signedAt` and nonce ordering pick the
operative set):

```text
StreamArtistGuardianSet(
    bytes32 artistId,
    address[] guardians,     // strictly ascending, unique, nonzero;
                             // up to MAX_ARTIST_GUARDIANS
    uint32 approvalThreshold, // guardian approvals that execute a staged
                              // rotation immediately; 1..guardians.length;
                              // 0 only with an empty guardian list
    uint256 nonce,
    uint64 signedAt
)
```

Requirements:

1. A guardian set is recorded only under `AUTH_ARTIST` authority (direct
   or signed), verified under `AA-SIGVER`, hashed under
   `GUARDIAN_SET_RECORD_DOMAIN`, evented
   (`ArtistGuardianSetUpdated`), and append-only; the record with the
   highest nonce that is not adjudicated-superseded (requirement 7) and
   not provisional (requirement 8) is operative. Guardians may be EOAs
   or contracts
   (family, studio, gallery, lawyer, estate); artist onboarding tooling
   must recommend registering at least one guardian
   (`AA-TOOLING`).
2. Guardian powers are exhaustively: approving a pending rotation
   (`approveArtistRotation`), vetoing a pending rotation
   (`vetoArtistRotation`), and filing an identity-compromise contest
   under requirement 5. Guardian actions are direct calls from the
   guardian address (contract guardians act through their own
   execution); guardians hold no capability bits, sign no artist
   payloads, and can never author records in the artist's name —
   compromising every guardian yields veto power, not authorship.
3. While a rotation is pending, a veto by any single registered guardian,
   by the identity's current authority address, by the operative
   designated successor, or by any prior authority address of the same
   identity cancels the pending rotation, emits `ArtistRotationVetoed`
   with a reason hash, and sets the identity status to
   `IDENTITY_CONTESTED`. Veto is deliberately cheaper than approval
   (one vetoer versus a quorum): the registry cannot distinguish victim
   from attacker, so it freezes toward safety and routes to
   adjudication.
4. While `IDENTITY_CONTESTED`, the registry must reject new binding
   acceptances, sanctions, policy/economics/content consents, delegation
   grants, designations, directives, estate activations, dormancy
   initiation, and further rotation staging for the identity. Defensive
   actions remain available: authorization revocations (`AA-REVOKE`),
   dispute openings and counter-statements, royalty and content freezes.
   The contested state exits only through arbiter resolution
   (requirement 6) or an identity recovery (requirement 7); no signature
   from the (possibly stolen) authority key can clear it.
5. Standing to contest executed rotations is permanent: any prior
   authority address of an identity, the operative designated successor,
   or any registered guardian may file an identity-compromise contest
   via `contestArtistIdentity` (evidence hash and reason hash required,
   empty evidence reverts; recorded under
   `IDENTITY_CONTEST_RECORD_DOMAIN` and evented via
   `ArtistIdentityContested`) at any time after a rotation executes,
   setting the identity status to `IDENTITY_CONTESTED`. This closes the
   wait-out-the-window path: an attacker
   who completes an uncontested rotation still never holds
   incontestable authority. The griefing inverse — a compromised old key
   filing harassment contests — is accepted and mitigated by
   adjudication: the arbiter's dismissal may revoke the filing address's
   future contest standing for that identity.
6. `ROLE_ATTRIBUTION_ARBITER` resolves a contested identity by staged,
   reasoned governance action (delay discipline of `AA-ROLES`): either
   dismissal — restoring `IDENTITY_ACTIVE` under the incumbent authority
   address — or an identity recovery under requirement 7. Every
   resolution links the contest evidence and is evented.
7. Identity recovery reassigns `authorityAddress` for a hijacked
   `artistId` without a new identity — the join key museums rely on
   never changes (`AA-IDENTITY` requirement 1). `recoverArtistIdentity`
   requires: the arbiter's staged resolution carrying evidence and
   reason hashes; new-side acceptance by the recovery address (direct
   call or `StreamArtistRotationAcceptance` signature); and an
   append-only recovery record hashed under
   `IDENTITY_RECOVERY_RECORD_DOMAIN`, emitted via
   `ArtistIdentityRecovered`. Recovery revokes all outstanding
   delegations, and the resolution may enumerate attacker-era
   designation, directive, and guardian-set records as
   adjudicated-superseded
   (`IDENTITY_RECOVERY_SUPERSESSION_DOMAIN` over the sorted
   record-hash list): superseded records stay in history but stop being
   operative, so "highest nonce is operative" (`AA-ESTATE`) reads
   "highest nonce not adjudicated-superseded". Recovery never rewrites
   consumed consents, sanctions, or any executed history.
8. Records authored in the takeover window are provisional: a successor
   designation, estate directive, or guardian-set record recorded within
   `ARTIST_ROTATION_CONTEST_SECONDS` after a rotation executes becomes
   operative only when that same window elapses without an
   identity-compromise contest. A genuine artist waits days; a thief's
   rewrite of the estate plan never outruns the contest.
9. Dormancy and the contest window interact conservatively: dormancy must
   not initiate while a rotation is pending or the identity status is
   `IDENTITY_CONTESTED`, and any veto, approval, or contest filing counts as
   activity for nobody — guardian actions never update
   `lastAuthorityActionAt`, which tracks artist-side authority only
   (`AA-IDENTITY` requirement 3).

## Successor Designation And Estate Directives [AA-ESTATE]

Artists designate, while alive and in control, who inherits their
authority and under what constraints (ADR 0010 decision D2.2).

Pinned typed payloads (long-lived; deliberately no deadline — `signedAt`
and nonce ordering pick the latest):

```text
StreamArtistSuccessorDesignation(
    bytes32 artistId,
    address successor,
    uint8 successorKind,     // 1 EOA, 2 CONTRACT (estate/foundation/DAO)
    uint32 grantedCapabilities,
    bytes32 conditionsHash,  // canonical activation conditions document
    bytes32 directiveHash,   // zero or the paired directive's record hash
    uint256 nonce,
    uint64 signedAt
)

StreamArtistEstateDirective(
    bytes32 artistId,
    uint32 grantedCapabilities,
    uint32 forbiddenCapabilities,
    bytes32 directivePayloadHash,
    uint256 nonce,
    uint64 signedAt
)
```

Estate-activation request payload (signed by the designated successor;
`deadline` bounds the request, not the notice window):

```text
StreamArtistEstateActivation(
    bytes32 artistId,
    address successor,
    bytes32 evidenceHash,
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. Designations and directives are recorded only under `AUTH_ARTIST`
   authority (direct or signed), verified under `AA-SIGVER`, evented, and
   append-only; the record with the highest nonce that is not
   adjudicated-superseded (`AA-GUARD` requirement 7) and not provisional
   (`AA-GUARD` requirement 8) is the operative one. Successors and
   stewards cannot rewrite them.
2. A designation activates only through one of two evented paths, neither
   of which requires a live, cooperative platform (ADR 0011 decision
   R7.4):
   (a) completion of the governed dormancy procedure (`AA-DORMANCY`),
   which remains the fallback when no designation exists or the estate
   never comes forward; or
   (b) estate-initiated activation, which is governance-independent by
   construction: `requestEstateActivation` — a direct call from the
   operative designated successor or a verified
   `StreamArtistEstateActivation` signature, carrying a nonzero
   activation evidence hash (death certificate references, court
   letters, or equivalent, dual-family mirrored) — starts a public
   onchain notice window of `ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS`
   (`AA-LIMITS`), emits `ArtistEstateActivationRequested` with
   `noticeEndsAt`, and records the request under
   `ESTATE_ACTIVATION_RECORD_DOMAIN`. After `noticeEndsAt`, any caller
   may complete it permissionlessly via `executeEstateActivation`; a
   confirming ADR 0004 governance action of the `DELAYED` class carrying
   the same evidence hash may execute it earlier, as an accelerator
   only, never a requirement. Liveness always wins, exactly as in
   dormancy: any authenticated act of the living artist authority during
   the notice window automatically cancels the pending activation
   (evented via `ArtistEstateActivationCancelled`), and
   `cancelEstateActivation` exists for an explicit artist-side cancel.
   Execution must recheck at execution time that the requesting
   successor is still the operative designee under requirement 1 —
   a later designation, an adjudicated supersession, or a contested
   identity (`AA-GUARD` requirement 4) voids the pending request.
   Activation sets the identity status to `IDENTITY_SUCCEEDED`, vests
   `AUTH_SUCCESSOR` in the successor limited to `grantedCapabilities`
   minus `forbiddenCapabilities`, revokes all outstanding delegations,
   and emits `ArtistSuccessionActivated` (with `governanceActionId`
   zero when execution was permissionless).
3. Directive payloads are canonical RFC 8785 JSON, stored onchain up to
   `MAX_DIRECTIVE_PAYLOAD_BYTES = 8,192` (SSTORE2-style permitted), or
   hash-committed with a dual-family sealed archival record for private
   material, following the privacy and custody rules of the umbrella
   spec's Hash And Manifest Discipline. Directives may constrain the
   estate (for example: forbid `CAP_POLICY_CONSENT` so no posthumous
   works are ever authorized, permit only preservation records), name
   payout-routing intent (`AA-SPLITS` requirement 5), and reference legal
   instruments by hash.
4. `forbiddenCapabilities` are absolute: no successor, steward, delegation,
   or governance action can exercise or re-grant a capability the artist
   forbade. The forbidden mask is enforced in every authority check.
5. Absent any designation, dormancy completion falls back to the steward
   rules (`AA-DORMANCY` requirement 6); an artist who designates nothing
   still gets the protective default of a never-new-works steward.
6. Successor contracts (estates, foundations, DAOs) act through ERC-1271;
   the GGP-governed verification gas (`AA-SIGVER` requirement 2) keeps
   heavy estate governance contracts verifiable decades from now.

## Governed Dormancy Procedure [AA-DORMANCY]

Lost keys without designations must not orphan artist authority forever,
and the recovery must be impossible to abuse quietly (ADR 0010 decision
D2.2). Dormancy is slow, loud, cancellable by any sign of life, and staged
through the canonical governance action.

Governed time parameters (staged-governance values with immutable floors,
following the Governed Gas Parameter change discipline of ADR 0010
decision D1; time floors protect artists, so values may be raised freely
and lowered only through the normal delay class, never below the floor):

```text
ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS
    immutable floor 31_536_000 (365 days); genesis value 63_072_000
    (730 days) of no authenticated registry activity for the identity
ARTIST_DORMANCY_NOTICE_SECONDS
    immutable floor 15_552_000 (180 days); genesis value 31_536_000
    (365 days) of public onchain notice
```

Requirements:

1. `initiateArtistDormancy(artistId, evidenceHash, reasonURI)` requires
   `ROLE_ARTIST_DORMANCY_ADMIN` through a staged ADR 0004 governance
   action, and reverts unless
   `block.timestamp - lastAuthorityActionAt >=
   ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS`. It sets status
   `IDENTITY_DORMANCY_NOTICE`, records `noticeEndsAt = block.timestamp +
   ARTIST_DORMANCY_NOTICE_SECONDS`, and emits `ArtistDormancyInitiated`
   with the evidence hash and reason URI. Operational runbooks must
   document the offchain outreach performed before initiation; the
   evidence hash commits to it.
2. Any authenticated action by the artist authority, an active delegate,
   or the designated successor during the notice window automatically
   cancels dormancy (the registry checks status in every authenticated
   path), and `cancelArtistDormancy` exists for an explicit cancel. Every
   cancellation emits `ArtistDormancyCancelled` with the cancelling
   authority class. Liveness always wins.
3. `completeArtistDormancy` is a second staged governance action, valid
   only after `noticeEndsAt`. Completion vests authority per the operative
   successor designation and directives (`AA-ESTATE`); every transition
   emits `ArtistDormancyCompleted` with the vested address, authority
   class, and capability mask.
4. Dormancy state, notice deadlines, and both parameter values are
   readable; indexers and frontends must be able to display a running
   notice to the world for the entire window.
5. Dormancy never reduces recorded history: bindings, sanctions, consents,
   and attestations made before dormancy stand unchanged with their
   original authority classes.
6. Absent any operative designation, completion appoints the steward named
   in the completing governance action with `AUTH_STEWARD` limited to:

```text
STEWARD_CAPABILITIES = CAP_SANCTION | CAP_ATTEST | CAP_ECONOMICS_CONSENT
                     | CAP_ROYALTY_FREEZE | CAP_DISPUTE
                     | CAP_INTENT_RECORDS
```

   `CAP_POLICY_CONSENT` is permanently excluded: a steward can complete
   preservation, sanction finality of already-minted works, and defend
   economics, but can never authorize new works in the artist's name. The
   exclusion is a Permanent semantic of `AUTH_STEWARD`.
7. All dormancy governance actions use the canonical
   `STREAM_GOVERNANCE_ACTION_V1` action ID with dormancy fields folded
   into `scopeHash`/`newValueHash` per ADR 0004 (Canonical Action ID And
   Batch Execution); this document defines no second staging preimage.

## Disputed And Revoked Attribution [AA-DISPUTE]

Misattribution and forgery disputes are certainties over a 50-year record.
Dispute standing, evidence, resolution authority, and display are explicit
(ADR 0010 decision D2.7).

Pinned typed payload (for signed, relayed filings):

```text
StreamArtistAttributionDispute(
    address core,
    uint256 collectionId,
    uint64 bindingGeneration,
    uint8 disputeAction,     // 1 OPEN, 2 WITHDRAW, 3 COUNTER_STATEMENT
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. Standing to open a dispute: the bound artist authority (including
   successor; delegation requires `CAP_DISPUTE`), any accepted
   collaborator authority, a previously bound artist authority of an
   earlier generation of the same collection, or
   `ROLE_ATTRIBUTION_ARBITER`. Arbiter-opened disputes are the path for
   third-party forgery evidence; the arbiter role is held by a governance
   Safe or governor contract under ADR 0004 and every arbiter action is a
   staged, reasoned governance action.
2. A dispute record must carry `evidenceHash` and `reasonHash` committing
   to canonical evidence documents (stored via the metadata record
   satellites, dual-family mirrored). Empty evidence reverts.
3. While `DISPUTED`, the blocking rules of `AA-STATE` requirement 4 apply,
   and every consumer surface must display `disputed` (`AA-DISPLAY`).
4. Resolution: the arbiter resolves with `resolveAttributionDispute`
   carrying a resolution record (evidence hash, reason hash) to either
   `UPHELD` — restoring the pre-dispute state — or `REVOKE` — moving the
   generation to `REVOKED`. An artist-opened dispute may also be withdrawn
   by its opener, restoring the pre-dispute state. All outcomes are
   evented, reasoned, and append-only. Arbiter resolutions are never
   procedurally cheaper than a parameter change (ADR 0011 decision
   R7.7): every resolution stages under the `DELAYED` class or stricter
   (`AA-ROLES`), the staged action is public for at least its full delay
   as the evidence window, and the resolution record must link the
   latest counter-statement record for the dispute (or zero when none
   was filed) — `AttributionDisputeResolved` carries
   `counterStatementRecordHash` so a resolution can never claim the
   artist was silent when they were not.
5. The bound artist authority may directly repudiate their own attribution
   with `revokeAttribution` (collaborator policy applies); this is the
   artist's unilateral exit and requires no arbiter.
6. Revocation semantics are prospective-only per `AA-STATE` requirement 5:
   display changes everywhere, future authority ends, history and executed
   finality records remain intact and permanently marked. A fraudulent
   binding discovered after an `ARTIST_IDENTITY`-style metadata lock is
   still repudiable here, because registry truth — not the display lock —
   is the authority consumers must read.
7. Dispute vocabulary (`DISPUTED`, `REVOKED`, dispute actions `OPEN`,
   `WITHDRAW`, `COUNTER_STATEMENT`, resolution codes `UPHELD`, `REVOKE`,
   reason codes `REFUSED`, `WITHDRAWN`, `REPUDIATED_BY_ARTIST`,
   `ARBITER_REVOKED`) enters the numeric ID catalog.
8. Counter-statement right (ADR 0011 decision R7.7): while a dispute is
   open — including while a resolution is staged — the authority of the
   disputed binding (artist, activated successor, or delegation with
   `CAP_DISPUTE`; collaborator policy applies) may record
   counter-statements using `disputeAction = COUNTER_STATEMENT` with
   evidence and reason hashes, recorded under `DISPUTE_RECORD_DOMAIN`,
   evented via `AttributionCounterStatementRecorded`, and append-only.
   Counter-statements are exempt from the `AA-STATE` requirement 4
   blocks; silencing the accused is never a dispute feature.
9. Appeal and reopening (ADR 0011 decision R7.7): the governance tier
   holding role-admin authority over `ROLE_ATTRIBUTION_ARBITER`
   ([`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-ROLES] root) is the appeal tier — it may cancel a staged
   resolution before execution through the ordinary staged-action cancel
   path, on the record and reasoned. After execution, a `REVOKE`
   resolved by the arbiter (`ARBITER_REVOKED`) is not epoch-final: a
   later arbiter may reopen the same generation by opening a new dispute
   carrying new evidence (`AA-STATE` transition `REVOKED -> DISPUTED`);
   resolving that reopened dispute `UPHELD` restores the pre-revocation
   state, and `REVOKE` re-affirms. Reopening is append-only — every
   opinion every arbiter ever held remains in the record. Terminations
   the artist chose (`REPUDIATED_BY_ARTIST`) or that ended an unaccepted
   proposal (`REFUSED`, `WITHDRAWN`) are never reopenable against the
   artist's exit.

## Authorization Revocation [AA-REVOKE]

Signers can kill outstanding unused signed payloads (ADR 0010 decision
D10.4).

Pinned typed payload:

```text
StreamArtistAuthorizationRevocation(
    bytes32 artistId,
    bytes32 revokedDigest,   // zero when revoking by nonce
    uint256 revokedNonce,    // zero when revoking by digest
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. `revokeArtistAuthorization` accepts a direct call from the authority
   address or a verified `StreamArtistAuthorizationRevocation`, marks the
   named digest or nonce consumed, and emits
   `ArtistAuthorizationRevoked`. Exactly one of `revokedDigest` and
   `revokedNonce` must be nonzero.
2. Revocation applies to every typed payload family in this document
   (acceptances, sanctions, consents — policy, economics, and content —
   freezes, delegations, rotations, recovery approvals, designations,
   directives, estate activations, disputes). A revoked-then-submitted
   payload reverts.
3. Already-consumed authorizations cannot be revoked; revocation is
   preventive, never historical.
4. Revocation is scoped to the named `artistId` (ADR 0011 decision R10):
   it requires that identity's own authority, consumes state only inside
   that identity's digest and nonce spaces, and can never invalidate
   another identity's outstanding payloads. Cross-identity nonce or
   digest griefing is structurally impossible and negatively tested
   (`AA-GATES`); revocation records are hashed under
   `AUTH_REVOCATION_RECORD_DOMAIN`.

## Record Discipline And Write Authority [AA-RECORDS]

The CON-015 whole-module writer exception is retired for artist authority
(ADR 0010 decision D2.8): genesis uses record-family-scoped, signature
-verified writer authorization.

Requirements:

1. Every artist-authority record family defined here (bindings,
   acceptances, sanctions, consents — policy, economics, and content —
   delegations, guardian sets, rotations and rotation contests, identity
   recoveries, designations, directives, estate activations, dormancy
   records, disputes and counter-statements, platform-works claims and
   contests, recovery approvals, unavailability findings, attestations,
   freeze authorizations, revocations) is writable only through the
   authenticated paths of this registry. No safe-operator,
   metadata-admin, or whole-module writer role can author them, at
   genesis or ever.
2. `ARTIST_*` record families in the collection metadata satellites must
   reject writers that do not hold live artist authority in this registry
   for the subject collection; the generic v1 satellite enforces this from
   genesis (the collection metadata spec mirrors the storage-side check).
3. Every record event includes the recorder address and
   `ArtistAuthorityClass`, so artist-authored and operator-authored
   provenance are permanently distinguishable in the event stream.
   Record preimages are uniform across authorization paths: an
   artist-side action performed by direct call (no signed payload)
   consumes the identity's current allocator-hint nonce and records
   `block.timestamp` as its `signedAt`, so every record hash has the
   same field inventory whether authorized by call or by signature, and
   every preimage field appears in the record's event (`AA-RECON`
   requirement 2).
4. The registry maintains rolling record-chain accumulators, one per
   collection and one per `artistId` (aligned with ADR 0010 decision
   D4.4):

```solidity
recordChainHash = keccak256(abi.encode(
    RECORD_CHAIN_DOMAIN,
    bytes32(previousRecordChainHash),
    bytes32(recordHash)
));
```

   Accumulators are readable (`collectionRecordChainHash(collectionId)`,
   `artistRecordChainHash(artistId)`), included in the STATE_EXPORT leaf
   set of the umbrella spec, and prove the completeness of any replica of
   the artist-authority history.
5. Registry records referenced by finality manifests (sanctions and
   their ceremony documents, intent waivers, platform-works
   declarations, recovery approvals and unavailability findings) are
   covered by the dual-family archival rule before finality or recovery
   executes (ADR 0010 decision D4.6; verifiable receipt classes per
   ADR 0011 decision R4); onchain-stored signature bytes (`AA-SIGVER`
   requirement 6) and onchain-stored identity documents (`AA-IDENTITY`
   requirement 2) satisfy the onchain family.

## Limits And Governed Parameters [AA-LIMITS]

```text
MAX_COLLABORATORS                 32
MAX_ARTIST_GUARDIANS              8
MAX_FREEZE_LOCK_CLASSES           16
MAX_STORED_SIGNATURE_BYTES        4,096
MAX_DIRECTIVE_PAYLOAD_BYTES       8,192
MAX_IDENTITY_RECORD_BYTES         8,192
MAX_IDENTITY_RECORD_URI_BYTES     2,048
MAX_REASON_URI_BYTES              2,048
ARTIST_ERC1271_VERIFY_GAS         GGP; floor 90,000; genesis 150,000
ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS
                                  floor 31,536,000; genesis 63,072,000
ARTIST_DORMANCY_NOTICE_SECONDS    floor 15,552,000; genesis 31,536,000
ARTIST_ROTATION_CONTEST_SECONDS   floor 259,200 (72 h);
                                  genesis 604,800 (7 days)
ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS
                                  floor 7,776,000 (90 days);
                                  genesis 15,552,000 (180 days)
ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS
                                  floor 2,592,000 (30 days);
                                  genesis 7,776,000 (90 days)
```

Requirements:

1. Byte limits are Replaceable-genesis implementation constants; writes
   exceeding a limit revert with typed errors before storage or events.
   "Unbounded" is not an acceptable policy for any field.
2. `ARTIST_ERC1271_VERIFY_GAS` follows the full Governed Gas Parameter
   model (ADR 0010 decision D1): named constant, genesis value and floor
   in the release manifest, change events with old and new values,
   membership in the hard-fork/repricing review checklist, health probes
   for lowering, and exclusion from finality identity. Its floor and
   genesis value are sized against the heaviest named wallet class of
   the one wallet-class home, ADR 0004 [GOV-1271-CLASS] (ADR 0011
   decision R10).
3. Every governed time parameter above (dormancy inactivity and notice,
   rotation contest, estate-activation notice, unavailability-recovery
   notice) follows the same staged change discipline with immutable
   floors; time floors protect artists, so values may be raised freely
   and lowered only through the `DELAYED` class, never below the floor.
   Floors and genesis values are recorded in the release manifest and
   their change events carry old and new values. The rotation contest
   floor deliberately matches the 72-hour terminal-freeze veto floor
   ([`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-WINDOWS]): identity takeover deserves at least the reaction time
   a terminal freeze gets.

## Interfaces [AA-INTERFACES]

Permanent read surface (selector-stable; structs returned as tuples for
ABI stability):

```solidity
interface IStreamArtistRegistry {
    // identity
    function artistIdentity(bytes32 artistId)
        external view
        returns (
            address authorityAddress,
            uint8 authorityClass,
            uint8 status,
            bytes32 identityRecordHash,
            uint64 registeredAt,
            uint64 lastAuthorityActionAt,
            uint256 nonce
        );
    function artistIdForAddress(address account)
        external view returns (bytes32 artistId);
    function identityRecordBytes(bytes32 artistId)
        external view returns (bytes memory);

    // guardians and rotation contest (AA-GUARD)
    function guardianSet(bytes32 artistId)
        external view
        returns (
            address[] memory guardians,
            uint32 approvalThreshold,
            bytes32 guardianSetRecordHash
        );
    function pendingRotation(bytes32 artistId)
        external view
        returns (
            address oldAddress,
            address newAddress,
            uint64 contestEndsAt,
            uint32 guardianApprovals,
            bytes32 rotationRecordHash
        );

    // bindings and attribution
    function attributionState(uint256 collectionId)
        external view returns (uint8 state, uint64 generation);
    function attributionBinding(uint256 collectionId, uint64 generation)
        external view
        returns (
            bytes32 bindingHash,
            bytes32 artistId,
            address artistAddress,
            uint8 consentMode,
            uint8 collabPolicyMode,
            uint32 collabThreshold,
            bytes32 collaboratorSetHash,
            uint8 state
        );
    function collaboratorCount(uint256 collectionId, uint64 generation)
        external view returns (uint256);
    function collaboratorAt(
        uint256 collectionId,
        uint64 generation,
        uint256 index
    )
        external view
        returns (
            address account,
            bytes32 role,
            bytes32 shareLabelId,
            bool accepted
        );

    // sanctions and finality
    function verifySanctionForSubject(
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 sanctionSubjectHash
    )
        external view
        returns (
            bool valid,
            bytes32 sanctionRecordHash,
            address signer,
            uint8 authorityClass
        );
    function platformWorksDeclaration(uint256 collectionId)
        external view
        returns (bool declared, bytes32 declarationHash, uint64 declaredAt);
    function platformWorksContest(uint256 collectionId)
        external view
        returns (uint8 contestState, bytes32 claimRecordHash);
    function verifyRecoveryApproval(
        uint256 collectionId,
        bytes32 finalityRecordHash,
        bytes32 recoveryManifestHash
    )
        external view
        returns (
            bool valid,
            bytes32 approvalRecordHash,
            address signer,
            uint8 authorityClass
        );

    // attestations
    function artistAttestationStatus(
        uint256 collectionId,
        uint8 subjectKind,
        bytes32 subjectId,
        bytes32 currentSubjectStateHash
    )
        external view
        returns (
            uint8 status,
            bytes32 attestationRecordHash,
            bytes32 attestedSubjectStateHash,
            uint64 signedAt
        );

    // delegations
    function delegationState(bytes32 delegationRecordHash)
        external view
        returns (
            bool active,
            address delegate,
            uint256 collectionId,
            uint32 capabilities,
            uint64 notBefore,
            uint64 expiresAt,
            uint64 usesRemaining
        );

    // succession and dormancy
    function successorDesignation(bytes32 artistId)
        external view
        returns (
            address successor,
            uint8 successorKind,
            uint32 grantedCapabilities,
            bytes32 conditionsHash,
            bytes32 directiveHash,
            uint256 designationNonce
        );
    function dormancyState(bytes32 artistId)
        external view
        returns (uint8 identityStatus, uint64 noticeEndsAt);
    function estateActivationState(bytes32 artistId)
        external view
        returns (
            address successor,
            uint64 noticeEndsAt,
            bytes32 activationRecordHash
        );

    // record chains and evidence
    function collectionRecordChainHash(uint256 collectionId)
        external view returns (bytes32);
    function artistRecordChainHash(bytes32 artistId)
        external view returns (bytes32);
    function signatureBundle(bytes32 recordHash)
        external view returns (bytes memory);
}
```

`IStreamArtistConsent` is defined in `AA-CONSENT`. Write functions
(`proposeArtistBinding`, `acceptArtistBinding`, `refuseArtistBinding`,
`withdrawArtistBinding`, `acceptCollaborator`, `declarePlatformWorks`,
`filePlatformWorksClaim`, `setPlatformWorksContest`,
`recordArtistSanction`, `confirmSanctionFinalized`, `recordPolicyConsent`,
`recordEconomicsConsent`, `recordContentConsent`,
`authorizeArtistRoyaltyFreeze`, `authorizeArtistContentFreeze`,
`recordRecoveryApproval`, `recordUnavailabilityFinding`,
`recordArtistAttestation`,
`grantArtistDelegation`, `revokeArtistDelegation`, `setArtistGuardians`,
`rotateArtistAddress`, `approveArtistRotation`, `vetoArtistRotation`,
`executeArtistRotation`, `contestArtistIdentity`,
`recoverArtistIdentity`,
`designateSuccessor`, `recordEstateDirective`, `requestEstateActivation`,
`cancelEstateActivation`, `executeEstateActivation`,
`initiateArtistDormancy`, `cancelArtistDormancy`,
`completeArtistDormancy`, `openAttributionDispute`,
`recordCounterStatement`,
`resolveAttributionDispute`, `revokeAttribution`,
`revokeArtistAuthorization`) follow the requirements of their owning
sections; exact calldata struct shapes may be tuned during implementation
without changing the record semantics, preimages, or events, and the final
selectors are pinned in the release manifest.

## Events [AA-EVENTS]

Every event carries `uint16 schemaVersion` and at most three indexed
fields. Full payloads support event-only reconstruction (`AA-RECON`):
each record-emitting event carries every signer-chosen preimage field of
its record hash (including `nonce` and `signedAt`-class timestamps), so
no record hash depends on unevented values.

```solidity
event ArtistIdentityRegistered(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed authorityAddress,
    bytes32 identityRecordHash,
    string identityRecordURI,
    uint256 registrationNonce
);

event ArtistBindingProposed(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed artistId,
    address indexed artistAddress,
    uint64 bindingGeneration,
    bytes32 bindingHash,
    uint8 consentMode,
    uint8 collabPolicyMode,
    uint32 collabThreshold,
    bytes32 collaboratorSetHash,
    bytes32 capabilityPolicySetHash,
    address proposer,
    bytes32 reasonHash,
    string reasonURI
);

event ArtistBindingAccepted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed artistId,
    address indexed signer,
    uint64 bindingGeneration,
    bytes32 bindingHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 acceptanceRecordHash
);

event CollaboratorAccepted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed collaborator,
    uint64 bindingGeneration,
    bytes32 role,
    bytes32 shareLabelId,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 acceptanceRecordHash
);

event ArtistAttributionStateChanged(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint8 indexed newState,
    uint64 bindingGeneration,
    uint8 oldState,
    address actor,
    uint8 authorityClass,
    bytes32 recordHash,
    bytes32 reasonHash,
    string reasonURI
);

event PlatformWorksDeclared(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 declarationHash,
    bytes32 statementHash,
    address actor,
    uint64 declaredAt
);

event PlatformWorksClaimFiled(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed claimant,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    string reasonURI,
    uint64 filedAt,
    bytes32 claimRecordHash
);

event PlatformWorksContestChanged(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint8 indexed contestState, // CONTESTED | CONTEST_DISMISSED |
                                // CONTEST_SUSTAINED
    bytes32 claimRecordHash,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    bytes32 governanceActionId
);

event ArtistSanctionRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed sanctionSubjectHash,
    address indexed signer,
    uint8 scopeType,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 sanctionRecordHash,
    uint8 authorityClass,
    bytes32 statementHash,
    uint256 nonce,
    uint64 signedAt
);

event ArtistPolicyConsentRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed policyHash,
    address indexed signer,
    bytes32 phaseId,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 consentRecordHash
);

event ArtistEconomicsConsentRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed assignmentHash,
    address indexed signer,
    bytes32 revenueClass,
    uint8 scope,
    uint256 scopeId,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 consentRecordHash
);

event ArtistRoyaltyFreezeAuthorized(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed expectedAssignmentHash,
    address indexed signer,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 freezeRecordHash
);

event ArtistContentConsentRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed familyId,
    address indexed signer,
    bytes32 newStateHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 consentRecordHash
);

event ArtistContentFreezeAuthorized(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed signer,
    bytes32[] lockClasses,
    bytes32 expectedStateHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 freezeRecordHash
);

event ArtistRecoveryApprovalRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryManifestHash,
    address indexed signer,
    bytes32 finalityRecordHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 approvalRecordHash
);

event ArtistUnavailabilityFindingRecorded(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    uint256 indexed collectionId,
    uint64 noticeEndsAt,
    uint64 recordedAt,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    bytes32 findingRecordHash,
    bytes32 governanceActionId
);

event ArtistAttestationRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint8 indexed subjectKind,
    address indexed signer,
    bytes32 subjectId,
    bytes32 subjectStateHash,
    bytes32 schemaId,
    bytes32 statementHash,
    bytes32 statementURIHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 attestationRecordHash
);

event ArtistDelegationGranted(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed delegate,
    uint256 indexed collectionId,
    uint32 capabilities,
    uint64 notBefore,
    uint64 expiresAt,
    uint64 maxUses,
    bytes32 constraintsHash,
    uint256 nonce,
    bytes32 delegationRecordHash
);

event ArtistDelegationRevoked(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed delegate,
    bytes32 indexed delegationRecordHash,
    bytes32 reasonHash
);

event ArtistGuardianSetUpdated(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address[] guardians,
    uint32 approvalThreshold,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 guardianSetRecordHash
);

event ArtistRotationStaged(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed oldAddress,
    address indexed newAddress,
    uint64 stagedAt,
    uint64 contestEndsAt,
    uint256 nonce,
    bytes32 reasonHash,
    bytes32 rotationRecordHash
);

event ArtistRotationGuardianApproved(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed guardian,
    bytes32 indexed rotationRecordHash,
    uint32 approvals
);

event ArtistRotationVetoed(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed vetoer,
    bytes32 indexed rotationRecordHash,
    bytes32 reasonHash
);

event ArtistIdentityContested(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed contester,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint64 contestedAt,
    bytes32 contestRecordHash
);

event ArtistIdentityRecovered(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed oldAddress,
    address indexed newAddress,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    bytes32 supersededRecordsHash,
    uint64 recoveredAt,
    bytes32 recoveryRecordHash,
    bytes32 governanceActionId
);

event ArtistAddressRotated(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed oldAddress,
    address indexed newAddress,
    uint8 authorityClass,
    bytes32 reasonHash,
    bytes32 rotationRecordHash
);

event ArtistSuccessorDesignated(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed successor,
    uint8 successorKind,
    uint32 grantedCapabilities,
    bytes32 conditionsHash,
    bytes32 directiveHash,
    uint256 nonce,
    uint64 signedAt,
    bytes32 designationRecordHash
);

event ArtistEstateDirectiveRecorded(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    uint32 grantedCapabilities,
    uint32 forbiddenCapabilities,
    bytes32 directivePayloadHash,
    uint256 nonce,
    uint64 signedAt,
    bytes32 directiveRecordHash
);

event ArtistEstateActivationRequested(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed successor,
    uint64 requestedAt,
    uint64 noticeEndsAt,
    uint256 nonce,
    bytes32 evidenceHash,
    bytes32 activationRecordHash
);

event ArtistEstateActivationCancelled(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed canceller,
    uint8 authorityClass,
    bytes32 activationRecordHash
);

event ArtistSuccessionActivated(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed successor,
    uint8 authorityClass,
    uint32 effectiveCapabilities,
    bytes32 activationEvidenceHash,
    bytes32 governanceActionId // zero for permissionless execution
);

event ArtistDormancyInitiated(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    bytes32 indexed governanceActionId,
    uint64 noticeEndsAt,
    bytes32 evidenceHash,
    string reasonURI
);

event ArtistDormancyCancelled(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed canceller,
    uint8 authorityClass
);

event ArtistDormancyCompleted(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed vestedAuthority,
    uint8 authorityClass,
    uint32 effectiveCapabilities,
    bytes32 governanceActionId
);

event AttributionDisputeOpened(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed opener,
    uint64 bindingGeneration,
    uint8 openerAuthorityClass,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 openedAt,
    bytes32 disputeRecordHash
);

event AttributionCounterStatementRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed disputeRecordHash,
    address indexed signer,
    uint64 bindingGeneration,
    uint8 authorityClass,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 recordedAt,
    bytes32 counterStatementRecordHash
);

event AttributionDisputeResolved(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed disputeRecordHash,
    uint8 resolution,
    uint8 restoredState,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    bytes32 counterStatementRecordHash, // zero when none filed
    bytes32 governanceActionId
);

event ArtistAuthorizationRevoked(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    bytes32 revokedDigest,
    uint256 revokedNonce,
    uint256 nonce,
    uint64 revokedAt,
    bytes32 revocationRecordHash
);

event ArtistRegistryParameterChanged(
    uint16 schemaVersion,
    bytes32 indexed parameterId,
    uint256 oldValue,
    uint256 newValue,
    bytes32 governanceActionId
);
```

## Domain Constants And Typehashes [AA-DOMAINS]

Every constant below is Permanent and enters the domain-constants
discipline of
[`launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
(Domain Constants And Schema Versions), which carries the checker-verified
mirror rows. Hash values are pinned from their string preimages and CI
recomputes every preimage, failing on drift. Rows whose hash value reads
introduced in this revision were pinned from their exact adjacent string
preimages at authoring time; CI recomputes every value, and an unpinned
hash reaching a release manifest is a conformance failure.

### StreamArtistRegistry Hash Domains

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `ARTIST_ID_DOMAIN` | `6529STREAM_ARTIST_ID_V1` | 0x17025ea630b7c9d1ea5b6bf0e6375e9190581d7ef45b70c5244b82e48143e3df | `StreamArtistRegistry` | `1` | `ARTIST_ID_DOMAIN; uint256(block.chainid); address(registry); address(firstAddress); bytes32(identityRecordHash); uint256(registrationNonce)` |
| `ARTIST_BINDING_DOMAIN` | `6529STREAM_ARTIST_BINDING_V1` | 0x2ecc91c2aabdb535f25312ccca9a9f7f4ccda08dbaff9fac0423f236562918a0 | `StreamArtistRegistry` | `1` | `ARTIST_BINDING_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint64(bindingGeneration); bytes32(artistId); address(artistAddress); bytes32(identityRecordHash); uint8(consentMode); uint8(collabPolicyMode); uint32(collabThreshold); bytes32(collaboratorSetHash); bytes32(capabilityPolicySetHash)` |
| `COLLABORATOR_SET_DOMAIN` | `6529STREAM_ARTIST_COLLABORATOR_SET_V1` | 0x8e6d305019215c4390d1d804fef71d54d3b43e361f66837f5476ecfaf83c4289 | `StreamArtistRegistry` | `1` | `COLLABORATOR_SET_DOMAIN; CollaboratorRecord[] sorted ascending by (account, role, shareLabelId)` |
| `SANCTION_SUBJECT_DOMAIN` | `6529STREAM_ARTIST_SANCTION_SUBJECT_V1` | 0x47c9894872096248b3971f1551b555619aea8b63903f526c2da354a7286bb473 | `StreamArtistRegistry` | `1` | `SANCTION_SUBJECT_DOMAIN; uint256(block.chainid); address(core); address(finalityRegistry); uint8(scopeType); uint256(collectionId); uint256(tokenId); bytes32(scopeId); bytes32(coreFactsHash); bytes32(nonSanctionComponentsHash); bytes32(manifestURIHash); bytes32(manifestContentHash); bytes32(manifestSchemaId); bytes32(manifestCanonicalizationHash)` |
| `SANCTION_RECORD_DOMAIN` | `6529STREAM_ARTIST_SANCTION_RECORD_V1` | 0xc41417c9bc70713f2cd138ca6fa362e0868076b835d53f51e6d710a2be40dc6b | `StreamArtistRegistry` | `1` | `SANCTION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(signer); uint8(authorityClass); uint8(scopeType); uint256(collectionId); uint256(tokenId); bytes32(scopeId); bytes32(sanctionSubjectHash); bytes32(statementHash); uint256(nonce); uint64(signedAt)` |
| `PLATFORM_WORKS_DOMAIN` | `6529STREAM_PLATFORM_WORKS_DECLARATION_V1` | 0x6e2c16c800cfbfb61e5796751c487517f39063218731ac94bdf06929ec6c4441 | `StreamArtistRegistry` | `1` | `PLATFORM_WORKS_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); bytes32(statementHash); uint64(declaredAt)` |
| `POLICY_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1` | 0x2eebbe574cd30197850ff70c0036755a29224da718226068ffc4d1ea2f1f45a6 | `StreamArtistRegistry` | `1` | `POLICY_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(mintManager); uint256(collectionId); bytes32(phaseId); bytes32(policyHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `ECONOMICS_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1` | 0xc8480bd8b314f13ce90d2a190a53f2b0423cd8325d1080113867b79b79ed6fd3 | `StreamArtistRegistry` | `1` | `ECONOMICS_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(resolver); bytes32(revenueClass); uint8(scope); uint256(scopeId); bytes32(assignmentHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `ROYALTY_FREEZE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1` | 0x4008ba56591f508aff1cc667a65013859ee45bb7abd5506a6176389b97e32b9c | `StreamArtistRegistry` | `1` | `ROYALTY_FREEZE_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(resolver); uint256(collectionId); bytes32(revenueClass); bytes32(expectedAssignmentHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `DELEGATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_DELEGATION_RECORD_V1` | 0xf6aa4346269e975cd2ca6f06c3e610c53b2e6f6505d0707ed8c3661300151bbb | `StreamArtistRegistry` | `1` | `DELEGATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(delegate); uint256(collectionId); uint32(capabilities); uint64(notBefore); uint64(expiresAt); uint64(maxUses); bytes32(constraintsHash); uint256(nonce)` |
| `ATTESTATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTESTATION_RECORD_V1` | 0xa5320c9a6c82fac30567d7843275acca4cb9f68fd5bccff12411115bd197e512 | `StreamArtistRegistry` | `1` | `ATTESTATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint8(subjectKind); bytes32(subjectId); bytes32(subjectStateHash); bytes32(schemaId); bytes32(statementHash); bytes32(statementURIHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `DISPUTE_RECORD_DOMAIN` | `6529STREAM_ARTIST_DISPUTE_RECORD_V1` | 0xcd966414757b448743dc1228e0170513508888b6305f277d658bb84f40946c8f | `StreamArtistRegistry` | `1` | `DISPUTE_RECORD_DOMAIN; uint256(block.chainid); address(registry); uint256(collectionId); uint64(bindingGeneration); uint8(disputeAction); address(opener); uint8(openerAuthorityClass); bytes32(evidenceHash); bytes32(reasonHash); uint256(nonce); uint64(openedAt)` |
| `SUCCESSION_RECORD_DOMAIN` | `6529STREAM_ARTIST_SUCCESSION_RECORD_V1` | 0xe72b08eca38f3231b67e0fa8daba2f1d5daf1953d4b91f8c8e698d14f0ed2b0a | `StreamArtistRegistry` | `1` | `SUCCESSION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(successor); uint8(successorKind); uint32(grantedCapabilities); bytes32(conditionsHash); bytes32(directiveHash); uint256(nonce); uint64(signedAt)` |
| `DIRECTIVE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ESTATE_DIRECTIVE_RECORD_V1` | 0x993e7562ac3c0f8eddb70e4c49c42ef750a52133056061d419fdbe9ee7236f50 | `StreamArtistRegistry` | `1` | `DIRECTIVE_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); uint32(grantedCapabilities); uint32(forbiddenCapabilities); bytes32(directivePayloadHash); uint256(nonce); uint64(signedAt)` |
| `RECORD_CHAIN_DOMAIN` | `6529STREAM_ARTIST_RECORD_CHAIN_V1` | 0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e | `StreamArtistRegistry` | `1` | `RECORD_CHAIN_DOMAIN; bytes32(previousRecordChainHash); bytes32(recordHash)` |
| `CAPABILITY_POLICY_SET_DOMAIN` | `6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1` | 0x87c9af42ac310f72fd69d92f1c290288dcf159f63ed2a1fc75c7e66cc55704d0 | `StreamArtistRegistry` | `1` | `CAPABILITY_POLICY_SET_DOMAIN; CapabilityPolicyOverride[] sorted ascending by capabilityMask (disjoint, nonzero masks)` |
| `ACCEPTANCE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1` | 0x4b6ab2e018b05a2ca441cf6b0bc3e12a4674b70fd785051a0536faf074f995b4 | `StreamArtistRegistry` | `1` | `ACCEPTANCE_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint64(bindingGeneration); bytes32(bindingHash); uint8(acceptanceKind: 1 artist, 2 collaborator); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `GUARDIAN_SET_RECORD_DOMAIN` | `6529STREAM_ARTIST_GUARDIAN_SET_RECORD_V1` | 0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297 | `StreamArtistRegistry` | `1` | `GUARDIAN_SET_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address[] guardians strictly ascending; uint32(approvalThreshold); uint256(nonce); uint64(signedAt)` |
| `ROTATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ROTATION_RECORD_V1` | 0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5 | `StreamArtistRegistry` | `1` | `ROTATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(oldAddress); address(newAddress); bytes32(reasonHash); uint256(nonce); uint64(stagedAt); uint64(contestEndsAt)` |
| `IDENTITY_CONTEST_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_CONTEST_RECORD_V1` | 0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb | `StreamArtistRegistry` | `1` | `IDENTITY_CONTEST_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(contester); bytes32(evidenceHash); bytes32(reasonHash); uint64(contestedAt)` |
| `IDENTITY_RECOVERY_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_RECOVERY_RECORD_V1` | 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff | `StreamArtistRegistry` | `1` | `IDENTITY_RECOVERY_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(oldAddress); address(newAddress); bytes32(evidenceHash); bytes32(reasonHash); bytes32(supersededRecordsHash); bytes32(governanceActionId); uint64(recoveredAt)` |
| `IDENTITY_RECOVERY_SUPERSESSION_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_RECOVERY_SUPERSESSION_V1` | 0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae | `StreamArtistRegistry` | `1` | `IDENTITY_RECOVERY_SUPERSESSION_DOMAIN; bytes32[] supersededRecordHashes sorted ascending` |
| `CONTENT_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1` | 0x85ea98da8f1f57787fd3dc784129c3f4f4d4ac889735761822ba32cec9de0bee | `StreamArtistRegistry` | `1` | `CONTENT_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(metadataContract); address(core); uint256(collectionId); bytes32(familyId); bytes32(newStateHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `CONTENT_FREEZE_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1` | 0xdd3e1d6b06c6a49f0da1f66064526a5535238b6a1c258233a419aed42a968354 | `StreamArtistRegistry` | `1` | `CONTENT_FREEZE_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(metadataContract); address(core); uint256(collectionId); bytes32[] lockClasses sorted ascending; bytes32(expectedStateHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `RECOVERY_APPROVAL_RECORD_DOMAIN` | `6529STREAM_ARTIST_RECOVERY_APPROVAL_RECORD_V1` | 0xe60e6ec1d140fa0166261169322ac5c58d77797094a2b68866f812d1172e89b9 | `StreamArtistRegistry` | `1` | `RECOVERY_APPROVAL_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(finalityRegistry); uint256(collectionId); bytes32(finalityRecordHash); bytes32(recoveryManifestHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `UNAVAILABILITY_FINDING_RECORD_DOMAIN` | `6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1` | 0xc087b73d3ef4933341423d2630b88eca87257e38716a129b316ebc148a7fa1f5 | `StreamArtistRegistry` | `1` | `UNAVAILABILITY_FINDING_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); uint256(collectionId); bytes32(evidenceHash); bytes32(reasonHash); bytes32(governanceActionId); uint64(noticeEndsAt); uint64(recordedAt)` |
| `ESTATE_ACTIVATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1` | 0x2bd396eef0a5daaf54fe3c6b7a3888c3d7f7a237c3c4eb69f2848677ee96302f | `StreamArtistRegistry` | `1` | `ESTATE_ACTIVATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(successor); bytes32(evidenceHash); uint256(nonce); uint64(requestedAt); uint64(noticeEndsAt)` |
| `PLATFORM_WORKS_CLAIM_RECORD_DOMAIN` | `6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1` | 0x4b566ba07bf420b345ba4618b1dd0721da12c22766a8024791d4d651a170b0e6 | `StreamArtistRegistry` | `1` | `PLATFORM_WORKS_CLAIM_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); address(claimant); bytes32(evidenceHash); bytes32(reasonHash); uint64(filedAt)` |
| `AUTH_REVOCATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1` | 0x52beeaf4afc420319e9e3d55d092b732ea0ad2a3407f22b60918c0acb7c7d1e5 | `StreamArtistRegistry` | `1` | `AUTH_REVOCATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); bytes32(revokedDigest); uint256(revokedNonce); uint256(nonce); uint64(revokedAt)` |
| `GGP_ARTIST_ERC1271_VERIFY_GAS` | `6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS` | 0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5 | `StreamArtistRegistry` | `1` | Governed Gas Parameter identifier per [LTA-GGP] definition item 5; no `abi.encode` inputs ([AA-SIGVER]) |

### StreamArtistRegistry EIP-712 Typehashes

EIP-712 domain: `name = "6529StreamArtistRegistry"`, `version = "1"`,
`chainId`, `verifyingContract = address(registry)`. Each typehash is
`keccak256` of the exact string below; field inventories are normative
(ADR 0010 decision D3.5).

| Constant name | Typehash string preimage | Hash value | Owner | Schema version |
| --- | --- | --- | --- | --- |
| `STREAM_ARTIST_ACCEPTANCE_TYPEHASH` | `StreamArtistAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)` | 0x863408883ac6994b06f1a735545fd486c6a1a53866fb8851488d56d1b54f92af | `StreamArtistRegistry` | `1` |
| `STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH` | `StreamCollaboratorAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline)` | 0x636ddaeeea1f3879203e4707eba02a65484041c3869c8a04560af9a57886343b | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_SANCTION_TYPEHASH` | `StreamArtistSanction(address core,uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId,bytes32 sanctionSubjectHash,bytes32 statementHash,uint256 nonce,uint64 deadline)` | 0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_POLICY_CONSENT_TYPEHASH` | `StreamArtistPolicyConsent(address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline)` | 0xbb408425c14bb658b72c5c6d190446d6d3cce65e6cb127239882bff780982c2b | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH` | `StreamArtistEconomicsConsent(address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline)` | 0x38c2c794170472cc1bbd6385664d7d8a409ce16455caa0db97392b80fbc4b434 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH` | `StreamArtistRoyaltyFreeze(address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline)` | 0x34f54304a829e6bd32c4bcd8d63f31f7652adf9d1d653b874107a0a93eee73c4 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_DELEGATION_TYPEHASH` | `StreamArtistDelegation(address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce)` | 0x259b01d4bf9aa04d6f900a2f85548eebdbb07661fdf1eac68031895cadae6d0d | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ATTESTATION_TYPEHASH` | `StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)` | 0x74b9521f5d5caa162fb97b3a7f8e6aa5352156e3a1ff7c8e8103092eaaeaaa08 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_KEY_ROTATION_TYPEHASH` | `StreamArtistKeyRotation(bytes32 artistId,address oldAddress,address newAddress,bytes32 reasonHash,uint256 nonce,uint64 deadline)` | 0x5b4e68760703787cefafa5c70864d397b1de70e70818739680256a123fe7a184 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH` | `StreamArtistRotationAcceptance(bytes32 artistId,address oldAddress,address newAddress,uint256 nonce,uint64 deadline)` | 0x87eea3b0d5e1275bbdc74e691b4e19a12e9e76b634bac03ae439ae584859ecd0 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH` | `StreamArtistSuccessorDesignation(bytes32 artistId,address successor,uint8 successorKind,uint32 grantedCapabilities,bytes32 conditionsHash,bytes32 directiveHash,uint256 nonce,uint64 signedAt)` | 0x978b9dfcca0968239ea043e735357728a9489fe40067fea6673256206c83de15 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH` | `StreamArtistEstateDirective(bytes32 artistId,uint32 grantedCapabilities,uint32 forbiddenCapabilities,bytes32 directivePayloadHash,uint256 nonce,uint64 signedAt)` | 0xa1f146b360069294c6453e91242bb36bb0245545d57b3c89e1cc73c25e953d31 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH` | `StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)` | 0x8b535108c442947650eb1dec541e1e10f715f240a1554e488f2d4a51afb31541 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH` | `StreamArtistAuthorizationRevocation(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline)` | 0xd1d93f1d81c2c2b5353543093ebfca89c460de55b540dfed4a019c7ac448f214 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_GUARDIAN_SET_TYPEHASH` | `StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint256 nonce,uint64 signedAt)` | 0xc1d4df790f8ec0e3a2f9171e160c06485194d9257a8f13d97c206eedfeffe7b3 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH` | `StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)` | 0x7908964dc70554ffd5c82353690255d1a8c338be77ffc0f8fb925a27d890587d | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH` | `StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)` | 0xfcb15d96b29996a5852bf06058ae82a7e8acaf7d7601b13fe881ada5d30fc63b | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH` | `StreamArtistRecoveryApproval(address core,address finalityRegistry,uint256 collectionId,bytes32 finalityRecordHash,bytes32 recoveryManifestHash,uint256 nonce,uint64 deadline)` | 0x242bffdf15416a6743c57bd362683aa2933edcd42a4ef176f4e983a745eee511 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH` | `StreamArtistEstateActivation(bytes32 artistId,address successor,bytes32 evidenceHash,uint256 nonce,uint64 deadline)` | 0x35ad5d0278eb067119334d7d4fddd596cad723598851900a95e6ad9a94e51a8a | `StreamArtistRegistry` | `1` |

Component type constants (values enter the same table):

```text
keccak256("ARTIST_SANCTION")             0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047
keccak256("PLATFORM_WORKS_DECLARATION")  0x9b732a2be945a9747de080e93cd0a83076acad44dca7585847960ffebdb0d29d
keccak256("STREAM_ARTIST_REGISTRY")      0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a (module type)
keccak256("artist")                      0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb (ARTIST beneficiary label)
```

Pinned schema identifiers (values enter the same table, computed from the
exact strings below):

```text
keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_V1")   0xa7222b7835606e613ba5eee0ebc23654b567e946e997bb27e127e24ed9534c44
    sanction ceremony document schema (AA-SANCTION requirement 9)
keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1")    0x89276c3535c7321ce7f36b8228b64a1b1b9667d531786d9d68df290f9bd0768a
    C2PA credential enumeration attestation schemaId (AA-C2PA)
```

## Event Reconstruction [AA-RECON]

Requirements:

1. The implementation test suite must include a harness that rebuilds,
   from events alone, and compares against direct reads: artist
   identities and authority addresses through every staged rotation,
   contest, recovery, and succession; guardian sets and rotation
   contest timelines; binding generations, collaborator sets, capability
   policy overrides, and acceptance states; the attribution state
   timeline per collection; consent modes, platform-works declarations,
   claims, and contest states; policy, economics, and content consent
   records keyed by their hashes; content freezes; sanction records and
   their subjects; recovery approvals and unavailability findings;
   attestations with staleness inputs; delegations with grant, use, and
   revocation state; successor designations, directives, and estate
   activation timelines; dormancy timelines; disputes,
   counter-statements, and resolutions; authorization revocations; and
   both record-chain accumulators.
2. Every record hash emitted must be recomputable from event payload
   fields plus the pinned domain constants; no record may depend on
   unevented storage.
3. The registry's events enter the machine-readable event catalog with
   schema versions, indexed-field lists, and semantic owner, per the
   umbrella spec's Hash And Manifest Discipline.

## Artist Ceremony Tooling And Rehearsal [AA-TOOLING]

A single artist-bound collection requires binding acceptance,
collaborator acceptances, per-phase policy consent, economics consent,
an intent record, and a finality sanction — each an EIP-712 ceremony
over hashes no human can read. Fifty-year consent guarantees are only
real if year-one artists can complete them, so tooling and rehearsal are
conformance-gated, not aspirational (ADR 0011 decisions R7.7 and R12).
This section is Operational-layer: it binds release evidence and
tooling, never contract semantics.

Requirements:

1. A named artist signing tool ships with the release and must render,
   for every typed payload family in this document, a human-readable
   summary of what is being signed — resolved collection, phase, policy,
   economics, content, or subject facts, never bare `bytes32` values —
   before requesting the signature. The tool's name and version are
   recorded in release evidence and in sanction ceremony documents
   (`AA-SANCTION` requirement 9).
2. The release must include a rehearsed end-to-end artist onboarding on
   the rehearsal deployment: identity registration (with guardian-set
   registration recommended in-flow, `AA-GUARD` requirement 1), binding
   proposal and acceptance, collaborator acceptance, policy consent,
   economics consent, intent record, a mint under the consented policy,
   and a finality sanction over a `previewFinality`-computed subject.
   The rehearsal artifact records the total ceremony count and
   wall-clock signing latency per ceremony; both measurements enter
   release evidence so onboarding friction is a tracked number, not an
   anecdote. The rehearsal must also capture the artist's recorded
   acknowledgment of the disclosure-only royalty term before first
   public sale
   ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   [RSR-MARKETPLACE-ROYALTY] rule 3; protocol v1 exclusions item 1), and
   the acknowledgment record enters the same rehearsal artifact.
3. Tooling must handle consent churn: when a `policyHash` or
   `assignmentHash` changes after a consent was gathered but before
   registration, the tool must detect the drift, invalidate the stale
   ceremony, and re-present the changed facts — silent re-signing of
   changed hashes is nonconformant.
4. An independent, openly published recomputation tool — part of the
   reconstruction-client obligations of
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   — must recompute `sanctionSubjectHash`, `bindingHash`, and every
   record hash in this document from public inputs without operator
   infrastructure, so an artist can verify what they are signing against
   software the operator does not control.
5. Estate and dormancy runbooks (outreach before initiation, activation
   evidence assembly, steward onboarding) remain Operational documents;
   this section adds that they must be exercised in the rehearsal run at
   least to the point of staging (initiation and cancel), so no
   estate-path transaction is executed for the first time in production.

## Conformance Gates [AA-GATES]

These gates enter [`launch-conformance-matrix.md`](launch-conformance-matrix.md)
(Required Gates); deployment is blocked while any fails:

1. Artist binding gate: two-sided acceptance required; admin cannot
   self-accept; unverified display until acceptance; generation history
   reconstructs from events.
2. Artist sanction gate: `finalizeCollectionArtwork` and
   `finalizeArtworkScope` revert for artist-bound collections without a
   verified sanction over the exact computed subject hash; subject drift
   invalidates; `PLATFORM_WORKS` collections bind the declaration
   component; no collection finalizes with neither component.
3. Consent-mode gate: phase policy registration reverts for
   `CONSENT_UNSET`; `ARTIST_SIGNED_POLICY` rejects delegated consent;
   stale policy hashes authorize nothing; mint events chain to consent
   records; `requireMintConsent` runs on every mint execution and fails
   closed on `DISPUTED` mid-drop; pause and unpause of an
   `ARTIST_SIGNED_POLICY` phase execute with no artist signature and no
   policy re-registration, in every attribution state including
   `DISPUTED` (golden pause-then-resume test, ADR 0011 decision R6).
4. Economics gate: artist-bound assignment changes revert without verified
   economics consent; artist royalty freeze applies exactly once against
   the expected assignment hash; artist-majority default template and
   split disclosure verified.
5. Signature verification gate: ECDSA nonzero-and-matched plus
   non-canonical rejection negative tests (high-`s`, `v` outside
   `{27, 28}`, per `AA-SIGVER` requirement 1); ERC-1271
   wrong-magic/out-of-gas/malformed rejection; GGP floor, raise,
   lower, and probe tests for `ARTIST_ERC1271_VERIFY_GAS`; signature-bytes
   storage and oversized-bundle archival-proof path; unordered-nonce
   tests: two outstanding payloads submitted in reverse order both
   verify, and consuming or revoking a nonce value in one identity's
   space never affects another identity's payloads.
6. Lifecycle gate: rotation requires both sides and stages behind the
   contest window; guardian approval executes early, a single-guardian
   veto cancels and contests, prior-address contests stand after
   execution, provisional post-rotation records wait out the window, and
   identity recovery preserves `artistId` while superseding adjudicated
   records; estate activation runs permissionlessly after its notice
   window, cancels on artist liveness, rechecks the operative
   designation at execution, and accelerates — never gates — on
   governance confirmation; dormancy respects inactivity and notice
   floors, cancels on any liveness, and appoints stewards without
   `CAP_POLICY_CONSENT`; forbidden capability masks are absolute;
   `COLLABORATOR_QUORUM` and capability-policy overrides execute
   without the primary where designated.
7. Dispute gate: standing enforcement, evidence requirement, blocking
   while disputed, arbiter resolution paths under the `DELAYED` class
   with counter-statement linkage, appeal-tier cancel of a staged
   resolution, reopen of an `ARBITER_REVOKED` generation with new
   evidence, prospective-only revocation, arbiter-gated rebinding after
   revocation; platform-works claims file permissionlessly with
   evidence, `CONTESTED` blocks finality, and sustained contests display
   permanently.
8. Display gate: renderer emits the `AA-DISPLAY` attribution object with
   golden assertions on the presence and paths of `state`, `works_class`,
   `consent_mode`, `artist_id`, `binding_generation`,
   `attestation_status`, `sanction_record`, `contested`, and
   `c2pa_authorship_status` across all five states, both works classes,
   staleness, the disputed override, and the contested platform-works
   case, verified against registry reads; no surface emits the retired
   flat fields.
9. Write-authority gate: `ARTIST_*` families reject non-artist writers in
   every genesis satellite; every artist-authority event carries recorder
   and authority class; record-chain accumulators verify against replayed
   history and appear in state exports.
10. Identity-archival gate: identity registration stores canonical
    document bytes onchain whose keccak256 equals `identityRecordHash`;
    oversized documents revert; binding acceptance refuses to complete
    without the stored bytes plus a dual-family archival record with a
    verifiable receipt for the identity document (`AA-IDENTITY`
    requirement 2).
11. Content-authority gate: post-first-mint content-affecting writes on
    artist-bound collections revert without verified content consent
    over the exact resulting state hash; pre-mint and post-finality
    writes need none; the artist content freeze applies the named locks
    exactly once against the expected state hash; delegated content
    consent is rejected on `ARTIST_SIGNED_POLICY` collections
    (`AA-CONTENT`).
12. Recovery-approval gate: an `artworkBytesChanged = true` recovery for
    an artist-bound collection reverts without a verified
    `StreamArtistRecoveryApproval` over the exact finality record and
    recovery manifest, or a recorded unavailability finding plus its
    notice window; an artist-authority action during the window voids
    the fallback (`AA-RECOVERY`).
13. Ceremony-tooling gate: the rehearsed end-to-end onboarding artifact
    of `AA-TOOLING` exists in release evidence with ceremony-count and
    latency measurements, the named signing tool renders every typed
    payload family human-readable, and the independent recomputation
    tool reproduces `sanctionSubjectHash` and `bindingHash` from public
    inputs (`AA-TOOLING`; ADR 0011 decision R12).

## Exclusions [AA-EXCL]

Artist authority intentionally does not cover the following. Exclusion is
intentional absence, not deferral (per
[`docs/spec-policy.md`](spec-policy.md)):

1. Legal enforcement. Bindings, sanctions, directives, and rights records
   are cryptographic evidence and notice, not contracts of adhesion; they
   compel no offchain actor by themselves, and estates must still resolve
   law offchain (the rights posture of
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   applies).
2. Identity vetting. The registry proves address control and consent
   chains; it does not prove that a human is who a display name claims.
   Institutional verification lives in attestation records and offchain
   diligence.
3. Payment custody. The registry never holds, routes, or releases funds;
   split wallets and escrow are owned by
   [`revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md),
   and no registry authority can move owed balances (`AA-SPLITS`).
4. Collector-side or owner-side records (accession, condition, loans);
   those are the owner-records surface of the museum object dossier
   (ADR 0010 decision D6.2).
5. Curation authority. Curator identities and curatorial attestations are
   metadata-satellite concerns; this registry grants curators no standing
   over attribution.
6. Secondary-market attribution display by third parties. The protocol
   exposes truthful state; it cannot compel external marketplaces to
   render it.
7. Ongoing-work co-creation mechanics (shared canvases, post-mint
   parameter changes); any future module builds behind these interfaces
   through its own accepted spec.
8. Retroactive rewrites. No authority in this document — artist, estate,
   steward, arbiter, or governance — can alter executed finality records,
   historical mints, consumed consents, or economics history.
