# Stream Artist Authority

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md). Its decisions are taken by
[ADR 0010](adr/0010-world-class-spec-pass.md) (decision D2); it contains no
open questions.

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
  - key rotation, successor designation, pre-signed estate directives
  - governed dormancy procedure with long public notice
  - append-only dispute and revocation records with a governed arbiter
  - onchain signature verification (EIP-712 + ERC-1271, GGP-governed gas)
  - onchain storage of verified signature bytes
  - rolling record-chain accumulators for provable history completeness

Consumers
  - StreamMintManager: refuses artist-bound phases without verified consent
  - Revenue resolver: refuses artist-bound assignment changes without
    verified artist co-signature; applies artist royalty freezes
  - StreamArtworkFinalityRegistry: requires the artist sanction component
  - StreamMetadataRouter / renderers: expose attribution state in token JSON
  - StreamCollectionMetadata: stores display fields and record satellites
```

The registry holds authority truth. Display fields, statements, media, and
identity documents live in the
[`collection-metadata-contract.md`](collection-metadata-contract.md)
satellites and are evidence, not authority.

## Permanence Classification [AA-PERM]

Requirements are classified per [`docs/spec-policy.md`](spec-policy.md):

| Surface | Class |
| --- | --- |
| Artist identity semantics: `artistId` derivation, binding preimages, acceptance semantics, attribution states and numeric values, consent-mode semantics and numeric values, authority classes, sanction subject and record preimages, typehash strings, event schemas, canonical orderings | Permanent |
| `IStreamArtistRegistry`, `IStreamArtistConsent`, and the finality component read surfaces this registry implements | Permanent |
| The two-sided binding rule, the unverified-attribution display rule, the artist-sanction finality requirement, the platform-works immutability rule, the append-only record discipline | Permanent |
| `StreamArtistRegistry` genesis implementation, its storage layout, and its byte limits | Replaceable (genesis module behind the Permanent interfaces) |
| `ARTIST_ERC1271_VERIFY_GAS` value, dormancy notice and inactivity values above their immutable floors | Operational (governed parameters, excluded from finality identity) |
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
   phase policy, `policyHash`, `MintTicket`, and mint execution order. This
   document owns the consent-mode model and the consent records the mint
   manager must verify before registering or serving artist-bound phases.
3. [`revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   owns split profiles, templates, `assignmentHash`, freeze mechanics, and
   release authorization. This document owns the artist economics rights
   that constrain those flows for artist-bound collections.
4. [`collection-metadata-contract.md`](collection-metadata-contract.md)
   owns collection display metadata, record storage satellites, locks, and
   snapshots. `CollectionPeople.artistAddress` and collaborator display
   fields are display data; the registry binding defined here is the
   authority. The metadata contract's artist attestation storage adopts the
   state-bound payload defined here.
5. [`metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   owns token JSON schemas. This document owns the attribution states and
   the required display semantics the renderer must expose.
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
ROLE_ATTRIBUTION_ARBITER     governed arbiter for attribution disputes and
                             post-revocation rebinding approval
ROLE_ARTIST_DORMANCY_ADMIN   initiates and completes the governed dormancy
                             procedure through staged governance actions
```

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
    IDENTITY_SUCCEEDED  // 3 authority vested in successor or steward
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
    uint256 nonce;               // next unused typed-authorization nonce
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
   JSON) containing display name, biographical references, and public-key
   history references. The document is stored through the collection
   metadata record satellites and mirrored under the dual-family archival
   rule (ADR 0010 decision D4.6). The hash, not the URI, is authoritative.
3. Every authenticated artist-side action (acceptance, sanction, consent,
   attestation, delegation grant or revocation, rotation, designation,
   directive, dispute action) must update `lastAuthorityActionAt`.
4. `nonce` is a single monotonically consumed space per identity across all
   typed authorizations in this document. Each verified typed payload
   consumes exactly the nonce it names; nonces are never reusable.
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
    ALL_COLLABORATORS,  // 1 every accepted collaborator must co-act
    THRESHOLD           // 2 primary plus threshold-many collaborators
}

struct CollaboratorRecord {
    address account;      // collaborator authority address
    bytes32 role;         // open vocabulary, see AA-COLLAB
    bytes32 shareLabelId; // split-profile label reference, see AA-ECON
}

struct ArtistBindingProposal {
    bytes32 artistId;         // zero to allocate a new identity
    address artistAddress;    // proposed authority address
    bytes32 identityRecordHash;
    string identityRecordURI;
    ArtistConsentMode consentMode;      // must not be CONSENT_UNSET
    CollabPolicyMode collabPolicyMode;
    uint32 collabThreshold;             // THRESHOLD mode only
    CollaboratorRecord[] collaborators; // sorted, see AA-COLLAB
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
    bytes32(collaboratorSetHash)
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
   consent mode, collaborator policy, and full collaborator set in one
   signature. Any change to any of those fields before acceptance requires
   a new generation.
3. Acceptance is valid only by direct call from `artistAddress` or by a
   verified `StreamArtistAcceptance` signature under `AA-SIGVER`. Platform
   roles must not be able to accept; there is no admin bypass.
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
   ratified by every acceptance — define how many collaborator
   co-signatures artist-gated actions need:
   `PRIMARY_ONLY` requires the primary artist authority only;
   `ALL_COLLABORATORS` requires the primary plus every accepted
   collaborator; `THRESHOLD` requires the primary plus at least
   `collabThreshold` accepted collaborators. The mode applies uniformly to
   sanction, policy consent, economics consent, royalty freeze, and
   revocation actions.
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
5. `REVOKED` is terminal per generation and prospective only: it changes
   display and future authority, and it never rewrites executed finality
   records, mint history, or economics history. Posthumous or corrective
   rebinding starts a new generation at `CLAIMED` and requires
   `ROLE_ATTRIBUTION_ARBITER` approval when the prior generation ended
   `REVOKED`, so an operator cannot spam re-claims over a repudiation.
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

Requirements:

1. Until a binding reaches `ARTIST_ACCEPTED`, every consumer surface —
   token JSON, `contractURI`, operator frontends, marketplace feeds — must
   render the attribution as unverified (ADR 0010 decision D2.1). The
   default renderer satisfies this by emitting
   `properties.provenance.attribution.state = "claimed"` and must not
   present the artist name as verified fact in that state.
2. For artist-bound collections, default token JSON must include, under
   `properties.provenance.attribution`: `state` (one of the five strings
   above, resolved for the token's scope), `artist_id`, `artist_address`,
   `binding_generation`, `attestation_status` (`none`, `attested_current`,
   `attested_stale`, or `disputed`, from `AA-ATTEST`),
   `attestation_record` and `attested_state_hash` (the staleness-aware
   attestation record hash and its attested digest, when one exists), and,
   when a sanction covers the token, `sanction_record` (the sanction
   record hash). Platform assertion is never rendered as artist fact.
3. For `PLATFORM_WORKS` collections, default token JSON must include
   `properties.provenance.attribution.works_class = "platform_works"` and
   must omit artist fields rather than fabricate them (`AA-PLATFORM`).
   Artist-bound collections expose `works_class = "artist_bound"`.
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
   classes, staleness, and the disputed override (`AA-GATES`).
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

1. EOA signatures use ECDSA recovery; the recovered address must be nonzero
   and must exactly match the required signer. A zero recovery result is a
   verification failure, never a wildcard (ADR 0010 decision D8.3).
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
4. The supported wallet class is any wallet that completes verification
   within the current parameter value; because the parameter is raisable, a
   future heavier wallet can be supported without a registry redeploy.
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
7. Delegates never gain rotation, successor-designation, directive,
   delegation-granting, or revocation-of-attribution powers; those are
   non-delegable.

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
the complete mintability policy — without modifying the pinned
`POLICY_DOMAIN` preimage.

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
   prerequisite of `AA-ECON` requirement 4 is satisfied. The mint manager
   must call it before registering a phase policy and before serving mints
   whenever the active policy hash changes
   ([`mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   mirrors this as a mint-path requirement).
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
   `dataHash = platformWorksDeclarationHash` and `frozen = true`; finality
   for artist-less collections binds the immutable declaration instead of
   a sanction. Exactly one of the two component types applies to any
   collection; a finality submission carrying neither, for any collection,
   is nonconformant.
8. There is no unsigned finalization path for artist-bound collections.
   Key loss and death do not soften this rule; they route through
   succession and dormancy (`AA-ESTATE`, `AA-DORMANCY`), which produce an
   authorized, clearly-classified signer. Absence of artist sanction is
   therefore always provable intent (`PLATFORM_WORKS`), never silence.

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
   recovery rules of the umbrella spec.

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
artist does not control.

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
2. Rotation updates `authorityAddress` for the `artistId` across every
   binding at once, emits `ArtistAddressRotated` with old address, new
   address, authority class, and reason hash, and preserves the full
   address history in events. `artistId` and all bindings, consents,
   sanctions, and attestations are unaffected: history stays attributed to
   the identity, not the key.
3. Rotation never changes split-wallet entitlements (`AA-SPLITS`
   requirement 4) and never revokes delegations (`AA-DELEG` requirement 3).
4. A compromised-key response is a rotation followed by
   `revokeArtistAuthorization` of any outstanding unused signed payloads
   (`AA-REVOKE`); operator runbooks must document this two-step and the
   registry must allow both in one transaction.
5. Rotation is available to collaborator identities identically.

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

Requirements:

1. Designations and directives are recorded only under `AUTH_ARTIST`
   authority (direct or signed), verified under `AA-SIGVER`, evented, and
   append-only; the record with the highest nonce is the operative one.
   Successors and stewards cannot rewrite them.
2. A designation activates only through one of two evented paths:
   (a) completion of the governed dormancy procedure (`AA-DORMANCY`); or
   (b) an estate-initiated activation — a direct call or verified
   signature from the designated successor — plus a confirming governance
   action of the normal delay class carrying the activation evidence
   hash (dual evidence: estate attestation and staged governance action).
   Activation sets the identity status to `IDENTITY_SUCCEEDED`, vests
   `AUTH_SUCCESSOR` in the successor limited to `grantedCapabilities`
   minus `forbiddenCapabilities`, and revokes all outstanding delegations.
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
    uint8 disputeAction,     // 1 OPEN, 2 WITHDRAW
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
   evented, reasoned, and append-only.
5. The bound artist authority may directly repudiate their own attribution
   with `revokeAttribution` (collaborator policy applies); this is the
   artist's unilateral exit and requires no arbiter.
6. Revocation semantics are prospective-only per `AA-STATE` requirement 5:
   display changes everywhere, future authority ends, history and executed
   finality records remain intact and permanently marked. A fraudulent
   binding discovered after an `ARTIST_IDENTITY`-style metadata lock is
   still repudiable here, because registry truth — not the display lock —
   is the authority consumers must read.
7. Dispute vocabulary (`DISPUTED`, `REVOKED`, resolution codes `UPHELD`,
   `REVOKE`, reason codes `REFUSED`, `WITHDRAWN`, `REPUDIATED_BY_ARTIST`,
   `ARBITER_REVOKED`) enters the numeric ID catalog.

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
   (acceptances, sanctions, consents, delegations, rotations,
   designations, directives, disputes). A revoked-then-submitted payload
   reverts.
3. Already-consumed authorizations cannot be revoked; revocation is
   preventive, never historical.

## Record Discipline And Write Authority [AA-RECORDS]

The CON-015 whole-module writer exception is retired for artist authority
(ADR 0010 decision D2.8): genesis uses record-family-scoped, signature
-verified writer authorization.

Requirements:

1. Every artist-authority record family defined here (bindings,
   acceptances, sanctions, consents, delegations, rotations, designations,
   directives, dormancy records, disputes, attestations, freeze
   authorizations) is writable only through the authenticated paths of
   this registry. No safe-operator, metadata-admin, or whole-module writer
   role can author them, at genesis or ever.
2. `ARTIST_*` record families in the collection metadata satellites must
   reject writers that do not hold live artist authority in this registry
   for the subject collection; the generic v1 satellite enforces this from
   genesis (the collection metadata spec mirrors the storage-side check).
3. Every record event includes the recorder address and
   `ArtistAuthorityClass`, so artist-authored and operator-authored
   provenance are permanently distinguishable in the event stream.
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
5. Registry records referenced by finality manifests (sanctions, intent
   waivers, platform-works declarations) are covered by the dual-family
   archival rule before finality executes (ADR 0010 decision D4.6);
   onchain-stored signature bytes (`AA-SIGVER` requirement 6) satisfy the
   onchain family.

## Limits And Governed Parameters [AA-LIMITS]

```text
MAX_COLLABORATORS                 32
MAX_STORED_SIGNATURE_BYTES        4,096
MAX_DIRECTIVE_PAYLOAD_BYTES       8,192
MAX_IDENTITY_RECORD_URI_BYTES     2,048
MAX_REASON_URI_BYTES              2,048
ARTIST_ERC1271_VERIFY_GAS         GGP; floor 90,000; genesis 150,000
ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS
                                  floor 31,536,000; genesis 63,072,000
ARTIST_DORMANCY_NOTICE_SECONDS    floor 15,552,000; genesis 31,536,000
```

Requirements:

1. Byte limits are Replaceable-genesis implementation constants; writes
   exceeding a limit revert with typed errors before storage or events.
   "Unbounded" is not an acceptable policy for any field.
2. `ARTIST_ERC1271_VERIFY_GAS` follows the full Governed Gas Parameter
   model (ADR 0010 decision D1): named constant, genesis value and floor
   in the release manifest, change events with old and new values,
   membership in the hard-fork/repricing review checklist, health probes
   for lowering, and exclusion from finality identity.
3. The dormancy time parameters follow the same staged change discipline
   with immutable floors; their floors and genesis values are recorded in
   the release manifest and their change events carry old and new values.

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
`recordArtistSanction`, `confirmSanctionFinalized`, `recordPolicyConsent`,
`recordEconomicsConsent`,
`authorizeArtistRoyaltyFreeze`, `recordArtistAttestation`,
`grantArtistDelegation`, `revokeArtistDelegation`, `rotateArtistAddress`,
`designateSuccessor`, `recordEstateDirective`, `activateSuccessor`,
`initiateArtistDormancy`, `cancelArtistDormancy`,
`completeArtistDormancy`, `openAttributionDispute`,
`resolveAttributionDispute`, `revokeAttribution`,
`revokeArtistAuthorization`) follow the requirements of their owning
sections; exact calldata struct shapes may be tuned during implementation
without changing the record semantics, preimages, or events, and the final
selectors are pinned in the release manifest.

## Events [AA-EVENTS]

Every event carries `uint16 schemaVersion` and at most three indexed
fields. Full payloads support event-only reconstruction (`AA-RECON`).

```solidity
event ArtistIdentityRegistered(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed authorityAddress,
    bytes32 identityRecordHash,
    string identityRecordURI
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
    address actor
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
    bytes32 statementHash
);

event ArtistPolicyConsentRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed policyHash,
    address indexed signer,
    bytes32 phaseId,
    uint8 authorityClass,
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
    bytes32 consentRecordHash
);

event ArtistRoyaltyFreezeAuthorized(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed expectedAssignmentHash,
    address indexed signer,
    uint8 authorityClass,
    bytes32 freezeRecordHash
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
    bytes32 delegationRecordHash
);

event ArtistDelegationRevoked(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed delegate,
    bytes32 indexed delegationRecordHash,
    bytes32 reasonHash
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
    bytes32 designationRecordHash
);

event ArtistEstateDirectiveRecorded(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    uint32 grantedCapabilities,
    uint32 forbiddenCapabilities,
    bytes32 directivePayloadHash,
    bytes32 directiveRecordHash
);

event ArtistSuccessionActivated(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed successor,
    uint8 authorityClass,
    uint32 effectiveCapabilities,
    bytes32 activationEvidenceHash,
    bytes32 governanceActionId
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
    bytes32 disputeRecordHash
);

event AttributionDisputeResolved(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed disputeRecordHash,
    uint8 resolution,
    uint8 restoredState,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    bytes32 governanceActionId
);

event ArtistAuthorizationRevoked(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    bytes32 revokedDigest,
    uint256 revokedNonce,
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
recomputes every preimage, failing on drift.

### StreamArtistRegistry Hash Domains

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `ARTIST_ID_DOMAIN` | `6529STREAM_ARTIST_ID_V1` | 0x17025ea630b7c9d1ea5b6bf0e6375e9190581d7ef45b70c5244b82e48143e3df | `StreamArtistRegistry` | `1` | `ARTIST_ID_DOMAIN; uint256(block.chainid); address(registry); address(firstAddress); bytes32(identityRecordHash); uint256(registrationNonce)` |
| `ARTIST_BINDING_DOMAIN` | `6529STREAM_ARTIST_BINDING_V1` | 0x2ecc91c2aabdb535f25312ccca9a9f7f4ccda08dbaff9fac0423f236562918a0 | `StreamArtistRegistry` | `1` | `ARTIST_BINDING_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint64(bindingGeneration); bytes32(artistId); address(artistAddress); bytes32(identityRecordHash); uint8(consentMode); uint8(collabPolicyMode); uint32(collabThreshold); bytes32(collaboratorSetHash)` |
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

Component type constants (values enter the same table):

```text
keccak256("ARTIST_SANCTION")             0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047
keccak256("PLATFORM_WORKS_DECLARATION")  0x9b732a2be945a9747de080e93cd0a83076acad44dca7585847960ffebdb0d29d
keccak256("STREAM_ARTIST_REGISTRY")      0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a (module type)
keccak256("artist")                      0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb (ARTIST beneficiary label)
```

## Event Reconstruction [AA-RECON]

Requirements:

1. The implementation test suite must include a harness that rebuilds,
   from events alone, and compares against direct reads: artist
   identities and authority addresses through every rotation and
   succession; binding generations, collaborator sets, and acceptance
   states; the attribution state timeline per collection; consent modes
   and platform-works declarations; policy and economics consent records
   keyed by their hashes; sanction records and their subjects;
   attestations with staleness inputs; delegations with grant, use, and
   revocation state; successor designations and directives; dormancy
   timelines; disputes and resolutions; authorization revocations; and
   both record-chain accumulators.
2. Every record hash emitted must be recomputable from event payload
   fields plus the pinned domain constants; no record may depend on
   unevented storage.
3. The registry's events enter the machine-readable event catalog with
   schema versions, indexed-field lists, and semantic owner, per the
   umbrella spec's Hash And Manifest Discipline.

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
   records.
4. Economics gate: artist-bound assignment changes revert without verified
   economics consent; artist royalty freeze applies exactly once against
   the expected assignment hash; artist-majority default template and
   split disclosure verified.
5. Signature verification gate: ECDSA nonzero-and-matched negative tests;
   ERC-1271 wrong-magic/out-of-gas/malformed rejection; GGP floor, raise,
   lower, and probe tests for `ARTIST_ERC1271_VERIFY_GAS`; signature-bytes
   storage and oversized-bundle archival-proof path.
6. Lifecycle gate: rotation requires both sides; succession activation
   requires dual evidence; dormancy respects inactivity and notice floors,
   cancels on any liveness, and appoints stewards without
   `CAP_POLICY_CONSENT`; forbidden capability masks are absolute.
7. Dispute gate: standing enforcement, evidence requirement, blocking
   while disputed, arbiter resolution paths, prospective-only revocation,
   arbiter-gated rebinding after revocation.
8. Display gate: renderer emits all five attribution states, both works
   classes, attestation staleness, and collaborator verification per
   `AA-DISPLAY`, verified against registry reads.
9. Write-authority gate: `ARTIST_*` families reject non-artist writers in
   every genesis satellite; every artist-authority event carries recorder
   and authority class; record-chain accumulators verify against replayed
   history and appear in state exports.

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
