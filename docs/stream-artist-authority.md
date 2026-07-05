# Stream Artist Authority

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md). Its decisions are taken by
[ADR 0010](adr/0010-world-class-spec-pass.md) (decision D2),
[ADR 0011](adr/0011-world-class-pass-round-2.md) (decision R7), and
[ADR 0012](adr/0012-world-class-pass-round-3.md) (decision T4, plus the
artist-side items of decisions T3, T5, and T9), and
[ADR 0013](adr/0013-world-class-pass-round-4.md) (decisions U1 and U4,
plus the artist-side item of decision U8), and
[ADR 0014](adr/0014-world-class-pass-round-5.md) (decision V3, plus the
artist-ceremony item of decision V4); it contains no open questions.

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
  - append-only identity-document revisions (registration document
    immutable; the operative document carries payout and key history)
  - typed, artist-signed payout designations resolved by settlement
    contracts at settlement time (AA-PAYOUT); the signing key is never
    the payment address
  - two-sided collection bindings (operator proposes, artist accepts),
    with an optional per-binding registry-immutability election
  - typed collaborator sets with per-collaborator acceptance and
    collaborator identity registration
  - attribution state machine per collection binding
  - consent modes: ARTIST_SIGNED_POLICY | ARTIST_DELEGATED | PLATFORM_WORKS
  - optional sale-parameter consent scope pinned per binding
  - phase-policy consent records consumed by StreamMintManager
  - economics consent records and artist royalty freeze authorizations
    consumed by the revenue resolver
  - ARTIST_SANCTION / PLATFORM_WORKS_DECLARATION finality components
    consumed by StreamArtworkFinalityRegistry
  - state-bound artist attestations with staleness reads
  - artist-signed deployment attestations for address-level provenance
  - scoped, expiring, revocable delegations
  - artist first-release content ratification, content consent from
    ratification (or first mint) to finality, and a unilateral content
    freeze from binding acceptance to finality
  - key rotation staged behind a contest window with a pre-registered
    artist guardian set and arbiter-adjudicated identity recovery
  - prior-address standing revocation after a pinned tail window, so a
    leaked historical key is not a permanent griefing lever
  - guardian/arbiter contest path over pending and executed estate
    activations and dormancy completions
  - successor designation, pre-signed estate directives and steward
    sanction grants, and permissionless estate activation after public
    notice
  - governed dormancy procedure with long public notice
  - append-only dispute, counter-statement, and revocation records with a
    governed, delay-classed, appealable arbiter; artist repudiation is
    staged behind a contest-class window with guardian veto
  - append-only third-party claims for both works classes —
    platform-works claims and artist-bound attribution claims —
    surfaced in token JSON without arbiter action, with an arbiter
    CONTESTED state that stops further minting of contested platform
    works and an arbiter-gated corrective rebinding path for sustained
    misappropriation contests
  - artist-side approval of artwork-bytes-affecting finality recovery
  - onchain signature verification (EIP-712 + ERC-1271, GGP-governed gas)
  - onchain storage of verified signature bytes, identity documents, and
    authority-record preimages, with enumerable payload discovery reads
  - rolling record-chain accumulators for provable history completeness
  - Merkle-proofed successor-registry history import surface with
    onchain lane-tip verification against the predecessor's reads

Consumers
  - StreamMintManager: refuses artist-bound phases without verified
    consent and the artist-bound first-sale floor records
  - Sale adapters: refuse sale activation without verified sale-parameter
    consent where the binding elects it (AA-SALE-CONSENT)
  - Revenue resolver: refuses artist-bound assignment changes without
    verified artist co-signature; applies artist royalty freezes
  - Settlement contracts: resolve COLLECTION_ARTIST and collaborator
    template sources through the AA-PAYOUT typed reads at settlement
  - StreamEntropyCoordinator: enforces artist content consent for
    entropy configuration changes and fresh-entropy redraws (AA-CONTENT)
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
| Artist identity semantics: `artistId` derivation, binding preimages, acceptance semantics, attribution states and numeric values, consent-mode semantics and numeric values, sale-consent-scope semantics and numeric values, registry-immutability-election semantics and numeric values, authority classes, identity-revision semantics, the pinned identity-document schema, payout-designation semantics (`AA-PAYOUT`), steward-sanction-grant semantics, collaborator identity registration semantics, sanction subject and record preimages, steward minted-before enforcement semantics, typehash strings, event schemas, canonical orderings, rotation contest and guardian semantics, prior-address standing-revocation semantics, estate/dormancy contest semantics, content consent/freeze semantics, first-release content-ratification semantics, attribution-repudiation staging semantics, platform-works correction semantics, recovery-approval semantics, estate-activation semantics, platform-works and artist-bound third-party claim semantics, deployment-attestation semantics, history-import leaf, binding, and lane-verification semantics, the normative attribution JSON schema (`AA-DISPLAY`) | Permanent |
| `IStreamArtistRegistry`, `IStreamArtistConsent`, and the finality component read surfaces this registry implements | Permanent |
| The two-sided binding rule, the unverified-attribution display rule, the artist-sanction finality requirement, the platform-works immutability rule, the append-only record discipline | Permanent |
| `StreamArtistRegistry` genesis implementation, its storage layout, and its byte limits | Replaceable (genesis module behind the Permanent interfaces) |
| `ARTIST_ERC1271_VERIFY_GAS` value; dormancy notice, dormancy inactivity, rotation contest, repudiation contest, prior-address standing tail, estate-activation notice, and unavailability-recovery notice values above their immutable floors | Operational (governed parameters, excluded from finality identity) |
| Artist ceremony tooling, rehearsal evidence, and measurement artifacts (`AA-TOOLING`) | Operational |
| Outreach runbooks, dormancy evidence collection, estate onboarding, signature-suite re-attestation drills | Operational |

Changing a Permanent surface after deployment means declaring a successor
registry line; the deployed registry is never patched. A successor registry
must import the full append-only record history of its predecessor by
Merkle-proofed snapshot and must preserve every `artistId`; the import
binding, leaf schema, verification reads, and cutover discipline are
specified in `AA-IMPORT` (ADR 0012 decision T4), and the one-way
`ARTIST_REGISTRY` pointer-freeze option of `AA-MODULE` requirement 2 is
the registry-immutability guarantee for artists who require that consent
enforcement never re-point on this Core line.

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
                             findings, identity recovery, post-revocation
                             rebinding approval, and corrective-rebinding
                             approval for sustained platform-works
                             contests
ROLE_ARTIST_DORMANCY_ADMIN   initiates and completes the governed dormancy
                             procedure through staged governance actions
```

Every arbiter action stages through the canonical ADR 0004 governance
action under the `DELAYED` window class of
[`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
[GOV-WINDOWS] or a stricter class — never `IMMEDIATE` — and is subject to
the counter-statement and appeal rules of `AA-DISPUTE`
(ADR 0011 decision R7.7). Every arbiter action that vests or strips
verified provenance must use the `TERMINAL_FREEZE` action class — its
delay plus the independent veto guardian and 72-hour veto floor of
[GOV-WINDOWS] — because those are the most consequential provenance
powers a platform role holds: identity recovery (`AA-GUARD`
requirement 7) and a `REVOKE` dispute resolution (`AA-DISPUTE`
requirement 4) (ADR 0012 decision T4), the `UPHELD` reinstatement of a
reopened `ARBITER_REVOKED` generation (`AA-DISPUTE` requirement 4;
ADR 0013 decision U4), and the corrective-rebinding approval for a
sustained platform-works contest (`AA-PLATFORM` requirement 8;
ADR 0014 decision V3). Appeal to the role-admin tier alone is not an
independent check; the veto guardian is.

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
2. `AUTH_STEWARD` authority is restricted to the steward's effective
   capability mask (`AA-DORMANCY` requirement 6: the
   `STEWARD_CAPABILITIES` default plus explicitly granted bits, minus
   forbidden bits); it must never satisfy new-work policy consent.
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
([LTA-MODULE-ID], Satellite Versioning) with:

```text
streamModuleType() = keccak256("STREAM_ARTIST_REGISTRY")
```

Requirements:

1. The registry must be bound to exactly one `StreamCore` at deployment and
   must reject records for collections that do not exist in that Core.
2. The registry must be registered in the module registry and referenced by
   the Core satellite pointer family `ARTIST_REGISTRY` under the Core
   Satellite Pointer Policy of
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-POINTERS]; pointer moves follow that policy unchanged. Forward
   consent enforcement resolves through this pointer, so the one-way
   pointer freeze of [LTA-POINTERS] rule 7 is the registry-immutability
   option (ADR 0012 decision T4): once `ARTIST_REGISTRY` is frozen, no
   governance action can re-point consent verification away from this
   registry for the life of the Core line, and a successor registry then
   requires a successor Core line. Artist onboarding must disclose the
   pointer's current freeze state and any operator commitment to freeze
   it (`AA-TOOLING` requirement 2), so an artist for whom registry
   mutability is unacceptable can see, before binding, exactly what
   guarantee they are getting — and can make the guarantee binding
   rather than disclosed: the per-binding registry-immutability
   election of `AA-BINDING` requirement 10 obligates the pointer-freeze
   path before the electing collection can mint, so the meta-level
   consent guarantee never has to rest on an operator promise
   (ADR 0013 decision U4).
3. The registry must implement `IStreamFinalityComponent` and
   `IStreamScopedFinalityComponent` (owned by the umbrella spec) for the
   component semantics in `AA-SANCTION`.
4. State-changing registry functions must use checks-effects-interactions
   and a registry-wide reentrancy guard. The only external calls the
   registry makes are bounded ERC-1271 `staticcall`s (`AA-SIGVER`) and
   bounded `staticcall`s to the bound Core's pinned read surface —
   collection existence (requirement 1), the finality facts read, the
   one-way collection burn-block activation height
   (`collectionBurnsBlockedAtBlock`, home
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-BURN]; ADR 0013 decision U4) consumed by the steward
   minted-before check (`AA-SANCTION` requirement 5), the
   `ARTIST_REGISTRY` pointer's one-way freeze state
   ([LTA-POINTERS] rule 7) consumed by the registry-immutability
   election (`AA-BINDING` requirement 10), and the `ARTIST_REGISTRY`
   pointer's current target consumed by the succession cutover rules
   (`AA-IMPORT` requirement 7) — plus, on a successor registry line,
   bounded `staticcall`s to a committed predecessor registry's lane-tip
   reads (`collectionRecordChainHash`, `artistRecordChainHash`),
   consumed by the lane-verification latch of `AA-IMPORT`
   requirement 7 (ADR 0014 decision V3). Because the burn-block
   height and the pointer freeze are both one-way, the registry may
   latch an observed value and never re-read it; the cutover
   observation that the pointer no longer names this registry, and a
   verified imported lane tip, are likewise latched one-way and never
   re-read.
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
    bytes32 identityRecordHash;  // registration identity document hash;
                                 // immutable artistId input (req 6 owns
                                 // the operative-document rule)
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
2. `identityRecordHash` commits to a canonical identity document under
   the pinned schema `keccak256("6529STREAM_ARTIST_IDENTITY_V1")`
   (`AA-DOMAINS`; ADR 0013 decision U4): RFC 8785 canonical JSON whose
   required top-level members are `schema` (the exact schema string),
   `displayName`, `biographicalRefs` (array; may be empty; typed
   `kind`/`uri`/`hash` entries, and the identity-document lane for
   art-historical authority-file identifiers — ULAN, VIAF, Wikidata
   QID — cited by [CMC-CITATION] rule 6 in
   [`collection-metadata-contract.md`](collection-metadata-contract.md)),
   `publicKeyHistory` (array of key references with validity periods),
   `c2paCredentials` (the `AA-C2PA` signing-credential enumeration; may
   be empty), and `payoutAccounts` (a human-readable mirror of the
   operative typed payout designation — `AA-PAYOUT` requirement 6 owns
   the settlement-authoritative record). Any additional material lives
   only under an `extensions` member, so two tooling generations can
   never produce structurally incompatible documents, and revision
   documents (requirement 6) are complete documents under the same
   schema, never diffs. The schema document itself is registered as
   onchain schema-registry bytes exactly like the
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-GENESIS-SCHEMAS] families (that document owns the registration
   mechanism). Worked example (non-normative values, normative shape):

```json
{
  "schema": "6529STREAM_ARTIST_IDENTITY_V1",
  "displayName": "Alice Example",
  "biographicalRefs": [
    {"kind": "website", "uri": "https://alice.example",
     "hash": "0x5d41..."},
    {"kind": "ulan", "uri": "https://vocab.getty.edu/ulan/500356337",
     "hash": "0x9c1e..."}
  ],
  "publicKeyHistory": [
    {"scheme": "secp256k1-eth", "address": "0xa11c...",
     "validFrom": 1750000000, "validTo": 0}
  ],
  "c2paCredentials": [],
  "payoutAccounts": {
    "primary": "0xdefa...",
    "designationRecordHash": "0x91b2..."
  },
  "extensions": {}
}
```

   The registry verifies bytes, bound, and hash; it never parses JSON
   onchain. Schema conformance is enforced by submission tooling
   (`AA-TOOLING` requirement 1) and by the identity-archival gate
   (`AA-GATES` gate 10), which validates every stored document —
   registration and revision — against the pinned schema. The hash, not
   the URI, is authoritative. The identity document is the onchain
   commitment mapping
   an `artistId` to a human, so it joins the onchain-bytes and dual-family
   archival rules (ADR 0011 decision R7.10): the canonical document bytes
   must be stored in registry contract storage (SSTORE2-style permitted)
   at identity registration, bounded by `MAX_IDENTITY_RECORD_BYTES`
   (`AA-LIMITS`), readable via
   `identityDocumentBytes(identityRecordHash)` (requirement 6), and
   `keccak256` of the stored bytes must equal `identityRecordHash`; a
   document exceeding the bound is rejected at registration. The document
   must additionally be mirrored under the dual-family archival rule with
   at least one verifiable receipt class
   ([`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-ARCHIVE]; ADR 0011 decisions R1 and R4) before any binding or
   collaborator acceptance for the identity completes; the
   identity-archival gate
   (`AA-GATES`) enforces both halves. Log data never substitutes for the
   stored bytes.
3. Every authenticated artist-side action (acceptance, sanction, consent,
   attestation, delegation grant or revocation, rotation, designation,
   directive, payout designation, steward sanction grant, dispute
   action) must update `lastAuthorityActionAt`.
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
6. Identity documents are append-only revised, never rewritten
   (ADR 0012 decision T4). Names, payout accounts, and key histories
   change over five decades; the registration document stays immutable —
   it is the `artistId` preimage input and the permanent record of who
   registered — and currency lives in a revision chain:

```text
StreamArtistIdentityRevision(
    bytes32 artistId,
    bytes32 previousRecordHash,  // the operative document hash superseded
    bytes32 revisedRecordHash,   // keccak256 of the revised document
    uint256 nonce,
    uint64 signedAt
)
```

   `recordIdentityRevision` verifies the payload under `AA-SIGVER`,
   requires `previousRecordHash` to equal the operative document hash at
   submission (revisions form one linear chain from the registration
   document; forks revert), stores the revised canonical document bytes
   under the same rules as registration (requirement 2:
   `MAX_IDENTITY_RECORD_BYTES` bound, `keccak256` equality, dual-family
   mirroring before the next binding acceptance for the identity), and
   emits `ArtistIdentityRevisionRecorded` with the revision record hash
   (`IDENTITY_REVISION_RECORD_DOMAIN`, `AA-DOMAINS`). Authority is
   `AUTH_ARTIST` or an activated `AUTH_SUCCESSOR` whose effective
   capabilities include `CAP_IDENTITY_REVISION` (`AA-DELEG`); revisions
   are never delegable and never available to `AUTH_STEWARD` — a
   governance-appointed steward must not be able to rewrite the mapping
   between an `artistId` and a human or its payout account. The
   operative document is the tip of the revision chain that is not
   adjudicated-superseded (`AA-GUARD` requirement 7) and not provisional
   (`AA-GUARD` requirement 8); absent any revision it is the
   registration document. `operativeIdentityRecord(artistId)` returns
   the operative hash; `identityRecordBytes(artistId)` returns the
   operative document bytes; `identityDocumentBytes(identityRecordHash)`
   returns any stored document — registration or revision — by hash, so
   history never becomes unreadable. Payout-address currency
   (`AA-ECON` requirement 1) and key-history currency (`AA-C2PA`) read
   the operative document; `artistId` derivation and executed history
   keep reading the documents they bound at the time.
7. Legal-person verification pattern (ADR 0013 decision U8). The
   registry proves address control and consent chains, never
   personhood (`AA-EXCL` item 2). The blessed pattern for third-party
   verification of the `artistId`-to-legal-person mapping at
   acquisition standard is a notarized attestation record of the
   `INSTITUTIONAL_VERIFICATION` or `ESTATE_VERIFICATION` classes —
   record family, pinned `STREAM_IDENTITY_NOTARIZATION_V1` payload
   schema, and verification mechanics owned by
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-ATTESTATIONS] rule 11 — recorded over the identity's operative
   `identityRecordHash`, so identity-verification evidence is typed,
   discoverable, and weightable like every other attestation, and a
   registrar or acquisition committee follows a named pattern instead
   of improvising the linkage evidence. Acquisition-packet surfaces
   cite this pattern from the museum side; the registry side is only
   the subject hash the attestation binds.
8. Personhood-evidence first-sale floor (ADR 0014 decision V3). For an
   artist-bound collection, the requirement 7 evidence is a
   recorded-or-waived first-sale floor item, never always-optional
   diligence: before the collection's first phase policy registration
   and first mint — the mint path is the primary-sale path — an
   operative state-bound attestation with
   `subjectKind = SUBJECT_IDENTITY_RECORD` (`AA-ATTEST`) must exist
   for the primary artist identity, under exactly one of two pinned
   schemas (`AA-DOMAINS`): the evidence-reference schema
   `keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")`, whose
   `statementHash` commits to a canonical document referencing the
   recorded `INSTITUTIONAL_VERIFICATION` or `ESTATE_VERIFICATION`
   notarization record of requirement 7 by its record hash (storage
   home
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-ATTESTATIONS] rule 11); or the waiver schema
   `keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")`, whose
   `statementHash` commits to the artist's statement that no
   personhood evidence is recorded. The attestation binds the operative
   `identityRecordHash` as its `subjectStateHash`, so a later identity
   revision marks it `ATTESTED_STALE` through the ordinary staleness
   read and acquisition tooling sees exactly which identity version
   the evidence covered. `requireMintConsent` enforces the floor
   (`AA-CONSENT` requirement 6); the museum-grade pre-first-sale floor
   carries the notarization itself on the metadata side
   ([CMC-MUSEUM-GRADE] rules 2(f) and 3). A waiver makes absence a
   provable, displayed
   choice — impostor onboarding stays detectable, and the absence of
   acquisition-grade identity evidence at sale time is a recorded
   election rather than a silent default.
9. Display-name mirror (ADR 0014 decision V3). The registry stores,
   for the registration document and every revision, the document's
   `displayName` member as a typed string (bounded by
   `MAX_DISPLAY_NAME_BYTES`, `AA-LIMITS`), supplied with the document
   bytes at submission and emitted in the registration and revision
   events; `artistDisplayName(artistId)` returns the operative
   identity's display name together with the operative
   `identityRecordHash` so any consumer can verify the mirror against
   the stored document bytes (`identityDocumentBytes`). The document
   bytes — artist-ratified through `identityRecordHash` — are
   authoritative: on any divergence the document wins, the mirror is
   a defect, and the identity-archival gate (`AA-GATES` gate 10)
   verifies mirror-document equality for every stored document. The
   mirror exists so display surfaces can source the artist's name
   from the registry without parsing JSON onchain (`AA-DISPLAY`
   requirement 2); it is never a second home for the name.

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

enum SaleConsentScope {
    SALE_CONSENT_NONE,      // 0 sale parameters are operator-set
    SALE_CONSENT_REQUIRED   // 1 sale activation requires artist consent
                            //   over the exact saleConfigHash
                            //   (AA-SALE-CONSENT; ADR 0012 decision T4)
}

enum RegistryImmutabilityElection {
    REGISTRY_MUTABLE_OK,     // 0 the pointer policy alone governs
    REGISTRY_FREEZE_REQUIRED // 1 the ARTIST_REGISTRY pointer freeze must
                             //   execute before the collection can mint
                             //   (requirement 10; ADR 0013 decision U4)
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
    SaleConsentScope saleConsentScope;  // AA-SALE-CONSENT election
    RegistryImmutabilityElection registryImmutabilityElection;
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
    uint8(saleConsentScope),
    uint8(registryImmutabilityElection),
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
   revert if the collection has a `PLATFORM_WORKS` declaration — except
   under the corrective-rebinding path of `AA-PLATFORM` requirement 8
   (ADR 0014 decision V3) — an
   unresolved prior generation in `CLAIMED` state, or a live generation in
   `ARTIST_ACCEPTED`, `ARTIST_SANCTIONED`, or `DISPUTED` state.
2. Acceptance must verify against the exact stored `bindingHash`. The
   acceptance therefore ratifies the artist address, identity record,
   consent mode, sale-parameter consent scope, registry-immutability
   election, collaborator policy,
   capability policy overrides, and full collaborator set in one
   signature. Any change to any of those fields before acceptance
   requires a new generation. For a proposal naming an existing
   `artistId`, `identityRecordHash` must equal the identity's operative
   document hash at proposal time (`AA-IDENTITY` requirement 6), so
   every binding generation permanently records which identity-document
   version its artist ratified and no two "canonical" documents can
   compete: the per-binding hash is the ratified version, and the
   identity's operative document governs display, payout designation,
   and key history going forward.
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
10. Registry-immutability election (ADR 0013 decision U4). A binding
    whose accepted proposal pins `REGISTRY_FREEZE_REQUIRED` obligates
    the pointer-freeze path: `requireMintConsent` — and therefore every
    phase policy registration and every mint — must revert for the
    collection until the one-way `ARTIST_REGISTRY` pointer freeze of
    [LTA-POINTERS] rule 7 has executed, read per `AA-MODULE`
    requirement 4. The election is ratified inside `bindingHash`,
    immutable per generation, and readable via
    `registryImmutabilityElection(collectionId)`; an operator who never
    freezes simply never mints the electing collection, so the artist's
    protection cannot be waited out. `REGISTRY_MUTABLE_OK` leaves the
    pointer under the ordinary [LTA-POINTERS] policy and the `AA-MODULE`
    requirement 2 disclosure. Numeric values of
    `RegistryImmutabilityElection` are pinned above, enter the numeric
    ID catalog, and are never reused with different meaning. Operator
    tooling must present the election in the binding proposal flow
    exactly like the sale-consent election (`AA-SALE-CONSENT`
    requirement 5).

Artist-initiated proposals are a named extension profile, not a genesis
capability (ADR 0013 decision U4): the `ARTIST_INITIATED_BINDING`
profile — a future Replaceable module behind these same Permanent
interfaces under which an artist proposes their own binding and the
operator-side role accepts, the exact mirror image of this section's
two-sidedness — is pre-shaped here so the protocol v1 exclusion is
provably intentional and a genesis-adjacent module spec can ship against
stable semantics; its activation remains governed. Nothing in this
section's preimages or events assumes the proposer is an operator role:
`ArtistBindingProposed` carries the proposer address, and acceptance
semantics are proposer-independent.

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
   rotation, succession, dormancy, delegation, and payout-designation
   rights as the primary artist, scoped to their collaborator standing,
   and are created through the registration flow of requirement 7 —
   never implied into existence.
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
   sale-parameter consent, royalty freeze, content consent, content
   freeze, recovery approval, and revocation actions unless a
   `CapabilityPolicyOverride` row pins a
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
7. Collaborator identity registration (ADR 0013 decision U4). A
   collaborator identity is allocated through the same two-sided
   discipline as a primary identity, collaborator-scoped:
   `proposeCollaboratorIdentity(account, identityRecordHash,
   identityRecordURI, reasonHash, reasonURI)` requires
   `ROLE_ARTIST_REGISTRY_ADMIN` and stages the registration; acceptance
   — by direct call from `account` or a verified signature over the
   pinned payload below — allocates the `artistId` under the
   `AA-IDENTITY` derivation (with `account` as `firstAddress` and the
   registry-wide `registrationNonce`), stores the identity document
   bytes under `AA-IDENTITY` requirement 2 (pinned schema, byte bound,
   `keccak256` equality, dual-family mirroring before any acceptance
   for the identity completes), and emits the ordinary
   `ArtistIdentityRegistered` event. No other collaborator identity
   creation path exists, so every implementation derives the same
   `artistId` for the same collaborator.

```text
StreamCollaboratorIdentityAcceptance(
    address account,
    bytes32 identityRecordHash,
    uint256 nonce,
    uint64 deadline
)
```

   A `StreamCollaboratorAcceptance` (the per-binding acceptance of
   requirement 2) completes only when `collaborator` holds an
   `IDENTITY_ACTIVE` identity — pre-existing or allocated in the same
   transaction (identity acceptance and collaborator acceptance may
   land together, exactly like the two rotation sides in `AA-ROTATE`).
   Completion permanently links the pair
   `(collaboratorArtistId, account)` in registry state and records the
   collaborator's `artistId` on the stored collaborator row
   (`collaboratorAt` returns it, and `CollaboratorAccepted` emits it),
   so every collaborative work has a durable per-collaborator join key
   and the payout read `collaboratorPayoutAccount` (`AA-PAYOUT`
   requirement 5) can verify acceptance-ratified account-identity
   linkage. Collaborator identity registration is rejected while the
   named account already controls an `IDENTITY_ACTIVE` identity
   (`AA-IDENTITY` requirement 5); the flow then simply names the
   existing identity instead.

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
ARTIST_ACCEPTED  -> REVOKED            executeAttributionRepudiation
                                       (staged artist repudiation,
                                       AA-DISPUTE requirement 5)
ARTIST_SANCTIONED-> REVOKED            executeAttributionRepudiation
                                       (staged artist repudiation,
                                       AA-DISPUTE requirement 5)
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
   consents, economics consents, sale consents, content consents,
   content ratifications, delegation grants, and
   attestations for
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
   executed artist repudiations, refusals, and withdrawals are never
   reopenable — which is why a repudiation never executes instantly:
   it stages behind a contest-class window with guardian veto
   (`AA-DISPUTE` requirement 5; ADR 0014 decision V3). Corrective
   rebinding of a sustained platform-works contest follows
   `AA-PLATFORM` requirement 8 under the same append-only discipline.
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

Canonical display strings for `ArtistAuthorityClass` (Permanent;
ADR 0012 decision T4):

```text
AUTH_ARTIST -> artist | AUTH_DELEGATE -> delegate |
AUTH_SUCCESSOR -> successor | AUTH_STEWARD -> steward
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
                       disputed | revoked            (always present;
                                           attribution_unavailable is
                                           the sole degraded value,
                                           requirement 8 — a read
                                           posture, never a stored
                                           AttributionState)
  works_class:         artist_bound | platform_works (always present)
  consent_mode:        artist_signed_policy | artist_delegated |
                       platform_works               (always present)
  artist_id:           bytes32 hex                  (artist_bound only)
  artist_address:      address hex                  (artist_bound only)
  artist_display_name: string             (artist_bound only; the
                                           operative identity document's
                                           displayName, served through
                                           the registry mirror of
                                           AA-IDENTITY requirement 9)
  identity_record_hash: bytes32 hex       (artist_bound only; the
                                           operative identityRecordHash
                                           the name verifies against)
  binding_generation:  integer                      (artist_bound only)
  corrected_attribution: boolean          (artist_bound only; true when
                                           the operative binding is a
                                           post-contest corrective
                                           rebinding, AA-PLATFORM
                                           requirement 8)
  deployment_attestation: bytes32 hex    (artist_bound only, when an
                                          AA-DEPLOY attestation exists;
                                          required before first mint,
                                          AA-DEPLOY requirement 6)
  collaborators:       array per requirement 5      (when collaborators)
  attestation_status:  none | attested_current | attested_stale |
                       disputed                     (artist_bound only)
  attestation_record:  bytes32 hex                  (when one exists)
  attestation_authority_class: artist | delegate | successor | steward
                                          (when attestation_record
                                           is present)
  attested_state_hash: bytes32 hex                  (when one exists)
  sanction_record:     bytes32 hex        (when a sanction covers the
                                           token's resolved scope)
  sanction_authority_class: artist | delegate | successor | steward
                                          (when sanction_record is
                                           present; ADR 0012 decision T4)
  contested:           boolean            (platform_works, and corrected
                                           collections per AA-PLATFORM
                                           requirement 8; true while or
                                           after a sustained contest,
                                           AA-PLATFORM)
  contest_record:      bytes32 hex        (when contested is true)
  claim_count:         integer            (always present; total filed
                                           third-party claims for the
                                           collection — platform-works
                                           claims, AA-PLATFORM
                                           requirement 4, or
                                           artist-bound attribution
                                           claims, AA-DISPUTE
                                           requirement 10; zero when
                                           none)
  latest_claim_record: bytes32 hex        (when claim_count > 0)
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
   binding generation. Wherever a sanction or attestation record hash is
   emitted, its authority-class field must be emitted beside it using
   the pinned `ArtistAuthorityClass` display strings, sourced from the
   record's stored authority class (`verifySanctionForSubject` and
   `artistAttestationStatus` return it), so a catalogue can never read a
   steward, successor, or delegate signature as the living artist's own
   hand (ADR 0012 decision T4). `deployment_attestation` carries the
   `AA-DEPLOY` attestation record hash when one exists, and
   `claim_count` (plus `latest_claim_record` when nonzero) is emitted
   directly from the permissionless artist-bound claim read of
   `AA-DISPUTE` requirement 10 — a misappropriation victim's filing
   reaches token JSON with no arbiter action, exactly as it does for
   platform works (ADR 0013 decision U4). The artist's name is
   registry-sourced (ADR 0014 decision V3): `artist_display_name` is
   the operative identity document's `displayName`, served through the
   `artistDisplayName` mirror read (`AA-IDENTITY` requirement 9), and
   `identity_record_hash` is the operative `identityRecordHash`, so a
   consumer can verify the displayed name against the artist-ratified
   stored document bytes with no operator trust. Conformant surfaces
   must render the registry-sourced name as the verified artist name;
   operator-writable display fields
   ([`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-PEOPLE] `artistDisplayName` and similar) are supplemental
   credits, never the verified name, and the metadata and renderer
   homes mirror that demotion. Platform
   assertion is never rendered as artist fact, and no conformant surface
   may omit, rename, re-case, or flatten these fields, except under the
   registry-read-failure posture of requirement 8.
3. For `PLATFORM_WORKS` collections, default token JSON must include the
   attribution object with `works_class = "platform_works"`, must omit
   artist fields rather than fabricate them (`AA-PLATFORM`), must emit
   `claim_count` (and `latest_claim_record` when nonzero) directly from
   the permissionless claim read of `AA-PLATFORM` requirement 4 — filed
   claims reach token JSON automatically, with no arbiter action
   (ADR 0012 decision T4) — and must emit `contested = true` plus
   `contest_record` while a platform-works contest stands or after one
   is sustained (`AA-PLATFORM` requirement 6). Artist-bound collections
   expose `works_class = "artist_bound"`.
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
   referenced from it, with each listed collaborator's display name
   sourced from that collaborator identity's operative document through
   the same mirror read (`AA-IDENTITY` requirement 9; ADR 0014
   decision V3); the second artist of a duo is never reduced to an
   unverifiable offchain note or an operator-typed name.
6. Renderer conformance tests must cover all five states, both works
   classes, staleness, the disputed override, the contested
   platform-works display, the filed-claim display for both works
   classes, the registry-unreachable degraded object of requirement 8,
   and — as golden
   assertions — the presence and exact paths of `artist_id`,
   `artist_display_name`, `identity_record_hash`,
   `binding_generation`, `corrected_attribution`, `sanction_record`,
   `sanction_authority_class`,
   `attestation_authority_class`, `claim_count`, `latest_claim_record`,
   `deployment_attestation`, `works_class`, and `consent_mode` in the
   elected nested shape, including one golden case per
   `ArtistAuthorityClass` display string for the sanction field and a
   golden case verifying `artist_display_name` against the stored
   identity document bytes
   (`AA-GATES`; ADR 0011 decision R7.6; ADR 0012 decision T4;
   ADR 0014 decision V3).
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
8. Registry-read failure posture (ADR 0013 decision U4). This section
   is the normative home of the degraded output; the router's bounded
   fail-safe read mechanics mirror it
   ([`metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   [MRR-ATTRIBUTION]). When the bounded artist-registry read fails
   during token JSON assembly — out of gas inside its bound, a pointer
   mid-incident, malformed returndata — the renderer must emit the
   attribution object as exactly:

```text
properties.provenance.attribution = { state: "attribution_unavailable" }
```

   It must not omit the object (requirement 2), must not revert
   `tokenURI` for this cause alone (the router's fail-safe posture),
   and must not emit any other attribution member from stale, cached,
   or default values — in particular it must never present a sanctioned
   work as `claimed`. `attribution_unavailable` is a transient read
   posture, never a stored `AttributionState`, never enters the numeric
   ID catalog, and consumer surfaces must re-resolve rather than cache
   it as attribution truth. A golden renderer test covers the
   registry-unreachable case (`AA-GATES` gate 8).

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
   records measured values in the release manifest. The parameter's
   release-manifest failure-direction class is `FAIL_CLOSED_PRECHECK`
   ([LTA-GGP] requirement 10): requirement 3 failures revert the
   submission, so raises are governance-only with no permissionless
   conditional raise (ADR 0012 decision T1), and its named
   Permanent-class probe ([LTA-GGP-PROBES]) proves a
   maximum-supported-class ([GOV-1271-CLASS]) `isValidSignature`
   verification completes with the magic value under exactly the probed
   cap for pinned fixture inputs, with run records hosted on the probe
   and `evidenceHash` committing to the measurement artifact.
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
   space) and, except long-lived designations, directives, steward
   sanction grants, and payout designations, `deadline`.
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
CAP_GUARDIAN_SET      = 1 << 8   guardian-set maintenance (AA-GUARD
                                 requirement 1; designations, directives,
                                 and steward masks only — never grantable
                                 by delegation, requirement 7)
CAP_IDENTITY_REVISION = 1 << 9   identity-document revisions and payout
                                 designations (AA-IDENTITY requirement
                                 6; AA-PAYOUT requirement 1;
                                 designations and directives only —
                                 never delegable, never steward)
CAP_SALE_CONSENT      = 1 << 10  sale-parameter consent
                                 (AA-SALE-CONSENT; delegated use on
                                 ARTIST_DELEGATED collections only)
CAP_GUARDIAN_DISPLACE = 1 << 11  removal of artist-recorded guardians
                                 from the operative set (AA-GUARD
                                 requirement 1; designations and
                                 directives only — never grantable by
                                 delegation, never in a default mask;
                                 ADR 0014 decision V3)
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
5. `CAP_POLICY_CONSENT` and `CAP_SALE_CONSENT` are only usable on
   `ARTIST_DELEGATED` collections; the registry must reject delegated
   policy or sale-parameter consent on `ARTIST_SIGNED_POLICY`
   collections regardless of the delegation's bits.
6. `CAP_SANCTION` delegation is permitted but operator tooling must warn:
   sanction is the strongest provenance statement, and artists should keep
   it undelegated. The sanction record's authority class makes any
   delegated sanction permanently visible.
7. Delegates never gain rotation, guardian-set, guardian-displacement,
   identity-revision,
   payout-designation, steward-sanction-grant, standing-revocation,
   successor-designation, directive, delegation-granting, or
   repudiation powers; those are non-delegable. A
   delegation payload naming `CAP_GUARDIAN_SET`,
   `CAP_GUARDIAN_DISPLACE`, or
   `CAP_IDENTITY_REVISION` reverts at grant: those bits exist so
   designations, directives, and steward masks can grant or forbid the
   powers (`AA-GUARD` requirement 1, `AA-IDENTITY` requirement 6,
   `AA-ESTATE` requirement 4), never so a delegate can hold them.

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

    // sale-parameter consent reads consumed by sale adapters
    // (AA-SALE-CONSENT; ADR 0012 decision T4)
    function saleConsentScope(uint256 collectionId)
        external view returns (uint8);

    function isSaleConsented(
        uint256 collectionId,
        bytes32 saleId,
        bytes32 saleConfigHash
    ) external view returns (bool consented, bytes32 consentRecordHash);

    function requireSaleConsent(
        uint256 collectionId,
        bytes32 saleId,
        bytes32 saleConfigHash
    ) external view;

    function isRoyaltyFreezeAuthorized(
        uint256 collectionId,
        bytes32 expectedAssignmentHash
    ) external view returns (bool);

    // content authority reads consumed by the collection metadata
    // contract, its satellites, and the entropy coordinator
    // (AA-CONTENT; ADR 0013 decision U4)
    function requireContentConsent(
        uint256 collectionId,
        bytes32 familyId,
        bytes32 newStateHash
    ) external view;

    function isContentFreezeAuthorized(
        uint256 collectionId,
        bytes32 lockClass
    ) external view returns (bool authorized, bytes32 freezeRecordHash);

    // first-release content ratification read consumed by the
    // collection metadata contract and onboarding tooling
    // (AA-CONTENT requirement 6; ADR 0014 decision V3)
    function firstReleaseRatification(uint256 collectionId)
        external view
        returns (
            bool ratified,
            bytes32 contentStateHash,
            bytes32 ratificationRecordHash
        );
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
   declaration. One append-only transition exists on this registry
   line (ADR 0014 decision V3): a `CONTEST_SUSTAINED` `PLATFORM_WORKS`
   collection adopts the corrective binding's artist mode exactly once,
   at corrective-rebinding acceptance (`AA-PLATFORM` requirement 8);
   no other transition between modes exists.
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
   implied, and `requireMintConsent` succeeds on the declaration alone —
   except under an open or sustained misappropriation contest
   (ADR 0012 decision T4): `requireMintConsent` must revert while the
   declaration's contest state is `CONTESTED`, and permanently after
   `CONTEST_SUSTAINED`, mirroring the fail-closed `DISPUTED` rule for
   artist-bound collections. Because the mint manager calls
   `requireMintConsent` on every mint execution (requirement 6), an
   arbiter elevation stops further minting — and therefore every further
   primary sale, which settles through the mint path — of the contested
   collection with no operator action; a dismissal
   (`CONTEST_DISMISSED`) restores minting, and a sustained contest
   never resumes it on this registry line under the artist-less
   declaration — minting can resume only under a completed corrective
   rebinding and the corrected artist's full consent chain
   (`AA-PLATFORM` requirement 8; ADR 0014 decision V3). The sales
   layer inherits the
   stop through its mint-settlement dependency and keeps its own
   operational pause surface
   ([`stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   [SSA-PAUSE]) for incident response; already-owed refunds, credits,
   and claims are never blocked by the contest stop, exactly as they are
   never blocked by a pause.
6. `requireMintConsent` must revert unless all of the following hold for
   artist-bound collections: attribution state is `ARTIST_ACCEPTED` or
   `ARTIST_SANCTIONED` (never `CLAIMED`, `DISPUTED`, or `REVOKED`); a
   consent record matches the exact active `policyHash`; the economics
   prerequisite of `AA-ECON` requirement 4 is satisfied; the
   artist-bound first-sale floor is satisfied (ADR 0014 decision V3) —
   the mint path is the primary-sale path, so this read is where the
   floor binds: an operative first-release content ratification exists
   (`AA-CONTENT` requirement 6), a recorded deployment attestation
   exists for the operative binding generation (`AA-DEPLOY`
   requirement 6), and the personhood-evidence floor of `AA-IDENTITY`
   requirement 8 is satisfied — all registry-internal state, so the
   pinned read signature and the mint manager's calling cadence are
   unchanged; and, where the
   operative binding pins `REGISTRY_FREEZE_REQUIRED`, the
   `ARTIST_REGISTRY` pointer freeze has executed (`AA-BINDING`
   requirement 10). For
   `PLATFORM_WORKS` collections it must revert per the contest rule of
   requirement 5. The calling
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
   binding on this registry line — with exactly one append-only,
   arbiter-gated exception, the corrective rebinding of a sustained
   misappropriation contest (requirement 8; ADR 0014 decision V3) —
   and an artist-bound collection can never
   be redeclared platform works. This prevents attribution laundering in
   both directions (ADR 0010 decision D2.3): the declaration record
   itself is never rewritten, and the corrective path attaches the true
   author forward without erasing what was declared.
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
   the claimant no authority. Claim existence is state-readable and
   surfaces automatically (ADR 0012 decision T4): the registry maintains
   a per-collection claim count and latest claim record hash, readable
   via `platformWorksClaims(collectionId)`, and every conformant display
   surface emits them through the attribution object (`AA-DISPLAY`
   `claim_count` / `latest_claim_record`) with no arbiter action — the
   wronged party's filing reaches marketplaces and archives even when
   the accused party's own governance never elevates it. Spam filings
   are an accepted cost: claims are evidence-committed, append-only, and
   permanently attributed to their claimant, and a raw claim count
   asserts only that claims exist, never that they are true.
   Artist-bound collections carry the parallel permissionless claim
   surface under `AA-DISPUTE` requirement 10 (ADR 0013 decision U4);
   neither works class is ever the one a wronged third party cannot
   reach.
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
   permanently bind a declaration the arbiter has open doubts about —
   and `requireMintConsent` fails closed (`AA-CONSENT` requirement 5),
   stopping further minting and primary sales of the contested
   collection until dismissal (ADR 0012 decision T4): misappropriated
   art must not keep selling while governance deliberates. A
   sustained contest recorded before finality keeps blocking finality
   and permanently stops further minting; a contest
   opened after an executed finality record changes display only, per the
   prospective-only discipline of `AA-STATE` requirement 5, except that
   the mint stop still applies to any unminted remainder. A sustained
   contest opens the corrective-rebinding path of requirement 8 on this
   registry line (ADR 0014 decision V3); the successor-line import rule
   (`AA-PERM`, `AA-IMPORT`) remains the fallback for whatever a
   corrective rebinding cannot repair.
8. Corrective rebinding after a sustained contest (ADR 0014 decision
   V3). A proven misappropriation must be repairable into verified
   attribution and future artist economics on this registry line,
   without rewriting history. After `CONTEST_SUSTAINED`, and only
   then:
   (a) `approvePlatformWorksCorrection(collectionId,
   claimRecordHash, evidenceHash, reasonHash)` is a
   `ROLE_ATTRIBUTION_ARBITER` action staged under the
   `TERMINAL_FREEZE` class (`AA-ROLES`) — attaching attribution to
   sold works and re-routing their future economics carries a
   `REVOKE` resolution's weight — whose record, hashed under
   `PLATFORM_WORKS_CORRECTION_RECORD_DOMAIN` (`AA-DOMAINS`), links the
   sustaining resolution and the claim records it credits, evented via
   `PlatformWorksCorrectionApproved` with its `governanceActionId`.
   (b) The approval authorizes exactly one corrective
   `proposeArtistBinding` generation for the collection (the
   requirement 1 exception): an ordinary two-sided `AA-BINDING`
   proposal naming the adjudicated true author, accepted — or
   refused — by that artist under the unchanged acceptance
   semantics. Nothing vests without the artist's own signature; an
   unaccepted corrective proposal terminates like any other.
   (c) Acceptance makes the collection artist-bound forward: the
   binding's consent mode takes effect (`AA-CONSENT` requirement 2),
   the collection's works class reads `artist_bound`, and further
   minting resumes only under the corrected artist's full consent
   chain — policy consent, economics consent, and the first-sale
   floor of `AA-CONSENT` requirement 6, including a first-release
   content ratification over the current content state and a
   deployment attestation for the corrective generation. Future
   primary and royalty economics route through `AA-ECON` under the
   corrected binding; executed settlements, mints, and finality
   records are untouched (`AA-EXCL` item 8).
   (d) The lineage is append-only and permanently displayed: the
   declaration, claims, contest, sustaining resolution, and
   corrective approval all remain in the record chains; display
   surfaces emit `corrected_attribution = true` with `contested` and
   `contest_record` retained (`AA-DISPLAY`), so the correction can
   never masquerade as an original attribution and the declaration
   can never again read as uncontested.
   (e) Reach is honestly bounded: a contest sustained after an
   executed finality record yields display, economics, and
   mint-remainder repair only — the finality record permanently
   binds the declaration component, and `ARTIST_SANCTIONED` display
   is unreachable for it, exactly as `AA-STATE` requirement 5
   prospective-only discipline demands. Pre-finality, the corrected
   artist's sanction serves the `ARTIST_SANCTION` component and full
   repair is reachable. `platformWorksCorrection(collectionId)`
   returns the corrective generation and approval action ID (zero
   values when none).

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
   retroactive, and every consumer surface names the class beside the
   record (`AA-DISPLAY` `sanction_authority_class`; ADR 0012 decision
   T4). A steward sanction exists only where the artist-side record
   trail authorizes it and only for works minted before the steward's
   appointment, enforced by specified reads (ADR 0012 decision T4;
   ADR 0013 decision U4), never left to intent. `recordArtistSanction`
   must revert for an `AUTH_STEWARD` signer unless all three hold:
   the steward's effective capabilities include `CAP_SANCTION` — an
   operative artist-signed steward sanction grant (`AA-ESTATE`
   requirement 7) or the explicit `TERMINAL_FREEZE`-class governance
   grant of `AA-DORMANCY` requirement 6; `scopeType` is `COLLECTION`;
   and the collection's one-way collection burn block ([CMC-BURN]
   vocabulary) is active with its activation height at or before
   `stewardAppointedAtBlock` (`AA-DORMANCY` requirement 3), read from
   the bound Core's `collectionBurnsBlockedAtBlock(collectionId)`
   (nonzero exactly when the burn block is active; home
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-BURN]; ADR 0013 decision U4). The minted-before inference is
   stated, not implied: activating the collection burn block requires
   Core collection status `CLOSED` ([CMC-BURN] rule 6), `CLOSED` ends
   minting permanently, so no mint can postdate the recorded activation
   height — every token in scope was provably minted while artist-side
   authority governed. Both reads are
   append-only/one-way, so a sanction that passes at recording can never
   retroactively fail. Scoped (`TOKEN`, `RELEASE`, `SEASON`, `VIEW`)
   `AUTH_STEWARD` sanctions are intentionally absent on this registry
   line and revert (`AA-EXCL` item 9): no state read proves a scope's
   token set predates the appointment, and a rule that cannot be
   enforced would invite implementations to drop it silently. Scoped
   posthumous finality therefore requires an `AUTH_SUCCESSOR` with
   `CAP_SANCTION` — one more reason designation is the protective
   default (`AA-ESTATE`).
6. Scoped finality for open series uses the same mechanism per scope;
   the sanction subject includes the full `FinalityScope`, so a release
   sanction cannot be replayed against a season or the collection.
7. For `PLATFORM_WORKS` collections the registry serves
   `componentType = keccak256("PLATFORM_WORKS_DECLARATION")` with
   `dataHash = platformWorksDeclarationHash` and `frozen = true` — except
   while the declaration's contest state is `CONTESTED`, when it serves
   `frozen = false` (`AA-PLATFORM` requirement 7); finality for
   artist-less collections binds the immutable declaration instead of
   a sanction. A collection corrected under `AA-PLATFORM` requirement 8
   before finality serves the `ARTIST_SANCTION` component under its
   corrective binding (ADR 0014 decision V3). Exactly one of the two
   component types applies to any
   collection; a finality submission carrying neither, for any collection,
   is nonconformant.
8. There is no unsigned finalization path for artist-bound collections.
   Key loss and death do not soften this rule; they route through
   succession and dormancy (`AA-ESTATE`, `AA-DORMANCY`), which produce an
   authorized, clearly-classified signer — for stewards, sanction
   authority arrives only through the artist's pre-signed grant or the
   explicit veto-checked governance grant of `AA-DORMANCY`
   requirement 6 (ADR 0013 decision U4). Absence of artist sanction is
   therefore always provable intent (`PLATFORM_WORKS`), never silence.
   The one terminal shape this rule accepts — a dead artist with no
   designation under permanently failed governance — is documented,
   with its mitigations, at `AA-DORMANCY` requirement 9 (ADR 0014
   decision V3).
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
   when authored under artist-side authority: `AUTH_ARTIST`, an
   activated `AUTH_SUCCESSOR` whose effective capabilities include
   `CAP_INTENT_RECORDS`, an `AUTH_STEWARD` (`STEWARD_CAPABILITIES`
   carries `CAP_INTENT_RECORDS` — a steward completes conservation
   documentation, with the stored authority class permanently marking
   it; ADR 0013 decision U4), or a delegation carrying
   `CAP_INTENT_RECORDS`. The authority lists here and in the storage
   mirrors ([CMC-ARTIST-INTENT], [CMC-ARTIST-ATTESTATION] rule 3)
   follow the capability model exactly; a capability the mask grants is
   never silently withheld by a per-section list.
2. Finality for an artist-bound collection requires either a recorded
   `ARTIST_INTENT` record referenced in the finality manifest, or an
   explicit intent waiver recorded as a state-bound
   attestation with `subjectKind = SUBJECT_ARTIST_INTENT` and a
   waiver statement hash, authored under requirement 1 authority.
   Absence of both blocks finality; the waiver
   makes the absence provable intent (ADR 0010 decision D6.4). For a
   posthumous authority the waiver takes the form of an intent-absence
   statement (ADR 0013 decision U4): an activated `AUTH_SUCCESSOR` or
   `AUTH_STEWARD` holding `CAP_INTENT_RECORDS` records the
   `SUBJECT_ARTIST_INTENT` attestation whose statement asserts that no
   artist intent record or waiver exists to complete. Its stored
   authority class permanently marks that the artist's own voice is
   absent, it is never retroactive artist intent
   ([`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-ARTIST-INTENT] rule 4 owns the never-retroactive marking), and
   finality then proceeds with the absence provable rather than the
   collection deadlocked — an artist who dies intestate having recorded
   neither intent nor waiver no longer blocks posthumous finality
   forever.
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
   authority-side rule: for an artist-bound script-based collection,
   finality requires a resolved interview entry — a recorded interview
   reference or the artist's explicit `interview_waived` statement —
   and mere absence blocks finality
   ([CMC-FINALITY-INPUTS] rule 6 in the same document owns the
   blocking gate; ADR 0014 decision V8). Pre-finality tooling must
   emit a distinct warning — separate from the missing-intent
   warning — while the interview entry is unresolved, so the block is
   anticipated in preparation, never discovered at the ceremony. For
   museum-grade collections the interview entry
   (or its recorded waiver) is additionally a pre-first-sale floor
   record, required
   before the first primary-sale settlement under [CMC-MUSEUM-GRADE]
   rule 2 in that home (ADR 0013 decision U8), never a finality-time
   add-on. Absence of an interview
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
   includes `CAP_SANCTION`, an `AUTH_STEWARD` whose effective
   capabilities include `CAP_SANCTION` (`AA-DORMANCY` requirement 6),
   or a delegation carrying `CAP_SANCTION`;
   the collaborator policy (`AA-COLLAB` requirement 4) applies.
   Steward reach follows the sanction authority table exactly
   (ADR 0013 decision U4): an `AUTH_STEWARD` recovery approval is
   valid only for a collection-scope finality record of a collection
   satisfying the `AA-SANCTION` requirement 5 burn-block/appointment
   check, and reverts for `TOKEN`, `RELEASE`, `SEASON`, and `VIEW`
   scoped finality records — the same unprovability that bars scoped
   steward sanctions (`AA-EXCL` item 9) bars scoped steward recovery
   approvals, so which bytes are served for a scoped sanctioned work
   is never decided by an authority whose boundary no state read can
   prove. Scoped recovery approvals therefore require an activated
   `AUTH_SUCCESSOR` or delegation with `CAP_SANCTION`, or the
   requirement 2 fallback. The
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
    SUBJECT_FREEFORM,            // 8 statement only; no staleness read
    SUBJECT_DEPLOYMENT,          // 9 deployment facts hash (AA-DEPLOY)
    SUBJECT_IDENTITY_RECORD      // 10 operative identityRecordHash
                                 //    (AA-IDENTITY requirement 8;
                                 //    subjectId = artistId)
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
    uint8 authorityClass,   // of the operative attestation (AA-DISPLAY
                            // attestation_authority_class)
    uint64 signedAt
);
```

Requirements:

1. `recordArtistAttestation` verifies the signature onchain under
   `AA-SIGVER` (EOA and ERC-1271 alike, from genesis), stores the record
   and signature bytes, and emits `ArtistAttestationRecorded`. Authority is
   `AUTH_ARTIST`, an activated `AUTH_SUCCESSOR` whose effective
   capabilities include `CAP_ATTEST`, an `AUTH_STEWARD`
   (`STEWARD_CAPABILITIES` carries `CAP_ATTEST` — steward-completed
   preservation attestations are first-class and permanently
   class-marked; ADR 0013 decision U4), or a delegation with
   `CAP_ATTEST`; the record stores the authority class, and the storage
   mirror ([CMC-ARTIST-ATTESTATION] rule 3) follows the same list.
2. `subjectStateHash` must be the canonical hash the subject kind names
   (snapshot manifest hash, script hash, media manifest hash, finality
   record hash, policy hash, assignment hash, deployment facts hash,
   or operative identity record hash,
   each owned by its home
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

### Artist Deployment Attestation [AA-DEPLOY]

Every collection lives at a platform-deployed Core address, so explorers
and marketplaces see the platform — not the artist — as the
address-level deployer. The registry's attribution is stronger than any
deployer field, but external surfaces cannot read intent from an
address. The artist-signed deployment attestation is the address-level
provenance record (ADR 0012 decision T9): the artist's own signature
asserting that this collection at this Core address is their authorized
deployment. The per-collection facade profile — an address-per-series
front for Core identity — remains reserved in the open-questions
register (OQ-X8, option (c)) and is not decided here.

Requirements:

1. A deployment attestation is a state-bound artist attestation
   (`AA-ATTEST`) with `subjectKind = SUBJECT_DEPLOYMENT`,
   `subjectId = bytes32(uint256(uint160(address(core))))` — the subject
   is the address itself — and
   `subjectStateHash = deploymentFactsHash`:

```solidity
bytes32 deploymentFactsHash = keccak256(abi.encode(
    DEPLOYMENT_FACTS_DOMAIN,
    uint256(block.chainid),
    address(core),
    uint256(collectionId),
    bytes32(artistId),
    uint64(bindingGeneration),
    bytes32(bindingHash)
));
```

   The registry computes the expected hash from its own binding state at
   submission and rejects a mismatched payload; the attestation is
   recordable only for `ARTIST_ACCEPTED` or `ARTIST_SANCTIONED`
   bindings. `SUBJECT_DEPLOYMENT`'s numeric value is pinned in
   `AA-ATTEST`, enters the numeric ID catalog, and is never reused.
   Because the facts bind the binding generation, a later
   generation (or a revocation) makes the attestation `ATTESTED_STALE`
   through the ordinary staleness read — address-level provenance can
   never outlive the binding it attested.
2. `schemaId` is the pinned deployment-attestation document schema
   (`AA-DOMAINS`), and `statementHash` commits to a canonical RFC 8785
   document carrying the artist display name, chain ID, Core address,
   collection ID, any ENS names the operator has assigned, and the
   human-readable authorization statement. The document is stored
   through the collection metadata record satellites — the storage side
   is owned by
   [`collection-metadata-contract.md`](collection-metadata-contract.md)
   (record families and `ARTIST_*` write authority per `AA-RECORDS`
   requirement 2) — and dual-family mirrored.
3. Exposure is automatic: token JSON carries the attestation record
   hash (`AA-DISPLAY` `deployment_attestation`), and the collection
   `contractURI` surface should reference it, so explorer-grade tooling
   can resolve address-level artist provenance from the JSON it already
   reads.
4. Operational guidance (Operational layer, enforced through
   `AA-TOOLING`): the operator should assign a per-collection ENS name
   and publish verified-contract metadata naming the artist, and artist
   onboarding must present the shared-contract posture — one
   platform-deployed Core address, artist provenance served by the
   registry and this attestation rather than by a deployer field — as
   an explicit disclosed term alongside the royalty term
   (`AA-TOOLING` requirement 2).
5. Creator-verification posture (ADR 0013 decision U4). Independent of
   the reserved facade decision (OQ-X8), the registry attests three
   creator-verification facts an external marketplace or explorer can
   consume with no bespoke integration: the two-sided binding — an
   artist-accepted attribution, address-verifiable and evented
   (`AA-BINDING`); this section's deployment attestation — the
   artist's own signature over exactly this Core address and
   collection; and sanction records (`AA-SANCTION`) — each typed and
   reachable from token JSON and `contractURI`. What the registry
   cannot supply on a shared Core is a per-series deployer address for
   pipelines that verify creators by deployer key alone; that gap is
   exactly OQ-X8 option (c) and stays owner-reserved. Launch-evidence
   enforcement — per pinned marketplace target, proof that the launch
   artist displays as the verified creator or a recorded target
   limitation — is owned by the conformance matrix
   ([`launch-conformance-matrix.md`](launch-conformance-matrix.md)
   [LCM-MARKETPLACE]); this section owns what the registry can attest.
6. Required at first sale (ADR 0014 decision V3). For an artist-bound
   collection, a recorded deployment attestation for the operative
   binding generation is a first-sale floor record, not an option:
   `requireMintConsent` reverts until one exists (`AA-CONSENT`
   requirement 6), so no artist-bound work is ever sold — primary
   sales settle through the mint path — while the address-level
   provenance record explorer pipelines key on is absent. The
   attestation is a session-1 ceremony item within the pinned budget
   (`AA-TOOLING` requirement 6): it is computable from binding state
   the moment acceptance completes, and it binds the generation, so a
   later generation (including a corrective rebinding, `AA-PLATFORM`
   requirement 8) requires a fresh attestation before its next mint.
   "When one exists" wording elsewhere in this document describes
   pre-floor states (an accepted-but-never-minted binding) and
   non-mint surfaces, never a licence to sell without it.

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

## Artist Payout Designation [AA-PAYOUT]

Settlement contracts pay the artist for the life of the Core line, so
the payout entitlement must be a typed state read — never a parsed
document, and never the signing key (ADR 0013 decision U1). This section
is the single payout-resolution surface: `COLLECTION_ARTIST` and
collaborator template sources
([`revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
[RSR-TEMPLATES];
[ADR 0008](adr/0008-revenue-splits-and-royalty-resolver.md)), and
`AA-ECON` requirement 1, all cite these
reads and this one resolution moment.

Pinned typed payload (long-lived; the chain rule below picks the
operative record):

```text
StreamArtistPayoutDesignation(
    bytes32 artistId,
    address payoutAccount,          // nonzero settlement recipient
    bytes32 previousDesignationRecordHash, // zero for the first
    uint256 nonce,
    uint64 signedAt
)
```

Payout reads (Permanent):

```solidity
function artistPayoutAccount(bytes32 artistId)
    external view
    returns (address payoutAccount, bytes32 designationRecordHash);

function collaboratorPayoutAccount(bytes32 artistId, address collaborator)
    external view
    returns (address payoutAccount, bytes32 designationRecordHash);
```

Requirements:

1. `recordPayoutDesignation` verifies the payload under `AA-SIGVER`,
   stores the record and signature bytes, emits
   `ArtistPayoutDesignationRecorded`, and hashes the record under
   `PAYOUT_DESIGNATION_RECORD_DOMAIN` (`AA-DOMAINS`). Authority is
   identity-revision-class (`AA-IDENTITY` requirement 6): `AUTH_ARTIST`
   or an activated `AUTH_SUCCESSOR` whose effective capabilities
   include `CAP_IDENTITY_REVISION`; designations are never delegable
   and never available to `AUTH_STEWARD` — a governance-appointed
   steward must never be able to re-point an artist's money.
   `payoutAccount` must be nonzero.
2. Designations form one linear chain per identity, exactly like
   identity-document revisions: `previousDesignationRecordHash` must
   equal the operative designation record hash at submission (zero for
   the first designation) and forks revert, so an old signed-but-unused
   designation payload can never re-point payouts after a newer one is
   recorded. The operative designation is the tip of the chain that is
   not adjudicated-superseded (`AA-GUARD` requirement 7) and not
   provisional (`AA-GUARD` requirement 8) — payout-designation records
   join both lists, because re-pointing revenue is a thief's first
   move. While the identity is `IDENTITY_CONTESTED`, new designations
   are rejected (`AA-GUARD` requirement 4).
3. Resolution is at settlement time (ADR 0013 decision U1): settlement
   contracts materializing an artist-bound template resolve these reads
   in the settlement call, so every settlement pays the operative
   designation then in force. The economics consent of `AA-ECON` binds
   the designation revision in force at consent as evidence (the
   consent record and event carry its record hash), and a later
   designation revision re-points future settlements without
   re-consent — revisions are themselves artist-signed records of this
   section, so currency never requires a new economics ceremony.
   Executed settlements keep the accounts resolution produced; nothing
   re-points retroactively.
4. `authorityAddress` is never a payout account source or fallback, at
   any layer, under any failure (ADR 0013 decision U1): the signing key
   and the payment entitlement are deliberately separate systems
   (`AA-SPLITS` requirement 4), and a key rotation must never move
   money. An identity with no operative designation resolves to
   `(address(0), bytes32(0))`; consumers must treat the zero account as
   unresolvable — an artist-bound template then fails to materialize
   and settlement reverts before any state change ([RSR-TEMPLATES] owns
   the settlement-side revert; the registry never substitutes a
   default). `recordEconomicsConsent` must revert for an artist-bound
   collection while the primary identity, or any accepted collaborator
   with a nonzero `shareLabelId`, has no operative designation, so the
   unresolvable case is caught at the consent ceremony rather than
   discovered at first sale.
5. `collaboratorPayoutAccount(artistId, collaborator)` resolves the
   operative designation of the collaborator identity `artistId` and
   additionally requires the pair `(artistId, collaborator)` to be
   acceptance-linked (`AA-COLLAB` requirement 7); it returns
   `(address(0), bytes32(0))` otherwise. Settlement resolves the whole
   collaborator path from typed reads alone: `attributionState` gives
   the operative generation, `collaboratorAt` gives each accepted
   collaborator's account, `shareLabelId`, and `collaboratorArtistId`,
   and this read gives the payout — with the pair check proving the
   account-identity association the artist's binding ratified.
6. The identity document's `payoutAccounts` member (`AA-IDENTITY`
   requirement 2) is a human-readable mirror for archives and
   onboarding; the typed designation record is the sole
   settlement-authoritative source, and on any divergence the typed
   record wins. One home, one read path, one resolution moment.

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
   collection must include at least one `artist`-labeled entry and one
   entry per collaborator with a nonzero `shareLabelId` (`AA-COLLAB`).
   Artist-class payout addresses resolve through the typed payout
   designation surface of `AA-PAYOUT` (ADR 0013 decision U1): dynamic
   `COLLECTION_ARTIST` and collaborator sources resolve
   `artistPayoutAccount` / `collaboratorPayoutAccount` at settlement
   time, and a static artist-class entry is conformant only when its
   account equals the relevant operative designation at the moment the
   assignment's economics consent is recorded (tooling-checked; static
   entries deliberately do not track later designation revisions, which
   is why templates should carry the dynamic sources). The consent
   record binds the primary identity's operative
   `payoutDesignationRecordHash` in force at consent, and
   `recordEconomicsConsent` reverts while any required designation is
   unset (`AA-PAYOUT` requirements 3 and 4). Anchoring payout to the
   operative typed designation means an artist who rotates their payout
   Safe records one signed designation and every later settlement pays
   the new account with no re-consent; executed settlements keep the
   accounts resolution produced, and `authorityAddress` is never a
   payout fallback (`AA-PAYOUT` requirement 4).
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
7. The consent boundary is stated, not implied (ADR 0012 decision T4):
   economics consent covers the split and royalty assignment — who is
   paid and in what shares — never the primary-sale price or mechanics.
   Unit price, reserve, decay schedule, minimums, refund windows, and
   sale kind bind into the sale layer's `saleConfigHash`
   ([`stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   [SSA-IDENTITY]) and are artist-gated only when the binding elects
   `SALE_CONSENT_REQUIRED` (`AA-SALE-CONSENT`). A binding that does not
   elect it leaves sale parameters operator-set within the consented
   phase policy, and artist onboarding must disclose that boundary in
   exactly those terms (`AA-TOOLING` requirement 2), so no artist can
   discover after a repricing that their signature never covered price.

## Sale-Parameter Consent [AA-SALE-CONSENT]

Policy consent binds mintability; economics consent binds shares. The
most economically material sale term — the price and mechanics a work is
actually sold under — is a sale-layer fact. Bindings may pin it into the
artist consent surface (ADR 0012 decision T4): `SALE_CONSENT_REQUIRED`
is elected in the binding proposal, ratified by acceptance inside
`bindingHash` (`AA-BINDING`), and immutable per generation, exactly like
the consent mode.

Pinned typed payload:

```text
StreamArtistSaleConsent(
    address core,
    address saleAdapter,
    uint256 collectionId,
    bytes32 saleId,
    bytes32 saleConfigHash,
    uint256 nonce,
    uint64 deadline
)
```

`saleId` and `saleConfigHash` are the sale identity and configuration
fingerprint owned by
[`stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
[SSA-IDENTITY]; this document does not restate their preimages. Because
the consent binds the exact `saleConfigHash`, the artist's signature
covers unit price, auction reserve and increments, decay schedules,
pay-what-you-want minimums, refund windows, and sale kind — the complete
committed sale configuration.

Requirements:

1. `recordSaleConsent` verifies the payload under `AA-SIGVER`, enforces
   the collaborator policy (`AA-COLLAB` requirement 4; the
   `CAP_SALE_CONSENT` override row applies when present), stores the
   record and signature bytes, and emits `ArtistSaleConsentRecorded`
   with the record hash (`SALE_CONSENT_RECORD_DOMAIN`, `AA-DOMAINS`).
   It must revert while the collection is `DISPUTED` or `REVOKED`
   (`AA-STATE` requirement 4).
2. Authority follows consent mode: on `ARTIST_SIGNED_POLICY` collections
   the consent must be signed by the artist authority (`AUTH_ARTIST` or
   an activated `AUTH_SUCCESSOR` whose grant includes
   `CAP_SALE_CONSENT`); on `ARTIST_DELEGATED` collections an active
   delegation carrying `CAP_SALE_CONSENT` may also consent
   (`AA-DELEG` requirement 5).
3. Enforcement: where the collection's binding pins
   `SALE_CONSENT_REQUIRED`, a sale program must not activate — no
   purchase, bid, commit, or claim entry action may become executable —
   until the sale adapter has verified `requireSaleConsent(collectionId,
   saleId, saleConfigHash)` against this registry over the exact
   committed configuration. `requireSaleConsent` reverts when the scope
   is elected and no matching consent record exists; it succeeds
   trivially for `SALE_CONSENT_NONE` bindings and `PLATFORM_WORKS`
   collections, so adapters may call it unconditionally. The sales
   specification mirrors this as a sale-activation requirement.
4. Consents are append-only and bound to one `(collectionId, saleId,
   saleConfigHash)`. A changed sale configuration produces a different
   `saleConfigHash` and requires fresh consent; stale consents authorize
   nothing, and an operator repricing an artist's consented drop is
   structurally indistinguishable from configuring an unconsented sale.
5. The election is honest in both directions (`AA-ECON` requirement 7):
   electing the scope buys signature-per-sale friction for price
   control; declining it keeps sale parameters operator-set. Operator
   tooling must present the election in the binding proposal flow, and
   the onboarding disclosure states which was chosen.
6. Numeric values of `SaleConsentScope` (`AA-BINDING`) are pinned,
   enter the numeric ID catalog, and are never reused with different
   meaning; the value is hashed into every `bindingHash`.

## Artist Content Consent And Freeze [AA-CONTENT]

Policy consent binds mintability; it does not bind what minted tokens
render. From the first-release content ratification (or the first mint)
until executed finality, the artist holds a
standing veto over the content of their own works, and from binding
acceptance onward a
unilateral defensive freeze (ADR 0011 decision R7.2; ADR 0014 decision
V3). The content actually sold at first mint is itself
artist-ratified: no artist-bound collection mints until the artist has
signed the content root it will sell under (requirement 6).

Content-affecting record families are the collection metadata surfaces
that change what a minted token renders or resolves to: the script
manifest, dependency manifest, media manifest, renderer assignment, and
snapshot-route families, identified by the family and lock identifiers
owned by [`collection-metadata-contract.md`](collection-metadata-contract.md)
(Lock Model and record families); that document owns the exact family
list and mirrors the storage-side enforcement of this section.

Entropy joins the same boundary (ADR 0013 decision U4): on a generative
platform the seed is the work's genome, so for artist-bound collections
whose tokens derive from coordinator-served entropy, the per-collection
entropy configuration (provider assignment, security class,
fresh-recovery policy) and any fresh-entropy redraw of a minted token's
pending entropy are content-affecting writes. The entropy family
identifiers, canonical entropy state hashes, and caller-side enforcement
are owned by
[`stream-entropy-coordinator.md`](stream-entropy-coordinator.md), which
mirrors this section: between the first mint and executed finality the
coordinator must verify `requireContentConsent` over the exact resulting
entropy state before applying such a change, with the
artist-unavailability fallback of `AA-RECOVERY` requirement 2 available
when no artist authority is live, and the unilateral content freeze
(requirement 3) may pin entropy lock classes like any other family — the
consent reads are `bytes32`-generic by construction, so no new registry
surface is needed.

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
                             // metadata-contract lock vocabulary plus
                             // coordinator-owned entropy lock classes
    bytes32 expectedStateHash, // current collection content state pinned
    uint256 nonce,
    uint64 deadline
)

StreamArtistContentRatification(
    address core,
    address metadataContract,
    uint256 collectionId,
    bytes32 contentStateHash, // first-release content commitment;
                              // composition owned by the metadata home
                              // (CMC-ARTIST-CONTENT-VETO rule 6)
    uint256 nonce,
    uint64 deadline
)
```

Requirements:

1. For an artist-bound collection, from the earlier of the operative
   first-release content ratification (requirement 6) and the first
   minted token, until an
   executed finality record exists, every write to a content-affecting
   record family requires a verified `StreamArtistContentConsent` over
   the exact resulting family state hash (the same canonical hash the
   family's staleness read exposes, `AA-ATTEST` requirement 2). The
   collection metadata contract must call `requireContentConsent` before
   applying such writes; before ratification and the first mint, and
   after executed
   finality (where content locks and the recovery rules of `AA-RECOVERY`
   govern), no content consent is required and iteration stays free —
   ratification is the artist's own act, so the artist chooses when
   free iteration ends (ADR 0014 decision V3).
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
   collection at any time from binding acceptance until executed
   finality (ADR 0014 decision V3 — the pre-mint freeze right; this
   home now matches the metadata mirror,
   [CMC-ARTIST-CONTENT-VETO] rule 3, which already grants the freeze
   from acceptance):
   `authorizeArtistContentFreeze` records a verified
   `StreamArtistContentFreeze`; any caller may relay it to the metadata
   contract, which must verify `isContentFreezeAuthorized` and apply the
   named one-way locks when the collection's current content state
   matches `expectedStateHash`. The right is freeze-only and defensive,
   exactly parallel to the royalty freeze (`AA-ECON` requirement 5): it
   cannot change content, cannot unlock, and cannot touch other
   collections. Locks applied this way are ordinary metadata-contract
   one-way locks; nothing about them blocks registry authority
   (`AA-DISPLAY` requirement 7). Because the freeze application
   verifies the live state against `expectedStateHash`, a freeze
   authorized alongside the requirement 6 ratification is the artist's
   hard proof that the ratified root is the root actually configured —
   a mismatch refuses loudly instead of selling silently.
4. Content consent gates content-affecting families only. It never gates
   the operational phase pause flag, preservation-receipt appends,
   owner records, or display-metadata families that cannot change served
   artwork bytes; the metadata contract's family classification is the
   boundary, and disputes about the boundary resolve to the stricter
   class.
5. Records and events: content consents, freezes, and ratifications
   are hashed under
   `CONTENT_CONSENT_RECORD_DOMAIN`, `CONTENT_FREEZE_RECORD_DOMAIN`,
   and `CONTENT_RATIFICATION_RECORD_DOMAIN`,
   store signature bytes per `AA-SIGVER`, emit
   `ArtistContentConsentRecorded` / `ArtistContentFreezeAuthorized` /
   `ArtistContentRatificationRecorded`, and
   enter the record chains (`AA-RECORDS`). While the collection is
   `DISPUTED`, new content consents and ratifications are blocked
   (`AA-STATE` requirement
   4) but the defensive content freeze remains available.
6. First-release content ratification (ADR 0014 decision V3). For a
   system whose thesis is that consent is the product, the primary
   sale itself must serve artist-approved content: `policyHash` covers
   mintability, never the render pipeline, so the pipeline gets its
   own signature. `recordContentRatification` verifies a
   `StreamArtistContentRatification` under `AA-SIGVER`, binding the
   exact `contentStateHash` — the first-release content commitment
   whose composition the metadata home owns
   ([`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-ARTIST-CONTENT-VETO] rule 6): the recorded token content root
   covering the first release, or, for `ONCHAIN`-mode works whose
   binding is the manifests themselves, the collection's canonical
   content state over its content-affecting families — the latter the
   same collection-wide commitment the freeze pins as
   `expectedStateHash`. Authority follows consent mode exactly
   as requirement 2 (delegated ratification is invalid on
   `ARTIST_SIGNED_POLICY` collections; `CAP_CONTENT_CONSENT` covers it
   on `ARTIST_DELEGATED` collections), the collaborator policy
   applies, and records are append-only with the latest operative —
   after consented post-ratification changes, re-ratifying the new
   root is hygiene, not obligation, because every applied change was
   itself artist-signed. Effects: recording a ratification opens the
   requirement 1 consent window, and `requireMintConsent` reverts for
   an artist-bound collection until an operative ratification exists
   (`AA-CONSENT` requirement 6) — the first minted, sold token
   therefore renders either the ratified state or a consented
   evolution of it, and a compromised operator pipeline swapping the
   script manifest an hour before a public drop needs the one thing
   it cannot forge: the artist's signature. Tooling must present the
   live canonical content state at signing and the independent
   recomputation tool must reproduce it (`AA-TOOLING` requirements 1,
   3, and 4); the requirement 3 freeze is the artist's unilateral
   backstop when tooling is not trusted.
   `firstReleaseRatification(collectionId)` (`AA-CONSENT` interface)
   returns the operative ratification for the metadata contract's
   window enforcement and for onboarding tooling. Entropy
   configuration keeps its first-mint boundary (the coordinator
   mirror is unchanged); the acceptance-onward freeze pinning entropy
   lock classes is the artist's pre-mint entropy defense, and the
   seed of any minted token is already consent-gated.

## Estate Interaction With Split Wallets [AA-SPLITS]

Split profiles are immutable and entitlements are address-bound; this
section states exactly what succession can and cannot recover, so artists
consent knowingly.

Requirements:

1. Normative guidance, enforced by operator tooling defaults and stated in
   artist onboarding: artist and collaborator payout accounts — the
   accounts payout designations name (`AA-PAYOUT`) — should be
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
   rotating one never silently moves the other. The payout designation
   (`AA-PAYOUT`) moves future settlement resolution only; balances
   already owed inside deployed split wallets stay address-bound per
   requirement 3.
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
   `ROTATION_RECORD_DOMAIN`, sets `contestEndsAt = block.timestamp +`
   the identity's effective rotation-contest window (`AA-GUARD`
   requirement 10; the global `ARTIST_ROTATION_CONTEST_SECONDS` unless
   the operative guardian-set record pins a higher per-identity floor),
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
   5), so the attacker can never win by racing: standing revocation
   (`AA-GUARD` requirement 11) is impossible until long after the
   contested transition, and an attacker-staged attribution
   repudiation is vetoed the same way (`AA-DISPUTE` requirement 5).
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
    uint64 minContestSeconds, // per-identity contest-window floor;
                              // 0 adopts the global value; bounded by
                              // MAX_GUARDIAN_MIN_CONTEST_SECONDS
                              // (requirement 10; ADR 0013 decision U4)
    uint256 nonce,
    uint64 signedAt
)
```

Requirements:

1. A guardian set is recorded under `AUTH_ARTIST` authority (direct or
   signed) — or, so guardian protection survives the authority
   transitions it exists to police (ADR 0012 decision T4), under an
   activated `AUTH_SUCCESSOR` whose effective capabilities include
   `CAP_GUARDIAN_SET`, or under `AUTH_STEWARD` (the default steward
   mask includes `CAP_GUARDIAN_SET`, `AA-DORMANCY` requirement 6): an
   estate holding authority for decades can add fresh guardians
   instead of running the most theft-exposed phase of the
   identity's life on a stale set. Posthumous maintenance is
   additive by default (ADR 0014 decision V3): an `AUTH_SUCCESSOR` or
   `AUTH_STEWARD` guardian-set record that omits any member of the
   operative artist-recorded set — the operative guardian-set record
   whose stored authority class is `AUTH_ARTIST` — reverts unless the
   actor's effective capabilities include `CAP_GUARDIAN_DISPLACE`
   (`AA-DELEG`), a bit grantable only by the artist's own designation
   or directive and held by no default mask. The policed party can
   therefore never replace the police: the artist's lifetime guardians
   stay in the registered set, with their rotation-veto and
   recovery-veto standing, unless the artist personally pre-granted
   their removal. A full artist-recorded set at `MAX_ARTIST_GUARDIANS`
   leaves an ungranted posthumous authority no maintenance move — an
   accepted consequence of the artist's own election. Records are
   verified under
   `AA-SIGVER`, hashed under `GUARDIAN_SET_RECORD_DOMAIN`, evented
   (`ArtistGuardianSetUpdated`) with their authority class, and
   append-only; the record with the
   highest nonce that is not adjudicated-superseded (requirement 7) and
   not provisional (requirement 8) is operative. The artist may forbid
   `CAP_GUARDIAN_SET` in a directive (`AA-ESTATE` requirement 4) to
   keep their lifetime guardians as a permanent check on the estate
   itself. Guardians may be EOAs
   or contracts
   (family, studio, gallery, lawyer, estate); artist onboarding tooling
   must recommend registering at least one guardian
   (`AA-TOOLING`).
2. Guardian powers are exhaustively: approving a pending rotation
   (`approveArtistRotation`), vetoing a pending rotation
   (`vetoArtistRotation`), vetoing a staged attribution repudiation
   (`vetoAttributionRepudiation`, `AA-DISPUTE` requirement 5;
   ADR 0014 decision V3), filing an identity-compromise contest
   under requirement 5, and vetoing a staged identity recovery under
   requirement 7 (`vetoIdentityRecovery`). Guardian actions are direct
   calls from the
   guardian address (contract guardians act through their own
   execution); guardians hold no capability bits, sign no artist
   payloads, and can never author records in the artist's name —
   compromising every guardian yields veto power, not authorship.
3. While a rotation is pending, a veto by any single registered guardian,
   by the identity's current authority address, by the operative
   designated successor, or by any prior authority address of the same
   identity whose standing is unrevoked (requirement 11) cancels the
   pending rotation, emits `ArtistRotationVetoed`
   with a reason hash, and sets the identity status to
   `IDENTITY_CONTESTED`. Veto is deliberately cheaper than approval
   (one vetoer versus a quorum): the registry cannot distinguish victim
   from attacker, so it freezes toward safety and routes to
   adjudication.
4. While `IDENTITY_CONTESTED`, the registry must reject new binding
   acceptances, sanctions, policy/economics/sale/content consents,
   content ratifications, delegation
   grants, designations, directives, guardian-set updates, identity
   revisions, payout designations, steward sanction grants,
   prior-address standing revocations (requirement 11), estate
   activations, dormancy
   initiation and completion, attribution-repudiation staging and
   execution (`AA-DISPUTE` requirement 5 — a filed contest voids any
   pending repudiation of the identity's bindings), and further
   rotation staging for the
   identity. Defensive
   actions remain available: authorization revocations (`AA-REVOKE`),
   dispute openings and counter-statements, royalty and content freezes.
   The contested state exits only through arbiter resolution
   (requirement 6) or an identity recovery (requirement 7); no signature
   from the (possibly stolen) authority key can clear it.
5. Standing to contest outlives every authority-vesting
   transition by default — revocable only under requirement 11
   (ADR 0014 decision V3) — and covers every such
   transition, not only rotations (ADR 0012 decision T4): any prior
   authority address of an identity whose standing is unrevoked, the
   operative designated successor,
   or any registered guardian may file an identity-compromise contest
   via `contestArtistIdentity` (evidence hash and reason hash required,
   empty evidence reverts; `subjectRecordHash` names the rotation,
   estate-activation, dormancy, or recovery record contested, or zero
   for a general compromise filing; recorded under
   `IDENTITY_CONTEST_RECORD_DOMAIN` and evented via
   `ArtistIdentityContested`) — while an estate-activation or dormancy
   notice window is running, and at any time after a rotation, estate
   activation, dormancy completion, or identity recovery executes.
   `ROLE_ATTRIBUTION_ARBITER` may file the same contest through a
   staged, reasoned action — the third-party evidence path, mirroring
   arbiter-opened disputes (`AA-DISPUTE` requirement 1) — so a
   stranger's proof of a stolen successor key has a route into the
   registry. Filing sets the identity status to `IDENTITY_CONTESTED`
   (from `IDENTITY_ACTIVE`, `IDENTITY_DORMANCY_NOTICE`, or
   `IDENTITY_SUCCEEDED` alike), which voids any pending estate
   activation (`AA-ESTATE` requirement 2) and blocks dormancy
   completion (`AA-DORMANCY` requirement 3). This closes the
   wait-out-the-window path in every lane: an attacker
   who completes an uncontested rotation — or who probates a stolen
   successor key into an executed estate activation — still never holds
   incontestable authority. The griefing inverse — a compromised old key
   filing harassment contests or vetoing every rotation — is bounded
   two ways (ADR 0014 decision V3): the arbiter's dismissal of a
   demonstrated-bad-faith filing may revoke the filing prior address's
   future contest and veto standing for that identity (recorded in the
   resolution, evented, and appealable under `AA-DISPUTE`
   requirement 9), and the current authority may revoke a prior
   address's standing after the requirement 11 tail — so
   freeze-toward-safety never hardens into a permanent
   denial-of-service lever held by every historical key.
6. `ROLE_ATTRIBUTION_ARBITER` resolves a contested identity by staged,
   reasoned governance action (delay discipline of `AA-ROLES`): either
   dismissal — restoring the pre-contest status under the incumbent
   authority (`IDENTITY_ACTIVE`, `IDENTITY_SUCCEEDED` under the vested
   successor or steward, or `IDENTITY_DORMANCY_NOTICE` with its
   original `noticeEndsAt`) — or an identity recovery under
   requirement 7. A pending estate activation voided by the contest is
   not revived by dismissal; the successor re-requests and a fresh
   notice window runs, so a contested filing never banks notice time.
   Every resolution links the contest evidence and is evented.
7. Identity recovery reassigns `authorityAddress` for a hijacked
   `artistId` without a new identity — the join key museums rely on
   never changes (`AA-IDENTITY` requirement 1). `recoverArtistIdentity`
   requires: the arbiter's resolution staged under the
   `TERMINAL_FREEZE` class — its delay plus the independent veto
   guardian of [GOV-WINDOWS], because a captured hierarchy must not be
   able to both stage and bless its own identity takeover (`AA-ROLES`;
   ADR 0012 decision T4) — carrying evidence and
   reason hashes; new-side acceptance by the recovery address (direct
   call or `StreamArtistRotationAcceptance` signature); and an
   append-only recovery record hashed under
   `IDENTITY_RECOVERY_RECORD_DOMAIN`, emitted via
   `ArtistIdentityRecovered`. The identity's registered guardians hold
   veto standing over the staged recovery in addition to the
   independent veto guardian: `vetoIdentityRecovery(artistId,
   reasonHash)` is a direct guardian call available while the
   resolution is staged, is evented
   (`ArtistIdentityRecoveryVetoed`), and permanently blocks that
   staged action (a fresh resolution may be staged, each publicly
   delayed). Supersession never silences the artist's own installed
   check (ADR 0013 decision U4): a staged resolution may enumerate as
   adjudicated-superseded — and thereby disqualify from this veto —
   only guardian-set records recorded at or after the earliest
   authority-vesting transition the resolution's evidence contests, or
   still provisional under requirement 8. An attacker-installed
   guardian set therefore cannot veto the recovery that unseats it,
   while every guardian-set record predating the contested transition —
   the artist's lifetime guardians above all — retains full veto
   standing regardless of enumeration. Disqualifying a pre-transition
   guardian set is possible only when the guardians themselves are the
   disputed party, and then only by the appeal tier: the resolution
   must be staged by the governance tier holding role-admin authority
   over `ROLE_ATTRIBUTION_ARBITER` (`AA-DISPUTE` requirement 9), never
   by the arbiter alone, still under `TERMINAL_FREEZE` with the
   independent veto guardian, with the hostile-guardian evidence
   linked. A directive forbidding `CAP_GUARDIAN_SET` (`AA-ESTATE`
   requirement 4) also forbids supersession of pre-transition
   guardian-set records at every tier — supersession is adjudication,
   not a capability exercise, and the artist's forbiddance reaches
   both. The
   resolution names the vested authority class: `AUTH_ARTIST` (status
   `IDENTITY_ACTIVE`) for a living artist's replacement key, or
   `AUTH_SUCCESSOR` (status `IDENTITY_SUCCEEDED`, capabilities bounded
   by the operative non-superseded designation and directives) when
   recovering a posthumous takeover to the rightful estate — so
   recovery is reachable from `IDENTITY_SUCCEEDED` and never fabricates
   living-artist authority for an estate. Recovery revokes all
   outstanding
   delegations, and the resolution may enumerate attacker-era
   designation, directive, guardian-set, identity-revision,
   payout-designation, steward-sanction-grant, and prior-address
   standing-revocation records
   as adjudicated-superseded
   (`IDENTITY_RECOVERY_SUPERSESSION_DOMAIN` over the sorted
   record-hash list; guardian-set enumeration bounded as above): superseded
   records stay in history but stop being
   operative, so "highest nonce is operative" (`AA-ESTATE`) reads
   "highest nonce not adjudicated-superseded" and chain-tip rules
   (`AA-IDENTITY` requirement 6, `AA-PAYOUT` requirement 2) rewind to
   the last non-superseded link. Recovery never rewrites
   consumed consents, sanctions, or any executed history.
8. Records authored in a takeover window are provisional: a successor
   designation, estate directive, guardian-set, identity-revision,
   payout-designation, or steward-sanction-grant
   record recorded within the identity's effective rotation-contest
   window (requirement 10) after any authority-vesting
   transition executes (a rotation, estate activation, dormancy
   completion, or identity recovery) becomes
   operative only when that same window elapses without an
   identity-compromise contest. A genuine artist or estate waits days;
   a thief's
   rewrite of the estate plan — or of where the money goes — never
   outruns the contest.
9. Dormancy and the contest window interact conservatively: dormancy must
   not initiate while a rotation is pending or the identity status is
   `IDENTITY_CONTESTED`, and any veto, approval, or contest filing counts as
   activity for nobody — guardian actions never update
   `lastAuthorityActionAt`, which tracks artist-side authority only
   (`AA-IDENTITY` requirement 3).
10. Guardian holder latency is sized, not assumed (ADR 0013 decision
    U4; the deployment-side analogue is [LTA-GOV] rule 6 as extended
    by ADR 0012 decision T5). Guardians may be governor-class
    contracts whose own proposal-and-execution cycle takes days; a
    guardian that cannot physically act inside the contest window is
    the dead-control pattern the governance layer already forbids for
    its own roles. Two rules close it. First, the guardian-set record
    pins `minContestSeconds`, a per-identity contest-window floor:
    the identity's effective rotation-contest window is the greater of
    the global `ARTIST_ROTATION_CONTEST_SECONDS` and the operative
    guardian-set record's `minContestSeconds` (zero adopts the global
    value; values above `MAX_GUARDIAN_MIN_CONTEST_SECONDS`,
    `AA-LIMITS`, revert), so a later global lowering toward the
    72-hour floor can never undercut the window a slow guardian set
    was registered against. The effective window governs rotation
    `contestEndsAt` (`AA-ROTATE` requirement 1) and the requirement 8
    provisional window. Second, onboarding tooling must check every
    declared guardian's account class against the effective contest
    window and against the [GOV-WINDOWS] terminal-freeze veto floor
    (the identity-recovery veto of requirement 7 runs on
    governance-side timing this record cannot extend), and must warn —
    and, for a guardian set whose every member is slower than the
    effective window, block — before registration (`AA-TOOLING`
    requirement 2).
11. Prior-address standing revocation (ADR 0014 decision V3). A prior
    authority address's veto standing (requirement 3) and contest
    standing (requirement 5) outlive its retirement by default —
    freeze-toward-safety — but not incontestably forever: once the
    authority-vesting transition that retired the address has
    executed, its effective contest window (requirement 10) has
    elapsed, and the pinned tail
    `ARTIST_PRIOR_ADDRESS_STANDING_TAIL_SECONDS` (`AA-LIMITS`) has
    additionally passed, the identity's current authority may revoke
    that address's standing. The pinned typed payload is:

```text
StreamArtistStandingRevocation(
    bytes32 artistId,
    address revokedAddress,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 deadline
)
```

    `revokePriorAddressStanding` accepts a
    direct call or a verified `StreamArtistStandingRevocation`
    payload; authority is `AUTH_ARTIST` or an activated
    `AUTH_SUCCESSOR` — never `AUTH_STEWARD` and never delegable,
    because prior-address standing is a check on exactly those
    parties — and the action reverts while the identity is
    `IDENTITY_CONTESTED` or any rotation or repudiation is pending.
    Revocations are append-only records hashed under
    `STANDING_REVOCATION_RECORD_DOMAIN`, evented
    (`PriorAddressStandingRevoked` with the retired transition's
    record hash), readable via
    `priorAddressStandingRevoked(artistId, priorAddress)`, and
    adjudicated-supersedable (requirement 7), so an
    identity recovery restores standing an attacker stripped. A
    revoked address loses rotation-veto and identity-contest standing
    for the identity; standing it holds as a currently registered
    guardian is a guardian-set fact and is untouched. The timing
    makes racing impossible: a thief who rotates in can neither
    strip the victim's standing before the tail elapses nor while the
    victim's contest keeps the identity contested — while an artist
    whose decades-old leaked key vetoes every rotation can, after one
    adjudication-free tail, permanently retire that lever without
    arbiter dependence. Sovereign rotation stays sovereign; the
    griefing surface does not.

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

Steward sanction grant payload (long-lived; requirement 7;
ADR 0013 decision U4):

```text
StreamStewardSanctionGrant(
    bytes32 artistId,
    bool granted,            // true grants; false withdraws
    bytes32 statementHash,   // canonical grant statement document
    uint256 nonce,
    uint64 signedAt
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
   The notice window doubles as the third-party challenge window
   (ADR 0012 decision T4): any registered guardian, any prior
   authority address of the identity, or `ROLE_ATTRIBUTION_ARBITER`
   may file the identity-compromise contest of `AA-GUARD`
   requirement 5 against the pending activation — a stolen successor
   key now has the same pre-effect tripwire a stolen rotation key has —
   and standing continues after execution, so even an uncontested
   activation never vests incontestable authority. A voided request is
   never revived; the successor re-requests and a fresh notice window
   runs.
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
7. Pre-signed steward sanction grant (ADR 0013 decision U4). The
   sanction is the strongest provenance statement a signer can make in
   an artist's name, so a governance-appointed steward holds it only
   with the artist's own pre-authorization or a veto-checked
   governance grant (`AA-DORMANCY` requirement 6). While alive and in
   control, the artist may record a `StreamStewardSanctionGrant`:
   `recordStewardSanctionGrant` accepts `AUTH_ARTIST` authority only —
   successors, stewards, and delegates can never grant it, because the
   grant exists precisely to carry the artist's voice past them —
   verified under `AA-SIGVER`, hashed under
   `STEWARD_SANCTION_GRANT_RECORD_DOMAIN` (`AA-DOMAINS`), evented
   (`StewardSanctionGrantRecorded`), and append-only. The record with
   the highest nonce that is not adjudicated-superseded (`AA-GUARD`
   requirement 7) and not provisional (`AA-GUARD` requirement 8) is
   operative; `granted = false` withdraws a prior grant.
   `statementHash` commits to a canonical RFC 8785 statement of what
   the artist is authorizing, rendered human-readable at signing
   (`AA-TOOLING` requirement 1). A directive forbidding `CAP_SANCTION`
   (requirement 4) overrides any grant — forbidden capabilities stay
   absolute — and the dormancy-completing action's evidence must
   reference the operative grant record hash it relied on. The grant
   affects steward masks only; successor capabilities come from
   designations and directives alone.

## Governed Dormancy Procedure [AA-DORMANCY]

Lost keys without designations must not orphan artist authority forever,
and the recovery must be impossible to abuse quietly (ADR 0010 decision
D2.2). Dormancy is slow, loud, cancellable by any sign of life, and staged
through the canonical governance action.

Governed dormancy windows (seconds-denominated staged-governance values
with immutable floors owned by this home — not Governed Time
Parameters, per the [LTA-GTP] closed-world rule in
[`stream-long-term-architecture.md`](stream-long-term-architecture.md)
(ADR 0013 decision U9) — following the Governed Gas Parameter change
discipline of ADR 0010
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
   authority class. Liveness always wins. The notice window is also the
   third-party challenge window (ADR 0012 decision T4): any registered
   guardian, any prior authority address, or the arbiter may file the
   identity-compromise contest of `AA-GUARD` requirement 5 — the path
   for a guardian who knows the artist is alive but unable to act
   onchain — and a dismissal restores `IDENTITY_DORMANCY_NOTICE` with
   the original `noticeEndsAt`.
3. `completeArtistDormancy` is a second staged governance action, valid
   only after `noticeEndsAt`, and must revert while the identity status
   is `IDENTITY_CONTESTED` (`AA-GUARD` requirement 5). Completion vests
   authority per the operative
   successor designation and directives (`AA-ESTATE`); every transition
   emits `ArtistDormancyCompleted` with the vested address, authority
   class, and capability mask. When completion appoints an
   `AUTH_STEWARD`, the registry records the completion block as
   `stewardAppointedAtBlock`, readable through `dormancyState` — the
   pinned boundary the steward minted-before enforcement of
   `AA-SANCTION` requirement 5 reads (ADR 0012 decision T4).
4. Dormancy state, notice deadlines, and both parameter values are
   readable; indexers and frontends must be able to display a running
   notice to the world for the entire window.
5. Dormancy never reduces recorded history: bindings, sanctions, consents,
   and attestations made before dormancy stand unchanged with their
   original authority classes.
6. Absent any operative designation, completion appoints the steward named
   in the completing governance action with `AUTH_STEWARD` limited to
   an effective capability mask built from:

```text
STEWARD_CAPABILITIES = CAP_ATTEST | CAP_ROYALTY_FREEZE | CAP_DISPUTE
                     | CAP_INTENT_RECORDS | CAP_GUARDIAN_SET
```

   `CAP_POLICY_CONSENT` is permanently excluded: a steward can complete
   preservation documentation, defend economics, and — when sanction
   authority is granted below — sanction finality of already-minted
   works, but can never authorize new works in the artist's name.
   `CAP_SANCTION` is not in the default mask (ADR 0013 decision U4):
   signing finality in a dead artist's name is the strongest provenance
   statement the registry knows, so the completing action includes
   `CAP_SANCTION` in the steward's effective mask exactly when an
   operative artist-signed steward sanction grant exists (`AA-ESTATE`
   requirement 7, referenced in the completing action's evidence);
   absent a grant, `CAP_SANCTION` may be added only by a later,
   explicit, reasoned governance action of the `TERMINAL_FREEZE` class
   — its independent veto guardian standing in as the non-platform
   check the missing artist consent would have been — never silently
   inside the completing action, and steward sanctions stay bounded by
   `AA-SANCTION` requirement 5 regardless of grant source.
   `CAP_ECONOMICS_CONSENT` is likewise excluded from the default
   (ADR 0012 decision T4): for a heirless dead artist, governance both
   appoints the steward and stages assignment changes, so a default
   economics grant would collapse both halves of the economics
   handshake into platform-chosen parties. The defensive
   `CAP_ROYALTY_FREEZE` is retained. `CAP_ECONOMICS_CONSENT` may be
   granted to a steward only by the same later, explicit,
   `TERMINAL_FREEZE`-class governance action, never silently inside
   the completing action. `CAP_GUARDIAN_SET` is included so the steward
   can maintain the guardian set that polices its own tenure
   (`AA-GUARD` requirement 1) — additively: the default mask never
   includes `CAP_GUARDIAN_DISPLACE`, so a steward can add guardians
   but cannot remove the artist's own recorded ones absent the
   artist's explicit directive pre-grant, and no governance action may
   grant `CAP_GUARDIAN_DISPLACE` to a steward — the appointing party
   must never be able to unseat the appointee's police (`AA-GUARD`
   requirement 1; ADR 0014 decision V3). A directive's
   `forbiddenCapabilities`
   override every grant path (`AA-ESTATE` requirement 4). The
   policy-consent exclusion, the economics-consent exclusion, the
   grant-gated sanction rule, and the guardian-displacement exclusion
   are Permanent semantics
   of `AUTH_STEWARD`.
7. All dormancy governance actions use the canonical
   `STREAM_GOVERNANCE_ACTION_V1` action ID with dormancy fields folded
   into `scopeHash`/`newValueHash` per ADR 0004 (Canonical Action ID And
   Batch Execution); this document defines no second staging preimage.
8. Completion never voids recorded consents (requirement 5): phases the
   artist consented to keep minting after dormancy completion — the
   consent record still matches the active `policyHash`, attribution
   stays `ARTIST_ACCEPTED`, and `requireMintConsent` keeps passing —
   because a standing authorization does not lapse with liveness. The
   artist-era/steward-era boundary is therefore not the appointment
   itself but the collection's one-way collection burn block
   ([CMC-BURN] vocabulary; ADR 0013 decision U4), and
   steward-completed collection finality requires the burn-block
   activation height to be at or before
   the appointment (`AA-SANCTION` requirement 5). Operational runbooks
   must order the two staged actions accordingly — activate the
   collection burn block before completing dormancy wherever steward-led
   collection finality is the goal — and the completing action's
   evidence should record the open-phase disposition so the boundary
   scholars will interrogate is a documented decision, not an accident
   (ADR 0012 decision T4).
9. Accepted terminal state: dead governance plus an undesignated dead
   artist (ADR 0014 decision V3). Dormancy initiation and completion
   require live platform governance roles, and there is deliberately
   no unsigned finalization path (`AA-SANCTION` requirement 8). If an
   artist dies with no operative successor designation and platform
   governance later fails permanently, no authority can ever again
   vest for the identity: bound-but-unfinalized collections then
   remain permanently unsanctionable and unfinalizable — never
   `ARTIST_SANCTIONED`, never carrying the finality-grade bindings —
   and this document accepts that consequence rather than weaken the
   no-unsigned-finality rule. The mitigations are the artist's own,
   available from day one and restated here as the disclosure home:
   a successor designation (`AA-ESTATE`), whose estate activation is
   governance-independent by construction; pre-signed directives and
   the steward sanction grant (`AA-ESTATE` requirements 3 and 7),
   which carry the artist's voice past any appointed party; a
   registered guardian set (`AA-GUARD`); and the sale-attached
   preservation floor (ADR 0014 decision V1), which binds
   render-critical evidence to the sale itself so an unfinalizable
   collection still carries sale-grade archival records. Designation
   is therefore not merely protective: it is the only
   governance-independent path to posthumous finality, and artist
   onboarding must disclose exactly that (`AA-TOOLING`
   requirement 2).

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
    uint8 disputeAction,     // 1 OPEN, 2 WITHDRAW, 3 COUNTER_STATEMENT,
                             // 4 REPUDIATE (requirement 5; ADR 0014
                             // decision V3)
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
   (`AA-ROLES`), and a `REVOKE` resolution — stripping attribution is
   the strongest thing the platform can do to an artist — must use the
   `TERMINAL_FREEZE` class, whose independent veto guardian checks the
   arbiter's own hierarchy in addition to the requirement 9 appeal tier
   (ADR 0012 decision T4). An `UPHELD` resolution of a reopened
   `ARBITER_REVOKED` generation (requirement 9) must use the
   `TERMINAL_FREEZE` class as well (ADR 0013 decision U4): re-vesting
   adjudicated-away provenance is symmetric in consequence to
   revocation — for the true author and for everyone who relied on the
   earlier adjudication — so reinstatement is never procedurally
   cheaper than the revocation it reverses, and a later captured or
   negligent arbiter cannot resurrect a forger's verified attribution
   under the ordinary delay class. The staged action is public for at
   least its
   full delay
   as the evidence window, and the resolution record must link the
   latest counter-statement record for the dispute (or zero when none
   was filed) — `AttributionDisputeResolved` carries
   `counterStatementRecordHash` so a resolution can never claim the
   artist was silent when they were not.
5. The bound artist authority may repudiate their own attribution; this
   is the artist's unilateral exit and requires no arbiter approval —
   but it is never instant (ADR 0014 decision V3): erasing verified
   attribution across a sanctioned body of work is the one action this
   document makes irreversible, so it stages exactly like the other
   authority-destroying moves instead of handing a stolen key a
   one-shot kill. `revokeAttribution` (direct call, or the
   `StreamArtistAttributionDispute` payload with
   `disputeAction = REPUDIATE`; collaborator policy applies per
   `AA-COLLAB` requirement 4, following the `CAP_DISPUTE` override row
   when present) stages a pending repudiation for the generation:
   at most one may be pending per collection, staging reverts while
   the identity is `IDENTITY_CONTESTED` (`AA-GUARD` requirement 4) or
   the collection is `DISPUTED`, and the record — hashed under
   `ATTRIBUTION_REPUDIATION_RECORD_DOMAIN` — is evented via
   `AttributionRepudiationStaged` and readable via
   `pendingRepudiation(collectionId)` with
   `executableAt = block.timestamp +
   ARTIST_REPUDIATION_CONTEST_SECONDS` (`AA-LIMITS`; the window is
   delay-classed like an arbiter action — its floor matches the
   72-hour [GOV-WINDOWS] terminal-freeze veto floor and the rotation
   contest floor, per `AA-ROLES` discipline). While pending: any
   single registered guardian may veto
   (`vetoAttributionRepudiation`, a direct guardian call per
   `AA-GUARD` requirement 2), which cancels the pending repudiation,
   emits `AttributionRepudiationVetoed` with a reason hash, and sets
   the identity `IDENTITY_CONTESTED` — the registry cannot
   distinguish exit from theft, so it freezes toward safety and
   routes to adjudication; the staging authority may cancel
   (`cancelAttributionRepudiation`, evented via
   `AttributionRepudiationCancelled`); and an
   identity-compromise contest voids the pending repudiation like any
   other pending vesting. After `executableAt`, any caller may
   complete it via `executeAttributionRepudiation`, which performs
   the `AA-STATE` transition to `REVOKED` with reason code
   `REPUDIATED_BY_ARTIST` and is permanently unreopenable
   (`AA-STATE` requirement 5). A thief holding the artist's key
   therefore buys a public, vetoable countdown, not an outcome; an
   artist with no registered guardians still gets the full window in
   which staging a rotation or filing a contest voids the theft —
   and an artist who truly wants out waits out one window, once.
6. Revocation semantics are prospective-only per `AA-STATE` requirement 5:
   display changes everywhere, future authority ends, history and executed
   finality records remain intact and permanently marked. A fraudulent
   binding discovered after an `ARTIST_IDENTITY`-style metadata lock is
   still repudiable here, because registry truth — not the display lock —
   is the authority consumers must read.
7. Dispute vocabulary (`DISPUTED`, `REVOKED`, dispute actions `OPEN`,
   `WITHDRAW`, `COUNTER_STATEMENT`, `REPUDIATE`, resolution codes
   `UPHELD`, `REVOKE`,
   reason codes `REFUSED`, `WITHDRAWN`, `REPUDIATED_BY_ARTIST`,
   `ARBITER_REVOKED`) enters the numeric ID catalog; `REPUDIATE` is
   dispute action `4` (ADR 0014 decision V3), and for a `REPUDIATE`
   payload `evidenceHash` may be zero — requirement 2's
   empty-evidence rule binds dispute openings, not exits.
8. Counter-statement right (ADR 0011 decision R7.7): while a dispute is
   open — including while a resolution is staged — the authority of the
   disputed binding (artist, activated successor, or delegation with
   `CAP_DISPUTE`; collaborator policy applies) may record
   counter-statements using `disputeAction = COUNTER_STATEMENT` with
   evidence and reason hashes, recorded under `DISPUTE_RECORD_DOMAIN`,
   evented via `AttributionCounterStatementRecorded`, and append-only.
   Counter-statements are exempt from the `AA-STATE` requirement 4
   blocks; silencing the accused is never a dispute feature.
9. Appeal and reopening (ADR 0011 decision R7.7): the appeal tier is
   `ROLE_ATTRIBUTION_APPEAL`
   ([`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-ROLES] root; ADR 0013 decision U5) — the governance tier
   holding role-admin authority over `ROLE_ATTRIBUTION_ARBITER`,
   resolved through the admin registry — and it may cancel a staged
   resolution before execution through the ordinary staged-action cancel
   path, on the record and reasoned. After execution, a `REVOKE`
   resolved by the arbiter (`ARBITER_REVOKED`) is not epoch-final: a
   later arbiter may reopen the same generation by opening a new dispute
   carrying new evidence (`AA-STATE` transition `REVOKED -> DISPUTED`);
   resolving that reopened dispute `UPHELD` restores the pre-revocation
   state — under the `TERMINAL_FREEZE` class of requirement 4, because
   reinstatement carries revocation's weight (ADR 0013 decision U4) —
   and `REVOKE` re-affirms. Reopening is append-only — every
   opinion every arbiter ever held remains in the record. Terminations
   the artist chose (`REPUDIATED_BY_ARTIST`) or that ended an unaccepted
   proposal (`REFUSED`, `WITHDRAWN`) are never reopenable against the
   artist's exit.
10. Permissionless third-party attribution claims (ADR 0013 decision
    U4). Requirement 1 standing is deliberately narrow, which would
    leave the most damaging 50-year attack — a third party's work
    misappropriated into an artist-bound collection by an impostor —
    with no onchain record once the bound artist line is dead,
    captured, or complicit, while `PLATFORM_WORKS` victims keep a
    permanent filing path. Artist-bound collections therefore carry
    the same surface: `fileAttributionClaim(collectionId,
    evidenceHash, reasonHash, reasonURI)` lets any address assert
    third-party authorship of an artist-bound collection's works.
    Claims are append-only, permissionless, evented
    (`AttributionClaimFiled`), hashed under
    `ATTRIBUTION_CLAIM_RECORD_DOMAIN`; both hashes must be nonzero and
    commit to canonical evidence documents under the `AA-PLATFORM`
    requirement 4 evidence discipline (metadata record satellites,
    dual-family mirrored). Claims are display-only records: they never
    change attribution state, grant the claimant no authority and no
    requirement 1 standing, and are fileable in every attribution
    state — the `AA-STATE` requirement 4 blocks never apply to them,
    exactly as counter-statements are never blocked. The registry
    maintains a per-collection claim count and latest claim record
    hash readable via `attributionClaims(collectionId)`, and every
    conformant display surface emits them through the attribution
    object (`AA-DISPLAY` `claim_count` / `latest_claim_record`) with
    no arbiter action — the wronged party's evidence reaches
    marketplaces and archives even when nobody with standing ever
    acts. The only state-changing path remains requirement 1: an
    arbiter-opened dispute, whose record should link the claim records
    it elevates. Spam filings are accepted on `AA-PLATFORM`
    requirement 4 terms: evidence-committed, append-only, permanently
    attributed to their claimant, and a raw count asserts only that
    claims exist, never that they are true.

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
   (acceptances — binding, collaborator, and collaborator-identity —
   sanctions, consents — policy, economics, sale, and
   content — content ratifications, freezes, delegations, rotations,
   recovery approvals,
   designations, directives, steward sanction grants, payout
   designations, standing revocations, estate activations, identity
   revisions,
   disputes and repudiations). A revoked-then-submitted
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
   acceptances — binding, collaborator, and collaborator-identity —
   sanctions, consents — policy, economics, sale, and
   content — content ratifications, delegations, guardian sets,
   identity revisions, payout
   designations, steward sanction grants, prior-address standing
   revocations, rotations
   and rotation contests, identity
   recoveries, designations, directives, estate activations, dormancy
   records, disputes, counter-statements, and staged repudiations,
   third-party claims —
   platform-works and artist-bound attribution claims — and
   contests, corrective-rebinding approvals, recovery approvals,
   unavailability findings, attestations,
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
6. Authority-defining records are state-carried (ADR 0012 decision
   T3): for every executed rotation, identity
   recovery, executed estate activation, and dormancy completion, the
   registry stores the exact `abi.encode` preimage bytes of the record
   hash in registry storage (SSTORE2-style permitted), readable via
   `recordPreimageBytes(recordHash)`; `keccak256` of the stored bytes
   equals the record hash, so the carrier is self-verifying with no
   schema trust. The current-authority chain of custody for every
   `artistId` — who held authority, under which class, vested by which
   record — therefore reconstructs from state alone after full log
   expiry, while the broader record stream (consents, attestations,
   disputes) recovers through the mirrored event-history snapshot lane
   (`AA-RECON` requirement 4). This adopts the record payload-bytes
   state-carrier discipline whose mechanism home is the collection
   metadata contract's v1 generic record payload carrier
   ([`collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-RECORD-PAYLOAD]; ADR 0012 decision T3) and the
   onchain-bytes rule of
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-CATALOGS] rule 6: event-embedded payloads never satisfy it.
7. Every stored payload family on this registry — identity documents
   (`AA-IDENTITY`), signature bundles (`AA-SIGVER` requirement 6),
   directive payloads (`AA-ESTATE` requirement 3), and authority-record
   preimages (requirement 6) — is discoverable from state without logs
   (ADR 0012 decision T3): the registry exposes the host payload
   pointer registry of the umbrella home — `storedPayloadCount()` plus
   paged `storedPayloadAt(index)` rows returning
   `(pointer, payloadType, payloadHash)` — with the payload-type tags
   pinned in `AA-DOMAINS`, so a state-only archivist can enumerate and
   verify every payload this registry has ever stored.

## Successor Registry History Import [AA-IMPORT]

The `AA-PERM` succession obligation — a successor registry imports the
full append-only record history and preserves every `artistId` — is
mechanical, not aspirational (ADR 0012 decision T4), specified with the
same discipline as the mint-ledger counter import
([`mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-CONTINUITY]; ADR 0010 decision D5.8). Every registry line ships
this surface from genesis — the genesis registry's import binding is
simply empty — so the mechanism is testable and rehearsed decades
before it is needed.

```solidity
struct ArtistHistoryImportLeaf {
    uint8 laneKind;          // 1 ARTIST_LANE, 2 COLLECTION_LANE
    bytes32 laneKey;         // artistId, or bytes32(uint256(collectionId))
    uint64 sequence;         // 0-based position in the lane's chain
    bytes32 recordHash;
    bytes32 recordChainHash; // accumulator value after this record
}

function commitArtistHistoryImportRoot(
    address predecessorRegistry,
    uint64 snapshotBlock,
    bytes32 importRoot,
    bytes32 manifestHash
) external;

function importedHistoryBinding(uint256 index)
    external view
    returns (
        address predecessorRegistry,
        uint64 snapshotBlock,
        bytes32 importRoot,
        bytes32 manifestHash
    );

function importedHistoryBindingCount() external view returns (uint256);

function verifyImportedRecord(
    bytes32 importRoot,
    ArtistHistoryImportLeaf calldata leaf,
    bytes32[] calldata proof
) external view returns (bool);

// onchain lane-tip verification latch (requirement 7;
// ADR 0014 decision V3)
function verifyImportedLaneTip(
    uint256 bindingIndex,
    ArtistHistoryImportLeaf calldata tipLeaf,
    bytes32[] calldata proof
) external;

function importedLaneVerified(uint8 laneKind, bytes32 laneKey)
    external view
    returns (bool verified, bytes32 laneTip, uint64 recordCount);
```

Requirements:

1. Snapshot and tree: succession tooling exports the predecessor's
   record history — every record hash in every per-`artistId` and
   per-collection lane, in lane order, with the running
   `RECORD_CHAIN_DOMAIN` accumulator value after each record — into a
   Merkle tree at a pinned `snapshotBlock`. Leaves are
   `keccak256(bytes.concat(keccak256(abi.encode(
   ARTIST_HISTORY_IMPORT_LEAF_DOMAIN, uint256(block.chainid),
   address(predecessorRegistry), leaf...))))`; trees are sorted-pair
   keccak with double-hashed leaves, the [MPA-CONTINUITY] construction
   unchanged. Chain linkage is verifiable leaf-by-leaf: each leaf's
   `recordChainHash` must equal the accumulator of its predecessor leaf
   applied to its `recordHash`, so a forged or omitted record breaks
   the chain even against a colluding tree builder.
2. Commitment: `commitArtistHistoryImportRoot` is a staged governance
   action on the successor registry binding
   `(predecessorRegistry, snapshotBlock, importRoot, manifestHash)` and
   emitting `ArtistHistoryImportRootCommitted`. Bindings are
   append-only; the manifest hash commits the full exported dataset —
   every leaf, every lane's `(chainHash, recordCount)` tip at
   `snapshotBlock`, and the predecessor's identity table — so any
   replica can additionally audit completeness offchain against the
   predecessor's
   own `collectionRecordChainHash`/`artistRecordChainHash` reads.
   Offchain audit is redundancy, not the enforcement: cutover
   fidelity is onchain-verified per lane under requirement 7
   (ADR 0014 decision V3).
3. `artistId` preservation: imported identities are served verbatim
   under their original `artistId` values with their full authority,
   status, and record history. The `AA-IDENTITY` derivation rule
   applies only to identities a registry line itself registers — a
   successor cannot recompute predecessor IDs (the preimage binds the
   predecessor's address) and must never re-derive or collide them; a
   new registration that would collide with an imported `artistId`
   reverts.
4. Serving imported history: consumer reads (`IStreamArtistConsent`,
   finality component reads, `verifySanctionForSubject`,
   `verifyRecoveryApproval`, attestation and dispute reads) must answer
   for imported records exactly as for native ones once the record is
   proven and its lane's tip-verification latch is set (requirement
   7) — lazily via `verifyImportedRecord` plus the record's full
   field preimage (recomputing `recordHash` under the pinned
   `AA-DOMAINS` constants), or eagerly by a bulk import; either way an
   unproven claim about predecessor history authorizes nothing, and an
   unverified lane serves nothing. Forward
   writes for an imported lane extend the verified imported
   accumulator tip, so
   the two-line history remains one provable chain.
5. Cutover completeness: the `ARTIST_REGISTRY` pointer move to a
   successor must not execute before the successor has a committed
   binding for the predecessor ([LTA-POINTERS] rule 5 execution
   recheck). The predecessor keeps accepting authenticated records
   until the pointer executes and remains readable forever, so any
   records written between `snapshotBlock` and the pointer execution
   import through one or more follow-up committed roots; the
   succession conformance obligation is that the union of committed
   roots reproduces the predecessor's lane accumulator tips at the
   cutover block. Executed finality is unaffected throughout:
   finality-referenced components pin the registry address that served
   them.
6. Gate: the implementation test suite must rehearse the full import
   round-trip — deploy a second registry instance as successor, export
   a populated predecessor, commit the binding, execute the cutover,
   verify lane tips through `verifyImportedLaneTip` (requirement 7),
   prove records lazily
   and in bulk, verify consumer reads and accumulator continuity, and
   verify the cutover recheck refuses a pointer move without a
   committed binding (`AA-GATES` gate 14).
7. Onchain lane-tip verification (ADR 0014 decision V3). Cutover
   fidelity is enforced onchain per lane, never merely audited:
   governance commits the root, and the chain itself checks the
   commitment against the predecessor's own reads before anything
   imported can serve.
   (a) Predecessor cutover latch: every registry observes the bound
   Core's `ARTIST_REGISTRY` pointer through the bounded read of
   `AA-MODULE` requirement 4. Authenticated record writes revert once
   the pointer no longer names this registry (the live check runs on
   every write until the latch is set), and the permissionless
   `observeRegistryCutover()` records the one-way cutover latch and
   emits `ArtistRegistryCutoverObserved`; the lane accumulator tips
   are thereafter final and readable forever — the fixed reference a
   successor verifies against. Reads are never refused; only new
   records are.
   (b) Successor lane verification: `verifyImportedLaneTip(
   bindingIndex, tipLeaf, proof)` is permissionless — it can only
   confirm truth. It reverts while the Core's `ARTIST_REGISTRY`
   pointer still names the binding's predecessor (tips must be final
   before they are compared); it verifies `tipLeaf` against the named
   binding's `importRoot` under the requirement 1 proof rule; it
   `staticcall`s the predecessor registry the binding names —
   `collectionRecordChainHash(uint256(laneKey))` for
   `COLLECTION_LANE`, `artistRecordChainHash(laneKey)` for
   `ARTIST_LANE` — and reverts unless the returned accumulator equals
   `tipLeaf.recordChainHash`. Success latches
   `importedLaneVerified(laneKind, laneKey)` one-way as
   `(true, tipLeaf.recordChainHash, tipLeaf.sequence + 1)`, never
   re-read and never unset, and emits `ArtistHistoryLaneVerified`.
   (c) The latch gates everything imported: consumer reads must not
   answer for an imported record, and forward writes must not extend
   an imported lane's accumulator, until that lane's latch is set
   (requirement 4). A committed root whose lane tip mismatches the
   predecessor's read can never verify, so a captured governance that
   commits fabricated authority records produces a lane that loudly
   never serves — not quietly served forgery — and the repair is a
   corrected follow-up root under the requirement 5 union rule. The
   offchain manifest audit of requirement 2 remains redundancy for
   archivists, never the enforcement.

## Limits And Governed Parameters [AA-LIMITS]

```text
MAX_COLLABORATORS                 32
MAX_ARTIST_GUARDIANS              8
MAX_GUARDIAN_MIN_CONTEST_SECONDS  2,592,000 (30 days; AA-GUARD req 10)
MAX_FREEZE_LOCK_CLASSES           16
MAX_STORED_SIGNATURE_BYTES        4,096
MAX_DIRECTIVE_PAYLOAD_BYTES       8,192
MAX_IDENTITY_RECORD_BYTES         8,192
MAX_IDENTITY_RECORD_URI_BYTES     2,048
MAX_DISPLAY_NAME_BYTES            256 (AA-IDENTITY req 9)
MAX_REASON_URI_BYTES              2,048
ARTIST_ERC1271_VERIFY_GAS         GGP; floor 90,000; genesis 150,000
ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS
                                  floor 31,536,000; genesis 63,072,000
ARTIST_DORMANCY_NOTICE_SECONDS    floor 15,552,000; genesis 31,536,000
ARTIST_ROTATION_CONTEST_SECONDS   floor 259,200 (72 h);
                                  genesis 604,800 (7 days)
ARTIST_REPUDIATION_CONTEST_SECONDS
                                  floor 259,200 (72 h);
                                  genesis 604,800 (7 days)
ARTIST_PRIOR_ADDRESS_STANDING_TAIL_SECONDS
                                  floor 2,592,000 (30 days);
                                  genesis 7,776,000 (90 days)
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
3. Every seconds-denominated governed window above (dormancy inactivity
   and notice, rotation contest, repudiation contest, prior-address
   standing tail, estate-activation notice,
   unavailability-recovery notice) is owned by this home under the
   [LTA-GTP] closed-world rule — these windows are never Governed Time
   Parameters and claim none of that pattern's identifier, probe, or
   mirror obligations (ADR 0013 decision U9) — and
   follows the same staged change discipline with immutable
   floors; time floors protect artists, so values may be raised freely
   and lowered only through the `DELAYED` class, never below the floor.
   Floors and genesis values are recorded in the release manifest and
   their change events carry old and new values. The rotation contest
   floor deliberately matches the 72-hour terminal-freeze veto floor
   ([`adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-WINDOWS]): identity takeover deserves at least the reaction time
   a terminal freeze gets. The repudiation contest floor matches it for
   the same reason — erasing verified attribution carries takeover
   weight (`AA-DISPUTE` requirement 5; ADR 0014 decision V3) — and the
   prior-address standing tail floor gives a displaced victim at least
   a full extra month beyond the effective contest window before any
   standing can be stripped (`AA-GUARD` requirement 11).

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
        external view returns (bytes memory); // operative document bytes
    function operativeIdentityRecord(bytes32 artistId)
        external view
        returns (
            bytes32 identityRecordHash,
            bytes32 revisionRecordHash, // zero for the registration doc
            uint64 revisedAt
        );
    function identityDocumentBytes(bytes32 identityRecordHash)
        external view returns (bytes memory); // any stored version
    function artistDisplayName(bytes32 artistId)
        external view
        returns (string memory displayName, bytes32 identityRecordHash);
        // operative display-name mirror (AA-IDENTITY requirement 9;
        // ADR 0014 decision V3)

    // guardians and rotation contest (AA-GUARD)
    function guardianSet(bytes32 artistId)
        external view
        returns (
            address[] memory guardians,
            uint32 approvalThreshold,
            uint64 minContestSeconds,
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
    function priorAddressStandingRevoked(
        bytes32 artistId,
        address priorAddress
    )
        external view
        returns (bool revoked, bytes32 revocationRecordHash);
        // AA-GUARD requirement 11 (ADR 0014 decision V3)

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
            bool accepted,
            bytes32 collaboratorArtistId // zero until accepted
        );
    function registryImmutabilityElection(uint256 collectionId)
        external view returns (uint8); // AA-BINDING requirement 10
    function pendingRepudiation(uint256 collectionId)
        external view
        returns (
            uint64 bindingGeneration,
            uint64 executableAt,
            bytes32 repudiationRecordHash
        ); // AA-DISPUTE requirement 5 (ADR 0014 decision V3);
           // zero values when none is pending

    // payout designation (AA-PAYOUT; ADR 0013 decision U1)
    function artistPayoutAccount(bytes32 artistId)
        external view
        returns (address payoutAccount, bytes32 designationRecordHash);
    function collaboratorPayoutAccount(
        bytes32 artistId,
        address collaborator
    )
        external view
        returns (address payoutAccount, bytes32 designationRecordHash);

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
    function platformWorksClaims(uint256 collectionId)
        external view
        returns (uint256 claimCount, bytes32 latestClaimRecordHash);
    function platformWorksCorrection(uint256 collectionId)
        external view
        returns (uint64 correctiveGeneration, bytes32 approvalActionId);
        // AA-PLATFORM requirement 8 (ADR 0014 decision V3);
        // zero values when none
    function attributionClaims(uint256 collectionId)
        external view
        returns (uint256 claimCount, bytes32 latestClaimRecordHash);
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
            uint8 authorityClass,
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
    function stewardSanctionGrant(bytes32 artistId)
        external view
        returns (bool granted, bytes32 grantRecordHash);
        // operative grant per AA-ESTATE requirement 7
    function dormancyState(bytes32 artistId)
        external view
        returns (
            uint8 identityStatus,
            uint64 noticeEndsAt,
            uint64 stewardAppointedAtBlock // zero unless AUTH_STEWARD
        );
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

    // state-carried payloads and discovery (AA-RECORDS 6-7)
    function recordPreimageBytes(bytes32 recordHash)
        external view returns (bytes memory);
    function storedPayloadCount() external view returns (uint256);
    function storedPayloadAt(uint256 index)
        external view
        returns (address pointer, bytes32 payloadType, bytes32 payloadHash);
}
```

`IStreamArtistConsent` is defined in `AA-CONSENT`; the history-import
surface is defined in `AA-IMPORT`. Write functions
(`proposeArtistBinding`, `acceptArtistBinding`, `refuseArtistBinding`,
`withdrawArtistBinding`, `proposeCollaboratorIdentity`,
`acceptCollaboratorIdentity`, `acceptCollaborator`,
`declarePlatformWorks`,
`filePlatformWorksClaim`, `fileAttributionClaim`,
`setPlatformWorksContest`,
`recordArtistSanction`, `confirmSanctionFinalized`, `recordPolicyConsent`,
`recordEconomicsConsent`, `recordSaleConsent`, `recordContentConsent`,
`recordPayoutDesignation`, `recordStewardSanctionGrant`,
`authorizeArtistRoyaltyFreeze`, `authorizeArtistContentFreeze`,
`recordRecoveryApproval`, `recordUnavailabilityFinding`,
`recordArtistAttestation`, `recordIdentityRevision`,
`grantArtistDelegation`, `revokeArtistDelegation`, `setArtistGuardians`,
`rotateArtistAddress`, `approveArtistRotation`, `vetoArtistRotation`,
`executeArtistRotation`, `contestArtistIdentity`,
`vetoIdentityRecovery`, `recoverArtistIdentity`,
`designateSuccessor`, `recordEstateDirective`, `requestEstateActivation`,
`cancelEstateActivation`, `executeEstateActivation`,
`initiateArtistDormancy`, `cancelArtistDormancy`,
`completeArtistDormancy`, `openAttributionDispute`,
`recordCounterStatement`,
`resolveAttributionDispute`, `revokeAttribution`,
`vetoAttributionRepudiation`, `cancelAttributionRepudiation`,
`executeAttributionRepudiation`, `revokePriorAddressStanding`,
`recordContentRatification`, `approvePlatformWorksCorrection`,
`revokeArtistAuthorization`, `commitArtistHistoryImportRoot`,
`verifyImportedLaneTip`, `observeRegistryCutover`) follow the
requirements of their owning
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

event ArtistIdentityRevisionRecorded(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed signer,
    bytes32 previousRecordHash,
    bytes32 revisedRecordHash,
    string identityRecordURI,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 revisionRecordHash
);

event ArtistPayoutDesignationRecorded(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed payoutAccount,
    address indexed signer,
    bytes32 previousDesignationRecordHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 designationRecordHash
);

event ArtistBindingProposed(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed artistId,
    address indexed artistAddress,
    uint64 bindingGeneration,
    bytes32 bindingHash,
    uint8 consentMode,
    uint8 saleConsentScope,
    uint8 registryImmutabilityElection,
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

event CollaboratorIdentityProposed(
    uint16 schemaVersion,
    address indexed account,
    bytes32 identityRecordHash,
    string identityRecordURI,
    address proposer,
    bytes32 reasonHash,
    string reasonURI
);

event CollaboratorAccepted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed collaborator,
    bytes32 indexed collaboratorArtistId,
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

event AttributionClaimFiled(
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

event PlatformWorksCorrectionApproved(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed claimRecordHash,
    bytes32 sustainedContestRecordHash,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint64 approvedAt,
    bytes32 correctionRecordHash,
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
    bytes32 payoutDesignationRecordHash, // operative at consent
                                         // (AA-PAYOUT requirement 3)
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 consentRecordHash
);

event ArtistSaleConsentRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed saleConfigHash,
    address indexed signer,
    bytes32 saleId,
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

event ArtistContentRatificationRecorded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed contentStateHash,
    address indexed signer,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 ratificationRecordHash
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
    uint64 minContestSeconds,
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
    bytes32 subjectRecordHash, // contested transition record; zero for
                               // a general compromise filing
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint64 contestedAt,
    bytes32 contestRecordHash
);

event ArtistIdentityRecoveryVetoed(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed vetoer,
    bytes32 reasonHash,
    bytes32 governanceActionId
);

event ArtistIdentityRecovered(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed oldAddress,
    address indexed newAddress,
    uint8 vestedAuthorityClass, // AUTH_ARTIST or AUTH_SUCCESSOR
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

event PriorAddressStandingRevoked(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed revokedAddress,
    address indexed signer,
    bytes32 retiredTransitionRecordHash,
    uint8 authorityClass,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 signedAt,
    bytes32 revocationRecordHash
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

event StewardSanctionGrantRecorded(
    uint16 schemaVersion,
    bytes32 indexed artistId,
    address indexed signer,
    bool granted,
    bytes32 statementHash,
    uint8 authorityClass,
    uint256 nonce,
    uint64 signedAt,
    bytes32 grantRecordHash
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

event AttributionRepudiationStaged(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed artistId,
    address indexed signer,
    uint64 bindingGeneration,
    uint8 authorityClass,
    bytes32 evidenceHash,
    bytes32 reasonHash,
    uint256 nonce,
    uint64 stagedAt,
    uint64 executableAt,
    bytes32 repudiationRecordHash
);

event AttributionRepudiationVetoed(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed vetoer,
    bytes32 indexed repudiationRecordHash,
    bytes32 reasonHash
);

event AttributionRepudiationCancelled(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed canceller,
    bytes32 indexed repudiationRecordHash,
    uint8 authorityClass
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

event ArtistHistoryImportRootCommitted(
    uint16 schemaVersion,
    address indexed predecessorRegistry,
    bytes32 indexed importRoot,
    uint64 snapshotBlock,
    bytes32 manifestHash,
    bytes32 governanceActionId
);

event ArtistHistoryLaneVerified(
    uint16 schemaVersion,
    uint8 indexed laneKind,
    bytes32 indexed laneKey,
    uint256 bindingIndex,
    bytes32 laneTip,
    uint64 recordCount
);

event ArtistRegistryCutoverObserved(
    uint16 schemaVersion,
    address indexed successorTarget,
    uint64 observedAt
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
hash reaching a release manifest is a conformance failure. For rows
newly pinned in this revision, the exact string preimage in the adjacent
column is normative and the value was computed from it directly. Rows
introduced by ADR 0013 with unpinned hash values are transitional: the
adjacent string preimage is normative, and the value is computed from
it by the domain-constants sweep before merge — an unpinned hash reaching a
release manifest is a conformance failure. Rows and identifiers
introduced by ADR 0014 (decision V3) were pinned in place per
[`launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
[PV1-MIRROR] rule 2 under the same rule: the exact adjacent string
preimage is normative, the CI recomputation run pins the value, and an
unpinned value fails the Review-entry condition of
[`launch-conformance-matrix.md`](launch-conformance-matrix.md)
[LCM-REVIEW-ENTRY].

### StreamArtistRegistry Hash Domains

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `ARTIST_ID_DOMAIN` | `6529STREAM_ARTIST_ID_V1` | 0x17025ea630b7c9d1ea5b6bf0e6375e9190581d7ef45b70c5244b82e48143e3df | `StreamArtistRegistry` | `1` | `ARTIST_ID_DOMAIN; uint256(block.chainid); address(registry); address(firstAddress); bytes32(identityRecordHash); uint256(registrationNonce)` |
| `ARTIST_BINDING_DOMAIN` | `6529STREAM_ARTIST_BINDING_V1` | 0x2ecc91c2aabdb535f25312ccca9a9f7f4ccda08dbaff9fac0423f236562918a0 | `StreamArtistRegistry` | `1` | `ARTIST_BINDING_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint64(bindingGeneration); bytes32(artistId); address(artistAddress); bytes32(identityRecordHash); uint8(consentMode); uint8(saleConsentScope); uint8(registryImmutabilityElection); uint8(collabPolicyMode); uint32(collabThreshold); bytes32(collaboratorSetHash); bytes32(capabilityPolicySetHash)` |
| `COLLABORATOR_SET_DOMAIN` | `6529STREAM_ARTIST_COLLABORATOR_SET_V1` | 0x8e6d305019215c4390d1d804fef71d54d3b43e361f66837f5476ecfaf83c4289 | `StreamArtistRegistry` | `1` | `COLLABORATOR_SET_DOMAIN; CollaboratorRecord[] sorted ascending by (account, role, shareLabelId)` |
| `SANCTION_SUBJECT_DOMAIN` | `6529STREAM_ARTIST_SANCTION_SUBJECT_V1` | 0x47c9894872096248b3971f1551b555619aea8b63903f526c2da354a7286bb473 | `StreamArtistRegistry` | `1` | `SANCTION_SUBJECT_DOMAIN; uint256(block.chainid); address(core); address(finalityRegistry); uint8(scopeType); uint256(collectionId); uint256(tokenId); bytes32(scopeId); bytes32(coreFactsHash); bytes32(nonSanctionComponentsHash); bytes32(manifestURIHash); bytes32(manifestContentHash); bytes32(manifestSchemaId); bytes32(manifestCanonicalizationHash)` |
| `SANCTION_RECORD_DOMAIN` | `6529STREAM_ARTIST_SANCTION_RECORD_V1` | 0xc41417c9bc70713f2cd138ca6fa362e0868076b835d53f51e6d710a2be40dc6b | `StreamArtistRegistry` | `1` | `SANCTION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(signer); uint8(authorityClass); uint8(scopeType); uint256(collectionId); uint256(tokenId); bytes32(scopeId); bytes32(sanctionSubjectHash); bytes32(statementHash); uint256(nonce); uint64(signedAt)` |
| `PLATFORM_WORKS_DOMAIN` | `6529STREAM_PLATFORM_WORKS_DECLARATION_V1` | 0x6e2c16c800cfbfb61e5796751c487517f39063218731ac94bdf06929ec6c4441 | `StreamArtistRegistry` | `1` | `PLATFORM_WORKS_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); bytes32(statementHash); uint64(declaredAt)` |
| `POLICY_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1` | 0x2eebbe574cd30197850ff70c0036755a29224da718226068ffc4d1ea2f1f45a6 | `StreamArtistRegistry` | `1` | `POLICY_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(mintManager); uint256(collectionId); bytes32(phaseId); bytes32(policyHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `ECONOMICS_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1` | 0xc8480bd8b314f13ce90d2a190a53f2b0423cd8325d1080113867b79b79ed6fd3 | `StreamArtistRegistry` | `1` | `ECONOMICS_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(resolver); bytes32(revenueClass); uint8(scope); uint256(scopeId); bytes32(assignmentHash); bytes32(payoutDesignationRecordHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `ROYALTY_FREEZE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1` | 0x4008ba56591f508aff1cc667a65013859ee45bb7abd5506a6176389b97e32b9c | `StreamArtistRegistry` | `1` | `ROYALTY_FREEZE_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(resolver); uint256(collectionId); bytes32(revenueClass); bytes32(expectedAssignmentHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `DELEGATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_DELEGATION_RECORD_V1` | 0xf6aa4346269e975cd2ca6f06c3e610c53b2e6f6505d0707ed8c3661300151bbb | `StreamArtistRegistry` | `1` | `DELEGATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(delegate); uint256(collectionId); uint32(capabilities); uint64(notBefore); uint64(expiresAt); uint64(maxUses); bytes32(constraintsHash); uint256(nonce)` |
| `ATTESTATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTESTATION_RECORD_V1` | 0xa5320c9a6c82fac30567d7843275acca4cb9f68fd5bccff12411115bd197e512 | `StreamArtistRegistry` | `1` | `ATTESTATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint8(subjectKind); bytes32(subjectId); bytes32(subjectStateHash); bytes32(schemaId); bytes32(statementHash); bytes32(statementURIHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `DISPUTE_RECORD_DOMAIN` | `6529STREAM_ARTIST_DISPUTE_RECORD_V1` | 0xcd966414757b448743dc1228e0170513508888b6305f277d658bb84f40946c8f | `StreamArtistRegistry` | `1` | `DISPUTE_RECORD_DOMAIN; uint256(block.chainid); address(registry); uint256(collectionId); uint64(bindingGeneration); uint8(disputeAction); address(opener); uint8(openerAuthorityClass); bytes32(evidenceHash); bytes32(reasonHash); uint256(nonce); uint64(openedAt)` |
| `SUCCESSION_RECORD_DOMAIN` | `6529STREAM_ARTIST_SUCCESSION_RECORD_V1` | 0xe72b08eca38f3231b67e0fa8daba2f1d5daf1953d4b91f8c8e698d14f0ed2b0a | `StreamArtistRegistry` | `1` | `SUCCESSION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(successor); uint8(successorKind); uint32(grantedCapabilities); bytes32(conditionsHash); bytes32(directiveHash); uint256(nonce); uint64(signedAt)` |
| `DIRECTIVE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ESTATE_DIRECTIVE_RECORD_V1` | 0x993e7562ac3c0f8eddb70e4c49c42ef750a52133056061d419fdbe9ee7236f50 | `StreamArtistRegistry` | `1` | `DIRECTIVE_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); uint32(grantedCapabilities); uint32(forbiddenCapabilities); bytes32(directivePayloadHash); uint256(nonce); uint64(signedAt)` |
| `RECORD_CHAIN_DOMAIN` | `6529STREAM_ARTIST_RECORD_CHAIN_V1` | 0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e | `StreamArtistRegistry` | `1` | `RECORD_CHAIN_DOMAIN; bytes32(previousRecordChainHash); bytes32(recordHash)` |
| `CAPABILITY_POLICY_SET_DOMAIN` | `6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1` | 0x87c9af42ac310f72fd69d92f1c290288dcf159f63ed2a1fc75c7e66cc55704d0 | `StreamArtistRegistry` | `1` | `CAPABILITY_POLICY_SET_DOMAIN; CapabilityPolicyOverride[] sorted ascending by capabilityMask (disjoint, nonzero masks)` |
| `ACCEPTANCE_RECORD_DOMAIN` | `6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1` | 0x4b6ab2e018b05a2ca441cf6b0bc3e12a4674b70fd785051a0536faf074f995b4 | `StreamArtistRegistry` | `1` | `ACCEPTANCE_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); uint64(bindingGeneration); bytes32(bindingHash); uint8(acceptanceKind: 1 artist, 2 collaborator); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `GUARDIAN_SET_RECORD_DOMAIN` | `6529STREAM_ARTIST_GUARDIAN_SET_RECORD_V1` | 0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297 | `StreamArtistRegistry` | `1` | `GUARDIAN_SET_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address[] guardians strictly ascending; uint32(approvalThreshold); uint64(minContestSeconds); uint256(nonce); uint64(signedAt)` |
| `ROTATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ROTATION_RECORD_V1` | 0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5 | `StreamArtistRegistry` | `1` | `ROTATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(oldAddress); address(newAddress); bytes32(reasonHash); uint256(nonce); uint64(stagedAt); uint64(contestEndsAt)` |
| `IDENTITY_CONTEST_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_CONTEST_RECORD_V1` | 0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb | `StreamArtistRegistry` | `1` | `IDENTITY_CONTEST_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(contester); bytes32(subjectRecordHash); bytes32(evidenceHash); bytes32(reasonHash); uint64(contestedAt)` |
| `IDENTITY_RECOVERY_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_RECOVERY_RECORD_V1` | 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff | `StreamArtistRegistry` | `1` | `IDENTITY_RECOVERY_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(oldAddress); address(newAddress); uint8(vestedAuthorityClass); bytes32(evidenceHash); bytes32(reasonHash); bytes32(supersededRecordsHash); bytes32(governanceActionId); uint64(recoveredAt)` |
| `IDENTITY_RECOVERY_SUPERSESSION_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_RECOVERY_SUPERSESSION_V1` | 0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae | `StreamArtistRegistry` | `1` | `IDENTITY_RECOVERY_SUPERSESSION_DOMAIN; bytes32[] supersededRecordHashes sorted ascending` |
| `CONTENT_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1` | 0x85ea98da8f1f57787fd3dc784129c3f4f4d4ac889735761822ba32cec9de0bee | `StreamArtistRegistry` | `1` | `CONTENT_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(metadataContract); address(core); uint256(collectionId); bytes32(familyId); bytes32(newStateHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `CONTENT_FREEZE_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1` | 0xdd3e1d6b06c6a49f0da1f66064526a5535238b6a1c258233a419aed42a968354 | `StreamArtistRegistry` | `1` | `CONTENT_FREEZE_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(metadataContract); address(core); uint256(collectionId); bytes32[] lockClasses sorted ascending; bytes32(expectedStateHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `RECOVERY_APPROVAL_RECORD_DOMAIN` | `6529STREAM_ARTIST_RECOVERY_APPROVAL_RECORD_V1` | 0xe60e6ec1d140fa0166261169322ac5c58d77797094a2b68866f812d1172e89b9 | `StreamArtistRegistry` | `1` | `RECOVERY_APPROVAL_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(finalityRegistry); uint256(collectionId); bytes32(finalityRecordHash); bytes32(recoveryManifestHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `UNAVAILABILITY_FINDING_RECORD_DOMAIN` | `6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1` | 0xc087b73d3ef4933341423d2630b88eca87257e38716a129b316ebc148a7fa1f5 | `StreamArtistRegistry` | `1` | `UNAVAILABILITY_FINDING_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); uint256(collectionId); bytes32(evidenceHash); bytes32(reasonHash); bytes32(governanceActionId); uint64(noticeEndsAt); uint64(recordedAt)` |
| `ESTATE_ACTIVATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1` | 0x2bd396eef0a5daaf54fe3c6b7a3888c3d7f7a237c3c4eb69f2848677ee96302f | `StreamArtistRegistry` | `1` | `ESTATE_ACTIVATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(successor); bytes32(evidenceHash); uint256(nonce); uint64(requestedAt); uint64(noticeEndsAt)` |
| `PLATFORM_WORKS_CLAIM_RECORD_DOMAIN` | `6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1` | 0x4b566ba07bf420b345ba4618b1dd0721da12c22766a8024791d4d651a170b0e6 | `StreamArtistRegistry` | `1` | `PLATFORM_WORKS_CLAIM_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); address(claimant); bytes32(evidenceHash); bytes32(reasonHash); uint64(filedAt)` |
| `AUTH_REVOCATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1` | 0x52beeaf4afc420319e9e3d55d092b732ea0ad2a3407f22b60918c0acb7c7d1e5 | `StreamArtistRegistry` | `1` | `AUTH_REVOCATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); bytes32(revokedDigest); uint256(revokedNonce); uint256(nonce); uint64(revokedAt)` |
| `GGP_ARTIST_ERC1271_VERIFY_GAS` | `6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS` | 0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5 | `StreamArtistRegistry` | `1` | Governed Gas Parameter identifier per [LTA-GGP] definition item 5; no `abi.encode` inputs ([AA-SIGVER]) |
| `IDENTITY_REVISION_RECORD_DOMAIN` | `6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1` | 0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4 | `StreamArtistRegistry` | `1` | `IDENTITY_REVISION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); bytes32(previousRecordHash); bytes32(revisedRecordHash); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `SALE_CONSENT_RECORD_DOMAIN` | `6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1` | 0xf30702786801bdda286e4555272eb70024e76bd156af98fab2513886e5bdcfd1 | `StreamArtistRegistry` | `1` | `SALE_CONSENT_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(saleAdapter); address(core); uint256(collectionId); bytes32(saleId); bytes32(saleConfigHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` |
| `DEPLOYMENT_FACTS_DOMAIN` | `6529STREAM_ARTIST_DEPLOYMENT_FACTS_V1` | 0x4ee364f5ea4a8329db8f1dd8aa0877f59a6c2c9878f7239266911d7b56dd3bd7 | `StreamArtistRegistry` | `1` | `DEPLOYMENT_FACTS_DOMAIN; uint256(block.chainid); address(core); uint256(collectionId); bytes32(artistId); uint64(bindingGeneration); bytes32(bindingHash)` ([AA-DEPLOY]) |
| `ARTIST_HISTORY_IMPORT_LEAF_DOMAIN` | `6529STREAM_ARTIST_HISTORY_IMPORT_LEAF_V1` | 0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d | `StreamArtistRegistry` | `1` | double-hashed leaf per [AA-IMPORT]: `ARTIST_HISTORY_IMPORT_LEAF_DOMAIN; uint256(block.chainid); address(predecessorRegistry); uint8(laneKind); bytes32(laneKey); uint64(sequence); bytes32(recordHash); bytes32(recordChainHash)` |
| `PAYOUT_DESIGNATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1` | 0x522d15b3feccd38d699443377aff30a2f429ead391a74f9106313a0fd900379b | `StreamArtistRegistry` | `1` | `PAYOUT_DESIGNATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(payoutAccount); bytes32(previousDesignationRecordHash); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` ([AA-PAYOUT]) |
| `STEWARD_SANCTION_GRANT_RECORD_DOMAIN` | `6529STREAM_ARTIST_STEWARD_SANCTION_GRANT_RECORD_V1` | 0x8e938520f64582e71a67db13c1e692945f6168798f060033fffca4ad733798b4 | `StreamArtistRegistry` | `1` | `STEWARD_SANCTION_GRANT_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); bool(granted); bytes32(statementHash); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` ([AA-ESTATE] requirement 7) |
| `ATTRIBUTION_CLAIM_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1` | 0x1680e7a03051474bbcc02fca6246f1703a2728f81a8997930877a706e2eae063 | `StreamArtistRegistry` | `1` | `ATTRIBUTION_CLAIM_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); address(claimant); bytes32(evidenceHash); bytes32(reasonHash); uint64(filedAt)` ([AA-DISPUTE] requirement 10) |
| `ATTRIBUTION_REPUDIATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1` | 0x295c6fc296e56beb850b55533c6c5d2f45548cda45bb255d9b94a54b4884a4aa | `StreamArtistRegistry` | `1` | `ATTRIBUTION_REPUDIATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); uint256(collectionId); uint64(bindingGeneration); bytes32(artistId); address(signer); uint8(authorityClass); bytes32(evidenceHash); bytes32(reasonHash); uint256(nonce); uint64(stagedAt); uint64(executableAt)` ([AA-DISPUTE] requirement 5; ADR 0014 decision V3) |
| `STANDING_REVOCATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_STANDING_REVOCATION_RECORD_V1` | 0xc62769083037c111cec5a5f8d100e5c4064db79bec694312e35e53acc7256d0e | `StreamArtistRegistry` | `1` | `STANDING_REVOCATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); bytes32(artistId); address(revokedAddress); bytes32(retiredTransitionRecordHash); address(signer); uint8(authorityClass); bytes32(reasonHash); uint256(nonce); uint64(signedAt)` ([AA-GUARD] requirement 11; ADR 0014 decision V3) |
| `CONTENT_RATIFICATION_RECORD_DOMAIN` | `6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1` | 0x90a8ba640de3b545eba38c55a60ece1dc76395a2147d2d2045d8591fad19a730 | `StreamArtistRegistry` | `1` | `CONTENT_RATIFICATION_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(metadataContract); address(core); uint256(collectionId); bytes32(contentStateHash); bytes32(artistId); address(signer); uint8(authorityClass); uint256(nonce); uint64(signedAt)` ([AA-CONTENT] requirement 6; ADR 0014 decision V3) |
| `PLATFORM_WORKS_CORRECTION_RECORD_DOMAIN` | `6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1` | 0x57109180107392289f9aa5aeb40ff031eccfd6b90246bd6c4a1f5c24df62df16 | `StreamArtistRegistry` | `1` | `PLATFORM_WORKS_CORRECTION_RECORD_DOMAIN; uint256(block.chainid); address(registry); address(core); uint256(collectionId); bytes32(sustainedContestRecordHash); bytes32(claimRecordHash); bytes32(evidenceHash); bytes32(reasonHash); bytes32(governanceActionId); uint64(approvedAt)` ([AA-PLATFORM] requirement 8; ADR 0014 decision V3) |

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
| `STREAM_ARTIST_GUARDIAN_SET_TYPEHASH` | `StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)` | 0x397aa6a887bb93367eab618ebf56732031f29da75f932c71ea556746542ebafe | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH` | `StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)` | 0x7908964dc70554ffd5c82353690255d1a8c338be77ffc0f8fb925a27d890587d | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH` | `StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)` | 0xfcb15d96b29996a5852bf06058ae82a7e8acaf7d7601b13fe881ada5d30fc63b | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH` | `StreamArtistRecoveryApproval(address core,address finalityRegistry,uint256 collectionId,bytes32 finalityRecordHash,bytes32 recoveryManifestHash,uint256 nonce,uint64 deadline)` | 0x242bffdf15416a6743c57bd362683aa2933edcd42a4ef176f4e983a745eee511 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH` | `StreamArtistEstateActivation(bytes32 artistId,address successor,bytes32 evidenceHash,uint256 nonce,uint64 deadline)` | 0x35ad5d0278eb067119334d7d4fddd596cad723598851900a95e6ad9a94e51a8a | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH` | `StreamArtistIdentityRevision(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt)` | 0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_SALE_CONSENT_TYPEHASH` | `StreamArtistSaleConsent(address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline)` | 0x5a0d2fee9c2248ad2b0735d54beb28b1decdd1adeb65c63c4016da70ec399045 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH` | `StreamArtistPayoutDesignation(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt)` | 0xfd30c946c20c3c9415f06991c291231ff12c255c9cc849164de44f91cb72c213 | `StreamArtistRegistry` | `1` |
| `STREAM_STEWARD_SANCTION_GRANT_TYPEHASH` | `StreamStewardSanctionGrant(bytes32 artistId,bool granted,bytes32 statementHash,uint256 nonce,uint64 signedAt)` | 0xb48c9f264543966930485ab31e707d91b18c4f9e8644f8dd4a8cbb38c2aea9f2 | `StreamArtistRegistry` | `1` |
| `STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH` | `StreamCollaboratorIdentityAcceptance(address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)` | 0x9a40f74dcb1bb82d3fa4b33ed2dedc82fab75d7dd6c4b04f86cf263a0b867380 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH` | `StreamArtistContentRatification(address core,address metadataContract,uint256 collectionId,bytes32 contentStateHash,uint256 nonce,uint64 deadline)` | 0x56c622946d6da26c6684a8bfd94e3142562ae44e7da904bebe454f049c01b1f5 | `StreamArtistRegistry` | `1` |
| `STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH` | `StreamArtistStandingRevocation(bytes32 artistId,address revokedAddress,bytes32 reasonHash,uint256 nonce,uint64 deadline)` | 0xc3782eba55027b9bef1f60b09cfbcfa48bbd834194f743ae92029711ae18f936 | `StreamArtistRegistry` | `1` |

Component type constants (values enter the same table):

```text
keccak256("ARTIST_SANCTION")             0x1e14b418e60392f62e7baf2e6edfcfb6dfeab92fb4428eff216b492ed5cef047
keccak256("PLATFORM_WORKS_DECLARATION")  0x9b732a2be945a9747de080e93cd0a83076acad44dca7585847960ffebdb0d29d
keccak256("STREAM_ARTIST_REGISTRY")      0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a (module type)
keccak256("artist")                      0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb (ARTIST beneficiary label)
```

Payload-type tags for the payload pointer registry (`AA-RECORDS`
requirement 7; values enter the same table):

```text
keccak256("ARTIST_IDENTITY_DOCUMENT")    0x2126d55680e8526a6a1e238576c0df654dc008fde816e8c1fcb0a5070cf3d1b9
keccak256("ARTIST_SIGNATURE_BUNDLE")     0xbd380808b17a372ab9b9615f35de4cad0deb88a5d9f98fe339cfb976c708005e
keccak256("ARTIST_DIRECTIVE_PAYLOAD")    0x5e503d7bdc75ceeed4f572354ae0b08d6d8d3033937d6a8b5d8aa9a2489694c5
keccak256("ARTIST_RECORD_PREIMAGE")      0xfbd53a6faaa3bc868c95acd12b889bf40dbdda94077ea2fcf8cd6cf29b75427d
```

Pinned schema identifiers (values enter the same table, computed from the
exact strings below):

```text
keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_V1")   0xa7222b7835606e613ba5eee0ebc23654b567e946e997bb27e127e24ed9534c44
    sanction ceremony document schema (AA-SANCTION requirement 9)
keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1")    0x89276c3535c7321ce7f36b8228b64a1b1b9667d531786d9d68df290f9bd0768a
    C2PA credential enumeration attestation schemaId (AA-C2PA)
keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")  0x033054525a5800f9c570932b5b51ed66f5e8a0f1e7622b490ea3d5611bd08025
    deployment attestation document schemaId (AA-DEPLOY)
keccak256("6529STREAM_ARTIST_IDENTITY_V1")            0x513c1691fa38db92e21766dd1b22bc43dfb88d3f422917796fba5bcec0bb4c17
    artist identity document schema (AA-IDENTITY requirement 2;
    revision documents use the same schema; registered as onchain
    schema-registry bytes per [CMC-GENESIS-SCHEMAS])
keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1") 0xbd2c70c3ca64561289cb94739dc105b9f0197370aa78d71850a414840f49d488
    personhood evidence-reference attestation schemaId (AA-IDENTITY
    requirement 8; ADR 0014 decision V3)
keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")   0xb7fae8632a4a5e5d691710e74a3e1e7ea5fd33638e689d90a7a9aa1f4442fb85
    personhood waiver attestation schemaId (AA-IDENTITY requirement 8;
    ADR 0014 decision V3)
```

## Event Reconstruction [AA-RECON]

Requirements:

1. The implementation test suite must include a harness that rebuilds,
   from events alone, and compares against direct reads: artist
   identities and authority addresses through every staged rotation,
   contest, recovery, and succession; guardian sets and rotation
   contest timelines; binding generations, collaborator sets, capability
   policy overrides, collaborator identity registrations and
   acceptance links, and acceptance states; the attribution state
   timeline per collection; consent modes, sale-consent scopes,
   registry-immutability elections, platform-works declarations,
   third-party claims and claim counts for both works classes,
   contest states, and corrective-rebinding approvals with their
   corrected generations; policy, economics,
   sale, and content consent
   records keyed by their hashes; content freezes and first-release
   content ratifications; sanction records and
   their subjects; recovery approvals and unavailability findings;
   attestations with staleness inputs, including deployment
   attestations; identity revisions and the operative-document
   timeline; payout designations and the operative-designation
   timeline; steward sanction grants; delegations with grant, use, and
   revocation state; successor designations, directives, and estate
   activation timelines; dormancy timelines and steward appointment
   blocks; disputes,
   counter-statements, and resolutions; staged attribution
   repudiations with their veto, cancel, and execution timelines;
   prior-address standing revocations; authorization revocations;
   history-import bindings, verified lane tips, and cutover
   observations; and
   both record-chain accumulators.
2. Every record hash emitted must be recomputable from event payload
   fields plus the pinned domain constants; no record may depend on
   unevented storage.
3. The registry's events enter the machine-readable event catalog with
   schema versions, indexed-field lists, and semantic owner, per the
   umbrella spec's Hash And Manifest Discipline.
4. Post-expiry recovery posture (ADR 0012 decision T3): full field
   contents of the broader record stream are
   log-borne by design, so this section's guarantee explicitly rides
   the mirrored event-history snapshot lane — the pinned serialization
   of
   [`stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-EVENT-HISTORY] under its dual-family archival mandate with
   verifiable receipts — as its recovery substrate after log expiry.
   The coupling is deliberately not total: the authority-defining
   chain of custody (rotations, recoveries, estate activations,
   dormancy completions) is additionally state-carried as
   self-verifying preimage bytes (`AA-RECORDS` requirement 6), so a
   2075 question of who controlled an identity in 2031 is answerable
   from the state trie alone even if every event mirror is lost, while
   the full narrative record stream recovers from the mirrored
   snapshots.

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
   anecdote. The rehearsal run must additionally include one artist
   identity held by a Safe-class ERC-1271 contract wallet
   (ADR 0004 [GOV-1271-CLASS]) completing the full ceremony chain from
   acceptance through sanction, with its per-ceremony latency recorded
   separately, and the signing tool must state its supported wallet
   classes in the rehearsal artifact (ADR 0012 decision T5): the
   spec set steers artists toward Safe-held identities (`AA-SPLITS`
   requirement 1), so the recommended custody path must never be the
   one path launch tooling never exercised. The rehearsal must also
   capture the artist's recorded
   acknowledgment of the disclosure-only royalty term before first
   public sale
   ([`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
   [RSR-MARKETPLACE-ROYALTY] rule 3; protocol v1 exclusions item 1),
   of the shared-contract posture (`AA-DEPLOY` requirement 4), of the
   `ARTIST_REGISTRY` pointer freeze state and the registry-immutability
   election (`AA-MODULE` requirement 2, `AA-BINDING` requirement 10),
   of the sale-parameter consent election and its boundary
   (`AA-ECON` requirement 7), and of the guardian holder-latency check
   against the effective contest window (`AA-GUARD` requirement 10);
   every acknowledgment record enters the
   same rehearsal artifact.
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
6. Ceremony load is budgeted, not merely measured (ADR 0012 decision
   T9): exactly as collector gas gets pinned ceilings
   ([`mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MPA-GAS-BUDGET]), the artist's signature count is a product fact
   with a not-to-exceed budget. For the canonical single-artist
   fixed-price collection — one phase, no collaborators, primary and
   `ROYALTY_ERC2981` economics, an intent record, no sale-consent
   election — the complete chain from binding acceptance through
   finality sanction must fit within:

```text
ARTIST_CEREMONY_MAX_SIGNATURES              9
ARTIST_CEREMONY_MAX_SIGNING_SESSIONS        4
ARTIST_CEREMONY_MAX_ACTIVE_SIGNING_MINUTES  60 (cumulative; EOA leg)
ARTIST_CEREMONY_SAFE_MAX_ACTIVE_COORDINATION_MINUTES
                                            180 (cumulative; Safe leg)
```

   The canonical ledger is: binding acceptance (1), guardian-set
   registration (2), payout designation (3), phase policy consent (4),
   primary economics consent (5), royalty economics consent (6),
   intent record or waiver (7), royalty acknowledgment (8), finality
   sanction (9). Sessions are the consolidation instrument
   (ADR 0013 decision U4): a signing session is one continuous
   tool-guided sitting in which consecutive payloads are presented and
   signed with no out-of-band waits between them, and session-batching
   is permitted exactly where it is security-equivalent — every
   batched payload is separately rendered human-readable
   (requirement 1), separately signed, and separately verified
   onchain, so batching changes when ceremonies happen, never what a
   signature covers. The canonical session plan is: session 1 —
   binding acceptance, guardian set, payout designation (plus the
   optional steward sanction grant election, `AA-ESTATE`
   requirement 7, when taken); session 2 — policy and economics
   consents; session 3 — intent record or waiver and the disclosure
   acknowledgments; session 4 — the finality sanction, alone, because
   it binds a `previewFinality`-computed subject that exists only at
   finality time. Active signing
   time is measured from payload presentation to signature completion
   and excludes out-of-band coordination waits, so
   `ARTIST_CEREMONY_MAX_ACTIVE_SIGNING_MINUTES` binds the EOA
   rehearsal leg. The Safe-class contract-wallet leg (requirement 2)
   carries its own pinned ceiling, not disclosure alone (ADR 0014
   decision V4): the signature budget and session plan are shared —
   the payload families are wallet-class-independent — and
   `ARTIST_CEREMONY_SAFE_MAX_ACTIVE_COORDINATION_MINUTES` caps the
   Safe leg's cumulative active coordination time, measured per
   ceremony from payload presentation to the wallet's completed
   `isValidSignature`-ready confirmation across its signer quorum and
   excluding waits between ceremonies. The spec set expects estate-
   and institution-held identities as first-class citizens for fifty
   years, so the friction budget for exactly that signer class is
   bounded too: the gate proves practicality every release, not
   feasibility once. The
   budgets are Operational release-evidence ceilings: the ceremony
   gate (`AA-GATES` gate 13) fails when the rehearsed canonical run
   exceeds any pinned number on its leg,
   and raising a budget requires an ADR, so consent friction can never
   silently grow into operator pressure to weaken consent. No combined
   mega-payload exists and none is planned: each record keeps its own
   signature so 50-year evidence stays granular, and tooling meets the
   budget by presenting ceremonies in the pinned sessions and
   submitting
   multiple verified payloads in one transaction where the owning
   sections permit it. The artist-initiated proposal path stays a
   named extension profile (`AA-BINDING`; ADR 0013 decision U4), so
   the friction ceiling and the onboarding entry point are both
   product facts with recorded owners, not aspirations.

## Conformance Gates [AA-GATES]

These gates enter [`launch-conformance-matrix.md`](launch-conformance-matrix.md)
(Required Gates); deployment is blocked while any fails:

1. Artist binding gate: two-sided acceptance required; admin cannot
   self-accept; unverified display until acceptance; generation history
   reconstructs from events; collaborator identity registration is
   two-sided, permanently links the `(collaboratorArtistId, account)`
   pair at acceptance, rejects registration for an account already
   controlling an `IDENTITY_ACTIVE` identity, and a collaborator
   acceptance without an active collaborator identity reverts
   (`AA-COLLAB` requirement 7).
2. Artist sanction gate: `finalizeCollectionArtwork` and
   `finalizeArtworkScope` revert for artist-bound collections without a
   verified sanction over the exact computed subject hash; subject drift
   invalidates; `PLATFORM_WORKS` collections bind the declaration
   component; no collection finalizes with neither component; an
   `AUTH_STEWARD` sanction records only at `COLLECTION` scope, only
   when the steward's effective mask includes `CAP_SANCTION` (operative
   artist grant and explicit `TERMINAL_FREEZE`-class governance grant
   both exercised in test), with the
   collection burn-block activation height
   (`collectionBurnsBlockedAtBlock`, [CMC-BURN]) nonzero and at or
   before `stewardAppointedAtBlock`; reverts
   for every scoped shape, for a steward without `CAP_SANCTION`, and
   for post-appointment activation heights; an
   `AUTH_SUCCESSOR` sanction carries no such restriction
   (`AA-SANCTION` requirement 5); and steward-completed finality of an
   intent-less collection is exercised end to end — intent-absence
   statement, grant-carried sanction, burn-block boundary
   (ADR 0013 decision U4).
3. Consent-mode gate: phase policy registration reverts for
   `CONSENT_UNSET`; `ARTIST_SIGNED_POLICY` rejects delegated consent;
   stale policy hashes authorize nothing; mint events chain to consent
   records; `requireMintConsent` runs on every mint execution, fails
   closed on `DISPUTED` mid-drop, and fails closed for `PLATFORM_WORKS`
   collections while `CONTESTED` and permanently after
   `CONTEST_SUSTAINED`, resuming on `CONTEST_DISMISSED`
   (`AA-CONSENT` requirement 5); pause and unpause of an
   `ARTIST_SIGNED_POLICY` phase execute with no artist signature and no
   policy re-registration, in every attribution state including
   `DISPUTED` (golden pause-then-resume test, ADR 0011 decision R6);
   a `REGISTRY_FREEZE_REQUIRED` binding blocks phase registration and
   minting until the `ARTIST_REGISTRY` pointer freeze executes, and a
   `REGISTRY_MUTABLE_OK` binding is unaffected (`AA-BINDING`
   requirement 10); the artist-bound first-sale floor binds at the
   mint path (ADR 0014 decision V3): `requireMintConsent` reverts
   absent an operative first-release content ratification
   (`AA-CONTENT` requirement 6), absent a recorded deployment
   attestation for the operative binding generation (`AA-DEPLOY`
   requirement 6), and absent the recorded-or-waived
   personhood-evidence attestation (`AA-IDENTITY` requirement 8),
   with each floor item exercised independently and the waiver path
   exercised.
4. Economics gate: artist-bound assignment changes revert without verified
   economics consent; artist royalty freeze applies exactly once against
   the expected assignment hash; artist-majority default template and
   split disclosure verified; payout designation suite (`AA-PAYOUT`;
   ADR 0013 decision U1): designation chains reject forks and stale
   previous hashes, a designation revision re-points the next
   settlement resolution with no re-consent, economics consent reverts
   while a required designation is unset and binds the operative
   designation record hash, unset designations resolve to zero and the
   settlement mirror reverts, authority rotation changes
   `authorityAddress` while both payout reads return the unchanged
   designated account (the never-a-fallback negative test),
   provisional-window designations are not operative, steward and
   delegate designations revert, and `collaboratorPayoutAccount`
   returns zero for an unlinked pair; where a binding elects
   `SALE_CONSENT_REQUIRED`, sale activation reverts without a verified
   sale consent over the exact `(saleId, saleConfigHash)`, a changed
   configuration invalidates, delegated sale consent is rejected on
   `ARTIST_SIGNED_POLICY` collections, and `SALE_CONSENT_NONE` bindings
   activate with no sale consent (`AA-SALE-CONSENT`).
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
   identity's effective contest window (the guardian-set
   `minContestSeconds` floor raises it, a later global lowering never
   undercuts it, and values above `MAX_GUARDIAN_MIN_CONTEST_SECONDS`
   revert — `AA-GUARD` requirement 10); guardian approval executes
   early, a single-guardian
   veto cancels and contests, prior-address contests stand after
   execution, provisional records — including payout designations and
   steward sanction grants — wait out the window after every
   authority-vesting transition, and
   identity recovery preserves `artistId` while superseding adjudicated
   records, stages under `TERMINAL_FREEZE` with both the independent
   veto guardian and non-superseded registered guardians able to veto,
   and vests the named class (`AUTH_ARTIST` to `IDENTITY_ACTIVE`,
   `AUTH_SUCCESSOR` to `IDENTITY_SUCCEEDED` with designation-bounded
   capabilities); supersession scope is tested both ways (`AA-GUARD`
   requirement 7): a pre-transition guardian's recovery veto counts
   even when an arbiter-staged resolution enumerates its record, an
   arbiter-alone resolution enumerating a pre-transition guardian set
   is refused, the appeal-tier path for hostile pre-transition
   guardians is exercised, and a directive forbidding
   `CAP_GUARDIAN_SET` blocks pre-transition supersession at every
   tier; guardian and arbiter contests filed during estate
   and dormancy notice windows void the pending vesting, contests
   filed after execution reach `IDENTITY_CONTESTED` from
   `IDENTITY_SUCCEEDED`, and dismissal restores the pre-contest
   status; estate activation runs permissionlessly after its notice
   window, cancels on artist liveness, rechecks the operative
   designation at execution, and accelerates — never gates — on
   governance confirmation; dormancy respects inactivity and notice
   floors, cancels on any liveness, refuses completion while
   contested, records `stewardAppointedAtBlock`, and appoints stewards
   without `CAP_POLICY_CONSENT`, `CAP_ECONOMICS_CONSENT`, or — absent
   an operative artist grant — `CAP_SANCTION` (both explicit
   `TERMINAL_FREEZE`-class grants exercised in
   test, and the artist grant path exercised with a withdrawn grant
   rejected); guardian sets are maintainable under `AUTH_SUCCESSOR` and
   `AUTH_STEWARD` with `CAP_GUARDIAN_SET` and rejected without it;
   identity revisions chain from the operative document, reject forks,
   follow the provisional window, and drive the operative reads of
   `AA-IDENTITY` requirement 6; forbidden capability masks are
   absolute, including over steward sanction grants;
   `COLLABORATOR_QUORUM` and capability-policy overrides execute
   without the primary where designated; prior-address standing
   revocation (`AA-GUARD` requirement 11; ADR 0014 decision V3):
   revocation reverts before the retired transition's effective
   contest window plus the pinned tail have both elapsed, while the
   identity is `IDENTITY_CONTESTED`, and while any rotation or
   repudiation is pending; it strips rotation-veto and
   identity-contest standing while a currently registered guardian's
   standing is untouched; steward and delegated revocations revert;
   an identity recovery restores attacker-stripped standing through
   adjudicated supersession; and an arbiter dismissal of a
   demonstrated-bad-faith filing strips the filer's contest and veto
   standing (`AA-GUARD` requirement 5).
7. Dispute gate: standing enforcement, evidence requirement, blocking
   while disputed, arbiter resolution paths — `UPHELD` under the
   `DELAYED` class, `REVOKE` under `TERMINAL_FREEZE` with an exercised
   independent veto —
   with counter-statement linkage, appeal-tier cancel of a staged
   resolution, reopen of an `ARBITER_REVOKED` generation with new
   evidence and its `UPHELD` reinstatement rejected under any class
   weaker than `TERMINAL_FREEZE` (`AA-DISPUTE` requirement 4;
   ADR 0013 decision U4), prospective-only revocation, arbiter-gated
   rebinding after
   revocation; third-party claims file permissionlessly with evidence
   for both works classes — platform-works claims and artist-bound
   attribution claims (`AA-DISPUTE` requirement 10) — update the claim
   count and latest-claim reads with no
   arbiter action, stay fileable in every attribution state, never
   change attribution state, `CONTESTED` blocks finality and minting
   of platform works, and
   sustained contests display
   permanently; staged repudiation (`AA-DISPUTE` requirement 5;
   ADR 0014 decision V3): `revokeAttribution` stages and never
   executes instantly, staging reverts while `IDENTITY_CONTESTED` or
   `DISPUTED`, a single-guardian veto cancels the pending repudiation
   and contests the identity, the staging authority's cancel and a
   filed identity-compromise contest each void it, execution succeeds
   only after `executableAt` and is permanently unreopenable, and the
   collaborator `CAP_DISPUTE` override row is honored; corrective
   rebinding (`AA-PLATFORM` requirement 8; ADR 0014 decision V3):
   approval reverts before `CONTEST_SUSTAINED` and stages under
   `TERMINAL_FREEZE`, authorizes exactly one corrective generation,
   acceptance flips the works class and consent mode exactly once,
   minting resumes only under the corrected artist's full consent
   chain — including a fresh deployment attestation and first-release
   content ratification for the corrective generation — display
   retains `contested` beside `corrected_attribution = true`, and a
   post-finality correction repairs display, economics, and mint
   remainder only.
8. Display gate: renderer emits the `AA-DISPLAY` attribution object with
   golden assertions on the presence and paths of `state`, `works_class`,
   `consent_mode`, `artist_id`, `artist_display_name`,
   `identity_record_hash`, `binding_generation`,
   `attestation_status`, `sanction_record`,
   `sanction_authority_class`, `attestation_authority_class`,
   `deployment_attestation`, `contested`, `corrected_attribution`,
   `claim_count`,
   `latest_claim_record`, and
   `c2pa_authorship_status` across all five states, both works classes,
   staleness, the disputed override, the contested, claimed, and
   corrected platform-works cases, the artist-bound filed-claim case,
   the
   registry-unreachable golden case emitting exactly
   `{ state: "attribution_unavailable" }` (`AA-DISPLAY` requirement 8),
   one golden case per `ArtistAuthorityClass`
   display string, and a golden case verifying `artist_display_name`
   against the stored identity document bytes (ADR 0014 decision V3),
   verified against registry reads; no surface emits
   the retired
   flat fields.
9. Write-authority gate: `ARTIST_*` families reject non-artist writers in
   every genesis satellite; every artist-authority event carries recorder
   and authority class; record-chain accumulators verify against replayed
   history and appear in state exports; `recordPreimageBytes` returns
   self-verifying preimage bytes (`keccak256` equals the record hash)
   for every authority-defining record, and the payload pointer
   registry enumerates every stored payload family with matching
   hashes (`AA-RECORDS` requirements 6-7).
10. Identity-archival gate: identity registration and every identity
    revision store canonical
    document bytes onchain whose keccak256 equals the committed hash;
    oversized documents revert; every stored document — registration
    and revision, primary and collaborator — validates against the
    pinned `6529STREAM_ARTIST_IDENTITY_V1` schema with all required
    members and no unknown top-level members, with the worked example
    as a fixture (`AA-IDENTITY` requirement 2; ADR 0013 decision U4);
    binding and collaborator acceptances refuse to complete
    without the stored bytes plus a dual-family archival record with a
    verifiable receipt for the identity document (`AA-IDENTITY`
    requirements 2 and 6); binding proposals for existing identities
    reject a non-operative `identityRecordHash`; the stored
    display-name mirror equals the document's `displayName` for every
    stored document — registration and revision — oversized names
    revert, and `artistDisplayName` returns the operative pair
    (`AA-IDENTITY` requirement 9; ADR 0014 decision V3).
11. Content-authority gate: content-affecting writes on artist-bound
    collections revert without verified content consent over the exact
    resulting state hash from the earlier of the first-release content
    ratification and the first mint until executed finality;
    pre-ratification and post-finality writes need none, and a
    post-ratification pre-mint write without consent reverts
    (ADR 0014 decision V3); the ratification records only under
    consent-mode authority, is blocked while `DISPUTED`, and drives
    `firstReleaseRatification` and the `requireMintConsent` floor
    (gate 3); the artist content freeze applies the named locks
    exactly once against the expected state hash and is exercised
    pre-mint from binding acceptance; delegated content
    consent and delegated ratification are rejected on
    `ARTIST_SIGNED_POLICY` collections
    (`AA-CONTENT`); entropy configuration changes and fresh-entropy
    redraws for minted artist-bound tokens revert without verified
    content consent over the exact resulting entropy state, with the
    coordinator-side enforcement mirrored in
    [`stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
    (ADR 0013 decision U4).
12. Recovery-approval gate: an `artworkBytesChanged = true` recovery for
    an artist-bound collection reverts without a verified
    `StreamArtistRecoveryApproval` over the exact finality record and
    recovery manifest, or a recorded unavailability finding plus its
    notice window; an artist-authority action during the window voids
    the fallback (`AA-RECOVERY`); an `AUTH_STEWARD` approval for a
    `TOKEN`, `RELEASE`, `SEASON`, or `VIEW` scoped finality record
    reverts, and a collection-scope steward approval reverts absent
    `CAP_SANCTION` or the burn-block/appointment check
    (ADR 0013 decision U4).
13. Ceremony-tooling gate: the rehearsed end-to-end onboarding artifact
    of `AA-TOOLING` exists in release evidence with ceremony-count,
    signing-session, and
    latency measurements at or under the pinned ceremony budgets
    (`AA-TOOLING` requirement 6; ADR 0013 decision U4), includes the
    Safe-class
    contract-wallet artist leg with separately recorded latencies at
    or under `ARTIST_CEREMONY_SAFE_MAX_ACTIVE_COORDINATION_MINUTES`
    (ADR 0014 decision V4) and
    the tool's supported wallet classes, carries every required
    acknowledgment record (royalty term, shared-contract posture,
    pointer freeze state, sale-consent election), the named signing
    tool renders every typed
    payload family human-readable, and the independent recomputation
    tool reproduces `sanctionSubjectHash` and `bindingHash` from public
    inputs (`AA-TOOLING`; ADR 0011 decision R12; ADR 0012 decisions T5
    and T9).
14. History-import gate: the `AA-IMPORT` rehearsal round-trip — commit,
    cutover, lane-tip verification (`AA-IMPORT` requirement 7;
    ADR 0014 decision V3: `verifyImportedLaneTip` latches on equality
    with the predecessor's live lane-tip read, reverts before the
    cutover and on a mismatched or fabricated tip, an unverified lane
    neither serves nor extends, and the predecessor's cutover latch
    refuses post-cutover records while staying readable),
    lazy and bulk proof-verified imports, consumer-read parity for
    imported records, accumulator continuity across the cutover, and
    the pointer-move recheck refusing an unbound successor — passes on
    the implementation test suite (ADR 0012 decision T4).

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
   diligence; the blessed evidence pattern is `AA-IDENTITY`
   requirement 7.
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
9. Scoped steward sanctions. An `AUTH_STEWARD` sanction exists only at
   `COLLECTION` scope under the minted-before read of `AA-SANCTION`
   requirement 5; token-, release-, season-, and view-scope steward
   sanctions are intentionally absent on this registry line because no
   state read proves a scope's token set predates the appointment, and
   an unenforceable validity rule is worse than a provable absence.
   Scoped posthumous finality is served by designated successors
   (`AA-ESTATE`), never by stewards.
