# Artist authority implementation

`StreamArtistOnboardingRegistry` is the ingress for the first executable artist
profile. Its address is the identity used in artist IDs, EIP712 domains, binding
records, owner configuration, and archive evidence. `StreamArtistRegistryV2`
remains the earlier immutable directory; it does not own these new records.

The supported profile is `ARTIST_SIGNED_POLICY`, `PRIMARY_ONLY`, up to 32
collaborator rows, no capability overrides, and operator-set sale parameters.
Operations 1, 2, 3, 4, 5, 6, 7, 14, 15, 17, 18, 20, 21, 24, 26, 27, 52, and 54 have typed entrypoints.
The full 57-operation API is not
advertised, and this implementation does not provide recovery,
estate administration, platform works, collaborator changes, or terminal
finality operations.

Use the caller interfaces under `interfaces/stream/artist/`:

| Caller need | Interface |
| --- | --- |
| Propose, accept, and record the supported artist authorizations | `IStreamArtistOnboarding` |
| Manager consent checks and dependency reads | `IStreamArtistMintConsent` |
| Accepted attribution for metadata and other readers | `IStreamArtistAttribution` |
| Existing content ratification | `IStreamArtistContentRatification` |
| Exact content consent and defensive one-way content freeze | `IStreamArtistContentAuthority` |
| Prospective fixed economics and exact defensive royalty freeze | `IStreamArtistEconomicsAuthority` |
| Preventive identity-scoped nonce or digest cancellation | `IStreamArtistAuthorizationRevocation` |
| Scoped economics/freeze delegation, revocation and exact grant witnesses | `IStreamArtistDelegation` |
| Refuse or withdraw a pending proposal; accept exact queued proposal terms | `IStreamArtistBindingLifecycle` |
| Accepted artist identity and current explicit payout designation | `IStreamArtistBeneficiaryFacts` |
| Two-sided collaborator registration, row acceptance, and generation-scoped reads | `IStreamArtistCollaboratorLifecycle` |
| Immutable owner identity, snapshot, and replay cell | `IStreamArtistOwner` |
| Each domain's typed reads and coordinator-only writes | The seven `IStreamArtist*Owner` interfaces |

`StreamArtistOnboardingTypes` owns the shared payloads. The `Authorization.time`
field is a deadline for acceptance, policy, economics, content consent, freezes, and ratification; it is
the signed timestamp for payout and attestations. Direct payout/attestation calls
can set it to zero to record the eventual inclusion timestamp, so a queued Safe
transaction need not predict its execution time. This convention applies only
when the original caller is the artist and the signature is empty; signed relays,
including approved-empty Safe relays, retain their signed timestamp. Archive
evidence preserves both the submitted zero and the effective authorization.
Delegation grants require time zero because their payload signs its validity
window and nonce. These ABI tuples preserve the
specified EIP712 field order inside each digest. The EIP712 name is
`6529StreamArtistRegistry`, version `1`.

The immutable coordinator authenticates the original caller, obtains typed
facts, and runs the ordered owner actions. Binding, Collaborator, Identity,
Acceptance, Attribution, Payout, and ConsentFinality are separate owners in that
order. Each checks its own prior snapshot before a mutation. The final ArchiveV2
append is atomic with every owner write and nonce consumption. The archive is
evidence storage, not a current-state authority. Identity reuse across a second
collection validates the existing identity without re-registering it or changing
its liveness; Binding and Attribution own the new collection records.

Collaborator identities are staged by an admin and allocated only after the
named account accepts with a direct call or verified signature. Identity stores
the actual document bytes. The permanent signature omits the global allocation
nonce, so a separate persistent account nonce/digest lane prevents replay across
future identity reuse; the same nonce is consumed in the allocated identity too.
Direct registration uses `collaboratorRegistrationNonceState` to read the account
lane's unused nonce. Both lanes and the proposal completion roll back if any
later owner or archive step fails.

Binding owns the immutable sorted `(account, role, shareLabelId)` proposal rows;
Collaborator owns acceptance-ratified identity joins and counts. Each row and the
primary artist must accept. Either order works, and partial acceptance stays
`CLAIMED`; it can still be refused or withdrawn with its evidence preserved.
Exactly the final required acceptance advances Binding and Attribution. Old
generation signatures and joins cannot complete a replacement proposal.
The compatibility attribution read's `acceptanceHash` and `acceptedAt` describe
the primary artist's acceptance event, including while acceptance is partial.
Its `artist` field and `acceptedArtist` remain zero until the complete set accepts;
use authoritative attribution/binding state for readiness, not the timestamp.
The facade's generation-scoped `collaboratorCount` and `collaboratorAt` expose
actual rows. The owner's older no-argument empty/zero getters are bootstrap
compatibility sentinels, not a live inventory.

A nonzero collaborator share label must appear in the actual static economics
profile and pay that collaborator's explicit designation when consent is
created. A zero label is an explicitly unpaid credit, whose declaration must
also be stated in the identity document; this contract does not parse JSON.
Later payout revisions govern new consent and leave existing fixed profiles
unchanged. `collaboratorPayoutAccount` takes the collaborator's artist ID and
acceptance-linked account, returning zero values for an unlinked or undesignated
pair. Collective co-signature modes, collaborator attestations, and changes to
an already accepted collaborator set remain subsequent capabilities.
The maximum-row economics read cost needs separate measured gas admission;
the earlier 300,000 unit Manager allowance is not a claim about that maximum.

The named artist can refuse a pending proposal with a direct call or a verified
refusal signature. Only its stored proposer can withdraw it, even if that
proposer later loses the admin role. Both calls pin the exact generation and
binding hash. They terminate a `CLAIMED` generation with a reason and preserve
its history. A new proposal increments the generation; an authoritative accepted
generation cannot be reopened through these calls. Withdrawal creates no artist
record and changes no Identity state. Its archive entry cites the existing
binding hash, so repeated withdrawal and reproposal remain distinct.

Use `acceptArtistBindingExpected` for queued direct acceptance. It checks the
expected generation and binding hash before consuming authorization. The older
`acceptArtistBinding` retains signed acceptance for every generation, but empty
direct proofs only for generation 1; queued old calldata cannot silently accept
a replacement proposal. Refusal and withdrawal never clear the nomination hash
used by the actual economics providers to enforce artist consent.

`collectionArtistBeneficiary` composes the actual accepted identity and explicit
operative payout record. It rejects absent attribution/designation and a facade
that Core no longer selects. It does not substitute a signing address or require
a revenue resolver callback. Fixed split profiles retain their prior accounts;
this read supplies current facts for consumers that explicitly support them.

All floors are required both at phase registration and before mint effects:

- Accepted binding and consent over the exact prospective Manager policy hash.
- Operative artist payout designation.
- Consent over both actual collection-level primary and ERC2981 assignments.
- Initial ratification, followed only by its exact content or a host-proven consented evolution.
- Deployment attestation matching the current binding generation.
- Personhood evidence or an explicit waiver bound to the operative identity record.

A waiver records the absence of evidence. It does not certify a person. Fixed
split profiles must actually pay the designated artist account when economics
consent is recorded. A later payout designation does not rewrite an existing
fixed split wallet. Unsupported assignment modes are rejected; the separately
described current primary template profile is the supported dynamic path.

Prospective economics consent uses the admitted resolver's typed candidate
preview and its actual split factory. The signed hash must equal that preview,
and artist-labeled profile accounts must match the current payout designation.
Current and prospective consent share operation 15 records and replay keys.
Existing fixed consent remains valid after a payout revision; newly consented
profiles must match the revised designation.

Current operation 15 also admits an initial primary template installed before
artist binding. Its immutable terms must use dynamic `COLLECTION_ARTIST` entries
for the artist label, static nonartist entries, a zero policy, and at least
500,000 artist ppm. The actual pinned resolver supplies the template facts and
canonical assignment hash. The artist signs that current assignment hash; the
archive also retains the actual immutable template terms. All paid collaborator
labels are rejected by this first template profile so they cannot be omitted;
explicitly unpaid rows are supported.

A lawful payout revision changes future template materializations without
requiring new consent to unchanged terms. Existing materialized wallets retain
their immutable recipients. Mint still requires an accepted current identity,
an explicit operative designation, and the exact current economics record.
`FixedEconomicsCandidate.profileHash` keeps its fixed-profile meaning; it is not
a template ID, and current template consent grants no prospective replacement
permission. The previous `requireStaticArtistPayout` read remains static-only.

Operation 54 lets the current identity authority cancel an outstanding principal
nonce or exact action digest. It is independent of collection acceptance and mint
readiness. Exactly one target is nonzero; an authorization using nonce zero can
be cancelled by its exact digest. Already executed or revoked targets reject.
The revocation consumes its own authorization and records observed execution
time. Direct Safe calls and relayed Safe proofs use the same canonical payload.

Principal nonce revocation updates the existing bounded nonce index. Delegate
nonce lanes remain separate; an explicitly revoked identity-scoped digest also
blocks delegated execution. Successful digest observation prevents retrospective
revocation but does not itself collapse distinct delegate lanes. Existing grant
revocation remains the way to remove an entire delegate's authority. Initial
collaborator registration has its separate account replay lane before an identity
exists; no cross-identity account revocation right is implied for future reuse.

Operation 20 authorizes freezing one exact current royalty assignment. It does
not require policy, payout, economics or content mint floors. The authorization
belongs to the current artist and binding generation; the actual resolver must
check the active hash again before applying it. Freezing changes the economics
hash, so minting still requires separate consent to the resulting frozen state.
Neither this record nor prospective consent substitutes for governance on
ordinary assignment changes. `StreamArtistEconomicsHashes` is a linked pure
hashing library; authorization and replay storage remain in their domain owners.

The artist can grant a delegate `CAP_ECONOMICS_CONSENT` (4),
`CAP_ROYALTY_FREEZE` (32), or both. Every other capability is currently rejected,
including the permanently nondelegable payout and identity powers. A grant can
cover one collection or all collections belonging to that artist identity.
Only one unexpired, unrevoked and unexhausted grant per artist/delegate pair is
admitted; a future grant reserves that pair too. `notBefore` is inclusive and
`expiresAt` exclusive. `maxUses = 0` is unlimited only within that finite window;
the read returns `uint64.max` for its remaining-use sentinel. `constraintsHash`
records narrative constraints, not additional executable restrictions.

The grant's `active` read describes its time window, revocation and use limit.
Every actual action also checks the accepted artist binding, collection scope
and capability. Only the original stored grantor can revoke. Revocation blocks
future actions and preserves already recorded consent/freeze authorizations.
Each successful delegated record stores `AUTH_DELEGATE` and an exact grant
witness, readable with `recordDelegation`; its event supplies the same witness.
Delegation never changes the artist's payout or substitutes for governance on
ordinary resolver mutations.

Delegate nonces have a separate persistent artist/delegate lane. Replacement
grants cannot reset used nonces or the bounded allocator. The permanent action
digest does not include a grant ID, so an unused, still-valid action signature
can be submitted under a later matching grant. Every successful use advances
the counter atomically with the Identity replay cell, Consent record and Archive
append. A later failure rolls them all back. Delegated actions do not advance
the artist's liveness timestamp or consume the artist's nonce lane. Automatic
revocation on succession/dormancy remains a required seam before those future
operations can be enabled.

`StreamArtistIdentityState` and `StreamArtistDelegationState` are linked storage
helpers operating on the Identity owner's original and appended slots.
Identity retains its typed Coordinator/snapshot guards and the single semantic
commit. `StreamArtistEconomicOperations` and `StreamArtistBindingOperations` are
linked stateless recipe helpers;
the Coordinator keeps facade authentication, immutable target checks and its
reentrancy lock. These helpers are deployment dependencies, not additional
semantic owners or public protocol ingress points.

Content operation 17 records permission for one exact resulting family state.
The supplied host must equal the immutable metadata host and Core's current
`METADATA_ROUTER`; the artist facade must also remain Core-selected. Unknown
families, unchanged target states, unsupported consent/collaborator modes and
inactive attribution reject. An actual host consumes the returned record once
before applying a write. A fresh nonce can consent to a previously used target
again, so returning to an earlier artwork state does not erase history or reuse
an earlier permission. Permanent records and the latest applicable lookup are
separate. Content signatures remain nondelegable in this signed-policy profile.

Operation 21 authorizes exact current-state one-way locks, with sorted unique
nonzero lock classes and a maximum of 16. It needs accepted-generation authority,
but no payout, economics, ratification or nonempty artwork. The defensive read
also accepts a `DISPUTED` attribution boundary; this does not implement dispute
creation. Unknown or already locked classes reject. The current router's
dependencies are supported but already immutable, so their authorization is a
no-op and rejects. A stale unused freeze can be replaced with a fresh signed
record while its prior evidence stays readable. The host validates the exact
record and expected state, then applies locks permissionlessly. Its event uses
the verified authority class stored in that record.

`requireContentConsent` and `contentConsentEvidence` perform the same current
host, generation and authority validation; the latter returns the exact record
for host consumption. The host's evolution witness must extend an already valid
ratified or consented state. Mint checks that the witness names the current
operative ratification and actual current content. Re-ratification is optional
after compliant evolution and cannot make an old witness describe a new baseline.
`StreamArtistContentHashes` and `StreamArtistContentOperations` are linked,
stateless dependencies; Identity and ConsentFinality retain the only semantic
writes and share the existing atomic archive and revocation-aware nonce path.

The current suite does not yet admit an actual executed-finality provider.
That mandatory gate remains an explicit integration dependency before full-v1
acceptance. Neither Core collection freeze nor an empty/default boolean stands
in for executed finality. Entropy families, successor authority and collective
content policies also remain outside this current router profile.

Policy consent can be recorded before Manager registration. Use
`IStreamMintReads.previewPhasePolicyHash` with the intended executor set. Manager
pause is outside the policy hash and never calls the artist registry or
re-registers the Ledger. Content ratification does not authorize a later content
write; the separate typed content-consent operation must be consumed by the
actual host before that mutation.

Manager links `StreamMintPhaseState` for configuration and executor bookkeeping
to stay within the EIP-170 runtime limit. These delegatecalls operate on the
Manager's original storage and emit events from Manager; owner checks and the
reentrancy lock remain on its public entry points. Full artist consent still
precedes Ledger registration, and a failed registration rolls back the phase.

EOA signatures use canonical ECDSA. Contract signatures remain opaque, bounded
ERC1271 proof bytes. For a Safe, threshold owners sign the handler's SafeMessage
wrapping of the Stream digest, or approve that message through the real Safe
SignMessageLib. An approved empty proof is a valid relayed contract proof. A
direct artist call with empty proof consumes the current unused allocator nonce;
payout and attestation can use the observed-time convention described above.
A Safe owner's EOA
has no implicit authority belonging to the Safe.

The focused onboarding tests use real owners, archive, split factories, primary
and royalty resolvers, Manager, Ledger, and official Safe 1.4.1 bytecode. Their
explicitly named Core, metadata, module-registry, and governance doubles isolate
protocol boundaries. Both primary and royalty previews and application use the
actual providers. The Manager fixture uses an explicit 300,000 authority-read
allowance raised through the real host with a unit governance context. These
tests are not substitutes for the separate real current-Core integration and
governed-provider tests.
